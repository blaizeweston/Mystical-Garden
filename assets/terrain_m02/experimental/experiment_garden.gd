extends Node3D

const Participation = preload("res://expedition_participation.gd")

const PlayerLifecycle = preload("res://player_lifecycle.gd")

const Generator = preload("res://assets/terrain_m02/terrain_generator.gd")
const Layout = preload("res://assets/terrain_m02/terrain_feature_layout.gd")
const Art = preload("res://assets/terrain_m02/terrain_art_direction.gd")
const Enclosure = preload("res://assets/terrain_m02/terrain_enclosure.gd")
const Canopy = preload("res://garden_canopy.gd")
const Garden = preload("res://assets/terrain_m02/garden_expansion.gd")
const Forest = preload("res://assets/terrain_m02/garden_forest_barrier.gd")
const Heart = preload("res://assets/terrain_m02/terrain_heart_preview.gd")
const Roots = preload("res://assets/terrain_m02/garden_heart_roots.gd")
const Build = preload("res://assets/terrain_m02/garden_construction.gd")
const Surface = preload("res://assets/terrain_m02/experimental/experiment_terrain_view.gd")
const Stations = preload("res://assets/terrain_m02/garden_station_art.gd")
const Offerings = preload("res://assets/terrain_m02/garden_offerings.gd")
const OfferView = preload("res://assets/terrain_m02/garden_offerings_view.gd")
const Journal = preload("res://diagnostic_journal.gd")
const Tx = preload("res://game_transaction.gd")
const Catalog = preload("res://heart_catalog.gd")
const Shapes = preload("res://assets/terrain_m02/terrain_feature_geometry.gd")
const GateMesh = preload("res://assets/terrain_m02/wilds_massing_mesh.gd")
const Bark = preload("res://assets/terrain_m02/heart_bark.gdshader")
const SavedGarden = preload("res://garden_development_state.gd")
const Spacing := SavedGarden.SPACING
const Radius := SavedGarden.RADIUS
const Seed := SavedGarden.SEED
const STATIONS := {"altar": "altar", "study": "monster_studies", "archive": "seed_archive"}

var game: Node
var stage: Node3D
var state: Garden
var water_sources := preload("res://garden_water.gd").new()
var barrier: Forest
var forest: Canopy
var _features: Node3D
var _shown_props: Array = []
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
var reclaim_glow := 0.0
var offering_dialog: OfferView
var development_dialog: AcceptDialog
var frontier: OptionButton
var grow: Button
var review: Label
var plans := {}
var construction_kind: OptionButton
var build_button: Button
var building_picker: OptionButton
var ghost: MeshInstance3D
var build_kind := ""
var build_moving := 0
var build_target := Vector2.INF
var build_yaw := 0.0
var reveal: Tween
var growth_preview: MeshInstance3D
var layout_revision := 0
const RECLAIM_SECONDS := 2.45
var remote_revision := -1
var geometry := {}
var remote_development := {}
var development_controls: VBoxContainer
var guest_review: Label

