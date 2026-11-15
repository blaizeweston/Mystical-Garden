# Combat balance and vitals milestones

Source audit dated 2026-11-12 against Mystical Garden v0.5.3.1. CB-00 through CB-07 are complete. The CB-08 release candidate promotes the 100 HP scale and revised combat after the solo Developer Garden playtest.

The first playable target is a 100 HP player with a liquid health orb, a Warden using the Rootblade and Heartwood Maul, one early Wilds pack, and the Orchard. The target includes solo and host/guest play so the next batch can reuse a proven combat and presentation path. See the [project milestones](GARDEN_MILESTONES.md) and the [mechanics and test map](MECHANICS_TEST_MAP.md).

## Plant-affinity rework contract

The opt-in affinity ruleset keeps Core, Form and Catalyst independent. Supporting
affinities are reserved for cards. CR03 Frost and the CR04 families use the same
authoritative event and class-skill mappings. Default combat stays on the legacy
ruleset.

### Overlapping Ward claims

Native protection decides whether the hit was blocked and owns duration, charges,
caps and clears. Each accepted grant keeps its recipient, expiry, host grant
order, response budget and granting Catalyst snapshot. Unenhanced grants also
have claims. An actual block chooses the earliest-expiring eligible claim, with
host grant order breaking ties. The chosen claim supplies its own family and
potency. No-op or duplicate grants cannot replenish responses. Expiry,
exhaustion or clearing invalidates the corresponding claims. Multi-block
Guard responds on the first qualifying block per activation.

### Drenched direct damage

The host evaluates Drenched at the native damage resolution point. A ranged
attack committed before Drenched was applied is reduced if the attacker is
still Drenched at impact. Expiry before impact restores normal damage. Lingering
ground hazards and attacks by separate summoned creatures use their own
resolution. Water cleanses ordinary Slow independently of other movement effects.

### Vital capacity and regeneration

Vitality changes expedition vitals on the host. Its strongest active capacity
bonus and regeneration rate are resolved independently on the existing physics
timeline. Capacity does not heal on grant. Expiry clamps current HP only when
necessary. Native maximum HP and revival costs remain independent of the bonus.
Vitality lasts during the current floor and can help the party recover between
fights. Falling, floor changes and Garden return clear the temporary grant.

### Thorn growth and Bleed

Thorn Line lasts 7 s with an 8 s cooldown. Each player can keep one Core field,
two Form patches, and two Catalyst patches. At the slot limit the newest field
replaces the oldest in that slot. Barbed Strikes creates a stationary patch on
the first valid direct contact, with a 2.1 s interval. Thorn occupancy applies
the strongest movement slow. Brittle remains a separate contribution. Only
Bleed deals recurring damage. Each player and slot owns one wound per enemy.
Leaving ends the Thorn slow and leaves the wound on its existing cadence until
its finite expiry. Growth follows terrain sight and does not affect collision.

### Bark Armor resolution

After the native Ward, brace and incoming-damage checks, including Drenched,
Bark attempts 40% partial absorption, rounded down. Each live grant retains its
source and expiry. A grant admits only what fits within 48 total capacity.
Consumption uses earliest expiry first and then host grant order. Reaching
zero through a hostile hit triggers at most one radial burst. The hit's
consumed grants supply a damage-weighted average of their burst potencies,
rounded to HP. The largest absorbed share gets damage credit, with ties going
to the earliest host grant order. Expiry, clearing and an exhausted single
grant with capacity remaining do not burst. Bark can absorb hostile hazards
through the enemy-hit path. Self-paid costs use their native path.

Wood Ward damage and armor-break damage share a 1.35 s interval per protected
recipient. Suppressed responses are discarded. Ward protection and the
admissible grant still resolve. Bursts do not grant armor. A breaking hit
that also ends the expedition keeps its settlement authoritative. A guarded
lethal hit publishes its burst only after verified commitment while that
floor is still active and writable. Falling, floor travel and Garden return
clear temporary armor. Splintering Strikes grants no armor.

### Four-player snapshot warning

The existing unreliable ordered channel 4 world snapshot in
`game.gd::send_expedition_state` produced the ENet MTU warning on CR04A and
CR04B. The payload contains compressed public player and scout state plus
floor and campaign data. Thorn footprints and Bark presentation use the
existing details stream, so the fast packet schema stays the same.

| Disposable loopback observation | ENet packet / MTU | Peak compressed player / scout sections | Client marker observation / sequence gaps |
|---|---:|---:|---|
| CR04A baseline `cr04b-baseline02` | 1417 / 1392 B | 819 / 265 B | 25–34 ms, 0–3 gaps |
| Same four-family control after integration `cr04b-wood01` | 1397 / 1392 B | 809 / 265 B | 19–201 ms, 5–19 gaps |
| Four-player Thorn and Wood `cr04b-wood02` | 1465 / 1392 B | 843 / 259 B | 31–43 ms, 0 gaps |

The section peaks are separate measurements and exclude RPC framing and
other fields. All guests received the authoritative floor, roster and enemy
HP marker and continued receiving snapshots. The timing measures observation
from when each fixture sees the probe marker. Packet gaps and fragmentation
remain possible on other networks.

### CR04B-N1 snapshot delivery

Protocol 41 keeps the same 50 ms scheduled cadence on the unreliable ordered
`receive_state` RPC (Godot channel 4, ENet channel 5). A sequence identifies
one authoritative batch shared by eligible recipients. Each frame replaces
the previous state. Reliable details carry display names and diagnostic
labels. When ENet's throttle falls to half or less of its normal scale, the
same reliable stream also carries the latest replacement frame for just
that peer. The 250 ms details cadence and shared sequence let a guest
recover without replaying a frame it received on the fast channel.
Vitals, phase-specific details, and combat cues still use their existing
channels. Receiving a frame updates presentation and prediction and
does not execute damage, rewards, or combat events.

