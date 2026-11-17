# Mechanics and test coverage map

Generated from `tools/test_map.json` by `test_workflow.py document`.

Edges describe gameplay/data relationships. Selection uses explicit suite coverage and resource dependencies; it does not follow every visual edge recursively.

```mermaid
flowchart LR
  affinity_cards["Affinity expedition cards<br/> rarity<br/> Essence rerolls and owned effects"]
  oracle_progression["Connected Oracle<br/> native Omens and first-run focus admission"]
  void_affinity["Void wells<br/> compression and bounded displacement"]
  spirit_affinity["Spirit stride<br/> traces and attack claims"]
  storm_affinity["Storm discharge and source-owned charges"]
  world_snapshot["Protocol 41 bounded unreliable world snapshots<br/> roster metadata and receive convergence"]
  wood_affinity["CR04B Wood<br/> finite Bark absorption and secondary splinters"]
  thorn_affinity["CR04B Thorn fields<br/> Bleed cadence and stationary patches"]
  vital_affinity["CR04A Vital<br/> native capacity and expedition regeneration"]
  water_affinity["CR04A Water<br/> Drenched impact-time damage and ordinary Slow cleansing"]
  fire_affinity["CR04A Fire<br/> Burning cadence and shared affinity combat clock"]
  frost_affinity["CR03 Frost and native Ward response ownership"]
  combat_affinity_contracts["CR02 development build resolution<br/> Catalyst contracts and event provenance"]
  plant_affinities["Explicit plant affinities and material quality for the inactive combat rework"]
  hex_terrain["Standalone M02 hex grid<br/> terrain data<br/> generator and welded surface"]
  persistence_operations["Opt-in guarded persistence operation scope and activation gate"]
  health_pool_hud["Main health pool and floor map layout"]
  persistence_save_access["Opt-in save directory bootstrap and passive inspection"]
  persistence_recovery_plan["Read-only save participant and journal discovery"]
  persistence_authorization["Native persistence operation authorization and legacy mutation containment"]
  foundation["Save formats<br/> identity<br/> transactions and global contracts"]
  seeds["Seed species<br/> cultivation and crossbreeding"]
  items["Item definitions<br/> stacks<br/> stash and safe pouch"]
  weapons["Crafting<br/> grafting<br/> part tags and weapon effects"]
  classes["Class levels<br/> choices and abilities"]
  combat["Cursor aiming<br/> hit shapes<br/> cooldowns and damage"]
  enemies["Enemy families<br/> bosses and adaptation"]
  terrain["Procedural paths<br/> collision and floor exploration"]
  garden["Garden beds<br/> care<br/> scenery and Heart appearance"]
  knowledge["Knowledge research and Garden unlocks"]
  progression["Reusable progression tree UI"]
  expeditions["Gates<br/> ready checks<br/> cards and extraction"]
  loot["Individual monster rewards and loot ownership"]
  life["Damage<br/> fallen state<br/> revival and spectating"]
  characters["Character roster<br/> models and customization"]
  menus["Main Menu and connections panel"]
  settings["Bindings<br/> audio<br/> display and aim settings"]
  presentation["HUD<br/> world drawing<br/> animation and effects"]
  diagnostics["Saved diagnostic logs and report export"]
  party_ui["Compact teammate portraits<br/> names<br/> health and fallen indicators"]
  gate_access["Gate interaction distances<br/> prompts and readiness boundaries"]
  garden_observations["Garden location hierarchy<br/> observation commands<br/> receipts and presentation"]
  garden_costs["Garden offering previews and existing party material claims"]
  garden_zones["Garden footprints<br/> water placement and stable bed membership"]
  garden_relationships["Authored plant conditions and existing Altar refinement clues"]
  garden_life["Cosmetic Garden wind<br/> water<br/> bounded moths and motion control"]
  garden_cinematics["Saved Garden expansion reveals<br/> growing roots and tracking camera"]
  garden_care["Crop-cycle identity<br/> optional care<br/> delayed rare harvest and flowering exclusion"]
  cultivation_growth["Tier growth times<br/> Wilds/Knowledge rates<br/> spring watering and seed harvest choice"]
  avatar_motion_view["Visible traveller gait<br/> weapon poses and grips"]
  garden_returns["Committed expedition banking/identification<br/> homecoming discovery and reactive life"]
  garden_conduit["Researched next-cycle Garden conditions and terrace presentation"]
  expedition_pressure["Avoidable escalating reinforcement waves and replicated spawn warnings"]
  expedition_ui["Numbered Wilds floor track<br/> revealed history and checkpoint icons"]
  heart_growth_visual["Per-technology Heart growth<br/> sapling/tree model and local cinematic interpolation"]
  garden_stations["Physical Garden stations<br/> trophy offerings<br/> reclamation and spring-water pickup"]
  menu_layout["Title navigation<br/> categorized settings and in-game menu layout"]
  ui_copy["Player-facing labels<br/> prompts<br/> help and upgrade descriptions"]
  enemy_attack_plan["Locked ordinary and elite attack geometry<br/> pose cues and tactic pressure selection"]
  encounter_composition["Biome-legal mixed packs<br/> reachable escorts<br/> gate access and terrain-aware reinforcements"]
  boss_lair_fights["Orchard and Drowned committed moves<br/> seeded crossing routes<br/> phase cues and exposure"]
  boss_phase_fights["Matriarch rib and hatch previews<br/> Nameless phase growth and committed memory attacks"]
  core_combat["Slot-aware Core builds<br/> aimed casts<br/> thorn contact and owner cooldowns"]
  ability_aim["Hold-to-aim<br/> release-to-cast previews and commands"]
  thorn_adaptation["Thorn Line evidence and the Thornmaw Hound's learned vault"]
  wilds_skill_tactics["Core interference evidence and learned enemy responses"]
  enemy_move_feedback["Resolved Wilds enemy move cues<br/> hazards and combat conditions"]
  warden_progression["Class subclasses<br/> neighboring skill branches<br/> cast presentation and checkpoint interactions"]
  weaver_progression["Connected Weaver progression<br/> native spells and Ward ownership"]
  ranger_progression["Connected Ranger choices<br/> Tracked Prey<br/> release-time projectiles and legal trap corridors"]
  reaper_progression["Connected Reaper choices<br/> native Death Charges and source-owned melee and Siphon effects"]
  connection_flow["Direct co-op endpoint sharing<br/> connection progress and retry"]
  developer_garden["Single-player developer settings<br/> isolated test Garden<br/> material stock and research tools"]
  thief_escape["Graft Thief trophy escape<br/> encounter completion and map trails"]
  soundscape["Garden and Wilds music<br/> biome ambience<br/> spatial emitters and volume controls"]
  event_audio["Event-driven party and spatial cues<br/> priority<br/> playback receipts and source events"]
  ranged_release["Cursor tracking through ranged wind-up and committed projectile launch"]
  class_tree_access["Class tree purchases and crafting navigation at the Wilds Gate"]
  class_skill_icons["Distinct Wilds HUD icons for equipped class skills"]
  expedition_summary["Wilds run summary<br/> private upgrade ranks<br/> combined stats and active bonuses"]
  glasscap_feints["Glasscap placement<br/> authoritative swaps and matching decoy models"]
  combat_vitals["HP units<br/> health resolution<br/> learning thresholds and capacity parity"]
  combat_balance_preview["Optional 100 HP combat preview<br/> Warden damage rolls and player/party health orbs"]
  weapon_balance["Weapon damage ranges<br/> fractional component bonuses<br/> hit snapshots and equipment previews"]
  class_balance["Class ability HP<br/> effects and progression previews"]
  core_balance["Core skill HP<br/> slot effects and checkpoint values"]
  healing_rolls["Healing rolls<br/> shared pulses and resolved HP ranges"]
  enemy_balance["Preview enemy durability<br/> damage and reinforcement budgets"]
  expedition_sustain["Expedition sustain<br/> heal feedback and health transitions"]
  spectator_layout["Spectator panel placement below the floor tracker"]
  expeditions -->|"Earned choices, owner revisions and expedition-only currency"| affinity_cards
  affinity_cards -->|"Source-scoped contributions captured by existing combat actions"| combat_affinity_contracts
  affinity_cards -->|"Acquired copy totals and inactive requirements in owner details"| expedition_summary
  class_tree_access -->|"level one focus admission and earned Oracle choices"| oracle_progression
  oracle_progression -->|"owned attack recovery and conditional support"| combat
  oracle_progression -->|"host-owned Omen details and status feedback"| world_snapshot
  class_tree_access -->|"earned connected Reaper choices"| reaper_progression
  reaper_progression -->|"Veil Dance uses actor clearance"| terrain
  reaper_progression -->|"one shared class and graft Death Charge budget and native hit lineage"| combat
  class_tree_access -->|"earned connected Ranger choices"| ranger_progression
  ranger_progression -->|"native corridor requires supported ground"| terrain
  ranger_progression -->|"precise direct hit and release-time prepared effects"| combat
  combat_affinity_contracts -->|"Host Frost responses and effect ownership"| frost_affinity
  plant_affinities -->|"Explicit material identities"| combat_affinity_contracts
  classes -->|"Native skill and focus adapters"| combat_affinity_contracts
  combat_affinity_contracts -->|"Development ruleset compatibility"| connection_flow
  seeds -->|"Stable species and ordinary material"| plant_affinities
  weapons -->|"Refined material and stable inventory identity"| plant_affinities
  seeds -->|"Parts and tags alter crafted weapons"| weapons
  seeds -->|"Discoveries and cultivation support Garden research"| knowledge
  items -->|"Seed stacks, storage and safe pouch"| seeds
  items -->|"Reservations, crafting costs and graft cargo"| weapons
  classes -->|"Class weapon families and traits"| weapons
  weapons -->|"Resolved damage, reach, cooldown and effects"| combat
  classes -->|"Abilities, upgrades and combat XP"| combat
  expeditions -->|"Checkpoint cards depend on installed components"| weapons
  enemies -->|"Attacks, defenses and adaptation"| combat
  enemies -->|"Per-monster reward tables"| loot
  loot -->|"Private dropped items and pickup"| items
  loot -->|"Monster trophies enable grafts and upgrades"| weapons
  terrain -->|"Movement, line of sight and projectile collision"| combat
  terrain -->|"Spawn placement and boss lairs"| enemies
  knowledge -->|"Research expands beds and unlocks services"| garden
  progression -->|"Discovery tree"| seeds
  progression -->|"Research tree"| knowledge
  progression -->|"Class choices"| classes
  life -->|"Revival, wipe, extraction and travel readiness"| expeditions
  settings -->|"Remapped strike and cursor aim"| combat
  characters -->|"Creation, selection, deletion and world entry"| menus
  presentation -->|"Hearts and spectator feedback"| life
  foundation -->|"Saved inventories and atomic transactions"| items
  foundation -->|"Stable identity, leases and saves"| characters
  foundation -->|"Authoritative state and network protocol"| expeditions
  diagnostics -->|"Crash, save and network diagnostics"| foundation
  diagnostics -->|"Damage and action traces"| combat
  diagnostics -->|"Issue markers and report export"| settings
  party_ui -->|"Public health, fallen state and revival"| life
  gate_access -->|"Prompts, readiness, crafting and cleared checkpoints"| expeditions
  foundation -->|"Existing save transactions own observation commits and rollback"| garden_observations
  knowledge -->|"Technology capabilities unlock authored location descendants"| garden_observations
  garden_observations -->|"Read-only state drives local inspection and post-commit cues"| presentation
  weapons -->|"Party loadout claims constrain shared and personal offerings"| garden_costs
  garden_costs -->|"Preview existing inventory availability; retain transactional payment"| items
  knowledge -->|"Completed existing technologies expose registered Garden places"| garden_zones
  garden_zones -->|"Layout anchors and parent zones use the existing inspection route"| garden_observations
  seeds -->|"Mature crops in registered beds enable authored observations"| garden_relationships
  garden_relationships -->|"Journal clues reference existing Altar recipes without granting outputs"| garden_observations
  garden_zones -->|"Read-only places bound cosmetic populations and water"| garden_life
  settings -->|"Local motion preference controls shaders and fauna"| garden_life
  knowledge -->|"Committed research queues a presentation"| garden_cinematics
  garden_cinematics -->|"Root destinations use registered beds and spring"| garden_zones
  garden_cinematics -->|"Water and fauna reveal after root arrival"| garden_life
  garden_cinematics -->|"Wilds and ready travel defer local presentation"| expeditions
  seeds -->|"Growth stages create a bounded crop opportunity"| garden_care
  garden_care -->|"One existing harvest pays ordinary/rare parts or seeds"| items
  garden_care -->|"Familiarity remains a harvest-only reward"| characters
  garden_care -->|"Existing Garden route and private cultivation projection"| garden_observations
  cultivation_growth -->|"Time-based watering and preservation share one crop clock"| garden_care
  expeditions -->|"One world-level Wilds multiplier; no per-player stacking"| cultivation_growth
  knowledge -->|"Irrigation/nursery remain growth-rate modifiers"| cultivation_growth
  avatar_motion_view -->|"Rendered travel drives synchronized gait phases, hip motion and facing"| presentation
  expeditions -->|"One saved run identity and bank/outcome receipts"| garden_returns
  garden_returns -->|"Only identified banked discoveries trigger persistent cosmetic responses"| garden_life
  garden_returns -->|"Existing local scene queue and per-viewer acknowledgements"| garden_cinematics
  knowledge -->|"Existing focused research unlocks a usable terrace tool"| garden_conduit
  garden_zones -->|"Catalog footprint and existing universal bed membership"| garden_conduit
  garden_conduit -->|"Host setting snapshots a bounded policy for future crop cycles"| garden_care
  characters -->|"Shared rig and palm sockets align customized bodies with authored weapon poses"| weapons
  expedition_pressure -->|"Normal enemy attacks, bounded populations and safe spawn sites"| enemies
  expedition_pressure -->|"Clear/travel cancels pending waves"| expeditions
  expedition_pressure -->|"Owner snapshots replicate labeled spawn warnings"| presentation
  expeditions -->|"Authoritative global floor drives the read-only HUD"| expedition_ui
  expedition_ui -->|"Root-connected numbered nodes and checkpoint icons"| presentation
  knowledge -->|"Completed technologies determine persistent visual size"| heart_growth_visual
  garden_cinematics -->|"Each unlock animates one permanent growth step"| heart_growth_visual
  knowledge -->|"researched landmarks"| garden_stations
  garden_stations -->|"spring water carried to a bed"| garden_care
  garden_stations -->|"local station transactions"| items
  menu_layout -->|"screen navigation and existing menu actions"| menus
  ui_copy -->|"screen labels and help"| menus
  ui_copy -->|"research and class descriptions"| progression
  ui_copy -->|"checkpoint prompts and cards"| expeditions
  enemies -->|"host move choice and warning geometry"| enemy_attack_plan
  enemy_attack_plan -->|"locked attack posture and telegraph"| presentation
  enemy_attack_plan -->|"committed landing and hit area"| combat
  enemy_attack_plan -->|"Support intents lock corpses, broods, allies and trophy drops by stable IDs"| enemies
  encounter_composition -->|"Gate elites and their complements use the same move and warning data"| enemy_attack_plan
  encounter_composition -->|"Escorts and modifiers need a reachable site with room near the gate"| terrain
  encounter_composition -->|"Reinforcements select mobile roles for narrow terrain"| expedition_pressure
  boss_lair_fights -->|"Host and guest use the same dry crossing landmarks and test escape routes against floor collision"| terrain
  boss_lair_fights -->|"Boss wind-ups and active hazards use the host-committed radius, sector and timing"| presentation
  boss_lair_fights -->|"Uprooting and exposed core windows use the shared status and weapon hit flow"| combat
  boss_lair_fights -->|"Lair move plans share the existing rare boss selection and reward flow"| loot
  boss_phase_fights -->|"Rib previews and host and guest collision share exact phase rectangles"| terrain
  boss_phase_fights -->|"The phase fights reuse escape checks and the host-owned exposure window"| boss_lair_fights
  boss_phase_fights -->|"Replicated lane and hatch warnings use the committed attack geometry"| enemy_attack_plan
  boss_phase_fights -->|"Matriarch young use the same nonrewarding summon path"| loot
  gate_access -->|"Overlapping onward gates and grafting shrines use nearest interaction for both prompt and authority"| terrain
  weapons -->|"Resolve the Core part and delivery alongside slot-qualified tags"| core_combat
  settings -->|"Rebindable mouse-aimed Core cast"| core_combat
  life -->|"Living casters only, with cooldown carried through revival"| core_combat
  expeditions -->|"Expire Core growth on floor change and reset cooldown on departure"| core_combat
  terrain -->|"Validate placement and match swept contact to the displayed footprint"| core_combat
  enemies -->|"Root the first living enemy whose movement crosses the line"| core_combat
  foundation -->|"Validate the host's world and owner scope before accepting a cast"| core_combat
  presentation -->|"Show the committed line, rooted status and private cooldown"| core_combat
  diagnostics -->|"Record authoritative casts and trips by stable skill and cast IDs"| core_combat
  classes -->|"Root Quake can trip a Catalyst-primed thorn line"| core_combat
  core_combat -->|"Slot-qualified checkpoint offers and purchased Thorn Line behaviors"| expeditions
  weapons -->|"All weapon motions supply placement, delivery and timing"| core_combat
  items -->|"Equipped Core and graft effects appear in private inventory"| core_combat
  core_combat -->|"Monster graft can change later Thorn Line casts"| loot
  seeds -->|"Species signatures survive ordinary and refined harvests"| core_combat
  core_combat -->|"One resolved tooltip and icon for the crafting bench and the Wilds"| presentation
  core_combat -->|"Signature projectile marks consume on allied direct hits and anchored beams reuse swept contact"| combat
  ability_aim -->|"Class target selection shares its range and landing geometry with the cast"| classes
  ability_aim -->|"Core aiming projects its placement and recast geometry"| core_combat
  ability_aim -->|"The host commits the guest's release direction in the same floor and life"| combat
  core_combat -->|"Armed Thorn Lines and successful ground crossings supply evidence"| thorn_adaptation
  thorn_adaptation -->|"Eligible Thornmaw Hounds can lock a warned vault over a live line"| enemy_attack_plan
  core_combat -->|"Confirmed Core hits and cancellations contribute to host-world learning"| wilds_skill_tactics
  wilds_skill_tactics -->|"Eligible regular enemies lock one response using the shared warning geometry"| enemy_attack_plan
  enemy_attack_plan -->|"Committed and resolved move geometry drives warnings, effects and status callouts"| enemy_move_feedback
  classes -->|"The Warden subclass defines its first class skill and connected nodes change the block and Quake interactions"| warden_progression
  core_combat -->|"Root Quake can trip an armed Force Catalyst Thorn Line to activate Thorn Shelter"| warden_progression
  warden_progression -->|"Skill tooltips, owner anchor previews and the prepared Quake status use the host result"| presentation
  warden_progression -->|"An affordable eligible Warden branch card competes with an equipped Core and a flexible card"| expeditions
  connection_flow -->|"Host and Join share a copyable endpoint and preserve the form when a connection fails"| menus
  connection_flow -->|"Join progress and retry follow compatibility and character registration without claiming a Garden slot"| characters
  connection_flow -->|"Direct transport, compatibility, registration and first world state are distinct join stages"| diagnostics
  developer_garden -->|"Settings launches a test Garden with its own save lease and restores the normal menu on exit"| menus
  developer_garden -->|"Developer tools use the normal research completion and Garden save path"| knowledge
  developer_garden -->|"The test Garden rejects hosting and joining before transport starts"| connection_flow
  thief_escape -->|"Escape paths use connected floor navigation and waypoints that the thief can reach"| terrain
  thief_escape -->|"An escaped actor leaves the floor count without a kill or its trophy reward"| expeditions
  thief_escape -->|"Host escape routes drive the party minimap and local tunnel marker"| presentation
  soundscape -->|"Music and Ambience buses use independent persistent volume settings"| settings
  soundscape -->|"The spring emitter follows its unlocked Garden capability"| garden_zones
  soundscape -->|"The mix follows local Garden or Wilds state, biome, floor depth and boss state"| expeditions
  event_audio -->|"One-shot cues use the effects bus while ambience and score stay independent"| soundscape
  event_audio -->|"A committed trophy theft emits one alert to the party"| thief_escape
  event_audio -->|"A committed clear plays the gate or extraction cue once"| expeditions
  event_audio -->|"Committed research plays its cue at the Garden reveal or when the player skips growth scenes"| garden_cinematics
  weapons -->|"Weapon delivery and contact phase drive the two grips and the displayed shaft"| avatar_motion_view
  ranged_release -->|"Cursor updates steer the draw pose through release, then the projectile follows the committed aim"| avatar_motion_view
  weapons -->|"Crafting opens the Class tree and returns to the prepared loadout"| class_tree_access
  class_tree_access -->|"Learning uses one location rule in the panel and on the host"| classes
  developer_garden -->|"The material tool stocks shared parts and personal seeds through the ordinary inventory and Garden save paths"| items
  developer_garden -->|"Stocked parts are available to the weapon bench and monster cargo selection"| weapons
  classes -->|"Equipped skill identity selects the icon, including subclass and saved replacement skills"| class_skill_icons
  weapons -->|"Resolved combat stats and active weapon interactions feed the summary"| expedition_summary
  expeditions -->|"Purchased checkpoint ranks feed owner-only cards and their tooltips"| expedition_summary
  settings -->|"The Wilds summary uses the configurable Tab action"| expedition_summary
  glasscap_feints -->|"Decoy placement and swap destinations must be open"| terrain
  glasscap_feints -->|"Completed Watcher volleys can move the real actor"| enemy_attack_plan
  glasscap_feints -->|"Host formation state drives identical scout and elite decoy bodies"| presentation
  combat_vitals -->|"Damage, healing, maximum HP and revival cost"| life
  combat_vitals -->|"Party-scaled pools and percentage phase thresholds"| enemies
  combat_vitals -->|"Normalized burst and ranged evidence"| wilds_skill_tactics
  combat_vitals -->|"Applied amounts and capacity drive health feedback"| presentation
  combat_balance_preview -->|"Maps authored damage and healing to the preview health scale"| combat_vitals
  combat_balance_preview -->|"Locks one roll at commitment and publishes matching stat ranges"| weapons
  combat_balance_preview -->|"Local feedback and simplified authoritative party orbs"| party_ui
  combat_balance_preview -->|"Rejects mixed health scales before registration"| connection_flow
  combat_balance_preview -->|"Guaranteed Orchard preview floor and unchanged phase ratios"| boss_lair_fights
  weapon_balance -->|"Each class weapon authors its own roll spread and components use the existing slots"| weapons
  weapon_balance -->|"Projects authored amounts at hit and heal resolution"| combat_balance_preview
  weapon_balance -->|"Direct contacts share one roll and delayed effects use the captured strike"| combat
  weapon_balance -->|"Component IDs are stable and inventory describes full-strength HP bonuses"| items
  weapon_balance -->|"The equipped and projected weapon ranges use the same calculation"| expedition_summary
  class_balance -->|"Resolves class damage, healing and guard from learned skills"| classes
  class_balance -->|"Uses equipped modifiers and the committed weapon roll for empowered strikes"| weapon_balance
  class_balance -->|"Projects authored class effects onto preview HP and preserves legacy profiles"| combat_balance_preview
  core_balance -->|"Keeps authored points through Core contact and converts once at the HP boundary"| core_combat
  core_balance -->|"Projects the resolved Core and aggregate card ranks"| expedition_summary
  core_balance -->|"Adds marks and links to the committed strike through the shared hit path"| weapon_balance
  healing_rolls -->|"Rolls healing on its own stream and clamps the result to current capacity"| combat_balance_preview
  healing_rolls -->|"Shares direct heals and rolls each Renewal tick"| class_balance
  healing_rolls -->|"Keeps one heal roll for the whole wave or canopy"| core_balance
  healing_rolls -->|"Shows resolved healing ranges and flat stat bonuses"| expedition_summary
  healing_rolls -->|"Rolls floor recovery once for the living party"| expeditions
  enemy_balance -->|"Applies species HP, contact damage and body budgets"| enemies
  enemy_balance -->|"Limits and tunes telegraphed waves in later loops"| expedition_pressure
  enemy_balance -->|"Scales phase pressure, hazards and exposure without changing telegraph shapes"| boss_lair_fights
  enemy_balance -->|"Applies native preview HP and retains ordinary combat rules"| combat_balance_preview
  expedition_sustain -->|"Applies shared recovery rolls with healing limits and actual amounts"| healing_rolls
  expedition_sustain -->|"Distinguishes healing from earned or lost maximum HP"| life
  expedition_sustain -->|"Shows the kill budget and the next gate recovery range"| expedition_summary
  expedition_sustain -->|"Keeps health readouts and fallen state authoritative"| party_ui
  spectator_layout -->|"Keeps watched ally health and the floor legend visible together"| party_ui
```

## System ownership and tests

