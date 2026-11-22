extends RefCounted
## Publishes the game's ground areas to the simulation's field registry (mob_sim/mob_fields.gd): the
## hazards enemies leave and the fields players make (fire and void fields, gravity wells, thorn lines),
## read from the same hint lists the game draws its warnings from. The game keeps applying their effects;
## the registry only lets the simulation, and later the net, know where they are.

const CoreCombat = preload("res://core_combat.gd")
const Fields = preload("res://mob_sim/mob_fields.gd")
const Thorn = preload("res://thorn_affinity.gd")

const PUBLISH_TICKS := 6
const MS_PER_TICK := 1000.0 / 60.0
const FIELD_ROLES := ["core_field"]


## tick is the simulation tick the areas are published for and now the game's clock in milliseconds.
static func publish(game: Node, sim: RefCounted, tick: int, now: int) -> void:
	if tick % PUBLISH_TICKS != 0:
		return
	var rows := []
	for entry: Dictionary in game.enemy_hazards:
		var at: Vector3 = entry.point
		rows.append([Fields.Owner.MOBS, at.x, at.z, float(entry.radius), tick + _ticks(int(entry.activate) - now),
			tick + _ticks(int(entry.until) - now), true])
	var hints: Array = CoreCombat.hints(game)
	hints.append_array(Thorn.hints(game))
	for hint: Dictionary in hints:
		if not FIELD_ROLES.has(str(hint.get("role", ""))):
			continue
		var from: Array = hint.from
		rows.append([Fields.Owner.PLAYERS, float(from[0]), float(from[2]), float(hint.radius), tick,
			tick + maxi(1, _ticks(roundi(float(hint.get("remaining", 0.0)) * 1000.0))), true])
	sim.fields.publish(rows)


static func _ticks(milliseconds: int) -> int:
	return ceili(milliseconds / MS_PER_TICK)
