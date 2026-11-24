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
var infrastructure := preload("res://garden_infrastructure_view.gd").new()
var remote_irrigation := preload("res://garden_irrigation.gd").new()
var coverage_preview := MeshInstance3D.new()
var placed_info := Label.new()
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
var inventory_revision := -1
var build_revision := -1
var menu_revision := -1
var sanctuary_mode := OptionButton.new()
var inventory_info := Label.new()
var inventory_picker: OptionButton
var management_tabs: TabContainer
var store_button: Button
var dismantle_button: Button
var refund_dialog: ConfirmationDialog
var refund_request := {}
var preview_viewport: SubViewport
var preview_model: MeshInstance3D
var construct_info: Label
var construct_button: Button
var geometry := {}
var remote_development := {}
var development_controls: ScrollContainer
var guest_scroll: ScrollContainer
var last_review_revision := -1
var funds_on_review := -1
var guest_review: Label

var habitat_beds := 3
var legacy_clearing := false

func _generate_habitat(inventory: Dictionary) -> void:
	habitat_beds = inventory.get("legacy_prop_beds",3)
	legacy_clearing = inventory.legacy_clearing
	var starting_margin := 0.0 if legacy_clearing else SavedGarden.STARTING_MARGIN_M
	var cells := Generator.generate(Seed, Radius, preload("res://assets/terrain_m02/garden_clearing.tres"), Surface.Catalog)
	var layout := Layout.build(cells, Spacing, Radius, Seed, true, true)
	# The inner habitat (gate, water, rocks and trees) keeps its original seed and extent.
	var outer := Generator.generate(Seed, SavedGarden.FRONTIER_RADIUS, preload("res://assets/terrain_m02/garden_clearing.tres"), Surface.Catalog)
	outer.merge(cells,true)
	cells = outer
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
	for index in range(3,habitat_beds):
		var owned_bed := Shapes.disk("owned_bed_%d"%index,"plot",planar(stage.PLOTS[index]),1.3)
		owned_bed.blocks_movement=false # The construction record supplies its actual footprint.
		cleared_beds.append(owned_bed)
		protections.append(owned_bed)
	for row: Dictionary in cleared_beds:
		layout.rocks = layout.rocks.filter(func(rock): return not Shapes.in_any([rock], row.center, row.radius + 0.55))
		layout.plants = layout.plants.filter(func(plant): return plant.center.distance_to(row.center) > row.radius + 0.65)
	layout = Art.placements(Enclosure.build(layout, cells, Spacing, Seed, true), 0)
	state = Garden.new(cells, layout, Spacing, Seed, SavedGarden.FRONTIER_RADIUS, protections, starting_margin)
	state.release_structure_landmarks()

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
	_generate_habitat(game.progress.structures)
	barrier = Forest.new()
	add_child(barrier)
	barrier.bind(state, false) # Movement boundary only; complete trees present the edge.
	construction = Build.new(barrier)
	_project_inventory(game.progress.structures)
	var profile := Art.profile(0)
	material = Surface.material(state.terrain, state.layout, Seed, SavedGarden.FRONTIER_RADIUS, Spacing)
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
	add_child(infrastructure)
	add_child(coverage_preview)
	var coverage_tint := StandardMaterial3D.new()
	coverage_tint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	coverage_tint.no_depth_test = true
	coverage_preview.material_override = coverage_tint
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
		_refresh_connections()

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
	_refresh_connections()
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
	sync_inventory()
	var revision := layout_revision + inventory_revision
	if geometry.get("revision", -1) != revision:
		geometry = {"revision":revision,"outline":state.outline,"owned":state.owned.duplicate(),
			"growth":state.expansion_history.duplicate(),"roots":network.duplicate(true),
			"inventory":game.progress.structures.duplicate(true),"cultivation_research":game.progress.heart.unlocked.duplicate()}

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
	if development_dialog.visible and (incoming != last_review_revision or funds_on_review != snapshot_data.get("energy",-1)):
		_refresh_guest_review()

