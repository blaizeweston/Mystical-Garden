"""Brings a policy's dead trunk back to life without changing how it plays.

Found 2026-11-25: every unit of trunk_b had died (a ReLU whose input is negative for every observation outputs 0 and
gets no gradient, so it never recovers). It happened after the learning rate went from 0.0003 to 0.003 at policy
3103; from about policy 13800 on, the policy's choices did not depend on the observation at all, only on the legal
options and a nearly constant memory.

Reviving gives the encoders and both trunk layers fresh weights, and zeroes the two places the trunk feeds: the heads'
trunk columns and the memory's input weights. Those carried exactly zero before (the trunk's output was zero), so the
policy answers exactly as before, while the fresh trunk now fires and its outgoing weights get gradient from the first
update. Adam's state for every touched weight is reset, step count included, so the first steps are ordinary
bias-corrected ones rather than oversized. The critic is not touched.

usage: python revive_trunk.py --checkpoint <ckpt_*.pt> --out-folder <folder> [--seed 20261126] [--shards <folder>]
The checkpoint is never changed: the revived copy goes to --out-folder under the same version. --shards (copied
.shard files) checks liveness on real decisions as well as on random ones.
"""

from __future__ import annotations

import argparse
from pathlib import Path

import numpy as np
import torch

import rollouts as R
import safe_files as S
from convert_checkpoint import read_state
from mob_net import MobCritic, MobPolicy
from mob_schema import MobSchema

## The layers upstream of the memory and heads, all replaced.
UPSTREAM = ("self_encoder", "enemy_encoder", "ally_encoder", "leader_encoder", "trunk_a", "trunk_b")


def revive(state: dict, schema: MobSchema, seed: int) -> dict:
    """The state with fresh upstream layers and zeroed trunk outputs; the optimizer's state reset for them."""
    with torch.random.fork_rng():
        torch.manual_seed(seed)
        fresh = MobPolicy(schema).state_dict()
    policy = dict(state["policy"])
    touched = []
    for layer in UPSTREAM:
        for part in ("weight", "bias"):
            policy[f"{layer}.{part}"] = fresh[f"{layer}.{part}"].clone()
            touched.append(f"{layer}.{part}")
    policy["recurrent.weight_ih"] = torch.zeros_like(policy["recurrent.weight_ih"])
    heads = policy["heads.weight"].clone()
    heads[:, :schema.network["trunk_hidden"]] = 0.0
    policy["heads.weight"] = heads
    touched += ["recurrent.weight_ih", "heads.weight"]
    revived = dict(state)
    revived["policy"] = policy
    if "optimizer" in state:
        revived["optimizer"] = _reset_moments(state["optimizer"], schema, touched)
    return revived


def _reset_moments(optimizer: dict, schema: MobSchema, touched: list[str]) -> dict:
    names = [n for n, _ in MobPolicy(schema).named_parameters()] + [f"critic.{n}" for n, _ in MobCritic(schema).named_parameters()]
    state = {key: dict(value) for key, value in optimizer["state"].items()}
    for name in touched:
        index = names.index(name)
        entry = state.get(index)
        if entry is None:
            continue
        for key in ("exp_avg", "exp_avg_sq"):
            if key in entry:
                entry[key] = torch.zeros_like(entry[key])
        if "step" in entry:
            step = entry["step"]
            entry["step"] = torch.zeros_like(step) if torch.is_tensor(step) else 0.0
        state[index] = entry
    return {**optimizer, "state": state}


def largest_difference(before: dict, after: dict, schema: MobSchema, rows: int = 512) -> float:
    """Largest change in any logit or next memory value on random observations and memories."""
    generator = torch.Generator().manual_seed(11)
    obs = torch.randn(rows, schema.observation_size, generator=generator)
    hidden = torch.randn(rows, schema.network["recurrent_hidden"], generator=generator) * 0.5
    old, new = MobPolicy(schema), MobPolicy(schema)
    old.load_state_dict(before["policy"])
    new.load_state_dict(after["policy"])
    with torch.no_grad():
        old_logits, old_hidden = old(obs, hidden)
        new_logits, new_hidden = new(obs, hidden)
    return max(float((old_logits - new_logits).abs().max()), float((old_hidden - new_hidden).abs().max()))


def alive_share(state: dict, schema: MobSchema, obs: torch.Tensor) -> tuple[float, float]:
    """Share of trunk_a and trunk_b units that fire on at least one of the observations."""
    net = MobPolicy(schema)
    net.load_state_dict(state["policy"])
    with torch.no_grad():
        first, second = net.trunk_layers(obs)
    return float((first > 0).any(0).float().mean()), float((second > 0).any(0).float().mean())


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--checkpoint", type=Path, required=True)
    parser.add_argument("--out-folder", type=Path, required=True)
    parser.add_argument("--seed", type=int, default=20261126)
    parser.add_argument("--shards", type=Path, default=None)
    args = parser.parse_args()
    if args.out_folder.resolve() == args.checkpoint.parent.resolve():
        print("Pass --out-folder, a folder other than the checkpoint's own.")
        return 1
    state = read_state(args.checkpoint)
    schema = MobSchema()
    if state is None or state.get("schema_hash") != schema.hash_hex:
        print(f"{args.checkpoint.name} fails its checksum or was made for another schema.")
        return 1
    revived = revive(state, schema, args.seed)
    difference = largest_difference(state, revived, schema)
    if difference > 1e-5:
        print(f"Reviving changed the policy's answers by {difference:.2e}; nothing was saved.")
        return 1
    checks = {"random": torch.randn(4096, schema.observation_size, generator=torch.Generator().manual_seed(12))}
    if args.shards:
        parts = [R.read_shard(p, schema) for p in sorted(args.shards.glob("*.shard"))[:6]]
        if parts:
            obs = R.concatenate(parts).obs
            checks["shards"] = torch.as_tensor(obs[np.linspace(0, len(obs) - 1, min(20000, len(obs))).astype(int)])
    for label, obs in checks.items():
        before, after = alive_share(state, schema, obs), alive_share(revived, schema, obs)
        print(f"Live units on {label} observations: trunk_a {before[0]:.0%} -> {after[0]:.0%}, trunk_b {before[1]:.0%} -> {after[1]:.0%}.")
    args.out_folder.mkdir(parents=True, exist_ok=True)
    saved = S.save_checkpoint(args.out_folder, revived, int(state["version"]), 0)
    print(f"Saved {saved}: trunk revived (largest change in the policy's answers {difference:.1e}); {args.checkpoint} is unchanged.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
