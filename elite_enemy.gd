extends RefCounted
# Ordinary gate elites share scout species rules, control, rewards and bounded summons.
const Catalog=preload("res://enemy_catalog.gd")
const Attacks=preload("res://enemy_attack.gd")
const Variants=preload("res://enemy_variants.gd")
static func pool(site: int,floor_number: int) -> Array[int]:
 var result: Array[int]=[]
 for kind in Catalog.all().size():
  var entry:=Catalog.get_kind(kind)
  if not entry.get("boss",false) and not Catalog.is_support(kind) and entry.role!="lure" and Catalog.in_biome(entry,site) and floor_number>=int(entry.unlock):result.append(kind)
 return result
static func choose(site: int,floor_number: int,seed_value: int,previous: int=-1) -> int:
 var choices:=pool(site,floor_number)
 if choices.size()>1:choices.erase(previous)
 if choices.is_empty():return 0
 var random:=RandomNumberGenerator.new();random.seed=seed_value+floor_number*104729+site*7919
 return choices[random.randi_range(0,choices.size()-1)]
static func select(game: Node) -> int:
 var key: String="%d:%d:%d"%[game.destination,game.encounter_number,game.map_seed]
 var last: Dictionary=game.get_meta("gate_elite",{})
 if last.get("key","")==key:return int(last.kind)
 var kind:=choose(game.destination,game.encounter_number,game.map_seed,int(last.get("kind",-1)))
 game.set_meta("gate_elite",{"key":key,"kind":kind})
 return kind
const SIGNATURES={
 0:"bark_guard",1:"late_pulse",2:"angled_charge",4:"leading_pounce",5:"root_line",
 6:"offset_spores",7:"fault_stomp",8:"wide_flank",9:"split_nursery",11:"planted_canopy",
 13:"bent_seam",14:"split_web",16:"edge_thief",17:"cutoff_charge",18:"early_decoys"
}

static func empowered(kind: int) -> String:
 return Variants.cue(SIGNATURES.get(kind,""),kind)
static func state(game: Node) -> Dictionary:
 if not game.leader_brain.has("elite") or int(game.leader_brain.elite.kind)!=int(game.enemy_kind):
  var body: Dictionary=game.make_scout(game.enemy_kind,game.enemy_pos,0,game.enemy_mutations,game.enemy_growth)
  body.summons=0;body.remaining=0;body.repeat=0;body.gate_elite=true
  if game.Life.Preview.enabled: body.max_hp=game.encounter_health()
  if game.encounter_number>=3:body.variant=SIGNATURES.get(int(game.enemy_kind),body.variant)
  game.leader_brain.elite=body
 return game.leader_brain.elite
static func tick(game: Node,delta: float,now: int) -> void:
 if game.enemy_hp<=0:return
 if game.enemy_winding_up:
  if now>=game.enemy_strike_at:resolve(game,now)
  return
 if game.enemy_kind==16 and not game.leader_brain.get("elite",{}).get("stolen",[]).is_empty():
  var fleeing: Dictionary=game.leader_brain.elite
  fleeing.pos=game.enemy_pos
  fleeing.rooted_until=game.rooted_until
  fleeing.stagger_until=game.enemy_stagger_until
  game.EnemyBehaviors.tick(game,fleeing,delta,now)
  game.enemy_pos=fleeing.pos
  return
 if preload("res://glasscap_feint.gd").holding(game,game.leader_brain.get("elite",{}),now):return
 if now<game.enemy_stagger_until:return
 var id: int=game.Director.target(game,game.enemy_pos,game.leader_brain,now)
 if id==0:return
 var victim: Vector3=game.players[id].pos;var distance: float=game.enemy_pos.distance_to(victim)
 if not game.enemy_engaged and (distance>float(game.Director.config().aggro_radius) or not game.battlefield.clear_line(game.enemy_pos,victim)):return
 if not game.enemy_engaged:game.Director.alert(game,game.enemy_pos)
 game.enemy_engaged=true
 var definition:=Catalog.get_kind(game.enemy_kind);var role: String=definition.role;var body:=state(game)
 body.pos=game.enemy_pos;body.rooted_until=game.rooted_until;body.mutations=game.enemy_mutations;body.haste_until=game.enemy_haste_until
 if game.enemy_kind==16:
  body.ready=game.enemy_ready_at;body.stagger_until=game.enemy_stagger_until
  if game.EnemyBehaviors.tick(game,body,delta,now):
   game.enemy_pos=body.pos
   if body.windup>0:
    game.enemy_winding_up=true;game.enemy_attack_mode=body.mode;game.enemy_strike_at=body.windup;game.enemy_landing=body.attack.to
   return
 var reach:=float(definition.range)+(.65 if game.longlimb else 0.0)
 var can_leap: bool=now>=game.rooted_until and now>=game.enemy_ready_at
 if can_leap and Attacks.try_skill_approach(game,body,victim,now):
  game.enemy_winding_up=true
  game.enemy_attack_mode=body.mode
  game.enemy_strike_at=body.windup
  game.enemy_landing=body.attack.to
  game.active_radius=body.attack.radius
  return
 var thorn_vault:=can_leap and Attacks.try_thorn_vault(game,body,victim,now)
 var landing:=Attacks.vault_target(game,body,victim) if can_leap and not thorn_vault else Vector3.INF
 var vault:=thorn_vault or landing.is_finite()
 if not vault and (distance>reach or not game.battlefield.clear_line(game.enemy_pos,victim)):
  if now>=game.rooted_until:
   var goal: Vector3=game.Director.pursuit(game,id,0)
   if role=="skirmish" and distance<4:goal=game.enemy_pos+(victim-game.enemy_pos).normalized().rotated(Vector3.UP,.9)*2
   game.enemy_pos=game.Director.navigate(game,game.enemy_pos,goal,game.Director.speed(game,float(definition.speed)*1.08)*(1.22 if now<game.enemy_haste_until else 1.0)*delta)
  return
 if now<game.enemy_ready_at:return
 if not vault and Variants.prepare(game,body,victim,delta,now):
  game.enemy_pos=body.pos
  return
 body.repeat=1 if game.enemy_kind==1 and not vault else 0
 var mode: String="vault" if vault else role
 var aim: Vector3=landing if vault else Attacks.aim(game,body,role,id)
 var windup: int=Attacks.VAULT_WINDUP if vault else game.Director.windup(game,maxi(650,int(definition.windup))+(300 if body.get("variant","")=="early_decoys" else 0))
 if not thorn_vault: Attacks.lock(game,body,mode,aim,now+windup)
 body.erase("approach_done");body.erase("approach");body.erase("approach_used")
 game.EnemyBehaviors.telegraph(game,body,now)
 game.enemy_landing=body.attack.to;game.enemy_attack_mode=mode;game.active_radius=body.attack.radius
 game.enemy_winding_up=true;game.enemy_strike_at=body.windup
