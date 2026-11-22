"""Checks the training pieces that need no Godot: shards, advantages, windows, masked sampling terms, the PPO
update and crash-safe checkpoints. Uses a temporary folder only."""

from __future__ import annotations

import os
import sys
import tempfile
from pathlib import Path

import numpy as np
import torch

import rollouts as R
import safe_files as S
import train as T
from mob_schema import MobSchema

failures: list[str] = []


def check(condition: bool, label: str) -> None:
    print(("PASS " if condition else "FAIL ") + label)
    if not condition:
        failures.append(label)


def synthetic(schema: MobSchema, lives: list[int], seed: int = 1) -> R.Rollout:
    """Random decisions for lives of the given lengths, each ending terminal except the last, which is truncated."""
    rng = np.random.default_rng(seed)
    rows = sum(lives)
    life = np.repeat(np.arange(len(lives)), lives)
    end = np.zeros(rows, dtype=np.uint8)
    stops = np.cumsum(lives) - 1
    end[stops] = R.TERMINAL
    end[stops[-1]] = R.TRUNCATED
    masks = np.zeros((rows, schema.logit_count), dtype=np.uint8)
    actions = np.zeros((rows, len(schema.head_sizes)), dtype=np.uint8)
    offset = 0
    for head, size in enumerate(schema.head_sizes.values()):
        masks[:, offset:offset + size] = rng.random((rows, size)) < 0.6
        masks[:, offset] = 1
        for row in range(rows):
            actions[row, head] = rng.choice(np.flatnonzero(masks[row, offset:offset + size]))
        offset += size
    return R.Rollout(np.zeros(rows, dtype=np.int64), life, rng.normal(size=(rows, schema.observation_size)).astype(np.float32),
                     rng.normal(size=(rows, schema.global_size)).astype(np.float32),
                     np.zeros((rows, schema.network["recurrent_hidden"]), dtype=np.float32), masks, actions,
                     np.full(rows, -3.0, dtype=np.float32), rng.normal(size=rows).astype(np.float32), end,
                     [{"mode": "explore", "outcome": "timeout", "first_sight": 4.0}])


def test_shards(schema: MobSchema, folder: Path) -> None:
    rollout = synthetic(schema, [5, 3, 7])
    path = folder / "a.shard"
    R.write_shard(path, schema, rollout, policy_version=4)
    read = R.read_shard(path, schema)
    same = all(np.array_equal(getattr(read, name), getattr(rollout, name)) for name in ("life", "obs", "masks", "actions", "reward", "end"))
    check(same and read.policy_version[0] == 4 and read.episodes == rollout.episodes, "a shard reads back exactly")
    data = bytearray(path.read_bytes())
    data[200] ^= 0xFF
    path.write_bytes(bytes(data))
    try:
        R.read_shard(path, schema)
        check(False, "a damaged shard is rejected")
    except R.ShardError:
        check(True, "a damaged shard is rejected")
    R.write_shard(path, schema, rollout, policy_version=4)
    path.write_bytes(path.read_bytes()[:-1000])
    try:
        R.read_shard(path, schema)
        check(False, "a shard cut short is rejected")
    except R.ShardError:
        check(True, "a shard cut short is rejected")
    joined = R.concatenate([rollout, rollout])
    check(joined.rows == 30 and len(np.unique(joined.life)) == 6, "joined shards keep their lives apart")


def test_advantages() -> None:
    reward = np.array([0.0, 0.0, 1.0, 0.0, 0.0], dtype=np.float32)
    value = np.array([0.5, 0.5, 0.5, 2.0, 2.0], dtype=np.float32)
    end = np.array([0, 0, R.TERMINAL, 0, R.TRUNCATED], dtype=np.uint8)
    advantage, returns = R.advantages(reward, value, end, gamma=1.0, lam=1.0)
    check(np.allclose(returns[:3], 1.0), "a terminal life returns its rewards and nothing after")
    check(np.allclose(returns[3:], 2.0), "a truncated life bootstraps from its last value")
    check(np.isclose(advantage[0], 0.5), "advantage is return less value")
    windows, first = R.sequences(np.array([0, 0, 0, 0, 0, 1, 1]), 3)
    check(windows.tolist() == [[0, 1, 2], [3, 4, -1], [5, 6, -1]] and first.tolist() == [True, False, True],
          "lives split into padded windows that never cross a life")


