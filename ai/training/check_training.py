"""Checks the training pieces that need no Godot: shards, advantages, windows, masked sampling terms, the PPO
update and crash-safe checkpoints. Uses a temporary folder only."""

from __future__ import annotations

import json
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
    overrides = {"device": "cpu", "batch_rows": 40, "minibatch_sequences": 4, "epochs": 2, "checkpoint_minutes": 0, "keep_checkpoints": 2,
                 "benchmark_milestones": False}
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
    explained = __import__("json").loads(metrics[0]).get("explained_variance")
    check(isinstance(explained, float) and explained <= 1.0, "each update logs the critic's explained variance")
    line = __import__("json").loads(metrics[0])
    check(line["entropy_messages"] > 0.0 and line["entropy_fight"] > 0.0 and 0.0 < line["free_share"] <= 1.0,
          "each update logs fighting entropy on free decisions, message entropy, and the share of free decisions")
    check(0.0 < line["trunk_alive"] <= 1.0 and 0.0 < line["trunk_a_alive"] <= 1.0 and line["obs_sensitivity"] > 0.0,
          "each update logs the live trunk units and how much choices react to the observation")
    check(line["policy_grad_norm"] > 0.0 and line["critic_grad_norm"] > 0.0, "each update logs the policy's and critic's gradient norms")
    configured = T.load_settings()["trainer"]
    check(T.entropy_weights(configured) == (float(configured["entropy_weight_fight"]), float(configured["entropy_weight_messages"])) and
          T.entropy_weights({"entropy_weight": 0.01}) == (0.01, 0.01), "fighting and message choices have their own entropy bonus")
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
    for kl in (0.0,) * 40:
        resumed.adapt_learning_rate(kl)
    check(abs(resumed.learning_rate - float(settings["trainer"]["max_learning_rate"])) < 1e-12, "the learning rate rises no higher than max_learning_rate")
    for kl in (1.0,) * 200:
        resumed.adapt_learning_rate(kl)
    check(abs(resumed.learning_rate - T.LR_FLOOR) < 1e-12, "the learning rate falls no lower than its floor")
    check(resumed.accept_from == 0, "an ordinary resume accepts rollouts from the policy it saved")
    # Roll back: the newest published policy (here 50) is newer than any checkpoint.
    published = resumed.version + 40
    S.atomic_write_json(run / "policy" / "manifest.json", {**S.read_json(run / "policy" / "manifest.json"), "version": published})
    for leftover in (run / "shards").glob("*.shard"):
        leftover.unlink()
    rolled = T.Trainer(run, settings, overrides, log=lambda text: None)
    check(rolled.accept_from == published + 1 == rolled.version and rolled.weights_from < published,
          "a resume from an older checkpoint accepts only rollouts from the policy it publishes")
    for name, version in (("w00_old.shard", published), ("w01_new.shard", published + 1)):
        played = synthetic(schema, [12, 9, 20, 6])
        played.policy_version[:] = version
        R.write_shard(run / "shards" / name, schema, played, version)
    rolled.collect()
    left = sorted(p.name for p in (run / "shards").glob("*.shard"))
    check(left == ["w01_new.shard"] and rolled.stale == 1, "rollouts played by the replaced run are dropped after a rollback")


def test_replace_waits_for_open_file(folder: Path) -> None:
    """A reader holding the target open (as a worker reading the manifest does) only delays an atomic write."""
    import threading
    target = folder / "held.json"
    S.atomic_write_json(target, {"version": 1})
    holder = target.open("rb")
    threading.Timer(0.4, holder.close).start()
    S.atomic_write_json(target, {"version": 2})
    check(S.read_json(target) == {"version": 2} and holder.closed, "an atomic write waits for a reader to let go, then succeeds")


