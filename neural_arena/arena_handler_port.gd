extends "res://mob_sim/abilities/handler_port.gd"
## HandlerPort for the Neural Arena. Handlers act on the real enemies: corpses are real fallen enemies,
## healing uses the game's corpse balance, hatching uses the game's brood rules, and per-enemy memory is
## the enemy's own record, so legacy flags such as a denied volley or a broken shelter are shared.
## Simulation slots and roster slots are the same numbers.

const Catalog = preload("res://enemy_catalog.gd")
const CombatClock = preload("res://combat_clock.gd")
const Support = preload("res://enemy_support.gd")

var game: Node
var bridge: RefCounted


func _init(world: Node, mob_bridge: RefCounted) -> void:
	game = world
	bridge = mob_bridge


static func _v3(point: Vector2) -> Vector3:
	return Vector3(point.x, 0.0, point.y)


static func _v2(point: Vector3) -> Vector2:
	return Vector2(point.x, point.z)


func _scout(slot: int) -> Dictionary:
	return bridge.actor(slot) if slot >= 0 else {}


func tick() -> int:
	return bridge.sim.clock.tick


func line_clear(from: Vector2, to: Vector2, clearance: float = 0.0) -> bool:
	if from.is_equal_approx(to):
		return true
	return game.battlefield.clear_line(_v3(from), _v3(to), clearance) if clearance > 0.0 else game.battlefield.clear_line(_v3(from), _v3(to))


func position(slot: int) -> Vector2:
	var scout := _scout(slot)
	return _v2(scout.pos) if not scout.is_empty() else Vector2.INF


func alive(slot: int) -> bool:
	return slot >= 0 and bridge.actor_alive(slot)


func reach(slot: int) -> float:
	var scout := _scout(slot)
	return Catalog.radius(int(scout.get("kind", 0)), int(scout.get("mutations", 0))) if not scout.is_empty() else 0.0


func fighters(slot: int, center: Vector2, radius: float) -> PackedInt32Array:
	var found := []
	for other in game.encounter.scout_count():
		var scout: Dictionary = game.encounter.scout(other)
		if other == slot or not game.encounter.alive(other) or Catalog.is_support(int(scout.get("kind", 0))):
			continue
		var at := _v2(scout.pos)
		var distance := center.distance_to(at)
		if distance <= radius and line_clear(center, at):
			found.append([distance, other])
	found.sort()
	var result := PackedInt32Array()
	for entry in found:
		result.append(int(entry[1]))
	return result


func corpses(slot: int, radius: float, exclude: int = -1) -> Array:
	var origin := position(slot)
	var consumed: Array = _scout(slot).get("consumed_corpses", [])
	var found := []
	for other in game.encounter.scout_count():
		var dead: Dictionary = game.encounter.scout(other)
		var token: int = game.encounter.token(other)
		if game.encounter.hp(other) > 0 or dead.get("escaped", false) or dead.get("summoned", false) or token == exclude or consumed.has(token):
			continue
		var at := _v2(dead.pos)
		if origin.distance_to(at) <= radius and line_clear(origin, at):
			found.append([origin.distance_to(at), token, at])
	found.sort()
	var result := []
	for entry in found:
		result.append({"id": int(entry[1]), "point": entry[2]})
	return result


func corpse_still_there(id: int, point: Vector2) -> bool:
	for other in game.encounter.scout_count():
		var dead: Dictionary = game.encounter.scout(other)
		if game.encounter.token(other) == id:
			return game.encounter.hp(other) <= 0 and not dead.get("escaped", false) and not dead.get("summoned", false) \
				and _v2(dead.pos).is_equal_approx(point)
	return false


func consume_corpse(slot: int, id: int) -> void:
	var scout := _scout(slot)
	if not scout.has("consumed_corpses"):
		scout.consumed_corpses = []
	scout.consumed_corpses.append(id)


func heal_from_corpse(slot: int, spare: bool) -> int:
	var scout := _scout(slot)
	var before: int = game.encounter.hp(bridge.game_slot(slot))
	var healed := mini(int(scout.get("max_hp", before)), before + int(game.Director.Balance.corpse_heal(game, scout, spare)))
	game.encounter.set_hp(bridge.game_slot(slot), healed)
	var sim = bridge.sim
	if healed > before and sim != null:
		sim.events.push(sim.Events.Kind.HEALED, tick(), slot, sim.pool.generation[slot], slot, 0, sim.pool.xz[slot * 2],
			sim.pool.xz[slot * 2 + 1], healed - before)
	return healed - before


func haste(slot: int, ms: int) -> void:
	var scout := _scout(slot)
	if not scout.is_empty():
		scout.haste_until = maxi(int(scout.get("haste_until", 0)), CombatClock.now() + ms)


## Orders live in the simulation, which drives the arena's enemies. The bridge never overwrites them.
func command(slot: int, player: int, ms: int, via: Vector2) -> void:
	var pool = bridge.sim.pool
	pool.command_player[slot] = player
	pool.command_until[slot] = tick() + ceili(ms * 60.0 / 1000.0)
	pool.command_via[slot] = int(via.is_finite())
	if via.is_finite():
		pool.command_via_x[slot] = via.x
		pool.command_via_z[slot] = via.y


func player_position(player: int) -> Vector2:
	var peer: int = bridge.peer_of(player) if player >= 0 and player < bridge.sim.party.count else 0
	if peer == 0 or not game.players.has(peer) or not game.Life.alive(game.players[peer]):
		return Vector2.INF
	return _v2(game.players[peer].pos)


func hatch_safe(point: Vector2) -> bool:
	return Support.hatch_safe(game, _v3(point))


func hatch(_slot: int, point: Vector2) -> bool:
	return Support.spawn_brood_at(game, _v3(point), true) >= 0


func memory(slot: int) -> Dictionary:
	return _scout(slot)


func denied_aim(slot: int) -> Vector2:
	var denied = _scout(slot).get("denied_aim", null)
	return _v2(denied) if denied is Vector3 else Vector2.INF


func shelter_escort(slot: int) -> int:
	var ref: Dictionary = _scout(slot).get("shelter_escort", {})
	if ref.is_empty() or int(ref.get("slot", -1)) < 0 or not Support.live_ally(game, ref):
		return -1
	return int(ref.slot)


func shelter_radius() -> float:
	return float(Catalog.get_kind(11).get("shelter_radius", 2.8))


func move(slot: int, to: Vector2) -> void:
	var scout := _scout(slot)
	if not scout.is_empty():
		scout.pos = _v3(to)
		bridge.place(slot, scout.pos)
