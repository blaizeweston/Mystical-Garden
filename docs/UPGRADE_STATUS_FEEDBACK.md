# Upgrade cards and status feedback — 2026-11-10

Reviewed through the mechanics map in this order: checkpoint-card effects → resolved weapon/skill traits → authoritative applications and delayed hits → status state → presentation events → local/guest rendering → diagnostics and validation.

## Player conditions

Brief overhead labels follow the rendered player and fade after about 1.35 seconds. Supported live conditions are Slowed, Warded, Counter ready, Mark ready, Death charge and Echo charge. Charge callouts include their count out of three. A refreshed or changed condition can produce a new callout; steady conditions do not emit events every frame. These labels reflect conditions that exist in the current game; they do not introduce new player debuffs.

## Enemy conditions and marks

Marked enemies carry a pulsing purple diamond/rune. Brittle has a blue geometric icon and visible stack count. Rooted, Staggered and Hastened also have indicators. Multiple conditions stack vertically instead of overlapping. Names appear briefly, while active enemy icons remain. Indicators follow interpolated models, respect sight range, and clear on expiry, death, floor change or consumption.

Mark behavior is now explicit: a marking contact applies a four-second mark; an eligible follow-up consumes it and receives the corresponding bonus. It cannot immediately reapply that same mark. Subsequent contacts can mark again. Precision requires a primary contact; Omen consumes only when its wind-up bonus triggers. An ordinary hit without a compatible bonus does not consume another player's setup. Consumption removes the icon and emits a small burst at the icon height with a Mark triggered callout.

This changes the previous refresh-on-every-hit behavior. Descriptions in the trait inspector state the consumption rule.

## Upgrade effect coverage

All 126 checkpoint-card definitions were checked against the existing effect vocabulary.

| Effects | Feedback |
|---|---|
| Mark, precision, omen | Apply icon, eligible consumption burst; wind-up punishment callout |
| Brittle and shatter damage | Live stacks out of three; shatter burst on threshold |
| Echo and echo redirect | Charge callouts, distinct confirmed echo cue/path; pulse for same-target echoes |
| Linked hits and linked brittle | Curved strand from original contact to the actual second target |
| Chorus pulse | Labeled strands to each additional enemy actually hit |
| Counter, brace, death charges | Ready/charge callouts and distinct committed-strike proc cues |
| Suppression | Interrupted callout and cancellation pulse only when an attack is interrupted |
| Additional projectile targets | Existing swept projectile/contact visuals plus Pierced on subsequent body contacts |
| Additional melee targets | Shared attack footprint, individual confirmed damage numbers and flashes |
| Healing on kill | Life restored cue only when health increases |
| Cinder trail | Existing bounded field plus rising ember strokes |
| Growth, tides, sanctuary, decoys | Existing living field/silhouette and visible area boundaries; guard status callouts |
| Spread bind, trap power, duration/recovery/stagger | Existing skill/field area plus live Rooted/Staggered conditions |
| Pull and knockback | Existing actual body displacement and hit flashes |
| Damage/power/technique/wind-up bonuses | Actual damage values, contact flashes; wind-up bonus gets its own cue |
| Reach, cooldown, target limits, skill tuning | Existing shared footprint, action/projectile timing, HUD readiness, and per-target confirmed impacts |
| Max health, healing skill, dodge cooldown | Existing heart HUD, named skills and ability timing |
| Loot attraction, graft chance, Rift Hook | Existing item movement or contextual crafting/research effects; no false combat proc |

Secondary attack cues resolve only after validating target identity and cover. Delayed hits on dead/replaced targets produce neither damage nor a misleading effect. The new visuals do not consume RNG or cause damage.

## Reusable implementation

- `combat_status.gd`: bounded host-derived condition vocabulary, transition events, active snapshots and proc event helper.
- `status_feedback.gd`: cosmetic billboard icons and following/fading labels.
- `combat_traits.gd`: actual mark/shatter/secondary-hit triggers; delayed hits retain origin and effect identity.
- `combat_effects.gd`: shared rendering for the new proc vocabulary and status renderer lifecycle.
- `game.gd`: existing event transport/snapshot integration and detailed diagnostic fields.

Active condition snapshots are independent of the capped transient event list. Consumed conditions are excluded from snapshots, and explicit end events prevent old packets from resurrecting a consumed icon. Guests use host duration/age rather than comparing unsynchronized clocks. Status publication is skipped while a save transaction is active; committed proc events retain the existing transactional event pipeline. No save-format changes were made.

Network protocol is now 19. All co-op players need this updated build.

## Verification

Dedicated unit checks cover application, consumption, bonus damage, Omen eligibility, no per-frame spam, expiry/cleanse, stale targets, brittle shattering, echo/link/chorus resolution, renderer following, transient-list eviction, late snapshots and cleanup. A local host/guest test checks replicated player conditions, enemy icons, consumption, deduplication and secondary cues. Existing class, species, upgrade, animation, combat-readability and diagnostics checks also passed during implementation.

The preview image is an isolated scene using the actual game renderer, not an internet multiplayer playtest. Final release results are recorded below after packaging.
Final release: all 77 source suites passed with stable inputs and release-ready evidence. All 44 packaged suites plus startup/catalog and four-player transport smoke passed. Updated only Mystical Garden v0.5.2.0.exe, with automatic backup. Installed SHA256 matches verified package: 001B8108F1D71065510F676304023B02D379C6DB68002EBC72425FBD1E61E4A5. Source fingerprint: 9DE8267524DB6B3E0CDC57D24B0B3980757FD96031163DDBF077A58B522C7FFF.
