extends RefCounted
## One instance belongs to the title-issued developer world. Practice borrows it.
const Developer = preload("res://developer_mode.gd")
const ClassArt = preload("res://class_release_visuals.gd")
const Astral = preload("res://astral_visuals.gd")
const Shelter = preload("res://shelter_visuals.gd")
const Affinities = preload("res://affinity_glyphs.gd")
const Contacts = preload("res://contact_particles.gd")
const Delivery = preload("res://weapon_delivery_visuals.gd")
const Ambient = preload("res://assets/terrain_m02/garden_ambient.gd")
const IMPACT := "impact.emission"
const SUN := "scene.sun_energy"
const SPEAR := "briar_spear.reach"
const WATER := "living_sprinkler.base_radius"
const FLORA := "wild_flora.probability"
# All entries are finite floats. Source symbols own the production numbers.
const CORE_PROPERTIES := {
	IMPACT: {"type":"float", "category":"Visuals", "object_name":"Combat impact", "label":"Emission", "unit":"×",
		"minimum":0, "maximum":4, "step":0.05,
		"timing":"Next impact or visual replay", "source":"combat_effects.gd", "symbol":"IMPACT_EMISSION"},
	"impact.count": {"type":"float","category":"Visuals","object_name":"Weapon contact","label":"Splinters","unit":"pieces",
		"minimum":2,"maximum":14,"step":1,"timing":"Next confirmed event or replay","source":"contact_particles.gd","symbol":"DEFAULTS.impact.count"},
	"impact.size": {"type":"float","category":"Visuals","object_name":"Weapon contact","label":"Splinter scale","unit":"×",
		"minimum":0.45,"maximum":2,"step":0.05,"timing":"Next confirmed event or replay","source":"contact_particles.gd","symbol":"DEFAULTS.impact.size"},
	"impact.speed": {"type":"float","category":"Visuals","object_name":"Weapon contact","label":"Splinter speed","unit":"m/s",
		"minimum":1,"maximum":7,"step":0.1,"timing":"Next confirmed event or replay","source":"contact_particles.gd","symbol":"DEFAULTS.impact.speed"},
	"impact.lifetime": {"type":"float","category":"Visuals","object_name":"Weapon contact","label":"Decay","unit":"s",
		"minimum":0.08,"maximum":0.4,"step":0.01,"timing":"Next confirmed event or replay","source":"contact_particles.gd","symbol":"DEFAULTS.impact.lifetime"},
	"impact.flash": {"type":"float","category":"Visuals","object_name":"Weapon contact","label":"Contact flash","unit":"×",
		"minimum":0,"maximum":1,"step":0.05,"timing":"Next confirmed event or replay","source":"contact_particles.gd","symbol":"DEFAULTS.impact.flash"},
	"impact.hue": {"type":"float","category":"Visuals","object_name":"Weapon contact","label":"Tint hue","unit":"°",
		"minimum":0,"maximum":360,"step":1,"timing":"Next confirmed event or replay","source":"contact_particles.gd","symbol":"DEFAULTS.impact.hue"},
	"rupture.count": {"type":"float","category":"Visuals","object_name":"Brittle rupture","label":"Fragments","unit":"pieces",
		"minimum":3,"maximum":18,"step":1,"timing":"Next confirmed event or replay","source":"contact_particles.gd","symbol":"DEFAULTS.rupture.count"},
	"rupture.size": {"type":"float","category":"Visuals","object_name":"Brittle rupture","label":"Shard scale","unit":"×",
		"minimum":0.45,"maximum":1.8,"step":0.05,"timing":"Next confirmed event or replay","source":"contact_particles.gd","symbol":"DEFAULTS.rupture.size"},
	"rupture.speed": {"type":"float","category":"Visuals","object_name":"Brittle rupture","label":"Outward speed","unit":"m/s",
		"minimum":0.8,"maximum":6,"step":0.1,"timing":"Next confirmed event or replay","source":"contact_particles.gd","symbol":"DEFAULTS.rupture.speed"},
	"rupture.lifetime": {"type":"float","category":"Visuals","object_name":"Brittle rupture","label":"Decay","unit":"s",
		"minimum":0.14,"maximum":0.5,"step":0.01,"timing":"Next confirmed event or replay","source":"contact_particles.gd","symbol":"DEFAULTS.rupture.lifetime"},
	"rupture.flash": {"type":"float","category":"Visuals","object_name":"Brittle rupture","label":"Fracture glint","unit":"×",
		"minimum":0,"maximum":1.5,"step":0.05,"timing":"Next confirmed event or replay","source":"contact_particles.gd","symbol":"DEFAULTS.rupture.flash"},
	"rupture.hue": {"type":"float","category":"Visuals","object_name":"Brittle rupture","label":"Tint hue","unit":"°",
		"minimum":0,"maximum":360,"step":1,"timing":"Next confirmed event or replay","source":"contact_particles.gd","symbol":"DEFAULTS.rupture.hue"},
	"rupture.repeat_labels": {"type":"float","category":"Visuals","object_name":"Brittle rupture","label":"Show every nearby rupture label","unit":"off/on",
		"minimum":0,"maximum":1,"step":1,"timing":"Live combat labels · 0 groups nearby ruptures, 1 shows every label","source":"contact_particles.gd","symbol":"DEFAULTS.rupture.repeat_labels"},
	SUN: {"type":"float", "category":"Visuals", "object_name":"Scene sun", "label":"Light energy", "unit":"×",
		"minimum":0, "maximum":4, "step":0.05,
		"timing":"Immediate scene update", "source":"stage.gd", "symbol":"apply_scene_sun / biome climate.sun_energy"},
	SPEAR: {"type":"float", "category":"Gameplay", "object_name":"Briar Spear", "label":"Attack reach", "unit":"m",
		"minimum":0.5, "maximum":8, "step":0.1,
		"timing":"Next accepted spear attack", "source":"class_catalog.gd", "symbol":"warden.weapons[0_1].reach"},
	WATER: {"type":"float", "category":"Garden", "object_name":"Living Sprinkler", "label":"Base coverage", "unit":"m",
		"minimum":0.5, "maximum":10, "step":0.1,
		"timing":"Apply to recalculate base coverage. Researched coverage takes precedence.", "source":"garden_structure_catalog.gd", "symbol":"sprinkler.radius_m"},
	FLORA: {"type":"float", "category":"World", "object_name":"Ordinary Wild Flora", "label":"Specimen chance", "unit":"%",
		"minimum":0, "maximum":100, "step":1,
		"timing":"Next eligible generated floor", "source":"wild_flora_generation.gd", "symbol":"SPAWN_CHANCE"}
}
static var PROPERTIES := _property_definitions()