func configure(world_node: Node, presentation: Node3D) -> void:
	game = world_node
	stage = presentation
	stage.experimental_garden = self
	stage.visual_field = preload("res://battlefield.gd").new()
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
	protections.append(Shapes.disk("altar", "station", Vector2(-3.5, -2), 0.88))
	# Keep authored interaction landmarks usable on the generated Garden floor.
	# This reserves geometry only; research and construction still authorize services.
	for point: Dictionary in preload("res://garden_interaction_catalog.gd").POINTS:
		var reserved_point := Shapes.disk("interaction_"+point.id,"interaction",planar(point.position),0.65)
		reserved_point.requires_access=false # Reserve scenery, without an invisible actor collider.
		reserved_point.blocks_movement=false
		reserved_point.blocks_construction=point.get("blocks_construction",true)
		protections.append(reserved_point)
	for id: String in stage.HEART_STATIONS:
		var reserved_station := Shapes.disk("native_station_"+id,"station",planar(stage.HEART_STATIONS[id]),0.65)
		reserved_station.requires_access=false
		reserved_station.blocks_movement=(id=="living_archive")
		protections.append(reserved_station)
	var cleared_beds: Array=protections.duplicate()
	for index in range(3,mini(game.progress.plots.size(),stage.PLOTS.size())):
		var owned_bed := Shapes.disk("owned_bed_%d"%index,"plot",planar(stage.PLOTS[index]),1.3)
		owned_bed.blocks_movement=false # The construction record supplies its actual footprint.
		cleared_beds.append(owned_bed)
		protections.append(owned_bed)
	for row: Dictionary in cleared_beds:
		layout.rocks = layout.rocks.filter(func(rock): return not Shapes.in_any([rock], row.center, row.radius + 0.55))
		layout.plants = layout.plants.filter(func(plant): return plant.center.distance_to(row.center) > row.radius + 0.65)
	layout = Art.placements(Enclosure.build(layout, cells, Spacing, Seed, true), 0)
	state = Garden.new(cells, layout, Spacing, Seed, Radius, protections)
	state.release_structure_landmarks()
	barrier = Forest.new()
	add_child(barrier)
	barrier.bind(state, false) # Movement boundary only; complete trees present the edge.
	construction = Build.new(barrier)
	adopt_recorded_beds()
	station_ids.altar = construction.adopt_owned("altar", planar(stage.ALTAR))
	var profile := Art.profile(0)
	material = Surface.material(cells, layout, Seed, Radius, Spacing)
	material.set_shader_parameter("art_mode", 1)
	material.set_shader_parameter("garden_frontier", true)
	material.set_shader_parameter("scenic_cover", Vector3(0.10, 0.89, 0.01))
	material.set_shader_parameter("botanical_ground", profile.ground)
	material.set_shader_parameter("botanical_water", profile.water)
	Surface.plane(self, material, 92.0)
	_features = Surface.Features.new()
	add_child(_features)
	_refresh_revealed_props()
	forest = Canopy.new()
	add_child(forest)
	forest.configure(barrier.visible_outline)
	base_rim = state.enclosure_support()
	_update_rim()
	heart = Heart.new()
	heart.sculpt_only = true
	add_child(heart)
	stage.heart_tree = heart
	stage.heart_size = 1.0 # Imported sculpt uses its authored scale during growth cues.
	heart.set_sculpt(true)
	stage.marker(Vector3.UP * 2.2, "HEART", heart)
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
	_initialize_controls()
	if not game.progress.garden_development.is_empty():
		_restore_development(game.progress.garden_development)
	_refresh_structure_views()
	_refresh_root_views()
	barrier.begin_shape(state.outline, state.outline)
	barrier.update_shape(1.0)
	_update_rim()
	if game.progress.garden_development_error.is_empty():
		game.progress.garden_development = _capture_development()


func show_heart_stage(index: int) -> void:
	var id := "living_archive"
	if not stage.heart_stations.has(id):
		stage.heart_stations[id]=preload("res://heart_visuals.gd").station(stage,id,stage.HEART_STATIONS[id])
	stage.heart_stations[id].visible=stage.heart_unlocked.has(id)
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
	if id=="living_archive":return stage.HEART_STATIONS[id]
	return world(construction.records[station_ids[id]].at) if station_ids.has(id) else Vector3.INF

func bed_position(index: int) -> Vector3:
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
	return world(barrier.move(planar(from), planar(to - from)))

func _make_station(id: String, art: String, world_position: Vector3, yaw: float) -> void:
	var instance := structure_nodes.get(id) as MeshInstance3D
	if instance == null:
		instance = MeshInstance3D.new()
		instance.mesh = Stations.build(art)
		var colors := StandardMaterial3D.new()
		colors.vertex_color_use_as_albedo = true
		instance.material_override = colors
		add_child(instance)
		structure_nodes[id] = instance
	instance.position = world_position
	instance.rotation.y = -yaw

