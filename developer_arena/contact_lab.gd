extends VBoxContainer
## Only a local camera, reference targets and cosmetic meshes enter this viewport.
const Contacts = preload("res://contact_particles.gd")
const Tune = preload("res://developer_arena/tuning.gd")
const FRAME := 1.0 / 60.0
const CYCLE := 0.85
var world: Node
var viewport := SubViewport.new()
var camera := Camera3D.new()
var captured_values := {}
var captured_emission := 0.0
var scene := Node3D.new()
var targets := Node3D.new()
var samples: Array[Dictionary] = []
var selection := OptionButton.new()
var formation := OptionButton.new()
var mode := OptionButton.new()
var repeat := CheckButton.new()
var phase := Label.new()
var transport := VBoxContainer.new()
var equipped: Control
var clock := 0.0
var running := false
var started := false

func setup(panel: Control, legacy_controls: Control) -> void:
	world=panel.world
	equipped=legacy_controls
	for item in ["Weapon contact · melee","Weapon contact · projectile","Brittle rupture","Equipped skill replay"]:
		selection.add_item(item)
	add_child(selection)
	selection.item_selected.connect(func(_index): select_effect())
	add_child(transport)
	var host := SubViewportContainer.new()
	host.custom_minimum_size=Vector2(350,156)
	host.stretch=true
	host.mouse_filter=Control.MOUSE_FILTER_IGNORE
	transport.add_child(host)
	viewport.own_world_3d=true
	host.add_child(viewport)
	viewport.add_child(scene)
	var environment := Environment.new()
	environment.background_mode=Environment.BG_COLOR
	environment.background_color=Color("#253029")
	environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color=Color("#c1d2bc")
	environment.ambient_light_energy=0.6
	var atmosphere := WorldEnvironment.new()
	atmosphere.environment=environment
	scene.add_child(atmosphere)
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.size=3.7
	scene.add_child(camera)
	camera.position=Vector3(2.5,4.2,6.8)
	camera.look_at(Vector3(0,0.78,0))
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees=Vector3(-53,-25,0)
	sun.light_energy=1.2
	scene.add_child(sun)
	scene.add_child(targets)
	var options := HBoxContainer.new()
	transport.add_child(options)
	for item in ["One target","Three · cluster","Six · ring"]: formation.add_item(item)
	formation.item_selected.connect(func(_index): stop(); arrange_targets())
	options.add_child(formation)
	mode.add_item("Production baseline")
	mode.add_item("Experimental")
	mode.item_selected.connect(func(_index): compare_at_phase())
	options.add_child(mode)
	repeat.text="Repeat"
	options.add_child(repeat)
	var buttons := HFlowContainer.new()
	transport.add_child(buttons)
	panel.command(buttons,"Play / restart",func(): play(true))
	panel.command(buttons,"Pause / resume",pause_resume)
	panel.command(buttons,"Step 1/60 s",single_step)
	panel.command(buttons,"Stop and clear",stop)
	transport.add_child(phase)
	visibility_changed.connect(update_visibility)
	arrange_targets()
	select_effect()
	update_visibility()

func select_effect() -> void:
	stop()
	transport.visible=selection.selected!=3
	equipped.visible=selection.selected==3

func origins() -> Array[Vector3]:
	var points: Array[Vector3]=[]
	var count: int=[1,3,6][formation.selected]
	for i in count:
		var angle: float=i*TAU/count
		var radius: float=0.0 if count==1 else (0.75 if count==3 else 1.7)
		points.append(Vector3(cos(angle),0,sin(angle))*radius)
	return points

func arrange_targets() -> void:
	for old in targets.get_children():
		targets.remove_child(old)
		old.queue_free()
	camera.size=[2.35,3.0,3.7][formation.selected]
	var body := CapsuleMesh.new()
	body.radius=.26
	body.height=1.3
	var material := StandardMaterial3D.new()
	material.albedo_color=Color("#676955")
	body.material=material
	for at in origins():
		var target := MeshInstance3D.new()
		target.mesh=body
		targets.add_child(target)
		target.position=at+Vector3.UP*.65

func play(advance: bool) -> void:
	if not world.developer_tuning.authorized(world) or selection.selected==3: return
	stop()
	var tune=world.developer_tuning
	var settings: Dictionary=tune.contact_values() if mode.selected==1 else {}
	var emission: float=tune.applied(Tune.IMPACT) if mode.selected==1 else tune.baseline(Tune.IMPACT)
	captured_values=settings
	captured_emission=emission
	var family := "rupture" if selection.selected==2 else "impact"
	var points:=origins()
	for i in points.size():
		var sample:=Contacts.create(scene,family,points[i],Vector3.FORWARD,
			"bow" if selection.selected==1 else "blade",17+i,settings,emission)
		samples.append(sample)
	started=true
	running=advance
	seek(0)

func compare_at_phase() -> void:
	if not started: return
	var previous_time:=clock
	play(running)
	seek(previous_time)

func seek(seconds: float) -> void:
	clock=clampf(seconds,0,CYCLE)
	for sample in samples:
		sample.root.visible=clock<sample.life
		Contacts.pose(sample,clock)
	phase.text="%d ms   ·   %s"%[roundi(clock*1000),"Playing" if running else "Paused"]
	viewport.render_target_update_mode=SubViewport.UPDATE_ONCE

func pause_resume() -> void:
	if not world.developer_tuning.authorized(world):return
	if not started or clock>=CYCLE: play(true); return
	running=not running
	seek(clock)

func single_step() -> void:
	if not world.developer_tuning.authorized(world):return
	if not started or clock>=CYCLE: play(false)
	running=false
	seek(clock+FRAME)

func stop() -> void:
	for sample in samples:
		sample.root.hide()
		sample.root.queue_free()
	samples.clear()
	running=false
	started=false
	clock=0
	phase.text="Ready"
	viewport.render_target_update_mode=SubViewport.UPDATE_ONCE

func update_visibility() -> void:
	if not is_visible_in_tree(): stop()
	set_process(is_visible_in_tree())
	if is_visible_in_tree(): viewport.render_target_update_mode=SubViewport.UPDATE_ONCE

func _process(delta: float) -> void:
	if not running: return
	if not world.developer_tuning.authorized(world): stop(); return
	if clock+delta>=CYCLE:
		if repeat.button_pressed:
			var next_time:=fposmod(clock+delta,CYCLE)
			var tune=world.developer_tuning
			if mode.selected==1 and (captured_values!=tune.contact_values() or not is_equal_approx(captured_emission,tune.applied(Tune.IMPACT))):
				play(true)
			seek(next_time)
		else: stop()
	else: seek(clock+delta)