func _apply_layout(layout: Dictionary) -> void:
	var inventory: Dictionary = layout.inventory
	if habitat_beds != int(inventory.get("legacy_prop_beds",3)) or legacy_clearing != bool(inventory.legacy_clearing):
		_generate_habitat(inventory)
		barrier.bind(state,false)
		construction._revision = -1
		base_rim = state.enclosure_support()
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
	_refresh_revealed_props()
	_project_inventory(inventory,layout.get("cultivation_research",[]))
	_refresh_structure_views()
	stage.plot_key = ""

func _refresh_guest_review() -> void:
	last_review_revision = remote_revision
	funds_on_review = remote_development.get("energy",-1)
	var lines := PackedStringArray(["The host manages Garden development.",
		"Growth Energy %d" % int(remote_development.get("energy", 0))])
	for frontier_data: Array in remote_development.get("layout", {}).get("frontiers", []):
		lines.append("%s frontier · %d energy" % frontier_data)
	for stored: bool in [true,false]:
		lines.append("Inventory" if stored else "Placed")
		for id: int in remote_development.get("layout",{}).get("inventory",{}).get("instances",{}):
			var entry: Dictionary = remote_development.layout.inventory.instances[id]
			if entry.placed != stored:
				lines.append("%s #%d" % [Build.CATALOG[entry.kind].name,id])
				if entry.placed and Build.CATALOG[entry.kind].has("effect"): lines.append(_coverage_info(entry.kind,entry.at,entry))
	guest_review.text = "\n".join(lines)

func _placement_refusal(kind: String, id: int) -> String:
	if not _may_place(): return "The host manages construction in the Garden."
	var entry: Dictionary = game.progress.structures.instances.get(id,{})
	if not Build.CATALOG.has(kind) or entry.get("kind","") != kind: return "Choose an owned structure from Inventory or Placed."
	return ""

func _build_refusal(kind: String, target: Vector2, yaw: float, id: int) -> String:
	var refusal := _placement_refusal(kind,id)
	if not refusal.is_empty(): return refusal
	var moving := id if construction.records.has(id) else 0
	if target.is_finite() and is_finite(yaw):
		var footprint := construction.footprint(kind,target,yaw)
		for peer: int in game.players:
			var actor: Dictionary = game.players[peer]
			if peer!=game.HOST and not Participation.is_wild(actor) and Shapes.in_any([footprint],planar(actor.pos),Build.WALK_RADIUS):
				return "Another player is standing in this footprint."
	return construction.validate(kind,target,yaw,planar(game.players[game.HOST].pos),moving)

func _may_place() -> bool:
	if not game.players.has(game.HOST) or not game.multiplayer.is_server() or not game.slot_claimed:
		return false
	var player: Dictionary = game.players[game.HOST]
	return not Participation.is_wild(player) and not PlayerLifecycle.fallen(player) and game.participation.travel_kind().is_empty() and reveal == null and game.persistence_session.can_simulate() and game.progress.garden_development_error.is_empty()

func sync_inventory() -> void:
	if not game.multiplayer.is_server() or not game.persistence_session.can_simulate(): return
	if inventory_revision == int(game.progress.structures.revision): return
	_project_inventory(game.progress.structures)
	_refresh_structure_views()
	stage.plot_key = ""

func _project_inventory(inventory: Dictionary, remote_research: Array = []) -> void:
	construction.records.clear()
	bed_ids.clear()
	station_ids.clear()
	for id: int in inventory.instances:
		var entry: Dictionary = inventory.instances[id]
		if not entry.placed: continue
		construction.records[id] = {"id":id,"kind":entry.kind,"at":entry.at,"yaw":entry.yaw,
			"footprint":construction.footprint(entry.kind,entry.at,entry.yaw)}
		if entry.kind=="bed": bed_ids[entry.slot]=id
		elif STATIONS.has(entry.kind): station_ids[STATIONS[entry.kind]]=id
	construction._sync_obstacles()
	if game.multiplayer.is_server(): game.progress.irrigation.resolve(inventory,game.progress.heart.unlocked)
	else: remote_irrigation.resolve(inventory,remote_research)
	inventory_revision = inventory.revision

