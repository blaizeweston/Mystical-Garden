extends SceneTree
const WorldViewCase = preload("res://tests/support/world_presentation_case.gd")
const UIFixture = preload("res://tests/support/gameplay_ui_case.gd")

const SessionCase = preload("res://tests/support/session_case.gd")

const ExpeditionCase = preload("res://tests/support/expedition_case.gd")

const IncomingPlayerHit = preload("res://incoming_player_hit.gd")

const PlayerLifecycle = preload("res://player_lifecycle.gd")
const PlayerVitals = preload("res://player_vitals.gd")

const Orb=preload("res://health_orb.gd")
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
 call_deferred("run")
func run() -> void:
 role=OS.get_cmdline_user_args()[0];base="res://.godot/revival-net-"+OS.get_cmdline_user_args()[1]
 game=load("res://world.tscn").instantiate();game.progress.path=base+role+".cfg";game.local_character.path=game.progress.path+".character";game.guest_character.path=game.progress.path+".guest";root.add_child(game)
 if role=="host": await host_run()
 else: await guest_run()
 game.queue_free();await process_frame
 if not failed: print("PASS: revival co-op ",role," private blue drops, guest/host spectating, authoritative E revival, capacity penalty and party wipe")
 quit(1 if failed else 0)
func host_run() -> void:
 check(game.session_world.host()==OK,"host starts")
 if not await until(func(): return game.players.size()==2 and game.players.values().all(func(p): return SessionCase.Session.ready_for(p))):
  check(false,"guest registers");return
 var id:=int(game.players.keys()[1]);var p: Dictionary=game.players[id];var host: Dictionary=game.players[1]
 game.battlefield.configure(0,1);game.encounter.set_hp(-1, 100);game.tactics.position=Vector3(12,0,12);game.tactics.stagger_until=Time.get_ticks_msec()+60000;game.encounter.clear_scouts()
 ExpeditionCase.set_membership(game, host, true);host.pos=Vector3(1,0,2);ExpeditionCase.set_membership(game, p, true);p.pos=Vector3(0,0,2)
 var item: String=game.Items.part_id(game.Parts.HOOK)
 game.wild_item_drops.append({"id":"guest-part","owner":id,"stack":{"item":item,"quantity":1},"position":[0,0,2]})
 check(game.inventory_floor_snapshot(host).is_empty(),"host cannot see guest trophy")
 check(await until(func(): return p.carried_parts[game.Parts.HOOK]==1),"guest picks up visible private part")
 check(game.wild_item_drops.is_empty(),"pickup removes authoritative drop")
 IncomingPlayerHit.apply_health_loss(game, id, PlayerLifecycle.generation(p), 100)
 check(PlayerLifecycle.fallen(p) and ExpeditionCase.is_wild(p) and PlayerVitals.current_hp(p)==0,"guest down remains in expedition")
 check(await until(func(): return marked("guest-spectates")),"guest follows host camera/fog")
 var corpse: Vector3=p.pos
 # Forged down-state action must be rejected by host too.
 check(await until(func(): return marked("blocked")),"guest sends down-state requests")
 check(p.pos==corpse and p[Cooldowns.STATE].deadline(Cooldowns.Q)==0,"down-state movement and skills blocked on authority")
 game.act(1,false)
 check(PlayerVitals.current_hp(p)==80 and PlayerVitals.maximum_hp(p)==80 and p.lost_health==20,"host revives guest through interact")
 check(await until(func(): return marked("guest-revived")),"guest receives lost-capacity state")
 IncomingPlayerHit.apply_health_loss(game, 1, PlayerLifecycle.generation(host), 100)
 check(ExpeditionCase.is_wild(host) and PlayerLifecycle.fallen(host) and game.spectator_view.focus_id(1)==id,"fallen host watches guest")
 mark("revive-host")
 check(await until(func(): return not PlayerLifecycle.fallen(host) and PlayerVitals.maximum_hp(host)==80),"guest E request revives host")
 check(host.lost_health==20 and PlayerVitals.current_hp(host)==80,"host pays same 20-HP capacity cost")
 check(await until(func(): return marked("host-revived")),"guest observes authoritative host revival")
 IncomingPlayerHit.apply_health_loss(game, 1, PlayerLifecycle.generation(host), 100);IncomingPlayerHit.apply_health_loss(game, id, PlayerLifecycle.generation(p), 100)
 check(not ExpeditionCase.is_wild(host) and not ExpeditionCase.is_wild(p) and host.lost_health==0 and p.lost_health==0,"party wipe resets lost capacity")
 check(await until(func(): return marked("wipe")),"guest sees wipe and restored capacity")
 mark("done");check(await until(func(): return game.players.size()==1),"guest leaves normally");game.session_world.leave("Revival fixture complete")