| System | Source files | Covering suites |
|---|---|---|
| affinity_cards | `affinity_cards.gd`, `affinity_cards.gd.uid`, `affinity_card_catalog.gd`, `affinity_card_catalog.gd.uid` | `ec01_affinity_cards_party`, `ec01_affinity_cards`, `cr02_mode_coop` |
| oracle_progression | `oracle_connected_tree.gd`, `oracle_connected_tree.gd.uid`, `oracle_combat.gd`, `oracle_combat.gd.uid`, `oracle_omens.gd`, `oracle_omens.gd.uid` | `ct05_oracle`, `ct05_oracle_coop`, `ct05_oracle_party` |
| void_affinity | `void_affinity.gd`, `void_affinity.gd.uid` | `cr04c_void`, `cr04c_void_coop`, `cr04c_mixed_party` |
| spirit_affinity | `spirit_affinity.gd`, `spirit_affinity.gd.uid` | `cr04c_mixed_party`, `cr04c_spirit`, `cr04c_spirit_coop` |
| storm_affinity | `storm_affinity.gd`, `storm_affinity.gd.uid` | `cr04c_mixed_party`, `cr04c_storm`, `cr04c_storm_coop` |
| world_snapshot | `world_snapshot.gd`, `world_snapshot.gd.uid` | `ec01_affinity_cards_party`, `ct05_oracle_coop`, `ct05_oracle_party`, `ct01_warden_coop`, `ct02_weaver_coop`, `ct02_weaver_party`, `ct03_ranger_coop`, `ct03_ranger_party`, `ct04_reaper_coop`, `ct04_reaper_party`, `cr05_native_grafts_coop`, `cr05_native_grafts_party`, `cr04c_void_coop`, `cr04c_mixed_party`, `cr04c_spirit_coop`, `cr04c_storm_coop`, `world_snapshot_codec`, `cr04b_wood_coop`, `cr04b_mixed_party`, `cr04b_thorn_coop`, `cr04a_mixed_party`, `cr02_mode_mismatch`, `cr02_definitions_mismatch`, `experimental_terrain_coop`, `candidate_release_party`, `guarded_expedition_coop`, `diagnostics_coop`, `four_players_coop`, `network_movement_coop`, `network_presentation`, `status_feedback_coop`, `weapon_actions_coop` |
| wood_affinity | `wood_affinity.gd`, `wood_affinity.gd.uid` | `cr04b_wood`, `cr04b_wood_coop`, `cr04b_mixed_party` |
| thorn_affinity | `thorn_affinity.gd`, `thorn_affinity.gd.uid` | `cr04b_wood`, `cr04b_mixed_party`, `cr04b_thorn`, `cr04b_thorn_coop` |
| vital_affinity | `vital_combat.gd`, `vital_combat.gd.uid` | `cr04a_vital`, `cr04a_vital_coop`, `cr04a_mixed_party` |
| water_affinity | `water_combat.gd`, `water_combat.gd.uid` | `cr04a_vital`, `cr04a_mixed_party`, `cr04a_water`, `cr04a_water_coop` |
| fire_affinity | `affinity_time.gd`, `affinity_time.gd.uid`, `fire_combat.gd`, `fire_combat.gd.uid` | `cr04a_vital`, `cr04a_mixed_party`, `cr04a_water`, `cr04a_fire`, `cr04a_fire_coop` |
| frost_affinity | `frost_balance.gd`, `frost_balance.gd.uid`, `frost_combat.gd`, `frost_combat.gd.uid`, `ward_responses.gd`, `ward_responses.gd.uid` | `cr04a_vital`, `cr04a_vital_coop`, `cr04a_mixed_party`, `cr04a_water`, `cr04a_water_coop`, `cr04a_fire_coop`, `cr03_frost`, `cr03_frost_coop`, `cr03_frost_party` |
| combat_affinity_contracts | `affinity_build.gd`, `affinity_build.gd.uid`, `catalyst_adapters.gd`, `catalyst_adapters.gd.uid`, `combat_action_events.gd`, `combat_action_events.gd.uid`, `combat_ruleset.gd`, `combat_ruleset.gd.uid`, `native_grafts.gd`, `native_grafts.gd.uid` | `ec01_affinity_cards_party`, `ec01_affinity_cards`, `ct05_oracle`, `ct05_oracle_coop`, `ct05_oracle_party`, `ct01_warden`, `ct01_warden_coop`, `ct02_weaver`, `ct02_weaver_coop`, `ct02_weaver_party`, `ct03_ranger`, `ct03_ranger_coop`, `ct03_ranger_party`, `ct04_reaper`, `ct04_reaper_coop`, `ct04_reaper_party`, `cr05_native_grafts`, `cr05_native_grafts_coop`, `cr05_native_grafts_party`, `cr04c_void`, `cr04c_void_coop`, `cr04c_mixed_party`, `cr04c_spirit`, `cr04c_spirit_coop`, `cr04c_storm`, `cr04c_storm_coop`, `cr04b_wood`, `cr04b_wood_coop`, `cr04b_mixed_party`, `cr04b_thorn`, `cr04b_thorn_coop`, `cr04a_vital`, `cr04a_vital_coop`, `cr04a_mixed_party`, `cr04a_water`, `cr04a_water_coop`, `cr04a_fire`, `cr04a_fire_coop`, `cr03_frost`, `cr03_frost_coop`, `cr03_frost_party`, `cr02_combat_contracts`, `cr02_mode_coop`, `cr02_mode_mismatch`, `cr02_definitions_mismatch` |
| plant_affinities | `plant_affinities.gd`, `plant_affinities.gd.uid` | `cr04a_fire`, `cr03_frost`, `cr02_combat_contracts`, `plant_affinities` |
| hex_terrain |  | `ec01_affinity_cards_party`, `ct05_oracle_coop`, `ct05_oracle_party`, `ct03_ranger_coop`, `ct03_ranger_party`, `ct04_reaper_coop`, `ct04_reaper_party`, `cr04b_wood_coop`, `cr04b_mixed_party`, `cr04b_thorn_coop`, `cr04a_vital_coop`, `cr04a_mixed_party`, `cr04a_water_coop`, `cr04a_fire_coop`, `cr03_frost_coop`, `cr03_frost_party`, `cr02_mode_coop`, `experimental_terrain_coop`, `experimental_terrain`, `garden_offerings_preview`, `garden_knowledge_preview`, `garden_construction`, `garden_expansion`, `wilds_combat_preview`, `wilds_route_variation`, `wilds_boundary`, `wilds_play_floor`, `wilds_massing`, `wilds_biomes`, `terrain_continuity`, `terrain_botanical_art`, `terrain_enclosure`, `terrain_features`, `hex_terrain`, `projectile_terrain` |
| persistence_operations | `guest_profile_projection.gd`, `guest_profile_projection.gd.uid`, `guarded_title_session.gd`, `guarded_title_session.gd.uid`, `legacy_save_import.gd`, `legacy_save_import.gd.uid`, `persistence_operations.gd`, `persistence_operations.gd.uid`, `persistence_writer_integration.gd`, `persistence_writer_integration.gd.uid` | `experimental_terrain`, `legacy_import_recovery`, `legacy_mutation_containment`, `candidate_release_solo`, `candidate_release_party`, `production_persistence`, `guest_projection_coop`, `serializer_integrity`, `guarded_lifecycle`, `guarded_lifecycle_coop`, `guarded_expedition`, `guarded_expedition_coop`, `guarded_garden_actions`, `guarded_garden_actions_coop`, `guarded_gameplay_transactions`, `guarded_title_session`, `persistence_destructive_slots`, `persistence_slot_roster`, `persistence_group_one`, `persistence_restart_recovery`, `persistence_durable_evidence`, `persistence_outcomes`, `persistence_operations` |
| health_pool_hud | `health_pool.gdshader`, `health_pool.gdshader.uid` | `exploration_ui`, `four_players_coop`, `party_hud_gates`, `player_hud`, `combat_balance_saves`, `combat_balance_preview`, `combat_balance_preview_coop` |
| persistence_save_access | `persistence_save_inspection.gd`, `persistence_save_inspection.gd.uid` | `legacy_import_recovery`, `production_persistence`, `serializer_integrity`, `guarded_lifecycle`, `guarded_lifecycle_coop`, `guarded_title_session`, `persistence_destructive_slots`, `persistence_operations`, `persistence_save_access` |
| persistence_recovery_plan | `persistence_recovery_plan.gd`, `persistence_recovery_plan.gd.uid`, `persistence_evidence.gd`, `persistence_evidence.gd.uid` | `legacy_import_recovery`, `legacy_mutation_containment`, `production_persistence`, `serializer_integrity`, `guarded_lifecycle`, `guarded_lifecycle_coop`, `guarded_expedition`, `guarded_expedition_coop`, `guarded_garden_actions`, `guarded_gameplay_transactions`, `guarded_title_session`, `persistence_destructive_slots`, `persistence_slot_roster`, `persistence_group_one`, `persistence_restart_recovery`, `persistence_durable_evidence`, `persistence_outcomes`, `persistence_operations`, `persistence_save_access`, `persistence_recovery_plan` |
| persistence_authorization | `legacy_persistence.gd`, `legacy_persistence.gd.uid`, `persistence_authorization.gd`, `persistence_authorization.gd.uid`, `persistence_save_layout.gd`, `persistence_save_layout.gd.uid`, `assets/native/persistence_lock/persistence_lock.gdextension`, `assets/native/persistence_lock/persistence_lock.gdextension.uid`, `assets/native/persistence_lock/b0_native_lock.dll` | `legacy_import_recovery`, `legacy_mutation_containment`, `candidate_release_solo`, `candidate_release_party`, `production_persistence`, `serializer_integrity`, `guarded_lifecycle`, `guarded_lifecycle_coop`, `guarded_expedition`, `guarded_expedition_coop`, `guarded_garden_actions`, `guarded_gameplay_transactions`, `guarded_title_session`, `persistence_destructive_slots`, `persistence_slot_roster`, `persistence_group_one`, `persistence_restart_recovery`, `persistence_durable_evidence`, `persistence_outcomes`, `persistence_operations`, `persistence_save_access`, `persistence_recovery_plan`, `persistence_authorization` |
| foundation | `save_batch.gd`, `game_transaction.gd`, `progress.gd`, `character_profile.gd`, `content_ids.gd`, `network_compatibility.gd`, `network_settings.gd`, `content_validator.gd`, `project.godot`, `world.tscn`, `main_menu.tscn`, `export_presets.cfg`, `save_slots.gd` | `All registered suites (implicit shared contract)` |
| seeds | `seed_catalog.gd`, `altar_recipes.gd`, `altar_service.gd`, `planting_panel.gd`, `garden_altar_panel.gd`, `altar_input_slot.gd` | `plant_affinities`, `guarded_garden_actions`, `boss_coop`, `boss_roster`, `classes_coop`, `classes_weapons`, `crafting_availability_coop`, `cultivation_growth`, `foundations`, `garden_altar`, `garden_cleanup`, `garden_cleanup_coop`, `garden_crop_care`, `garden_crop_care_coop`, `garden_returns`, `garden_returns_coop`, `garden_spring`, `garden_spring_coop`, `gardening`, `gate_garden_services`, `heart_progression`, `inventory_grid`, `inventory_party`, `network_research_coop`, `seed_coop`, `seed_inventory`, `seed_progression`, `seed_template`, `species_depth`, `timed_research`, `tree_portraits`, `developer_garden` |
| items | `item_catalog.gd`, `inventory_model.gd`, `inventory_panel.gd`, `inventory_slot.gd`, `inventory_drop_surface.gd`, `inventory_drop_visuals.gd` | `plant_affinities`, `candidate_release_solo`, `guarded_garden_actions`, `checkpoint_extraction`, `classes_coop`, `classes_weapons`, `core_starters`, `crafting_availability_coop`, `cultivation_growth`, `diagnostics`, `foundations`, `four_players_coop`, `garden_altar`, `garden_cleanup`, `garden_cleanup_coop`, `garden_conduit`, `garden_crop_care`, `garden_crop_care_coop`, `garden_interactions`, `garden_interactions_coop`, `garden_returns`, `garden_returns_coop`, `garden_spring`, `garden_spring_coop`, `gate_crafting_rules`, `grafting_menu`, `inventory_grid`, `inventory_party`, `loot_revival`, `loot_revival_coop`, `monster_rewards`, `player_hud`, `seed_coop`, `seed_inventory`, `seed_template`, `species_depth`, `developer_garden` |
| weapons | `weapon_parts.gd`, `weapon_system.gd`, `weapon_frames.gd`, `loadout_materials.gd`, `loadout_panel.gd`, `grafting_panel.gd` | `ec01_affinity_cards`, `cr05_native_grafts`, `cr05_native_grafts_coop`, `cr05_native_grafts_party`, `cr04b_wood`, `cr04b_thorn`, `cr04a_vital`, `cr04a_vital_coop`, `cr04a_mixed_party`, `cr04a_water`, `cr04a_water_coop`, `cr04a_fire`, `cr04a_fire_coop`, `cr03_frost`, `cr03_frost_coop`, `cr03_frost_party`, `cr02_combat_contracts`, `cr02_mode_coop`, `plant_affinities`, `guarded_garden_actions`, `guarded_garden_actions_coop`, `boss_roster`, `character_locomotion`, `character_overhaul`, `character_rig`, `class_depth`, `class_depth_coop`, `classes_coop`, `classes_weapons`, `combat_animation`, `core_combat`, `core_combat_coop`, `core_modifiers`, `core_roster`, `core_roster_coop`, `core_signatures`, `core_signatures_coop`, `core_starters`, `crafting_availability_coop`, `dual_skills`, `dual_skills_coop`, `enemy_depth`, `foundations`, `four_players_coop`, `garden_altar`, `garden_interactions`, `garden_interactions_coop`, `garden_spring`, `garden_spring_coop`, `gate_crafting_rules`, `gate_garden_services`, `grafting_menu`, `inventory_grid`, `inventory_party`, `menu_coop`, `mouse_combat`, `mouse_combat_coop`, `network_presentation`, `network_warden_coop`, `party_ready`, `party_ready_coop`, `run_flow`, `seed_coop`, `seed_template`, `shrines_hits`, `species_depth`, `status_feedback`, `warden_depth`, `warden_depth_coop`, `weapon_actions`, `weapon_actions_coop`, `weighted_upgrades`, `developer_garden`, `core_balance_preview` |
| classes | `class_experience.gd`, `class_experience.gd.uid`, `class_catalog.gd`, `skill_catalog.gd`, `combat_traits.gd` | `ec01_affinity_cards_party`, `ec01_affinity_cards`, `ct05_oracle`, `ct05_oracle_coop`, `ct05_oracle_party`, `ct01_warden`, `ct01_warden_coop`, `ct02_weaver`, `ct02_weaver_coop`, `ct02_weaver_party`, `ct03_ranger`, `ct03_ranger_coop`, `ct03_ranger_party`, `ct04_reaper`, `ct04_reaper_coop`, `ct04_reaper_party`, `cr05_native_grafts`, `cr05_native_grafts_coop`, `cr05_native_grafts_party`, `cr04b_wood`, `cr04b_thorn`, `cr04a_vital`, `cr04a_water`, `cr04a_fire`, `cr03_frost`, `cr02_combat_contracts`, `guarded_garden_actions`, `guarded_garden_actions_coop`, `class_depth`, `class_depth_coop`, `classes_coop`, `classes_weapons`, `core_modifiers`, `core_starters`, `dual_skills`, `dual_skills_coop`, `enemy_depth`, `foundations`, `four_players_coop`, `inventory_party`, `monster_rewards`, `mouse_combat`, `projectile_terrain`, `mouse_combat_coop`, `network_warden_coop`, `player_hud`, `run_flow`, `seed_template`, `species_depth`, `status_feedback`, `status_feedback_coop`, `warden_depth`, `warden_depth_coop`, `weapon_actions`, `weighted_upgrades`, `warden_prototype`, `warden_prototype_coop`, `subclass_skills`, `class_balance_preview` |
| combat | `mouse_combat.gd`, `attack_geometry.gd`, `weapon_motion.gd`, `enemy_hurtbox.gd`, `enemy_hurtbox.gd.uid`, `weapon_contact.gd`, `weapon_contact.gd.uid`, `combat_status.gd`, `combat_status.gd.uid` | `ec01_affinity_cards_party`, `ec01_affinity_cards`, `ct05_oracle`, `ct05_oracle_coop`, `ct05_oracle_party`, `ct01_warden`, `ct01_warden_coop`, `ct02_weaver`, `ct02_weaver_coop`, `ct02_weaver_party`, `ct03_ranger`, `ct03_ranger_coop`, `ct03_ranger_party`, `ct04_reaper`, `ct04_reaper_coop`, `ct04_reaper_party`, `cr05_native_grafts`, `cr04c_void`, `cr04c_spirit`, `cr04c_storm`, `cr04b_wood`, `cr04b_thorn`, `cr04a_vital`, `cr04a_water`, `candidate_release_solo`, `guarded_expedition`, `guarded_expedition_coop`, `boss_coop`, `boss_lairs`, `boss_phase_fights`, `boss_roster`, `class_depth`, `class_depth_coop`, `classes_coop`, `classes_weapons`, `combat_animation`, `combat_balance`, `combat_readability`, `combat_readability_coop`, `core_combat`, `core_combat_coop`, `core_modifiers`, `core_roster`, `core_roster_coop`, `core_signatures`, `core_signatures_coop`, `core_starters`, `core_weapon_variants`, `diagnostics`, `diagnostics_coop`, `dual_skills`, `dual_skills_coop`, `enemy_depth`, `enemy_support`, `four_players_coop`, `gate_elites`, `gate_elites_coop`, `grafting_menu`, `health_points`, `menu_coop`, `monster_behaviors`, `mouse_combat`, `projectile_terrain`, `mouse_combat_coop`, `network_presentation`, `network_warden_coop`, `player_hud`, `shrines_hits`, `status_feedback`, `status_feedback_coop`, `supplied_network_smoke`, `support_deaths`, `support_rite_responses`, `support_rite_responses_coop`, `terrain_generation_coop`, `warden_depth`, `warden_depth_coop`, `weapon_actions`, `weapon_actions_coop`, `weighted_upgrades`, `regular_enemy_responses`, `regular_enemy_responses_coop`, `thief_escape`, `thief_escape_coop` |
| enemies | `enemy_catalog.gd`, `enemy_behaviors.gd`, `boss_encounters.gd`, `combat_director.gd`, `wilds_learning.gd`, `game_balance.gd`, `elite_enemy.gd`, `elite_enemy.gd.uid` | `boss_coop`, `boss_lairs`, `boss_phase_fights`, `boss_roster`, `combat_animation`, `combat_balance`, `combat_readability`, `combat_readability_coop`, `enemy_depth`, `enemy_roster`, `enemy_support`, `expedition_pressure`, `expedition_pressure_coop`, `gate_elites`, `gate_elites_coop`, `monster_behaviors`, `monster_rewards`, `shrines_hits`, `status_feedback`, `support_deaths`, `terrain_generation`, `enemy_balance_preview` |
| terrain | `battlefield.gd`, `encounter_config.gd`, `exploration.gd`, `walkable_surface.gd`, `walkable_surface.gd.uid`, `wilds_layout.gd`, `wilds_layout.gd.uid` | `ct03_ranger`, `ct04_reaper`, `experimental_terrain_coop`, `experimental_terrain`, `boss_coop`, `boss_lairs`, `boss_phase_fights`, `boss_roster`, `core_combat`, `core_combat_coop`, `core_modifiers`, `core_weapon_variants`, `expedition_pressure`, `exploration_maps`, `exploration_ui`, `garden_presentation`, `gate_elites`, `loot_revival`, `loot_revival_coop`, `menu_controls`, `mouse_combat`, `projectile_terrain`, `mouse_combat_coop`, `natural_world`, `network_movement_coop`, `network_presentation`, `path_junctions`, `shrines_hits`, `support_rite_responses`, `terrain_generation`, `terrain_generation_coop`, `weapon_actions`, `wilds_skill_tactics`, `regular_enemy_responses`, `thief_escape`, `thief_escape_coop` |
| garden | `garden_visuals.gd`, `heart_visuals.gd` | `cr04a_vital_coop`, `cr04a_water_coop`, `cr04a_fire_coop`, `cr03_frost_coop`, `cr02_mode_coop`, `experimental_terrain_coop`, `candidate_release_solo`, `candidate_release_party`, `guest_projection_coop`, `garden_cleanup`, `garden_cleanup_coop`, `garden_interactions`, `garden_interactions_coop`, `garden_presentation`, `gardening`, `gate_garden_services`, `heart_progression`, `network_research_coop`, `seed_inventory`, `timed_research` |
| knowledge | `heart_catalog.gd`, `heart_progress.gd` | `guarded_garden_actions`, `guarded_gameplay_transactions`, `cultivation_growth`, `foundations`, `garden_altar`, `garden_cleanup`, `garden_cleanup_coop`, `garden_conduit`, `garden_conduit_coop`, `garden_growth`, `garden_growth_coop`, `garden_spring`, `garden_spring_coop`, `gardening`, `gate_garden_services`, `heart_growth_visual`, `heart_progression`, `network_research_coop`, `seed_coop`, `seed_progression`, `seed_template`, `species_depth`, `timed_research`, `developer_garden` |
| progression | `progression_panel.gd`, `progression_tree.gd` | `garden_cleanup`, `garden_cleanup_coop`, `heart_progression`, `seed_progression`, `tree_portraits` |
| expeditions | `party_travel.gd`, `run_upgrade_catalog.gd`, `campaign.gd` | `ec01_affinity_cards_party`, `ec01_affinity_cards`, `candidate_release_solo`, `candidate_release_party`, `guest_projection_coop`, `guarded_expedition`, `guarded_expedition_coop`, `guarded_garden_actions`, `boss_coop`, `boss_roster`, `checkpoint_extraction`, `class_depth`, `class_depth_coop`, `combat_balance`, `core_starters`, `crafting_availability_coop`, `diagnostics_coop`, `enemy_depth`, `expedition_pressure`, `expedition_pressure_coop`, `expedition_track`, `expedition_track_coop`, `foundations`, `four_players_coop`, `garden_cleanup`, `garden_cleanup_coop`, `garden_growth`, `garden_growth_coop`, `garden_returns`, `garden_returns_coop`, `gate_crafting_rules`, `grafting_menu`, `heart_progression`, `loot_revival`, `loot_revival_coop`, `party_hud_gates`, `party_hud_gates_coop`, `party_ready`, `party_ready_coop`, `run_flow`, `shrines_hits`, `species_depth`, `supplied_network_smoke`, `terrain_generation`, `terrain_generation_coop`, `warden_depth`, `warden_depth_coop`, `weighted_upgrades`, `regular_enemy_responses`, `warden_prototype`, `warden_prototype_coop`, `subclass_skills`, `thief_escape`, `thief_escape_coop`, `soundscape`, `event_audio` |
| loot | `monster_rewards.gd` | `guarded_expedition`, `guarded_expedition_coop`, `guarded_garden_actions`, `boss_coop`, `boss_phase_fights`, `boss_roster`, `checkpoint_extraction`, `combat_balance`, `enemy_depth`, `enemy_roster`, `enemy_support`, `expedition_pressure`, `gate_elites`, `inventory_grid`, `loot_revival`, `loot_revival_coop`, `monster_rewards`, `seed_template`, `support_deaths` |
| life | `expedition_life.gd`, `spectator_view.gd` | `ec01_affinity_cards`, `ct05_oracle`, `ct05_oracle_coop`, `ct05_oracle_party`, `ct01_warden`, `ct01_warden_coop`, `ct02_weaver`, `ct02_weaver_coop`, `ct02_weaver_party`, `ct03_ranger`, `ct03_ranger_coop`, `ct03_ranger_party`, `ct04_reaper`, `ct04_reaper_coop`, `ct04_reaper_party`, `cr05_native_grafts`, `cr04b_wood`, `cr04b_wood_coop`, `cr04b_mixed_party`, `guarded_expedition`, `guarded_expedition_coop`, `checkpoint_extraction`, `combat_balance`, `combat_readability`, `combat_readability_coop`, `core_combat`, `core_combat_coop`, `core_signatures_coop`, `core_starters`, `diagnostics_coop`, `expedition_pressure`, `expedition_pressure_coop`, `four_players_coop`, `health_points`, `loot_revival`, `loot_revival_coop`, `mouse_combat`, `mouse_combat_coop`, `network_movement_coop`, `network_presentation`, `network_warden_coop`, `party_hud_gates`, `party_hud_gates_coop`, `party_ready`, `party_ready_coop`, `player_hud`, `run_flow`, `status_feedback`, `status_feedback_coop`, `supplied_network_smoke`, `warden_depth`, `warden_depth_coop`, `expedition_sustain` |
| characters | `character_slots.gd`, `character_creator.gd`, `character_appearance.gd`, `traveller_avatar.gd` | `legacy_import_recovery`, `legacy_mutation_containment`, `candidate_release_solo`, `candidate_release_party`, `production_persistence`, `guest_projection_coop`, `serializer_integrity`, `guarded_lifecycle`, `guarded_lifecycle_coop`, `guarded_expedition`, `guarded_expedition_coop`, `guarded_garden_actions`, `guarded_garden_actions_coop`, `guarded_gameplay_transactions`, `guarded_title_session`, `persistence_destructive_slots`, `persistence_slot_roster`, `character_locomotion`, `character_overhaul`, `character_rig`, `character_roster`, `delete_saves`, `direct_ip_coop`, `four_players_coop`, `garden_crop_care`, `garden_crop_care_coop`, `garden_presentation`, `menu_controls`, `menu_coop`, `network_presentation`, `network_research_coop`, `network_settings`, `party_hud_gates`, `start_menu`, `supplied_network_smoke`, `weapon_actions`, `weapon_actions_coop`, `combat_balance_saves` |
| menus | `network_panel.gd` | `legacy_import_recovery`, `legacy_mutation_containment`, `candidate_release_solo`, `candidate_release_party`, `production_persistence`, `guarded_lifecycle`, `guarded_lifecycle_coop`, `guarded_title_session`, `persistence_destructive_slots`, `persistence_slot_roster`, `character_rig`, `character_roster`, `delete_saves`, `direct_ip_coop`, `four_players_coop`, `gate_garden_services`, `menu_controls`, `menu_coop`, `network_settings`, `start_menu`, `developer_garden`, `combat_balance_saves` |
| settings | `preference_file.gd`, `preference_file.gd.uid`, `app_settings.gd`, `settings_panel.gd` | `serializer_integrity`, `guarded_lifecycle`, `guarded_lifecycle_coop`, `core_combat`, `core_combat_coop`, `diagnostics`, `dual_skills`, `dual_skills_coop`, `exploration_ui`, `garden_growth`, `garden_growth_coop`, `menu_controls`, `mouse_combat`, `mouse_combat_coop`, `network_warden_coop`, `player_hud`, `start_menu`, `soundscape` |
| presentation | `root_ui.gd`, `stage.gd`, `network_presentation.gd`, `combat_effects.gd`, `enemy_death_effects.gd`, `boss_lair_visuals.gd`, `weapon_visuals.gd`, `game_metrics.gd`, `network_movement.gd`, `network_movement.gd.uid`, `combat_feedback.gd`, `combat_feedback.gd.uid`, `assets/characters/weapon_actions.json`, `status_feedback.gd`, `status_feedback.gd.uid` | `world_snapshot_codec`, `boss_lairs`, `boss_phase_fights`, `character_locomotion`, `character_overhaul`, `character_rig`, `combat_animation`, `combat_readability`, `combat_readability_coop`, `core_combat_coop`, `core_roster_coop`, `core_signatures`, `core_signatures_coop`, `dual_skills`, `enemy_roster`, `enemy_support`, `expedition_pressure`, `expedition_pressure_coop`, `expedition_track`, `expedition_track_coop`, `exploration_ui`, `garden_presentation`, `gate_elites`, `gate_elites_coop`, `health_points`, `inventory_party`, `loot_revival`, `natural_world`, `network_movement_coop`, `network_presentation`, `party_hud_gates`, `party_hud_gates_coop`, `player_hud`, `status_feedback`, `status_feedback_coop`, `supplied_network_smoke`, `support_deaths`, `support_rite_responses_coop`, `terrain_generation`, `terrain_generation_coop`, `thorn_adaptation_coop`, `tree_portraits`, `weapon_actions`, `weapon_actions_coop`, `wilds_skill_tactics_coop`, `regular_enemy_responses_coop`, `warden_prototype`, `warden_prototype_coop`, `subclass_skills`, `thief_escape_coop` |
| diagnostics | `diagnostic_journal.gd`, `diagnostic_watch.gd`, `diagnostics_boot.gd`, `playtest_storage.gd`, `diagnostics_panel.gd` | `serializer_integrity`, `guarded_lifecycle`, `guarded_lifecycle_coop`, `diagnostics`, `diagnostics_coop`, `four_players_coop`, `network_movement_coop` |
| party_ui | `party_hud.gd`, `party_hud.gd.uid` | `four_players_coop`, `loot_revival_coop`, `network_presentation`, `party_hud_gates`, `party_hud_gates_coop`, `player_hud` |
| gate_access | `gate_interaction.gd`, `gate_interaction.gd.uid` | `checkpoint_extraction`, `crafting_availability_coop`, `four_players_coop`, `gate_crafting_rules`, `gate_garden_services`, `party_hud_gates`, `party_hud_gates_coop`, `party_ready`, `party_ready_coop`, `run_flow`, `shrines_hits`, `weighted_upgrades` |
| garden_observations | `garden_interaction_catalog.gd`, `garden_interaction_catalog.gd.uid`, `garden_interaction_state.gd`, `garden_interaction_state.gd.uid`, `garden_interaction_service.gd`, `garden_interaction_service.gd.uid`, `garden_interaction_view.gd`, `garden_interaction_view.gd.uid` | `garden_cleanup`, `garden_conduit`, `garden_conduit_coop`, `garden_crop_care`, `garden_crop_care_coop`, `garden_growth`, `garden_growth_coop`, `garden_interactions`, `garden_interactions_coop`, `garden_presentation`, `garden_returns`, `garden_returns_coop`, `garden_spring`, `garden_spring_coop`, `gardening`, `gate_garden_services`, `menu_controls` |
| garden_costs | `garden_inventory_gateway.gd`, `garden_inventory_gateway.gd.uid` | `crafting_availability_coop`, `foundations`, `garden_altar`, `garden_interactions`, `garden_interactions_coop`, `inventory_party` |
| garden_zones | `garden_layout.gd`, `garden_layout.gd.uid`, `garden_spring_visuals.gd`, `garden_spring_visuals.gd.uid`, `assets/garden/sheltered_spring.tscn`, `assets/shaders/garden_spring_flow.gdshader`, `assets/shaders/garden_spring_flow.gdshader.uid` | `garden_conduit`, `garden_conduit_coop`, `garden_growth`, `garden_growth_coop`, `garden_interactions`, `garden_interactions_coop`, `garden_presentation`, `garden_spring`, `garden_spring_coop`, `gardening`, `gate_garden_services`, `heart_progression`, `menu_controls`, `soundscape` |
| garden_relationships | `garden_relationships.gd`, `garden_relationships.gd.uid` | `garden_interactions`, `garden_interactions_coop`, `garden_presentation`, `garden_spring`, `garden_spring_coop`, `gardening`, `gate_garden_services`, `heart_progression`, `menu_controls` |
| garden_life | `garden_ambience.gd`, `garden_ambience.gd.uid`, `garden_scenery.gd`, `garden_scenery.gd.uid` | `garden_growth`, `garden_interactions`, `garden_interactions_coop`, `garden_presentation`, `garden_returns`, `garden_returns_coop`, `garden_spring`, `garden_spring_coop`, `gardening`, `gate_garden_services`, `heart_growth_visual`, `heart_progression`, `menu_controls` |
| garden_cinematics | `garden_growth_catalog.gd`, `garden_growth_catalog.gd.uid`, `garden_growth_state.gd`, `garden_growth_state.gd.uid`, `garden_growth_service.gd`, `garden_growth_service.gd.uid`, `garden_growth_view.gd`, `garden_growth_view.gd.uid` | `guarded_lifecycle`, `guarded_lifecycle_coop`, `guarded_gameplay_transactions`, `delete_saves`, `garden_growth`, `garden_growth_coop`, `garden_interactions`, `garden_interactions_coop`, `garden_presentation`, `garden_returns`, `garden_returns_coop`, `garden_spring`, `garden_spring_coop`, `gate_garden_services`, `heart_growth_visual`, `heart_progression`, `menu_controls`, `menu_coop`, `network_research_coop`, `party_ready`, `party_ready_coop`, `run_flow`, `start_menu`, `timed_research`, `developer_garden`, `event_audio` |
| garden_care | `garden_crop_catalog.gd`, `garden_crop_catalog.gd.uid`, `garden_crop_state.gd`, `garden_crop_state.gd.uid`, `garden_crop_service.gd`, `garden_crop_service.gd.uid`, `garden_crop_view.gd`, `garden_crop_view.gd.uid` | `experimental_terrain`, `guarded_garden_actions`, `guarded_garden_actions_coop`, `guarded_gameplay_transactions`, `cultivation_growth`, `foundations`, `garden_conduit`, `garden_conduit_coop`, `garden_crop_care`, `garden_crop_care_coop`, `garden_growth`, `garden_growth_coop`, `garden_interactions`, `garden_interactions_coop`, `garden_spring`, `garden_spring_coop`, `gardening`, `network_research_coop`, `seed_inventory`, `seed_progression`, `species_depth` |
| cultivation_growth | `cultivation_growth.gd`, `cultivation_growth.gd.uid` | `checkpoint_extraction`, `cultivation_growth`, `direct_ip_coop`, `foundations`, `garden_conduit`, `garden_conduit_coop`, `garden_crop_care`, `garden_crop_care_coop`, `garden_growth`, `garden_growth_coop`, `garden_interactions`, `garden_interactions_coop`, `garden_spring`, `garden_spring_coop`, `gardening`, `network_research_coop`, `network_settings`, `network_warden_coop`, `run_flow`, `seed_inventory`, `seed_progression`, `seed_template`, `species_depth`, `supplied_network_smoke` |
| avatar_motion_view | `avatar_motion_view.gd`, `avatar_motion_view.gd.uid`, `field_traveller.gd`, `field_traveller.gd.uid`, `plant_polearms.gd`, `plant_polearms.gd.uid`, `traveller_locomotion.gd`, `traveller_locomotion.gd.uid`, `plant_weapon_models.gd`, `plant_weapon_models.gd.uid` | `character_locomotion`, `character_overhaul`, `character_rig`, `combat_animation`, `combat_readability`, `combat_readability_coop`, `four_players_coop`, `garden_presentation`, `network_movement_coop`, `network_presentation`, `network_research_coop`, `supplied_network_smoke`, `weapon_actions`, `weapon_actions_coop` |
| garden_returns | `garden_return_catalog.gd`, `garden_return_catalog.gd.uid`, `garden_return_state.gd`, `garden_return_state.gd.uid`, `garden_return_service.gd`, `garden_return_service.gd.uid`, `garden_return_view.gd`, `garden_return_view.gd.uid`, `garden_story_panel.gd`, `garden_story_panel.gd.uid` | `guarded_expedition`, `guarded_expedition_coop`, `guarded_garden_actions`, `guarded_garden_actions_coop`, `checkpoint_extraction`, `direct_ip_coop`, `garden_altar`, `garden_cleanup`, `garden_cleanup_coop`, `garden_growth`, `garden_growth_coop`, `garden_interactions`, `garden_interactions_coop`, `garden_returns`, `garden_returns_coop`, `garden_spring`, `garden_spring_coop`, `heart_growth_visual`, `inventory_grid`, `inventory_party`, `loot_revival`, `network_warden_coop`, `party_ready`, `party_ready_coop`, `run_flow` |
| garden_conduit | `garden_conduit.gd`, `garden_conduit.gd.uid`, `garden_terrace_view.gd`, `garden_terrace_view.gd.uid` | `garden_conduit`, `garden_conduit_coop`, `garden_crop_care`, `garden_crop_care_coop`, `garden_growth`, `garden_growth_coop`, `garden_presentation`, `garden_spring`, `heart_progression`, `timed_research` |
| expedition_pressure | `expedition_pressure.gd`, `expedition_pressure.gd.uid` | `expedition_pressure`, `expedition_pressure_coop`, `enemy_balance_preview` |
| expedition_ui | `expedition_track.gd`, `expedition_track.gd.uid` | `expedition_track`, `expedition_track_coop` |
| heart_growth_visual | `heart_growth_visuals.gd`, `heart_growth_visuals.gd.uid`, `assets/shaders/heart_foliage.gdshader`, `assets/shaders/heart_foliage.gdshader.uid` | `garden_cleanup`, `garden_cleanup_coop`, `garden_growth`, `garden_growth_coop`, `garden_presentation`, `garden_returns`, `garden_returns_coop`, `heart_growth_visual`, `heart_progression` |
| garden_stations | `garden_care_panel.gd` | `guarded_garden_actions`, `cultivation_growth`, `direct_ip_coop`, `four_players_coop`, `garden_cleanup`, `garden_cleanup_coop`, `garden_crop_care_coop`, `garden_spring`, `garden_spring_coop`, `gate_garden_services`, `heart_progression`, `network_settings` |
| menu_layout | `main_menu.gd`, `settings_panel.gd`, `menu_button_roots.gd`, `menu_button_roots.gd.uid` | `guarded_title_session`, `character_rig`, `character_roster`, `delete_saves`, `direct_ip_coop`, `four_players_coop`, `gate_garden_services`, `menu_controls`, `menu_coop`, `network_settings`, `start_menu`, `developer_garden` |
| ui_copy |  | `class_depth`, `classes_weapons`, `cultivation_growth`, `direct_ip_coop`, `four_players_coop`, `garden_altar`, `garden_conduit`, `garden_conduit_coop`, `garden_crop_care`, `garden_crop_care_coop`, `gate_garden_services`, `grafting_menu`, `heart_progression`, `inventory_grid`, `inventory_party`, `menu_controls`, `seed_progression`, `species_depth`, `start_menu`, `status_feedback`, `tree_portraits`, `ui_copy`, `weighted_upgrades` |
| enemy_attack_plan | `enemy_attack.gd`, `enemy_attack.gd.uid`, `enemy_variants.gd`, `enemy_variants.gd.uid`, `enemy_support.gd`, `enemy_support.gd.uid` | `boss_coop`, `boss_roster`, `combat_animation`, `combat_balance`, `combat_readability`, `combat_readability_coop`, `enemy_depth`, `enemy_roster`, `enemy_support`, `enemy_variants`, `expedition_pressure`, `expedition_pressure_coop`, `gate_elites`, `gate_elites_coop`, `monster_behaviors`, `monster_rewards`, `projectile_terrain`, `network_presentation`, `status_feedback`, `status_feedback_coop`, `support_deaths`, `support_rite_responses`, `support_rite_responses_coop`, `thorn_adaptation`, `thorn_adaptation_coop`, `wilds_skill_tactics`, `wilds_skill_tactics_coop`, `regular_enemy_responses`, `regular_enemy_responses_coop` |
| encounter_composition | `wilds_composition.gd`, `wilds_composition.gd.uid` | `boss_coop`, `boss_roster`, `combat_balance`, `enemy_roster`, `expedition_pressure`, `expedition_pressure_coop`, `four_players_coop`, `gate_elites`, `gate_elites_coop`, `supplied_network_smoke`, `support_deaths`, `terrain_generation`, `terrain_generation_coop` |
| boss_lair_fights | `boss_lair_fights.gd`, `boss_lair_fights.gd.uid`, `boss_lair_routes.gd`, `boss_lair_routes.gd.uid`, `orchard_moves.gd`, `orchard_moves.gd.uid` | `boss_coop`, `boss_lairs`, `boss_phase_fights`, `boss_roster`, `enemy_balance_preview` |
| boss_phase_fights | `boss_phase_fights.gd`, `boss_phase_fights.gd.uid`, `boss_phase_visuals.gd`, `boss_phase_visuals.gd.uid`, `boss_nest_layout.gd`, `boss_nest_layout.gd.uid` | `boss_coop`, `boss_lairs`, `boss_phase_fights`, `boss_roster`, `terrain_generation`, `terrain_generation_coop`, `enemy_balance_preview` |
| core_combat | `core_skill_rules.gd`, `core_combat.gd`, `core_thorn_visual.gd`, `core_skill_rules.gd.uid`, `core_combat.gd.uid`, `core_thorn_visual.gd.uid`, `core_lance.gd`, `core_lance.gd.uid`, `core_skill_catalog.gd`, `core_strike_mark.gd`, `core_anchor_beam.gd`, `assets/ui/core_skills/thorn_line.png`, `assets/ui/core_skills/seed_lance.png`, `assets/ui/core_skills/lantern_burst.png`, `assets/ui/core_skills/whisper_mark.png`, `assets/ui/core_skills/constellation.png`, `core_skill_catalog.gd.uid`, `core_strike_mark.gd.uid`, `core_anchor_beam.gd.uid`, `assets/ui/core_skills/constellation.png.import`, `assets/ui/core_skills/lantern_burst.png.import`, `assets/ui/core_skills/seed_lance.png.import`, `assets/ui/core_skills/thorn_line.png.import`, `assets/ui/core_skills/whisper_mark.png.import`, `core_skill_roster.gd`, `core_skill_roster.gd.uid`, `core_skill_effects.gd`, `core_skill_effects.gd.uid`, `core_weapon_variants.gd`, `core_weapon_variants.gd.uid`, `core_footprint.gd`, `core_footprint.gd.uid`, `core_skill_visuals.gd`, `core_skill_visuals.gd.uid` | `cr04c_void`, `cr04c_void_coop`, `cr04c_mixed_party`, `cr04c_spirit`, `cr04c_spirit_coop`, `cr04c_storm`, `cr04c_storm_coop`, `cr04b_wood`, `cr04b_wood_coop`, `cr04b_mixed_party`, `cr04b_thorn`, `cr04b_thorn_coop`, `cr04a_vital`, `cr04a_water`, `cr04a_fire`, `cr03_frost`, `ability_aim`, `classes_weapons`, `combat_readability`, `combat_readability_coop`, `core_combat`, `core_combat_coop`, `core_modifiers`, `core_roster`, `core_roster_coop`, `core_signatures`, `core_signatures_coop`, `core_starters`, `core_weapon_variants`, `crafting_availability_coop`, `diagnostics_coop`, `dual_skills`, `dual_skills_coop`, `four_players_coop`, `gate_crafting_rules`, `grafting_menu`, `inventory_grid`, `inventory_party`, `loot_revival`, `loot_revival_coop`, `menu_controls`, `mouse_combat`, `projectile_terrain`, `mouse_combat_coop`, `network_settings`, `network_warden_coop`, `party_ready`, `party_ready_coop`, `player_hud`, `run_flow`, `species_depth`, `status_feedback`, `status_feedback_coop`, `thorn_adaptation`, `thorn_adaptation_coop`, `weapon_actions`, `weapon_actions_coop`, `weighted_upgrades`, `wilds_skill_tactics`, `wilds_skill_tactics_coop`, `warden_prototype`, `warden_prototype_coop`, `core_balance_preview` |
| ability_aim | `ability_aim.gd`, `ability_aim.gd.uid`, `class_ability_targeting.gd`, `class_ability_targeting.gd.uid` | `ct05_oracle`, `ct05_oracle_coop`, `ct05_oracle_party`, `ct03_ranger`, `ct04_reaper`, `ability_aim`, `classes_weapons`, `combat_readability`, `combat_readability_coop`, `core_combat`, `core_combat_coop`, `core_modifiers`, `core_signatures`, `core_signatures_coop`, `core_weapon_variants`, `dual_skills`, `dual_skills_coop`, `menu_controls`, `mouse_combat`, `projectile_terrain`, `mouse_combat_coop`, `network_warden_coop`, `player_hud`, `warden_prototype`, `warden_prototype_coop`, `subclass_skills` |
| thorn_adaptation | `thorn_adaptation.gd`, `thorn_adaptation.gd.uid` | `ability_aim`, `combat_balance`, `combat_readability`, `combat_readability_coop`, `core_combat`, `core_combat_coop`, `core_starters`, `diagnostics_coop`, `enemy_variants`, `gate_elites`, `gate_elites_coop`, `terrain_generation`, `terrain_generation_coop`, `thorn_adaptation`, `thorn_adaptation_coop` |
| wilds_skill_tactics | `wilds_skill_tactics.gd`, `wilds_skill_tactics.gd.uid`, `enemy_skill_responses.gd`, `enemy_skill_responses.gd.uid` | `ability_aim`, `boss_coop`, `boss_phase_fights`, `combat_balance`, `combat_readability`, `combat_readability_coop`, `core_combat`, `core_roster`, `core_roster_coop`, `core_weapon_variants`, `diagnostics_coop`, `enemy_depth`, `enemy_support`, `enemy_variants`, `gate_elites`, `gate_elites_coop`, `status_feedback`, `status_feedback_coop`, `support_rite_responses`, `support_rite_responses_coop`, `terrain_generation`, `terrain_generation_coop`, `weighted_upgrades`, `wilds_skill_tactics`, `wilds_skill_tactics_coop`, `regular_enemy_responses`, `regular_enemy_responses_coop` |
| enemy_move_feedback | `enemy_move_feedback.gd`, `enemy_move_feedback.gd.uid` | `boss_phase_fights`, `combat_readability`, `combat_readability_coop`, `enemy_support`, `status_feedback`, `status_feedback_coop`, `support_rite_responses`, `support_rite_responses_coop`, `thorn_adaptation`, `thorn_adaptation_coop`, `wilds_skill_tactics`, `regular_enemy_responses`, `regular_enemy_responses_coop` |
| warden_progression | `connected_class_tree.gd`, `connected_class_tree.gd.uid`, `warden_connected_tree.gd`, `warden_connected_tree.gd.uid`, `warden_tree.gd`, `warden_tree.gd.uid`, `warden_combat.gd`, `warden_combat.gd.uid`, `subclass_catalog.gd`, `subclass_catalog.gd.uid`, `subclass_combat.gd`, `subclass_combat.gd.uid`, `subclass_visuals.gd`, `subclass_visuals.gd.uid` | `ct01_warden`, `ct01_warden_coop`, `ct02_weaver`, `ct02_weaver_coop`, `ct02_weaver_party`, `ct03_ranger`, `ct03_ranger_coop`, `ct03_ranger_party`, `ct04_reaper`, `ct04_reaper_coop`, `ct04_reaper_party`, `ability_aim`, `character_roster`, `class_depth`, `class_depth_coop`, `classes_coop`, `classes_weapons`, `core_modifiers`, `foundations`, `four_players_coop`, `menu_coop`, `network_warden_coop`, `player_hud`, `seed_template`, `status_feedback`, `status_feedback_coop`, `warden_depth`, `warden_depth_coop`, `weighted_upgrades`, `warden_prototype`, `warden_prototype_coop`, `subclass_skills`, `class_balance_preview` |
| weaver_progression | `weaver_connected_tree.gd`, `weaver_connected_tree.gd.uid`, `weaver_combat.gd`, `weaver_combat.gd.uid` | `ct02_weaver`, `ct02_weaver_coop`, `ct02_weaver_party`, `ct03_ranger_party`, `ct04_reaper_party` |
| ranger_progression | `ranger_connected_tree.gd`, `ranger_connected_tree.gd.uid`, `ranger_combat.gd`, `ranger_combat.gd.uid` | `ct03_ranger`, `ct03_ranger_coop`, `ct03_ranger_party`, `ct04_reaper` |
| reaper_progression | `reaper_connected_tree.gd`, `reaper_connected_tree.gd.uid`, `reaper_combat.gd`, `reaper_combat.gd.uid` | `ct04_reaper`, `ct04_reaper_coop`, `ct04_reaper_party` |
| connection_flow |  | `ec01_affinity_cards_party`, `ct05_oracle_coop`, `ct05_oracle_party`, `ct01_warden_coop`, `ct02_weaver_coop`, `ct02_weaver_party`, `ct03_ranger_coop`, `ct03_ranger_party`, `ct04_reaper_coop`, `ct04_reaper_party`, `cr05_native_grafts_coop`, `cr05_native_grafts_party`, `cr04c_void_coop`, `cr04c_mixed_party`, `cr04c_spirit_coop`, `cr04c_storm_coop`, `world_snapshot_codec`, `cr04b_wood_coop`, `cr04b_mixed_party`, `cr04b_thorn_coop`, `cr04a_vital_coop`, `cr04a_mixed_party`, `cr04a_water_coop`, `cr04a_fire_coop`, `cr03_frost_coop`, `cr03_frost_party`, `cr02_mode_coop`, `cr02_mode_mismatch`, `cr02_definitions_mismatch`, `experimental_terrain_coop`, `candidate_release_party`, `production_persistence`, `guest_projection_coop`, `guarded_lifecycle`, `guarded_lifecycle_coop`, `guarded_expedition`, `guarded_expedition_coop`, `guarded_garden_actions_coop`, `guarded_gameplay_transactions`, `guarded_title_session`, `direct_ip_coop`, `four_players_coop`, `menu_coop`, `network_movement_coop`, `network_settings`, `start_menu`, `supplied_network_smoke` |
| developer_garden | `developer_mode.gd`, `developer_mode.gd.uid`, `developer_settings.gd`, `developer_settings.gd.uid` | `legacy_import_recovery`, `production_persistence`, `guarded_title_session`, `direct_ip_coop`, `garden_growth`, `heart_growth_visual`, `heart_progression`, `menu_controls`, `menu_coop`, `start_menu`, `timed_research`, `developer_garden` |
| thief_escape | `thief_escape.gd`, `thief_escape.gd.uid`, `thief_escape_view.gd`, `thief_escape_view.gd.uid` | `enemy_depth`, `enemy_support`, `exploration_ui`, `gate_elites`, `gate_elites_coop`, `monster_rewards`, `party_hud_gates`, `regular_enemy_responses`, `regular_enemy_responses_coop`, `thief_escape`, `thief_escape_coop`, `event_audio` |
| soundscape | `soundscape.gd`, `soundscape.gd.uid`, `title_music.gd`, `title_music.gd.uid` | `four_players_coop`, `garden_growth`, `menu_controls`, `start_menu`, `soundscape`, `event_audio` |
| event_audio | `event_audio.gd`, `event_audio.gd.uid`, `combat_audio.gd`, `combat_audio.gd.uid` | `guarded_expedition`, `guarded_expedition_coop`, `guarded_garden_actions`, `guarded_garden_actions_coop`, `boss_lairs`, `boss_phase_fights`, `combat_readability_coop`, `core_combat`, `cultivation_growth`, `direct_ip_coop`, `enemy_support`, `garden_crop_care`, `garden_crop_care_coop`, `garden_growth`, `menu_controls`, `party_hud_gates`, `party_hud_gates_coop`, `supplied_network_smoke`, `thief_escape`, `thief_escape_coop`, `event_audio` |
| ranged_release |  | `combat_animation`, `combat_readability`, `combat_readability_coop`, `core_weapon_variants`, `mouse_combat`, `mouse_combat_coop`, `network_presentation`, `supplied_network_smoke`, `weapon_actions`, `weapon_actions_coop` |
| class_tree_access | `class_tree_access.gd`, `class_tree_access.gd.uid` | `ct05_oracle`, `ct05_oracle_coop`, `ct05_oracle_party`, `ct01_warden`, `ct01_warden_coop`, `ct02_weaver`, `ct02_weaver_coop`, `ct02_weaver_party`, `ct03_ranger`, `ct03_ranger_coop`, `ct03_ranger_party`, `ct04_reaper`, `ct04_reaper_coop`, `ct04_reaper_party`, `guarded_garden_actions`, `class_depth`, `class_depth_coop`, `classes_weapons`, `garden_cleanup`, `gate_crafting_rules`, `gate_garden_services`, `warden_prototype`, `warden_prototype_coop` |
| class_skill_icons | `class_skill_icons.gd`, `class_skill_icons.gd.uid`, `assets/ui/class_skills.png`, `assets/ui/class_skills.png.import`, `assets/ui/class_skill_icons.json` | `player_hud` |
| expedition_summary | `run_summary_panel.gd`, `run_summary_panel.gd.uid` | `menu_controls`, `menu_coop`, `player_hud`, `core_balance_preview`, `expedition_sustain` |
| glasscap_feints | `glasscap_feint.gd`, `glasscap_feint.gd.uid`, `glasscap_visuals.gd`, `glasscap_visuals.gd.uid` | `enemy_variants`, `gate_elites`, `regular_enemy_responses_coop` |
| combat_vitals | `combat_vitals.gd`, `combat_vitals.gd.uid` | `boss_coop`, `boss_lairs`, `boss_phase_fights`, `checkpoint_extraction`, `class_depth`, `combat_balance`, `combat_readability_coop`, `core_roster`, `core_roster_coop`, `core_signatures_coop`, `diagnostics_coop`, `dual_skills_coop`, `four_players_coop`, `health_points`, `loot_revival`, `loot_revival_coop`, `network_presentation`, `party_hud_gates_coop`, `supplied_network_smoke`, `support_rite_responses`, `weighted_upgrades`, `wilds_skill_tactics`, `subclass_skills`, `combat_vitals_baseline`, `combat_balance_saves`, `expedition_sustain` |
| combat_balance_preview | `combat_balance_preview.gd`, `combat_balance_preview.gd.uid`, `health_orb.gd`, `health_orb.gd.uid` | `boss_coop`, `boss_lairs`, `combat_readability_coop`, `core_roster_coop`, `diagnostics_coop`, `direct_ip_coop`, `four_players_coop`, `health_points`, `loot_revival_coop`, `network_settings`, `party_hud_gates_coop`, `player_hud`, `start_menu`, `supplied_network_smoke`, `weapon_actions_coop`, `combat_vitals_baseline`, `combat_balance_saves`, `combat_balance_preview`, `combat_balance_preview_coop`, `class_balance_preview`, `core_balance_preview`, `enemy_balance_preview` |
| weapon_balance |  | `class_depth_coop`, `classes_weapons`, `core_roster`, `core_roster_coop`, `crafting_availability_coop`, `grafting_menu`, `inventory_grid`, `inventory_party`, `mouse_combat_coop`, `seed_template`, `status_feedback`, `status_feedback_coop`, `weapon_actions`, `weapon_actions_coop`, `weighted_upgrades`, `combat_balance_preview`, `combat_balance_preview_coop`, `weapon_balance_preview`, `class_balance_preview`, `core_balance_preview` |
| class_balance | `class_skill_balance.gd`, `class_skill_balance.gd.uid` | `class_depth`, `class_depth_coop`, `classes_coop`, `classes_weapons`, `combat_readability`, `combat_readability_coop`, `dual_skills`, `dual_skills_coop`, `network_warden_coop`, `player_hud`, `status_feedback`, `status_feedback_coop`, `warden_depth`, `warden_depth_coop`, `warden_prototype`, `subclass_skills`, `combat_balance_preview`, `combat_balance_preview_coop`, `weapon_balance_preview`, `class_balance_preview`, `expedition_sustain` |
| core_balance | `core_skill_balance.gd`, `core_skill_balance.gd.uid` | `core_combat`, `core_combat_coop`, `core_modifiers`, `core_roster`, `core_roster_coop`, `core_signatures`, `core_signatures_coop`, `core_starters`, `core_weapon_variants`, `menu_controls`, `menu_coop`, `player_hud`, `status_feedback`, `status_feedback_coop`, `thorn_adaptation`, `thorn_adaptation_coop`, `weighted_upgrades`, `combat_balance_preview`, `combat_balance_preview_coop`, `weapon_balance_preview`, `core_balance_preview`, `expedition_sustain` |
| healing_rolls |  | `checkpoint_extraction`, `core_combat`, `core_combat_coop`, `core_roster`, `core_roster_coop`, `core_signatures`, `core_signatures_coop`, `diagnostics_coop`, `dual_skills`, `dual_skills_coop`, `enemy_support`, `loot_revival`, `loot_revival_coop`, `menu_controls`, `menu_coop`, `party_hud_gates`, `party_hud_gates_coop`, `party_ready_coop`, `player_hud`, `run_flow`, `support_rite_responses`, `support_rite_responses_coop`, `weighted_upgrades`, `subclass_skills`, `combat_balance_preview`, `combat_balance_preview_coop`, `weapon_balance_preview`, `class_balance_preview`, `core_balance_preview`, `expedition_sustain` |
| enemy_balance | `enemy_balance.gd`, `enemy_balance.gd.uid`, `assets/enemies/preview_scaling.json` | `boss_coop`, `boss_lairs`, `boss_phase_fights`, `boss_roster`, `combat_balance`, `combat_readability`, `combat_readability_coop`, `enemy_depth`, `enemy_roster`, `enemy_support`, `enemy_variants`, `expedition_pressure`, `expedition_pressure_coop`, `four_players_coop`, `gate_elites`, `gate_elites_coop`, `support_rite_responses`, `support_rite_responses_coop`, `thorn_adaptation`, `thorn_adaptation_coop`, `regular_enemy_responses`, `regular_enemy_responses_coop`, `combat_balance_preview`, `combat_balance_preview_coop`, `weapon_balance_preview`, `class_balance_preview`, `core_balance_preview`, `enemy_balance_preview`, `expedition_sustain` |
| expedition_sustain | `expedition_sustain.gd`, `expedition_sustain.gd.uid` | `guarded_expedition`, `guarded_expedition_coop`, `checkpoint_extraction`, `class_depth`, `class_depth_coop`, `combat_readability`, `combat_readability_coop`, `core_combat`, `core_combat_coop`, `core_roster`, `core_roster_coop`, `core_signatures`, `core_signatures_coop`, `diagnostics_coop`, `dual_skills`, `dual_skills_coop`, `four_players_coop`, `loot_revival`, `loot_revival_coop`, `menu_controls`, `menu_coop`, `network_movement_coop`, `network_presentation`, `party_hud_gates`, `party_hud_gates_coop`, `party_ready_coop`, `player_hud`, `weighted_upgrades`, `subclass_skills`, `combat_balance_preview`, `combat_balance_preview_coop`, `weapon_balance_preview`, `class_balance_preview`, `core_balance_preview`, `expedition_sustain` |
| spectator_layout |  | `loot_revival`, `loot_revival_coop`, `party_hud_gates`, `party_hud_gates_coop`, `combat_balance_preview_coop`, `expedition_sustain` |

