extends Node3D

const WeaponMotion=preload("res://weapon_motion.gd")
const GardenScenery=preload("res://garden_scenery.gd")
const Frames = preload("res://weapon_frames.gd")
const Campaign = preload("res://campaign.gd")
const Battlefield = preload("res://battlefield.gd")
const EncounterConfig=preload("res://encounter_config.gd")
const PACK_STRIDE := EncounterConfig.PACK_STRIDE

const WILD_OFFSET := Vector3(80, 0, 0)
const Enemies = preload("res://enemy_catalog.gd")
var enemy_scenes := {}
const ROCK = preload("res://assets/root_stone.glb")
const PINE = preload("res://assets/root_tree.glb")
const SNAG = preload("res://assets/root_snag.glb")
const RUIN = preload("res://assets/wild_ruin.glb")
const Classes = preload("res://class_catalog.gd")
const Parts = preload("res://weapon_parts.gd")
const Seeds = preload("res://seed_catalog.gd")
const FLAGSTONES = preload("res://assets/wild_path.glb")
const WILD_BOUNDS := Vector2(25.0, 23.0)
const WILD_ENTRY := Vector3(0, 0, -11.8)
const WILD_EXIT := Vector3(0, 0, -13.9)
const SUPPORT_SPAWNS := [Vector3(-5.9, 0, 3.0), Vector3(6.5, 0, 2.5),
	Vector3(-9.5, 0, 7.0), Vector3(9.5, 0, 7.0), Vector3(0, 0, 10.2),
	Vector3(-13.5, 0, 3.3), Vector3(13.5, 0, 3.3), Vector3(5.4, 0, 11.3)]
const SPAWN := Vector3(0, 0, 5)
const GATE := Vector3(0, 0, -6)
const GRAFT_ALTAR := Vector3(-4.6, 0, 2.4)
const DEEPER_GATE := Vector3(0, 0, 13.2)
const HEART := Vector3(0, 0, 0)
const HEART_STATIONS := {"seed_archive":Vector3(7.2,0,-4.2),"monster_studies":Vector3(-7.8,0,1),"living_archive":Vector3(0,0,9.2)}
const ALTAR := Vector3(-3.5, 0, -2)
const PLOTS := [Vector3(3.6, 0, -1.6), Vector3(3.6, 0, 2.6), Vector3(-3.6, 0, 2.6), Vector3(-5.0,0,-5.0), Vector3(0,0,6.4), Vector3(5.7,0,5.4), Vector3(-6,0,5.6), Vector3(7.9,0,1.7), Vector3(3.3,0,-6.8)]
const ENEMY_START := Vector3(0, 0, 5.4)

@onready var camera: Camera3D = $Camera
var avatars := {}
var avatar_models := {}
var foe_model: Dictionary
var scout_models: Array[Dictionary] = []
var crops: Array[Node3D] = []
var foe: Node3D
var support_models: Array[Node3D] = []
var support_rings: Array[MeshInstance3D] = []
var support_binds: Array[MeshInstance3D] = []
var support_hp: Array[int] = []
var terrain: Node3D
var scenery_materials: Dictionary={}
var wilderness_base: MeshInstance3D
var trail: MeshInstance3D
var visual_field := Battlefield.new()
var seed_cache: Node3D
var cache_kernels: Array[Node3D] = []
var cache_label: Label3D
var terrain_key := Vector3i(-1, -1, -1)
var support_hit_until: Array[int] = []
var last_foe_hp := 0
var foe_hit_until := 0
var seed: Node3D
var attack_ring: MeshInstance3D
var garden_portal: Node3D
var wild_portal: Node3D
var deeper_gate: Node3D
var graft_altar: Node3D
var wild_floor: StandardMaterial3D
var briar_vines: MeshInstance3D
var longlimb_legs: Node3D
var heart_phase := 0
var heart_tech_key := ""
var heart_stations := {}
var heart_unlocked: Array=[]
var heart_size := 0.9
var heart_core: MeshInstance3D
var heart_tree: Node3D
var heart_seed: MeshInstance3D
var garden_floor: ShaderMaterial
var garden_disc: MeshInstance3D
var garden_edge: Node3D
var garden_tier := -1
var active_plots := 3
var occupied_offshoots: Array=[]
var garden_extent := 11.5
var garden_beds: Node3D
var plot_key := ""
var returning_corruption: Node3D
var offshoot_models: Array[Node3D] = []
var scenery: Array[Node3D] = []
var crown: Node3D
var foe_surface: StandardMaterial3D
const FLOORS := [Color("#66503a"), Color("#514735"), Color("#4d433c"), Color("#4c3632")]
const FOE_COLORS := [Color("#dc618b"), Color("#91a054"), Color("#b78de8"), Color("#fc9d73")]


static func make_environment() -> Environment:
	var env := Environment.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("#1c2f33")
	sky_mat.sky_horizon_color = Color("#3b4a3a")
	sky_mat.sky_curve = 0.12
	sky_mat.ground_bottom_color = Color("#141d17")
	sky_mat.ground_horizon_color = Color("#2a3528")
	sky_mat.ground_curve = 0.2
	sky_mat.sun_angle_max = 40.0
	sky_mat.energy_multiplier = 0.85
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 0.6
	env.ambient_light_color = Color("#9fb4c4")
	env.ambient_light_energy = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.08
	env.tonemap_white = 1.3
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = Color("#2d3c38")
	env.fog_sun_scatter = 0.1
	env.fog_density = 0.9
	env.fog_depth_begin = 34.0
	env.fog_depth_end = 92.0
	env.fog_depth_curve = 1.6
	env.adjustment_enabled = true
	env.adjustment_brightness = 1.02
	env.adjustment_contrast = 1.08
	env.adjustment_saturation = 0.88
	return env


func _ready() -> void:
	if has_node("WorldEnvironment"):
		$WorldEnvironment.environment = make_environment()
	if has_node("Sun"):
		var sun := $Sun as DirectionalLight3D
		sun.light_color = Color("#ffe9c6")
		sun.light_energy = 1.35
		sun.shadow_enabled = true
		sun.shadow_bias = 0.04
		sun.shadow_blur = 1.4
		sun.light_angular_distance = 1.2
	garden_floor = build_circular_garden()
	wild_floor = build_wilderness_ground()
	build_garden_gateway()
	deeper_gate = build_wild_gateway(DEEPER_GATE, "GO DEEPER", Color("#ef9690"))
	wild_portal=build_gate_swirl(deeper_gate,WILD_OFFSET+DEEPER_GATE)
	var heart := HEART
	heart_tree = build_heart_growth()
	heart_seed = sphere(heart + Vector3.UP * 0.3, 0.31, Color("#8ff5ad"))
	returning_corruption = Node3D.new()
	add_child(returning_corruption)
	for i in 6:
		var angle := TAU * float(i) / 6.0
		var radial := Vector3(cos(angle), 0, sin(angle))
		var root := box(heart + radial * 1.25 + Vector3.UP * 0.7,
			Vector3(0.26, 1.6, 0.34), Color("#713451"))
		root.rotation_degrees.z = 31.0
		root.rotation.y = angle
		root.reparent(returning_corruption)
	returning_corruption.hide()
	build_campaign_scenery()
	build_tactical_cover()
	var altar_model := preload("res://garden_visuals.gd").altar(self)
	graft_altar = preload("res://assets/altar.glb").instantiate() as Node3D
	add_child(graft_altar)
	graft_altar.position = WILD_OFFSET + GRAFT_ALTAR
	marker(Vector3.UP * 2.2, "GRAFTING SHRINE", graft_altar)
	var shrine_ring := TorusMesh.new()
	shrine_ring.inner_radius = 0.95
	shrine_ring.outer_radius = 1.08
	var shrine_base := mesh(shrine_ring, Vector3.ZERO, Color("#a3c4ba"))
	shrine_base.reparent(graft_altar,false)
	shrine_base.position.y = 0.06
	var shrine_material := shrine_base.material_override as StandardMaterial3D
	shrine_material.emission_enabled = true
	shrine_material.emission = Color("#52786b")
	shrine_material.emission_energy_multiplier = 0.35
	graft_altar.hide()
	seed_cache = build_cache_model()
	seed_cache.hide()
	marker(ALTAR + Vector3.UP * 1.8, "ALTAR")
	garden_beds = Node3D.new()
	add_child(garden_beds)
	foe = Node3D.new()
	add_child(foe)
	foe.position = WILD_OFFSET + ENEMY_START
	foe_model = {}
	ensure_enemy(foe, foe_model, 0)
	foe_surface = foe_model.tint
	crown = Node3D.new()
	foe.add_child(crown)
	longlimb_legs = Node3D.new()
	foe.add_child(longlimb_legs)
	longlimb_legs.hide()
	seed = build_seed_model()
	seed.scale = Vector3.ONE * 1.35
	var ring := TorusMesh.new()
	ring.inner_radius = 0.90
	ring.outer_radius = 1.0
	attack_ring = mesh(ring, Vector3.ZERO, Color("#ff7854"))
	var material := attack_ring.material_override as StandardMaterial3D
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	attack_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	attack_ring.hide()
	for i in EncounterConfig.MAX_SCOUTS:
		var scout := Node3D.new()
		add_child(scout)
		scout.scale = Vector3.ONE * 0.73
		support_models.append(scout)
		var actor := {}
		ensure_enemy(scout, actor, 0)
		scout_models.append(actor)
		support_hp.append(0)
		support_hit_until.append(0)
		var warning := mesh(ring, Vector3.ZERO, Color("#ffa862"))
		warning.material_override = material.duplicate()
		warning.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		support_rings.append(warning)
	var bind_mesh := TorusMesh.new()
	bind_mesh.inner_radius = 0.67
	bind_mesh.outer_radius = 0.8
	briar_vines = mesh(bind_mesh, Vector3.ZERO, Color("#7cdbdb"))
	briar_vines.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	briar_vines.hide()
	for i in EncounterConfig.MAX_SCOUTS:
		var bind := mesh(bind_mesh, Vector3.ZERO, Color("#7cdbdb"))
		bind.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		support_binds.append(bind)
	focus(Vector3.ZERO, false)