def test_evaluation(schema: MobSchema, folder: Path) -> None:
    """evaluate.py's fight-by-fight comparison, summaries, critic diagnosis and report, on made-up fights."""
    import evaluate as E
    from mob_net import MobCritic, MobPolicy
    names = ["idle_wander", "approach", "flee"]

    def fight(seed: int, index: int, outcome: str, damage: float) -> dict:
        return {"seed": seed, "index": index, "mode": "engaged" if index % 2 else "explore", "party": 2, "mobs": 4,
                "outcome": outcome, "seconds": 30.0, "damage_to_party": damage, "party_hp": 200.0, "downs": 0, "mobs_killed": 2,
                "first_sight": 5.0, "first_within_3m": 8.0, "reward_values": {"damage": damage / 100.0, "hp_lost": -0.5},
                "awake_behaviours": [0, 3, 1], "idle_behaviours": [4, 0, 0],
                "time": {"mob_seconds": 100.0, "aware": 60.0, "sees": 40.0, "within_3m": 10.0, "3_to_8m": 30.0, "8_to_16m": 40.0, "beyond_16m": 20.0}}

    base = [fight(1, i, "timeout", 20.0) for i in range(10)]
    same = E.paired(base, base)
    check(all(abs(v) < 1e-12 and abs(e) < 1e-12 for v, e in same.values()), "identical brains differ by nothing on the same fights")
    better = [fight(1, i, "wipe", 60.0 + i) for i in range(10)]
    difference = E.paired(better, base)
    check(abs(difference["wipe"][0] - 1.0) < 1e-9 and abs(difference["party_hp_lost"][0] - 0.2225) < 1e-9,
          "fight-by-fight differences match the fights")
    summary = E.summarise(base, names)
    check(abs(sum(summary["awake_behaviours"].values()) - 1.0) < 1e-9 and abs(summary["time"]["aware"] - 0.6) < 1e-9,
          "behaviour shares add up and time shares are per mob-second")
    shards = folder / "eval_shards"
    shards.mkdir()
    R.write_shard(shards / "eval_1.shard", schema, synthetic(schema, [20, 15, 9]), 1)
    torch.manual_seed(3)
    state = {"policy": MobPolicy(schema).state_dict(), "critic": MobCritic(schema).state_dict(), "version": 5, "samples": 1000}
    contestant = E.Contestant("v5 (0M)", folder / "unused.bin", state)
    found = E.diagnose(contestant, shards, schema, T.load_settings())
    shares = sum(h["share_of_entropy_sum"] for h in found["heads"].values())
    check(found["rows"] == 44 and np.isfinite(found["explained_variance_full"]) and abs(shares - 1.0) < 1e-6,
          "the critic diagnosis reads recorded decisions and splits entropy by head")

    uniform = E.random_brain(schema, folder)
    check(uniform.kind == "random" and not uniform.scripted and uniform.policy_file.stat().st_size > 1000,
          "the random brain is exported as a policy of its own kind")

    sharp = E.sharpened(contestant, 0.5, schema, folder)
    check(sharp.kind == "sharpened" and sharp.label == "v5 (0M) T0.5" and sharp.policy_file.exists(),
          "a sharpened policy is exported under its own label")
    plain_policy = MobPolicy(schema)
    plain_policy.load_state_dict(state["policy"])
    sharp_policy = E.sharpen_policy(state["policy"], schema, 0.5)
    sample = torch.randn(3, schema.observation_size)
    hidden = plain_policy.initial_hidden(3)
    with torch.no_grad():
        check(torch.allclose(sharp_policy(sample, hidden)[0], plain_policy(sample, hidden)[0] / 0.5, atol=1e-5),
              "sharpening at temperature 0.5 doubles every logit")

    class Args:
        episodes, seed = 10, 1
    scripted = E.Contestant(E.SCRIPTED, folder / "unused.bin")
    text, data = E.report([scripted, contestant], {E.SCRIPTED: base, "v5 (0M)": better}, {"v5 (0M)": found}, names, Args)
    check("Same fights, difference from scripted" in text and "Entropy by action head" in text and data["baseline"] == E.SCRIPTED,
          "the report compares every brain with the first one")


