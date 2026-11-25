extends VBoxContainer
## Only a local camera, reference targets and cosmetic meshes enter this viewport.
const Contacts = preload("res://contact_particles.gd")
const Tune = preload("res://developer_arena/tuning.gd")
const Exhibit = preload("res://developer_arena/garden_exhibit.gd")
const Shelter=preload("res://shelter_visuals.gd")
const Affinities=preload("res://affinity_glyphs.gd")
const Fire=preload("res://fire_combat.gd")
const Thorn=preload("res://thorn_affinity.gd")
const Frost=preload("res://frost_balance.gd")
const AFFINITY_START:=11
const AFFINITY_KINDS:=["fire","open","thorn","burning","brittle","bleeding","patch"]+Shelter.PREVIEWS
var affinity_samples:Array[MeshInstance3D]=[]
const WEAPON_SEQUENCE := 9
const DODGE := 10
const DODGE_LIFE := preload("res://weapon_delivery_visuals.gd").DODGE_DURATION
var scuff: MeshInstance3D
const WeaponExhibit = preload("res://developer_arena/weapon_exhibit.gd")
var weapon_exhibit: Node3D
var weapon_choice := OptionButton.new()
var variant_choice := OptionButton.new()
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
	for item in ["Weapon contact · melee","Weapon contact · projectile","Brittle rupture","Equipped skill replay","Heart fissure","Root energy","Water Intake","Living Sprinkler","Pollination Bloom","Reviewed weapon sequence","Dodge foot scuff","Ember Wake","Rime Bloom · both phases","Thorn Line","Burning · target","Brittle · two stacks","Bleed · target","Thorn Form patch"]+Shelter.TITLES:
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
	for role in WeaponExhibit.Classes.DEFINITIONS:
		for weapon in role.weapons: weapon_choice.add_item(weapon.name)
	options.add_child(weapon_choice)
	for name_text in ["First attack","Follow-up"]: variant_choice.add_item(name_text)
	options.add_child(variant_choice)
	weapon_choice.item_selected.connect(func(_index): rebuild_at_phase())
	variant_choice.item_selected.connect(func(_index): rebuild_at_phase())
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
	formation.visible=selection.selected<3 or selection.selected>=AFFINITY_START
	targets.visible=formation.visible
	weapon_choice.visible=selection.selected==WEAPON_SEQUENCE
	variant_choice.visible=weapon_choice.visible
	heart_stage.visible=selection.selected in [4,5]
	water.visible=selection.selected in [6,7]
	var center:=Vector3(3.5,.55,1.5) if selection.selected==5 else Vector3(0,1.6,0) if selection.selected==4 else Vector3(0,.78,0)
	camera.position=center+(Vector3(0,4.1,7.4) if selection.selected==5 else Vector3(2.5,3.42,6.8))
	camera.look_at(center)
	camera.size=3.7 if selection.selected==5 else 5.8 if selection.selected==4 else 2.35 if selection.selected>5 else float([2.35,3.,3.7][formation.selected])

	if selection.selected>=AFFINITY_START:
		frame_affinity()
	if selection.selected==DODGE:
		camera.look_at(Vector3(0,.12,0))
		camera.size=1.9
	if weapon_choice.visible:
		camera.position=Vector3(5.,3.4,4.1)
		camera.look_at(Vector3(0,1.,.6))
		camera.size=3.15

func frame_affinity() -> void:
	camera.look_at(Vector3(0,.6,0))
	camera.size=float([3.3,4.6,5.8][formation.selected])

func duration() -> float:
	if selection.selected>=AFFINITY_START:
		match AFFINITY_KINDS[selection.selected-AFFINITY_START]:
			"dewfall":return preload("res://water_combat.gd").WAVE_MS*.001
			"riptide","riptide_return":return preload("res://water_tidal_return.gd").PHASE_MS*.001
			"ironbark","vital_bloom":return .55
			"wood_fragment","bark_contact":return .32
			"vital_heal":return .78
			"fire": return Fire.FIELD_MS*.001
			"open": return Affinities.OPEN_SECONDS+.42
			"thorn": return Thorn.LIFETIME.core*.001
			"patch": return Thorn.LIFETIME.form*.001
			_: return 3.0
	if selection.selected==WEAPON_SEQUENCE:
		return weapon_exhibit.duration+.3 if is_instance_valid(weapon_exhibit) else 1.
	return 16.0 if selection.selected in range(4,9) else CYCLE

