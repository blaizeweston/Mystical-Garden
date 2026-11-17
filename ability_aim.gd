extends Node3D

const Cooldowns = preload("res://player_cooldowns.gd")
const Core = preload("res://core_combat.gd")
const Targeting = preload("res://class_ability_targeting.gd")
const Contact = preload("res://weapon_contact.gd")
const ACTIONS := [&"class_skill", &"class_skill_two", &"core_skill"]
const PREFIX := "class_cast:"
const META := &"ability_aim"

var game: Node
var slot := -1
var binding: Array
var world := ""
var drawing := ImmediateMesh.new()
var color := Color.WHITE


static func active(game_node: Node):
	return game_node.get_meta(META) if game_node.has_meta(META) else null


static func player(game_node: Node) -> Dictionary:
	return game_node.players.get(game_node.multiplayer.get_unique_id(), {})


static func available(game_node: Node, local: Dictionary, requested_slot: int) -> bool:
	return game_node.session != "Connecting" and not game_node.returning_to_title and not game_node.overlay.visible and not game_node.checkpoint_menu.visible \
		and not game_node.get_meta("garden_cinematic_active", false) and not (game_node.settings_dialog != null and game_node.settings_dialog.visible) \
		and game_node.Life.alive(local) \
		and (not game_node.encounter_cleared() or (requested_slot == 2 and can_recover(game_node, local))) \
		and (game_node.multiplayer.is_server() or (game_node.session == "Guest" and game_node.client_details_key == str([game_node.participation.route(), game_node.participation.floor(), game_node.participation.seed()])))


static func can_recover(game: Node, player: Dictionary) -> bool:
	if not preload("res://combat_ruleset.gd").active(game):
		return false
	if game.multiplayer.is_server():
		return Core.equipped(player).get("affinity_family") == "vital"
	var build: Dictionary = player.get("weapon_stats", {}).get("affinity_build", {})
	var core: Dictionary = build.get("core", {})
	return core.get("state") == "ready" and core.get("primary_affinity") == "vital"



static func input_event(game_node: Node, event: InputEvent) -> bool:
	if release_event(game_node, event):
		return true
	if not event.is_pressed() or event.is_echo():
		return false
	for index in ACTIONS.size():
		if not event.is_action_pressed(ACTIONS[index]):
			continue
		var local := player(game_node)
		if available(game_node, local, index):
			var preview = active(game_node)
			if preview == null:
				preview = new()
				preview.game = game_node
				game_node.add_child(preview)
				game_node.set_meta(META, preview)
			if preview.slot == -1:
				preview.slot = index
				preview.binding = identity(event)
				preview.world = Core.cast_key(game_node, local)
				preview.set_process(true)
				preview.update_preview(local)
		return true
	return false


static func release_event(game_node: Node, event: InputEvent) -> bool:
	var preview = active(game_node)
	if preview == null or preview.slot == -1 or event.is_pressed() or preview.binding != identity(event):
		return false
	var local := player(game_node)
	var committed_slot: int = preview.slot
	var valid: bool = available(game_node, local, committed_slot) and preview.world == Core.cast_key(game_node, local)
	preview.cancel()
	if valid:
		var aim := Core.local_aim(game_node, local)
		var direction: Vector2 = aim.direction
		var action := Core.request(game_node, local, direction, aim.distance) if committed_slot == 2 else request(game_node, local, committed_slot, direction, aim.distance)
		game_node.send_garden_action(action)
	return true


static func identity(event: InputEvent) -> Array:
	if event is InputEventKey:
		return ["key", event.device, event.physical_keycode if event.physical_keycode != 0 else event.keycode]
	if event is InputEventMouseButton:
		return ["mouse", event.device, event.button_index]
	if event is InputEventJoypadButton:
		return ["joy", event.device, event.button_index]
	if event is InputEventAction:
		return ["action", event.device, event.action]
	return []


static func request(game_node: Node, local: Dictionary, class_slot: int, direction: Vector2, distance: float = -1.0) -> String:
	return PREFIX + "%s:%d:%s:%s:%s" % [Core.cast_key(game_node, local), class_slot, direction.x, direction.y, distance]


static func command(game_node: Node, id: int, local: Dictionary, action: String) -> void:
	if not game_node.multiplayer.is_server() or not game_node.Life.alive(local) or not local.get("profile_ready", false) or game_node.encounter_cleared():
		return
	var args := action.split(":", true, 5)
	if args.size() not in [5,6] or args[1] != Core.cast_key(game_node, local) or args[2] not in ["0", "1"] or not args[3].is_valid_float() or not args[4].is_valid_float():
		return
	var direction := Vector2(float(args[3]), float(args[4]))
	if not direction.is_finite() or absf(direction.x) > 1.001 or absf(direction.y) > 1.001 or direction.length_squared() < .01:
		return
	if args.size() == 6 and not args[5].is_valid_float():
		return
	var distance := float(args[5]) if args.size() == 6 else -1.0
	if not is_finite(distance) or distance < -1.0 or distance > 10000.0:
		return
	var was_mouse: bool = local.get("mouse_aim", false)
	local.mouse_aim = true
	local.class_aim = Vector3(direction.x, 0, direction.y).normalized()
	local.class_aim_distance = distance
	game_node.use_class_skill(id, local, int(args[2]))
	local.erase("class_aim")
	local.erase("class_aim_distance")
	local.mouse_aim = was_mouse


func _ready() -> void:
	var surface := MeshInstance3D.new()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.vertex_color_use_as_albedo = true
	surface.material_override = material
	surface.mesh = drawing
	surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(surface)
	position = game.stage.WILD_OFFSET + Vector3.UP * .08
	get_window().focus_exited.connect(cancel)
	set_process(false)


