extends SceneTree

const WeaponActions = preload("res://player_weapon_actions.gd")

const SessionCase = preload("res://tests/support/session_case.gd")

const ExpeditionCase = preload("res://tests/support/expedition_case.gd")

const Cooldowns = preload("res://player_cooldowns.gd")
const Field=preload("res://field_traveller.gd")
const Motion=preload("res://weapon_motion.gd")
var game: Node
var role: String
var base: String
var failed:=false
func check(ok: bool,message: String):
 if not ok:failed=true;printerr("FAIL weapon actions co-op ",role,": ",message)
func mark(key: String):
 var f=FileAccess.open(base+key,FileAccess.WRITE);f.store_string("ok")
func marked(key: String) -> bool:return FileAccess.file_exists(base+key)
func until(predicate: Callable) -> bool:
 var deadline:=Time.get_ticks_msec()+16000
 while not predicate.call() and Time.get_ticks_msec()<deadline:await process_frame
 return predicate.call()
func _initialize():call_deferred("run")
func run():
 role=OS.get_cmdline_user_args()[0];base="res://.godot/weapon-net-"+OS.get_cmdline_user_args()[1]
 game=load("res://world.tscn").instantiate();game.progress.path=base+role;game.local_character.path=base+role+".character";game.guest_character.path=base+role+".guest";root.add_child(game)
 if role=="host":await host_run()
 else:await guest_run()
 if game.network_session.transport()!=null:game.session_world.leave("Weapon animation fixture")
 check(game.network_session.transport()==null and game.multiplayer.multiplayer_peer is OfflineMultiplayerPeer,"offline before world removal")
 game.queue_free();await process_frame
 if not failed:print("PASS: weapon actions co-op ",role," bow draw, projectile footprint, elevated focus carry and native two-handed scythe contact")
 quit(1 if failed else 0)
func host_run():
 check(game.session_world.host()==OK,"host opens")
 if not await until(func():return game.players.size()==2 and game.players.values().all(func(p):return SessionCase.Session.ready_for(p))):check(false,"registration");return
 var id: int=game.players.keys().filter(func(i):return i!=1)[0];var p: Dictionary=game.players[id]
 check(p.character.appearance[5]==1 and p.character.appearance[6]==0 and p.character.appearance[7]==100,"host receives customized female model and independent sliders")
 game.encounter.set_hp(-1, 80);game.tactics.position=Vector3(0,0,3);game.tactics.ready_at=Time.get_ticks_msec()+60000;game.tactics.winding_up=false;game.encounter.clear_scouts()
 ExpeditionCase.set_membership(game, p, true);p.pos=Vector3.ZERO;p.weapon_kind=0;p.weapon=0;p.secondary=0;p.catalyst=0;p[Cooldowns.STATE] = p[Cooldowns.STATE].with_deadline(Cooldowns.Q, 0)
 mark("ready");check(await until(func():return marked("verified")),"guest confirms attack")
 check(game.enemy_health()<80,"projectile hits on the host")
 check(not game.combat_events.any(func(e):return e.kind=="windup"),"host has no generic bow circle")
 p.frame=1;p.weapon_kind=2;p[WeaponActions.STATE] = p[WeaponActions.STATE].clear_active()
 p[WeaponActions.STATE]=WeaponActions.State.new()
 game.encounter.set_hp(-1,1000)
 mark("focus-ready")
 check(await until(func():return marked("focus-checked")),"guest confirms the focus carry pose")
 check(p[WeaponActions.STATE].basic_step()==2 and game.enemy_health()<1000,"host resolves exactly two guest Seed Focus casts")
 p.frame=3;p.weapon_kind=1;p[WeaponActions.STATE]=WeaponActions.State.new()
 game.tactics.position=Vector3(0,0,1.45)
 var before: int=game.enemy_health()
 mark("scythe-ready")
 check(await until(func():return marked("scythe-checked")),"guest confirms the scythe swing")
 check(await until(func():return game.enemy_health()<before),"scythe contact damages the enemy on the host after its wind-up")
 p.frame=0;p.weapon_kind=1;p[WeaponActions.STATE]=WeaponActions.State.new()
 game.encounter.set_hp(-1,1000);game.tactics.position=Vector3(0,0,2)
 game.tactics.ready_at=Time.get_ticks_msec()+60000;game.tactics.winding_up=false
 game.encounter.clear_scouts()
 var flank: int=game.encounter.register_scout(game.make_scout(0,Vector3(1.6,0,1.6),1))
 game.encounter.set_hp(flank,1000)
 mark("spear-ready")
 check(await until(func():return marked("spear-checked")),"guest sees imported thrust then sweep")
 check(await until(func():return game.enemy_health()<1000 and game.encounter.hp(flank)<1000),"host damages front and flank using the alternating areas after release")
 p.weapon_kind=0;p[WeaponActions.STATE]=WeaponActions.State.new()
 game.encounter.set_hp(-1,1000);game.encounter.clear_scouts()
 mark("rootblade-ready")
 check(await until(func():return marked("rootblade-checked")),"guest sees alternating Rootblade slashes and both returns")
 check(game.enemy_health()<1000,"Rootblade contact remains host authoritative")

 for index in Field.Reviewed.FORMS.size():
  var form: String=Field.Reviewed.FORMS[index]
  p.frame=2 if index<3 else 3;p.weapon_kind=index if index<3 else int({"knives":0,"scythe":1,"whip":2}[form])
  p[WeaponActions.STATE]=WeaponActions.State.new()
  game.encounter.set_hp(-1,1000);game.tactics.position=Vector3(0,0,1.25)
  mark("equip-"+form)
  check(await until(func():return marked("seen-"+form)),"guest confirms both "+form+" attacks")
  check(p[WeaponActions.STATE].basic_step()==2,"two admitted "+form+" attacks")
 mark("done");check(await until(func():return game.players.size()==1),"guest disconnects")
