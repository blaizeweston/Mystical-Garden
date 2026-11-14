extends Node3D

const Generator = preload("res://assets/terrain_m02/terrain_generator.gd")
const Layout = preload("res://assets/terrain_m02/terrain_feature_layout.gd")
const Art = preload("res://assets/terrain_m02/terrain_art_direction.gd")
const Enclosure = preload("res://assets/terrain_m02/terrain_enclosure.gd")
const EnclosureView = preload("res://assets/terrain_m02/terrain_enclosure_view.gd")
const Garden = preload("res://assets/terrain_m02/garden_expansion.gd")
const Forest = preload("res://assets/terrain_m02/garden_forest_barrier.gd")
const Heart = preload("res://assets/terrain_m02/terrain_heart_preview.gd")
const Roots = preload("res://assets/terrain_m02/garden_heart_roots.gd")
const Build = preload("res://assets/terrain_m02/garden_construction.gd")
const Surface = preload("res://assets/terrain_m02/experimental/experiment_terrain_view.gd")
const Stations = preload("res://assets/terrain_m02/garden_station_art.gd")
const Offerings = preload("res://assets/terrain_m02/garden_offerings.gd")
const OfferView = preload("res://assets/terrain_m02/garden_offerings_view.gd")
const Study = preload("res://assets/terrain_m02/experimental/heart_assimilation.gd")
const Journal = preload("res://diagnostic_journal.gd")
const Tx = preload("res://game_transaction.gd")
const Catalog = preload("res://heart_catalog.gd")
const Shapes = preload("res://assets/terrain_m02/terrain_feature_geometry.gd")
const GateMesh = preload("res://assets/terrain_m02/wilds_massing_mesh.gd")
const Bark = preload("res://assets/terrain_m02/heart_bark.gdshader")
const Spacing := 1.75
const Radius := 14
const Seed := 117

var game: Node
var stage: Node3D
var state: Garden
var barrier: Forest
var forest: EnclosureView
var heart: Heart
var roots: Node3D
var network: Array[Dictionary] = []
var material: ShaderMaterial
var base_rim: PackedFloat32Array
var construction: Build
var bed_ids := {}
var bed_mesh: ArrayMesh
var bed_material: StandardMaterial3D
var station_ids := {}
var structure_nodes := {}
var funds := Offerings.new()
var assimilation := Study.new()
var study_glow := 0.0
var reclaim_glow := 0.0
var study_light: Tween
var offering_dialog: OfferView
var development_dialog: AcceptDialog
var frontier: OptionButton
var grow: Button
var review: Label
var plans := {}
var construction_kind: OptionButton
var building_picker: OptionButton
var ghost: MeshInstance3D
var build_kind := ""
var build_moving := 0
var build_target := Vector2.INF
var build_yaw := 0.0
var reveal: Tween
var growth_preview: MeshInstance3D

