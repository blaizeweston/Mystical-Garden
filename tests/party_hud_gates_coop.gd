extends SceneTree
const PlayerVitals = preload("res://player_vitals.gd")
var game: Node
var base: String
var role: String
var failed:=false
func check(ok: bool,message: String):
 if not ok:failed=true;printerr("FAIL party HUD co-op ",role,": ",message)
func mark(key: String):
 var file=FileAccess.open(base+key,FileAccess.WRITE);file.store_string("ok")
func marked(key: String) -> bool:return FileAccess.file_exists(base+key)
func until(predicate: Callable) -> bool:
 var deadline:=Time.get_ticks_msec()+16000
 while not predicate.call() and Time.get_ticks_msec()<deadline:await process_frame
 return predicate.call()
func _initialize():
 preload("res://combat_balance_preview.gd").enabled = false
 call_deferred("run")
func run():
 role=OS.get_cmdline_user_args()[0];base="res://.godot/party-ui-net-"+OS.get_cmdline_user_args()[1]
 game=load("res://world.tscn").instantiate();game.progress.path=base+role;game.local_character.path=base+role+".character";game.guest_character.path=base+role+".guest";root.add_child(game)
 if role=="host":await host_run()
 else:await guest_run()
 game.queue_free();await process_frame
 if not failed:print("PASS: party HUD co-op ",role," guest gate range, teammate names, damage, fallen skull and revival")
 quit(1 if failed else 0)
func host_run():
 check(game.host_game()==OK,"host opens")
 if not await until(func():return game.players.size()==2 and game.players.values().all(func(p):return p.profile_ready)):check(false,"registration");return
 var guest_id: int=game.players.keys().filter(func(i):return i!=1)[0];var p: Dictionary=game.players[1];var friend: Dictionary=game.players[guest_id]
 p.character.name="Host Gardener";friend.pos=game.Stage.GATE+Vector3(2.65,0,0)
 check(await until(func():return marked("gate")),"guest opens gate at new range")
 for player in game.players.values():player.wild=true;player[PlayerVitals.STATE]=PlayerVitals.Health.new(10,10);player.pos=Vector3.ZERO
 game.enemy_hp=80;game.enemy_pos=Vector3(0,0,8);game.enemy_ready_at=Time.get_ticks_msec()+60000;game.enemy_winding_up=false;game.scouts.clear()
 check(await until(func():return marked("party")),"guest sees host portrait/name/health")
 game.damage_player(1,p,3);check(await until(func():return marked("damage")),"guest sees host damage")
 game.damage_player(1,p,99);check(await until(func():return marked("skull")),"guest sees fallen host")
 check(game.Life.revive(game,guest_id,1),"guest revives host")
 check(await until(func():return marked("revived")),"guest sees restored portrait and reduced max health")
 mark("done");check(await until(func():return game.players.size()==1),"guest disconnects")
 game._process(.016);check(not game.player_hud.party_panel.visible,"host panel removes disconnected teammate")
func guest_run():
 game.guest_character.save_profile();check(game.join_game()==OK,"guest connects")
 var id:=game.multiplayer.get_unique_id()
 if not await until(func():return game.session=="Guest" and not game.client_details.is_empty() and game.players[id].pos.distance_to(game.Stage.GATE)<2.75):check(false,"Garden position arrives");return
 game.send_action(false);check(await until(func():return game.loadout_menu.visible),"authoritative gate interaction at 2.65m")
 check(not game.player_hud.party_panel.visible,"no Garden party clutter");mark("gate")
 check(await until(func():return game.player_hud.party_panel.visible and game.player_hud.party_panel.rows.size()==1 and game.player_hud.party_panel.rows[0].name=="Host Gardener" and game.player_hud.party_panel.rows[0].hp==10),"public teammate HUD state")
 game.toggle_overlay(null);mark("party")
 check(await until(func():return game.player_hud.party_panel.rows[0].hp==7),"remote host health damage");mark("damage")
 check(await until(func():return game.player_hud.party_panel.rows[0].fallen),"skull state");mark("skull")
 check(await until(func():return not game.player_hud.party_panel.rows[0].fallen and game.player_hud.party_panel.rows[0].max_hp==8 and game.player_hud.party_panel.rows[0].hp>0),"revived health and portrait")
 mark("revived");check(await until(func():return marked("done")),"host finishes");game.leave_game("Party HUD fixture")
