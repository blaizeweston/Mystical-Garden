# Mob neural net

The initial neural net for mob decisions. It targets the architecture in [`mob_sim`](../mob_sim/MIGRATION.md). Nothing in the game loads this folder yet, and the `.gdignore` file keeps it out of the editor scan and exported builds.

## Layout

| Path | Purpose |
|---|---|
| `schema.json` | Every observation field, its scale, masked fields and network sizes |
| `mob_schema.gd`, `training/mob_schema.py` | Read the schema in Godot and Python |
| `mob_native_runtime.gd` | Connects the schema and simulation to the native observation builder and policy runner |
| `mob_neural_brain.gd` | Chooses intents through the shared mob brain interface |
| `mob_observation_builder.gd`, `mob_policy_reference.gd` | GDScript reference versions, used to prove the native code matches |
| `mob_history.gd` | Rolling damage records used by observations |
| `mob_rewards.gd` | Rewards v2: turns encounter events into per-mob training rewards |
| `stand_in_party.gd` | The scripted party mobs train against: classes, stats, tactics, difficulty and patrols |
| `training_brain.gd`, `rollout_recorder.gd` | Training-time sampling and recording; checksummed rollout shards |
| `training_env.gd`, `training_worker.gd` | Training episodes (engaged and explore starts) and the worker loop |
| `training/train.py`, `training/rollouts.py`, `training/safe_files.py` | Recurrent PPO trainer, shard reading, crash-safe files and checkpoints |
| `training/training.json` | Worker count, episode mix and trainer settings |
| `training/dashboard.py`, `dashboard.html` | Live training dashboard in the browser (`Training Dashboard.cmd`) |
| `training/convert_checkpoint.py` | Carries a run's checkpoint over to a changed schema |
| `training/export_view.py` | Writes the newest checkpoint for a model viewer such as Netron |
| `training/start_training.ps1`, `stop_training.ps1`, `training_status.ps1` | Start, stop and check on training (double-click the `.cmd` files beside them) |
| `training/mob_net.py` | PyTorch policy, training-only critic and weight export |
| `training/rewards.json` | Reward weights (rewards v2) |
| `tests/run_checks.ps1` | Runs the Python, Godot and cross-language checks |
| `tests/mob_ai_bench.gd` | Measures decision cost in the synthetic encounter |

The native code is in `mob_sim/native`: `mob_policy.c` runs the model and `mob_obs.c` builds observations.

## Run the checks

The checks use the private Python environment in `Documents\Godot\toolchain\mob-ai-venv`.

```powershell
./ai/tests/run_checks.ps1
```

## Train

Training runs in the background and resumes where it left off. Double-click `training/Start Training.cmd`, `Stop Training.cmd` or `Training Status.cmd`, or run the scripts:

```powershell
./ai/training/start_training.ps1
./ai/training/training_status.ps1
./ai/training/stop_training.ps1
```

Watch it with `training/Training Dashboard.cmd`, or from another computer on the same network with `Training Dashboard (LAN).cmd` (Windows asks once whether to let Python through its firewall). Progress lives in `Documents\Godot\mob-training\run` (change `run_dir` in `training/training.json`). Stopping saves a checkpoint; a crash or power loss loses at most the last 10 minutes. `ai/tests/run_training_smoke.ps1` checks the controls in a throwaway folder.

To train on another computer: clone the repository at the same commit, copy `mob_sim/bin/mob_nav.dll` (not in git) and the run folder, install Python with `training/requirements.txt`, and put that computer's own `godot`, `python` and `workers` in `training/training.local.json` (not committed; it overrides `training.json`). Then run `training/check_setup.ps1`, which checks everything, plays two episodes as a test and says what is missing. Run training on only one computer at a time, and copy the run folder back when you move it.

## Not built yet

- Curriculum stages, self-play against a learned player net and past checkpoints, and evaluation against the scripted brain (Phase 6, part E).
- Intelligence handicaps other than sampling temperature, player resistances, and the spare party profile and player effect inputs (still masked). The party's classes, and each player's speed change, guard and bark armour, are live: the training party publishes them, and the game will once it has a host bridge.