func configure(world: Node, presentation: Node3D) -> void:
	game = world
	stage = presentation
	stage.experimental_garden = self
	for node in [stage.garden_disc, stage.garden_edge, stage.legacy_garden_base, stage.legacy_gate, stage.legacy_altar, stage.heart_tree, stage.heart_seed]:
		node.hide()
	game.progress.player_placed_beds = true
	# The shared stash stores canonical components. Do not offer an alias of the same stack.
	for id: String in funds.items.keys():
		if funds.Items.part_id(funds.items[id].legacy_part) != id:
			funds.items.erase(id)
	var cells := Generator.generate(Seed, Radius, preload("res://assets/terrain_m02/garden_clearing.tres"), Surface.Catalog)
	var layout := Layout.build(cells, Spacing, Radius, Seed, true, true)
	var protections: Array = []
	for index in 3:
		var point: Vector3 = stage.PLOTS[index]
		protections.append(Shapes.disk("bed_%d" % index, "plot", planar(point), 1.06))
	for id: String in ["altar", "spring"]:
		var at := Vector2(-3.5, -2) if id == "altar" else Vector2(6.0, 1.5)
		protections.append(Shapes.disk(id, "station", at, 0.88))
	for row: Dictionary in protections:
		layout.rocks = layout.rocks.filter(func(rock): return not Shapes.in_any([rock], row.center, row.radius + 0.55))
		layout.plants = layout.plants.filter(func(plant): return plant.center.distance_to(row.center) > row.radius + 0.65)
	layout = Art.placements(Enclosure.build(layout, cells, Spacing, Seed, true), 0)
	state = Garden.new(cells, layout, Spacing, Seed, Radius, protections)
	barrier = Forest.new()
	add_child(barrier)
	barrier.bind(state)
	construction = Build.new(barrier)
	var profile := Art.profile(0)
	material = Surface.material(cells, layout, Seed, Radius, Spacing)
	material.set_shader_parameter("art_mode", 1)
	material.set_shader_parameter("garden_frontier", true)
	material.set_shader_parameter("scenic_cover", Vector3(0.10, 0.89, 0.01))
	material.set_shader_parameter("botanical_ground", profile.ground)
	material.set_shader_parameter("botanical_water", profile.water)
	Surface.plane(self, material, 92.0)
	var features := Surface.Features.new()
	add_child(features)
	features.rebuild(layout, profile, 0)
	forest = EnclosureView.new()
	add_child(forest)
	var enclosure := state.forest_layout()
	enclosure["scenic_woodland"] = state.scenic_woodland()
	forest.rebuild(enclosure, true, profile, 0, true)
	base_rim = state.enclosure_support()
	_update_rim(base_rim)
	heart = Heart.new()
	add_child(heart)
	heart.set_sculpt(true)
	roots = Node3D.new()
	add_child(roots)
	growth_preview = MeshInstance3D.new()
	growth_preview.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var highlight := StandardMaterial3D.new()
	highlight.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	highlight.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	highlight.cull_mode = BaseMaterial3D.CULL_DISABLED
	highlight.no_depth_test = true
	highlight.albedo_color = Color("#dfbd5860")
	growth_preview.material_override = highlight
	add_child(growth_preview)
	var gate := stage.mesh(GateMesh.gate(), landmark("wilds_entrance"), Color.WHITE) as MeshInstance3D
	gate.reparent(self, false)
	var colors := StandardMaterial3D.new()
	colors.vertex_color_use_as_albedo = true
	gate.material_override = colors
	stage.build_gate_swirl(self, landmark("wilds_entrance"))
	_make_station("altar", "altar", landmark("altar"), 0.0)
	_make_station("spring", "spring", landmark("spring"), 0.0)
	_initialize_controls()

func show_heart_stage(index: int) -> void:
	if heart.stage != mini(index, 4):
		heart.show_stage(mini(index, 4))

func planar(at: Vector3) -> Vector2:
	return Vector2(at.x, at.z)

func world(at: Vector2) -> Vector3:
	return Vector3(at.x, 0, at.y)

func landmark(id: String) -> Vector3:
	return world(state.landmarks[id].center)

func return_position() -> Vector3:
	var route: PackedVector2Array = state.layout.paths[0].spine
	for point in route:
		if point.distance_to(planar(landmark("wilds_entrance"))) >= 1.5 and barrier.walkable(point):
			return world(point)
	return landmark("wilds_entrance")

func station_position(id: String) -> Vector3:
	return world(construction.records[station_ids[id]].at) if station_ids.has(id) else Vector3.INF

func bed_position(index: int) -> Vector3:
	if index < 3:
		return stage.PLOTS[index]
	return world(construction.records[bed_ids[index]].at) if bed_ids.has(index) else Vector3.INF

func bed_yaw(index: int) -> float:
	return -float(construction.records[bed_ids[index]].yaw) if bed_ids.has(index) else 0.0

func make_bed(index: int) -> MeshInstance3D:
	if bed_mesh == null:
		bed_mesh = Stations.build(Build.CATALOG.bed.art, false)
		bed_material = StandardMaterial3D.new()
		bed_material.vertex_color_use_as_albedo = true
	var bed := MeshInstance3D.new()
	bed.name = "CultivationBed"
	bed.mesh = bed_mesh
	bed.material_override = bed_material
	bed.position = bed_position(index)
	bed.rotation.y = bed_yaw(index)
	return bed