func _commit_structure(expected: int, change: Callable) -> bool:
	if not _may_place() or expected!=int(game.progress.structures.revision) or not game.persistence_session.can_write(): return false
	var result: Dictionary = game.apply_cultivation_change(change)
	if not Tx.committed(result.persistence) and not result.completed: return false
	if result.value != true: return false
	funds.energy = game.progress.garden_development.energy
	_project_inventory(game.progress.structures)
	_refresh_structure_views()
	stage.plot_key = ""
	Journal.event("interaction","garden_construction",{"revision":inventory_revision,"operation":change.get_method()})
	return true

func construct(kind: String, expected: int) -> bool:
	if not available_here() or not Build.CATALOG.has(kind): return false
	var definition: Dictionary = Build.CATALOG[kind]
	if not definition.get("repeatable",false) or not game.progress.heart.has(definition.research): return false
	var cost: Dictionary = definition.cost
	if not game.Progress.Structures.valid_payment(cost) or not _affordable(cost): return false
	return _commit_structure(expected,func():
		_apply_payment(cost,-1)
		game.Progress.Structures.add(game.progress.structures,kind,cost)
		return true)

func _affordable(cost: Dictionary) -> bool:
	if game.progress.garden_development.get("energy",0) < cost.energy: return false
	for item: String in cost.materials:
		var part: int = game.Items.get_item(item).legacy_part
		if _shared_free(game.players[game.HOST],part) < cost.materials[item]: return false
	return true

func _apply_payment(cost: Dictionary, direction: int) -> void:
	game.progress.garden_development.energy += direction * int(cost.energy)
	for item: String in cost.materials:
		game.progress.add_parts(game.Items.get_item(item).legacy_part,direction * int(cost.materials[item]))

func _price(cost: Dictionary) -> String:
	var parts := PackedStringArray(["%d Growth Energy" % cost.energy])
	for item: String in cost.materials:
		parts.append("%d %s" % [cost.materials[item],game.Items.get_item(item).name])
	return ", ".join(parts)

func place(kind: String, target: Vector2, yaw: float, id: int = 0, expected := -1) -> bool:
	sync_inventory()
	var refusal := _build_refusal(kind,target,yaw,id)
	if not refusal.is_empty():
		if game.multiplayer.is_server(): game.tell(game.HOST,refusal)
		return false
	var entry: Dictionary = game.progress.structures.instances[id]
	if entry.placed and entry.at == target and entry.yaw == yaw: return false
	return _commit_structure(expected if expected>=0 else inventory_revision,func():
		var slot: int = entry.slot
		if kind=="bed" and slot==-1:
			slot = game.progress.plots.size()
			game.progress.plots.append(game.Progress.empty_plot())
		game.Progress.Structures.place(entry,target,yaw,slot)
		game.progress.structures.revision += 1
		return true)

