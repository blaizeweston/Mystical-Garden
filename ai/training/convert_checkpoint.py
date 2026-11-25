"""Converts a run's newest good checkpoint to the current schema, keeping everything it learned.

Use it after the schema or contract gains inputs or options (for example a new behaviour). Every weight that
still has a place is copied there; inputs that are new start with zero weight, and new options start as a copy
of a similar existing option (roam starts as idle_wander). When messages are turned on, every symbol starts with
symbol 0's weights, so the network ignores messages at first, and symbols added later start the same way
(see open_messages). When symbols are removed, mates are taken never to send them. A new commit head starts
leaning toward its option 0, the behaviour's usual hold (see lean_commit). The optimizer starts fresh when weights
change shape. The old checkpoints are moved into
checkpoints/schema_<old hash>/ so the trainer cannot fall back to one it can no longer load.

Stop training first. Then:
  python convert_checkpoint.py [--run-dir <folder>]

To convert one saved checkpoint (an anchor for benchmark.py, say) without touching any run folder:
  python convert_checkpoint.py --checkpoint <file.pt> --out-folder <folder>
It writes ckpt_<version>.pt and its checksum into --out-folder and leaves the original as it is.

The checkpoint's schema is found in the repository's history by its hash, so no old files are needed.
"""

from __future__ import annotations

import argparse
import hashlib
import io
import json
import shutil
import subprocess
import sys
import tempfile
import time
from pathlib import Path

import torch

import safe_files as S
from mob_net import MobCritic, MobPolicy
from mob_schema import CONTRACT_PATH, HEAD_NAMES, PROJECT_ROOT, SCHEMA_PATH, MobSchema
from train import default_run_dir, load_settings, pid_alive

## New options start as a copy of these, so they begin about as likely as the option they resemble.
SEED_OPTIONS = {("behaviour", "roam"): "idle_wander"}
## A new commit head picks option 0 (the behaviour's usual hold) this often at first, the set lengths the rest.
COMMIT_USUAL_SHARE = 0.5


def git_versions(path: Path) -> list[str]:
    relative = path.relative_to(PROJECT_ROOT).as_posix()
    out = subprocess.run(["git", "log", "--format=%H", "--", relative], cwd=PROJECT_ROOT, capture_output=True, text=True, check=True)
    return out.stdout.split()


def git_file(commit: str, path: Path) -> bytes:
    relative = path.relative_to(PROJECT_ROOT).as_posix()
    return subprocess.run(["git", "show", f"{commit}:{relative}"], cwd=PROJECT_ROOT, capture_output=True, check=True).stdout


def line_endings(versions) -> list[bytes]:
    """Each version with Unix and with Windows line endings: the hash was taken from a checkout, whose line
    endings depend on the computer's git settings."""
    variants = []
    for data in versions:
        unix = data.replace(b"\r\n", b"\n")
        variants += [unix, unix.replace(b"\n", b"\r\n")]
    return list(dict.fromkeys(variants))


def find_schema(schema_hash: str, folder: Path) -> MobSchema | None:
    """The schema and contract, from the working copy or any commit, whose hash matches. Checkpoints from before
    the hash ignored line endings carry a hash of the raw bytes, which is matched too."""
    current = MobSchema()
    if schema_hash in (current.hash_hex, legacy_hash(SCHEMA_PATH.read_bytes(), CONTRACT_PATH.read_bytes())):
        return current
    schemas = line_endings(git_file(c, SCHEMA_PATH) for c in git_versions(SCHEMA_PATH))
    contracts = line_endings(git_file(c, CONTRACT_PATH) for c in git_versions(CONTRACT_PATH))
    for schema_bytes in schemas:
        for contract_bytes in contracts:
            schema_file, contract_file = folder / "schema.json", folder / "contract.json"
            schema_file.write_bytes(schema_bytes)
            contract_file.write_bytes(contract_bytes)
            candidate = MobSchema(schema_file, contract_file)
            if schema_hash in (candidate.hash_hex, legacy_hash(schema_bytes, contract_bytes)):
                return candidate
    return None


def legacy_hash(schema_bytes: bytes, contract_bytes: bytes) -> str:
    """The hash used before line endings were ignored: of the raw file bytes."""
    return hashlib.sha256(schema_bytes + contract_bytes).hexdigest()


def contract_names(schema: MobSchema, contract_path: Path | None = None) -> list[str]:
    data = json.loads((contract_path or CONTRACT_PATH).read_text(encoding="utf-8"))
    return [entry["name"] for entry in data["behaviours"]]


