extends SceneTree

const PlayerVitals = preload("res://player_vitals.gd")
var game: Node
var role: String
var base: String
var failed:=false
func check(ok: bool,message: String) -> void:
 if not ok:failed=true;printerr("FAIL terrain co-op ",role,": ",message)
func mark(key: String) -> void:
 var file:=FileAccess.open(base+key,FileAccess.WRITE);file.store_string("ok")
func marked(key: String) -> bool:return FileAccess.file_exists(base+key)
func until(predicate: Callable) -> bool:
 var end:=Time.get_ticks_msec()+18000
 while not predicate.call() and Time.get_ticks_msec()<end:await process_frame
 return predicate.call()
func _initialize() -> void:call_deferred("run")
func run() -> void:
 role=OS.get_cmdline_user_args()[0];base="res://.godot/terrain-net-"+OS.get_cmdline_user_args()[1]
 game=load("res://world.tscn").instantiate();game.progress.path=base+role;game.local_character.path=base+role+".character";game.guest_character.path=base+role+".guest";root.add_child(game)
 if role=="host":await host_run()
 else:await guest_run()
 game.leave_game("Fixture complete")
 check(game.online_peer == null and game.multiplayer.multiplayer_peer is OfflineMultiplayerPeer, "network shuts down before world removal")
 game.queue_free();await process_frame
 if not failed:print("PASS: terrain co-op ",role," incompatible geometry rejected, seed reconstruction, gate positions and matched collision")
 quit(1 if failed else 0)
func incompatible(_id: int) -> void:
 game.set_meta("join_phase","compatibility")
 var payload: Dictionary={"game":"mystical-garden","protocol":game.Network.PROTOCOL,"methods":game.network_compatibility.signature,"garden":preload("res://garden_return_catalog.gd").signature,"cultivation":preload("res://cultivation_growth.gd").signature,"terrain":"obsolete-algorithm"}
 game.multiplayer.send_auth(1,JSON.stringify(payload).to_utf8_buffer())
func host_run() -> void:
 check(game.host_game()==OK,"host opens")
 check(await until(func():return marked("rejected")),"guest rejects incompatible terrain")
 if not await until(func():return game.players.size()==2 and game.players.values().all(func(p):return p.profile_ready)):check(false,"compatible guest joins");return
 for seed_value in [91247,91249,91255]:
  game.destination=0;game.depth=2;game.encounter_number=2;game.map_seed=seed_value;game.boss_kind=-1;game.reset_encounter()
  for p in game.players.values():p.wild=true;p.pos=game.battlefield.entry;p[PlayerVitals.STATE] = p[PlayerVitals.STATE].with_hp(10)
  game.enemy_hp=100;game.enemy_ready_at=Time.get_ticks_msec()+60000
  for scout in game.scouts:scout.ready=Time.get_ticks_msec()+60000;scout.rooted_until=Time.get_ticks_msec()+60000
  var f:=ConfigFile.new();f.set_value("floor","entry",game.battlefield.entry);f.set_value("floor","exit",game.battlefield.advance);f.set_value("floor","mask",var_to_bytes(game.battlefield.surface.cells).hex_encode().sha256_text());f.save(base+str(seed_value))
  check(await until(func():return marked("seen"+str(seed_value))),"guest reproduces floor "+str(seed_value))
 mark("done");await create_timer(.3).timeout
func guest_run() -> void:
 # Override only the test's pre-auth payload, using the real transport callback.
 game.guest_character.save_profile()
 game.multiplayer.peer_authenticating.disconnect(game.network_compatibility.begin_check);game.multiplayer.peer_authenticating.connect(incompatible)
 check(game.join_game()==OK,"incompatible connection starts")
 check(await until(func():return game.session=="Solo" and game.status.contains("compatibility")),"old terrain signature rejected with update message")
 mark("rejected")
 game.multiplayer.peer_authenticating.disconnect(incompatible);game.multiplayer.peer_authenticating.connect(game.network_compatibility.begin_check)
 await create_timer(.5).timeout
 check(game.join_game()==OK,"matching connection starts")
 for seed_value in [91247,91249,91255]:
  if not await until(func():return game.session=="Guest" and game.map_seed==seed_value and game.stage.visual_field.configured_key==Vector3i(0,2,seed_value)):check(false,"host's generated floor arrives: "+game.status);return
  var f:=ConfigFile.new();check(f.load(base+str(seed_value))==OK,"host floor receipt available")
  var field=game.stage.visual_field
  check(field.entry==f.get_value("floor","entry") and field.advance==f.get_value("floor","exit") and var_to_bytes(field.surface.cells).hex_encode().sha256_text()==f.get_value("floor","mask"),"host/guest share randomized gates and exact traversable surface")
  var id:=game.multiplayer.get_unique_id();var p: Dictionary=game.players[id];var original: Vector3=p.pos
  game.net_motion.predict_step(game,p,Vector2.RIGHT,.02)
  check(field.clear_line(original,p.pos,field.CLEARANCE),"predicted movement uses the same final floor collision")
  mark("seen"+str(seed_value))
 check(await until(func():return marked("done")),"host completes")
