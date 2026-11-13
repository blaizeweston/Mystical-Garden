# Core skill authoring

## What the pilot proves

Whispervine and Star Orchid are the first species-specific signatures in the Rare and Epic tiers. Whisper Mark uses the existing swept projectile and adds a one-use direct-hit mark. Constellation places a star that charges briefly, then automatically fires toward the owner’s cursor. Both work across the fifteen weapon forms.

| Source | What it owns |
|---|---|
| [Core skill catalog](../core_skill_catalog.gd) | Species signatures, skill text, icon paths, mechanic selection, tuning and tag interactions |
| [Core skill rules](../core_skill_rules.gd) | Weapon delivery, slot provenance, compatibility checks and resolved tooltip text |
| [Core combat](../core_combat.gd) | Host-owned input, validated aim, cooldowns, placement and encounter cleanup |
| [Swept contact](../core_lance.gd) | Piercing shots and mark projectiles |
| [Ground footprints](../core_footprint.gd) | Shared aim, host contact, and the shapes sent to clients |
| [Ground sequences](../core_skill_effects.gd) | Persistent fields, phase timing, and contact outcomes |
| [Core animations](../core_skill_visuals.gd) | Windups, impacts, and active field cues drawn from host footprints |

## Add a skill that uses an existing mechanic

1. In the catalog, add the stable species ID to **SIGNATURES** with an exclusive signature tag and skill ID. Leave the species' ordinary tags in the seed catalog for basic weapons and existing checkpoint cards. Ordinary and refined parts resolve the signature through their existing species reference.
2. Add the skill to **SKILLS** with its own icon under `assets/ui/core_skills/`. Use a transparent square PNG and check the silhouette at 34 px. Supply text for ground, arrow, bolt and seed delivery. Pick an existing mechanic and tune its parameters.
3. Add optional **INTERACTIONS** for specific slots. An interaction matches one named skill and a tag in Core secondary, Form, Catalyst or graft. A weapon form filter is optional. Use an existing tuning field and include the player-facing description. One compatible interaction wins per slot in catalog order.
4. Check the prepared icon and tooltip at the bench, then compare the equipped slot in the Wilds. Check ordinary and refined parts, solo and guest casts, and cleanup on expiry, defeat and floor advance. Run connected validation through the [mechanics test map](MECHANICS_TEST_MAP.md).

For an example, Star Orchid in Form supplies the `constellation` tag to widen Whisper Mark. Thorn Bloom in Form uses the shared `piercing` tag to widen Constellation. The resolver considers the actual slot in each case. Use the same slot-qualified build in any future checkpoint predicate.

## Reusable mechanics

| Mechanic | Parameters and gameplay |
|---|---|
| `line_trap` | Place a damaging line with a length, radius, lifetime and per-target tick interval. |
| `swept_projectile` | Use speed, radius, hit cap and contact type. Damage and strike mark are supported. A strike mark has its own lifetime and burst damage. |
| `ground_burst` | Place an area with radius, target cap and stagger duration. |
| `ground_sequence` | Resolve bounded contacts using shared strips, capsules, cones, and areas. |
| `anchor_beam` | Place an anchor with a charge time. It automatically fires toward the live cursor using the beam range, width, hit cap and root duration. |

Add a new mechanic when a skill needs a new interaction, such as temporary terrain. Give it one shared placement or contact handler with bounds and explicit ownership. Later skills can select that mechanic in the catalog. Keep save and item IDs stable. Gameplay actions, visible footprints and status lifetimes come from the host. Skill tooltips and cooldowns belong to the owning player. Cap each cast's targets and follow-ups so a triggered effect cannot recursively trigger itself.

## Targeting previews

Hold the bound Core or class skill key to see reach and impact on the ground. Aim with the cursor and release to commit. The preview uses the resolved skill, including slot and class modifiers, and terrain limits for travel and placement. Dashed rings show reach and solid outlines show impact. Targeted class abilities show an impact marker when they acquire an enemy. Constellation previews where the star will land. Once placed, a guide from the star follows the cursor during its charge. Only the local player sees a held preview.

Core mechanics share their placement with the preview in [Core combat](../core_combat.gd). Class modes share target selection and dash geometry in [Class ability targeting](../class_ability_targeting.gd). When adding a mode, use the existing shapes in [Ability aim](../ability_aim.gd) and extend the preview fixture to cover the new footprint.

## Pilot acceptance

- The mark appears on the first target struck. One direct hit from the owner or a teammate consumes it. Secondary procs leave it available, and the mark expires when its caster falls or leaves.
- The star lands at the aimed point and shows a live beam guide during its charge. The guide and collision use the same terrain-limited segment. The beam fires once and the anchor clears.
- All five Core skills have separate icons. The HUD keeps the equipped icon visible through cooldown. Hovering the equipped slot or the bench preview shows the resolved behavior and modifiers.
- Compare the Rare skill's immediate team payoff with the Epic skill's deliberate setup during C-07 playtesting.

## Weapon-specific applications

The [variant definitions](../core_weapon_variants.gd) use the equipped weapon's ground or projectile delivery. This lets hybrid classes switch applications at the Gate with the same Core part. Slot modifiers and bought cards tune the resolved profile that drives both the preview and the host's cast.

| Core | Melee application | Ranged application |
|---|---|---|
| Phantom Step | Rush to the aimed spot and root enemies along the final stretch. | Root a strip across the projectile landing and step back up to 1.7 m. |
| Gravity Well | Open the well at your feet and draw enemies inward. | Place the well at an aimed location. |
| Ironbark | Raise warding plates across your position. | Send the plates to allies at the aimed position. |
| Hush | Interrupt windups in a forward fan from your position. | Interrupt windups in a fan at the projectile landing. |
| Riptide | Send a wave that draws enemies toward the caster, then heals allies on its return. | Send a wave that pushes enemies away from the caster, then heals allies on its return. |
| Dream Lure | Leave a decoy at your feet before moving away. | Send the decoy to an aimed location. |

