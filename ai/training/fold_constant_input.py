"""Folds an input that a policy has only ever seen at one value into the networks' biases, so a change that starts
feeding it real values does not shift the trained behaviour at once.

Every fight has had a commander since policy 75583, and the leader block's is_elite input read "leader or elite",
so it was always 1. It now reads true elites only. Folding moves value x weight into the bias and zeroes the weight,
in the policy's leader encoder and in the critic's first layer, so the networks answer exactly as before for the old
constant and learn the input's new meaning from zero. Adam's moments for those weights are cleared too.

usage: python fold_constant_input.py --checkpoint <ckpt_*.pt> --out-folder <folder>
       [--block leader --field is_elite --value 1.0]
The checkpoint is never changed: the folded copy goes to --out-folder under the same version.
"""

from __future__ import annotations

import argparse
from pathlib import Path

import torch

import safe_files as S
from convert_checkpoint import read_state
from mob_net import MobCritic, MobPolicy
from mob_schema import MobSchema

## The policy's encoder for each repeated-or-single observation block.
ENCODERS = {"leader": "leader_encoder", "enemy": "enemy_encoder", "ally": "ally_encoder"}


def fold(state: dict, schema: MobSchema, block_name: str, field: str, value: float) -> dict:
    """The state with the field's weights folded into the biases. Raises on an unknown block or field."""
    block = next(b for b in schema.blocks if b.name == block_name)
    column = block.fields[field][0]
    encoder = ENCODERS[block_name]
    policy, critic = dict(state["policy"]), dict(state["critic"])
    weight = policy[f"{encoder}.weight"].clone()
    policy[f"{encoder}.bias"] = policy[f"{encoder}.bias"] + value * weight[:, column]
    weight[:, column] = 0.0
    policy[f"{encoder}.weight"] = weight
    first = critic["layers.0.weight"].clone()
    for repeat in range(block.repeat):
        at = block.offset + repeat * block.stride + column
        critic["layers.0.bias"] = critic["layers.0.bias"] + value * first[:, at]
        first[:, at] = 0.0
    critic["layers.0.weight"] = first
    folded = dict(state)
    folded["policy"], folded["critic"] = policy, critic
    if "optimizer" in state:
        folded["optimizer"] = _clear_moments(state["optimizer"], schema, encoder, block, column)
    return folded


def _clear_moments(optimizer: dict, schema: MobSchema, encoder: str, block, column: int) -> dict:
    """Adam state for the folded weights reset to zero, so stale moments do not push them back at once."""
    names = [f"policy.{n}" for n, _ in MobPolicy(schema).named_parameters()] + [f"critic.{n}" for n, _ in MobCritic(schema).named_parameters()]
    state = {key: dict(value) for key, value in optimizer["state"].items()}
    columns = {f"policy.{encoder}.weight": [column],
               "critic.layers.0.weight": [block.offset + r * block.stride + column for r in range(block.repeat)]}
    for name, cols in columns.items():
        entry = state.get(names.index(name))
        if entry is None:
            continue
        for key in ("exp_avg", "exp_avg_sq"):
            if key in entry:
                moment = entry[key].clone()
                moment[:, cols] = 0.0
                entry[key] = moment
        state[names.index(name)] = entry
    return {**optimizer, "state": state}


def largest_difference(before: dict, after: dict, schema: MobSchema, block_name: str, field: str, value: float, rows: int = 256) -> float:
    """Largest change in any policy logit or critic value, feeding `value` before folding and 0 after."""
    block = next(b for b in schema.blocks if b.name == block_name)
    generator = torch.Generator().manual_seed(7)
    obs = torch.rand(rows, schema.observation_size, generator=generator)
    global_state = torch.rand(rows, schema.global_size, generator=generator)
    hidden = torch.rand(rows, schema.network["recurrent_hidden"], generator=generator)
    old_obs, new_obs = obs.clone(), obs.clone()
    for repeat in range(block.repeat):
        at = block.offset + repeat * block.stride + block.fields[field][0]
        old_obs[:, at] = value
        new_obs[:, at] = 0.0
    largest = 0.0
    with torch.no_grad():
        old_policy, new_policy = MobPolicy(schema), MobPolicy(schema)
        old_policy.load_state_dict(before["policy"])
        new_policy.load_state_dict(after["policy"])
        old_critic, new_critic = MobCritic(schema), MobCritic(schema)
        old_critic.load_state_dict(before["critic"])
        new_critic.load_state_dict(after["critic"])
        largest = max(largest, float((old_policy(old_obs, hidden)[0] - new_policy(new_obs, hidden)[0]).abs().max()))
        largest = max(largest, float((old_critic(old_obs, global_state) - new_critic(new_obs, global_state)).abs().max()))
    return largest


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--checkpoint", type=Path, required=True)
    parser.add_argument("--out-folder", type=Path, required=True)
    parser.add_argument("--block", default="leader")
    parser.add_argument("--field", default="is_elite")
    parser.add_argument("--value", type=float, default=1.0)
    args = parser.parse_args()
    if args.out_folder.resolve() == args.checkpoint.parent.resolve():
        print("Pass --out-folder, a folder other than the checkpoint's own.")
        return 1
    state = read_state(args.checkpoint)
    schema = MobSchema()
    if state is None or state.get("schema_hash") != schema.hash_hex:
        print(f"{args.checkpoint.name} fails its checksum or was made for another schema.")
        return 1
    folded = fold(state, schema, args.block, args.field, args.value)
    difference = largest_difference(state, folded, schema, args.block, args.field, args.value)
    if difference > 1e-4:
        print(f"Folding changed the networks' answers by {difference:.2e}; nothing was saved.")
        return 1
    args.out_folder.mkdir(parents=True, exist_ok=True)
    saved = S.save_checkpoint(args.out_folder, folded, int(state["version"]), 0)
    print(f"Saved {saved}: {args.block}.{args.field} folded at {args.value} (largest change {difference:.1e}); {args.checkpoint} is unchanged.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
