extends SceneTree

const WeaponActions = preload("res://player_weapon_actions.gd")

const ExpeditionCase = preload("res://tests/support/expedition_case.gd")

const PlayerVitals = preload("res://player_vitals.gd")
const Motion=preload("res://weapon_motion.gd")
const Contact=preload("res://weapon_contact.gd")
const Avatar=preload("res://traveller_avatar.gd")
const Field=preload("res://field_traveller.gd")
const Models=preload("res://plant_weapon_models.gd")
const Visuals=preload("res://weapon_visuals.gd")
var failed:=false
func check(ok: bool,message: String):
 if not ok:failed=true;printerr("FAIL weapon actions: ",message)
func _initialize():call_deferred("run")
func run():
 var segment:=MeshInstance3D.new();segment.mesh=CylinderMesh.new();segment.mesh.height=1.0
 var a:=Vector3(-.1,.3,-.4);var b:=Vector3(.2,.1,.2)
 preload("res://weapon_visuals.gd").segment(segment,a,b)
 check((segment.transform*Vector3(0,.5,0)).distance_to(b)<.0001 and (segment.transform*Vector3(0,-.5,0)).distance_to(a)<.0001,"rotated string/vine segments end at their actual endpoints")
 segment.free()
 var game=load("res://world.tscn").instantiate();var token:=str(Time.get_ticks_usec())
 game.progress.path="res://.godot/weapon-actions-"+token+".cfg";game.local_character.path=game.progress.path+".character";root.add_child(game)
 game.set_process(false);game.set_physics_process(false);game.combat_visuals.set_process(false)
 var p: Dictionary=game.players[1];ExpeditionCase.set_membership(game, p, true);p.pos=Vector3.ZERO;p[PlayerVitals.STATE] = p[PlayerVitals.STATE].with_hp(10);p.power=0;p.weapon=0;p.secondary=0;p.catalyst=0;p.facing=Vector3(0,0,1);p.aim_direction=p.facing;p.mouse_aim=true
 game.battlefield.configure(0,1);game.battlefield.barriers.clear();game.encounter.clear_scouts();game.encounter.set_hp(-1, 100);game.tactics.position=Vector3(0,0,1.4)
 var actor: Dictionary=game.stage.avatar_models.get(1,{})
 game._process(.016);actor=game.stage.avatar_models[1]
 for sex in 2:
  p.character.appearance[5]=sex
  Avatar.swap(actor,sex)
  var poses: Array=[]
  for c in 5:
   for w in 3:
    p.frame=c;p.weapon_kind=w;p[WeaponActions.STATE] = p[WeaponActions.STATE].clear_active();p.cast_until=0;p[WeaponActions.STATE] = p[WeaponActions.STATE].with_ready_at(0)
    var form:=Motion.form(p);var profile:=Motion.profile(form)
    for clip in profile.get("variants",{}).values():check(actor.animator.has_animation(str(clip)),"crafted delivery clip "+str(clip))
    check(actor.animator.has_animation(str(profile.clip)) and actor.animator.has_animation(str(profile.ready)),"named Blender clips "+str(sex)+":"+form)
    Avatar.animate(actor,true,float(profile.release),form,{"equipped":true},1.0)
    var hand: int=actor.skeleton.find_bone("hand.R")
    var left: int=actor.skeleton.find_bone("hand.L")
    var signature:=str([actor.skeleton.get_bone_global_pose(hand),actor.skeleton.get_bone_global_pose(left)])
    if not poses.has(signature):poses.append(signature)
    game.stage.update_avatar(game.stage.avatars[1],actor,p,game.Stage.WILD_OFFSET,Time.get_ticks_msec(),.016)
    var left_palm:=Field.hand(actor,true)
    var right_palm:=Field.hand(actor,false)
    var anchor:=left_palm if form=="bow" else (left_palm+right_palm)*.5 if form=="orb" else right_palm
    var handle: Vector3=actor.visual_weapon.to_global(actor.visual_weapon.get_meta("handle",Vector3.ZERO))
    check(actor.visual_weapon.is_visible_in_tree() and handle.distance_to(anchor)<.001,"visible weapon follows its field grip: "+form)
    check(actor.has("secondary_weapon")== (form=="knives"),"no residual off-hand weapon "+form)
    if Models.MODELS.has(form):
     var mesh: Node3D=actor.visual_weapon.get_node_or_null(Models.MODELS[form].name)
     check(is_instance_valid(mesh) and (mesh is MeshInstance3D or not mesh.find_children("*","MeshInstance3D",true,false).is_empty()),"the authored model is built through the normal equipment path "+form)
    if form=="knives":
     var offhand: Node3D=actor.secondary_weapon
     check(offhand.has_node("GraftKnifeModel") and offhand.global_position.distance_to(left_palm)<.001,"the matching knife follows the left grip")
    if form=="crossbow":
     arbalest_pose(actor,sex,profile)
    if form=="whip":
     lash_pose(actor,sex)
    if form in ["spear","staff","wand"]:
     Avatar.animate(actor,true,float(profile.release),form,{"equipped":true},1.0)
     preload("res://weapon_visuals.gd").animate(actor,form,float(profile.release),true,0,float(game.Classes.DEFINITIONS[c].weapons[w].reach),{"delivery":"line" if form=="spear" else "projectile"})
     var tip: Node3D=actor.visual_weapon.get_node("WeaponTip")
     check((tip.global_position-Field.hand(actor,false)).dot(Vector3(0,0,1))>0,"weapon tip points toward its attack on model "+str(sex)+":"+form)
    if form=="bow":
     var sample_phase:=float(profile.release)-.01
     Avatar.animate(actor,true,sample_phase,form,{"equipped":true},1.0)
     preload("res://weapon_visuals.gd").animate(actor,form,sample_phase,true,0,6)
     var draw:=smoothstep(0,float(profile.release),sample_phase)
     var nock: Vector3=actor.visual_weapon.global_transform*Vector3(0,.2,-.2-.25*draw)
     check(nock.distance_to(Field.hand(actor,false))<.035,"visible draw hand reaches the bow string on body "+str(sex))
    var stats: Dictionary=game.weapon_stats(p);var description:=Contact.describe(form,stats)
    check(float(description.contact)==float(profile.release),"shared contact marker "+form)
    var outline:=Contact.outline(description,p.pos,p.pos+p.facing*float(stats.reach))
    check(outline.size()>16,"visible delivery footprint "+form)
    game.projectile_queue.clear();game.combat_events.clear();game.encounter.set_hp(-1, 100);game.tactics.position=Vector3(0,0,1.4)
    game.strike_enemy(1,p,p.pos)
    check(not game.combat_events.any(func(e):return e.kind=="windup"),"no generic circle at weapon wind-up "+form)
    check(game.projectile_queue.size()==1,"one coherent attack record "+form)
    var shot: Dictionary=game.projectile_queue[0]
    check(int(shot.release)-Time.get_ticks_msec()<=roundi(float(p[WeaponActions.STATE].duration_ms())*float(profile.release))+1,"release follows clip "+form)
    if Motion.is_projectile(form):
     check(game.combat_events.is_empty(),"projectile cannot appear before release "+form)
     game.update_projectiles(int(shot.release)-1);check(game.enemy_health()==100,"no pre-release damage "+form)
     game.update_projectiles(int(shot.due)+2)
     var flight: Array=game.combat_events.filter(func(e):return e.kind=="projectile")
     check(flight.size()==int(profile.get("projectiles",1)) and str(flight[0].form)==form,"matching projectiles "+form)
     if form=="fan":
      game.update_projectiles(int(shot.due)+300)
      check(shot.hits.size()==1 and float(flight[1].to[0])*float(flight[2].to[0])<0,"petals spread on both sides and only hit a shared target once")
     if form=="orb":
      Avatar.animate(actor,true,float(profile.release),form,{"equipped":true,"aim_yaw":0.0},1.0)
      Visuals.animate(actor,form,float(profile.release),true,0.0,float(stats.reach))
      var focus: Node3D=actor.visual_weapon.get_node("CoreSeed")
      var muzzle: Vector3=Vector3(flight[0].from[0],flight[0].height,flight[0].from[2])+game.Stage.WILD_OFFSET
      check(focus.global_position.distance_to(muzzle)<.18,"Seed Focus releases at the lifted focus on both rigs: "+str(focus.global_position-muzzle))
     check(absf(float(flight[0].projectile_radius)-float(profile.projectile_radius))<.0001,"projectile width matches collision "+form)
     if form in ["ring","orb"]:
      game.combat_visuals.sync([flight[0]],[],"weapon-model-flight",p.pos)
      var glyph: Node3D=game.combat_visuals.active[int(flight[0].id)].glyph
      check(glyph.has_node(Models.MODELS[form].name),"the released projectile carries the held model "+form)
    else:
     game.update_projectiles(int(shot.due)-1);check(game.enemy_health()==100,"melee waits for authored contact "+form)
     game.update_projectiles(int(shot.due)+1);check(game.enemy_health()<100,"authored contact reaches foe "+form)
     var event: Dictionary=game.combat_events.filter(func(e):return e.kind=="swing")[0]
     check(str(event.pattern)==str(description.pattern) and float(event.width)==float(description.width),"effect and hit geometry share dimensions "+form)
  check(poses.size()==15,"fifteen genuinely distinct two-hand poses on model "+str(sex)+", got "+str(poses.size()))
 p.frame=0;p.weapon_kind=0;var altered: Dictionary=game.weapon_stats(p);altered.pattern="line"
 var thrust:=Contact.describe("blade",altered)
 check(thrust.pattern=="line" and thrust.clip=="Attack_blade_line","crafted line blade uses a thrust action, not a sweeping clip")
 p.weapon_kind=1;altered=game.weapon_stats(p);altered.pattern="sweep"
 var cleave:=Contact.describe("spear",altered)
 check(cleave.pattern=="sweep" and cleave.clip=="Attack_spear_sweep","crafted spear sweep uses its matching action")
 # Narrow thrusts cannot hit something outside their visible corridor.
 p.frame=0;p.weapon_kind=1;var stats: Dictionary=game.weapon_stats(p)
 game.tactics.position=Vector3(1.1,0,1.4);check(not Contact.accepts(game,-1,p.pos,Vector3(0,0,3),"spear",stats),"no invisible wide spear strip")
 game.tactics.position=Vector3(.3,0,1.4);check(Contact.accepts(game,-1,p.pos,Vector3(0,0,3),"spear",stats),"visible spear corridor clips body edge")
 p.frame=4;p.weapon_kind=0;stats=game.weapon_stats(p);game.tactics.position=Vector3(0,0,-1.5)
 check(Contact.accepts(game,-1,p.pos,Vector3(0,0,3),"bell",stats),"bell pulse surrounds the caster")
 p.weapon_kind=1;stats=game.weapon_stats(p)
 check(not Contact.accepts(game,-1,p.pos,Vector3(0,0,3),"censer",stats),"censer sweep leaves rear foes untouched")
 p.weapon_kind=2;p[WeaponActions.STATE] = p[WeaponActions.STATE].with_ready_at(0);p.cast_until=0;game.combat_events.clear();game.projectile_queue.clear()
 game.encounter.set_hp(-1, 100);game.tactics.position=Vector3(0,0,3)
 var outer: Dictionary=game.make_scout(0,Vector3(.96,0,3.1),1)
 var outside: Dictionary=game.make_scout(0,Vector3(2,0,3.1),2)
 game.encounter.clear_scouts();game.encounter.register_scout(outer);game.encounter.register_scout(outside)
 game.strike_enemy(1,p,p.pos)
 var fan: Dictionary=game.projectile_queue[0]
 game.update_projectiles(int(fan.release))
 game.update_projectiles(int(fan.due)+350)
 check(game.enemy_health()<100 and game.encounter.hp_for(outer)<outer.max_hp and game.encounter.hp_for(outside)==outside.max_hp,"independent petals hit visible lanes and leave the space outside them clear")
 game.encounter.clear_scouts()
 p.frame=2;p.weapon_kind=0;p[WeaponActions.STATE] = p[WeaponActions.STATE].with_ready_at(0);p.cast_until=0;game.combat_events.clear();game.projectile_queue.clear();game.tactics.position=Vector3(0,0,2)
 game.strike_enemy(1,p,p.pos);var bow: Dictionary=game.projectile_queue[0]
 p.pos=Vector3(1,0,0);game.update_projectiles(int(bow.release))
 check(Vector3(bow.origin).x>.9,"moving bow releases from the current grip, not the old position")
 game.queue_free();await process_frame
 if not failed:print("PASS: 30 model/weapon combinations, 15 Blender clip pairs, grips, no firing circles, shared areas, release timing and moving muzzles")
 quit(1 if failed else 0)


