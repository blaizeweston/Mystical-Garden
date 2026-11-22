"""Exports the newest good checkpoint as TorchScript files a model viewer such as Netron can open.

Reads checkpoints only (never changes them), so it is safe while training runs.

  python export_view.py [--run-dir <folder>] [--checkpoint <file.pt>]

Writes <run>/exports/mob_policy_v<version>.pt (the net mobs use) and mob_critic_v<version>.pt (training only).
"""

from __future__ import annotations

import argparse
import io
import sys
from pathlib import Path

import torch

import safe_files as S
from mob_net import MobCritic, MobPolicy
from mob_schema import MobSchema
from train import default_run_dir, load_settings


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--run-dir", type=Path)
    parser.add_argument("--checkpoint", type=Path, help="a specific checkpoint instead of the newest good one")
    args = parser.parse_args()
    run_dir = args.run_dir or default_run_dir(load_settings())
    if args.checkpoint:
        data = S.verified_bytes(args.checkpoint)
        if data is None:
            print(f"{args.checkpoint} does not match its checksum.")
            return 1
        state, path = torch.load(io.BytesIO(data), map_location="cpu", weights_only=True), args.checkpoint
    else:
        loaded = S.load_checkpoint(run_dir / "checkpoints")
        if loaded is None:
            print(f"No good checkpoint in {run_dir / 'checkpoints'}.")
            return 1
        state, path = loaded
    schema = MobSchema()
    policy = MobPolicy(schema).eval()
    policy.load_state_dict(state["policy"])
    critic = MobCritic(schema).eval()
    critic.load_state_dict(state["critic"])
    out = run_dir / "exports"
    out.mkdir(parents=True, exist_ok=True)
    version = int(state["version"])
    obs = torch.zeros(1, schema.observation_size)
    with torch.no_grad():
        traced_policy = torch.jit.trace(policy, (obs, torch.zeros(1, schema.network["recurrent_hidden"])))
        traced_critic = torch.jit.trace(critic, (obs, torch.zeros(1, schema.global_size)))
    policy_path = out / f"mob_policy_v{version}.pt"
    critic_path = out / f"mob_critic_v{version}.pt"
    torch.jit.save(traced_policy, str(policy_path))
    torch.jit.save(traced_critic, str(critic_path))
    print(f"From {path.name} ({int(state['samples']):,} decisions trained):")
    print(f"  {policy_path}")
    print(f"  {critic_path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