def test_masked_terms(schema: MobSchema) -> None:
    trainer_slices = []
    cursor = 0
    for size in schema.head_sizes.values():
        trainer_slices.append((cursor, size))
        cursor += size
    logits = torch.randn(4, schema.logit_count)
    masks = torch.zeros(4, schema.logit_count, dtype=torch.bool)
    for offset, _size in trainer_slices:
        masks[:, offset] = True
    actions = torch.zeros(4, len(trainer_slices), dtype=torch.int64)
    log_prob, entropy = T.masked_terms(logits, masks, actions, trainer_slices)
    check(torch.allclose(log_prob, torch.zeros(4)) and torch.allclose(entropy, torch.zeros(4)), "heads with one legal option add nothing")
    offset, size = trainer_slices[0]
    masks[:, offset:offset + size] = True
    log_prob, _ = T.masked_terms(logits, masks, actions, trainer_slices)
    expected = torch.log_softmax(logits[:, offset:offset + size], dim=1)[:, 0]
    check(torch.allclose(log_prob, expected, atol=1e-5), "an open head scores its choice by softmax over legal options")


def test_trainer(schema: MobSchema, folder: Path) -> None:
    settings = T.load_settings()
    overrides = {"device": "cpu", "batch_rows": 40, "minibatch_sequences": 4, "epochs": 2, "checkpoint_minutes": 0, "keep_checkpoints": 2}
    run = folder / "run"
    trainer = T.Trainer(run, settings, overrides, log=lambda text: None)
    check((run / "policy" / "manifest.json").exists() and trainer.version == 1, "a new run exports policy 1 for the workers")
    rollout = synthetic(schema, [12, 9, 20, 6])
    rollout.policy_version[:] = trainer.version
    R.write_shard(run / "shards" / "w00_a.shard", schema, rollout, trainer.version)
    (run / "shards" / "w00_b.shard").write_bytes(b"not a shard")
    trainer.run(max_updates=1)
    manifest = S.read_json(run / "policy" / "manifest.json")
    check(trainer.updates == 1 and manifest["version"] == 2, "an update trains and publishes policy 2")
    check(not list((run / "shards").glob("*.shard")) and trainer.rejected == 1, "used and damaged shards are removed")
    metrics = (run / "logs" / "metrics.jsonl").read_text().splitlines()
    check(len(metrics) == 1 and '"replay_gap"' in metrics[0], "each update writes a metrics line")
    for index in range(3):
        trainer.checkpoint()
        trainer.version += 1
    kept = sorted(p.name for p in (run / "checkpoints").glob("ckpt_*.pt"))
    check(len(kept) == 2, "only the newest checkpoints are kept")
    newest = run / "checkpoints" / kept[-1]
    newest.write_bytes(newest.read_bytes()[:100])
    resumed = T.Trainer(run, settings, overrides, log=lambda text: None)
    older = S.checkpoint_version(run / "checkpoints" / kept[-2])
    check(resumed.weights_from == older and resumed.samples == rollout.rows, "a damaged newest checkpoint falls back to the one before")
    check(resumed.version == max(older, int(manifest["version"])) + 1, "a resumed run publishes a newer policy version than any before")
    S.atomic_write_bytes(run / "checkpoints" / "latest.json", b"{broken")
    again = S.load_checkpoint(run / "checkpoints", log=lambda text: None)
    check(again is not None, "an unreadable latest.json still finds a good checkpoint")
    check(T.pid_alive(os.getpid()) and not T.pid_alive(0), "the running-process test sees this process")


def main() -> int:
    schema = MobSchema()
    with tempfile.TemporaryDirectory() as temporary:
        folder = Path(temporary)
        test_shards(schema, folder)
        test_advantages()
        test_masked_terms(schema)
        test_trainer(schema, folder)
    print("PASSED" if not failures else f"FAILED: {len(failures)} check(s)")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
