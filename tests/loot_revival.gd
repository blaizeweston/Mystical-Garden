extends SceneTree

const PlayerLifecycle = preload("res://player_lifecycle.gd")
const PlayerVitals = preload("res://player_vitals.gd")

const Cooldowns = preload("res://player_cooldowns.gd")
var failed:=false
func check(ok: bool,message: String) -> void:
 if not ok: failed=true;printerr("FAIL loot/revival: ",message)
func _initialize() -> void:
 preload("res://combat_balance_preview.gd").enabled = false
 call_deferred("run")
func run() -> void:
 var game=load("res://world.tscn").instantiate()
 game.progress.path="res://.godot/life-"+Crypto.new().generate_random_bytes(8).hex_encode()+".cfg";game.local_character.path=game.progress.path+".character";root.add_child(game)
 game.set_process(false);game.set_physics_process(false)
 game.add_player(2);game.players[2].profile_ready=true
 var a: Dictionary=game.players[1];var b: Dictionary=game.players[2]
 game.battlefield.configure(0,1);game.encounter.set_hp(-1, 100);game.encounter.clear_scouts()
 for p in [a,b]: p.wild=true;p.pos=Vector3(0,0,2);p[PlayerVitals.STATE] = p[PlayerVitals.STATE].with_hp(10)
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
 game.damage_player(1,a,10)
 check(a.wild and PlayerLifecycle.fallen(a) and PlayerVitals.current_hp(a)==0 and a.carried_seeds==[0],"fallen player keeps run cargo pending revival")
 check(game.spectator_view.focus_id(1)==2,"fallen host spectates living teammate")
 game.add_player(3);game.players[3].wild=true;game.players[3].profile_ready=true
 game.spectator_view.cycle();check(game.spectator_view.focus_id(1)==3,"spectator can cycle living allies")
 game.players[3][PlayerLifecycle.STATE] = game.players[3][PlayerLifecycle.STATE].fall()
 game.players[3][PlayerVitals.STATE] = game.players[3][PlayerVitals.STATE].with_hp(0.0)
 check(game.spectator_view.focus_id(1)==2,"spectator automatically replaces fallen target")
 game.players.erase(3)
 var pos: Vector3=a.pos;game.move_player(1,Vector2.RIGHT,1);game.dodge_player(1,Vector2.RIGHT);game.use_class_skill(1,a)
 check(a.pos==pos and a[Cooldowns.STATE].deadline(Cooldowns.Q)==0,"fallen players cannot move, dodge or cast")
 a.renewal_until=Time.get_ticks_msec()+2000;game.update_support_effects(Time.get_ticks_msec()+1000)
 check(PlayerVitals.current_hp(a)==0,"regeneration cannot revive")
 check(game.nearest_wild_player(a.pos)==2 and game.Director.target(game,a.pos,{},0)==2,"enemies ignore fallen players")
 b.pos=Vector3(10,0,10);check(not game.Life.revive(game,2,1),"distant revival refused")
 b.pos=a.pos
 game.act(2,false)
 check(not PlayerLifecycle.fallen(a) and PlayerVitals.current_hp(a)==8 and PlayerVitals.maximum_hp(a)==8 and a.lost_health==2,"nearby E revives at full reduced capacity")
 check(not game.Life.revive(game,2,1) and a.lost_health==2,"duplicate requests cannot charge twice")
 game._process(.016)
 check(game.player_hud.state.lost_health==2 and game.player_hud.heart_state(8,8,4)==3,"lost full heart uses fourth damage texture")
 check(game.spectator_view.focus_id(1)==1,"revived camera returns to own character")
 game.encounter.set_hp(-1, 0);game.encounter_number=6;a.pos=game.battlefield.advance;a[game.ExpeditionWallet.STATE] = game.ExpeditionWallet.Wallet.new(10000, game.wallet_for(a).spent_essence());a.offer_floor=6;a.checkpoint_offers=["class_0_0"]
 check(game._buy_upgrade(1,a,0) and PlayerVitals.maximum_hp(a)==10 and a.lost_health==2,"real health upgrade preserves the sacrificed-heart deduction")
 a.run_upgrades={};a[PlayerVitals.STATE] = a[PlayerVitals.STATE].with_native_max_hp(8);a[PlayerVitals.STATE] = a[PlayerVitals.STATE].with_hp(8);b.pos=a.pos;game.encounter_number=1;game.encounter.set_hp(-1, 100)
 for capacity in [6,4,2]:
  var generation := PlayerLifecycle.generation(a)
  game.damage_player(1,a,100)
  check(PlayerLifecycle.matches(a,generation) and PlayerLifecycle.fallen(a),"each lethal hit changes the fallen state without replacing generation")
  check(game.Life.revive(game,2,1) and PlayerVitals.maximum_hp(a)==capacity and int(a.lost_health)==10-capacity
   and not PlayerLifecycle.matches(a,generation),"each revival spends one heart and replaces the previous generation")
 game.damage_player(1,a,100)
 check(not game.Life.revive(game,2,1) and PlayerVitals.current_hp(a)==0 and PlayerVitals.maximum_hp(a)==2,"last remaining full heart cannot be sacrificed")
 # Fallen allies cannot block travel or get healed by moving floors.
 game.encounter.set_hp(-1, 0);game.encounter_rewarded=true;game.encounter_number=1
 b.pos=game.battlefield.advance;a.pos=Vector3(0,0,2)
 check(game.PartyTravel.members(game,"advance")==[2],"fallen player omitted from ready checks")
 game._use_checkpoint(2,true)
 check(a.wild and PlayerLifecycle.fallen(a) and PlayerVitals.current_hp(a)==0,"floor transition carries fallen body without reviving")
 # Extracting alive banks full cargo, while a fallen ally keeps only their pouch.
 game.encounter.set_hp(-1, 0);game.encounter.clear_scouts();game.encounter_number=6;game.encounter_rewarded=true;b.pos=game.battlefield.advance
 var safe_before: int=game.seed_reserve(a).unknown.size()
 game._use_checkpoint(2,false)
 check(not a.wild and not PlayerLifecycle.fallen(a) and PlayerVitals.current_hp(a)==10 and a.lost_health==0
  and game.seed_reserve(a).unknown.size()==safe_before+1,"extraction restores fallen ally while banking only their safe pouch")
 for player in [a,b]: player.wild=true;player[PlayerLifecycle.STATE] = PlayerLifecycle.start_life()
 game.abandon_run(1,a)
 check(not a.wild and b.wild and PlayerLifecycle.fallen(a) and not game._enter_wilds(1,a),
  "abandoned player waits in the Garden while the party expedition continues")
 game.abandon_run(2,b)
 check(not PlayerLifecycle.fallen(a),"ending the party expedition clears the wait before departure")
 for player in [a,b]: player.wild=true;player[PlayerLifecycle.STATE] = PlayerLifecycle.start_life();player[PlayerVitals.STATE] = player[PlayerVitals.STATE].with_hp(1);player[PlayerVitals.STATE] = player[PlayerVitals.STATE].with_native_max_hp(8);player.lost_health=2
 game.damage_player(1,a,100);game.damage_player(2,b,100)
 check(not a.wild and not b.wild and PlayerVitals.current_hp(a)==10 and a.lost_health==0 and a.carried_seeds.is_empty(),"party wipe returns everyone and restores sacrificed hearts")
 # Newer revival state must survive an older movement packet.
 var view=load("res://network_presentation.gd").new()
 view.accept_vital(1,{"revision":3,"hp":8,"max_hp":8,"fallen":false,"lost_health":2,"damage_seq":1})
 var stale={"vitals_revision":2,"hp":0,"max_hp":10,"fallen":true,"lost_health":0,"damage_seq":1};view.merge_health(1,stale)
 check(not stale.fallen and stale.hp==8 and stale.lost_health==2,"stale snapshots cannot undo revived state or penalty")
 a.wild=true;a[PlayerLifecycle.STATE] = a[PlayerLifecycle.STATE].fall();a[PlayerVitals.STATE] = a[PlayerVitals.STATE].with_hp(0);a.lost_health=2;a[PlayerVitals.STATE] = a[PlayerVitals.STATE].with_native_max_hp(8)
 b.wild=true;b[PlayerLifecycle.STATE] = b[PlayerLifecycle.STATE].clear_inactive();b[PlayerVitals.STATE] = b[PlayerVitals.STATE].with_hp(8)
 game.abandon_run(2,b)
 check(not a.wild and PlayerVitals.current_hp(a)==10 and a.lost_health==0,"last living ally abandoning resolves fallen player's run")
 a.wild=true;a[PlayerLifecycle.STATE] = a[PlayerLifecycle.STATE].fall();a[PlayerVitals.STATE] = a[PlayerVitals.STATE].with_hp(0);a.lost_health=2;a[PlayerVitals.STATE] = a[PlayerVitals.STATE].with_native_max_hp(8)
 b.wild=true;b[PlayerLifecycle.STATE] = b[PlayerLifecycle.STATE].clear_inactive();b[PlayerVitals.STATE] = b[PlayerVitals.STATE].with_hp(8)
 var departed_generation := PlayerLifecycle.generation(b)
 game.remove_player(2)
 check(not a.wild and PlayerVitals.current_hp(a)==10 and a.lost_health==0,"disconnecting last living ally resolves fallen player's run")
 game.add_player(2)
 var readmitted: Dictionary = game.players[2]
 check(not PlayerLifecycle.fallen(readmitted) and not PlayerLifecycle.matches(readmitted,departed_generation),
  "reused peer ID starts with a new lifecycle generation")
 game.queue_free();await process_frame
 if not failed: print("PASS: loot visibility/privacy, blue map markers, spectating, revival cost, action guards, travel, wipe and stale health")
 quit(1 if failed else 0)