func focus(origin: Vector3, wild: bool, delta: float = 1.0) -> void:
	if has_node("Sun"):
		$Sun.light_color=Color("#ffe9c6") if wild else Color("#fff4dc")
		$Sun.light_energy=1.35 if wild else 1.05
	if has_node("WorldEnvironment"):
		$WorldEnvironment.environment.adjustment_saturation=.88 if wild else .98
		$WorldEnvironment.environment.ambient_light_energy=.9 if wild else 1.05
	var target := origin
	if not wild:
		target = garden_camera_target(origin, garden_extent)
	var shot: Dictionary=get_meta("garden_growth_camera",{}) if not wild else {}
	if not shot.is_empty():target=shot.target
	var desired := target + Vector3(3.3, 14, 14)
	var blend := 1.0 if camera.position.distance_to(desired) > 28.0 else 1.0 - exp(-(6.0 if wild else 3.0) * delta)
	camera.size = lerpf(camera.size, float(shot.get("size",16.5)), blend)
	camera.position = camera.position.lerp(desired, blend)
	camera.look_at(camera.position - Vector3(3.3, 14, 14))


func draw_state(players: Dictionary, local_id: int, enemy: Vector3, hp: int,
		winding_up: bool, strike_radius: float, drop: Vector3, has_drop: bool, planted: Array, depth: int, route_rooms: int, show_graft_altar: bool, briar_bound: bool, longlimb: bool, campaign: PackedInt32Array, pack: PackedFloat32Array, delta: float, view_id: int=-1) -> void:
	var now := Time.get_ticks_msec()
	for id in avatars.keys():
		if not players.has(id):
			avatars[id].queue_free()
			avatars.erase(id)
			avatar_models.erase(id)
	for id in players:
		if not avatars.has(id):
			var avatar := Node3D.new()
			add_child(avatar)
			avatars[id] = avatar
			var actor := preload("res://traveller_avatar.gd").build(avatar)
			actor.look_key = ""
			avatar_models[id] = actor
			marker(Vector3.UP * 1.85, "YOU" if id == local_id else "ALLY", avatar)
			actor.name_label=avatar.find_children("*","Label3D",true,false)[0]
		var p: Dictionary = players[id]
		var offset := WILD_OFFSET if p.wild else Vector3.ZERO
		var actor: Dictionary = avatar_models[id]
		actor.name_label.text="YOU" if id==local_id else str(p.get("display_name",p.get("character",{}).get("name","Wanderer")))
		if p.get("fallen",false): actor.name_label.text+=" · FALLEN"
		actor.name_label.modulate=[Color("d8edb3"),Color("a3d5ef"),Color("e5bcf2"),Color("efcf9f")][clampi(int(p.get("party_slot",0)),0,3)]
		update_avatar(avatars[id], actor, p, offset + p.pos, now, delta)
		var effect: Dictionary=p.get("skill_fx",{})
		if p.wild and not effect.is_empty() and not effect.get("event_driven",false) and int(effect.get("seq",0))!=int(actor.get("skill_fx_seq",-1)):
			actor.skill_fx_seq=int(effect.seq)
			emit_skill_effect(WILD_OFFSET+Vector3(effect.pos),float(effect.radius),Color(effect.color))

	var camera_id:=view_id if view_id>=0 else local_id
	if players.has(camera_id):
		var wild: bool = players[camera_id].wild
		var player_position: Vector3 = avatars[camera_id].position - WILD_OFFSET
		var center: Vector3 = WILD_OFFSET + Vector3(player_position.x,
			0, player_position.z) if wild else avatars[camera_id].position
		focus(center, wild, delta)
	deeper_gate.visible = campaign[0] != Campaign.HEART
	graft_altar.visible = show_graft_altar
	if garden_portal: garden_portal.visible=true
	if wild_portal:
		var cleared: bool=hp<=0
		for index in range(0,pack.size(),PACK_STRIDE):
			if pack[index+2]>0: cleared=false
		wild_portal.visible=cleared and campaign[0]!=Campaign.HEART
	var site := campaign[0]
	var boss: int=campaign[EncounterConfig.BOSS_KIND] if campaign.size()>EncounterConfig.BOSS_PHASE else -1
	var phase: int=campaign[EncounterConfig.BOSS_PHASE] if campaign.size()>EncounterConfig.BOSS_PHASE else 0
	var rendered_lair := Vector2i(boss,phase)
	var map_key := Vector3i(site, depth, campaign[8])
	if terrain_key != map_key or get_meta("rendered_lair",Vector2i(-2,-2)) != rendered_lair:
		terrain_key = map_key
		redraw_terrain(site, depth, campaign[8],boss,phase)
		set_meta("rendered_lair",rendered_lair)
	seed_cache.visible = visual_field.procedural and site != Campaign.HEART
	var claimed: bool = players.get(local_id, {}).get("cache_claimed", false)
	for kernel in cache_kernels:
		kernel.visible = not claimed
	cache_label.text = "SEARCHED POD" if claimed else "ABANDONED SEED POD"
	seed_cache.position = WILD_OFFSET + visual_field.cache

	for i in scenery.size():
		scenery[i].visible = i == site
	ensure_enemy(foe, foe_model, campaign[18] if campaign.size() > 18 else 0)
	ensure_finale_form(foe_model,site==Campaign.HEART)
	preload("res://elite_enemy.gd").decorate(self,foe_model,boss<0 and site!=Campaign.HEART)
	foe_surface = foe_model.tint
	if hp > 0 and hp < last_foe_hp:
		foe_hit_until = now + 115
	elif hp > last_foe_hp:
		foe_hit_until = 0
	last_foe_hp = hp
	foe_model.hit_until = foe_hit_until
	foe_surface.albedo_color = Color.WHITE if now < foe_hit_until else Color(Enemies.get_kind(foe_model.kind).core)
	var guardian := site == Campaign.HEART or depth == route_rooms
	var expedition_boss: bool=boss>=0
	crown.visible = guardian and hp>0
	foe.scale = Vector3.ONE * (float(Enemies.get_kind(foe_model.kind).get("model_scale",1.0)) if expedition_boss else 1.9 if guardian else (1.0 if depth == 1 else 1.22))
	heart_tree.visible = campaign[5] == Campaign.UNFINISHED
	var pulse := 1.0 + 0.023 * sin(now * 0.0018) + 0.008 * sin(now * 0.0047 + 0.8)
	heart_tree.scale = Vector3(heart_size * pulse, heart_size * (2.0 - pulse), heart_size * pulse)
	if heart_core != null:
		(heart_core.material_override as StandardMaterial3D).emission_energy_multiplier = 0.04 + heart_phase * 0.02 + (pulse - 0.98) * 0.6
	heart_seed.visible = campaign[5] == Campaign.SEED
	returning_corruption.visible = campaign[5] == Campaign.CORRUPTION
	garden_floor.set_shader_parameter("tint",Color("#8b6a57") if returning_corruption.visible else Color.WHITE)
	for i in offshoot_models.size():
		var state := campaign[2 + i]
		var sapling := offshoot_models[i]
		sapling.visible = Campaign.LEGACY_ENDING_ENABLED and (state == Campaign.GROWING or state == Campaign.MATURE) and not occupied_offshoots.has(i)
		sapling.scale.y = 1.0 if state == Campaign.MATURE else 0.44
	longlimb_legs.visible = longlimb
	foe.visible = hp > 0
	var attack_poses: Dictionary=get_meta("enemy_attack_poses",{})
	animate_enemy(foe, foe_model, WILD_OFFSET + enemy, winding_up, delta,attack_poses.get(-1,{}))
	attack_ring.visible = winding_up and hp > 0 and (boss>=22 or site==Campaign.HEART)
	var warning_position := Vector3(campaign[EncounterConfig.LANDING_X] / 100.0, 0, campaign[EncounterConfig.LANDING_Z] / 100.0) if campaign.size() > EncounterConfig.ATTACK_MODE and campaign[EncounterConfig.ATTACK_MODE] != 0 else enemy
	attack_ring.position = WILD_OFFSET + warning_position + Vector3.UP * 0.06
	attack_ring.scale = Vector3(strike_radius, 0.25, strike_radius)
	briar_vines.visible = briar_bound and hp > 0
	briar_vines.position = WILD_OFFSET + enemy + Vector3.UP * 0.13
	for i in support_models.size():
		var start := i * PACK_STRIDE
		var health := int(pack[start + 2]) if start < pack.size() else 0
		var active := health > 0
		if active and health < support_hp[i]:
			support_hit_until[i] = now + 115
		elif health > support_hp[i]:
			support_hit_until[i] = 0
		support_hp[i] = health
		var actor: Dictionary = scout_models[i]
		ensure_enemy(support_models[i], actor, campaign[19 + i] if campaign.size() > 19 + i else 0)
		actor.hit_until = support_hit_until[i]
		var surface: StandardMaterial3D = actor.tint
		var ranged := active and pack[start + 5] > 0.0
		var hasted := active and (int(pack[start + 4]) & 2) != 0
		surface.emission_enabled = ranged or hasted
		surface.emission = Color("#72a745") if hasted else Color(Enemies.get_kind(actor.kind).glow) if ranged else Color.BLACK
		surface.emission_energy_multiplier = 0.65 if hasted else 0.45 if ranged else 0.0
		surface.albedo_color = Color("#fff0d8") if now < support_hit_until[i] else (
			Color(Enemies.get_kind(actor.kind).core))
		support_models[i].visible = active
		# Authored warnings already show the actual shape and reach of the attack.
		support_rings[i].visible = active and pack[start + 3] > 0.0 and not attack_poses.has(i)
		support_binds[i].visible = active and (int(pack[start + 4]) & 1) != 0
		if active:
			var p := WILD_OFFSET + Vector3(pack[start], 0.0, pack[start + 1])
			animate_enemy(support_models[i], actor, p, pack[start + 3] > 0.0, delta,attack_poses.get(i,{}))
			var impact := WILD_OFFSET + Vector3(pack[start + 6], 0.06, pack[start + 7])
			var radius := Enemies.radius(int(actor.kind), int(actor.mask))
			(support_rings[i].material_override as StandardMaterial3D).albedo_color = Color("#99ca76") if Enemies.get_kind(actor.kind).role == "chant" else Color("#ffa862")
			support_rings[i].position = impact
			support_rings[i].scale = Vector3(radius, 0.25, radius)
			support_binds[i].position = p + Vector3.UP * 0.13
	seed.visible = has_drop
	seed.position = WILD_OFFSET + drop + Vector3.UP * (0.38 + sin(now * 0.002) * 0.06)
	seed.rotation.y = now * 0.0004
	pass # Plot presentation is driven by individual bed snapshots.


