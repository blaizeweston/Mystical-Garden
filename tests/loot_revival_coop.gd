extends SceneTree

const PlayerVitals = preload("res://player_vitals.gd")

const Cooldowns = preload("res://player_cooldowns.gd")
var game: Node
var role: String
var base: String
var failed:=false
func check(ok: bool,message: String) -> void:
 if not ok: failed=true;printerr("FAIL revival co-op ",role,": ",message)
func mark(key: String) -> void:
 var file:=FileAccess.open(base+"-"+key,FileAccess.WRITE);file.store_string("ready")
func marked(key: String) -> bool: return FileAccess.file_exists(base+"-"+key)
func until(predicate: Callable) -> bool:
 var deadline:=Time.get_ticks_msec()+18000
 while not predicate.call() and Time.get_ticks_msec()<deadline: await process_frame
 return predicate.call()
func _initialize() -> void:
 preload("res://combat_balance_preview.gd").enabled = false
 call_deferred("run")
func run() -> void:
 role=OS.get_cmdline_user_args()[0];base="res://.godot/revival-net-"+OS.get_cmdline_user_args()[1]
 game=load("res://world.tscn").instantiate();game.progress.path=base+role+".cfg";game.local_character.path=game.progress.path+".character";game.guest_character.path=game.progress.path+".guest";root.add_child(game)
 if role=="host": await host_run()
 else: await guest_run()
 game.queue_free();await process_frame
 if not failed: print("PASS: revival co-op ",role," private blue drops, guest/host spectating, authoritative E revival, max-heart penalty and party wipe")
 quit(1 if failed else 0)
func host_run() -> void:
 check(game.host_game()==OK,"host starts")
 if not await until(func(): return game.players.size()==2 and game.players.values().all(func(p): return p.profile_ready)):
  check(false,"guest registers");return
 var id:=int(game.players.keys()[1]);var p: Dictionary=game.players[id];var host: Dictionary=game.players[1]
 game.battlefield.configure(0,1);game.enemy_hp=100;game.enemy_pos=Vector3(12,0,12);game.enemy_stagger_until=Time.get_ticks_msec()+60000;game.scouts.clear()
 host.wild=true;host.pos=Vector3(1,0,2);p.wild=true;p.pos=Vector3(0,0,2)
 var item: String=game.Items.part_id(game.Parts.HOOK)
 game.wild_item_drops.append({"id":"guest-part","owner":id,"stack":{"item":item,"quantity":1},"position":[0,0,2]})
 check(game.inventory_floor_snapshot(host).is_empty(),"host cannot see guest trophy")
 check(await until(func(): return p.carried_parts[game.Parts.HOOK]==1),"guest picks up visible private part")
 check(game.wild_item_drops.is_empty(),"pickup removes authoritative drop")
 game.damage_player(id,p,100)
 check(p.fallen and p.wild and PlayerVitals.current_hp(p)==0,"guest down remains in expedition")
 check(await until(func(): return marked("guest-spectates")),"guest follows host camera/fog")
 var corpse: Vector3=p.pos
 # Forged down-state action must be rejected by host too.
 check(await until(func(): return marked("blocked")),"guest sends down-state requests")
 check(p.pos==corpse and p[Cooldowns.STATE].deadline(Cooldowns.Q)==0,"down-state movement and skills blocked on authority")
 game.act(1,false)
 check(PlayerVitals.current_hp(p)==8 and PlayerVitals.maximum_hp(p)==8 and p.lost_health==2,"host revives guest through interact")
 check(await until(func(): return marked("guest-revived")),"guest receives lost-heart texture state")
 game.damage_player(1,host,100)
 check(host.wild and host.fallen and game.spectator_view.focus_id(1)==id,"fallen host watches guest")
 mark("revive-host")
 check(await until(func(): return not host.fallen and PlayerVitals.maximum_hp(host)==8),"guest E request revives host")
 check(host.lost_health==2 and PlayerVitals.current_hp(host)==8,"host pays same one-heart cost")
 check(await until(func(): return marked("host-revived")),"guest observes authoritative host revival")
 game.damage_player(1,host,100);game.damage_player(id,p,100)
 check(not host.wild and not p.wild and host.lost_health==0 and p.lost_health==0,"party wipe resets lost hearts")
 check(await until(func(): return marked("wipe")),"guest sees wipe and restored capacity")
 mark("done");check(await until(func(): return game.players.size()==1),"guest leaves normally");game.leave_game("Revival fixture complete")
func capture(name: String) -> void:
 if DisplayServer.get_name()=="headless": return
 await create_timer(.3).timeout
 await RenderingServer.frame_post_draw
 get_root().get_texture().get_image().save_png(base+"-"+name+".png")
func guest_run() -> void:
 game.guest_character.data.name="Revival guest";game.guest_character.save_profile();check(game.join_game()==OK,"guest starts")
 if not await until(func(): return game.session=="Guest" and not game.client_details.is_empty()): check(false,"guest accepted");return
 var id:=game.multiplayer.get_unique_id()
 check(await until(func(): return game.players[id].wild and game.inventory_drop_visuals.models.has("guest-part")),"guest sees own trophy model")
 var model: Node3D=game.inventory_drop_visuals.models["guest-part"]
 check(model.visible and model.position==game.stage.WILD_OFFSET+Vector3(0,0,2),"guest trophy visible in Wilds")
 check(game.exploration.drop_color(game.Items.part_id(game.Parts.HOOK))==Color("#62baff"),"guest minimap uses blue")
 await capture("loot")
 game.send_action(false)
 check(await until(func(): return game.players[id].get("fallen",false)),"guest receives fallen state")
 game._process(.016)
 check(game.spectator_view.target_id==1 and game.exploration.player.distance_to(game.players[1].pos)<.1,"guest camera and fog follow living host")
 check(game.player_hud.state.fallen,"fallen HUD hides combat controls");await capture("spectator");mark("guest-spectates")
 game.request_garden_action.rpc_id(1,"class_skill");game.submit_motion.rpc_id(1,Vector2.RIGHT)
 await create_timer(.35).timeout;mark("blocked")
 var shows_revival := func():
  var player: Dictionary = game.players[id]
  return not player.get("fallen",true) and player.max_hp==8 and not player.has(PlayerVitals.STATE)
 check(await until(shows_revival),"guest receives revived health without the authority owner")
 game._process(.016)
 check(game.player_hud.state.lost_health==2 and game.spectator_view.target_id==0 and game.player_hud.heart_state(8,8,4)==3,"guest restored camera and lost-heart HUD")
 await capture("revived");mark("guest-revived")
 check(await until(func(): return marked("revive-host") and game.players[1].get("fallen",false)),"host fallen state arrives")
 game.send_action(false)
 check(await until(func(): return not game.players[1].get("fallen",true) and game.players[1].max_hp==8),"guest sees host revived")
 mark("host-revived")
 check(await until(func(): return not game.players[id].wild and game.players[id].max_hp==10 and game.players[id].hp==10),"wipe returns guest with full five hearts")
 mark("wipe");check(await until(func(): return marked("done")),"host finishes");game.leave_game("Revival fixture complete")
