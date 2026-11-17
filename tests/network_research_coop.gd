extends SceneTree

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
 preload("res://combat_balance_preview.gd").enabled = false
 call_deferred("run")
func run():
 role=OS.get_cmdline_user_args()[0];base="res://.godot/network-research-"+OS.get_cmdline_user_args()[1]
 game=load("res://world.tscn").instantiate();game.progress.path=base+"-"+role+".cfg";game.local_character.path=game.progress.path+".character";game.guest_character.path=game.progress.path+".guest";root.add_child(game)
 if role=="host":await host_run()
 else:await guest_run()
 Input.action_release("right");game.queue_free();await process_frame
 if not failed:print("PASS: network research ",role," live guest locomotion, reliable monster damage, Knowledge research, timers and guest plant offerings")
 quit(1 if failed else 0)
func host_run():
 check(game.host_game()==OK,"host starts")
 if not await until(func():return game.players.size()==2 and game.players.values().all(func(p):return p.profile_ready)):
  check(false,"guest registers");return
 var id=int(game.players.keys()[1]);var p=game.players[id]
 var origin: Vector3=p.pos
 check(await until(func():return marked("walking")),"guest samples walking animation")
 check(p.pos.distance_to(origin)>1.5,"guest input actually moves on authority")
 p.wild=true;p.pos=Vector3(0,0,4);p[PlayerVitals.STATE] = p[PlayerVitals.STATE].with_hp(10);p.guard_until=0;p.hurt_until=0;game.encounter.set_hp(-1, 0);game.encounter.clear_scouts();game.encounter_rewarded=true
 preload("res://enemy_attack_hits.gd").for_world(game).area(p.pos,1.2,Time.get_ticks_msec(),1)
 check(PlayerVitals.current_hp(p)==9,"monster hit applies one half-heart on host")
 check(await until(func():return marked("hit")),"guest confirms reliable HP and hit feedback")
 game.return_to_garden(p);p.pos=game.Stage.HEART;game.players[1].pos=game.Stage.HEART
 game.progress.knowledge=8;game.progress.parts.fill(0)
 game.garden_action(1,'heart_confirm:'+JSON.stringify({"id":"plot_4","plan":{}}))
 check(game.progress.heart.active=="plot_4" and game.progress.heart.available_insight(game.progress)==6,"host starts Knowledge research without materials")
 check(await until(func():return marked("timer")),"research timer reaches guest")
 game.progress.heart.work.plot_4=game.progress.heart.duration("plot_4")-4;game.progress.save_garden()
 check(await until(func():return game.progress.plots.size()==4),"research completes naturally while world runs")
 game.progress.parts[0]=2;game.garden_action(1,"heart_start_flowering")
 check(await until(func():return game.progress.parts[0]==0 and float(game.progress.heart.work.get("flowering",0))>=60),"guest offering accelerates active research")
 check(await until(func():return marked("offering")),"guest sees confirmed material cost and research boost")
 mark("done");check(await until(func():return game.players.size()==1),"guest leaves cleanly");game.leave_game("Network research fixture complete")
func guest_run():
 game.guest_character.data.name="Guest animation probe";game.guest_character.save_profile();check(game.join_game()==OK,"guest connects")
 if not await until(func():return game.session=="Guest" and game.players.has(game.multiplayer.get_unique_id())):
  check(false,"guest accepted");return
 var id=game.multiplayer.get_unique_id()
 Input.action_press("right");var deadline=Time.get_ticks_msec()+2200;var first=Quaternion.IDENTITY;var angle=0.0;var sampled=false;var peak_pace=0.0
 while Time.get_ticks_msec()<deadline:
  if game.stage.avatar_models.has(id):
   var actor=game.stage.avatar_models[id];var pose=actor.skeleton.get_bone_pose_rotation(actor.skeleton.find_bone("thigh.L"))
   if not sampled:first=pose;sampled=true
   angle=maxf(angle,first.angle_to(pose));peak_pace=maxf(peak_pace,float(actor.pace))
  await process_frame
 Input.action_release("right")
 check(sampled and angle>.5 and peak_pace>.5,"real guest shows walking joints between network packets");mark("walking")
 check(await until(func():return game.players.get(id,{}).get("hp",10)==9),"guest receives authoritative damage")
 check(int(game.players[id].get("client_hurt_until",0))>Time.get_ticks_msec(),"guest receives deduplicated hit feedback");mark("hit")
 check(await until(func():return game.heart_state().get("active","")=="plot_4"),"guest sees research project")
 check(game.heart_state().get("insight",0)==6,"guest sees spendable Knowledge decrease");mark("timer")
 check(await until(func():return game.heart_state().get("active","")=="flowering" and game.client_garden[5][0]==2),"guest sees available offering materials")
 game.progression_view.tabs.current_tab=1;game.progression_view.refresh();game.progression_view.heart_infuse_button.pressed.emit()
 check(await until(func():return float(game.heart_state().get("work",{}).get("flowering",0))>=60 and game.client_garden[5][0]==0),"guest offering costs parts and updates research")
 check(game.heart_state().get("unlocked",[]).has("plot_4"),"completed timed bed replicates");mark("offering")
 check(await until(func():return marked("done")),"host flow finishes");game.leave_game("Network research fixture complete")