func build_actor(parent: Node3D, scene: PackedScene, leg_prefix: String, count: int) -> Dictionary:
	var model := scene.instantiate() as Node3D
	parent.add_child(model)
	var legs: Array[Node3D] = []
	for i in count:
		var leg := model.find_child(leg_prefix + str(i), true, false) as Node3D
		if leg != null:
			legs.append(leg)
	var arms: Array[Node3D] = []
	var hand_names := ["AdventurerHand", "AdventurerHand_001"]
	for i in 2:
		var sleeve := model.find_child("AdventurerSleeve" + str(i), true, false) as Node3D
		if sleeve == null:
			continue
		var pivot := Node3D.new()
		sleeve.get_parent().add_child(pivot)
		pivot.position = sleeve.position + Vector3(0, 0.13, 0)
		sleeve.reparent(pivot, true)
		var hand := model.find_child(hand_names[i], true, false) as Node3D
		if hand != null:
			hand.reparent(pivot, true)
		arms.append(pivot)
	return {"model": model, "legs": legs, "arms": arms, "phase": 0.0, "pace": 0.0,
		"last": Vector3.INF, "windup": 0.0}


func tint_mesh(root: Node3D, mesh_name: String, color: Color) -> StandardMaterial3D:
	var surface := StandardMaterial3D.new()
	surface.albedo_color = color
	surface.roughness = 0.83
	var target := root.find_child(mesh_name, true, false) as MeshInstance3D
	if target != null:
		target.material_override = surface
	return surface


func slide_actor(root: Node3D, actor: Dictionary, target: Vector3, delta: float,velocity_hint: Vector3=Vector3.INF) -> Vector3:
	var rendered_before:=root.position
	var previous: Vector3 = actor.last
	var motion := Vector3.ZERO if previous == Vector3.INF or previous.distance_to(target) > 4.0 else target - previous
	if previous == Vector3.INF or root.position.distance_to(target) > 4.0:
		root.position = target
	else:
		root.position = root.position.lerp(target, 1.0 - exp(-28.0 * delta))
	var visible_motion:=root.position-rendered_before if previous!=Vector3.INF and previous.distance_to(target)<=4.0 else Vector3.ZERO
	var speed := velocity_hint.length() if velocity_hint!=Vector3.INF else visible_motion.length()/maxf(delta,.001)
	actor.speed = lerpf(float(actor.get("speed", 0.0)), speed, minf(1.0, 12.0 * delta))
	actor.pace = lerpf(actor.pace, clampf(speed * 0.21, 0.0, 1.0), minf(1.0, 9.0 * delta))
	actor.phase += delta * (3.0 + float(actor.pace) * 11.0)
	actor.last = target
	return visible_motion


func update_avatar(root: Node3D, actor: Dictionary, player: Dictionary, position: Vector3, now: int, delta: float) -> void:
	var speed_hint: Vector3=player.get("velocity",Vector3.INF)
	var travel:=slide_actor(root,actor,position,delta,Vector3.INF if speed_hint.is_zero_approx() else speed_hint)
	actor.gait_vector=travel
	actor.gait_phase=fposmod(float(actor.get("gait_phase",0.0))+travel.length()/2.0,1.0)
	actor.gait_travel=travel.length()
	apply_appearance(actor, Array(player.get("character", {}).get("appearance", player.get("appearance", [0,0,0,0,0]))))
	var pose: int = player.get("pose", 0)
	var yaw := deg_to_rad(float(pose & 511))
	var swing := float(pose >> 9) / 24.0
	if player.has("facing"):
		var facing: Vector3 = player.facing
		yaw = atan2(facing.x, facing.z)
		if player.has("swing_until"):
			swing = clampf((int(player.swing_until) - now) / 240.0, 0.0, 1.0)
	var animation: Dictionary=player.get("attack_anim",{})
	if player.has("attack_until"):
		var remaining:=int(player.attack_until)-now
		animation={"active":remaining>0,"phase":clampf(1.0-remaining/float(maxi(1,int(player.get("attack_duration",240)))),0,1),"combo":int(player.get("attack_combo",0)),"duration":int(player.get("attack_duration",240)),"reach":player.get("attack_reach",2.0),"direction":preload("res://mouse_combat.gd").attack_direction(player,now),"clip":player.get("attack_clip",WeaponMotion.profile(WeaponMotion.form(player)).clip),"delivery":player.get("attack_delivery","sweep"),"span":player.get("attack_span",1.9),"form":"weapon"}
		if int(player.get("cast_until",0))>now:animation=get_parent().attack_animation_snapshot(player)
	if player.get("fallen",false):animation.active=false
	var rendered_animation:=WeaponMotion.advance(actor,animation,delta)
	var active: bool=rendered_animation.active
	var attack_phase: float=rendered_animation.phase
	if animation.is_empty() and not active and swing>0: active=true;attack_phase=1.0-swing
	var motion_form: String="staff" if rendered_animation.form=="cast" else WeaponMotion.form(player)
	var motion:=WeaponMotion.pose(motion_form,attack_phase,active,int(animation.get("combo",0)))
	motion.equipped=player.get("wild",false);motion.reach=animation.get("reach",2.0);motion.clip=animation.get("clip","")
	motion.delivery=animation.get("delivery",WeaponMotion.profile(motion_form).delivery);motion.span=animation.get("span",WeaponMotion.profile(motion_form).span)
	motion.ability=rendered_animation.form=="cast"
	var direction: Variant=animation.get("direction")
	if animation.get("aim_live",false) and player.has("aim_direction"):
		direction=player.aim_direction
	if active and direction is Vector3:
		yaw=atan2(direction.x,direction.z)
	if travel.length()>maxf(delta,.001)*.24:
		actor.travel_yaw=atan2(travel.x,travel.z)
	if not active and actor.has("travel_yaw") and (actor.speed>.24 or not player.get("wild",false)):
		yaw=float(actor.travel_yaw)
	var model: Node3D = actor.model
	model.rotation.y = lerp_angle(model.rotation.y, yaw+float(motion.yaw), minf(1.0, 18.0 * delta))
	if not active:
		yaw=model.rotation.y
	motion.aim_yaw=yaw
	var dash:=clampf((float(actor.get("speed",0.0))-7.5)/8.0,0,1)
	model.position.y=0.0
	model.rotation.z=lerp_angle(model.rotation.z,PI*.48 if player.get("fallen",false) else 0.0,minf(1.0,8.0*delta))
	model.rotation.x=0.0
	var forward:=Vector3(sin(model.rotation.y),0,cos(model.rotation.y))
	model.position.x=forward.x*dash*.5;model.position.z=forward.z*dash*.5
	preload("res://traveller_avatar.gd").animate(actor,active,attack_phase,motion_form,motion,delta)
	if player.get("fallen",false): model.position.y=.3
	var class_id:=clampi(int(player.frame),0,Classes.DEFINITIONS.size()-1)
	var weapon_id:=clampi(int(player.get("weapon_kind",0)),0,Classes.DEFINITIONS[class_id].weapons.size()-1)
	var visual_key: String=str(Classes.DEFINITIONS[class_id].id)+":"+str(Classes.DEFINITIONS[class_id].weapons[weapon_id].id)
	if str(actor.get("weapon_key",""))!=visual_key:
		if actor.has("visual_weapon"): actor.visual_weapon.free()
		var visual:=preload("res://weapon_visuals.gd").build(self,class_id,weapon_id)
		visual.reparent(actor.model,false)
		visual.position=Vector3(.47,.79,.1)
		if actor.has("secondary_weapon"):actor.secondary_weapon.free();actor.erase("secondary_weapon")
		if WeaponMotion.form(player)=="knives":
			var other:=preload("res://weapon_visuals.gd").build(self,class_id,weapon_id);other.reparent(actor.model,false);actor.secondary_weapon=other
		actor.visual_weapon=visual
		actor.weapon_key=visual_key
	var visual: Node3D=actor.visual_weapon
	preload("res://weapon_visuals.gd").animate(actor,WeaponMotion.form(player),attack_phase,active,yaw,float(motion.reach),motion)
	var core:=int(player.get("core_part",player.get("weapon",0) if player.get("wild",false) else player.get("prepared",0)))
	if core>0 and core<Parts.DEFINITIONS.size() and Parts.is_plant(core):
		var seed: MeshInstance3D=visual.get_node("CoreSeed")
		(seed.material_override as StandardMaterial3D).albedo_color=Color(Seeds.DEFINITIONS[Parts.plant_source(core)].color)


