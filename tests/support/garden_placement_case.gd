extends RefCounted
## Deterministic fixture setup through the real placement validator, not stale art coordinates.
const Shape = preload("res://assets/terrain_m02/terrain_feature_geometry.gd")
static func find(model: RefCounted, kind: String, preferred: Vector2, yaw: float, pawn: Vector2, moving: int = 0) -> Vector2:
	var outline: PackedVector2Array = model.forest.visible_outline
	var bounds: Rect2 = Shape.shape("fixture", "clearing", outline).bounds
	var candidates: Array[Vector2] = []
	for x in range(floori(bounds.position.x * 2), ceili(bounds.end.x * 2) + 1):
		for y in range(floori(bounds.position.y * 2), ceili(bounds.end.y * 2) + 1):
			var at := Vector2(x, y) * 0.5
			if at.distance_to(preferred) < 0.25 or not Geometry2D.is_point_in_polygon(at, outline): continue
			candidates.append(at)
	candidates.sort_custom(func(a, b):
		var da: float = a.distance_squared_to(preferred)
		var db: float = b.distance_squared_to(preferred)
		return a < b if is_equal_approx(da, db) else da < db)
	for at in candidates:
		if model.validate(kind, at, yaw, pawn, moving).is_empty(): return at
	return Vector2.INF

static func stored_id(garden: Node, kind: String) -> int:
	for id: int in garden.game.progress.structures.instances:
		var entry: Dictionary = garden.game.progress.structures.instances[id]
		if entry.kind==kind and not entry.placed: return id
	return 0

static func deploy_irrigation(garden: Node, kind: String, near: Vector2) -> int:
	var id := stored_id(garden,kind)
	var pawn: Vector2 = garden.planar(garden.game.players[1].pos)
	if not id: return 0
	var site := find(garden.construction,kind,near,0,pawn)
	if not site.is_finite() or not garden.place(kind,site,0,id): return 0
	return id

## Place real owned beds through their ordinary host commands. Sample a regular row spacing,
## then try a staggered row for awkward boundaries. Reclaim a legal frontier when needed.
static func develop(garden: Node, target: int, profile := false) -> bool:
	var game: Node = garden.game
	var pawn: Vector2 = garden.planar(game.players[1].pos)
	var revision: int = -1
	var sites: Array[Vector2] = []
	if profile:
		# Reclaim space for the large orchard before placing its beds along the approaches.
		for step in 18:
			var choices: Array = garden.state.frontier_options()
			if choices.is_empty(): break
			choices.sort_custom(func(a,b): return a.cells.size()>b.cells.size())
			var plan: Dictionary = choices.front()
			garden.plans[plan.sector] = plan
			if not garden.expand(plan.sector): break
			garden.reveal.custom_step(3.0)
		print("HG02_SCALE frontier purchases=",garden.state.revision)
	while garden.bed_ids.size() < target:
		if garden.state.revision != revision:
			revision = garden.state.revision
			sites.clear()
			var bounds: Rect2 = Shape.shape("test","clearing",garden.state.outline).bounds
			for offset in [Vector2.ZERO,Vector2(1.35,1.4)]:
				for y in range(floori(bounds.position.y/2.8), ceili(bounds.end.y/2.8)):
					for x in range(floori(bounds.position.x/2.7), ceili(bounds.end.x/2.7)):
						sites.append(Vector2(x*2.7,y*2.8)+offset)
		var placed := false
		while not sites.is_empty():
			var at: Vector2 = sites.pop_back()
			if not garden.construction.validate("bed",at,0.0,pawn).is_empty(): continue
			var id := 0
			for key: int in game.progress.structures.instances:
				var e: Dictionary=game.progress.structures.instances[key]
				if e.kind=="bed" and not e.placed: id=key;break
			if id==0:
				if not garden.construct("bed",game.progress.structures.revision): return false
				id=game.progress.structures.next_id-1
			if not garden._build_refusal("bed",at,0,id).is_empty(): continue
			if not garden.place("bed",at,0,id): return false
			placed=true
			break
		if not placed:
			var options: Array = garden.state.frontier_options()
			if options.is_empty():
				print("HG02 exhausted reachable frontiers at beds=",garden.bed_ids.size()," expansions=",revision)
				return false
			options.sort_custom(func(a,b):return a.cells.size()>b.cells.size())
			var sector: int = options[0].sector
			garden.plans[sector]=options[0]
			if not garden.expand(sector): return false
			if garden.reveal != null: garden.reveal.custom_step(3.0)
		if profile and placed and garden.bed_ids.size() in [12,30,60]:
			var plots: Array = game.progress.plots.duplicate(true)
			for slot: int in garden.bed_ids:
				var bed: Dictionary = game.progress.plots[slot]
				bed.species=0
				preload("res://cultivation_growth.gd").initialize(bed)
			var started := Time.get_ticks_usec()
			for step in 20: game.progress.advance_growth(0.2)
			var growth_us := (Time.get_ticks_usec()-started)/20.0
			var packet: int = var_to_bytes([game.garden_snapshot(),garden.snapshot()]).size()
			started=Time.get_ticks_usec()
			game.stage.update_plots(game.Progress.decode_plots(game.progress.plot_snapshot()))
			var full_us := Time.get_ticks_usec() - started
			game.progress.plots[0].stage=2
			started=Time.get_ticks_usec()
			game.stage.update_plots(game.Progress.decode_plots(game.progress.plot_snapshot()))
			var single_us := Time.get_ticks_usec()-started
			var id: int = garden.bed_ids.values().back()
			var placed_bed: Dictionary = garden.construction.records[id]
			started=Time.get_ticks_usec()
			var refusal: String = garden.construction.validate("bed",placed_bed.at,placed_bed.yaw,pawn,id)
			if not refusal.is_empty():
				printerr("FAIL HG02 layout no longer admits its last placed bed: ",refusal)
				return false
			var validation_us := Time.get_ticks_usec()-started
			started=Time.get_ticks_usec()
			garden.infrastructure.rebuild(garden.construction.records,garden.planar(garden.landmark("heart")),garden.state.layout.water,garden.game.progress.irrigation.supplied)
			var roots_us:=Time.get_ticks_usec()-started
			var index:=preload("res://garden_irrigation.gd").new()
			started=Time.get_ticks_usec()
			index.resolve(game.progress.structures)
			var coverage_us:=Time.get_ticks_usec()-started
			started=Time.get_ticks_usec()
			for sample in 20:
				var aim := placed_bed.at as Vector2
				garden.infrastructure.preview(aim,index.bed_centers,index.beds_in_range(aim))
			var overlay_us:=(Time.get_ticks_usec()-started)/20.0
			print("HG03_SCALE roots_us=",roots_us," root_vertices=",garden.infrastructure.mesh.surface_get_array_len(0)," coverage_us=",coverage_us," overlay_us=",overlay_us," active_beds=",index.watered_slots.size())
			print("HG02_SCALE beds=",garden.bed_ids.size()," growth_us=",growth_us," render_updates_us=",full_us," one_crop_update_us=",single_us," placement_us=",validation_us," garden_projection_bytes=",packet)
			game.progress.plots.assign(plots)
			game.progress.sync_plot_flags()
	return true
