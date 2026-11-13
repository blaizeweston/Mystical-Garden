# Foundation correction milestone — 2026-11-08

This is the implementation ledger for the 24 findings in SYSTEMS_REVIEW_2026-11-08.md. Findings were handled in dependency order: identity and recovery, shared component/reward contracts, progression and combat, synchronized presentation, then validation and release. The original review remains historical evidence.

## Corrections and explicit boundaries
| Finding | Result | Evidence / remaining boundary |
| --- | --- | --- |
| R01: fixed-leader rewards | Corrected | Actual eligible killed species drive familiarity and trophy selection. Summoned brood excluded. foundations / enemy_roster. |
| R02: shifting part indices | Corrected | Frozen v1 and v2 orders; stable-ID save manifests migrate seed, part, class, enemy, weapon and node references. Existing IDs retained. foundations. |
| R03: partial saves | Corrected for persistent gameplay actions | Cross-file journal, before-images, transaction rollback, recovery on load, deferred character publication and reward retry. Injected failed harvest and interrupted two-file commit tested. |
| R04: Thorn-only rare yields | Corrected | Every species has a refined harvest component; familiarity benefits continue beyond five harvests. Complete non-Thorn cultivation-to-weapon test. |
| R05: roster caps | Corrected | Catalog-driven class/weapon/node selection, separate enemy ID bits, dynamic scout capacity and visual keys. Explicit remaining budgets: 63 class choices, 9 spatial beds, 12 scouts. |
| R06: stale tests | Corrected | Fixtures use current menus, five-gate checkpoints, contact timing, current XP thresholds and offshoot duration. Standalone and co-op suites rerun. |
| R07: tags/effects contract | Defined and validated | Shared component templates; unsupported effect names, references and assets rejected. A new arbitrary tag still needs authored interaction semantics. CONTENT_AUTHORING.md. |
| R08: combat contact/visual drift | Corrected foundation | Shared geometry, queued melee contact/ranged release, point-blank handling, attack sound feedback. Reliable guest FX events. Projectiles remain explicitly assisted rather than full physical collision. |
| R09: progression/economy | Corrected obvious mismatch; balancing instrumented | Class cap raised to 70 encounters; earned legacy levels preserved; each repeated guardian completion banks a memory. Local timing/reward/rollback metrics. Weeks of human play remain unvalidated. |
| R10: pouch policy | Made explicit | One protected stack, quantity up to 99; wipe protects it, abandonment loses it. Existing requested stack behavior preserved. |
| R11: adaptation expectations | Corrected documentation | Host-persistent authored director, not a neural network. No claim of arbitrary learned counters or player-built trap understanding. Future tactical tools and observation quality remain separate work. |
| R12: shallow offshoot sacrifice | Corrected | Nurture permanently reserves an empty bed, leaves one bed free, matures after three completed expeditions. Dedicated mature Heart finale form. Legacy mature offshoots preserved. |
| R13: competing art generators | Corrected authoring ownership | One authoritative natural-world generator; old generator bodies archived outside project and wrappers delegate. Art guidelines specify Garden/Wilds contrast. Full character/crop art polish remains a future pass. |
| R14: contradictory docs/build target | Corrected | Rewritten current README and systems spec, numeric latest-revision launcher/release helper, build fingerprint. Save directory retained. |
| R15: controller/storage coupling | Reduced at stable boundaries | Extracted content IDs, save batching, gameplay transactions, attack geometry, schedule, balance, validation and metrics. Full controller rewrite deliberately unnecessary for this milestone; further systems must use these services. |
| R16: unmeasured scale | Measured and optimized | Shared authoritative map; cached terrain-distance samples. Five-floor headless sample reduced generation p95 from about 1179 ms to 312 ms; steady CPU about 0.67 ms. GPU and large online battles unmeasured. |
| R17: invalid IDs become Thorn | Corrected | Missing species returns -1; inventory mutation rejects unknown parts; migration quarantines unknown identities. Invalid-ID regression. |
| R18: generic material masquerades as component | Corrected | Extra equippable plant components use shared component registry. Generic plant_part entries without component linkage rejected. Inventory, altar, weapon and upgrades share identity. |
| R19: silent research spending | Corrected | Common-first default with exact preview, optional selected species, server checks submitted plan and never silently substitutes. Heart progression tests. |
| R20: apparent backpack capacity | Made explicit | Scrollable unlimited ordinary stacks; square grid is presentation. Capacity may be added centrally later, never inferred from visible squares. |
| R21: co-op/transfer overclaim | Corrected documentation and local synchronization | Same-PC two-instance scope retained. Content handshake, public/private state channels and deferred profile updates tested. LAN/internet trust, reconnect recovery and portable seed slots are future work. |
| R22: accidental schedule coupling | Corrected | Independent checkpoint 5 / biome 6 / graft 8 configuration; network fields reference shared named offsets. |
| R23: dead biome floor tint | Corrected | Active soil shader receives biome tint and corruption/depth; old unused floor color no longer defines the visible Wilds material. natural_world tests. |
| R24: historical resources in EXE | Corrected release boundary | Import-ignore markers and export exclusions for docs/tests/tools/Blender sources and archives. Staged package smoke verifies runtime assets and forbidden resources before replacing the current EXE. |

## Verification
Source checks cover inventory/pouch loss and drops, save deletion, Heart research/costs, seed lineage/portraits, planting/identification, class choices/skills, weighted cards, graft replacement, combat contact/telegraphs/deaths, support spawn rules, paths, exploration, gates, checkpoint extraction and run abandonment. foundations.gd adds acquisition-to-use tests, stable-ID reordering, invalid IDs, legacy level preservation, failed transaction rollback and interrupted multi-file recovery. playable.gd solo covers the wider integration using explicit long-campaign fixtures. Local co-op checks exercise class equipment, monster grafts, two skills, seeds, menus and selected character transfer.

The performance numbers are local headless CPU samples, not frame-rate claims. Floor generation is still synchronous and may cause a visible transition pause. The 70-XP curve and Heart memory requirements need human play data; this milestone does not claim weeks of balanced content. Automated fixtures that complete late-game restoration are not evidence of natural completion time.

## Working rules from here
Add permanent IDs first, validate the catalog, connect all mechanical uses, then add one acquisition-to-use test. Keep costs and awards inside the transaction boundary. Do not put backpack payloads into the movement channel or revive retired shortcuts. Record new art ownership before generating shared assets. Run tools/validate_release.ps1, then tools/release_latest.ps1; release only the highest numeric EXE and preserve its backup. Source and packaged-runtime logs live in .godot/stabilization and .godot/release.

## Installed build evidence
34 release suites passed (29 focused source suites, solo integration, four host/guest pairs). The installed v0.3 runtime pack also passed the foundation acquisition/migration/recovery test and a dynamic-resource/world/exclusion smoke check. The actual v0.3 executable started and exited successfully in an isolated headless check. Its prior binary is preserved under .godot/release/backup-20261108-144538-Mystical Garden v0.3.exe. Earlier numbered revisions were not updated. Runtime fingerprint checks prevent releasing changed sources against an old validation result.