func refresh_ambient() -> void:
	if not affinity_samples.is_empty() and mode.selected==1:
		var latest:Dictionary=world.developer_tuning.affinity_values()
		if latest!=captured_values:
			captured_values=latest
			for glyph in affinity_samples:
				if glyph.has_meta("shelter_kind"):Shelter.configure(glyph,latest)
				else:Affinities.configure(glyph,latest)
			seek(clock)
	if is_instance_valid(scuff) and mode.selected==1:
		captured_values=world.developer_tuning.motion_values()
		seek(clock)
	if is_instance_valid(weapon_exhibit) and mode.selected==1 and captured_values!=world.developer_tuning.motion_values():
		rebuild_at_phase()
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
	if selection.selected>=AFFINITY_START: frame_affinity()
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
	if selection.selected>=AFFINITY_START:
		var kind:String=AFFINITY_KINDS[selection.selected-AFFINITY_START]
		var dims:=Vector2.ONE*.55
		match kind:
			"fire": dims=Vector2(Fire.HALF_LENGTH,Fire.WIDTH)
			"thorn": dims=Vector2(Thorn.CORE_HALF_LENGTH,Thorn.CORE_WIDTH)
			"patch": dims=Vector2.ONE*Thorn.RADIUS.form
			"open": dims=Vector2.ONE*Frost.BLOOM_RADIUS
		captured_values=tune.affinity_values() if mode.selected==1 else {}
		for point in origins():
			var offset:=Vector3.UP*.24 if kind in Affinities.STATUS else Vector3.ZERO
			var seed_value:=17+affinity_samples.size()
			if kind in Shelter.PREVIEWS:
				var width:=preload("res://water_combat.gd").WAVE_RADIUS if kind=="dewfall" else preload("res://water_tidal_return.gd").BASE_WIDTH
				if kind=="riptide_return":width*=preload("res://water_tidal_return.gd").RETURN_WIDTH_SCALE
				if kind=="vital_bloom":width=preload("res://vital_combat.gd").CORE_RADIUS
				var heading:=Vector3.RIGHT if kind!="riptide_return" else Vector3.LEFT
				var glyph:=Shelter.create(scene,kind,point,width,heading,seed_value,captured_values,.65)
				glyph.set_meta("home",point)
				glyph.set_meta("direction",heading)
				affinity_samples.append(glyph)
				continue
			affinity_samples.append(Affinities.create(scene,kind,point+offset,dims,0.,seed_value,captured_values,2))
			if kind=="open":
				affinity_samples.append(Affinities.create(scene,"close",point,dims,0.,seed_value,captured_values))
		started=true
		running=advance
		seek(0)
		return
	if selection.selected==DODGE:
		scuff=MeshInstance3D.new()
		scuff.mesh=ImmediateMesh.new()
		scuff.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		scuff.material_override=world.stage.get_node("CombatEffects").material(WeaponExhibit.Delivery.SCUFF_TINT,0.)
		scene.add_child(scuff)
		captured_values=tune.motion_values() if mode.selected==1 else {}
		started=true
		running=advance
		seek(0.)
		return
	if selection.selected==WEAPON_SEQUENCE:
		weapon_exhibit=WeaponExhibit.new()
		scene.add_child(weapon_exhibit)
		captured_values=tune.motion_values() if mode.selected==1 else {}
		weapon_exhibit.build(world.stage,weapon_choice.selected/3,weapon_choice.selected%3,variant_choice.selected,captured_values)
		started=true
		running=advance
		seek(0)
		return
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
	for glyph in affinity_samples:
		var phase_time:=clock
		var end:=duration()
		if glyph.has_meta("shelter_kind"):
			glyph.visible=clock<end
			if str(glyph.get_meta("shelter_kind")) in Shelter.TRAVEL:
				glyph.position=Vector3(glyph.get_meta("home"))+Vector3(glyph.get_meta("direction"))*(clock/end-.5)*1.6
			Shelter.seek(glyph,clock,end)
			continue
		var phase_id:int=glyph.material_override.get_shader_parameter("effect")
		if phase_id==Affinities.PHASES.find("open"):end=Affinities.OPEN_SECONDS
		if phase_id==Affinities.PHASES.find("close"):phase_time-=Affinities.OPEN_SECONDS
		glyph.visible=phase_time>=0. and clock<end
		if glyph.visible: Affinities.seek(glyph,phase_time,end-clock)
	if is_instance_valid(scuff):
		scuff.visible=clock<DODGE_LIFE
		if scuff.visible:
			var mesh:=scuff.mesh as ImmediateMesh
			mesh.clear_surfaces()
			mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
			WeaponExhibit.Delivery.foot_scuff(mesh,Vector3.ZERO,Vector3.RIGHT,clock/DODGE_LIFE,captured_values.get("dodge.dust",WeaponExhibit.Delivery.CONTROLS["dodge.dust"][0]))
			mesh.surface_end()
	if is_instance_valid(weapon_exhibit): weapon_exhibit.seek(clock)
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
	for glyph in affinity_samples:
		glyph.hide()
		glyph.queue_free()
	affinity_samples.clear()
	if is_instance_valid(scuff):
		scuff.hide()
		scuff.queue_free()
		scuff=null
	if is_instance_valid(weapon_exhibit):
		weapon_exhibit.hide()
		weapon_exhibit.queue_free()
		weapon_exhibit=null
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
