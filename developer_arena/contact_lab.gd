extends VBoxContainer
## Only a local camera, reference targets and cosmetic meshes enter this viewport.
const Contacts = preload("res://contact_particles.gd")
const Tune = preload("res://developer_arena/tuning.gd")
const Exhibit = preload("res://developer_arena/garden_exhibit.gd")
var exhibit: Node3D
var water := CheckButton.new()
var heart_stage := OptionButton.new()
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
	for item in ["Weapon contact · melee","Weapon contact · projectile","Brittle rupture","Equipped skill replay","Heart fissure","Root energy","Water Intake","Living Sprinkler","Pollination Bloom"]:
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
	water.text="Water supplied"
	water.button_pressed=true
	water.toggled.connect(func(_on): rebuild_at_phase())
	options.add_child(water)
	for title in Exhibit.Heart.STAGES: heart_stage.add_item(title)
	heart_stage.item_selected.connect(func(_index): rebuild_at_phase())
	options.add_child(heart_stage)
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
	formation.visible=selection.selected<3
	targets.visible=formation.visible
	heart_stage.visible=selection.selected in [4,5]
	water.visible=selection.selected in [6,7]
	var center:=Vector3(3.5,.55,1.5) if selection.selected==5 else Vector3(0,1.6,0) if selection.selected==4 else Vector3(0,.78,0)
	camera.position=center+(Vector3(0,4.1,7.4) if selection.selected==5 else Vector3(2.5,3.42,6.8))
	camera.look_at(center)
	camera.size=3.7 if selection.selected==5 else 5.8 if selection.selected==4 else 2.35 if selection.selected>5 else float([2.35,3.,3.7][formation.selected])

func duration() -> float:
	return 16.0 if selection.selected>=4 else CYCLE

func refresh_ambient() -> void:
	if not is_instance_valid(exhibit) or mode.selected!=1: return
	var values: Dictionary=world.developer_tuning.ambient_values()
	if values==captured_values: return
	captured_values=values
	exhibit.configure(Exhibit.GROUPS[selection.selected-4],captured_values,clock)
	viewport.render_target_update_mode=SubViewport.UPDATE_ONCE

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
	if selection.selected>=4:
		var group: String=Exhibit.GROUPS[selection.selected-4]
		exhibit=Exhibit.new()
		scene.add_child(exhibit)
		exhibit.create(group,water.button_pressed,heart_stage.selected)
		if group=="heart": exhibit.frame_heart(camera,heart_stage.selected)
		captured_values=tune.ambient_values() if mode.selected==1 else {}
		exhibit.configure(group,captured_values,0.)
		started=true
		running=advance
		seek(0)
		return
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
	if is_instance_valid(exhibit):
		captured_values=world.developer_tuning.ambient_values() if mode.selected==1 else {}
		exhibit.configure(Exhibit.GROUPS[selection.selected-4],captured_values,clock)
		viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
	else: rebuild_at_phase()

func rebuild_at_phase() -> void:
	if not started: return
	var previous_time:=clock
	play(running)
	seek(previous_time)

func seek(seconds: float) -> void:
	clock=clampf(seconds,0,duration())
	if is_instance_valid(exhibit): exhibit.seek(clock)
	for sample in samples:
		sample.root.visible=clock<sample.life
		Contacts.pose(sample,clock)
	phase.text="%d ms   ·   %s"%[roundi(clock*1000),"Playing" if running else "Paused"]
	viewport.render_target_update_mode=SubViewport.UPDATE_ONCE

func pause_resume() -> void:
	if not world.developer_tuning.authorized(world):return
	if not started or clock>=duration(): play(true); return
	running=not running
	seek(clock)

func single_step() -> void:
	if not world.developer_tuning.authorized(world):return
	if not started or clock>=duration(): play(false)
	running=false
	seek(clock+FRAME)

func stop() -> void:
	if is_instance_valid(exhibit):
		exhibit.hide()
		exhibit.queue_free()
		exhibit=null
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
	if clock+delta>=duration():
		if repeat.button_pressed:
			var next_time:=fposmod(clock+delta,duration())
			var tune=world.developer_tuning
			if selection.selected<3 and mode.selected==1 and (captured_values!=tune.contact_values() or not is_equal_approx(captured_emission,tune.applied(Tune.IMPACT))):
				play(true)
			seek(next_time)
		else: stop()
	else: seek(clock+delta)
