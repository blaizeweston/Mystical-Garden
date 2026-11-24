extends SceneTree
const UIFixture = preload("res://tests/support/gameplay_ui_case.gd")
const Conditions = preload("res://player_hit_conditions.gd")
const Protection = preload("res://player_protection.gd")

const SessionCase = preload("res://tests/support/session_case.gd")

const ExpeditionCase = preload("res://tests/support/expedition_case.gd")

const PlayerVitals = preload("res://player_vitals.gd")
var game: Node
var base: String
var role: String
var failed=false
func check(ok: bool,message: String):
 if not ok:failed=true;printerr("FAIL network research ",role,": ",message)
func mark(key: String):
 var file=FileAccess.open(base+"-"+key,FileAccess.WRITE);file.store_string("ready")
func marked(key: String) -> bool:return FileAccess.file_exists(base+"-"+key)
func until(predicate: Callable,seconds: float=25.0) -> bool:
 var deadline=Time.get_ticks_msec()+int(seconds*1000)
 while not predicate.call() and Time.get_ticks_msec()<deadline:await process_frame
 return predicate.call()
func _initialize():
 call_deferred("run")
func run():
 role=OS.get_cmdline_user_args()[0];base="res://.godot/network-research-"+OS.get_cmdline_user_args()[1]
 game=load("res://world.tscn").instantiate();game.progress.path=base+"-"+role+".cfg";game.local_character.path=game.progress.path+".character";game.guest_character.path=game.progress.path+".guest";root.add_child(game)
 if role=="host":await host_run()
 else:await guest_run()
 Input.action_release("right");game.queue_free();await process_frame
 if not failed:print("PASS: network research ",role," live guest locomotion, reliable monster damage, Knowledge research, immediate unlocks and guest authorization")
 quit(1 if failed else 0)
func host_run():
 check(game.session_world.host()==OK,"host starts")
 if not await until(func():return game.players.size()==2 and game.players.values().all(func(p):return SessionCase.Session.ready_for(p))):
  check(false,"guest registers");return
 var id=int(game.players.keys()[1]);var p=game.players[id]
 var origin: Vector3=p.pos
 check(await until(func():return marked("walking")),"guest samples walking animation")
 check(p.pos.distance_to(origin)>1.5,"guest input actually moves on authority")
 ExpeditionCase.set_membership(game, p, true);p.pos=Vector3(0,0,4);p[PlayerVitals.STATE] = p[PlayerVitals.STATE].with_hp(100);p[Protection.STATE] = p[Protection.STATE].clear_guard();p[Conditions.STATE] = p[Conditions.STATE].clear_grace();game.encounter.set_hp(-1, 0);game.encounter.clear_scouts();game.encounter_rewarded=true
 preload("res://enemy_attack_hits.gd").for_world(game).area(p.pos,1.2,Time.get_ticks_msec(),1)
 check(PlayerVitals.current_hp(p)==90,"monster hit applies ten HP on host")
 check(await until(func():return marked("hit")),"guest confirms reliable HP and hit feedback")
 game.expedition_transitions.return_member(preload("res://network_session.gd").peer_for(p));p.pos=game.Stage.HEART;game.players[1].pos=game.Stage.HEART
 game.progress.knowledge=8;game.progress.parts.fill(0)
 var existing_beds: int=game.progress.plots.size()
 game.garden_action(1,"heart_start_plot_4")
 check(game.progress.heart.has("plot_4") and game.progress.heart.available_insight(game.progress)==6 and game.progress.plots.size()==existing_beds,"immediate bed permission with one Knowledge debit")
 check(await until(func():return marked("attempt")),"guest attempts free unlock")
 check(await until(func():return marked("denied")),"guest request made")
 check(not game.progress.flowering_unlocked,"guest cannot buy free research")
 game.garden_action(1,"heart_start_flowering")
 check(await until(func():return marked("offering")),"guest sees host-confirmed free unlock")
 mark("done");check(await until(func():return game.players.size()==1),"guest leaves cleanly");game.session_world.leave("Network research fixture complete")
func guest_run():
 game.guest_character.data.name="Guest animation probe";game.guest_character.save_profile();check(game.session_world.join()==OK,"guest connects")
 if not await until(func():return game.network_session.role()=="Guest" and game.players.has(game.multiplayer.get_unique_id())):
  check(false,"guest accepted");return
 var id=game.multiplayer.get_unique_id()
 Input.action_press("right");var deadline=Time.get_ticks_msec()+2200;var first=Quaternion.IDENTITY;var angle=0.0;var sampled=false;var peak_pace=0.0
 while Time.get_ticks_msec()<deadline:
  if game.stage.avatar_models.has(id):
   var actor=game.stage.avatar_models[id];var pose=actor.field_rig.skeleton.get_bone_pose_rotation(actor.field_rig.skeleton.find_bone("thigh_l"))
   if not sampled:first=pose;sampled=true
   angle=maxf(angle,first.angle_to(pose));peak_pace=maxf(peak_pace,float(actor.pace))
  await process_frame
 Input.action_release("right")
 check(sampled and angle>.5 and peak_pace>.5,"real guest shows walking joints between network packets");mark("walking")
 check(await until(func():return game.players.get(id,{}).get("hp",-1)==90),"guest receives authoritative damage")
 check(int(game.players[id].get("client_hurt_until",0))>Time.get_ticks_msec(),"guest receives deduplicated hit feedback");mark("hit")
 check(await until(func():return game.heart_state().get("unlocked",[]).has("plot_4")),"guest sees immediate purchase")
 var panel=UIFixture.control(game,"progression_view")
 panel.tabs.current_tab=1;panel.refresh()
 var shown: Dictionary=game.progression_ui_data({"tab":1,"chosen":"heart_flowering"})
 check(shown.heart.insight==6 and not shown.may_start_research and panel.heart_start_button.disabled,"guest reads confirmed balance with host-only purchase control")
 shown.heart.unlocked.append("flowering")
 check(not game.heart_state().unlocked.has("flowering"),"detached projection cannot unlock Flowering")
 game.send_garden_action("heart_start_flowering");mark("attempt")
 check(await until(func():return game.status.contains("host restores")),"host refused guest research request");mark("denied")
 check(await until(func():return game.heart_state().get("unlocked",[]).has("flowering")),"host's free purchase replicated");mark("offering")
 check(await until(func():return marked("done")),"host flow finishes");game.session_world.leave("Network research fixture complete")
