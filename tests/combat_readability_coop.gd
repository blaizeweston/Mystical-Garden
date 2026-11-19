extends SceneTree
const OutgoingHits = preload("res://outgoing_hits.gd")
const HitSession = preload("res://network_session.gd")
const ClassActions = preload("res://native_class_actions.gd")

const SessionCase = preload("res://tests/support/session_case.gd")

const ExpeditionCase = preload("res://tests/support/expedition_case.gd")

const IncomingPlayerHit = preload("res://incoming_player_hit.gd")
const PlayerLifecycle = preload("res://player_lifecycle.gd")

const PlayerVitals = preload("res://player_vitals.gd")
const Attacks=preload("res://enemy_attack.gd")
var game: Node
var base: String
var role: String
var failed:=false
func check(ok: bool,message: String):
 if not ok:failed=true;printerr("FAIL combat feedback co-op ",role,": ",message)
func mark(key: String):
 var f=FileAccess.open(base+key,FileAccess.WRITE);f.store_string("ok")
func marked(key: String) -> bool:return FileAccess.file_exists(base+key)
func until(predicate: Callable) -> bool:
 var deadline:=Time.get_ticks_msec()+16000
 while not predicate.call() and Time.get_ticks_msec()<deadline:await process_frame
 return predicate.call()
func _initialize():call_deferred("run")
func run():
 role=OS.get_cmdline_user_args()[0];base="res://.godot/readability-net-"+OS.get_cmdline_user_args()[1]
 game=load("res://world.tscn").instantiate();game.progress.path=base+role;game.local_character.path=base+role+".character";game.guest_character.path=base+role+".guest";root.add_child(game)
 if role=="host":await host_run()
 else:await guest_run()
 game.queue_free();await process_frame
 if not failed:print("PASS: combat feedback co-op ",role," committed damage, ability names, deduplicated guest popups and cleanup")
 quit(1 if failed else 0)
func host_run():
 check(SessionCase.World.host(game)==OK,"host opens")
 if not await until(func():return game.players.size()==2 and game.players.values().all(func(p):return SessionCase.Session.ready_for(p))):check(false,"registration");return
 var id: int=game.players.keys().filter(func(i):return i!=1)[0];var p: Dictionary=game.players[id]
 p.pos=game.Stage.HEART
 var tree=game.Classes.connected_tree(int(p.frame))
 game.handle_loadout_action(id,p,"learn_%d_%d"%[int(p.frame),tree.REQUEST_OFFSET])
 check(tree.path(p.character)==["vanguard"],"guest selects a free native Warden focus before combat")
 for player in game.players.values():ExpeditionCase.set_membership(game, player, true);player[PlayerVitals.STATE] = player[PlayerVitals.STATE].with_hp(10);player.pos=Vector3(0,0,-1)
 game.encounter.clear_scouts();game.encounter.set_hp(-1, 50);game.tactics.position=Vector3(0,0,1);game.tactics.ready_at=Time.get_ticks_msec()+60000;game.tactics.winding_up=false;game.enemy_mutations=0
 check(await until(func():return marked("ready")),"guest sees Wilds")
 game.Transactions.run(game,func():
  OutgoingHits.hit_world(game, HitSession.peer_for(p), -1, p.pos, game.weapon_stats(p), Time.get_ticks_msec())
  IncomingPlayerHit.apply_health_loss(game, id, PlayerLifecycle.generation(p), 1)
  ClassActions.cast_world(game, id, 0))
 check(await until(func():return marked("verified")),"guest verifies feedback")
 var at:=Vector3(-2.5,0,0)
 var stag: Dictionary=game.make_scout(2,at,1)
 var now:=Time.get_ticks_msec()
 Attacks.lock(game,stag,"charge",at+Vector3.BACK*1.7,now+650)
 var mix: Node=game.get_node("EventAudio")
 check(await until(func():return mix.last_played.has("enemy_charge_windup") and marked("windup")),"both listeners receive the committed warning")
 check(not mix.last_played.has("enemy_charge_release"),"no launch sound plays during wind-up")
 preload("res://scout_behavior.gd").release(game, stag,game.Enemies.get_kind(2),now+650)
 check(await until(func():return mix.last_played.has("enemy_charge_release") and marked("release")),"both listeners receive the confirmed release")
 mark("done");check(await until(func():return game.players.size()==1),"guest disconnects")
func guest_run():
 game.guest_character.save_profile();check(SessionCase.World.join(game)==OK,"guest connects")
 var id:=game.multiplayer.get_unique_id()
 if not await until(func():return game.network_session.role()=="Guest" and not game.client_details.is_empty() and ExpeditionCase.is_wild(game.players.get(id,{}))):check(false,"Wilds state arrives");return
 game.combat_visuals.set_process(false);mark("ready")
 check(await until(func():return game.received_combat_events.any(func(e):return e.event.kind=="ability") and game.players[id].hp==9),"committed ability and health arrive")
 game._process(.016)
 var events: Array=game.guest_combat_events(game.players[id])
 check(events.any(func(e):return e.kind=="impact" and e.shape=="hurt" and int(e.get("amount",0))==1),"player damage uses actual amount")
 check(events.any(func(e):return e.kind=="impact" and e.shape=="hit" and int(e.get("amount",0))>0),"outgoing hit reaches guest")
 check(events.any(func(e):return e.kind=="ability" and not str(e.get("label","")).is_empty()),"named ability reaches guest")
 var fx=game.combat_visuals
 check(fx.feedback.labels.size()==3,"two damage values and one ability label: "+str(fx.feedback.labels.map(func(item):return item.node.text)))
 var count: int=fx.feedback.labels.size();fx.sync(events,[],"%d:%d:%d:%s"%[game.participation.route(),game.participation.floor(),game.participation.seed(),str(true)],game.players[id].pos)
 check(fx.feedback.labels.size()==count,"repeat details cannot duplicate labels")
 fx.clear();check(fx.feedback.labels.is_empty() and fx.feedback.flashes.is_empty(),"cleanup restores all feedback")
 var mix: Node=game.get_node("EventAudio")
 check(mix.last_played.has("combat_hurt"),"confirmed guest damage reaches the audio mixer")
 mark("verified")
 check(await until(func():return mix.last_played.has("enemy_charge_windup")),"guest hears the warning")
 check(not mix.last_played.has("enemy_charge_release"),"guest never guesses the release from the warning")
 mark("windup")
 check(await until(func():return mix.last_played.has("enemy_charge_release")),"guest hears the resolved release")
 mark("release")
 check(await until(func():return marked("done")),"host finishes");SessionCase.World.leave(game,"Feedback fixture")