func guest_run():
 game.guest_character.data.active_class=2
 game.guest_character.data.appearance=preload("res://character_appearance.gd").DEFAULT.duplicate();game.guest_character.data.appearance[5]=1;game.guest_character.data.appearance[6]=0;game.guest_character.data.appearance[7]=100;game.guest_character.data.appearance[8]=100
 game.guest_character.save_profile();check(game.session_world.join()==OK,"guest joins")
 var id:=game.multiplayer.get_unique_id()
 if not await until(func():return marked("ready") and game.network_session.role()=="Guest" and game.guest_replication.has_details() and ExpeditionCase.is_wild(game.players.get(id,{}))):check(false,"Wilds state");return
 # Begin the timed redirect after the guest has actually drawn its equipped bow.
 if not await until(func():
  var avatar: Dictionary=game.stage.avatar_models.get(id,{})
  return avatar.has("field_rig") and str(avatar.field_rig.player.current_animation)=="Ready_bow_review"):
  check(false,"guest renders the equipped bow before requesting a draw");return
 check(not game.players[id].has(WeaponActions.STATE) and not game.players[id].has("strike_at")
  and not game.players[id].has("attack_until"),"guest has detached attack presentation, not a second authoritative timeline")
 var aim:=Vector2(1,0)
 var next_input:=0
 var deadline:=Time.get_ticks_msec()+6000;var saw_clip:=false;var saw_draw:=false
 var projectile: Dictionary={}
 var saw_hit:=false
 var saw_windup:=false
 var encounter:=str([game.participation.route(),game.participation.floor(),game.participation.seed()])
 while Time.get_ticks_msec()<deadline:
  var actor: Dictionary=game.stage.avatar_models.get(id,{})
  if not actor.is_empty() and str(actor.field_rig.player.current_animation)=="Attack_bow_upright":
   saw_clip=true
   if aim.x>0:
    aim=Vector2(0,1)
    next_input=0
   var weapon: Node3D=actor.visual_weapon
   var arrow: Node3D=weapon.get_node("NockedArrow")
   var phase:=float(actor.get("motion_phase",1.0))
   if arrow.visible and phase>.10 and phase<.55:
    var nock:=arrow.to_global(Vector3(0,.2,-.2))
    saw_draw=saw_draw or nock.distance_to(Field.hand(actor,false))<.035
  if game.network_session.transport()==null:
   check(false,"guest stays connected through bow action")
   return
  # Match MouseCombat.frame's input cadence. Keep advertising the new aim
  # while released, so a single lost unreliable packet cannot define the shot.
  var now:=Time.get_ticks_msec()
  if now>=next_input:
   next_input=now+50
   game.submit_combat.rpc_id(1,aim,aim.x>0)
  # Capture the RPC-backed events while they are live, independently of
  # visual expiry and the relative arrival of the arrow and hit.
  for entry in game.guest_replication.received_events():
   if entry.key!=encounter:continue
   var event: Dictionary=entry.event
   if event.kind=="windup":saw_windup=true
   if event.kind=="projectile" and projectile.is_empty():projectile=event.duplicate(true)
   if event.kind=="impact" and event.shape=="hit" and event.get("form")=="bow" and event.target_id==-1:saw_hit=true
  if not projectile.is_empty() and saw_hit:break
  await process_frame
 game.submit_combat.rpc_id(1,aim,false)
 check(saw_clip and saw_draw,"guest plays the authored bow animation with the visible draw hand following the nock")
 var actor: Dictionary=game.stage.avatar_models[id]
 check(actor.rig_kind==1 and is_equal_approx(actor.model.scale.y,.92),"guest renders the customized rig at the saved height")
 var bow: Node3D=actor.visual_weapon
 check(bow.is_visible_in_tree() and bow.has_node("VineBowModel") and bow.to_global(Vector3(0,.2,0)).distance_to(Field.hand(actor,true))<.001,"guest bow stays in the visible left hand")
 check(not projectile.is_empty(),"arrow arrives")
 check(saw_hit,"guest receives authoritative bow hit")
 if not projectile.is_empty():
  var event: Dictionary=projectile;var profile: Dictionary=game.WeaponMotion.profile("bow")
  check(float(event.to[2])-float(event.from[2])>1.0 and absf(float(event.to[0])-float(event.from[0]))<.6,"guest can redirect the shot after draw begins")
  check(str(event.form)=="bow" and float(event.projectile_radius)==float(profile.projectile_radius) and float(event.height)==float(profile.height),"same profile controls guest projectile and host collision")
 check(not saw_windup,"guest receives no firing ring")
 mark("verified")
 var focus_lifted:=await until(func():
  var player: Dictionary=game.stage.avatar_models.get(id,{})
  if not marked("focus-ready") or Motion.form(game.players.get(id,{}))!="orb" or not player.has("visual_weapon"):return false
  var focus: Node3D=player.visual_weapon.get_node_or_null("SeedFocusModel")
  if focus==null:return false
  var rig: Skeleton3D=player.field_rig.skeleton
  var pelvis:=rig.to_global(rig.get_bone_global_pose(player.field_rig.pelvis).origin)
  var seed: Node3D=player.visual_weapon.get_node("CoreSeed")
  return seed.global_position.y>pelvis.y+.15)
 check(focus_lifted,"guest receives a focus carried above the pelvis")
 await inspect_focus_casts(id)
 mark("focus-checked")
 if not await until(func():return marked("scythe-ready") and Motion.form(game.players.get(id,{}))=="scythe"):
  check(false,"host scythe loadout arrives");return
 game.submit_combat.rpc_id(1,Vector2(0,1),true)
 var scythe_gripped:=await until(func():
  var player: Dictionary=game.stage.avatar_models.get(id,{})
  if player.is_empty() or str(player.field_rig.player.current_animation)!="Attack_scythe_crossing":
   return false
  var scythe: Node3D=player.visual_weapon
  return scythe.has_node("HarvestScytheModel") and scythe.is_visible_in_tree() and scythe.to_global(scythe.get_meta("handle")).distance_to(Field.hand(player,false))<.001 and scythe.to_global(scythe.get_meta("support_grip")).distance_to(Field.hand(player,true))<.035)
 check(scythe_gripped,"both visible guest hands stay on the scythe through its attack")
 check(await until(func():return game.guest_replication.received_events().any(func(e):return e.event.kind=="swing" and str(e.event.get("form",""))=="scythe")),"guest receives the scythe swing visual")
 game.submit_combat.rpc_id(1,Vector2(0,1),false)
 mark("scythe-checked")
 if not await until(func():return marked("spear-ready") and Motion.form(game.players.get(id,{}))=="spear"):
  check(false,"spear loadout arrives");return
 var clips: Array[String]=[]
 var shapes: Array[String]=[]
 var visible_clips: Array[String]=[]
 var ready_at:=Time.get_ticks_msec()+5000
 var send_at:=0
 while Time.get_ticks_msec()<ready_at and (clips.size()<2 or shapes.size()<2 or visible_clips.size()<2):
  var now:=Time.get_ticks_msec()
  if now>=send_at:
   send_at=now+50;game.submit_combat.rpc_id(1,Vector2(0,1),true)
  var animation: Dictionary=game.players[id].get("attack_anim",{})
  if animation.get("active",false) and str(animation.get("clip","")) in ["Attack_spear","Attack_spear_sweep"] and not clips.has(animation.clip):clips.append(animation.clip)
  var view: Dictionary=game.stage.avatar_models.get(id,{})
  if not view.is_empty():
   var name:=str(view.field_rig.player.current_animation)
   if name in ["Attack_spear","Attack_spear_sweep"] and not visible_clips.has(name):visible_clips.append(name)
  for received in game.guest_replication.received_events():
   var event: Dictionary=received.event
   if event.kind=="swing" and event.get("form","")=="spear" and not shapes.has(str(event.pattern)):
    shapes.append(str(event.pattern))
    check(event.clip==("Attack_spear" if event.pattern=="line" else "Attack_spear_sweep"),"replicated indicator uses the selected clip")
    if event.pattern=="sweep":check(is_equal_approx(float(event.span),deg_to_rad(125)) and is_equal_approx(float(event.yaw_offset),deg_to_rad(7.5)),"guest has the approved sweep sector")
  await process_frame
 game.submit_combat.rpc_id(1,Vector2(0,1),false)
 check(clips==["Attack_spear","Attack_spear_sweep"] and shapes==["line","sweep"],"host-selected thrust precedes sweep without a guest-side counter")
 check(visible_clips.has("Attack_spear") and visible_clips.has("Attack_spear_sweep"),"both imported clips run on the visible guest rig")
 mark("spear-checked")
 if not await until(func():return marked("rootblade-ready") and Motion.form(game.players.get(id,{}))=="blade"):
  check(false,"Rootblade loadout arrives");return
 var blade_clips: Array[String]=[]
 var blade_visible: Array[String]=[]
 var blade_returns: Array[String]=[]
 var blade_events: Array[String]=[]
 ready_at=Time.get_ticks_msec()+6000;send_at=0
 while Time.get_ticks_msec()<ready_at and (blade_clips.size()<2 or blade_visible.size()<2 or blade_returns.size()<2 or blade_events.size()<2):
  var now:=Time.get_ticks_msec()
  if now>=send_at:
   send_at=now+50;game.submit_combat.rpc_id(1,Vector2(0,1),true)
  var animation: Dictionary=game.players[id].get("attack_anim",{})
  if animation.get("active",false) and str(animation.get("clip","")).begins_with("Attack_rootblade") and not blade_clips.has(animation.clip):blade_clips.append(animation.clip)
  var view: Dictionary=game.stage.avatar_models.get(id,{})
  if not view.is_empty():
   var name:=str(view.field_rig.player.current_animation)
   if name.begins_with("Attack_rootblade") and not blade_visible.has(name):blade_visible.append(name)
   if name.begins_with("Recover_rootblade") and not blade_returns.has(name):blade_returns.append(name)
  for received in game.guest_replication.received_events():
   var event: Dictionary=received.event
   if event.kind=="swing" and event.get("form","")=="blade":
    if not blade_events.has(event.clip):blade_events.append(event.clip)
    check(event.pattern=="sweep" and is_equal_approx(float(event.span),1.9) and is_zero_approx(float(event.get("yaw_offset",0))),"both Rootblade slashes replicate the same existing indicator")
  await process_frame
 game.submit_combat.rpc_id(1,Vector2(0,1),false)
 check(blade_clips==["Attack_rootblade_forehand","Attack_rootblade_backhand"],"host selects forehand then backhand without a guest counter")
 check(blade_visible.size()==2 and blade_events.size()==2,"both Rootblade clips arrive in rendered poses and swing events")
 check(blade_returns.has("Recover_rootblade_left") and blade_returns.has("Recover_rootblade_right"),"guest plays both imported return clips")
 check(await until(func():return not game.players[id].get("attack_anim",{}).get("active",false) and not game.stage.avatar_models[id].field_rig.rootblade.has("last_clip")),"stopping after either slash settles back to ready")
 print("ROOTBLADE GUEST clips=",blade_clips," visible=",blade_visible," returns=",blade_returns," indicators=",blade_events)
 mark("rootblade-checked")

 for form in Field.Reviewed.FORMS:
  if not await until(func():return marked("equip-"+form) and Motion.form(game.players.get(id,{}))==form):
   check(false,"guest receives "+form+" loadout");return
  await inspect_alternates(id,form)
  mark("seen-"+form)
 check(await until(func():return marked("done")),"host finishes")
 game.session_world.leave("Weapon animation fixture")

