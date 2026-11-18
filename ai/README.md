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
| `training/mob_net.py` | PyTorch policy, training-only critic and weight export |
| `training/rewards.json` | Reward weights, with the night rewards removed |
| `tests/run_checks.ps1` | Runs the Python, Godot and cross-language checks |
| `tests/mob_ai_bench.gd` | Measures decision cost in the synthetic encounter |

The native code is in `mob_sim/native`: `mob_policy.c` runs the model and `mob_obs.c` builds observations.

## Run the checks

The checks use the private Python environment in `Documents\Godot\toolchain\mob-ai-venv`.

```powershell
./ai/tests/run_checks.ps1
```

## Not built yet

- The training loop, reward calculation and the bridge between Godot and Python.
- Intelligence handicaps other than sampling temperature, and the party profile.