Godot's 1,392-byte warning compares the complete RPC packet supplied to
ENet. ENet's fragmentation check also reserves its own headers. At the
default 1,392-byte ENet MTU, allowing for a 4-byte protocol header, 24-byte
fragment command and optional 4-byte checksum leaves 1,360 bytes for the RPC.
The single packed byte argument adds 3–7 bytes of RPC framing and an
uncached node path if needed. The 1,200-byte application budget covers
all four players and 20 scouts with a 1,196-byte maximum. The measured
application body excludes RPC, ENet, UDP and IP overhead. [Godot 4.7.2 ENet peer](https://github.com/godotengine/godot/blob/4.7.2-stable/modules/enet/enet_multiplayer_peer.cpp#L337-L347), [RPC framing](https://github.com/godotengine/godot/blob/4.7.2-stable/modules/multiplayer/scene_rpc_interface.cpp#L326-L433), [packed argument encoding](https://github.com/godotengine/godot/blob/4.7.2-stable/scene/main/multiplayer_api.cpp#L199-L225), [ENet fragmentation check](https://github.com/godotengine/godot/blob/4.7.2-stable/thirdparty/enet/peer.c#L97-L115), [ENet headers](https://github.com/godotengine/godot/blob/4.7.2-stable/thirdparty/enet/enet/protocol.h#L59-L70).

The original 580 ms observation began when one guest read a fixture signal
and ended when the local probe saw a newer sequence, the expected roster and
leader health, and the rendered floor. Its 20 numeric gaps were counted
through the extra post-observation sampling interval. These clocks measured
local observation and could include snapshot scheduling, main-thread work,
transport, guest application and probe polling. The original trace lacks
matched send and receipt records for the missing sequence numbers, so it
cannot identify which cause contributed to the delay. The new probe matches
send, receipt and application by sequence and measures local observation
from reading each marker. It reports separately any sequence that the
host did not target, any attempted send without a receive callback, and
any received frame that was stale.

Two repeats per family configuration used the same four-player floor and
15-scout workload. The first ENet warning in each old run was 1,409–1,449
bytes at the full RPC layer. The old code's application estimate was
1,228–1,307 bytes, including the compressed sections and an allowance
for the typed fields. Protocol 41 sent an exact 1,091-byte application
body in every matched sample and 1,196 bytes with 20 scouts. None of
the final runs reported the unreliable MTU warning. Two early sequence
gaps in the old runs preceded the first observed callback for one guest.
The original transport counters were unavailable for those sends.

| Matched loopback observation | Old protocol | Protocol 41 with recovery |
|---|---:|---:|
| Marker read to observation, median / p95 / worst | 33.6 / 53.5 / 141.5 ms | 29.4 / 48.2 / 340.7 ms |
| Marker observations | 96 / 96 | 96 / 96 |
| Fast application send rate per peer | 19.9–20.2 Hz | 19.8–20.1 Hz |
| Fast application bandwidth per peer, excluding recovery and transport | 25.0–26.1 KB/s estimate | 21.6–21.9 KB/s |
| Host encoding, median / p95 | 229 / 323 µs per peer | 206 / 229 µs per shared batch and first recipient |
| Guest receipt to state application, median / p95 | 374 / 633 µs | 392 / 605 µs |
| Longest guest process-frame interval | 34.3 ms | 35.0 ms |

A compact-only diagnostic run without recovery isolated the independent ENet
throttle effect. All 68 witnessed sends with no receive callback had an
ENet throttle-counter step above the peer's send threshold. Another 41 gaps
preceded the available host trace. One four-family guest missed five of eight
markers and went 1,150 ms between applied frames. This reproduced a delivery
delay with under-budget frames, and the evidence attributes that reproduction
to ENet discarding unreliable sends. The original 580 ms observation lacks
the counters needed for the same attribution. [Godot ENet throttle counters](https://github.com/godotengine/godot/blob/4.7.2-stable/modules/enet/enet_packet_peer.cpp#L139-L144), [ENet send decision](https://github.com/godotengine/godot/blob/4.7.2-stable/thirdparty/enet/protocol.c#L1382-L1410).

The final trace matched 478 fast sends, 466 fast receive callbacks and
469 applications including three reliable recoveries. All 12 matched
misses coincided with ENet's throttle decision for one six-family guest,
which observed all eight markers and went at most 277 ms between fresh
applications. There were no stale rejections in the matched window.
The final marker p95 met 250 ms and the worst marker delay and worst fresh
update interval both met 500 ms. No separate-PC or internet timings were
measured.

The preserved baseline runs are `cr04bn1-beforeA` and `cr04bn1-beforeB`.
The compact-only diagnostic failure is `d4c4055b1e3f481eb5994e13f977ddcf`.
Final structured verdicts are `be4a764d5ee349759ce59b57ddd5c5b1` and
`d0d61822b544414b9e6fcbf138a681fe` for four affinities, and
`dda390c966824824a984a2840fdefe08` and
`55f3738b22fc49cf910372668297224a` for six. All five processes exited
successfully in each run, including the refused overflow client. The
six-family fixture checks full occupancy, one Bark break after skipping an
intermediate state, and removal of Thorn hints on the same active floor.
`cr04bn1-accepted-source` keeps the impact preview, exact-input hashes and
all 22 execution results, including the four matched runs. The focused
controls cover codec rejection and recovery, legacy co-op, movement and
weapons, status presentation, integrated terrain, advance, extraction and
rejoin, overflow, and protocol/ruleset/definition refusal. The planner
self-tests passed 55 of 55.

## Size of the change

This is a major combat balance release. It has two separate jobs. First, give HP, damage and healing enough precision while keeping comparable fights recognizable. Then tune damage ranges, enemy durability, and sustain against how the fights actually play. The existing content templates give us a route to review this by family and tune exceptions individually.

| Shipped content to review | Verified catalogue scope |
|---|---:|
| Enemy roster | 20 regular species and 4 bosses, plus the shared gate-elite curve, variants, reinforcements and summons |
| Class weapons | 15 across 5 classes |
| Class skills and progression | 10 base skill slots, 10 legacy replacement entries, 15 subclass focuses, 60 current branch nodes and 60 legacy nodes |
| Plant Core skills | 24 skills and 70 slot interactions, with additional weapon delivery variants |
| Crafting materials | 48 plant components from 24 species and 24 monster grafts |
| Checkpoint upgrades | 166 cards, including 128 JSON entries, 23 generated Core cards and 15 generated class cards |

Counts come from the loaded catalogues, including entries generated at runtime. Every entry gets a compatibility review. A timing, geometry, movement or utility effect only needs retuning if its interaction with the new balance calls for it. [Classes](../class_catalog.gd), [Warden tree](../warden_tree.gd), [Subclass catalogue](../subclass_catalog.gd), [Core catalogue](../core_skill_catalog.gd), [Parts](../weapon_parts.gd), [Cards](../run_upgrade_catalog.gd), [Enemies](../assets/enemies/catalog.json).

## Impact audit

| Area | Current dependency and migration work |
|---|---|
| **Player health and expedition life** | Players start with 10 HP. Rebuild max health from base, earned and equipped bonuses, then apply expedition capacity loss. Follow that calculation through spawn, entering the Wilds, class/loadout changes, checkpoint purchases, grafting, falling, revival, extraction, wipe and Garden return. Revival currently subtracts 2 max HP and heals to the reduced maximum. Carry the full-heart cost and minimum remaining capacity into the new scale. Define how a max-HP increase affects current HP, including a purchase while wounded and a purchase after revival. [Game state](../game.gd), [Expedition life](../expedition_life.gd). |
| **Healing and mitigation** | Healing is spread across floor transitions, Renewal ticks, direct class and subclass casts, Core return waves, siphons, death triggers, pools, and weapon/graft kill effects. The current values include +1/+2 at floor transitions, +1 per Renewal tick, and a cap of 3 HP on the resolved heal-on-kill stat. Separate potency, tick interval, targets, per-cast or per-kill limits, and actual HP restored. Check full-health targets, fallen targets, simultaneous effects, repeated kills in large packs, summons and reinforcement kills. Review guard, brace, wards, hit grace, and the ordering of prevention before health loss. [Game combat](../game.gd), [Core effects](../core_skill_effects.gd), [Combat traits](../combat_traits.gd), [Subclass combat](../subclass_combat.gd), [Warden combat](../warden_combat.gd). |
| **Basic attacks and weapon progression** | Damage enters from the weapon, the three plant slots, the monster graft, permanent class effects, and in-run cards. Some bonuses are fractional before rounding. Checkpoint `power` has a separate path through player state, while `technique` affects several different attributes. Capture the basic roll on the host at attack commitment and use that value for the queued strike, projectile, piercing or fan contacts. Apply contact-specific effects such as wind-up bonus, mark consumption, damage reduction and weak-point exposure at the hit. Check graft replacement while a shot is in flight. Use one resolved preview for crafting, comparison and the expedition summary. [Weapon resolution](../weapon_system.gd), [Contact geometry](../weapon_contact.gd), [Mouse combat](../mouse_combat.gd), [Run summary](../run_summary_panel.gd). |
| **Skills, class trees and cards** | Direct strikes, waves, pulses, lingering fields, traps, projectiles, links, marks, shatter, counters and execute-like follow-ups all have separate damage paths or coefficients. Healing and guard upgrades can change the value of the same loadout. Legacy class `power` can increase damage, healing, charges, duration, radius and range in one resolver. Core values are authored in definitions, weapon variants, phase effects, slot interactions and card overrides. Audit per hit, per cast and per target. Review behaviour-only cards whose payoff depends on newly tuned damage or healing. Update validators and generated effect text along with values. [Class skill resolver](../skill_catalog.gd), [Subclass runtime](../subclass_combat.gd), [Core rules](../core_skill_rules.gd), [Core roster](../core_skill_roster.gd), [Checkpoint catalogue](../run_upgrade_catalog.gd), [Content validator](../content_validator.gd). |
| **Monsters, elites and bosses** | Scout HP combines a shared base, a species adjustment, growth, depth, loops and party size. Elites and bosses use different HP curves. Regular hits add damage every two loops and boss hits every three. Some hazards use fixed damage and the Pallbearer can restore enemy HP. Review basic hits, heavy telegraphs, fallback strikes, lingering hazards, summoned units, boss exposure bonuses, and Bark/shelter reduction. Measure solo and four-player pack pressure together with individual HP. Longer fights also give enemies more time to summon, heal or reinforce. Keep the boss phase checks as percentages and verify each transition. [Enemy catalogue](../assets/enemies/catalog.json), [Combat Director](../combat_director.gd), [Balance data](../assets/content/balance.json), [Enemy support](../enemy_support.gd), [Bosses](../boss_encounters.gd), [Reinforcements](../expedition_pressure.gd). |
| **Enemy learning and targeting** | A hit of 3 or more counts toward burst learning. The ranged rule has both a 2-damage minimum and a ratio, and target selection uses accumulated damage as threat. A flat change in damage units would change tactic detection and how soon threat reaches its cap. Translate absolute thresholds during the parity pass and keep ratios and counts in their own units. Check that new roll variance does not make an unchanged build register as a different tactic too often. Preserve saved tactic scores. [Combat and floor settlement](../game.gd), [Threat targeting](../combat_director.gd), [Wilds learning](../wilds_learning.gd). |
| **HUD, tooltips and feedback** | Replace the lower heart row with an orb and exact HP readout. Animate a short change band for healing and damage. Show revival's unavailable capacity above the current maximum even when the reduced pool is full. Keep ally bars compact with the same lost-capacity marker and heal feedback. Check fallen and spectator states, low-health readability, HUD scale, co-op colours and the Garden view. Weapon previews, class nodes, part tooltips, cards and Tab totals need matching units. Show the final basic attack range and label conditional effects separately. Hit and heal numbers show applied amounts, including overkill and overheal handling. [HUD](../root_ui.gd), [Party HUD](../party_hud.gd), [Combat feedback](../combat_feedback.gd), [Loadout panel](../loadout_panel.gd), [Progression panel](../progression_panel.gd). |
| **Co-op authority and diagnostics** | Movement snapshots and reliable vitals messages both carry health. The guest reconciles them by revision, and damage feedback is deduplicated by sequence. Keep the host authoritative for rolls, damage, heals, max HP and falls. Check interleaved damage and regeneration, stale snapshots, rejoin, revival, and committed hit feedback. The content manifest tracks IDs and levels, so a unit change alone may leave it unchanged. Update multiplayer compatibility at release. The log analyser currently identifies revival from a 2-HP loss; it needs an explicit event or a version-aware interpretation to read both old and new reports. Log applied healing and damage distinctly for tuning. [Network presentation](../network_presentation.gd), [Compatibility](../network_compatibility.gd), [Content IDs](../content_ids.gd), [Diagnostics](DIAGNOSTICS.md), [Log analyser](../tools/log_analysis/analyze_session_logs.py). |
| **Existing profiles, saves and progression** | The inspected character and Garden schemas persist loadout IDs, learned-node masks, XP, materials, unlocks and Wilds memory. Live HP, capacity loss and checkpoint ranks are expedition state. Resolve existing loadouts and learned effects through the new data. Preserve stable IDs and old node meanings, including the legacy class tree path. Verify older saves, grafts, inventory, return/settlement and failed-save rollback. Translate a persisted value only if the source audit finds that it stores an affected combat amount. [Character profile](../character_profile.gd), [Garden progress](../progress.gd), [Content IDs](../content_ids.gd), [Transactions](../game_transaction.gd). |

## Proposed combat rules for the prototype

- **Use integer HP for absolute effects.** Start at 100 HP and a 20 HP revival cost. Define units at the content and runtime boundaries. An absolute damage bonus, a multiplier, a target count, a duration and a charge count each keep their own meaning. A field such as `power` or `field_power` needs review at its consumer because its meaning varies with the effect.
- **Establish a parity baseline before retuning.** An old 3 HP scout becomes 30 HP and an old 1 HP hit becomes 10 HP for the baseline comparison. Apply the same check to each relevant damage, healing and mitigation path, its thresholds and its clamps. Check rounding at co-op and multi-hit boundaries against the original build. Keep percent-of-HP checks and dimensionless multipliers in their original units. Mark deliberate departures from parity.
- **Roll ordinary weapon attacks first.** The Rootblade starts at 8–12 and the Heartwood Maul at 17–23 as provisional values. Add a flat bonus to both ends. Resolve it once per committed basic attack using host-only randomness independent of loot, grafts and map generation. Keep authored skill ticks and conditional effects deterministic for the prototype. Verify the range, expected damage and hit count before picking spreads for other weapons.
- **Give healing a per-source budget.** Track the theoretical heal, actual HP gained and wasted overheal. Test 20 → 24 → 28 HP under a four-point regeneration tick, then test overlapping damage and healing. Compare single-target, group and on-kill sustain with one and four players. Choose final gate-heal amounts after comparing loss and recovery across several floors. Use 100/100 → 80/80 after a first revive as the starting-capacity fixture, with the upper fifth of the orb showing lost capacity.
- **Tune encounter outcomes.** Compare hits to kill and time to kill for light, heavy and multi-target weapons. Measure hits survived, healing per cleared floor, downs and revives, and the damage players can land during a boss opening. Exercise an early pack, a mixed biome pack, a deep reinforcements floor and the Orchard in solo and co-op. Save representative logs and record intentional breakpoints before increasing health beyond the baseline.

## Milestone catalogue

| ID | Status | Objective | Depends on | Acceptance |
|---|---|---|---|---|
| **CB-00** | Complete | Audit scope and catalogue the update | — | Source paths and loaded catalogue counts verified. This document records the rollout and its dependencies. |
| **CB-01** | Complete | Establish HP units, shared resolution rules and baseline fixtures | CB-00 | Define absolute values, ratios, durations and counts. Trace every active damage/heal/cap writer and consumer to its unit and owner. Compare representative current and converted hits, regeneration, mitigation, threat, learning thresholds, boss phases and co-op HP rounding. Document the chosen round points and save/wire handling. |
| **CB-02** | Complete | Prove the Warden, health orb and Orchard vertical slice | CB-01 | Rootblade and Heartwood Maul roll in their displayed ranges. One plant Core and one Warden heal/defence effect work with the new units. Verify 20 → 24 → 28 HP, 100 → 80 capacity loss, exact guest vitals and the Orchard opening and phase transitions. Compare the prototype with the old build before broad conversion. |
| **CB-03** | Complete | Convert all weapons and component bonuses | CB-02 | Cover all 15 weapons and the 72 plant/graft components through shared data. Test rapid, heavy, multi-target, projectile, pierce, chain, follow-up, miss and in-flight graft cases. Resolve damage and preview ranges from the same data. Verify content IDs and existing crafted loadouts. |
| **CB-04** | Complete | Convert all class skills and tree bonuses | CB-02, CB-03 | Cover the five classes, each focus, current nodes and legacy builds. Audit direct hits, area skills, fields, guard, healing, augmentation and class-driven damage/charge changes. Preserve unlocked nodes and make the affected node text agree with resolved stats. |
| **CB-05** | Complete | Convert the plant Core roster, interactions and checkpoint cards | CB-03, CB-04 | Review all 24 Core skills, 70 interactions and 166 cards. Verify pulses, traps, marks, links, healing, defensive effects, stacked card ranks and slot-qualified changes. Test resolved text and the Tab total. Confirm card eligibility and costs continue to use their existing inputs. |
| **CB-06** | Complete | Rebalance regular enemies, elites, bosses and depth | CB-02, CB-05 | Review all 24 species, juvenile and hazard exceptions, enemy healing, elite formulas, loop boundaries and co-op packs. Compare early, biome-end and deep floors, including a floor where reinforcements activate. Confirm scaling leaves each boss's telegraphed response and vulnerability window meaningful. |
| **CB-07** | Complete | Tune expedition sustain and finish health presentation | CB-04, CB-05, CB-06 | Balance floor recovery, regeneration, ally heals, pools, siphon and kill sustain with the larger packs. Test simultaneous heals and hits, lost-capacity clamping and revival after earning max HP. Verify orb and party readability in combat, including overheal and spectating. |
| **CB-08** | Promotion verified | Verify compatibility, playtest and release | CB-07 | Load existing character/Garden fixtures, reject mismatched co-op builds, and verify host plus three guests through crafting, a heal, death, revive, checkpoint and extraction. Compare logged applied amounts and HP revisions, run the major-release suite, and update only the highest revision EXE after package verification. Record live balance evidence and any remaining tuning. |

```mermaid
flowchart LR
  CB00[Audit] --> CB01[HP units and baseline]
  CB01 --> CB02[Warden and Orchard prototype]
  CB02 --> CB03[Weapons and components]
  CB03 --> CB04[Classes and skill trees]
  CB04 --> CB05[Core skills and cards]
  CB05 --> CB06[Enemy and depth balance]
  CB06 --> CB07[Healing and health presentation]
  CB07 --> CB08[Co-op, playtest and release]
```

## CB-01 implementation and numeric ownership

The shared [combat vitals service](../combat_vitals.gd) now owns damage clamping, health restoration, the max-health floor, revival eligibility, floor recovery, the party HP ceiling, boss phase thresholds and the numeric inputs to threat and Wilds learning. Live calls use the shipped unit. The [baseline fixture](../tests/combat_vitals_baseline.gd) exercises the same calculations with 10 HP per authored point and verifies fine-grained vitals against the current revision merger.

| Boundary | Authored and runtime quantities | Conversion owner for CB-02 |
|---|---|---|
| Player spawn, travel, purchases and loadout changes | Base maximum, flat max-HP bonuses, spent revival capacity and grants to current HP. Initialize, restore or clamp current HP after resolving the maximum. | Resolve base plus equipped/earned bonuses once when producing runtime max HP. Apply capacity loss in runtime HP. Max-HP adjustments stay distinct from ordinary healing. [Player lifecycle](../game.gd), [Expedition life](../expedition_life.gd). |
| Player hit, block and fall | Enemy definitions, cycle bonuses, fallback and hazard values are authored damage. Guard, brace, hit grace and status duration have their own units. Direct damage writes also drive vitals and transaction state. | Pass the resolved hit amount into the player damage boundary once. Keep confirmed applied damage separate from attempted damage. Preserve guard charges, stagger, hit grace and transaction semantics. [Player combat](../game.gd), [Traits](../combat_traits.gd), [Boss hazards](../boss_encounters.gd). |
| Player weapon, skill and trait hits | Weapon/part/graft/class/card contributions, wind-up and mark bonuses, link and echo coefficients, armor and boss vulnerability, and per-pulse hit amounts. | Keep the authored source data and tag/timing rules legible. Resolve and round ordinary strike amounts at commitment for the prototype. Apply target-side adjustments at contact. Convert legacy skill and follow-up amounts once at the damage boundary. Carry the resolved roll on the attack record. [Weapon stats](../weapon_system.gd), [Mouse attacks](../mouse_combat.gd), [Core effects](../core_skill_effects.gd), [Marks](../core_strike_mark.gd). |
| Enemy pool and sustain | Scout and gate HP growth, boss HP, juvenile fixed HP, reinforcement spawns, and Pallbearer recovery. Phase checks compare current HP with full capacity. | For parity, preserve the existing integer co-op ceiling before projecting the resulting pool. The floor-10 Orchard example is 61 → 610 in solo and 146 → 1460 with four players. Apply enemy healing against that runtime maximum. [Director](../combat_director.gd), [Enemy support](../enemy_support.gd). |
| Healing | Floor and biome recovery, Renewal ticks, direct class and Core heals, siphons, pools, and on-kill restoration. Some effects compute their potency from hit counts or skill ranks. | Resolve potency using the source's authored effect, then clamp applied HP against current capacity. Preserve independent tick, target and charge limits. A four-HP regeneration tick is a deliberate prototype change. [Core effects](../core_skill_effects.gd), [Subclass combat](../subclass_combat.gd), [Trait events](../combat_traits.gd). |
| AI and learning | Burst evidence starts at 3 authored points. Ranged evidence starts at 2 authored points and requires at least two thirds of applied damage. Threat uses pre-overkill damage. | Project absolute thresholds to 30 and 20 HP. Normalize damage before adding threat to preserve its current weighting and cap. Keep the ranged ratio and required hit counts in their own units. [Settlement](../game.gd), [Director](../combat_director.gd). |
| UI, wire and persisted state | Health and capacity in reliable vitals and movement snapshots, enemy HP in public encounter data, damage events and health HUD. Profiles hold loadout IDs and node masks, which resolve on spawn. | Use one runtime HP scale across a preview session and all its peers. Keep health revision and damage sequence semantics. Version the preview compatibility when wire values change and record the scale for log analysis. Preserve save IDs and current schema for numeric values resolved from content. [Network view](../network_presentation.gd), [Compatibility](../network_compatibility.gd), [Content IDs](../content_ids.gd). |

For the parity fixture, authored additions, legacy caps and the legacy rounding order stay intact through conversion. Later milestones can move individual entries to native HP and tune their breakpoints. Durations, multipliers, distances, charge counts, level thresholds and the percentage phase checks keep their own units.

## CB-02 playable preview

Launch the verified preview with the `--combat-balance-preview` game argument after Godot's `--` separator. The [preview shortcut](<../Mystical Garden - CB-02 Preview.lnk>) supplies both arguments. Host and guests use that same shortcut. The handshake compares the HP scale before registering a peer. The preview menu uses its own save and character slots under `user://combat-balance-preview/`.

| Area | Preview behaviour |
|---|---|
| Starting vitality | 100 HP. The primary liquid orb has an exact readout and briefly marks the amount gained or lost. Revival costs 20 maximum HP for the expedition. The gold level mark shows where the reduced capacity ends. |
| Party UI | A small static orb beside each teammate's name and exact HP. The fill and reduced-capacity mark follow the same scale as the main orb. Fallen players retain the skull indicator. |
| Warden | Rootblade starts at 8–12 damage and Heartwood Maul at 17–23 before parts and bonuses. The host locks one roll for each committed strike, including all targets struck by that action. The crafting preview and Tab summary use the same range. The slice verifies Warden Guard and a deterministic Thorn Line hit. |
| Recovery | Oracle Renewal uses a provisional 4 HP tick to exercise small changes. Other existing heals and damaging effects use converted values so the preview can be played with the current roster. Healing budgets and individual content tuning remain separate milestones. |
| Orchard | Enter from the Wilds gate and play through to floor 10, where the Orchard is guaranteed in the preview. The legacy co-op ceiling is applied before projection. Its health phases and vulnerability window use the same thresholds. |

Implementation uses the shared vitals calculations from CB-01 and a single runtime HP scale for the session. Plant, class, and enemy catalogues retain authored points during this slice. Weapon roll randomness is separate from map, loot, and graft randomness. Diagnostics attach the HP scale to damage and life changes. The log analyser handles both scales.

**CB-02 evidence.** The 22 affected source suites passed across focused and connected validation, with 115 results reused. The ordinary solo route smoke passed on retry after an intermittent progression failure. All 26 selected package checks passed, including preview host/guest health, rolled damage, mixed-mode rejection, and the four-player smoke. A separate packaged launch with the preview flag created the isolated save directory. Rendered checks covered a small Renewal tick, lost capacity, and a fallen teammate. Live tuning remains open.

## CB-03 weapon and component rollout

All 15 weapons now have an authored spread around their existing average damage in the preview. The range is resolved from the equipped weapon, the Core, Form and Catalyst weights, the monster graft, and applicable bonuses. Crafting, graft candidate comparisons, and the expedition summary use the same range. Conditional effects still resolve at contact.

| Class | Starting weapon ranges in HP |
|---|---|
| Warden | Rootblade 8–12, Briar Spear 8–12, Heartwood Maul 17–23 |
| Weaver | Spore Staff 8–12, Thorn Wand 9–11, Seed Focus 7–13 |
| Ranger | Vine Bow 8–12, Bark Arbalest 16–24, Thorn Ring 8–12 |
| Reaper | Graft Knives 9–11, Harvest Scythe 7–13, Root Lash 8–12 |
| Oracle | Bloom Bell 8–12, Spore Censer 7–13, Petal Fan 9–11 |

A weapon's `roll_spread_hp` lives beside its base damage in the class catalogue and in the weapon template. The current spread choices are provisional. The direct strike roll is captured on the host at commitment. Its snapshot follows melee, piercing, fan, splash and chain contacts. Echo and linked follow-ups use a portion of that captured strike, with their own effect bonuses. Chorus Pulse uses its authored potency. Wind-up damage, marks, shatter, armor and exposed-boss bonuses remain contact effects.

All 48 plant components and 24 monster grafts retain their stable IDs. Fractional contributions from Form and Catalyst survive until conversion into integer HP at the hit, heal or maximum-health boundary. A half-strength Heartwood Barb contributes 5 HP to both ends of the range. Inventory shows the full Core-slot effect for plant parts, and the weapon preview shows the equipped result. The existing counters, durations, reach, tags, charge counts, and caps retain their original units. Replacing a graft changes maximum HP immediately when applicable and clamps current HP to that ceiling. In-flight strikes retain the graft and power captured at commitment.

[Weapon catalogue](../class_catalog.gd), [Weapon template](../assets/data/weapon_template.json), [Preview rules](../combat_balance_preview.gd), [Weapon resolver](../weapon_system.gd), [Traits](../combat_traits.gd), [Roster and delivery fixture](../tests/weapon_balance_preview.gd).

**CB-03 evidence.** All 27 affected source suites passed across focused and connected validation, with 111 unaffected results reused. All 19 selected package checks passed, including the grafted projectile roll on a guest and four-player play. The packaged executable also launched into the isolated preview save directory. The [CB-03 preview shortcut](<../Mystical Garden - CB-03 Preview.lnk>) uses the same preview save directory as CB-02. Use the same CB-03 executable with preview enabled on every co-op machine. Live tuning remains open.

## CB-04 class skills and progression

The preview keeps the five class kits, 15 subclass focuses, ten base skills, ten legacy replacement entries, and all 120 learned-node positions. Current and legacy profiles use their existing masks and skill identifiers. Existing direct damage keeps the 10 HP per authored point baseline. Class follow-ups, periodic effects, and delayed hits apply their authored potency. Weapon-based skills such as Gale Volley and Reaping Step use the committed weapon roll plus their flat skill bonus. Expedition power is applied once to direct or delayed class hits. Enemy armor, active conditions and other conditional weapon effects still resolve at contact.

Healing and guard use separate rules. Base Renewal restores 20 HP before equipment bonuses and applies its 4 HP regeneration ticks. Positive class healing fields use 4 HP per tick for each authored point. Living Sanctuary applies equipped class healing to its opening cast and leaves a cleansing pool. Blood Harvest drains 6 HP per contact up to 18 HP, or 24 HP with its extra-contact node. Legacy Siphon Cut and Blood Moon keep their existing per-cast cap converted to 30 HP. Guard continues to block a number of hits, with duration measured in seconds. Class-duration bonuses also extend deployed class traps and fields in the preview.

The skill bar and crafting view use the class resolver for their numeric descriptions. The tree previews subclass skills and learned legacy effects in HP. Stats shown as base damage leave room for conditional effects such as a consumed Mark, armor, or Foretell's wind-up bonus. An equipped Oracle's healing bonus, or a purchased Foretell signature, updates the corresponding Wilds tooltip. The revised healing values are initial tuning for the preview.

[Class effect rules](../class_skill_balance.gd), [Class skill resolver and descriptions](../skill_catalog.gd), [Subclass combat](../subclass_combat.gd), [Legacy and current class tree](../progression_panel.gd), [Class balance fixture](../tests/class_balance_preview.gd).

**CB-04 evidence.** The focused and connected passes covered the 40 affected source suites, with 99 unaffected results reused. All 28 selected packaged checks passed, including the guest Oracle restoring 20 HP to both players and seeing the synchronized skill cooldown. A packaged startup verified the isolated preview save directory. The [CB-04 preview shortcut](<../Mystical Garden - CB-04 Preview.lnk>) reuses the previous preview saves. Every peer must use the CB-04 executable with the preview enabled. Final healing and damage tuning remains open.

## CB-05 Core skills and checkpoint upgrades

The 24 species signatures, 70 slot interactions and 166 checkpoint cards retain their authored identifiers. Core casts capture the resolved weapon form, slot interactions and owned cards at commitment. Direct hits, repeated field contacts, delayed effects, marked hits and linked damage retain fractional authored amounts until they reach the HP boundary. The committed weapon roll stays independent of Core damage. Enemy armor and vulnerability still resolve at contact.

Core damage and direct ally heals retain the 10 HP per authored point baseline. Blood Siphon starts at 6 HP per damaged enemy, up to 12 HP or 18 HP with its matching Catalyst. Riptide applies its heal on the return sweep, once per living ally. Its Water Catalyst increases that heal from 10 to 20 HP before the health cap. The figures are initial tuning for the preview. Control effects keep their original duration, target cap, and ward charges.

Crafting and the Wilds skill bar describe the resolved hit, heal, mark and pulse amounts. Checkpoint offers and purchased-card tooltips format HP separately from timing, distance and count effects. The Tab summary shows the final attack range, aggregate combat stats, and the resolved Core. Rank stacking, weighted offers, slot requirements, prices, and limits use the existing purchase rules.

[Core effect amounts and descriptions](../core_skill_balance.gd), [Core cast effects](../core_skill_effects.gd), [Checkpoint catalogue](../run_upgrade_catalog.gd), [Tab summary](../run_summary_panel.gd), [Core balance fixture](../tests/core_balance_preview.gd).

**CB-05 evidence.** All 30 affected source suites passed, with 110 unaffected results reused from the initial plan. The preview co-op fixture passed after its party-orb assertion was updated to wait for the rendered state. All 24 selected packaged checks passed. The guest Riptide test confirmed the Catalyst-adjusted 20 HP heal for both players and matching tooltip text. The [CB-05 preview shortcut](<../Mystical Garden - CB-05 Preview.lnk>) reuses the prior preview save directory. Every co-op peer must use the CB-05 executable with the preview enabled. Live tuning remains open.

## Healing rolls before CB-06

Direct class and Core heals, heal-on-kill effects, floor recovery, and enemy restoration use a uniform integer roll around their previous preview amount, ordinarily ±2 HP. Renewal, healing-pool pulses, and drain totals use ±1 HP. A heal centered on 20 HP is 18–22 HP, and a Renewal tick centered on 4 HP is 3–5 HP. Flat healing bonuses adjust the midpoint before rolling. Very small heals use a narrower spread to preserve the minimum of 1 HP without increasing their average.

The host uses a separate healing random stream. A party heal, pool pulse, or floor recovery shares one result across eligible recipients. A moving Riptide wave or lingering Worldbloom canopy retains its roll for each later contact. Renewal rolls on each recipient's tick. Drain rolls once around the total earned from qualifying contacts. Each applied amount clamps to the recipient's current maximum. Revival, capacity changes, and resets still apply their exact values. Earlier milestone examples record the previous fixed amounts, which now serve as the midpoints.

Crafting, skill and checkpoint tooltips, and Tab distinguish resolved healing ranges from flat bonuses to healing. Detailed diagnostic traces record rolled and applied HP for player heals. CB-06 remains next, with the new ranges in place for encounter tuning.

[Shared healing rules](../combat_balance_preview.gd), [Class descriptions](../skill_catalog.gd), [Core effects](../core_skill_effects.gd), [Preview fixture](../tests/combat_balance_preview.gd).

**Healing roll evidence.** All 37 affected source suites and 27 selected packaged checks passed. The fixtures cover the full integer range, separate random streams, shared recovery, late canopy entrants, overheal, revival and the exact host roll on guest vitals. The [Healing Rolls preview](<../Mystical Garden - Healing Rolls Preview.lnk>) uses the previous preview saves. These spreads are starting values for playtesting.

## CB-06 enemy and expedition scaling

The preview uses per-species starting HP and contact damage across 20 regular enemies and four bosses. The regular curve combines floor depth, growth tier, and completed loops. Elites use the chosen species' base HP and get a premium at the end of each biome. Juveniles have a separate durability and damage curve. Each additional player adds up to three scouts, subject to the 20-scout limit. Regular HP gets a smaller per-player multiplier than elite and boss HP. The host fixes the encounter's party size at spawn so a mid-fight departure cannot rewrite enemy capacity.

A seeded expedition sample captured the following live spawn budgets. Total HP includes the elite and opening scouts.

| Floor | Solo scouts | Solo total HP | Four-player scouts | Four-player total HP |
|---|---:|---:|---:|---:|
| 1 | 6 | 250 | 15 | 799 |
| 6 | 7 | 471 | 16 | 1,403 |
| 18 | 11 | 1,125 | 20 | 3,060 |
| 19 | 10 | 1,004 | 19 | 2,893 |
| 48 | 12 | 2,006 | 20 | 5,915 |
| 72 | 11 | 2,294 | 19 | 7,167 |

Base regular attacks range from 7 HP for the Wicker Wasp to 19 HP for the Gravebud Colossus before depth scaling. A Rootbound Pilgrim deals 10 HP on floor 1 and 28 HP on floor 48 before elite bonuses. Boss attacks use distinct move and phase bonuses. Primary boss hazards take 70% of their move's hit and follow-up hazards take 50%, rounded to whole HP. Armor reduces the current hit by about a quarter. A successful boss opening adds 30% damage, with a 3 HP minimum bonus. The phase thresholds remain at 65% and 30% of the spawned health pool. The preview stages the Orchard on floor 10 for balance testing.

Reinforcements begin after the first biome loop. Arrivals have 75% of regular scout HP and use existing nonrewarding spawn rules. Successful waves cap at two per floor on the first loop, increasing to five in deeper loops. The warning lasts three seconds and the interval has a 22-second lower bound. A blocked warning site cancels the arrival. Pallbearer corpse healing still rolls and restores at most a quarter of its own capacity per corpse.

[Species catalogue](../assets/enemies/catalog.json), [Preview scaling data](../assets/enemies/preview_scaling.json), [Enemy balance resolver](../enemy_balance.gd), [Reinforcements](../expedition_pressure.gd), [Encounter balance fixture](../tests/enemy_balance_preview.gd).

**CB-06 evidence.** All 36 affected source suites and 31 selected packaged checks passed. The seeded fixture covered floors 1 through 72 at party sizes one, two and four, each boss phase and opening, and the finite reinforcement budget. A connected preview guest confirmed the 960 HP two-player Orchard and its 26 HP march hit. Four-player packaged connection and play checks also passed. The [CB-06 preview shortcut](<../Mystical Garden - CB-06 Preview.lnk>) reuses the existing preview save directory. Live difficulty and clear times remain open for playtesting.

## CB-07 expedition sustain and health feedback

Gate recovery rolls around 10 HP on ordinary gates and 20 HP when crossing into another biome. Each completed loop adds 3 HP to the midpoint, up to a 9 HP bonus. Entering the biome's final encounter uses ordinary recovery. The party shares the gate roll, and Tab shows the upcoming range. In the seeded two-floor fixture, ordinary recovery on loop two was 14–18 HP and the biome crossing was 24–28 HP, enough to offset part of the incoming 28 HP contacts without erasing attrition.

Heal-on-kill effects can restore up to 24 actual HP per player per floor. Overheal spends only the amount restored. Summons and reinforcements provide no kill or drain healing. Drains continue to scale with the number of qualifying contacts. A weapon-generated Tide pool with one point of potency restores 3–5 HP each second, and two points restore 7–9 HP. Renewal still rolls 3–5 HP per tick. Reapplying Renewal preserves its scheduled tick and can extend its duration. Direct ally heals keep their rolled ranges and share one result across each cast, wave, or canopy.

Applied healing appears as a green number and uses the host's confirmed combat event. Heal and damage feedback remain separate when both happen before a vitals snapshot. The main orb highlights recovery and labels sealed maximum HP. Party orbs keep their static readout and fallen skull. Spectating shows the watched ally's current HP. Revival still fills the reduced pool after subtracting 20 maximum HP, including when a checkpoint upgrade has increased the ceiling.

[Expedition sustain](../expedition_sustain.gd), [Health orb](../health_orb.gd), [Vitals replication](../network_presentation.gd), [Expedition sustain fixture](../tests/expedition_sustain.gd).

**CB-07 evidence.** All 39 affected source suites and 30 selected packaged checks passed. The host/guest fixture verified two exact feedback numbers when healing and damage cancel in a single host step. The sustain fixture verified gate recovery across two deep floors, overheal accounting, summoned enemy eligibility, and revival after a 20 HP checkpoint upgrade. Rendered checks at 1100 × 720 verified the main orb, compact party orb, and spectator panel below the floor legend. The [CB-07 preview shortcut](<../Mystical Garden - CB-07 Preview.lnk>) uses the prior preview save directory. Live sustain tuning remains open for CB-08 playtesting.

## CB-08 compatibility and release checks

The isolated compatibility check opens Garden and character saves through Continue with the new balance active. It covers both current-format files and pre-manifest files, including planted beds, inventory, character identity, class XP and loadout. An additional check writes a fixture with the installed Windows build and reads it with the candidate. Ordinary and preview saves stay in separate directories during playtesting.

The four-player fixture covers the shared crafting stock, travel votes, an actual Core cast, private monster rewards, Renewal, lethal damage, guest-to-guest revival, checkpoint cards, extraction and reconnect. It compares current HP, maximum HP, sealed capacity, fallen state and damage sequence at the same authoritative revision on all three guests.

**CB-08 evidence.** All 143 source suites have passing evidence from the full run and the focused recheck of the solo smoke fixture. The solo fixture now checks both combat roles on floor four and uses a fixed target when testing the checkpoint. All 110 packaged checks passed, plus startup smoke. The installed v0.5.3.1 Windows build generated a save that the candidate continued at 100 HP with progression intact. The protocol 31 installed build and protocol 38 candidate rejected each other in both directions, with compatibility guidance for the guest.

The four-player run matched 39 of 39 comparable guest vitals revisions. The host recorded 35 HP damage, a 4 HP Renewal tick, 69 actual HP lost to a lethal hit, an 80/80 HP revival and restoration to 100 HP after extraction. The analyzer now exports rolled and applied healing, distinguishes overkill from HP lost, and compares sealed capacity at matching vitals revisions. This was scripted loopback play.

### Live playtest

Open the [CB-08 playtest shortcut](<../Mystical Garden - CB-08 Playtest.lnk>) to use the existing combat preview saves. For friends, share the [portable Windows ZIP](<../.godot/release/Mystical Garden - CB-08 Playtest.zip>). Extract both files together and run `Start CB-08 Playtest.cmd`.

### Promotion to ordinary play

The release candidate enables the health orb, rolled damage and healing, and revised enemy scaling on normal launch. It opens the usual Garden and roster slots. The playtest argument still selects separate saves and the guaranteed floor 10 Orchard for testing. Normal expeditions retain rare boss selection. New Garden opens the character creator if the selected slot is empty, then resumes Garden setup. The save compatibility fixture exercises that flow on a fresh profile as well as Continue with current and legacy saves. Co-op uses protocol 39 and requires everyone to update. Keep the native companion DLL beside the EXE when distributing the promoted build.

Promotion evidence covers all 146 source suites and 113 registered packaged checks plus packaged startup. The final source run was `cb08-live-source-31e5d69e6dc2` and the final package run was `cb08-live-package-d71d073cfa92`. Legacy numeric assertions explicitly exercise the 10-point path. The default combat, fresh Garden, old-save Continue, and four-player fixtures cover the promoted path. Six co-op fixtures now use the existing leave lifecycle before freeing their world to prevent late RPC errors. Full runs used isolated saves. Live tuning beyond the Developer Garden playtest remains open.

Run a solo Warden expedition and a four-player expedition with all peers on the same candidate. Keep the same loadouts for a repeat if one fight feels off. Note the class, weapon and Core if a build performs differently from the rest.

| Playtest segment | Evidence to capture |
|---|---|
| Floors 1–6 | Clear time, party HP when each gate opens, damage and healing at the next gate, and which packs felt stalled or overwhelming. |
| First Orchard encounter | First hit taken, which telegraphs were readable, how often a player could safely attack, and what forced a retreat, down or revival. |
| Beyond the first biome loop | Whether reinforcements build pressure, how often kill healing hits its floor limit, and whether gate recovery changes the decision to extract. |

Enable detailed tracing in Settings → Diagnostics before each run. Mark a problem when it happens and export the host and guest reports at the end of the expedition. The [log analyzer](../tools/log_analysis/README.md) compares applied damage and healing with recorded HP and matches host and guest vitals by revision. Use the notes and logs together to decide which balance values to change before promotion.

## Verification plan

Use the [interaction tree](MECHANICS_TEST_MAP.md) and [validation workflow](VALIDATION_WORKFLOW.md) as each milestone lands. The suite names below are existing starting points. Confirm ownership and the actual connected plan after the code changes. Add targeted coverage for new invariants and run the full suite at the major release gate.

| Work | Existing starting checks | New behaviour to verify |
|---|---|---|
| HP, orb, recovery and revival | `health_points`, `player_hud`, `loot_revival`, `loot_revival_coop`, `party_hud_gates_coop` | Exact small ticks, partial fill, cut-off max capacity, deterministic clamping and no duplicate heal or damage feedback |
| Weapons and class progression | `classes_weapons`, `class_depth`, `class_depth_coop`, `subclass_skills`, `weapon_actions_coop`, `mouse_combat_coop` | One roll per committed attack, preview/combat parity, in-flight changes, explicit stat units and legacy masks |
| Core, upgrades and tooltips | `core_roster`, `core_roster_coop`, `core_signatures_coop`, `weighted_upgrades`, `content_validation` | Typed values across nested effects, per-cast hit caps, tooltip totals, stable card behaviour and graft eligibility |
| Enemy pressure and bosses | `combat_balance`, `enemy_roster`, `enemy_support`, `gate_elites`, `wilds_skill_tactics`, `expedition_pressure_coop`, `boss_lairs`, `boss_coop` | Threshold parity, expected hits to kill, party scaling across loops, telegraphed damage, and no runaway sustain or reinforcement cycles |
| Co-op, saves and evidence | `network_presentation`, `diagnostics_coop`, `four_players_coop`, `supplied_network_smoke`, `playable_solo` | Reordered vitals and duplicate events, old/new logs, existing saves, transaction rollback, mixed-build rejection and packaged play |

**Audit evidence.** Traced the current source and loaded the catalogue definitions with a read-only headless fixture. CB-01 is complete. Its focused and connected plans ran 26 affected suites across both passes, with 109 unaffected results reused. Coverage included the 10- and 100-point baseline fixture, current combat and revive behaviour, boss lairs, Core skills, upgrade cards, exact vitals and the host plus three guests. The 100-point pool is exercised in fixtures at this stage. CB-02 brings it into the playable prototype. Prototype numbers are starting points. Combat feel, healing limits and the final difficulty curve require playtesting.
