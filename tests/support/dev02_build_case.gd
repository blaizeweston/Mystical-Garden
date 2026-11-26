extends RefCounted
const Plan=preload("res://developer_arena/build_plan.gd")
const Spirit=preload("res://spirit_affinity.gd")

static func verify(session: Node) -> String:
	var arena: Node=session.combat
	var spec: Dictionary=session.build.duplicate(true)
	spec.frame=2
	spec.weapon=0
	spec.path=["wildstalker"]
	var spirit: Array=[]
	for i in range(1,Plan.Parts.DEFINITIONS.size()):
		var part:=Plan.Affinities.slot("core",i)
		if part.get("primary_affinity")=="spirit": spirit.append(i)
	spec.parts=[spirit.front(),spirit.back(),spirit.front()]
	spec.upgrades=[{"id":"lingering_echoes","rarity":"Rare"},{"id":"mirrorstep","rarity":""},{"id":"wraithcast","rarity":""},{"id":"ordinary_weapon_damage","rarity":"Epic"},{"id":"silken_link","rarity":""}]
	var result:=Plan.plan(arena,spec)
	if not result.error.is_empty() or not result.removed.is_empty(): return "simultaneous transformations or deferred dependent: "+str(result.get("removed",result.error))
	for entry in [{"id":"mirrorstep","rarity":"Epic"},{"id":"mirrorstep","rarity":""},{"id":"ordinary_weapon_damage","rarity":"Mythic"},{"id":"silken_link","rarity":""}]:
		if Plan.acquire(arena,spec,result,entry).has("ledger"): return "illegal rarity or duplicate Unique"
	var bad:=spec.duplicate(true)
	bad.path=["invented"]
	if Plan.plan(arena,bad).error.is_empty(): return "disconnected class progression"
	bad=spec.duplicate(true)
	bad.weapon=99
	if Plan.plan(arena,bad).error.is_empty(): return "incompatible weapon"
	bad=spec.duplicate(true)
	bad.parts[0]=Plan.Parts.monster_part(0)
	if Plan.plan(arena,bad).error.is_empty(): return "nonplant component"
	bad=spec.duplicate(true)
	bad.upgrades=[]
	for i in 15: bad.upgrades.append({"id":"ordinary_weapon_damage","rarity":"Common"})
	if Plan.plan(arena,bad).removed.is_empty(): return "stack limit"
	if not arena.apply_build(spec,[]).is_empty(): return "apply valid draft"
	await session.get_tree().process_frame
	await session.get_tree().process_frame
	arena=session.combat
	var old: Dictionary=arena.players[1]
	var spawn: String=arena.spawn_selection("Target",0,1,"Single",true)
	if not spawn.is_empty(): return spawn
	arena.dodge_player(1,Vector2.RIGHT)
	if old.get(Spirit.ECHOES,[]).is_empty() or old.get(Spirit.SHADOWS,[]).is_empty(): return "real dash failed to prepare echo and shadow"
	await session.get_tree().process_frame
	await session.get_tree().process_frame
	var images:Array=arena.stage.get_node("CombatEffects").hints.values().filter(func(h):return h.event.role=="spirit_image" and h.has("astral"))
	if images.size()!=2:return "dash images missing from practice stage"
	var echo_mesh:MeshInstance3D=images[0].astral
	var shadow_mesh:MeshInstance3D=images[1].astral
	var now: int=arena.CombatClock.now()
	arena.weapon_attacks.try_start(arena.weapon_attack_world,1,old.pos,now)
	var old_life: int=arena.PlayerLifecycle.generation(old)
	spec.weapon=1
	spec.parts=[0,0,0]
	spec.upgrades=spec.upgrades.filter(func(e):return e.id not in ["mirrorstep","wraithcast"])
	result=Plan.plan(arena,spec)
	if result.removed.size()!=1 or result.removed[0].entry.id!="lingering_echoes": return "dependent removal preview"
	if arena.apply_build(spec,[]).is_empty(): return "stale preview accepted"
	if not arena.apply_build(spec,result.removed).is_empty(): return "rebuild refused"
	await session.get_tree().process_frame
	await session.get_tree().process_frame
	if is_instance_valid(arena): return "old world survived"
	if is_instance_valid(echo_mesh) or is_instance_valid(shadow_mesh):return "spectral geometry survived build replacement"
	arena=session.combat
	var actor: Dictionary=arena.players[1]
	var build=arena.combat_build(actor)
	if arena.PlayerLifecycle.generation(actor)==old_life or actor.weapon_kind!=1 or not build.spirit_passives().is_empty(): return "replacement weapon or stale Spirit action"
	if arena.weapon_attacks.pending_count()!=0 or arena.effect_timeline.native_count()!=0 or not arena.combat_events.is_empty() or actor.has(Spirit.ECHOES) or actor.has(Spirit.SHADOWS): return "residual attacks or effects"
	if arena.AffinityCards.amount(actor,"ordinary_weapon_damage")<=0 or not actor[Plan.Grafts.STATE].resolution().owned.has("silken_link"): return "valid upgrades lost"
	arena.dodge_player(1,Vector2.RIGHT)
	if actor.has(Spirit.ECHOES) or actor.has(Spirit.SHADOWS): return "removed transformation still triggers"
	var form: String=arena.WeaponMotion.form(actor)
	if not arena.weapon_attacks.try_start(arena.weapon_attack_world,1,actor.pos,arena.CombatClock.now()): return "replacement weapon attack refused"
	var pending: Array=arena.weapon_attacks.savepoint().pending
	if pending.is_empty() or pending[0].form!=form or not arena.attack_animation_snapshot(actor).active: return "replacement weapon animation"
	arena.weapon_attacks.advance(arena.weapon_attack_world,arena.CombatClock.now()+2000)
	var hit:=preload("res://outgoing_hits.gd").hit_world(arena,1,0,actor.pos,{"damage":1.0,"knockback":0.0},arena.CombatClock.now())
	if hit.applied_hp<=0: return "clean effect fixture"
	var damage: float=arena.round_stats().party.damage
	var point: Vector3=arena.encounter.position(0)
	session.rebuild("effects")
	await session.get_tree().process_frame
	await session.get_tree().process_frame
	var clean: Node=session.combat
	if is_instance_valid(arena) or clean.weapon_attacks.pending_count()!=0 or clean.effect_timeline.native_count()!=0 or clean.round_stats().party.damage!=damage or clean.encounter.position(0)!=point:
		return "clear effects changed round statistics or roster"
	return ""
