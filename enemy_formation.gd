extends RefCounted
## Support escort observations, starting formation, and following behavior.
## EnemySupport retains species-specific rite requirements and responses.

const Enemies = preload("res://enemy_catalog.gd")
const Battlefield = preload("res://battlefield.gd")
const EnemyBehaviors = preload("res://enemy_behaviors.gd")
const Attacks = preload("res://enemy_attack.gd")
const SkillTactics = preload("res://wilds_skill_tactics.gd")


static func allies(game: Node, support: Dictionary) -> Array:
	var result: Array=[]
	if game.enemy_health()>0 and not Enemies.is_support(game.enemy_kind): result.append({"index":-1,"pos":game.tactics.position,"engaged":game.tactics.engaged})
	for index in game.encounter.scout_count():
		var other: Dictionary=game.encounter.scout(index)
		if game.encounter.hp(index)>0 and not Enemies.is_support(int(other.get("kind",0))): result.append({"index":index,"pos":other.pos,"engaged":bool(other.get("engaged",false))})
	result.sort_custom(func(a,b): return support.pos.distance_squared_to(a.pos)<support.pos.distance_squared_to(b.pos))
	return result


static func _formation_position(game: Node, anchor: Vector3,ignore: int,phase: float) -> Vector3:
	for radius in [1.5,2.0,2.6]:
		for step in 20:
			var angle:=phase+step*TAU/20
			var candidate:=anchor+Vector3(cos(angle)*radius,0,sin(angle)*radius)
			if game.battlefield.occupied(candidate,Battlefield.CLEARANCE) or not game.battlefield.clear_line(anchor,candidate,Battlefield.CLEARANCE): continue
			if not preload("res://wilds_composition.gd").partner_position(game,candidate) or candidate.distance_to(game.tactics.position)<.85: continue
			var free:=true
			for index in game.encounter.scout_count():
				if index!=ignore and game.encounter.hp(index)>0 and candidate.distance_to(game.encounter.scout(index).pos)<.85: free=false;break
			if free: return candidate
	return Vector3.INF


static func arrange(game: Node) -> void:
	for index in game.encounter.scout_count():
		var support: Dictionary=game.encounter.scout(index)
		if not Enemies.is_support(int(support.kind)): continue
		var minimum:=maxi(1,int(Enemies.get_kind(int(support.kind)).get("escort_min",2)))
		var escorts := allies(game, support)
		# A support-heavy pool still needs fighters. Reuse slots instead of adding enemies.
		if escorts.size()<minimum:
			for other in range(game.encounter.scout_count()-1,-1,-1):
				if other==index or not Enemies.is_support(int(game.encounter.scout(other).kind)): continue
				var old: Dictionary=game.encounter.scout(other)
				game.encounter.register_scout(game.make_scout(0,old.pos,int(old.route),int(old.mutations),int(old.growth)), other)
				escorts=allies(game, support)
				if escorts.size()>=minimum: break
		if escorts.size()<minimum:
			game.encounter.register_scout(game.make_scout(0,support.pos,int(support.route),int(support.mutations),int(support.growth)), index);continue
		var anchor: Vector3=escorts[0].pos
		var placed:=_formation_position(game, anchor,index,float(index)*1.7)
		if placed==Vector3.INF:
			game.encounter.register_scout(game.make_scout(0,support.pos,int(support.route),int(support.mutations),int(support.growth)), index);continue
		support.pos=placed
		var radius:=float(Enemies.get_kind(int(support.kind)).get("escort_radius",3.8))
		for ally in escorts.slice(1,minimum):
			if int(ally.index)<0: continue
			if support.pos.distance_to(ally.pos)<=radius and game.battlefield.clear_line(support.pos,ally.pos,Battlefield.CLEARANCE): continue
			var companion:=_formation_position(game, anchor,int(ally.index),float(index)*1.7+PI)
			if companion!=Vector3.INF: game.encounter.scout(int(ally.index)).pos=companion
		var nearby:=0
		for ally in allies(game, support):
			nearby+=int(support.pos.distance_to(ally.pos)<=radius and game.battlefield.clear_line(support.pos,ally.pos,Battlefield.CLEARANCE))
		if nearby<minimum: game.encounter.register_scout(game.make_scout(0,support.pos,int(support.route),int(support.mutations),int(support.growth)), index)

	# A later group may have reused an escort. Check the complete formation once more.
	for index in game.encounter.scout_count():
		var support: Dictionary=game.encounter.scout(index)
		if not Enemies.is_support(int(support.kind)): continue
		var definition:=Enemies.get_kind(int(support.kind))
		var nearby:=0
		for ally in allies(game, support):
			nearby+=int(support.pos.distance_to(ally.pos)<=float(definition.get("escort_radius",3.8)) and game.battlefield.clear_line(support.pos,ally.pos,Battlefield.CLEARANCE))
		if nearby<int(definition.get("escort_min",2)): game.encounter.register_scout(game.make_scout(0,support.pos,int(support.route),int(support.mutations),int(support.growth)), index)


static func follow_support(game: Node, scout: Dictionary,allies: Array,definition: Dictionary,speed: float,delta: float,now: int) -> void:
	var anchor: Vector3=allies[0].pos
	var distance: float=scout.pos.distance_to(anchor)
	if distance>2.65 or not game.battlefield.clear_line(scout.pos,anchor):
		if now>=int(scout.rooted_until): scout.pos=game.battlefield.navigate(scout.pos,anchor,speed*delta,int(scout.route))
		return
	if now>=int(scout.ready):
		if EnemyBehaviors.support_target(game,scout,allies,anchor,speed,delta,now):return
		scout.repeat=0
		var role: String=definition.role
		var aim: Vector3=Attacks.aim(game,scout,role,int(scout.cast_target))
		var duration:=int(definition.windup)+(380 if scout.get("variant","")=="long_tether" else 0)
		Attacks.lock(game,scout,role,aim,now+duration)
		scout.windup=now+SkillTactics.response_windup(scout.attack,duration)
		if scout.get("covered_once",false):scout.covered_cast=true
