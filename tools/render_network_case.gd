extends SceneTree
## Graphical observer for ordinary multiplayer fixtures using their scripted keyboard input.
const Game = preload("res://game.gd")

class KeyboardFixtureInput extends "res://mouse_combat.gd":
	# Multiple test windows share one OS pointer. The fixture supplies normal actions and facing.
	func frame(_game: Node) -> void: pass

const Case = preload("res://tests/support/cr03_network_case.gd")
const Experiment = preload("res://assets/terrain_m02/experimental/experiment_mode.gd")
const Settings = preload("res://app_settings.gd")
var previous := 0
var frames := PackedFloat64Array()
var active_frames := PackedFloat64Array()
var slowest: Array[Dictionary] = []
var next_sample := 0
var peak_players := 0
var peak_effects := 0
var observed := {}
var actual_level := ""
var rendered_frames := 0
var keyboard_worlds := 0

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var role := OS.get_cmdline_user_args()[0]
	if DisplayServer.get_name()=="headless" or not Experiment.verified() or role!=OS.get_environment("MYSTICAL_VALIDATION_PEER"):
		printerr("FAIL: graphical fixture requires a marked peer profile"); quit(2); return
	var level: String = {"host":"High","guest":"Low","1":"Low","2":"Medium","3":"Ultra","overflow":"Low"}[role]
	var settings := Settings.new()
	settings.values.graphics = Settings.Visuals.normalize({"level":level})
	settings.values.vsync = false
	settings.values.fps = 60
	if settings.save_settings(settings.values)!=OK:
		printerr("FAIL: could not set disposable local preferences"); quit(2); return
	var name_value := OS.get_environment("MYSTICAL_VALIDATION_FIXTURE")
	node_added.connect(install_keyboard_input)
	var fixture := fixture_for(name_value)
	process_frame.connect(sample)
	RenderingServer.frame_post_draw.connect(draw)
	var is_party := name_value.ends_with("_party")
	var passed: bool = await fixture.run(self,is_party)
	node_added.disconnect(install_keyboard_input)
	process_frame.disconnect(sample)
	RenderingServer.frame_post_draw.disconnect(draw)
	frames.sort()
	if rendered_frames==0 or (role!="overflow" and (keyboard_worlds==0 or frames.is_empty() or actual_level!=level or peak_players<(4 if is_party else 2))):passed=false
	var report := {"peer":role,"expected":level,"applied":actual_level,"rendered":rendered_frames,"frames":frames.size(),"players":peak_players,"effects":peak_effects,"events":observed.keys(),"slow_frames":slowest}
	if not frames.is_empty():
		for value in [["median",.5],["p95",.95],["p99",.99],["max",1.]]:
			report[value[0]]=frames[ceili(frames.size()*value[1])-1]
	if not active_frames.is_empty():
		active_frames.sort()
		report.active_samples=active_frames.size()
		report.active_p95=active_frames[ceili(active_frames.size()*.95)-1]
		report.active_p99=active_frames[ceili(active_frames.size()*.99)-1]
		report.active_max=active_frames[-1]
	print("NET_RENDER ",JSON.stringify(report))
	if passed:print("PASS: ordinary rendered multiplayer fixture ",name_value," ",role)
	quit(int(not passed))

func install_keyboard_input(node: Node) -> void:
	if node is Game:
		node.mouse_controls = KeyboardFixtureInput.new()
		keyboard_worlds += 1

func fixture_for(fixture_name: String) -> RefCounted:
	if fixture_name == "wild_flora_party":
		return preload("res://tests/support/wild_flora_network_case.gd").new()
	var fixture := Case.new()
	if fixture_name == "cr04c_mixed_party":
		fixture.extra_cores = ["part_11", "plant_part_rare_ghost_fern", "plant_part_rare_void_willow"]
		fixture.measure_packets = true
		fixture.final_family_mix = true
	else:
		var family := fixture_name.get_slice("_", 1)
		if family == "spirit": fixture.ce04_family = family
		else: fixture.ce03_family = family
		fixture.connected_oracle_case = true
		fixture.affinity_cards_case = true
	return fixture

func draw() -> void: rendered_frames+=1

func sample() -> void:
	var scene := current_scene
	var now := Time.get_ticks_usec()
	if not is_instance_valid(scene) or not scene.has_node("Stage/CombatEffects"):
		previous=0;return
	var fx: Node=scene.stage.get_node("CombatEffects")
	if previous:
		var elapsed := (now-previous)*.001
		frames.append(elapsed)
		if not fx.active.is_empty():active_frames.append(elapsed)
		if elapsed >= 50.0 and (slowest.size() < 5 or elapsed > float(slowest.back().ms)):
			slowest.append({"ms":elapsed, "at_ms":now/1000, "floor_view_exists":scene.stage.has_floor(), "expedition_active":scene.participation.active(),
				"players":scene.players.size(), "effects":fx.active.size(), "hints":fx.hints.size(),
				"shapes":fx.active.values().map(func(effect):return effect.event.shape).slice(0,8)})
			slowest.sort_custom(func(a,b):return a.ms>b.ms)
			if slowest.size()>5:slowest.pop_back()
	previous=now
	if now<next_sample:return
	next_sample=now+80000
	actual_level=fx.local_graphics.level
	peak_players=maxi(peak_players,scene.players.size())
	peak_effects=maxi(peak_effects,fx.active.size()+fx.hints.size()+fx.statuses.active.size())
	for item in fx.active.values():observed[item.event.shape]=true
	for hint in fx.hints.values():observed[hint.event.get("skill",hint.event.role)]=true
