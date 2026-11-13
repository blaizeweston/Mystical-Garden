# Mystical Garden — systems and iteration review

**Review date:** 8 November 2026  
**Scope:** current editable project, design brief, implementation notes, content definitions, persistence and automated checks. Current playable file is `Mystical Garden v0.3.exe`. No gameplay source, existing tests or EXE was changed for this review. Tests used isolated saves. This is a source and systems review, not a claim that the v0.3 binary has identical contents or that a human-length campaign has been playtested.

## Assessment

The game has a coherent identity and a useful playable foundation. The strongest structure is the relationship between the safe Garden, scarce plant materials, a deliberately assembled expedition weapon, risky grafting and checkpoint decisions. Reusable progression-tree presentation, data-backed upgrade offers, seed lineage, shared/per-character ownership and procedural navigation are worth keeping.

The project is not yet ready for unrestricted content expansion. There are genuine progression bottlenecks and save-identity hazards beneath the expanding presentation. Several systems look deeper in the UI than their actual reward paths support. Further isolated feature additions will amplify those inconsistencies unless the core contracts are consolidated first.

My recommendation is a stabilization milestone followed by a focused depth milestone. Keep the current game's direction; repair the supply chains and data model before making dozens more entries.

### Verified inventory

| System | Current scope | Assessment |
| --- | --- | --- |
| Seeds | 15 species, tiered lineage, identification and crossbreeding | Good foundation; species mastery rewards are incomplete |
| Classes | 5 classes, 3 weapons each, 2 skills and tree choices | Useful breadth; fixed limits and shared execution reduce expansion freedom |
| Enemy roster | 10 definitions, support groups and adaptive variants | Encounter composition works; signature-part acquisition is disconnected |
| Checkpoint upgrades | 69 definitions; weighted 3 cards, 8% chance of a fourth | Strong reusable system; balance and dependency validation need work |
| Heart | 24 nodes, research, facilities, plots and six visual phases | Coherent progression structure with old parallel flags still present |
| Inventory | Carried/stored/shared items, stacks, pouch and ground drops | Functional facade over several different storage representations |
| World | Seeded clearings, cover, navigation, fog/map, gates | Much improved consistency; still uses fixed placement and population assumptions |
| Persistence | Three slots, profile identity, migrations, replacement/deletion backups | Valuable safeguards, but transactions are inconsistent across actions |

## Highest-priority findings

### R01 — Most signature monster parts cannot be earned through the normal loop [P1, confirmed]

**Evidence:** `game.gd:2201` (`reset_encounter`) sets the primary enemy to kind 0 on ordinary floors. `game.gd:1680` (`act`) rolls the optional trophy when collecting the encounter seed drop, using that primary `enemy_kind`. Scout deaths do not contribute their species to this roll. `award_combat_progress` likewise credits only `profile.monsters[enemy_kind]`, even when the other species were defeated. `record_enemy_death` captures the actual slain species for visual effects, not loot selection.

**Reproduction:** a generated encounter had Rootbound Pilgrim as leader and scout kinds `[4,1,4,0]`; its eligible trophy pool was only `["monster_0"]`. With the current empty custom-item catalog, killing Nightblooms, stags or other scouts does not make their signature components eligible for that ordinary encounter's reward. The final Heart has a different leader, but it does not solve the normal expedition supply chain.

**Additional reproduction:** clearing a mixed encounter with a stag and Nightbloom awarded +1 Rootbound familiarity, +0 stag and +0 Nightbloom familiarity. The graft-success progression for those species is therefore disconnected as well.

**Impact:** the fourth weapon slot, monster research and graft-specific checkpoint offers promise variety that the loot loop cannot supply naturally. Catalog tests can pass by directly inserting parts, masking the missing acquisition path.

**Recommendation:** record the actual encounter's kills and build personal loot from those species, or roll personal drops at each eligible death. Keep summon provenance so brood farming cannot produce unlimited rewards. Add an end-to-end test that earns a stag component through play, extracts or pouches it, brings it to an altar, grafts it and receives an eligible upgrade offer.

### R02 — Adding a plant shifts existing monster-part save IDs [P1, confirmed structural defect]

**Evidence:** `weapon_parts.gd:167` builds plant entries first, then appends nine monster components. Today Briar Hook is part 4, while the other monster parts occupy indices 18–26. Inventories, cargo, graft fields and saved arrays use these numeric part indices.

