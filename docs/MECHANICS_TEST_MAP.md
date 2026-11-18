# Mechanics and test coverage map

Generated from `tools/test_map.json` by `test_workflow.py document`.

Edges describe gameplay/data relationships. Selection uses explicit suite coverage and resource dependencies; it does not follow every visual edge recursively.

```mermaid
flowchart LR
  encounter_roster["Host encounter membership<br/> HP<br/> stable target identities and defeat"]
  expedition_grafts["Expedition graft ledgers<br/> altar quotes and source-owned adaptations"]
  departure_settlement["Detached profiles<br/> protected cargo and guarded disconnect settlement"]
  player_lifecycle["Host-owned player life generations and fallen phase"]
  player_vitals["Host-owned current HP<br/> native capacity and temporary Vital capacity"]
  player_cooldowns["Host-owned native Q<br/> R and dodge cooldown deadlines"]
  expedition_wallet["Run-only Essence sparks<br/> floor grants and spending"]
  affinity_cards["Affinity expedition card ledger<br/> rarity<br/> Essence rerolls and owned effects"]
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
  enemy_tactics["Host enemy tactics<br/> behavior decisions and attack intent validation"]
  enemy_attack_execution["Host enemy attack execution<br/> scheduled identity and detached contacts"]
  incoming_player_hit["Host incoming hit defenses<br/> guarded health loss and life outcomes"]
  expedition_participation["Expedition membership<br/> run/floor identity and travel consent"]
  network_session["Peer authorization<br/> session lifecycle<br/> explicit RPC contract and action identity"]
  life -->|"Falling, revival and expedition transitions replace host lifecycle state"| player_lifecycle
  player_lifecycle -->|"Delayed combat checks the captured player generation"| combat
  player_lifecycle -->|"Guest packets retain the fallen projection and existing movement epoch"| world_snapshot
  combat_vitals -->|"Health uses existing HP rules and resolved native capacity"| player_vitals
  life -->|"Falling and revival operate on the same host health value"| player_vitals
  player_vitals -->|"Fast and reliable channels project the existing health fields"| world_snapshot
  player_cooldowns -->|"Native class casts and refunds use each actor’s Q and R deadlines"| classes
  life -->|"New actors and expedition entry initialize native readiness"| player_cooldowns
  player_cooldowns -->|"Guests receive projected readiness and remaining Q and R seconds"| world_snapshot
  expedition_grafts -->|"Basic attacks capture purchased adaptations and resolve bounded secondary effects"| combat_affinity_contracts
  expedition_grafts -->|"Reinforced Frame previews share the resolved maximum-health calculation"| life
  expeditions -->|"Earned choices, owner revisions and expedition-only currency"| affinity_cards
  expeditions -->|"The latest cleared floor determines the shared milestone grant"| expedition_wallet
  loot -->|"Monster rewards credit sparks separately from permanent rewards"| expedition_wallet
  connection_flow -->|"Capture a disconnected profile and protect its identity until settlement"| departure_settlement
  loot -->|"Frozen kill credits settle against detached profile identities"| departure_settlement
  persistence_operations -->|"Verified save outcomes govern retry, cleanup and release of detached records"| departure_settlement
  affinity_cards -->|"Accepted rerolls replace the owner wallet and ledger together"| expedition_wallet
  expedition_wallet -->|"Guests receive the host wallet balance without its private state"| world_snapshot
  affinity_cards -->|"Source-scoped contributions captured by existing combat actions"| combat_affinity_contracts
  affinity_cards -->|"Acquired copy totals and inactive requirements in owner details"| expedition_summary
  affinity_cards -->|"Graft previews and card effects share resolved attack and health values"| expedition_grafts
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
  encounter_roster -->|"Tick and release against the live floor epoch and spawn identity"| enemy_tactics
  enemy_tactics -->|"Validate and commit a world-aware intent through ordinary telegraphs and attack plans"| enemy_attack_plan
  enemy_tactics -->|"Project leader position, warning geometry and active boss phase"| world_snapshot
  enemy_tactics -->|"Claim the scheduled attack with current floor and spawn identity"| enemy_attack_execution
  enemy_attack_execution -->|"Submit a current player-life contact and its combat facts"| incoming_player_hit
  incoming_player_hit -->|"Apply one HP outcome after Guard, Ward, Brace, and damage mitigation"| player_vitals
  incoming_player_hit -->|"Reject stale life and report falling through the existing life boundary"| player_lifecycle
  expedition_participation -->|"One host membership and floor identity governs entry, votes, advance and return"| expeditions
  expedition_participation -->|"Pending settlement still holds character readmission"| departure_settlement
  expedition_participation -->|"Protocol 41 retains detached membership and existing world fields"| world_snapshot
  expedition_participation -->|"Run/floor identity remains distinct from player life generation"| player_lifecycle
  network_session -->|"One accepted peer/character binding governs registration and RPC authorization"| connection_flow
  network_session -->|"Session admission and expedition participation retain separate owners"| expedition_participation
  network_session -->|"Settlement owner remains authoritative for unsafe readmission holds"| departure_settlement
  network_session -->|"Protocol 41 stays fixed; accepted owner details carry the connection binding"| world_snapshot
  network_session -->|"Current session, character, life and floor identify native action requests"| player_lifecycle
```

## System ownership and tests

