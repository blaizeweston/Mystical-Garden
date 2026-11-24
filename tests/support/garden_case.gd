extends RefCounted
## Place an already researched station through the current transaction/geometry rules.
## This fixture grants no research, currency, materials or placement exceptions.
static func place_researched(world: Node, kind: String) -> bool:
	var garden=world.stage.experimental_garden
	var station: String=garden.STATIONS[kind]
	if world.stage.station_position(station).is_finite():return true
	var player: Dictionary=world.players[world.HOST]
	var previous: Vector3=player.pos
	player.pos=Vector3(0,0,1.5)
	var id := 0
	for key: int in world.progress.structures.instances:
		var entry: Dictionary=world.progress.structures.instances[key]
		if entry.kind==kind and not entry.placed: id=key;break
	for x in range(-14,15):
		for y in range(-14,15):
			var at := Vector2(x,y)*.6
			if not garden._build_refusal(kind,at,0.0,id).is_empty():continue
			var placed: bool=garden.place(kind,at,0.0,id)
			player.pos=previous
			return placed
	player.pos=previous
	return false