Appending the next plant part before those appended monster entries would move Nightbloom Pollen from 18 to 19 and shift the remaining monster parts. Existing stored component 18 could then be interpreted as a plant. Merely following the seed catalog's “append, do not reorder” instruction is insufficient.

**Impact:** an otherwise routine content update can silently reinterpret existing inventories and equipment. This is the first issue to solve before expanding species.

**Recommendation:** save stable string IDs for plants, parts, monsters, weapons and learned nodes. Resolve them to runtime indices after loading. Freeze and migrate the current numeric table with explicit versioned mappings; do not discard existing saves or reset player progression.

### R03 — Save failure handling is strong in new actions but inconsistent elsewhere [P1, reproduced]

**Evidence:** planting, batch identification, Altar combinations and Heart purchases have rollback paths. In contrast, `game.gd:1740` (`harvest`) clears the bed, grants parts and calls `publish_character` before `save_progress`. `game.gd:2340` reports a Garden save failure without undoing mutations. Departure, extraction, offshoot decisions and protected-item banking also need a consistent transaction policy rather than assuming the generic helper rolls back.

**Reproduction:** forcing a harvest's Garden path to fail left the bed empty, granted a part and saved +1 character familiarity. The Garden and character files no longer described the same operation. A later reload or retry can expose loss, duplication or progression inconsistencies depending on which file succeeded.

**Recommendation:** introduce a small transaction service for inventory/progression operations. Validate first, capture affected state, persist safely, then commit notifications. Where Garden and character files must change together, use a transaction record and recovery procedure. Explicitly test retry/reload behavior, not only an error message.

### R04 — Familiarity is effectively a Thorn Bloom rare-harvest system [P1 for progression depth, confirmed]

**Evidence:** every harvested species gains familiarity, but the rare-material roll in `harvest` is guarded by `kind == Parts.THORN - 1` and awards only Heartwood Barb. `rare_harvest_chance` rises from 5% to 25% over the first five familiarity points, then stops improving. Grafting familiarity also uses only the first five points. Stored familiarity can reach 9999.

**Impact:** the general promise that cultivating any species develops its rare yields is not fulfilled. After a handful of harvests, most familiarity progression has little visible meaning. The rare material is another special case in storage and recipes.

**Recommendation:** give each species a harvest table with guaranteed yield and optional rare products, driven by shared familiarity bands. Not every plant needs more raw power: options can unlock alternative parts, processing methods, reliability or distinctive graft interactions. Show the next meaningful familiarity benefit. Preserve the latest decision that harvesting empties the bed and requires replanting; update the older brief's replenishment wording.

## Further systems findings

### R05 — Content templates still contain restrictive fixed limits [P1 before expansion]

`enemy_catalog.gd:44–48` reserves four bits for enemy kind. A probe encoded kind 16 and decoded it as kind 0 with an unintended mutation; kind 20 became kind 4. This is a real ceiling, not a hypothetical performance issue.

Other limits are more deliberate but scattered: `weapon_motion.gd` clamps class to 0–4 and weapon to 0–2; `run_upgrade_catalog.gd:21` also assumes three weapons; character normalization clamps learned-node masks to 255 and four two-choice rows; the world supports nine plots and eight scout slots. Adding a sixth class, fourth weapon, ninth class node or seventeenth enemy is not consistently data-only.

Make limits explicit content rules or remove them with schema migrations. Add catalog validation that rejects unsupported definitions before a build ships. New abilities or behaviors will reasonably require code, but new variants using supported behaviors should not require scattered edits.

### R06 — The broad test suite contains superseded interactions [P2, verified]

28 standalone non-co-op tests plus the full solo sequence were run: **27 passed and 2 failed**. `campaign_combat.gd` expects E at the Gate to immediately enter the Wilds, while the current design opens preparation. `dual_skills.gd` expects R in the Garden to perform research, a deliberately retired shortcut. Both are stale expectations, not demonstrated production regressions.

The main solo fixture frequently teleports characters, sets enemy HP and supplies resources. It is useful for state transitions, but it does not establish combat balance or campaign pacing. Old `Parts.effect` and Rift-pair tests still exercise the earlier two-slot model separately from the current resolver.

