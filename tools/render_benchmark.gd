extends SceneTree
## Standalone diagnostic. Launch through render_benchmark.py to allocate an isolated profile.
const Dev = preload("res://developer_mode.gd")
const Scenarios = preload("res://developer_arena/scenarios.gd")
const Placement = preload("res://tests/support/garden_placement_case.gd")
const Features = preload("res://assets/terrain_m02/terrain_feature_view.gd")
const Core = preload("res://core_combat.gd")
const Aim = preload("res://ability_aim.gd")
const BUILDS = {"weapon":"Sustained damage","fire":"Wildfire practice","frost":"Avalanche practice",
	"water":"Monsoon practice","storm":"Conductor practice","spirit":"Mirrorstep practice",
	"void":"Singularity practice","mixed":"Avalanche practice"}
var garden: Node
var arena: Node
var world: Node
var storage: String
var cases: PackedStringArray
var window_us: int
var recording: bool
var output_index := 0
var failed := false
var trace_stalls := false
var draw_started := 0
var draw_ended := 0
var startup := Time.get_ticks_usec()

func _initialize() -> void:
	call_deferred("run")

func report(kind: String, values: Dictionary) -> void:
	values.kind = kind
	print("BENCH ", JSON.stringify(values))

func allowed(name: String, group: String) -> bool:
	return name in cases or group in cases

func run() -> void:
	storage = OS.get_environment("VFX08_ROOT").replace("\\","/").simplify_path()
	var prefix := ProjectSettings.globalize_path("res://.godot/vfx08/").replace("\\","/").trim_suffix("/")
	var marker := storage.path_join("fixture.marker")
	var profile := OS.get_user_data_dir().replace("\\","/").simplify_path()
	if storage.get_base_dir()!=prefix or not profile.begins_with(storage+"/") or not FileAccess.file_exists(marker) or FileAccess.get_file_as_string(marker)!=storage.get_file() or DisplayServer.get_name()=="headless":
		printerr("REJECT unmarked graphical fixture"); quit(2); return
	cases = OS.get_environment("VFX08_CASES").split(",",false)
	for name in cases:
		if name not in ["garden","world","combat","probe","isolate"] and not BUILDS.has(name):
			printerr("REJECT unknown workload ", name); quit(2); return
	window_us = clampi(OS.get_environment("VFX08_SECONDS").to_int(),3,120)*1000000
	trace_stalls = OS.get_environment("VFX08_STALLS") == "1"
	if trace_stalls:
		RenderingServer.frame_pre_draw.connect(func(): draw_started=Time.get_ticks_usec())
		RenderingServer.frame_post_draw.connect(func(): draw_ended=Time.get_ticks_usec())
	recording = OS.get_environment("VFX08_CAPTURE")=="1"
	report("device",{"adapter":RenderingServer.get_video_adapter_name(),"renderer":RenderingServer.get_current_rendering_method(),"size":str(root.size),"cpu":OS.get_processor_name(),"screen":str(DisplayServer.screen_get_size())})
	var menu: Node = preload("res://main_menu.tscn").instantiate()
	menu.storage.root_path = "user://saves"
	menu.import_legacy = false
	menu.restore_last_selection = false
	root.add_child(menu)
	current_scene = menu
	menu.app_settings.values.developer_mode = true
	if menu.app_settings.save_settings(menu.app_settings.values)!=OK or Dev.open_garden(menu,false)!=OK:
		printerr("REJECT developer Garden"); quit(3); return
	garden = current_scene
	await RenderingServer.frame_post_draw
	report("first_garden",{"ms_from_script":(Time.get_ticks_usec()-startup)*.001})
	if "probe" in cases: await floor_probe()
	if "isolate" in cases: await component_probe()
	if "garden" in cases: await garden_workloads()
	var combat := "combat" in cases or "world" in cases
	for name in BUILDS: combat = combat or name in cases
	if combat and not failed:
		if not Dev.enter_arena(garden):
			printerr("REJECT arena"); quit(4); return
		arena = garden.get_node("TestingArena")
		world = arena.combat
		for name: String in BUILDS:
			if allowed(name,"combat"): await practice(name,0,0)
		if "world" in cases:
			for spec in [[2,136],[10,137],[16,129],[2,136]]:
				await practice("biome_%d"%spec[0],spec[0],spec[1])
		arena.close()
		await process_frame
		await process_frame
	if failed: quit(5); return
	report("complete",{})
	quit()