func arbalest_pose(actor: Dictionary, sex: int, profile: Dictionary) -> void:
 var yaw:=.47
 var phase:=float(profile.release)-.01
 var action: Dictionary={"equipped":true,"aim_yaw":yaw,"contact":profile.release}
 Avatar.animate(actor,true,phase,"crossbow",action,1.0)
 Visuals.animate(actor,"crossbow",phase,true,yaw,6.0)
 var weapon: Node3D=actor.visual_weapon
 check(weapon.to_global(weapon.get_meta("support_grip")).distance_to(Field.hand(actor,true))<.035,"the arbalest seats in both palms on body "+str(sex))
 var arrow: Node3D=weapon.get_node("NockedArrow")
 var nock:=arrow.transform*Models.ARBALEST_NOCK
 check(arrow.visible,"the bolt is seated during wind-up")
 for side in [-1.0,1.0]:
  var string: MeshInstance3D=weapon.get_node("StringLower" if side<0 else "StringUpper")
  var half: float=string.mesh.height*.5
  check((string.transform*(Vector3.UP*half)).distance_to(nock)<.001,"string halves meet the nocked bolt")
  check((string.transform*(Vector3.DOWN*half)).distance_to(Visuals.limb_tip("crossbow",side))<.001,"string stays seated on the limb tip")
 Visuals.animate(actor,"crossbow",float(profile.release),true,yaw,6.0)
 check(not arrow.visible,"the loaded bolt disappears at the release frame")


func lash_pose(actor: Dictionary, sex: int) -> void:
 var weapon: Node3D=actor.visual_weapon
 var segments: Array=weapon.get_meta("vine_segments")
 Visuals.animate(actor,"whip",0,false,0,3.0)
 var coil: Vector3=segments[-1].transform*(Vector3.UP*.5)
 Visuals.animate(actor,"whip",float(Motion.profile("whip").release),true,0,3.0)
 var extended: Vector3=segments[-1].transform*(Vector3.UP*.5)
 check(coil.length()<.45 and extended.z>2.7,"the Root Lash coils and extends on body "+str(sex))
 for index in range(1,segments.size()):
  var end: Vector3=segments[index-1].transform*(Vector3.UP*.5)
  var start: Vector3=segments[index].transform*(Vector3.DOWN*.5)
  check(end.distance_to(start)<.001,"braided lash meshes meet through the extension")