Create one maintained player-input smoke sequence and route subsystem tests through the current station contracts. Keep compatibility tests labeled as such. Do not restore old gameplay merely to make obsolete tests pass. Parse test failure output as well as exit status: this engine can print script errors without a reliable nonzero exit in some script paths.

### R07 — Plants influence builds, but tag semantics and effect boundaries need clearer contracts [P2]

`weapon_system.gd` gives the three plant slots different weights and applies the first matching tag rule in each slot. Tag ordering therefore changes behavior. Pattern overrides can also depend on slot processing order. Fractional values are rounded, and several stats have hard caps; some apparently different recipes can produce the same final result.

There are useful interactions—Steam Bloom, Eclipse Wake, Sanguine Cycle and Storm Needle—but much differentiation is still scalar reach, cooldown, recovery, pull or damage. A tag such as fire does not itself guarantee a burning behavior. Existing data can be extended safely only within these supported effects.

Define an effect vocabulary, units, rounding/cap order and deterministic precedence. Show the resolved result and explain which slot produced it. Add validation for unknown effect keys and unsupported patterns, plus a small matrix of representative combinations. Add new behaviors deliberately rather than letting tag names imply unimplemented effects.

### R08 — Combat logic and visual timing are not yet one model [P2]

Melee damage is applied immediately in `strike_enemy`, while the new motion/trail proceeds over its animation. Ranged attacks queue an impact on arrival, but the projectile is emitted when the attack begins rather than from an authored release/contact event. The current shot is an auto-targeted endpoint event with a movement tolerance, not a fully simulated projectile that can intercept a different creature along its flight.

These are legitimate prototype choices, but they limit perceived weight, precision and weapon identity. A maul, knife and spear need distinct anticipation, contact and recovery, not only distinct poses. The nearest-target auto-aim can also limit battlefield intent.

There is also a measurable shape mismatch: the sweep damage test accepts a half-angle of about 95.7 degrees (`dot > -0.1`), while the scythe arc uses a half-span of about 77.3 degrees. The exact displayed trail changes over time, but it is not derived from the authoritative damage shape.

Use the same attack definition for targeting shape, contact/release time, damage window, movement allowance and effect lifetime. Decide whether projectiles are simulated collisions or explicitly assisted targeting. Add sound, restrained hit-stop and better impact reactions after contact timing is reliable. I found no game audio assets or audio-player implementation in this source scan; that is a major missing contributor to feel.

### R09 — Progression duration and reward economy are not yet validated [P2]

Class level 5 is reached at 20 credited encounters. Natural familiarity benefits saturate quickly. By contrast, Heart memory counts require repeated extracted guardian completions: `[12,16,20]`. The run uses a guardian bitset, so repeatedly clearing the same biome in one endless expedition does not award repeated memories for that biome when extracted.

A character can therefore reach the current class cap on the first 20 credited encounters, while late seed definitions begin appearing only at encounters 51 and 56. This creates a possible mismatch: class and familiarity choices exhaust early while the campaign asks for repeated long journeys. It also weakens the reward for looping deeper in a single run compared with repeatedly extracting. This is a design choice to evaluate, not a measured proof that completion takes a particular number of hours.

Instrument encounter time, survival, extraction depth, resource income, unused materials and time between meaningful unlocks. Build a pacing sheet for the first hour, first five expeditions and the restoration campaign. Keep experienced characters broader rather than simply stronger, as intended.

### R10 — The safe pouch's stack policy substantially changes risk [P2, design decision]

The inventory correctly implements the requested ability to move an entire stack into a one-slot pouch. However, mysterious seeds share a single item ID and can stack up to 99 while retaining different hidden species internally. One protected stack can therefore shelter many discoveries rather than one rare find.

This is not a request to revert the user's stacking decision. It is a balancing consequence that needs an explicit rule: protected stack quantity, item mass, rarity cost or later pouch upgrades. Also document that voluntary abandonment loses pouch contents while a wipe preserves them, and that already-earned class progress may remain even when the abandonment message says “no rewards.”

### R11 — Adaptation is a useful rules-based director, not a neural network [P2, expectation alignment]

The current implementation records ranged, burst and choke pressure in the host's save, decays it over quieter expeditions and applies visible mutation flags. This is aligned with persistent host-world adaptation and is a sensible foundation.