func floor_probe() -> void:
	for i in 4:
		var family: int = [0,1,2,0][i]
		var features := Features.new()
		var start := Time.get_ticks_usec()
		var assets: Dictionary = features._wilds_assets(family)
		var prepared := Time.get_ticks_usec()
		var mesh: Mesh = assets.tree[0].mesh
		var again: Dictionary = features._wilds_assets(family)
		report("family_meshes",{"family":family,"build_ms":(prepared-start)*.001,"lookup_us":Time.get_ticks_usec()-prepared,"same_mesh":mesh==again.tree[0].mesh,"mesh_id":mesh.get_instance_id()})
		features.free()
		var stage: Node = garden.stage
		var old: WeakRef = weakref(stage.wilds_air) if is_instance_valid(stage.wilds_air) else null
		start = Time.get_ticks_usec()
		stage.redraw_terrain(family,[2,4,4][family],[136,137,129][family])
		prepared = Time.get_ticks_usec()
		stage.terrain.show()
		stage.focus(stage.WILD_OFFSET+stage.visual_field.entry,true)
		stage.apply_exploration_sight(stage.visual_field.entry,true,8.)
		RenderingServer.force_draw(false)
		RenderingServer.force_sync()
		report("floor_draw",{"family":family,"setup_ms":(prepared-start)*.001,"draw_sync_ms":(Time.get_ticks_usec()-prepared)*.001})
		await process_frame
		await process_frame
		if old!=null and old.get_ref()!=null: printerr("REJECT retained floor"); failed=true

func component_probe() -> void:
	var stage: Node = garden.stage
	for index in [0,1,2,0]:
		var depth: int = [2,4,4][index]
		stage.redraw_terrain(index,depth,[136,137,129][index])
		var layout: Dictionary = stage.visual_field.generated.layout
		var start := Time.get_ticks_usec()
		var atlas := preload("res://assets/terrain_m02/terrain_feature_mask.gd").bake(layout,1.75,14)
		var baked := Time.get_ticks_usec()
		report("distance_atlas",{"family":index,"ms":(baked-start)*.001,"pixels":str(atlas.size),"digest":hash(atlas.image.get_data())})
	var participant: Dictionary = stage.spectral_body(1)
	if participant.is_empty(): participant={"frame":0,"weapon_kind":0}
	for index in 10:
		var start:=Time.get_ticks_usec()
		var body := preload("res://astral_visuals.gd").create(stage,"mirrorstep_attack",Vector3.ZERO,Vector3.RIGHT,1.,index,{},"",participant)
		var created:=Time.get_ticks_usec()
		var field: Dictionary = body.get_meta("spectral_body").actor.field_rig
		var calibration_start := Time.get_ticks_usec()
		for owner in [preload("res://spear_animation.gd"), preload("res://staff_animation.gd"), preload("res://maul_animation.gd"), preload("res://wand_animation.gd"), preload("res://rootblade_animation.gd")]:
			owner.calibration(field.skeleton, field.player, field.pelvis)
		var calibrated := Time.get_ticks_usec()
		preload("res://astral_visuals.gd").seek(body,.15,.55)
		var posed:=Time.get_ticks_usec()
		RenderingServer.force_draw(false)
		RenderingServer.force_sync()
		report("apparition",{"i":index,"build_ms":(created-start)*.001,"explicit_calibration_ms":(calibrated-calibration_start)*.001,"pose_ms":(posed-calibrated)*.001,"draw_sync_ms":(Time.get_ticks_usec()-posed)*.001})
		body.queue_free()
		await process_frame
		await process_frame
	var rid:=root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(rid,true)
	for index in 20: await RenderingServer.frame_post_draw
	report("viewport_timers",{"cpu_ms":RenderingServer.viewport_get_measured_render_time_cpu(rid),"gpu_ms":RenderingServer.viewport_get_measured_render_time_gpu(rid)})
	RenderingServer.viewport_set_measure_render_time(rid,false)

