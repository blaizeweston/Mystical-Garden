extends RefCounted
## Darkness in the Neural Arena. Each round has a light level. Players carry a light and glowing species
## give off their own, and the simulation's light grid is built from them. Mobs then need light, darkvision,
## hearing or smell to sense players, and players see a mob only when it is lit or close
## (MobPerception.player_sees). The arena's bots and the local view both use that rule.
##
## Lights are republished every few ticks rather than every tick. The light grid is rebuilt only when its
## sources change, and positions are snapped to half a unit, so a party standing still costs nothing.

const Perception = preload("res://mob_sim/mob_perception.gd")

const LEVELS := {"day": 1.0, "dusk": 0.4, "night": 0.08}
const PLAYER_LIGHT := 5.5
const PLAYER_LIGHT_INTENSITY := 1.0
const GLOW_INTENSITY := 0.9
const PUBLISH_TICKS := 6
const SNAP := 0.5

var level := "day"
var ambient := 1.0
var enabled := false
## One byte per party slot and enemy slot (player * capacity + slot), nonzero when that player sees the mob.
var seen := PackedByteArray()
var _capacity := 0
var _players := 0


func _init(darkness: String, capacity: int, players: int) -> void:
	level = darkness if LEVELS.has(darkness) else "day"
	ambient = float(LEVELS[level])
	enabled = ambient < 1.0
	_capacity = capacity
	_players = players
	seen.resize(capacity * players)
	seen.fill(1)


static func level_names() -> PackedStringArray:
	return PackedStringArray(LEVELS.keys())


## Switches the simulation's darkness on for this round.
func attach(sim: RefCounted) -> void:
	sim.set_darkness(enabled, ambient)


## Publishes the light sources and refreshes who sees whom. Call before the simulation's tick.
func update(sim: RefCounted, tick: int) -> void:
	if not enabled or tick % PUBLISH_TICKS != 0:
		return
	var lights := PackedFloat32Array()
	var party = sim.party
	for player in party.count:
		if party.targetable(player):
			lights.append_array(PackedFloat32Array([_snap(party.x[player]), _snap(party.z[player]), PLAYER_LIGHT, PLAYER_LIGHT_INTENSITY]))
	var pool = sim.pool
	for slot in pool.active:
		var radius: float = sim.species.glow[pool.species[slot]]
		if radius > 0.0:
			lights.append_array(PackedFloat32Array([_snap(pool.xz[slot * 2]), _snap(pool.xz[slot * 2 + 1]), radius, GLOW_INTENSITY]))
	sim.perception.lights = lights
	_refresh_seen(sim)


## Whether the player in party slot player sees enemy slot. Always true in daylight.
func sees(player: int, slot: int) -> bool:
	return not enabled or (player >= 0 and player < _players and slot >= 0 and slot < _capacity and seen[player * _capacity + slot] != 0)


func _refresh_seen(sim: RefCounted) -> void:
	seen.fill(0)
	var party = sim.party
	var pool = sim.pool
	for player in party.count:
		if not party.targetable(player):
			continue
		var from := Vector2(party.x[player], party.z[player])
		for slot in pool.active:
			if slot < _capacity:
				seen[player * _capacity + slot] = int(sim.perception.player_sees(from, Vector2(pool.xz[slot * 2], pool.xz[slot * 2 + 1])))


static func _snap(value: float) -> float:
	return roundf(value / SNAP) * SNAP
