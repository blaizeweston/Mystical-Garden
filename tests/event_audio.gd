extends SceneTree

const ExpeditionCase = preload("res://tests/support/expedition_case.gd")

const Cues = preload("res://event_audio.gd")
const Attacks = preload("res://enemy_attack.gd")
var failed := false


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		printerr("FAIL event audio: ",message)


func event(id: int, cue: String, age: float=0.0) -> Dictionary:
	return {"id":id,"kind":"audio","shape":cue,"to":[0,0,0],"age":age}


func verify_mix(mix: Node) -> void:
	for cue in Cues.DEFINITIONS.values()+Cues.combat_definitions.values():
		for variant in cue.samples:
			var stream: AudioStreamWAV = load("res://assets/audio/cues/"+variant+".wav")
			check(stream!=null and stream.loop_mode==AudioStreamWAV.LOOP_DISABLED and stream.get_length()>.25,
				variant+" is an imported one-shot")
	mix.sync([event(1,"trophy_taken"),event(1,"trophy_taken"),event(2,"gate_ready",4.0)],"wild:1",true,Vector3.ZERO,1,500)
	check(mix.voices.size()==1 and mix.last_played.has("trophy_taken"),"duplicate packets and expired events play at most once")
	mix.sync([event(1,"trophy_taken")],"wild:2",true,Vector3.ZERO,1,700)
	check(mix.voices.is_empty(),"floor transitions stop the old cue and keep its receipt")
	mix.sync([event(3,"crop_watered")],"wild:2",true,Vector3.ZERO,1,750)
	check(mix.voices.is_empty(),"Garden sounds stay out of Wilds playback")
	mix.sync([event(4,"crop_watered")],"garden",false,Vector3(18,0,0),1,900)
	mix.sync([event(4,"crop_watered")],"garden",false,Vector3.ZERO,1,940)
	check(mix.voices.is_empty(),"a distant interaction cannot replay when the listener moves closer")
	for index in Cues.MAX_VOICES:
		check(mix.request("crop_harvested","harvest:"+str(index),Vector3.ZERO,Vector3.ZERO,1000+index*100),"low-priority voice is accepted")
	check(mix.request("trophy_taken","important",Vector3.ZERO,Vector3.ZERO,1500),"theft takes priority in a full mix")
	check(mix.voices.size()==Cues.MAX_VOICES and mix.voices.any(func(voice):return voice.cue=="trophy_taken"),"important cues replace a quieter voice within the cap")
	check(not mix.request("crop_harvested","excess",Vector3.ZERO,Vector3.ZERO,1510),"another quiet cue cannot evict an alert")
	mix.sync([],"wild:3",true,Vector3.ZERO,1,1520)
	check(mix.voices.is_empty(),"changing realm clears active cue voices")
	var far := event(10,"enemy_charge_windup")
	far.to = [10,0,0]
	var near := event(11,"enemy_charge_windup")
	near.to = [2,0,0]
	mix.sync([far,near],"wild:3",true,Vector3.ZERO,1,1600)
	check(mix.voices.size()==1 and is_equal_approx(mix.voices[0].distance,2.0),"nearer threats win the same-cue cooldown")


func verify_world(game: Node, mix: Node) -> void:
	var p: Dictionary = game.players[1]
	var growth: Node = game.get_node("GardenInteractions/GrowthScenes")
	growth.set_process(false)
	game._process(.016)
	game.progress.heart.complete(game.progress,"plot_4")
	check(game.progress.save_garden()==OK,"research commits")
	var saved: Dictionary = game.progress.garden_interactions.growth.events.back()
	game.app_settings.values.garden_cinematics = false
	growth.force_playback = true
	growth._process(0.0)
	check(mix.last_played.has("research_complete"),"research plays its cue even with cinematics disabled")
	var count: int = mix.voices.size()
	Cues.play_research(game,saved)
	check(mix.voices.size()==count,"replaying the same research receipt does not replay the cue")

	ExpeditionCase.set_membership(game, p, true)
	ExpeditionCase.set_world(game, {"destination": 0})
	game.encounter.set_hp(-1, 0)
	game.encounter.clear_scouts()
	ExpeditionCase.set_world(game, {"encounter_number": 5})
	game.finish_combat(1,Vector3.ZERO)
	game.finish_combat(1,Vector3.ZERO)
	var clears: Array = game.combat_events.filter(func(e):return e.kind=="audio")
	check(clears.size()==1 and clears[0].shape=="gate_ready","an ordinary clear produces exactly one gate cue")
	ExpeditionCase.set_world(game, {"encounter_number": 6})
	game.encounter_rewarded = false
	game.finish_combat(1,Vector3.ZERO)
	clears = game.combat_events.filter(func(e):return e.kind=="audio")
	check(clears.size()==2 and clears[1].shape=="extract_ready","extraction replaces the ordinary cue at its checkpoint")
	game._process(.016)
	check(game.combat_visuals.active.values().all(func(fx):return fx.event.kind!="audio"),"audio cues never instantiate combat visuals")