func garden_workloads() -> void:
	var plot: Node = garden.stage.experimental_garden
	var actor: Dictionary = garden.players[1]
	await trials("garden_start",false)
	actor.pos = Vector3(0,0,1.5)
	garden.app_settings.values.garden_cinematics=false
	for tech in ["cultivation_grounds","irrigation","nursery","refinement_grove","vital_roots","pollination_bloom","bud_sanctuary","clearing_1"]:
		Dev.test_unlock(garden,tech)
	var water: Vector2 = plot.planar(preload("res://garden_water.gd").anchor(garden.stage))
	var near := {"intake":water,"sprinkler":Vector2(3.6,0),"pollination_bloom":Vector2(4,3.8),"nursery":Vector2(-3,3.5),"refinement_grove":Vector2(-4,1),"vital_roots":Vector2(2,-3),"bud_sanctuary":Vector2(-2,-4)}
	for kind in near:
		if not Placement.deploy_irrigation(plot,kind,near[kind]): printerr("REJECT installation ",kind); failed=true; return
	for bed in 3:
		actor.pos=garden.stage.bed_position(bed)
		actor.seed_choice=bed
		garden.seed_reserve(actor).stock[bed]+=1
		garden.cultivation.plant_seed(1,bed)
	actor.pos=Vector3(0,0,1.5)
	await trials("garden_developed",false)
	plot.funds.energy=10000
	garden.progress.garden_development.energy=10000
	Placement.reclaim_orchard(plot)
	for count in [30,60]:
		for kind in ["sprinkler","pollination_bloom"]:
			for index in 2:
				if not plot.construct(kind,garden.progress.structures.revision) or not Placement.deploy_irrigation(plot,kind,Vector2.from_angle((index+count/30)*1.8)*7):
					printerr("REJECT orchard station ",kind); failed=true; return
		Placement.develop(plot,count)
		while plot.bed_ids.size()<count:
			if not plot.construct("bed",garden.progress.structures.revision) or not Placement.deploy_irrigation(plot,"bed",Vector2(-3,-3)):
				printerr("REJECT orchard size ",plot.bed_ids.size()); failed=true; return
		await trials("garden_%d"%count,false)

func practice(name: String, depth: int, seed_value: int) -> void:
	var lib := Scenarios.new(world)
	var record := lib.builtin(BUILDS.get(name,"Sustained damage"))
	var row: Dictionary = record.participants[0]
	record.encounter.count=3
	record.encounter.formation="Cluster"
	if name=="spirit": row.upgrades.append({"id":"wraithcast","rarity":""})
	if name=="water": row.upgrades.append({"id":"saturating_strikes","rarity":"Rare"})
	if name=="mixed" or depth: row.parts=["plant:frostbell","plant:thorn_bloom","plant:storm_reed"]
	if depth: record.terrain={"seed":seed_value,"depth":depth}
	var old: WeakRef=weakref(world)
	var start:=Time.get_ticks_usec()
	var error:=lib.start(record)
	if not error.is_empty(): printerr("REJECT ",name," ",error); failed=true; return
	await process_frame
	await RenderingServer.frame_post_draw
	await process_frame
	world=arena.combat
	if old.get_ref()!=null: printerr("REJECT retained practice world"); failed=true; return
	if world.workbench.opened: world.workbench.toggle()
	world.set_control("invincible",true)
	world.set_control("no_cooldowns",true)
	world.rng.seed=18478
	report("transition",{"case":name,"ms":(Time.get_ticks_usec()-start)*.001,"layout":hash(world.battlefield.generated.layout),"seed":seed_value})
	var actor: Dictionary=world.players[1]
	if depth:
		var floor: Dictionary=world.battlefield.generated.layout
		actor.pos=world.battlefield.entry
		for item in floor.crossings:
			if item.has("bridge"):
				var at: Vector2=item.bridge[0].lerp(item.bridge[1],.5)
				actor.pos=Vector3(at.x,0,at.y)
				break
		await trials(name+"_walk",false)
	actor.pos=world.encounter.position(0)-Vector3.RIGHT*1.25
	actor.facing=Vector3.RIGHT
	await trials(name,true)

func trials(name: String, fighting: bool) -> void:
	for pass_index in 3:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		Engine.max_fps=120 if pass_index<2 else 0
		await process_frame
		await sample(name,fighting,pass_index)