func slide(from: Vector3, to: Vector3) -> Vector3:
	var target := planar(to)
	var moved := barrier.move(planar(from), target - planar(from))
	if moved.is_equal_approx(target):
		return world(moved)
	var x := barrier.move(moved, Vector2(target.x - moved.x, 0))
	var z := barrier.move(moved, Vector2(0, target.y - moved.y))
	return world(x if x.distance_squared_to(target) < z.distance_squared_to(target) else z)

func _make_station(id: String, art: String, position: Vector3, yaw: float) -> void:
	var instance := structure_nodes.get(id) as MeshInstance3D
	if instance == null:
		instance = MeshInstance3D.new()
		instance.mesh = Stations.build(art)
		var colors := StandardMaterial3D.new()
		colors.vertex_color_use_as_albedo = true
		instance.material_override = colors
		add_child(instance)
		structure_nodes[id] = instance
	instance.position = position
	instance.rotation.y = -yaw

func _update_rim(previous: PackedFloat32Array, progress: float = 1.0) -> void:
	var packed := PackedFloat32Array()
	for i in barrier.starts.size():
		packed.append_array([barrier.starts[i].length(), barrier.finishes[i].length(), base_rim[i], 0.0])
	var image := Image.create_from_data(barrier.starts.size(), 1, false, Image.FORMAT_RGBAF, packed.to_byte_array())
	material.set_shader_parameter("garden_perimeter", ImageTexture.create_from_image(image))
	material.set_shader_parameter("garden_reveal", progress)
	forest.position_frontier(previous, state.enclosure_support(), progress)

func available_here() -> bool:
	return _may_place() and game.at_heart(game.players[game.HOST])

func open_offerings() -> void:
	if not available_here():
		game.tell(game.HOST, "Visit the Heart to offer shared parts.")
		return
	_refresh_parts()
	offering_dialog.present(funds)

func _refresh_parts() -> void:
	for id: String in funds.items:
		var part: int = funds.items[id].legacy_part
		var player: Dictionary = game.players[game.HOST]
		funds.inventory[id] = game.progress.part_count(part)
		funds.reserved[id] = funds.inventory[id] - _shared_free(player, part)
	funds.inventory_revision += 1

func _shared_free(player: Dictionary, part: int) -> int:
	var others: int = game.LoadoutMaterials.shared_free(game, part, player)
	var personal: int = game.seed_reserve(player).parts[part]
	var reserved: int = maxi(0, game.LoadoutMaterials.demand(player, part) - personal)
	return maxi(0, others - reserved)

func contribute(quote: Dictionary) -> bool:
	if not available_here() or quote.is_empty() or not quote.get("items") is Dictionary:
		return false
	var outcome := Tx.run_gameplay(game, Tx.Scope.GARDEN, func() -> bool:
		if funds.quote(quote.items) != quote:
			return false
		var player: Dictionary = game.players[game.HOST]
		for id: String in quote.items:
			if _shared_free(player, funds.items[id].legacy_part) < int(quote.items[id]):
				return false
		for id: String in quote.items:
			game.progress.add_parts(funds.items[id].legacy_part, -int(quote.items[id]))
		return true)
	var accepted: bool = Tx.committed(outcome.persistence) and outcome.value == true
	if accepted:
		funds.energy += int(quote.energy)
		var starting := assimilation.queue.is_empty()
		assimilation.add(quote.items)
		if starting:
			_study_light(0.6, 0.22)
		Journal.event("interaction", "heart_assimilation_queued", {"parts": quote.items,
			"growth": quote.energy, "knowledge": assimilation.queue.back().knowledge})
	_refresh_parts()
	return accepted