It does not learn arbitrary strategies or invent counters. Pressure thresholds and mutation effects are authored. Existing choke detection also relies on floor-boundary proximity as a proxy rather than understanding player-built traps. No runtime barrier construction/removal was found in the skill execution paths inspected; battlefield manipulation is still primarily movement, cover and crowd control.

Keep the director and improve its observations first: separate repeated success from ordinary class use, record counter effectiveness, cap simultaneous responses and give players readable warning. Add encounter roles and terrain tools before considering a neural model. A neural network is not required to deliver the desired experience, and would not repair missing tactical options.

### R12 — The ending expresses the right theme, but its sacrifice is shallow [P2]

The three offshoot choices are explicit and visible, which is preferable to secretly penalizing ordinary harvesting. At present nurturing transitions an offshoot to GROWING; the next positive expedition milestone matures it. Harvesting instead gives two Heartwood Barbs. No planting-bed occupancy or ongoing care cost is attached.

The brief's meaningful commitment of Garden space/time is therefore only partially implemented. Since two mature offshoots determine the viable-seed ending, choosing nurture twice can settle the ending early in a much longer restoration campaign.

Give each offshoot a visible, understandable commitment and a tempting immediate alternative. Avoid making it a hidden morality meter or treating routine cultivation as cruelty. Revisit the final Heart's dedicated visual/behavior identity as well: the normal Garden growth is distinctive, while the finale's main enemy kind is a scaled roster entry.

### R13 — Theme and visual development are converging, but the art pipeline has multiple generations [P2]

The safe green Garden, faintly unsettling Heart, darker Wilds, illustrated root UI and animated gates communicate the intended contrast. Preserve it.

The character, crop, weapon and enemy kits still contain older primitive silhouettes and generic effects alongside newer natural scenery. Some technology names and messages still sound like implementation labels. The environment source history includes `wilderness.blend`, `rootwood.blend` and `natural_world.blend`; more than one generator writes the same output asset names. Running an older script can silently bring back superseded art.

Create a short art guide for silhouette, palette, surface detail, motion, corruption depth and screen-space readability. Name one authoritative generator/source for each asset. Keep older sources archived and clearly marked; do not delete them without a recovery copy. Treat Garden serenity and combat telegraph contrast as requirements, not just mood references.

### R14 — Documentation and release configuration contradict current play [P2]

The README still advertises old slot shortcuts, direct Gate departure, H affinity, C seed cycling, R research and other retired interactions. The design brief still describes plant replenishment, plant grafting and transferable-seed class traits that do not match the latest empty-and-replant / monster-only fourth-slot implementation. `heart_progress.gd` can still tell players to resolve offshoots with Y/U after those bindings were retired.

The current project contains v0.3, but `export_presets.cfg:14` still targets v0.2. The launcher starts source through a particular engine path rather than selecting the latest packaged EXE. A source launch and an EXE launch can therefore represent different builds.

Publish one current player guide, one current systems specification and a dated change history. Add a build manifest with content/schema version and source fingerprint. Make the release target explicit; never infer it from a stale hardcoded version. Do not rename the Prototype save directory casually: that would require a migration.

### R15 — Storage and controller boundaries will make continued additions expensive [P2]

`game.gd` is roughly 162 KB and handles input, authority, combat, encounters, storage, progression, menus, rewards, save notifications and snapshots. `stage.gd` combines scenery generation, actors, Heart growth, HUD-adjacent labels and effects. The inventory presents a common item API, but internally uses seed arrays, personal/shared part arrays, special Briar/Heartwood counters, custom item dictionaries and pouch-specific seed metadata.

This does not require a large rewrite. Gradually extract services around existing stable behavior: inventory transactions, encounter/reward resolution, weapon/ability resolution, progression and presentation. Use typed action requests and named state objects instead of adding more branches and positional snapshot slots. Resolve the stable-ID migration first so extra layers do not formalize the wrong schema.

### R16 — Performance and scale need measurement before larger battles [P2 risk, not a measured failure]

Fixed eight-scout assumptions, synchronous floor generation and repeated inventory/catalog/stat work during UI/state updates will constrain larger battles. The current material sharing and batched grass/geometry are useful optimizations. There is no evidence from this review alone that a particular machine cannot run the game.

Profile a worst-case generated floor, a full backpack, an open tree and a multi-player encounter before increasing counts. Establish frame-time and generation-time budgets, cache derived values when inputs change, and separate encounter capacity from packed rendering/network assumptions. Keep internet co-op deferred until state ownership, item IDs and transactions are stable.