func inspect_alternates(id: int, form: String) -> void:
 var previously_seen := {}
 for entry in game.guest_replication.received_events():previously_seen[entry.event.id]=true
 for step in [1,2]:
  var clip: String=Motion.basic_variant(form,step).clip
  var deadline:=Time.get_ticks_msec()+4000
  var next_send:=0
  var seen_pose:=false
  var seen_event:=false
  while Time.get_ticks_msec()<deadline and not (seen_pose and seen_event):
   var now:=Time.get_ticks_msec()
   if now>=next_send:
    next_send=now+50
    game.submit_combat.rpc_id(1,Vector2(0,1),not seen_pose)
   var actor: Dictionary=game.stage.avatar_models.get(id,{})
   if not actor.is_empty() and str(actor.field_rig.player.current_animation)==clip:seen_pose=true
   for entry in game.guest_replication.received_events():
    var event: Dictionary=entry.event
    if previously_seen.has(event.id) or event.get("clip","")!=clip:continue
    if event.kind==("projectile" if Motion.is_projectile(form) else "swing"):
     seen_event=true
     if Motion.is_projectile(form):check(game.stage.weapon_release_point(event).is_finite(),"guest locates "+clip+" release")
     if form=="scythe":
      var variant:=Motion.basic_variant(form,step)
      check(event.pattern=="sweep" and is_equal_approx(float(event.span),float(variant.span)) and is_equal_approx(float(event.yaw_offset),float(variant.yaw_offset)),"guest receives the matching Scythe footprint")
     if form=="whip":
      var path:=preload("res://weapon_contact.gd").lash_path(event,Vector3.ZERO,Vector3.BACK)
      check(path.size()>=3 and absf(path[-1].z-float(event.reach))<.15,"guest receives the matching lash footprint")
   await process_frame
  game.submit_combat.rpc_id(1,Vector2(0,1),false)
  check(seen_pose and seen_event,"guest sees host-selected pose and contact for "+clip)