| System | Source files | Covering suites |
|---|---|---|
| encounter_roster | `encounter_roster.gd`, `encounter_roster.gd.uid`, `scout_behavior.gd`, `scout_behavior.gd.uid` | `encounter_roster`, `ec01_affinity_cards_party`, `world_snapshot_codec`, `experimental_terrain_coop`, `guarded_expedition`, `guarded_expedition_coop`, `boss_coop`, `boss_lairs`, `boss_phase_fights`, `boss_roster`, `combat_animation`, `enemy_support`, `expedition_pressure`, `expedition_pressure_coop`, `four_players_coop`, `monster_rewards`, `projectile_terrain`, `support_rite_responses`, `regular_enemy_responses`, `regular_enemy_responses_coop`, `thief_escape`, `thief_escape_coop`, `combat_vitals_baseline` |
| expedition_grafts | `expedition_grafts.gd`, `expedition_grafts.gd.uid`, `affinity_grafting_panel.gd`, `affinity_grafting_panel.gd.uid` | `modern_gameplay_cutover`, `ec01_affinity_cards_party`, `ec01_affinity_cards`, `ct02_weaver`, `ct04_reaper`, `cr05_native_grafts`, `cr05_native_grafts_coop`, `cr05_native_grafts_party` |
| departure_settlement | `departure_settlement.gd`, `departure_settlement.gd.uid` | `experimental_terrain_coop`, `candidate_release_party`, `guarded_expedition`, `guarded_expedition_coop`, `monster_rewards` |
| player_lifecycle | `player_lifecycle.gd`, `player_lifecycle.gd.uid` | `ct05_oracle`, `cr05_native_grafts`, `world_snapshot_codec`, `cr02_combat_contracts`, `guarded_expedition`, `guarded_expedition_coop`, `loot_revival`, `loot_revival_coop`, `network_movement_coop`, `network_action_identity` |
| player_vitals | `player_vitals.gd`, `player_vitals.gd.uid` | `ec01_affinity_cards`, `world_snapshot_codec`, `cr04a_vital`, `guarded_expedition`, `guarded_expedition_coop`, `loot_revival`, `loot_revival_coop`, `party_hud_gates_coop`, `player_hud`, `combat_vitals_baseline`, `expedition_sustain` |
| player_cooldowns | `player_cooldowns.gd`, `player_cooldowns.gd.uid` | `ec01_affinity_cards_party`, `ec01_affinity_cards`, `ct05_oracle`, `ct01_warden`, `ct02_weaver`, `ct03_ranger`, `ct04_reaper`, `world_snapshot_codec`, `cr02_combat_contracts`, `experimental_terrain`, `guarded_expedition`, `guarded_expedition_coop`, `ability_aim`, `classes_weapons`, `network_warden_coop`, `player_hud` |
| expedition_wallet | `expedition_wallet.gd`, `expedition_wallet.gd.uid` | `ec01_affinity_cards_party`, `ec01_affinity_cards`, `cr05_native_grafts`, `world_snapshot_codec`, `cr02_mode_coop`, `experimental_terrain`, `guarded_expedition`, `guarded_expedition_coop`, `guarded_garden_actions`, `monster_rewards`, `run_flow` |
| affinity_cards | `affinity_cards.gd`, `affinity_cards.gd.uid`, `affinity_card_ledger.gd`, `affinity_card_ledger.gd.uid`, `affinity_card_catalog.gd`, `affinity_card_catalog.gd.uid` | `modern_gameplay_cutover`, `ec01_affinity_cards_party`, `ec01_affinity_cards`, `cr05_native_grafts`, `cr02_mode_coop` |
| oracle_progression | `oracle_connected_tree.gd`, `oracle_connected_tree.gd.uid`, `oracle_combat.gd`, `oracle_combat.gd.uid`, `oracle_omens.gd`, `oracle_omens.gd.uid`, `leader_behavior.gd`, `leader_behavior.gd.uid`, `scout_behavior.gd`, `scout_behavior.gd.uid`, `combat_status.gd`, `combat_status.gd.uid` | `ct05_oracle`, `ct05_oracle_coop`, `ct05_oracle_party` |
| void_affinity | `void_affinity.gd`, `void_affinity.gd.uid` | `cr04c_void`, `cr04c_void_coop`, `cr04c_mixed_party` |
| spirit_affinity | `spirit_affinity.gd`, `spirit_affinity.gd.uid`, `leader_behavior.gd`, `leader_behavior.gd.uid`, `scout_behavior.gd`, `scout_behavior.gd.uid` | `cr04c_mixed_party`, `cr04c_spirit`, `cr04c_spirit_coop` |
| storm_affinity | `storm_affinity.gd`, `storm_affinity.gd.uid` | `cr04c_mixed_party`, `cr04c_storm`, `cr04c_storm_coop` |
| world_snapshot | `world_snapshot.gd`, `world_snapshot.gd.uid`, `leader_behavior.gd`, `leader_behavior.gd.uid`, `scout_behavior.gd`, `scout_behavior.gd.uid` | `encounter_roster`, `ec01_affinity_cards_party`, `ct05_oracle_coop`, `ct05_oracle_party`, `ct01_warden_coop`, `ct02_weaver_coop`, `ct02_weaver_party`, `ct03_ranger_coop`, `ct03_ranger_party`, `ct04_reaper_coop`, `ct04_reaper_party`, `cr05_native_grafts_coop`, `cr05_native_grafts_party`, `cr04c_void_coop`, `cr04c_mixed_party`, `cr04c_spirit_coop`, `cr04c_storm_coop`, `world_snapshot_codec`, `cr04b_wood_coop`, `cr04b_mixed_party`, `cr04b_thorn_coop`, `cr04a_mixed_party`, `cr02_definitions_mismatch`, `experimental_terrain_coop`, `candidate_release_party`, `guarded_expedition_coop`, `diagnostics_coop`, `four_players_coop`, `network_movement_coop`, `network_presentation`, `status_feedback_coop`, `weapon_actions_coop`, `network_contract`, `network_contract_coop` |
| wood_affinity | `wood_affinity.gd`, `wood_affinity.gd.uid` | `cr04b_wood`, `cr04b_wood_coop`, `cr04b_mixed_party` |
| thorn_affinity | `thorn_affinity.gd`, `thorn_affinity.gd.uid`, `leader_behavior.gd`, `leader_behavior.gd.uid` | `cr04b_wood`, `cr04b_mixed_party`, `cr04b_thorn`, `cr04b_thorn_coop` |
| vital_affinity | `vital_combat.gd`, `vital_combat.gd.uid` | `cr04a_vital`, `cr04a_vital_coop`, `cr04a_mixed_party` |
| water_affinity | `water_combat.gd`, `water_combat.gd.uid`, `leader_behavior.gd`, `leader_behavior.gd.uid` | `cr04a_vital`, `cr04a_mixed_party`, `cr04a_water`, `cr04a_water_coop` |
| fire_affinity | `affinity_time.gd`, `affinity_time.gd.uid`, `fire_combat.gd`, `fire_combat.gd.uid` | `cr04a_vital`, `cr04a_mixed_party`, `cr04a_water`, `cr04a_fire`, `cr04a_fire_coop` |
| frost_affinity | `frost_balance.gd`, `frost_balance.gd.uid`, `frost_combat.gd`, `frost_combat.gd.uid`, `ward_responses.gd`, `ward_responses.gd.uid`, `leader_behavior.gd`, `leader_behavior.gd.uid`, `scout_behavior.gd`, `scout_behavior.gd.uid` | `cr04a_vital`, `cr04a_vital_coop`, `cr04a_mixed_party`, `cr04a_water`, `cr04a_water_coop`, `cr04a_fire_coop`, `cr03_frost`, `cr03_frost_coop`, `cr03_frost_party` |
| combat_affinity_contracts | `affinity_build.gd`, `affinity_build.gd.uid`, `catalyst_adapters.gd`, `catalyst_adapters.gd.uid`, `combat_action_events.gd`, `combat_action_events.gd.uid`, `combat_ruleset.gd`, `combat_ruleset.gd.uid`, `native_grafts.gd`, `native_grafts.gd.uid`, `leader_behavior.gd`, `leader_behavior.gd.uid`, `scout_behavior.gd`, `scout_behavior.gd.uid`, `enemy_attack_hits.gd`, `enemy_attack_hits.gd.uid` | `modern_gameplay_cutover`, `ec01_affinity_cards_party`, `ec01_affinity_cards`, `ct05_oracle`, `ct05_oracle_coop`, `ct05_oracle_party`, `ct01_warden`, `ct01_warden_coop`, `ct02_weaver`, `ct02_weaver_coop`, `ct02_weaver_party`, `ct03_ranger`, `ct03_ranger_coop`, `ct03_ranger_party`, `ct04_reaper`, `ct04_reaper_coop`, `ct04_reaper_party`, `cr05_native_grafts`, `cr05_native_grafts_coop`, `cr05_native_grafts_party`, `cr04c_void`, `cr04c_void_coop`, `cr04c_mixed_party`, `cr04c_spirit`, `cr04c_spirit_coop`, `cr04c_storm`, `cr04c_storm_coop`, `cr04b_wood`, `cr04b_wood_coop`, `cr04b_mixed_party`, `cr04b_thorn`, `cr04b_thorn_coop`, `cr04a_vital`, `cr04a_vital_coop`, `cr04a_mixed_party`, `cr04a_water`, `cr04a_water_coop`, `cr04a_fire`, `cr04a_fire_coop`, `cr03_frost`, `cr03_frost_coop`, `cr03_frost_party`, `cr02_combat_contracts`, `cr02_mode_coop`, `cr02_definitions_mismatch` |
| plant_affinities | `plant_affinities.gd`, `plant_affinities.gd.uid` | `cr04a_fire`, `cr03_frost`, `cr02_combat_contracts`, `plant_affinities` |
| hex_terrain | `scout_behavior.gd`, `scout_behavior.gd.uid`, `enemy_attack_hits.gd`, `enemy_attack_hits.gd.uid` | `ec01_affinity_cards_party`, `ct05_oracle_coop`, `ct05_oracle_party`, `ct03_ranger_coop`, `ct03_ranger_party`, `ct04_reaper_coop`, `ct04_reaper_party`, `cr04b_wood_coop`, `cr04b_mixed_party`, `cr04b_thorn_coop`, `cr04a_vital_coop`, `cr04a_mixed_party`, `cr04a_water_coop`, `cr04a_fire_coop`, `cr03_frost_coop`, `cr03_frost_party`, `cr02_mode_coop`, `experimental_terrain_coop`, `experimental_terrain`, `garden_offerings_preview`, `garden_knowledge_preview`, `garden_construction`, `garden_expansion`, `wilds_combat_preview`, `wilds_route_variation`, `wilds_boundary`, `wilds_play_floor`, `wilds_massing`, `wilds_biomes`, `terrain_continuity`, `terrain_botanical_art`, `terrain_enclosure`, `terrain_features`, `hex_terrain`, `projectile_terrain` |
| persistence_operations | `guest_profile_projection.gd`, `guest_profile_projection.gd.uid`, `guarded_title_session.gd`, `guarded_title_session.gd.uid`, `legacy_save_import.gd`, `legacy_save_import.gd.uid`, `persistence_operations.gd`, `persistence_operations.gd.uid`, `persistence_writer_integration.gd`, `persistence_writer_integration.gd.uid` | `experimental_terrain`, `legacy_import_recovery`, `legacy_mutation_containment`, `candidate_release_solo`, `candidate_release_party`, `production_persistence`, `guest_projection_coop`, `serializer_integrity`, `guarded_lifecycle`, `guarded_lifecycle_coop`, `guarded_expedition`, `guarded_expedition_coop`, `guarded_garden_actions`, `guarded_garden_actions_coop`, `guarded_gameplay_transactions`, `guarded_title_session`, `persistence_destructive_slots`, `persistence_slot_roster`, `persistence_group_one`, `persistence_restart_recovery`, `persistence_durable_evidence`, `persistence_outcomes`, `persistence_operations`, `network_contract_coop` |
| health_pool_hud | `health_pool.gdshader`, `health_pool.gdshader.uid` | `exploration_ui`, `four_players_coop`, `party_hud_gates`, `player_hud`, `combat_balance_saves`, `combat_balance_preview` |
| persistence_save_access | `persistence_save_inspection.gd`, `persistence_save_inspection.gd.uid` | `legacy_import_recovery`, `production_persistence`, `serializer_integrity`, `guarded_lifecycle`, `guarded_lifecycle_coop`, `guarded_title_session`, `persistence_destructive_slots`, `persistence_operations`, `persistence_save_access` |
| persistence_recovery_plan | `persistence_recovery_plan.gd`, `persistence_recovery_plan.gd.uid`, `persistence_evidence.gd`, `persistence_evidence.gd.uid` | `legacy_import_recovery`, `legacy_mutation_containment`, `production_persistence`, `serializer_integrity`, `guarded_lifecycle`, `guarded_lifecycle_coop`, `guarded_expedition`, `guarded_expedition_coop`, `guarded_garden_actions`, `guarded_gameplay_transactions`, `guarded_title_session`, `persistence_destructive_slots`, `persistence_slot_roster`, `persistence_group_one`, `persistence_restart_recovery`, `persistence_durable_evidence`, `persistence_outcomes`, `persistence_operations`, `persistence_save_access`, `persistence_recovery_plan` |
| persistence_authorization | `legacy_persistence.gd`, `legacy_persistence.gd.uid`, `persistence_authorization.gd`, `persistence_authorization.gd.uid`, `persistence_save_layout.gd`, `persistence_save_layout.gd.uid`, `assets/native/persistence_lock/persistence_lock.gdextension`, `assets/native/persistence_lock/persistence_lock.gdextension.uid`, `assets/native/persistence_lock/b0_native_lock.dll` | `legacy_import_recovery`, `legacy_mutation_containment`, `candidate_release_solo`, `candidate_release_party`, `production_persistence`, `serializer_integrity`, `guarded_lifecycle`, `guarded_lifecycle_coop`, `guarded_expedition`, `guarded_expedition_coop`, `guarded_garden_actions`, `guarded_gameplay_transactions`, `guarded_title_session`, `persistence_destructive_slots`, `persistence_slot_roster`, `persistence_group_one`, `persistence_restart_recovery`, `persistence_durable_evidence`, `persistence_outcomes`, `persistence_operations`, `persistence_save_access`, `persistence_recovery_plan`, `persistence_authorization` |
| foundation | `save_batch.gd`, `game_transaction.gd`, `progress.gd`, `character_profile.gd`, `content_ids.gd`, `network_compatibility.gd`, `network_settings.gd`, `content_validator.gd`, `project.godot`, `world.tscn`, `main_menu.tscn`, `export_presets.cfg`, `save_slots.gd` | `All registered suites (implicit shared contract)` |
| seeds | `seed_catalog.gd`, `altar_recipes.gd`, `altar_service.gd`, `planting_panel.gd`, `garden_altar_panel.gd`, `altar_input_slot.gd` | `plant_affinities`, `guarded_garden_actions`, `boss_coop`, `boss_roster`, `classes_weapons`, `crafting_availability_coop`, `cultivation_growth`, `foundations`, `garden_altar`, `garden_cleanup`, `garden_cleanup_coop`, `garden_crop_care`, `garden_crop_care_coop`, `garden_returns`, `garden_returns_coop`, `garden_spring`, `garden_spring_coop`, `gardening`, `gate_garden_services`, `heart_progression`, `inventory_grid`, `inventory_party`, `network_research_coop`, `seed_coop`, `seed_inventory`, `seed_progression`, `seed_template`, `species_depth`, `timed_research`, `tree_portraits`, `developer_garden` |
| items | `item_catalog.gd`, `inventory_model.gd`, `inventory_panel.gd`, `inventory_slot.gd`, `inventory_drop_surface.gd`, `inventory_drop_visuals.gd` | `plant_affinities`, `candidate_release_solo`, `guarded_garden_actions`, `checkpoint_extraction`, `classes_weapons`, `crafting_availability_coop`, `cultivation_growth`, `diagnostics`, `foundations`, `four_players_coop`, `garden_altar`, `garden_cleanup`, `garden_cleanup_coop`, `garden_conduit`, `garden_crop_care`, `garden_crop_care_coop`, `garden_interactions`, `garden_interactions_coop`, `garden_returns`, `garden_returns_coop`, `garden_spring`, `garden_spring_coop`, `gate_crafting_rules`, `inventory_grid`, `inventory_party`, `loot_revival`, `loot_revival_coop`, `monster_rewards`, `player_hud`, `seed_coop`, `seed_inventory`, `seed_template`, `species_depth`, `developer_garden` |
| weapons | `weapon_parts.gd`, `weapon_system.gd`, `weapon_frames.gd`, `loadout_materials.gd`, `loadout_panel.gd` | `ec01_affinity_cards`, `cr05_native_grafts`, `cr05_native_grafts_coop`, `cr05_native_grafts_party`, `cr04b_wood`, `cr04b_thorn`, `cr04a_vital`, `cr04a_vital_coop`, `cr04a_mixed_party`, `cr04a_water`, `cr04a_water_coop`, `cr04a_fire`, `cr04a_fire_coop`, `cr03_frost`, `cr03_frost_coop`, `cr03_frost_party`, `cr02_combat_contracts`, `cr02_mode_coop`, `plant_affinities`, `guarded_garden_actions`, `guarded_garden_actions_coop`, `boss_roster`, `character_locomotion`, `character_overhaul`, `character_rig`, `classes_weapons`, `combat_animation`, `crafting_availability_coop`, `enemy_depth`, `foundations`, `four_players_coop`, `garden_altar`, `garden_interactions`, `garden_interactions_coop`, `garden_spring`, `garden_spring_coop`, `gate_crafting_rules`, `gate_garden_services`, `inventory_grid`, `inventory_party`, `menu_coop`, `mouse_combat`, `mouse_combat_coop`, `network_presentation`, `network_warden_coop`, `party_ready`, `party_ready_coop`, `run_flow`, `seed_coop`, `seed_template`, `shrines_hits`, `species_depth`, `status_feedback`, `weapon_actions`, `weapon_actions_coop`, `developer_garden` |
| classes | `class_experience.gd`, `class_experience.gd.uid`, `class_catalog.gd`, `skill_catalog.gd`, `combat_traits.gd`, `enemy_attack_hits.gd`, `enemy_attack_hits.gd.uid` | `modern_gameplay_cutover`, `ec01_affinity_cards_party`, `ec01_affinity_cards`, `ct05_oracle`, `ct05_oracle_coop`, `ct05_oracle_party`, `ct01_warden`, `ct01_warden_coop`, `ct02_weaver`, `ct02_weaver_coop`, `ct02_weaver_party`, `ct03_ranger`, `ct03_ranger_coop`, `ct03_ranger_party`, `ct04_reaper`, `ct04_reaper_coop`, `ct04_reaper_party`, `cr05_native_grafts`, `cr05_native_grafts_coop`, `cr05_native_grafts_party`, `cr04b_wood`, `cr04b_thorn`, `cr04a_vital`, `cr04a_water`, `cr04a_fire`, `cr03_frost`, `cr02_combat_contracts`, `guarded_garden_actions`, `guarded_garden_actions_coop`, `classes_weapons`, `enemy_depth`, `foundations`, `four_players_coop`, `inventory_party`, `monster_rewards`, `mouse_combat`, `projectile_terrain`, `mouse_combat_coop`, `network_warden_coop`, `player_hud`, `run_flow`, `seed_template`, `species_depth`, `status_feedback`, `status_feedback_coop`, `weapon_actions` |
| combat | `mouse_combat.gd`, `attack_geometry.gd`, `weapon_motion.gd`, `enemy_hurtbox.gd`, `enemy_hurtbox.gd.uid`, `weapon_contact.gd`, `weapon_contact.gd.uid`, `combat_status.gd`, `combat_status.gd.uid`, `enemy_attack_hits.gd`, `enemy_attack_hits.gd.uid` | `encounter_roster`, `ec01_affinity_cards_party`, `ec01_affinity_cards`, `ct05_oracle`, `ct05_oracle_coop`, `ct05_oracle_party`, `ct01_warden`, `ct01_warden_coop`, `ct02_weaver`, `ct02_weaver_coop`, `ct02_weaver_party`, `ct03_ranger`, `ct03_ranger_coop`, `ct03_ranger_party`, `ct04_reaper`, `ct04_reaper_coop`, `ct04_reaper_party`, `cr05_native_grafts`, `cr04c_void`, `cr04c_spirit`, `cr04c_storm`, `cr04b_wood`, `cr04b_thorn`, `cr04a_vital`, `cr04a_water`, `candidate_release_solo`, `guarded_expedition`, `guarded_expedition_coop`, `boss_coop`, `boss_lairs`, `boss_phase_fights`, `boss_roster`, `classes_weapons`, `combat_animation`, `combat_balance`, `combat_readability`, `combat_readability_coop`, `diagnostics`, `diagnostics_coop`, `enemy_depth`, `enemy_support`, `four_players_coop`, `gate_elites`, `gate_elites_coop`, `health_points`, `menu_coop`, `monster_behaviors`, `mouse_combat`, `projectile_terrain`, `mouse_combat_coop`, `network_presentation`, `network_warden_coop`, `player_hud`, `shrines_hits`, `status_feedback`, `status_feedback_coop`, `supplied_network_smoke`, `support_deaths`, `support_rite_responses`, `support_rite_responses_coop`, `terrain_generation_coop`, `weapon_actions`, `weapon_actions_coop`, `regular_enemy_responses`, `regular_enemy_responses_coop`, `thief_escape`, `thief_escape_coop` |
| enemies | `enemy_catalog.gd`, `enemy_behaviors.gd`, `boss_encounters.gd`, `combat_director.gd`, `wilds_learning.gd`, `game_balance.gd`, `elite_enemy.gd`, `elite_enemy.gd.uid`, `leader_behavior.gd`, `leader_behavior.gd.uid`, `scout_behavior.gd`, `scout_behavior.gd.uid`, `enemy_formation.gd`, `enemy_formation.gd.uid` | `encounter_roster`, `boss_coop`, `boss_lairs`, `boss_phase_fights`, `boss_roster`, `combat_animation`, `combat_balance`, `combat_readability`, `combat_readability_coop`, `enemy_depth`, `enemy_roster`, `enemy_support`, `expedition_pressure`, `expedition_pressure_coop`, `gate_elites`, `gate_elites_coop`, `monster_behaviors`, `monster_rewards`, `shrines_hits`, `status_feedback`, `support_deaths`, `terrain_generation`, `enemy_balance_preview` |
| terrain | `battlefield.gd`, `encounter_config.gd`, `exploration.gd`, `walkable_surface.gd`, `walkable_surface.gd.uid`, `wilds_layout.gd`, `wilds_layout.gd.uid` | `ct03_ranger`, `ct04_reaper`, `experimental_terrain_coop`, `experimental_terrain`, `boss_coop`, `boss_lairs`, `boss_phase_fights`, `boss_roster`, `expedition_pressure`, `exploration_maps`, `exploration_ui`, `garden_presentation`, `gate_elites`, `loot_revival`, `loot_revival_coop`, `menu_controls`, `mouse_combat`, `projectile_terrain`, `mouse_combat_coop`, `natural_world`, `network_movement_coop`, `network_presentation`, `path_junctions`, `shrines_hits`, `support_rite_responses`, `terrain_generation`, `terrain_generation_coop`, `weapon_actions`, `wilds_skill_tactics`, `regular_enemy_responses`, `thief_escape`, `thief_escape_coop` |
| garden | `garden_visuals.gd`, `heart_visuals.gd` | `cr04a_vital_coop`, `cr04a_water_coop`, `cr04a_fire_coop`, `cr03_frost_coop`, `cr02_mode_coop`, `experimental_terrain_coop`, `candidate_release_solo`, `candidate_release_party`, `guest_projection_coop`, `garden_cleanup`, `garden_cleanup_coop`, `garden_interactions`, `garden_interactions_coop`, `garden_presentation`, `gardening`, `gate_garden_services`, `heart_progression`, `network_research_coop`, `seed_inventory`, `timed_research` |
| knowledge | `heart_catalog.gd`, `heart_progress.gd` | `guarded_garden_actions`, `guarded_gameplay_transactions`, `cultivation_growth`, `foundations`, `garden_altar`, `garden_cleanup`, `garden_cleanup_coop`, `garden_conduit`, `garden_conduit_coop`, `garden_growth`, `garden_growth_coop`, `garden_spring`, `garden_spring_coop`, `gardening`, `gate_garden_services`, `heart_growth_visual`, `heart_progression`, `network_research_coop`, `seed_coop`, `seed_progression`, `seed_template`, `species_depth`, `timed_research`, `developer_garden` |
| progression | `progression_panel.gd`, `progression_tree.gd` | `garden_cleanup`, `garden_cleanup_coop`, `heart_progression`, `seed_progression`, `tree_portraits` |
| expeditions | `party_travel.gd`, `campaign.gd`, `expedition_transitions.gd`, `expedition_transitions.gd.uid` | `modern_gameplay_cutover`, `ec01_affinity_cards_party`, `ec01_affinity_cards`, `candidate_release_solo`, `candidate_release_party`, `guest_projection_coop`, `guarded_expedition`, `guarded_expedition_coop`, `guarded_garden_actions`, `boss_coop`, `boss_roster`, `checkpoint_extraction`, `combat_balance`, `crafting_availability_coop`, `diagnostics_coop`, `enemy_depth`, `expedition_pressure`, `expedition_pressure_coop`, `expedition_track`, `expedition_track_coop`, `foundations`, `four_players_coop`, `garden_cleanup`, `garden_cleanup_coop`, `garden_growth`, `garden_growth_coop`, `garden_returns`, `garden_returns_coop`, `gate_crafting_rules`, `heart_progression`, `loot_revival`, `loot_revival_coop`, `party_hud_gates`, `party_hud_gates_coop`, `party_ready`, `party_ready_coop`, `run_flow`, `shrines_hits`, `species_depth`, `supplied_network_smoke`, `terrain_generation`, `terrain_generation_coop`, `regular_enemy_responses`, `thief_escape`, `thief_escape_coop`, `soundscape`, `event_audio`, `expedition_participation` |
| loot | `monster_rewards.gd` | `cr03_frost_coop`, `cr03_frost_party`, `experimental_terrain_coop`, `experimental_terrain`, `candidate_release_party`, `guarded_expedition`, `guarded_expedition_coop`, `guarded_garden_actions`, `guarded_gameplay_transactions`, `boss_coop`, `boss_phase_fights`, `boss_roster`, `checkpoint_extraction`, `combat_balance`, `enemy_depth`, `enemy_roster`, `enemy_support`, `expedition_pressure`, `four_players_coop`, `gate_elites`, `inventory_grid`, `loot_revival`, `loot_revival_coop`, `monster_rewards`, `seed_inventory`, `seed_template`, `support_deaths` |
| life | `expedition_life.gd`, `spectator_view.gd`, `combat_status.gd`, `combat_status.gd.uid` | `ec01_affinity_cards`, `ct05_oracle`, `ct05_oracle_coop`, `ct05_oracle_party`, `ct01_warden`, `ct01_warden_coop`, `ct02_weaver`, `ct02_weaver_coop`, `ct02_weaver_party`, `ct03_ranger`, `ct03_ranger_coop`, `ct03_ranger_party`, `ct04_reaper`, `ct04_reaper_coop`, `ct04_reaper_party`, `cr05_native_grafts`, `cr04b_wood`, `cr04b_wood_coop`, `cr04b_mixed_party`, `guarded_expedition`, `guarded_expedition_coop`, `checkpoint_extraction`, `combat_balance`, `combat_readability`, `combat_readability_coop`, `diagnostics_coop`, `expedition_pressure`, `expedition_pressure_coop`, `four_players_coop`, `health_points`, `loot_revival`, `loot_revival_coop`, `mouse_combat`, `mouse_combat_coop`, `network_movement_coop`, `network_presentation`, `network_warden_coop`, `party_hud_gates`, `party_hud_gates_coop`, `party_ready`, `party_ready_coop`, `player_hud`, `run_flow`, `status_feedback`, `status_feedback_coop`, `supplied_network_smoke`, `expedition_sustain` |
| characters | `character_slots.gd`, `character_creator.gd`, `character_appearance.gd`, `traveller_avatar.gd` | `legacy_import_recovery`, `legacy_mutation_containment`, `candidate_release_solo`, `candidate_release_party`, `production_persistence`, `guest_projection_coop`, `serializer_integrity`, `guarded_lifecycle`, `guarded_lifecycle_coop`, `guarded_expedition`, `guarded_expedition_coop`, `guarded_garden_actions`, `guarded_garden_actions_coop`, `guarded_gameplay_transactions`, `guarded_title_session`, `persistence_destructive_slots`, `persistence_slot_roster`, `character_locomotion`, `character_overhaul`, `character_rig`, `character_roster`, `delete_saves`, `direct_ip_coop`, `four_players_coop`, `garden_crop_care`, `garden_crop_care_coop`, `garden_presentation`, `menu_controls`, `menu_coop`, `network_presentation`, `network_research_coop`, `network_settings`, `party_hud_gates`, `start_menu`, `supplied_network_smoke`, `weapon_actions`, `weapon_actions_coop`, `combat_balance_saves` |
| menus | `network_panel.gd` | `legacy_import_recovery`, `legacy_mutation_containment`, `candidate_release_solo`, `candidate_release_party`, `production_persistence`, `guarded_lifecycle`, `guarded_lifecycle_coop`, `guarded_title_session`, `persistence_destructive_slots`, `persistence_slot_roster`, `character_rig`, `character_roster`, `delete_saves`, `direct_ip_coop`, `four_players_coop`, `gate_garden_services`, `menu_controls`, `menu_coop`, `network_settings`, `start_menu`, `developer_garden`, `combat_balance_saves` |
| settings | `preference_file.gd`, `preference_file.gd.uid`, `app_settings.gd`, `settings_panel.gd` | `serializer_integrity`, `guarded_lifecycle`, `guarded_lifecycle_coop`, `diagnostics`, `exploration_ui`, `garden_growth`, `garden_growth_coop`, `menu_controls`, `mouse_combat`, `mouse_combat_coop`, `network_warden_coop`, `player_hud`, `start_menu`, `soundscape` |
| presentation | `root_ui.gd`, `stage.gd`, `network_presentation.gd`, `combat_effects.gd`, `enemy_death_effects.gd`, `boss_lair_visuals.gd`, `weapon_visuals.gd`, `game_metrics.gd`, `network_movement.gd`, `network_movement.gd.uid`, `combat_feedback.gd`, `combat_feedback.gd.uid`, `assets/characters/weapon_actions.json`, `status_feedback.gd`, `status_feedback.gd.uid` | `world_snapshot_codec`, `boss_lairs`, `boss_phase_fights`, `character_locomotion`, `character_overhaul`, `character_rig`, `combat_animation`, `combat_readability`, `combat_readability_coop`, `enemy_roster`, `enemy_support`, `expedition_pressure`, `expedition_pressure_coop`, `expedition_track`, `expedition_track_coop`, `exploration_ui`, `garden_presentation`, `gate_elites`, `gate_elites_coop`, `health_points`, `inventory_party`, `loot_revival`, `natural_world`, `network_movement_coop`, `network_presentation`, `party_hud_gates`, `party_hud_gates_coop`, `player_hud`, `status_feedback`, `status_feedback_coop`, `supplied_network_smoke`, `support_deaths`, `support_rite_responses_coop`, `terrain_generation`, `terrain_generation_coop`, `tree_portraits`, `weapon_actions`, `weapon_actions_coop`, `wilds_skill_tactics_coop`, `regular_enemy_responses_coop`, `thief_escape_coop` |
| diagnostics | `diagnostic_journal.gd`, `diagnostic_watch.gd`, `diagnostics_boot.gd`, `playtest_storage.gd`, `diagnostics_panel.gd` | `serializer_integrity`, `guarded_lifecycle`, `guarded_lifecycle_coop`, `diagnostics`, `diagnostics_coop`, `four_players_coop`, `network_movement_coop` |
| party_ui | `party_hud.gd`, `party_hud.gd.uid` | `four_players_coop`, `loot_revival_coop`, `network_presentation`, `party_hud_gates`, `party_hud_gates_coop`, `player_hud` |
| gate_access | `gate_interaction.gd`, `gate_interaction.gd.uid` | `checkpoint_extraction`, `crafting_availability_coop`, `four_players_coop`, `gate_crafting_rules`, `gate_garden_services`, `party_hud_gates`, `party_hud_gates_coop`, `party_ready`, `party_ready_coop`, `run_flow`, `shrines_hits` |
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
| ui_copy |  | `ec01_affinity_cards_party`, `ec01_affinity_cards`, `classes_weapons`, `cultivation_growth`, `direct_ip_coop`, `four_players_coop`, `garden_altar`, `garden_conduit`, `garden_conduit_coop`, `garden_crop_care`, `garden_crop_care_coop`, `gate_garden_services`, `heart_progression`, `inventory_grid`, `inventory_party`, `menu_controls`, `seed_progression`, `species_depth`, `start_menu`, `status_feedback`, `tree_portraits`, `ui_copy` |
| enemy_attack_plan | `enemy_attack.gd`, `enemy_attack.gd.uid`, `enemy_variants.gd`, `enemy_variants.gd.uid`, `enemy_support.gd`, `enemy_support.gd.uid`, `scout_behavior.gd`, `scout_behavior.gd.uid`, `enemy_formation.gd`, `enemy_formation.gd.uid` | `boss_coop`, `boss_roster`, `combat_animation`, `combat_balance`, `combat_readability`, `combat_readability_coop`, `enemy_depth`, `enemy_roster`, `enemy_support`, `enemy_variants`, `expedition_pressure`, `expedition_pressure_coop`, `gate_elites`, `gate_elites_coop`, `monster_behaviors`, `monster_rewards`, `projectile_terrain`, `network_presentation`, `status_feedback`, `status_feedback_coop`, `support_deaths`, `support_rite_responses`, `support_rite_responses_coop`, `wilds_skill_tactics`, `wilds_skill_tactics_coop`, `regular_enemy_responses`, `regular_enemy_responses_coop` |
| encounter_composition | `wilds_composition.gd`, `wilds_composition.gd.uid`, `enemy_formation.gd`, `enemy_formation.gd.uid` | `boss_coop`, `boss_roster`, `combat_balance`, `enemy_roster`, `expedition_pressure`, `expedition_pressure_coop`, `four_players_coop`, `gate_elites`, `gate_elites_coop`, `supplied_network_smoke`, `support_deaths`, `terrain_generation`, `terrain_generation_coop` |
| boss_lair_fights | `boss_lair_fights.gd`, `boss_lair_fights.gd.uid`, `boss_lair_routes.gd`, `boss_lair_routes.gd.uid`, `orchard_moves.gd`, `orchard_moves.gd.uid` | `boss_coop`, `boss_lairs`, `boss_phase_fights`, `boss_roster`, `enemy_balance_preview` |
| boss_phase_fights | `boss_phase_fights.gd`, `boss_phase_fights.gd.uid`, `boss_phase_visuals.gd`, `boss_phase_visuals.gd.uid`, `boss_nest_layout.gd`, `boss_nest_layout.gd.uid` | `boss_coop`, `boss_lairs`, `boss_phase_fights`, `boss_roster`, `terrain_generation`, `terrain_generation_coop`, `enemy_balance_preview` |
| core_combat | `core_skill_rules.gd`, `core_combat.gd`, `core_thorn_visual.gd`, `core_skill_rules.gd.uid`, `core_combat.gd.uid`, `core_thorn_visual.gd.uid`, `core_lance.gd`, `core_lance.gd.uid`, `assets/ui/core_skills/thorn_line.png`, `assets/ui/core_skills/seed_lance.png`, `assets/ui/core_skills/lantern_burst.png`, `assets/ui/core_skills/whisper_mark.png`, `assets/ui/core_skills/constellation.png`, `assets/ui/core_skills/constellation.png.import`, `assets/ui/core_skills/lantern_burst.png.import`, `assets/ui/core_skills/seed_lance.png.import`, `assets/ui/core_skills/thorn_line.png.import`, `assets/ui/core_skills/whisper_mark.png.import`, `core_footprint.gd`, `core_footprint.gd.uid`, `core_skill_visuals.gd`, `core_skill_visuals.gd.uid` | `cr04c_void`, `cr04c_void_coop`, `cr04c_mixed_party`, `cr04c_spirit`, `cr04c_spirit_coop`, `cr04c_storm`, `cr04c_storm_coop`, `cr04b_wood`, `cr04b_wood_coop`, `cr04b_mixed_party`, `cr04b_thorn`, `cr04b_thorn_coop`, `cr04a_vital`, `cr04a_water`, `cr04a_fire`, `cr03_frost`, `ability_aim`, `classes_weapons`, `combat_readability`, `combat_readability_coop`, `crafting_availability_coop`, `diagnostics_coop`, `four_players_coop`, `gate_crafting_rules`, `inventory_grid`, `inventory_party`, `loot_revival`, `loot_revival_coop`, `menu_controls`, `mouse_combat`, `projectile_terrain`, `mouse_combat_coop`, `network_settings`, `network_warden_coop`, `party_ready`, `party_ready_coop`, `player_hud`, `run_flow`, `species_depth`, `status_feedback`, `status_feedback_coop`, `weapon_actions`, `weapon_actions_coop`, `wilds_skill_tactics`, `wilds_skill_tactics_coop` |
| ability_aim | `ability_aim.gd`, `ability_aim.gd.uid`, `class_ability_targeting.gd`, `class_ability_targeting.gd.uid` | `ct05_oracle`, `ct05_oracle_coop`, `ct05_oracle_party`, `ct03_ranger`, `ct04_reaper`, `ability_aim`, `classes_weapons`, `combat_readability`, `combat_readability_coop`, `menu_controls`, `mouse_combat`, `projectile_terrain`, `mouse_combat_coop`, `network_warden_coop`, `player_hud`, `network_action_identity` |
| thorn_adaptation | `scout_behavior.gd`, `scout_behavior.gd.uid` | `ability_aim`, `combat_balance`, `combat_readability`, `combat_readability_coop`, `diagnostics_coop`, `enemy_variants`, `gate_elites`, `gate_elites_coop`, `terrain_generation`, `terrain_generation_coop` |
| wilds_skill_tactics | `wilds_skill_tactics.gd`, `wilds_skill_tactics.gd.uid`, `enemy_skill_responses.gd`, `enemy_skill_responses.gd.uid`, `scout_behavior.gd`, `scout_behavior.gd.uid`, `enemy_formation.gd`, `enemy_formation.gd.uid` | `ability_aim`, `boss_coop`, `boss_phase_fights`, `combat_balance`, `combat_readability`, `combat_readability_coop`, `diagnostics_coop`, `enemy_depth`, `enemy_support`, `enemy_variants`, `gate_elites`, `gate_elites_coop`, `status_feedback`, `status_feedback_coop`, `support_rite_responses`, `support_rite_responses_coop`, `terrain_generation`, `terrain_generation_coop`, `wilds_skill_tactics`, `wilds_skill_tactics_coop`, `regular_enemy_responses`, `regular_enemy_responses_coop` |
| enemy_move_feedback | `enemy_move_feedback.gd`, `enemy_move_feedback.gd.uid`, `scout_behavior.gd`, `scout_behavior.gd.uid` | `boss_phase_fights`, `combat_readability`, `combat_readability_coop`, `enemy_support`, `status_feedback`, `status_feedback_coop`, `support_rite_responses`, `support_rite_responses_coop`, `wilds_skill_tactics`, `regular_enemy_responses`, `regular_enemy_responses_coop` |
| warden_progression | `connected_class_tree.gd`, `connected_class_tree.gd.uid`, `warden_connected_tree.gd`, `warden_connected_tree.gd.uid`, `warden_tree.gd`, `warden_tree.gd.uid`, `warden_combat.gd`, `warden_combat.gd.uid`, `subclass_catalog.gd`, `subclass_catalog.gd.uid`, `subclass_combat.gd`, `subclass_combat.gd.uid`, `subclass_visuals.gd`, `subclass_visuals.gd.uid`, `enemy_attack_hits.gd`, `enemy_attack_hits.gd.uid` | `ct01_warden`, `ct01_warden_coop`, `ct02_weaver`, `ct02_weaver_coop`, `ct02_weaver_party`, `ct03_ranger`, `ct03_ranger_coop`, `ct03_ranger_party`, `ct04_reaper`, `ct04_reaper_coop`, `ct04_reaper_party`, `ability_aim`, `character_roster`, `classes_weapons`, `foundations`, `four_players_coop`, `menu_coop`, `network_warden_coop`, `player_hud`, `seed_template`, `status_feedback`, `status_feedback_coop` |
| weaver_progression | `weaver_connected_tree.gd`, `weaver_connected_tree.gd.uid`, `weaver_combat.gd`, `weaver_combat.gd.uid` | `ct02_weaver`, `ct02_weaver_coop`, `ct02_weaver_party`, `ct03_ranger_party`, `ct04_reaper_party` |
| ranger_progression | `ranger_connected_tree.gd`, `ranger_connected_tree.gd.uid`, `ranger_combat.gd`, `ranger_combat.gd.uid` | `ct03_ranger`, `ct03_ranger_coop`, `ct03_ranger_party`, `ct04_reaper` |
| reaper_progression | `reaper_connected_tree.gd`, `reaper_connected_tree.gd.uid`, `reaper_combat.gd`, `reaper_combat.gd.uid` | `ct04_reaper`, `ct04_reaper_coop`, `ct04_reaper_party` |
| connection_flow |  | `ec01_affinity_cards_party`, `ct05_oracle_coop`, `ct05_oracle_party`, `ct01_warden_coop`, `ct02_weaver_coop`, `ct02_weaver_party`, `ct03_ranger_coop`, `ct03_ranger_party`, `ct04_reaper_coop`, `ct04_reaper_party`, `cr05_native_grafts_coop`, `cr05_native_grafts_party`, `cr04c_void_coop`, `cr04c_mixed_party`, `cr04c_spirit_coop`, `cr04c_storm_coop`, `world_snapshot_codec`, `cr04b_wood_coop`, `cr04b_mixed_party`, `cr04b_thorn_coop`, `cr04a_vital_coop`, `cr04a_mixed_party`, `cr04a_water_coop`, `cr04a_fire_coop`, `cr03_frost_coop`, `cr03_frost_party`, `cr02_mode_coop`, `cr02_definitions_mismatch`, `experimental_terrain_coop`, `candidate_release_party`, `production_persistence`, `guest_projection_coop`, `guarded_lifecycle`, `guarded_lifecycle_coop`, `guarded_expedition`, `guarded_expedition_coop`, `guarded_garden_actions_coop`, `guarded_gameplay_transactions`, `guarded_title_session`, `direct_ip_coop`, `four_players_coop`, `menu_coop`, `network_movement_coop`, `network_settings`, `start_menu`, `supplied_network_smoke`, `network_session`, `network_contract`, `network_contract_coop` |
| developer_garden | `developer_mode.gd`, `developer_mode.gd.uid`, `developer_settings.gd`, `developer_settings.gd.uid` | `legacy_import_recovery`, `production_persistence`, `guarded_title_session`, `direct_ip_coop`, `garden_growth`, `heart_growth_visual`, `heart_progression`, `menu_controls`, `menu_coop`, `start_menu`, `timed_research`, `developer_garden` |
| thief_escape | `thief_escape.gd`, `thief_escape.gd.uid`, `thief_escape_view.gd`, `thief_escape_view.gd.uid` | `enemy_depth`, `enemy_support`, `exploration_ui`, `gate_elites`, `gate_elites_coop`, `monster_rewards`, `party_hud_gates`, `regular_enemy_responses`, `regular_enemy_responses_coop`, `thief_escape`, `thief_escape_coop`, `event_audio` |
| soundscape | `soundscape.gd`, `soundscape.gd.uid`, `title_music.gd`, `title_music.gd.uid` | `four_players_coop`, `garden_growth`, `menu_controls`, `start_menu`, `soundscape`, `event_audio` |
| event_audio | `event_audio.gd`, `event_audio.gd.uid`, `combat_audio.gd`, `combat_audio.gd.uid`, `leader_behavior.gd`, `leader_behavior.gd.uid`, `scout_behavior.gd`, `scout_behavior.gd.uid` | `guarded_expedition`, `guarded_expedition_coop`, `guarded_garden_actions`, `guarded_garden_actions_coop`, `boss_lairs`, `boss_phase_fights`, `combat_readability_coop`, `cultivation_growth`, `direct_ip_coop`, `enemy_support`, `garden_crop_care`, `garden_crop_care_coop`, `garden_growth`, `menu_controls`, `party_hud_gates`, `party_hud_gates_coop`, `supplied_network_smoke`, `thief_escape`, `thief_escape_coop`, `event_audio` |
| ranged_release |  | `combat_animation`, `combat_readability`, `combat_readability_coop`, `mouse_combat`, `mouse_combat_coop`, `network_presentation`, `supplied_network_smoke`, `weapon_actions`, `weapon_actions_coop` |
| class_tree_access | `class_tree_access.gd`, `class_tree_access.gd.uid` | `ct05_oracle`, `ct05_oracle_coop`, `ct05_oracle_party`, `ct01_warden`, `ct01_warden_coop`, `ct02_weaver`, `ct02_weaver_coop`, `ct02_weaver_party`, `ct03_ranger`, `ct03_ranger_coop`, `ct03_ranger_party`, `ct04_reaper`, `ct04_reaper_coop`, `ct04_reaper_party`, `guarded_garden_actions`, `classes_weapons`, `garden_cleanup`, `gate_crafting_rules`, `gate_garden_services` |
| class_skill_icons | `class_skill_icons.gd`, `class_skill_icons.gd.uid`, `assets/ui/class_skills.png`, `assets/ui/class_skills.png.import`, `assets/ui/class_skill_icons.json` | `player_hud` |
| expedition_summary | `run_summary_panel.gd`, `run_summary_panel.gd.uid` | `ec01_affinity_cards_party`, `ec01_affinity_cards`, `menu_controls`, `menu_coop`, `player_hud`, `expedition_sustain` |
| glasscap_feints | `glasscap_feint.gd`, `glasscap_feint.gd.uid`, `glasscap_visuals.gd`, `glasscap_visuals.gd.uid`, `scout_behavior.gd`, `scout_behavior.gd.uid` | `enemy_variants`, `gate_elites`, `regular_enemy_responses_coop` |
| combat_vitals | `combat_vitals.gd`, `combat_vitals.gd.uid` | `boss_coop`, `boss_lairs`, `boss_phase_fights`, `checkpoint_extraction`, `combat_balance`, `combat_readability_coop`, `diagnostics_coop`, `four_players_coop`, `health_points`, `loot_revival`, `loot_revival_coop`, `network_presentation`, `party_hud_gates_coop`, `supplied_network_smoke`, `support_rite_responses`, `wilds_skill_tactics`, `combat_vitals_baseline`, `combat_balance_saves`, `expedition_sustain` |
| combat_balance_preview | `combat_balance_preview.gd`, `combat_balance_preview.gd.uid`, `health_orb.gd`, `health_orb.gd.uid` | `boss_coop`, `boss_lairs`, `combat_readability_coop`, `diagnostics_coop`, `direct_ip_coop`, `four_players_coop`, `health_points`, `loot_revival_coop`, `network_settings`, `party_hud_gates_coop`, `player_hud`, `start_menu`, `supplied_network_smoke`, `weapon_actions_coop`, `combat_vitals_baseline`, `combat_balance_saves`, `combat_balance_preview`, `enemy_balance_preview` |
| weapon_balance |  | `classes_weapons`, `crafting_availability_coop`, `inventory_grid`, `inventory_party`, `mouse_combat_coop`, `seed_template`, `status_feedback`, `status_feedback_coop`, `weapon_actions`, `weapon_actions_coop`, `combat_balance_preview`, `weapon_balance_preview` |
| class_balance | `class_skill_balance.gd`, `class_skill_balance.gd.uid` | `classes_weapons`, `combat_readability`, `combat_readability_coop`, `network_warden_coop`, `player_hud`, `status_feedback`, `status_feedback_coop`, `combat_balance_preview`, `weapon_balance_preview`, `expedition_sustain` |
| core_balance |  | `menu_controls`, `menu_coop`, `player_hud`, `status_feedback`, `status_feedback_coop`, `combat_balance_preview`, `weapon_balance_preview`, `expedition_sustain` |
| healing_rolls |  | `checkpoint_extraction`, `diagnostics_coop`, `enemy_support`, `loot_revival`, `loot_revival_coop`, `menu_controls`, `menu_coop`, `party_hud_gates`, `party_hud_gates_coop`, `party_ready_coop`, `player_hud`, `run_flow`, `support_rite_responses`, `support_rite_responses_coop`, `combat_balance_preview`, `weapon_balance_preview`, `expedition_sustain` |
| enemy_balance | `enemy_balance.gd`, `enemy_balance.gd.uid`, `assets/enemies/preview_scaling.json`, `leader_behavior.gd`, `leader_behavior.gd.uid`, `scout_behavior.gd`, `scout_behavior.gd.uid`, `enemy_attack_hits.gd`, `enemy_attack_hits.gd.uid` | `boss_coop`, `boss_lairs`, `boss_phase_fights`, `boss_roster`, `combat_balance`, `combat_readability`, `combat_readability_coop`, `enemy_depth`, `enemy_roster`, `enemy_support`, `enemy_variants`, `expedition_pressure`, `expedition_pressure_coop`, `four_players_coop`, `gate_elites`, `gate_elites_coop`, `support_rite_responses`, `support_rite_responses_coop`, `regular_enemy_responses`, `regular_enemy_responses_coop`, `combat_balance_preview`, `weapon_balance_preview`, `enemy_balance_preview`, `expedition_sustain` |
| expedition_sustain | `expedition_sustain.gd`, `expedition_sustain.gd.uid` | `guarded_expedition`, `guarded_expedition_coop`, `checkpoint_extraction`, `combat_readability`, `combat_readability_coop`, `diagnostics_coop`, `four_players_coop`, `loot_revival`, `loot_revival_coop`, `menu_controls`, `menu_coop`, `network_movement_coop`, `network_presentation`, `party_hud_gates`, `party_hud_gates_coop`, `party_ready_coop`, `player_hud`, `combat_balance_preview`, `weapon_balance_preview`, `expedition_sustain` |
| spectator_layout |  | `loot_revival`, `loot_revival_coop`, `party_hud_gates`, `party_hud_gates_coop`, `expedition_sustain` |
| enemy_tactics | `enemy_tactics.gd`, `enemy_tactics.gd.uid`, `leader_behavior.gd`, `leader_behavior.gd.uid`, `scout_behavior.gd`, `scout_behavior.gd.uid`, `enemy_formation.gd`, `enemy_formation.gd.uid` | `encounter_roster`, `ct05_oracle`, `world_snapshot_codec`, `cr04a_water`, `cr03_frost`, `experimental_terrain_coop`, `guarded_expedition`, `guarded_expedition_coop`, `boss_coop`, `boss_lairs`, `boss_phase_fights`, `boss_roster`, `combat_animation`, `enemy_roster`, `enemy_support`, `expedition_pressure`, `four_players_coop`, `gate_elites`, `gate_elites_coop`, `monster_rewards`, `projectile_terrain`, `support_rite_responses`, `wilds_skill_tactics`, `regular_enemy_responses`, `regular_enemy_responses_coop`, `thief_escape`, `combat_vitals_baseline` |
| enemy_attack_execution | `enemy_attack.gd`, `enemy_attack.gd.uid`, `enemy_attack_hits.gd`, `enemy_attack_hits.gd.uid`, `scout_behavior.gd`, `scout_behavior.gd.uid`, `combat_status.gd`, `combat_status.gd.uid` | `ec01_affinity_cards`, `cr05_native_grafts`, `world_snapshot_codec`, `cr04b_wood`, `experimental_terrain_coop`, `guarded_expedition`, `guarded_expedition_coop`, `boss_coop`, `boss_lairs`, `boss_phase_fights`, `boss_roster`, `combat_animation`, `enemy_support`, `four_players_coop`, `gate_elites`, `gate_elites_coop`, `health_points`, `monster_rewards`, `projectile_terrain`, `network_research_coop`, `support_rite_responses`, `regular_enemy_responses`, `regular_enemy_responses_coop`, `combat_vitals_baseline` |
| incoming_player_hit | `incoming_player_hit.gd`, `incoming_player_hit.gd.uid` | `ec01_affinity_cards`, `ct05_oracle`, `ct01_warden`, `ct04_reaper`, `cr05_native_grafts`, `world_snapshot_codec`, `cr04b_wood`, `cr04a_vital`, `cr04a_water`, `cr04a_fire`, `experimental_terrain_coop`, `guarded_expedition`, `guarded_expedition_coop`, `boss_coop`, `boss_phase_fights`, `combat_animation`, `combat_readability_coop`, `four_players_coop`, `gate_elites`, `gate_elites_coop`, `health_points`, `loot_revival`, `loot_revival_coop`, `projectile_terrain`, `support_rite_responses`, `regular_enemy_responses`, `regular_enemy_responses_coop`, `combat_vitals_baseline` |
| expedition_participation | `expedition_participation.gd`, `expedition_participation.gd.uid` | `ec01_affinity_cards_party`, `ec01_affinity_cards`, `cr05_native_grafts`, `world_snapshot_codec`, `experimental_terrain_coop`, `guarded_lifecycle`, `guarded_lifecycle_coop`, `guarded_expedition`, `guarded_expedition_coop`, `expedition_track`, `expedition_track_coop`, `four_players_coop`, `loot_revival`, `loot_revival_coop`, `monster_rewards`, `party_ready`, `party_ready_coop`, `expedition_participation`, `network_action_identity` |
| network_session | `network_session.gd`, `network_session.gd.uid`, `session_world.gd`, `session_world.gd.uid`, `network_contract.gd`, `network_contract.gd.uid`, `network_action_identity.gd`, `network_action_identity.gd.uid` | `modern_gameplay_cutover`, `ec01_affinity_cards_party`, `world_snapshot_codec`, `cr02_mode_coop`, `cr02_definitions_mismatch`, `experimental_terrain_coop`, `guarded_lifecycle`, `guarded_lifecycle_coop`, `guarded_expedition`, `guarded_expedition_coop`, `ability_aim`, `four_players_coop`, `menu_coop`, `network_presentation`, `network_settings`, `expedition_participation`, `network_session`, `network_contract`, `network_action_identity`, `network_contract_coop` |