static func _property_definitions() -> Dictionary:
	var properties := CORE_PROPERTIES.duplicate()
	for id: String in Ambient.CONTROLS:
		var d: Array = Ambient.CONTROLS[id]
		properties[id] = {"type":"float","category":"Visuals","object_name":Ambient.OBJECTS[id.get_slice(".",0)],
			"label":d[4],"unit":d[5],"minimum":d[1],"maximum":d[2],"step":d[3],
			"timing":"Live Garden and experimental playback","source":"assets/terrain_m02/garden_ambient.gd","symbol":"CONTROLS."+id}
	for id:String in Affinities.CONTROLS:
		var d:Array=Affinities.CONTROLS[id]
		properties[id]={"type":"float","category":"Visuals","object_name":Affinities.LABELS[id.get_slice(".",0)],
			"label":d[4],"unit":d[5],"minimum":d[1],"maximum":d[2],"step":d[3],
			"timing":"Local combat and experimental playback","source":"affinity_glyphs.gd","symbol":"CONTROLS."+id}
	for id:String in Shelter.CONTROLS:
		var d:Array=Shelter.CONTROLS[id]
		properties[id]={"type":"float","category":"Visuals","object_name":Shelter.LABELS[id.get_slice(".",0)],
			"label":d[4],"unit":d[5],"minimum":d[1],"maximum":d[2],"step":d[3],
			"timing":"Local combat and experimental playback","source":"shelter_visuals.gd","symbol":"CONTROLS."+id}
	for id:String in ClassArt.CONTROLS:
		var d:Array=ClassArt.CONTROLS[id]
		properties[id]={"type":"float","category":"Visuals","object_name":"Class releases",
			"label":d[4],"unit":d[5],"minimum":d[1],"maximum":d[2],"step":d[3],
			"timing":"Local combat and experimental playback","source":"class_release_visuals.gd","symbol":"CONTROLS."+id}
	for id:String in Astral.CONTROLS:
		var d:Array=Astral.CONTROLS[id]
		properties[id]={"type":"float","category":"Visuals","object_name":Astral.LABELS[id.get_slice(".",0)],
			"label":d[4],"unit":d[5],"minimum":d[1],"maximum":d[2],"step":d[3],
			"timing":"Local combat and experimental playback","source":"astral_visuals.gd","symbol":"CONTROLS."+id}
	for id: String in Delivery.CONTROLS:
		var d: Array=Delivery.CONTROLS[id]
		var group: String={"trail":"Weapon edge","projectile":"Projectile","dodge":"Ordinary dodge","text":"Combat captions"}[id.get_slice(".",0)]
		properties[id]={"type":"float","category":"Visuals","object_name":group,"label":d[4],"unit":d[5],"minimum":d[1],"maximum":d[2],"step":d[3],"timing":"Next live proc caption" if id=="text.detail" else "Local combat and experimental playback","source":"weapon_delivery_visuals.gd","symbol":"CONTROLS."+id}
	return properties

