extends SceneTree

const ExpeditionCase = preload("res://tests/support/expedition_case.gd")

const Soundscape = preload("res://soundscape.gd")
const Settings = preload("res://app_settings.gd")
const TitleMusic = preload("res://title_music.gd")
var failed := false


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		printerr("FAIL soundscape: ",message)


func run() -> void:
	var base := "res://.godot/soundscape-"+str(Time.get_ticks_usec())
	var game: Node = load("res://world.tscn").instantiate()
	game.progress.path = base+".garden"
	game.local_character.path = base+".character"
	game.settings_path = base+".settings"
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	var soundscape: Node = game.get_node("Soundscape")
	soundscape.audible = true

	var expected := {"garden_theme":59.52,"wilds_theme":64.0,"wilds_tension":64.0,"garden_air":47.0,
		"grove_air":39.0,"mire_air":42.0,"hollow_air":43.0,"spring_water":25.0,"heart_pulse":26.0}
	for id in Soundscape.TRACKS:
		var voice: Node = soundscape.create_voice(id,Soundscape.TRACKS[id])
		var stream: AudioStreamWAV = voice.stream
		check(stream!=null and stream.loop_mode==AudioStreamWAV.LOOP_FORWARD and absf(stream.get_length()-expected[id])<.05,
			id+" imports and loops at the intended length")
		check(voice.bus==Soundscape.TRACKS[id].bus,"correct audio bus for "+id)
		check((voice is AudioStreamPlayer3D)==bool(Soundscape.TRACKS[id].get("point",false)),"point sources use positional audio")

	var player: Dictionary = game.players[1]
	player.pos = game.Stage.HEART
	game._process(.5)
	check(is_equal_approx(soundscape.levels.garden_theme,.25) and soundscape.levels.heart_pulse>0,
		"the Garden music fades in and the Heart is audible nearby")
	check(not soundscape.levels.has("spring_water"),"the spring is silent before research")
	for tech in ["clearing_1","irrigation"]:
		game.progress.heart.complete(game.progress,tech)
	player.pos = preload("res://garden_water.gd").center(game.stage)
	game._process(.5)
	check(soundscape.levels.spring_water>.5 and not soundscape.levels.has("wilds_theme"),"the unlocked spring gains a local sound")
	player.pos = Vector3(-15,0,-12)
	game._process(1.0)
	check(not soundscape.levels.has("spring_water") and not soundscape.levels.has("heart_pulse"),"walking away fades both local sources")

	await create_timer(.12).timeout
	ExpeditionCase.set_membership(game, player, true)
	ExpeditionCase.set_world(game, {"destination": 0})
	ExpeditionCase.set_world(game, {"encounter_number": 1})
	game._process(.5)
	check(soundscape.levels.garden_theme>0 and soundscape.levels.wilds_theme>0 and soundscape.levels.grove_air>0,"going to the Grove crossfades music and ambience")
	var base_voice: Node = soundscape.voices.wilds_theme
	check(base_voice.playing and soundscape.voices.wilds_tension.playing and soundscape.levels.wilds_tension==0.0,"base and inaudible stem start together")
	game._process(2.0)
	check(not soundscape.voices.garden_theme.playing and is_equal_approx(soundscape.levels.wilds_theme,1.0),"Garden voices retire after the fade")
	ExpeditionCase.set_world(game, {"destination": 1})
	ExpeditionCase.set_world(game, {"encounter_number": 12})
	game._process(.5)
	check(soundscape.levels.mire_air>0 and soundscape.levels.grove_air>0 and soundscape.levels.wilds_tension>0,"Mire ambience and deeper tension fade in")
	ExpeditionCase.set_world(game, {"destination": 2})
	ExpeditionCase.set_world(game, {"encounter_number": 18})
	game._process(.5)
	check(soundscape.voices.wilds_theme==base_voice and soundscape.levels.hollow_air>0,"the theme continues through biome and floor changes")
	var boss := Soundscape.targets(true,2,1,true,Vector3.ZERO,Vector3.ZERO,Vector3.ZERO,false)
	check(is_equal_approx(float(boss.wilds_tension),.92),"boss entry raises the tension layer")

	await create_timer(.12).timeout
	ExpeditionCase.set_membership(game, player, false)
	game._process(2.6)
	check(soundscape.voices.garden_theme.playing and not base_voice.playing and not soundscape.voices.wilds_tension.playing,
		"returning to the Garden retires both Wilds music layers")
	var window: Window = game.settings_dialog
	window.begin(game.app_settings)
	window.music.value = 0.0
	window.ambience.value = 38.0
	window.save()
	var restored := Settings.new()
	restored.path = game.settings_path
	check(restored.load_settings()==OK and restored.values.music==0.0 and is_equal_approx(restored.values.ambience,.38),
		"music and ambience sliders persist independently")
	var music_bus := AudioServer.get_bus_index("Music")
	var ambience_bus := AudioServer.get_bus_index("Ambience")
	check(AudioServer.is_bus_mute(music_bus) and not AudioServer.is_bus_mute(ambience_bus) and not AudioServer.is_bus_mute(AudioServer.get_bus_index("SFX")),
		"muting music leaves ambience and combat effects audible")
	check(AudioServer.get_bus_send(music_bus)==&"Master" and AudioServer.get_bus_send(ambience_bus)==&"Master","Master controls the whole mix")
	await create_timer(.12).timeout
	soundscape.apply_mix({},3.0)
	await create_timer(.12).timeout
	game.queue_free()
	await process_frame
	Settings.new().apply()
	await verify_title()
	if not failed:
		print("PASS: looping title theme, transition fades, spatial ambience, biome crossfades and independent volume controls")
	quit(1 if failed else 0)


func verify_title() -> void:
	TitleMusic.set_playing(self,true)
	var player := root.get_node(NodePath(str(TitleMusic.PLAYER_NAME))) as AudioStreamPlayer
	var track := player.stream as AudioStreamWAV
	check(track.loop_mode==AudioStreamWAV.LOOP_FORWARD and absf(track.get_length()-49.92)<.05 and player.bus==&"Music",
		"title theme is a dedicated loop on the Music bus")
	var intro: Tween = player.get_meta("title_fade")
	intro.custom_step(1.2)
	TitleMusic.set_playing(self,true)
	check(root.get_node(NodePath(str(TitleMusic.PLAYER_NAME)))==player and player.get_meta("title_fade")==intro and player.playing,
		"staying in setup reuses the original title player")
	TitleMusic.set_playing(self,false)
	var exit_fade: Tween = player.get_meta("title_fade")
	exit_fade.custom_step(.4)
	TitleMusic.set_playing(self,true)
	var return_fade: Tween = player.get_meta("title_fade")
	return_fade.custom_step(1.2)
	check(player.playing and is_equal_approx(player.volume_db,TitleMusic.LEVEL) and not exit_fade.is_valid(),
		"an immediate return reverses the existing fade")
	TitleMusic.set_playing(self,false)
	var final_fade: Tween = player.get_meta("title_fade")
	final_fade.custom_step(1.2)
	check(not player.playing,"the title voice stops after the fade into play")
	await create_timer(.12).timeout
	player.queue_free()
	await process_frame