def test_choice_test(schema: MobSchema, folder: Path) -> None:
    """choice_test.py's returns, critic advantages and summaries, on made-up replays."""
    import choice_test as C
    from mob_net import MobCritic, MobPolicy
    check(abs(C.discounted([1.0, 0.0, 2.0], 0.5) - 1.5) < 1e-12, "the discounted return weighs later rewards down")
    values = np.array([1.0, 2.0, 0.5])
    whole = C.critic_advantage([1.0, 0.0, 2.0], values, 0.5, 1.0)
    check(abs(whole - (C.discounted([1.0, 0.0, 2.0], 0.5) - 1.0)) < 1e-12, "with lambda 1 and the whole life kept, the advantage is return minus value")
    cut = C.critic_advantage([1.0, 0.0, 2.0, 5.0], values, 0.5, 1.0)
    check(abs(cut - (1.0 + 0.5 * 0.0 + 0.25 * 0.5 - 1.0)) < 1e-12, "a life longer than the kept decisions is bootstrapped by the critic")
    options, continuations, rows = [1, 2, 5], 4, 3
    lives = [rows] * (len(options) * continuations)
    shard = folder / "choice" / "moment.shard"
    shard.parent.mkdir()
    R.write_shard(shard, schema, synthetic(schema, lives, seed=4), 1)
    rng = np.random.default_rng(2)
    branches = []
    for index, option in enumerate(options):
        for c in range(continuations):
            luck = 0.01 * rng.normal()
            branches.append({"option": option, "continuation": c, "forced": True, "legal": True, "same_state": True,
                             "life": index * continuations + c, "kept": rows, "end": 1,
                             "rewards": [0.0, 0.0, (2.0 if option == 2 else 0.0) + luck],
                             "report": {"squad_after": 1.0 + luck, "outcome": "wipe" if option == 2 else "timeout", "party_damage_after": 10.0}})
    branches.append(dict(branches[0], same_state=False, life=-1))
    moment = {"fight_seed": 9, "moment": {"tick": 5, "slot": 1, "options": options, "seconds": 3.0},
              "scout": {"mode": "engaged", "mobs": 6}, "branches": branches}
    torch.manual_seed(1)
    behaviour = next((o, s) for n, o, s in __import__("evaluate").head_slices(schema) if n == "behaviour")
    result = C.analyse_moment(moment, shard, MobPolicy(schema), MobCritic(schema), schema, 0.999, 0.98, behaviour)
    check(result["bad_replays"] == 1 and sorted(result["options"]) == ["1", "2", "5"] and
          all(len(o["returns"]) == continuations for o in result["options"].values()),
          "a moment's analysis keeps only replays that reached the scouted state")
    names = [f"b{i}" for i in range(16)]
    summary = C.summarise([result, {"skipped": "none"}], names)
    check(summary["used"] == 1 and summary["skipped"] == 1 and summary["choice_share"] > 0.99,
          f"a choice that decides the return has a choice share near 1 ({summary['choice_share']:.3f})")
    check(summary["behaviours"]["b2"]["best_share"] == 1.0 and summary["behaviours"]["b2"]["true_edge"] > 1.0 and summary["wipe_spread"] == 1.0,
          "the per-behaviour table finds the option that pays")
    text = C.report(summary, "v1", type("Args", (), {"continuations": continuations}))
    check("Does the critic know?" in text and "| b2 |" in text, "the choice report has every section")


def test_commit_conversion(folder: Path) -> None:
    """Converting a checkpoint from 16 symbols and no commit head keeps every kept choice and starts the commit head
    leaning toward the usual hold."""
    import json
    import convert_checkpoint as C
    from mob_net import MobCritic, MobPolicy
    from mob_schema import CONTRACT_PATH, SCHEMA_PATH
    contract = json.loads(CONTRACT_PATH.read_text(encoding="utf-8"))
    schema_data = json.loads(SCHEMA_PATH.read_text(encoding="utf-8"))
    contract.pop("commitments_ms")
    for entry in contract["behaviours"]:
        entry.pop("commit", None)
    contract["slots"]["message_symbols"] = 16
    for block in schema_data["observation"]:
        for item in block["fields"]:
            if item["name"] == "message":
                item["size"] = 32
    old_files = (folder / "schema_old_commit.json", folder / "contract_old_commit.json")
    old_files[0].write_text(json.dumps(schema_data), encoding="utf-8")
    old_files[1].write_text(json.dumps(contract), encoding="utf-8")
    old, new = MobSchema(*old_files), MobSchema()
    check(old.head_sizes["commit"] == 0 and new.head_sizes["commit"] == 8, "an old contract has no commit head; the new one has 8 lengths")
    torch.manual_seed(9)
    state = {"policy": MobPolicy(old).state_dict(), "critic": MobCritic(old).state_dict()}
    weights, proof = C.convert(state, old, C.contract_names(old, old_files[1]), new, C.contract_names(new))
    check(proof["largest_logit_difference"] < 1e-4 and proof["largest_memory_difference"] < 1e-4,
          f"dropping symbols 8-15 keeps every kept choice when mates never send them ({proof['largest_logit_difference']:.1e})")
    usual = C.lean_commit(weights, new)
    policy = MobPolicy(new)
    policy.load_state_dict(weights["policy"])
    with torch.no_grad():
        logits, _hidden = policy(torch.randn(32, new.observation_size), torch.zeros(32, new.network["recurrent_hidden"]))
    commit = torch.softmax(policy.split_logits(logits)["commit"], 1)
    check(abs(usual - C.COMMIT_USUAL_SHARE) < 1e-6 and torch.allclose(commit[:, 0], torch.full((32,), usual), atol=1e-5)
          and torch.allclose(commit[:, 1:], commit[:, 1:2].expand(-1, 7), atol=1e-6),
          f"the new commit head starts at the usual hold {100 * usual:.0f}% of the time, the set lengths equally")


