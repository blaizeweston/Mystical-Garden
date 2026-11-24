# Cultivation terrace and Living Water Conduit

G-07 proves a second location and a practical Garden tool through the existing boundaries.

**Verdant Refuge** (`clearing_2`) reveals a ruined cultivation terrace northwest of the Heart. The registered location includes existing **Bed 4**; it does not add, move or restrict a planting bed. Recording its root pattern supplies an existing Whispervine refinement clue. Sacrifice, discovery and rewards still happen at the Altar.

Research **Living Water Conduit** for six available Knowledge after Verdant Refuge, Living Sprinklers and Cultivation Grounds. Its policy follows the historical fourth crop slot when the bed is relocated.

At the terrace, the host can redirect the living channels:

| Condition | Optional preserved-bud outcome for newly planted terrace crops |
|---|---|
| Gentle seep | Existing unusual bud: 20% longer growing work, +15 percentage points rare chance, capped at 60% |
| Deep pulse | Deep-veined bud: 40% longer growing work, +25 points rare chance, capped at 70% |

These modifiers apply only if someone chooses to preserve the bud during the young stage. Leaving it alone preserves ordinary growing time and normal harvest chances. Seeds can still be planted in any bed; ordinary parts remain guaranteed at a normal parts harvest. Flowering remains the alternative mature seed harvest and forfeits the parts/rare opportunity. Existing Wilds acceleration, research bonuses and watering still use the one shared growth clock.

Switching is free and affects **subsequent plantings only** in the registered terrace bed. Current crops snapshot their policy, choice, revision and saved rare roll. Changing the flow cannot reroll, reset or upgrade them. Other beds retain ordinary care.

## Authority and compatibility

`garden_conduit.gd` owns a small versioned `garden_interactions.conduit` configuration: mode and revision. Old saves default to gentle seep without auto-unlocking the new research. Future/unknown configuration is retained and fails closed; the rest of the Garden remains usable. Planting falls back to normal care if that configuration cannot be understood.

The host validates Garden eligibility, host identity, research, range, travel state, mode and current revision. The change commits through existing transactions; failed saves retain the prior setting. Repeated same-setting commands cannot reroll crops. Guests receive a read-only configuration and can inspect and tend host crops, including preserving deep-pulse buds, but cannot change the host's setting. Rejoining restores mode and crop choices without altering a guest's own Garden research.

The UI derives policy numbers and bed labels from the catalogs. Existing Garden actions carry the new intent; no new network RPC or public packet slot was added. The existing cultivation compatibility fingerprint includes the care catalog, so all co-op players need this updated build.

## Content and change audit

| Files | Why they changed |
|---|---|
| `garden_interaction_catalog.gd` | Second zone, footprint, existing bed, reveal anchor and ordinary observation/refinement references |
| `garden_layout.gd` | Generic footprint clearance and pond exclusion, keeping approaches and existing/future beds safe |
| `heart_catalog.gd` | One appended stable research ID, prerequisites and tuning; existing IDs/order remain intact |
| `garden_crop_catalog.gd` | One additional bounded policy using existing preserve/leave, duration, rare chance and harvest code |
| `garden_conduit.gd` | Small setting/policy adapter, host validation, transactional command, projection and catalog reference checks |
| `garden_terrace_view.gd` | Local low stone/root-channel art, visible flow color and settings controls inside ordinary inspection |
| `garden_interaction_service.gd` / `garden_interaction_view.gd` | Narrow optional projection/handler/view wiring; generic observation code stays authoritative |
| `game.gd::plant_seed` | Ask the adapter to snapshot a policy into the already existing crop cycle |
| `garden_growth_catalog.gd` / `garden_growth_view.gd` | Reusable zone reveal destination and formation, using the saved queue and root-following camera |
| `garden_growth_service.gd` | Separate regression fix: title-screen guests must not initialize/save a local world just to register a viewer |
| Tests/map/docs | Isolated conduit/co-op coverage, reusable enabled-catalog assertions, ownership and this authoring audit |

Combat, weapon interactions, generic inventory, Altar sacrifice/refinement, Heart project processing and harvest payout handlers required no new branch. Adding the ordinary terrace observation needed content and placement only; configuration is the deliberately new verb with its own small authority. This remains a small authored tool, not a general-purpose ecology scripting framework.

For another zone, declare its stable ID/footprint/bed references/prerequisites and an existing observation/refinement. Use a clear `reveal` anchor/name for an existing root-following scene. Unique art needs a presentation builder. For another conduit condition, define a bounded care policy and refer to its ID in the mode catalog; do not copy harvest, RNG, growth-clock or research implementations. A genuinely different behavior needs an explicit small service and interaction-map coverage.

## Validation

`garden_conduit` exercises real research start/completion, terrace/refinement references, water and bed clearance over supported layouts, one root-following reveal, save rollback, stale/out-of-range/unknown intent rejection, fixed existing crop choices, policy math, ordinary non-terrace planting, reload/future data and a fully upgraded historical Garden without a free new unlock. `garden_conduit_coop` exercises real admission, server rejection of guest settings, authoritative policy projection, guest tending and reconnect. Existing source/package suites cover consumers selected by the interaction map.

The existing cleanup/Heart/seed tree checks now compare enabled catalogs and stable IDs instead of freezing the old Heart-node count. The failed-title-Join regression is covered by `start_menu`, now explicitly linked to viewer registration. Full validation remains reserved for a major release or an explicit request. Release evidence is recorded in the canonical milestone handoff after package verification.

## Released evidence

Evidence (2026-11-10): connected run `20261110-155748-7d2c37ca` passed 44 affected suites with 51 verified results reused (95 registered). Packaged validation passed 31 selected suites with 31 reused, startup/catalog/exclusion validation, real host/three-guest admission and full-session rejection, and movement/animation/private-detail smoke. Full game-suite validation was not run. Rendered terrace, both settings and research views were inspected at 1280×720; the renderer error log is empty.

Only `Mystical Garden v0.5.2.0.exe` was replaced. Installed SHA256 `f6b0afc9931d101bc8da6a6d25630de3c57ef56c79c826349edeba7416ad587d` matches the verified staged package. Prior EXE: `.godot/release/backup-20261110-160219-Mystical Garden v0.5.2.0.exe`. Logs: `.godot/g07-connected-release.log`, `.godot/g07-package.log`, `.godot/validation/last-package.json` and `.godot/network-tests/20261110-160211-5f8b0dc8`. The protected pre-cleanup backup was not accessed.

G-07 is Complete. G-08 is Ready and needs real playtest observations for its pacing targets. All co-op players should use the updated EXE.