The affected Core skills share their existing cooldowns, costs, and card IDs. A self-centered preview anchors the shape at the caster’s current position. Phantom Step uses the same terrain clipping for its movement preview and execution. If the caster moves during the windup, the host checks the final path from the caster's position at impact.

## Wilds adaptation evidence

Thorn Line records an opportunity when it arms and a successful outcome when a real enemy moves into it from outside. Encounter completion applies one learning update to the host world's existing memory, which lets later floors use that evidence after the world is reloaded. The Thornmaw Hound's response uses the shared enemy attack plan so the warning and landing agree in solo and co-op. See [Thorn adaptation](../thorn_adaptation.gd) and the [C-08 rollout](GARDEN_MILESTONES.md#c-08--full-core-tag-skill-rollout).


## Core roster

| Species | Primary tag | Active | Combat use |
|---|---|---|---|
| Thorn Bloom | `thorn` | Thorn Line | Grow a persistent line of thorns that damages enemies on contact and again while they remain inside. |
| Lantern Moss | `luminous` | Lantern Burst | Stagger nearby enemies between attacks. |
| Cinder Vine | `piercing` | Seed Lance | Sweep through up to three targets. |
| Whispervine | `whisper_mark` | Whisper Mark | Set up a teammate’s direct hit. |
| Star Orchid | `constellation` | Constellation | Place a star that automatically fires a rooting beam toward the cursor. |
| Ember Fern | `fire` | Ember Wake | Leaves a hot trail that burns on contact and again while enemies stay in it. |
| Storm Reed | `storm` | Chain Spark | The first hit jumps to up to two nearby enemies. Each enemy can be hit once. |
| Veilcap | `arcane` | Spore Seal | Plant three independent seals that each root one entrant after arming. |
| Dewcap | `water` | Dewfall | Drops a crosswise curtain that heals allies and clears Slowed. |
| Bloodbriar | `siphon` | Blood Siphon | Sweeps a thorn fan. Confirmed hits tether back and heal the caster up to two health. |
| Ghost Fern | `phase_step` | Phantom Step | Root the end of a forward dash or a strip across a ranged seed landing. |
| Moon Lotus | `lunar` | Moon Snare | Set a crescent trap that wounds and roots entrants, with extra damage during enemy windups. |
| Void Willow | `gravity` | Gravity Well | A spiral draws eligible enemies toward the center up to a per-target limit. |
| Sun Spire | `solar` | Sun Pillar | Four rays erupt from the pillar and push eligible enemies outward. |
| Eclipse Root | `eclipse` | Eclipse Maw | Two jaws funnel enemies into a seam and bite once. |
| Worldseed | `worldbloom` | Worldbloom | Roots branch out to hold enemies. The canopy heals each ally once on entry. |
| Frostbell | `frost` | Rime Bloom | A fan of petals applies Brittle. Shattering it roots the enemy. |
| Ironroot | `brace` | Ironbark | A row of bark plates wards allies against their next hit. |
| Mirror Mint | `echo` | Mirror Bloom | Bloom at the aimed point, then bloom on the opposite side of the caster’s cast position. |
| Gravemoss | `grave` | Grave Lantern | Watches for the first death inside its boundary and detonates at the corpse, including the final kill. |
| Tide Lily | `tide` | Riptide | Sends a moving wave from the caster that displaces idle enemies, then heals allies on the return. |
| Hush Orchid | `hush` | Hush | A fan interrupts up to three lesser enemies winding up. |
| Dream Poppy | `dream` | Dream Lure | A decoy redirects pursuers and shows which enemies are following it before bursting. |
| Crownroot | `link` | Crownlink | Links the two nearest enemies in the narrow band. The next direct hit on either sends damage to the other and consumes the link. |


Each ordinary or refined plant part inherits its species’ signature. Tags such as `vital`, `force`, `control`, and `radiant` are shared ingredients for compatible slot interactions. The content validator checks that every species has a signature and every authored plant tag participates as a primary or modifier.

## Standardized roster entries

New entries in [the Core roster](../core_skill_roster.gd) contain the signature, icon ID, range and footprint, slot rules, and checkpoint card. The aim preview and host use the same shape definitions. The host sends the committed shapes with each effect or field hint, so clients can draw a matching outline and animate the cast inside it. The same phase handler supports fields, heals, wards, positioning changes and interruptions. Chain Spark extends the swept projectile after its first contact. Grave Lantern uses a bounded death window and Crownlink uses the one-use mark lifecycle.

At a checkpoint, the card uses the same primary tag and skill ID as the equipped build. Purchased card tuning is applied to the host cast and the owner's HUD preview. A card phase and a graft phase can both apply to one cast. Effects use the existing health, status and weapon-hit paths and never trigger further Core casts.

For later adaptation planning, the roster now includes route denial, repeated area pressure, displacement, interruption, positional escape, decoys, linked hits and allied protection. The [Core and enemy interaction audit](CORE_ENEMY_INTERACTIONS.md) groups skills by the effects that actually happen during a fight and describes which outcomes now feed learning.

## Verified builds

The v0.5.3.1 footprint and animation pass uses protocol 29. Its source and packaged checks covered the Core roster, status snapshot replay, and four-player co-op. Live timing and balance remain part of C-07 playtesting.

The v0.5.2.4 weapon-variant build uses protocol 26. All players in a co-op session need the current build. The variant update passed 49 affected source suites, 40 selected packaged checks, startup smoke and four-player network smoke. Combat balance and readability remain part of C-07 playtesting.
