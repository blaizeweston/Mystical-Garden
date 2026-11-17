extends RefCounted
## A feint uses only one real combat actor. The host supplies the entire visible formation.

const KIND := 18
const ROLE := "glasscap_feint"
const PLACEMENT_TRIES := 20
const SPACING := 2.55


static func prepare(game: Node, actor: Dictionary) -> void:
	if not game.multiplayer.is_server() or int(actor.kind) != KIND or actor.mode != "volley":
		return
	var sequence := int(actor.get("feint_sequence",0))+1
	actor.feint_sequence = sequence
	var random := RandomNumberGenerator.new()
	random.seed = hash([game.participation.seed(),game.participation.epoch(),game.encounter.token_for(actor),sequence])
	var origin: Vector3 = actor.pos
	var start := random.randf_range(0,TAU)
	var points: Array[Vector3] = []
	for index in PLACEMENT_TRIES:
		var direction := Vector3.FORWARD.rotated(Vector3.UP,start+index*2.399963)
		var point := origin+direction*random.randf_range(3.0,5.0)
		if not game.battlefield.clear_line(origin,point,.46) or not open_site(game,actor,point):
			continue
		if points.any(func(other): return point.distance_to(other)<SPACING):
			continue
		points.append(point)
		if points.size()==2:
			break
	actor.glass_feint = {"id":"glass:%d:%d:%d"%[game.participation.epoch(),game.encounter.token_for(actor),sequence],
		"epoch":game.participation.epoch(),"points":points,"seed":random.seed,"until":0}


static func open_site(game: Node, actor: Dictionary, point: Vector3) -> bool:
	if game.battlefield.occupied(point,.46):
		return false
	for player in game.players.values():
		if game.Life.alive(player) and point.distance_to(player.pos)<1.3:
			return false
	if game.encounter.hp(-1)>0 and not actor.get("gate_elite",false) and point.distance_to(game.tactics.position)<1.25:
		return false
	for slot in game.encounter.scout_count():
		var other: Dictionary=game.encounter.scout(slot)
		if game.encounter.hp(slot)>0 and not is_same(actor,other) and point.distance_to(other.pos)<1.25:
			return false
	return true


static func release(game: Node, actor: Dictionary, now: int) -> void:
	var feint: Dictionary = actor.get("glass_feint",{})
	if feint.is_empty() or int(feint.epoch)!=game.participation.epoch() or int(feint.until)>0:
		return
	var candidates: Array[int] = []
	for index in feint.points.size():
		var point: Vector3 = feint.points[index]
		if point.distance_to(actor.pos)>=SPACING and open_site(game,actor,point):
			candidates.append(index)
	if candidates.is_empty():
		actor.erase("glass_feint")
		return
	var random := RandomNumberGenerator.new()
	random.seed = int(feint.seed) ^ 463501
	var selected: int = candidates[random.randi_range(0,candidates.size()-1)]
	var origin: Vector3 = actor.pos
	actor.pos = feint.points[selected]
	feint.points[selected] = origin
	feint.until = now + (1300 if actor.get("variant","")=="early_decoys" else 1050)
	game.Journal.event("combat","glasscap_decoy_swap",{"actor":game.encounter.token_for(actor),"formation":feint.id,"floor":game.participation.floor()})


static func holding(game: Node, actor: Dictionary, now: int) -> bool:
	var feint: Dictionary = actor.get("glass_feint",{})
	return not feint.is_empty() and int(feint.epoch)==game.participation.epoch() and now<int(feint.until)


static func hints(game: Node, now: int) -> Array:
	var result: Array = []
	for slot in range(-1,game.encounter.scout_count()):
		var actor: Dictionary = game.encounter.leader_tactics() if slot<0 else game.encounter.scout(slot)
		var feint: Dictionary = actor.get("glass_feint",{})
		if feint.is_empty() or int(feint.epoch)!=game.participation.epoch() or feint.points.is_empty():
			continue
		var alive: bool = game.encounter.hp(slot)>0
		var winding: bool = game.tactics.winding_up and game.tactics.attack_mode=="volley" if slot<0 else int(actor.windup)>0 and actor.mode=="volley"
		var released := int(feint.until)>0
		if not alive or (now>=int(feint.until) if released else not winding):
			continue
		var at: Vector3 = game.tactics.position if slot<0 else actor.pos
		result.append({"id":feint.id,"role":ROLE,"slot":slot,"real":pack_point(at),
			"decoys":feint.points.map(pack_point),"released":released})
	return result


static func pack_point(point: Vector3) -> Array:
	return [point.x,point.y,point.z]