var _owner: WeakRef
var _active_stage: WeakRef
var _requested := {}
var _applied := {}
var last_used := {}
var replay_slot := 0

func attach(garden: Node) -> bool:
	if _owner != null or not Developer.is_test_garden(garden) or not Developer.is_solo(garden): return false
	_owner = weakref(garden)
	_active_stage = weakref(garden.stage)
	return true

func authorized(world: Node) -> bool:
	if not Developer.authorized_build() or _owner == null: return false
	var garden: Node = _owner.get_ref()
	if not Developer.is_test_garden(garden) or not Developer.is_solo(garden) or not garden.slot_claimed or not garden.persistence_session.can_write() or garden.returning_to_title or not garden.app_settings.values.developer_mode: return false
	var session := garden.get_node_or_null("TestingArena")
	if world == garden: return session == null or session.garden == null
	return session != null and session.combat == world and session.authorized(world) and Developer.is_solo(world)

func directory(world: Node) -> String:
	if not authorized(world): return ""
	return str(_owner.get_ref().slot_storage_root).path_join("tuning")

func baseline(id: String) -> float:
	match id:
		IMPACT: return preload("res://combat_effects.gd").IMPACT_EMISSION
		SUN: return _active_stage.get_ref().production_sun_energy if _active_stage != null and is_instance_valid(_active_stage.get_ref()) else NAN
		SPEAR: return preload("res://class_catalog.gd").DEFINITIONS[0].weapons[1].reach
		WATER: return preload("res://garden_irrigation.gd").RADIUS_M
		FLORA: return preload("res://wild_flora_generation.gd").SPAWN_CHANCE * 100.0
	if ClassArt.CONTROLS.has(id): return ClassArt.CONTROLS[id][0]
	if Astral.CONTROLS.has(id): return Astral.CONTROLS[id][0]
	if Shelter.CONTROLS.has(id): return Shelter.CONTROLS[id][0]
	if Affinities.CONTROLS.has(id): return Affinities.CONTROLS[id][0]
	if Delivery.CONTROLS.has(id): return Delivery.CONTROLS[id][0]
	if Ambient.CONTROLS.has(id): return Ambient.CONTROLS[id][0]
	return Contacts.DEFAULTS.get(id,NAN)

static func valid(id: String, value: Variant) -> bool:
	if not PROPERTIES.has(id) or not (value is float or value is int): return false
	var row: Dictionary = PROPERTIES[id]
	return is_finite(value) and value >= row.minimum and value <= row.maximum and (row.unit not in ["pieces","off/on"] or value == floor(value))

func requested(id: String) -> float: return _requested.get(id, baseline(id))
func applied(id: String) -> float: return _applied.get(id, baseline(id))

func request(world: Node, id: String, value: Variant) -> bool:
	if not authorized(world) or not valid(id,value): return false
	_set_difference(_requested,id,value)
	if id in [SUN,IMPACT] or Contacts.DEFAULTS.has(id) or Ambient.CONTROLS.has(id) or Delivery.CONTROLS.has(id) or Affinities.CONTROLS.has(id) or Shelter.CONTROLS.has(id) or Astral.CONTROLS.has(id) or ClassArt.CONTROLS.has(id): return apply(world,[id])
	return true

func _set_difference(values: Dictionary, id: String, value: float) -> void:
	if is_equal_approx(value,baseline(id)): values.erase(id)
	else: values[id] = value

func apply(world: Node, ids: Array) -> bool:
	if not authorized(world): return false
	for id in ids:
		if not PROPERTIES.has(id): return false
	for id in ids: _set_difference(_applied,id,requested(id))
	sync_scene(world)
	return true

func replace(world: Node, changes: Dictionary) -> bool:
	if not authorized(world): return false
	for id in changes:
		if not valid(id,changes[id]): return false
	_requested.clear()
	for id in changes: _set_difference(_requested,id,changes[id])
	return apply(world,PROPERTIES.keys())

func reset(world: Node, ids: Array) -> bool:
	if not authorized(world): return false
	for id in ids:
		if not PROPERTIES.has(id): return false
	for id in ids: _requested.erase(id)
	return apply(world,ids)

