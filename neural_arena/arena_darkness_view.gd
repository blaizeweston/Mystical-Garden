extends RefCounted
## Draws the arena's darkness: dims the stage's sky, sun and ambient light, carries a light with every player
## and glowing enemy, and hides enemies the viewer cannot see. ArenaPresentation calls it on the host and on
## guests with the state it captured or received.
##
## The stage sets its own light levels as floors change, so each frame scales whatever it last set.

const ArenaLight = preload("res://neural_arena/arena_light.gd")
const Catalog = preload("res://enemy_catalog.gd")

const PLAYER_LIGHT_ENERGY := 1.8
const PLAYER_LIGHT_HEIGHT := 1.8
const PLAYER_LIGHT_COLOR := Color("#ffd9a0")
const GLOW_ENERGY := 1.2
const GLOW_HEIGHT := 1.0
## Even at night the scene keeps this share of its light, so terrain stays readable.
const FLOOR_SHARE := 0.18

var _lights := {}
var _base := {}
var _applied := {}


## Call after the game has drawn the frame. sees(slot) says whether the viewer sees an enemy, and
## glow(slot) gives the radius of the light an enemy gives off. hide_unseen hides the rest.
func apply(world: Node, enabled: bool, ambient: float, hide_unseen: bool, sees: Callable, glow: Callable) -> void:
	if not enabled or world.stage == null:
		_clear_lights()
		_restore()
		return
	var share := maxf(FLOOR_SHARE, ambient)
	var stage: Node3D = world.stage
	var environment: WorldEnvironment = stage.get_node_or_null("WorldEnvironment")
	if environment != null and environment.environment != null:
		_scale(environment.environment, "ambient_light_energy", share)
		_scale(environment.environment, "background_energy_multiplier", share)
	var sun: DirectionalLight3D = stage.get_node_or_null("Sun")
	if sun != null:
		_scale(sun, "light_energy", share)
	var used := {}
	for id in stage.avatars:
		var avatar: Node3D = stage.avatars[id]
		if is_instance_valid(avatar) and avatar.visible:
			_place_light("player_%d" % id, stage, avatar.global_position + Vector3.UP * PLAYER_LIGHT_HEIGHT, ArenaLight.PLAYER_LIGHT,
				PLAYER_LIGHT_ENERGY, PLAYER_LIGHT_COLOR, used)
	for slot in stage.support_models.size():
		var model: Node3D = stage.support_models[slot]
		if not model.visible:
			continue
		if hide_unseen and not sees.call(slot):
			model.visible = false
			stage.support_rings[slot].visible = false
			stage.support_binds[slot].visible = false
			continue
		var radius: float = glow.call(slot)
		if radius > 0.0:
			var kind := int(stage.scout_models[slot].get("kind", 0))
			_place_light("enemy_%d" % slot, stage, model.global_position + Vector3.UP * GLOW_HEIGHT, radius, GLOW_ENERGY,
				Color(Catalog.get_kind(kind).glow), used)
	for key in _lights.keys():
		if not used.has(key):
			_lights[key].queue_free()
			_lights.erase(key)


func _scale(target: Object, property: String, share: float) -> void:
	var key := "%d:%s" % [target.get_instance_id(), property]
	var current: float = target.get(property)
	# A value other than the one written last frame is the stage's new level.
	if not _applied.has(key) or not is_equal_approx(current, float(_applied[key])):
		_base[key] = current
	var value: float = float(_base[key]) * share
	target.set(property, value)
	_applied[key] = value


## Puts back the light levels this view dimmed, unless the stage has set new ones since.
func _restore() -> void:
	for key: String in _applied:
		var target := instance_from_id(int(key.get_slice(":", 0)))
		var property := key.get_slice(":", 1)
		if target != null and is_equal_approx(float(target.get(property)), float(_applied[key])):
			target.set(property, _base[key])
	_applied.clear()
	_base.clear()


func _place_light(key: String, parent: Node3D, at: Vector3, radius: float, energy: float, color: Color, used: Dictionary) -> void:
	var lamp: OmniLight3D = _lights.get(key)
	if lamp == null or not is_instance_valid(lamp):
		lamp = OmniLight3D.new()
		lamp.shadow_enabled = false
		parent.add_child(lamp)
		_lights[key] = lamp
	lamp.global_position = at
	lamp.omni_range = radius
	lamp.light_energy = energy
	lamp.light_color = color
	used[key] = true


func _clear_lights() -> void:
	for lamp in _lights.values():
		if is_instance_valid(lamp):
			lamp.queue_free()
	_lights.clear()
