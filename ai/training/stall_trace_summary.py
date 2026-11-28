"""Summarises ai/stall_trace.gd traces: what mobs and players do once a fight that times out has gone quiet.

    python stall_trace_summary.py <traces.jsonl> [<traces.jsonl> ...] [--mode engaged|explore|all] [--json <out>]

A mob "seeks without a route" when its movement command follows a route field that has no route from where it
stands (the trace's route cost is -1): it pushes straight at its goal and usually stays put.

The quiet stretch of a fight starts at the last sample where either side lost health (or at the start when
nobody ever did) and runs to the time limit. Only the stretch after QUIET_SETTLE_S seconds of quiet counts, so
the end of the last exchange is left out. Reading only.
"""

from __future__ import annotations

import argparse
import json
import math
import statistics
from collections import Counter, defaultdict
from pathlib import Path

QUIET_SETTLE_S = 5.0
# Mob row fields, as ai/stall_trace.gd writes them.
SLOT, SPECIES, X, Z, BEHAVIOUR, TARGET, KNOWS, SEES, AGE, ERROR, TO_MEMORY, NEAREST, HP, ENGAGED, LIGHT = range(15)
COMMAND, SPEED, WINDUP, STUNNED, ROOTED, ROUTE = range(15, 21)
SEEK = 1
# Player row fields.
PX, PZ, PMODE, PHP, PTARGET, PSEES, PLIGHT, PMOVED = range(8)


def quantiles(values: list[float]) -> dict:
    if not values:
        return {"n": 0}
    values = sorted(values)
    pick = lambda q: values[min(len(values) - 1, int(q * len(values)))]
    return {"n": len(values), "p25": round(pick(0.25), 2), "median": round(pick(0.5), 2), "p75": round(pick(0.75), 2),
            "mean": round(statistics.fmean(values), 2)}


def shares(counter: Counter) -> dict:
    total = sum(counter.values())
    return {key: round(value / total, 3) for key, value in counter.most_common()} if total else {}


def load(paths: list[str]) -> tuple[dict, list[dict]]:
    legend: dict = {}
    fights: list[dict] = []
    for path in paths:
        for line in Path(path).read_text(encoding="utf-8").splitlines():
            if not line.strip():
                continue
            row = json.loads(line)
            if "legend" in row:
                legend = row["legend"]
            else:
                fights.append(row)
    return legend, fights


def quiet_start(trace: list[dict]) -> float:
    start = 0.0
    for before, after in zip(trace, trace[1:]):
        if after["taken"] > before["taken"] or after["dealt"] > before["dealt"]:
            start = after["t"]
    return start


