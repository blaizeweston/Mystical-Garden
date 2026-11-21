# Combat balance and vitals milestones

The approved card/progression contract below is the maintained design authority for the next catalog phase, reconciled on **2026-11-20**. It distinguishes implemented mechanics, approved future mechanics, provisional tuning and unresolved decisions. [ARCHITECTURE.md](ARCHITECTURE.md) remains the implementation/ownership reference; executable values remain in their named content definitions.

The later milestone records retain their historical context, including the 2026-11-12 v0.5.3.1 balance audit. Their old opt-in modes, priced cards, installed grafts, launch instructions and verification results are not the current gameplay contract and do not authorize restoring retired runtime paths.

## Plant-affinity rework contract

Modern affinity combat is the sole gameplay implementation. Core, Form and Catalyst have distinct responsibilities and cooperate through their affinity's authored shared-effect rules. Plant supporting tags are eligibility facts for future cards; they do not grant another affinity's baseline abilities. Historical profile conversion is separate from retired gameplay execution.

### Approved card and progression design

#### Verified source boundary and status labels

| Reference at this review | Verified state |
|---|---|
| Local `main` | `e1265e0dd750c4b1d63382921d574ccf11fd0562`; modern-only gameplay, before the shared-affinity rework. |
| Reviewed affinity implementation | `combat/affinity-scaling-foundation`, `12d54b6251db5917cd67741890f2f01fcd5c24cb`; six commits ahead of `main`, with shared statuses and scaling corrections. These changes have **not** been integrated into `main`. |
| Original design baseline | `design/card-catalog-baseline`, `c2fc7415603fb8b5b7863749a165006a3637cb9c`, changed only this reference and its architecture pointer. |
| CE01 consolidation | `combat/ce01-card-eligibility` starts at `ab2e82ee8c811acaff00ac55353202190ee03502`: affinity implementation `12d54b6` plus the focused cherry-pick of `c2fc741`. `main` and both source branches remain unchanged. CE01 implements requirements for the existing 28 cards, not transformations. |
| **Implemented** | Present in the reviewed source. Where `main` differs, the distinction is stated explicitly. |
| **Approved, unimplemented** | The design direction is accepted, but the card/action/consumer is not playable yet. |
| **Provisional** | Current or illustrative numerical tuning, not a permanent balance promise. |
| **Unresolved** | A specific policy or parameter still needs a decision before implementation. |

#### Permanent expedition and progression constraints

Players choose their class, starting focus, connected class-tree selections, weapon and Core/Form/Catalyst plant parts **in the Garden before entry**. Those choices and every equipped plant's primary and supporting affinities remain locked for the entire expedition. Cards must not depend on changing equipment, class, focus or tree selections mid-run. Acquired cards and graft adaptations are the sources of build evolution during the expedition.

All five classes begin at level 1 with zero Class XP and an explicit starting-focus choice; no plant part, graft, card, currency or completed expedition is required for useful native Q/R. The six-selection structure is one focus plus one connected choice in each of five successive tiers. Same/adjacent lanes connect; Balanced connects to all three. No backfilling or second capstone is permitted, and crossing branches preserves the starting Q.

Class XP can be earned in the Wilds, but newly earned selections, respec and class-tree changes wait until the Garden. Permanent Class XP is separate from expedition Essence. Historical investments retain their explicit Heart refund/conversion boundary and idempotent whole-number XP conversion; no automatic redistribution or obsolete combat fallback is authorized. The current XP thresholds **0, 50, 150, 350, 1400, 2600** are provisional pacing, not a redesign in this phase.

Current enforcement is in [class_tree_access.gd](../class_tree_access.gd), `Game.handle_loadout_action`, `select_class`, `at_weapon_gate` and [connected_class_tree.gd](../connected_class_tree.gd). The card ledger's ability to project an equipment-dependent card as inactive remains useful defensive/compatibility behavior and a fixture surface; it is not permission for normal mid-expedition equipment changes.

#### Mandatory eligibility before offer weighting

A player must never receive an offer their current build cannot use. Eligibility is a **mandatory filter**, applied before identity weighting and rarity. Host generation, rerolls and acquisition must use the same actual prerequisites and effective-headroom policy; the description must accurately explain the resulting effect.

| Required eligibility facts | Design rule |
|---|---|
| Locked class, focus, weapon and tree | Check exact identities, learned selections and the actual native actions they provide. A class or tag name is not a substitute for a functioning ability. |
| Equipped plant slots and tags | Identify Core, Form and Catalyst separately. There are exactly two roles: `primary_affinity` and unordered `supporting_affinities`. Both influence eligibility; there is no secondary/tertiary rank and no inference of scope from a raw union of tags. |
| Existing mechanic/capability | A card that modifies an existing mechanic must verify that the build can produce it. Alternatively, the offered card may explicitly grant that missing capability as part of its stated effect. All other requirements still apply. |
| Acquired cards and transformations | Their explicitly granted capabilities can open new eligible cards. Previously acquired Unique cards are excluded. Do not guarantee a transformation or construct a complete synergy build automatically. |
| Graft adaptations | Check acquired, functioning adaptations rather than merely carried trophies or unrelated species tags. Graft acquisition can expand the eligible pool. |
| Resource generation | Temporary depletion does not disqualify a reachable effect. An empty Bark pool or spent Vital bonus HP can be replenished by a real producer; lacking that producer is a different condition. |
| Acquisition and effective headroom | Respect current copy/acquisition restrictions and resolved usefulness. Do not offer entirely ineffective numerical contributions. Eligibility and offer weighting/rarity remain separate decisions. |

Supporting affinities **do not** automatically grant baseline abilities, effects or status producers. For example, Dewcap's Vital supporting tag can qualify an explicitly authored future interaction, but does not itself grant Vital bonus HP or regeneration and therefore cannot alone satisfy a requirement for those mechanics.

The initial loadout stays fixed, while eligibility may expand through acquired cards and grafts. CE01 expresses these requirements as readable data; this does not make any future card or transformation playable.

Current source reconciliation:

- [card_requirements.gd](../card_requirements.gd) implements pure `all`, `any`, class/focus/weapon/node, plant, same-plant `tags_all`/`tags_any`, `distinct_slots`, capability and acquired-card/graft predicates. [card_eligibility.gd](../card_eligibility.gd) derives detached facts and valid IDs from current executable build/class/adapter/acquisition definitions. No Game or actor enters the evaluator.
- [affinity_card_ledger.gd](../affinity_card_ledger.gd) remains the offer/acquisition authority. It revalidates predicates, verified grants, copy/Unique limits and numerical headroom. Its former scope-specific requirement switch is removed. All 28 definitions use the same expression model while retaining their existing restrictions and values.
- [plant_affinities.gd](../plant_affinities.gd) retains `primary_affinity` and normalized, sorted `supporting_affinities`; sorting does not establish rank. [affinity_build.gd](../affinity_build.gd) exposes the same plant facts and the selected connected path. Card counts and graft purchase counts are detached projections of existing receipts, not new ownership stores.
- Capabilities identify real Core skills, Form behaviors, native action names/modes and Catalyst response IDs. `target_scope` preserves a native adapter's footprint; it is not falsely treated as a response's protection/healing recipient. Explicit `recipient` metadata is supplied by the relevant verified grant consumer. No generic Bark/Burning resource producer is inferred from a tag or an animation.
- `requires` tests current facts only. `grants` names implemented additions advertised by the real consumer's `CARD_GRANTS` parameter/method contract. Dew Shelter and Echoing Growth demonstrate this boundary. Candidates do not count themselves as acquired; unknown IDs, unsupported consumers and circular dependencies fail closed. Future transformations need their own implemented consumers before any grant declaration can validate.
- Initial and replacement offers may contain zero to three distinct useful identities. A paid reroll still requires at least one new identity, never rarity-only replacement. No replacement means no debit. Reopening stays cached, and zero-useful-card checkpoints retain Continue/Skip and ordinary travel.

#### Shared affinity mechanics and scaling

A normal build should be viable. An exceptional, specialized build should be capable of becoming exceptionally powerful. Rare and unusually strong class/weapon/plant/card/graft combinations are intentional, not automatically balance defects. Do not impose arbitrary absolute power ceilings or aggressive diminishing returns that invalidate further investment.

Distinguish **material baselines**, **build-derived resource/potency limits**, **mechanical thresholds** and **technical safeguards**. Retain three-stack Brittle and Saturation's Surge threshold. Protect against recursion, invalid/stale identities, overflow and excessive computation without disguising a gameplay ceiling as a safety check. Core/Form/Catalyst and multiple players cooperate through one appropriate enemy- or recipient-owned effect; attribution and secondary-hit lineage remain explicit.

| Affinity | Approved foundation | Implemented state at `12d54b6`; numerical tuning remains provisional |
|---|---|---|
| Thorn | One enemy-owned Bleed; cumulative, difficult buildup and high eventual damage. Shared cap derives from contributing players' personal build potency. | [thorn_affinity.gd](../thorn_affinity.gd), `affinity_cards.affinity_values`: ordinary/refined **12/18 damage per tick** are baselines, not absolute ceilings. Matching slot upgrades contribute once to personal potency. Core/Catalyst add 25%, Form 10%; stronger caps require new buildup and cannot promote accumulated damage for free. |
| Frost | One shared three-stack Brittle sequence; each source freezes one third of its shatter potency; deterministic rupture, no baseline root. | [frost_balance.gd](../frost_balance.gd), [frost_combat.gd](../frost_combat.gd): **12/21** baseline shatter potency; **three stacks** is the rupture threshold, not a damage ceiling. |
| Fire | One fast-ticking shared Burning intensity; cumulative applications and ongoing decay. | [fire_combat.gd](../fire_combat.gd): former **96-stack** ceiling removed. Core/Form/Catalyst apply **16/8/12**, refined adds four before cards. **0.125 damage/stack every 250 ms**; each 500 ms lose 10% rounded up, at least eight stacks, limited by the amount present. Work is per contributor, not per individual stack. |
| Water | Bounded Drenched defense, shared Saturation, weighted outgoing damage / returning restoration with overflow. | [water_combat.gd](../water_combat.gd): **100 pressure** triggers a Surge; baseline **6 damage / 6 healing**, distributed by actually consumed source pressure. CE03 Tidal Return replaces the former radial hit with player-originating outgoing/return waves. Application, independent potency/coverage and duration have explicit consumers. Drenched uses strongest **18%/30%** reduction, bounded at 30%. |
| Wood | Recipient-owned cooperative Bark protection; actual independently expiring capacity, partial absorption and depletion. | [wood_affinity.gd](../wood_affinity.gd): former **48-capacity** ceiling removed; full valid grants add. Core **30/40**, Catalyst **12/18**; **40%** partial absorption remains. No invulnerability or new armor system. |
| Vital | Temporary Max HP and regeneration without free healing; bonus capacity stays distinct from non-Vital capacity. | [vital_combat.gd](../vital_combat.gd), [player_vitals.gd](../player_vitals.gd): strongest live capacity and regeneration resolve independently; baseline **12/18 Max HP**, **3/5 HP/s**. `harvest_plan` and immutable HP expenditure exist only as a foundation, not a playable transformation. |
| Storm | Chain discharge, falloff, arcs and source-owned charges. | [storm_affinity.gd](../storm_affinity.gd): existing Chain Spark, Arcing Strikes and mapped Catalyst responses remain unchanged. Conductor is not implemented. |
| Spirit | Terrain-legal movement, Spiritstride, traces and movement-prepared follow-ups. | [spirit_affinity.gd](../spirit_affinity.gd): existing actions remain unchanged. These are not Mirrorstep's accumulated echoes. |
| Void | Gathering, compression, collapse and validated displacement with native/graft arbitration. | [void_affinity.gd](../void_affinity.gd): existing Gravity Well and responses remain unchanged. They are not the additional Singularity action. |

The implemented 28-card catalog has only three definition changes relative to `main`: Sawtooth Briars now raises the personal shared-Bleed cap; Hotter Embers and Heart of Cinders now add Burning **stacks per application** instead of damage per tick. Their IDs, copy counts and rarity numbers remain unchanged. [affinity_card_catalog.gd](../affinity_card_catalog.gd) owns the values; `ResolvedCombatBuild.Snapshot.affinity_potency` and `affinity_cards.affinity_values` feed actual actions and resolved equipment descriptions. Old stacks do not acquire later upgrades for free. Historical per-slot Bleed/Burning and 48-capacity wording below must not be applied to the reviewed newer source.