func advance_assimilation(elapsed: float, in_wilds: bool) -> void:
	if elapsed <= 0.0 or assimilation.queue.is_empty() or get_tree().paused or not Tx.session_writable(game):
		return
	var next := assimilation.plan(game.progress.heart.progression_work(elapsed, in_wilds))
	var knowledge: int = next.earned
	if knowledge > 0:
		var result := Tx.run_gameplay(game, Tx.Scope.GARDEN, func(): game.progress.knowledge += knowledge)
		if not Tx.committed(result.persistence):
			if offering_dialog.visible:
				offering_dialog.refresh_studies()
			return
	assimilation.queue = next.queue
	if knowledge > 0:
		game.tell(game.HOST, "The Heart assimilated its offering. +%d Knowledge." % knowledge)
		Journal.event("interaction", "heart_assimilation_completed", {"knowledge": knowledge})
		_study_light(0.65, 0.14, true)
	else:
		_study_light(0.18 + 0.09 * sin(float(assimilation.queue[0].done) * 0.65), 0.66)
	if offering_dialog.visible:
		offering_dialog.refresh_studies()

func _offering_studies(items: Dictionary) -> Dictionary:
	var state := assimilation.summary()
	state.available = game.progress.heart.available_insight(game.progress)
	state.selected = Study.quote(items).knowledge if not items.is_empty() else 0
	state.blocked = Tx.pending_notice(game)
	return state

func _study_light(value: float, seconds: float, settle := false) -> void:
	if study_light != null:
		study_light.kill()
	study_light = create_tween()
	study_light.tween_method(_set_study_glow, study_glow, value, seconds)
	if settle:
		var rest := 0.18 if not assimilation.queue.is_empty() else 0.0
		study_light.tween_method(_set_study_glow, value, rest, 0.75)

func _set_study_glow(amount: float) -> void:
	study_glow = amount
	heart.reclaim_light(study_glow + reclaim_glow)

func clearing_tier() -> int:
	return game.progress.heart.clearing_bonus()

func expand(sector: int) -> bool:
	if not available_here() or clearing_tier() <= 0 or not plans.has(sector):
		return false
	var plan: Dictionary = plans[sector]
	var cost := funds.expansion_cost(plan, state.reclaimed_cells, clearing_tier())
	var result := Tx.run_gameplay(game, Tx.Scope.GARDEN, func() -> bool:
		return state.proposal(sector) == plan and funds.energy >= cost)
	if not Tx.committed(result.persistence) or result.value != true:
		return false
	var previous := state.enclosure_support()
	var outline := state.outline
	if not state.apply(plan):
		return false
	funds.energy -= cost
	barrier.begin_shape(outline, state.outline)
	barrier.update_shape(0.0)
	_update_rim(previous, 0.0)
	var root := MeshInstance3D.new()
	var root_plan := Roots.plan(state.roots[-1], heart.stage, state, network)
	network.append(root_plan)
	root.mesh = Roots.mesh(root_plan)
	var shader := ShaderMaterial.new()
	shader.shader = Bark
	shader.set_shader_parameter("growing_root", true)
	shader.set_shader_parameter("root_progress", 0.0)
	root.material_override = shader
	roots.add_child(root)
	construction.set_roots(network)
	plans.clear()
	var current := state.enclosure_support()
	reveal = create_tween()
	reveal.tween_method(func(t: float):
		shader.set_shader_parameter("root_progress", t)
		reclaim_glow = sin(t * PI)
		heart.reclaim_light(study_glow + reclaim_glow)
		material.set_shader_parameter("garden_reveal", t)
		forest.position_frontier(previous, current, t)
		barrier.update_shape(t), 0.0, 1.0, 2.45)
	reveal.finished.connect(func(): reveal = null)
	return true

func _required(kind: String) -> String:
	return {"bed": "plot_4", "study": "monster_studies", "archive": "seed_archive", "spring": "irrigation"}.get(kind, "")

func _build_refusal(kind: String, target: Vector2, yaw: float, moving: int) -> String:
	if not _may_place():
		return "Construction requires an active experimental solo Garden."
	if moving == 0:
		if not game.progress.heart.has(_required(kind)) or (kind == "spring" and not game.progress.heart.has("clearing_1")):
			return "Research the required capability at the Heart first."
		if kind == "bed":
			var cap := 3
			for entry: Dictionary in Catalog.DEFINITIONS:
				if entry.has("plots") and game.progress.heart.has(entry.id):
					cap = maxi(cap, int(entry.plots))
			if game.progress.plots.size() >= cap:
				return "All researched bed spaces are used."
	return construction.validate(kind, target, yaw, planar(game.players[game.HOST].pos), moving)

