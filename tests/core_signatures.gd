extends SceneTree

const Core = preload("res://core_combat.gd")
const Rules = preload("res://core_skill_rules.gd")
const Status = preload("res://combat_status.gd")
const Mark = preload("res://core_strike_mark.gd")
var failed := false


func check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		printerr("FAIL core signatures: ", message)


func _initialize() -> void:
	preload("res://combat_balance_preview.gd").enabled = false
	call_deferred("run")


func fixture(game: Node) -> void:
	game.enemy_kind = 0
	game.enemy_hp = 30
	game.enemy_mutations = 0
	game.enemy_winding_up = false
	game.boss_kind = -1
	game.enemy_traits.clear()
	game.scouts.clear()
	game.battlefield.configure(0, 1, 0)
	game.battlefield.barriers.clear()


func run() -> void:
	var game: Node = load("res://world.tscn").instantiate()
	game.progress.path = "res://.godot/signatures-" + str(Time.get_ticks_usec()) + ".cfg"
	game.local_character.path = game.progress.path + ".character"
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	await process_frame
	var p: Dictionary = game.players[1]
	var whisper: int = game.Parts.index_of("plant:whispervine")
	var star: int = game.Parts.index_of("plant:star_orchid")
	var refined_whisper: int = game.Parts.rare_part(game.Parts.plant_source(whisper))
	var refined_star: int = game.Parts.rare_part(game.Parts.plant_source(star))
	var thorn: int = game.Parts.THORN
	var icons: Array = []
	for part in [thorn,game.Parts.MOSS,game.Parts.index_of("plant:cinder_vine"),whisper,star]:
		var build := Rules.resolve("0_0",[part],0)
		var refined: int = game.Parts.rare_part(game.Parts.plant_source(part))
		var variant := Rules.resolve("0_0",[refined],0)
		check(variant.primary == build.primary and variant.skill.id == build.skill.id, "harvest quality preserves signature for "+game.Parts.part_name(part))
		check(ResourceLoader.exists(build.skill.icon,"Texture2D") and not icons.has(build.skill.icon),"each active has its own usable icon")
		icons.append(build.skill.icon)
	var plain := Rules.resolve("0_0",[star],0)
	var altered := Rules.resolve("0_0",[refined_star,thorn,star],0)
	check(plain.primary=="constellation" and plain.secondary==["radiant","piercing"] and plain.skill.radius<altered.skill.radius, "signature and shared tags are independent")
	check(altered.skill.modifiers.size()==2 and int(altered.skill.root_ms)>int(plain.skill.root_ms),"Form and Catalyst affect the same skill by slot")
	var long_mark := Rules.resolve("0_0",[refined_whisper,refined_star,whisper],0)
	check(long_mark.skill.mark_ms==5800 and Rules.resolve("0_0",[whisper],0).skill.mark_ms==4300,"Catalyst spirit applies once")
	check(long_mark.form.has("constellation") and is_equal_approx(float(long_mark.skill.radius),.30),"signature tag from a refined Form part drives a data-only interaction")
	p.pos=game.Stage.GATE
	game.seed_reserve(p).parts[refined_whisper]=1
	game.handle_loadout_action(1,p,"loadpart_0_%d"%refined_whisper)
	var bench: Control=game.loadout_view
	bench.refresh()
	var index: int=bench.slots[0].get_item_index(refined_whisper)
	check(bench.core_preview.visible and bench.core_preview_icon.texture.resource_path.ends_with("whisper_mark.png"),"bench displays the crafted Core icon")
	check(index>=0 and bench.slots[0].get_popup().get_item_tooltip(index).contains("next direct hit"),"available Core part offers a hover explanation")
	check(bench.core_preview.tooltip_text==bench.slots[0].tooltip_text,"selected part and ability preview share the tooltip")
	game.enter_wilds(1,p)
	check(p.wild and p.weapon==refined_whisper and game.seed_reserve(p).parts[refined_whisper]==0,"refined part crafts through existing reservation and stock")
	fixture(game)
	p.pos=Vector3.ZERO
	game.enemy_pos=Vector3(0,0,-2.0)
	game.scouts.append(game.make_scout(0,Vector3(0,0,-4),1))
	game.garden_action(1,Core.request(game,p,Vector2(0,-1)))
	var cast: Dictionary=game.get_meta(Core.STATE,{}).get(1,{})
	if cast.is_empty():
		check(false,"Whisper Mark casts")
		await finish(game)
		return
	Core.tick(game,cast.armed)
	Status.sync(game,cast.armed)
	check(game.enemy_hp==30 and not Mark.active(game,game.enemy_traits,cast.armed).is_empty() and not game.scouts[0].get("traits",{}).has(Mark.STATE),"mark arrives on the first target without impact damage")
	check(game.combat_events.any(func(event):return event.shape=="core_strike_mark"),"persistent mark status is visible")
	game._process(.016)
	var hud: Control=game.player_hud
	check(hud.core_icon.resource_path.ends_with("whisper_mark.png") and hud.state.core.remaining>0,"icon stays loaded during cooldown")
	check(hud.skill_hover[2].visible and hud.skill_hover[2].tooltip_text.begins_with(bench.core_preview.tooltip_text) and hud.skill_hover[2].tooltip_text.contains("Release to cast") and hud.skill_hover[0].tooltip_text.contains("Release to cast"),"Wilds hover targets expose the same Core details and class text")
	check(hud.skill_hover[2].position.is_equal_approx(Vector2(392,hud.size.y-101)) and hud.skill_hover[2].size.is_equal_approx(Vector2(98,77)),"hover matches the drawn Core slot")
	var hit := {"damage":1,"knockback":-.35}
	var secondary:=hit.duplicate();secondary.trait_secondary=true
	game.apply_weapon_hit(p,-1,p.pos,secondary,cast.armed+10)
	check(game.enemy_hp==29 and game.enemy_traits.has(Mark.STATE),"secondary proc cannot consume the mark")
	game.apply_weapon_hit(p,-1,p.pos,hit,cast.armed+20)
	game.apply_weapon_hit(p,-1,p.pos,hit,cast.armed+30)
	check(game.enemy_hp==25 and not game.enemy_traits.has(Mark.STATE),"two strikes receive exactly one mark burst")
	check(game.combat_events.filter(func(event):return event.shape=="core_mark_burst").size()==1,"mark consumes once")

	fixture(game)
	p.weapon=refined_star;p.secondary=thorn;p.core_ready_at=0;p.core_cast_until=0;p.cast_until=0
	game.enemy_pos=Vector3(1.1,0,-1.9)
	game.scouts.assign([game.make_scout(0,Vector3(2.3,0,-1.9),1),game.make_scout(0,Vector3(2.3,0,-3.2),2)])
	var initial := Core.request(game,p,Vector2(0,-1),1.9)
	game.garden_action(1,initial)
	cast=game.get_meta(Core.STATE,{}).get(1,{})
	if cast.is_empty():
		check(false,"Constellation places a star")
		await finish(game)
		return
	Core.tick(game,cast.armed)
	check(Core.hints(game)[0].role=="core_anchor" and is_equal_approx(float(cast.center.z),-1.9),"anchor follows aimed distance and has a visible marker")
	var timer: int=p.core_ready_at
	game.garden_action(1,initial)
	game._process(.016)
	check(hud.core_icon.resource_path.ends_with("constellation.png") and hud.state.core.remaining>0 and hud.skill_hover[2].tooltip_text.contains("Widens the beam"),"HUD shows the skill's cooldown and Form tooltip")
	var fires: int=cast.fires_at
	var cursor := Vector2(3,-1.9)
	game.mouse_controls.receive(game,1,cursor.normalized()*(cursor.length()+2.0),false,fires-30)
	Core.tick(game,fires-1)
	check(game.rooted_until==0 and Core.hints(game).size()==1,"the star waits before firing")
	Core.tick(game,fires)
	var beam: Array=game.combat_events.filter(func(event): return event.kind=="swing" and event.shape=="constellation")
	check(beam.size()==1 and is_equal_approx(float(beam[0].from[0]),0) and float(beam[0].to[0])>5.5 and is_equal_approx(float(beam[0].width),.34),"beam fires automatically from the anchor toward the current cursor")
	check(game.rooted_until>fires and int(game.scouts[0].rooted_until)>fires and int(game.scouts[1].rooted_until)==0,"beam roots on-line enemies while leaving the off-line scout free")
	Core.tick(game,fires+100)
	check(Core.hints(game).is_empty() and p.core_ready_at==timer and game.combat_events.filter(func(event): return event.kind=="swing" and event.shape=="constellation").size()==1,"the star fires once and preserves the independent cooldown")
	game.return_to_garden(p)
	game._process(.016)
	check(not hud.skill_hover[2].visible,"Core hover target clears in the Garden")
	await finish(game)


func finish(game: Node) -> void:
	game.queue_free()
	await process_frame
	if not failed:
		print("PASS: signature inheritance, distinct icons, prepared and live tooltips, single direct-hit mark burst and automatic cursor-directed Constellation beam")
	quit(1 if failed else 0)