func act(name: String, beat: int) -> void:
	var actor: Dictionary=world.players[1]
	actor.mouse_aim=true
	actor.aim_direction=Vector3.RIGHT
	if name=="spirit":
		if beat%8 in [0,1]: world.dodge_player(1,Vector2.RIGHT if beat%8==0 else Vector2.LEFT)
		if beat%6==4:
			world.garden_action(1,Aim.request(world,actor,0,Vector2.RIGHT,1.35)); return
	if name=="void" and beat%6==3:
		world.garden_action(1,preload("res://card_active_actions.gd").request(world,actor,"singularity",Vector2.RIGHT,1000+beat)); return
	if name!="weapon" and beat%6 in [0,3]: world.garden_action(1,Core.request(world,actor,Vector2.RIGHT,1.35))
	elif name!="weapon" and beat%6==4: world.garden_action(1,Aim.request(world,actor,1,Vector2.RIGHT,1.35))
	else: world.weapon_attacks.try_start(world.weapon_attack_world,1,actor.pos,world.CombatClock.now())

func percentile(frames: PackedFloat64Array, fraction: float) -> float:
	return snappedf(frames[clampi(ceili(frames.size()*fraction)-1,0,frames.size()-1)],.001)

func sample(name: String, fighting: bool, pass_index: int) -> void:
	var frames := PackedFloat64Array()
	var start:=Time.get_ticks_usec()
	var previous:=start
	var beat:=0
	var next_observe:=0
	var next_image:=125000
	var previous_physics:=Engine.get_physics_frames()
	var peak_effects:=0
	var kinds: Dictionary={}
	var process_peak_ms:=0.0
	var next_threshold:=[0,0,0,0]
	var thresholds:=[16.7,33.3,50.,100.]
	var last_draws:=0
	var last_primitives:=0
	var resources:=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
	var pipeline_start:=int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_DRAW))
	var fx: Node = world.stage.get_node("CombatEffects") if fighting else null
	while Time.get_ticks_usec()-start<window_us:
		await process_frame
		var now:=Time.get_ticks_usec()
		var dt:=(now-previous)*.001
		if trace_stalls and dt>50.0:
			report("stall",{"case":name,"pass":pass_index,"at_ms":(now-start)*.001,"frame_ms":dt,"until_pre_draw_ms":(draw_started-previous)*.001,"draw_submission_ms":(draw_ended-draw_started)*.001,"after_draw_ms":(now-draw_ended)*.001,"physics_steps":Engine.get_physics_frames()-previous_physics,"tweens":get_processed_tweens().size()})
		if trace_stalls: previous_physics=Engine.get_physics_frames()
		frames.append(dt)
		previous=now
		for i in thresholds.size():
			if dt>thresholds[i]: next_threshold[i]+=1
		if fighting and now-start>=beat*320000:
			act(name,beat)
			beat+=1
		if now-start>=next_observe:
			next_observe+=200000
			last_draws=int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
			last_primitives=int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
			process_peak_ms=maxf(process_peak_ms,Performance.get_monitor(Performance.TIME_PROCESS)*1000.)
			if fighting:
				peak_effects=maxi(peak_effects,fx.active.size()+fx.hints.size()+fx.statuses.active.size())
				for e in fx.active.values(): kinds[e.event.shape]=true
				for h in fx.hints.values(): kinds[h.event.get("skill",h.event.role)]=true
		if recording and now-start>=next_image:
			next_image+=125000
			await RenderingServer.frame_post_draw
			var image:=root.get_texture().get_image()
			image.resize(550,360,Image.INTERPOLATE_BILINEAR)
			if image.save_jpg(storage.path_join("frame-%06d.jpg"%output_index),.82)!=OK: failed=true
			output_index+=1
	frames.sort()
	report("frames",{"case":name,"pass":pass_index,"cap":Engine.max_fps,"n":frames.size(),"median":percentile(frames,.5),
		"p95":percentile(frames,.95),"p99":percentile(frames,.99),"p999":percentile(frames,.999) if frames.size()>=1000 else null,
		"max":frames[-1],"above_ms":next_threshold,"draws":last_draws,"primitives":last_primitives,"texture_bytes":Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED),
		"resources_delta":Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)-resources,"nodes":Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		"process_monitor_peak_ms":process_peak_ms,"pipeline_draw_delta":Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_DRAW)-pipeline_start,
		"peak_effects":peak_effects,"events":kinds.keys()})