func _refresh_revealed_props() -> void:
	# Covered scenery keeps its gameplay footprint in state.layout/occupied.
	# Only its presentation is filtered; new props appear as expansion exposes them.
	var visible_layout: Dictionary = state.layout.duplicate()
	var outline: PackedVector2Array = barrier.visible_outline
	visible_layout.plants = state.layout.plants.filter(func(plant): return Geometry2D.is_point_in_polygon(plant.center, outline))
	visible_layout.rocks = state.layout.rocks.filter(func(rock): return Geometry2D.is_point_in_polygon(rock.center, outline))
	var identities: Array = visible_layout.plants.map(func(plant): return plant.id)
	identities.append_array(visible_layout.rocks.map(func(rock): return rock.id))
	if identities == _shown_props:
		return
	_shown_props = identities
	_features.rebuild(visible_layout, Art.profile(0), 0)


func _update_rim(progress: float = 1.0) -> void:
	var packed := PackedFloat32Array()
	for i in barrier.starts.size():
		packed.append_array([barrier.starts[i].length(), barrier.finishes[i].length(), base_rim[i], 0.0])
	var image := Image.create_from_data(barrier.starts.size(), 1, false, Image.FORMAT_RGBAF, packed.to_byte_array())
	var perimeter := ImageTexture.create_from_image(image)
	material.set_shader_parameter("garden_perimeter", perimeter)
	material.set_shader_parameter("garden_reveal", progress)
	forest.set_boundary(image, progress)
	_refresh_revealed_props()

func available_here() -> bool:
	return _may_place() and game.at_heart(game.players[game.HOST])

func can_view_development() -> bool:
	if game.multiplayer.is_server():
		return available_here()
	return game.network_session.role() == "Guest" and remote_revision >= 0 and game.at_heart(game.players.get(game.local_player_id(), {}))

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
	funds.garden_revision = layout_revision
	funds.inventory_revision += 1

func _shared_free(player: Dictionary, part: int) -> int:
	var others: int = game.LoadoutMaterials.shared_free(game, part, player)
	var personal: int = game.seed_reserve(player).parts[part]
	var reserved: int = maxi(0, game.LoadoutMaterials.demand(player, part) - personal)
	return maxi(0, others - reserved)

func contribute(quote: Dictionary) -> bool:
	if not available_here() or quote.is_empty() or not quote.get("items") is Dictionary:
		return false
	var accepted := _commit_development(func() -> bool:
		if quote.get("garden_revision", -1) != layout_revision or funds.quote(quote.items) != quote:
			return false
		layout_revision += 1
		funds.energy += int(quote.energy)
		return true, func() -> bool:
		var player: Dictionary = game.players[game.HOST]
		for id: String in quote.items:
			if _shared_free(player, funds.items[id].legacy_part) < int(quote.items[id]):
				return false
		for id: String in quote.items:
			game.progress.add_parts(funds.items[id].legacy_part, -int(quote.items[id]))
		game.progress.knowledge += int(quote.knowledge)
		return true)
	if accepted:
		Journal.event("interaction", "heart_contribution", {"parts": quote.items,
			"growth": quote.energy, "knowledge": quote.knowledge})
	_refresh_parts()
	return accepted

func clearing_tier() -> int:
	return game.progress.heart.clearing_bonus()

