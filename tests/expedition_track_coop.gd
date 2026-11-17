extends SceneTree

const ExpeditionCase = preload("res://tests/support/expedition_case.gd")

const PlayerVitals = preload("res://player_vitals.gd")
var game: Node
var base: String
var role: String
var failed:=false
func check(ok: bool,message: String) -> void:
 if not ok:failed=true;printerr("FAIL floor track co-op ",role,": ",message)
func mark(key: String) -> void:
 var file:=FileAccess.open(base+key,FileAccess.WRITE);file.store_string("ok")
func marked(key: String) -> bool:return FileAccess.file_exists(base+key)
func until(predicate: Callable) -> bool:
 var end:=Time.get_ticks_msec()+16000
 while not predicate.call() and Time.get_ticks_msec()<end:await process_frame
 return predicate.call()
func _initialize() -> void:call_deferred("run")
func run() -> void:
 role=OS.get_cmdline_user_args()[0];base="res://.godot/floor-track-"+OS.get_cmdline_user_args()[1]
 game=load("res://world.tscn").instantiate();game.progress.path=base+role;game.local_character.path=base+role+".character";game.guest_character.path=base+role+".guest";root.add_child(game)
 if role=="host":await host_run()
 else:await guest_run()
 game.leave_game("Fixture complete")
 check(game.online_peer == null and game.multiplayer.multiplayer_peer is OfflineMultiplayerPeer, "network shuts down before world removal")
 game.queue_free();await process_frame
 if not failed:print("PASS: expedition floor track co-op ",role," authoritative floor, checkpoint icons, advancing history and Garden reset")
 quit(1 if failed else 0)
func host_run() -> void:
 check(game.host_game()==OK,"host opens")
 if not await until(func():return game.players.size()==2 and game.players.values().all(func(p):return p.profile_ready)):check(false,"admission");return
 for p in game.players.values():ExpeditionCase.set_membership(game, p, true);p.pos=game.battlefield.entry;p[PlayerVitals.STATE] = p[PlayerVitals.STATE].with_hp(10)
 game.encounter.set_hp(-1, 80);game.tactics.ready_at=Time.get_ticks_msec()+60000;game.tactics.winding_up=false;game.encounter.clear_scouts();ExpeditionCase.set_world(game, {"encounter_number": 6})
 check(await until(func():return marked("six")),"guest sees checkpoint six")
 ExpeditionCase.set_world(game, {"encounter_number": 7})
 check(await until(func():return marked("seven")),"guest advances to seven")
 for p in game.players.values():ExpeditionCase.set_membership(game, p, false)
 check(await until(func():return marked("garden")),"guest hides track on return")
 mark("done");await create_timer(.3).timeout
func guest_run() -> void:
 check(game.join_game()==OK,"guest joins")
 if not await until(func():return game.session=="Guest" and game.player_hud.floor_track.visible and game.player_hud.floor_track.floor_number==6):check(false,"authoritative floor six arrives");return
 var track=game.player_hud.floor_track
 check(track.nodes.any(func(n):return n.current and n.label=="6" and n.upgrade and n.extraction),"guest checkpoint matches host schedule")
 mark("six")
 check(await until(func():return track.floor_number==7),"guest floor updates from snapshot")
 check(track.nodes.any(func(n):return n.floor==6 and n.label=="6") and track.nodes.any(func(n):return n.floor==8 and n.label=="?"),"guest preserves history and hides unreached numbers")
 mark("seven")
 check(await until(func():return not track.visible),"Garden hides guest track")
 mark("garden");check(await until(func():return marked("done")),"host completes")