### R17 — Unknown part IDs silently become Thorn Bloom resources [P1 before content expansion, reproduced]

`Seeds.species_for_part` returns 0 when no matching part exists. `Progress.part_count` and `add_parts` use that result rather than rejecting the ID. In a probe with seven Thorn Bloom parts, `part_count(999)` returned 7, and `add_parts(999,1)` raised the Thorn Bloom count to 8.

Current UI checks block many invalid requests, so this is not proof of a player-accessible exploit. It is a dangerous content/persistence fallback: an incorrectly migrated ID or malformed definition can quietly read or modify a valid resource instead of producing an actionable error. Other catalogs similarly clamp unknown kinds or fall back to a blade visual.

Return an explicit missing result, validate at system boundaries and quarantine unrecognized saved items until migration can resolve them. Never silently reinterpret valuable inventory as another species. Add invalid-ID probes to the catalog and migration test suite.

### R18 — A generic inventory item is not automatically a usable crafting component [P2, confirmed]

The custom-item registry can accept an entry categorized as `plant_part` with tags and rarity, and the inventory can represent it. But equipment slots still require numeric entries in `Parts.DEFINITIONS`, and Altar/equipment integrations often depend on `legacy_part`. A probe registered a custom Rare plant part successfully; it had no equipment part ID and therefore no route into the current weapon-slot API.

This is not necessarily wrong for miscellaneous materials. It does mean the item template currently overpromises if used as a universal component template. Classify entries as general materials versus equippable components, and validate the required reference. Long term, a stable part ID should link its inventory, effects, harvest/drop, Altar and equipment definitions.

### R19 — Generic research payment chooses resources without consulting the player [P2, design/UX]

`HeartProgress.spend_materials` consumes shared plant parts in species-array order, valuing each as one generic unit. It does not choose by rarity, protect a favored species, or ask which parts to sacrifice. A probe with both Thorn Bloom and Moss available spent only Thorn Bloom first.

This conflicts with the importance placed on deciding how to use a specific plant. A research purchase can consume ingredients the player intended for the next expedition, although departure later validates availability and blocks an impossible loadout. This is friction rather than a confirmed duplication bug.

Offer an ingredient choice, reserve materials explicitly, or introduce a clearly named generic research resource produced through voluntary processing. Display the exact consumption before confirmation. Do not add another currency casually; the simplest adequate choice is likely an explicit material-selection step.

### R20 — Inventory squares are presentation, not a backpack capacity rule [P2, decision to document]

The inventory draws at least 40 squares, but does not cap the number of carried stacks at 40. `InventoryModel.stacks` keeps emitting stacks, and the grid scrolls as needed. Only the pouch and prepacked monster cargo have explicit limits.

A finite backpack was not explicitly required in the earlier inventory request, so this is not a broken requirement. It is an important game-design distinction: currently expedition risk is survival/checkpoint access, not carrying capacity. If later UI or upgrades promise extra backpack slots, implement capacity centrally rather than making grid size the rule. Keep ordinary item stacks and protected-pouch capacity separate.

### R21 — The co-op backend is same-PC only, and world-transfer progression remains future work [P2 planning]

`host_game` binds to `127.0.0.1`, allows one guest and `join_game` connects to that same address. This is two local instances, not general LAN support. The host accepts a normalized supplied character profile, appropriate for the current trusted local prototype but not a complete public-session trust model.

Character XP, learned choices and familiarity live in the character profile. Seed reserves are held by the host Garden under the guest's identity; the profile contains no seed-transfer inventory or tiered cross-world seed slots. The earlier ambition to bring seeds between hosts is therefore not implemented merely because character progression travels.

Keep networking transport deferred as requested. Before opening LAN/internet access, specify world ownership, profile trust, reconnect/disconnect recovery, duplicate identities, progression authority and how guests deliberately export seeds. The stable-ID and transaction work directly supports this future milestone.

### R22 — Encounter scheduling has accidental couplings [P2]

The checkpoint interval is 5, while `ROUTE_ROOMS` is defined as `CHECKPOINT_INTERVAL + 1`, currently six encounters per biome. Grafting altars use a separate fixed interval of eight. These are legitimate current values, but changing checkpoint frequency also changes biome length and guardian frequency without an explicit design decision.