func _may_place() -> bool:
	if not game.players.has(game.HOST) or not game.multiplayer.is_server() or game.online_peer != null:
		return false
	var player: Dictionary = game.players[game.HOST]
	return not player.wild and not player.fallen and game.travel_kind.is_empty() and reveal == null and Tx.session_writable(game)

func place(kind: String, target: Vector2, yaw: float, moving: int = 0) -> bool:
	var refusal := _build_refusal(kind, target, yaw, moving)
	if not refusal.is_empty():
		game.tell(game.HOST, refusal)
		return false
	var slot: int = game.progress.plots.size()
	var transaction := Tx.run_gameplay(game, Tx.Scope.GARDEN, func() -> bool:
		if not _build_refusal(kind, target, yaw, moving).is_empty():
			return false
		if kind == "bed" and moving == 0:
			game.progress.plots.append(game.Progress.empty_plot())
		return true)
	if not Tx.committed(transaction.persistence) or transaction.value != true:
		return false
	var id := construction.commit(kind, target, yaw, planar(game.players[game.HOST].pos), moving)
	if id == 0:
		return false
	if kind == "bed":
		if moving == 0:
			bed_ids[slot] = id
		stage.plot_key = ""
	else:
		var station: String = {"study": "monster_studies", "archive": "seed_archive", "spring": "spring"}[kind]
		station_ids[station] = id
		_make_station(str(id), Build.CATALOG[kind].art, world(target), yaw)
	game.tell(game.HOST, Build.CATALOG[kind].name + (" relocated." if moving else " built."))
	return true

func _initialize_controls() -> void:
	offering_dialog = OfferView.new()
	offering_dialog.experimental_commit = contribute
	offering_dialog.study_summary = _offering_studies
	add_child(offering_dialog)
	development_dialog = AcceptDialog.new()
	development_dialog.title = "Experimental Garden Development"
	development_dialog.ok_button_text = "Back to Garden"
	development_dialog.exclusive = true
	add_child(development_dialog)
	development_dialog.visibility_changed.connect(func():
		if not development_dialog.visible: growth_preview.mesh = null)
	var controls := VBoxContainer.new()
	development_dialog.add_child(controls)
	var offering_button := Button.new()
	offering_button.text = "Heart offerings and studies"
	offering_button.pressed.connect(func():
		development_dialog.hide()
		open_offerings())
	controls.add_child(offering_button)
	frontier = OptionButton.new()
	frontier.item_selected.connect(func(_index): _preview_growth())
	controls.add_child(frontier)
	grow = Button.new()
	grow.text = "Confirm growth"
	grow.pressed.connect(func():
		if expand(int(frontier.get_selected_metadata())):
			development_dialog.hide()
			game.tell(game.HOST, "%d clearings reclaimed · %d energy held." % [state.revision, funds.energy]))
	controls.add_child(grow)
	review = Label.new()
	controls.add_child(review)
	construction_kind = OptionButton.new()
	for kind: String in Build.CATALOG:
		construction_kind.add_item(Build.CATALOG[kind].name)
		construction_kind.set_item_metadata(construction_kind.item_count - 1, kind)
	controls.add_child(construction_kind)
	var build_button := Button.new()
	build_button.text = "Start placement"
	build_button.pressed.connect(func():
		begin_placement(construction_kind.get_selected_metadata()))
	controls.add_child(build_button)
	building_picker = OptionButton.new()
	controls.add_child(building_picker)
	var relocate := Button.new()
	relocate.text = "Move selected structure"
	relocate.pressed.connect(func():
		var id := building_picker.get_selected_id()
		if construction.records.has(id):
			begin_placement(construction.records[id].kind, id))
	controls.add_child(relocate)