func expand(sector: int) -> bool:
	if not available_here() or clearing_tier() <= 0 or not plans.has(sector):
		return false
	var plan: Dictionary = plans[sector]
	var cost := funds.expansion_cost(plan, state.reclaimed_cells, clearing_tier())
	var outline := state.outline
	var number := state.revision + 1
	var accepted := _commit_development(func() -> bool:
		if funds.energy < cost or not state.apply(plan):
			return false
		funds.energy -= cost
		layout_revision += 1
		network.append(Roots.plan(state.roots[-1], heart.stage, state, network))
		return true, preload("res://garden_growth_state.gd").record_expansion.bind(game.progress, number, Garden.DIRECTIONS[sector]))
	if not accepted:
		return false
	Journal.event("interaction", "garden_expanded", {"sector": sector, "revision": state.revision, "energy_spent": cost})
	plans.clear()
	_animate_expansion(outline, _add_root(network[-1]))
	return true

func expansion_route(number: int) -> PackedVector3Array:
	if number < 1 or number > network.size():
		return PackedVector3Array()
	return PackedVector3Array(network[number - 1].main)

func _animate_expansion(previous_outline: PackedVector2Array, root: MeshInstance3D) -> void:
	barrier.begin_shape(previous_outline, state.outline)
	barrier.update_shape(0.0)
	_update_rim(0.0)
	var shader := root.material_override as ShaderMaterial
	shader.set_shader_parameter("growing_root", true)
	shader.set_shader_parameter("root_progress", 0.0)
	reveal = create_tween()
	reveal.tween_method(func(t: float):
		shader.set_shader_parameter("root_progress", t)
		reclaim_glow = sin(t * PI)
		heart.reclaim_light(reclaim_glow)
		material.set_shader_parameter("garden_reveal", t)
		forest.set_reveal(t)
		barrier.update_shape(t)
		_refresh_revealed_props(), 0.0, 1.0, RECLAIM_SECONDS)
	reveal.finished.connect(func(): reveal = null)

func snapshot() -> Dictionary:
	if geometry.get("revision", -1) != layout_revision:
		var buildings: Array = []
		for id: int in construction.records:
			var record: Dictionary = construction.records[id]
			buildings.append([id, record.kind, record.at, record.yaw, bed_ids.find_key(id)])
		geometry = {"revision": layout_revision, "outline": state.outline, "owned": state.owned.duplicate(),
			"growth": state.expansion_history.duplicate(), "roots": network.duplicate(true), "buildings": buildings}
	var tier := clearing_tier()
	if geometry.get("tier", -1) != tier:
		geometry.tier = tier
		geometry.frontiers = []
		if tier > 0:
			for proposal in state.frontier_options():
				geometry.frontiers.append([Garden.DIRECTIONS[proposal.sector], funds.expansion_cost(proposal, state.reclaimed_cells, tier)])
	return {"layout": geometry, "energy": funds.energy}

func receive_snapshot(snapshot_data: Dictionary) -> void:
	if game.multiplayer.is_server():
		return
	var layout: Dictionary = snapshot_data.get("layout", {})
	var incoming: int = layout.get("revision", -1)
	if incoming < remote_revision or not layout.get("outline") is PackedVector2Array:
		return
	if incoming != remote_revision:
		_apply_layout(layout)
		remote_revision = incoming
	remote_development = snapshot_data
	if development_dialog.visible:
		_refresh_guest_review()

func _apply_layout(layout: Dictionary) -> void:
	var previous_outline := state.outline
	var live_expansion: bool = remote_revision >= 0 and layout.growth.size() == state.revision + 1
	var growth_changed: bool = remote_revision < 0 or layout.growth.size() != state.revision
	state.outline = layout.outline
	state.owned = layout.owned.duplicate()
	state.expansion_history.assign(layout.growth)
	state.revision = state.expansion_history.size()
	if growth_changed:
		if reveal != null:
			reveal.kill()
			reveal = null
			roots.get_child(-1).material_override.set_shader_parameter("root_progress", 1.0)
			reclaim_glow = 0.0
			heart.reclaim_light(reclaim_glow)
		network.assign(layout.roots.duplicate(true))
		if live_expansion:
			_animate_expansion(previous_outline, _add_root(network[-1]))
		else:
			barrier.begin_shape(previous_outline, state.outline)
			barrier.update_shape(1.0)
			_update_rim()
			_refresh_root_views()
	_restore_buildings(layout.buildings)
	_refresh_structure_views()
	stage.plot_key = ""