That affects memory pacing, offshoot timing, extraction opportunities and the number of biome transitions in a run. Put checkpoint spacing, biome length, guardian placement and shrine scheduling into an encounter schedule with independent fields. Show the next extraction opportunity clearly, especially when a guardian at encounter six is followed by several more encounters before extraction opens.

### R23 — New terrain materials bypass the old biome-color logic [P2, source-confirmed]

`stage.gd` still changes `wild_floor.albedo_color` by site and depth. But `redraw_terrain` replaces the displayed wilderness base with a new `forest_soil` ShaderMaterial, and the generated walkable floor uses that same shader. The shader has a forest-bed toggle but no biome/depth palette parameter. `build_exploration_floor` retains a `site` argument that no longer selects its material.

The enemies and layout parameters can still vary by biome, so the biomes are not identical in every respect. The specific old floor-color/depth treatment is ineffective. This is a direct example of a new visual pass leaving a previous system apparently active but disconnected.

Move biome palette, dampness, vegetation, corruption accent and depth progression into a shared biome presentation definition consumed by the current shaders and scenery generator. Preserve the distinction between a peaceful Garden and dangerous Wilds; vary horror progressively rather than tinting everything purple again.

### R24 — Historical resources are being included in release exports [P2, export-log confirmed]

The preset exports all resources without exclusion rules. A recent export log explicitly stores compiled archived scripts such as `res://docs/change-backups/20261107-175301/game.gdc`, along with historical review screenshots and test resources. This is stronger evidence than simply finding a backup folder in the project.

These resources are not proven to execute in normal play, so this is not a claim that the old game controller runs alongside the new one. They do add unnecessary release contents and make provenance and cleanup more confusing.

Move archives outside the active import tree or exclude them through a tested release preset. Keep the recovery copies intact. Include runtime-required assets explicitly, and make a release-content check fail if test scripts, archived source or review imagery appear in the pack. Recheck the packaged game after exclusion so the cleanup cannot accidentally remove a dynamically loaded runtime asset.

## Cross-system ownership and lifetime contract

The following should become a concise, authoritative specification rather than being inferred from fields and menus:

| State | Intended owner and lifetime | Current review observation |
| --- | --- | --- |
| Garden Knowledge, technologies, seed recipes | Host world; persistent | Broadly represented; legacy flags still mirror newer Heart state |
| Class XP/choices and species familiarity | Character; persistent across hosts | Profile exists; monster familiarity is currently credited to the wrong species |
| Planted crops and harvested shared materials | Host Garden; persistent | Ownership is coherent; harvest persistence needs transaction recovery |
| Guest stored seeds/parts | Guest-owned reserve within host world | Present; not the same as portable cross-world inventory |
| Starting weapon components | Consumed once per expedition | Validated on departure; define recovery if saving departure fails |
| Checkpoint upgrades | This expedition only | Purchases remain active after a graft replacement, matching the accepted rule |
| Grafted monster component | This expedition's fourth slot | Replaced at a later shrine; old component is sacrificed; purchased upgrades remain |
| Pouch contents | Protected on wipe; lost on voluntary abandonment | Explicitly different outcomes; quantity/stack protection is a balance decision |
| Run currency | Equal earnings, individually spent | Shared milestone-derived amount supports that intent |
| Guardian memories | Host world; banked on extraction | Once per biome per expedition, even if that biome is looped repeatedly |
| Research milestones | Host world; deepest qualifying clear | Advances on extraction or wipe, not voluntary abandonment |
| Character combat XP already awarded | Character; persistent | Kept independently of later abandonment; wording should distinguish it from expedition rewards |

## Rules for the next content milestone

Do not count a new definition as complete until it passes an acquisition-to-use path. For example, adding a new monster should require a test that spawns it through composition rules, defeats it through normal combat, credits that species, awards its eligible personal loot, preserves the loot through the intended outcome, installs its component and exposes a valid related upgrade. A new plant similarly needs discovery, planting, visible stages, harvest-table rewards, personal familiarity, crafting and save/reload coverage.

For the next milestone I would choose **one existing monster and one non-Thorn plant** and make those paths fully correct before adding another roster batch. This provides a smaller, verifiable standard that the rest of the content can then follow.

## Old artifacts: keep, migrate or retire

