# Wilds enemy and expedition boss content

Implemented 9 November 2026. The earlier content proposal totals **24 enemy species: 20 regular enemies and four rare expedition bosses**. The Heart finale is currently deferred. These four expedition bosses remain active and are independent of that ending.

The [Core and enemy interaction audit](CORE_ENEMY_INTERACTIONS.md) ranks how the finished skills affect each enemy and records the first learned responses. The [roster design review](#wilds-roster-design-review) compares the current moves with proposed changes for all 24 species. The [Wilds milestones](GARDEN_MILESTONES.md#wilds-enemy-design-milestones) are the implementation queue.

## Roster and trophies

| Stable ID | Enemy | Type | Unique trophy | Graft effects |
|---|---|---|---|---|
| `rootbound` | Rootbound Pilgrim | Regular | Briar Hook | pull: 0.8 |
| `nightbloom` | Nightbloom | Regular | Nightbloom Pollen | recovery: 650, windup damage: 1 |
| `gallhorn` | Gallhorn Stag | Regular | Gallhorn Antler | reach: 0.7, knockback: 0.3 |
| `bellcap` | Bellcap Cantor | Regular | Cantor Bellcap | skill cooldown: 900, recovery: 300 |
| `thornmaw` | Thornmaw Hound | Regular | Thornmaw Fang | damage: 1, cooldown: -120 |
| `willow` | Mourning Willow | Regular | Willow Sinew | pull: 1.1, reach: 0.3 |
| `orchid` | Carrion Orchid | Regular | Orchid Sac | heal on kill: 1, recovery: 350 |
| `colossus` | Gravebud Colossus | Regular | Gravebud Husk | knockback: 0.65, stagger: 90 |
| `wasp` | Wicker Wasp | Regular | Wicker Sting | cooldown: 70, windup damage: 1 |
| `broodmother` | Mycelial Broodmother | Regular | Brood Heart | targets: 1, recovery: 400 |
| `root_shepherd` | Root Shepherd | Regular | Shepherd Knot | targets: 1, recovery: 150 |
| `hollowback` | Hollowback Grazer | Regular | Hollow Carapace | max health: 2, knockback: 0.25 |
| `lantern_lure` | Lantern Lure | Regular | Lure Bladder | pull: 0.65, recovery: 180 |
| `seamroot` | Seamroot Burrower | Regular | Burrowing Tendon | targets: 1, reach: 0.6, pierce: 1 |
| `spore_widow` | Spore Widow | Regular | Silken Mycelium | link: 1 |
| `pallbearer` | Pallbearer Bloom | Regular | Funeral Petal | death charge: 1 |
| `graft_thief` | Graft Thief | Regular | Grasping Rootlet | loot attract: 3.5 |
| `ashen_hart` | Ashen Hart | Regular | Cinder Antler | cinder trail: 1 |
| `glasscap` | Glasscap Watcher | Regular | Prismatic Gill | echo: 1, echo redirect: 1 |
| `root_choir` | Root Choir | Regular | Chorus Node | chorus pulse: 1 |
| `orchard` | The Orchard That Walks | Boss | Orchard Heartwood | brace: 1, knockback: 0.5 |
| `drowned` | The Drowned Congregation | Boss | Congregation Pearl | tide pool: 1, pool radius: 0.4 |
| `matriarch` | The Hollow Matriarch | Boss | Matriarch Spindle | link: 1, spread bind: 1 |
| `nameless` | The Nameless Bloom | Boss | Nameless Stigma | echo: 1, mark damage: 1 |

## Rare boss rules

- Eligible from encounter 10 onward, with a 2.5% roll per new floor. No forced first boss, pity spawn or ordinary spawn-pool entry. All four may occur during a long expedition, but each can appear only once.
- A floor has exactly one cached boss decision. Resetting combat cannot reroll it or create a second boss. A new expedition clears the appearance history. Abandoning a boss floor does not create another roll on that floor.
- Bosses replace the primary enemy and retain up to four initial escorts. The existing 20-scout budget also bounds Matriarch summons. Summoned offspring provide no XP, essence or trophy rewards.
- Boss maximum health uses the party size recorded at encounter start. Boss damage, wind-up, recovery, reach, model scale, moves, lair, hurt radius and reward chances are authored in the catalog.
- Every boss has three authored moves, with phases below 65% and 30% health. Later phases increase attack pace and hazard coverage. The same authority owns damage, minion spawning, map changes and rewards in co-op.
- Host and guest receive a public boss/lair/phase descriptor. Lair geometry and collision use the same deterministic floor generator; the private appearance history is host-owned.

| Boss | Lair | Moves and identity |
|---|---|---|
| The Orchard That Walks | Broad 44m-diameter central arena, with gate approaches and dead-grove anchors | Broad root sweep, marching charge with lingering anchors, falling fruit, and Root Cage in later phases. Separate walking roots and an uneven grove canopy. |
| The Drowned Congregation | Flooded clearing with three shallow, traversable water channels, dry causeways and reeds | Expanding tidal pattern, surging bodies, grasping pools. Seven host bodies linked to one fungal core. |
| The Hollow Matriarch | Nursery clearing with egg clusters and connected ribbed routes | Reshapes hazardous nursery spokes, calls bounded offspring, lunges. Health phases shift ribs and alter living offspring; newly raised ribs cannot trap an existing player. |
| The Nameless Bloom | Memory glade with corrupted growths | Memory lance, spore constellation, remembered rend. Existing host-world adaptations add visible bark, spores and reach; those traits alter the lance and follow-up hazards. |

## Rewards and weapon progression

Natural regular kills keep their existing low trophy chances and individual ownership. Boss trophies have a 60% drop chance per eligible living player, with six times the primary-enemy essence and eight times its class XP. Each boss also guarantees one **Ancient Mystery Seed** per eligible living player. Reward rolls are frozen before the existing save transaction; repeated death events or save retries cannot duplicate them.

The ancient seed uses the common item/stack/pouch/drop/stash system. Its species is chosen only when identified at the Garden altar, including through **Identify all**. It cannot be used as a known species in an altar recipe. Tier chances are 25% Rare, 55% Epic, 20% Mythic, with equal chances between species within the selected tier. Failed identification restores both inventory and random state. Ordinary mysterious seeds retain their exact concealed species.

All 24 enemy species have a trophy that fits the fourth weapon slot. The eleven additions have two checkpoint cards each: a trophy-specific improvement and a plant-tag resonance. This brings the checkpoint catalog to **126 cards**. The existing three-card layout, 8% fourth-card chance, costs and rank limits remain in use. Installed grafts unlock the relevant card pool; existing purchased upgrades retain the established run behavior.

New behavior vocabulary includes penetrating weapon lines, Cinder fields, owner-only post-combat loot attraction and a four-contact Chorus pulse. These share the existing bounded effect queue. Spore links, death charges, redirected echoes, bracing and healing pools reuse the verified plant/class effect vocabulary. Secondary contacts do not recursively generate more contacts.

## Reusing the templates

1. Append a stable enemy entry to `assets/enemies/catalog.json`; do not reorder published entries. Ordinary spawns automatically filter biome, unlock depth and role. Mark expedition threats with `boss: true` to keep them out of ordinary pools.
2. Append the corresponding trophy to `MONSTER_DEFINITIONS` in `weapon_parts.gd`, and append its `monster:<stable ID>` to `assets/content/part_order.json`. Keep the frozen legacy manifests unchanged. Items, stash counts, monster familiarity and loot ownership then use the shared registry.
3. Add trophy cards to `assets/upgrades/checkpoint_upgrades.json`, using `grafts` for the source monster and actual existing plant tags for resonances. Every effect must have a real consumer and pass content validation.
4. Author ordinary behavior through the common actor hooks in `enemy_behaviors.gd`; add a new hook only for genuinely new behavior. Common targeting, movement, telegraphs, hit handling, death and reward logic remain shared.
5. Bosses use `boss_encounters.gd` for cached selection, phases, moves, bounded hazards and brood. `battlefield.gd` authors their collision/navigation; `boss_lair_visuals.gd` supplies matching scenery. A new move or lair needs an explicit implementation and regression case.
6. Extend `tools/new_enemy_forms.py` for ordinary silhouettes or `tools/boss_model_template.py` for bosses. `tools/make_enemies.py` dispatches the correct builder, saves editable `.blend` source and exports GLB. Preserve `EnemyCore`, `Base`, `Root0..7`, `Growth1/2` and `Adapt*` sockets. Bosses additionally expose three attack sockets.
7. Run focused behavior, reward, lair and co-op checks, then the release gate. Only the highest numbered EXE is replaced after packaged tests pass.

## Compatibility and verification

Enemy IDs 0–12 and all previously published component indices are preserved. New component IDs are appended after the 24-species expansion. Frozen legacy migration files are untouched. Multiplayer protocol is **13**, covering boss/nest descriptors and the revised gate and crafting rules; all players should use this updated build.

New release suites: `enemy_depth`, `boss_roster`, and `boss_coop`. They exercise all new trophy/card mappings, reachable plant resonances, actual enemy/effect behavior, boss-sized melee contacts, rarity distributions, no-repeat scheduling, deterministic connected lairs, all boss moves, bounded nonrewarding brood, private co-op drops, seed identification and failed-save recovery. Existing item, progression, death-animation, movement, four-player and supplied network suites remain release requirements.

## Wilds roster design review

Reviewed 2026-11-10 against the Mystical Garden source before W-01. Each **Current** paragraph records that baseline. The milestone evidence records subsequent changes. **Fight**, **Adaptation**, and **Counterplay** are proposals for the current Wilds. The separate Battlefield Trials experiment remains outside this review. See the [implementation queue](GARDEN_MILESTONES.md#wilds-enemy-design-milestones).

### Findings across the roster

- **Shared roles are useful; shared decisions make them blend together.** The same scout loop handles most approach, prediction, wind-up and recovery. Nightbloom and Carrion Orchid share the repeat-cast structure, Gallhorn and Ashen Hart share a charge, and four support species share escort positioning. The strongest exceptions change a player decision: Ashen Hart leaves a trail, Hollowback shelters allies, Pallbearer consumes corpses, and Graft Thief makes dropped loot contested. [Scout movement and attacks](../game.gd#L1726) · [Species hooks](../enemy_behaviors.gd)
- **Descriptions, visuals and resolution need to agree.** The regular Gravebud entry describes a two-point stomp, while the generic regular stomp resolves one area; an elite can repeat it. Lantern Lure's default attack point is its own position. Glasscap's false silhouettes are effects, with no hit targets of their own. Species resolve hooks can run before the generic vault handler, so a Burrower, Widow or Ashen Hart marked for a vault can still use its species attack. Confirm the chosen move and its actual hit region from the same host-owned state. [Scout resolution](../game.gd#L1791) · [Elite attacks](../elite_enemy.gd#L66)
- **Memory measures proxies.** The current saved world scores observe ranged damage share, burst hits, deaths on narrow generated ground, and ranged hits while moving. Narrow-ground kills do not reveal trap use. Moving ranged hits do not identify a repeated retreat lane. The old pressure counters still contribute alongside the newer memory. Both choke and kite can yield mobility. Treat any new signal in the roster below as a proposed measurement, with eligibility and fallback spelled out before implementation. [Evidence collection](../game.gd#L2205) · [Saved memory](../progress.gd#L278) · [Trait selection](../wilds_learning.gd) · [Legacy merge](../game.gd#L3116)
- **Encounter composition matters.** Existing support escorts, elite selection and the director's spawn and targeting budgets are useful boundaries. Pair one obvious pressure source with one modifier in early encounters. In deeper encounters, mix complementary roles while leaving a readable opening to engage or retreat. When a map lacks space for an enemy's alternate route, choose another legal move or omit that variant. [Support placement](../game.gd#L3799) · [Director](../combat_director.gd) · [Gate elites](../elite_enemy.gd)

### Early melee and pursuit

#### Rootbound Pilgrim · rootbound

- **Current** — Early close sweep. The host has a special case that can give this species reach against ranged pressure. It teaches basic movement and spacing, but extra reach mostly shifts a distance threshold.
- **Fight** — Give the hooked arm a deliberate drag, a readable sweep, and an exposed reset. The visible arc teaches players to step past the arm or retreat past its tip. Avoid making the basic Pilgrim a flanker.
- **Adaptation** — Under sustained frontal ranged pressure, one arm grows a bark guard. It raises the guard during approach, then lowers it to sweep. Use a directional reduction with a fixed facing during the guard.
- **Counterplay** — Shoot from the side, wait for the guard to drop, or bait the sweep. A solo ranged build has a repeatable shot window. An elite can alternate sweep directions with a fresh tell.

#### Gallhorn Stag · gallhorn

- **Current** — Locks a ground target and charges. Its path can hit players before the endpoint. An elite leaves hazards along the charge.
- **Fight** — Emphasize the full straight line with the existing chevrons, a planted hoof and a clear stop. Give a missed or terrain-stopped charge a recovery window. Keep the warning width equal to the swept hit area.
- **Adaptation** — After repeated narrow-lane kills, back away once and line up a second approach from a legal angle. Antler growth and a hoof scrape identify the variant before the new line is drawn.
- **Counterplay** — Step across the line or bait the Stag into blocking terrain. A single-exit space falls back to its straight charge. The Stag owns the straight-lane challenge; persistent fire stays the Hart's identity.

#### Thornmaw Hound · thornmaw

- **Current** — Crouches and pounces to a marked landing point. Its attack pressures a landing area, unlike the Stag's swept path.
- **Fight** — Tighten the crouch, airborne silhouette and landing recovery. Keep the landing circle separate from the leap animation so players can read the danger at a glance.
- **Adaptation** — Against sustained moving ranged play, try one longer lead on a lateral runner. A split hind-leg silhouette and a deeper crouch warn the player. Freeze the destination once the marker appears.
- **Counterplay** — Change direction after the marker locks, or interrupt the crouch. A miss leaves the Hound grounded long enough for a short counterattack.

#### Wicker Wasp · wasp

- **Current** — Uses lateral circling inside its approach band and a short sting. Shares the skirmish role with the Graft Thief.
- **Fight** — Give it an observable pass from one flank and a moment of hover before the sting. The pass communicates its approach; the sting gets the damage cue. Keep the attack on the ground-plane hit area.
- **Adaptation** — When it repeatedly takes hits during its approach, take a wider pass and approach from the opposite side. Flared wings preview the turn. Allow one reroute per attack, with a direct fallback in cramped ground.
- **Counterplay** — Track the hover, intercept the approach, or dodge into the space it just left. Pair sparingly with another fast flanker so each tell stays legible.

#### Seamroot Burrower · seamroot

- **Current** — Has a species charge hook with its own swept width and eruption hit. Its catalog describes an underground seam; the shared charge and elite paths still need consistent tells and resolution.
- **Fight** — Make the seam the main cue: begin at the burrow, trace the actual path, and flare where it will emerge. Give the surfaced Burrower a longer punish window than the Hound.
- **Adaptation** — After repeated choke-point kills, allow one bent seam around walkable terrain. Lock both legs and the exit during the warning. Keep the chosen movement and hit path consistent through the turn.
- **Counterplay** — Cross before the seam reaches you or move clear of the marked exit. If the map cannot support a bent route and safe landing, use the normal move. Preserve a visible emergence window for melee.

#### Ashen Hart · ashen_hart

- **Current** — Charges and leaves delayed ember hazards along the path. The lingering hazard is its strongest distinction from Gallhorn.
- **Fight** — Separate the charge warning from the ember activation cue. Use intermittent burning patches with a clear safe crossing. Once the Hart stops, players decide whether to pursue or wait for the trail to cool.
- **Adaptation** — After repeated retreats down the same lane, angle one charge across it. Ember growth along the antlers signals the change. Only choose the move if the player has a connected escape route after the trail lights.
- **Counterplay** — Exit laterally, cross before the embers activate, or take a visible gap. The Hart changes the route after it passes; the Stag pressures the line during the charge.

### Ranged pressure and area control

#### Nightbloom · nightbloom

- **Current** — Fires two separately timed spore pulses using the shared volley loop. Its distinct flower silhouette already gives it a strong presentation.
- **Fight** — Let the flower open once per pulse, with a crisp cue for each release. Use it as the early lesson in reading a second shot.
- **Adaptation** — After consistent early dodges during its first tell, swell a second bud to signal a delayed follow-up. Until dodge timing is measured, use an authored late-floor variant with the same cue.
- **Counterplay** — Walk out of the second marker or save the dodge for the swollen bud. Keep the second cast clearly distinguishable from a general speed boost.

#### Mourning Willow · willow

- **Current** — Predicts a target point and lands a slowing snare. The Widow shares its role label but has a custom multi-point web attack.
- **Fight** — Make its roots threaten the next step. Show them traveling from the Willow toward one marked patch, with a small clear area around the caster.
- **Adaptation** — Against repeated movement through a marked retreat lane, grow one narrow root line across it. The roots trace the line before rising. Use the normal snare when no lane evidence or side exit exists.
- **Counterplay** — Change lanes, step around the short end, or close on the Willow while its roots are out. Keep it distinct from the Widow's lingering boundaries.

#### Carrion Orchid · orchid

- **Current** — Delayed double spore burst using the artillery loop. It differs from Nightbloom in cadence and range, with a similar response for the player.
- **Fight** — Make it an artillery threat to stationary players. Drop a larger, slower patch with a clear landing marker and a gap before its next attack.
- **Adaptation** — Against repeated stationary ranged play, place the follow-up beside the first patch along an observed firing position, leaving a safe gap. An inflated lower sac identifies the longer attack.
- **Counterplay** — Reposition across the gap and advance during recovery. The Orchid pushes you out of a spot, while Nightbloom tests the timing of your dodge.

#### Lantern Lure · lantern_lure

- **Current** — Pulls nearby players toward the bloom when the marked area resolves, subject to line of sight. The standard lure's blast is centered on itself.
- **Fight** — Show the threatened circle and the direction of pull with a connecting root. Pair it with one predictable follow-up, such as a Pilgrim sweep, so pulling has a tactical purpose the player can read.
- **Adaptation** — After repeated exits from one side of the lure, grow an offset lantern that projects a narrow, clearly anchored pull from that side.
- **Counterplay** — Exit the marked area, put cover between the lantern and the player, or interrupt the cast. Resolve forced movement through walkable space and keep the endpoint out of an unavoidable second hit.

#### Spore Widow · spore_widow

- **Current** — Weaves four delayed hazards between itself and the target. The line of web hazards is already a space-control tool.
- **Fight** — Make it divide the fight into sides. Show slack strands while safe and tighten them when they become active. Make each crossing point easy to read.
- **Adaptation** — After repeated use of a lane, spin two short offset strands with a deliberate opening. Telegraph each strand in the order it will tighten. Skip the second strand if it would cut off all movement.
- **Counterplay** — Cross before the strand tightens, use the opening, or fight from the other side. The Willow slows an attempted escape; the Widow changes which lanes are safe over time.

#### Glasscap Watcher · glasscap

- **Current** — Places up to two copies on clear ground three to five meters away in a different formation each cast. Each matches the original’s scale, growth, adaptations and pose.
- **Fight** — A completed volley swaps the real Watcher with a randomly selected clear decoy. The copy fills the spot the Watcher left. The Watcher holds position briefly until the copies disappear.
- **Adaptation** — Early Decoys extends the wind-up and the time the copies remain after the swap. Glass Crossfire still warns the actual impact areas.
- **Counterplay** — Dodge the warned impact, then use confirmed damage or a mark to identify the real Watcher. Only the real body can take damage.

### Heavy enemies, escorts and scavengers

#### Gravebud Colossus · colossus

- **Current** — Winds up a broad regular stomp. The catalog's two-point description is closer to an elite repeat than the normal generic resolution.
- **Fight** — Establish one heavy stomp with a heel lift, a firm impact boundary and a long exposed recovery. Give the base enemy one visible answer to greedy attacks during the heel lift.
- **Adaptation** — Against repeated close burst, pre-mark a delayed aftershock with cracks before the first impact. Keep the initial stomp and aftershock distinct in time and presentation.
- **Counterplay** — Take a short punish window and back out, attack from reach, or interrupt before the heel drops. The elite can offset the second impact visibly. Never show two marks for one actual hit area.

#### Mycelial Broodmother · broodmother

- **Current** — Can spawn two seedlings through the shared brood path. The elite can surge up to a live-brood cap. Summoned offspring yield no kill rewards.
- **Fight** — Show where the next seedling will emerge. Make the choice between interrupting the birth and killing the mother legible while the existing brood applies pressure.
- **Adaptation** — If players repeatedly kill the young immediately, lay two exposed egg sacs farther apart. Reuse the same summon budget and release one child per surviving sac.
- **Counterplay** — Break a sac, interrupt the birth, or rush the mother. Space the sacs within reach of low-area-damage builds. In small clearings use one valid sac and preserve the total cap.

#### Bellcap Cantor · bellcap

- **Current** — Follows an escort and hastes nearby allies, including the primary enemy when in range. With no allies it falls back to a weak attack.
- **Fight** — Use a clear bell wind-up, a wave that shows buff range and a persistent tell on hastened allies. The player's question is when to interrupt a buff.
- **Adaptation** — If Cantors are repeatedly killed before ringing, step behind an escort for one cast. A furled bell and a short movement pause mark the defensive choice.
- **Counterplay** — Cut the escort off, use a second angle, or interrupt the ring. The Cantor modifies pace; it leaves group routing to the Shepherd.

#### Root Shepherd · root_shepherd

- **Current** — Commands nearby non-support scouts toward a common target through a short-lived command. Shares escort placement with other supports.
- **Fight** — Use the crook and a brief ground cue to show which escorts will coordinate. It changes **where and whom** enemies attack, while the Cantor changes their pace.
- **Adaptation** — Under repeated choke pressure, signal one escort to take a legal alternate route before the main group commits. The escort's departure is visible before its attack.
- **Counterplay** — Interrupt the crook, intercept the lone escort, or rotate before the two routes converge. If an alternate route is unavailable, retain the normal command.

#### Hollowback Grazer · hollowback

- **Current** — Its shelter reduces damage taken by nearby allies in line of sight. It also attacks with a stomp.
- **Fight** — Show which allies are covered and give the canopy a clear edge. Make it a formation defense first, with its stomp used to discourage crowding underneath.
- **Adaptation** — Against repeated frontal ranged hits on sheltered allies, turn and root a directional canopy toward the pressure. The turn is slow and holds its facing for a brief interval.
- **Counterplay** — Split angles in co-op, draw an ally outside the canopy, or punish the rooted turn in solo. Keep the current shelter and adaptation from stacking into opaque armor.

#### Pallbearer Bloom · pallbearer

- **Current** — Consumes a nearby natural corpse once per corpse, heals itself and hastes nearby allies. Its effect depends on where earlier kills happened.
- **Fight** — Show the selected corpse through a root tether before it is consumed. Use that warning to make moving the fight or killing the Bloom first feel deliberate.
- **Adaptation** — If corpses often gather outside its normal reach, extend one longer and slower tether. Decide whether the first version can be severed by a hit or only by interrupting the caster.
- **Counterplay** — Fight away from the corpses, break line of sight, or interrupt before the tether closes. Brood corpses stay ineligible and a corpse can only pay out once per caster.

#### Graft Thief · graft_thief

- **Current** — Seeks loose monster trophies and flees after taking one. The death hook restores stolen drops. It leaves seeds and the safe pouch alone.
- **Fight** — Give it an obvious look, grab tell and trophy silhouette after the theft. The player can choose to chase or finish fighting first.
- **Adaptation** — If loose trophies are often left within reach, approach along the edge and wait for a short opening before a visible rush. Preserve the existing return-on-death behavior and pickup ownership.
- **Counterplay** — Pick up the trophy, cut off the approach, or pursue the carrier. Keep the escape route bounded by encounter terrain. The Thief creates a loot decision instead of adding another damage check.

#### Root Choir · root_choir

- **Current** — Its species pulse hastes nearby scouts and can hit nearby players when allies are present. It has a shepherd role label, although the species resolution overrides the generic command.
- **Fight** — Give the three throats separate wind-up beats and one exposed root. The Choir is an area-denial support. Make that role explicit in composition and presentation.
- **Adaptation** — If parties repeatedly crowd it, stagger two pulses into marked sectors. Each throat lights before its own pulse. Keep one safe sector and avoid simultaneous overlapping hits at the sector boundaries.
- **Counterplay** — Read the beat, step into the gap, or interrupt at the exposed root. Its immediate local threat sets it apart from the Cantor's pure haste and the Shepherd's coordination.

### Rare expedition bosses

Bosses share health phase boundaries, rotating move lists and a host-owned hazard budget. Most phases currently raise pace or coverage. Distinct phase rules below give each lair a decision of its own. Keep existing floor eligibility, encounter caching, once-per-run species appearances and reward identity. [Boss selection and phases](../boss_encounters.gd) · [Lair geometry](../battlefield.gd#L314)

#### The Orchard That Walks · orchard

- **Current** — A large mobile grove in an oversized clearing. Root sweep, marching charge and falling fruit alternate. Marching leaves roots behind and later phases cover more ground.
- **Fight** — Organize the battle around the grove's march and anchoring. Show which trunk section plants its roots, let the party rotate around the planted side, and offer a punish window while the Orchard pulls free. The later phases link a broad sweep to Falling Fruit and then a wide march. Falling Fruit pressures distant targets and marks a second impact to one side. Root Cage marks two narrow exits across the targeted player's position.
- **Adaptation** — After sustained outer-edge kiting, establish one visibly growing outer anchor before sweeping that arc. Leave an interior route and a post-sweep window. Derive positions from the actual arena routes.
- **Counterplay** — Watch the anchor side, rotate through the open interior and return for the uprooting window. In four-player play keep separated targets from triggering enough fruit markers to seal the open route.

#### The Drowned Congregation · drowned

- **Current** — Uses expanding tidal patterns, surges and grasping pools in a flooded clearing. The linked hosts share a single fight state. Water channels are traversable.
- **Fight** — Make water motion preview which causeway is safest next. Give the linked bodies a readable relay that ends with an exposed fungal core. The choice is when and where to cross.
- **Adaptation** — Against repeated use of one dry firing position, a later tide temporarily covers that area. Reeds lean and water rises in advance. Use temporary marked hazards with a validated alternative dry route.
- **Counterplay** — Move to the next causeway early, cross after a surge, then attack the exposed core. Keep shallow terrain and hazardous tide visually distinct. Ensure pool placement cannot seal both ends of a crossing.

#### The Hollow Matriarch · matriarch

- **Current** — Changes rib layout with phase, reshapes hazardous nursery spokes, calls offspring and lunges. Later phases can add bark or mobility to summons. The host adjusts occupants if a layout shift would place them in blocked geometry.
- **Fight** — Preview the next rib alignment and active hatch sites before the transition. Offer one route toward the mother and another around her brood. Give the mother a short lull after committing to a hatch or lunge.
- **Adaptation** — When hatchlings are repeatedly wiped at one entrance, preview a second nursery exit in the next phase. Use the same live summon budget and shift the origin of the brood.
- **Counterplay** — Interrupt a hatch, clear one nursery lane, or use the lull to reach the mother. Validate connected routes at every phase. Test occupants on each changing rib and confirm host and guests see the same safe space.

#### The Nameless Bloom · nameless

- **Current** — Rotates memory lance, spore constellation and remembered rend. Reach widens the lance and spores can add a follow-up hazard. It is already the most explicit expression of world memory.
- **Fight** — Make the chosen remembered tactic legible through a single dominant growth at phase start. Present a distinct punish window after each remembered move. It should feel like a recognition of the party's habits.
- **Adaptation** — Select one memory response for each phase from the host's strongest supported evidence. Ranged pressure can grow an asymmetric lance, repeated stationary burst can bring a clearly delayed constellation, and choke pressure can split a rend into two telegraphed lanes. Publish one response at a time; varied play can select a baseline phase.
- **Counterplay** — Learn the growth, read the corresponding attack and exploit its recovery. Avoid combining a lane split, lingering hazard and wider hit area in one tell. Check the phase preview against the actual host move and hazard footprint.

### Adaptation authoring and validation

- Give each variant a stable ID, species eligibility, evidence source, depth and cooldown policy, tell, move, and fallback. Reuse the existing host-owned target, attack, hit, hazard and reward paths. A small set of reusable moves can express different species choices. Keep published enemy, trophy and card IDs stable. The current compact mutation flags are also used for model cues and reward logic, so carry a distinct move identity with an explicit compatibility plan.
- Start with existing evidence for the first slice. Add measurements for narrow decisions only when a proposed variant needs them. Track opportunity and outcome together. For example, time near a Cantor without killing it before a ring is evidence of an opportunity, while a Cantor that spawned out of reach tells us little. Aggregate persistent evidence at the world level and keep it isolated by host save. World memory should influence variety after repeated behavior; a single use of a skill should be safe to experiment with.
- Set each adaptation at spawn or at a clearly signaled boss phase. For the first pass, cap ordinary enemies at one signature variant. Teach normal moves early, make adapted variants rarer at first, and use deeper runs for stronger combinations. Preserve readable tells and at least one viable response for every weapon range and solo party size. Use bounded reinforcement and hazard systems.
- Use paired fixtures for the normal and evolved form, with repeated tactic and varied tactic histories. Check role selection, lock point, visible warning versus damage area, terrain fallback, interrupt/recovery, world reload, guest projection, stable loot ownership and existing gate-elite differences. Test a low-area-damage solo build as well as a coordinated party. Use playtests to judge recognition and counterplay; automated geometry and timing checks verify the underlying contract.
