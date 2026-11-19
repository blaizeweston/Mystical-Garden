extends SceneTree
const OutgoingHits = preload("res://outgoing_hits.gd")
const HitSession = preload("res://network_session.gd")

const ExpeditionCase = preload("res://tests/support/expedition_case.gd")

const PlayerVitals = preload("res://player_vitals.gd")
var failed:=false
func check(ok: bool,message: String):
 if not ok: failed=true;printerr("FAIL support/death: ",message)
func _initialize(): call_deferred("run")
func run():
 var game=load("res://world.tscn").instantiate()
 var token=Crypto.new().generate_random_bytes(8).hex_encode()
 game.progress.path="res://.godot/death_test_"+token+".cfg";game.local_character.path=game.progress.path+".character"
 root.add_child(game);game.set_process(false);game.set_physics_process(false);game.death_visuals.set_process(false)
 var p: Dictionary=game.players[1]
 var supports:=0
 var rosters: Dictionary={}
 for biome in 3:
  for stamp in range(1,101):
   ExpeditionCase.set_world(game, {"destination": biome});ExpeditionCase.set_world(game, {"depth": 2+stamp%5});ExpeditionCase.set_world(game, {"encounter_number": 5+stamp%30});ExpeditionCase.set_world(game, {"map_seed": stamp*991+biome})
   game.reset_encounter()
   if game.tactics.boss_kind<0:
    check(game.encounter.scout_count()<=game.Director.scout_count(game),"composition uses the existing encounter budget")
    var support_count: int=game.encounter.scout_tactics().filter(func(s):return game.Enemies.is_support(s.kind)).size()
    check(support_count<=1,"solo composition has at most one dedicated support")
    check(game.encounter.scout_tactics().any(func(s):return game.Enemies.get_kind(s.kind).role in ["swipe","charge","pounce","skirmish","stomp"]),"group retains a frontline fighter")
    rosters[str(game.encounter.scout_tactics().map(func(s):return s.kind))]=true
   for scout in game.encounter.scout_tactics():
    check(not game.battlefield.occupied(scout.pos,game.Battlefield.CLEARANCE),"spawn remains walkable")
    if not game.Enemies.is_support(scout.kind): continue
    supports+=1
    var nearby:=0
    for ally in preload("res://enemy_formation.gd").allies(game, scout):
     nearby+=int(scout.pos.distance_to(ally.pos)<=float(game.Enemies.get_kind(scout.kind).get("escort_radius",3.8)) and game.battlefield.clear_line(scout.pos,ally.pos,game.Battlefield.CLEARANCE))
    check(nearby>=2,"support spawns with two reachable combat escorts")
 check(rosters.size()>35,"composition offers distinct combinations across layouts and depths")
 check(supports>20,"formation checks keep support enemies in the pool rather than removing them all")
 print("Escorted supports across 300 procedural floors: ",supports)
 # Force a support-only pool: existing slots become fighters instead of leaving solo supports.
 ExpeditionCase.set_world(game, {"map_seed": 0});ExpeditionCase.set_world(game, {"destination": 0});ExpeditionCase.set_world(game, {"depth": 1});game.battlefield.configure(0,1);game.encounter.set_hp(-1, 5)
 game.encounter.clear_scouts()
 for index in 4: game.encounter.register_scout(game.make_scout(3,Vector3(-5+index*3,0,3),index+1))
 preload("res://enemy_formation.gd").arrange(game)
 for scout in game.encounter.scout_tactics():
  if not game.Enemies.is_support(scout.kind): continue
  var nearby:=0
  for ally in preload("res://enemy_formation.gd").allies(game, scout): nearby+=int(scout.pos.distance_to(ally.pos)<=float(game.Enemies.get_kind(scout.kind).get("escort_radius",3.8)) and game.battlefield.clear_line(scout.pos,ally.pos))
  check(nearby>=2,"all-support composition is repaired")
 # During combat the caster follows allies instead of walking at the player alone.
 preload("res://tests/support/terrain_case.gd").walls(game.battlefield,[]);game.encounter.set_hp(-1, 0)
 var caster: Dictionary=game.make_scout(3,Vector3(0,0,0),1)
 var ally: Dictionary=game.make_scout(0,Vector3(5,0,0),2);ally.engaged=true;ally.windup=Time.get_ticks_msec()+60000
 game.encounter.clear_scouts();game.encounter.register_scout(caster);game.encounter.register_scout(ally);ExpeditionCase.set_membership(game, p, true);p[PlayerVitals.STATE] = p[PlayerVitals.STATE].with_hp(10);p.pos=Vector3(-4,0,0)
 var before: float=caster.pos.distance_to(ally.pos)
 preload("res://scout_behavior.gd").tick(game, .2,Time.get_ticks_msec())
 check(caster.pos.distance_to(ally.pos)<before and caster.pos.x>0,"support follows combat ally, even away from player")
 caster.pos=Vector3(4,0,0);caster.windup=0;caster.ready=0;caster.engaged=true
 preload("res://scout_behavior.gd").tick(game, .016,Time.get_ticks_msec())
 check(caster.mode=="chant" and caster.windup>0,"grouped support telegraphs its allied buff")
 var now:=Time.get_ticks_msec();preload("res://scout_behavior.gd").release(game, caster,game.Enemies.get_kind(3),now)
 check(ally.haste_until>now and int(caster.get("haste_until",0))==0,"haste buffs combatants rather than the caster")
 game.encounter.set_hp(game.encounter.scout_slot(ally), 0);caster.windup=0;caster.ready=0;p.pos=caster.pos+Vector3.RIGHT*.7
 preload("res://scout_behavior.gd").tick(game, .016,now+10)
 check(caster.mode=="desperate" and caster.windup>0,"orphaned support remains defeatable and can defend itself")
 # A genuine lethal hit emits one authoritative death event, and no collision-bearing enemy remains.
 game.encounter.clear_scouts();game.tactics.position=Vector3(0,0,5);game.encounter.set_hp(-1, 1);game.enemy_kind=0;game.enemy_growth=0;game.enemy_mutations=0
 p.pos=Vector3(0,0,4);p.weapon=0;p.secondary=0;p.catalyst=0;p.power=0;p.run_upgrades={}
 OutgoingHits.hit_world(game, HitSession.peer_for(p), -1, p.pos, game.weapon_stats(p), now)
 check(game.enemy_health()==0 and game.enemy_death_events.size()==1,"lethal hit creates an event while logical health reaches zero immediately")
 var events: Array=game.death_events_snapshot()
 game.death_visuals.sync(events,"floor-test",p.pos)
 check(game.death_visuals.corpses.size()==1,"defeated monster has a visible death body")
 var body: Dictionary=game.death_visuals.corpses.values()[0]
 var rotation: Vector3=body.actor.model.rotation
 game.death_visuals.step(.4)
 check(body.actor.model.rotation.distance_to(rotation)>.3 and body.root.visible,"death body visibly collapses")
 check(body.root.find_children("*","CollisionObject3D",true,false).is_empty(),"death body cannot block movement")
 game.death_visuals.sync(events,"floor-test",p.pos)
 check(game.death_visuals.corpses.size()==1,"repeated snapshots do not duplicate corpses")
 game.death_visuals.step(1.0)
 check(float(body.materials[0].material.albedo_color.a)<1,"corpse fades after collapse")
 check(is_equal_approx(game.stage.foe_model.tint.albedo_color.a,1.0),"corpse fading does not alter living-enemy materials")
 game.death_visuals.step(1.0)
 check(game.death_visuals.corpses.is_empty(),"death body cleans up after its animation")
 var variants: Array=[]
 # All twenty-four model templates support the death pose, including growth and adaptations.
 for kind in game.Enemies.all().size():
  var event: Dictionary={"id":100+kind,"position":[0,0,5],"direction":[1,0,0],"code":game.Enemies.encode(kind,game.Enemies.BARK|game.Enemies.MOBILITY,2),"scale":1.0,"age":0.0}
  variants.append(event)
 game.death_visuals.sync(variants,"variants",p.pos)
 game.death_visuals.step(.1)
 check(game.death_visuals.corpses.size()==game.Enemies.all().size(),"all enemy forms animate with variant morphology")
 game.death_visuals.sync([],"next-floor",p.pos)
 check(game.death_visuals.corpses.is_empty(),"floor transition clears old visual bodies")
 var other: Dictionary=game.player_snapshot(999)[1]
 check(not other.has("death_events"),"event payload uses the existing viewer snapshot")
 game.free()
 if not failed: print("PASS: escort formations, walkable spawns, ally-following support, buffs, orphan defense, lethal-hit events, collapse/fade, snapshot deduplication and all twenty-four death forms")
 quit(1 if failed else 0)
