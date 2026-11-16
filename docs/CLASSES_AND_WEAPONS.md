> Current expansion: 24 species, seven class levels, 12 choices per class and 104 checkpoint cards. See [current content depth](CONTENT_DEPTH_2026-11-08.md); historical counts below describe earlier milestones.

# Classes, tagged weapons and monster grafts

> Legacy class and weapon reference. The [approved progression and altar constraints](COMBAT_BALANCE_MILESTONES.md#approved-card-and-progression-design) govern the future design.

## Playing this milestone
Open **F2 — Class & Weapon Workbench** at the Garden Heart between expeditions. Choose a class and one of its three basic weapons. The **Plant slots** tab sets Core, Form and Catalyst. The **Monster cargo** tab packs trophies from personal or shared stash. Empty plant slots are allowed for an unmodified starter weapon.

On departure, each occupied plant slot consumes one material. Reusing the same material in multiple slots requires that many copies. Monster cargo is withdrawn from stash into carried inventory, never pre-installed. The current cargo limit is six; it is defined once in weapon_system.gd. Successful extraction banks uninstalled trophies privately; defeat loses unbanked cargo. Installed grafts and crafted plant components last for the expedition.

At a discovered Wilds grafting shrine, **V** selects a carried monster trophy and **G** attempts to install it in slot four. Only monster materials are accepted. Neither the Garden altar nor weapon preparation can install them. Success fills the fourth slot; failure loses one trophy. Filled graft slots cannot be overwritten. Plant slots and purchased run upgrades survive a graft attempt.

**O → Classes** opens the living-root skill tree. Choose the class path to inspect, then select a node and press Learn at the Heart. Class combat XP, cultivation familiarity, monster familiarity, class choices and saved weapon plans belong to the character and travel to hosted Gardens. Host Garden knowledge and material stocks remain world-owned.

## Five roles / fifteen basic weapons

| Class | Basic weapons | Q skill |
|---|---|---|
| Warden | Rootblade; Briar Spear; Heartwood Maul | Guard: blocks one hit |
| Weaver (legacy Caster ID) | Spore Staff; Thorn Wand; Seed Focus | Rootbind: immobilizes a target |
| Ranger | Vine Bow; Bark Arbalest; Thorn Ring | Gale Volley: empowered strike and brief faster multi-target focus |
| Reaper | Graft Knives; Harvest Scythe; Root Lash | Reaping Step: safe approach, empowered strike and brief guard |
| Oracle | Bloom Bell; Spore Censer; Petal Fan | Renewal: heals nearby allies and grants brief regrowth |

Weapons have different reach, attack intervals, base damage, target limits and target patterns. Their actual abilities also depend on installed material tags. Prototype 3D models are generated from a reusable weapon kit; these are functional base assets, not final Blender-authored weapon art.

Two active skills per class are now available on Q and R. The table above lists the original Q skills; see [DUAL_CLASS_SKILLS.md](DUAL_CLASS_SKILLS.md) for both skills, replacements and level-up choices.

## Slots, tags and interactions

1. **Core:** strongest raw plant contribution, primary technique scaling, and an identity-tag effect.
2. **Form:** reduced raw contribution; its dominant matching tag can change the attack shape or behavior. Piercing yields a line, fire a splash, arcane/storm a chain, and radiant a sweep.
3. **Catalyst:** a smaller raw contribution with timing, class-skill, healing, utility or grafting modifiers from tags.
4. **Monster graft:** a unique monster trophy's effects and tags, added only at a Wilds shrine.

Duration modifiers extend Guard, Rootbind, Gale Focus, Reaping Step protection or Renewal regrowth according to the class.

The first matching tag in a material's ordered tag list selects the slot rule. All its tags remain available for cross-slot interaction rules. Fire + water produces Steam Bloom; void + lunar produces Eclipse Wake; vital + blood produces Sanguine Cycle; piercing + storm produces Storm Needle. The workbench previews the resolved attack and interaction names.

Single, line, sweep, splash and chain patterns select actual targets with range and terrain line-of-sight checks. Extra targets do not pass through forest boundaries or solid cover. Core damage, wind-up damage, recovery, pull, knockback, stagger, killing-strike healing and attack timing feed the authoritative combat system. Catalyst/class upgrades also affect Q skill cooldown/duration/healing, dodge recovery, health capacity, grafting chance and cultivation familiarity.

## Class choices
Every class has eight upgrades arranged as four two-way choice rows, requiring levels 2, 3, 4 and 5. Each level after the first grants a point. One upgrade may be chosen per row; a preceding-row choice is required. Class-specific choices include extra targets, reach, attack speed, defense, binding duration, healing, cultivation or grafting benefits. Learned nodes grow living roots in the existing tree.

Free Garden refunds return all spent points for the selected class. Choices cannot be learned or refunded during an expedition. The legacy Steady Hands / Wilds Scholar trait remains a separate level-two selection.

## Monster trophies
Each of the ten enemy species has a distinct trophy: Briar Hook, Nightbloom Pollen, Gallhorn Antler, Cantor Bellcap, Thornmaw Fang, Willow Sinew, Orchid Sac, Gravebud Husk, Wicker Sting and Brood Heart. Encounter loot can contain the current leader species' trophy, guaranteed every third encounter and otherwise at a 35% chance per player. These materials cannot be grown. Monster familiarity is species-specific and raises graft success; class choices can improve it further. First successful grafts grant discovery knowledge to the host Garden, with a lower repeat reward.

## Extending the system
- **class_catalog.gd:** authoritative class definitions, nested weapon templates and class-upgrade nodes. Append stable IDs. Frame metadata, character class arrays and menus derive from the catalog. Existing IDs 0/1 preserve Warden/Caster progress.
- **weapon_system.gd:** slot rules, interaction rules and resolved weapon statistics. Add tag rules with existing effect keys/patterns without changing combat. A genuinely new mechanic needs a combat handler before it is advertised.
- **seed_catalog.gd:** plant tags live beside lineage, rarity and growth definitions; plant materials inherit them.
- **weapon_parts.gd:** monster trophy tags, effects and enemy-source mapping. Append stable part IDs. The existing seed parts retain their IDs.
- **weapon_visuals.gd:** shared primitive 3D kit keyed by each weapon's visual field. It can be extended or replaced with imported models.
- **character_profile.gd:** per-class XP, upgrade masks, selected class, basic weapon and three-part plans. Old two-class profiles and three-species familiarity arrays expand safely.
- **progression_panel.gd / progression_tree.gd:** class-tree adapter and shared circular-node/vine view. **loadout_panel.gd** presents preparation and cargo.
- Example schemas: assets/data/class_template.json, weapon_template.json, monster_part_template.json. The first collection uses three weapons and eight upgrade nodes per class; keep the four two-choice rows unless extending the point/prerequisite rules.

## Validation
New tests cover all five classes, fifteen model builders, slot-specific tags, cross-tag interactions, mutually exclusive choices, refunds, migration, duplicate material costs, cargo transfer/loss, altar-only installation, target patterns and the normal class-skill action path. Co-op tests verify portable class choices, private stash costs, all three plant slots, fourth-slot monster grafts, synchronized combat and mid-run upgrade restrictions.

Existing seed, plot, HUD, shrine, save-slot, floor navigation, checkpoint, campaign and two-player checks remain part of the validation. All use isolated test saves. Screenshots in this directory show the workbench and class choice tree. Balance and weapon art remain an initial playable pass.

### Completed build checks
Passed the dedicated class/weapon test, fifteen-weapon render, tag/seed progression checks, slot import/migration, Garden plots, HUD, shrine/knockback, circular tree interactions, checkpoint extraction and 48 generated-map checks. The updated solo campaign and host/guest integration scenarios passed. The dedicated class co-op scenario also passed, including portable class choices, private crafting costs, transported monster cargo, fourth-slot graft synchronization and mid-run upgrade restrictions.

The Windows release pack passed a runtime check of class selection, three-slot crafting, cargo transfer, altar grafting, class-tree choices, HUD and weapon models. The executable itself passed startup (exit 0). Mystical Garden v0.1.exe was replaced after preserving its previous version in the Codex workspace work/change-preview/Mystical Garden v0.1-before-classes.exe. Tests used isolated saves.
