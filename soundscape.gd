extends Node

const Layout = preload("res://garden_layout.gd")
const BIOME_AMBIENCE := ["grove_air","mire_air","hollow_air","hollow_air"]
const TRACKS := {
	"garden_theme": {"bus":&"Music","gain":-9.0,"fade":2.0},
	"wilds_theme": {"bus":&"Music","gain":-10.0,"fade":2.0},
	"wilds_tension": {"bus":&"Music","gain":-16.0,"fade":2.4},
	"garden_air": {"bus":&"Ambience","gain":-12.0,"fade":1.5},
	"grove_air": {"bus":&"Ambience","gain":-13.0,"fade":1.5},
	"mire_air": {"bus":&"Ambience","gain":-13.0,"fade":1.5},
	"hollow_air": {"bus":&"Ambience","gain":-13.0,"fade":1.5},
	"spring_water": {"bus":&"Ambience","gain":-9.0,"fade":.72,"point":true},
	"heart_pulse": {"bus":&"Ambience","gain":-12.0,"fade":.72,"point":true},
}
var voices: Dictionary = {}
var levels: Dictionary = {}
var audible := false
var spring: Dictionary
var heart: Vector3


func _ready() -> void:
	audible = DisplayServer.get_name() != "headless"
	spring = Layout.zone("sheltered_spring")
	heart = get_parent().Stage.HEART


static func targets(wild: bool, site: int, floor_number: int, boss: bool, observer: Vector3,
		heart_point: Vector3, spring_point: Vector3, spring_open: bool) -> Dictionary:
	if wild:
		var intensity := .72 * smoothstep(3.0,18.0,float(floor_number))
		return {
			"wilds_theme":1.0,
			"wilds_tension":maxf(intensity,.92 if boss else 0.0),
			BIOME_AMBIENCE[clampi(site,0,BIOME_AMBIENCE.size()-1)]:1.0,
		}
	return {
		"garden_theme":1.0,
		"garden_air":1.0,
		"spring_water":1.0-smoothstep(1.3,8.5,observer.distance_to(spring_point)) if spring_open else 0.0,
		"heart_pulse":1.0-smoothstep(1.0,6.5,observer.distance_to(heart_point)),
	}


func update_mix(delta: float, wild: bool, site: int, floor_number: int, boss: bool,
		observer: Vector3, unlocked: Array) -> void:
	if not audible:
		return
	var spring_point: Vector3 = spring.water.position
	var desired := targets(wild,site,floor_number,boss,observer,heart,spring_point,Layout.enabled(spring,unlocked))
	apply_mix(desired,delta)


func apply_mix(desired: Dictionary, delta: float) -> void:
	for id in TRACKS:
		var definition: Dictionary = TRACKS[id]
		var target := float(desired.get(id,0.0))
		# The stem starts with the base loop so its accents stay on the same beat.
		var silent_stem: bool = id == "wilds_tension" and voices.has("wilds_theme") and voices.wilds_theme.playing
		var level := move_toward(float(levels.get(id,0.0)),target,maxf(0.0,delta)/float(definition.fade))
		var voice: Node = voices.get(id)
		if target <= 0.0 and level <= 0.0 and not silent_stem:
			if is_instance_valid(voice) and voice.playing:
				voice.stop()
			levels.erase(id)
			continue
		if not is_instance_valid(voice):
			voice = create_voice(id,definition)
		if not voice.playing:
			voice.volume_db = -80.0
			voice.play()
		voice.volume_db = float(definition.gain)+linear_to_db(maxf(level,.0001))
		levels[id] = level


func create_voice(id: String, definition: Dictionary) -> Node:
	var voice: Node
	if definition.get("point",false):
		var spatial := AudioStreamPlayer3D.new()
		add_child(spatial)
		spatial.position = spring.water.position if id == "spring_water" else heart
		spatial.attenuation_model = AudioStreamPlayer3D.ATTENUATION_DISABLED
		spatial.attenuation_filter_cutoff_hz = 20500
		spatial.panning_strength = .66
		voice = spatial
	else:
		voice = AudioStreamPlayer.new()
		add_child(voice)
	voice.stream = load("res://assets/audio/soundscape/"+id+".wav")
	voice.bus = definition.bus
	voices[id] = voice
	return voice


func _exit_tree() -> void:
	for voice in voices.values():
		voice.stop()
		voice.stream = null