## Existing game dispatcher functions

`game.gd` is currently shared by most mechanics. Body-only edits use the function ownership below. Shared declarations broaden affected coverage; Full runs require an explicit major-release request. Unmapped inputs must be classified before validation. This is a conservative bridge until the dispatcher is separated into smaller services.

| Function | Systems |
|---|---|
| `_act` | foundation |
| `_apply_loadout_action` | classes, characters, weapons, items |
| `_attempt_graft` | weapons |
| `_bank_checkpoint_item` | items, garden_returns |
| `_buy_upgrade` | expeditions |
| `_cycle_slot` | weapons, items |
| `_damage_player` | life |
| `_donate_part` | items, garden |
| `_drop_inventory_stack` | loot, items |
| `_enter_wilds` | expeditions |
| `_exit_tree` | foundation |
| `_experimental_spawn_reachable` | hex_terrain, terrain |
| `_finish_combat` | loot, enemies, expeditions, classes |
| `_finish_failed_expedition` | life |
| `_finish_title_return` | menus, connection_flow, persistence_operations |
| `_garden_action` | foundation, affinity_cards |
| `_harvest` | seeds, garden, knowledge, items |
| `_init` | foundation |
| `_input` | foundation |
| `_notification` | foundation |
| `_offer_monster` | garden_stations, items, knowledge |
| `_physics_process` | foundation |
| `_pickup_inventory_drop` | loot, items |
| `_process` | foundation, affinity_cards |
| `_ready` | foundation |
| `_reclaim_seed` | garden_stations, seeds, items |
| `_recover_pouch` | life |
| `_refuse_unowned_world` | persistence_operations, persistence_authorization, persistence_recovery_plan, persistence_save_access, menus, characters, developer_garden, connection_flow |
| `_report_guest_projection` | persistence_operations, connection_flow, characters, expeditions, garden |
| `_select_class` | classes, characters, weapons |
| `_stop_guarded_session` | menus, persistence_operations |
| `_unhandled_input` | foundation |
| `_unhandled_key_input` | foundation, affinity_cards |
| `_use_checkpoint` | expeditions |
| `abandon_if_empty` | expeditions |
| `abandon_run` | expeditions |
| `act` | foundation |
| `action_feedback` | persistence_operations |
| `activate_checkpoint` | expeditions, gate_access |
| `actor_profile_scope` | persistence_operations, characters |
| `add_button` | presentation |
| `add_label` | presentation |
| `add_player` | foundation |
| `admission_error` | foundation |
| `affinity_checkpoint_action` | expeditions, affinity_cards |
| `allow_remote` | foundation |
| `apply_enemy_hit` | life |
| `apply_hit_grace` | combat, life |
| `apply_skill_targets` | classes, affinity_cards |
| `apply_weapon_hit` | combat, weapons, classes, loot, enemies, enemy_attack_plan |
| `apply_world_snapshot` | world_snapshot, presentation, life |
| `arrange_support_groups` | enemies |
| `at_garden_altar` | seeds |
| `at_garden_station` | knowledge, garden_stations |
| `at_graft_altar` | seeds |
| `at_heart` | knowledge |
| `at_weapon_gate` | foundation |
| `attack_animation_snapshot` | presentation |
| `attack_hints_snapshot` | presentation, enemy_attack_plan |
| `attempt_graft` | weapons |
| `attract_loot` | loot |
| `available_parts` | weapons |
| `awaken_heart` | knowledge |
| `award_combat_progress` | loot |
| `bank_checkpoint_item` | items |
| `base_strike_radius` | enemies |
| `bound_position` | terrain |
| `build_garden_altar_panel` | seeds |
| `build_grafting_panel` | weapons |
| `build_heart_panels` | knowledge |
| `build_hud` | presentation, menus, settings, life, classes |
| `build_loadout_panel` | weapons |
| `build_planting_panel` | seeds |
| `build_progression_panel` | progression, knowledge, classes, seeds |
| `build_run_flow_panels` | expeditions, affinity_cards |
| `buy_upgrade` | expeditions, affinity_cards |
| `campaign_snapshot` | foundation |
| `can_checkpoint_bank` | items |
| `can_see_item_drop` | loot |
| `can_vault` | terrain |
| `checkpoint_all_ready` | expeditions |
| `checkpoint_card_data` | expeditions, affinity_cards |
| `checkpoint_offer_ids` | expeditions |
| `choose_checkpoint_card` | expeditions, persistence_operations, ui_copy, gate_access, affinity_cards |
| `clear_spawn` | terrain |
| `close_flow_for` | expeditions, connection_flow |
| `close_planting_picker` | seeds |
| `close_run_flow_panel` | expeditions |
| `closest_enemy` | enemies |
| `collect_drop` | loot |
| `combat_events_snapshot` | presentation |
| `combat_pose` | presentation |
| `complete_finale` | expeditions |
| `configure_keys` | settings |
| `connection_accepted` | foundation |
| `connection_rejected` | foundation |
| `consider_recollection` | knowledge |
| `current_mutations` | enemies |
| `cycle_destination` | expeditions |
| `cycle_reclamation` | seeds |
| `cycle_slot` | weapons |
| `damage_player` | life |
| `death_events_snapshot` | presentation |
| `deferred_save_available` | persistence_operations |
| `dodge_player` | combat, affinity_cards |
| `donate_part` | seeds |
| `drop_inventory_stack` | loot |
| `emit_combat_event` | presentation |
| `emit_weapon_attack` | presentation |
| `encounter_cleared` | expeditions |
| `encounter_health` | expeditions |
| `ending_message` | expeditions |
| `enemy_contact_point` | combat |
| `enemy_name` | enemies |
| `enemy_position` | enemies |
| `enter_wilds` | expeditions |
| `expedition_active` | expeditions |
| `extraction_checkpoint_open` | expeditions |
| `finish_combat` | loot, enemies, expeditions, classes |
| `finish_failed_expedition` | life |
| `formation_position` | enemies, encounter_composition |
| `garden_action` | foundation |
| `garden_snapshot` | foundation |
| `go_offline` | connection_flow, persistence_operations |
| `graft_altar_open` | seeds |
| `graft_block_reason` | weapons |
| `graft_chance` | weapons |
| `graft_feedback` | weapons |
| `graft_menu_data` | weapons |
| `grant_guard` | classes |
| `guarded_growth_tick` | persistence_operations |
| `guest_combat_events` | presentation |
| `guest_projection_status` | persistence_operations, connection_flow, characters, expeditions, garden |
| `handle_altar_action` | seeds |
| `handle_inventory_action` | items, weapons, seeds, loot |
| `handle_loadout_action` | weapons, classes, items |
| `harvest` | seeds, garden, knowledge, items |
| `harvest_guarded` | garden_care, characters, seeds |
| `has_rift_loadout` | weapons |
| `heart_state` | knowledge |
| `hit_players` | combat |
| `hit_players_charge` | combat |
| `host_game` | foundation |
| `hud_panel` | presentation |
| `identify_seed` | seeds |
| `infuse_study` | knowledge |
| `inventory_drop_list` | loot |
| `inventory_floor_snapshot` | items |
| `inventory_snapshot` | items |
| `inventory_ui_data` | items |
| `join_game` | foundation |
| `leave_game` | foundation |
| `living_scout_count` | enemies |
| `local_player_id` | menus |
| `make_scout` | enemies, enemy_attack_plan |
| `mark_checkpoint_ready` | expeditions, affinity_cards |
| `milestone_message` | expeditions |
| `monster_cargo_limit` | knowledge |
| `monster_loot_tags` | loot |
| `move_player` | terrain |
| `nearby_plot` | foundation |
| `nearest_inventory_drop` | loot |
| `nearest_visible_inventory_drop` | loot |
| `nearest_wild_player` | foundation |
| `next_monster_part` | foundation |
| `next_part` | seeds |
| `offer_monster` | seeds, garden_stations |
| `on_connection_failed` | foundation |
| `on_joined_world` | foundation |
| `on_server_disconnected` | foundation |
| `open_checkpoint_cards` | expeditions, combat_affinity_contracts, ui_copy, affinity_cards |
| `open_deposit_menu` | items |
| `open_garden_altar` | seeds |
| `open_gate_preparation` | expeditions |
| `open_graft_menu` | weapons |
| `open_heart_tree` | knowledge |
| `open_planting_picker` | seeds |
| `party_travel_state` | expeditions |
| `persist_loadout` | weapons |
| `pickup_inventory_drop` | loot |
| `plant_seed` | seeds |
| `player_snapshot` | foundation, affinity_cards |
| `prepare_guarded_exit` | persistence_operations, menus, expeditions |
| `present_checkpoint_cards` | expeditions |
| `publish_character` | foundation |
| `publish_combat_event` | combat, connection_flow |
| `rare_harvest_chance` | seeds |
| `receive_character` | foundation |
| `receive_combat_event` | foundation |
| `receive_details` | foundation |
| `receive_message` | foundation |
| `receive_state` | foundation |
| `receive_vitals` | foundation |
| `reclaim_seed` | seeds, garden_stations |
| `reclamation_cost` | seeds |
| `reclamation_species` | seeds |
| `record_character` | persistence_operations |
| `record_enemy_death` | enemies |
| `record_settlement_metric` | diagnostics, expeditions |
| `recover_pouch` | life |
| `refresh_drop` | loot |
| `refresh_feedback` | persistence_operations, presentation |
| `register_character` | foundation |
| `reject_peer` | foundation |
| `release_slot` | foundation |
| `remove_player` | foundation |
| `report_harvest` | garden_care, diagnostics |
| `request_abandon_run` | expeditions |
| `request_action` | foundation |
| `request_dodge` | foundation |
| `request_garden_action` | foundation |
| `request_ip_join` | menus |
| `request_main_menu` | menus |
| `reset_encounter` | expeditions, encounter_composition |
| `reset_expedition` | expeditions, affinity_cards |
| `resolve_briar_strike` | enemies |
| `resolve_scout` | enemies, enemy_attack_plan |
| `restore_class_loadout` | weapons |
| `restore_expedition_runtime` | expeditions, persistence_operations |
| `resume_checkpoint_if_ready` | expeditions |
| `return_to_garden` | life, affinity_cards |
| `return_to_main_menu` | foundation |
| `revive_player` | life, persistence_operations |
| `roll_kill_trophy` | loot |
| `roll_monster_item` | loot |
| `route_rooms` | expeditions |
| `run_altar_save` | persistence_operations |
| `run_guarded_action` | persistence_operations |
| `run_heart_save` | persistence_operations |
| `run_seed_experiment` | seeds, items, knowledge |
| `run_wallet` | expeditions, affinity_cards |
| `save_action_profile` | characters, persistence_operations |
| `save_guest_projection` | characters, persistence_operations, connection_flow |
| `save_local_character` | foundation |
| `save_progress` | foundation |
| `save_session_garden` | persistence_operations |
| `scout_radius` | enemies |
| `scout_snapshot` | enemies |
| `seed_reserve` | seeds |
| `select_attack_target` | combat |
| `select_class` | classes, weapons, characters |
| `selected_donation` | seeds |
| `selected_graft` | weapons |
| `selected_offering` | seeds |
| `selected_seed` | seeds |
| `send_action` | foundation |
| `send_altar_action` | seeds |
| `send_committed_profile` | characters, connection_flow |
| `send_expedition_state` | connection_flow, expeditions, life |
| `send_garden_action` | foundation |
| `send_inventory_action` | items |
| `send_travel_ready` | expeditions |
| `settle_expedition_rewards` | loot, persistence_operations, garden_returns |
| `shared_parts_snapshot` | weapons |
| `show_checkpoint_deposit` | items |
| `show_garden_altar` | seeds |
| `show_gate_preparation` | expeditions |
| `show_graft_menu` | weapons |
| `show_heart_tree` | knowledge |
| `show_planting_picker` | seeds |
| `skill_area_targets` | classes |
| `skill_line_targets` | classes |
| `snapshot_expedition_runtime` | expeditions, persistence_operations |
| `spawn_brood` | enemies, enemy_attack_plan |
| `start_encounter` | expeditions |
| `stored_counts` | weapons |
| `strike_enemy` | combat, affinity_cards |
| `strike_radius` | enemies |
| `submit_combat` | foundation |
| `submit_motion` | foundation |
| `submit_movement` | foundation |
| `support_allies` | enemies |
| `tell` | presentation |
| `tell_profile_action` | persistence_operations, connection_flow, characters, expeditions, garden |
| `toggle_overlay` | presentation |
| `update_combat_tracking` | enemies |
| `update_enemy` | enemies |
| `update_garden_altar` | seeds |
| `update_network_session` | foundation |
| `update_pressure` | enemies |
| `update_projectiles` | combat, weapons, classes, enemies |
| `update_ready_panel` | expeditions |
| `update_scouts` | enemies, enemy_attack_plan |
| `update_support_effects` | classes |
| `update_support_position` | enemies, enemy_attack_plan |
| `upgrade_checkpoint_open` | expeditions |
| `use_checkpoint` | expeditions |
| `use_class_skill` | classes, combat, weapons, life, affinity_cards |
| `use_heart_research` | knowledge |
| `weapon_effect_color` | presentation |
| `weapon_stats` | weapons, classes, expeditions, combat |
| `wild_entry` | expeditions |
| `world_direction` | terrain |

## Scoped integration wiring

The untouched dispatcher/file remainder keeps its original coverage. These exact fragments and their source locations have the following additional consumers.

