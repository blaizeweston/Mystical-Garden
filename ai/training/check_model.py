"""Checks the network, writes parity fixtures for Godot and compares the two schema parsers."""

from __future__ import annotations

import json
import struct
import sys
from pathlib import Path

import torch

from mob_net import MobCritic, MobPolicy, export_weights
from mob_schema import HEAD_NAMES, MobSchema

OUT = Path(__file__).resolve().parent / "out"
PARITY_ROWS = 256
EXPECTED_PARAMETERS = 284_730
SEED = 20261118


def check(condition: bool, label: str, failures: list[str]) -> None:
    print(("PASS " if condition else "FAIL ") + label)
    if not condition:
        failures.append(label)


def write_fixtures(schema: MobSchema, failures: list[str]) -> None:
    torch.manual_seed(SEED)
    policy = MobPolicy(schema).eval()
    critic = MobCritic(schema).eval()
    parameters = sum(p.numel() for p in policy.parameters())
    check(schema.observation_size == 744, "the observation has 744 values", failures)
    check(schema.logit_count == 66, "the action heads have 66 options", failures)
    check(parameters == EXPECTED_PARAMETERS, f"the policy has {parameters:,} parameters", failures)

    obs = torch.clamp(torch.randn(PARITY_ROWS, schema.observation_size), -schema.clip, schema.clip)
    hidden = torch.tanh(torch.randn(PARITY_ROWS, schema.network["recurrent_hidden"]))
    with torch.no_grad():
        logits, next_hidden = policy(obs, hidden)
        value = critic(obs, torch.zeros(PARITY_ROWS, schema.global_size))
    check(logits.shape == (PARITY_ROWS, schema.logit_count), "the policy returns every head", failures)
    check(next_hidden.shape == hidden.shape, "the policy returns the next hidden state", failures)
    check(value.shape == (PARITY_ROWS,), "the critic returns one value per mob", failures)
    split = policy.split_logits(logits)
    check(list(split) == list(HEAD_NAMES), "the heads split in contract order", failures)

    OUT.mkdir(exist_ok=True)
    export_weights(policy, OUT / "policy.bin")
    with (OUT / "parity.bin").open("wb") as out:
        out.write(struct.pack("<IIII", PARITY_ROWS, schema.observation_size, schema.network["recurrent_hidden"], schema.logit_count))
        for tensor in (obs, hidden, logits, next_hidden):
            out.write(tensor.numpy().astype("<f4").tobytes())
    (OUT / "schema_hash.txt").write_text(schema.hash_hex, encoding="ascii")


def compare_layouts(schema: MobSchema, failures: list[str]) -> None:
    godot = json.loads((OUT / "godot_layout.json").read_text(encoding="utf-8"))
    python_rows = schema.layout_rows()
    check(godot["hash"] == schema.hash_hex, "Godot and Python compute the same schema hash", failures)
    check(godot["observation_size"] == schema.observation_size, "Godot and Python agree on the observation size", failures)
    check(godot["global_size"] == schema.global_size, "Godot and Python agree on the critic state size", failures)
    check(godot["rows"] == python_rows, f"Godot and Python agree on all {len(python_rows)} field offsets", failures)


def main() -> int:
    schema = MobSchema()
    failures: list[str] = []
    if len(sys.argv) > 1 and sys.argv[1] == "compare":
        compare_layouts(schema, failures)
    else:
        write_fixtures(schema, failures)
    print("PASSED" if not failures else f"FAILED: {len(failures)} check(s)")
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