func retire_structure(id: int, expected: int, deconstruct: bool) -> bool:
	if not available_here(): return false
	var entry: Dictionary = game.progress.structures.instances.get(id,{})
	if entry.is_empty() or (not entry.placed and not deconstruct): return false
	if entry.slot>=0 and game.progress.plots[entry.slot].species>=0:
		game.tell(game.HOST,"Harvest this crop before storing or deconstructing its bed.")
		return false
	if deconstruct and entry.paid.is_empty(): return false
	return _commit_structure(expected,func():
		if deconstruct:
			_apply_payment(entry.paid,1)
			game.progress.structures.instances.erase(id)
		else: entry.placed=false
		game.progress.structures.revision += 1
		return true)

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
	development_controls = ScrollContainer.new()
	development_controls.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	development_controls.follow_focus = true
	development_dialog.add_child(development_controls)
	var controls := VBoxContainer.new()
	controls.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	development_controls.add_child(controls)
	guest_scroll = ScrollContainer.new()
	guest_scroll.custom_minimum_size = Vector2(440,280)
	development_dialog.add_child(guest_scroll)
	guest_review = Label.new()
	guest_review.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	guest_review.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	guest_scroll.add_child(guest_review)
	guest_scroll.hide()
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
	management_tabs = TabContainer.new()
	controls.add_child(management_tabs)
	var inventory_tab := _tab("Inventory")
	inventory_picker = OptionButton.new()
	inventory_tab.add_child(inventory_picker)
	inventory_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inventory_tab.add_child(inventory_info)
	inventory_picker.item_selected.connect(func(_i): _show_inventory_info())
	build_button = _button(inventory_tab,"Place selected structure",func(): _place_selected(inventory_picker))
	_button(inventory_tab,"Deconstruct purchased structure…",func(): _confirm_refund(inventory_picker))
	var catalog_tab := _tab("Construct")
	construction_kind = OptionButton.new()
	var recipe_row := HBoxContainer.new()
	catalog_tab.add_child(recipe_row)
	construction_kind.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	recipe_row.add_child(construction_kind)
	_add_recipe_preview(recipe_row)
	construct_info = Label.new()
	construct_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	catalog_tab.add_child(construct_info)
	construct_button = _button(catalog_tab,"Construct and store",func():
		if construction_kind.selected>=0 and construct(construction_kind.get_selected_metadata(),menu_revision):
			_refresh_build_choices())
	construction_kind.item_selected.connect(func(_index:int): _show_cost(construct_button))
	var placed_tab := _tab("Placed")
	building_picker = OptionButton.new()
	placed_tab.add_child(building_picker)
	placed_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	placed_tab.add_child(placed_info)
	placed_tab.add_child(sanctuary_mode)
	for label in ["Automatic care disabled","Standard Patient Bud","Enhanced Deep Pulse"]: sanctuary_mode.add_item(label)
	sanctuary_mode.item_selected.connect(func(index):
		configure_sanctuary(building_picker.get_selected_id(),["disabled","standard","enhanced"][index],menu_revision)
		_refresh_build_choices())
	building_picker.item_selected.connect(func(_index): _show_placed_info())
	_button(placed_tab,"Relocate for free",func(): _place_selected(building_picker))
	store_button = _button(placed_tab,"Store for free",func():
		if retire_structure(building_picker.get_selected_id(),menu_revision,false): _refresh_build_choices())
	dismantle_button = _button(placed_tab,"Deconstruct purchased structure…",func(): _confirm_refund(building_picker))
	refund_dialog = ConfirmationDialog.new()
	refund_dialog.title = "Permanently deconstruct"
	refund_dialog.confirmed.connect(func():
		if not refund_request.is_empty():
			retire_structure(refund_request.id,refund_request.revision,true)
			refund_request.clear()
			_refresh_build_choices())
	development_dialog.add_child(refund_dialog)

func _add_recipe_preview(row: Control) -> void:
	# Draw the catalogue mesh once per selection, in its own tiny world.
	var image := TextureRect.new()
	image.custom_minimum_size = Vector2(96,64)
	row.add_child(image)
	preview_viewport = SubViewport.new()
	preview_viewport.size = Vector2i(96,64)
	preview_viewport.own_world_3d = true
	preview_viewport.transparent_bg = true
	preview_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	image.add_child(preview_viewport)
	image.texture = preview_viewport.get_texture()
	var camera := Camera3D.new()
	preview_viewport.add_child(camera)
	camera.position = Vector3(1.7,2.3,3)
	camera.look_at(Vector3.ZERO)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 1.9
	preview_model = MeshInstance3D.new()
	var tint := StandardMaterial3D.new()
	tint.vertex_color_use_as_albedo = true
	tint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	preview_model.material_override = tint
	preview_viewport.add_child(preview_model)

func _tab(title: String) -> VBoxContainer:
	var tab := VBoxContainer.new()
	tab.name = title
	management_tabs.add_child(tab)
	return tab