func _refresh_guest_review() -> void:
	var lines := PackedStringArray(["The host manages Garden development.",
		"Growth Energy %d" % int(remote_development.get("energy", 0))])
	for frontier_data: Array in remote_development.get("layout", {}).get("frontiers", []):
		lines.append("%s frontier · %d energy" % frontier_data)
	guest_review.text = "\n".join(lines)

func _required(kind: String) -> String:
	return {"bed": "plot_4", "study": "monster_studies", "archive": "seed_archive"}.get(kind, "")

func _placement_refusal(kind: String, moving: int) -> String:
	if not _may_place():
		return "The host manages construction in the Garden."
	if not Build.CATALOG.has(kind):
		return "Choose a Garden structure."
	if moving != 0:
		if not construction.records.has(moving) or construction.records[moving].kind != kind:
			return "Select a placed structure to move."
		return ""
	if not Build.CATALOG[kind].buildable:
		return "The starting Garden Altar can only be moved."
	var research := _required(kind)
	if not game.progress.heart.has(research):
		return "Research %s at the Heart first." % Catalog.get_node(research).name
	if kind == "bed":
		var cap := 3
		for entry: Dictionary in Catalog.DEFINITIONS:
			if entry.has("plots") and game.progress.heart.has(entry.id):
				cap = maxi(cap, int(entry.plots))
		if game.progress.plots.size() >= cap:
			return "All researched bed spaces are used."
	return ""

func _build_refusal(kind: String, target: Vector2, yaw: float, moving: int) -> String:
	var refusal := _placement_refusal(kind, moving)
	if not refusal.is_empty():
		return refusal
	return construction.validate(kind, target, yaw, planar(game.players[game.HOST].pos), moving)

func _may_place() -> bool:
	if not game.players.has(game.HOST) or not game.multiplayer.is_server() or not game.slot_claimed:
		return false
	var player: Dictionary = game.players[game.HOST]
	return not Participation.is_wild(player) and not PlayerLifecycle.fallen(player) and game.participation.travel_kind().is_empty() and reveal == null and game.persistence_session.can_simulate() and game.progress.garden_development_error.is_empty()

func place(kind: String, target: Vector2, yaw: float, moving: int = 0) -> bool:
	var refusal := _build_refusal(kind, target, yaw, moving)
	if not refusal.is_empty():
		game.tell(game.HOST, refusal)
		return false
	var slot: int = game.progress.plots.size()
	var accepted := _commit_development(func() -> bool:
		var id := construction.commit(kind, target, yaw, planar(game.players[game.HOST].pos), moving)
		if id == 0:
			return false
		layout_revision += 1
		if kind == "bed":
			if moving == 0: bed_ids[slot] = id
		else:
			station_ids[STATIONS[kind]] = id
		return true, func() -> bool:
		if kind == "bed" and moving == 0:
			game.progress.plots.append(game.Progress.empty_plot())
		return true, int(kind == "bed" and moving == 0))
	if not accepted:
		return false
	_refresh_structure_views()
	stage.plot_key = ""
	Journal.event("interaction", "garden_structure_placed", {"kind": kind, "moving": moving,
		"position": target, "yaw": yaw, "revision": layout_revision})
	game.tell(game.HOST, Build.CATALOG[kind].name + (" relocated." if moving else " built."))
	return true

