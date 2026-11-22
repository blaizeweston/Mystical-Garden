"""Reads rollout shards written by ai/rollout_recorder.gd and turns them into training batches.

A shard ends with a SHA-256 of everything before it; a shard that fails it (cut short by a crash or power loss)
is rejected rather than trained on. See ai/rollout_recorder.gd for the layout.
"""

from __future__ import annotations

import hashlib
import json
import struct
from dataclasses import dataclass, field
from pathlib import Path

import numpy as np

from mob_schema import MobSchema

MAGIC = b"MOBR"
FORMAT_VERSION = 1
HEADER = struct.Struct("<4sI64sIIIIIIIII")
CONTINUES, TERMINAL, TRUNCATED = 0, 1, 2


class ShardError(Exception):
    pass


@dataclass
class Rollout:
    """Decisions in life order. life holds a batch-wide id; rows of one life are contiguous."""

    policy_version: np.ndarray
    life: np.ndarray
    obs: np.ndarray
    global_state: np.ndarray
    memory: np.ndarray
    masks: np.ndarray
    actions: np.ndarray
    log_prob: np.ndarray
    reward: np.ndarray
    end: np.ndarray
    episodes: list = field(default_factory=list)

    @property
    def rows(self) -> int:
        return int(self.reward.shape[0])


def read_shard(path: Path, schema: MobSchema) -> Rollout:
    data = path.read_bytes()
    if len(data) < HEADER.size + 36:
        raise ShardError("too short")
    body, digest = data[:-32], data[-32:]
    if hashlib.sha256(body).digest() != digest:
        raise ShardError("checksum does not match")
    magic, version, schema_hash, policy, _worker, rows, _lives, obs_size, global_size, memory, mask_size, heads = HEADER.unpack_from(body)
    if magic != MAGIC or version != FORMAT_VERSION:
        raise ShardError("not a rollout shard of this format")
    if schema_hash.decode("ascii") != schema.hash_hex:
        raise ShardError("recorded with a different schema")
    expected = (schema.observation_size, schema.global_size, schema.network["recurrent_hidden"], schema.logit_count, len(schema.head_sizes))
    if (obs_size, global_size, memory, mask_size, heads) != expected:
        raise ShardError("sizes do not match the schema")
    cursor = HEADER.size

    def take(dtype, count: int, width: int = 1) -> np.ndarray:
        nonlocal cursor
        size = np.dtype(dtype).itemsize * count * width
        if cursor + size > len(body):
            raise ShardError("ends early")
        array = np.frombuffer(body, dtype=dtype, count=count * width, offset=cursor)
        cursor += size
        return array.reshape(count, width) if width > 1 else array

    life = take("<i4", rows)
    obs = take("<f4", rows, obs_size)
    global_state = take("<f4", rows, global_size)
    memory_rows = take("<f4", rows, memory)
    masks = take("u1", rows, mask_size)
    actions = take("u1", rows, heads)
    log_prob = take("<f4", rows)
    reward = take("<f4", rows)
    end = take("u1", rows)
    (stats_length,) = struct.unpack_from("<I", body, cursor)
    cursor += 4
    episodes = json.loads(body[cursor:cursor + stats_length].decode("utf-8")) if stats_length else []
    if cursor + stats_length != len(body):
        raise ShardError("has trailing bytes")
    if rows and (end[-1] == CONTINUES or np.any(np.diff(life) < 0)):
        raise ShardError("has an unfinished or unordered life")
    return Rollout(np.full(rows, policy, dtype=np.int64), life.astype(np.int64), obs, global_state, memory_rows, masks, actions,
                   log_prob, reward, end, episodes)


def concatenate(parts: list[Rollout]) -> Rollout:
    """Joins shards, renumbering lives so they stay distinct."""
    offset = 0
    lives = []
    for part in parts:
        lives.append(part.life + offset)
        offset += int(part.life.max()) + 1 if part.rows else 0
    join = lambda name: np.concatenate([getattr(p, name) for p in parts])  # noqa: E731
    return Rollout(join("policy_version"), np.concatenate(lives), join("obs"), join("global_state"), join("memory"), join("masks"),
                   join("actions"), join("log_prob"), join("reward"), join("end"), [e for p in parts for e in p.episodes])


def advantages(reward: np.ndarray, value: np.ndarray, end: np.ndarray, gamma: float, lam: float) -> tuple[np.ndarray, np.ndarray]:
    """GAE over lives laid end to end. A terminal row has no future; a truncated one bootstraps from its own value,
    since the state after the time limit was never observed."""
    rows = reward.shape[0]
    advantage = np.zeros(rows, dtype=np.float32)
    running = 0.0
    for index in range(rows - 1, -1, -1):
        if end[index] == TERMINAL:
            next_value, running = 0.0, 0.0
        elif end[index] == TRUNCATED:
            next_value, running = value[index], 0.0
        else:
            next_value = value[index + 1]
        delta = reward[index] + gamma * next_value - value[index]
        running = delta + gamma * lam * running
        advantage[index] = running
    return advantage, advantage + value


def sequences(life: np.ndarray, length: int) -> tuple[np.ndarray, np.ndarray]:
    """Splits lives into windows of up to `length` rows. Returns the row index of each window step (-1 for
    padding) and whether each window starts its life."""
    starts = np.flatnonzero(np.r_[True, life[1:] != life[:-1]])
    stops = np.r_[starts[1:], life.shape[0]]
    windows: list[np.ndarray] = []
    first: list[bool] = []
    for start, stop in zip(starts, stops):
        for at in range(start, stop, length):
            window = np.full(length, -1, dtype=np.int64)
            count = min(length, stop - at)
            window[:count] = np.arange(at, at + count)
            windows.append(window)
            first.append(at == start)
    if not windows:
        return np.zeros((0, length), dtype=np.int64), np.zeros(0, dtype=bool)
    return np.stack(windows), np.array(first)


def write_shard(path: Path, schema: MobSchema, rollout: Rollout, policy_version: int, worker: int = 0) -> None:
    """Writes a shard in the recorder's format. Tests use it to make fixtures."""
    lives = int(rollout.life.max()) + 1 if rollout.rows else 0
    head = HEADER.pack(MAGIC, FORMAT_VERSION, schema.hash_hex.encode("ascii"), policy_version, worker, rollout.rows, lives,
                       schema.observation_size, schema.global_size, schema.network["recurrent_hidden"], schema.logit_count,
                       len(schema.head_sizes))
    stats = json.dumps(rollout.episodes).encode("utf-8")
    body = b"".join([head, rollout.life.astype("<i4").tobytes(), rollout.obs.astype("<f4").tobytes(),
                     rollout.global_state.astype("<f4").tobytes(), rollout.memory.astype("<f4").tobytes(),
                     rollout.masks.astype("u1").tobytes(), rollout.actions.astype("u1").tobytes(),
                     rollout.log_prob.astype("<f4").tobytes(), rollout.reward.astype("<f4").tobytes(),
                     rollout.end.astype("u1").tobytes(), struct.pack("<I", len(stats)), stats])
    path.write_bytes(body + hashlib.sha256(body).digest())
