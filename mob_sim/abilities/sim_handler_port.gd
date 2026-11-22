extends "res://mob_sim/abilities/handler_port.gd"
## HandlerPort for the training simulation. A dead mob's slot keeps its last position until the slot is
## reused, which serves as its corpse. Hatchlings carry FLAG_SUMMONED and leave no corpse.

const Catalog = preload("res://enemy_catalog.gd")
const Clock = preload("res://mob_sim/mob_clock.gd")
const Pool = preload("res://mob_sim/mob_pool.gd")

## Share of a mob's maximum health a corpse restores, from the shared balance. A spare tether restores half.
var corpse_fraction := 0.25
## The simulation, read through a weak reference because the simulation owns this port.
var sim: RefCounted:
	get:
		return _sim.get_ref()
var _sim: WeakRef
var _memory := {}
var _hatchling := -1


func _init(simulation: RefCounted) -> void:
	_sim = weakref(simulation)
	corpse_fraction = float(preload("res://enemy_balance.gd").tuning.get("corpse_hp_fraction", corpse_fraction))
	_hatchling = sim.species.ids.find("rootbound")


func tick() -> int:
	return sim.clock.tick


func line_clear(from: Vector2, to: Vector2, clearance: float = 0.0) -> bool:
	return from.is_equal_approx(to) or sim.locomotion.world.line_clear(from.x, from.y, to.x, to.y, clearance) != 0


func position(slot: int) -> Vector2:
	return Vector2(sim.pool.xz[slot * 2], sim.pool.xz[slot * 2 + 1])


func alive(slot: int) -> bool:
	return slot >= 0 and slot < sim.pool.capacity and sim.pool.alive[slot] != 0


func reach(slot: int) -> float:
	return Catalog.radius(sim.pool.species[slot], sim.pool.mutations[slot] & 31)


func fighters(slot: int, center: Vector2, radius: float) -> PackedInt32Array:
	var found := []
	for other in sim.pool.active:
		if other == slot or sim.species.support[sim.pool.species[other]] != 0:
			continue
		var at := position(other)
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
	var consumed: Array = memory(slot).get("consumed", [])
	var found := []
	for other in sim.pool.capacity:
		if sim.pool.alive[other] != 0 or sim.pool.generation[other] == 0 or sim.pool.flags[other] & Pool.FLAG_SUMMONED != 0:
			continue
		var id := _corpse_id(other)
		var at := position(other)
		if id == exclude or consumed.has(id) or origin.distance_to(at) > radius or not line_clear(origin, at):
			continue
		found.append([origin.distance_to(at), other])
	found.sort()
	var result := []
	for entry in found:
		result.append({"id": _corpse_id(int(entry[1])), "point": position(int(entry[1]))})
	return result


func corpse_still_there(id: int, point: Vector2) -> bool:
	var slot := id >> 16
	return slot >= 0 and slot < sim.pool.capacity and sim.pool.alive[slot] == 0 and _corpse_id(slot) == id \
		and position(slot).is_equal_approx(point)


func consume_corpse(slot: int, id: int) -> void:
	var record := memory(slot)
	if not record.has("consumed"):
		record.consumed = []
	record.consumed.append(id)


func heal_from_corpse(slot: int, spare: bool) -> int:
	var before: float = sim.pool.hp[slot]
	var amount: float = sim.pool.max_hp[slot] * corpse_fraction * (0.5 if spare else 1.0)
	sim.pool.hp[slot] = minf(sim.pool.max_hp[slot], before + amount)
	var healed := roundi(sim.pool.hp[slot] - before)
	if healed > 0:
		sim.events.push(sim.Events.Kind.HEALED, tick(), slot, sim.pool.generation[slot], slot, 0, sim.pool.xz[slot * 2], sim.pool.xz[slot * 2 + 1],
			healed)
	return healed


func haste(slot: int, ms: int) -> void:
	sim.pool.haste_until[slot] = maxi(sim.pool.haste_until[slot], tick() + Clock.from_ms(float(ms)))


func command(slot: int, player: int, ms: int, via: Vector2) -> void:
	sim.pool.command_player[slot] = player
	sim.pool.command_until[slot] = tick() + Clock.from_ms(float(ms))
	sim.pool.command_via[slot] = int(via.is_finite())
	if via.is_finite():
		sim.pool.command_via_x[slot] = via.x
		sim.pool.command_via_z[slot] = via.y


func player_position(player: int) -> Vector2:
	if player < 0 or player >= sim.party.count or not sim.party.targetable(player):
		return Vector2.INF
	return Vector2(sim.party.x[player], sim.party.z[player])


func hatch_safe(point: Vector2) -> bool:
	if sim.locomotion.world.clearance(point.x, point.y) < 0.4:
		return false
	for player in sim.party.count:
		var at := player_position(player)
		if at.is_finite() and at.distance_to(point) < 1.5:
			return false
	for other in sim.pool.active:
		if position(other).distance_to(point) < 1.1:
			return false
	return true


func hatch(slot: int, point: Vector2) -> bool:
	if _hatchling < 0:
		return false
	var request := Pool.Spawn.new()
	request.species = _hatchling
	request.at = point
	request.hp = maxf(1.0, sim.pool.max_hp[slot] * 0.25)
	request.damage = sim.pool.damage[slot] * 0.5
	request.mutations = Catalog.JUVENILE
	request.flags = Pool.FLAG_SUMMONED
	request.leader = slot
	request.intelligence = sim.pool.intelligence[slot]
	return sim.spawn(request) >= 0


func memory(slot: int) -> Dictionary:
	var generation: int = sim.pool.generation[slot]
	var record: Dictionary = _memory.get(slot, {})
	if int(record.get("_generation", -1)) != generation:
		record = {"_generation": generation}
		_memory[slot] = record
	return record


func shelter_radius() -> float:
	return float(Catalog.get_kind(sim.species.ids.find("hollowback")).get("shelter_radius", 2.8))


func move(slot: int, to: Vector2) -> void:
	sim.locomotion.displace(slot, to.x, to.y)


func _corpse_id(slot: int) -> int:
	return (slot << 16) | (sim.pool.generation[slot] & 0xFFFF)