func cancel() -> void:
	slot = -1
	binding.clear()
	world = ""
	drawing.clear_surfaces()
	set_process(false)


func _process(_delta: float) -> void:
	var local := player(game)
	if not available(game, local, slot) or world != Core.cast_key(game, local):
		cancel()
		return
	update_preview(local)


func update_preview(local: Dictionary) -> void:
	var sampled := Core.local_aim(game, local)
	var direction: Vector2 = sampled.direction
	var forward := Vector3(direction.x, 0, direction.y).normalized()
	var field: RefCounted = game.battlefield if game.multiplayer.is_server() else game.stage.visual_field
	drawing.clear_surfaces()
	if field == null:
		return
	var preview := footprint(game, local, field, slot, forward, sampled.distance)
	if preview.is_empty() or preview.shapes.is_empty():
		return
	color = Color(preview.color) if preview.valid else Color("#d99979")
	drawing.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for shape in preview.shapes:
		draw_shape(shape)
	drawing.surface_end()


static func footprint(game_node: Node, local: Dictionary, field: RefCounted, skill_slot: int, forward: Vector3, distance: float) -> Dictionary:
	if skill_slot == 2:
		return Core.preview(game_node, local, field, forward, distance)
	var stats: Dictionary = game_node.weapon_stats(local) if game_node.multiplayer.is_server() else local.get("weapon_stats", {})
	if stats.is_empty():
		return {}
	var profile: Dictionary = local.get("character", game_node.guest_character.data)
	var skill: Dictionary = game_node.Traits.tune_skill(game_node.Skills.resolve_in_world(game_node, int(local.frame), skill_slot, profile), stats)
	var cast := Targeting.plan(game_node, local, field, skill, stats, forward, distance)
	var ready: bool
	if game_node.multiplayer.is_server():
		var timers: Cooldowns.Timers = local.get(Cooldowns.STATE)
		ready = timers == null or timers.ready(Cooldowns.Q if skill_slot == 0 else Cooldowns.R, Time.get_ticks_msec())
	else:
		ready = local.get("skill_ready" if skill_slot == 0 else "skill_two_ready", false)
	return {"shapes": Targeting.footprint(game_node, local, field, skill, stats, cast), "color": skill.color, "valid": cast.valid and ready}


func draw_shape(shape: Dictionary) -> void:
	match shape.kind:
		"range", "area", "point":
			if float(shape.radius) <= 0.0:
				return
			var contour := ring(shape.at, shape.radius)
			outline(contour, .028 if shape.kind == "range" else .052, shape.kind == "range")
			if shape.kind == "area":
				fill(contour, shape.at)
		"cone":
			var contour := PackedVector3Array([shape.at])
			var forward: Vector3 = shape.forward
			for index in 33:
				contour.append(shape.at + forward.rotated(Vector3.UP, (index / 32.0 - .5) * float(shape.span)) * float(shape.radius))
			outline(contour, .052)
			fill(contour, shape.at)
		"crescent_guide":
			for lane in shape.segments:
				var from: Vector3 = lane.from
				var to: Vector3 = lane.to
				var side := (to - from).normalized().cross(Vector3.UP) * float(lane.width)
				for offset in [-side, side]:
					segment(from + offset, to + offset, .068, .94)
				segment(from, to, .046, .62)
			if not shape.segments.is_empty():
				outline(ring(shape.segments.front().from, shape.segments.front().width), .036)
				outline(ring(shape.segments.back().to, shape.segments.back().width), .036)
		"link_guide":
			segment(shape.from, shape.to, .05, .9)
		"travel":
			segment(shape.from, shape.to, .038, .78)
			outline(ring(shape.to, .43), .046)
		"strip", "capsule":
			var start: Vector3 = shape.from
			var end: Vector3 = shape.to
			var side := (end - start).normalized().cross(Vector3.UP) * float(shape.width)
			var contour := PackedVector3Array([start - side, end - side, end + side, start + side])
			if shape.kind == "capsule":
				contour = Contact.outline({"pattern": "line", "reach": start.distance_to(end), "width": shape.width}, start, end)
			outline(contour, .052)
			fill(contour, (start + end) * .5)
		"weapon":
			var contour := Contact.outline(shape.profile, shape.at, shape.at + shape.forward)
			outline(contour, .052)
			fill(contour, shape.at)


func ring(center: Vector3, radius: float) -> PackedVector3Array:
	var points := PackedVector3Array()
	for index in 64:
		points.append(center + Vector3(cos(index * TAU / 64.0), 0, sin(index * TAU / 64.0)) * radius)
	return points


func outline(points: PackedVector3Array, thickness: float, dashed: bool = false) -> void:
	for index in points.size():
		if not dashed or index % 4 < 2:
			segment(points[index], points[(index + 1) % points.size()], thickness, .55 if dashed else .94)


func fill(points: PackedVector3Array, center: Vector3) -> void:
	for index in points.size():
		triangle(center, points[index], points[(index + 1) % points.size()], .12)


func segment(start: Vector3, end: Vector3, thickness: float, alpha: float) -> void:
	var side := (end - start).normalized().cross(Vector3.UP) * thickness
	triangle(start - side, end - side, end + side, alpha)
	triangle(start - side, end + side, start + side, alpha)


func triangle(a: Vector3, b: Vector3, c: Vector3, alpha: float) -> void:
	for point in [a, b, c]:
		drawing.surface_set_color(Color(color, alpha))
		drawing.surface_add_vertex(point)