| Artifact | Disposition |
| --- | --- |
| Retired affinity `traits` slots | Keep as inert compatibility data until an explicit schema migration; do not restore the old toggle |
| Legacy save backups/tombstones | Keep. They protect existing progression and intentional save deletion |
| Legacy flowering/Rift flags mirrored from the Heart | Migrate toward one source of truth; retain load adapters during transition |
| `Parts.effect`, old two-slot/Rift-pair paths | Label compatibility tests; remove production-dead helpers only after reference checks |
| Unused primitive `build_gate` and superseded scenery builders | Candidates for retirement, not automatic deletion based only on a name scan |
| Hidden old station models and old action strings | Consolidate display/action routing; preserve only migration or compatibility needs |
| Old tool generators writing current asset filenames | Archive or require an explicit legacy output directory |
| Historical screenshots and 19 change-backup directories | Retain outside the active content/export path with an index; do not treat them as current specification |
| Old README controls and stale test expectations | Replace now; they no longer document intended behavior |
| `Mystical Garden Prototype` user-data folder | Keep until a tested migration exists; its name alone is not a gameplay defect |

## A content pipeline that can grow

Before adding another batch of content, require every definition to declare a stable ID, display data, supported behavior/effect IDs, prerequisites, rewards and visual references. Validate duplicate IDs, missing assets, invalid parents, unreachable rewards, recipe ambiguity, unsupported effect keys and unmet loot tags.

| Addition | Expected work after stabilization |
| --- | --- |
| Plant species | Definition, lineage, harvest table, portrait/model; inventory/tree/Altar use shared registries |
| Plant material | Item ID, supported effects, rarity and acquisition path; no new special counter |
| Weapon using an existing attack behavior | Definition, compatible slots/tags, model and motion profile; no class/weapon-index clamp edits |
| New attack behavior | One registered execution handler with matching targeting, animation and tests |
| Enemy variant | Definition, behavior parameters, model variants, spawn/loot eligibility; no bit-packing alias |
| New enemy behavior | Registered handler and clear telegraph, plus encounter composition rules |
| Class | Definition, weapons, two skill kits and node IDs; no fixed five-class renderer assumption |
| Heart upgrade | Catalog entry and supported effect; one authoritative progression state |
| Checkpoint offer | Validated definition with requirement and effect IDs, description generated from the same effects |

An entry is not finished merely because its menu renders. It must be obtainable, usable, persistent, described accurately and exercised through a normal player path.

## Recommended development order

1. **Repair supply and persistence.** Correct monster loot and familiarity provenance; reject unknown IDs; introduce stable IDs and a migration fixture; make harvest/departure/extraction transactions recoverable. Exit criterion: old saves retain item identities and a naturally earned trophy completes the full graft/upgrade loop.
2. **Unify player-facing truth.** Replace retired controls/messages, fix stale tests, make the current build target explicit, and update the brief's current-vs-future sections. Exit criterion: a new player can follow the guide without discovering a superseded interaction.
3. **Add depth to the existing roster.** Species harvest tables, meaningful familiarity bands, readable build interactions and attack-contact timing. Exit criterion: several equally viable supply/build paths work without spawning items manually.
4. **Tune a repeatable campaign slice.** Instrument several expeditions and test offshoot tradeoffs, class progression, pouch protection and guardian memories. Exit criterion: repeated runs yield meaningful decisions rather than only longer counters.
5. **Expand content, then multiplayer transport.** Add catalog validators and performance budgets first. Keep networking concerns in the data/authority design now; internet infrastructure can remain a later milestone.

## Validation and limits

- 28 standalone non-co-op scripts: 26 pass; 2 fail with superseded interaction expectations.
- Full `playable.gd -- solo`: passes. Combined result: 27/29 runs pass.
- Focused review probes confirm the restricted leader loot pool and familiarity credit, current part-ID allocation, enemy encoding alias, failed harvest-save inconsistency, unknown-ID resource alias, partial custom-component registration, research payment order, attack-angle mismatch and early familiarity caps.
- Exact baseline results and probe output are saved alongside this review in `review-evidence-2026-11-08`.
- No co-op/network suite, internet connection, performance benchmark or multi-hour balance playtest was run. Visual judgments use the current presentation and implementation evidence; they are not claims of a complete live playtest.
- No fixes were applied during this review. The next milestone should address R01–R04 and the content-ID constraints before substantially increasing the roster.
