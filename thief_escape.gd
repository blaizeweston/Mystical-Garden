extends RefCounted

const KIND := 16
const RUN_SPEED := 2.6
const MIN_CHASE_MS := 4500
const BURROW_MS := 1600
const TUNNEL_RADIUS := .24
const FIELD = preload("res://battlefield.gd")


static func candidate(field: RefCounted, point: Vector3, origin: Vector3, options: Dictionary) -> void:
	var cell := Vector2i(roundi(point.x * 2.0),roundi(point.z * 2.0))
	if options.has(cell) or not field.navigation.region.has_point(cell) or field.navigation.is_point_solid(cell):
		return
	var at := Vector3(cell.x * .5,0,cell.y * .5)
	var distance := origin.distance_to(at)
	if distance < 5.0 or at.distance_to(field.advance) < 2.5 or at.distance_to(field.entry) < 2.5:
		return
	var edge_cost := absf(field.floor_distance(at) - .95) * .8 if field.procedural else 0.0
	options[cell] = {"at":at,"score":absf(distance - 10.5) + edge_cost}


static func path_to(field: RefCounted, origin: Vector3, tunnel: Vector3) -> PackedVector3Array:
	if field.clear_line(origin,tunnel,FIELD.CLEARANCE+.1):
		return PackedVector3Array([tunnel])
	var target := Vector2i(roundi(tunnel.x * 2.0),roundi(tunnel.z * 2.0))
	if not field.navigation.region.has_point(target) or field.navigation.is_point_solid(target):
		return PackedVector3Array()
	var grid: PackedVector2Array = field.navigation.get_point_path(field.free_cell(origin),target)
	var route := PackedVector3Array()
	var start := 0
	var anchor := origin
	while start < grid.size():
		var next := start
		for i in range(grid.size()-1,start,-1):
			if field.clear_line(anchor,Vector3(grid[i].x,0,grid[i].y),FIELD.CLEARANCE+.1):
				next = i
				break
		var point := Vector3(grid[next].x,0,grid[next].y)
		if not field.clear_line(anchor,point,FIELD.CLEARANCE):
			return PackedVector3Array()
		if anchor.distance_to(point) > .03:
			route.append(point)
		anchor = point
		start = next + 1
	return route


static func plan(field: RefCounted, origin: Vector3) -> PackedVector3Array:
	var options := {}
	for clearing in field.clearings:
		for i in 8:
			var angle := i * TAU / 8.0
			candidate(field,Vector3(clearing.x + cos(angle) * clearing.z * .78,0,clearing.y + sin(angle) * clearing.z * .78),origin,options)
	for i in 12:
		var angle := i * TAU / 12.0
		candidate(field,origin + Vector3(cos(angle),0,sin(angle)) * 10.5,origin,options)
	var ranked := options.values()
	ranked.sort_custom(func(a,b): return a.score < b.score)
	var backup := PackedVector3Array()
	for option in ranked.slice(0,16):
		var route := path_to(field,origin,option.at)
		if route.is_empty():
			continue
		var distance := 0.0
		var previous := origin
		for waypoint in route:
			distance += previous.distance_to(waypoint)
			previous = waypoint
		if distance <= 17.5:
			return route
		if backup.is_empty():
			backup = route
	return backup


static func steal(game: Node, actor: Dictionary, drop: Dictionary, now: int) -> bool:
	var path := plan(game.battlefield,actor.pos)
	if path.is_empty():
		return false
	actor.escape = {"path":path,"step":0,"tunnel":path[-1],"earliest":now+MIN_CHASE_MS,"burrow_until":0}
	actor.stolen = [drop.duplicate(true)]
	game.wild_item_drops.erase(drop)
	preload("res://event_audio.gd").emit(game,"trophy_taken",actor.pos)
	notify_party(game,"The Graft Thief stole a trophy. Follow its trail to the tunnel!")
	game.Journal.event("combat","thief_fled_with_trophy",{"actor":game.encounter.token_for(actor),"floor":game.encounter_number})
	return true


static func notify_party(game: Node, message: String) -> void:
	for id in game.players:
		if game.players[id].get("wild",false) and game.players[id].get("profile_ready",false):
			game.tell(id,message)