def test_message_warm_start(folder: Path) -> None:
    """Turning messages on keeps the network's choices and makes it ignore mates' symbols until it learns them."""
    import json
    import convert_checkpoint as C
    from mob_net import MobCritic, MobPolicy
    from mob_schema import CONTRACT_PATH, SCHEMA_PATH
    contract = json.loads(CONTRACT_PATH.read_text(encoding="utf-8"))
    paths = {}
    for enabled in (False, True):
        contract["rules"]["messages_enabled"] = enabled
        paths[enabled] = folder / f"contract_messages_{int(enabled)}.json"
        paths[enabled].write_text(json.dumps(contract), encoding="utf-8")
    quiet, talking = MobSchema(SCHEMA_PATH, paths[False]), MobSchema(SCHEMA_PATH, paths[True])
    check(not C.messages_enabled(paths[False]) and C.messages_enabled(paths[True]), "the converter reads whether messages are on")
    torch.manual_seed(5)
    state = {"policy": MobPolicy(quiet).state_dict(), "critic": MobCritic(quiet).state_dict()}
    names = C.contract_names(quiet, paths[False])
    weights, proof = C.convert(state, quiet, names, talking, C.contract_names(talking, paths[True]))
    check(proof["largest_logit_difference"] < 1e-5, "turning messages on converts every weight unchanged")
    check(C.message_proof(weights, talking)["logit_difference"] > 1e-3, "before the warm start, mates' symbols change the choices")
    before = MobPolicy(talking)
    before.load_state_dict(weights["policy"])
    C.open_messages(weights, talking)
    heard = C.message_proof(weights, talking)
    check(max(heard.values()) < 1e-5, f"after the warm start, symbols change nothing and start equally likely ({max(heard.values()):.1e})")
    after = MobPolicy(talking)
    after.load_state_dict(weights["policy"])
    obs = torch.clamp(torch.randn(64, talking.observation_size), -talking.clip, talking.clip)
    for start in C.message_groups(talking, "ally", True) + C.message_groups(talking, "leader", True):
        obs[:, start:start + talking.head_sizes["message_a"]] = 0.0
        obs[:, start] = 1.0
    hidden = torch.zeros(64, talking.network["recurrent_hidden"])
    with torch.no_grad():
        old_heads, new_heads = before.split_logits(before(obs, hidden)[0]), after.split_logits(after(obs, hidden)[0])
    same = all(torch.allclose(old_heads[h], new_heads[h]) for h in old_heads if not h.startswith("message")) and         all(torch.allclose(old_heads[h][:, 0], new_heads[h][:, 0]) for h in ("message_a", "message_b"))
    check(same, "the warm start keeps every choice the network made with messages off")
    test_message_growth(folder)


def test_message_growth(folder: Path) -> None:
    """Going from 4 to 16 symbols keeps every learned symbol on both channels; the new ones start as symbol 0."""
    import json
    import convert_checkpoint as C
    from mob_net import MobCritic, MobPolicy
    from mob_schema import CONTRACT_PATH, SCHEMA_PATH
    contract = json.loads(CONTRACT_PATH.read_text(encoding="utf-8"))
    schema_data = json.loads(SCHEMA_PATH.read_text(encoding="utf-8"))
    contract["rules"]["messages_enabled"] = True
    files = {}
    for symbols in (4, 16):
        contract["slots"]["message_symbols"] = symbols
        for block in schema_data["observation"]:
            for item in block["fields"]:
                if item["name"] == "message":
                    item["size"] = 2 * symbols
        files[symbols] = (folder / f"schema_{symbols}.json", folder / f"contract_{symbols}.json")
        files[symbols][0].write_text(json.dumps(schema_data), encoding="utf-8")
        files[symbols][1].write_text(json.dumps(contract), encoding="utf-8")
    small, large = MobSchema(*files[4]), MobSchema(*files[16])
    torch.manual_seed(6)
    state = {"policy": MobPolicy(small).state_dict(), "critic": MobCritic(small).state_dict()}
    weights, proof = C.convert(state, small, C.contract_names(small, files[4][1]), large, C.contract_names(large, files[16][1]))
    check(proof["largest_logit_difference"] < 1e-5, "growing to 16 symbols keeps every old choice")
    old_start, new_start = C.message_groups(small, "ally", False), C.message_groups(large, "ally", False)
    old_w, new_w = state["policy"]["ally_encoder.weight"], weights["policy"]["ally_encoder.weight"]
    kept = all(torch.equal(old_w[:, old_start[channel] + symbol], new_w[:, new_start[channel] + symbol]) for channel in (0, 1) for symbol in range(4))
    check(kept, "each channel's learned symbols keep their own weights when symbols are added")
    C.open_messages(weights, large, 4)
    heard = C.message_proof(weights, large, 4)
    check(max(heard.values()) < 1e-5, f"new symbols mean what symbol 0 means and start as likely ({max(heard.values()):.1e})")
    learned = torch.equal(new_w[:, new_start[0] + 1], old_w[:, old_start[0] + 1])
    check(learned, "the warm start leaves the learned symbols 1-3 alone")