func capture(name: String) -> void:
 if DisplayServer.get_name()=="headless": return
 await create_timer(.3).timeout
 await RenderingServer.frame_post_draw
 get_root().get_texture().get_image().save_png(base+"-"+name+".png")
func guest_run() -> void:
 game.guest_character.data.name="Revival guest";game.guest_character.save_profile();check(game.session_world.join()==OK,"guest starts")
 if not await until(func(): return game.network_session.role()=="Guest" and game.guest_replication.has_details()): check(false,"guest accepted");return
 var id:=game.multiplayer.get_unique_id()
 check(await until(func(): return ExpeditionCase.is_wild(game.players[id]) and game.get_node("InventoryDrops").models.has("guest-part")),"guest sees own trophy model")
 var model: Node3D=game.get_node("InventoryDrops").models["guest-part"]
 check(model.visible and model.position==game.stage.WILD_OFFSET+Vector3(0,0,2),"guest trophy visible in Wilds")
 check(WorldViewCase.component(game,"map").drop_color(game.Items.part_id(game.Parts.HOOK))==Color("#62baff"),"guest minimap uses blue")
 await capture("loot")
 game.send_action(false)
 check(await until(func(): return game.players[id].get("fallen",false)),"guest receives fallen state")
 game._process(.016)
 check(game.spectator_view.target_peer()==1 and WorldViewCase.component(game,"map").player.distance_to(game.players[1].pos)<.1,"guest camera and fog follow living host")
 check(UIFixture.control(game,"player_hud").state.fallen,"fallen HUD hides combat controls");await capture("spectator");mark("guest-spectates")
 game.request_garden_action.rpc_id(1,"class_skill");game.submit_motion.rpc_id(1,Vector2.RIGHT)
 await create_timer(.35).timeout;mark("blocked")
 var shows_revival := func():
  var player: Dictionary = game.players[id]
  return not player.get("fallen",true) and player.max_hp==80 and not player.has(PlayerVitals.STATE) and not player.has(PlayerLifecycle.STATE)
 check(await until(shows_revival),"guest receives revival scalars without the health or lifecycle owners")
 game._process(.016)
 check(UIFixture.control(game,"player_hud").state.lost_health==20 and game.spectator_view.target_peer()==0 and Orb.fractions(80,80,20).is_equal_approx(Vector2(.8,.8)),"guest restored camera and lost-capacity HUD")
 await capture("revived");mark("guest-revived")
 check(await until(func(): return marked("revive-host") and game.players[1].get("fallen",false)),"host fallen state arrives")
 game.send_action(false)
 check(await until(func(): return not game.players[1].get("fallen",true) and game.players[1].max_hp==80),"guest sees host revived")
 mark("host-revived")
 check(await until(func(): return not ExpeditionCase.is_wild(game.players[id]) and game.players[id].max_hp==100 and game.players[id].hp==100),"wipe returns guest with full health capacity")
 mark("wipe");check(await until(func(): return marked("done")),"host finishes");game.session_world.leave("Revival fixture complete")