## Existing game dispatcher functions

`game.gd` is currently shared by most mechanics. Body-only edits use the function ownership below. Shared declarations broaden affected coverage; Full runs require an explicit major-release request. Unmapped inputs must be classified before validation. This is a conservative bridge until the dispatcher is separated into smaller services.

| Function | Systems |
|---|---|
| `_act` | foundation |
| `_affinity_checkpoint_command` | expeditions, affinity_cards |
| `_apply_loadout_action` | classes, characters, weapons, items |
| `_apply_pending_kill_rewards` | loot |
| `_apply_run_kill_reward` | loot |
| `_bank_checkpoint_item` | items, garden_returns |
| `_capture_pending_departure` | departure_settlement |
| `_cycle_slot` | weapons, items |
| `_defers_kill_profiles` | loot |
| `_donate_part` | items, garden |
| `_drop_inventory_stack` | loot, items |
| `_exit_tree` | foundation |
| `_experimental_spawn_reachable` | hex_terrain, terrain |
| `_finish_combat` | loot, enemies, expeditions, classes |
| `_finish_title_return` | menus, connection_flow, persistence_operations |
| `_garden_action` | foundation, affinity_cards |
| `_harvest` | seeds, garden, knowledge, items |
| `_init` | foundation |
| `_input` | foundation |
| `_kill_reward_identity` | loot |
| `_notification` | foundation |
| `_offer_monster` | garden_stations, items, knowledge |
| `_physics_process` | foundation |
| `_pickup_inventory_drop` | loot, items |
| `_plan_essence_debit` | expedition_wallet |
| `_process` | foundation, affinity_cards |
| `_publish_kill_reward_notices` | loot |
| `_purchase_expedition_graft` | expedition_grafts |
| `_queue_monster_reward` | loot |
| `_ready` | foundation |
| `_reclaim_seed` | garden_stations, seeds, items |
| `_recover_pouch` | life |
| `_refuse_unowned_world` | persistence_operations, persistence_authorization, persistence_recovery_plan, persistence_save_access, menus, characters, developer_garden, connection_flow |
| `_report_guest_projection` | persistence_operations, connection_flow, characters, expeditions, garden |
| `_resolve_departure_settlement` | departure_settlement |
| `_select_class` | classes, characters, weapons |
| `_stop_guarded_session` | menus, persistence_operations |
| `_unhandled_input` | foundation |
| `_unhandled_key_input` | foundation, affinity_cards |
| `act` | foundation |
| `action_feedback` | persistence_operations |
| `activate_checkpoint` | expeditions, gate_access |
| `actor_profile_scope` | persistence_operations, characters |
| `add_button` | presentation |
| `add_label` | presentation |
| `add_player` | foundation |
| `affinity_checkpoint_action` | expeditions, affinity_cards |
| `apply_skill_targets` | classes, affinity_cards |
| `apply_weapon_hit` | combat, weapons, classes, loot, enemies, enemy_attack_plan, encounter_roster |
| `apply_world_snapshot` | world_snapshot, presentation, life |
| `at_garden_altar` | seeds |
| `at_garden_station` | knowledge, garden_stations |
| `at_graft_altar` | seeds |
| `at_heart` | knowledge |
| `at_weapon_gate` | foundation |
| `attack_animation_snapshot` | presentation |
| `attack_hints_snapshot` | presentation, enemy_attack_plan |
| `attract_loot` | loot |
| `available_parts` | weapons |
| `awaken_heart` | knowledge |
| `award_combat_progress` | loot |
| `bank_checkpoint_item` | items |
| `bound_position` | terrain |
| `build_garden_altar_panel` | seeds |
| `build_grafting_panel` | weapons |
| `build_heart_panels` | knowledge |
| `build_hud` | presentation, menus, settings, life, classes |
| `build_loadout_panel` | weapons |
| `build_planting_panel` | seeds |
| `build_progression_panel` | progression, knowledge, classes, seeds |
| `build_run_flow_panels` | expeditions, affinity_cards |
| `campaign_snapshot` | foundation |
| `can_checkpoint_bank` | items |
| `can_see_item_drop` | loot |
| `can_vault` | terrain |
| `checkpoint_all_ready` | expeditions |
| `checkpoint_card_data` | expeditions, affinity_cards |
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
| `death_events_snapshot` | presentation |
| `deferred_save_available` | persistence_operations |
| `dodge_player` | combat, affinity_cards |
| `donate_part` | seeds |
| `drop_inventory_stack` | loot |
| `emit_combat_event` | presentation |
| `emit_weapon_attack` | presentation |
| `encounter_cleared` | expeditions, encounter_roster |
| `encounter_health` | expeditions |
| `ending_message` | expeditions |
| `enemy_contact_point` | combat |
| `enemy_health` | encounter_roster, combat, world_snapshot |
| `enemy_name` | enemies |
| `enemy_position` | enemies |
| `extraction_checkpoint_open` | expeditions |
| `finish_combat` | loot, enemies, expeditions, classes |
| `flush_kill_rewards` | loot |
| `garden_action` | foundation |
| `garden_snapshot` | foundation |
| `graft_altar_open` | seeds |
| `graft_feedback` | weapons |
| `graft_menu_data` | weapons |
| `grant_guard` | classes |
| `grant_run_essence` | expedition_wallet, loot |
| `guarded_growth_tick` | persistence_operations |
| `guest_combat_events` | presentation |
| `guest_projection_status` | persistence_operations, connection_flow, characters, expeditions, garden |
| `handle_altar_action` | seeds |
| `handle_inventory_action` | items, weapons, seeds, loot |
| `handle_loadout_action` | weapons, classes, items |
| `harvest` | seeds, garden, knowledge, items |
| `harvest_guarded` | garden_care, characters, seeds |
| `heart_state` | knowledge |
| `hud_panel` | presentation |
| `identify_seed` | seeds |
| `infuse_study` | knowledge |
| `inventory_drop_list` | loot |
| `inventory_floor_snapshot` | items |
| `inventory_snapshot` | items |
| `inventory_ui_data` | items |
| `living_scout_count` | enemies, encounter_roster |
| `local_player_id` | menus |
| `make_scout` | enemies, enemy_attack_plan, encounter_roster |
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
| `receive_state` | foundation, encounter_roster |
| `receive_vitals` | foundation |
| `reclaim_seed` | seeds, garden_stations |
| `reclamation_cost` | seeds |
| `reclamation_species` | seeds |
| `record_character` | persistence_operations |
| `record_enemy_death` | enemies, loot, encounter_roster |
| `record_settlement_metric` | diagnostics, expeditions |
| `recover_pouch` | life |
| `refresh_drop` | loot |
| `refresh_feedback` | persistence_operations, presentation |
| `register_character` | foundation |
| `release_slot` | foundation |
| `report_harvest` | garden_care, diagnostics |
| `request_abandon_run` | expeditions |
| `request_action` | foundation |
| `request_dodge` | foundation |
| `request_garden_action` | foundation |
| `request_ip_join` | menus |
| `request_main_menu` | menus |
| `reset_encounter` | expeditions, encounter_composition, encounter_roster |
| `restore_class_loadout` | weapons |
| `restore_expedition_runtime` | expeditions, persistence_operations |
| `resume_checkpoint_if_ready` | expeditions |
| `return_to_main_menu` | foundation |
| `revive_player` | life, persistence_operations |
| `roll_kill_trophy` | loot |
| `roll_monster_item` | loot |
| `route_rooms` | expeditions |
| `run_altar_save` | persistence_operations |
| `run_guarded_action` | persistence_operations |
| `run_heart_save` | persistence_operations |
| `run_seed_experiment` | seeds, items, knowledge |
| `run_wallet` | expeditions, affinity_cards, expedition_wallet |
| `save_action_profile` | characters, persistence_operations |
| `save_guest_projection` | characters, persistence_operations, connection_flow |
| `save_local_character` | foundation |
| `save_progress` | foundation |
| `save_session_garden` | persistence_operations |
| `scout_radius` | enemies |
| `scout_snapshot` | enemies, encounter_roster |
| `seed_reserve` | seeds |
| `select_attack_target` | combat |
| `select_class` | classes, weapons, characters |
| `selected_donation` | seeds |
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
| `start_encounter` | expeditions |
| `stored_counts` | weapons |
| `strike_enemy` | combat, affinity_cards |
| `submit_combat` | foundation |
| `submit_motion` | foundation |
| `submit_movement` | foundation |
| `tell` | presentation |
| `tell_profile_action` | persistence_operations, connection_flow, characters, expeditions, garden |
| `toggle_overlay` | presentation |
| `update_combat_tracking` | enemies |
| `update_garden_altar` | seeds |
| `update_pressure` | enemies |
| `update_projectiles` | combat, weapons, classes, enemies |
| `update_ready_panel` | expeditions |
| `upgrade_checkpoint_open` | expeditions |
| `use_class_skill` | classes, combat, weapons, life, affinity_cards |
| `use_heart_research` | knowledge |
| `wallet_for` | expedition_wallet |
| `weapon_effect_color` | presentation |
| `weapon_stats` | weapons, classes, expeditions, combat |
| `wild_entry` | expeditions |
| `world_direction` | terrain |