func generate_specimen(world: Node, starter: int, occupied: Array, reserved_root: Dictionary) -> Dictionary:
	if not authorized(world): return {}
	var depth: int=world.participation.floor()
	var chance:=applied(FLORA)
	if starter<0 and world.battlefield.boss_kind<0: last_used[FLORA]=chance
	# Banking uses the site it would have received with the production flora roll.
	# A newly enabled specimen finds a clear site around that existing reservation.
	if starter<0 and _applied.has(FLORA) and "checkpoint_deposit" in world.progress.heart.unlocked:
		var ordinary: Dictionary=world.battlefield.generate_flora(depth,starter,occupied)
		reserved_root.position=world.battlefield.generate_returning_root(depth,"reaching_tendrils" in world.progress.heart.unlocked,occupied,ordinary.get("position",Vector3.INF))
	return world.battlefield.generate_flora(depth,starter,occupied,chance/100.0,reserved_root.get("position",Vector3.INF))

func gameplay_modified() -> bool:
	for id in [SPEAR,WATER,FLORA]:
		if _requested.has(id) or _applied.has(id): return true
	return false

func sync_scene(world: Node) -> void:
	if not authorized(world): return
	_active_stage = weakref(world.stage)
	_set_scene(world,_applied.get(SUN,NAN),applied(WATER),applied(IMPACT))

func discard_disabled(world: Node) -> void:
	if _owner == null or _owner.get_ref() != world or not Developer.is_test_garden(world) or world.app_settings.values.developer_mode: return
	_requested.clear()
	_applied.clear()
	last_used.clear()
	_set_scene(world,NAN,baseline(WATER),baseline(IMPACT))
	if is_instance_valid(world.developer_workbench): world.developer_workbench.hide(); world.developer_workbench.opened=false

func _set_scene(world: Node, sun: float, water: float, emission: float) -> void:
	var restoring_disabled: bool = _owner != null and _owner.get_ref() == world and Developer.is_test_garden(world) and not world.app_settings.values.developer_mode and is_nan(sun) and is_equal_approx(water,baseline(WATER)) and is_equal_approx(emission,baseline(IMPACT))
	if not authorized(world) and not restoring_disabled: return
	world.stage.preview_sun_energy = sun
	world.stage.apply_scene_sun(world.stage.production_sun_energy)
	var effects: Node = world.stage.get_node("CombatEffects")
	effects.impact_emission = emission
	effects.contact_overrides = contact_values()
	effects.set_affinity_tuning(affinity_values())
	world.stage.weapon_vfx_values = motion_values()
	effects.motion_overrides = world.stage.weapon_vfx_values
	var plot: Node = world.stage.experimental_garden
	if is_instance_valid(plot): plot.set_ambient_tuning(ambient_values())
	var coverage = world.progress.irrigation
	if is_equal_approx(coverage.radius_base_sprinkler,water): return
	# Settle the partial growth tick at its previous rate before recomputing coverage.
	if world.growth_clock > 0.0:
		var elapsed: float = world.growth_clock
		world.growth_clock = 0.0
		if world.persistence_session.is_guarded(): world.guarded_growth_tick(elapsed)
		elif world.progress.advance_growth(elapsed,world.participation.active()) and not world.is_practice_world():
			if world.progress.save_garden()!=OK: world.status="Plant growth could not be saved. Use Save Garden to retry."
	coverage.set_sprinkler_radius(water,world.progress.structures,world.progress.heart.unlocked)
	var garden: Node = world.stage.experimental_garden
	if garden != null and garden.ghost != null and garden.ghost.visible: garden._show_ghost()

func affinity_values() -> Dictionary:
	var result:={}
	for id in _applied:
		if Affinities.CONTROLS.has(id) or Shelter.CONTROLS.has(id) or Astral.CONTROLS.has(id) or ClassArt.CONTROLS.has(id): result[id]=_applied[id]
	return result

func motion_values() -> Dictionary:
	var result := {}
	for id in _applied:
		if Delivery.CONTROLS.has(id): result[id]=_applied[id]
	return result

func ambient_values() -> Dictionary:
	var result := {}
	for id in _applied:
		if Ambient.CONTROLS.has(id): result[id] = _applied[id]
	return result

func contact_values() -> Dictionary:
	var result := {}
	if _applied.has("frost.mist"): result["frost.mist"]=_applied["frost.mist"]
	for id in Contacts.DEFAULTS:
		if _applied.has(id): result[id] = _applied[id]
	return result

func replay(world: Node, original := false) -> bool:
	if not authorized(world) or not world.players.has(world.HOST): return false
	var actor: Dictionary = world.players[world.HOST]
	var skill: Dictionary = world.combat_build(actor).class_skill(replay_slot)
	if skill.is_empty(): return false
	var wild: bool = world.participation.active()
	var from: Vector3 = actor.pos
	var to: Vector3 = from + actor.facing * 2.0
	var effects: Node = world.stage.get_node("CombatEffects")
	effects.preview_skill_impact(skill,from,to,wild,baseline(IMPACT) if original else applied(IMPACT),
		preload("res://weapon_motion.gd").form(actor),{} if original else contact_values())
	return true