func _button(parent: Control, title: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = title
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _place_selected(picker: OptionButton) -> void:
	var id := picker.get_selected_id()
	if menu_revision!=inventory_revision or not game.progress.structures.instances.has(id): return
	begin_placement(game.progress.structures.instances[id].kind,id)

func _confirm_refund(picker: OptionButton) -> void:
	var id := picker.get_selected_id()
	var entry: Dictionary = game.progress.structures.instances.get(id,{})
	if entry.is_empty(): return
	if entry.paid.is_empty():
		game.tell(game.HOST,"This free structure can be stored and redeployed.")
		return
	refund_request={"id":id,"revision":menu_revision}
	refund_dialog.dialog_text="Permanently remove %s? Refund: %s." % [_building_name(id),_price(entry.paid)]
	refund_dialog.popup_centered()

func _show_cost(buy: Button) -> void:
	buy.disabled = construction_kind.selected<0
	if buy.disabled:
		preview_model.mesh = null
		preview_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		construct_info.text = "Research Cultivation Grounds for beds or Living Sprinklers for irrigation."
		return
	var kind: String = construction_kind.get_selected_metadata()
	preview_model.mesh = Stations.build(Build.CATALOG[kind].art,false)
	preview_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	var cost: Dictionary = Build.CATALOG[kind].cost
	buy.disabled = not _affordable(cost)
	var held := PackedStringArray(["%d Growth Energy" % funds.energy])
	for item in cost.materials:
		var definition: Dictionary = game.Items.get_item(item)
		held.append("%d %s" % [_shared_free(game.players[game.HOST],definition.legacy_part),definition.name])
	construct_info.text = "Available: %s\nPlace on reclaimed dry ground with a clear approach." % ", ".join(held)
	construct_info.text += "\n" + _structure_summary(kind)

func _structure_summary(kind: String) -> String:
	var owned := 0
	var placed := 0
	for entry: Dictionary in game.progress.structures.instances.values():
		if entry.kind == kind:
			owned += 1
			placed += int(entry.placed)
	var summary := "%d owned, %d placed" % [owned,placed]
	var irrigation := _irrigation()
	if Build.CATALOG[kind].has("cost"):
		summary += "\nAdditional copy: " + _price(Build.CATALOG[kind].cost)
	if Build.CATALOG[kind].has("effect"):
		summary += "\n%s within %.1f m" % [_effect_text(kind),irrigation.radius(kind)]
		summary += "\nEffectiveness %s · Coverage %s" % [
			"improved" if irrigation.research.has(kind+"_effectiveness") else "base",
			"improved" if irrigation.research.has(kind+"_coverage") else "base"]
	return summary

func _show_inventory_info() -> void:
	var entry: Dictionary = game.progress.structures.instances.get(inventory_picker.get_selected_id(),{})
	inventory_info.text = _structure_summary(entry.kind) if not entry.is_empty() else ""

func configure_sanctuary(id: int, mode: String, expected: int) -> bool:
	if not available_here() or mode not in ["disabled","standard","enhanced"]: return false
	var entry: Dictionary = game.progress.structures.instances.get(id,{})
	if entry.get("kind")!="bud_sanctuary" or not entry.placed or entry.care_mode==mode: return false
	if mode=="enhanced" and not game.progress.heart.has("bud_sanctuary_effectiveness"): return false
	return _commit_structure(expected,func():
		entry.care_mode = mode
		game.progress.structures.revision += 1
		return true)

func _refresh_build_choices() -> void:
	sync_inventory()
	menu_revision = inventory_revision
	inventory_picker.clear()
	building_picker.clear()
	for id: int in game.progress.structures.instances:
		var entry: Dictionary = game.progress.structures.instances[id]
		var picker := building_picker if entry.placed else inventory_picker
		picker.add_item(_building_name(id),id)
	build_button.disabled = inventory_picker.item_count==0
	construction_kind.clear()
	for kind: String in Build.CATALOG:
		var def: Dictionary = Build.CATALOG[kind]
		if def.get("repeatable",false) and game.progress.heart.has(def.research):
			construction_kind.add_item(def.name)
			construction_kind.set_item_metadata(construction_kind.item_count-1,kind)
	_show_cost(construct_button)
	_show_inventory_info()
	_show_placed_info()

func open_development() -> void:
	if not game.multiplayer.is_server():
		if can_view_development():
			development_controls.hide()
			guest_scroll.show()
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
	guest_scroll.hide()
	development_controls.show()
	_refresh_build_choices()
	development_dialog.popup_centered(Vector2i(570, 480))
	management_tabs.get_tab_bar().grab_focus()

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
	build_revision = inventory_revision
	build_yaw = float(game.progress.structures.instances[moving].yaw)
	game.tell(game.HOST, "Aim or use arrows/D-pad · Q/E or bumpers rotate · Click or Accept to place · Back cancels.")

func build_input(event: InputEvent) -> bool:
	if build_kind.is_empty():
		if event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_Y:
			if can_view_development() and not development_dialog.visible and not game.ui.is_overlay_open():
				open_development()
				return true
		return false
	var right_click: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT
	if not event.is_action_pressed("session_menu") and not event.is_action_pressed("ui_cancel") and not right_click:
		return event is InputEventJoypadButton and placement_input(event)
	_cancel_placement()
	game.tell(game.HOST, "Placement cancelled.")
	return true

func placement_input(event: InputEvent) -> bool:
	if build_kind.is_empty():
		return false
	for direction: String in ["ui_left","ui_right","ui_up","ui_down"]:
		if event.is_action_pressed(direction,true):
			if not build_target.is_finite(): build_target = planar(game.players[game.HOST].pos)
			build_target += {"ui_left":Vector2.LEFT,"ui_right":Vector2.RIGHT,"ui_up":Vector2.UP,"ui_down":Vector2.DOWN}[direction] * 0.25
			_show_ghost()
			return true
	if event.is_action_pressed("ui_accept"):
		if build_target.is_finite() and place(build_kind,build_target,build_yaw,build_moving,build_revision): _cancel_placement()
		return true
	if event is InputEventJoypadButton and event.pressed and event.button_index in [JOY_BUTTON_LEFT_SHOULDER,JOY_BUTTON_RIGHT_SHOULDER]:
		build_yaw += deg_to_rad(15.0) * (1 if event.button_index == JOY_BUTTON_RIGHT_SHOULDER else -1)
		_show_ghost()
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
		if event is InputEventMouseButton and place(build_kind, build_target, build_yaw, build_moving,build_revision):
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
	var instruction := "Click or Accept to place · Q/E or bumpers rotate" if refusal.is_empty() else refusal
	if Build.CATALOG[build_kind].has("effect"):
		var irrigation := _irrigation()
		coverage_preview.mesh = infrastructure.preview(build_target,irrigation.bed_centers,irrigation.beds_in_range(build_target,build_kind),irrigation.radius(build_kind))
		var entry: Dictionary = game.progress.structures.instances.get(build_moving,{})
		var inactive: bool = (build_kind=="sprinkler" and not irrigation.supplied) or (build_kind=="bud_sanctuary" and entry.get("care_mode","disabled")=="disabled")
		var color := Color("#c39c72") if inactive else Color("#8edfd3")
		coverage_preview.material_override.albedo_color = Color("#ec8a78") if not refusal.is_empty() else color
		instruction += " | " + _coverage_info(build_kind,build_target,entry)
	game.tell(game.HOST, instruction + " · Esc or right-click cancels.")

func _cancel_placement() -> void:
	coverage_preview.mesh = null
	build_kind = ""
	build_moving = 0
	build_target = Vector2.INF
	build_yaw = 0.0
	if ghost != null:
		ghost.queue_free()
		ghost = null

func _building_name(id: int) -> String:
	var entry: Dictionary = game.progress.structures.instances[id]
	if entry.kind=="bed" and entry.slot in [0,1,2]: return "Starting bed %d" % (entry.slot+1)
	return "%s #%d" % [Build.CATALOG[entry.kind].name,id]

func _capture_development() -> Dictionary:
	return {"version": SavedGarden.VERSION, "seed": Seed, "radius": Radius, "spacing": Spacing,
		"layout_revision": layout_revision, "revision": state.revision, "outline": state.outline.duplicate(),
		"owned": state.owned.duplicate(), "growth": state.expansion_history.duplicate(),
		"reclaimed_cells": state.reclaimed_cells, "root_paths": state.roots.duplicate(true),
		"roots": network.duplicate(true),
		"energy": funds.energy}

func _restore_development(saved: Dictionary) -> void:
	# Only validated save projections or our own synchronous savepoints reach here.
	state.outline = saved.outline.duplicate()
	state.owned = saved.owned.duplicate()
	state.expansion_history.assign(saved.growth)
	state.revision = saved.revision
	state.reclaimed_cells = saved.reclaimed_cells
	state.roots.assign(saved.root_paths.duplicate(true))
	network.assign(saved.roots.duplicate(true))
	state.refresh_owned_cells()
	layout_revision = saved.layout_revision
	funds.energy = saved.energy
	geometry.clear()

func _commit_development(change: Callable, progress_change := Callable()) -> bool:
	# Prepare synchronously, then restore live owners BEFORE attempting durability.
	# No node, UI, network or animation changes occur until the save is committed.
	var before := _capture_development()
	var changed: bool = change.call()
	var after := _capture_development()
	_restore_development(before)
	if not changed or not SavedGarden.refusal(after).is_empty():
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

func _irrigation() -> RefCounted:
	return game.progress.irrigation if game.multiplayer.is_server() else remote_irrigation

func _refresh_connections() -> void:
	infrastructure.sync_layout(construction.records,state,heart.stage,network,_irrigation().supplied,game.multiplayer.is_server() or remote_revision>=0)

func _effect_text(kind: String) -> String:
	var value: float = _irrigation().strength(kind)
	match kind:
		"sprinkler": return "Watering x%.2f" % value
		"pollination_bloom": return "%d seeds per seed harvest" % int(value)
		"nursery": return "%d familiarity per harvest" % int(value)
		"vital_roots": return "Growth x%.2f" % value
		"refinement_grove": return "+%d percentage points of refinement" % roundi(value*100)
		"bud_sanctuary": return "Standard or enhanced bud care" if value>=2 else "Standard bud care"
	return ""

func _coverage_info(kind: String, at: Vector2, entry: Dictionary) -> String:
	var irrigation := _irrigation()
	var labels := PackedStringArray()
	for slot: int in irrigation.beds_in_range(at,kind): labels.append(str(slot+1))
	var status := ""
	if kind=="sprinkler": status = "Water supplied" if irrigation.supplied else "Inactive: place a Water Intake"
	if kind=="bud_sanctuary": status = "Automatic care "+str(entry.get("care_mode","disabled"))
	return "%s within %.1f m | %s Beds: %s" % [_effect_text(kind),irrigation.radius(kind),status,", ".join(labels) if not labels.is_empty() else "none"]

func _show_placed_info() -> void:
	var entry: Dictionary = game.progress.structures.instances.get(building_picker.get_selected_id(),{})
	placed_info.text = "" if entry.is_empty() else _structure_summary(entry.kind)
	if not entry.is_empty() and Build.CATALOG[entry.kind].has("effect"):
		placed_info.text += "\n"+_coverage_info(entry.kind,entry.at,entry)
	sanctuary_mode.visible = entry.get("kind")=="bud_sanctuary"
	if sanctuary_mode.visible:
		sanctuary_mode.set_item_disabled(2,not game.progress.heart.has("bud_sanctuary_effectiveness"))
		sanctuary_mode.select(["disabled","standard","enhanced"].find(entry.care_mode))

func _refresh_structure_views() -> void:
	_refresh_connections()
	var present := {}
	for id: int in construction.records:
		var record: Dictionary = construction.records[id]
		if record.kind=="bed": continue
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