def summarise(legend: dict, fights: list[dict]) -> dict:
    behaviours = legend["behaviours"]
    species = legend["species"]
    every = float(legend.get("every_s", 1.0))
    mob_behaviour: Counter = Counter()
    mob_species: Counter = Counter()
    player_mode: Counter = Counter()
    counts = Counter()
    error, to_memory, nearest, speed, age, light_mob, light_player, player_speed = ([] for _ in range(8))
    gap_change, quiet_from = [], []
    stalls: Counter = Counter()
    # Per behaviour: how far mobs in it are from players, and how fast they move.
    by_behaviour = defaultdict(lambda: {"nearest": [], "speed": [], "knows": 0, "sees": 0, "n": 0, "arrived": 0, "no_route": 0})
    for fight in fights:
        trace = fight["trace"]
        start = quiet_start(trace)
        quiet_from.append(start)
        settled = [sample for sample in trace if sample["t"] >= start + QUIET_SETTLE_S]
        if len(settled) < 2:
            stalls["too_short"] += 1
            continue
        last_at: dict[int, tuple[float, float]] = {}
        fight_mob = Counter()
        gaps = []
        for sample in settled:
            gap = min((mob[NEAREST] for mob in sample["mobs"] if mob[NEAREST] >= 0), default=None)
            if gap is not None:
                gaps.append(gap)
            for mob in sample["mobs"]:
                slot = mob[SLOT]
                name = behaviours[mob[BEHAVIOUR]] if mob[BEHAVIOUR] < len(behaviours) else str(mob[BEHAVIOUR])
                mob_behaviour[name] += 1
                mob_species[species[mob[SPECIES]]] += 1
                counts["mob_samples"] += 1
                counts["knows"] += mob[KNOWS]
                counts["sees"] += mob[SEES]
                counts["engaged"] += mob[ENGAGED]
                stuck = len(mob) > ROUTE and mob[COMMAND] == SEEK and mob[ROUTE] == -1.0
                counts["seeking"] += int(len(mob) > ROUTE and mob[COMMAND] == SEEK)
                counts["no_route"] += int(stuck)
                fight_mob["no_route"] += int(stuck)
                entry = by_behaviour[name]
                entry["n"] += 1
                entry["knows"] += mob[KNOWS]
                entry["sees"] += mob[SEES]
                entry["no_route"] += int(stuck)
                if mob[NEAREST] >= 0:
                    nearest.append(mob[NEAREST])
                    entry["nearest"].append(mob[NEAREST])
                if mob[ERROR] >= 0:
                    error.append(mob[ERROR])
                if mob[TO_MEMORY] >= 0:
                    to_memory.append(mob[TO_MEMORY])
                    if mob[TO_MEMORY] <= 2.0:
                        entry["arrived"] += 1
                if mob[AGE] >= 0:
                    age.append(mob[AGE])
                light_mob.append(mob[LIGHT])
                if slot in last_at:
                    moved = math.dist(last_at[slot], (mob[X], mob[Z])) / every
                    speed.append(moved)
                    entry["speed"].append(moved)
                    fight_mob["moving" if moved > 0.5 else "still"] += 1
                last_at[slot] = (mob[X], mob[Z])
                fight_mob["knows"] += mob[KNOWS]
                fight_mob["sees"] += mob[SEES]
                fight_mob["n"] += 1
            for player in sample["players"]:
                player_mode[player[PMODE]] += 1
                if player[PMODE] == "down":
                    continue
                counts["player_samples"] += 1
                counts["player_sees"] += player[PSEES]
                light_player.append(player[PLIGHT])
                player_speed.append(player[PMOVED] / every)
        if len(gaps) >= 2:
            gap_change.append(gaps[-1] - gaps[0])
        if fight_mob["n"]:
            still = fight_mob["still"] / max(1, fight_mob["still"] + fight_mob["moving"])
            knows = fight_mob["knows"] / fight_mob["n"]
            sees = fight_mob["sees"] / fight_mob["n"]
            if fight_mob["no_route"] / fight_mob["n"] >= 0.5:
                stalls["mobs_seek_without_a_route"] += 1
            elif sees >= 0.5:
                stalls["mobs_see_the_party"] += 1
            elif knows < 0.5:
                stalls["mobs_lost_the_party"] += 1
            elif still >= 0.6:
                stalls["mobs_know_but_stand_still"] += 1
            else:
                stalls["mobs_know_and_move_but_never_see"] += 1
    mob_samples = max(1, counts["mob_samples"])
    player_samples = max(1, counts["player_samples"])
    per_behaviour = {}
    for name, entry in sorted(by_behaviour.items(), key=lambda item: -item[1]["n"]):
        if entry["n"] < 0.01 * mob_samples:
            continue
        per_behaviour[name] = {"share": round(entry["n"] / mob_samples, 3), "knows": round(entry["knows"] / entry["n"], 2),
                               "sees": round(entry["sees"] / entry["n"], 2), "no_route": round(entry["no_route"] / entry["n"], 2), "at_memory": round(entry["arrived"] / entry["n"], 2),
                               "nearest_median": quantiles(entry["nearest"]).get("median"),
                               "speed_median": quantiles(entry["speed"]).get("median")}
    return {
        "fights": len(fights),
        "quiet_from_s": quantiles(quiet_from),
        "stall_kinds": dict(stalls.most_common()),
        "mobs": {
            "knows_target": round(counts["knows"] / mob_samples, 3),
            "sees_a_player": round(counts["sees"] / mob_samples, 3),
            "engaged": round(counts["engaged"] / mob_samples, 3),
            "seeking_without_a_route": round(counts["no_route"] / mob_samples, 3),
            "seeking": round(counts["seeking"] / mob_samples, 3),
            "memory_error_m": quantiles(error),
            "to_memory_m": quantiles(to_memory),
            "memory_age_s": quantiles(age),
            "nearest_player_m": quantiles(nearest),
            "speed_mps": quantiles(speed),
            "light": quantiles(light_mob),
            "behaviours": per_behaviour,
            "species": shares(mob_species),
        },
        "players": {
            "modes": shares(player_mode),
            "sees_a_mob": round(counts["player_sees"] / player_samples, 3),
            "speed_mps": quantiles(player_speed),
            "light": quantiles(light_player),
        },
        "gap_change_m": quantiles(gap_change),
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("traces", nargs="+")
    parser.add_argument("--mode", default="engaged", choices=["engaged", "explore", "all"])
    parser.add_argument("--json", default="")
    args = parser.parse_args()
    legend, fights = load(args.traces)
    fights = [fight for fight in fights if fight.get("outcome") == "timeout" and (args.mode == "all" or fight.get("mode") == args.mode)]
    result = summarise(legend, fights)
    text = json.dumps(result, indent=1)
    if args.json:
        Path(args.json).write_text(text, encoding="utf-8")
    print(text)


if __name__ == "__main__":
    main()