func run() -> void:
	var game: Node = load("res://world.tscn").instantiate()
	var base := "res://.godot/event-audio-"+str(Time.get_ticks_usec())
	game.progress.path = base+".cfg"
	game.local_character.path = base+".character"
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	var mix: Node = game.get_node("EventAudio")
	verify_mix(mix)
	verify_world(game,mix)
	verify_combat(game)
	mix.stop_voices()
	mix.audible = true
	var now := Time.get_ticks_msec()
	check(mix.request("trophy_taken","device-party",Vector3.ZERO,Vector3.ZERO,now),"party cue creates a player")
	check(mix.request("crop_watered","device-point",Vector3(2,0,0),Vector3.ZERO,now),"local cue creates a positional player")
	check(mix.voices[0].player is AudioStreamPlayer and mix.voices[1].player is AudioStreamPlayer3D
		and mix.voices[0].player.bus==&"SFX" and mix.voices[1].player.bus==&"SFX","both cue types use the effects volume")
	await create_timer(.10).timeout
	mix.stop_voices()
	check(mix.request("enemy_charge_windup","device-threat",Vector3(2,0,0),Vector3.ZERO,now+200),"enemy warning creates a voice")
	var warning: Node3D = mix.voices[0].player
	check(warning.position.is_equal_approx(game.Stage.WILD_OFFSET+Vector3(2,.25,0)),
		"the warning plays at the enemy in the Wilds")
	await create_timer(.15).timeout
	mix.stop_voices()
	await create_timer(.15).timeout
	game.queue_free()
	await process_frame
	if not failed:
		print("PASS: committed and canceled attack audio, hit feedback, spatial range, priority, research and gate cues")
	quit(1 if failed else 0)


func audio_ids(game: Node) -> Array:
	return game.combat_events.filter(func(e):return e.kind=="audio").map(func(e):return e.shape)


func verify_combat(game: Node) -> void:
	game.combat_events.clear()
	game.battlefield.configure(0,1,0)
	preload("res://tests/support/terrain_case.gd").walls(game.battlefield,[])
	game.encounter.set_hp(-1, 45)
	game.encounter.clear_scouts()
	var p: Dictionary = game.players[1]
	ExpeditionCase.set_membership(game, p, true)
	p.pos = Vector3(5,0,1)
	var now := Time.get_ticks_msec()
	var stag: Dictionary = game.make_scout(2,Vector3.ZERO,1)
	Attacks.lock(game,stag,"charge",Vector3(0,0,4),now+650)
	check(audio_ids(game)==["enemy_charge_windup"],"the stag warns when its charge commits")
	preload("res://scout_behavior.gd").release(game, stag,game.Enemies.get_kind(2),now+650)
	check(audio_ids(game)==["enemy_charge_windup","enemy_charge_release"],"a completed charge plays one release")
	game.combat_events.clear()
	stag.pos = Vector3.ZERO
	Attacks.lock(game,stag,"charge",Vector3(0,0,4),now+1600)
	preload("res://tests/support/terrain_case.gd").walls(game.battlefield,[Rect2(-1.2,2.1,2.4,1.3)])
	preload("res://scout_behavior.gd").release(game, stag,game.Enemies.get_kind(2),now+1600)
	check(audio_ids(game)==["enemy_charge_windup"],"a blocked charge cannot play a release")
	check(Cues.Combat.enemy({"mode":"charge","variant":"antler_hook"},false)=="enemy_hook_windup",
		"the bent charge has a distinct warning")
	preload("res://tests/support/terrain_case.gd").walls(game.battlefield,[])
	game.combat_events.clear()
	p.pos = Vector3.ZERO
	p.facing = Vector3.FORWARD
	p.mouse_aim = false
	game.tactics.position = Vector3(5,0,1)
	var stats: Dictionary = game.weapon_stats(p)
	game.MouseCombat.queue_attack(game,1,p,p.pos,stats,now,"blade",500)
	check(audio_ids(game).is_empty(),"a queued swing is silent before release")
	game.update_projectiles(now+500)
	check(audio_ids(game)==["weapon_blade_release"] and not game.combat_events.any(func(e):return e.kind=="impact"),
		"a missed swing plays only its release")
	game.combat_events.clear()
	game.MouseCombat.queue_attack(game,1,p,p.pos,stats,now+650,"fan",500)
	game.update_projectiles(now+1150)
	check(audio_ids(game)==["weapon_bow_release"],"a multi-projectile attack releases one sound")
	check(Cues.Combat.presentation({"kind":"impact","shape":"hit","form":"bow"})=="weapon_bow_hit"
		and Cues.Combat.presentation({"kind":"impact","shape":"block"})=="combat_block"
		and Cues.Combat.presentation({"kind":"proc","shape":"core_mark_burst"})=="combat_mark","confirmed hit, block and mark map to distinct cues")
