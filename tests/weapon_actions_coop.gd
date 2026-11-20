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
 if not failed:print("PASS: weapon actions co-op ",role," bow draw, projectile footprint, and two-handed scythe contact")
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
 p.frame=3;p.weapon_kind=1;p[WeaponActions.STATE] = p[WeaponActions.STATE].clear_active();p[WeaponActions.STATE] = p[WeaponActions.STATE].with_ready_at(0)
 game.tactics.position=Vector3(0,0,1.45)
 var before: int=game.enemy_health()
 mark("scythe-ready")
 check(await until(func():return marked("scythe-checked")),"guest confirms the scythe swing")
 check(await until(func():return game.enemy_health()<before),"scythe contact damages the enemy on the host after its wind-up")
 mark("done");check(await until(func():return game.players.size()==1),"guest disconnects")
func guest_run():
 game.guest_character.data.active_class=2
 game.guest_character.data.appearance=preload("res://character_appearance.gd").DEFAULT.duplicate();game.guest_character.data.appearance[5]=1;game.guest_character.data.appearance[6]=0;game.guest_character.data.appearance[7]=100;game.guest_character.data.appearance[8]=100
 game.guest_character.save_profile();check(game.session_world.join()==OK,"guest joins")
 var id:=game.multiplayer.get_unique_id()
 if not await until(func():return marked("ready") and game.network_session.role()=="Guest" and game.guest_replication.has_details() and ExpeditionCase.is_wild(game.players.get(id,{}))):check(false,"Wilds state");return
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
  if not actor.is_empty() and str(actor.animator.current_animation)=="Attack_bow":
   saw_clip=true
   if aim.x>0:
    aim=Vector2(0,1)
    next_input=0
   var weapon: Node3D=actor.visual_weapon
   var arrow: Node3D=weapon.get_node("NockedArrow")
   var phase:=float(actor.get("motion_phase",1.0))
   if arrow.visible and phase>.10 and phase<.55:
    var draw:=smoothstep(0,.55,phase)
    var nock:=weapon.to_global(Vector3(0,.2,-.2-.25*draw))
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
 if not await until(func():return marked("scythe-ready") and Motion.form(game.players.get(id,{}))=="scythe"):
  check(false,"host scythe loadout arrives");return
 game.submit_combat.rpc_id(1,Vector2(0,1),true)
 var scythe_gripped:=await until(func():
  var player: Dictionary=game.stage.avatar_models.get(id,{})
  if player.is_empty() or str(player.animator.current_animation)!="Attack_scythe":
   return false
  var scythe: Node3D=player.visual_weapon
  return scythe.has_node("HarvestScytheModel") and scythe.is_visible_in_tree() and scythe.to_global(Vector3.ZERO).distance_to(Field.hand(player,false))<.001 and scythe.to_global(scythe.get_meta("support_grip")).distance_to(Field.hand(player,true))<.035)
 check(scythe_gripped,"both visible guest hands stay on the scythe through its attack")
 check(await until(func():return game.guest_replication.received_events().any(func(e):return e.event.kind=="swing" and str(e.event.get("form",""))=="scythe")),"guest receives the scythe swing visual")
 game.submit_combat.rpc_id(1,Vector2(0,1),false)
 mark("scythe-checked")
 check(await until(func():return marked("done")),"host finishes")
 game.session_world.leave("Weapon animation fixture")