static func resolve(game: Node,now: int) -> void:
 var body:=state(game);var definition:=Catalog.get_kind(game.enemy_kind)
 body.pos=game.enemy_pos;body.blast=game.enemy_landing;body.mode=game.enemy_attack_mode;body.hp=game.enemy_hp;body.recovery=game.moss_recovery_bonus
 body.rooted_until=game.rooted_until
 game.resolve_scout(body,definition,now)
 game.enemy_pos=body.pos
 game.enemy_winding_up=body.windup>0
 if game.enemy_winding_up:
  game.enemy_strike_at=body.windup
 else:
  game.enemy_attack_mode="";game.active_radius=0
  game.enemy_ready_at=int(body.ready)
 game.moss_recovery_bonus=0
static func hints(game: Node) -> Array:
 if game.enemy_hp<=0 or not game.enemy_winding_up:return []
 var body:=state(game)
 return Attacks.hints(Attacks.current(game,body),-1,maxf(0,(game.enemy_strike_at-Time.get_ticks_msec())/1000.0))
static func decorate(stage: Node3D,actor: Dictionary,enabled: bool) -> void:
 var model: Node3D=actor.model
 var growth: Node3D=model.get_node_or_null("EliteGrowth")
 if is_instance_valid(growth):growth.visible=enabled;return
 if not enabled:return
 growth=Node3D.new();growth.name="EliteGrowth";model.add_child(growth)
 var role: String=Catalog.get_kind(actor.kind).role
 var color:=Color(Catalog.get_kind(actor.kind).core).lightened(.18)
 var material:=StandardMaterial3D.new();material.albedo_color=color;material.roughness=.85;material.emission_enabled=true;material.emission=color;material.emission_energy_multiplier=.18
 # Extra connected root ribs, antler forks or swollen casting/brood sacs are anatomy, not a scale multiplier.
 for side in [-1.0,1.0]:
  for i in 3:
   var start:=Vector3(side*.18,.35+i*.16,-.12);var end:=Vector3(side*(.35+i*.08),.65+i*.22,-.23)
   var rod:=MeshInstance3D.new();var mesh:=CylinderMesh.new();mesh.height=start.distance_to(end);mesh.top_radius=.015;mesh.bottom_radius=.055;mesh.radial_segments=8;rod.mesh=mesh;rod.material_override=material;growth.add_child(rod);rod.position=(start+end)*.5;rod.basis=Basis(Quaternion(Vector3.UP,(end-start).normalized()))
   if role in ["brood","volley","snare","artillery"]:
    var sac:=MeshInstance3D.new();var sphere:=SphereMesh.new();sphere.radius=.10+i*.015;sphere.height=sphere.radius*2.4;sac.mesh=sphere;sac.material_override=material;growth.add_child(sac);sac.position=end