func inspect_focus_casts(id: int) -> void:
 var animations: Array[String]=[]
 var releases: Array[String]=[]
 var deadline:=Time.get_ticks_msec()+6000
 var next_send:=0
 while Time.get_ticks_msec()<deadline and releases.size()<2:
  var now:=Time.get_ticks_msec()
  if now>=next_send:
   next_send=now+50
   game.submit_combat.rpc_id(1,Vector2(0,1),true)
  var actor: Dictionary=game.stage.avatar_models[id]
  var clip:=str(actor.field_rig.player.current_animation)
  if clip in ["Attack_focus_push","Attack_focus_gather"] and not animations.has(clip):animations.append(clip)
  for received in game.guest_replication.received_events():
   var event: Dictionary=received.event
   if event.kind!="projectile" or event.get("form","")!="orb" or releases.has(event.clip):continue
   releases.append(event.clip)
   check(event.get("owner",0)==id and event.has("weapon_release") and game.stage.weapon_release_point(event).is_finite(),"guest resolves the cast's hand origin")
  await process_frame
 game.submit_combat.rpc_id(1,Vector2(0,1),false)
 check(animations==["Attack_focus_push","Attack_focus_gather"] and releases==animations,"both rendered casts match the host projectile order")
 check(await until(func():return game.stage.avatar_models[id].field_rig.player.current_animation=="Ready_focus"),"guest returns to the shared cradle")