def element_key(schema: MobSchema, name: str, element: int):
    """A field element's key. A message's elements are keyed by channel and symbol, so that a symbol keeps its
    weights when the symbol count changes (with 4 symbols element 4 is channel B's symbol 0; with 16 it is A's 4)."""
    if name == "message":
        symbols = schema.head_sizes["message_a"]
        return ("ab"[element // symbols], element % symbols)
    return element


def column_keys(schema: MobSchema, blocks, prefix: str = "") -> list[tuple]:
    """One key per input value: (block, repeat index, field, element), in layout order."""
    keys = []
    for block in blocks:
        for index in range(block.repeat):
            for name, (_offset, size) in block.fields.items():
                for element in range(size):
                    keys.append((prefix + block.name, index, name, element_key(schema, name, element)))
    return keys


def slot_keys(schema: MobSchema, block_name: str) -> list[tuple]:
    """Keys for one slot of a repeated block (the input of a shared encoder)."""
    block = next(b for b in schema.blocks if b.name == block_name)
    return [(block.name, 0, name, element_key(schema, name, element)) for name, (_offset, size) in block.fields.items()
            for element in range(size)]


def option_keys(schema: MobSchema, behaviours: list[str]) -> list[tuple]:
    keys = []
    for head in HEAD_NAMES:
        for option in range(schema.head_sizes[head]):
            keys.append((head, behaviours[option] if head == "behaviour" else option))
    return keys


def remap(old: torch.Tensor, new_shape, old_rows=None, new_rows=None, old_cols=None, new_cols=None, seeds=None) -> torch.Tensor:
    """Copies old values to the new shape by matching row and column keys. Unmatched values are zero, or, for a
    row in seeds, a copy of the row it names."""
    result = torch.zeros(new_shape, dtype=old.dtype)
    row_from = {key: i for i, key in enumerate(old_rows)} if old_rows else None
    col_from = {key: i for i, key in enumerate(old_cols)} if old_cols else None
    rows = range(new_shape[0])
    for row in rows:
        key = new_rows[row] if new_rows else None
        source_row = row if row_from is None else row_from.get(key)
        if source_row is None and seeds and key in seeds:
            source_row = row_from.get((key[0], seeds[key]))
        if source_row is None:
            continue
        if old.dim() == 1:
            result[row] = old[source_row]
            continue
        if col_from is None:
            result[row] = old[source_row]
            continue
        for col, col_key in enumerate(new_cols):
            source_col = col_from.get(col_key)
            if source_col is not None:
                result[row, col] = old[source_row, source_col]
    return result


def convert(state: dict, old: MobSchema, old_names: list[str], new: MobSchema, new_names: list[str]) -> tuple[dict, dict]:
    old_obs, new_obs = column_keys(old, old.blocks), column_keys(new, new.blocks)
    old_global, new_global = column_keys(old, old.global_blocks, "global."), column_keys(new, new.global_blocks, "global.")
    old_self = [k for b in old.encoder_blocks("self") for k in column_keys(old, [b])]
    new_self = [k for b in new.encoder_blocks("self") for k in column_keys(new, [b])]
    old_options, new_options = option_keys(old, old_names), option_keys(new, new_names)
    seeds = {key: value for key, value in SEED_OPTIONS.items()}
    policy, critic = MobPolicy(new), MobCritic(new)
    shapes = {name: tuple(t.shape) for name, t in policy.state_dict().items()}
    converted = {}
    columns = {"self_encoder": (old_self, new_self), "enemy_encoder": (slot_keys(old, "enemy"), slot_keys(new, "enemy")),
               "ally_encoder": (slot_keys(old, "ally"), slot_keys(new, "ally")),
               "leader_encoder": (slot_keys(old, "leader"), slot_keys(new, "leader"))}
    for name, tensor in state["policy"].items():
        layer, kind = name.split(".", 1)
        if layer in columns and kind == "weight":
            converted[name] = remap(tensor, shapes[name], old_cols=columns[layer][0], new_cols=columns[layer][1])
        elif layer == "heads":
            converted[name] = remap(tensor, shapes[name], old_options, new_options, seeds=seeds)
        elif tuple(tensor.shape) == shapes[name]:
            converted[name] = tensor.clone()
        else:
            raise SystemExit(f"Cannot convert {name}: {tuple(tensor.shape)} to {shapes[name]}.")
    critic_converted = {}
    critic_shapes = {name: tuple(t.shape) for name, t in critic.state_dict().items()}
    for name, tensor in state["critic"].items():
        if name == "layers.0.weight":
            critic_converted[name] = remap(tensor, critic_shapes[name], old_cols=old_obs + old_global, new_cols=new_obs + new_global)
        elif tuple(tensor.shape) == critic_shapes[name]:
            critic_converted[name] = tensor.clone()
        else:
            raise SystemExit(f"Cannot convert critic {name}: {tuple(tensor.shape)} to {critic_shapes[name]}.")
    policy.load_state_dict(converted)
    critic.load_state_dict(critic_converted)
    proof = prove(state, old, new, old_obs, new_obs, old_options, new_options, policy)
    return {"policy": converted, "critic": critic_converted}, proof


def prove(state, old, new, old_obs, new_obs, old_options, new_options, policy) -> dict:
    """Feeds the same situations to the old and the converted policy: every old option must score the same."""
    torch.manual_seed(7)
    old_policy = MobPolicy(old)
    old_policy.load_state_dict(state["policy"])
    rows = 256
    old_inputs = torch.clamp(torch.randn(rows, old.observation_size), -old.clip, old.clip)
    # Masked inputs are always zero, so a masked field that is renamed or dropped loses nothing. Inputs with no
    # place in the new observation (message symbols no longer sent) are taken as never set.
    kept = set(new_obs)
    for col, key in enumerate(old_obs):
        if key[2] in next(b for b in old.blocks if b.name == key[0]).masked or key not in kept:
            old_inputs[:, col] = 0.0
    new_inputs = torch.zeros(rows, new.observation_size)
    index = {key: i for i, key in enumerate(old_obs)}
    for col, key in enumerate(new_obs):
        if key in index:
            new_inputs[:, col] = old_inputs[:, index[key]]
    hidden = torch.tanh(torch.randn(rows, old.network["recurrent_hidden"]))
    with torch.no_grad():
        old_logits, old_next = old_policy(old_inputs, hidden)
        new_logits, new_next = policy(new_inputs, hidden)
    where = {key: i for i, key in enumerate(new_options)}
    # Options removed (message symbols) are dropped; a softmax over the rest keeps their relative odds.
    shared = [i for i, key in enumerate(old_options) if key in where]
    mapped = torch.stack([new_logits[:, where[old_options[i]]] for i in shared], dim=1)
    return {"largest_logit_difference": float((mapped - old_logits[:, shared]).abs().max()),
            "largest_memory_difference": float((new_next - old_next).abs().max())}


def lean_commit(weights: dict, schema: MobSchema, share: float = COMMIT_USUAL_SHARE) -> float:
    """Starts a new commit head choosing option 0 (the behaviour's usual hold) with probability share and the set
    lengths equally the rest of the time, whatever the situation: its weights are zero and only option 0's bias is
    raised. Returns option 0's probability."""
    size = schema.head_sizes.get("commit", 0)
    if size < 2:
        return 1.0
    start = sum(schema.head_sizes[h] for h in HEAD_NAMES[:HEAD_NAMES.index("commit")])
    policy = weights["policy"]
    policy["heads.weight"][start:start + size] = 0.0
    policy["heads.bias"][start:start + size] = 0.0
    policy["heads.bias"][start] = float(torch.log(torch.tensor(share * (size - 1) / (1.0 - share))))
    return float(torch.softmax(policy["heads.bias"][start:start + size], 0)[0])


def messages_enabled(contract_path: Path) -> bool:
    data = json.loads(contract_path.read_text(encoding="utf-8"))
    return bool(data.get("rules", {}).get("messages_enabled", False))


def message_groups(schema: MobSchema, block: str, absolute: bool) -> list[int]:
    """The first input column of every message's one-hot symbols: per slot of the block (absolute=False, the
    encoder's input) or for every repeat of it in the whole observation (absolute=True, the critic's input)."""
    found = next(b for b in schema.blocks if b.name == block)
    offset, size = found.fields["message"]
    symbols = schema.head_sizes["message_a"]
    repeats = range(found.repeat) if absolute else range(1)
    base = found.offset if absolute else 0
    return [base + index * found.stride + start for index in repeats for start in range(offset, offset + size, symbols)]


def open_messages(weights: dict, schema: MobSchema, first_new: int = 1) -> None:
    """Gives message symbols first_new and above symbol 0's weights. With messages off every mate's message was
    symbol 0, so only symbol 0's weights learned anything (first_new 1); when symbols are added, the new ones have
    none (first_new is the old symbol count). With symbol 0's input weights a mob hears a new symbol as symbol 0 at
    first, and with symbol 0's head row each new symbol starts as likely as symbol 0. Training then finds what is
    worth saying."""
    symbols = schema.head_sizes["message_a"]

    def spread(tensor: torch.Tensor, starts: list[int]) -> None:
        for start in starts:
            tensor[:, start + first_new:start + symbols] = tensor[:, start:start + 1]

    policy, critic = weights["policy"], weights["critic"]
    spread(policy["ally_encoder.weight"], message_groups(schema, "ally", False))
    spread(policy["leader_encoder.weight"], message_groups(schema, "leader", False))
    spread(critic["layers.0.weight"], message_groups(schema, "ally", True) + message_groups(schema, "leader", True))
    position = 0
    for head in HEAD_NAMES:
        size = schema.head_sizes[head]
        if head in ("message_a", "message_b"):
            for name in ("heads.weight", "heads.bias"):
                policy[name][position + first_new:position + size] = policy[name][position:position + 1]
        position += size


def message_proof(weights: dict, schema: MobSchema, first_new: int = 1) -> dict:
    """Mates sending random new symbols (first_new and above) instead of symbol 0 must change nothing yet, and every
    new symbol must be as likely as symbol 0."""
    torch.manual_seed(11)
    policy, critic = MobPolicy(schema), MobCritic(schema)
    policy.load_state_dict(weights["policy"])
    critic.load_state_dict(weights["critic"])
    rows, symbols = 256, schema.head_sizes["message_a"]
    quiet = torch.clamp(torch.randn(rows, schema.observation_size), -schema.clip, schema.clip)
    starts = message_groups(schema, "ally", True) + message_groups(schema, "leader", True)
    for start in starts:
        quiet[:, start:start + symbols] = 0.0
    talking = quiet.clone()
    for start in starts:
        quiet[:, start] = 1.0
        talking[torch.arange(rows), start + torch.randint(first_new, symbols, (rows,))] = 1.0
    hidden = torch.tanh(torch.randn(rows, schema.network["recurrent_hidden"]))
    global_state = torch.randn(rows, schema.global_size)
    with torch.no_grad():
        quiet_logits, quiet_next = policy(quiet, hidden)
        talking_logits, talking_next = policy(talking, hidden)
        value_gap = (critic(quiet, global_state) - critic(talking, global_state)).abs().max()
        heads = policy.split_logits(quiet_logits)
    spread = max(float((heads[h][:, first_new:] - heads[h][:, :1]).abs().max()) for h in ("message_a", "message_b"))
    return {"logit_difference": float((quiet_logits - talking_logits).abs().max()),
            "memory_difference": float((quiet_next - talking_next).abs().max()),
            "value_difference": float(value_gap), "symbol_spread": spread}


def wall_seconds(metrics: Path) -> float | None:
    """Training time from the metrics log: the time between updates, leaving out pauses."""
    if not metrics.exists():
        return None
    stamps = []
    for line in metrics.read_text(encoding="utf-8").splitlines():
        try:
            stamps.append(time.mktime(time.strptime(json.loads(line)["time"], "%Y-%m-%d %H:%M:%S")))
        except (ValueError, KeyError):
            continue
    return sum(b - a for a, b in zip(stamps, stamps[1:]) if 0 < b - a < 600)


def read_state(path: Path) -> dict | None:
    data = S.verified_bytes(path)
    if data is None:
        if path.with_name(path.name + ".sha256").exists():
            return None
        data = path.read_bytes()
    return torch.load(io.BytesIO(data), map_location="cpu", weights_only=True)


def convert_state(state: dict, path: Path) -> dict | None:
    """The checkpoint converted to the current schema, proven to score its old options the same, or None."""
    new = MobSchema()
    with tempfile.TemporaryDirectory() as temporary:
        old = find_schema(state["schema_hash"], Path(temporary))
        if old is None:
            print("The checkpoint's schema is not in this repository's history; it cannot be converted.")
            return None
        old_contract = Path(temporary) / "contract.json"
        if not old_contract.exists():
            old_contract = CONTRACT_PATH
        old_names = contract_names(old, old_contract)
        was_quiet = not messages_enabled(old_contract)
    new_names = contract_names(new)
    weights, proof = convert(state, old, old_names, new, new_names)
    print(f"Converted {path.name}: observation {old.observation_size} -> {new.observation_size}, options {old.logit_count} -> {new.logit_count}.")
    print(f"Old options score the same: largest difference {proof['largest_logit_difference']:.2e}, memory {proof['largest_memory_difference']:.2e}.")
    if proof["largest_logit_difference"] > 1e-4 or proof["largest_memory_difference"] > 1e-4:
        print("The converted policy does not match the old one; nothing was changed.")
        return None
    first_new = 1 if was_quiet else old.head_sizes["message_a"]
    if messages_enabled(CONTRACT_PATH) and new.head_sizes["message_a"] > first_new:
        open_messages(weights, new, first_new)
        heard = message_proof(weights, new, first_new)
        print(f"Message symbols {first_new}-{new.head_sizes['message_a'] - 1} opened: they mean what symbol 0 means for now "
              f"(logits {heard['logit_difference']:.2e}, memory {heard['memory_difference']:.2e}, value {heard['value_difference']:.2e}) "
              f"and start as likely as symbol 0 (spread {heard['symbol_spread']:.2e}).")
        if max(heard.values()) > 1e-4:
            print("The message warm start did not hold; nothing was changed.")
            return None
    if old.head_sizes.get("commit", 0) == 0 and new.head_sizes.get("commit", 0) > 1:
        usual = lean_commit(weights, new)
        print(f"Commit head added: the usual hold starts at {100 * usual:.0f}%, each set length at {100 * (1 - usual) / (new.head_sizes['commit'] - 1):.0f}%.")
    if new.head_sizes["message_a"] < old.head_sizes["message_a"]:
        print(f"Message symbols {new.head_sizes['message_a']}-{old.head_sizes['message_a'] - 1} removed: mates are taken never to send them.")
    converted = dict(state)
    converted.update(weights)
    converted["schema_hash"] = new.hash_hex
    # When only the schema's hash changed, every weight keeps its shape and the optimizer's memory still fits.
    # Otherwise it no longer fits the reshaped weights and the trainer starts a new one.
    same_shapes = all(tuple(state["policy"][k].shape) == tuple(v.shape) for k, v in weights["policy"].items()) and         all(tuple(state["critic"][k].shape) == tuple(v.shape) for k, v in weights["critic"].items())
    if not same_shapes:
        converted.pop("optimizer", None)
    return converted


def convert_file(path: Path, out_folder: Path) -> int:
    state = read_state(path)
    if state is None:
        print(f"{path.name} does not match its checksum.")
        return 1
    if state["schema_hash"] == MobSchema().hash_hex:
        print(f"{path.name} already uses the current schema. Nothing to convert.")
        return 0
    converted = convert_state(state, path)
    if converted is None:
        return 1
    out_folder.mkdir(parents=True, exist_ok=True)
    saved = S.save_checkpoint(out_folder, converted, int(state["version"]), 0)
    print(f"Saved {saved} for the current schema; {path} is unchanged.")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--run-dir", type=Path)
    parser.add_argument("--checkpoint", type=Path, help="convert this one file into --out-folder instead of a run's newest")
    parser.add_argument("--out-folder", type=Path)
    args = parser.parse_args()
    if args.checkpoint is not None:
        if args.out_folder is None or args.out_folder.resolve() == args.checkpoint.parent.resolve():
            print("Pass --out-folder, a folder other than the checkpoint's own.")
            return 1
        return convert_file(args.checkpoint, args.out_folder)
    run_dir = args.run_dir or default_run_dir(load_settings())
    holder = S.read_json(run_dir / "trainer.lock") or {}
    if pid_alive(int(holder.get("pid", 0))):
        print("Training is running. Stop it first (stop_training.ps1).")
        return 1
    folder = run_dir / "checkpoints"
    loaded = S.load_checkpoint(folder)
    if loaded is None:
        print(f"No good checkpoint in {folder}.")
        return 1
    state, path = loaded
    if state["schema_hash"] == MobSchema().hash_hex:
        print(f"{path.name} already uses the current schema. Nothing to convert.")
        return 0
    converted = convert_state(state, path)
    if converted is None:
        return 1
    seconds = wall_seconds(run_dir / "logs" / "metrics.jsonl")
    if seconds is not None:
        converted["seconds"] = seconds
        converted["milestone_seconds"] = min(float(state.get("milestone_seconds", 0.0)), seconds)
    archive = folder / f"schema_{state['schema_hash'][:12]}"
    archive.mkdir(exist_ok=True)
    for old_file in list(folder.glob("ckpt_*.pt")) + list(folder.glob("ckpt_*.pt.sha256")) + [folder / "latest.json"]:
        if old_file.exists():
            shutil.move(str(old_file), str(archive / old_file.name))
    saved = S.save_checkpoint(folder, converted, int(state["version"]), 5)
    print(f"Saved {saved.name} for the current schema; the old checkpoints are in {archive.name}.")
    print("Start training again to continue from it.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