func _initialize_controls() -> void:
	offering_dialog = OfferView.new()
	offering_dialog.experimental_commit = contribute
	add_child(offering_dialog)
	development_dialog = AcceptDialog.new()
	development_dialog.title = "Garden Development"
	development_dialog.ok_button_text = "Back to Garden"
	development_dialog.exclusive = true
	add_child(development_dialog)
	development_dialog.visibility_changed.connect(func():
		if not development_dialog.visible: growth_preview.mesh = null)
	var controls := VBoxContainer.new()
	development_controls = controls
	development_dialog.add_child(controls)
	guest_review = Label.new()
	guest_review.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	development_dialog.add_child(guest_review)
	guest_review.hide()
	var offering_button := Button.new()
	offering_button.text = "Heart offerings"
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
	controls.add_child(construction_kind)
	construction_kind.item_selected.connect(func(index: int): build_button.disabled = index <= 0)
	build_button = Button.new()
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

func _refresh_build_choices() -> void:
	var previous: Variant = construction_kind.get_selected_metadata() if construction_kind.selected >= 0 else null
	construction_kind.clear()
	construction_kind.add_item("Choose an unlocked structure")
	construction_kind.set_item_metadata(0, "")
	var selected := 0
	for kind: String in Build.CATALOG:
		if not Build.CATALOG[kind].buildable: continue
		var refusal := _placement_refusal(kind, 0)
		construction_kind.add_item(Build.CATALOG[kind].name)
		var index := construction_kind.item_count - 1
		construction_kind.set_item_metadata(index, kind)
		construction_kind.set_item_disabled(index, not refusal.is_empty())
		construction_kind.set_item_tooltip(index, refusal)
		if refusal.is_empty() and (selected == 0 or previous == kind):
			selected = index
	construction_kind.select(selected)
	build_button.disabled = selected == 0

func open_development() -> void:
	if not game.multiplayer.is_server():
		if can_view_development():
			development_controls.hide()
			guest_review.show()
			_refresh_guest_review()
			development_dialog.popup_centered(Vector2i(470, 360))
		return
	if not available_here():
		game.tell(game.HOST, "Visit the Heart to manage Garden growth and construction.")
		return
	_cancel_placement()
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
	_refresh_build_choices()
	building_picker.clear()
	for id: int in construction.records:
		building_picker.add_item(_building_name(id), id)
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
	var refusal := _placement_refusal(kind, moving)
	if not refusal.is_empty():
		game.tell(game.HOST, refusal)
		return
	development_dialog.hide()
	_cancel_placement()
	build_kind = kind
	build_moving = moving
	build_yaw = float(construction.records[moving].yaw) if moving else 0.0
	game.tell(game.HOST, "Aim to build · Q/E rotate · Click to place · Esc or right-click cancels.")

func cancel_placement_input(event: InputEvent) -> bool:
	if build_kind.is_empty():
		return false
	var right_click: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT
	if not event.is_action_pressed("session_menu") and not right_click:
		return false
	_cancel_placement()
	game.tell(game.HOST, "Placement cancelled.")
	return true

func placement_input(event: InputEvent) -> bool:
	if build_kind.is_empty():
		return false
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
	var instruction := "Click to place · Q/E rotate" if refusal.is_empty() else refusal
	game.tell(game.HOST, instruction + " · Esc or right-click cancels.")

func _cancel_placement() -> void:
	build_kind = ""
	build_moving = 0
	build_target = Vector2.INF
	build_yaw = 0.0
	if ghost != null:
		ghost.queue_free()
		ghost = null

func adopt_recorded_beds() -> void:
	# Existing crop records already own these beds. Preserve their crops and
	# investments when entering the generated Garden; never buy them twice.
	for index in range(mini(game.progress.plots.size(),stage.PLOTS.size())):
		if bed_ids.has(index):continue
		bed_ids[index]=construction.adopt_owned("bed", planar(stage.PLOTS[index]))
		layout_revision+=1
	if station_ids.has("altar"):
		game.progress.garden_development = _capture_development()

func _building_name(id: int) -> String:
	var kind: String = construction.records[id].kind
	if kind == "bed":
		var index: int = bed_ids.find_key(id)
		return ("Starting bed %d" if index < 3 else "Cultivation bed %d") % (index + 1)
	return Build.CATALOG[kind].name