func open_development() -> void:
	if not available_here():
		game.tell(game.HOST, "Visit the Heart to manage Garden growth and construction.")
		return
	plans.clear()
	frontier.clear()
	frontier.add_item("Choose a frontier", -1)
	frontier.set_item_metadata(0, -1)
	grow.disabled = true
	for proposal: Dictionary in state.frontier_options():
		var cost := funds.expansion_cost(proposal, state.reclaimed_cells, clearing_tier())
		plans[proposal.sector] = proposal
		frontier.add_item("%s · %d energy" % [Garden.DIRECTIONS[proposal.sector], cost])
		frontier.set_item_metadata(frontier.item_count - 1, proposal.sector)
	frontier.select(0)
	review.text = "Research Reaching Roots to expand." if clearing_tier() <= 0 else "%d growth energy held." % funds.energy
	if plans.is_empty() and clearing_tier() > 0:
		review.text = "No frontier fits inside this generated Garden."
	building_picker.clear()
	for id: int in construction.records:
		building_picker.add_item("%s #%d" % [Build.CATALOG[construction.records[id].kind].name, id], id)
	if construction.records.is_empty():
		building_picker.add_item("No placed structures", 0)
	development_dialog.popup_centered(Vector2i(470, 360))

func _preview_growth() -> void:
	var sector: int = frontier.get_selected_metadata()
	var plan: Dictionary = plans.get(sector, {})
	grow.disabled = true
	growth_preview.mesh = null
	if not plan.is_empty():
		var cost := funds.expansion_cost(plan, state.reclaimed_cells, clearing_tier())
		review.text = "%d usable hexes · %d energy needed / %d held" % [plan.cells.size(), cost, funds.energy]
		grow.disabled = clearing_tier() <= 0 or funds.energy < cost
		var points: PackedVector2Array = plan.new_area
		var tris := Geometry2D.triangulate_polygon(points)
		if not tris.is_empty():
			var mesh_builder := SurfaceTool.new()
			mesh_builder.begin(Mesh.PRIMITIVE_TRIANGLES)
			for index in tris:
				mesh_builder.add_vertex(world(points[index]) + Vector3.UP * 0.065)
			growth_preview.mesh = mesh_builder.commit()

func begin_placement(kind: String, moving: int = 0) -> void:
	development_dialog.hide()
	build_kind = kind
	build_moving = moving
	build_yaw = float(construction.records[moving].yaw) if moving else 0.0
	game.tell(game.HOST, "Aim to build · Q/E rotate · Click to confirm · Esc cancels.")

func placement_input(event: InputEvent) -> bool:
	if build_kind.is_empty():
		return false
	if event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE:
		_cancel_placement()
		return true
	if event is InputEventKey and event.pressed and event.physical_keycode in [KEY_Q, KEY_E]:
		build_yaw += deg_to_rad(15.0) * (1 if event.physical_keycode == KEY_E else -1)
		_show_ghost()
		return true
	if event is InputEventMouseMotion or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed):
		var origin: Vector3 = stage.camera.project_ray_origin(event.position)
		var ray: Vector3 = stage.camera.project_ray_normal(event.position)
		build_target = planar(origin - ray * origin.y / ray.y)
		_show_ghost()
		if event is InputEventMouseButton and place(build_kind, build_target, build_yaw, build_moving):
			_cancel_placement()
		return true
	return false

func _show_ghost() -> void:
	if not build_target.is_finite():
		return
	if ghost == null:
		ghost = MeshInstance3D.new()
		ghost.mesh = Stations.build(Build.CATALOG[build_kind].art)
		add_child(ghost)
		var tint := StandardMaterial3D.new()
		tint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		ghost.material_override = tint
	ghost.position = world(build_target) + Vector3.UP * 0.05
	ghost.rotation.y = -build_yaw
	var refusal := _build_refusal(build_kind, build_target, build_yaw, build_moving)
	ghost.material_override.albedo_color = Color("#74e2b299") if refusal.is_empty() else Color("#ec8a78bb")
	game.tell(game.HOST, "Click to place · Q/E rotate · Esc cancels." if refusal.is_empty() else refusal)

func _cancel_placement() -> void:
	build_kind = ""
	build_target = Vector2.INF
	if ghost != null:
		ghost.queue_free()
		ghost = null