| Location | Region | Systems |
|---|---|---|
| `game.gd::_select_class` | ct05_oracle_1 | oracle_progression, class_tree_access |
| `game.gd::apply_hit_grace` | ct05_oracle_1 | oracle_progression |
| `game.gd::save_guest_projection` | ct01_whole_xp_0 | classes, connection_flow, characters, persistence_operations |
| `game.gd::receive_character` | ct01_whole_xp_0 | classes, connection_flow, characters, persistence_operations |
| `game.gd::graft_block_reason` | cr05_grafts_0 | combat_affinity_contracts, weapons, classes, life |
| `game.gd::_apply_loadout_action` | ct02_0 | weaver_progression, warden_progression, combat_affinity_contracts |
| `game.gd::_apply_loadout_action` | ct02_1 | weaver_progression, warden_progression, combat_affinity_contracts |
| `game.gd::_apply_loadout_action` | ct02_2 | weaver_progression, warden_progression, combat_affinity_contracts |
| `game.gd::_apply_loadout_action` | ct01_0 | warden_progression, classes, combat_affinity_contracts |
| `game.gd::_apply_loadout_action` | ct01_1 | warden_progression, classes, combat_affinity_contracts |
| `game.gd::_apply_loadout_action` | cr05_progression_0 | classes, life, combat_affinity_contracts |
| `game.gd::dodge_player` | ec01_1 | affinity_cards |
| `game.gd::dodge_player` | cr04c_spirit_0 | spirit_affinity, combat_affinity_contracts, world_snapshot |
| `game.gd::move_player` | ct03_ranger_1 | terrain, ranger_progression |
| `game.gd::move_player` | cr04c_spirit_0 | spirit_affinity, combat_affinity_contracts, world_snapshot |
| `game.gd::move_player` | cr04c_spirit_1 | spirit_affinity, combat_affinity_contracts, world_snapshot |
| `game.gd::send_expedition_state` | experimental_coop_1 | hex_terrain, terrain, connection_flow, garden |
| `game.gd::collect_drop` | experimental_seed_rewards_1 | hex_terrain, loot, terrain |
| `game.gd::_garden_action` | ec01_1 | affinity_cards |
| `game.gd::_garden_action` | experimental_terrain_1 | hex_terrain, terrain, garden, persistence_operations |
| `game.gd::_garden_action` | experimental_terrain_3 | hex_terrain, terrain, garden, persistence_operations |
| `game.gd::_garden_action` | experimental_terrain_5 | hex_terrain, terrain, garden, persistence_operations |
| `game.gd::_garden_action` | experimental_terrain_7 | hex_terrain, terrain, garden, persistence_operations |
| `game.gd::_garden_action` | experimental_terrain_9 | hex_terrain, terrain, garden, persistence_operations |
| `game.gd::_garden_action` | guest_projection | persistence_operations, connection_flow, characters, expeditions, garden, foundation, cultivation_growth, garden_care, garden_stations, garden_cinematics, gate_access, garden_observations |
| `game.gd::_garden_action` | guarded_expedition | persistence_operations, foundation, cultivation_growth, garden_care, garden_stations, garden_cinematics, gate_access, garden_observations |
| `game.gd::_garden_action` | guarded_garden_actions | persistence_operations, foundation, cultivation_growth, garden_care, garden_stations, garden_cinematics, gate_access, garden_observations |
| `game.gd::_garden_action` | cleanup_feedback | persistence_operations |
| `game.gd::_garden_action` | guarded_gameplay_writer | persistence_operations |
| `game.gd::_garden_action` | growth_balance | cultivation_growth |
| `game.gd::_garden_action` | crop_care_adapter | garden_care |
| `game.gd::_garden_action` | local_garden_stations | garden_stations |
| `game.gd::_garden_action` | growth_adapter | garden_cinematics |
| `game.gd::_garden_action` | gate_range | gate_access |
| `game.gd::_garden_action` | garden_command | garden_observations |
| `game.gd::_buy_upgrade` | cr02_affinity_contract | combat_affinity_contracts |
| `game.gd::_buy_upgrade` | guarded_garden_actions | persistence_operations, expeditions, combat_vitals, gate_access |
| `game.gd::_buy_upgrade` | vitals_upgrade_capacity | combat_vitals |
| `game.gd::_buy_upgrade` | gate_range | gate_access |
| `game.gd::_act` | experimental_seed_rewards_1 | hex_terrain, loot, terrain |
| `game.gd::_act` | experimental_terrain_1 | hex_terrain, terrain, garden, persistence_operations |
| `game.gd::_act` | experimental_terrain_3 | hex_terrain, terrain, garden, persistence_operations |
| `game.gd::_act` | guarded_expedition | persistence_operations, foundation, gate_access, ui_copy, garden_care, garden_observations |
| `game.gd::_act` | guarded_gameplay_writer | persistence_operations |
| `game.gd::_act` | prefer_nearest_gate | gate_access |
| `game.gd::_act` | ui_copy | ui_copy |
| `game.gd::_act` | crop_care_adapter | garden_care |
| `game.gd::_act` | gate_range | gate_access |
| `game.gd::_act` | garden_inspect | garden_observations |
| `game.gd::_use_checkpoint` | guarded_expedition | persistence_operations, expeditions, expedition_sustain, healing_rolls, combat_balance_preview, combat_vitals, garden_returns, gate_access |
| `game.gd::_use_checkpoint` | cb07_0 | expedition_sustain |
| `game.gd::_use_checkpoint` | cb07_6 | expedition_sustain |
| `game.gd::_use_checkpoint` | cb07_7 | expedition_sustain |
| `game.gd::_use_checkpoint` | healing_roll_0 | healing_rolls |
| `game.gd::_use_checkpoint` | healing_roll_5 | healing_rolls |
| `game.gd::_use_checkpoint` | healing_roll_6 | healing_rolls |
| `game.gd::_use_checkpoint` | preview_gate_recovery | combat_balance_preview |
| `game.gd::_use_checkpoint` | vitals_floor_recovery | combat_vitals |
| `game.gd::_use_checkpoint` | garden_returns | garden_returns |
| `game.gd::_use_checkpoint` | gate_hold | gate_access |
| `game.gd::_use_checkpoint` | gate_range | gate_access |
| `game.gd::_process` | ec01_1 | affinity_cards |
| `game.gd::_process` | ct01_0 | warden_progression, classes, combat_affinity_contracts |
| `game.gd::_process` | ct01_1 | warden_progression, classes, combat_affinity_contracts |
| `game.gd::_process` | cr04c_void_hud_0 | void_affinity, combat_affinity_contracts, world_snapshot, presentation |
| `game.gd::_process` | cr02_affinity_contract | combat_affinity_contracts |
| `game.gd::_process` | experimental_coop_1 | hex_terrain, terrain, connection_flow, garden |
| `game.gd::_process` | experimental_seed_rewards_1 | hex_terrain, loot, terrain |
| `game.gd::_process` | experimental_gate_visibility | hex_terrain, terrain |
| `game.gd::_process` | experimental_terrain_1 | hex_terrain, terrain, garden, persistence_operations |
| `game.gd::_process` | experimental_terrain_3 | hex_terrain, terrain, garden, persistence_operations |
| `game.gd::_process` | experimental_terrain_5 | hex_terrain, terrain, garden, persistence_operations |
| `game.gd::_process` | experimental_terrain_7 | hex_terrain, terrain, garden, persistence_operations |
| `game.gd::_process` | guarded_expedition | persistence_operations, foundation, menus, connection_flow, health_pool_hud, class_balance, combat_balance_preview, glasscap_feints, core_combat, ranged_release, event_audio, soundscape, thief_escape, developer_garden, warden_progression, gate_access, boss_phase_fights, enemy_attack_plan, ui_copy, avatar_motion_view, cultivation_growth, party_ui, garden_observations, expedition_pressure, expedition_ui, garden_stations |
| `game.gd::_process` | guarded_garden_actions | persistence_operations, foundation, menus, connection_flow, health_pool_hud, class_balance, combat_balance_preview, glasscap_feints, core_combat, ranged_release, event_audio, soundscape, thief_escape, developer_garden, warden_progression, gate_access, boss_phase_fights, enemy_attack_plan, ui_copy, avatar_motion_view, cultivation_growth, party_ui, garden_observations, expedition_pressure, expedition_ui, garden_stations |
| `game.gd::_process` | cleanup_feedback | persistence_operations |
| `game.gd::_process` | guarded_session_heartbeat | persistence_operations, menus, connection_flow |
| `game.gd::_process` | guarded_legacy_heartbeat | persistence_operations, menus, connection_flow |
| `game.gd::_process` | health_pool_map_layout | health_pool_hud |
| `game.gd::_process` | cb04_1 | class_balance |
| `game.gd::_process` | preview_revive_prompt | combat_balance_preview |
| `game.gd::_process` | render_glasscap_copies | glasscap_feints |
| `game.gd::_process` | prepare_glasscap_view | glasscap_feints |
| `game.gd::_process` | stale_glasscap_formation | glasscap_feints |
| `game.gd::_process` | stale_dream_lure_hints | core_combat |
| `game.gd::_process` | local_ranged_aim | ranged_release |
| `game.gd::_process` | event_audio_frame | event_audio |
| `game.gd::_process` | soundscape_scene_context | soundscape |
| `game.gd::_process` | display_thief_routes | thief_escape |
| `game.gd::_process` | developer_menu_status | developer_garden |
| `game.gd::_process` | host_show_port_only | connection_flow |
| `game.gd::_process` | show_join_address_button | connection_flow |
| `game.gd::_process` | subclass_tooltip_visibility | warden_progression |
| `game.gd::_process` | subclass_card_tooltip | warden_progression |
| `game.gd::_process` | warden_skill_hud_readout | warden_progression |
| `game.gd::_process` | warden_skill_hud_state | warden_progression |
| `game.gd::_process` | expanded_core_stale_field | core_combat |
| `game.gd::_process` | class_skill_hover | core_combat |
| `game.gd::_process` | core_hud_state | core_combat |
| `game.gd::_process` | core_stale_terrain | core_combat |
| `game.gd::_process` | prefer_nearest_gate_prompt | gate_access |
| `game.gd::_process` | nursery_guide | boss_phase_fights |
| `game.gd::_process` | enemy_attack_plan | enemy_attack_plan |
| `game.gd::_process` | ui_copy | ui_copy |
| `game.gd::_process` | avatar_motion_view | avatar_motion_view |
| `game.gd::_process` | growth_balance | cultivation_growth |
| `game.gd::_process` | party_panel | party_ui |
| `game.gd::_process` | gate_range | gate_access |
| `game.gd::_process` | garden_prompt | garden_observations |
| `game.gd::_process` | reinforcement_countdown | expedition_pressure |
| `game.gd::_process` | floor_track | expedition_ui |
| `game.gd::_process` | garden_stories_label | garden_stations |
| `game.gd::can_checkpoint_bank` | gate_range | gate_access |
| `game.gd::at_weapon_gate` | experimental_terrain_1 | hex_terrain, terrain, garden, persistence_operations |
| `game.gd::at_weapon_gate` | gate_range | gate_access |
| `game.gd::resume_checkpoint_if_ready` | guarded_expedition | persistence_operations, expeditions, gate_access |
| `game.gd::resume_checkpoint_if_ready` | gate_range | gate_access |
| `game.gd::build_hud` | experimental_coop_1 | hex_terrain, terrain, connection_flow, garden |
| `game.gd::build_hud` | experimental_terrain_1 | hex_terrain, terrain, garden, persistence_operations |
| `game.gd::build_hud` | guarded_lifecycle | persistence_operations, connection_flow, presentation, menus, settings, life, classes, expedition_summary, menu_layout, ui_copy, garden_observations, garden_stations |
| `game.gd::build_hud` | retained_cleanup_feedback | persistence_operations |
| `game.gd::build_hud` | mount_run_summary | expedition_summary |
| `game.gd::build_hud` | menu_buttons_use_shared_roots | menu_layout |
| `game.gd::build_hud` | guest_connection_cancel | connection_flow |
| `game.gd::build_hud` | guest_connection_action | connection_flow |
| `game.gd::build_hud` | host_share_action | connection_flow |
| `game.gd::build_hud` | ui_copy | ui_copy |
| `game.gd::build_hud` | menu_layout | menu_layout |
| `game.gd::build_hud` | garden_mount | garden_observations |
| `game.gd::build_hud` | garden_stories_label | garden_stations |
| `game.gd::toggle_overlay` | show_run_summary | expedition_summary |
| `game.gd::toggle_overlay` | cancel_held_aim | ability_aim |
| `game.gd::toggle_overlay` | garden_panel | garden_observations |
| `game.gd::player_snapshot` | ec01_1 | affinity_cards |
| `game.gd::player_snapshot` | ct03_ranger_1 | foundation, ranger_progression |
| `game.gd::player_snapshot` | ct01_0 | warden_progression, classes, combat_affinity_contracts |
| `game.gd::player_snapshot` | cr04c_void_0 | void_affinity, combat_affinity_contracts, world_snapshot |
| `game.gd::player_snapshot` | cr04c_spirit_0 | spirit_affinity, combat_affinity_contracts, world_snapshot |
| `game.gd::player_snapshot` | cr02_affinity_contract | combat_affinity_contracts |
| `game.gd::player_snapshot` | experimental_coop_1 | hex_terrain, terrain, connection_flow, garden |
| `game.gd::player_snapshot` | replicate_thief_routes | thief_escape |
| `game.gd::player_snapshot` | warden_private_combat_state | warden_progression |
| `game.gd::player_snapshot` | class_aim_owner | ability_aim |
| `game.gd::player_snapshot` | core_owner_projection | core_combat |
| `game.gd::player_snapshot` | garden_projection | garden_observations |
| `game.gd::add_player` | cr02_affinity_contract | combat_affinity_contracts |
| `game.gd::add_player` | preview_spawn_capacity | combat_balance_preview |
| `game.gd::add_player` | preview_starting_capacity | combat_balance_preview |
| `game.gd::add_player` | growth_adapter | garden_cinematics |
| `game.gd::register_character` | ct01_whole_xp_0 | classes, connection_flow, characters, persistence_operations |
| `game.gd::register_character` | ct01_whole_xp_1 | classes, connection_flow, characters, persistence_operations |
| `game.gd::register_character` | guest_projection | persistence_operations, connection_flow, characters, expeditions, garden, foundation, garden_cinematics |
| `game.gd::register_character` | guarded_lifecycle | persistence_operations, connection_flow, foundation, garden_cinematics |
| `game.gd::register_character` | guarded_gameplay_writer | persistence_operations |
| `game.gd::register_character` | growth_adapter | garden_cinematics |
| `game.gd::_input` | experimental_placement_cancel | hex_terrain, garden |
| `game.gd::_input` | run_summary_shortcut | expedition_summary |
| `game.gd::_input` | held_aim_release | ability_aim |
| `game.gd::_input` | growth_adapter | garden_cinematics |
| `game.gd::_unhandled_key_input` | ec01_1 | affinity_cards |
| `game.gd::_unhandled_key_input` | experimental_coop_1 | hex_terrain, terrain, connection_flow, garden |
| `game.gd::_unhandled_key_input` | experimental_terrain_1 | hex_terrain, terrain, garden, persistence_operations |
| `game.gd::_unhandled_key_input` | experimental_terrain_3 | hex_terrain, terrain, garden, persistence_operations |
| `game.gd::_unhandled_key_input` | held_aim_press | ability_aim |
| `game.gd::_unhandled_key_input` | held_aim_replaces_press | ability_aim |
| `game.gd::_unhandled_key_input` | core_press | core_combat |
| `game.gd::_unhandled_key_input` | crop_care_adapter | garden_care |
| `game.gd::_unhandled_key_input` | growth_adapter | garden_cinematics |
| `game.gd::_physics_process` | ct02_0 | weaver_progression, warden_progression, combat_affinity_contracts |
| `game.gd::_physics_process` | ct01_0 | warden_progression, classes, combat_affinity_contracts |
| `game.gd::_physics_process` | cr04c_void_0 | void_affinity, combat_affinity_contracts, world_snapshot |
| `game.gd::_physics_process` | cr04c_spirit_0 | spirit_affinity, combat_affinity_contracts, world_snapshot |
| `game.gd::_physics_process` | wood_affinity_1 | wood_affinity, combat_affinity_contracts |
| `game.gd::_physics_process` | thorn_tick | thorn_affinity, combat_affinity_contracts |
| `game.gd::_physics_process` | affinity_effect_updates | vital_affinity, fire_affinity, combat_affinity_contracts |
| `game.gd::_physics_process` | experimental_heart_assimilation | hex_terrain |
| `game.gd::_physics_process` | guarded_expedition | persistence_operations, foundation, core_combat, cultivation_growth, garden_cinematics |
| `game.gd::_physics_process` | guarded_gameplay_writer | persistence_operations |
| `game.gd::_physics_process` | core_simulation | core_combat |
| `game.gd::_physics_process` | growth_balance | cultivation_growth |
| `game.gd::_physics_process` | growth_adapter | garden_cinematics |
| `game.gd::plant_seed` | cleanup_feedback | persistence_operations |
| `game.gd::plant_seed` | guarded_gameplay_writer | persistence_operations |
| `game.gd::plant_seed` | ui_copy | ui_copy |
| `game.gd::plant_seed` | plant_seed_g07 | garden_conduit |
| `game.gd::plant_seed` | growth_balance | cultivation_growth |
| `game.gd::plant_seed` | crop_care_adapter | garden_care |
| `game.gd::harvest` | guarded_garden_actions | persistence_operations, seeds, garden, knowledge, items, garden_care |
| `game.gd::harvest` | crop_care_adapter | garden_care |
| `game.gd::_harvest` | experimental_terrain_1 | hex_terrain, terrain, garden, persistence_operations |
| `game.gd::_harvest` | guest_projection | persistence_operations, connection_flow, characters, expeditions, garden, seeds, knowledge, items, event_audio, garden_care |
| `game.gd::_harvest` | guarded_garden_actions | persistence_operations, seeds, garden, knowledge, items, event_audio, garden_care |
| `game.gd::_harvest` | harvest_cue | event_audio |
| `game.gd::_harvest` | crop_care_adapter | garden_care |
| `game.gd::garden_action` | guarded_garden_actions | persistence_operations, foundation, ability_aim, core_combat, cultivation_growth |
| `game.gd::garden_action` | guarded_gameplay_writer | persistence_operations |
| `game.gd::garden_action` | class_aim_command | ability_aim |
| `game.gd::garden_action` | core_cast | core_combat |
| `game.gd::garden_action` | growth_balance | cultivation_growth |
| `game.gd::_enter_wilds` | cr04c_void_0 | void_affinity, combat_affinity_contracts, world_snapshot |
| `game.gd::_enter_wilds` | cr04c_spirit_0 | spirit_affinity, combat_affinity_contracts, world_snapshot |
| `game.gd::_enter_wilds` | cr04c_storm_lifecycle | storm_affinity |
| `game.gd::_enter_wilds` | wood_affinity_1 | wood_affinity, combat_affinity_contracts |
| `game.gd::_enter_wilds` | thorn_form_reset | thorn_affinity, combat_affinity_contracts |
| `game.gd::_enter_wilds` | affinity_floor_state | vital_affinity, fire_affinity, combat_affinity_contracts |
| `game.gd::_enter_wilds` | cr03_frost_integration | frost_affinity |
| `game.gd::_enter_wilds` | cr02_affinity_contract | combat_affinity_contracts |
| `game.gd::_enter_wilds` | guarded_expedition | persistence_operations, expeditions, combat_balance_preview, combat_vitals, core_combat, ui_copy, garden_returns |
| `game.gd::_enter_wilds` | preview_departure_capacity | combat_balance_preview |
| `game.gd::_enter_wilds` | vitals_capacity_bonus | combat_vitals |
| `game.gd::_enter_wilds` | core_cooldown_reset | core_combat |
| `game.gd::_enter_wilds` | ui_copy | ui_copy |
| `game.gd::_enter_wilds` | garden_returns | garden_returns |
| `game.gd::_finish_failed_expedition` | experimental_reward_checkpoint | hex_terrain, terrain, persistence_operations |
| `game.gd::_finish_failed_expedition` | guarded_expedition | persistence_operations, life, garden_returns |
| `game.gd::_finish_failed_expedition` | garden_returns | garden_returns |
| `game.gd::remove_player` | guarded_lifecycle | persistence_operations, connection_flow, foundation, garden_returns |
| `game.gd::remove_player` | guarded_expedition | persistence_operations, foundation, garden_returns |
| `game.gd::remove_player` | guarded_gameplay_writer | persistence_operations |
| `game.gd::remove_player` | garden_returns | garden_returns |
| `game.gd::abandon_run` | experimental_reward_checkpoint | hex_terrain, terrain, persistence_operations |
| `game.gd::abandon_run` | guarded_expedition | persistence_operations, expeditions, ui_copy, garden_returns |
| `game.gd::abandon_run` | ui_copy | ui_copy |
| `game.gd::abandon_run` | garden_returns | garden_returns |
| `game.gd::bank_checkpoint_item` | guarded_garden_actions | persistence_operations, items, ui_copy, garden_returns |
| `game.gd::bank_checkpoint_item` | guarded_gameplay_writer | persistence_operations |
| `game.gd::bank_checkpoint_item` | ui_copy | ui_copy |
| `game.gd::bank_checkpoint_item` | garden_returns | garden_returns |
| `game.gd::identify_seed` | garden_returns | garden_returns |
| `game.gd::use_checkpoint` | guarded_expedition | persistence_operations, expeditions, garden_returns |
| `game.gd::use_checkpoint` | return_retry_field | garden_returns |
| `game.gd::finish_failed_expedition` | guarded_expedition | persistence_operations, life, garden_returns |
| `game.gd::finish_failed_expedition` | return_retry_field | garden_returns |
| `game.gd::update_pressure` | reinforcement_service | expedition_pressure |
| `game.gd::attack_hints_snapshot` | thorn_fields | thorn_affinity, combat_affinity_contracts |
| `game.gd::attack_hints_snapshot` | publish_glasscap_formation | glasscap_feints |
| `game.gd::attack_hints_snapshot` | warden_anchor_ground_marker | warden_progression |
| `game.gd::attack_hints_snapshot` | core_terrain_projection | core_combat |
| `game.gd::attack_hints_snapshot` | boss_lair_fights | boss_lair_fights |
| `game.gd::attack_hints_snapshot` | heavy_and_support | enemy_attack_plan |
| `game.gd::attack_hints_snapshot` | enemy_attack_plan | enemy_attack_plan |
| `game.gd::attack_hints_snapshot` | reinforcement_hints | expedition_pressure |
| `game.gd::at_garden_station` | experimental_terrain_1 | hex_terrain, terrain, garden, persistence_operations |
| `game.gd::at_garden_station` | station_access | garden_stations |
| `game.gd::reclaim_seed` | guarded_garden_actions | persistence_operations, seeds, garden_stations |
| `game.gd::reclaim_seed` | guarded_gameplay_writer | persistence_operations |
| `game.gd::reclaim_seed` | station_access | garden_stations |
| `game.gd::select_class` | guarded_garden_actions | persistence_operations, classes, weapons, characters, ui_copy |
| `game.gd::select_class` | guarded_gameplay_writer | persistence_operations |
| `game.gd::select_class` | ui_copy | ui_copy |
| `game.gd::handle_loadout_action` | guarded_garden_actions | persistence_operations, weapons, classes, items, class_tree_access, warden_progression, ui_copy |
| `game.gd::handle_loadout_action` | guarded_gameplay_writer | persistence_operations |
| `game.gd::handle_loadout_action` | class_tree_stations | class_tree_access |
| `game.gd::handle_loadout_action` | display_learned_warden_node | warden_progression |
| `game.gd::handle_loadout_action` | ui_copy | ui_copy |
| `game.gd::checkpoint_card_data` | ec01_1 | affinity_cards |
| `game.gd::checkpoint_card_data` | cb05_0 | core_balance |
| `game.gd::checkpoint_card_data` | cb05_1 | core_balance |
| `game.gd::checkpoint_card_data` | warden_card_text | warden_progression |
| `game.gd::checkpoint_card_data` | core_card_copy | core_combat |
| `game.gd::checkpoint_card_data` | ui_copy | ui_copy |
| `game.gd::update_scouts` | tc01_ranged_clearance_1 | enemies, enemy_attack_plan, hex_terrain |
| `game.gd::update_scouts` | tc01_ranged_clearance_2 | enemies, enemy_attack_plan, hex_terrain |
| `game.gd::update_scouts` | tc01_ranged_clearance_3 | enemies, enemy_attack_plan, hex_terrain |
| `game.gd::update_scouts` | cr04c_spirit_0 | spirit_affinity, combat_affinity_contracts, world_snapshot |
| `game.gd::update_scouts` | cr03_frost_integration | frost_affinity |
| `game.gd::update_scouts` | regular_learned_approach | wilds_skill_tactics |
| `game.gd::update_scouts` | thorn_vault_choice | thorn_adaptation |
| `game.gd::update_scouts` | heavy_and_support | enemy_attack_plan |
| `game.gd::update_scouts` | species_variants | enemy_attack_plan |
| `game.gd::update_scouts` | enemy_attack_plan | enemy_attack_plan |
| `game.gd::resolve_scout` | ct05_oracle_1 | oracle_progression |
| `game.gd::resolve_scout` | tc01_ranged_clearance_1 | enemies, enemy_attack_plan, hex_terrain |
| `game.gd::resolve_scout` | tc01_ranged_clearance_2 | enemies, enemy_attack_plan, hex_terrain |
| `game.gd::resolve_scout` | cr03_frost_integration | frost_affinity |
| `game.gd::resolve_scout` | cb06_11 | enemy_balance |
| `game.gd::resolve_scout` | glasscap_volley_release | glasscap_feints |
| `game.gd::resolve_scout` | repeat_windup | event_audio |
| `game.gd::resolve_scout` | ranged_release | event_audio |
| `game.gd::resolve_scout` | sweep_release | event_audio |
| `game.gd::resolve_scout` | movement_release | event_audio |
| `game.gd::resolve_scout` | chant_release | event_audio |
| `game.gd::resolve_scout` | lure_release | event_audio |
| `game.gd::resolve_scout` | resolved_echo_bud | enemy_move_feedback |
| `game.gd::resolve_scout` | resolved_learned_sector | enemy_move_feedback |
| `game.gd::resolve_scout` | resolved_learned_travel | enemy_move_feedback |
| `game.gd::resolve_scout` | confirmed_pull | enemy_move_feedback |
| `game.gd::resolve_scout` | visible_lantern_release | enemy_move_feedback |
| `game.gd::resolve_scout` | no_extra_learned_volley | wilds_skill_tactics |
| `game.gd::resolve_scout` | learned_bent_charge | wilds_skill_tactics |
| `game.gd::resolve_scout` | thorn_vault_release | thorn_adaptation |
| `game.gd::resolve_scout` | heavy_and_support | enemy_attack_plan |
| `game.gd::resolve_scout` | species_variants | enemy_attack_plan |
| `game.gd::resolve_scout` | enemy_attack_plan | enemy_attack_plan |
| `game.gd::current_mutations` | enemy_attack_plan | enemy_attack_plan |
| `game.gd::update_support_position` | learned_support_windup | wilds_skill_tactics |
| `game.gd::update_support_position` | learned_relay_windup | wilds_skill_tactics |
| `game.gd::update_support_position` | heavy_and_support | enemy_attack_plan |
| `game.gd::update_support_position` | enemy_attack_plan | enemy_attack_plan |
| `game.gd::make_scout` | cb06_12 | enemy_balance |
| `game.gd::make_scout` | preview_juvenile_hp | combat_balance_preview |
| `game.gd::make_scout` | heavy_and_support | enemy_attack_plan |
| `game.gd::make_scout` | species_variants | enemy_attack_plan |
| `game.gd::apply_weapon_hit` | ct05_oracle_1 | oracle_progression |
| `game.gd::apply_weapon_hit` | ct05_oracle_2 | oracle_progression |
| `game.gd::apply_weapon_hit` | ct03_ranger_1 | combat, weapons, classes, loot, enemies, enemy_attack_plan, ranger_progression |
| `game.gd::apply_weapon_hit` | cr05_shared_grave_0 | combat_affinity_contracts, weapons, classes, life |
| `game.gd::apply_weapon_hit` | cr05_shared_grave_1 | combat_affinity_contracts, weapons, classes, life |
| `game.gd::apply_weapon_hit` | cr05_grafts_0 | combat_affinity_contracts, weapons, classes, life |
| `game.gd::apply_weapon_hit` | cr05_grafts_1 | combat_affinity_contracts, weapons, classes, life |
| `game.gd::apply_weapon_hit` | cr03_frost_integration | fire_affinity, frost_affinity |
| `game.gd::apply_weapon_hit` | cr02_affinity_contract | combat_affinity_contracts |
| `game.gd::apply_weapon_hit` | cb07_8 | expedition_sustain |
| `game.gd::apply_weapon_hit` | cb06_5 | enemy_balance |
| `game.gd::apply_weapon_hit` | healing_roll_1 | healing_rolls |
| `game.gd::apply_weapon_hit` | cb04_4 | class_balance, weapon_balance |
| `game.gd::apply_weapon_hit` | cb03_kill_heal | weapon_balance |
| `game.gd::apply_weapon_hit` | cb03_roll_resolution | weapon_balance |
| `game.gd::apply_weapon_hit` | cb03_weapon_contact_points | weapon_balance |
| `game.gd::apply_weapon_hit` | preview_kill_heal | combat_balance_preview |
| `game.gd::apply_weapon_hit` | preview_burst_threshold | combat_balance_preview |
| `game.gd::apply_weapon_hit` | preview_normalized_threat | combat_balance_preview |
| `game.gd::apply_weapon_hit` | preview_boss_exposure | combat_balance_preview |
| `game.gd::apply_weapon_hit` | preview_bark_reduction | combat_balance_preview |
| `game.gd::apply_weapon_hit` | preview_shelter_reduction | combat_balance_preview |
| `game.gd::apply_weapon_hit` | preview_outgoing_damage | combat_balance_preview |
| `game.gd::apply_weapon_hit` | preview_captured_power | combat_balance_preview |
| `game.gd::apply_weapon_hit` | vitals_kill_healing | combat_vitals |
| `game.gd::apply_weapon_hit` | vitals_hit_amount | combat_vitals |
| `game.gd::apply_weapon_hit` | vitals_bark_guard | combat_vitals |
| `game.gd::apply_weapon_hit` | vitals_shelter | combat_vitals |
| `game.gd::apply_weapon_hit` | contact_material | event_audio |
| `game.gd::apply_weapon_hit` | suppression_rite_survived | wilds_skill_tactics |
| `game.gd::apply_weapon_hit` | core_mark_damage | core_combat |
| `game.gd::apply_weapon_hit` | core_hit_no_refresh | core_combat |
| `game.gd::apply_weapon_hit` | core_hit_damage | core_combat |
| `game.gd::apply_weapon_hit` | boss_phase_fights | boss_phase_fights |
| `game.gd::apply_weapon_hit` | boss_lair_fights | boss_lair_fights |
| `game.gd::apply_weapon_hit` | heavy_and_support | enemy_attack_plan |
| `game.gd::apply_weapon_hit` | species_variants | enemy_attack_plan |
| `game.gd::reset_encounter` | ct05_oracle_1 | oracle_progression |
| `game.gd::reset_encounter` | cr05_grafts_0 | combat_affinity_contracts, weapons, classes, life |
| `game.gd::reset_encounter` | cr04c_void_0 | void_affinity, combat_affinity_contracts, world_snapshot |
| `game.gd::reset_encounter` | cr04c_spirit_0 | spirit_affinity, combat_affinity_contracts, world_snapshot |
| `game.gd::reset_encounter` | cr04c_storm_lifecycle | storm_affinity |
| `game.gd::reset_encounter` | wood_affinity_1 | wood_affinity, combat_affinity_contracts |
| `game.gd::reset_encounter` | vital_floor_clear | vital_affinity, combat_affinity_contracts |
| `game.gd::reset_encounter` | experimental_certified_leader | hex_terrain, terrain |
| `game.gd::reset_encounter` | experimental_floor_diagnostic | hex_terrain, terrain |
| `game.gd::reset_encounter` | experimental_terrain_1 | hex_terrain, terrain, garden, persistence_operations |
| `game.gd::reset_encounter` | experimental_terrain_3 | hex_terrain, terrain, garden, persistence_operations |
| `game.gd::reset_encounter` | guarded_expedition | persistence_operations, expeditions, encounter_composition, enemy_balance, core_combat |
| `game.gd::reset_encounter` | cb06_0 | enemy_balance |
| `game.gd::reset_encounter` | cb06_1 | enemy_balance |
| `game.gd::reset_encounter` | cb06_2 | enemy_balance |
| `game.gd::reset_encounter` | cb06_3 | enemy_balance |
| `game.gd::reset_encounter` | core_floor_reset | core_combat |
| `game.gd::reset_encounter` | pack_composition | encounter_composition |
| `game.gd::use_class_skill` | ec01_1 | affinity_cards |
| `game.gd::use_class_skill` | ec01_2 | affinity_cards |
| `game.gd::use_class_skill` | ct05_oracle_1 | oracle_progression |
| `game.gd::use_class_skill` | ct05_oracle_2 | oracle_progression |
| `game.gd::use_class_skill` | ct05_oracle_3 | oracle_progression |
| `game.gd::use_class_skill` | ct05_oracle_4 | oracle_progression |
| `game.gd::use_class_skill` | ct04_reaper_1 | classes, combat, weapons, life, reaper_progression |
| `game.gd::use_class_skill` | ct04_reaper_2 | classes, combat, weapons, life, reaper_progression |
| `game.gd::use_class_skill` | ct04_reaper_3 | classes, combat, weapons, life, reaper_progression |
| `game.gd::use_class_skill` | ct04_reaper_4 | classes, combat, weapons, life, reaper_progression |
| `game.gd::use_class_skill` | ct03_ranger_1 | classes, combat, weapons, life, ranger_progression |
| `game.gd::use_class_skill` | ct03_ranger_2 | classes, combat, weapons, life, ranger_progression |
| `game.gd::use_class_skill` | ct03_ranger_3 | classes, combat, weapons, life, ranger_progression |
| `game.gd::use_class_skill` | ct03_ranger_4 | classes, combat, weapons, life, ranger_progression |
| `game.gd::use_class_skill` | tc01_ranged_clearance_1 | classes, combat, weapons, life, hex_terrain |
| `game.gd::use_class_skill` | ct02_0 | weaver_progression, warden_progression, combat_affinity_contracts |
| `game.gd::use_class_skill` | ct02_1 | weaver_progression, warden_progression, combat_affinity_contracts |
| `game.gd::use_class_skill` | ct01_0 | warden_progression, classes, combat_affinity_contracts |
| `game.gd::use_class_skill` | ct01_1 | warden_progression, classes, combat_affinity_contracts |
| `game.gd::use_class_skill` | ct01_2 | warden_progression, classes, combat_affinity_contracts |
| `game.gd::use_class_skill` | cr05_focus_0 | classes, combat_affinity_contracts |
| `game.gd::use_class_skill` | cr05_focus_1 | classes, combat_affinity_contracts |
| `game.gd::use_class_skill` | cr05_focus_2 | classes, combat_affinity_contracts |
| `game.gd::use_class_skill` | cr04c_spirit_0 | spirit_affinity, combat_affinity_contracts, world_snapshot |
| `game.gd::use_class_skill` | wood_affinity_1 | wood_affinity, combat_affinity_contracts |
| `game.gd::use_class_skill` | cr03_frost_integration | vital_affinity, frost_affinity |
| `game.gd::use_class_skill` | cr02_affinity_contract | combat_affinity_contracts |
| `game.gd::use_class_skill` | cb07_12 | expedition_sustain |
| `game.gd::use_class_skill` | cb07_13 | expedition_sustain |
| `game.gd::use_class_skill` | cb07_14 | expedition_sustain |
| `game.gd::use_class_skill` | healing_roll_2 | healing_rolls |
| `game.gd::use_class_skill` | healing_roll_3 | healing_rolls |
| `game.gd::use_class_skill` | healing_roll_4 | healing_rolls |
| `game.gd::use_class_skill` | healing_roll_7 | healing_rolls |
| `game.gd::use_class_skill` | healing_roll_8 | healing_rolls |
| `game.gd::use_class_skill` | healing_roll_9 | healing_rolls |
| `game.gd::use_class_skill` | cb04_2 | class_balance |
| `game.gd::use_class_skill` | cb04_8 | class_balance |
| `game.gd::use_class_skill` | cb04_9 | class_balance |
| `game.gd::use_class_skill` | cb04_10 | class_balance |
| `game.gd::use_class_skill` | cb04_11 | class_balance |
| `game.gd::use_class_skill` | cb04_12 | class_balance |
| `game.gd::use_class_skill` | cb03_class_heal_bonus | weapon_balance |
| `game.gd::use_class_skill` | preview_bonus_heal | combat_balance_preview |
| `game.gd::use_class_skill` | preview_capped_self_heal | combat_balance_preview |
| `game.gd::use_class_skill` | preview_ally_heal | combat_balance_preview |
| `game.gd::use_class_skill` | vitals_class_bonus_heal | combat_vitals |
| `game.gd::use_class_skill` | vitals_class_capped_heal | combat_vitals |
| `game.gd::use_class_skill` | vitals_class_ally_heal | combat_vitals |
| `game.gd::use_class_skill` | class_cast_audio | event_audio |
| `game.gd::use_class_skill` | subclass_finish_on_echo | warden_progression |
| `game.gd::use_class_skill` | subclass_followthrough | warden_progression |
| `game.gd::use_class_skill` | subclass_execute | warden_progression |
| `game.gd::use_class_skill` | warden_cast_and_confirmed_quake | warden_progression |
| `game.gd::use_class_skill` | warden_anchor_actual_center | warden_progression |
| `game.gd::use_class_skill` | aimed_target_init | ability_aim |
| `game.gd::use_class_skill` | aimed_charge | ability_aim |
| `game.gd::use_class_skill` | aimed_windstep | ability_aim |
| `game.gd::use_class_skill` | aimed_reap | ability_aim |
| `game.gd::use_class_skill` | aimed_skill_plan | ability_aim |
| `game.gd::use_class_skill` | core_quake | core_combat |
| `game.gd::use_class_skill` | core_animation_guard | core_combat |
| `game.gd::use_class_skill` | deploy_class_snare | classes, ability_aim |
| `game.gd::use_class_skill` | judgement_separate_from_snare | classes, ability_aim |
| `game.gd::receive_details` | experimental_coop_1 | hex_terrain, terrain, connection_flow, garden |
| `game.gd::receive_details` | experimental_coop_2 | hex_terrain, terrain, connection_flow, garden |
| `game.gd::receive_details` | core_owner_clock | core_combat |
| `game.gd::guest_combat_events` | core_floor_event_scope | core_combat |
| `game.gd::send_garden_action` | cleanup_feedback | persistence_operations |
| `game.gd::send_garden_action` | class_aim_log | ability_aim |
| `game.gd::send_garden_action` | core_cast_log | core_combat |
| `game.gd::weapon_stats` | cr02_affinity_contract | combat_affinity_contracts |
| `game.gd::weapon_stats` | cb07_1 | expedition_sustain |
| `game.gd::weapon_stats` | cb04_0 | class_balance |
| `game.gd::weapon_stats` | cb03_run_hp_cap | weapon_balance |
| `game.gd::weapon_stats` | cb03_run_skill_heal_cap | weapon_balance |
| `game.gd::weapon_stats` | cb03_run_kill_heal_cap | weapon_balance |
| `game.gd::weapon_stats` | cb03_run_vital_caps | weapon_balance |
| `game.gd::weapon_stats` | cb03_windup_precision | weapon_balance |
| `game.gd::weapon_stats` | cb03_damage_precision | weapon_balance |
| `game.gd::weapon_stats` | preview_stat_range | combat_balance_preview |
| `game.gd::weapon_stats` | expanded_core_card_tuning | core_combat |
| `game.gd::weapon_stats` | core_card_preview | core_combat |
| `game.gd::inventory_ui_data` | core_inventory_summary | core_combat |
| `game.gd::_finish_combat` | experimental_seed_rewards_1 | hex_terrain, loot, terrain |
| `game.gd::_finish_combat` | experimental_seed_rewards_2 | hex_terrain, loot, terrain |
| `game.gd::_finish_combat` | guarded_expedition | persistence_operations, loot, enemies, expeditions, classes, combat_balance_preview, combat_vitals, event_audio, wilds_skill_tactics, thorn_adaptation |
| `game.gd::_finish_combat` | preview_ranged_threshold | combat_balance_preview |
| `game.gd::_finish_combat` | vitals_ranged_observation | combat_vitals |
| `game.gd::_finish_combat` | vitals_ranged_threshold | combat_vitals |
| `game.gd::_finish_combat` | cleared_gate_cue | event_audio |
| `game.gd::_finish_combat` | skill_tactics_at_clear | wilds_skill_tactics |
| `game.gd::_finish_combat` | thorn_learning_observation | thorn_adaptation |
| `game.gd::emit_combat_event` | ct01_0 | warden_progression, classes, combat_affinity_contracts |
| `game.gd::emit_combat_event` | guarded_expedition | persistence_operations, presentation, expedition_sustain, core_combat, warden_progression |
| `game.gd::emit_combat_event` | cb07_2 | expedition_sustain |
| `game.gd::emit_combat_event` | core_shape_payload | core_combat |
| `game.gd::emit_combat_event` | subclass_release_label | warden_progression |
| `game.gd::emit_combat_event` | authored_core_label | core_combat |
| `game.gd::apply_enemy_hit` | ct05_oracle_1 | oracle_progression |
| `game.gd::apply_enemy_hit` | ct05_oracle_2 | oracle_progression |
| `game.gd::apply_enemy_hit` | ct01_holdfast_0 | warden_progression, combat, life |
| `game.gd::apply_enemy_hit` | ct01_0 | warden_progression, classes, combat_affinity_contracts |
| `game.gd::apply_enemy_hit` | ct01_1 | warden_progression, classes, combat_affinity_contracts |
| `game.gd::apply_enemy_hit` | ct01_2 | warden_progression, classes, combat_affinity_contracts |
| `game.gd::apply_enemy_hit` | wood_affinity_1 | wood_affinity, combat_affinity_contracts |
| `game.gd::apply_enemy_hit` | wood_affinity_2 | wood_affinity, combat_affinity_contracts |
| `game.gd::apply_enemy_hit` | wood_affinity_3 | wood_affinity, combat_affinity_contracts |
| `game.gd::apply_enemy_hit` | cr03_frost_integration | fire_affinity, water_affinity, frost_affinity |
| `game.gd::apply_enemy_hit` | cr02_affinity_contract | combat_affinity_contracts |
| `game.gd::apply_enemy_hit` | guarded_expedition | persistence_operations, life, enemy_balance, combat_balance_preview, core_combat, enemy_move_feedback |
| `game.gd::apply_enemy_hit` | cb06_7 | enemy_balance |
| `game.gd::apply_enemy_hit` | cb06_8 | enemy_balance |
| `game.gd::apply_enemy_hit` | preview_incoming_damage | combat_balance_preview |
| `game.gd::apply_enemy_hit` | ironbark_confirmed_block | core_combat |
| `game.gd::apply_enemy_hit` | generic_slow_copy | enemy_move_feedback |
| `game.gd::apply_skill_targets` | ec01_1 | affinity_cards |
| `game.gd::apply_skill_targets` | ec01_2 | affinity_cards |
| `game.gd::apply_skill_targets` | ct04_reaper_1 | classes, reaper_progression |
| `game.gd::apply_skill_targets` | ct03_ranger_1 | classes, ranger_progression |
| `game.gd::apply_skill_targets` | ct02_0 | weaver_progression, warden_progression, combat_affinity_contracts |
| `game.gd::apply_skill_targets` | ct02_1 | weaver_progression, warden_progression, combat_affinity_contracts |
| `game.gd::apply_skill_targets` | ct02_2 | weaver_progression, warden_progression, combat_affinity_contracts |
| `game.gd::apply_skill_targets` | cb07_9 | expedition_sustain |
| `game.gd::apply_skill_targets` | cb07_10 | expedition_sustain |
| `game.gd::apply_skill_targets` | cb07_11 | expedition_sustain |
| `game.gd::apply_skill_targets` | cb04_5 | class_balance |
| `game.gd::apply_skill_targets` | cb04_6 | class_balance |
| `game.gd::apply_skill_targets` | class_contact_material | event_audio |
| `game.gd::apply_skill_targets` | warden_damage_from_committed_origin | warden_progression |
| `game.gd::attack_animation_snapshot` | ranged_aim_snapshot | ranged_release |
| `game.gd::attack_animation_snapshot` | subclass_release_pose | warden_progression |
| `game.gd::join_game` | experimental_coop_1 | hex_terrain, terrain, connection_flow, garden |
| `game.gd::join_game` | experimental_terrain_1 | hex_terrain, terrain, garden, persistence_operations |
| `game.gd::join_game` | guest_projection | persistence_operations, connection_flow, characters, expeditions, garden, foundation, developer_garden |
| `game.gd::join_game` | guarded_lifecycle | persistence_operations, connection_flow, foundation, developer_garden |
| `game.gd::join_game` | guarded_garden_actions | persistence_operations, foundation, developer_garden, connection_flow |
| `game.gd::join_game` | retained_cleanup_feedback | persistence_operations |
| `game.gd::join_game` | cleanup_feedback | persistence_operations |
| `game.gd::join_game` | guarded_gameplay_writer | persistence_operations |
| `game.gd::join_game` | block_developer_join | developer_garden |
| `game.gd::join_game` | reset_join_phase | connection_flow |
| `game.gd::on_joined_world` | guest_projection | persistence_operations, connection_flow, characters, expeditions, garden, foundation |
| `game.gd::on_joined_world` | guarded_lifecycle | persistence_operations, connection_flow, foundation |
| `game.gd::on_joined_world` | character_join_phase | connection_flow |
| `game.gd::connection_accepted` | guest_projection | persistence_operations, connection_flow, characters, expeditions, garden, foundation |
| `game.gd::connection_accepted` | guarded_lifecycle | persistence_operations, connection_flow, foundation |
| `game.gd::connection_accepted` | retained_cleanup_feedback | persistence_operations |
| `game.gd::connection_accepted` | cleanup_feedback | persistence_operations |
| `game.gd::connection_accepted` | guarded_gameplay_writer | persistence_operations |
| `game.gd::connection_accepted` | garden_join_phase | connection_flow |
| `game.gd::on_server_disconnected` | join_disconnected_reason | connection_flow |
| `game.gd::on_connection_failed` | guarded_lifecycle | persistence_operations, connection_flow, foundation |
| `game.gd::on_connection_failed` | join_failed_reason | connection_flow |
| `game.gd::return_to_main_menu` | guarded_lifecycle | persistence_operations, connection_flow, foundation, menus |
| `game.gd::return_to_main_menu` | guarded_expedition | persistence_operations, foundation, menus, connection_flow |
| `game.gd::return_to_main_menu` | retained_cleanup_feedback | persistence_operations |
| `game.gd::return_to_main_menu` | cleanup_feedback | persistence_operations |
| `game.gd::return_to_main_menu` | guarded_gameplay_writer | persistence_operations |
| `game.gd::return_to_main_menu` | guarded_return_save_gate | persistence_operations, menus, connection_flow |
| `game.gd::return_to_main_menu` | join_does_not_save_garden | connection_flow |
| `game.gd::_finish_title_return` | production_route | persistence_operations, persistence_authorization, persistence_recovery_plan, persistence_save_access, menus, characters, developer_garden, connection_flow, expeditions, garden |
| `game.gd::_finish_title_return` | guest_projection | persistence_operations, connection_flow, characters, expeditions, garden, menus, developer_garden |
| `game.gd::_finish_title_return` | guarded_lifecycle | persistence_operations, connection_flow, menus, developer_garden |
| `game.gd::_finish_title_return` | guarded_expedition | persistence_operations, menus, connection_flow, developer_garden |
| `game.gd::_finish_title_return` | cleanup_feedback | persistence_operations |
| `game.gd::_finish_title_return` | guarded_gameplay_writer | persistence_operations |
| `game.gd::_finish_title_return` | return_from_developer_garden | developer_garden |
| `game.gd::_finish_title_return` | close_share_on_return | connection_flow |
| `game.gd::_finish_title_return` | join_menu_restore | connection_flow |
| `game.gd::request_ip_join` | experimental_coop_1 | hex_terrain, terrain, connection_flow, garden |
| `game.gd::request_ip_join` | experimental_terrain_1 | hex_terrain, terrain, garden, persistence_operations |
| `game.gd::request_ip_join` | in_world_join_endpoint | connection_flow |
| `game.gd::update_network_session` | join_steps_feedback | connection_flow |
| `game.gd::_ready` | experimental_terrain_1 | hex_terrain, terrain, garden, persistence_operations |
| `game.gd::_ready` | experimental_terrain_3 | hex_terrain, terrain, garden, persistence_operations |
| `game.gd::_ready` | production_route | persistence_operations, persistence_authorization, persistence_recovery_plan, persistence_save_access, menus, characters, developer_garden, connection_flow, foundation, menu_layout, event_audio, soundscape |
| `game.gd::_ready` | shared_menu_button_roots | menu_layout |
| `game.gd::_ready` | event_audio_node | event_audio |
| `game.gd::_ready` | soundscape_lifetime | soundscape |
| `game.gd::_ready` | developer_game_settings | developer_garden |
| `game.gd::host_game` | experimental_coop_1 | hex_terrain, terrain, connection_flow, garden |
| `game.gd::host_game` | experimental_terrain_1 | hex_terrain, terrain, garden, persistence_operations |
| `game.gd::host_game` | guarded_lifecycle | persistence_operations, connection_flow, foundation, developer_garden |
| `game.gd::host_game` | cleanup_feedback | persistence_operations |
| `game.gd::host_game` | block_developer_host | developer_garden |
| `game.gd::update_projectiles` | ct03_ranger_1 | combat, weapons, classes, enemies, ranger_progression |
| `game.gd::update_projectiles` | ct03_ranger_2 | combat, weapons, classes, enemies, ranger_progression |
| `game.gd::update_projectiles` | ct03_ranger_3 | combat, weapons, classes, enemies, ranger_progression |
| `game.gd::update_projectiles` | cr04c_spirit_0 | spirit_affinity, combat_affinity_contracts, world_snapshot |
| `game.gd::update_projectiles` | cr04c_spirit_1 | spirit_affinity, combat_affinity_contracts, world_snapshot |
| `game.gd::update_projectiles` | cr04c_spirit_2 | spirit_affinity, combat_affinity_contracts, world_snapshot |
| `game.gd::update_projectiles` | projectile_commit_audio | event_audio |
| `game.gd::update_projectiles` | melee_commit_audio | event_audio |
| `game.gd::update_projectiles` | launch_at_cursor_release | ranged_release |
| `game.gd::update_projectiles` | release_projectile_fan | ranged_release, combat_readability |
| `game.gd::update_projectiles` | fan_initial_rays | ranged_release, combat_readability |
| `game.gd::update_projectiles` | advance_projectile_rays | ranged_release, combat_readability |
| `game.gd::close_run_flow_panel` | close_crafting_class_tree | class_tree_access |
| `game.gd::add_button` | overlay_button_focus | menu_layout |
| `game.gd::grant_guard` | cr03_frost_integration | frost_affinity |
| `game.gd::grant_guard` | cr02_affinity_contract | combat_affinity_contracts |
| `game.gd::grant_guard` | cb04_7 | class_balance |
| `game.gd::grant_guard` | ironbark_replaced_ward | core_combat |
| `game.gd::update_enemy` | ct05_oracle_1 | oracle_progression |
| `game.gd::update_enemy` | ct05_oracle_2 | oracle_progression |
| `game.gd::update_enemy` | cr04c_spirit_0 | spirit_affinity, combat_affinity_contracts, world_snapshot |
| `game.gd::update_enemy` | thorn_heart_movement_scale | thorn_affinity, combat_affinity_contracts |
| `game.gd::update_enemy` | thorn_heart_movement | thorn_affinity, combat_affinity_contracts |
| `game.gd::update_enemy` | drenched_direct_leader | water_affinity, frost_affinity |
| `game.gd::update_enemy` | heart_swipe_windup | event_audio |
| `game.gd::update_enemy` | heart_vault_windup | event_audio |
| `game.gd::resolve_briar_strike` | ct05_oracle_1 | oracle_progression |
| `game.gd::resolve_briar_strike` | cb06_10 | enemy_balance |
| `game.gd::resolve_briar_strike` | heart_attack_release | event_audio |
| `game.gd::_damage_player` | guarded_expedition | persistence_operations, life, expedition_sustain, combat_balance_preview, combat_vitals |
| `game.gd::_damage_player` | cb07_3 | expedition_sustain |
| `game.gd::_damage_player` | cb07_4 | expedition_sustain |
| `game.gd::_damage_player` | preview_damage_log_units | combat_balance_preview |
| `game.gd::_damage_player` | vitals_damage_subtraction | combat_vitals |
| `game.gd::_damage_player` | vitals_damage_applied | combat_vitals |
| `game.gd::update_support_effects` | cb07_5 | expedition_sustain |
| `game.gd::update_support_effects` | cb04_3 | class_balance |
| `game.gd::update_support_effects` | preview_renewal_tick | combat_balance_preview |
| `game.gd::update_support_effects` | vitals_renewal | combat_vitals |
| `game.gd::strike_enemy` | ec01_1 | affinity_cards |
| `game.gd::strike_enemy` | ct04_reaper_1 | combat, reaper_progression |
| `game.gd::strike_enemy` | ct03_ranger_1 | combat, ranger_progression |
| `game.gd::strike_enemy` | cr05_grafts_0 | combat_affinity_contracts, weapons, classes, life |
| `game.gd::strike_enemy` | cr03_frost_integration | frost_affinity |
| `game.gd::strike_enemy` | cr02_affinity_contract | combat_affinity_contracts |
| `game.gd::strike_enemy` | preview_lock_strike | combat_balance_preview |
| `game.gd::encounter_health` | cb06_4 | enemy_balance |
| `game.gd::encounter_health` | preview_guest_enemy_hp | combat_balance_preview |
| `game.gd::restore_class_loadout` | cr05_progression_0 | classes, life, combat_affinity_contracts |
| `game.gd::restore_class_loadout` | preview_class_capacity | combat_balance_preview |
| `game.gd::_init` | preview_guest_storage | combat_balance_preview |
| `game.gd::_attempt_graft` | cr05_grafts_0 | combat_affinity_contracts, weapons, classes, life |
| `game.gd::_attempt_graft` | guarded_garden_actions | persistence_operations, weapons, weapon_balance |
| `game.gd::_attempt_graft` | cb03_graft_health_capacity | weapon_balance |
| `game.gd::hit_players_charge` | cb06_6 | enemy_balance |
| `game.gd::hit_players` | tc01_ranged_clearance_1 | combat, hex_terrain |
| `game.gd::hit_players` | ct01_0 | warden_progression, classes, combat_affinity_contracts |
| `game.gd::hit_players` | ct01_1 | warden_progression, classes, combat_affinity_contracts |
| `game.gd::hit_players` | cb06_9 | enemy_balance |
| `game.gd::enter_wilds` | cr02_affinity_contract | combat_affinity_contracts |
| `game.gd::checkpoint_offer_ids` | cr02_affinity_contract | combat_affinity_contracts |
| `game.gd::buy_upgrade` | ec01_1 | affinity_cards |
| `game.gd::buy_upgrade` | cr02_affinity_contract | combat_affinity_contracts |
| `game.gd::return_to_garden` | ec01_1 | affinity_cards |
| `game.gd::return_to_garden` | ct05_oracle_1 | oracle_progression |
| `game.gd::return_to_garden` | cr05_grafts_0 | combat_affinity_contracts, weapons, classes, life |
| `game.gd::return_to_garden` | cr04c_void_0 | void_affinity, combat_affinity_contracts, world_snapshot |
| `game.gd::return_to_garden` | cr04c_spirit_0 | spirit_affinity, combat_affinity_contracts, world_snapshot |
| `game.gd::return_to_garden` | cr04c_storm_lifecycle | storm_affinity |
| `game.gd::return_to_garden` | wood_affinity_1 | wood_affinity, combat_affinity_contracts |
| `game.gd::return_to_garden` | thorn_form_reset | thorn_affinity, combat_affinity_contracts |
| `game.gd::return_to_garden` | affinity_floor_state | vital_affinity, fire_affinity, combat_affinity_contracts |
| `game.gd::return_to_garden` | cr03_frost_integration | frost_affinity |
| `spirit_affinity.gd` | ec01_1 | affinity_cards |
| `storm_affinity.gd` | ec01_1 | affinity_cards |
| `wood_affinity.gd` | ec01_1 | affinity_cards |
| `vital_combat.gd` | ec01_1 | affinity_cards |
| `water_combat.gd` | ec01_1 | affinity_cards |
| `water_combat.gd` | ec01_2 | affinity_cards |
| `frost_combat.gd` | ec01_1 | affinity_cards |
| `combat_action_events.gd` | ec01_1 | affinity_cards |
| `combat_ruleset.gd` | ec01_playtest_1 | combat_affinity_contracts, weaver_progression |
| `combat_ruleset.gd` | ec01_1 | affinity_cards |
| `combat_ruleset.gd` | ec01_2 | affinity_cards |
| `combat_ruleset.gd` | ec01_3 | affinity_cards |
| `combat_ruleset.gd` | ct05_oracle_1 | oracle_progression |
| `combat_ruleset.gd` | ct05_oracle_2 | oracle_progression |
| `affinity_build.gd` | ec01_display_1 | combat_affinity_contracts, plant_affinities, ui_copy |
| `affinity_build.gd` | ec01_playtest_1 | combat_affinity_contracts, plant_affinities, ui_copy |
| `affinity_build.gd` | ec01_playtest_2 | combat_affinity_contracts, plant_affinities, ui_copy |
| `affinity_build.gd` | ct05_oracle_1 | oracle_progression, class_tree_access |
| `affinity_build.gd` | ct05_oracle_2 | oracle_progression, class_tree_access |
| `developer_settings.gd` | cr04a_affinity_1 | combat_affinity_contracts, fire_affinity |
| `developer_settings.gd` | cr03__ready | frost_affinity |
| `core_footprint.gd` | cr04b_wood_1 | wood_affinity, combat_affinity_contracts |
| `core_footprint.gd` | cr04b_thorn_1 | thorn_affinity, combat_affinity_contracts |
| `core_footprint.gd` | cr04a_affinity_1 | fire_affinity, water_affinity, vital_affinity, frost_affinity, combat_affinity_contracts |
| `core_footprint.gd` | cr03_build | frost_affinity |
| `warden_tree.gd` | ec01_playtest_1 | warden_progression, class_tree_access |
| `warden_tree.gd` | ct01_1 | warden_progression, classes, combat_affinity_contracts |
| `warden_tree.gd` | ct01_2 | warden_progression, classes, combat_affinity_contracts |
| `warden_tree.gd` | ct01_3 | warden_progression, classes, combat_affinity_contracts |
| `warden_tree.gd` | ct01_4 | warden_progression, classes, combat_affinity_contracts |
| `warden_tree.gd` | cr02_card_lines | combat_affinity_contracts |
| `warden_combat.gd` | ct02_1 | weaver_progression, warden_progression, combat_affinity_contracts |
| `warden_combat.gd` | ct02_2 | weaver_progression, warden_progression, combat_affinity_contracts |
| `warden_combat.gd` | ct01_holdfast_1 | warden_progression, combat, life |
| `warden_combat.gd` | ct01_holdfast_2 | warden_progression, combat, life |
| `warden_combat.gd` | ct01_holdfast_3 | warden_progression, combat, life |
| `warden_combat.gd` | ct01_holdfast_4 | warden_progression, combat, life |
| `warden_combat.gd` | ct01_1 | warden_progression, classes, combat_affinity_contracts |
| `warden_combat.gd` | ct01_2 | warden_progression, classes, combat_affinity_contracts |
| `warden_combat.gd` | ct01_3 | warden_progression, classes, combat_affinity_contracts |
| `warden_combat.gd` | ct01_4 | warden_progression, classes, combat_affinity_contracts |
| `warden_combat.gd` | ct01_5 | warden_progression, classes, combat_affinity_contracts |
| `warden_combat.gd` | ct01_6 | warden_progression, classes, combat_affinity_contracts |
| `warden_combat.gd` | ct01_7 | warden_progression, classes, combat_affinity_contracts |
| `warden_combat.gd` | ct01_8 | warden_progression, classes, combat_affinity_contracts |
| `warden_combat.gd` | ct01_9 | warden_progression, classes, combat_affinity_contracts |
| `warden_combat.gd` | ct01_10 | warden_progression, classes, combat_affinity_contracts |
| `warden_combat.gd` | ct01_11 | warden_progression, classes, combat_affinity_contracts |
| `warden_combat.gd` | ct01_12 | warden_progression, classes, combat_affinity_contracts |
| `warden_combat.gd` | ct01_13 | warden_progression, classes, combat_affinity_contracts |
| `warden_combat.gd` | ct01_14 | warden_progression, classes, combat_affinity_contracts |
| `warden_combat.gd` | ct01_15 | warden_progression, classes, combat_affinity_contracts |
| `warden_combat.gd` | ct01_16 | warden_progression, classes, combat_affinity_contracts |
| `warden_combat.gd` | ct01_17 | warden_progression, classes, combat_affinity_contracts |
| `warden_combat.gd` | cr03_block_effects | frost_affinity |
| `warden_combat.gd` | cr02_has_card | combat_affinity_contracts |
| `weapon_contact.gd` | ct04_reaper_1 | combat, reaper_progression |
| `weapon_contact.gd` | ct03_ranger_1 | combat, ranger_progression |
| `weapon_contact.gd` | cr05_grafts_1 | combat_affinity_contracts, weapons, classes, life |
| `weapon_contact.gd` | cr05_grafts_2 | combat_affinity_contracts, weapons, classes, life |
| `weapon_contact.gd` | cr04b_thorn_1 | thorn_affinity, combat_affinity_contracts |
| `weapon_contact.gd` | cr03_melee | frost_affinity |
| `weapon_contact.gd` | cr02_secondary | combat_affinity_contracts |
| `weapon_contact.gd` | cr02_melee | combat_affinity_contracts |
| `network_movement.gd` | experimental_coop_1 | hex_terrain, terrain, connection_flow, garden |
| `network_movement.gd` | experimental_coop_2 | hex_terrain, terrain, connection_flow, garden |
| `diagnostics_boot.gd` | experimental_coop_1 | hex_terrain, terrain, connection_flow, garden |
| `diagnostics_boot.gd` | experimental_coop_2 | hex_terrain, terrain, connection_flow, garden |
| `root_ui.gd` | cr04c_void_hud_1 | presentation, world_snapshot, void_affinity, spirit_affinity, storm_affinity |
| `root_ui.gd` | health_pool_7 | health_pool_hud |
| `root_ui.gd` | health_pool_6 | health_pool_hud |
| `root_ui.gd` | health_pool_5 | health_pool_hud |
| `root_ui.gd` | health_pool_4 | health_pool_hud |
| `root_ui.gd` | health_pool_3 | health_pool_hud |
| `root_ui.gd` | health_pool_2 | health_pool_hud |
| `root_ui.gd` | health_pool_1 | health_pool_hud |
| `root_ui.gd` | cb07_0 | expedition_sustain |
| `root_ui.gd` | cb02_root_ui_4_19 | combat_balance_preview |
| `root_ui.gd` | cb02_root_ui_3_18 | combat_balance_preview |
| `root_ui.gd` | cb02_root_ui_2_17 | combat_balance_preview |
| `root_ui.gd` | cb02_root_ui_1_16 | combat_balance_preview |
| `root_ui.gd` | class_skill_icon_catalog | class_skill_icons |
| `root_ui.gd` | draw_class_skill_icons | class_skill_icons |
| `root_ui.gd` | run_summary_shortcut_hint | expedition_summary |
| `root_ui.gd` | ability_aim_tooltip | ability_aim |
| `root_ui.gd` | ability_icon_draw | core_combat |
| `root_ui.gd` | ability_hover_update | core_combat |
| `root_ui.gd` | ability_hover_targets | core_combat |
| `root_ui.gd` | ability_hover_state | core_combat |
| `root_ui.gd` | core_hud_slot | core_combat |
| `root_ui.gd` | core_hud_size | core_combat |
| `root_ui.gd` | floor_view_field | expedition_ui |
| `root_ui.gd` | floor_view_child | expedition_ui |
| `root_ui.gd` | floor_view_state | expedition_ui |
| `root_ui.gd` | party_field | party_ui |
| `root_ui.gd` | party_child | party_ui |
| `root_ui.gd` | party_update | party_ui |
| `party_travel.gd` | ct05_oracle_1 | oracle_progression, class_tree_access |
| `party_travel.gd` | ct05_oracle_2 | oracle_progression, class_tree_access |
| `party_travel.gd` | cr02_departure_cost | combat_affinity_contracts |
| `party_travel.gd` | experimental_terrain_1 | hex_terrain, terrain, garden, persistence_operations |
| `party_travel.gd` | guarded_expedition_1 | persistence_operations, expeditions, connection_flow |
| `party_travel.gd` | guarded_expedition_2 | persistence_operations, expeditions, connection_flow |
| `party_travel.gd` | guarded_expedition_3 | persistence_operations, expeditions, connection_flow |
| `party_travel.gd` | guarded_expedition_4 | persistence_operations, expeditions, connection_flow |
| `party_travel.gd` | guarded_expedition_5 | persistence_operations, expeditions, connection_flow |
| `party_travel.gd` | hold_range | gate_access |
| `party_travel.gd` | request_range | gate_access |
| `progress.gd` | experimental_terrain_1 | hex_terrain, terrain, garden, persistence_operations |
| `progress.gd` | guest_projection | persistence_operations, connection_flow, characters, expeditions, garden |
| `progress.gd` | serializer_commit_integrity | foundation, persistence_operations |
| `progress.gd` | guarded_expedition_1 | persistence_operations, expeditions, garden |
| `progress.gd` | load_garden_returns | garden_returns |
| `progress.gd` | growth_backup_save | cultivation_growth |
| `progress.gd` | growth_backup_flag | cultivation_growth |
| `progress.gd` | apply_milestone_growth_balance | cultivation_growth |
| `progress.gd` | advance_growth_growth_balance | cultivation_growth |
| `progress.gd` | load_garden_growth_balance | cultivation_growth |
| `progress.gd` | advance_growth_crop_care | garden_care |
| `progress.gd` | load_garden_crop_care | garden_care |
| `progress.gd` | save_garden_growth | garden_cinematics |
| `progress.gd` | load_garden_growth | garden_cinematics |
| `progress.gd` | interaction_state | garden_observations |
| `progress.gd` | interaction_load | garden_observations |
| `progress.gd` | interaction_save | garden_observations |
| `altar_service.gd` | guarded_garden_actions_1 | persistence_operations, garden_care, seeds, items |
| `altar_service.gd` | guarded_garden_actions_2 | persistence_operations, garden_care, seeds, items |
| `altar_service.gd` | guarded_gameplay_save_dispatch | persistence_operations |
| `altar_service.gd` | guarded_gameplay_writer_1 | persistence_operations |
| `altar_service.gd` | ui_copy_1 | ui_copy |
| `altar_service.gd` | ui_copy_0 | ui_copy |
| `altar_service.gd` | identify_all_returns | garden_returns |
| `altar_service.gd` | identify_returns | garden_returns |
| `altar_service.gd` | identify_ancient_returns | garden_returns |
| `altar_service.gd` | restore_returns | garden_returns |
| `altar_service.gd` | capture_returns | garden_returns |
| `altar_service.gd` | garden_offering_plan | garden_costs |
| `content_validator.gd` | ct01_whole_xp_1 | classes, characters, loot, persistence_operations |
| `content_validator.gd` | plant_affinity_validation | plant_affinities |
| `content_validator.gd` | cb06_0 | enemy_balance |
| `content_validator.gd` | new_subclass_validation | warden_progression |
| `content_validator.gd` | subclass_card_requirement | warden_progression |
| `content_validator.gd` | subclass_tree | warden_progression |
| `content_validator.gd` | validate_warden_checkpoint_cards | warden_progression |
| `content_validator.gd` | validate_warden_skill_modes | warden_progression |
| `content_validator.gd` | validate_warden_parents | warden_progression |
| `content_validator.gd` | validate_warden_node_effects | warden_progression |
| `content_validator.gd` | validate_warden_node_capacity | warden_progression |
| `content_validator.gd` | core_checkpoint_validation | core_combat |
| `content_validator.gd` | core_rules | core_combat |
| `content_validator.gd` | garden_catalog | garden_observations |
| `garden_visuals.gd` | meadow_paths_and_flowers | garden_life |
| `garden_visuals.gd` | accents_growth | garden_cinematics |
| `garden_visuals.gd` | accents_adapter | garden_zones, garden_life |
| `garden_visuals.gd` | observation_anchors | garden_observations |
| `stage.gd` | experimental_seed_rewards_1 | hex_terrain, loot, terrain |
| `stage.gd` | experimental_terrain_1 | hex_terrain, terrain, garden, persistence_operations |
| `stage.gd` | experimental_terrain_3 | hex_terrain, terrain, garden, persistence_operations |
| `stage.gd` | experimental_terrain_5 | hex_terrain, terrain, garden, persistence_operations |
| `stage.gd` | experimental_terrain_7 | hex_terrain, terrain, garden, persistence_operations |
| `stage.gd` | experimental_terrain_9 | hex_terrain, terrain, garden, persistence_operations |
| `stage.gd` | experimental_terrain_11 | hex_terrain, terrain, garden, persistence_operations |
| `stage.gd` | experimental_terrain_13 | hex_terrain, terrain, garden, persistence_operations |
| `stage.gd` | experimental_terrain_15 | hex_terrain, terrain, garden, persistence_operations |
| `stage.gd` | experimental_terrain_17 | hex_terrain, terrain, garden, persistence_operations |
| `stage.gd` | experimental_terrain_19 | hex_terrain, terrain, garden, persistence_operations |
| `stage.gd` | experimental_terrain_21 | hex_terrain, terrain, garden, persistence_operations |
| `stage.gd` | experimental_terrain_23 | hex_terrain, terrain, garden, persistence_operations |
| `stage.gd` | experimental_terrain_25 | hex_terrain, terrain, garden, persistence_operations |
| `stage.gd` | experimental_terrain_27 | hex_terrain, terrain, garden, persistence_operations |
| `stage.gd` | experimental_terrain_29 | hex_terrain, terrain, garden, persistence_operations |
| `stage.gd` | experimental_terrain_31 | hex_terrain, terrain, garden, persistence_operations |
| `stage.gd` | experimental_terrain_33 | hex_terrain, terrain, garden, persistence_operations |
| `stage.gd` | experimental_terrain_35 | hex_terrain, terrain, garden, persistence_operations |
| `stage.gd` | experimental_crop_soil_height | hex_terrain, terrain, garden |
| `stage.gd` | preview_fallen_caption | combat_balance_preview |
| `stage.gd` | snap_glasscap_swap | glasscap_feints |
| `stage.gd` | local_ranged_direction | ranged_release |
| `stage.gd` | host_ranged_direction | ranged_release |
| `stage.gd` | gait_facing | avatar_motion_view |
| `stage.gd` | gait_velocity_hint | avatar_motion_view |
| `stage.gd` | field_secondary_weapon_tree | avatar_motion_view |
| `stage.gd` | field_primary_weapon_tree | avatar_motion_view |
| `stage.gd` | field_aim_yaw | avatar_motion_view |
| `stage.gd` | field_travel_sample | avatar_motion_view |
| `stage.gd` | garden_stone_banks | garden_life |
| `stage.gd` | garden_undergrowth | garden_life |
| `stage.gd` | garden_root_bark | garden_life |
| `stage.gd` | garden_meadow | garden_life |
| `stage.gd` | garden_floor_tint | garden_life |
| `stage.gd` | garden_floor_type | garden_life |
| `stage.gd` | garden_scenery_import | garden_life |
| `stage.gd` | subclass_host_pose | warden_progression |
| `stage.gd` | canopy_shift_windup_pose | enemy_move_feedback |
| `stage.gd` | suppress_duplicate_enemy_ring | enemy_move_feedback |
| `stage.gd` | guest_core_aim | core_combat |
| `stage.gd` | nest_rib_models | boss_phase_fights |
| `stage.gd` | rendered_lair_key | boss_phase_fights |
| `stage.gd` | phase_actor_target | boss_phase_fights |
| `stage.gd` | phase_actor_pose | boss_phase_fights |
| `stage.gd` | lair_boss_pose | boss_lair_fights |
| `stage.gd` | lair_warning_ring | boss_lair_fights |
| `stage.gd` | heavy_support | enemy_attack_plan |
| `stage.gd` | species_variants_2 | enemy_attack_plan |
| `stage.gd` | species_variants_1 | enemy_attack_plan |
| `stage.gd` | species_variants_0 | enemy_attack_plan |
| `stage.gd` | enemy_attack_plan_2 | enemy_attack_plan |
| `stage.gd` | enemy_attack_plan_1 | enemy_attack_plan |
| `stage.gd` | enemy_attack_plan_0 | enemy_attack_plan |
| `stage.gd` | heart_growth_sync | heart_growth_visual |
| `stage.gd` | forest_extent | terrain |
| `stage.gd` | terrain_diagnostics | terrain |
| `stage.gd` | update_garden_growth | garden_cinematics |
| `stage.gd` | build_garden_pond_growth | garden_cinematics |
| `stage.gd` | update_plots_growth | garden_cinematics |
| `stage.gd` | build_garden_plot_growth | garden_cinematics |
| `stage.gd` | update_heart_progress_growth | garden_cinematics |
| `stage.gd` | garden_growth_growth | garden_cinematics |
| `stage.gd` | focus_growth | garden_cinematics |
| `stage.gd` | update_garden_adapter | garden_zones |
| `stage.gd` | build_garden_pond_adapter | garden_life, garden_zones |
| `stage.gd` | build_garden_life_adapter | garden_zones, garden_life |
| `stage.gd` | garden_pond_positions_adapter | garden_zones |
| `app_settings.gd` | guarded_lifecycle_1 | persistence_operations, connection_flow, menus, settings |
| `app_settings.gd` | guarded_lifecycle_2 | persistence_operations, connection_flow, menus, settings |
| `app_settings.gd` | first_launch_volume | soundscape |
| `app_settings.gd` | run_summary_action | expedition_summary |
| `app_settings.gd` | run_summary_default | expedition_summary |
| `app_settings.gd` | run_summary_key_migration | expedition_summary |
| `app_settings.gd` | soundscape_buses | soundscape |
| `app_settings.gd` | soundscape_normalize | soundscape |
| `app_settings.gd` | soundscape_defaults | soundscape |
| `app_settings.gd` | developer_preference_load | developer_garden |
| `app_settings.gd` | developer_preference_default | developer_garden |
| `app_settings.gd` | core_legacy_binding | core_combat |
| `app_settings.gd` | core_default | core_combat |
| `app_settings.gd` | core_label | core_combat |
| `app_settings.gd` | normalize_growth | garden_cinematics |
| `app_settings.gd` | defaults_growth | garden_cinematics |
| `app_settings.gd` | garden_motion_load | garden_life |
| `app_settings.gd` | garden_motion_default | garden_life |
| `settings_panel.gd` | display_hint_field | menu_layout, menus |
| `settings_panel.gd` | display_hint_label | menu_layout, menus |
| `settings_panel.gd` | display_hint_refresh | menu_layout, menus |
| `settings_panel.gd` | scrollable_settings_pages | menu_layout |
| `settings_panel.gd` | settings_fit_viewport | menu_layout |
| `settings_panel.gd` | responsive_slider_width | menu_layout |
| `settings_panel.gd` | sound_effects_label | event_audio |
| `settings_panel.gd` | soundscape_slider_save | soundscape |
| `settings_panel.gd` | soundscape_slider_load | soundscape |
| `settings_panel.gd` | soundscape_sliders | soundscape |
| `settings_panel.gd` | soundscape_slider_refs | soundscape |
| `settings_panel.gd` | developer_panel_save | developer_garden |
| `settings_panel.gd` | developer_panel_refresh | developer_garden |
| `settings_panel.gd` | developer_panel_mount | developer_garden |
| `settings_panel.gd` | developer_context | developer_garden |
| `settings_panel.gd` | settings_layout | menu_layout |
| `settings_panel.gd` | settings_button_roots | menu_layout |
| `settings_panel.gd` | save_growth | garden_cinematics |
| `settings_panel.gd` | refresh_growth | garden_cinematics |
| `settings_panel.gd` | _ready_growth | garden_cinematics |
| `settings_panel.gd` | garden_motion_save | garden_life |
| `settings_panel.gd` | garden_motion_refresh | garden_life |
| `settings_panel.gd` | garden_motion_create | garden_life |
| `garden_interaction_service.gd` | experimental_research_landmarks_1 | hex_terrain, garden, garden_observations |
| `garden_interaction_service.gd` | experimental_research_landmarks_2 | hex_terrain, garden, garden_observations |
| `garden_interaction_service.gd` | experimental_terrain_1 | hex_terrain, terrain, garden, persistence_operations |
| `garden_interaction_service.gd` | experimental_terrain_3 | hex_terrain, terrain, garden, persistence_operations |
| `garden_interaction_service.gd` | experimental_terrain_5 | hex_terrain, terrain, garden, persistence_operations |
| `garden_interaction_service.gd` | experimental_terrain_7 | hex_terrain, terrain, garden, persistence_operations |
| `garden_interaction_service.gd` | experimental_terrain_9 | hex_terrain, terrain, garden, persistence_operations |
| `garden_interaction_service.gd` | cleanup_feedback_1 | persistence_operations |
| `garden_interaction_service.gd` | cleanup_feedback_2 | persistence_operations |
| `garden_interaction_service.gd` | guarded_gameplay_writer_1 | persistence_operations |
| `garden_interaction_service.gd` | guarded_gameplay_writer_2 | persistence_operations |
| `garden_interaction_service.gd` | command_g07 | garden_conduit |
| `garden_interaction_service.gd` | projection_g07 | garden_conduit |
| `garden_interaction_service.gd` | projection_returns | garden_returns |
| `garden_interaction_service.gd` | command_crop_care | garden_care |
| `garden_interaction_service.gd` | projection_crop_care | garden_care |
| `garden_interaction_service.gd` | projection_growth | garden_cinematics |
| `garden_interaction_service.gd` | stations_focus | garden_stations |
| `garden_interaction_view.gd` | experimental_research_landmarks_1 | hex_terrain, garden, garden_observations |
| `garden_interaction_view.gd` | station_controls_fields | garden_stations |
| `garden_interaction_view.gd` | stations__ready | garden_stations |
| `garden_interaction_view.gd` | stations__process | garden_stations |
| `garden_interaction_view.gd` | stations_update_prompt | garden_stations |
| `garden_interaction_view.gd` | _ready_g07 | garden_conduit |
| `garden_interaction_view.gd` | _process_returns | garden_returns |
| `garden_interaction_view.gd` | _ready_returns | garden_returns |
| `garden_interaction_view.gd` | update_prompt_crop_care | garden_care |
| `garden_interaction_view.gd` | _ready_crop_care | garden_care |
| `garden_interaction_view.gd` | _ready_growth | garden_cinematics |
| `garden_ambience.gd` | experimental_research_landmarks_1 | hex_terrain, garden, garden_life |
| `garden_ambience.gd` | experimental_research_landmarks_2 | hex_terrain, garden, garden_life |
| `garden_ambience.gd` | heart_motion | heart_growth_visual |
| `garden_ambience.gd` | nested_visuals | garden_zones, garden_life |
| `garden_ambience.gd` | _process_returns | garden_returns |
| `garden_ambience.gd` | _process_growth | garden_cinematics |
| `seed_catalog.gd` | cb03_seed_heal_hp | weapon_balance |
| `seed_catalog.gd` | cb03_seed_damage_hp | weapon_balance |
| `seed_catalog.gd` | ui_copy_0 | ui_copy |
| `seed_catalog.gd` | tier_growth_values | cultivation_growth |
| `network_compatibility.gd` | cr02_begin_check | combat_affinity_contracts |
| `network_compatibility.gd` | cr02_receive_compatibility | combat_affinity_contracts |
| `network_compatibility.gd` | experimental_coop_1 | hex_terrain, terrain, connection_flow, garden |
| `network_compatibility.gd` | experimental_coop_2 | hex_terrain, terrain, connection_flow, garden |
| `network_compatibility.gd` | experimental_coop_3 | hex_terrain, terrain, connection_flow, garden |
| `network_compatibility.gd` | experimental_coop_4 | hex_terrain, terrain, connection_flow, garden |
| `network_compatibility.gd` | cb02_network_compatibility_2_8 | combat_balance_preview |
| `network_compatibility.gd` | cb02_network_compatibility_1_7 | combat_balance_preview |
| `network_compatibility.gd` | connection_flow_stage | connection_flow |
| `network_compatibility.gd` | terrain_send | terrain, expeditions |
| `network_compatibility.gd` | terrain_receive | terrain, expeditions |
| `network_compatibility.gd` | receive_compatibility_returns | garden_returns |
| `network_compatibility.gd` | begin_check_returns | garden_returns |
| `network_compatibility.gd` | cultivation_auth_in | cultivation_growth |
| `network_compatibility.gd` | cultivation_auth_out | cultivation_growth |
| `planting_panel.gd` | ec01_playtest_1 | seeds, plant_affinities, ui_copy |
| `planting_panel.gd` | ec01_playtest_2 | seeds, plant_affinities, ui_copy |
| `planting_panel.gd` | ec01_playtest_3 | seeds, plant_affinities, ui_copy |
| `planting_panel.gd` | ec01_playtest_4 | seeds, plant_affinities, ui_copy |
| `planting_panel.gd` | cleanup_feedback_1 | persistence_operations |
| `planting_panel.gd` | ui_copy_3 | ui_copy |
| `planting_panel.gd` | ui_copy_2 | ui_copy |
| `planting_panel.gd` | ui_copy_1 | ui_copy |
| `planting_panel.gd` | ui_copy_0 | ui_copy |
| `planting_panel.gd` | tier_time_preview | cultivation_growth |
| `inventory_model.gd` | guarded_gameplay_writer_1 | persistence_operations |
| `inventory_model.gd` | bank_extra_returns | garden_returns |
| `inventory_model.gd` | bank_safe_returns | garden_returns |
| `garden_growth_state.gd` | prepare_returns | garden_returns |
| `garden_growth_view.gd` | experimental_terrain_1 | hex_terrain, terrain, garden, persistence_operations |
| `garden_growth_view.gd` | cleanup_feedback_1 | persistence_operations |
| `garden_growth_view.gd` | meadow_cinematic_bark | garden_life |
| `garden_growth_view.gd` | research_cue_without_scene | event_audio |
| `garden_growth_view.gd` | research_reveal_cue | event_audio |
| `garden_growth_view.gd` | heart_growth_adapter | heart_growth_visual |
| `garden_growth_view.gd` | conceal_g07 | garden_conduit, garden_cinematics |
| `garden_growth_view.gd` | destination_g07 | garden_conduit, garden_cinematics |
| `garden_growth_view.gd` | animate_returns | garden_returns |
| `garden_growth_view.gd` | destination_returns | garden_returns |
| `garden_layout.gd` | ponds_g07 | garden_zones, garden_conduit |
| `garden_layout.gd` | reserved_g07 | garden_zones, garden_conduit |
| `garden_growth_catalog.gd` | heart_counts | heart_growth_visual |
| `garden_growth_catalog.gd` | describe_g07 | garden_conduit, garden_cinematics |
| `garden_growth_service.gd` | guarded_lifecycle_1 | persistence_operations, connection_flow, menus, settings |
| `garden_growth_service.gd` | guarded_lifecycle_2 | persistence_operations, connection_flow, menus, settings |
| `garden_growth_service.gd` | cleanup_feedback_registration | persistence_operations |
| `garden_growth_service.gd` | cleanup_feedback_2 | persistence_operations |
| `garden_growth_service.gd` | cleanup_feedback_3 | persistence_operations |
| `garden_growth_service.gd` | guarded_gameplay_writer_1 | persistence_operations |
| `garden_growth_service.gd` | guarded_gameplay_writer_2 | persistence_operations |
| `garden_growth_service.gd` | guarded_gameplay_writer_3 | persistence_operations |
| `garden_growth_service.gd` | register_title_join | garden_cinematics, menus |
| `traveller_avatar.gd` | weapon_ready_during_action_only | avatar_motion_view |
| `traveller_avatar.gd` | field_rig_animation | avatar_motion_view |
| `traveller_avatar.gd` | field_rig_build | avatar_motion_view |
| `traveller_avatar.gd` | field_rig_swap | avatar_motion_view |
| `traveller_avatar.gd` | field_rig_import | avatar_motion_view |
| `traveller_avatar.gd` | subclass_clip | warden_progression |
| `traveller_avatar.gd` | character_overhaul | characters, presentation, avatar_motion_view |
| `weapon_visuals.gd` | censer_pendulum | avatar_motion_view, combat_readability |
| `weapon_visuals.gd` | botanical_weapon_dynamics | avatar_motion_view |
| `weapon_visuals.gd` | lash_segment_transform | avatar_motion_view |
| `weapon_visuals.gd` | botanical_weapon_anchors | avatar_motion_view |
| `weapon_visuals.gd` | botanical_weapon_build | avatar_motion_view |
| `weapon_visuals.gd` | botanical_weapon_catalog | avatar_motion_view |
| `weapon_visuals.gd` | nock_only_during_attack | avatar_motion_view |
| `weapon_visuals.gd` | plant_polearm_orientation | avatar_motion_view |
| `weapon_visuals.gd` | plant_polearm_ready_basis | avatar_motion_view |
| `weapon_visuals.gd` | plant_polearm_seed | avatar_motion_view |
| `weapon_visuals.gd` | plant_polearm_models | avatar_motion_view |
| `weapon_visuals.gd` | plant_polearm_catalog | avatar_motion_view |
| `weapon_visuals.gd` | field_second_hand | avatar_motion_view |
| `weapon_visuals.gd` | field_weapon_anchors | avatar_motion_view |
| `weapon_visuals.gd` | vine_bow_limb_geometry | avatar_motion_view |
| `weapon_visuals.gd` | vine_bow_mesh | avatar_motion_view |
| `weapon_visuals.gd` | rootblade_mesh | avatar_motion_view |
| `weapon_visuals.gd` | field_weapon_imports | avatar_motion_view |
| `weapon_visuals.gd` | crafted_ready_transition | avatar_motion_view |
| `weapon_visuals.gd` | character_overhaul | characters, presentation, avatar_motion_view |
| `assets/characters/rig_manifest.json` | character_overhaul | characters, presentation, avatar_motion_view |
| `character_creator.gd` | portrait_framing | characters, menus, presentation |
| `combat_effects.gd` | ct03_ranger_1 | presentation, ranger_progression |
| `combat_effects.gd` | ct03_ranger_2 | presentation, ranger_progression |
| `combat_effects.gd` | ct03_ranger_3 | presentation, ranger_progression |
| `combat_effects.gd` | cb07_0 | expedition_sustain |
| `combat_effects.gd` | orchard_fruit_palette | boss_lair_fights |
| `combat_effects.gd` | orchard_warning_label | boss_lair_fights |
| `combat_effects.gd` | orchard_warning_countdown | boss_lair_fights |
| `combat_effects.gd` | orchard_warning_geometry | boss_lair_fights |
| `combat_effects.gd` | omit_decoy_from_warnings | glasscap_feints |
| `combat_effects.gd` | remove_legacy_decoy | glasscap_feints |
| `combat_effects.gd` | centralized_combat_playback | event_audio |
| `combat_effects.gd` | centralized_voice_cleanup | event_audio |
| `combat_effects.gd` | skip_visual_audio | event_audio |
| `combat_effects.gd` | voice_budget_migration | event_audio |
| `combat_effects.gd` | shape_field_renderer | core_combat |
| `combat_effects.gd` | anchor_star_guide | core_combat |
| `combat_effects.gd` | core_phase_feedback | core_combat, combat_readability |
| `combat_effects.gd` | dream_lure_pursuit | core_combat |
| `combat_effects.gd` | blood_return | core_combat |
| `combat_effects.gd` | core_shape_animation | core_combat |
| `combat_effects.gd` | core_effects_renderer | core_combat |
| `combat_effects.gd` | wave_visibility | core_combat |
| `combat_effects.gd` | signature_release_shapes | core_combat, combat_readability |
| `combat_effects.gd` | individual_petal | combat_readability, ranged_release |
| `combat_effects.gd` | weapon_action_shapes | combat_readability, ranged_release |
| `combat_effects.gd` | draw_snare_roots | core_combat, ability_aim, combat_readability |
| `combat_effects.gd` | field_feedback | ability_aim, warden_progression, combat_readability |
| `combat_effects.gd` | thrown_plant_models | avatar_motion_view |
| `combat_effects.gd` | audio_has_own_player | event_audio |
| `combat_effects.gd` | subclass_release_text | warden_progression |
| `combat_effects.gd` | subclass_pose | warden_progression |
| `combat_effects.gd` | regular_hazard_palette | enemy_move_feedback |
| `combat_effects.gd` | destination_warning_labels | enemy_move_feedback |
| `combat_effects.gd` | regular_hazard_shapes | enemy_move_feedback |
| `combat_effects.gd` | regular_hazard_lookup | enemy_move_feedback |
| `combat_effects.gd` | confirmed_enemy_move_shapes | enemy_move_feedback |
| `combat_effects.gd` | confirmed_enemy_move_callouts | enemy_move_feedback |
| `combat_effects.gd` | enemy_move_effects_renderer | enemy_move_feedback |
| `combat_effects.gd` | expanded_core_field | core_combat |
| `combat_effects.gd` | core_star_marker | core_combat |
| `combat_effects.gd` | strike_mark_burst_visual | core_combat |
| `combat_effects.gd` | strike_mark_burst_label | core_combat |
| `combat_effects.gd` | core_footprint | core_combat |
| `combat_effects.gd` | growth_snapshot_skip | boss_phase_fights |
| `combat_effects.gd` | phase_warnings | boss_phase_fights |
| `combat_effects.gd` | boss_warnings | boss_lair_fights |
| `combat_effects.gd` | heavy_support | enemy_attack_plan |
| `combat_effects.gd` | species_variants_3 | enemy_attack_plan |
| `combat_effects.gd` | species_variants_2 | enemy_attack_plan |
| `combat_effects.gd` | species_variants_1 | enemy_attack_plan |
| `combat_effects.gd` | species_variants_0 | enemy_attack_plan |
| `combat_effects.gd` | enemy_attack_plan_1 | enemy_attack_plan |
| `combat_effects.gd` | enemy_attack_plan_0 | enemy_attack_plan |
| `combat_effects.gd` | reinforcement_warning | expedition_pressure |
| `battlefield.gd` | tc01_ranged_clearance_1 | terrain, combat, hex_terrain |
| `battlefield.gd` | tc01_ranged_clearance_2 | terrain, combat, hex_terrain |
| `battlefield.gd` | experimental_seed_rewards_1 | hex_terrain, loot, terrain |
| `battlefield.gd` | matriarch_layout | boss_phase_fights |
| `battlefield.gd` | finished_terrain | terrain, combat, enemies, expeditions, life, loot |
| `exploration.gd` | experimental_seed_rewards_1 | hex_terrain, loot, terrain |
| `exploration.gd` | health_pool_3 | health_pool_hud |
| `exploration.gd` | health_pool_2 | health_pool_hud |
| `exploration.gd` | health_pool_1 | health_pool_hud |
| `exploration.gd` | render_thief_route | thief_escape |
| `exploration.gd` | sync_tunnel_models | thief_escape |
| `exploration.gd` | hide_tunnels_in_garden | thief_escape |
| `exploration.gd` | thief_chart_state | thief_escape |
| `exploration.gd` | terrain_extent | terrain |
| `exploration.gd` | fog_bounds | terrain |
| `exploration.gd` | fog_coordinates | terrain |
| `exploration.gd` | fog_extent_input | terrain |
| `exploration.gd` | chart_extent | terrain |
| `heart_visuals.gd` | tree_attach | heart_growth_visual |
| `garden_crop_service.gd` | experimental_research_landmarks_1 | hex_terrain, garden, garden_care |
| `garden_crop_service.gd` | experimental_research_landmarks_2 | hex_terrain, garden, garden_care |
| `garden_crop_service.gd` | experimental_research_landmarks_3 | hex_terrain, garden, garden_care |
| `garden_crop_service.gd` | experimental_research_landmarks_4 | hex_terrain, garden, garden_care |
| `garden_crop_service.gd` | experimental_terrain_1 | hex_terrain, terrain, garden, persistence_operations |
| `garden_crop_service.gd` | experimental_terrain_3 | hex_terrain, terrain, garden, persistence_operations |
| `garden_crop_service.gd` | guarded_garden_actions_1 | persistence_operations, garden_care, seeds, items |
| `garden_crop_service.gd` | guarded_garden_actions_2 | persistence_operations, garden_care, seeds, items |
| `garden_crop_service.gd` | cleanup_feedback_1 | persistence_operations |
| `garden_crop_service.gd` | cleanup_feedback_2 | persistence_operations |
| `garden_crop_service.gd` | guarded_gameplay_writer_1 | persistence_operations |
| `garden_crop_service.gd` | guarded_gameplay_writer_2 | persistence_operations |
| `garden_crop_service.gd` | guarded_gameplay_writer_3 | persistence_operations |
| `garden_crop_service.gd` | guarded_gameplay_writer_4 | persistence_operations |
| `garden_crop_service.gd` | crop_water_cue | event_audio |
| `garden_crop_service.gd` | spring_vessel_cue | event_audio |
| `garden_crop_service.gd` | spring_water_pickup | garden_stations |
| `garden_crop_service.gd` | spring_water_projection | garden_stations |
| `garden_crop_service.gd` | spring_water_required | garden_stations |
| `garden_crop_service.gd` | spring_water_spent | garden_stations |
| `cultivation_growth.gd` | watering_compatibility | garden_stations |
| `garden_crop_view.gd` | experimental_terrain_1 | hex_terrain, terrain, garden, persistence_operations |
| `garden_crop_view.gd` | experimental_terrain_3 | hex_terrain, terrain, garden, persistence_operations |
| `garden_crop_view.gd` | experimental_terrain_5 | hex_terrain, terrain, garden, persistence_operations |
| `garden_crop_view.gd` | experimental_terrain_7 | hex_terrain, terrain, garden, persistence_operations |
| `garden_crop_view.gd` | experimental_terrain_9 | hex_terrain, terrain, garden, persistence_operations |
| `garden_crop_view.gd` | experimental_terrain_11 | hex_terrain, terrain, garden, persistence_operations |
| `garden_crop_view.gd` | ui_copy_2 | ui_copy |
| `garden_crop_view.gd` | ui_copy_1 | ui_copy |
| `garden_crop_view.gd` | ui_copy_0 | ui_copy |
| `garden_crop_view.gd` | water_button_field | garden_stations |
| `garden_crop_view.gd` | water_button_mount | garden_stations |
| `garden_crop_view.gd` | water_button_prompt | garden_stations |
| `garden_crop_view.gd` | water_button_projection | garden_stations |
| `inventory_panel.gd` | cb03_inventory_component_details | weapon_balance |
| `inventory_panel.gd` | core_equipment_details | core_combat |
| `inventory_panel.gd` | core_equipment_selection | core_combat |
| `inventory_panel.gd` | core_equipment_entries | core_combat |
| `inventory_panel.gd` | core_equipment_heading | core_combat |
| `inventory_panel.gd` | core_equipment_label | core_combat |
| `inventory_panel.gd` | ui_copy_4 | ui_copy |
| `inventory_panel.gd` | ui_copy_3 | ui_copy |
| `inventory_panel.gd` | ui_copy_2 | ui_copy |
| `inventory_panel.gd` | ui_copy_1 | ui_copy |
| `inventory_panel.gd` | ui_copy_0 | ui_copy |
| `garden_altar_panel.gd` | ui_copy_3 | ui_copy |
| `garden_altar_panel.gd` | ui_copy_2 | ui_copy |
| `garden_altar_panel.gd` | ui_copy_1 | ui_copy |
| `garden_altar_panel.gd` | ui_copy_0 | ui_copy |
| `grafting_panel.gd` | ui_copy_2 | ui_copy |
| `grafting_panel.gd` | ui_copy_1 | ui_copy |
| `grafting_panel.gd` | ui_copy_0 | ui_copy |
| `loadout_panel.gd` | ec01_display_1 | class_tree_access, combat_affinity_contracts, weapons |
| `loadout_panel.gd` | ec01_playtest_1 | class_tree_access, combat_affinity_contracts, weapons |
| `loadout_panel.gd` | ec01_playtest_2 | class_tree_access, combat_affinity_contracts, weapons |
| `loadout_panel.gd` | ec01_playtest_3 | class_tree_access, combat_affinity_contracts, weapons |
| `loadout_panel.gd` | ec01_playtest_4 | class_tree_access, combat_affinity_contracts, weapons |
| `loadout_panel.gd` | ec01_playtest_5 | class_tree_access, combat_affinity_contracts, weapons |
| `loadout_panel.gd` | ec01_playtest_6 | class_tree_access, combat_affinity_contracts, weapons |
| `loadout_panel.gd` | ec01_playtest_7 | class_tree_access, combat_affinity_contracts, weapons |
| `loadout_panel.gd` | ec01_playtest_8 | class_tree_access, combat_affinity_contracts, weapons |
| `loadout_panel.gd` | ec01_playtest_9 | class_tree_access, combat_affinity_contracts, weapons |
| `loadout_panel.gd` | ec01_playtest_10 | class_tree_access, combat_affinity_contracts, weapons |
| `loadout_panel.gd` | ec01_playtest_11 | class_tree_access, combat_affinity_contracts, weapons |
| `loadout_panel.gd` | ec01_playtest_12 | class_tree_access, combat_affinity_contracts, weapons |
| `loadout_panel.gd` | ec01_playtest_13 | class_tree_access, combat_affinity_contracts, weapons |
| `loadout_panel.gd` | ec01_playtest_14 | class_tree_access, combat_affinity_contracts, weapons |
| `loadout_panel.gd` | ec01_playtest_15 | class_tree_access, combat_affinity_contracts, weapons |
| `loadout_panel.gd` | ec01_playtest_16 | class_tree_access, combat_affinity_contracts, weapons |
| `loadout_panel.gd` | starting_focus_preview_labels | class_tree_access, oracle_progression |
| `loadout_panel.gd` | starting_focus_preview_layout | class_tree_access, oracle_progression |
| `loadout_panel.gd` | starting_focus_preview_effects | class_tree_access, oracle_progression |
| `loadout_panel.gd` | starting_focus_preview_current_q | class_tree_access, oracle_progression |
| `loadout_panel.gd` | ct05_oracle_1 | oracle_progression, class_tree_access |
| `loadout_panel.gd` | ct05_oracle_2 | oracle_progression, class_tree_access |
| `loadout_panel.gd` | ct05_oracle_3 | oracle_progression, class_tree_access |
| `loadout_panel.gd` | ct05_oracle_4 | oracle_progression, class_tree_access |
| `loadout_panel.gd` | ct02_1 | weaver_progression, warden_progression, combat_affinity_contracts |
| `loadout_panel.gd` | ct01_1 | warden_progression, classes, combat_affinity_contracts |
| `loadout_panel.gd` | cr04a_affinity_1 | combat_affinity_contracts, fire_affinity |
| `loadout_panel.gd` | cr03_refresh | frost_affinity |
| `loadout_panel.gd` | cr02_refresh | combat_affinity_contracts |
| `loadout_panel.gd` | class_location_copy | class_tree_access |
| `loadout_panel.gd` | open_class_tree_from_crafting | class_tree_access |
| `loadout_panel.gd` | warden_points_in_loadout | warden_progression |
| `loadout_panel.gd` | core_weapon_variant_title | core_combat |
| `loadout_panel.gd` | bench_core_choice_hover | core_combat |
| `loadout_panel.gd` | bench_skill_hover_row | core_combat |
| `loadout_panel.gd` | bench_skill_hover_state | core_combat |
| `loadout_panel.gd` | core_preview | core_combat |
| `loadout_panel.gd` | ui_copy_11 | ui_copy |
| `loadout_panel.gd` | ui_copy_10 | ui_copy |
| `loadout_panel.gd` | ui_copy_9 | ui_copy |
| `loadout_panel.gd` | ui_copy_8 | ui_copy |
| `loadout_panel.gd` | ui_copy_7 | ui_copy |
| `loadout_panel.gd` | ui_copy_6 | ui_copy |
| `loadout_panel.gd` | ui_copy_5 | ui_copy |
| `loadout_panel.gd` | ui_copy_4 | ui_copy |
| `loadout_panel.gd` | ui_copy_3 | ui_copy |
| `loadout_panel.gd` | ui_copy_2 | ui_copy |
| `loadout_panel.gd` | ui_copy_1 | ui_copy |
| `loadout_panel.gd` | ui_copy_0 | ui_copy |
| `progression_panel.gd` | ec01_playtest_1 | progression, classes, class_tree_access |
| `progression_panel.gd` | ec01_playtest_2 | progression, classes, class_tree_access |
| `progression_panel.gd` | ct04_reaper_1 | progression, reaper_progression |
| `progression_panel.gd` | ct02_1 | weaver_progression, warden_progression, combat_affinity_contracts |
| `progression_panel.gd` | ct02_2 | weaver_progression, warden_progression, combat_affinity_contracts |
| `progression_panel.gd` | ct02_3 | weaver_progression, warden_progression, combat_affinity_contracts |
| `progression_panel.gd` | ct02_4 | weaver_progression, warden_progression, combat_affinity_contracts |
| `progression_panel.gd` | ct02_5 | weaver_progression, warden_progression, combat_affinity_contracts |
| `progression_panel.gd` | ct02_6 | weaver_progression, warden_progression, combat_affinity_contracts |
| `progression_panel.gd` | ct02_7 | weaver_progression, warden_progression, combat_affinity_contracts |
| `progression_panel.gd` | ct01_whole_xp_1 | classes, progression, warden_progression |
| `progression_panel.gd` | ct01_whole_xp_2 | classes, progression, warden_progression |
| `progression_panel.gd` | ct01_whole_xp_3 | classes, progression, warden_progression |
| `progression_panel.gd` | ct01_1 | warden_progression, classes, combat_affinity_contracts |
| `progression_panel.gd` | ct01_2 | warden_progression, classes, combat_affinity_contracts |
| `progression_panel.gd` | ct01_3 | warden_progression, classes, combat_affinity_contracts |
| `progression_panel.gd` | ct01_4 | warden_progression, classes, combat_affinity_contracts |
| `progression_panel.gd` | ct01_5 | warden_progression, classes, combat_affinity_contracts |
| `progression_panel.gd` | ct01_6 | warden_progression, classes, combat_affinity_contracts |
| `progression_panel.gd` | cr05_effective_preview_1 | classes, combat_affinity_contracts |
| `progression_panel.gd` | cr05_progression_1 | classes, life, combat_affinity_contracts |
| `progression_panel.gd` | cr05_progression_2 | classes, life, combat_affinity_contracts |
| `progression_panel.gd` | experimental_terrain_1 | hex_terrain, terrain, garden, persistence_operations |
| `progression_panel.gd` | cb04_0 | class_balance |
| `progression_panel.gd` | cb04_1 | class_balance |
| `progression_panel.gd` | cb04_2 | class_balance |
| `progression_panel.gd` | cb04_3 | class_balance |
| `progression_panel.gd` | refund_station_tooltip | class_tree_access |
| `progression_panel.gd` | class_details_placeholder | class_tree_access |
| `progression_panel.gd` | shared_tree_base_scroll | class_tree_access |
| `progression_panel.gd` | scroll_classes_to_base | class_tree_access |
| `progression_panel.gd` | clear_highlight_on_class_tab_switch | class_tree_access |
| `progression_panel.gd` | subclass_learn_hint | class_tree_access |
| `progression_panel.gd` | class_learn_hint | class_tree_access |
| `progression_panel.gd` | hide_retired_seed_actions | class_tree_access |
| `progression_panel.gd` | stable_learn_button | class_tree_access |
| `progression_panel.gd` | stable_progression_rows | class_tree_access |
| `progression_panel.gd` | open_class_tree_page | class_tree_access |
| `progression_panel.gd` | class_page_return | class_tree_access |
| `progression_panel.gd` | crafting_navigation_state | class_tree_access |
| `progression_panel.gd` | subclass_nodes | warden_progression |
| `progression_panel.gd` | subclass_node_entry | warden_progression |
| `progression_panel.gd` | subclass_notice | warden_progression |
| `progression_panel.gd` | subclass_refund | warden_progression |
| `progression_panel.gd` | warden_three_lane_projection | warden_progression |
| `progression_panel.gd` | warden_tree_projection | warden_progression |
| `progression_panel.gd` | warden_class_notice | warden_progression |
| `progression_panel.gd` | warden_legacy_refund_label | warden_progression |
| `progression_panel.gd` | ui_copy_8 | ui_copy |
| `progression_panel.gd` | ui_copy_7 | ui_copy |
| `progression_panel.gd` | ui_copy_6 | ui_copy |
| `progression_panel.gd` | ui_copy_5 | ui_copy |
| `progression_panel.gd` | ui_copy_4 | ui_copy |
| `progression_panel.gd` | ui_copy_3 | ui_copy |
| `progression_panel.gd` | ui_copy_2 | ui_copy |
| `progression_panel.gd` | ui_copy_1 | ui_copy |
| `progression_panel.gd` | ui_copy_0 | ui_copy |
| `garden_story_panel.gd` | ui_copy_1 | ui_copy |
| `garden_story_panel.gd` | ui_copy_0 | ui_copy |
| `garden_terrace_view.gd` | ui_copy_0 | ui_copy |
| `heart_catalog.gd` | ui_copy_17 | ui_copy |
| `heart_catalog.gd` | ui_copy_16 | ui_copy |
| `heart_catalog.gd` | ui_copy_15 | ui_copy |
| `heart_catalog.gd` | ui_copy_14 | ui_copy |
| `heart_catalog.gd` | ui_copy_13 | ui_copy |
| `heart_catalog.gd` | ui_copy_12 | ui_copy |
| `heart_catalog.gd` | ui_copy_11 | ui_copy |
| `heart_catalog.gd` | ui_copy_10 | ui_copy |
| `heart_catalog.gd` | ui_copy_9 | ui_copy |
| `heart_catalog.gd` | ui_copy_8 | ui_copy |
| `heart_catalog.gd` | ui_copy_7 | ui_copy |
| `heart_catalog.gd` | ui_copy_6 | ui_copy |
| `heart_catalog.gd` | ui_copy_5 | ui_copy |
| `heart_catalog.gd` | ui_copy_4 | ui_copy |
| `heart_catalog.gd` | ui_copy_3 | ui_copy |
| `heart_catalog.gd` | ui_copy_2 | ui_copy |
| `heart_catalog.gd` | ui_copy_1 | ui_copy |
| `heart_catalog.gd` | ui_copy_0 | ui_copy |
| `class_catalog.gd` | ct05_oracle_1 | oracle_progression, class_tree_access |
| `class_catalog.gd` | ct05_oracle_2 | oracle_progression, class_tree_access |
| `class_catalog.gd` | ct04_reaper_1 | classes, reaper_progression |
| `class_catalog.gd` | ct04_reaper_2 | classes, reaper_progression |
| `class_catalog.gd` | ct03_ranger_1 | classes, ranger_progression |
| `class_catalog.gd` | ct03_ranger_2 | classes, ranger_progression |
| `class_catalog.gd` | ct02_1 | weaver_progression, warden_progression, combat_affinity_contracts |
| `class_catalog.gd` | ct02_2 | weaver_progression, warden_progression, combat_affinity_contracts |
| `class_catalog.gd` | cb04_0 | class_balance |
| `class_catalog.gd` | cb04_1 | class_balance |
| `class_catalog.gd` | weapon_roll_4_2 | weapon_balance |
| `class_catalog.gd` | weapon_roll_4_1 | weapon_balance |
| `class_catalog.gd` | weapon_roll_4_0 | weapon_balance |
| `class_catalog.gd` | weapon_roll_3_2 | weapon_balance |
| `class_catalog.gd` | weapon_roll_3_1 | weapon_balance |
| `class_catalog.gd` | weapon_roll_3_0 | weapon_balance |
| `class_catalog.gd` | weapon_roll_2_2 | weapon_balance |
| `class_catalog.gd` | weapon_roll_2_1 | weapon_balance |
| `class_catalog.gd` | weapon_roll_2_0 | weapon_balance |
| `class_catalog.gd` | weapon_roll_1_2 | weapon_balance |
| `class_catalog.gd` | weapon_roll_1_1 | weapon_balance |
| `class_catalog.gd` | weapon_roll_1_0 | weapon_balance |
| `class_catalog.gd` | weapon_roll_0_2 | weapon_balance |
| `class_catalog.gd` | weapon_roll_0_1 | weapon_balance |
| `class_catalog.gd` | weapon_roll_0_0 | weapon_balance |
| `class_catalog.gd` | ground_snare_description_1 | classes, ability_aim, ui_copy |
| `class_catalog.gd` | ground_snare_description_0 | classes, ability_aim, ui_copy |
| `class_catalog.gd` | bramble_snare_radius | classes, ability_aim |
| `class_catalog.gd` | censer_attack_pattern | combat_readability, ranged_release, weapons |
| `class_catalog.gd` | warden_choice_routing | warden_progression |
| `class_catalog.gd` | warden_tree_access | warden_progression |
| `class_catalog.gd` | ui_copy_4 | ui_copy |
| `class_catalog.gd` | ui_copy_3 | ui_copy |
| `class_catalog.gd` | ui_copy_2 | ui_copy |
| `class_catalog.gd` | ui_copy_1 | ui_copy |
| `class_catalog.gd` | ui_copy_0 | ui_copy |
| `skill_catalog.gd` | ct04_reaper_1 | classes, reaper_progression |
| `skill_catalog.gd` | ct04_reaper_2 | classes, reaper_progression |
| `skill_catalog.gd` | ct04_reaper_3 | classes, reaper_progression |
| `skill_catalog.gd` | ct04_reaper_4 | classes, reaper_progression |
| `skill_catalog.gd` | ct03_ranger_1 | classes, ranger_progression |
| `skill_catalog.gd` | ct03_ranger_2 | classes, ranger_progression |
| `skill_catalog.gd` | ct02_1 | weaver_progression, warden_progression, combat_affinity_contracts |
| `skill_catalog.gd` | ct02_2 | weaver_progression, warden_progression, combat_affinity_contracts |
| `skill_catalog.gd` | ct02_3 | weaver_progression, warden_progression, combat_affinity_contracts |
| `skill_catalog.gd` | ct02_4 | weaver_progression, warden_progression, combat_affinity_contracts |
| `skill_catalog.gd` | ct02_5 | weaver_progression, warden_progression, combat_affinity_contracts |
| `skill_catalog.gd` | ct02_6 | weaver_progression, warden_progression, combat_affinity_contracts |
| `skill_catalog.gd` | ct01_1 | warden_progression, classes, combat_affinity_contracts |
| `skill_catalog.gd` | ct01_2 | warden_progression, classes, combat_affinity_contracts |
| `skill_catalog.gd` | ct01_3 | warden_progression, classes, combat_affinity_contracts |
| `skill_catalog.gd` | cr05_focus_1 | classes, combat_affinity_contracts |
| `skill_catalog.gd` | cr05_focus_2 | classes, combat_affinity_contracts |
| `skill_catalog.gd` | cb07_0 | expedition_sustain |
| `skill_catalog.gd` | healing_roll_0 | healing_rolls |
| `skill_catalog.gd` | healing_roll_1 | healing_rolls |
| `skill_catalog.gd` | healing_roll_2 | healing_rolls |
| `skill_catalog.gd` | healing_roll_3 | healing_rolls |
| `skill_catalog.gd` | healing_roll_4 | healing_rolls |
| `skill_catalog.gd` | cb04_resolved_tooltips | class_balance |
| `skill_catalog.gd` | cb04_3 | class_balance |
| `skill_catalog.gd` | cb04_4 | class_balance |
| `skill_catalog.gd` | cb04_5 | class_balance |
| `skill_catalog.gd` | subclass_resolve | warden_progression |
| `skill_catalog.gd` | resolve_warden_subclass_skill | warden_progression |
| `skill_catalog.gd` | ui_copy_1 | ui_copy |
| `skill_catalog.gd` | ui_copy_0 | ui_copy |
| `run_upgrade_catalog.gd` | ec01_1 | affinity_cards |
| `run_upgrade_catalog.gd` | cr02_requirement | combat_affinity_contracts |
| `run_upgrade_catalog.gd` | cr02_effects | combat_affinity_contracts |
| `run_upgrade_catalog.gd` | cr02_core_cards | combat_affinity_contracts |
| `run_upgrade_catalog.gd` | cr02_pool | combat_affinity_contracts |
| `run_upgrade_catalog.gd` | cb05_0 | core_balance |
| `run_upgrade_catalog.gd` | cb05_1 | core_balance |
| `run_upgrade_catalog.gd` | cb05_2 | core_balance |
| `run_upgrade_catalog.gd` | cb05_3 | core_balance |
| `run_upgrade_catalog.gd` | subclass_source | warden_progression |
| `run_upgrade_catalog.gd` | subclass_filter | warden_progression |
| `run_upgrade_catalog.gd` | subclass_cards | warden_progression |
| `run_upgrade_catalog.gd` | warden_checkpoint_card_source | warden_progression |
| `run_upgrade_catalog.gd` | warden_checkpoint_offer_mix | warden_progression |
| `run_upgrade_catalog.gd` | warden_card_pool_types | warden_progression |
| `run_upgrade_catalog.gd` | warden_card_requirements | warden_progression |
| `run_upgrade_catalog.gd` | warden_checkpoint_catalog | warden_progression |
| `run_upgrade_catalog.gd` | expanded_core_cards_catalog | core_combat |
| `run_upgrade_catalog.gd` | expanded_core_pool | core_combat |
| `run_upgrade_catalog.gd` | expanded_core_cards_lookup | core_combat |
| `run_upgrade_catalog.gd` | expanded_core_behavior_guard | core_combat |
| `run_upgrade_catalog.gd` | expanded_core_tune | core_combat |
| `run_upgrade_catalog.gd` | expanded_core_card_validation | core_combat |
| `run_upgrade_catalog.gd` | core_card_validation | core_combat |
| `run_upgrade_catalog.gd` | core_card_text | core_combat |
| `run_upgrade_catalog.gd` | core_card_affordability | core_combat |
| `run_upgrade_catalog.gd` | core_card_pool | core_combat |
| `run_upgrade_catalog.gd` | core_card_weights | core_combat |
| `run_upgrade_catalog.gd` | core_card_requirements | core_combat |
| `run_upgrade_catalog.gd` | core_card_context | core_combat |
| `run_upgrade_catalog.gd` | core_card_catalog | core_combat |
| `run_upgrade_catalog.gd` | ui_copy_0 | ui_copy |
| `assets/upgrades/checkpoint_upgrades.json` | core_checkpoint_cards | core_combat |
| `assets/upgrades/checkpoint_upgrades.json` | ui_copy_106 | ui_copy |
| `assets/upgrades/checkpoint_upgrades.json` | ui_copy_105 | ui_copy |
| `assets/upgrades/checkpoint_upgrades.json` | ui_copy_104 | ui_copy |
| `assets/upgrades/checkpoint_upgrades.json` | ui_copy_103 | ui_copy |
| `assets/upgrades/checkpoint_upgrades.json` | ui_copy_102 | ui_copy |
| `assets/upgrades/checkpoint_upgrades.json` | ui_copy_101 | ui_copy |
| `assets/upgrades/checkpoint_upgrades.json` | ui_copy_100 | ui_copy |
| `assets/upgrades/checkpoint_upgrades.json` | ui_copy_99 | ui_copy |
| `assets/upgrades/checkpoint_upgrades.json` | ui_copy_98 | ui_copy |
| `assets/upgrades/checkpoint_upgrades.json` | ui_copy_97 | ui_copy |
| `assets/upgrades/checkpoint_upgrades.json` | ui_copy_96 | ui_copy |
| `assets/upgrades/checkpoint_upgrades.json` | ui_copy_95 | ui_copy |
| `assets/upgrades/checkpoint_upgrades.json` | ui_copy_94 | ui_copy |
| `assets/upgrades/checkpoint_upgrades.json` | ui_copy_93 | ui_copy |
| `assets/upgrades/checkpoint_upgrades.json` | ui_copy_92 | ui_copy |
| `assets/upgrades/checkpoint_upgrades.json` | ui_copy_91 | ui_copy |
| `assets/upgrades/checkpoint_upgrades.json` | ui_copy_90 | ui_copy |
| `assets/upgrades/checkpoint_upgrades.json` | ui_copy_89 | ui_copy |
| `assets/upgrades/checkpoint_upgrades.json` | ui_copy_88 | ui_copy |
| `assets/upgrades/checkpoint_upgrades.json` | ui_copy_87 | ui_copy |
| `assets/upgrades/checkpoint_upgrades.json` | ui_copy_86 | ui_copy |
| `assets/upgrades/checkpoint_upgrades.json` | ui_copy_85 | ui_copy |
| `assets/upgrades/checkpoint_upgrades.json` | ui_copy_84 | ui_copy |
| `assets/upgrades/checkpoint_upgrades.json` | ui_copy_83 | ui_copy |
| `assets/upgrades/checkpoint_upgrades.json` | ui_copy_82 | ui_copy |
| `assets/upgrades/checkpoint_upgrades.json` | ui_copy_81 | ui_copy |
| `assets/upgrades/checkpoint_upgrades.json` | ui_copy_80 | ui_copy |
| `assets/upgrades/checkpoint_upgrades.json` | ui_copy_79 | ui_copy |
| `assets/upgrades/checkpoint_upgrades.json` | ui_copy_78 | ui_copy |
| `assets/upgrades/checkpoint_upgrades.json` | ui_copy_77 | ui_copy |
| `assets/upgrades/checkpoint_upgrades.json` | ui_copy_76 | ui_copy |
| `assets/upgrades/checkpoint_upgrades.json` | ui_copy_75 | ui_copy |
| `assets/upgrades/checkpoint_upgrades.json` | ui_copy_74 | ui_copy |
| `assets/upgrades/checkpoint_upgrades.json` | ui_copy_73 | ui_copy |
| `assets/upgrades/checkpoint_upgrades.json` | ui_copy_72 | ui_copy |
| `assets/upgrades/checkpoint_upgrades.json` | ui_copy_71 | ui_copy |
| `assets/upgrades/checkpoint_upgrades.json` | ui_copy_70 | ui_copy |
| `assets/upgrades/checkpoint_upgrades.json` | ui_copy_69 | ui_copy |
| `assets/upgrades/checkpoint_upgrades.json` | ui_copy_68 | ui_copy |
| `assets/upgrades/checkpoint_upgrades.json` | ui_copy_67 | ui_copy |
| `assets/upgrades/checkpoint_upgrades.json` | ui_copy_66 | ui_copy |
| `assets/upgrades/checkpoint_upgrades.json` | ui_copy_65 | ui_copy |
| `assets/upgrades/checkpoint_upgrades.json` | ui_copy_64 | ui_copy |
| `assets/upgrades/checkpoint_upgrades.json` | ui_copy_63 | ui_copy |
| `assets/upgrades/checkpoint_upgrades.json` | ui_copy_62 | ui_copy |
| `assets/upgrades/checkpoint_upgrades.json` | ui_copy_61 | ui_copy |
| `assets/upgrades/checkpoint_upgrades.json` | ui_copy_60 | ui_copy |
| `assets/upgrades/checkpoint_upgrades.json` | ui_copy_59 | ui_copy |
| `assets/upgrades/checkpoint_upgrades.json` | ui_copy_58 | ui_copy |
| `assets/upgrades/checkpoint_upgrades.json` | ui_copy_57 | ui_copy |
| `assets/upgrades/checkpoint_upgrades.json` | ui_copy_56 | ui_copy |
| `assets/upgrades/checkpoint_upgrades.json` | ui_copy_55 | ui_copy |
| `assets/upgrades/checkpoint_upgrades.json` | ui_copy_54 | ui_copy |
| `assets/upgrades/checkpoint_upgrades.json` | ui_copy_53 | ui_copy |
| `assets/upgrades/checkpoint_upgrades.json` | ui_copy_52 | ui_copy |
| `assets/upgrades/checkpoint_upgrades.json` | ui_copy_51 | ui_copy |
| `assets/upgrades/checkpoint_upgrades.json` | ui_copy_50 | ui_copy |
| `assets/upgrades/checkpoint_upgrades.json` | ui_copy_49 | ui_copy |
| `assets/upgrades/checkpoint_upgrades.json` | ui_copy_48 | ui_copy |
| `assets/upgrades/checkpoint_upgrades.json` | ui_copy_47 | ui_copy |
| `assets/upgrades/checkpoint_upgrades.json` | ui_copy_46 | ui_copy |
| `assets/upgrades/checkpoint_upgrades.json` | ui_copy_45 | ui_copy |
| `assets/upgrades/checkpoint_upgrades.json` | ui_copy_44 | ui_copy |
| `assets/upgrades/checkpoint_upgrades.json` | ui_copy_43 | ui_copy |
| `assets/upgrades/checkpoint_upgrades.json` | ui_copy_42 | ui_copy |
| `assets/upgrades/checkpoint_upgrades.json` | ui_copy_41 | ui_copy |
| `assets/upgrades/checkpoint_upgrades.json` | ui_copy_40 | ui_copy |
| `assets/upgrades/checkpoint_upgrades.json` | ui_copy_39 | ui_copy |
| `assets/upgrades/checkpoint_upgrades.json` | ui_copy_38 | ui_copy |
| `assets/upgrades/checkpoint_upgrades.json` | ui_copy_37 | ui_copy |
| `assets/upgrades/checkpoint_upgrades.json` | ui_copy_36 | ui_copy |
| `assets/upgrades/checkpoint_upgrades.json` | ui_copy_35 | ui_copy |
| `assets/upgrades/checkpoint_upgrades.json` | ui_copy_34 | ui_copy |
| `assets/upgrades/checkpoint_upgrades.json` | ui_copy_33 | ui_copy |
| `assets/upgrades/checkpoint_upgrades.json` | ui_copy_32 | ui_copy |
| `assets/upgrades/checkpoint_upgrades.json` | ui_copy_31 | ui_copy |
| `assets/upgrades/checkpoint_upgrades.json` | ui_copy_30 | ui_copy |
| `assets/upgrades/checkpoint_upgrades.json` | ui_copy_29 | ui_copy |
| `assets/upgrades/checkpoint_upgrades.json` | ui_copy_28 | ui_copy |
| `assets/upgrades/checkpoint_upgrades.json` | ui_copy_27 | ui_copy |
| `assets/upgrades/checkpoint_upgrades.json` | ui_copy_26 | ui_copy |
| `assets/upgrades/checkpoint_upgrades.json` | ui_copy_25 | ui_copy |
| `assets/upgrades/checkpoint_upgrades.json` | ui_copy_24 | ui_copy |
| `assets/upgrades/checkpoint_upgrades.json` | ui_copy_23 | ui_copy |
| `assets/upgrades/checkpoint_upgrades.json` | ui_copy_22 | ui_copy |
| `assets/upgrades/checkpoint_upgrades.json` | ui_copy_21 | ui_copy |
| `assets/upgrades/checkpoint_upgrades.json` | ui_copy_20 | ui_copy |
| `assets/upgrades/checkpoint_upgrades.json` | ui_copy_19 | ui_copy |
| `assets/upgrades/checkpoint_upgrades.json` | ui_copy_18 | ui_copy |
| `assets/upgrades/checkpoint_upgrades.json` | ui_copy_17 | ui_copy |
| `assets/upgrades/checkpoint_upgrades.json` | ui_copy_16 | ui_copy |
| `assets/upgrades/checkpoint_upgrades.json` | ui_copy_15 | ui_copy |
| `assets/upgrades/checkpoint_upgrades.json` | ui_copy_14 | ui_copy |
| `assets/upgrades/checkpoint_upgrades.json` | ui_copy_13 | ui_copy |
| `assets/upgrades/checkpoint_upgrades.json` | ui_copy_12 | ui_copy |
| `assets/upgrades/checkpoint_upgrades.json` | ui_copy_11 | ui_copy |
| `assets/upgrades/checkpoint_upgrades.json` | ui_copy_10 | ui_copy |
| `assets/upgrades/checkpoint_upgrades.json` | ui_copy_9 | ui_copy |
| `assets/upgrades/checkpoint_upgrades.json` | ui_copy_8 | ui_copy |
| `assets/upgrades/checkpoint_upgrades.json` | ui_copy_7 | ui_copy |
| `assets/upgrades/checkpoint_upgrades.json` | ui_copy_6 | ui_copy |
| `assets/upgrades/checkpoint_upgrades.json` | ui_copy_5 | ui_copy |
| `assets/upgrades/checkpoint_upgrades.json` | ui_copy_4 | ui_copy |
| `assets/upgrades/checkpoint_upgrades.json` | ui_copy_3 | ui_copy |
| `assets/upgrades/checkpoint_upgrades.json` | ui_copy_2 | ui_copy |
| `assets/upgrades/checkpoint_upgrades.json` | ui_copy_1 | ui_copy |
| `assets/upgrades/checkpoint_upgrades.json` | ui_copy_0 | ui_copy |
| `assets/enemies/catalog.json` | cb06_0 | enemy_balance |
| `assets/enemies/catalog.json` | cb06_1 | enemy_balance |
| `assets/enemies/catalog.json` | cb06_2 | enemy_balance |
| `assets/enemies/catalog.json` | cb06_3 | enemy_balance |
| `assets/enemies/catalog.json` | cb06_4 | enemy_balance |
| `assets/enemies/catalog.json` | cb06_5 | enemy_balance |
| `assets/enemies/catalog.json` | cb06_6 | enemy_balance |
| `assets/enemies/catalog.json` | cb06_7 | enemy_balance |
| `assets/enemies/catalog.json` | cb06_8 | enemy_balance |
| `assets/enemies/catalog.json` | cb06_9 | enemy_balance |
| `assets/enemies/catalog.json` | cb06_10 | enemy_balance |
| `assets/enemies/catalog.json` | cb06_11 | enemy_balance |
| `assets/enemies/catalog.json` | cb06_12 | enemy_balance |
| `assets/enemies/catalog.json` | cb06_13 | enemy_balance |
| `assets/enemies/catalog.json` | cb06_14 | enemy_balance |
| `assets/enemies/catalog.json` | cb06_15 | enemy_balance |
| `assets/enemies/catalog.json` | cb06_16 | enemy_balance |
| `assets/enemies/catalog.json` | cb06_17 | enemy_balance |
| `assets/enemies/catalog.json` | cb06_18 | enemy_balance |
| `assets/enemies/catalog.json` | cb06_19 | enemy_balance |
| `assets/enemies/catalog.json` | cb06_20 | enemy_balance |
| `assets/enemies/catalog.json` | cb06_21 | enemy_balance |
| `assets/enemies/catalog.json` | cb06_22 | enemy_balance |
| `assets/enemies/catalog.json` | cb06_23 | enemy_balance |
| `assets/enemies/catalog.json` | species_variants_1 | enemy_attack_plan |
| `assets/enemies/catalog.json` | species_variants_0 | enemy_attack_plan |
| `assets/enemies/catalog.json` | enemy_attack_plan_0 | enemy_attack_plan |
| `assets/enemies/catalog.json` | choir_copy | enemy_attack_plan |
| `elite_enemy.gd` | tc01_ranged_clearance_1 | enemies, enemy_attack_plan, hex_terrain |
| `elite_enemy.gd` | tc01_ranged_clearance_2 | enemies, enemy_attack_plan, hex_terrain |
| `elite_enemy.gd` | cr04c_spirit_1 | spirit_affinity, core_combat, combat_affinity_contracts |
| `elite_enemy.gd` | cr03_tick | frost_affinity |
| `elite_enemy.gd` | cr03_resolve | frost_affinity |
| `elite_enemy.gd` | cb06_0 | enemy_balance |
| `elite_enemy.gd` | glasscap_elite_recovery | glasscap_feints |
| `elite_enemy.gd` | flee_before_targeting | thief_escape |
| `elite_enemy.gd` | gate_elite_learned_approach | wilds_skill_tactics |
| `elite_enemy.gd` | thorn_vault_elite_root | thorn_adaptation |
| `elite_enemy.gd` | preserve_thorn_vault_lock | thorn_adaptation |
| `elite_enemy.gd` | thorn_vault_approach | thorn_adaptation |
| `elite_enemy.gd` | signatures_0 | enemy_attack_plan, encounter_composition |
| `elite_enemy.gd` | signatures_1 | enemy_attack_plan, encounter_composition |
| `elite_enemy.gd` | signatures_2 | enemy_attack_plan, encounter_composition |
| `elite_enemy.gd` | signatures_3 | enemy_attack_plan, encounter_composition |
| `elite_enemy.gd` | signatures_4 | enemy_attack_plan, encounter_composition |
| `elite_enemy.gd` | species_variants_4 | enemy_attack_plan |
| `elite_enemy.gd` | species_variants_3 | enemy_attack_plan |
| `elite_enemy.gd` | species_variants_2 | enemy_attack_plan |
| `elite_enemy.gd` | species_variants_1 | enemy_attack_plan |
| `elite_enemy.gd` | species_variants_0 | enemy_attack_plan |
| `elite_enemy.gd` | enemy_attack_plan_4 | enemy_attack_plan |
| `elite_enemy.gd` | enemy_attack_plan_3 | enemy_attack_plan |
| `elite_enemy.gd` | enemy_attack_plan_2 | enemy_attack_plan |
| `elite_enemy.gd` | enemy_attack_plan_1 | enemy_attack_plan |
| `elite_enemy.gd` | enemy_attack_plan_0 | enemy_attack_plan |
| `elite_enemy.gd` | signatures_resolve_repeat | enemy_attack_plan, encounter_composition |
| `enemy_behaviors.gd` | ct05_oracle_1 | oracle_progression |
| `enemy_behaviors.gd` | tc01_ranged_clearance_1 | enemies, enemy_attack_plan, hex_terrain |
| `enemy_behaviors.gd` | cb06_0 | enemy_balance |
| `enemy_behaviors.gd` | cb06_1 | enemy_balance |
| `enemy_behaviors.gd` | glasscap_crossfire_release | glasscap_feints |
| `enemy_behaviors.gd` | glasscap_cast_formation | glasscap_feints |
| `enemy_behaviors.gd` | glasscap_recovery | glasscap_feints |
| `enemy_behaviors.gd` | glasscap_service | glasscap_feints |
| `enemy_behaviors.gd` | spore_release | event_audio |
| `enemy_behaviors.gd` | root_release | event_audio |
| `enemy_behaviors.gd` | web_release | event_audio |
| `enemy_behaviors.gd` | crossfire_release | event_audio |
| `enemy_behaviors.gd` | clear_thief_route | thief_escape |
| `enemy_behaviors.gd` | start_thief_route | thief_escape |
| `enemy_behaviors.gd` | thief_flee | thief_escape |
| `enemy_behaviors.gd` | thief_escape_service | thief_escape |
| `enemy_behaviors.gd` | resolved_trophy_grab | enemy_move_feedback |
| `enemy_behaviors.gd` | resolved_forked_roots | enemy_move_feedback |
| `enemy_behaviors.gd` | resolved_glass_crossfire | enemy_move_feedback |
| `enemy_behaviors.gd` | enemy_behavior_cues | enemy_move_feedback |
| `enemy_behaviors.gd` | thief_learned_grab_candidate | wilds_skill_tactics |
| `enemy_behaviors.gd` | resolve_learned_grab | wilds_skill_tactics |
| `enemy_behaviors.gd` | resolve_learned_canopy_and_glass | wilds_skill_tactics |
| `enemy_behaviors.gd` | thief_learned_grab_range | wilds_skill_tactics |
| `enemy_behaviors.gd` | dispatch_echo_toll | wilds_skill_tactics |
| `enemy_behaviors.gd` | allow_learned_spare_tether | wilds_skill_tactics |
| `enemy_behaviors.gd` | stagger_rite_evidence | wilds_skill_tactics |
| `enemy_behaviors.gd` | species_variants_1 | enemy_attack_plan |
| `enemy_behaviors.gd` | species_variants_0 | enemy_attack_plan |
| `enemy_behaviors.gd` | enemy_attack_plan_1 | enemy_attack_plan |
| `enemy_behaviors.gd` | enemy_attack_plan_0 | enemy_attack_plan |
| `wilds_learning.gd` | route_and_shelter_memory | wilds_skill_tactics |
| `wilds_learning.gd` | core_skill_tactics | wilds_skill_tactics |
| `wilds_learning.gd` | thorn_learning_key | thorn_adaptation |
| `wilds_learning.gd` | enemy_attack_plan_1 | enemy_attack_plan |
| `wilds_learning.gd` | enemy_attack_plan_0 | enemy_attack_plan |
| `combat_status.gd` | ct05_oracle_1 | oracle_progression |
| `combat_status.gd` | ct05_oracle_2 | oracle_progression |
| `combat_status.gd` | ct05_oracle_3 | oracle_progression |
| `combat_status.gd` | ct05_oracle_4 | oracle_progression |
| `combat_status.gd` | ct04_reaper_1 | combat, reaper_progression |
| `combat_status.gd` | ct04_reaper_2 | combat, reaper_progression |
| `combat_status.gd` | ct03_ranger_1 | combat, ranger_progression |
| `combat_status.gd` | ct03_ranger_2 | combat, ranger_progression |
| `combat_status.gd` | ct03_ranger_3 | combat, ranger_progression |
| `combat_status.gd` | ct03_ranger_4 | combat, ranger_progression |
| `combat_status.gd` | ct02_1 | weaver_progression, warden_progression, combat_affinity_contracts |
| `combat_status.gd` | ct02_2 | weaver_progression, warden_progression, combat_affinity_contracts |
| `combat_status.gd` | ct01_holdfast_1 | warden_progression, combat, life |
| `combat_status.gd` | ct01_holdfast_2 | warden_progression, combat, life |
| `combat_status.gd` | cr05_grafts_1 | combat_affinity_contracts, weapons, classes, life |
| `combat_status.gd` | cr04c_void_1 | void_affinity, core_combat, combat_affinity_contracts |
| `combat_status.gd` | cr04c_spirit_1 | spirit_affinity, core_combat, combat_affinity_contracts |
| `combat_status.gd` | cr04c_spirit_2 | spirit_affinity, core_combat, combat_affinity_contracts |
| `combat_status.gd` | cr04c_storm_1 | storm_affinity, core_combat, combat_affinity_contracts |
| `combat_status.gd` | cr04c_storm_2 | storm_affinity, core_combat, combat_affinity_contracts |
| `combat_status.gd` | cr04b_wood_1 | wood_affinity, combat_affinity_contracts |
| `combat_status.gd` | cr04b_wood_2 | wood_affinity, combat_affinity_contracts |
| `combat_status.gd` | cr04b_thorn_1 | thorn_affinity, combat_affinity_contracts |
| `combat_status.gd` | cr04b_thorn_2 | thorn_affinity, combat_affinity_contracts |
| `combat_status.gd` | cr04a_affinity_1 | fire_affinity, water_affinity, vital_affinity, combat_affinity_contracts |
| `combat_status.gd` | cr04a_affinity_2 | fire_affinity, water_affinity, vital_affinity, combat_affinity_contracts |
| `combat_status.gd` | cr04a_affinity_3 | fire_affinity, water_affinity, vital_affinity, combat_affinity_contracts |
| `combat_status.gd` | cr04a_affinity_4 | fire_affinity, water_affinity, vital_affinity, combat_affinity_contracts |
| `combat_status.gd` | cr04a_affinity_5 | fire_affinity, water_affinity, vital_affinity, combat_affinity_contracts |
| `combat_status.gd` | cr03_sync | frost_affinity |
| `combat_status.gd` | subclass_follow_status_lifetime | warden_progression |
| `combat_status.gd` | subclass_mark_status | warden_progression |
| `combat_status.gd` | subclass_prepared_status | warden_progression |
| `combat_status.gd` | subclass_prepared_label | warden_progression |
| `combat_status.gd` | warden_prepared_status_snapshot | warden_progression |
| `combat_status.gd` | warden_prepared_status_name | warden_progression |
| `combat_status.gd` | observe_route_denial | wilds_skill_tactics |
| `combat_status.gd` | expanded_core_link_status | core_combat |
| `combat_status.gd` | expanded_core_link_label | core_combat |
| `combat_status.gd` | strike_mark_tint | core_combat |
| `combat_status.gd` | strike_mark_label | core_combat |
| `combat_status.gd` | strike_mark_status | core_combat |
| `combat_status.gd` | core_root_primitive | core_combat |
| `combat_status.gd` | phase_exposure | boss_phase_fights |
| `combat_status.gd` | boss_exposure | boss_lair_fights |
| `combat_status.gd` | heavy_support | enemy_attack_plan |
| `combat_status.gd` | species_variants_1 | enemy_attack_plan |
| `combat_status.gd` | species_variants_0 | enemy_attack_plan |
| `boss_encounters.gd` | ct05_oracle_1 | oracle_progression |
| `boss_encounters.gd` | ct01_1 | warden_progression, classes, combat_affinity_contracts |
| `boss_encounters.gd` | cr03_tick | frost_affinity |
| `boss_encounters.gd` | cb06_0 | enemy_balance |
| `boss_encounters.gd` | cb06_1 | enemy_balance |
| `boss_encounters.gd` | cb06_2 | enemy_balance |
| `boss_encounters.gd` | cb06_3 | enemy_balance |
| `boss_encounters.gd` | cb02_boss_encounters_1_17 | combat_balance_preview |
| `boss_encounters.gd` | vitals_boss_phase | combat_vitals |
| `boss_encounters.gd` | orchard_active_fruit | boss_lair_fights |
| `boss_encounters.gd` | orchard_range_and_rotation | boss_lair_fights |
| `boss_encounters.gd` | orchard_timing | boss_lair_fights |
| `boss_encounters.gd` | orchard_move_set | boss_lair_fights |
| `boss_encounters.gd` | regular_hazard_identity | enemy_move_feedback |
| `boss_encounters.gd` | phase_boss_4 | boss_phase_fights |
| `boss_encounters.gd` | phase_boss_3 | boss_phase_fights |
| `boss_encounters.gd` | phase_boss_2 | boss_phase_fights |
| `boss_encounters.gd` | phase_boss_1 | boss_phase_fights |
| `boss_encounters.gd` | phase_boss_0 | boss_phase_fights |
| `boss_encounters.gd` | lair_fights_5 | boss_lair_fights |
| `boss_encounters.gd` | lair_fights_4 | boss_lair_fights |
| `boss_encounters.gd` | lair_fights_3 | boss_lair_fights |
| `boss_encounters.gd` | lair_fights_2 | boss_lair_fights |
| `boss_encounters.gd` | lair_fights_1 | boss_lair_fights |
| `boss_encounters.gd` | lair_fights_0 | boss_lair_fights |
| `boss_lair_visuals.gd` | orchard_fruit_warning | boss_lair_fights |
| `boss_lair_visuals.gd` | orchard_cage_warning | boss_lair_fights |
| `boss_lair_visuals.gd` | orchard_cage_pose | boss_lair_fights |
| `boss_lair_visuals.gd` | orchard_root_shapes | boss_lair_fights |
| `boss_lair_visuals.gd` | nursery_models | boss_phase_fights |
| `boss_lair_visuals.gd` | seeded_lair_visuals | boss_lair_fights |
| `assets/shaders/lair_water.gdshader` | lair_phase_water | boss_lair_fights |
| `enemy_attack.gd` | ct05_oracle_1 | oracle_progression |
| `enemy_attack.gd` | tc01_ranged_clearance_1 | enemy_attack_plan, combat, hex_terrain |
| `enemy_attack.gd` | committed_windup | event_audio |
| `enemy_attack.gd` | learned_route_validation | wilds_skill_tactics |
| `enemy_attack.gd` | regular_route_warnings | wilds_skill_tactics |
| `enemy_attack.gd` | learned_charge_first_leg | wilds_skill_tactics |
| `enemy_attack.gd` | regular_response_lock | wilds_skill_tactics |
| `enemy_attack.gd` | skill_response_planner | wilds_skill_tactics |
| `enemy_attack.gd` | learned_rite_hint_tether | wilds_skill_tactics |
| `enemy_attack.gd` | learned_rite_hint_center | wilds_skill_tactics |
| `enemy_attack.gd` | lock_learned_skill_response | wilds_skill_tactics |
| `enemy_attack.gd` | thorn_vault_landing | thorn_adaptation |
| `enemy_attack.gd` | thorn_vault_lock | thorn_adaptation |
| `enemy_attack.gd` | memory_growth_pose | boss_phase_fights |
| `weapon_system.gd` | ec01_display_1 | weapons, ui_copy |
| `weapon_system.gd` | ec01_display_2 | weapons, ui_copy |
| `weapon_system.gd` | cb07_0 | expedition_sustain |
| `weapon_system.gd` | healing_roll_0 | healing_rolls |
| `weapon_system.gd` | healing_roll_1 | healing_rolls |
| `weapon_system.gd` | cb03_weapon_hp_cap | weapon_balance |
| `weapon_system.gd` | cb03_weapon_skill_heal_cap | weapon_balance |
| `weapon_system.gd` | cb03_weapon_kill_heal_cap | weapon_balance |
| `weapon_system.gd` | cb03_apply_component_keys | weapon_balance |
| `weapon_system.gd` | cb03_resolved_component_keys | weapon_balance |
| `weapon_system.gd` | cb03_display_maximum_hp | weapon_balance |
| `weapon_system.gd` | cb03_display_effect_hp | weapon_balance |
| `weapon_system.gd` | cb03_weapon_vital_caps | weapon_balance |
| `weapon_system.gd` | cb03_windup_precision | weapon_balance |
| `weapon_system.gd` | cb03_component_effect_fields | weapon_balance |
| `weapon_system.gd` | cb03_balance_service | weapon_balance |
| `weapon_system.gd` | cb02_weapon_system_2_3 | combat_balance_preview |
| `weapon_system.gd` | cb02_weapon_system_1_2 | combat_balance_preview |
| `weapon_system.gd` | core_description | core_combat |
| `weapon_system.gd` | core_build | core_combat |
| `network_settings.gd` | compact_snapshot_protocol | world_snapshot, connection_flow |
| `network_settings.gd` | guest_projection | persistence_operations, connection_flow, characters, expeditions, garden |
| `network_settings.gd` | guarded_lifecycle_1 | persistence_operations, connection_flow, menus, settings |
| `network_settings.gd` | cb07_0 | expedition_sustain, connection_flow |
| `network_settings.gd` | cb06_0 | enemy_balance, connection_flow |
| `network_settings.gd` | healing_roll_0 | healing_rolls, connection_flow |
| `network_settings.gd` | cb05_0 | core_balance, connection_flow |
| `network_settings.gd` | cb04_0 | class_balance, connection_flow |
| `network_settings.gd` | cb03_weapon_balance_protocol | weapon_balance, connection_flow |
| `network_settings.gd` | cb02_network_settings_1_9 | combat_balance_preview, connection_flow |
| `network_settings.gd` | orchard_warning_protocol | boss_lair_fights, connection_flow |
| `network_settings.gd` | glasscap_formation_protocol | glasscap_feints, connection_flow |
| `network_settings.gd` | combat_aim_protocol | connection_flow, core_combat |
| `network_settings.gd` | event_audio_protocol | event_audio |
| `network_settings.gd` | connection_flow_settings | connection_flow |
| `network_settings.gd` | positional_core_protocol | core_combat |
| `network_settings.gd` | expanded_core_protocol | core_combat |
| `network_settings.gd` | ability_aim_protocol | ability_aim |
| `network_settings.gd` | core_protocol | core_combat |
| `status_feedback.gd` | status_application_visible_age | enemy_move_feedback |
| `status_feedback.gd` | await_status_actor_snapshot | enemy_move_feedback |
| `status_feedback.gd` | strike_mark_shape | core_combat |
| `mouse_combat.gd` | ct04_reaper_1 | combat, reaper_progression |
| `mouse_combat.gd` | ct03_ranger_1 | combat, ranger_progression |
| `mouse_combat.gd` | ct03_ranger_2 | combat, ranger_progression |
| `mouse_combat.gd` | tc01_ranged_clearance_1 | combat, ranged_release, ability_aim, hex_terrain |
| `mouse_combat.gd` | tc01_ranged_clearance_2 | combat, ranged_release, ability_aim, hex_terrain |
| `mouse_combat.gd` | tc01_ranged_clearance_3 | combat, ranged_release, ability_aim, hex_terrain |
| `mouse_combat.gd` | tc01_ranged_clearance_4 | combat, ranged_release, ability_aim, hex_terrain |
| `mouse_combat.gd` | tc01_ranged_clearance_5 | combat, ranged_release, ability_aim, hex_terrain |
| `mouse_combat.gd` | tc01_ranged_clearance_6 | combat, ranged_release, ability_aim, hex_terrain |
| `mouse_combat.gd` | tc01_ranged_clearance_7 | combat, ranged_release, ability_aim, hex_terrain |
| `mouse_combat.gd` | tc01_ranged_clearance_8 | combat, ranged_release, ability_aim, hex_terrain |
| `mouse_combat.gd` | cr04b_thorn_1 | thorn_affinity, combat_affinity_contracts |
| `mouse_combat.gd` | cr03_ray_tick | frost_affinity |
| `mouse_combat.gd` | cr02_ray_tick | combat_affinity_contracts |
| `mouse_combat.gd` | guarded_lifecycle_1 | persistence_operations, connection_flow, menus, settings |
| `mouse_combat.gd` | resolve_petal_hit | ranged_release, combat_readability |
| `mouse_combat.gd` | send_cursor_magnitude | ranged_release, core_combat |
| `mouse_combat.gd` | read_cursor_magnitude | ranged_release, core_combat |
| `mouse_combat.gd` | weapon_volley | ranged_release, combat_readability, ability_aim |
| `mouse_combat.gd` | ranged_launch | ranged_release |
| `mouse_combat.gd` | track_windup_cursor | ranged_release |
| `mouse_combat.gd` | clear_release_aim | ranged_release |
| `mouse_combat.gd` | send_cursor_on_input_release | ranged_release |
| `mouse_combat.gd` | capture_local_cursor | ranged_release, core_combat |
| `mouse_combat.gd` | local_release_aim | ranged_release |
| `mouse_combat.gd` | attack_uses_projectile_path | ability_aim |
| `mouse_combat.gd` | shared_aim_projectile_path | ability_aim |
| `mouse_combat.gd` | core_cursor_distance | core_combat |
| `core_combat.gd` | tc01_ranged_clearance_1 | core_combat, combat, ability_aim, hex_terrain |
| `core_combat.gd` | cr04c_void_1 | void_affinity, core_combat, combat_affinity_contracts |
| `core_combat.gd` | cr04c_void_2 | void_affinity, core_combat, combat_affinity_contracts |
| `core_combat.gd` | cr04c_void_3 | void_affinity, core_combat, combat_affinity_contracts |
| `core_combat.gd` | cr04c_spirit_1 | spirit_affinity, core_combat, combat_affinity_contracts |
| `core_combat.gd` | cr04c_spirit_2 | spirit_affinity, core_combat, combat_affinity_contracts |
| `core_combat.gd` | cr04c_spirit_3 | spirit_affinity, core_combat, combat_affinity_contracts |
| `core_combat.gd` | cr04c_spirit_4 | spirit_affinity, core_combat, combat_affinity_contracts |
| `core_combat.gd` | cr04c_spirit_5 | spirit_affinity, core_combat, combat_affinity_contracts |
| `core_combat.gd` | cr04c_storm_1 | storm_affinity, core_combat, combat_affinity_contracts |
| `core_combat.gd` | cr04c_storm_2 | storm_affinity, core_combat, combat_affinity_contracts |
| `core_combat.gd` | cr04b_wood_1 | wood_affinity, combat_affinity_contracts |
| `core_combat.gd` | cr04b_wood_2 | wood_affinity, combat_affinity_contracts |
| `core_combat.gd` | cr04b_thorn_1 | thorn_affinity, combat_affinity_contracts |
| `core_combat.gd` | cr04a_affinity_1 | fire_affinity, water_affinity, vital_affinity, frost_affinity, combat_affinity_contracts |
| `core_combat.gd` | cr04a_affinity_2 | fire_affinity, water_affinity, vital_affinity, frost_affinity, combat_affinity_contracts |
| `core_combat.gd` | cr04a_affinity_3 | fire_affinity, water_affinity, vital_affinity, frost_affinity, combat_affinity_contracts |
| `core_combat.gd` | cr04a_affinity_4 | fire_affinity, water_affinity, vital_affinity, frost_affinity, combat_affinity_contracts |
| `core_combat.gd` | cr04a_affinity_5 | fire_affinity, water_affinity, vital_affinity, frost_affinity, combat_affinity_contracts |
| `core_combat.gd` | cr04a_affinity_6 | fire_affinity, water_affinity, vital_affinity, frost_affinity, combat_affinity_contracts |
| `core_combat.gd` | cr04a_affinity_7 | fire_affinity, water_affinity, vital_affinity, frost_affinity, combat_affinity_contracts |
| `core_combat.gd` | cr04a_affinity_8 | fire_affinity, water_affinity, vital_affinity, frost_affinity, combat_affinity_contracts |
| `core_combat.gd` | cr04a_affinity_9 | fire_affinity, water_affinity, vital_affinity, frost_affinity, combat_affinity_contracts |
| `core_combat.gd` | cr04a_affinity_10 | fire_affinity, water_affinity, vital_affinity, frost_affinity, combat_affinity_contracts |
| `core_combat.gd` | cr04a_affinity_11 | fire_affinity, water_affinity, vital_affinity, frost_affinity, combat_affinity_contracts |
| `core_combat.gd` | cr04a_affinity_12 | fire_affinity, water_affinity, vital_affinity, frost_affinity, combat_affinity_contracts |
| `core_combat.gd` | cr03_command | frost_affinity |
| `core_combat.gd` | cr03_equipped | frost_affinity |
| `core_combat.gd` | cr03_owner_state | frost_affinity |
| `core_combat.gd` | cr03_hud_state | frost_affinity |
| `core_combat.gd` | cr03_preview | frost_affinity |
| `core_combat.gd` | cr03_tick | frost_affinity |
| `core_combat.gd` | cr02_command | combat_affinity_contracts |
| `core_combat.gd` | cr02_equipped | combat_affinity_contracts |
| `core_combat.gd` | cr02_hud_state | combat_affinity_contracts |
| `core_combat.gd` | cb05_0 | core_balance |
| `core_combat.gd` | cb05_1 | core_balance |
| `core_combat.gd` | core_commit_audio | event_audio |
| `core_combat.gd` | ground_shape_contract | core_combat |
| `core_combat.gd` | warden_confirmed_quake_trip_event | warden_progression |
| `core_combat.gd` | record_thorn_success | thorn_adaptation |
| `core_combat.gd` | record_thorn_opportunity | thorn_adaptation |
| `core_combat.gd` | thorn_learning_dependency | thorn_adaptation |
| `combat_traits.gd` | ct04_reaper_1 | classes, reaper_progression |
| `combat_traits.gd` | ct04_reaper_2 | classes, reaper_progression |
| `combat_traits.gd` | ct04_reaper_3 | classes, reaper_progression |
| `combat_traits.gd` | ct03_ranger_1 | classes, ranger_progression |
| `combat_traits.gd` | ct03_ranger_2 | classes, ranger_progression |
| `combat_traits.gd` | ct03_ranger_3 | classes, ranger_progression |
| `combat_traits.gd` | ct03_ranger_4 | classes, ranger_progression |
| `combat_traits.gd` | ct03_ranger_5 | classes, ranger_progression |
| `combat_traits.gd` | ct03_ranger_6 | classes, ranger_progression |
| `combat_traits.gd` | ct03_ranger_7 | classes, ranger_progression |
| `combat_traits.gd` | ct02_1 | weaver_progression, warden_progression, combat_affinity_contracts |
| `combat_traits.gd` | ct02_2 | weaver_progression, warden_progression, combat_affinity_contracts |
| `combat_traits.gd` | ct02_3 | weaver_progression, warden_progression, combat_affinity_contracts |
| `combat_traits.gd` | ct02_4 | weaver_progression, warden_progression, combat_affinity_contracts |
| `combat_traits.gd` | cr05_shared_grave_1 | combat_affinity_contracts, weapons, classes, life |
| `combat_traits.gd` | cr05_shared_grave_2 | combat_affinity_contracts, weapons, classes, life |
| `combat_traits.gd` | cr05_shared_grave_3 | combat_affinity_contracts, weapons, classes, life |
| `combat_traits.gd` | cr05_grafts_1 | combat_affinity_contracts, weapons, classes, life |
| `combat_traits.gd` | cr05_grafts_2 | combat_affinity_contracts, weapons, classes, life |
| `combat_traits.gd` | cr05_grafts_3 | combat_affinity_contracts, weapons, classes, life |
| `combat_traits.gd` | cr05_grafts_4 | combat_affinity_contracts, weapons, classes, life |
| `combat_traits.gd` | cr05_grafts_5 | combat_affinity_contracts, weapons, classes, life |
| `combat_traits.gd` | cr05_grafts_6 | combat_affinity_contracts, weapons, classes, life |
| `combat_traits.gd` | cr05_grafts_7 | combat_affinity_contracts, weapons, classes, life |
| `combat_traits.gd` | cr05_grafts_8 | combat_affinity_contracts, weapons, classes, life |
| `combat_traits.gd` | cr04b_thorn_1 | thorn_affinity, combat_affinity_contracts |
| `combat_traits.gd` | cr04a_affinity_1 | vital_affinity, combat_affinity_contracts |
| `combat_traits.gd` | cr04a_affinity_2 | vital_affinity, combat_affinity_contracts |
| `combat_traits.gd` | cr04a_affinity_3 | vital_affinity, combat_affinity_contracts |
| `combat_traits.gd` | cr04a_affinity_4 | vital_affinity, combat_affinity_contracts |
| `combat_traits.gd` | cr03_augment_hit | frost_affinity |
| `combat_traits.gd` | cr02_trip_snare | combat_affinity_contracts |
| `combat_traits.gd` | cr02_tick | combat_affinity_contracts |
| `combat_traits.gd` | cr02_defer_skill | combat_affinity_contracts |
| `combat_traits.gd` | cb07_0 | expedition_sustain |
| `combat_traits.gd` | cb07_1 | expedition_sustain |
| `combat_traits.gd` | cb07_2 | expedition_sustain |
| `combat_traits.gd` | healing_roll_0 | healing_rolls |
| `combat_traits.gd` | healing_roll_1 | healing_rolls |
| `combat_traits.gd` | healing_roll_2 | healing_rolls |
| `combat_traits.gd` | healing_roll_3 | healing_rolls |
| `combat_traits.gd` | healing_roll_4 | healing_rolls |
| `combat_traits.gd` | healing_roll_5 | healing_rolls |
| `combat_traits.gd` | cb04_0 | class_balance |
| `combat_traits.gd` | cb04_1 | class_balance |
| `combat_traits.gd` | cb04_2 | class_balance |
| `combat_traits.gd` | cb04_3 | class_balance |
| `combat_traits.gd` | cb04_4 | class_balance |
| `combat_traits.gd` | cb04_5 | class_balance |
| `combat_traits.gd` | cb03_uncapped_shatter | weapon_balance |
| `combat_traits.gd` | cb03_counter_potency | weapon_balance |
| `combat_traits.gd` | cb03_trait_hp_tooltip | weapon_balance |
| `combat_traits.gd` | cb03_field_damage | weapon_balance |
| `combat_traits.gd` | cb03_field_healing | weapon_balance |
| `combat_traits.gd` | cb03_pool_potency | weapon_balance |
| `combat_traits.gd` | cb03_cinder_potency | weapon_balance |
| `combat_traits.gd` | cb03_chorus_potency | weapon_balance |
| `combat_traits.gd` | cb03_field_potency | weapon_balance |
| `combat_traits.gd` | cb03_secondary_hit_points | weapon_balance |
| `combat_traits.gd` | cb03_apply_trait_points | weapon_balance |
| `combat_traits.gd` | cb03_charge_bonus | weapon_balance |
| `combat_traits.gd` | cb03_brace_bonus | weapon_balance |
| `combat_traits.gd` | cb03_counter_bonus | weapon_balance |
| `combat_traits.gd` | cb03_mark_bonus | weapon_balance |
| `combat_traits.gd` | cb03_omen_bonus | weapon_balance |
| `combat_traits.gd` | cb03_shatter_bonus | weapon_balance |
| `combat_traits.gd` | cb03_trait_hit_points | weapon_balance |
| `combat_traits.gd` | cb03_trait_balance_service | weapon_balance |
| `combat_traits.gd` | cb02_combat_traits_1_7 | combat_balance_preview |
| `combat_traits.gd` | vitals_healing_pool | combat_vitals |
| `combat_traits.gd` | rime_shatter_bridge | core_combat |
| `combat_traits.gd` | tick_class_snare | classes, ability_aim, warden_progression |
| `combat_traits.gd` | class_snare_runtime | classes, ability_aim, warden_progression |
| `combat_traits.gd` | warden_confirmed_guard_event | warden_progression |
| `combat_traits.gd` | suppression_rite_evidence | wilds_skill_tactics |
| `combat_traits.gd` | expanded_core_decoy | core_combat |
| `core_skill_effects.gd` | cb07_0 | expedition_sustain |
| `core_skill_effects.gd` | cb07_1 | expedition_sustain |
| `core_skill_effects.gd` | cb07_2 | expedition_sustain |
| `core_skill_effects.gd` | cb07_3 | expedition_sustain |
| `core_skill_effects.gd` | healing_roll_0 | healing_rolls |
| `core_skill_effects.gd` | healing_roll_1 | healing_rolls |
| `core_skill_effects.gd` | healing_roll_2 | healing_rolls |
| `core_skill_effects.gd` | healing_roll_3 | healing_rolls |
| `core_skill_effects.gd` | healing_roll_4 | healing_rolls |
| `core_skill_effects.gd` | healing_roll_5 | healing_rolls |
| `core_skill_effects.gd` | healing_roll_6 | healing_rolls |
| `core_skill_effects.gd` | healing_roll_7 | healing_rolls |
| `core_skill_effects.gd` | healing_roll_8 | healing_rolls |
| `core_skill_effects.gd` | healing_roll_9 | healing_rolls |
| `core_skill_effects.gd` | healing_roll_10 | healing_rolls |
| `core_skill_effects.gd` | healing_roll_11 | healing_rolls |
| `core_skill_effects.gd` | healing_roll_12 | healing_rolls |
| `core_skill_effects.gd` | healing_roll_13 | healing_rolls |
| `core_skill_effects.gd` | healing_roll_14 | healing_rolls |
| `core_skill_effects.gd` | cb05_0 | core_balance |
| `core_skill_effects.gd` | cb05_1 | core_balance |
| `core_skill_effects.gd` | cb05_2 | core_balance |
| `core_skill_effects.gd` | cb05_3 | core_balance |
| `core_skill_effects.gd` | cb05_4 | core_balance |
| `core_skill_effects.gd` | cb05_5 | core_balance |
| `core_skill_effects.gd` | cb05_6 | core_balance |
| `core_skill_effects.gd` | cb05_7 | core_balance |
| `core_skill_effects.gd` | cb05_8 | core_balance |
| `core_skill_effects.gd` | cb05_9 | core_balance |
| `core_skill_effects.gd` | cb05_10 | core_balance |
| `core_skill_effects.gd` | cb05_11 | core_balance |
| `core_skill_effects.gd` | cb05_12 | core_balance |
| `core_skill_effects.gd` | cb02_core_skill_effects_1_5 | combat_balance_preview |
| `core_skill_effects.gd` | vitals_core_heal | combat_vitals |
| `core_skill_effects.gd` | observe_core_displacement | wilds_skill_tactics |
| `core_skill_effects.gd` | hush_rite_evidence | wilds_skill_tactics |
| `core_skill_effects.gd` | core_area_evidence | wilds_skill_tactics |
| `core_skill_effects.gd` | core_tactics_dependency | wilds_skill_tactics |
| `enemy_support.gd` | cb06_0 | enemy_balance |
| `enemy_support.gd` | cb06_1 | enemy_balance |
| `enemy_support.gd` | cb06_2 | enemy_balance |
| `enemy_support.gd` | cb06_3 | enemy_balance |
| `enemy_support.gd` | cb06_4 | enemy_balance |
| `enemy_support.gd` | cb06_5 | enemy_balance |
| `enemy_support.gd` | cb06_6 | enemy_balance |
| `enemy_support.gd` | healing_roll_0 | healing_rolls |
| `enemy_support.gd` | cb02_enemy_support_1_38 | combat_balance_preview |
| `enemy_support.gd` | choir_second_windup | event_audio |
| `enemy_support.gd` | choir_release | event_audio |
| `enemy_support.gd` | antiphon_release | event_audio |
| `enemy_support.gd` | relay_release | event_audio |
| `enemy_support.gd` | relay_audio_state | event_audio |
| `enemy_support.gd` | corpse_release | event_audio |
| `enemy_support.gd` | echo_toll_release | event_audio |
| `enemy_support.gd` | brood_release | event_audio |
| `enemy_support.gd` | brood_audio_state | event_audio |
| `enemy_support.gd` | thief_corpse_resolution_guard | thief_escape |
| `enemy_support.gd` | thief_leaves_no_corpse | thief_escape |
| `enemy_support.gd` | resolved_antiphon | enemy_move_feedback |
| `enemy_support.gd` | confirmed_corpse_healing | enemy_move_feedback |
| `enemy_support.gd` | resolved_echo_toll | enemy_move_feedback |
| `enemy_support.gd` | confirmed_hatch_blocked | enemy_move_feedback |
| `enemy_support.gd` | confirmed_shelter_loss | enemy_move_feedback |
| `enemy_support.gd` | support_feedback_access | enemy_move_feedback |
| `enemy_support.gd` | observe_shelter_break | wilds_skill_tactics |
| `enemy_support.gd` | choir_sector_helper | wilds_skill_tactics |
| `enemy_support.gd` | shared_choir_contact | wilds_skill_tactics |
| `enemy_support.gd` | antiphon_resolution | wilds_skill_tactics |
| `enemy_support.gd` | spare_tether_resolution | wilds_skill_tactics |
| `enemy_support.gd` | learned_haste_resolution | wilds_skill_tactics |
| `enemy_support.gd` | choir_antiphon_plan | wilds_skill_tactics |
| `enemy_support.gd` | pallbearer_spare_plan | wilds_skill_tactics |
| `enemy_support.gd` | bellcap_echo_plan | wilds_skill_tactics |
| `enemy_support.gd` | choose_spare_tether | wilds_skill_tactics |
| `enemy_support.gd` | tether_corpse_exclusion | wilds_skill_tactics |
| `enemy_support.gd` | learned_rite_anchors | wilds_skill_tactics |
| `enemy_support.gd` | antiphon_interrupt | wilds_skill_tactics |
| `enemy_support.gd` | relay_revalidation | wilds_skill_tactics |
| `enemy_support.gd` | scattered_hatch_release | wilds_skill_tactics |
| `enemy_support.gd` | mark_spawned_brood | wilds_skill_tactics |
| `enemy_support.gd` | broodmother_provenance | wilds_skill_tactics |
| `enemy_support.gd` | shepherd_learned_relay | wilds_skill_tactics |
| `enemy_support.gd` | broodmother_learned_scatter | wilds_skill_tactics |
| `enemy_support.gd` | scatter_sites | wilds_skill_tactics |
| `enemy_support.gd` | skill_tactics_dependency | wilds_skill_tactics |
| `wilds_skill_tactics.gd` | learned_volley_reference | wilds_skill_tactics |
| `wilds_skill_tactics.gd` | regular_evidence_and_logging | wilds_skill_tactics |
| `wilds_skill_tactics.gd` | regular_eligibility | wilds_skill_tactics |
| `wilds_skill_tactics.gd` | regular_cast_denial | wilds_skill_tactics |
| `wilds_skill_tactics.gd` | regular_response_profiles | wilds_skill_tactics |
| `enemy_skill_responses.gd` | cb06_0 | enemy_balance |
| `enemy_skill_responses.gd` | canopy_release | event_audio |
| `enemy_skill_responses.gd` | resolved_canopy_circle | enemy_move_feedback |
| `combat_feedback.gd` | cb07_0 | expedition_sustain |
| `combat_feedback.gd` | space_pull_from_slow | enemy_move_feedback |
| `combat_feedback.gd` | callout_height_override | enemy_move_feedback |
| `character_profile.gd` | ct05_oracle_1 | oracle_progression |
| `character_profile.gd` | ct04_reaper_1 | foundation, reaper_progression |
| `character_profile.gd` | ct03_ranger_1 | foundation, ranger_progression |
| `character_profile.gd` | ct02_1 | weaver_progression, warden_progression, combat_affinity_contracts |
| `character_profile.gd` | ct02_2 | weaver_progression, warden_progression, combat_affinity_contracts |
| `character_profile.gd` | ct01_whole_xp_1 | classes, characters, loot, persistence_operations |
| `character_profile.gd` | ct01_whole_xp_2 | classes, characters, loot, persistence_operations |
| `character_profile.gd` | ct01_whole_xp_3 | classes, characters, loot, persistence_operations |
| `character_profile.gd` | ct01_whole_xp_4 | classes, characters, loot, persistence_operations |
| `character_profile.gd` | ct01_whole_xp_5 | classes, characters, loot, persistence_operations |
| `character_profile.gd` | ct01_whole_xp_6 | classes, characters, loot, persistence_operations |
| `character_profile.gd` | ct01_whole_xp_7 | classes, characters, loot, persistence_operations |
| `character_profile.gd` | ct01_1 | warden_progression, classes, combat_affinity_contracts |
| `character_profile.gd` | ct01_2 | warden_progression, classes, combat_affinity_contracts |
| `character_profile.gd` | cr05_progression_1 | classes, life, combat_affinity_contracts |
| `character_profile.gd` | guest_projection | persistence_operations, connection_flow, characters, expeditions, garden |
| `character_profile.gd` | normalize_warden_tree_choices | warden_progression |
| `content_ids.gd` | ct01_whole_xp_1 | classes, characters, loot, persistence_operations |
| `content_ids.gd` | ct01_whole_xp_2 | classes, characters, loot, persistence_operations |
| `content_ids.gd` | ct01_whole_xp_3 | classes, characters, loot, persistence_operations |
| `content_ids.gd` | subclass_manifest | warden_progression |
| `content_ids.gd` | manifest_warden_nodes | warden_progression |
| `progression_tree.gd` | show_warden_subclass_labels | warden_progression |
| `progression_tree.gd` | show_unlearned_warden_routes | warden_progression |
| `class_ability_targeting.gd` | ct03_ranger_1 | ability_aim, ranger_progression |
| `class_ability_targeting.gd` | tc01_ranged_clearance_1 | ability_aim, combat, ranged_release, hex_terrain |
| `class_ability_targeting.gd` | tc01_ranged_clearance_2 | ability_aim, combat, ranged_release, hex_terrain |
| `class_ability_targeting.gd` | tc01_ranged_clearance_3 | ability_aim, combat, ranged_release, hex_terrain |
| `class_ability_targeting.gd` | tc01_ranged_clearance_4 | ability_aim, combat, ranged_release, hex_terrain |
| `class_ability_targeting.gd` | tc01_ranged_clearance_5 | ability_aim, combat, ranged_release, hex_terrain |
| `class_ability_targeting.gd` | tc01_ranged_clearance_6 | ability_aim, combat, ranged_release, hex_terrain |
| `class_ability_targeting.gd` | tc01_ranged_clearance_7 | ability_aim, combat, ranged_release, hex_terrain |
| `class_ability_targeting.gd` | ct01_1 | warden_progression, classes, combat_affinity_contracts |
| `class_ability_targeting.gd` | ground_trap_modes | ability_aim, classes |
| `class_ability_targeting.gd` | plan_ground_trap | ability_aim, classes |
| `class_ability_targeting.gd` | ground_trap_range_preview | ability_aim, classes |
| `class_ability_targeting.gd` | ground_trap_area_preview | ability_aim, classes |
| `class_ability_targeting.gd` | ground_trap_point_preview | ability_aim, classes |
| `class_ability_targeting.gd` | fan_footprint | ability_aim, ranged_release |
| `class_ability_targeting.gd` | subclass_footprint | warden_progression |
| `class_ability_targeting.gd` | subclass_plan | warden_progression |
| `class_ability_targeting.gd` | warden_anchor_preview_center | warden_progression |
| `core_strike_mark.gd` | cb05_0 | core_balance |
| `core_strike_mark.gd` | cb05_1 | core_balance |
| `core_strike_mark.gd` | cb05_2 | core_balance |
| `core_strike_mark.gd` | cb05_3 | core_balance |
| `core_strike_mark.gd` | cb05_4 | core_balance |
| `core_strike_mark.gd` | subclass_mark_release | warden_progression |
| `core_strike_mark.gd` | subclass_mark_storage | warden_progression |
| `ability_aim.gd` | ct01_1 | warden_progression, classes, combat_affinity_contracts |
| `ability_aim.gd` | vital_aim_1 | vital_affinity, combat_affinity_contracts, core_combat, mouse_combat |
| `ability_aim.gd` | vital_aim_2 | vital_affinity, combat_affinity_contracts, core_combat, mouse_combat |
| `ability_aim.gd` | vital_aim_3 | vital_affinity, combat_affinity_contracts, core_combat, mouse_combat |
| `ability_aim.gd` | vital_aim_4 | vital_affinity, combat_affinity_contracts, core_combat, mouse_combat |
| `ability_aim.gd` | core_curved_and_link_guides | core_combat |
| `ability_aim.gd` | subclass_aim_preview | warden_progression |
| `ability_aim.gd` | subclass_aim_wire | warden_progression |
| `ability_aim.gd` | subclass_commit_aim | warden_progression |
| `main_menu.gd` | cr04a_affinity_1 | combat_affinity_contracts, fire_affinity |
| `main_menu.gd` | cr03__ready | frost_affinity |
| `main_menu.gd` | cr02__ready | combat_affinity_contracts |
| `main_menu.gd` | cr02__launch_guarded | combat_affinity_contracts |
| `main_menu.gd` | experimental_coop_1 | hex_terrain, terrain, connection_flow, garden |
| `main_menu.gd` | experimental_coop_2 | hex_terrain, terrain, connection_flow, garden |
| `main_menu.gd` | experimental_coop_3 | hex_terrain, terrain, connection_flow, garden |
| `main_menu.gd` | experimental_coop_4 | hex_terrain, terrain, connection_flow, garden |
| `main_menu.gd` | experimental_coop_5 | hex_terrain, terrain, connection_flow, garden |
| `main_menu.gd` | experimental_coop_6 | hex_terrain, terrain, connection_flow, garden |
| `main_menu.gd` | experimental_coop_7 | hex_terrain, terrain, connection_flow, garden |
| `main_menu.gd` | experimental_coop_8 | hex_terrain, terrain, connection_flow, garden |
| `main_menu.gd` | experimental_coop_9 | hex_terrain, terrain, connection_flow, garden |
| `main_menu.gd` | experimental_terrain_1 | hex_terrain, terrain, garden, persistence_operations |
| `main_menu.gd` | experimental_terrain_3 | hex_terrain, terrain, garden, persistence_operations |
| `main_menu.gd` | experimental_terrain_5 | hex_terrain, terrain, garden, persistence_operations |
| `main_menu.gd` | experimental_terrain_7 | hex_terrain, terrain, garden, persistence_operations |
| `main_menu.gd` | experimental_terrain_9 | hex_terrain, terrain, garden, persistence_operations |
| `main_menu.gd` | experimental_terrain_11 | hex_terrain, terrain, garden, persistence_operations |
| `main_menu.gd` | experimental_terrain_13 | hex_terrain, terrain, garden, persistence_operations |
| `main_menu.gd` | experimental_terrain_15 | hex_terrain, terrain, garden, persistence_operations |
| `main_menu.gd` | experimental_terrain_17 | hex_terrain, terrain, garden, persistence_operations |
| `main_menu.gd` | experimental_terrain_19 | hex_terrain, terrain, garden, persistence_operations |
| `main_menu.gd` | production_route_1 | persistence_operations, persistence_authorization, persistence_recovery_plan, persistence_save_access, menus, characters, developer_garden, connection_flow |
| `main_menu.gd` | production_route_2 | persistence_operations, persistence_authorization, persistence_recovery_plan, persistence_save_access, menus, characters, developer_garden, connection_flow |
| `main_menu.gd` | production_route_3 | persistence_operations, persistence_authorization, persistence_recovery_plan, persistence_save_access, menus, characters, developer_garden, connection_flow |
| `main_menu.gd` | production_route_4 | persistence_operations, persistence_authorization, persistence_recovery_plan, persistence_save_access, menus, characters, developer_garden, connection_flow |
| `main_menu.gd` | production_route_5 | persistence_operations, persistence_authorization, persistence_recovery_plan, persistence_save_access, menus, characters, developer_garden, connection_flow |
| `main_menu.gd` | production_route_6 | persistence_operations, persistence_authorization, persistence_recovery_plan, persistence_save_access, menus, characters, developer_garden, connection_flow |
| `main_menu.gd` | production_route_7 | persistence_operations, persistence_authorization, persistence_recovery_plan, persistence_save_access, menus, characters, developer_garden, connection_flow |
| `main_menu.gd` | production_route_8 | persistence_operations, persistence_authorization, persistence_recovery_plan, persistence_save_access, menus, characters, developer_garden, connection_flow |
| `main_menu.gd` | production_route_9 | persistence_operations, persistence_authorization, persistence_recovery_plan, persistence_save_access, menus, characters, developer_garden, connection_flow |
| `main_menu.gd` | production_route_10 | persistence_operations, persistence_authorization, persistence_recovery_plan, persistence_save_access, menus, characters, developer_garden, connection_flow |
| `main_menu.gd` | production_route_11 | persistence_operations, persistence_authorization, persistence_recovery_plan, persistence_save_access, menus, characters, developer_garden, connection_flow |
| `main_menu.gd` | production_route_12 | persistence_operations, persistence_authorization, persistence_recovery_plan, persistence_save_access, menus, characters, developer_garden, connection_flow |
| `main_menu.gd` | production_route_13 | persistence_operations, persistence_authorization, persistence_recovery_plan, persistence_save_access, menus, characters, developer_garden, connection_flow |
| `main_menu.gd` | production_route_14 | persistence_operations, persistence_authorization, persistence_recovery_plan, persistence_save_access, menus, characters, developer_garden, connection_flow |
| `main_menu.gd` | production_route_15 | persistence_operations, persistence_authorization, persistence_recovery_plan, persistence_save_access, menus, characters, developer_garden, connection_flow |
| `main_menu.gd` | production_route_16 | persistence_operations, persistence_authorization, persistence_recovery_plan, persistence_save_access, menus, characters, developer_garden, connection_flow |
| `main_menu.gd` | guarded_lifecycle_1 | persistence_operations, connection_flow, menus, settings |
| `main_menu.gd` | guarded_lifecycle_2 | persistence_operations, connection_flow, menus, settings |
| `main_menu.gd` | guarded_lifecycle_3 | persistence_operations, connection_flow, menus, settings |
| `main_menu.gd` | cleanup_feedback_1 | persistence_operations |
| `main_menu.gd` | cb02_main_menu_1_16 | combat_balance_preview |
| `main_menu.gd` | title_music_depart | soundscape |
| `main_menu.gd` | title_music_enter | soundscape |
| `main_menu.gd` | shared_button_roots | menu_layout |
| `main_menu.gd` | character_roots | menu_layout |
| `main_menu.gd` | action_roots | menu_layout |
| `main_menu.gd` | slot_roots | menu_layout |
| `main_menu.gd` | developer_title_settings | developer_garden |
| `main_menu.gd` | close_join_before_launch | connection_flow |
| `main_menu.gd` | remember_connection_roles | connection_flow |
| `main_menu.gd` | launch_connection_feedback | connection_flow |
| `main_menu.gd` | launch_network_port | connection_flow |
| `main_menu.gd` | join_return_panel | connection_flow |
| `main_menu.gd` | hosting_settings_button | connection_flow |
| `main_menu.gd` | coop_join_copy | connection_flow |
| `main_menu.gd` | separate_host_port | connection_flow |
| `main_menu.gd` | host_port_state | connection_flow |
| `thief_escape.gd` | committed_theft_cue | event_audio |
| `assets/shaders/garden_path.gdshader` | scan_soil | garden_life |
| `character_appearance.gd` | field_appearance | avatar_motion_view |
| `assets/characters/weapon_actions.json` | fan_release_profile | ranged_release, combat_readability, ability_aim |
| `assets/characters/weapon_actions.json` | censer_release_profile | combat_readability, avatar_motion_view, ranged_release |
| `assets/characters/weapon_actions.json` | orb_release_profile | ranged_release, avatar_motion_view, core_combat, combat_readability |
| `field_traveller.gd` | lift_seed_focus | avatar_motion_view, ranged_release |
| `combat_director.gd` | cb06_0 | enemy_balance |
| `combat_director.gd` | cb06_1 | enemy_balance |
| `combat_director.gd` | cb02_combat_director_1_2 | combat_balance_preview |
| `combat_director.gd` | vitals_enemy_capacity | combat_vitals |
| `combat_director.gd` | dream_lure_pursuit | core_combat |
| `core_skill_rules.gd` | cb05_0 | core_balance |
| `core_skill_rules.gd` | cb05_1 | core_balance |
| `core_skill_rules.gd` | cb05_2 | core_balance |
| `core_skill_rules.gd` | cb05_3 | core_balance |
| `core_skill_rules.gd` | cb05_4 | core_balance |
| `core_skill_rules.gd` | cb05_5 | core_balance |
| `core_skill_rules.gd` | cb05_6 | core_balance |
| `core_skill_rules.gd` | cb05_7 | core_balance |
| `core_skill_rules.gd` | cb05_8 | core_balance |
| `core_skill_rules.gd` | cb05_9 | core_balance |
| `core_skill_rules.gd` | cb05_10 | core_balance |
| `core_skill_rules.gd` | cb05_11 | core_balance |
| `core_skill_rules.gd` | cb05_12 | core_balance |
| `core_skill_rules.gd` | cb05_13 | core_balance |
| `core_skill_rules.gd` | cb05_14 | core_balance |
| `core_skill_rules.gd` | ground_footprint_tooltip | core_combat |
| `boss_lair_fights.gd` | ct05_oracle_1 | oracle_progression |
| `boss_lair_fights.gd` | cb06_0 | enemy_balance |
| `boss_lair_fights.gd` | cb06_1 | enemy_balance |
| `boss_lair_fights.gd` | orchard_resolve_cage | boss_lair_fights |
| `boss_lair_fights.gd` | lair_charge | event_audio |
| `boss_lair_fights.gd` | lair_release | event_audio |
| `boss_lair_fights.gd` | lair_windup | event_audio |
| `boss_phase_fights.gd` | ct05_oracle_1 | oracle_progression |
| `boss_phase_fights.gd` | ct05_oracle_2 | oracle_progression |
| `boss_phase_fights.gd` | cb06_0 | enemy_balance |
| `boss_phase_fights.gd` | cb06_1 | enemy_balance |
| `boss_phase_fights.gd` | boss_release | event_audio |
| `boss_phase_fights.gd` | boss_hatch_release | event_audio |
| `boss_phase_fights.gd` | boss_lane_release | event_audio |
| `boss_phase_fights.gd` | boss_release_state | event_audio |
| `boss_phase_fights.gd` | boss_windup | event_audio |
| `enemy_move_feedback.gd` | orchard_locked_release | boss_lair_fights |
| `combat_audio.gd` | orchard_cage_cast_audio | boss_lair_fights |
| `subclass_combat.gd` | ec01_playtest_1 | weaver_progression |
| `subclass_combat.gd` | ec01_playtest_2 | weaver_progression |
| `subclass_combat.gd` | ec01_1 | affinity_cards |
| `subclass_combat.gd` | ct05_oracle_1 | oracle_progression |
| `subclass_combat.gd` | ct05_oracle_2 | oracle_progression |
| `subclass_combat.gd` | ct05_oracle_3 | oracle_progression |
| `subclass_combat.gd` | ct05_oracle_4 | oracle_progression |
| `subclass_combat.gd` | ct05_oracle_5 | oracle_progression |
| `subclass_combat.gd` | ct05_oracle_6 | oracle_progression |
| `subclass_combat.gd` | ct04_reaper_1 | warden_progression, reaper_progression |
| `subclass_combat.gd` | ct04_reaper_2 | warden_progression, reaper_progression |
| `subclass_combat.gd` | ct04_reaper_3 | warden_progression, reaper_progression |
| `subclass_combat.gd` | ct04_reaper_4 | warden_progression, reaper_progression |
| `subclass_combat.gd` | ct04_reaper_5 | warden_progression, reaper_progression |
| `subclass_combat.gd` | ct04_reaper_6 | warden_progression, reaper_progression |
| `subclass_combat.gd` | ct04_reaper_7 | warden_progression, reaper_progression |
| `subclass_combat.gd` | ct03_ranger_1 | warden_progression, ranger_progression |
| `subclass_combat.gd` | ct03_ranger_2 | warden_progression, ranger_progression |
| `subclass_combat.gd` | ct03_ranger_3 | warden_progression, ranger_progression |
| `subclass_combat.gd` | ct03_ranger_4 | warden_progression, ranger_progression |
| `subclass_combat.gd` | ct03_ranger_5 | warden_progression, ranger_progression |
| `subclass_combat.gd` | ct03_ranger_6 | warden_progression, ranger_progression |
| `subclass_combat.gd` | ct03_ranger_7 | warden_progression, ranger_progression |
| `subclass_combat.gd` | ct03_ranger_8 | warden_progression, ranger_progression |
| `subclass_combat.gd` | ct02_1 | weaver_progression, warden_progression, combat_affinity_contracts |
| `subclass_combat.gd` | ct02_2 | weaver_progression, warden_progression, combat_affinity_contracts |
| `subclass_combat.gd` | ct02_3 | weaver_progression, warden_progression, combat_affinity_contracts |
| `subclass_combat.gd` | ct02_4 | weaver_progression, warden_progression, combat_affinity_contracts |
| `subclass_combat.gd` | ct02_5 | weaver_progression, warden_progression, combat_affinity_contracts |
| `subclass_combat.gd` | ct02_6 | weaver_progression, warden_progression, combat_affinity_contracts |
| `subclass_combat.gd` | ct02_7 | weaver_progression, warden_progression, combat_affinity_contracts |
| `subclass_combat.gd` | ct02_8 | weaver_progression, warden_progression, combat_affinity_contracts |
| `subclass_combat.gd` | ct02_9 | weaver_progression, warden_progression, combat_affinity_contracts |
| `subclass_combat.gd` | ct02_10 | weaver_progression, warden_progression, combat_affinity_contracts |
| `subclass_combat.gd` | ct02_11 | weaver_progression, warden_progression, combat_affinity_contracts |
| `subclass_combat.gd` | cr04c_spirit_1 | spirit_affinity, core_combat, combat_affinity_contracts |
| `subclass_combat.gd` | cr04a_affinity_1 | vital_affinity, combat_affinity_contracts |
| `subclass_combat.gd` | cr03_cast_skill | frost_affinity |
| `subclass_combat.gd` | cr02_cast_skill | combat_affinity_contracts |
| `subclass_combat.gd` | cb07_0 | expedition_sustain |
| `subclass_combat.gd` | cb07_1 | expedition_sustain |
| `subclass_combat.gd` | cb07_2 | expedition_sustain |
| `subclass_combat.gd` | cb07_3 | expedition_sustain |
| `subclass_combat.gd` | cb07_4 | expedition_sustain |
| `subclass_combat.gd` | healing_roll_0 | healing_rolls |
| `subclass_combat.gd` | healing_roll_1 | healing_rolls |
| `subclass_combat.gd` | healing_roll_2 | healing_rolls |
| `subclass_combat.gd` | healing_roll_3 | healing_rolls |
| `subclass_combat.gd` | healing_roll_4 | healing_rolls |
| `subclass_combat.gd` | cb04_ward_time_0 | class_balance |
| `subclass_combat.gd` | cb04_ward_time_1 | class_balance |
| `subclass_combat.gd` | cb04_ward_time_2 | class_balance |
| `subclass_combat.gd` | cb04_ward_time_3 | class_balance |
| `subclass_combat.gd` | cb04_0 | class_balance |
| `subclass_combat.gd` | cb04_1 | class_balance |
| `subclass_combat.gd` | cb04_2 | class_balance |
| `subclass_combat.gd` | cb04_3 | class_balance |
| `subclass_combat.gd` | cb04_4 | class_balance |
| `subclass_combat.gd` | cb04_5 | class_balance |
| `subclass_combat.gd` | cb04_6 | class_balance |
| `subclass_combat.gd` | cb04_7 | class_balance |
| `subclass_combat.gd` | cb04_8 | class_balance |
| `subclass_combat.gd` | cb04_9 | class_balance |
| `subclass_combat.gd` | cb04_10 | class_balance |
| `subclass_combat.gd` | cb02_subclass_combat_2_3 | combat_balance_preview |
| `subclass_combat.gd` | cb02_subclass_combat_1_2 | combat_balance_preview |
| `subclass_combat.gd` | vitals_subclass_ally | combat_vitals |
| `subclass_combat.gd` | vitals_subclass_siphon | combat_vitals |
| `expedition_life.gd` | ec01_1 | affinity_cards |
| `expedition_life.gd` | ct05_oracle_1 | oracle_progression |
| `expedition_life.gd` | cr05_grafts_1 | combat_affinity_contracts, weapons, classes, life |
| `expedition_life.gd` | cr05_progression_1 | classes, life, combat_affinity_contracts |
| `expedition_life.gd` | cr04c_void_1 | void_affinity, core_combat, combat_affinity_contracts |
| `expedition_life.gd` | cr04c_spirit_1 | spirit_affinity, core_combat, combat_affinity_contracts |
| `expedition_life.gd` | cr04c_storm_1 | storm_affinity, life |
| `expedition_life.gd` | cr04b_wood_1 | wood_affinity, combat_affinity_contracts |
| `expedition_life.gd` | cr04a_affinity_1 | fire_affinity, vital_affinity, combat_affinity_contracts |
| `expedition_life.gd` | cr04a_affinity_2 | fire_affinity, vital_affinity, combat_affinity_contracts |
| `expedition_life.gd` | cr04a_affinity_3 | fire_affinity, vital_affinity, combat_affinity_contracts |
| `expedition_life.gd` | cr04a_affinity_4 | fire_affinity, vital_affinity, combat_affinity_contracts |
| `expedition_life.gd` | cr03_down | frost_affinity |
| `expedition_life.gd` | cr03_revive | frost_affinity |
| `expedition_life.gd` | guarded_expedition_1 | persistence_operations, life, combat |
| `expedition_life.gd` | guarded_expedition_2 | persistence_operations, life, combat |
| `expedition_life.gd` | guarded_expedition_3 | persistence_operations, life, combat |
| `expedition_life.gd` | guarded_expedition_4 | persistence_operations, life, combat |
| `expedition_life.gd` | guarded_expedition_5 | persistence_operations, life, combat |
| `expedition_life.gd` | guarded_expedition_6 | persistence_operations, life, combat |
| `expedition_life.gd` | guarded_expedition_7 | persistence_operations, life, combat |
| `expedition_life.gd` | guarded_expedition_8 | persistence_operations, life, combat |
| `expedition_life.gd` | cb07_0 | expedition_sustain |
| `expedition_life.gd` | cb03_resolved_maximum_health | weapon_balance |
| `expedition_life.gd` | cb02_expedition_life_5_7 | combat_balance_preview |
| `expedition_life.gd` | cb02_expedition_life_4_6 | combat_balance_preview |
| `expedition_life.gd` | cb02_expedition_life_3_5 | combat_balance_preview |
| `expedition_life.gd` | cb02_expedition_life_2_4 | combat_balance_preview |
| `expedition_life.gd` | cb02_expedition_life_1_3 | combat_balance_preview |
| `expedition_life.gd` | vitals_revive_threshold | combat_vitals |
| `expedition_life.gd` | vitals_player_maximum | combat_vitals |
| `expedition_life.gd` | vitals_revive_constants | combat_vitals |
| `run_summary_panel.gd` | ec01_display_1 | affinity_cards, expedition_summary |
| `run_summary_panel.gd` | ec01_playtest_1 | affinity_cards, expedition_summary |
| `run_summary_panel.gd` | ec01_playtest_2 | affinity_cards, expedition_summary |
| `run_summary_panel.gd` | ec01_playtest_3 | affinity_cards, expedition_summary |
| `run_summary_panel.gd` | ec01_1 | affinity_cards |
| `run_summary_panel.gd` | ec01_2 | affinity_cards |
| `run_summary_panel.gd` | ct01_1 | warden_progression, classes, combat_affinity_contracts |
| `run_summary_panel.gd` | cr02_affinity_contract | combat_affinity_contracts |
| `run_summary_panel.gd` | cb07_0 | expedition_sustain |
| `run_summary_panel.gd` | cb07_1 | expedition_sustain |
| `run_summary_panel.gd` | healing_roll_0 | healing_rolls |
| `run_summary_panel.gd` | healing_roll_1 | healing_rolls |
| `run_summary_panel.gd` | healing_roll_2 | healing_rolls |
| `run_summary_panel.gd` | cb05_0 | core_balance |
| `run_summary_panel.gd` | cb05_1 | core_balance |
| `run_summary_panel.gd` | cb05_2 | core_balance |
| `run_summary_panel.gd` | cb05_3 | core_balance |
| `run_summary_panel.gd` | cb03_summary_effect_hp | weapon_balance |
| `run_summary_panel.gd` | cb02_run_summary_panel_1_2 | combat_balance_preview |
| `run_summary_panel.gd` | cb02_run_summary_panel_2_1 | combat_balance_preview |
| `run_summary_panel.gd` | cb02_run_summary_panel_1_0 | combat_balance_preview |
| `party_hud.gd` | preview_party_clearance | combat_balance_preview |
| `party_hud.gd` | cb02_party_hud_3_2 | combat_balance_preview |
| `party_hud.gd` | cb02_party_hud_2_1 | combat_balance_preview |
| `party_hud.gd` | cb02_party_hud_1_0 | combat_balance_preview |
| `diagnostic_watch.gd` | preview_logged_health_scale | combat_balance_preview |
| `spectator_view.gd` | preview_spectator_layout | spectator_layout |
| `spectator_view.gd` | cb07_0 | expedition_sustain |
| `spectator_view.gd` | preview_spectator_cost | combat_balance_preview |
| `assets/data/weapon_template.json` | cb03_template_roll_spread | weapon_balance |
| `combat_balance_preview.gd` | cb07_0 | expedition_sustain |
| `combat_balance_preview.gd` | cb06_0 | enemy_balance |
| `combat_balance_preview.gd` | healing_roll_0 | healing_rolls |
| `combat_balance_preview.gd` | healing_roll_1 | healing_rolls |
| `combat_balance_preview.gd` | healing_roll_2 | healing_rolls |
| `combat_balance_preview.gd` | healing_roll_3 | healing_rolls |
| `combat_balance_preview.gd` | healing_roll_4 | healing_rolls |
| `combat_balance_preview.gd` | healing_roll_5 | healing_rolls |
| `combat_balance_preview.gd` | healing_roll_6 | healing_rolls |
| `combat_balance_preview.gd` | healing_roll_7 | healing_rolls |
| `combat_balance_preview.gd` | cb03_capped_vitals | weapon_balance |
| `combat_balance_preview.gd` | cb03_followup_amount | weapon_balance |
| `combat_balance_preview.gd` | cb03_committed_roll | weapon_balance |
| `combat_balance_preview.gd` | cb03_authored_spread | weapon_balance |
| `combat_balance_preview.gd` | cb03_fractional_vitals | weapon_balance |
| `combat_balance_preview.gd` | cb03_component_hp_fields | weapon_balance |
| `item_catalog.gd` | cb03_inventory_component_hp | weapon_balance |
| `inventory_slot.gd` | cb03_slot_component_tooltip | weapon_balance |
| `subclass_catalog.gd` | ec01_playtest_1 | weaver_progression, classes, class_tree_access |
| `subclass_catalog.gd` | ec01_playtest_2 | weaver_progression, classes, class_tree_access |
| `subclass_catalog.gd` | ec01_playtest_3 | weaver_progression, classes, class_tree_access |
| `subclass_catalog.gd` | ec01_playtest_4 | weaver_progression, classes, class_tree_access |
| `subclass_catalog.gd` | ec01_playtest_5 | weaver_progression, classes, class_tree_access |
| `subclass_catalog.gd` | ct05_oracle_1 | oracle_progression |
| `subclass_catalog.gd` | ct05_oracle_2 | oracle_progression |
| `subclass_catalog.gd` | ct05_oracle_3 | oracle_progression |
| `subclass_catalog.gd` | ct04_reaper_1 | warden_progression, reaper_progression |
| `subclass_catalog.gd` | ct04_reaper_2 | warden_progression, reaper_progression |
| `subclass_catalog.gd` | ct04_reaper_3 | warden_progression, reaper_progression |
| `subclass_catalog.gd` | ct04_reaper_4 | warden_progression, reaper_progression |
| `subclass_catalog.gd` | ct03_ranger_1 | warden_progression, ranger_progression |
| `subclass_catalog.gd` | ct03_ranger_2 | warden_progression, ranger_progression |
| `subclass_catalog.gd` | ct03_ranger_3 | warden_progression, ranger_progression |
| `subclass_catalog.gd` | ct03_ranger_4 | warden_progression, ranger_progression |
| `subclass_catalog.gd` | ct03_ranger_5 | warden_progression, ranger_progression |
| `subclass_catalog.gd` | ct02_1 | weaver_progression, warden_progression, combat_affinity_contracts |
| `subclass_catalog.gd` | ct02_2 | weaver_progression, warden_progression, combat_affinity_contracts |
| `subclass_catalog.gd` | ct02_3 | weaver_progression, warden_progression, combat_affinity_contracts |
| `subclass_catalog.gd` | ct02_4 | weaver_progression, warden_progression, combat_affinity_contracts |
| `subclass_catalog.gd` | cr02_card_lines | combat_affinity_contracts |
| `subclass_catalog.gd` | cb04_0 | class_balance |
| `subclass_catalog.gd` | cb04_1 | class_balance |
| `subclass_catalog.gd` | cb04_2 | class_balance |
| `subclass_catalog.gd` | cb04_3 | class_balance |
| `subclass_catalog.gd` | cb04_4 | class_balance |
| `subclass_catalog.gd` | cb04_5 | class_balance |
| `core_skill_roster.gd` | cb05_0 | core_balance |
| `core_skill_roster.gd` | cb05_1 | core_balance |
| `core_skill_roster.gd` | cb05_2 | core_balance |
| `core_skill_roster.gd` | cb05_3 | core_balance |
| `core_skill_roster.gd` | cb05_4 | core_balance |
| `core_skill_balance.gd` | cb07_0 | expedition_sustain |
| `core_skill_balance.gd` | healing_roll_0 | healing_rolls |
| `core_skill_balance.gd` | healing_roll_1 | healing_rolls |
| `core_skill_balance.gd` | healing_roll_2 | healing_rolls |
| `core_skill_balance.gd` | healing_roll_3 | healing_rolls |
| `core_skill_balance.gd` | healing_roll_4 | healing_rolls |
| `expedition_pressure.gd` | cb06_0 | enemy_balance |
| `expedition_pressure.gd` | cb06_1 | enemy_balance |
| `expedition_pressure.gd` | cb06_2 | enemy_balance |
| `expedition_pressure.gd` | cb06_3 | enemy_balance |
| `expedition_pressure.gd` | cb06_4 | enemy_balance |
| `expedition_pressure.gd` | cb06_5 | enemy_balance |
| `class_skill_balance.gd` | cb07_0 | expedition_sustain |
| `network_presentation.gd` | cb07_0 | expedition_sustain |
| `health_orb.gd` | cb07_0 | expedition_sustain |
| `health_orb.gd` | cb07_1 | expedition_sustain |
| `health_orb.gd` | cb07_2 | expedition_sustain |
| `health_orb.gd` | cb07_3 | expedition_sustain |
| `health_orb.gd` | cb07_4 | expedition_sustain |

## Scoped visual assets

The base identity is the verified pre-scope asset hash, preserved for unrelated mechanics that incidentally import the world. The visual token, raw release fingerprint and broad smoke retain actual current bytes. Bone/morph/action/skin contracts are checked by the declared character/weapon suites. A contract change must broaden ownership.

| Asset | Visual consumers | Contract |
|---|---|---|
| `assets/characters/traveller_male.glb` | characters, presentation, avatar_motion_view | Same 25 bones, six named morphs and action IDs; normalized skins; cosmetic mesh/animation only, no gameplay collision |
| `assets/characters/traveller_female.glb` | characters, presentation, avatar_motion_view | Same 25 bones, six named morphs and action IDs; normalized skins; cosmetic mesh/animation only, no gameplay collision |