func _capture_development() -> Dictionary:
	var buildings: Array = []
	for id: int in construction.records:
		var record: Dictionary = construction.records[id]
		buildings.append([id, record.kind, record.at, record.yaw, bed_ids.find_key(id)])
	return {"version": SavedGarden.VERSION, "seed": Seed, "radius": Radius, "spacing": Spacing,
		"layout_revision": layout_revision, "revision": state.revision, "outline": state.outline.duplicate(),
		"owned": state.owned.duplicate(), "growth": state.expansion_history.duplicate(),
		"reclaimed_cells": state.reclaimed_cells, "root_paths": state.roots.duplicate(true),
		"roots": network.duplicate(true), "buildings": buildings, "next_id": construction.next_id,
		"energy": funds.energy}

func _restore_buildings(buildings: Array) -> void:
	construction.records.clear()
	construction.next_id = 1
	bed_ids.clear()
	station_ids.clear()
	for building: Array in buildings:
		var id: int = building[0]
		var kind: String = building[1]
		construction.records[id] = {"id": id, "kind": kind, "at": building[2], "yaw": building[3],
			"footprint": construction.footprint(kind, building[2], building[3])}
		construction.next_id = maxi(construction.next_id, id + 1)
		if kind == "bed":
			bed_ids[building[4]] = id
		else:
			station_ids[STATIONS[kind]] = id
	construction._sync_obstacles()
	construction._revision = -1

func _restore_development(saved: Dictionary) -> void:
	# Only validated save projections or our own synchronous savepoints reach here.
	state.outline = saved.outline.duplicate()
	state.owned = saved.owned.duplicate()
	state.expansion_history.assign(saved.growth)
	state.revision = saved.revision
	state.reclaimed_cells = saved.reclaimed_cells
	state.roots.assign(saved.root_paths.duplicate(true))
	network.assign(saved.roots.duplicate(true))
	_restore_buildings(saved.buildings)
	construction.next_id = saved.next_id
	state.refresh_owned_cells()
	layout_revision = saved.layout_revision
	funds.energy = saved.energy
	geometry.clear()

func _commit_development(change: Callable, progress_change := Callable(), added_beds := 0) -> bool:
	# Prepare synchronously, then restore live owners BEFORE attempting durability.
	# No node, UI, network or animation changes occur until the save is committed.
	var before := _capture_development()
	var changed: bool = change.call()
	var after := _capture_development()
	_restore_development(before)
	if not changed or not SavedGarden.refusal(after, game.progress.plots.size() + added_beds).is_empty():
		return false
	var result := Tx.run_gameplay(game, Tx.Scope.GARDEN, func() -> bool:
		if progress_change.is_valid() and progress_change.call() != true:
			return false
		game.progress.garden_development = after.duplicate(true)
		return true)
	var accepted: bool = (result.completed or Tx.committed(result.persistence)) and result.value == true
	if accepted:
		_restore_development(after)
	else:
		Journal.event("persistence", "garden_development_save_refused", {"revision": before.layout_revision})
	return accepted

func _refresh_structure_views() -> void:
	var present := {}
	for station: String in station_ids:
		var id: int = station_ids[station]
		var record: Dictionary = construction.records[id]
		present[str(id)] = true
		_make_station(str(id), Build.CATALOG[record.kind].art, world(record.at), record.yaw)
	for id: String in structure_nodes.keys():
		if not present.has(id):
			structure_nodes[id].free()
			structure_nodes.erase(id)

func _refresh_root_views() -> void:
	for child in roots.get_children():
		child.free()
	for plan: Dictionary in network:
		_add_root(plan)

func _add_root(plan: Dictionary) -> MeshInstance3D:
	var root := MeshInstance3D.new()
	root.mesh = Roots.mesh(plan)
	var shader := ShaderMaterial.new()
	shader.shader = Bark
	root.material_override = shader
	roots.add_child(root)
	return root