#### Approved working transformation catalog

CE02/CE03 implement Bloodletting, Avalanche, Wildfire, Monsoon, Splinterburst and Harvest. Conductor, Mirrorstep and Singularity remain approved directions without implementations. Current provisional tuning and focused evidence are in [ARCHITECTURE.md](ARCHITECTURE.md#second-affinity-card-expansion-ce03).

These nine transformations anchor the future catalog. They are **approved design directions**, not finished card definitions, stable card IDs, final numerical tuning or playable actions. Each is a proposed **Unique, nonstacking, once-per-expedition acquisition**. Unique is independent of numerical rarity. None is a prerequisite for a functional normal build.

| Affinity | Transformation | Type | Approved mechanic |
|---|---|---|---|
| Thorn | **Bloodletting** | Active | Extra damage based on accumulated Bleed **without consuming the shared effect**. |
| Frost | **Avalanche** | Passive | Brittle rupture spreads attributed Brittle buildup to nearby enemies. |
| Fire | **Wildfire** | Passive | Intense Burning spreads some stacks to nearby enemies. |
| Water | **Monsoon** | Passive | Surge produces additional expanding Water waves. |
| Wood | **Splinterburst** | Instant active | Consume actual accumulated Bark protection for radial damage. |
| Vital | **Harvest** | Toggle | Basic attacks spend filled Vital bonus HP for sustained additional damage. |
| Storm | **Conductor** | Passive | Chain Spark forks additional arcs and can return a reduced strike. |
| Spirit | **Mirrorstep** | Passive | Each eligible dash or movement ability creates an echo; the next basic attack releases all accumulated echoes simultaneously. |
| Void | **Singularity** | Instant active | Gravitational collapse followed by a damaging implosion. |

Active transformations unlock **additional configurable skill-bar actions**; they do not replace Core **B**, native **Q** or native **R**. Multiple transformations can coexist. Passive transformations need no extra controls. The nine transformations, their acquisitions and their extra action/toggle interfaces are **not implemented** by the current 28-card catalog.

Applications, expenditure and generated damage remain host-authoritative and use the existing status/health/defense owners. Every generated effect needs explicit source/cast/life/floor identity and proc lineage. Secondary effects cannot recursively trigger the transformation that generated them. Do not silently grant unrelated Core, Form, Catalyst, graft or class responses.

**Mirrorstep**

- Every eligible movement action generates an echo; echoes accumulate briefly.
- The next basic attack releases **all** accumulated echoes together.
- Echoes reproduce appropriately scaled weapon behavior and Form interactions. This is an explicitly authored transformation interaction, not permission for all secondary hits to trigger Forms.
- Echoes cannot recursively create more echoes or reopen unbounded proc chains.
- Do not impose an arbitrary echo-count ceiling as a balance mechanism. Expiry, valid movement/action identity and bounded execution work must provide the technical discipline; exact policies remain unresolved below.

**Harvest**

- Harvest is an optional Unique transformation, **not baseline Vital behavior**.
- Activation toggles a sustained offensive mode. Eligible basic attacks spend filled Vital bonus HP for additional damage.
- Normal HP is not spent by default. Available bonus HP is current HP above the non-Vital maximum, not unfilled capacity.
- Running out of spendable bonus HP suspends bonus damage **without turning off the toggle**. Regeneration can replenish the resource; a player may leave Harvest off and retain bonus HP for defense.
- Expenditure is a resource transaction, never incoming damage: no Guard/Ward consumption or damage-reactive response. Spending does not reduce maximum-health capacity.
- Exact expenditure and damage conversion remain provisional. The pure foundation quote's **1 damage per HP** is not live Harvest tuning. CE03 implements the attack loop at **up to 2 bonus HP per accepted launch, 2 damage per HP actually spent**, provisionally; a miss spends the launch resource, while a refused attack does not.
- **Deep Roots is deferred and must not be implemented here.** It remains a possible future modifier permitting limited normal-HP expenditure. The foundation's 50% safety test candidate is not an active card or finalized threshold.

**Splinterburst**

- Activation makes a one-time expenditure, not a sustained toggle.
- Damage depends on Bark protection **actually consumed**, never theoretical maximum capacity, ungranted capacity or a refused grant.
- Exact expenditure amount, conversion, radius and timing remain to be authored. Existing Splintering Strikes is a separate Form mechanic and does not implement this transformation.

#### Future catalog structure and readable definitions

Plan around these nine functional groups, using transformations as anchors rather than mandatory build gates:

1. General and weapon upgrades.
2. Affinity Core upgrades.
3. Affinity Form upgrades.
4. Affinity Catalyst upgrades.
5. Class and connected-focus upgrades.
6. Graft interactions.
7. Within-affinity specialization.
8. Cross-affinity synergy.
9. Unique transformations and their supporting upgrades.

Approximately **200 meaningful cards** is a planning scale, not a quota. Do not fill it with repetitive or unsupported effects. Preserve readable, data-driven authoring with one authoritative definition per displayed card and descriptive names/units.

| Required definition information | Authoring requirement |
|---|---|
| Display name and stable ID | Searchable, unambiguous identity; the transformation table does not preassign IDs. |
| Scope | Explicit General, Weapon, Core, Form, Catalyst, Class, Graft or multiple named scopes where accurate. Show scope beneath the title. |
| Required tags | State primary and unordered supporting identities, any slot constraint, and whether tags must share one plant or occupy different slots. Tags alone never imply an executable capability. |
| Required actual capabilities | State reachable triggers and prerequisites, including learned nodes, prior cards/transformations and graft adaptations where needed. |
| Effect and authoritative consumer | Name the real mechanic and its owning consumer. A stored but unused statistic is not a functioning card. |
| Numerical contribution or fixed Unique behavior | Identify scalable parameters and units, or the exact one-time unlock. No hidden unrelated changes. |
| Stacking and acquisition | State copy rules, resolved effective headroom and Unique policy independently of rarity. |
| Capability granted | Explicitly identify any new producer/action/status supplied by the card itself. |
| Shared effects and multiplayer | Describe source attribution, refresh/consumption, shared contributions, secondary proc lineage and relevant lifecycle behavior. |

#### Acquisition and balance: retain current provisional tuning

One base definition is selected before its offered rarity is rolled. Common, Uncommon, Rare and Epic copies retain their own actual contributions and add those contributions; no retroactive promotion. Earned checkpoint choices are free and may be skipped. Essence is expedition-only and pays for optional unclaimed-offer rerolls, not card acquisition. Graft improvements cost monster parts, with one successful improvement per player per altar. These are separate from permanent Class XP.

| Existing implementation | Current provisional configuration; unchanged by this document |
|---|---|
| Card pool | **28 definitions:** 26 numerical stackables and two Uniques, Dew Shelter and Echoing Growth. None of the nine transformations is an existing card. |
| Cadence and offer ownership | Every three cleared encounters; up to three distinct eligible identities; host-owned cached offer/revision, spending and acquisitions. Reopening is not a free reroll. |
| Acquisition limits | **12 cards per expedition**, **four copies per numerical card**, one copy per Unique. Twelve and four are playtest parameters, **not permanent catalog-design limits**. |
| Rerolls | **2, 4, 6 Essence** for successive accepted rerolls of that unclaimed offer, then no further configured reroll. Escalation resets at the next checkpoint. |
| Rarity | Common/Uncommon/Rare/Epic weights at floors **1: 78/18/3/1; 18: 64/25/8/3; 42: 52/30/13/5; 90: 42/32/18/8**. Interpolate between anchors, hold the last distribution at greater depth. These are provisional, not a floor-60 expedition end. |
| Grafts | **Six purchases** per expedition under current playtest tuning; cumulative ownership and per-altar restriction remain. No new adaptation is authored here. |

Acquisition limits, rarity probabilities and offer weighting are separate from mandatory eligibility. Do not guarantee transformations, promise a completed synergy, revise the current catalog or infer permanent growth restrictions from today's small playtest pool. Finite upgrade growth must not stop expedition/floor progression.

#### Remaining implementation gaps and unresolved decisions

| Area | Exact remaining boundary |
|---|---|
| Transformation-specific eligibility | CE01 implements the general predicates and verified-grant boundary. Each future transformation still needs its actual effect consumer, external producer requirements and any approved tag gate; a declaration alone cannot enable it. |
| New transformations and controls | Six transformations and the shared acquired-action/toggle controls are implemented in CE02/CE03. Conductor, Mirrorstep and Singularity still require actual consumers; existing B/Q/R never substitute for them. |
| Tag roles — settled in CE01 | Exactly primary plus unordered supporting affinities. No ranked supporting fields or alphabetical rank inference. Both roles influence eligibility without supporting tags granting baseline mechanics. |
| Numerical design | CE02/CE03 numbers are authored, provisional and recorded with units in the catalog/architecture reference. Remaining transformations and later balancing decisions are unauthored. Existing card contributions remain unchanged. |
| Shared-effect attribution | CE02/CE03 implement attributed shared Bleed, captured Brittle stacks, nonrecursive Burning spread, weighted tide contributions and actual Bark/HP expenditure. Conductor branch/return and Mirrorstep interactions still require their own definitions. |
| Harvest expenditure | Implemented once per accepted ordinary launch: up to 2 filled bonus HP, 2 damage per HP spent, first eligible primary contact only. Misses spend; refused launches do not. Empty reserves suspend the bonus with the toggle on. Normal HP is excluded. Deep Roots is unimplemented. |
| Echo semantics | Specify eligible voluntary movement actions, expiry, capture timing, release/miss behavior and the exact permitted scaled weapon/Form interactions. Preserve simultaneous release of all echoes and no arbitrary balance count ceiling; validate an execution/presentation budget before implementation. |
| Active targeting and networking | Bloodletting, Splinterburst and Harvest share host acquisition, character/life/world/binding, sequence and cooldown validation plus reliable owner details. B/Q/R and protocol-41 compact bytes remain unchanged. Singularity still needs its own authored action. |

These are design/implementation handoffs, not authorization to invent values or implement the catalog in this checkpoint. Storm/Spirit/Void redesign, enemy neural decisions, card/graft ledger refactoring and production persistence remain outside scope. The original baseline was documentation-only; subsequent CE02/CE03 implementation and focused verification are recorded in [ARCHITECTURE.md](ARCHITECTURE.md).

## Historical milestone record

The following dated CR/CT/EC/GA and CB notes retain their original implementation and verification context. They are historical evidence, **not a parallel active ruleset**. Where old mode switches, per-slot status formulas, installed grafts or priced cards conflict with the approved contract above or the implementation reference, the approved contract/current source takes precedence. Do not use historical counts or test results as acceptance evidence for an unimplemented transformation.

### Historical behavior and CR05 compatibility

- **Cards.** The legacy catalogue stores fixed rarity and cost on each definition. Its offer list stores card IDs, its ownership state stores integer ranks, and numeric effects multiply the base contribution by rank. Rarity and affordability already influence which entry is drawn, and selection charges Essence. A rank limit of one is the closest current equivalent to a one-time unlock. These assumptions need separate offer rarity, per-copy contributions, explicit Unique acquisition, and free selection when the future design is implemented. Existing card descriptions, caps, and event consumers still need to be checked together. CR05 kept affinity cards empty. EC01 owns a separate opt-in catalogue. [Catalogue](../run_upgrade_catalog.gd) · [Checkpoint selection](../game.gd)
- **Class tree.** The active branch tree grants one selection at each current row gate, at levels 1, 2, 4, and 7. It allows one node per row and accepts a learned adjacent predecessor. The legacy mask tree uses level minus one as its point budget, with additional tier and parent checks. Existing row exclusions already prevent buying every branch. The branch-tree budget, the current Offense/Control/Defense starting lanes, and the automatically generated adjacent links are compatibility behavior. The future graph needs the approved focus choices and deliberate connections. Level 7 currently resolves at 2,600 Class XP. Its suitability as a final-tier gate is unverified against the approved pacing goal. The current free respec at the Heart remains a legacy action. [Branch rules](../warden_tree.gd) · [Legacy rules](../class_catalog.gd) · [Current XP data](../assets/content/balance.json)
- **Grafting Altar.** Legacy combat consumes a carried monster part for a chance to install or replace one component. Affinity combat uses GA01A’s run-owned purchases. [Altar action and validation](../game.gd) · [Affinity purchases](../expedition_grafts.gd)

### CT01 connected Warden

Affinity Wardens without historical Warden investments can select a starting focus and five successive connected nodes. The character stores stable path IDs in the versioned `warden_connected` field. Other Warden profiles keep their historical masks. The starting focus supplies Q through every branch crossing. Heart respec refunds the connected choices while keeping earned Class XP. [Connected tree](../warden_connected_tree.gd) · [Character profile](../character_profile.gd)

Most native follow-ups require the first actual self-block attributed to that Warden's Q. A teammate's use of the same Ward counts against Measured Guard, and the original Catalyst rules still determine the teammate's response. Prepared Root Quake consumes the native preparation on cast. Living Rhythm requires a hit, and Sheltering Quake can protect allies around a Quake with no enemy contact. Holdfast uses the first actual block attributed to the Warden's Q, including a teammate's Ward from that Q. It grants the caster and living allies within 3 m and clear line 15% direct-attack mitigation for 2.5 s. A newer grant refreshes the recipient's timer. It follows the recipient, and only the stronger protection applies inside Sanctuary Ground. [Warden combat](../warden_combat.gd) · [Ward responses](../ward_responses.gd)

The isolated thresholds are **0, 50, 150, 350, 1400 and 2600 Class XP**. The capstone uses the previous tree's final-row threshold at the new scale as a provisional gate. The connected Weaver uses these same provisional thresholds.

| Expedition reference | Ordinary leaders | Scheduled scouts | Solo XP with full credit |
| --- | ---: | ---: | ---: |
| Short, through floor 6 | 6 | 37 | 55 XP |
| Medium, through floor 12 | 12 | 87 | 123 XP |
| Deep, through floor 18 | 18 | 150 | 204 XP |

The comparison uses the solo cycle-zero spawn budget with every scheduled ordinary enemy spawned and defeated. A normal scout pays 1 XP and a leader pays 3 XP to each eligible participant. Boss leaders pay 24 XP and alter the escort count. Actual spawns, reinforcements and player eligibility can change the award. These are computed inputs for the pacing review. Final thresholds await ordinary-play evidence and approval. [Spawn budget](../combat_director.gd) · [Reward logic](../monster_rewards.gd) · [Reward data](../assets/content/balance.json)

Whole Class XP is stored with a profile format marker. For each class, former whole XP multiplied by ten plus its saved fraction yields the new balance. Earlier content-curve remapping still precedes this conversion. Guest acknowledgment digests use an equivalent historical representation so existing committed and pending projections can reconcile. [Class XP conversion](../class_experience.gd) · [Guest projections](../guest_profile_projection.gd)

### CT02 connected Weaver

Affinity Weavers without historical Weaver investments use `weaver_connected` to store a versioned focus and five connected choices. The selected focus keeps its Q. Spore Nova remains R. Historical Weaver masks and earned XP keep their existing meanings. [Progression graph](../connected_class_tree.gd) · [Weaver node definitions](../weaver_connected_tree.gd)

Barbed Nova augments the first valid native hit and carries through an empty Nova. Spore Pressure arms on the first actual damage or root from each Q, including the first damaging Bloom pulse, and is spent on the next Nova cast. For hit selection the host visits the leader, then scouts in slot order within the main area, followed by extra Symbiotic targets in the same order. Bursting Spores captures that first impact position. Each caster owns one scheduled capstone alongside the existing trait queue. Symbiotic Nova merges its native target list once and keeps the original Catalyst footprint. [Native spells](../weaver_combat.gd) · [Q release](../subclass_combat.gd)

Protective Filaments follows its recipients. The latest valid grant refreshes its duration and the strongest direct protection wins across Filaments, Holdfast, and Sanctuary Ground. Silken Canopy grants each eligible ally one native Ward per canopy. Affinity Cultivate Bloom retains its native damage and timing and leaves independently granted Marks untouched. [Damage and Ward handling](../game.gd) · [Growth and delayed effects](../combat_traits.gd)

### CT04 connected Reaper

Affinity Reapers without historical Reaper investments store the starting focus and five choices in the versioned `reaper_connected` path. They use the existing six-level thresholds. The focus keeps its Q and Siphon Cut remains R. The historical masks keep their own effects. [Reaper tree](../reaper_connected_tree.gd) · [Profile normalization](../character_profile.gd)

Connected Veil Passage grants Veil Momentum for 2.7 seconds. A valid ordinary melee attack captures the Q preparation at commitment and spends it only at an eligible contact before expiry. Existing Core Marks and Ranger Tracked Prey keep their own consumers. Siphon preparations expire on a change of life or floor or on return to the Garden. A fresh successful Q replaces that actor's unspent Q preparations. Compatible bonuses coexist, including both +10 HP primary-hit bonuses from Barbed Siphon and Feast of Thorns. Veil Dance uses the actor-clearance step and allows a valid R to proceed from its original position when the step is blocked. [Reaper combat](../reaper_combat.gd) · [Native melee contact](../weapon_contact.gd)

Death’s Due uses the existing native class pool. Its charges survive floor changes and revival and reset on expedition entry or return. The installed Funeral Petal pool still resets on fall, a new floor or graft replacement. Both pools share three slots and spend class charges first. Immediate native class hits and ordinary melee can earn or spend a class charge. Feast secondary damage and affinity damage use the ordinary reward path with separate proc lineage. Void class responses retain their damage when resolved native or graft pull takes priority. [Native charge handling](../combat_traits.gd) · [Graft ownership](../native_grafts.gd) · [Catalyst resolution](../affinity_build.gd)

### CT05 connected Oracle and native Omens

Oracle uses the same provisional six-choice thresholds as the other affinity classes, with its own versioned profile path. Lifekeeper, Leykeeper, and Omenreader retain their starting Q and all share Warding Chime. The Wilds Gate offers an explicit starting focus before departure for each new affinity class. Existing historical paths continue to use their saved masks. [Oracle tree](../oracle_connected_tree.gd) · [Departure checks](../affinity_build.gd) · [Profile compatibility](../character_profile.gd)

Foreboding reserves 350 ms of recovery on one newly committed enemy attack. Guided Strike extends one eligible enemy recovery by 300 ms on a real ordinary weapon contact. Second Breath restores up to 6 HP after surviving unblocked direct enemy damage. Grants carry their issuing Oracle and cast. Overlapping copies provide one response, with strongest potency first and lower host peer ID breaking ties. Distinct named effects keep separate lifetimes. Portent of Mercy takes priority over Second Breath on a qualifying hit and leaves any unspent Second Breath available. Recipient and floor validity bound all effects. Accepted grants can finish on surviving recipients after their Oracle falls. [Omen records and recovery](../oracle_omens.gd) · [Native class effects](../oracle_combat.gd)

Warding Chime still uses the existing Ward claim priority. Shared Shelter extends the issued Ward to two seconds. Merciful Chime heals its claim’s protected recipient after an eligible block. These native benefits do not create additional Catalyst actions. Oracle sends effect indicators through existing detailed status feedback. [Ward claims](../ward_responses.gd) · [Status presentation](../combat_status.gd)

### EC01 affinity card playtest

The host offers up to three eligible card identities at each third cleared checkpoint. Each stackable offer rolls its own rarity and keeps the applied contribution on acquisition. A choice is free. Unclaimed offers can reroll for 2, 4, then 6 Essence, with a new revision on each accepted reroll. The provisional limit is 12 acquisitions per player and expedition. The Gate remains available after the limit. The rarity curve interpolates between floors 1, 18, 42 and 90 and holds the final probabilities at greater depth. [Catalogue and tuning](../affinity_card_catalog.gd) · [Ownership and checkpoints](../affinity_cards.gd)

Run cards live on the authoritative expedition player. Their source contributions are captured at the applicable action. The owner’s run summary shows inactive equipment-dependent copies and the reason. Essence income and permanent XP settlement still use their established receipts. On return, the player’s expedition wallet and cards are cleared. Legacy combat uses its separate priced cards. Hosts and guests match the EC01 affinity signature. [Combat events](../combat_action_events.gd) · [Run summary](../run_summary_panel.gd) · [Ruleset](../combat_ruleset.gd)

Launch the isolated affinity playtest with the [experimental terrain launcher](../tools/launch_experimental_terrain.ps1) and its `-CombatAffinities` switch. The authoring values are provisional.

### GA01A cumulative affinity grafting

Each player can buy one improvement per altar and up to six per expedition under the provisional playtest tuning. Reinforcements cost one chosen ordinary carried trophy. Each Unique adaptation costs one matching carried trophy. The host checks the current expedition, floor, and purchase revision before committing the material debit and receipt together. Purchases survive floor travel and revival and clear when the player returns to the Garden. Only owning peers receive their ledger through reliable detail updates. [Purchase definitions and state](../expedition_grafts.gd) · [Altar preview](../affinity_grafting_panel.gd)

The four reinforcements apply to basic damage, native Max HP, native class cooldowns, or basic reach. The six available adaptations are Silken Mycelium, Prismatic Gill, Chorus Node, Funeral Petal, Cinder Antler, and Grasping Rootlet. Link, Echo, Chorus, and Cinder have independent readiness. A full effect queue leaves a response ready for the next qualifying contact. Funeral Petal shares the three-charge cap with Death’s Due and yields spending priority to class charges. Permanent Knowledge rewards belong to GA01B. [Scoped combat effects](../native_grafts.gd) · [Focused fixture](../tests/cr05_native_grafts.gd)

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

### CR04C Storm, Spirit and Void

Storm Reed resolves Chain Spark. Its first hit deals 22/30 HP for
ordinary/refined material, up to two further contacts at 70% falloff per
jump and with a 3 m jump range. Arcing Strikes adds 9/13 HP every 1.7 s
with one additional arc. Only a qualifying hit spends the interval.
Catalyst offense starts a discharge. Actual blocks and pure movement
burst for 12/17 HP. Healing grants one 4.8 s charge worth 10/14 HP.
A weaker charge cannot overwrite or prolong a stronger grant.

All four Spirit species resolve Phantom Step. Travel is up to 2.2 m in
the chosen direction, with a 0.28 m minimum. Spiritstride adds 20/29%
movement for 2.5 s, with the strongest active source winning. A trace
lasts 0.75/1.10 s against current uncommitted pursuers, which then resist
new traces for 4.9 s. Flowing Strikes prepares a 4.4 s opportunity.
After 0.9 m of voluntary movement, one attack can claim 13/18 bonus HP.
The claim lasts through its last projectile and a miss leaves the original
deadline intact. Catalyst uses the current skill's mapped speed or trace
response. Traces change pursuit on the host and never create a targetable
decoy.

All three Void species resolve Gravity Well. It gathers for 1.08 s
before collapsing for 21/29 HP. Drawing Strikes adds 10/15 HP every 1.85 s
and attempts a 0.56/0.78 m draw. Native authored displacement takes
priority. Catalyst pulses deal 12/17 HP, toward mapped offensive centers
and away from protected allies, healing centers and movement landings.
The host ranks requests for an enemy in each tick by strength, then Core,
Catalyst, Form and ascending source peer ID. One request wins. Each enemy
can move at most 1.10 m in any rolling 850 ms, and opposing directions
are refused within that window. Resistance and clearance can stop motion
while legitimate damage still resolves.

Protocol 41 retains the same fast snapshot schema and recovery stream.
The development ruleset signature includes the nine-family definitions
and rejects mismatched clients. Charge timers and well hints use the
existing owner details, while actors and motion scale use the existing
fast fields. Launch with `tools/launch_experimental_terrain.ps1
-CombatAffinities` and use **Stock affinity materials in isolated
Garden** in the host's settings. Supporting affinities remain future
card opportunities. The default combat mode remains legacy.

The exact-input `cr04c-accepted` source run passed 22 focused fixtures,
including the three guarded expedition loops, the mixed party and overflow,
previous four- and six-family workloads, compatibility refusal and the
controlled missed-update case. The new mixed run used 1,196 bytes at 20 Hz
with 24 of 24 markers, 53 ms p95 observation and an 80 ms maximum interval
between applications. The six-family control applied four reliable
recoveries with a 306 ms maximum interval. None warned about the MTU.
With 20 scouts and 120 trials in a headless arena, mean Storm target
selection, Spirit step and Void clearance took 57, 59 and 49 µs,
respectively. Mixed-party snapshot encoding was 269 µs at p95.
This is local Windows loopback evidence.

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

## CR05 native class progression

Class XP and tenths keep their existing thresholds and identify which permanent nodes a character can learn. They do not grant affinity ranks or extra attack power. Learning, respec and selection use the existing guarded profile action and loadout rebuild. Unknown learned bits are retained in the existing profile quarantine, with native class IDs as keys.

| Source | Effects and runtime consumers |
|---|---|
| Legacy class mask, weapon handling | `damage` and `windup_damage` use native strike points. `reach`, `pull` and `knockback` use metres. `cooldown`, `stagger` and `recovery` use milliseconds. `targets` is an integer contact limit capped at five. Strike interval has a 230 ms floor. |
| Legacy class mask, character | `max_health` adds native capacity up to four authored points in affinity mode. `heal_on_kill` adds up to two authored points before expedition sustain limits. `graft_chance` adds probability points before the 95% cap. `familiarity` adds harvest familiarity. `dodge_cooldown` reduces native dodge time. |
| Legacy class mask, Q/R | `skill_cooldown` subtracts milliseconds above the 1,800 ms floor. `skill_duration` extends native roots, traps, fields, Guard and Renewal where that skill has the parameter. `skill_heal` adds up to three authored points to applicable native healing. Skill `power`, `efficient`, `augment` and `master` remain native `SkillCatalog` transforms. |
| Native learned responses | Warden's directional guard, counter damage/stagger and Ward-on-block remain in Guard resolution. Weaver's spread Bind and growth field, Ranger's Mark/precision/decoy, trap potency and Veil Mark, Reaper's grave charges/momentum and Oracle's sanctuary/omen remain native class mechanics. They do not grant a plant affinity or plant-card capability. |
| Restricted Warden and Oracle effects | Warden legacy nodes 10 and 11 and Oracle legacy node 11 retain other learned benefits. Their old Shatter scalar has no approved owner in source-attributed Frost rupture. Warden's Cracking Roots keeps existing investments and refuses new learning in affinity mode pending a decision on native Brittle sources. Oracle legacy node 10's pool Ward requires a compatible healing pool. |

Current tiered focuses use their named Q replacement and preserve native R follow-through or Root Anchor behavior. None of these rank paths changes Core, Form or Catalyst potency.

### Native monster graft compatibility

This section records the CR05 baseline before GA01A replaced the single-slot affinity implementation.

`native_grafts.gd` classifies every authored native statistic or special effect for all 24 grafts. The inventory item and component IDs remain the authored IDs in `weapon_parts.gd`. The affinity build reports installed numeric effects, supported procs and explicit refusal separately. Core, Form and Catalyst retain their original affinity identities. Numeric outputs still use native strike, skill and health caps.

| Graft | Native effect in affinity mode |
|---|---|
| Briar Hook, Nightbloom Pollen, Gallhorn Antler, Cantor Bellcap, Thornmaw Fang, Willow Sinew, Orchid Sac, Gravebud Husk, Wicker Sting, Brood Heart, Shepherd Knot, Hollow Carapace, Lure Bladder | Preserve authored native numeric effects. Their existing consumers resolve position and reach, recovery, strike and skill timers, wind-up damage, hit counts, kill sustain and maximum HP. |
| Burrowing Tendon, Grasping Rootlet | The Tendon supplies native line contacts and one extra target within the resolved limit. Rootlet draws visible loose loot within 3.5 m after the encounter clears. |
| Silken Mycelium, Matriarch Spindle | A direct hit links once to a visible nearby enemy with a 120 ms response interval and 140 ms delay. Matriarch additionally modifies native Bind target selection. |
| Funeral Petal, Prismatic Gill, Chorus Node | Petal earns one charge from an eligible direct kill while the shared three-charge capacity has room. An ordinary hit spends at most one charge for one authored point. The learned Reaper source spends first when both sources have charges. Gill redirects every third direct contact to another visible enemy after 240 ms. Chorus emits a pulse after four direct contacts to other visible enemies within 3.2 m. |
| Cinder Antler, Congregation Pearl | The native Cinder field lasts 2.6 s with a 4 s response interval and carries no Mark. The native healing pool lasts 2.4 s with a 4.5 s response interval. The existing learned Oracle pool-Ward modifier can augment that pool. |
| Orchard Heartwood | After 500 ms stationary, ordinary direct contact gains one authored damage point. Native Brace absorbs an incoming hit once per 4 s when available. This absorption has no Q/R Ward claim. |
| Nameless Stigma | Installation refuses before material consumption or the success roll. Its Echo/Mark pair needs an explicit decision on sharing Mark ownership and consumption with native class Marks. |

The host snapshots the graft identity, damage and attack at release. In-flight weapon hits retain their launch values after replacement. A replaced graft cannot accumulate new counters or create a new proc from an old shot. Already scheduled secondaries and fields keep the original owner and potency, with the existing target, visibility and floor checks. Counters reset on replacement, death and a new encounter. Return clears the expedition graft. Secondary damage uses native damage and reward handling with no new direct-hit trigger or card consumer.

### Dependencies on single-slot replacement

The altar's selection, currently installed preview, same-item refusal and later-floor replacement check depend on `graft_part` and `graft_floor`. The build resolver reads one installed component, and the equipment revision invalidates new proc claims from superseded attacks. Successful replacement clears that component's counters. The fixtures cover those existing rules.

Individual damage, Link, Echo, Chorus, Cinder, healing pool, Brace and Death Charge handlers are scoped to their authored sources. The bounded hit and field services carry impact and potency snapshots independently of installation. A future model can reuse those services after it defines how several active sources are admitted, expire and share limits.

### CR05 verification

Godot 4.7.2 passed 19 focused source suites with 35 successful process exits and no unexpected engine errors. Planner self-tests passed 55/55. Class fixtures resolve 210 skill configurations and exercise native focus casts, Ward consumption, delayed trap contact and learned HP under Vitality. Graft fixtures exercise all newly enabled distinct mechanisms, including the shared Death Charge cap and in-flight impact after replacement. The two-peer loop covers guarded learning, weapon selection, duplicate graft refusal, drops, Gate advance, extraction and rejoin. The four-player loop covers mixed classes and grafts with fifth-player refusal.

| Evidence | Structured run ID |
|---|---|
| Guarded solo graft and mixed Death Charge | `2daa2d6871164966b117a3375e69852b` |
| Guarded two-peer graft, progression, expedition and rejoin | `b17aa169a613425381006e50b527c100` |
| Guarded four-player active Cinder, 20 scouts and overflow | `8df18097066c42acaff735581dc803ce` |
| Skipped intermediate Bark and HP state, then convergence | `42d571312a22489db0cd74345873b774` |
| Storm, Spirit and Void transport regression | `065cc058000e4a48a1fb892d37c9c74a` |
| Stale sequence and reliable recovery codec | `7d2bb3c3e7d74687b5714a5867ecb23d` |
| Ruleset and definition mismatch refusal | `4bf046464ca14a67a510f08b1c4f1587`, `7c4d1c9385aa4ac0a721f18d7df3fd27` |
| Integrated Garden/Wilds co-op | `2c72383377274181a797bc08493476df` |

The composite evidence is in `cr05-accepted-final/results.json`, with intact identical-input verdicts linked from `cr05-accepted`. The sorted runtime evidence map hashes to `6ce4668736d832d01d1402c9bd4524cc1add749bd132bf3209310981dab53067`. The four-player graft run measured 1,196 application bytes at peak, 49.94 ms median sends, 59.0 ms for the highest guest p95 interval between applied states, and 85.7 ms for the longest measured apply gap. These are local loopback measurements. Protocol 41 exchanges the updated affinity definition identity through its existing compatibility check. Legacy mode remains the default and affinity-compatible cards remain empty.


## CE02 implementation status

Thorn's eleven additional cards and Bloodletting are implemented on `combat/ce02-affinity-cards` (39 total at this checkpoint). Their provisional per-copy values, ownership and verified action path are recorded in the maintained [architecture reference](ARCHITECTURE.md#first-affinity-card-expansion-ce02), with authoritative definitions in `affinity_card_catalog.gd`. The original 28 values and acquisition/rarity budgets are unchanged. Bloodletting adds an acquired action; it replaces neither Core nor Q/R and consumes no shared Bleed. The remaining transformation directions above are not implied implemented by this checkpoint.

Frost adds thirteen implemented cards (52 total at its checkpoint). Returning Winter, Shatterwave and Unique Avalanche are distinct; baseline rupture remains root-free. Source-specific and global potency, credit accumulation, class-slot preparation and nonrecursive propagation are verified and tuned in `affinity_card_catalog.gd` / `frost_combat.gd`. See the CE02 architecture section for provisional values and focused evidence.

Fire adds ten implemented cards, completing CE02 at **62 definitions**: the original 28 unchanged, plus 11 Thorn, 13 Frost and 10 Fire. Bloodletting, Avalanche and Wildfire are implemented; other transformation directions remain unimplemented. Flashover and Wildfire are independent. The eight-stack special-effect thresholds, 25% Flashover expenditure, 50% Wildfire spread, rational contributor decay retention and all per-rarity contributions are provisional. Definitions and readable preview labels live together in `affinity_card_catalog.gd`; the [maintained architecture reference](ARCHITECTURE.md#first-affinity-card-expansion-ce02) records the numerical snapshot, source interfaces and focused evidence. No automatic main integration or release evidence refresh is implied.

CE03 Water is implemented (16 additions, 78 total). The maintained [architecture reference](ARCHITECTURE.md#second-affinity-card-expansion-ce03) records actual behavior, provisional per-rarity units and focused evidence; the catalog remains the tuning authority. This updates the earlier design-only state, without implying other families or transformations are implemented.

CE03 Wood is implemented (11 additions, 89 total). The maintained [architecture reference](ARCHITECTURE.md#second-affinity-card-expansion-ce03) records actual behavior, provisional per-rarity units and focused evidence; the catalog remains the tuning authority. This updates the earlier design-only state, without implying other families or transformations are implemented.

CE03 Vital is implemented (12 additions, 101 total). The maintained [architecture reference](ARCHITECTURE.md#second-affinity-card-expansion-ce03) records actual behavior, provisional per-rarity units and focused evidence; the catalog remains the tuning authority. This updates the earlier design-only state, without implying other families or transformations are implemented.


CE04 Storm is implemented (10 additions, **111 total** at its checkpoint), including passive Unique Conductor. Its finite forks/return and independent normal-chain solo conversion are implemented in `storm_affinity.gd`. The [maintained architecture reference](ARCHITECTURE.md#remaining-affinity-card-families-ce04) records provisional contributions and focused evidence. Spirit and Void additions are not implied implemented by this checkpoint.


CE04 Spirit is implemented (15 additions, **126 total** at its checkpoint): sequential stored dashes, independent passive Mirrorstep and departure-position Wraithcast. Ordinary dash recharge changes provisionally from 850 to 2,200 ms; Quick Footing values are unchanged. [Architecture](ARCHITECTURE.md#spirit-stored-movement-and-independent-phantoms) records exact per-rarity values, supported replica portions, focused/network evidence, measured stress behavior and the retained unrelated binding-fixture failure. Void additions are not implied implemented yet.


CE04 Void is implemented (11 additions), completing the remaining three families at **137 definitions**: 101 prior cards retained, 10 Storm, 15 Spirit and 11 Void. Rift Shear independently grants the real lingering-field path needed for solo overlap. Singularity is an additional targeted/self-placeable action. The [architecture reference](ARCHITECTURE.md#void-actual-overlapping-fields-and-targeted-destruction) records provisional values, ownership and focused evidence. No class/weapon/graft/cross-affinity expansion or main integration is implied. Wraithcast's documented supported skill portions remain narrower than all nine Core families.


CE04 final source review retains the 137-card catalog and all original 101 definitions unchanged. Effective fixed-tempo headroom, chain-dependent Storm eligibility, native-displacement-compatible Void pulls, all 15 phantom weapon patterns and finite multi-Unique Chain Spark copies are verified. Siphon replicas are damage-only. [The maintained architecture reference](ARCHITECTURE.md#ce04-final-eligibility-replication-and-verification-boundaries) records the 40-suite integration run, final nine affected-source checks, 106 tool checks, performance measurements and exact unfinished controls/compatibility limits. Controller rebinding for extra actions is not implemented. Production activation and main integration remain outside this checkpoint.
