extends RefCounted
## Shows the framework's new mechanics on top of the game's enemy models, on the host and on guests:
## flyers hover, channeling casters glow, dodging mobs flash, mana shows as a bar, and darkness dims the
## scene and hides enemies the viewer cannot see.
##
## The host captures the state from the simulation each frame. Guests receive it as a small versioned
## packet every SEND_TICKS (receive_arena_presentation in arena_world.gd), so the game's own packets never
## change. Each guest's packet carries that guest's own "seen" bits.

const ArenaLight = preload("res://neural_arena/arena_light.gd")
const Config = preload("res://neural_arena/arena_config.gd")
const DarknessView = preload("res://neural_arena/arena_darkness_view.gd")
const Tables = preload("res://mob_sim/definitions/definition_tables.gd")

const VERSION := 1
const SEND_TICKS := 6
const HEADER := 4
const FLYING := 1
const CHANNELING := 2
const DODGING := 4
const SEEN := 8
const MANA := 16
const GLOWING := 32
const HOVER_HEIGHT := 1.1
const HOVER_BOB := 0.08
const CHANNEL_COLOR := Color("#7fb2ff")
const DODGE_COLOR := Color("#ffffff")
const MANA_COLOR := Color("#5d8cff")
const BAR_HEIGHT := 2.2
const BAR_WIDTH := 0.9

var enabled_darkness := false
var level := "day"
var ambient := 1.0
## Per enemy slot.
var flags := PackedByteArray()
var mana := PackedByteArray()
## Packets a guest has accepted.
var received := 0
var _darkness := DarknessView.new()
var _bars := {}
var _bar_material: StandardMaterial3D


## Host: reads the simulation and the light for the local viewer.
func capture(world: Node) -> void:
	var bridge = world.get("bridge")
	if bridge == null or bridge.sim == null:
		_clear_state()
		return
	_capture_for(bridge, world.multiplayer.get_unique_id())


## Packs the state for one guest, with that guest's seen bits.
func pack_for(bridge: RefCounted, peer: int) -> PackedByteArray:
	_capture_for(bridge, peer)
	var packet := PackedByteArray([VERSION, ArenaLight.LEVELS.keys().find(level), flags.size(), 0])
	packet.append_array(flags)
	packet.append_array(mana)
	return packet


## Guest: accepts a packet from the host. Returns false for a packet it cannot read.
func receive(packet: PackedByteArray) -> bool:
	if packet.size() < HEADER or packet[0] != VERSION:
		return false
	var count := packet[2]
	if packet.size() != HEADER + count * 2:
		return false
	var names: Array = ArenaLight.LEVELS.keys()
	level = names[packet[1]] if packet[1] < names.size() else "day"
	ambient = float(ArenaLight.LEVELS[level])
	enabled_darkness = ambient < 1.0
	flags = packet.slice(HEADER, HEADER + count)
	mana = packet.slice(HEADER + count, HEADER + count * 2)
	received += 1
	return true


## Draws the current state over the frame the game just drew.
func draw(world: Node, guest: bool) -> void:
	var stage = world.stage
	if stage == null:
		return
	# Darkness first, so effects and bars are only drawn for enemies the viewer sees.
	var hide_unseen: bool = guest or world.config.mode == Config.Mode.PLAY
	_darkness.apply(world, enabled_darkness, ambient, hide_unseen,
		func(slot: int) -> bool: return slot < flags.size() and flags[slot] & SEEN != 0,
		func(slot: int) -> float: return _glow(stage, slot))
	var now := Time.get_ticks_msec() / 1000.0
	var bar_used := {}
	for slot in flags.size():
		var found := DarknessView.view(stage, slot)
		if found.is_empty():
			continue
		var root: Node3D = found[0]
		if not root.visible:
			continue
		var bits := flags[slot]
		var actor: Dictionary = found[1]
		var model: Node3D = actor.get("model")
		if bits & FLYING != 0 and model != null:
			model.position.y += HOVER_HEIGHT + sin(now * 2.0 + slot) * HOVER_BOB
		var surface: StandardMaterial3D = actor.get("tint")
		if surface != null and bits & (CHANNELING | DODGING) != 0:
			surface.emission_enabled = true
			if bits & DODGING != 0:
				surface.emission = DODGE_COLOR
				surface.emission_energy_multiplier = 1.4
			else:
				surface.emission = CHANNEL_COLOR
				surface.emission_energy_multiplier = 0.55 + 0.35 * sin(now * 6.0)
		if bits & MANA != 0:
			_bar(stage, slot, root.global_position + Vector3.UP * (BAR_HEIGHT + (HOVER_HEIGHT if bits & FLYING != 0 else 0.0)),
				mana[slot] / 255.0, bar_used)
	for slot in _bars.keys():
		if not bar_used.has(slot):
			_bars[slot].visible = false


func _capture_for(bridge: RefCounted, viewer: int) -> void:
	var sim = bridge.sim
	var light = bridge.light
	level = light.level if light != null else "day"
	ambient = light.ambient if light != null else 1.0
	enabled_darkness = light != null and light.enabled
	var count: int = bridge.capacity
	flags.resize(count)
	mana.resize(count)
	flags.fill(0)
	mana.fill(0)
	var tick: int = sim.clock.tick
	var pool = sim.pool
	var species = sim.species
	for slot in pool.active:
		if slot >= count:
			continue
		var kind: int = pool.species[slot]
		var bits := 0
		if species.layer[kind] != 0:
			bits |= FLYING
		if sim.actions.channeling(slot, tick):
			bits |= CHANNELING
		if tick < pool.dodge_until[slot]:
			bits |= DODGING
		if species.glow[kind] > 0.0:
			bits |= GLOWING
		if species.mana_pool[kind] > 0.0:
			bits |= MANA
			mana[slot] = clampi(roundi(sim.actions.mana_fraction(slot, tick) * 255.0), 0, 255)
		if bridge.player_sees(viewer, slot):
			bits |= SEEN
		flags[slot] = bits


func _clear_state() -> void:
	flags.resize(0)
	mana.resize(0)
	enabled_darkness = false


func _glow(stage: Node, slot: int) -> float:
	if slot >= flags.size() or flags[slot] & GLOWING == 0:
		return 0.0
	var tables = Tables.shared()
	var found := DarknessView.view(stage, slot)
	var kind := int(found[1].get("kind", -1)) if not found.is_empty() else -1
	return tables.species_glow[kind] if tables != null and kind >= 0 and kind < tables.species_glow.size() else 0.0


func _bar(stage: Node3D, slot: int, at: Vector3, fraction: float, used: Dictionary) -> void:
	var bar: MeshInstance3D = _bars.get(slot)
	if bar == null or not is_instance_valid(bar):
		if _bar_material == null:
			_bar_material = StandardMaterial3D.new()
			_bar_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			_bar_material.albedo_color = MANA_COLOR
			_bar_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		var mesh := QuadMesh.new()
		mesh.size = Vector2(BAR_WIDTH, 0.08)
		bar = MeshInstance3D.new()
		bar.mesh = mesh
		bar.material_override = _bar_material
		stage.add_child(bar)
		_bars[slot] = bar
	bar.visible = fraction > 0.0
	bar.global_position = at
	bar.scale = Vector3(maxf(0.02, fraction), 1.0, 1.0)
	used[slot] = true
