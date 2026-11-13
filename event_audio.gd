extends Node

const Combat = preload("res://combat_audio.gd")
const DEFINITIONS := {
	"trophy_taken":{"samples":["theft_1","theft_2"],"wild":true,"priority":3,"gain":-4.5,"max_age":1.35,"repeat_ms":0},
	"gate_ready":{"samples":["gate_ready"],"wild":true,"priority":2,"gain":-7.0,"max_age":1.1,"repeat_ms":0},
	"extract_ready":{"samples":["extract_ready"],"wild":true,"priority":2,"gain":-6.5,"max_age":1.1,"repeat_ms":0},
	"vessel_filled":{"samples":["fill_1","fill_2"],"wild":false,"priority":1,"gain":-9.5,"max_age":.75,"repeat_ms":120,"range":7.5},
	"crop_watered":{"samples":["water_1","water_2"],"wild":false,"priority":1,"gain":-8.5,"max_age":.75,"repeat_ms":120,"range":7.5},
	"crop_harvested":{"samples":["harvest_1","harvest_2"],"wild":false,"priority":1,"gain":-8.5,"max_age":.75,"repeat_ms":90,"range":7.5},
	"research_complete":{"samples":["research_complete"],"wild":false,"priority":2,"gain":-7.0,"max_age":1.0,"repeat_ms":0},
}
static var combat_definitions := Combat.definitions()
const MAX_VOICES := 5
const MAX_RECEIPTS := 256

var context_key := ""
var listener_id := 0
var receipts: Dictionary = {}
var last_played: Dictionary = {}
var voices: Array[Dictionary] = []
var samples: Dictionary = {}
var audible := false


func _ready() -> void:
	audible = DisplayServer.get_name() != "headless"


static func definition(id: String) -> Dictionary:
	return DEFINITIONS.get(id,combat_definitions.get(id,{}))


static func emit(game: Node, id: String, at: Vector3) -> void:
	var cue := definition(id)
	if game.multiplayer.is_server() and not cue.is_empty():
		game.emit_combat_event("audio",id,at,at,float(cue.max_age),Color.WHITE,0.0,0)


static func enemy(game: Node, attack: Dictionary, released: bool) -> void:
	emit(game,Combat.enemy(attack,released),attack.from)


static func weapon(game: Node, form: String, at: Vector3) -> void:
	emit(game,Combat.weapon(form,false),at)


static func play_research(game: Node, reveal: Dictionary) -> void:
	if str(reveal.get("technology","")).is_empty():
		return
	var audio := game.get_node_or_null("EventAudio")
	if audio != null:
		audio.request("research_complete","research:"+str(reveal.sequence),Vector3.ZERO,Vector3.ZERO,Time.get_ticks_msec())


func sync(events: Array, key: String, wild: bool, observer: Vector3, viewer: int, now: int) -> void:
	if key != context_key or viewer != listener_id:
		stop_voices()
		last_played.clear()
		context_key = key
		if viewer != listener_id:
			receipts.clear()
			listener_id = viewer
	reap(now)
	var pending: Array[Dictionary] = []
	for event in events:
		var receipt := "event:"+str(event.id)
		if receipts.has(receipt):
			continue
		var id: String = event.shape if event.kind == "audio" else Combat.presentation(event) if wild else ""
		var cue := definition(id)
		if cue.is_empty() or cue.wild != wild or float(event.get("age",0.0)) >= float(cue.max_age):
			continue
		var to: Array = event.to
		var at := Vector3(to[0],to[1],to[2])
		var personal: bool = event.kind == "impact" and event.shape in ["hurt","block"] and int(event.get("combo",0)) == viewer
		pending.append({"cue":id,"receipt":receipt,"at":at,"distance":at.distance_to(observer),"personal":personal,
			"priority":int(cue.priority)+(2 if personal else 0)})
	pending.sort_custom(func(a,b): return a.distance < b.distance if a.priority == b.priority else a.priority > b.priority)
	for item in pending:
		request(item.cue,item.receipt,item.at,observer,now,item.personal)


func request(id: String, receipt: String, at: Vector3, observer: Vector3, now: int, personal: bool = false) -> bool:
	var cue := definition(id)
	if cue.is_empty() or receipts.has(receipt):
		return false
	receipts[receipt] = true
	if receipts.size() > MAX_RECEIPTS:
		receipts.erase(receipts.keys()[0])
	var distance := at.distance_to(observer)
	if cue.has("range") and distance > float(cue.range):
		return false
	if now-int(last_played.get(id,-1000000)) < int(cue.repeat_ms):
		return false
	reap(now)
	var priority := int(cue.priority)+(2 if personal else 0)
	var weakest := 0
	if voices.size() >= MAX_VOICES:
		for index in range(1,voices.size()):
			var other: Dictionary = voices[index]
			var current: Dictionary = voices[weakest]
			if other.priority < current.priority or (other.priority == current.priority and other.distance > current.distance):
				weakest = index
		var old: Dictionary = voices[weakest]
		if old.priority > priority or (old.priority == priority and old.distance <= distance+1.0):
			return false
		release_voice(weakest)
	var variants: Array = cue.samples
	var variant: String = variants[posmod(receipt.hash(),variants.size())]
	if not samples.has(variant):
		samples[variant] = load("res://assets/audio/cues/"+variant+".wav")
	var stream: AudioStream = samples[variant]
	if stream == null:
		return false
	var player: Node = play_voice(stream,cue,at,distance,personal) if audible else null
	voices.append({"cue":id,"priority":priority,"distance":distance,"end":now+ceili(stream.get_length()*1000.0)+65,"player":player})
	last_played[id] = now
	return true


func play_voice(stream: AudioStream, cue: Dictionary, at: Vector3, distance: float, personal: bool) -> Node:
	var player: Node
	var gain := float(cue.gain)+(3.0 if personal else 0.0)
	if cue.has("range") and not personal:
		var point := AudioStreamPlayer3D.new()
		add_child(point)
		point.position = at + Vector3.UP*.25
		if cue.wild:
			point.position += get_parent().Stage.WILD_OFFSET
		point.attenuation_model = AudioStreamPlayer3D.ATTENUATION_DISABLED
		point.attenuation_filter_cutoff_hz = 20500
		point.panning_strength = .65
		# The camera sits above the party. Use the avatar's distance for loudness.
		gain += linear_to_db(1.0-.72*smoothstep(1.0,float(cue.range),distance))
		player = point
	else:
		player = AudioStreamPlayer.new()
		add_child(player)
	player.stream = stream
	player.bus = &"SFX"
	player.volume_db = gain
	player.play()
	return player


func reap(now: int) -> void:
	for index in range(voices.size()-1,-1,-1):
		if now >= int(voices[index].end):
			release_voice(index)


func release_voice(index: int) -> void:
	var player: Node = voices[index].player
	voices.remove_at(index)
	if is_instance_valid(player):
		player.stop()
		player.stream = null
		player.queue_free()


func stop_voices() -> void:
	for index in range(voices.size()-1,-1,-1):
		release_voice(index)


func _exit_tree() -> void:
	stop_voices()