## Scoped integration wiring

The untouched dispatcher/file remainder keeps its original coverage. These exact fragments and their source locations have the following additional consumers.

| Location | Region | Systems |
|---|---|---|
| `game.gd::_queue_monster_reward` | ar08_lifecycle_1 | player_lifecycle |
| `game.gd::_purchase_expedition_graft` | ar07_vitals_1 | player_vitals |
| `game.gd::show_graft_menu` | ga01a_1 | expedition_grafts |
| `game.gd::_select_class` | ar07_vitals_1 | player_vitals |
| `game.gd::save_guest_projection` | ct01_whole_xp_0 | classes, connection_flow, characters, persistence_operations |
| `game.gd::receive_character` | ct01_whole_xp_0 | classes, connection_flow, characters, persistence_operations |
| `game.gd::_apply_loadout_action` | ct02_0 | weaver_progression, warden_progression, combat_affinity_contracts |
| `game.gd::dodge_player` | ar06_cooldown_1 | player_cooldowns |
| `game.gd::dodge_player` | ar06_cooldown_2 | player_cooldowns |
| `game.gd::dodge_player` | ec01_1 | affinity_cards |
| `game.gd::dodge_player` | cr04c_spirit_0 | spirit_affinity, combat_affinity_contracts, world_snapshot |
| `game.gd::move_player` | ct03_ranger_1 | terrain, ranger_progression |
| `game.gd::move_player` | cr04c_spirit_0 | spirit_affinity, combat_affinity_contracts, world_snapshot |
| `game.gd::move_player` | cr04c_spirit_1 | spirit_affinity, combat_affinity_contracts, world_snapshot |
| `game.gd::send_expedition_state` | experimental_coop_1 | hex_terrain, terrain, connection_flow, garden |
| `game.gd::collect_drop` | experimental_seed_rewards_1 | hex_terrain, loot, terrain |
| `game.gd::_garden_action` | ar08_lifecycle_1 | player_lifecycle |
| `game.gd::_garden_action` | experimental_terrain_1 | hex_terrain, terrain, garden, persistence_operations |
| `game.gd::_garden_action` | experimental_terrain_3 | hex_terrain, terrain, garden, persistence_operations |
| `game.gd::_garden_action` | experimental_terrain_5 | hex_terrain, terrain, garden, persistence_operations |
| `game.gd::_garden_action` | experimental_terrain_7 | hex_terrain, terrain, garden, persistence_operations |
| `game.gd::_garden_action` | experimental_terrain_9 | hex_terrain, terrain, garden, persistence_operations |
| `game.gd::_garden_action` | growth_balance | cultivation_growth |
| `game.gd::_garden_action` | crop_care_adapter | garden_care |
| `game.gd::_garden_action` | gate_range | gate_access |
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
| `game.gd::_process` | ar08_lifecycle_1 | player_lifecycle |
| `game.gd::_process` | ar08_lifecycle_2 | player_lifecycle |
| `game.gd::_process` | ar08_lifecycle_3 | player_lifecycle |
| `game.gd::_process` | ar07_vitals_1 | player_vitals |
| `game.gd::_process` | ar07_vitals_2 | player_vitals |
| `game.gd::_process` | ar07_vitals_3 | player_vitals |
| `game.gd::_process` | ar06_cooldown_1 | player_cooldowns |
| `game.gd::_process` | ar06_cooldown_2 | player_cooldowns |
| `game.gd::_process` | ar06_cooldown_3 | player_cooldowns |
| `game.gd::_process` | ar06_cooldown_4 | player_cooldowns |
| `game.gd::_process` | ar06_cooldown_5 | player_cooldowns |
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
| `game.gd::_process` | display_thief_routes | thief_escape |
| `game.gd::_process` | developer_menu_status | developer_garden |
| `game.gd::_process` | host_show_port_only | connection_flow |
| `game.gd::_process` | show_join_address_button | connection_flow |
| `game.gd::_process` | warden_skill_hud_readout | warden_progression |
| `game.gd::_process` | expanded_core_stale_field | core_combat |
| `game.gd::_process` | class_skill_hover | core_combat |
| `game.gd::_process` | core_hud_state | core_combat |
| `game.gd::_process` | core_stale_terrain | core_combat |
| `game.gd::_process` | prefer_nearest_gate_prompt | gate_access |
| `game.gd::_process` | growth_balance | cultivation_growth |
| `game.gd::_process` | party_panel | party_ui |
| `game.gd::_process` | gate_range | gate_access |
| `game.gd::_process` | garden_prompt | garden_observations |
| `game.gd::_process` | reinforcement_countdown | expedition_pressure |
| `game.gd::can_checkpoint_bank` | gate_range | gate_access |
| `game.gd::at_weapon_gate` | ar08_lifecycle_1 | player_lifecycle |
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
| `game.gd::player_snapshot` | ar08_lifecycle_1 | player_lifecycle |
| `game.gd::player_snapshot` | ar07_vitals_1 | player_vitals |
| `game.gd::player_snapshot` | ar06_cooldown_1 | player_cooldowns |
| `game.gd::player_snapshot` | ct03_ranger_1 | foundation, ranger_progression |
| `game.gd::player_snapshot` | ct01_0 | warden_progression, classes, combat_affinity_contracts |
| `game.gd::player_snapshot` | cr04c_spirit_0 | spirit_affinity, combat_affinity_contracts, world_snapshot |
| `game.gd::player_snapshot` | experimental_coop_1 | hex_terrain, terrain, connection_flow, garden |
| `game.gd::player_snapshot` | replicate_thief_routes | thief_escape |
| `game.gd::player_snapshot` | warden_private_combat_state | warden_progression |
| `game.gd::player_snapshot` | class_aim_owner | ability_aim |
| `game.gd::player_snapshot` | garden_projection | garden_observations |
| `game.gd::_affinity_checkpoint_command` | ar07_vitals_1 | player_vitals |
| `game.gd::_affinity_checkpoint_command` | ar03_wallet_reroll_debit | expedition_wallet, affinity_cards |
| `game.gd::run_guarded_action` | ar04_departure_result | departure_settlement |
| `game.gd::settle_expedition_rewards` | ar05_reward_lifecycle | loot |
| `game.gd::settle_expedition_rewards` | ar04_departure_staging | departure_settlement |
| `game.gd::settle_expedition_rewards` | ar04_departure_finalization | departure_settlement |
| `game.gd::prepare_guarded_exit` | ar05_reward_lifecycle | loot |
| `game.gd::prepare_guarded_exit` | ar04_departure_exit | departure_settlement |
| `game.gd::add_player` | ar03_wallet_initialization | expedition_wallet |
| `game.gd::add_player` | preview_starting_capacity | combat_balance_preview |
| `game.gd::_input` | experimental_placement_cancel | hex_terrain, garden |
| `game.gd::_input` | run_summary_shortcut | expedition_summary |
| `game.gd::_input` | held_aim_release | ability_aim |
| `game.gd::_input` | growth_adapter | garden_cinematics |
| `game.gd::_unhandled_key_input` | experimental_coop_1 | hex_terrain, terrain, connection_flow, garden |
| `game.gd::_unhandled_key_input` | experimental_terrain_1 | hex_terrain, terrain, garden, persistence_operations |
| `game.gd::_unhandled_key_input` | experimental_terrain_3 | hex_terrain, terrain, garden, persistence_operations |
| `game.gd::_unhandled_key_input` | held_aim_press | ability_aim |
| `game.gd::_unhandled_key_input` | held_aim_replaces_press | ability_aim |
| `game.gd::_unhandled_key_input` | core_press | core_combat |
| `game.gd::_unhandled_key_input` | crop_care_adapter | garden_care |
| `game.gd::_physics_process` | ar05_reward_lifecycle | loot |
| `game.gd::_physics_process` | ct02_0 | weaver_progression, warden_progression, combat_affinity_contracts |
| `game.gd::_physics_process` | cr04c_void_0 | void_affinity, combat_affinity_contracts, world_snapshot |
| `game.gd::_physics_process` | cr04c_spirit_0 | spirit_affinity, combat_affinity_contracts, world_snapshot |
| `game.gd::_physics_process` | wood_affinity_1 | wood_affinity, combat_affinity_contracts |
| `game.gd::_physics_process` | thorn_tick | thorn_affinity, combat_affinity_contracts |
| `game.gd::_physics_process` | experimental_heart_assimilation | hex_terrain |
| `game.gd::_physics_process` | growth_balance | cultivation_growth |
| `game.gd::plant_seed` | cleanup_feedback | persistence_operations |
| `game.gd::plant_seed` | guarded_gameplay_writer | persistence_operations |
| `game.gd::plant_seed` | ui_copy | ui_copy |
| `game.gd::plant_seed` | plant_seed_g07 | garden_conduit |
| `game.gd::plant_seed` | growth_balance | cultivation_growth |
| `game.gd::plant_seed` | crop_care_adapter | garden_care |
| `game.gd::harvest` | guarded_garden_actions | persistence_operations, seeds, garden, knowledge, items, garden_care |
| `game.gd::harvest` | crop_care_adapter | garden_care |
| `game.gd::_harvest` | experimental_terrain_1 | hex_terrain, terrain, garden, persistence_operations |
| `game.gd::garden_action` | guarded_garden_actions | persistence_operations, foundation, ability_aim, core_combat, cultivation_growth |
| `game.gd::garden_action` | guarded_gameplay_writer | persistence_operations |
| `game.gd::garden_action` | class_aim_command | ability_aim |
| `game.gd::garden_action` | core_cast | core_combat |
| `game.gd::garden_action` | growth_balance | cultivation_growth |
| `game.gd::bank_checkpoint_item` | guarded_garden_actions | persistence_operations, items, ui_copy, garden_returns |
| `game.gd::bank_checkpoint_item` | guarded_gameplay_writer | persistence_operations |
| `game.gd::bank_checkpoint_item` | ui_copy | ui_copy |
| `game.gd::bank_checkpoint_item` | garden_returns | garden_returns |
| `game.gd::identify_seed` | garden_returns | garden_returns |
| `game.gd::update_pressure` | reinforcement_service | expedition_pressure |
| `game.gd::attack_hints_snapshot` | ar11_scout_hint_projection | enemy_attack_execution, enemy_attack_plan, world_snapshot |
| `game.gd::attack_hints_snapshot` | thorn_fields | thorn_affinity, combat_affinity_contracts |
| `game.gd::attack_hints_snapshot` | publish_glasscap_formation | glasscap_feints |
| `game.gd::attack_hints_snapshot` | warden_anchor_ground_marker | warden_progression |
| `game.gd::attack_hints_snapshot` | core_terrain_projection | core_combat |
| `game.gd::attack_hints_snapshot` | boss_lair_fights | boss_lair_fights |
| `game.gd::attack_hints_snapshot` | heavy_and_support | enemy_attack_plan |
| `game.gd::attack_hints_snapshot` | enemy_attack_plan | enemy_attack_plan |
| `game.gd::attack_hints_snapshot` | reinforcement_hints | expedition_pressure |
| `game.gd::at_garden_station` | ar08_lifecycle_1 | player_lifecycle |
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
| `game.gd::current_mutations` | enemy_attack_plan | enemy_attack_plan |
| `game.gd::make_scout` | cb06_12 | enemy_balance |
| `game.gd::make_scout` | preview_juvenile_hp | combat_balance_preview |
| `game.gd::make_scout` | heavy_and_support | enemy_attack_plan |
| `game.gd::make_scout` | species_variants | enemy_attack_plan |
| `game.gd::apply_weapon_hit` | ct05_oracle_1 | oracle_progression |
| `game.gd::apply_weapon_hit` | cr05_shared_grave_0 | combat_affinity_contracts, weapons, classes, life |
| `game.gd::apply_weapon_hit` | cr05_shared_grave_1 | combat_affinity_contracts, weapons, classes, life |
| `game.gd::apply_weapon_hit` | cr05_grafts_0 | combat_affinity_contracts, weapons, classes, life |
| `game.gd::apply_weapon_hit` | cr05_grafts_1 | combat_affinity_contracts, weapons, classes, life |
| `game.gd::apply_weapon_hit` | cb07_8 | expedition_sustain |
| `game.gd::apply_weapon_hit` | cb06_5 | enemy_balance |
| `game.gd::apply_weapon_hit` | healing_roll_1 | healing_rolls |
| `game.gd::apply_weapon_hit` | cb03_kill_heal | weapon_balance |
| `game.gd::apply_weapon_hit` | preview_kill_heal | combat_balance_preview |
| `game.gd::apply_weapon_hit` | preview_burst_threshold | combat_balance_preview |
| `game.gd::apply_weapon_hit` | preview_normalized_threat | combat_balance_preview |
| `game.gd::apply_weapon_hit` | preview_boss_exposure | combat_balance_preview |
| `game.gd::apply_weapon_hit` | preview_bark_reduction | combat_balance_preview |
| `game.gd::apply_weapon_hit` | vitals_kill_healing | combat_vitals |
| `game.gd::apply_weapon_hit` | vitals_bark_guard | combat_vitals |
| `game.gd::apply_weapon_hit` | core_hit_damage | core_combat |
| `game.gd::reset_encounter` | ar05_reward_lifecycle | loot |
| `game.gd::reset_encounter` | experimental_certified_leader | hex_terrain, terrain |
| `game.gd::reset_encounter` | experimental_floor_diagnostic | hex_terrain, terrain |
| `game.gd::reset_encounter` | experimental_terrain_1 | hex_terrain, terrain, garden, persistence_operations |
| `game.gd::reset_encounter` | experimental_terrain_3 | hex_terrain, terrain, garden, persistence_operations |
| `game.gd::reset_encounter` | cb06_2 | enemy_balance |
| `game.gd::use_class_skill` | ar06_cooldown_1 | player_cooldowns |
| `game.gd::use_class_skill` | ar06_cooldown_2 | player_cooldowns |
| `game.gd::use_class_skill` | ec01_1 | affinity_cards |
| `game.gd::use_class_skill` | ct05_oracle_1 | oracle_progression |
| `game.gd::use_class_skill` | ct05_oracle_4 | oracle_progression |
| `game.gd::use_class_skill` | ct04_reaper_1 | classes, combat, weapons, life, reaper_progression |
| `game.gd::use_class_skill` | ct04_reaper_3 | classes, combat, weapons, life, reaper_progression |
| `game.gd::use_class_skill` | ct04_reaper_4 | classes, combat, weapons, life, reaper_progression |
| `game.gd::use_class_skill` | ct03_ranger_1 | classes, combat, weapons, life, ranger_progression |
| `game.gd::use_class_skill` | ct03_ranger_3 | classes, combat, weapons, life, ranger_progression |
| `game.gd::use_class_skill` | ct03_ranger_4 | classes, combat, weapons, life, ranger_progression |
| `game.gd::use_class_skill` | ct02_1 | weaver_progression, warden_progression, combat_affinity_contracts |
| `game.gd::use_class_skill` | ct01_2 | warden_progression, classes, combat_affinity_contracts |
| `game.gd::use_class_skill` | cr05_focus_0 | classes, combat_affinity_contracts |
| `game.gd::use_class_skill` | cr05_focus_1 | classes, combat_affinity_contracts |
| `game.gd::use_class_skill` | wood_affinity_1 | wood_affinity, combat_affinity_contracts |
| `game.gd::use_class_skill` | cb07_12 | expedition_sustain |
| `game.gd::use_class_skill` | cb07_13 | expedition_sustain |
| `game.gd::use_class_skill` | healing_roll_2 | healing_rolls |
| `game.gd::use_class_skill` | healing_roll_3 | healing_rolls |
| `game.gd::use_class_skill` | healing_roll_7 | healing_rolls |
| `game.gd::use_class_skill` | cb04_8 | class_balance |
| `game.gd::use_class_skill` | cb04_9 | class_balance |
| `game.gd::use_class_skill` | cb04_12 | class_balance |
| `game.gd::use_class_skill` | cb03_class_heal_bonus | weapon_balance |
| `game.gd::use_class_skill` | preview_bonus_heal | combat_balance_preview |
| `game.gd::use_class_skill` | preview_capped_self_heal | combat_balance_preview |
| `game.gd::use_class_skill` | vitals_class_bonus_heal | combat_vitals |
| `game.gd::use_class_skill` | vitals_class_capped_heal | combat_vitals |
| `game.gd::use_class_skill` | class_cast_audio | event_audio |
| `game.gd::use_class_skill` | subclass_finish_on_echo | warden_progression |
| `game.gd::use_class_skill` | aimed_target_init | ability_aim |
| `game.gd::use_class_skill` | core_animation_guard | core_combat |
| `game.gd::receive_details` | experimental_coop_1 | hex_terrain, terrain, connection_flow, garden |
| `game.gd::receive_details` | experimental_coop_2 | hex_terrain, terrain, connection_flow, garden |
| `game.gd::receive_details` | core_owner_clock | core_combat |
| `game.gd::guest_combat_events` | core_floor_event_scope | core_combat |
| `game.gd::send_garden_action` | cleanup_feedback | persistence_operations |
| `game.gd::send_garden_action` | class_aim_log | ability_aim |
| `game.gd::send_garden_action` | core_cast_log | core_combat |
| `game.gd::inventory_ui_data` | core_inventory_summary | core_combat, combat_affinity_contracts, items |
| `game.gd::_finish_combat` | experimental_seed_rewards_1 | hex_terrain, loot, terrain |
| `game.gd::_finish_combat` | experimental_seed_rewards_2 | hex_terrain, loot, terrain |
| `game.gd::_finish_combat` | preview_ranged_threshold | combat_balance_preview |
| `game.gd::_finish_combat` | vitals_ranged_observation | combat_vitals |
| `game.gd::_finish_combat` | vitals_ranged_threshold | combat_vitals |
| `game.gd::emit_combat_event` | ct01_0 | warden_progression, classes, combat_affinity_contracts |
| `game.gd::emit_combat_event` | guarded_expedition | persistence_operations, presentation, expedition_sustain, core_combat, warden_progression |
| `game.gd::emit_combat_event` | cb07_2 | expedition_sustain |
| `game.gd::emit_combat_event` | core_shape_payload | core_combat |
| `game.gd::emit_combat_event` | subclass_release_label | warden_progression |
| `game.gd::emit_combat_event` | authored_core_label | core_combat |
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
| `game.gd::_ready` | experimental_terrain_1 | hex_terrain, terrain, garden, persistence_operations |
| `game.gd::_ready` | experimental_terrain_3 | hex_terrain, terrain, garden, persistence_operations |
| `game.gd::_ready` | production_route | persistence_operations, persistence_authorization, persistence_recovery_plan, persistence_save_access, menus, characters, developer_garden, connection_flow, foundation, menu_layout, event_audio, soundscape |
| `game.gd::_ready` | shared_menu_button_roots | menu_layout |
| `game.gd::_ready` | event_audio_node | event_audio |
| `game.gd::_ready` | soundscape_lifetime | soundscape |
| `game.gd::_ready` | developer_game_settings | developer_garden |
| `game.gd::update_projectiles` | ar08_lifecycle_1 | player_lifecycle |
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
| `game.gd::grant_guard` | cb04_7 | class_balance |
| `game.gd::encounter_health` | cb06_4 | enemy_balance |
| `game.gd::encounter_health` | preview_guest_enemy_hp | combat_balance_preview |
| `game.gd::restore_class_loadout` | ar07_vitals_1 | player_vitals |
| `game.gd::_init` | preview_guest_storage | combat_balance_preview |
| `affinity_cards.gd` | ar08_lifecycle_1 | player_lifecycle |
| `affinity_cards.gd` | ar08_lifecycle_2 | player_lifecycle |
| `assets/terrain_m02/experimental/experiment_garden.gd` | ar08_lifecycle_1 | player_lifecycle |
| `assets/terrain_m02/experimental/experiment_garden.gd` | ar08_lifecycle_2 | player_lifecycle |
| `class_tree_access.gd` | ar08_lifecycle_1 | player_lifecycle |
| `class_tree_access.gd` | ar08_lifecycle_2 | player_lifecycle |
| `fire_combat.gd` | ar08_lifecycle_1 | player_lifecycle |
| `fire_combat.gd` | ar08_lifecycle_2 | player_lifecycle |
| `fire_combat.gd` | ar08_lifecycle_3 | player_lifecycle |
| `fire_combat.gd` | ar08_lifecycle_4 | player_lifecycle |
| `fire_combat.gd` | ar08_lifecycle_5 | player_lifecycle |
| `inventory_drop_visuals.gd` | ar08_lifecycle_1 | player_lifecycle, items |
| `inventory_drop_visuals.gd` | ar08_lifecycle_2 | player_lifecycle, items |
| `native_grafts.gd` | ar08_lifecycle_1 | player_lifecycle |
| `native_grafts.gd` | ar08_lifecycle_2 | player_lifecycle |
| `native_grafts.gd` | ar08_lifecycle_3 | player_lifecycle |
| `oracle_omens.gd` | ar08_lifecycle_1 | player_lifecycle |
| `oracle_omens.gd` | ar08_lifecycle_2 | player_lifecycle |
| `oracle_omens.gd` | ar08_lifecycle_3 | player_lifecycle |
| `oracle_omens.gd` | ar08_lifecycle_4 | player_lifecycle |
| `thorn_affinity.gd` | ar08_lifecycle_1 | player_lifecycle |
| `thorn_affinity.gd` | ar08_lifecycle_2 | player_lifecycle |
| `thorn_affinity.gd` | ar08_lifecycle_3 | player_lifecycle |
| `thorn_affinity.gd` | ar08_lifecycle_4 | player_lifecycle |
| `thorn_affinity.gd` | ar08_lifecycle_5 | player_lifecycle |
| `void_affinity.gd` | ar08_lifecycle_1 | player_lifecycle |
| `void_affinity.gd` | ar08_lifecycle_2 | player_lifecycle |
| `void_affinity.gd` | ar08_lifecycle_3 | player_lifecycle |
| `ward_responses.gd` | ar08_lifecycle_1 | player_lifecycle |
| `combat_vitals.gd` | ar07_vitals_1 | player_vitals |
| `expedition_sustain.gd` | ar07_vitals_1 | player_vitals |
| `expedition_sustain.gd` | ar07_vitals_2 | player_vitals |
| `diagnostic_journal.gd` | ar08_lifecycle_1 | player_lifecycle, diagnostics |
| `diagnostic_journal.gd` | ar08_lifecycle_3 | player_lifecycle, diagnostics |
| `diagnostic_journal.gd` | ar07_vitals_1 | player_vitals, diagnostics |
| `diagnostic_journal.gd` | ar07_vitals_3 | player_vitals, diagnostics |
| `diagnostic_journal.gd` | ar06_cooldown_1 | player_cooldowns, diagnostics |
| `diagnostic_journal.gd` | ar06_cooldown_3 | player_cooldowns, diagnostics |
| `oracle_combat.gd` | ar08_lifecycle_1 | player_lifecycle |
| `oracle_combat.gd` | ar08_lifecycle_2 | player_lifecycle |
| `oracle_combat.gd` | ar08_lifecycle_3 | player_lifecycle |
| `oracle_combat.gd` | ar07_vitals_1 | player_vitals |
| `oracle_combat.gd` | ar07_vitals_2 | player_vitals |
| `oracle_combat.gd` | ar06_cooldown_1 | player_cooldowns |
| `oracle_combat.gd` | ar06_cooldown_2 | player_cooldowns |
| `ranger_combat.gd` | ar08_lifecycle_1 | player_lifecycle |
| `ranger_combat.gd` | ar08_lifecycle_2 | player_lifecycle |
| `ranger_combat.gd` | ar08_lifecycle_3 | player_lifecycle |
| `ranger_combat.gd` | ar08_lifecycle_4 | player_lifecycle |
| `ranger_combat.gd` | ar08_lifecycle_5 | player_lifecycle |
| `ranger_combat.gd` | ar07_vitals_1 | player_vitals |
| `ranger_combat.gd` | ar07_vitals_2 | player_vitals |
| `ranger_combat.gd` | ar06_cooldown_1 | player_cooldowns |
| `ranger_combat.gd` | ar06_cooldown_2 | player_cooldowns |
| `reaper_combat.gd` | ar08_lifecycle_1 | player_lifecycle |
| `reaper_combat.gd` | ar08_lifecycle_2 | player_lifecycle |
| `reaper_combat.gd` | ar08_lifecycle_3 | player_lifecycle |
| `reaper_combat.gd` | ar07_vitals_1 | player_vitals |
| `reaper_combat.gd` | ar07_vitals_2 | player_vitals |
| `reaper_combat.gd` | ar06_cooldown_1 | player_cooldowns |
| `reaper_combat.gd` | ar06_cooldown_2 | player_cooldowns |
| `reaper_combat.gd` | ar06_cooldown_3 | player_cooldowns |
| `reaper_combat.gd` | ar06_cooldown_4 | player_cooldowns |
| `weaver_combat.gd` | ar08_lifecycle_1 | player_lifecycle |
| `weaver_combat.gd` | ar08_lifecycle_2 | player_lifecycle |
| `weaver_combat.gd` | ar08_lifecycle_3 | player_lifecycle |
| `weaver_combat.gd` | ar06_cooldown_1 | player_cooldowns |
| `weaver_combat.gd` | ar06_cooldown_2 | player_cooldowns |
| `weaver_combat.gd` | ar06_cooldown_3 | player_cooldowns |
| `game_transaction.gd` | receipt_owner | loot |
| `game_transaction.gd` | legacy_capture | loot |
| `game_transaction.gd` | legacy_rollback | loot |
| `game_transaction.gd` | legacy_commit | loot |
| `game_transaction.gd` | guarded_owner | loot |
| `game_transaction.gd` | guarded_capture | loot |
| `game_transaction.gd` | guarded_missing_outcome | loot |
| `game_transaction.gd` | guarded_uncertainty | loot |
| `game_transaction.gd` | guarded_commit | loot |
| `game_transaction.gd` | guarded_rollback | loot |
| `spirit_affinity.gd` | ar08_lifecycle_1 | player_lifecycle |
| `spirit_affinity.gd` | ar08_lifecycle_2 | player_lifecycle |
| `spirit_affinity.gd` | ar08_lifecycle_3 | player_lifecycle |
| `spirit_affinity.gd` | ec01_1 | affinity_cards |
| `storm_affinity.gd` | ar08_lifecycle_1 | player_lifecycle |
| `storm_affinity.gd` | ar08_lifecycle_2 | player_lifecycle |
| `storm_affinity.gd` | ar08_lifecycle_3 | player_lifecycle |
| `storm_affinity.gd` | ec01_1 | affinity_cards |
| `wood_affinity.gd` | ar08_lifecycle_1 | player_lifecycle |
| `wood_affinity.gd` | ar08_lifecycle_2 | player_lifecycle |
| `wood_affinity.gd` | ar08_lifecycle_3 | player_lifecycle |
| `wood_affinity.gd` | ar08_lifecycle_4 | player_lifecycle |
| `wood_affinity.gd` | ar08_lifecycle_5 | player_lifecycle |
| `wood_affinity.gd` | ec01_1 | affinity_cards |
| `vital_combat.gd` | ar07_vitals_1 | player_vitals |
| `vital_combat.gd` | ar07_vitals_2 | player_vitals |
| `vital_combat.gd` | ar07_vitals_3 | player_vitals |
| `vital_combat.gd` | ar07_vitals_4 | player_vitals |
| `vital_combat.gd` | ar07_vitals_5 | player_vitals |
| `vital_combat.gd` | ec01_1 | affinity_cards |
| `water_combat.gd` | ec01_1 | affinity_cards |
| `water_combat.gd` | ec01_2 | affinity_cards |
| `frost_combat.gd` | ec01_1 | affinity_cards |
| `combat_action_events.gd` | ar08_lifecycle_1 | player_lifecycle |
| `combat_action_events.gd` | ar08_lifecycle_2 | player_lifecycle |
| `combat_action_events.gd` | ar08_lifecycle_3 | player_lifecycle |
| `combat_action_events.gd` | ar08_lifecycle_4 | player_lifecycle |
| `combat_action_events.gd` | ar08_lifecycle_5 | player_lifecycle |
| `combat_action_events.gd` | ec01_1 | affinity_cards |
| `combat_ruleset.gd` | ga01a_2 | expedition_grafts, combat_affinity_contracts, connection_flow |
| `affinity_build.gd` | ar07_vitals_1 | player_vitals |
| `affinity_build.gd` | ar07_vitals_2 | player_vitals |
| `affinity_build.gd` | ar01_graft_combat_values | expedition_grafts |
| `affinity_build.gd` | ec01_display_1 | combat_affinity_contracts, plant_affinities, ui_copy |
| `affinity_build.gd` | ec01_playtest_1 | combat_affinity_contracts, plant_affinities, ui_copy |
| `affinity_build.gd` | ct05_oracle_1 | oracle_progression, class_tree_access |
| `affinity_build.gd` | ct05_oracle_2 | oracle_progression, class_tree_access |
| `core_footprint.gd` | cr04b_thorn_1 | thorn_affinity, combat_affinity_contracts |
| `warden_tree.gd` | ct01_1 | warden_progression, classes, combat_affinity_contracts |
| `warden_combat.gd` | ar08_lifecycle_1 | player_lifecycle |
| `warden_combat.gd` | ar08_lifecycle_2 | player_lifecycle |
| `warden_combat.gd` | ar08_lifecycle_3 | player_lifecycle |
| `warden_combat.gd` | ar08_lifecycle_4 | player_lifecycle |
| `warden_combat.gd` | ar08_lifecycle_6 | player_lifecycle |
| `warden_combat.gd` | ar08_lifecycle_7 | player_lifecycle |
| `warden_combat.gd` | ar08_lifecycle_8 | player_lifecycle |
| `warden_combat.gd` | ar06_cooldown_1 | player_cooldowns |
| `warden_combat.gd` | ar06_cooldown_2 | player_cooldowns |
| `warden_combat.gd` | ar06_cooldown_3 | player_cooldowns |
| `warden_combat.gd` | ar06_cooldown_4 | player_cooldowns |
| `warden_combat.gd` | ct02_2 | weaver_progression, warden_progression, combat_affinity_contracts |
| `warden_combat.gd` | ct01_holdfast_1 | warden_progression, combat, life |
| `warden_combat.gd` | ct01_holdfast_2 | warden_progression, combat, life |
| `warden_combat.gd` | ct01_holdfast_3 | warden_progression, combat, life |
| `warden_combat.gd` | ct01_holdfast_4 | warden_progression, combat, life |
| `warden_combat.gd` | ct01_1 | warden_progression, classes, combat_affinity_contracts |
| `warden_combat.gd` | ct01_4 | warden_progression, classes, combat_affinity_contracts |
| `warden_combat.gd` | ct01_5 | warden_progression, classes, combat_affinity_contracts |
| `warden_combat.gd` | ct01_6 | warden_progression, classes, combat_affinity_contracts |
| `warden_combat.gd` | ct01_12 | warden_progression, classes, combat_affinity_contracts |
| `warden_combat.gd` | ct01_13 | warden_progression, classes, combat_affinity_contracts |
| `warden_combat.gd` | ct01_15 | warden_progression, classes, combat_affinity_contracts |
| `warden_combat.gd` | ct01_16 | warden_progression, classes, combat_affinity_contracts |
| `warden_combat.gd` | ct01_17 | warden_progression, classes, combat_affinity_contracts |
| `weapon_contact.gd` | ct04_reaper_1 | combat, reaper_progression |
| `weapon_contact.gd` | ct03_ranger_1 | combat, ranger_progression |
| `weapon_contact.gd` | cr05_grafts_1 | combat_affinity_contracts, weapons, classes, life |
| `weapon_contact.gd` | cr05_grafts_2 | combat_affinity_contracts, weapons, classes, life |
| `weapon_contact.gd` | cr04b_thorn_1 | thorn_affinity, combat_affinity_contracts |
| `weapon_contact.gd` | cr03_melee | frost_affinity |
| `weapon_contact.gd` | cr02_secondary | combat_affinity_contracts |
| `weapon_contact.gd` | cr02_melee | combat_affinity_contracts |
| `network_movement.gd` | ar08_lifecycle_1 | player_lifecycle, presentation |
| `network_movement.gd` | ar08_lifecycle_2 | player_lifecycle, presentation |
| `network_movement.gd` | experimental_coop_1 | hex_terrain, terrain, connection_flow, garden |
| `network_movement.gd` | experimental_coop_2 | hex_terrain, terrain, connection_flow, garden |
| `diagnostics_boot.gd` | experimental_coop_1 | hex_terrain, terrain, connection_flow, garden |
| `diagnostics_boot.gd` | experimental_coop_2 | hex_terrain, terrain, connection_flow, garden |
| `root_ui.gd` | cr04c_void_hud_1 | presentation, world_snapshot, void_affinity, spirit_affinity, storm_affinity |
| `root_ui.gd` | health_pool_7 | health_pool_hud |
| `root_ui.gd` | health_pool_5 | health_pool_hud |
| `root_ui.gd` | health_pool_4 | health_pool_hud |
| `root_ui.gd` | health_pool_3 | health_pool_hud |
| `root_ui.gd` | health_pool_2 | health_pool_hud |
| `root_ui.gd` | health_pool_1 | health_pool_hud |
| `root_ui.gd` | cb02_root_ui_3_18 | combat_balance_preview |
| `root_ui.gd` | cb02_root_ui_2_17 | combat_balance_preview |
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
| `party_travel.gd` | ar08_lifecycle_1 | player_lifecycle |
| `party_travel.gd` | ar08_lifecycle_2 | player_lifecycle |
| `party_travel.gd` | ar08_lifecycle_3 | player_lifecycle |
| `party_travel.gd` | ct05_oracle_1 | oracle_progression, class_tree_access |
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
| `content_validator.gd` | validate_warden_skill_modes | warden_progression |
| `content_validator.gd` | validate_warden_parents | warden_progression |
| `content_validator.gd` | validate_warden_node_effects | warden_progression |
| `content_validator.gd` | garden_catalog | garden_observations |
| `garden_visuals.gd` | meadow_paths_and_flowers | garden_life |
| `garden_visuals.gd` | accents_growth | garden_cinematics |
| `garden_visuals.gd` | accents_adapter | garden_zones, garden_life |
| `garden_visuals.gd` | observation_anchors | garden_observations |
| `stage.gd` | ar08_lifecycle_1 | player_lifecycle, presentation |
| `stage.gd` | ar08_lifecycle_2 | player_lifecycle, presentation |
| `stage.gd` | ar08_lifecycle_3 | player_lifecycle, presentation |
| `stage.gd` | ar08_lifecycle_4 | player_lifecycle, presentation |
| `stage.gd` | ar08_lifecycle_5 | player_lifecycle, presentation |
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
| `garden_interaction_service.gd` | ar08_lifecycle_1 | player_lifecycle |
| `garden_interaction_service.gd` | ar08_lifecycle_2 | player_lifecycle |
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
| `garden_crop_service.gd` | ar08_lifecycle_1 | player_lifecycle |
| `garden_crop_service.gd` | ar08_lifecycle_2 | player_lifecycle |
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
| `inventory_panel.gd` | ga01a_1 | expedition_grafts, items, presentation |
| `inventory_panel.gd` | core_equipment_details | core_combat, combat_affinity_contracts, items |
| `inventory_panel.gd` | core_equipment_selection | core_combat |
| `inventory_panel.gd` | core_equipment_entries | core_combat, combat_affinity_contracts, items |
| `inventory_panel.gd` | core_equipment_heading | core_combat |
| `inventory_panel.gd` | core_equipment_label | core_combat |
| `inventory_panel.gd` | ui_copy_3 | ui_copy |
| `inventory_panel.gd` | ui_copy_2 | ui_copy |
| `inventory_panel.gd` | ui_copy_1 | ui_copy |
| `inventory_panel.gd` | ui_copy_0 | ui_copy |
| `garden_altar_panel.gd` | ui_copy_3 | ui_copy |
| `garden_altar_panel.gd` | ui_copy_2 | ui_copy |
| `garden_altar_panel.gd` | ui_copy_1 | ui_copy |
| `garden_altar_panel.gd` | ui_copy_0 | ui_copy |
| `loadout_panel.gd` | ec01_playtest_2 | class_tree_access, combat_affinity_contracts, weapons |
| `loadout_panel.gd` | ec01_playtest_4 | class_tree_access, combat_affinity_contracts, weapons |
| `loadout_panel.gd` | ec01_playtest_11 | class_tree_access, combat_affinity_contracts, weapons |
| `loadout_panel.gd` | starting_focus_preview_labels | class_tree_access, oracle_progression |
| `loadout_panel.gd` | starting_focus_preview_layout | class_tree_access, oracle_progression |
| `loadout_panel.gd` | starting_focus_preview_effects | class_tree_access, oracle_progression |
| `loadout_panel.gd` | ct05_oracle_1 | oracle_progression, class_tree_access |
| `loadout_panel.gd` | ct05_oracle_2 | oracle_progression, class_tree_access |
| `loadout_panel.gd` | class_location_copy | class_tree_access |
| `loadout_panel.gd` | open_class_tree_from_crafting | class_tree_access |
| `loadout_panel.gd` | ui_copy_9 | ui_copy |
| `loadout_panel.gd` | ui_copy_7 | ui_copy |
| `loadout_panel.gd` | ui_copy_6 | ui_copy |
| `loadout_panel.gd` | ui_copy_5 | ui_copy |
| `loadout_panel.gd` | ui_copy_4 | ui_copy |
| `loadout_panel.gd` | ui_copy_2 | ui_copy |
| `loadout_panel.gd` | ui_copy_1 | ui_copy |
| `loadout_panel.gd` | ui_copy_0 | ui_copy |
| `progression_panel.gd` | ct02_1 | weaver_progression, warden_progression, combat_affinity_contracts |
| `progression_panel.gd` | experimental_terrain_1 | hex_terrain, terrain, garden, persistence_operations |
| `progression_panel.gd` | refund_station_tooltip | class_tree_access |
| `progression_panel.gd` | class_details_placeholder | class_tree_access |
| `progression_panel.gd` | shared_tree_base_scroll | class_tree_access |
| `progression_panel.gd` | scroll_classes_to_base | class_tree_access |
| `progression_panel.gd` | clear_highlight_on_class_tab_switch | class_tree_access |
| `progression_panel.gd` | hide_retired_seed_actions | class_tree_access |
| `progression_panel.gd` | stable_progression_rows | class_tree_access |
| `progression_panel.gd` | open_class_tree_page | class_tree_access |
| `progression_panel.gd` | class_page_return | class_tree_access |
| `progression_panel.gd` | crafting_navigation_state | class_tree_access |
| `progression_panel.gd` | ui_copy_8 | ui_copy |
| `progression_panel.gd` | ui_copy_7 | ui_copy |
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
| `class_catalog.gd` | ec01_speed_modifier_text | ui_copy, classes, weapons |
| `class_catalog.gd` | ct05_oracle_1 | oracle_progression, class_tree_access |
| `class_catalog.gd` | ct05_oracle_2 | oracle_progression, class_tree_access |
| `class_catalog.gd` | ct04_reaper_1 | classes, reaper_progression |
| `class_catalog.gd` | ct04_reaper_2 | classes, reaper_progression |
| `class_catalog.gd` | ct03_ranger_1 | classes, ranger_progression |
| `class_catalog.gd` | ct03_ranger_2 | classes, ranger_progression |
| `class_catalog.gd` | ct02_1 | weaver_progression, warden_progression, combat_affinity_contracts |
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
| `skill_catalog.gd` | ct04_reaper_2 | classes, reaper_progression |
| `skill_catalog.gd` | healing_roll_0 | healing_rolls |
| `skill_catalog.gd` | healing_roll_2 | healing_rolls |
| `skill_catalog.gd` | healing_roll_3 | healing_rolls |
| `skill_catalog.gd` | healing_roll_4 | healing_rolls |
| `skill_catalog.gd` | cb04_5 | class_balance |
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
| `elite_enemy.gd` | cr04c_spirit_1 | spirit_affinity, core_combat, combat_affinity_contracts |
| `elite_enemy.gd` | cr03_tick | frost_affinity |
| `elite_enemy.gd` | cb06_0 | enemy_balance |
| `elite_enemy.gd` | glasscap_elite_recovery | glasscap_feints |
| `elite_enemy.gd` | flee_before_targeting | thief_escape |
| `elite_enemy.gd` | gate_elite_learned_approach | wilds_skill_tactics |
| `elite_enemy.gd` | signatures_0 | enemy_attack_plan, encounter_composition |
| `elite_enemy.gd` | signatures_1 | enemy_attack_plan, encounter_composition |
| `elite_enemy.gd` | signatures_2 | enemy_attack_plan, encounter_composition |
| `elite_enemy.gd` | signatures_3 | enemy_attack_plan, encounter_composition |
| `elite_enemy.gd` | species_variants_2 | enemy_attack_plan |
| `elite_enemy.gd` | species_variants_1 | enemy_attack_plan |
| `elite_enemy.gd` | species_variants_0 | enemy_attack_plan |
| `elite_enemy.gd` | enemy_attack_plan_4 | enemy_attack_plan |
| `elite_enemy.gd` | enemy_attack_plan_2 | enemy_attack_plan |
| `elite_enemy.gd` | enemy_attack_plan_0 | enemy_attack_plan |
| `elite_enemy.gd` | signatures_resolve_repeat | enemy_attack_plan, encounter_composition |
| `enemy_behaviors.gd` | ar11_execution_1 | enemy_attack_execution |
| `enemy_behaviors.gd` | ar11_execution_2 | enemy_attack_execution |
| `enemy_behaviors.gd` | ar11_execution_3 | enemy_attack_execution |
| `enemy_behaviors.gd` | ar11_execution_4 | enemy_attack_execution |
| `enemy_behaviors.gd` | ar11_execution_5 | enemy_attack_execution |
| `enemy_behaviors.gd` | ar11_execution_6 | enemy_attack_execution |
| `enemy_behaviors.gd` | ar11_execution_7 | enemy_attack_execution |
| `enemy_behaviors.gd` | ar11_execution_8 | enemy_attack_execution |
| `enemy_behaviors.gd` | ar11_execution_9 | enemy_attack_execution |
| `enemy_behaviors.gd` | ar11_execution_10 | enemy_attack_execution |
| `enemy_behaviors.gd` | ar11_execution_11 | enemy_attack_execution |
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
| `enemy_behaviors.gd` | resolve_learned_canopy_and_glass | wilds_skill_tactics |
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
| `combat_status.gd` | ar11_execution_1 | enemy_attack_execution |
| `combat_status.gd` | ct05_oracle_1 | oracle_progression |
| `combat_status.gd` | ct05_oracle_2 | oracle_progression |
| `combat_status.gd` | ct05_oracle_3 | oracle_progression |
| `combat_status.gd` | ct04_reaper_1 | combat, reaper_progression |
| `combat_status.gd` | ct04_reaper_2 | combat, reaper_progression |
| `combat_status.gd` | ct03_ranger_1 | combat, ranger_progression |
| `combat_status.gd` | ct03_ranger_2 | combat, ranger_progression |
| `combat_status.gd` | ct02_1 | weaver_progression, warden_progression, combat_affinity_contracts |
| `combat_status.gd` | ct01_holdfast_1 | warden_progression, combat, life |
| `combat_status.gd` | cr04c_void_1 | void_affinity, core_combat, combat_affinity_contracts |
| `combat_status.gd` | cr04c_spirit_1 | spirit_affinity, core_combat, combat_affinity_contracts |
| `combat_status.gd` | cr04c_spirit_2 | spirit_affinity, core_combat, combat_affinity_contracts |
| `combat_status.gd` | cr04c_storm_1 | storm_affinity, core_combat, combat_affinity_contracts |
| `combat_status.gd` | cr04c_storm_2 | storm_affinity, core_combat, combat_affinity_contracts |
| `combat_status.gd` | cr04b_wood_1 | wood_affinity, combat_affinity_contracts |
| `combat_status.gd` | cr04b_thorn_1 | thorn_affinity, combat_affinity_contracts |
| `combat_status.gd` | cr04a_affinity_1 | fire_affinity, water_affinity, vital_affinity, combat_affinity_contracts |
| `combat_status.gd` | cr04a_affinity_4 | fire_affinity, water_affinity, vital_affinity, combat_affinity_contracts |
| `combat_status.gd` | cr04a_affinity_5 | fire_affinity, water_affinity, vital_affinity, combat_affinity_contracts |
| `combat_status.gd` | subclass_follow_status_lifetime | warden_progression |
| `combat_status.gd` | subclass_prepared_label | warden_progression |
| `combat_status.gd` | warden_prepared_status_name | warden_progression |
| `combat_status.gd` | observe_route_denial | wilds_skill_tactics |
| `combat_status.gd` | expanded_core_link_label | core_combat |
| `combat_status.gd` | strike_mark_tint | core_combat |
| `combat_status.gd` | strike_mark_label | core_combat |
| `combat_status.gd` | core_root_primitive | core_combat |
| `boss_encounters.gd` | ar11_execution_1 | enemy_attack_execution |
| `boss_encounters.gd` | ar11_execution_2 | enemy_attack_execution |
| `boss_encounters.gd` | ar11_execution_3 | enemy_attack_execution |
| `boss_encounters.gd` | ar11_execution_4 | enemy_attack_execution |
| `boss_encounters.gd` | ar11_execution_5 | enemy_attack_execution |
| `boss_encounters.gd` | ar11_execution_6 | enemy_attack_execution |
| `boss_encounters.gd` | ar11_execution_7 | enemy_attack_execution |
| `boss_encounters.gd` | ar11_execution_8 | enemy_attack_execution |
| `boss_encounters.gd` | ct05_oracle_1 | oracle_progression |
| `boss_encounters.gd` | ct01_1 | warden_progression, classes, combat_affinity_contracts |
| `boss_encounters.gd` | cb06_0 | enemy_balance |
| `boss_encounters.gd` | cb06_1 | enemy_balance |
| `boss_encounters.gd` | cb06_2 | enemy_balance |
| `boss_encounters.gd` | cb06_3 | enemy_balance |
| `boss_encounters.gd` | cb02_boss_encounters_1_17 | combat_balance_preview |
| `boss_encounters.gd` | vitals_boss_phase | combat_vitals |
| `boss_encounters.gd` | orchard_active_fruit | boss_lair_fights |
| `boss_encounters.gd` | orchard_timing | boss_lair_fights |
| `boss_encounters.gd` | orchard_move_set | boss_lair_fights |
| `boss_encounters.gd` | regular_hazard_identity | enemy_move_feedback |
| `boss_encounters.gd` | phase_boss_4 | boss_phase_fights |
| `boss_encounters.gd` | phase_boss_3 | boss_phase_fights |
| `boss_encounters.gd` | phase_boss_2 | boss_phase_fights |
| `boss_encounters.gd` | phase_boss_0 | boss_phase_fights |
| `boss_encounters.gd` | lair_fights_5 | boss_lair_fights |
| `boss_encounters.gd` | lair_fights_4 | boss_lair_fights |
| `boss_encounters.gd` | lair_fights_3 | boss_lair_fights |
| `boss_encounters.gd` | lair_fights_2 | boss_lair_fights |
| `boss_encounters.gd` | lair_fights_0 | boss_lair_fights |
| `boss_lair_visuals.gd` | orchard_fruit_warning | boss_lair_fights |
| `boss_lair_visuals.gd` | orchard_cage_warning | boss_lair_fights |
| `boss_lair_visuals.gd` | orchard_cage_pose | boss_lair_fights |
| `boss_lair_visuals.gd` | orchard_root_shapes | boss_lair_fights |
| `boss_lair_visuals.gd` | nursery_models | boss_phase_fights |
| `boss_lair_visuals.gd` | seeded_lair_visuals | boss_lair_fights |
| `assets/shaders/lair_water.gdshader` | lair_phase_water | boss_lair_fights |
| `enemy_attack.gd` | ar11_execution_1 | enemy_attack_execution |
| `enemy_attack.gd` | ar11_execution_2 | enemy_attack_execution |
| `enemy_attack.gd` | ar11_execution_3 | enemy_attack_execution |
| `enemy_attack.gd` | ar11_execution_4 | enemy_attack_execution |
| `enemy_attack.gd` | ar11_execution_5 | enemy_attack_execution |
| `enemy_attack.gd` | ar11_execution_6 | enemy_attack_execution |
| `enemy_attack.gd` | ct05_oracle_1 | oracle_progression |
| `enemy_attack.gd` | committed_windup | event_audio |
| `enemy_attack.gd` | regular_route_warnings | wilds_skill_tactics |
| `enemy_attack.gd` | learned_charge_first_leg | wilds_skill_tactics |
| `enemy_attack.gd` | regular_response_lock | wilds_skill_tactics |
| `enemy_attack.gd` | skill_response_planner | wilds_skill_tactics |
| `enemy_attack.gd` | learned_rite_hint_tether | wilds_skill_tactics |
| `enemy_attack.gd` | learned_rite_hint_center | wilds_skill_tactics |
| `enemy_attack.gd` | lock_learned_skill_response | wilds_skill_tactics |
| `enemy_attack.gd` | memory_growth_pose | boss_phase_fights |
| `weapon_system.gd` | ec01_display_2 | weapons, ui_copy |
| `weapon_system.gd` | cb07_0 | expedition_sustain |
| `weapon_system.gd` | healing_roll_0 | healing_rolls |
| `weapon_system.gd` | healing_roll_1 | healing_rolls |
| `weapon_system.gd` | cb03_display_maximum_hp | weapon_balance |
| `weapon_system.gd` | cb03_display_effect_hp | weapon_balance |
| `weapon_system.gd` | cb03_balance_service | weapon_balance |
| `weapon_system.gd` | cb02_weapon_system_2_3 | combat_balance_preview |
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
| `mouse_combat.gd` | ar08_lifecycle_1 | player_lifecycle |
| `mouse_combat.gd` | ar08_lifecycle_2 | player_lifecycle |
| `mouse_combat.gd` | ar08_lifecycle_3 | player_lifecycle |
| `mouse_combat.gd` | ar08_lifecycle_4 | player_lifecycle |
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
| `core_combat.gd` | ar08_lifecycle_1 | player_lifecycle |
| `core_combat.gd` | ar08_lifecycle_3 | player_lifecycle |
| `core_combat.gd` | ar08_lifecycle_5 | player_lifecycle |
| `core_combat.gd` | tc01_ranged_clearance_1 | core_combat, combat, ability_aim, hex_terrain |
| `core_combat.gd` | cr04c_void_1 | void_affinity, core_combat, combat_affinity_contracts |
| `core_combat.gd` | cr04c_void_2 | void_affinity, core_combat, combat_affinity_contracts |
| `core_combat.gd` | cr04c_spirit_1 | spirit_affinity, core_combat, combat_affinity_contracts |
| `core_combat.gd` | cr04c_spirit_2 | spirit_affinity, core_combat, combat_affinity_contracts |
| `core_combat.gd` | cr04c_spirit_4 | spirit_affinity, core_combat, combat_affinity_contracts |
| `core_combat.gd` | cr04c_storm_1 | storm_affinity, core_combat, combat_affinity_contracts |
| `core_combat.gd` | cr04c_storm_2 | storm_affinity, core_combat, combat_affinity_contracts |
| `core_combat.gd` | cr04b_wood_1 | wood_affinity, combat_affinity_contracts |
| `core_combat.gd` | cr04b_wood_2 | wood_affinity, combat_affinity_contracts |
| `core_combat.gd` | cr04b_thorn_1 | thorn_affinity, combat_affinity_contracts |
| `core_combat.gd` | cr04a_affinity_1 | fire_affinity, water_affinity, vital_affinity, frost_affinity, combat_affinity_contracts |
| `core_combat.gd` | cr04a_affinity_2 | fire_affinity, water_affinity, vital_affinity, frost_affinity, combat_affinity_contracts |
| `core_combat.gd` | cr04a_affinity_3 | fire_affinity, water_affinity, vital_affinity, frost_affinity, combat_affinity_contracts |
| `core_combat.gd` | cr04a_affinity_10 | fire_affinity, water_affinity, vital_affinity, frost_affinity, combat_affinity_contracts |
| `core_combat.gd` | cr03_hud_state | frost_affinity |
| `core_combat.gd` | cr02_hud_state | combat_affinity_contracts |
| `core_combat.gd` | core_commit_audio | event_audio |
| `core_combat.gd` | ground_shape_contract | core_combat |
| `combat_traits.gd` | ar08_lifecycle_1 | player_lifecycle |
| `combat_traits.gd` | ar08_lifecycle_2 | player_lifecycle |
| `combat_traits.gd` | ar08_lifecycle_3 | player_lifecycle |
| `combat_traits.gd` | ar08_lifecycle_5 | player_lifecycle |
| `combat_traits.gd` | ar08_lifecycle_6 | player_lifecycle |
| `combat_traits.gd` | ar08_lifecycle_7 | player_lifecycle |
| `combat_traits.gd` | ar08_lifecycle_8 | player_lifecycle |
| `combat_traits.gd` | ar08_lifecycle_9 | player_lifecycle |
| `combat_traits.gd` | ar08_lifecycle_10 | player_lifecycle |
| `combat_traits.gd` | ga01a_2 | expedition_grafts, combat, weapons, reaper_progression |
| `combat_traits.gd` | ga01a_3 | expedition_grafts, combat, weapons, reaper_progression |
| `combat_traits.gd` | ga01a_4 | expedition_grafts, combat, weapons, reaper_progression |
| `combat_traits.gd` | ct03_ranger_4 | classes, ranger_progression |
| `combat_traits.gd` | ct03_ranger_5 | classes, ranger_progression |
| `combat_traits.gd` | ct03_ranger_6 | classes, ranger_progression |
| `combat_traits.gd` | ct03_ranger_7 | classes, ranger_progression |
| `combat_traits.gd` | ct02_1 | weaver_progression, warden_progression, combat_affinity_contracts |
| `combat_traits.gd` | ct02_3 | weaver_progression, warden_progression, combat_affinity_contracts |
| `combat_traits.gd` | cr05_grafts_2 | combat_affinity_contracts, weapons, classes, life |
| `combat_traits.gd` | cr05_grafts_3 | combat_affinity_contracts, weapons, classes, life |
| `combat_traits.gd` | cr05_grafts_4 | combat_affinity_contracts, weapons, classes, life |
| `combat_traits.gd` | cr05_grafts_5 | combat_affinity_contracts, weapons, classes, life |
| `combat_traits.gd` | cr05_grafts_6 | combat_affinity_contracts, weapons, classes, life |
| `combat_traits.gd` | cr04b_thorn_1 | thorn_affinity, combat_affinity_contracts |
| `combat_traits.gd` | cr04a_affinity_1 | vital_affinity, combat_affinity_contracts |
| `combat_traits.gd` | cr04a_affinity_2 | vital_affinity, combat_affinity_contracts |
| `combat_traits.gd` | cr02_trip_snare | combat_affinity_contracts |
| `combat_traits.gd` | cr02_tick | combat_affinity_contracts |
| `combat_traits.gd` | cb07_0 | expedition_sustain |
| `combat_traits.gd` | cb07_1 | expedition_sustain |
| `combat_traits.gd` | healing_roll_0 | healing_rolls |
| `combat_traits.gd` | healing_roll_1 | healing_rolls |
| `combat_traits.gd` | healing_roll_2 | healing_rolls |
| `combat_traits.gd` | healing_roll_3 | healing_rolls |
| `combat_traits.gd` | healing_roll_4 | healing_rolls |
| `combat_traits.gd` | healing_roll_5 | healing_rolls |
| `combat_traits.gd` | cb04_4 | class_balance |
| `combat_traits.gd` | cb04_5 | class_balance |
| `combat_traits.gd` | cb03_counter_potency | weapon_balance |
| `combat_traits.gd` | cb03_trait_hp_tooltip | weapon_balance |
| `combat_traits.gd` | cb03_field_healing | weapon_balance |
| `combat_traits.gd` | cb03_field_potency | weapon_balance |
| `combat_traits.gd` | cb02_combat_traits_1_7 | combat_balance_preview |
| `combat_traits.gd` | vitals_healing_pool | combat_vitals |
| `combat_traits.gd` | tick_class_snare | classes, ability_aim, warden_progression |
| `enemy_support.gd` | ar12_choir_hit | incoming_player_hit |
| `enemy_support.gd` | ar12_choir_life | incoming_player_hit |
| `enemy_support.gd` | ar11_execution_1 | enemy_attack_execution |
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
| `enemy_skill_responses.gd` | ar11_execution_1 | enemy_attack_execution |
| `enemy_skill_responses.gd` | cb06_0 | enemy_balance |
| `enemy_skill_responses.gd` | canopy_release | event_audio |
| `enemy_skill_responses.gd` | resolved_canopy_circle | enemy_move_feedback |
| `combat_feedback.gd` | cb07_0 | expedition_sustain |
| `combat_feedback.gd` | space_pull_from_slow | enemy_move_feedback |
| `combat_feedback.gd` | callout_height_override | enemy_move_feedback |
| `character_profile.gd` | ct01_whole_xp_1 | classes, characters, loot, persistence_operations |
| `character_profile.gd` | ct01_whole_xp_2 | classes, characters, loot, persistence_operations |
| `character_profile.gd` | ct01_whole_xp_3 | classes, characters, loot, persistence_operations |
| `character_profile.gd` | ct01_whole_xp_4 | classes, characters, loot, persistence_operations |
| `character_profile.gd` | ct01_whole_xp_5 | classes, characters, loot, persistence_operations |
| `character_profile.gd` | ct01_whole_xp_6 | classes, characters, loot, persistence_operations |
| `character_profile.gd` | ct01_whole_xp_7 | classes, characters, loot, persistence_operations |
| `character_profile.gd` | cr05_progression_1 | classes, life, combat_affinity_contracts |
| `character_profile.gd` | normalize_warden_tree_choices | warden_progression |
| `content_ids.gd` | ct01_whole_xp_1 | classes, characters, loot, persistence_operations |
| `content_ids.gd` | ct01_whole_xp_2 | classes, characters, loot, persistence_operations |
| `content_ids.gd` | ct01_whole_xp_3 | classes, characters, loot, persistence_operations |
| `content_ids.gd` | subclass_manifest | warden_progression |
| `content_ids.gd` | manifest_warden_nodes | warden_progression |
| `progression_tree.gd` | show_warden_subclass_labels | warden_progression |
| `progression_tree.gd` | show_unlearned_warden_routes | warden_progression |
| `class_ability_targeting.gd` | ar08_lifecycle_1 | player_lifecycle |
| `class_ability_targeting.gd` | tc01_ranged_clearance_2 | ability_aim, combat, ranged_release, hex_terrain |
| `class_ability_targeting.gd` | tc01_ranged_clearance_3 | ability_aim, combat, ranged_release, hex_terrain |
| `class_ability_targeting.gd` | tc01_ranged_clearance_4 | ability_aim, combat, ranged_release, hex_terrain |
| `class_ability_targeting.gd` | subclass_footprint | warden_progression |
| `class_ability_targeting.gd` | subclass_plan | warden_progression |
| `ability_aim.gd` | ar06_cooldown_1 | player_cooldowns |
| `ability_aim.gd` | ar06_cooldown_2 | player_cooldowns |
| `ability_aim.gd` | vital_aim_2 | vital_affinity, combat_affinity_contracts, core_combat, mouse_combat |
| `ability_aim.gd` | vital_aim_3 | vital_affinity, combat_affinity_contracts, core_combat, mouse_combat |
| `ability_aim.gd` | vital_aim_4 | vital_affinity, combat_affinity_contracts, core_combat, mouse_combat |
| `ability_aim.gd` | core_curved_and_link_guides | core_combat |
| `ability_aim.gd` | subclass_aim_preview | warden_progression |
| `ability_aim.gd` | subclass_commit_aim | warden_progression |
| `main_menu.gd` | experimental_coop_1 | hex_terrain, terrain, connection_flow, garden |
| `main_menu.gd` | experimental_coop_2 | hex_terrain, terrain, connection_flow, garden |
| `main_menu.gd` | experimental_coop_3 | hex_terrain, terrain, connection_flow, garden |
| `main_menu.gd` | experimental_coop_4 | hex_terrain, terrain, connection_flow, garden |
| `main_menu.gd` | experimental_coop_5 | hex_terrain, terrain, connection_flow, garden |
| `main_menu.gd` | experimental_coop_6 | hex_terrain, terrain, connection_flow, garden |
| `main_menu.gd` | experimental_coop_7 | hex_terrain, terrain, connection_flow, garden |
| `main_menu.gd` | experimental_coop_9 | hex_terrain, terrain, connection_flow, garden |
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
| `combat_director.gd` | ar08_lifecycle_1 | player_lifecycle |
| `combat_director.gd` | ar08_lifecycle_2 | player_lifecycle |
| `combat_director.gd` | ar08_lifecycle_3 | player_lifecycle |
| `combat_director.gd` | ar08_lifecycle_4 | player_lifecycle |
| `combat_director.gd` | ar07_vitals_1 | player_vitals |
| `combat_director.gd` | ar07_vitals_2 | player_vitals |
| `combat_director.gd` | ar07_vitals_3 | player_vitals |
| `combat_director.gd` | ar07_vitals_4 | player_vitals |
| `combat_director.gd` | cb06_0 | enemy_balance |
| `combat_director.gd` | cb06_1 | enemy_balance |
| `combat_director.gd` | cb02_combat_director_1_2 | combat_balance_preview |
| `combat_director.gd` | vitals_enemy_capacity | combat_vitals |
| `combat_director.gd` | dream_lure_pursuit | core_combat |
| `boss_lair_fights.gd` | ar11_execution_1 | enemy_attack_execution |
| `boss_lair_fights.gd` | ct05_oracle_1 | oracle_progression |
| `boss_lair_fights.gd` | cb06_0 | enemy_balance |
| `boss_lair_fights.gd` | cb06_1 | enemy_balance |
| `boss_lair_fights.gd` | orchard_resolve_cage | boss_lair_fights |
| `boss_lair_fights.gd` | lair_charge | event_audio |
| `boss_lair_fights.gd` | lair_release | event_audio |
| `boss_lair_fights.gd` | lair_windup | event_audio |
| `boss_phase_fights.gd` | ar11_execution_1 | enemy_attack_execution |
| `boss_phase_fights.gd` | ar11_execution_2 | enemy_attack_execution |
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
| `subclass_combat.gd` | ar08_lifecycle_1 | player_lifecycle |
| `subclass_combat.gd` | ar08_lifecycle_4 | player_lifecycle |
| `subclass_combat.gd` | ar08_lifecycle_5 | player_lifecycle |
| `subclass_combat.gd` | ar07_vitals_1 | player_vitals |
| `subclass_combat.gd` | ar07_vitals_2 | player_vitals |
| `subclass_combat.gd` | ar06_cooldown_1 | player_cooldowns |
| `subclass_combat.gd` | ar06_cooldown_2 | player_cooldowns |
| `subclass_combat.gd` | ct05_oracle_2 | oracle_progression |
| `subclass_combat.gd` | ct04_reaper_1 | warden_progression, reaper_progression |
| `subclass_combat.gd` | ct04_reaper_3 | warden_progression, reaper_progression |
| `subclass_combat.gd` | ct04_reaper_4 | warden_progression, reaper_progression |
| `subclass_combat.gd` | ct03_ranger_1 | warden_progression, ranger_progression |
| `subclass_combat.gd` | ct03_ranger_3 | warden_progression, ranger_progression |
| `subclass_combat.gd` | ct03_ranger_6 | warden_progression, ranger_progression |
| `subclass_combat.gd` | ct02_1 | weaver_progression, warden_progression, combat_affinity_contracts |
| `subclass_combat.gd` | ct02_2 | weaver_progression, warden_progression, combat_affinity_contracts |
| `subclass_combat.gd` | ct02_4 | weaver_progression, warden_progression, combat_affinity_contracts |
| `subclass_combat.gd` | ct02_7 | weaver_progression, warden_progression, combat_affinity_contracts |
| `subclass_combat.gd` | ct02_10 | weaver_progression, warden_progression, combat_affinity_contracts |
| `subclass_combat.gd` | ct02_11 | weaver_progression, warden_progression, combat_affinity_contracts |
| `subclass_combat.gd` | cr04c_spirit_1 | spirit_affinity, core_combat, combat_affinity_contracts |
| `subclass_combat.gd` | cr03_cast_skill | frost_affinity |
| `subclass_combat.gd` | cb07_0 | expedition_sustain |
| `subclass_combat.gd` | cb07_1 | expedition_sustain |
| `subclass_combat.gd` | cb07_2 | expedition_sustain |
| `subclass_combat.gd` | cb07_4 | expedition_sustain |
| `subclass_combat.gd` | healing_roll_0 | healing_rolls |
| `subclass_combat.gd` | healing_roll_1 | healing_rolls |
| `subclass_combat.gd` | healing_roll_2 | healing_rolls |
| `subclass_combat.gd` | healing_roll_3 | healing_rolls |
| `subclass_combat.gd` | healing_roll_4 | healing_rolls |
| `subclass_combat.gd` | cb04_ward_time_1 | class_balance |
| `subclass_combat.gd` | cb04_0 | class_balance |
| `subclass_combat.gd` | cb04_1 | class_balance |
| `subclass_combat.gd` | cb04_3 | class_balance |
| `subclass_combat.gd` | cb04_5 | class_balance |
| `subclass_combat.gd` | cb04_8 | class_balance |
| `subclass_combat.gd` | cb04_9 | class_balance |
| `subclass_combat.gd` | cb02_subclass_combat_2_3 | combat_balance_preview |
| `subclass_combat.gd` | cb02_subclass_combat_1_2 | combat_balance_preview |
| `subclass_combat.gd` | vitals_subclass_ally | combat_vitals |
| `subclass_combat.gd` | vitals_subclass_siphon | combat_vitals |
| `expedition_life.gd` | ar08_lifecycle_1 | player_lifecycle |
| `expedition_life.gd` | ar08_lifecycle_2 | player_lifecycle |
| `expedition_life.gd` | ar08_lifecycle_3 | player_lifecycle |
| `expedition_life.gd` | ar08_lifecycle_4 | player_lifecycle |
| `expedition_life.gd` | ar08_lifecycle_5 | player_lifecycle |
| `expedition_life.gd` | ar08_lifecycle_6 | player_lifecycle |
| `expedition_life.gd` | ar07_vitals_1 | player_vitals |
| `expedition_life.gd` | ar07_vitals_2 | player_vitals |
| `expedition_life.gd` | ar07_vitals_3 | player_vitals |
| `expedition_life.gd` | ar07_vitals_4 | player_vitals |
| `expedition_life.gd` | ar07_vitals_5 | player_vitals |
| `expedition_life.gd` | ar07_vitals_6 | player_vitals |
| `expedition_life.gd` | ec01_1 | affinity_cards |
| `expedition_life.gd` | cr05_grafts_1 | combat_affinity_contracts, weapons, classes, life |
| `expedition_life.gd` | cr05_progression_1 | classes, life, combat_affinity_contracts |
| `expedition_life.gd` | cr04a_affinity_1 | fire_affinity, vital_affinity, combat_affinity_contracts |
| `expedition_life.gd` | cr04a_affinity_3 | fire_affinity, vital_affinity, combat_affinity_contracts |
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
| `run_summary_panel.gd` | ar07_vitals_1 | player_vitals, expedition_summary |
| `run_summary_panel.gd` | ar07_vitals_2 | player_vitals, expedition_summary |
| `run_summary_panel.gd` | ec01_speed_stat_tooltip | affinity_cards, expedition_summary |
| `run_summary_panel.gd` | ga01a_2 | expedition_grafts, expedition_summary, affinity_cards |
| `run_summary_panel.gd` | cb07_1 | expedition_sustain |
| `run_summary_panel.gd` | healing_roll_0 | healing_rolls |
| `run_summary_panel.gd` | healing_roll_1 | healing_rolls |
| `run_summary_panel.gd` | healing_roll_2 | healing_rolls |
| `run_summary_panel.gd` | cb03_summary_effect_hp | weapon_balance |
| `run_summary_panel.gd` | cb02_run_summary_panel_1_2 | combat_balance_preview |
| `party_hud.gd` | ar08_lifecycle_1 | player_lifecycle, party_ui |
| `party_hud.gd` | ar08_lifecycle_2 | player_lifecycle, party_ui |
| `party_hud.gd` | ar07_vitals_1 | player_vitals, party_ui |
| `party_hud.gd` | ar07_vitals_2 | player_vitals, party_ui |
| `party_hud.gd` | preview_party_clearance | combat_balance_preview |
| `party_hud.gd` | cb02_party_hud_3_2 | combat_balance_preview |
| `party_hud.gd` | cb02_party_hud_2_1 | combat_balance_preview |
| `party_hud.gd` | cb02_party_hud_1_0 | combat_balance_preview |
| `diagnostic_watch.gd` | ar08_lifecycle_1 | player_lifecycle, diagnostics |
| `diagnostic_watch.gd` | ar08_lifecycle_2 | player_lifecycle, diagnostics |
| `diagnostic_watch.gd` | ar07_vitals_1 | player_vitals, diagnostics |
| `diagnostic_watch.gd` | ar07_vitals_2 | player_vitals, diagnostics |
| `diagnostic_watch.gd` | preview_logged_health_scale | combat_balance_preview |
| `spectator_view.gd` | ar08_lifecycle_1 | player_lifecycle, life |
| `spectator_view.gd` | ar08_lifecycle_2 | player_lifecycle, life |
| `spectator_view.gd` | ar07_vitals_1 | player_vitals, life |
| `spectator_view.gd` | ar07_vitals_2 | player_vitals, life |
| `spectator_view.gd` | preview_spectator_layout | spectator_layout |
| `spectator_view.gd` | cb07_0 | expedition_sustain |
| `spectator_view.gd` | preview_spectator_cost | combat_balance_preview |
| `assets/data/weapon_template.json` | cb03_template_roll_spread | weapon_balance |
| `combat_balance_preview.gd` | ar07_vitals_1 | player_vitals |
| `combat_balance_preview.gd` | ar07_vitals_2 | player_vitals |
| `combat_balance_preview.gd` | ar07_vitals_3 | player_vitals |
| `combat_balance_preview.gd` | ar01_native_health | expedition_grafts, life |
| `combat_balance_preview.gd` | ec01_speed_rate_label | affinity_cards, expedition_summary, weapons |
| `combat_balance_preview.gd` | cb07_0 | expedition_sustain |
| `combat_balance_preview.gd` | cb06_0 | enemy_balance |
| `combat_balance_preview.gd` | healing_roll_1 | healing_rolls |
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
| `inventory_slot.gd` | cb03_slot_component_tooltip | weapon_balance |
| `subclass_catalog.gd` | ec01_playtest_5 | weaver_progression, classes, class_tree_access |
| `subclass_catalog.gd` | ct05_oracle_1 | oracle_progression |
| `subclass_catalog.gd` | ct04_reaper_1 | warden_progression, reaper_progression |
| `subclass_catalog.gd` | cb04_1 | class_balance |
| `subclass_catalog.gd` | cb04_2 | class_balance |
| `subclass_catalog.gd` | cb04_4 | class_balance |
| `subclass_catalog.gd` | cb04_5 | class_balance |
| `expedition_pressure.gd` | cb06_0 | enemy_balance |
| `expedition_pressure.gd` | cb06_1 | enemy_balance |
| `expedition_pressure.gd` | cb06_2 | enemy_balance |
| `expedition_pressure.gd` | cb06_3 | enemy_balance |
| `expedition_pressure.gd` | cb06_4 | enemy_balance |
| `expedition_pressure.gd` | cb06_5 | enemy_balance |
| `class_skill_balance.gd` | ec01_speed_class_cooldown_limit | class_balance, expedition_summary |
| `class_skill_balance.gd` | cb07_0 | expedition_sustain |
| `network_presentation.gd` | ar08_lifecycle_1 | player_lifecycle, presentation |
| `network_presentation.gd` | ar08_lifecycle_2 | player_lifecycle, presentation |
| `network_presentation.gd` | ar08_lifecycle_3 | player_lifecycle, presentation |
| `network_presentation.gd` | ar07_vitals_1 | player_vitals, presentation |
| `network_presentation.gd` | ar07_vitals_2 | player_vitals, presentation |
| `network_presentation.gd` | ar07_vitals_3 | player_vitals, presentation |
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
