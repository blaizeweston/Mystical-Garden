extends RefCounted
const Catalog = preload("res://enemy_catalog.gd")
const Roster = preload("res://encounter_roster.gd")
const Elite = preload("res://elite_enemy.gd")
const FORMATIONS := ["Single", "Line", "Cluster", "Ring"]

class Targets extends Roster:
	var inexhaustible := false
	var anchors := {}

	func begin_floor(leader_hp: int) -> void:
		anchors.clear()
		super(leader_hp)

	func apply_damage(slot: int, damage: int, expected_token := -1) -> int:
		var applied := super(slot,damage,expected_token)
		if slot>=0 and anchors.has(token(slot)): scout(slot).pos=anchors[token(slot)]
		if inexhaustible and slot >= 0 and applied > 0:
			set_hp(slot,hp(slot)+applied)
		return applied

static func entries() -> Array[Dictionary]:
	var result: Array[Dictionary] = [{"type":"Target","kind":0,"name":"Stationary training target"}]
	for kind in Catalog.all().size():
		var row := Catalog.get_kind(kind)
		var title := str(row.get("name",row.id))
		if row.get("boss",false):
			result.append({"type":"Boss","kind":kind,"name":title})
		else:
			result.append({"type":"Enemy","kind":kind,"name":title})
			if not Catalog.is_support(kind) and row.role!="lure":
				result.append({"type":"Elite","kind":kind,"name":title})
	return result

static func place(world: Node, type: String, kind: int, count: int, formation: String, endless: bool) -> String:
	if not world.is_practice_world(): return "Developer session required."
	if not entries().any(func(row):return row.type==type and row.kind==kind):
		return "Unknown encounter selection."
	if count<1 or count>Roster.Config.MAX_SCOUTS or not FORMATIONS.has(formation):
		return "Invalid quantity or arrangement."
	if (type in ["Elite","Boss"] or formation=="Single") and count!=1:
		return "Choose one for a single target or a dedicated leader encounter."
	var points: Array[Vector3]=[]
	var actor: Dictionary=world.players[1]
	var ground=world.battlefield
	var origin: Vector3=actor.pos
	if world.tactics.boss_kind>=0 and type not in ["Boss","Elite"]:
		ground=world.Battlefield.new()
		ground.configure(world.participation.route(),world.participation.depth(),0)
		origin=Vector3.ZERO
	if type not in ["Elite","Boss"]:
		var facing: Vector3=actor.facing.normalized()
		var side:=facing.cross(Vector3.UP)
		var center: Vector3=origin+facing*3.0
		for index in count:
			var desired := center
			match formation:
				"Line": desired += side*(index-float(count-1)/2.0)*1.6
				"Cluster": desired += side*(index%3-1)*1.5+facing*floorf(index/3.0)*1.5
				"Ring": desired = origin+facing.rotated(Vector3.UP,TAU*index/count)*maxf(3.0,count*.35)
			var point: Vector3=world.clear_spawn(desired) if ground==world.battlefield else desired
			if not point.is_finite() or not ground.can_spawn(point) or point.distance_to(origin)<.9 or points.any(func(p):return p.distance_to(point)<.9):
				return "Insufficient clear space for this arrangement. Move or use fewer enemies."
			points.append(point)
	world.boss_floors[str(world.participation.floor())]=kind if type=="Boss" else -1
	world.reset_encounter(0)
	world.encounter.clear_scouts()
	world.encounter.inexhaustible=type=="Target" and endless
	if type in ["Elite","Boss"]:
		world.enemy_kind=kind
		world.encounter.begin_floor(world.encounter_health())
		actor.pos=world.battlefield.entry
		if type=="Elite": Elite.state(world)
	else:
		actor.pos=origin
		world.encounter.despawn(-1)
		for index in points.size():
			var body: Dictionary=world.make_scout(kind,points[index],index+1)
			if type=="Target" and endless:
				body.hp=2147483647
				body.max_hp=body.hp
			var slot: int=world.encounter.register_scout(body)
			if type=="Target": world.encounter.anchors[world.encounter.token(slot)]=points[index]
	world.practice_targets=type=="Target"
	return ""
