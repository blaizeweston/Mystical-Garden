# Supplemental Architecture Audit Summary

The audit used in-memory GDScript edits to recalculate suite fingerprints and inspected retained co-op logs. The probes measured cache reuse. Gameplay and validation suites were left unrun.

## Confirmed cache gaps

| Function in `game.gd` | In-memory edit | Why the cache key stayed valid | Direct callers eligible for reuse |
|---|---|---|---|
| `graft_altar_open` | Replace `encounter_number % GRAFT_ROOM == 0` with `encounter_number % 9 == 0`. | The body belongs only to `seeds`, which the affected suites omit. | `grafting_menu`, `menu_coop`, `shrines_hits` |
| `use_checkpoint` | Insert `if descend: return` before the mapped fragment. | Only the `expeditions` body and `garden_returns` fragment fingerprints change. The affected suites declare neither system. | `core_combat`, `core_combat_coop`, `combat_balance_preview` |
| `strike_enemy` | Change the cooldown guard from `if now<int(p.strike_at): return` to `if now>=int(p.strike_at): return`. | The `combat` body changes. The separately mapped preview roll fragment stays identical. | `combat_balance_preview`, `combat_balance_preview_coop`, `weapon_balance_preview`, `foundations`, `seed_progression` |

The individual gaps come from ownership declarations. The broader limitation is that `resources()` skips `game.gd`, so direct calls from a fixture do not automatically add dispatcher body fingerprints to that suite. The broad `playable_solo` suite invalidated in all three probes. [Dispatcher](../game.gd) · [Registry](../tools/test_map.json) · [Planner](../tools/test_workflow.py)

## Garden growth co-op and peer verdicts

The source and packaged guest logs both recorded `Node not found: "MysticalGarden" (relative to "/root")`, `Failed to get cached node from peer 1 with cache ID 1`, and `Invalid packet received. Requested node was not found.` The guest could not resolve an RPC target. The logs do not identify whether the errors arose during rejoin or final teardown. Fixture assertions still passed, both source processes exited zero, and the verdict filters missed ordinary engine errors. [Fixture](../tests/garden_growth_coop.gd) · [Source guest log](../.godot/validation/runs/20261112-124734-c9cfe486/garden_growth_coop-guest.log) · [Packaged guest errors](../.godot/release/packaged-garden_growth_coop-guest-errors.log)

- **Source pairs** require each process to exit zero and print a pass marker. [Source planner](../tools/test_workflow.py)
- **Packaged pairs and the four-player fixture** require a pass marker per role. Their wrappers wait for each process without inspecting each child’s exit code. [Package runner](../tools/release_latest.ps1) · [Four-player runner](../tools/test_four_players.ps1)
- **Connect-and-play smoke** verifies each peer’s exit code, structured run and role result, and absence of engine errors. The host also evaluates guest reports and acknowledgments. [Smoke launcher](../test/run_net_test.ps1) · [Smoke fixture](../test/net_test.gd)

## Validation and checklist status

`AGENTS.md` directs Codex to review the plan, use Focused during implementation and Connected before ordinary exports, and reserve Full for major releases or explicit requests. Runners enforce evidence when invoked. The planner checks file existence, ownership, some scope anchors, and literal resource references. It has no semantic check that reconciles GDScript calls, scene wiring, signals, or autoload behavior with the authored map. [Project instructions](../AGENTS.md) · [Validation workflow](VALIDATION_WORKFLOW.md)

| Checklist | Evidence status |
|---|---|
| **AC-01 through AC-05** | Demonstrated verdict or selection gaps, engine error symptoms, and map drift. The foundation preview listed 9 suites while the corresponding fingerprint change invalidated 143 keys. The part-icon rule is shadowed and six scoped rules had zero matches. The trigger for the co-op errors remains open. |
| **AC-06** | Confirmed control-flow defect. Transaction code ignores two save return values. Data loss or a partial commit was not reproduced. [Transaction code](../game_transaction.gd) |
| **AC-07 through AC-09** | Code-supported risks involving boss rollback, stale owner details, and same-ID compatibility. The gameplay failures remain unverified. [Battlefield](../battlefield.gd) · [State receiver](../game.gd) · [Compatibility](../network_compatibility.gd) |
| **AC-10 and AC-11** | Verified runtime dependencies. The combined reinforcement regression and diagnostics startup check are proposed coverage. [Reinforcements](../expedition_pressure.gd) · [Diagnostics autoload](../diagnostics_boot.gd) |
| **AC-12** | Demonstrated documentation drift for Thorn Line, scout limits, and Garden returns. [Mechanics map](MECHANICS_TEST_MAP.md) · [Content authoring](CONTENT_AUTHORING.md) · [Garden map](GARDEN_DEVELOPMENT_MAP.md) |

See the [Architecture Correction Checklist](ARCHITECTURE_CORRECTION_CHECKLIST.md) for the acceptance checks.