static func tick(game: Node, actor: Dictionary, delta: float, now: int) -> void:
	var state: Dictionary = actor.get("escape",{})
	if state.is_empty():
		recover(game,actor,actor.pos)
		return
	if now < int(actor.rooted_until) or now < int(actor.stagger_until):
		state.burrow_until = 0
		return
	var at: Vector3 = actor.pos
	var tunnel: Vector3 = state.tunnel
	if at.distance_to(tunnel) <= TUNNEL_RADIUS and game.battlefield.clear_line(at,tunnel,FIELD.CLEARANCE):
		if int(state.burrow_until) == 0:
			state.burrow_until = maxi(now+BURROW_MS,int(state.earliest))
		elif now >= int(state.burrow_until):
			escape(game,actor)
		return
	state.burrow_until = 0
	var route: PackedVector3Array = state.path
	var step: int = state.step
	while step < route.size()-1 and at.distance_to(route[step]) <= .04:
		step += 1
	var waypoint := route[step]
	if not game.battlefield.clear_line(at,waypoint,FIELD.CLEARANCE):
		route = path_to(game.battlefield,at,tunnel)
		if route.is_empty():
			recover(game,actor,at)
			actor.ready = now+800
			notify_party(game,"The Graft Thief dropped the stolen trophy.")
			return
		state.path = route
		step = 0
		waypoint = route[0]
	state.step = step
	actor.pos = at.move_toward(waypoint,maxf(0.0,delta)*RUN_SPEED)


static func escape(game: Node, actor: Dictionary) -> void:
	var gate_elite: bool=actor.get("gate_elite",false)
	var slot: int=-1 if gate_elite else game.encounter.scout_slot(actor)
	if not gate_elite and slot<0:
		return
	if gate_elite and not is_same(actor,game.encounter.leader_tactics()):
		return
	if not game.encounter.alive(slot):
		return
	actor.erase("escape")
	actor.erase("stolen")
	# Leave the slot inactive without awarding a kill, a corpse or a trophy.
	actor.escaped = true
	game.encounter.despawn(slot)
	if gate_elite:
		game.tactics.winding_up = false
		game.tactics.attack_mode = ""
	game.Journal.event("combat","thief_escaped",{"actor":game.encounter.token_for(actor),"floor":game.encounter_number})
	notify_party(game,"The Graft Thief escaped with the trophy.")


static func recover(game: Node, actor: Dictionary, point: Vector3) -> void:
	for drop in actor.get("stolen",[]):
		drop.position = [point.x,0,point.z]
		game.wild_item_drops.append(drop)
	actor.erase("stolen")
	actor.erase("escape")


static func route_info(game: Node, actor: Dictionary, id: int) -> Dictionary:
	var state: Dictionary = actor.get("escape",{})
	if state.is_empty():
		return {}
	var path: PackedVector3Array = state.path
	return {"id":id,"token":int(game.encounter.token_for(actor)),"pos":actor.pos,"tunnel":state.tunnel,
		"path":path.slice(int(state.step)),"burrowing":int(state.burrow_until)>0}


static func snapshot(game: Node) -> Array:
	var result := []
	if game.encounter.hp(-1) > 0:
		var leader := route_info(game,game.encounter.leader_tactics(),-1)
		if not leader.is_empty():
			result.append(leader)
	for id in game.encounter.scout_count():
		if game.encounter.hp(id) <= 0:
			continue
		var row := route_info(game,game.encounter.scout(id),id)
		if not row.is_empty():
			result.append(row)
	return result


static func map_routes(game: Node, player: Dictionary) -> Array:
	if game.multiplayer.is_server():
		return snapshot(game)
	if game.client_details_key != str([game.destination,game.encounter_number,game.map_seed]):
		return []
	var result := []
	for row in player.get("thief_routes",[]):
		var id: int = row.id
		var offset: int = id * game.PACK_STRIDE
		var at: Vector3
		if id == -1:
			if game.enemy_health() <= 0 or game.enemy_kind != KIND:
				continue
			at = game.tactics.position
		else:
			if offset+2 >= game.client_pack.size() or game.client_pack[offset+2] <= 0.0 or 19+id >= game.client_campaign.size():
				continue
			if int(game.Enemies.decode(game.client_campaign[19+id]).kind) != KIND:
				continue
			at = Vector3(game.client_pack[offset],0,game.client_pack[offset+1])
		var marker: Dictionary = row.duplicate()
		marker.pos = at
		result.append(marker)
	return result
