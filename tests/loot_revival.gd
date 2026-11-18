extends SceneTree
const UIFixture = preload("res://tests/support/gameplay_ui_case.gd")

const SessionCase = preload("res://tests/support/session_case.gd")

const ExpeditionCase = preload("res://tests/support/expedition_case.gd")

const IncomingPlayerHit = preload("res://incoming_player_hit.gd")

const PlayerLifecycle = preload("res://player_lifecycle.gd")
const PlayerVitals = preload("res://player_vitals.gd")

const Cooldowns = preload("res://player_cooldowns.gd")
const Orb=preload("res://health_orb.gd")
const Cards=preload("res://affinity_cards.gd")
var failed:=false
func check(ok: bool,message: String) -> void:
 if not ok: failed=true;printerr("FAIL loot/revival: ",message)
func _initialize() -> void:
 call_deferred("run")
func run() -> void:
 var game=load("res://world.tscn").instantiate()
 game.progress.path="res://.godot/life-"+Crypto.new().generate_random_bytes(8).hex_encode()+".cfg";game.local_character.path=game.progress.path+".character";root.add_child(game)
 game.set_process(false);game.set_physics_process(false)
 game.add_player(2);SessionCase.set_ready(game, game.players[2], true)
 var a: Dictionary=game.players[1];var b: Dictionary=game.players[2]
 game.battlefield.configure(0,1);game.encounter.set_hp(-1, 100);game.encounter.clear_scouts()
 for p in [a,b]: ExpeditionCase.set_membership(game, p, true);p.pos=Vector3(0,0,2);p[PlayerVitals.STATE] = p[PlayerVitals.STATE].with_hp(100)
 var item: String=game.Items.part_id(game.Parts.HOOK)
 game.wild_item_drops.assign([{"id":"part","owner":1,"stack":{"item":item,"quantity":1},"position":[0,0,2]}])
 game.inventory_drop_visuals._process(.3)
 var model: Node3D=game.inventory_drop_visuals.models.part
 check(model.position==game.stage.WILD_OFFSET+Vector3(0,0,2) and model.visible,"monster drop is visible at Wilds world offset")
 check(game.exploration.drop_color(item)==Color("#62baff") and game.exploration.drop_color("unidentified_seed")!=Color("#62baff"),"parts use blue minimap markers, seeds retain gold")
 check(game.inventory_floor_snapshot(b).is_empty(),"owner-only loot remains private")
 game.pickup_inventory_drop(1,a,"part");game.inventory_drop_visuals._process(.3)
 check(game.inventory_drop_visuals.models.is_empty() and a.carried_parts[game.Parts.HOOK]==1,"pickup removes visible drop and awards component")
 a.carried_seeds=[0];a.safe_items=[{"item":"unidentified_seed","quantity":1,"seeds":[0]}]
 IncomingPlayerHit.apply_health_loss(game, 1, PlayerLifecycle.generation(a), 100)
 check(ExpeditionCase.is_wild(a) and PlayerLifecycle.fallen(a) and PlayerVitals.current_hp(a)==0 and a.carried_seeds==[0],"fallen player keeps run cargo pending revival")
 check(game.spectator_view.focus_id(1)==2,"fallen host spectates living teammate")
 game.add_player(3);ExpeditionCase.set_membership(game, game.players[3], true);SessionCase.set_ready(game, game.players[3], true)
 game.spectator_view.cycle();check(game.spectator_view.focus_id(1)==3,"spectator can cycle living allies")
 game.players[3][PlayerLifecycle.STATE] = game.players[3][PlayerLifecycle.STATE].fall()
 game.players[3][PlayerVitals.STATE] = game.players[3][PlayerVitals.STATE].with_hp(0.0)
 check(game.spectator_view.focus_id(1)==2,"spectator automatically replaces fallen target")
 ExpeditionCase.remove_actor(game, 3)
 var pos: Vector3=a.pos;game.move_player(1,Vector2.RIGHT,1);game.dodge_player(1,Vector2.RIGHT);game.use_class_skill(1,a)
 check(a.pos==pos and a[Cooldowns.STATE].deadline(Cooldowns.Q)==0,"fallen players cannot move, dodge or cast")
 var vital=preload("res://vital_combat.gd")
 var material=preload("res://affinity_build.gd").slot("core",game.Items.get_item("part_2").legacy_part)
 var grant=preload("res://combat_action_events.gd").begin(game,2,"core",material,vital.QUALITY.ordinary,["core_action"],Time.get_ticks_msec()+3000)
 vital.grant(game,grant,1,0)
 vital.tick(game,1000)
 check(PlayerVitals.current_hp(a)==0 and not a.has(vital.SOURCES),"current Vitality refuses a fallen recipient and cannot regenerate a revival")
 check(game.nearest_wild_player(a.pos)==2 and game.Director.target(game,a.pos,{},0)==2,"enemies ignore fallen players")
 b.pos=Vector3(10,0,10);check(not game.Life.revive(game,2,1),"distant revival refused")
 b.pos=a.pos
 game.act(2,false)
 check(not PlayerLifecycle.fallen(a) and PlayerVitals.current_hp(a)==80 and PlayerVitals.maximum_hp(a)==80 and a.lost_health==20,"nearby E revives at full reduced capacity")
 check(not game.Life.revive(game,2,1) and a.lost_health==20,"duplicate requests cannot charge twice")
 game._process(.016)
 check(UIFixture.control(game,"player_hud").state.lost_health==20 and Orb.fractions(80,80,20).is_equal_approx(Vector2(.8,.8)),"health orb reserves the sacrificed capacity separately from current HP")
 check(game.spectator_view.focus_id(1)==1,"revived camera returns to own character")
 var health_copies: Array[Dictionary]=[{"id":"run_health","rarity":"Common","amount":3,"floor":6,"acquisition_id":1}]
 a[Cards.STATE]=Cards.Ledger.new(health_copies)
 a[PlayerVitals.STATE]=a[PlayerVitals.STATE].with_native_max_hp(game.Life.native_maximum(game,a))
 check(PlayerVitals.maximum_hp(a)==83 and PlayerVitals.current_hp(a)==80 and a.lost_health==20,"current health card preserves revive loss without free healing")
 Cards.clear(a)
 a[PlayerVitals.STATE] = a[PlayerVitals.STATE].with_native_max_hp(80);a[PlayerVitals.STATE] = a[PlayerVitals.STATE].with_hp(80);b.pos=a.pos;ExpeditionCase.set_world(game, {"encounter_number": 1});game.encounter.set_hp(-1, 100)
 for capacity in [60,40,20]:
  var generation := PlayerLifecycle.generation(a)
  IncomingPlayerHit.apply_health_loss(game, 1, PlayerLifecycle.generation(a), 100)
  check(PlayerLifecycle.matches(a,generation) and PlayerLifecycle.fallen(a),"each lethal hit changes the fallen state without replacing generation")
  check(game.Life.revive(game,2,1) and PlayerVitals.maximum_hp(a)==capacity and int(a.lost_health)==100-capacity
   and not PlayerLifecycle.matches(a,generation),"each revival spends 20 HP of capacity and replaces the previous generation")
 IncomingPlayerHit.apply_health_loss(game, 1, PlayerLifecycle.generation(a), 100)
 check(not game.Life.revive(game,2,1) and PlayerVitals.current_hp(a)==0 and PlayerVitals.maximum_hp(a)==20,"last remaining capacity segment cannot be sacrificed")
 # Fallen allies cannot block travel or get healed by moving floors.
 game.encounter.set_hp(-1, 0);game.encounter_rewarded=true;ExpeditionCase.set_world(game, {"encounter_number": 1})
 b.pos=game.battlefield.advance;a.pos=Vector3(0,0,2)
 check(game.PartyTravel.members(game,"advance")==[2],"fallen player omitted from ready checks")
 ExpeditionCase.Transitions.commit_checkpoint(game, 2,true)
 check(ExpeditionCase.is_wild(a) and PlayerLifecycle.fallen(a) and PlayerVitals.current_hp(a)==0,"floor transition carries fallen body without reviving")
 # Extracting alive banks full cargo, while a fallen ally keeps only their pouch.
 game.encounter.set_hp(-1, 0);game.encounter.clear_scouts();ExpeditionCase.set_world(game, {"encounter_number": 6});game.encounter_rewarded=true;b.pos=game.battlefield.advance
 var safe_before: int=game.seed_reserve(a).unknown.size()
 ExpeditionCase.Transitions.commit_checkpoint(game, 2,false)
 check(not ExpeditionCase.is_wild(a) and not PlayerLifecycle.fallen(a) and PlayerVitals.current_hp(a)==100 and a.lost_health==0
  and game.seed_reserve(a).unknown.size()==safe_before+1,"extraction restores fallen ally while banking only their safe pouch")
 for player in [a,b]: ExpeditionCase.set_membership(game, player, true);player[PlayerLifecycle.STATE] = PlayerLifecycle.start_life()
 for peer in [1,2]:
  var actor: Dictionary=game.players[peer]
  check(game.monster_rewards.begin_expedition(game._kill_reward_identity(peer,actor),game.participation.run_id(),actor.character.xp,actor.character.monsters),
   "synthetic post-extraction run records entry rewards before abandonment")
 ExpeditionCase.Transitions.abandon(game, 1,a)
 check(not ExpeditionCase.is_wild(a) and ExpeditionCase.is_wild(b) and PlayerLifecycle.fallen(a) and not ExpeditionCase.Transitions.admit(game, 1,a),
  "abandoned player waits in the Garden while the party expedition continues")
 var waiting_generation := PlayerLifecycle.generation(a)
 ExpeditionCase.Transitions.abandon(game, 2,b)
 check(not PlayerLifecycle.fallen(a) and not PlayerLifecycle.matches(a,waiting_generation),
  "ending the party expedition clears the wait and starts a fresh life before departure")
 for player in [a,b]: ExpeditionCase.set_membership(game, player, true);player[PlayerLifecycle.STATE] = PlayerLifecycle.start_life();player[PlayerVitals.STATE] = player[PlayerVitals.STATE].with_hp(1);player[PlayerVitals.STATE] = player[PlayerVitals.STATE].with_native_max_hp(80);player.lost_health=20
 IncomingPlayerHit.apply_health_loss(game, 1, PlayerLifecycle.generation(a), 100);IncomingPlayerHit.apply_health_loss(game, 2, PlayerLifecycle.generation(b), 100)
 check(not ExpeditionCase.is_wild(a) and not ExpeditionCase.is_wild(b) and PlayerVitals.current_hp(a)==100 and a.lost_health==0 and a.carried_seeds.is_empty(),"party wipe returns everyone and restores sacrificed capacity")
 # Newer revival state must survive an older movement packet.
 var view=load("res://network_presentation.gd").new()
 view.accept_vital(1,{"revision":3,"hp":80,"max_hp":80,"fallen":false,"lost_health":20,"damage_seq":1})
 var stale={"vitals_revision":2,"hp":0,"max_hp":100,"fallen":true,"lost_health":0,"damage_seq":1};view.merge_health(1,stale)
 check(not stale.fallen and stale.hp==80 and stale.lost_health==20,"stale snapshots cannot undo revived state or penalty")
 ExpeditionCase.set_membership(game, a, true);a[PlayerLifecycle.STATE] = a[PlayerLifecycle.STATE].fall();a[PlayerVitals.STATE] = a[PlayerVitals.STATE].with_hp(0);a.lost_health=20;a[PlayerVitals.STATE] = a[PlayerVitals.STATE].with_native_max_hp(80)
 ExpeditionCase.set_membership(game, b, true);b[PlayerLifecycle.STATE] = b[PlayerLifecycle.STATE].clear_inactive();b[PlayerVitals.STATE] = b[PlayerVitals.STATE].with_hp(80)
 check(game.monster_rewards.begin_expedition(game._kill_reward_identity(2,b),game.participation.run_id(),b.character.xp,b.character.monsters),
  "synthetic last-living-ally run records the forfeiter's entry rewards")
 ExpeditionCase.Transitions.abandon(game, 2,b)
 check(not ExpeditionCase.is_wild(a) and PlayerVitals.current_hp(a)==100 and a.lost_health==0,"last living ally abandoning resolves fallen player's run")
 ExpeditionCase.set_membership(game, a, true);a[PlayerLifecycle.STATE] = a[PlayerLifecycle.STATE].fall();a[PlayerVitals.STATE] = a[PlayerVitals.STATE].with_hp(0);a.lost_health=20;a[PlayerVitals.STATE] = a[PlayerVitals.STATE].with_native_max_hp(80)
 ExpeditionCase.set_membership(game, b, true);b[PlayerLifecycle.STATE] = b[PlayerLifecycle.STATE].clear_inactive();b[PlayerVitals.STATE] = b[PlayerVitals.STATE].with_hp(80)
 var departed_generation := PlayerLifecycle.generation(b)
 SessionCase.World.remove(game,2)
 check(not ExpeditionCase.is_wild(a) and PlayerVitals.current_hp(a)==100 and a.lost_health==0,"disconnecting last living ally resolves fallen player's run")
 game.add_player(2)
 var readmitted: Dictionary = game.players[2]
 check(not PlayerLifecycle.fallen(readmitted) and not PlayerLifecycle.matches(readmitted,departed_generation),
  "reused peer ID starts with a new lifecycle generation")
 game.queue_free();await process_frame
 if not failed: print("PASS: loot visibility/privacy, blue map markers, spectating, revival cost, action guards, travel, wipe and stale health")
 quit(1 if failed else 0)