def test_dashboard_eras() -> None:
    """The dashboard never averages across a listed change, and its focus view starts shortly before the newest."""
    import dashboard as D
    at = D.change_versions()[-1]
    rows = [{"time": "2026-01-01 00:00:00", "_t": float(i), "samples": i * 100, "version": at - 3001 + i * 3, "_gap": 1.0, "_new": 100}
            for i in range(2000)]
    for row in rows:
        row["damage_to_party"] = 1.0 if row["version"] >= at else 0.0
    old_max = D.MAX_POINTS
    D.MAX_POINTS = 100
    try:
        points = D.bucketed(rows)
    finally:
        D.MAX_POINTS = old_max
    means = {p["damage_to_party"] for p in points}
    check(means == {0.0, 1.0}, f"no dashboard point mixes updates from both sides of a change ({sorted(means)[:4]})")
    focus = D.since_change(rows)
    after = sum(1 for r in rows if r["version"] >= at)
    check(focus[0]["version"] < at and len(focus) == after + after // 4, "the focus view keeps a quarter as much context before the change")


def test_fold_constant_input(schema: MobSchema) -> None:
    """Folding an input the policy only ever saw at 1 leaves every logit and value unchanged when it then reads 0."""
    import fold_constant_input as F
    from mob_net import MobCritic, MobPolicy
    torch.manual_seed(3)
    policy, critic = MobPolicy(schema), MobCritic(schema)
    optimizer = torch.optim.Adam(list(policy.parameters()) + list(critic.parameters()), lr=1e-3)
    obs = torch.rand(8, schema.observation_size)
    loss = policy(obs, torch.zeros(8, schema.network["recurrent_hidden"]))[0].sum() + critic(obs, torch.rand(8, schema.global_size)).sum()
    loss.backward()
    optimizer.step()
    state = {"policy": policy.state_dict(), "critic": critic.state_dict(), "optimizer": optimizer.state_dict()}
    folded = F.fold(state, schema, "leader", "is_elite", 1.0)
    difference = F.largest_difference(state, folded, schema, "leader", "is_elite", 1.0)
    column = next(b for b in schema.blocks if b.name == "leader").fields["is_elite"][0]
    check(difference < 1e-5, f"folding the leader's is_elite input keeps every answer ({difference:.1e})")
    check(float(folded["policy"]["leader_encoder.weight"][:, column].abs().max()) == 0.0, "the folded input starts from zero weight")
    names = [n for n, _ in policy.named_parameters()]
    moment = folded["optimizer"]["state"][names.index("leader_encoder.weight")]["exp_avg"]
    check(float(moment[:, column].abs().max()) == 0.0 and float(moment.abs().max()) > 0.0, "only the folded weights' Adam moments are cleared")


def test_revive_trunk(schema: MobSchema) -> None:
    """Reviving a dead trunk keeps every answer, makes the trunk fire again, resets Adam for what it touched (step
    included), and lets gradient reach the trunk's outgoing weights at once."""
    import revive_trunk as V
    from mob_net import MobCritic, MobPolicy
    torch.manual_seed(5)
    policy, critic = MobPolicy(schema), MobCritic(schema)
    with torch.no_grad():
        policy.trunk_b.bias.fill_(-1000.0)
    optimizer = torch.optim.Adam(list(policy.parameters()) + list(critic.parameters()), lr=1e-3)
    obs = torch.randn(64, schema.observation_size)
    hidden = torch.zeros(64, schema.network["recurrent_hidden"])
    (policy(obs, hidden)[0].sum() + critic(obs, torch.rand(64, schema.global_size)).sum()).backward()
    optimizer.step()
    state = {"policy": policy.state_dict(), "critic": critic.state_dict(), "optimizer": optimizer.state_dict()}
    check(V.alive_share(state, schema, obs)[1] == 0.0, "the fixture's trunk is dead")
    revived = V.revive(state, schema, 1)
    difference = V.largest_difference(state, revived, schema)
    check(difference < 1e-5, f"reviving the trunk keeps every answer ({difference:.1e})")
    check(V.alive_share(revived, schema, obs)[1] > 0.5, "the revived trunk fires")
    names = [n for n, _ in policy.named_parameters()]
    entries = revived["optimizer"]["state"]
    trunk = entries[names.index("trunk_b.weight")]
    memory = entries[names.index("recurrent.weight_hh")]
    check(float(trunk["step"]) == 0.0 and float(trunk["exp_avg_sq"].abs().max()) == 0.0 and float(memory["step"]) > 0.0,
          "Adam restarts, step included, only for the revived weights")
    check(all(torch.equal(revived["critic"][k], state["critic"][k]) for k in state["critic"]), "reviving leaves the critic alone")
    fresh = MobPolicy(schema)
    fresh.load_state_dict(revived["policy"])
    fresh(obs, hidden)[0][:, :schema.head_sizes["behaviour"]].sum().backward()
    trunk_columns = fresh.heads.weight.grad[:, :schema.network["trunk_hidden"]]
    check(float(trunk_columns.abs().max()) > 0.0, "the revived trunk's outgoing weights get gradient on the first update")


def test_message_heads_detached(schema: MobSchema) -> None:
    """Message logits keep the values the game computes, but train only the heads, never the shared layers."""
    from mob_net import MobPolicy
    from mob_schema import HEAD_NAMES
    torch.manual_seed(6)
    policy = MobPolicy(schema)
    obs = torch.randn(32, schema.observation_size)
    hidden = torch.randn(32, schema.network["recurrent_hidden"]) * 0.3
    with torch.no_grad():
        plain, _ = policy(obs, hidden)
    logits, _ = policy(obs, hidden)
    check(torch.allclose(plain, logits, atol=1e-6), "message logits have the same values with and without gradient")
    offset = sum(schema.head_sizes[n] for n in HEAD_NAMES[:HEAD_NAMES.index("message_a")])
    width = schema.head_sizes["message_a"] + schema.head_sizes["message_b"]
    logits[:, offset:offset + width].sum().backward()
    check(policy.trunk_b.weight.grad is None or float(policy.trunk_b.weight.grad.abs().max()) == 0.0,
          "message choices send no gradient into the trunk")
    check(float(policy.heads.weight.grad[offset:offset + width].abs().max()) > 0.0, "message choices still train their own heads")
    policy.zero_grad()
    policy(obs, hidden)[0][:, :schema.head_sizes["behaviour"]].sum().backward()
    check(float(policy.trunk_b.weight.grad.abs().max()) > 0.0, "fighting choices still train the trunk")
    configured = T.load_settings()["trainer"]
    check(float(configured["max_learning_rate"]) <= 0.0003 + 1e-12, "the learning rate is capped at 0.0003, where the trunk stayed alive")


def test_benchmark_fight_mix() -> None:
    """The benchmark plays its own frozen fights: every setting training's episodes need, and no training curriculum."""
    import benchmark as B
    frozen = json.loads(B.FIGHT_MIX.read_text(encoding="utf-8"))["episodes"]
    training = T.load_settings()["episodes"]
    missing = sorted(set(training) - set(frozen) - {"mob_ratio_mix"})
    check(not missing and "mob_ratio_mix" not in frozen, f"the benchmark's frozen fight mix has every episode setting ({missing})")


def main() -> int:
    schema = MobSchema()
    with tempfile.TemporaryDirectory() as temporary:
        folder = Path(temporary)
        test_shards(schema, folder)
        test_advantages()
        test_masked_terms(schema)
        test_trainer(schema, folder)
        test_replace_waits_for_open_file(folder)
        test_evaluation(schema, folder)
        test_choice_test(schema, folder)
        test_commit_conversion(folder)
        test_message_warm_start(folder)
        test_dashboard_eras()
        test_fold_constant_input(schema)
        test_revive_trunk(schema)
        test_message_heads_detached(schema)
        test_benchmark_fight_mix()
    print("PASSED" if not failures else f"FAILED: {len(failures)} check(s)")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