func attack_material(tint: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = tint
	return material


func animate_enemy(root: Node3D, actor: Dictionary, position: Vector3, winding: bool, delta: float, cue: Dictionary={}) -> void:
	position = preload("res://glasscap_visuals.gd").motion(self,root,actor,position)
	var previous: Vector3=actor.last
	var motion := slide_actor(root, actor, position, delta)
	var model: Node3D = actor.model
	var facing:=motion
	var last_cue: Dictionary=actor.get("attack_cue",{})
	if winding and cue.has("target"):
		actor.attack_cue=cue
		if int(cue.get("pulse",0))>1 and cue.get("pulse")!=last_cue.get("pulse"):actor.windup=0.0
		facing=WILD_OFFSET+Vector3(cue.target)-position
	elif not winding and not last_cue.is_empty():
		if position.distance_to(WILD_OFFSET+Vector3(last_cue.target))<.15 and previous.distance_to(position)>.2:
			if last_cue.mode in ["pounce","vault"]:actor.jump_until=Time.get_ticks_msec()+350
			if last_cue.mode=="burrow":
				actor.burrow={"elapsed":0.0,"from":previous,"to":position,"via":WILD_OFFSET+Vector3(last_cue.via) if last_cue.has("via") else previous.lerp(position,.5)}
		actor.erase("attack_cue")
	elif not winding and motion.length()>1.5 and int(actor.mask)&Enemies.MOBILITY and get_meta("enemy_attack_poses",{}).is_empty():
		actor.jump_until=Time.get_ticks_msec()+350
	if facing.length_squared()>0.00002:
		model.rotation.y=lerp_angle(model.rotation.y,atan2(facing.x,facing.z),minf(1.0,10.0*delta))
	var brace := lerpf(float(actor.windup), 1.0 if winding else 0.0, minf(1.0, 9.0 * delta))
	actor.windup = brace
	var pace: float = actor.pace
	var phase: float = actor.phase
	model.rotation.x = 0.14 * maxf(0.0,(int(actor.get("hit_until",0)) - Time.get_ticks_msec()) / 115.0)
	var gait: String = Enemies.get_kind(actor.kind).motion
	model.position.y = absf(sin(phase)) * (0.15 if gait == "bound" else 0.065) * pace - 0.12 * brace
	model.rotation.z = 0.0
	var pose: String=cue.get("mode","")
	if pose=="pounce":model.position.y-=brace*.19
	if pose=="charge":model.rotation.x+=brace*.20
	if pose=="burrow":model.position.y-=brace*.48
	if int(actor.kind)==18 and pose=="volley" and winding:
		actor.tint.emission_enabled=true
		actor.tint.emission=Color("#d3f1ff")
		actor.tint.emission_energy_multiplier=1.1+2.5*(1.0-clampf(float(cue.get("remaining",1.0))/.35,0.0,1.0))
	elif int(actor.kind)==18 and root==foe:
		actor.tint.emission_enabled=false
	if gait == "hover":
		model.position.y = 0.15 + sin(phase * 0.7) * 0.07 - brace * 0.06
	elif gait == "sway":
		model.position.y = sin(phase * 0.4) * 0.025 - brace * 0.08
		model.rotation.z = sin(phase * 0.35) * 0.035
	elif gait == "crawl":
		model.rotation.z = sin(phase) * 0.025 * pace
	if actor.has("burrow"):
		var dive: Dictionary=actor.burrow
		dive.elapsed+=delta
		var t:=clampf(float(dive.elapsed)/.28,0.0,1.0)
		root.position=Vector3(dive.from).lerp(dive.via,t*2.0) if t<.5 else Vector3(dive.via).lerp(dive.to,t*2.0-1.0)
		model.position.y-=sin(t*PI)*.62
		if t>=1.0:actor.erase("burrow")
	var grow := (0.65 if int(actor.mask) & Enemies.JUVENILE else 1.0) * (1.0 + int(actor.growth) * 0.07)
	model.scale = Vector3(1.0 + 0.10 * brace, 1.0 - 0.08 * brace, 1.0 + 0.08 * brace) * grow
	if pose=="stomp" and int(actor.kind)==7:
		model.position.y+=brace*.21
		model.rotation.x-=brace*.26
	elif pose=="canopy_shift":
		model.rotation.x+=brace*.17
		model.position.y-=brace*.09
	elif pose in ["chant","shepherd","brood","lure","trophy_grab"]:
		model.rotation.x-=brace*(.25 if pose in ["chant","shepherd"] else -.16)
		if pose=="brood":model.scale.x+=brace*.13
		if pose=="shepherd" and int(actor.kind)==19:
			model.rotation.z+=sin(float(cue.get("remaining",0.0))*12.0)*brace*.10
	if int(actor.kind) in [20,21]:
		preload("res://boss_lair_visuals.gd").pose(actor,cue,brace)
	if int(actor.kind) in [22,23]:
		preload("res://boss_phase_visuals.gd").pose(actor,cue,brace)
	if int(actor.get("jump_until", 0)) > Time.get_ticks_msec():
		var t := 1.0 - (int(actor.jump_until) - Time.get_ticks_msec()) / 350.0
		model.position.y += sin(t * PI) * 0.7
	for i in actor.legs.size():
		var offset := PI if i == 1 or i == 2 else 0.0
		if gait == "hover":
			actor.legs[i].rotation.z = sin(phase * 2.0 + offset) * 0.42
		elif gait == "sway" or gait == "crawl":
			actor.legs[i].rotation.x = sin(phase * 0.55 + i * 1.5) * 0.13 - brace * 0.20
		else:
			actor.legs[i].rotation.x = sin(phase + offset) * 0.55 * pace - brace * 0.20


func ensure_enemy(parent: Node3D, actor: Dictionary, code: int) -> void:
	var data := Enemies.decode(code)
	if actor.is_empty() or actor.get("kind", -1) != data.kind:
		if actor.has("model"):
			actor.model.free()
		var definition := Enemies.get_kind(data.kind)
		if not enemy_scenes.has(data.kind):
			enemy_scenes[data.kind] = load("res://assets/enemies/%s.glb" % definition.id)
		var replacement := build_actor(parent, enemy_scenes[data.kind], "Root", 8)
		actor.clear()
		actor.merge(replacement)
		actor.kind = data.kind
		actor.tint = tint_mesh(actor.model, "EnemyCore", Color(definition.core))
	actor.mask = data.mask
	actor.growth = data.tier
	for group in ["Growth1", "Growth2", "AdaptReach", "AdaptBark", "AdaptSpore", "AdaptMobility"]:
		var node := actor.model.find_child(group, true, false) as Node3D
		if node == null:
			continue
		match group:
			"Growth1": node.visible = data.tier >= 1
			"Growth2": node.visible = data.tier >= 2
			"AdaptReach": node.visible = (int(data.mask) & Enemies.REACH) != 0
			"AdaptBark": node.visible = (int(data.mask) & Enemies.BARK) != 0
			"AdaptSpore": node.visible = (int(data.mask) & Enemies.SPORES) != 0
			"AdaptMobility": node.visible = (int(data.mask) & Enemies.MOBILITY) != 0

func build_tactical_cover() -> void:
	terrain = Node3D.new()
	add_child(terrain)



func redraw_terrain(site: int, depth: int, map_seed: int,boss: int=-1,phase: int=0) -> void:
	var generation_started:=Time.get_ticks_usec()
	for child in terrain.get_children():
		terrain.remove_child(child)
		child.queue_free()
	if visual_field.configured_key!=Vector3i(site,depth,map_seed) or visual_field.boss_kind!=boss or visual_field.boss_phase!=phase: visual_field.configure(site, depth, map_seed,boss,phase)
	deeper_gate.position = visual_field.advance - DEEPER_GATE
	graft_altar.position = WILD_OFFSET + visual_field.graft
	var cover := visual_field.barriers
	var random := RandomNumberGenerator.new()
	random.seed = 46213 + map_seed + site * 997 + depth * 127
	if boss!=22:
		for i in cover.size():
			build_cover(cover[i], terrain, (i + site) % 3 == 0)
	build_exploration_floor(visual_field, site,depth)
	if wilderness_base:
		var bed:=ShaderMaterial.new();bed.shader=preload("res://assets/shaders/forest_soil.gdshader");bed.set_shader_parameter("forest_bed",visual_field.procedural);apply_biome_material(bed,site,depth);wilderness_base.material_override=bed
	if visual_field.procedural:
		for link in visual_field.links:
			var a: Vector3 = visual_field.clearings[link[0]]
			var b: Vector3 = visual_field.clearings[link[1]]
			var distance := Vector2(a.x, a.y).distance_to(Vector2(b.x, b.y))
			var steps := ceili(distance / 1.6)
			for i in steps:
				if random.randf() < 0.78:
					continue
				var along := (i + 0.5) / steps
				var point := Vector2(a.x, a.y).lerp(Vector2(b.x, b.y), along)
				var p := Vector3(point.x, 0.015, point.y)
				place_asset(terrain, FLAGSTONES, p, Vector3.ONE * random.randf_range(0.58, 1.0),
					atan2(b.x - a.x, b.y - a.y) + random.randf_range(-0.3, 0.3))
		build_forest_edges(visual_field, random)
		build_root_network(visual_field)
	for i in 28:
		var point := Vector2(random.randf_range(-17.3, 17.3), random.randf_range(-12.7, 12.7))
		if covered(point, cover) or not visual_field.inside_floor(Vector3(point.x, 0, point.y), 0.5):
			continue
		place_asset(terrain, ROCK, Vector3(point.x, -0.05, point.y),
			Vector3.ONE * random.randf_range(0.08, 0.23), random.randf() * TAU)
	scatter_undergrowth(site, cover, random)
	if boss>=0: preload("res://boss_lair_visuals.gd").build(self,terrain,visual_field)
	preload("res://game_metrics.gd").record("floor_generation",{"seed":map_seed,"biome":site,"depth":depth,"terrain":preload("res://wilds_layout.gd").SIGNATURE,"entry":[visual_field.entry.x,visual_field.entry.z],"exit":[visual_field.advance.x,visual_field.advance.z],"clearings":visual_field.clearings.size(),"walkable_cells":visual_field.surface.cells.size() if visual_field.surface!=null else 0,"milliseconds":(Time.get_ticks_usec()-generation_started)/1000.})


func build_exploration_floor(field: RefCounted, site: int,depth: int=1) -> void:
	if not field.procedural:
		return
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for x in range(Battlefield.REGION.position.x * 2, (Battlefield.REGION.end.x - 1) * 2):
		for z in range(Battlefield.REGION.position.y * 2, (Battlefield.REGION.end.y - 1) * 2):
			var a := Vector3(x * 0.5, 0.008, z * 0.5)
			var b := Vector3((x + 1) * 0.5, 0.008, z * 0.5)
			var c := Vector3(x * 0.5, 0.008, (z + 1) * 0.5)
			var d := Vector3((x + 1) * 0.5, 0.008, (z + 1) * 0.5)
			clipped_ground(surface, field, [a, b, c])
			clipped_ground(surface, field, [b, d, c])
	var floor_model := MeshInstance3D.new()
	terrain.add_child(floor_model)
	floor_model.position = WILD_OFFSET
	floor_model.mesh = surface.commit()
	var material := ShaderMaterial.new()
	material.shader=preload("res://assets/shaders/forest_soil.gdshader")
	apply_biome_material(material,site,depth)
	floor_model.material_override = material


func clipped_ground(surface: SurfaceTool, field: RefCounted, triangle: Array) -> void:
	var polygon: Array[Vector3] = []
	for i in triangle.size():
		var a: Vector3 = triangle[i]
		var b: Vector3 = triangle[(i + 1) % triangle.size()]
		var da: float = field.sample_distance(a)
		var db: float = field.sample_distance(b)
		if da >= 0.0:
			polygon.append(a)
		if (da >= 0.0) != (db >= 0.0):
			polygon.append(a.lerp(b, da / (da - db)))
	for i in range(1, polygon.size() - 1):
		ground_triangle(surface, [polygon[0], polygon[i], polygon[i + 1]], [1.0, 1.0, 1.0])


func build_forest_edges(field: RefCounted, random: RandomNumberGenerator) -> void:
	for x in range(Battlefield.REGION.position.x, Battlefield.REGION.end.x, 2):
		for z in range(Battlefield.REGION.position.y, Battlefield.REGION.end.y, 2):
			var p := Vector3(x + random.randf_range(-0.36, 0.36), -0.08,
				z + random.randf_range(-0.36, 0.36))
			if field.inside_floor(p, -0.3) or not field.inside_floor(p, -2.8):
				continue
			if p.distance_to(field.extraction) < 3.0 or p.distance_to(field.advance) < 3.0:
				continue
			var asset := PINE if random.randf() > 0.29 else SNAG
			place_asset(terrain, asset, p, Vector3.ONE * random.randf_range(0.62, 1.08), random.randf() * TAU)
			if random.randf() < 0.25:
				place_asset(terrain, ROCK, p + Vector3(0.6, 0, 0.4),
					Vector3.ONE * random.randf_range(0.36, 0.65), random.randf() * TAU)
	var end: Vector3 = field.clearings.back()
	place_asset(terrain, RUIN, Vector3(end.x, 0, end.y) + Vector3.RIGHT * 2.6,
		Vector3.ONE * 0.65, random.randf() * TAU)


func scatter_undergrowth(_site: int, cover: Array, random: RandomNumberGenerator) -> void:
	var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 2400:
		var at:=Vector3(random.randf_range(-27,27),.022,random.randf_range(-26,26))
		var margin: float=visual_field.floor_distance(at)
		if margin < -1.1 or margin>3.5 or covered(Vector2(at.x,at.z),cover): continue
		var direction:=Vector3(cos(i*2.4),0,sin(i*2.4));var side:=direction.cross(Vector3.UP)
		var length:=random.randf_range(.045,.12);var width:=length*.42
		var color:=Color("#85704c").lerp(Color("#5d623e"),random.randf())
		var points: Array[Vector3]=[at-direction*length,at+side*width,at+direction*length,at-side*width,at+Vector3.UP*.008]
		for triangle in [[0,1,4],[1,2,4],[2,3,4],[3,0,4]]:
			for vertex in triangle:
				surface.set_color(color);surface.set_normal(Vector3.UP);surface.add_vertex(points[vertex])
	var litter:=MeshInstance3D.new();litter.name="ForestLeafLitter";litter.mesh=surface.commit();litter.position=WILD_OFFSET
	var material:=StandardMaterial3D.new();material.vertex_color_use_as_albedo=true;material.cull_mode=BaseMaterial3D.CULL_DISABLED;material.roughness=1
	litter.material_override=material;terrain.add_child(litter)


func covered(point: Vector2, cover: Array) -> bool:
	for rect in cover:
		if rect.grow(0.55).has_point(point):
			return true
	return false


func build_cover(rect: Rect2, parent: Node3D, masonry: bool) -> void:
	var center := rect.get_center()
	var along_x := rect.size.x >= rect.size.y
	var length := rect.size.x if along_x else rect.size.y
	var width := rect.size.y if along_x else rect.size.x
	var yaw := 0.0 if along_x else PI * 0.5
	if masonry:
		place_asset(parent, RUIN, Vector3(center.x, 0, center.y),
			Vector3(length / 3.25, 1.0, width / 1.22), yaw)
	else:
		var chunks := maxi(2, roundi(length / 1.24))
		for i in chunks:
			var offset := (i + 0.5 - chunks * 0.5) * length / chunks
			var p := Vector3(center.x + (offset if along_x else 0.0), 0,
				center.y + (0.0 if along_x else offset))
			place_asset(parent, ROCK, p, Vector3(length / chunks / 1.55,
				1.05 + 0.16 * sin(i * 2.1), width / 1.35), yaw + (PI if i % 2 == 0 else 0.0))


func place_asset(parent: Node3D, source: PackedScene, p: Vector3, size: Vector3, yaw: float) -> Node3D:
	var prop := source.instantiate() as Node3D
	natural_materials(prop)
	parent.add_child(prop)
	prop.position = WILD_OFFSET + p
	prop.scale = size
	prop.rotation.y = yaw
	return prop


# glTF base colours are linear; explicit scenery palettes avoid pale stone
# and tan bark under the game's warm light. Materials are shared, not per tree.
func natural_materials(node: Node) -> void:
	if node is MeshInstance3D:
		for i in node.mesh.get_surface_count():
			var original=node.mesh.surface_get_material(i)
			if not original: continue
			var key: String=original.resource_name
			if not scenery_materials.has(key):
				var material=original.duplicate() as StandardMaterial3D
				if material:
					if "bark" in key or "grain" in key: material.albedo_color=Color("#241c13") if "bark" in key else Color("#3d3020")
					elif "Leaf" in key: material.albedo_color=Color("#26351d").lightened(float(i%3)*.012)
					elif "stone" in key: material.albedo_color=Color("#37382f") if "edge" in key else Color("#2e322b")
					material.roughness=.97
					var noise:=FastNoiseLite.new();noise.seed=721;noise.frequency=.09
					var texture:=NoiseTexture2D.new();texture.noise=noise;texture.width=128;texture.height=128;texture.as_normal_map=true;texture.bump_strength=2.0;texture.seamless=true
					material.normal_enabled=true;material.normal_texture=texture;material.normal_scale=.6
					scenery_materials[key]=material
			if scenery_materials.has(key): node.set_surface_override_material(i,scenery_materials[key])
	for child in node.get_children(): natural_materials(child)


func build_wild_gateway(p: Vector3, title: String, tint: Color) -> Node3D:
	var gate := Node3D.new()
	add_child(gate)
	for side in [-1.0, 1.0]:
		place_asset(gate, RUIN, p + Vector3(side * 1.55, 0, 0.15), Vector3(0.36, 1.46, 0.8), side * 0.13)
		place_asset(gate, ROCK, p + Vector3(side * 1.85, 0, -0.55), Vector3.ONE * 0.65, side)
		place_asset(gate, SNAG, p + Vector3(side * 2.25, 0, 0.58), Vector3.ONE * 0.72, side * 0.7)
		var glow := sphere(WILD_OFFSET + p + Vector3(side * 1.07, 0.42, 0.3), 0.16, tint)
		var glow_material := glow.material_override as StandardMaterial3D
		glow_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		glow.reparent(gate)
	marker(WILD_OFFSET + p + Vector3.UP * 2.65, title, gate)
	return gate


func build_wilderness_ground() -> StandardMaterial3D:
	var random := RandomNumberGenerator.new()
	random.seed = 76351
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	const SLICES := 36
	var rings: Array = [[Vector3.ZERO]]
	var shades: Array = [[1.0]]
	for ring in 5:
		var positions: Array[Vector3] = []
		var values: Array[float] = []
		var spread := (ring + 1) / 5.0
		for i in SLICES:
			var angle := TAU * (i + 0.25 * (ring % 2)) / SLICES
			var irregular := random.randf_range(0.95, 1.05)
			positions.append(Vector3(cos(angle) * 42.0 * spread * irregular,
				-0.015 - 0.7 * maxf(0.0, spread - 0.68), sin(angle) * 38.0 * spread * irregular))
			values.append(1.0 - maxf(0.0, spread - 0.6) * 0.60)
		rings.append(positions)
		shades.append(values)
	for i in SLICES:
		var following := (i + 1) % SLICES
		ground_triangle(surface, [Vector3.ZERO, rings[1][i], rings[1][following]],
			[1.0, shades[1][i], shades[1][following]])
		for ring in range(1, 5):
			ground_triangle(surface, [rings[ring][i], rings[ring + 1][i], rings[ring][following]],
				[shades[ring][i], shades[ring + 1][i], shades[ring][following]])
			ground_triangle(surface, [rings[ring][following], rings[ring + 1][i], rings[ring + 1][following]],
				[shades[ring][following], shades[ring + 1][i], shades[ring + 1][following]])
	var floor_mesh := mesh(surface.commit(), WILD_OFFSET, FLOORS[0])
	wilderness_base=floor_mesh
	var material := floor_mesh.material_override as StandardMaterial3D
	material.vertex_color_use_as_albedo = true
	var noise := FastNoiseLite.new()
	noise.seed = 58301
	noise.frequency = 0.11
	var texture := NoiseTexture2D.new()
	texture.width = 256
	texture.height = 256
	texture.noise = noise
	texture.seamless = true
	var palette := Gradient.new()
	palette.colors = PackedColorArray([Color("#75634e"), Color("#d7c2a1")])
	texture.color_ramp = palette
	material.albedo_texture = texture
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


func ground_triangle(surface: SurfaceTool, points: Array, values: Array) -> void:
	for i in 3:
		var value: float = values[i]
		surface.set_color(Color(value, value, value))
		surface.set_normal(Vector3.UP)
		var point: Vector3 = points[i]
		surface.set_uv(Vector2(point.x, point.z) / 6.0)
		surface.add_vertex(point)


func tree(p: Vector3, _tint: Color, size: float) -> Node3D:
	var model := PINE.instantiate() as Node3D
	add_child(model)
	model.position = p
	model.scale = Vector3.ONE * size * 0.82
	return model

func build_campaign_scenery() -> void:
	for site in Campaign.NAMES.size():
		var region := Node3D.new()
		add_child(region)
		scenery.append(region)
		var random := RandomNumberGenerator.new()
		random.seed = 62971 + site * 3259
		for i in 39:
			var angle := TAU * i / 39.0 + random.randf_range(-0.1, 0.1)
			var spread := random.randf_range(0.91, 1.2)
			var p := Vector3(cos(angle) * 32.0 * spread, -0.13, sin(angle) * 29.5 * spread)
			if absf(p.x) < 3.5 and absf(p.z) < 18.0:
				continue
			var feature := PINE if random.randf() > 0.18 + site * 0.19 else SNAG
			if i % 4 == 0:
				feature = ROCK
			var size := random.randf_range(0.75, 1.55)
			place_asset(region, feature, p, Vector3.ONE * size, random.randf() * TAU)
		for i in 10:
			var side := -1.0 if i % 2 == 0 else 1.0
			var p := Vector3(side * random.randf_range(28.0, 31.2), -0.07, random.randf_range(-12.0, 12.0))
			var feature := RUIN if i % 4 == 0 else ROCK
			place_asset(region, feature, p, Vector3.ONE * random.randf_range(0.37, 0.73), random.randf() * TAU)


func marker(p: Vector3, title: String, parent: Node3D = self) -> void:
	var label := Label3D.new()
	label.text = title
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 44
	label.pixel_size = 0.009
	label.outline_size = 12
	label.no_depth_test = true
	parent.add_child(label)
	label.position = p


func box(p: Vector3, size: Vector3, tint: Color) -> MeshInstance3D:
	var shape := BoxMesh.new()
	shape.size = size
	return mesh(shape, p, tint)


func sphere(p: Vector3, radius: float, tint: Color) -> MeshInstance3D:
	var shape := SphereMesh.new()
	shape.radius = radius
	shape.height = radius * 2
	shape.radial_segments = 9
	shape.rings = 5
	return mesh(shape, p, tint)


func mesh(shape: Mesh, p: Vector3, tint: Color) -> MeshInstance3D:
	var model := MeshInstance3D.new()
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	material.roughness = 0.88
	model.mesh = shape
	model.material_override = material
	add_child(model)
	model.position = p
	return model


# Trace the shared floor boundary instead of clipping the old per-path roots.
# Every chain follows the actual connected floor, including merged junctions.
func build_root_network(field: RefCounted) -> void:
	var graph: Dictionary={};var positions: Dictionary={}
	var spacing:=.5
	for x in range(Battlefield.REGION.position.x*2,(Battlefield.REGION.end.x-1)*2):
		for z in range(Battlefield.REGION.position.y*2,(Battlefield.REGION.end.y-1)*2):
			var corners: Array[Vector3]=[Vector3(x*spacing,0,z*spacing),Vector3((x+1)*spacing,0,z*spacing),Vector3((x+1)*spacing,0,(z+1)*spacing),Vector3(x*spacing,0,(z+1)*spacing)]
			var crossings: Array[Vector3]=[]
			for edge in 4:
				var a:=corners[edge];var b:=corners[(edge+1)%4];var da: float=field.sample_distance(a);var db: float=field.sample_distance(b)
				if (da>=0)!=(db>=0): crossings.append(a.lerp(b,da/(da-db)))
			for pair in range(0,crossings.size()-1,2):
				var a: Vector3=crossings[pair];var b: Vector3=crossings[pair+1]
				var ka:=Vector2i(roundi(a.x*1000),roundi(a.z*1000));var kb:=Vector2i(roundi(b.x*1000),roundi(b.z*1000))
				positions[ka]=a;positions[kb]=b
				if not graph.has(ka): graph[ka]=[]
				if not graph.has(kb): graph[kb]=[]
				graph[ka].append(kb);graph[kb].append(ka)
	var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var visited: Dictionary={};var chain_count:=0
	for start in graph:
		if visited.has(start): continue
		var path: Array[Vector3]=[];var current=start
		for step in graph.size()+1:
			if visited.has(current): break
			visited[current]=true;path.append(positions[current]+Vector3.UP*.035)
			var next=null
			for neighbor in graph[current]:
				if not visited.has(neighbor): next=neighbor;break
			if next==null:
				if graph[current].has(start): path.append(path[0])
				break
			current=next
		if path.size()<8: continue
		chain_count+=1
		var original:=path.duplicate()
		for i in path.size():
			var tangent: Vector3=(original[mini(i+1,path.size()-1)]-original[maxi(0,i-1)]).normalized()
			var sideways:=tangent.cross(Vector3.UP)
			var offset:=.16*sin(original[i].x*1.2+original[i].z*.7)+.07*sin(original[i].z*2.7)
			path[i]+=sideways*offset
		root_tube(surface,path,.16,.16)
		# Smaller intertwined roots remain continuous and taper into the soil.
		var winding: Array[Vector3]=[]
		for i in path.size():
			var tangent: Vector3=(path[mini(i+1,path.size()-1)]-path[maxi(0,i-1)]).normalized()
			var side:=tangent.cross(Vector3.UP)
			winding.append(path[i]+side*sin(i*.33)*.21+Vector3.UP*(.045+cos(i*.33)*.07))
		root_tube(surface,winding,.085,.035)
		for i in range(8,path.size()-4,16):
			var origin:=path[i];var tangent: Vector3=(path[i+1]-path[i-1]).normalized();var side:=tangent.cross(Vector3.UP)
			# Branch toward the forest, leaving the path open.
			if field.floor_distance(origin+side*.4)>0: side=-side
			var branch: Array[Vector3]=[]
			for j in 16:
				var t:=j/15.0;branch.append(origin+side*t*1.7+tangent*sin(t*PI)*.4+Vector3.UP*sin(t*PI)*.05)
			root_tube(surface,branch,.13,.006)
	var roots:=MeshInstance3D.new();roots.name="ContinuousBoundaryRoots";terrain.add_child(roots);roots.position=WILD_OFFSET;roots.mesh=surface.commit()
	roots.set_meta("boundary_chains",chain_count)
	var bark:=ShaderMaterial.new();bark.shader=preload("res://assets/shaders/root_bark.gdshader");roots.material_override=bark


func root_tube(surface: SurfaceTool, points: Array[Vector3], radius_start: float, radius_end: float) -> void:
	const SIDES := 12
	for i in range(points.size() - 1):
		var axis := (points[i + 1] - points[i]).normalized()
		var side := axis.cross(Vector3.UP).normalized()
		for j in SIDES:
			var vertices: Array[Vector3] = []
			var normals: Array[Vector3] = []
			for pair in [[i, j], [i + 1, j], [i, j + 1], [i + 1, j + 1]]:
				var angle := float(pair[1]) / SIDES * TAU
				var normal := side * cos(angle) + Vector3.UP * sin(angle)
				var along := float(pair[0]) / (points.size() - 1)
				var radius := lerpf(radius_start, radius_end, along) * (1.0 + 0.18 * sin(along * 31.0) + 0.08 * sin(along * 73.0))
				vertices.append(points[pair[0]] + normal * radius)
				normals.append(normal)
			for index in [0, 2, 1, 1, 2, 3]:
				surface.set_normal(normals[index])
				var pair= [[i,j],[i+1,j],[i,j+1],[i+1,j+1]][index]
				surface.set_uv(Vector2(float(pair[0])*.3,float(pair[1])/SIDES))
				var grain := 0.78 + 0.22 * absf(sin(float(j) * 2.1))
				surface.set_color(Color(grain, grain, grain))
				surface.add_vertex(vertices[index])

func apply_exploration_sight(position: Vector3, wild: bool, radius: float) -> void:
	if not wild:
		return
	var observer := WILD_OFFSET + position
	foe.visible = foe.visible and foe.position.distance_to(observer) <= radius
	attack_ring.visible = attack_ring.visible and attack_ring.position.distance_to(observer) <= radius
	briar_vines.visible = briar_vines.visible and briar_vines.position.distance_to(observer) <= radius
	for i in support_models.size():
		var nearby := support_models[i].position.distance_to(observer) <= radius
		support_models[i].visible = support_models[i].visible and nearby
		support_rings[i].visible = support_rings[i].visible and support_rings[i].position.distance_to(observer) <= radius
		support_binds[i].visible = support_binds[i].visible and nearby
	seed.visible = seed.visible and seed.position.distance_to(observer) <= radius
	seed_cache.visible = seed_cache.visible and seed_cache.position.distance_to(observer) <= radius

static func garden_growth(knowledge: int, technologies: int) -> int:
	return preload("res://garden_growth_catalog.gd").level(knowledge,technologies)


static func garden_radius(knowledge: int, technologies: int) -> float:
	return 11.5 + garden_growth(knowledge, technologies) * 1.05


func build_circular_garden() -> ShaderMaterial:
	var soil := CylinderMesh.new()
	soil.top_radius = 24.5
	soil.bottom_radius = 24.5
	soil.height = 0.12
	soil.radial_segments = 96
	mesh(soil, Vector3(0, -0.30, 0), Color("#322a20"))
	var clearing := CylinderMesh.new()
	clearing.top_radius = 1.0
	clearing.bottom_radius = 1.0
	clearing.height = 0.12
	clearing.radial_segments = 96
	garden_disc = mesh(clearing, Vector3(0, -0.11, 0), Color("#4c6435"))
	var material := GardenScenery.floor_material()
	garden_disc.material_override=material
	garden_edge = Node3D.new()
	add_child(garden_edge)
	update_garden(0, 0)
	return material


func update_garden(knowledge: int, technologies: int) -> void:
	var radius := garden_radius(knowledge, technologies)
	garden_extent = preload("res://garden_layout.gd").extent(self,radius)
	garden_disc.scale = Vector3(radius, 1, radius)
	if is_instance_valid(heart_tree):
		heart_size = lerpf(0.78, 1.12, heart_phase / 5.0)
	var tier := garden_growth(knowledge, technologies) * 16 + active_plots
	if garden_tier == tier:
		return
	garden_tier = tier
	for child in garden_edge.get_children():
		child.free()
	var random := RandomNumberGenerator.new()
	random.seed = 8319
	for i in 34:
		var angle := TAU * i / 34.0
		var r := radius + random.randf_range(0.5, 1.5)
		var p := Vector3(cos(angle) * r, 0, sin(angle) * r)
		var tree_model := PINE.instantiate() as Node3D
		natural_materials(tree_model)
		garden_edge.add_child(tree_model)
		var safe_p:=p
		for bed in PLOTS.slice(0,active_plots):
			if safe_p.distance_to(bed)<3.0: safe_p=safe_p.normalized()*(radius+2.7)
		if preload("res://garden_layout.gd").reserved(self,safe_p,radius,1.1):safe_p=safe_p.normalized()*(radius+2.7)
		tree_model.position = safe_p
		tree_model.scale = Vector3.ONE * random.randf_range(0.7, 1.02)
		tree_model.rotation.y = random.randf() * TAU
	build_garden_life(radius, random)
	preload("res://garden_visuals.gd").accents(self,radius,random)
	var destinations: Array=preload("res://garden_layout.gd").destinations(self)
	var bark:=GardenScenery.root_material()
	for destination in destinations:
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		var path: Array[Vector3] = []
		for i in 16:
			var t := i / 15.0
			var p: Vector3 = HEART.lerp(destination, t)
			p.x += sin(t * PI * 2.0) * 0.23
			p.y = 0.03
			path.append(p)
		for strand in 3:
			var woven: Array[Vector3]=[]
			var direction: Vector3=destination.normalized();var side:=direction.cross(Vector3.UP)
			for i in path.size():
				var t:=i/float(path.size()-1);woven.append(path[i]+side*(sin(t*6.5+strand*2.1)*.12+sin(t*15+strand)*.025)*(1-t)+Vector3.UP*sin(t*5+strand)*.012)
			root_tube(surface,woven,.10-strand*.023,.003)
		for fork in [6,10]:
			var direction: Vector3=destination.normalized();var side:=direction.cross(Vector3.UP)*(-1 if fork==6 else 1)
			var branch: Array[Vector3]=[]
			for i in 13:
				var t:=i/12.0;branch.append(path[fork]+side*t*.45+direction*t*.35+Vector3.UP*sin(t*PI)*.015)
			root_tube(surface,branch,.035,.002)
		var roots := MeshInstance3D.new()
		garden_edge.add_child(roots)
		roots.mesh = surface.commit()
		roots.material_override = bark
		roots.set_meta("garden_route_target",destination)

func apply_appearance(actor: Dictionary,look: Array) -> void:
	preload("res://character_appearance.gd").apply(actor,look)

func build_garden_gateway() -> void:
	for side in [-1.0, 1.0]:
		var trunk := PINE.instantiate() as Node3D
		natural_materials(trunk)
		add_child(trunk)
		trunk.position = GATE + Vector3(side * 1.05, 0, 0)
		trunk.scale = Vector3(0.65, 0.80, 0.65)
		trunk.rotation.z = side * 0.20
		var lamp := sphere(GATE + Vector3(side * 0.85, 1.6, 0), 0.12, Color("#b1c393"))
		(lamp.material_override as StandardMaterial3D).emission_enabled = true
		(lamp.material_override as StandardMaterial3D).emission = Color("#657c45")
	garden_portal=build_gate_swirl(self,GATE)
	marker(GATE + Vector3.UP * 2.7, "WILDS")


func build_gate_swirl(parent: Node3D,at: Vector3) -> Node3D:
	var root:=Node3D.new();root.name="GateSwirl";parent.add_child(root);root.position=at+Vector3.UP*1.25
	var plane:=QuadMesh.new();plane.size=Vector2(1.9,2.6)
	var portal:=MeshInstance3D.new();root.add_child(portal);portal.mesh=plane;portal.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material:=ShaderMaterial.new();material.shader=preload("res://assets/shaders/gate_swirl.gdshader");portal.material_override=material
	var light:=OmniLight3D.new();root.add_child(light);light.light_color=Color("#68b5e6");light.light_energy=.28;light.omni_range=3.0
	return root


func build_garden_plot(position: Vector3, parent: Node3D = self) -> void:
	var group:=Node3D.new();group.name="GardenBed";parent.add_child(group);group.position=position;group.set_meta("garden_plot_position",position)
	parent=group;position=Vector3.ZERO
	var soil := CylinderMesh.new()
	soil.top_radius = 1.0
	soil.bottom_radius = 1.07
	soil.height = 0.08
	soil.radial_segments = 28
	var earth := mesh(soil, position + Vector3.UP * 0.02, Color("#43301d"))
	earth.reparent(parent,false)
	var soil_material:=ShaderMaterial.new();soil_material.shader=preload("res://assets/shaders/forest_soil.gdshader");earth.material_override=soil_material
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var points: Array[Vector3] = []
	for i in 33:
		var angle := TAU * i / 32.0
		var radius := 1.02 + sin(angle * 5.0) * 0.055
		points.append(position + Vector3(cos(angle) * radius, 0.09, sin(angle) * radius))
	root_tube(surface, points, 0.08, 0.065)
	var rim := MeshInstance3D.new()
	parent.add_child(rim)
	rim.mesh = surface.commit()
	var bark := StandardMaterial3D.new()
	bark.albedo_color = Color("#66502e")
	rim.material_override = bark

func build_heart_growth() -> Node3D:
	return preload("res://heart_visuals.gd").build(self,heart_phase)

func update_heart_progress(state: Dictionary) -> void:
	var phase:=clampi(int(get_meta("garden_growth_phase",state.get("phase",0))),0,5)
	var unlocked: Array=state.get("unlocked",[])
	if phase!=heart_phase and is_instance_valid(heart_tree):
		var shown: bool=heart_tree.visible
		heart_tree.free()
		heart_phase=phase
		heart_tree=build_heart_growth()
		heart_tree.visible=shown
	var key:=str(unlocked)
	if heart_tech_key!=key:
		heart_tech_key=key
		heart_unlocked=unlocked.duplicate()
		garden_tier=-1
		for id in HEART_STATIONS:
			if not heart_stations.has(id):
				heart_stations[id]=preload("res://heart_visuals.gd").station(self,id,HEART_STATIONS[id])
			heart_stations[id].visible=unlocked.has(id)
	preload("res://heart_growth_visuals.gd").sync(self,state)


func garden_pond_positions(radius: float) -> Array[Vector3]:
	var result: Array[Vector3]=[]
	for water in preload("res://garden_layout.gd").ponds(self,radius):result.append(water.position)
	return result


func build_garden_life(radius: float, random: RandomNumberGenerator) -> void:
	var ponds:=preload("res://garden_layout.gd").ponds(self,radius)
	for water in ponds:
		if water.id!="sheltered_spring":build_garden_pond(water.position,float(water.radius),random)
	var spring_zone: Dictionary=preload("res://garden_layout.gd").zone("sheltered_spring")
	var spring:=preload("res://assets/garden/sheltered_spring.tscn").instantiate()
	garden_edge.add_child(spring)
	spring.configure(self,spring_zone.water.position,preload("res://garden_layout.gd").enabled(spring_zone,heart_unlocked))
	GardenScenery.scatter(self,radius)


func build_garden_pond(position: Vector3, radius: float, random: RandomNumberGenerator) -> void:
	var group:=Node3D.new();group.name="GardenWaterFeature";garden_edge.add_child(group);group.position=position;group.set_meta("garden_water_position",position)
	position=Vector3.ZERO
	var shape:=SurfaceTool.new();shape.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 96:
		var a:=TAU*i/96;var b:=TAU*(i+1)/96
		var ra:=radius*(1+.09*sin(a*3)+.045*cos(a*5));var rb:=radius*(1+.09*sin(b*3)+.045*cos(b*5))
		for vertex in [Vector3.ZERO,Vector3(cos(b)*rb,0,sin(b)*rb),Vector3(cos(a)*ra,0,sin(a)*ra)]:
			shape.set_normal(Vector3.UP);shape.add_vertex(vertex)
	var water:=MeshInstance3D.new();water.name="GardenPond";water.set_meta("garden_pond",true);group.add_child(water);water.mesh=shape.commit();water.position=position+Vector3.UP*.018;water.scale.z=.72
	var shader=preload("res://assets/shaders/garden_water.gdshader")
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("pond_size",radius)
	water.material_override = material
	water.set_meta("garden_motion",true)
	GardenScenery.bank(group,radius,random)


	# Sparse lily pads soften the pools without obscuring their water.
	var leaves:=SurfaceTool.new();leaves.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 3:
		var at:=position+Vector3(-.45+i*.35,.034,.15+sin(i*2.1)*.28)
		for j in range(1,23):
			var a:=j*TAU/24;var b:=(j+1)*TAU/24
			for vertex in [at,at+Vector3(cos(b)*.16,0,sin(b)*.13),at+Vector3(cos(a)*.16,0,sin(a)*.13)]:
				leaves.set_normal(Vector3.UP);leaves.add_vertex(vertex)
	var pads:=MeshInstance3D.new();pads.name="LilyPads";group.add_child(pads);pads.mesh=leaves.commit()
	var green:=StandardMaterial3D.new();green.albedo_color=Color("#57704a");green.roughness=.65;green.cull_mode=BaseMaterial3D.CULL_DISABLED;pads.material_override=green


static func garden_camera_target(player: Vector3, radius: float) -> Vector3:
	var extent := maxf(1.2, radius - 11.8)
	var point := (Vector2(player.x, player.z) * 0.48).limit_length(extent)
	return Vector3(point.x, 0, point.y)

func update_plots(beds: Array) -> void:
	if garden_beds == null or plot_key == str(beds):
		return
	plot_key = str(beds)
	active_plots = beds.size()
	occupied_offshoots.clear()
	for child in garden_beds.get_children():
		child.free()
	for i in beds.size():
		var p: Vector3 = PLOTS[i]
		build_garden_plot(p, garden_beds)
		var bed_group:=garden_beds.get_child(garden_beds.get_child_count()-1)
		var bed: Dictionary = beds[i]
		if Campaign.LEGACY_ENDING_ENABLED and int(bed.get("offshoot",-1))>=0:
			occupied_offshoots.append(int(bed.offshoot));var sapling=PINE.instantiate();natural_materials(sapling);garden_beds.add_child(sapling);sapling.position=p;sapling.scale=Vector3.ONE*(.45 if int(bed.stage)==3 else .27)
		if bed.species >= 0:
			var plant := build_crop(int(bed.species), int(bed.stage), bool(bed.flowering))
			plant.reparent(bed_group, false)
			plant.position = Vector3.ZERO
		var label := Label3D.new()
		bed_group.add_child(label)
		label.position = Vector3(0, 0.18, 0.95)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.font_size = 28
		label.pixel_size = 0.008
		label.outline_size = 7
		label.text = "BED %d Â· EMPTY" % (i + 1) if bed.species < 0 else "%s Â· %s" % [
			Seeds.NAMES[int(bed.species)].to_upper(), ["SEED", "SPROUT", "YOUNG", "READY"][bed.stage]]
		if Campaign.LEGACY_ENDING_ENABLED and int(bed.get("offshoot",-1))>=0: label.text="LIVING OFFSHOOT Â· "+("MATURE" if int(bed.stage)==3 else "GROWING")
		label.modulate = Color("#d4d5ad") if bed.stage < 3 else Color("#f3dc92")


func plant_blob(parent: Node3D, position: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var shape := SphereMesh.new()
	shape.radius = 1.0
	shape.height = 2.0
	shape.radial_segments = 16
	shape.rings = 8
	var blob := MeshInstance3D.new()
	parent.add_child(blob)
	blob.mesh = shape
	blob.position = position
	blob.scale = size
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.85
	blob.material_override = material
	return blob


func build_seed_model() -> Node3D:
	var root := Node3D.new()
	add_child(root)
	plant_blob(root, Vector3.ZERO, Vector3(0.14,0.22,0.12), Color("#71502d"))
	var seam := plant_blob(root, Vector3(0,-0.015,0.115), Vector3(0.045,0.13,0.018), Color("#bcb571"))
	var material := seam.material_override as StandardMaterial3D
	material.emission_enabled = true
	material.emission = Color("#625e21")
	material.emission_energy_multiplier = 0.5
	return root


func build_cache_model() -> Node3D:
	var root := Node3D.new()
	add_child(root)
	plant_blob(root, Vector3(0,0.16,0), Vector3(0.52,0.19,0.43), Color("#45331e"))
	for i in 4:
		var angle := TAU * i / 4.0
		var husk := plant_blob(root, Vector3(cos(angle)*0.28,0.42,sin(angle)*0.28),
			Vector3(0.18,0.38,0.20), Color("#695332"))
		husk.rotation.z = cos(angle) * -0.28
		husk.rotation.x = sin(angle) * 0.28
		var seedling := build_seed_model()
		seedling.reparent(root, false)
		seedling.position = Vector3(cos(angle)*0.12,0.53,sin(angle)*0.12)
		cache_kernels.append(seedling)
	cache_label = Label3D.new()
	root.add_child(cache_label)
	cache_label.position = Vector3.UP * 1.08
	cache_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	cache_label.font_size = 36
	cache_label.pixel_size = 0.008
	cache_label.outline_size = 8
	cache_label.text = "ABANDONED SEED POD"
	return root


func build_crop(kind: int, stage: int, flowering: bool) -> Node3D:
	if kind >= 3:
		return build_lineage_crop(kind, stage, flowering)
	var plant := Node3D.new()
	add_child(plant)
	if stage == 0:
		var kernel := build_seed_model()
		kernel.reparent(plant, false)
		kernel.position.y = 0.14
		kernel.rotation.z = 0.9
		return plant
	var height: float = [0.0,0.25,0.57,0.88][stage]
	var stem := CylinderMesh.new()
	stem.top_radius = 0.025
	stem.bottom_radius = 0.045
	stem.height = height
	stem.radial_segments = 8
	var stalk := mesh(stem, Vector3(0,height*0.5,0), Color("#446037"))
	stalk.reparent(plant, false)
	for i in (2 if stage == 1 else 5):
		var side := -1.0 if i % 2 == 0 else 1.0
		var y: float = height * (0.35 + (i / 5.0) * 0.45)
		var leaf := plant_blob(plant, Vector3(side * 0.13,y,0), Vector3(0.20,0.042,0.095), Color("#638446"))
		leaf.rotation.z = side * 0.4
	if stage == 1:
		return plant
	if kind == 0:
		if stage == 3 and not flowering:
			for i in 8:
				var angle := TAU * i / 8.0
				var petal := plant_blob(plant, Vector3(cos(angle)*0.18,height,sin(angle)*0.18),
					Vector3(0.18,0.06,0.10), Color("#b96570"))
				petal.rotation.y = -angle
			plant_blob(plant, Vector3(0,height+0.06,0), Vector3(0.11,0.09,0.11), Color("#d0ba6a"))
		else:
			plant_blob(plant, Vector3(0,height,0), Vector3(0.10,0.15,0.10), Color("#70904b"))
	elif kind == 1:
		for i in 5:
			var angle := TAU * i / 5.0
			plant_blob(plant, Vector3(cos(angle)*0.22,0.16,sin(angle)*0.22), Vector3(0.22,0.16,0.22), Color("#597c43"))
		if stage == 3 and not flowering:
			var lantern := plant_blob(plant, Vector3(0,height,0), Vector3(0.19,0.24,0.19), Color("#d1ce72"))
			var material := lantern.material_override as StandardMaterial3D
			material.emission_enabled = true
			material.emission = Color("#7b8534")
			material.emission_energy_multiplier = 0.3
	else:
		var width := 0.32 if stage == 3 else 0.18
		plant_blob(plant, Vector3(0,height,0), Vector3(width,0.12,width), Color("#8c789f"))
		plant_blob(plant, Vector3(0,height-0.06,0), Vector3(width*0.8,0.025,width*0.8), Color("#b6a7bb"))
	if flowering and stage == 3:
		for i in 3:
			var angle := TAU * i / 3.0
			var kernel := build_seed_model()
			kernel.reparent(plant, false)
			kernel.position = Vector3(cos(angle)*0.13,height+0.12,sin(angle)*0.13)
	return plant

func build_lineage_crop(kind: int, growth: int, flowering: bool) -> Node3D:
	var entry: Dictionary = Seeds.DEFINITIONS[kind]
	var plant := Node3D.new()
	add_child(plant)
	var color := Color(entry.color)
	if growth == 0:
		var kernel := build_seed_model()
		kernel.reparent(plant, false)
		kernel.position.y = 0.08
		kernel.scale = Vector3.ONE * 0.6
		return plant
	var height := (0.28 + growth * 0.20) * (1.0 + int(entry.tier) * 0.06)
	var stem := CylinderMesh.new()
	stem.height = height
	stem.top_radius = 0.025
	stem.bottom_radius = 0.055
	stem.radial_segments = 10
	mesh(stem, Vector3(0,height/2,0), Color("#50633c")).reparent(plant,false)
	var count := 3 + growth * 2
	for i in count:
		var angle := i * 2.4 + kind
		var y := height * (0.15 + 0.7 * i / count)
		var leaf := plant_blob(plant,Vector3(cos(angle)*0.15,y,sin(angle)*0.15),Vector3(0.23,0.04,0.09),color.darkened(0.32))
		leaf.rotation = Vector3(0,-angle,0.35)
	if growth == 1:
		return plant
	var radius := 0.16 if growth == 2 else 0.32
	match str(entry.form):
		"root", "crown":
			for i in (7 if entry.form=="crown" else 5):
				var angle:=i*2.4
				var points: Array[Vector3]=[Vector3(cos(angle)*.38,.03,sin(angle)*.38),Vector3(cos(angle)*.17,height*.45,sin(angle)*.17),Vector3(cos(angle)*.23,height+.10,sin(angle)*.23)]
				var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES);root_tube(surface,points,.065,.015)
				mesh(surface.commit(),Vector3.ZERO,color).reparent(plant,false)
		"mirror", "whisper":
			for i in 6:
				var angle:=i*2.4
				var leaf:=plant_blob(plant,Vector3(cos(angle)*radius*.7,height-i*.065,sin(angle)*radius*.7),Vector3(.20,.025,.09),color)
				leaf.rotation=Vector3(.3,-angle,.35)
				if entry.form=="mirror": (leaf.material_override as StandardMaterial3D).metallic=.65
		"grave":
			for i in 9:
				var angle:=i*2.4
				plant_blob(plant,Vector3(cos(angle)*radius,.12+i*.035,sin(angle)*radius),Vector3(.18,.09,.17),color)
		"tide":
			for i in 8:
				var angle:=i*TAU/8
				var petal:=plant_blob(plant,Vector3(cos(angle)*radius*.5,height-.03,sin(angle)*radius*.5),Vector3(.23,.04,.11),color)
				petal.rotation=Vector3(.3,-angle,.3)
			plant_blob(plant,Vector3(0,height,.0),Vector3(.19,.025,.19),Color("#8ce1ef"))
		"hush", "dream":
			for i in 6:
				var angle:=i*TAU/6
				var petal:=plant_blob(plant,Vector3(cos(angle)*radius*.4,height,sin(angle)*radius*.4),Vector3(.21,.09,.12),color)
				petal.rotation.y=-angle
			plant_blob(plant,Vector3(0,height+.06,0),Vector3(.13,.06,.13),color.darkened(.65))
		"bell":
			for i in 5:
				var angle:=i*TAU/5
				var bell:=plant_blob(plant,Vector3(cos(angle)*radius*.65,height-.07*i,sin(angle)*radius*.65),Vector3(.1,.16,.1),color)
				bell.rotation.z=.4*sin(angle)
				plant_blob(plant,bell.position-Vector3(0,.13,0),Vector3(.12,.025,.12),color.lightened(.2))
		"cap":
			plant_blob(plant,Vector3(0,height,0),Vector3(radius,0.13,radius),color)
		"fern":
			for i in 7:
				var y := height * (0.3+i*0.1)
				for side in [-1.0,1.0]:
					var frond := plant_blob(plant,Vector3(side*radius*0.55,y,0),Vector3(radius,0.035,0.065),color)
					frond.rotation.z=side*(0.18+i*0.055)
		"reed":
			for i in 4:
				plant_blob(plant,Vector3((i-1.5)*0.13,height+i*0.08,0),Vector3(0.065,0.25,0.07),color)
		"willow", "vine":
			for i in 5:
				var a := TAU*i/5.0
				var points: Array[Vector3] = [Vector3(0,height,0),Vector3(cos(a)*radius,height+0.17,sin(a)*radius),Vector3(cos(a)*radius*1.4,height*0.4,sin(a)*radius*1.4)]
				var geometry := SurfaceTool.new()
				geometry.begin(Mesh.PRIMITIVE_TRIANGLES)
				root_tube(geometry,points,0.045,0.012)
				var tendril := mesh(geometry.commit(),Vector3.ZERO,color)
				tendril.reparent(plant,false)
		_:
			var petals := 9 if entry.form == "lotus" else 6
			for i in petals:
				var a := TAU*i/petals
				var leaf := plant_blob(plant,Vector3(cos(a)*radius*0.6,height,sin(a)*radius*0.6),Vector3(radius*0.8,0.055,0.11),color)
				leaf.rotation.y = -a
			plant_blob(plant,Vector3(0,height+0.04,0),Vector3(0.1,0.1,0.1),color.lightened(0.35))
	if growth == 3 and flowering:
		for i in 3:
			var seedling := build_seed_model()
			seedling.reparent(plant,false)
			seedling.scale = Vector3.ONE*0.6
			seedling.position = Vector3(cos(i*TAU/3)*0.15,height+0.12,sin(i*TAU/3)*0.15)
	return plant


func emit_skill_effect(at: Vector3,radius: float,color: Color) -> void:
	var shape:=TorusMesh.new()
	shape.inner_radius=.90
	shape.outer_radius=1.0
	shape.rings=32
	shape.ring_segments=8
	var effect:=MeshInstance3D.new()
	add_child(effect)
	effect.mesh=shape
	effect.position=at+Vector3.UP*.075
	effect.scale=Vector3(.12,.10,.12)
	color.a=.65
	var material:=attack_material(color)
	effect.material_override=material
	effect.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var tween:=create_tween()
	tween.set_parallel(true)
	tween.tween_property(effect,"scale",Vector3(radius,.10,radius),.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(material,"albedo_color:a",0.0,.65)
	tween.chain().tween_callback(effect.queue_free)





func apply_biome_material(material: ShaderMaterial,site: int,depth: int) -> void:
	var palettes: Array[Vector3]=[Vector3(1.,1.,.90),Vector3(.72,.86,.87),Vector3(.78,.71,.88),Vector3(.82,.68,.75)]
	material.set_shader_parameter("biome_tint",palettes[clampi(site,0,palettes.size()-1)])
	material.set_shader_parameter("corruption",clampf((depth-1)/8.,0,1))

func ensure_finale_form(actor: Dictionary,finale: bool) -> void:
	var model: Node3D=actor.model
	if not model.has_meta("finale_form") and finale:
		var originals: Array=model.find_children("*","MeshInstance3D",true,false)
		var saved_core:=heart_core
		var growth:=preload("res://heart_visuals.gd").build(self,5)
		heart_core=saved_core
		growth.reparent(model,false);growth.position=Vector3.ZERO;growth.scale=Vector3.ONE*.75
		for child in growth.find_children("*","Label3D",true,false): child.hide()
		model.set_meta("finale_form",growth);model.set_meta("original_meshes",originals)
	if model.has_meta("finale_form"):
		var growth: Node3D=model.get_meta("finale_form");growth.visible=finale
		growth.scale.y=.75+sin(Time.get_ticks_msec()*.002)*.025
		for original in model.get_meta("original_meshes"):
			if is_instance_valid(original): original.visible=not finale

