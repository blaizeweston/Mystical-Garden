extends RefCounted
## Called inside the self-verifying multi-process developer lifecycle fixture.
const Tune = preload("res://developer_arena/tuning.gd")
const Presets = preload("res://developer_arena/tuning_presets.gd")
const Developer = preload("res://developer_mode.gd")

static func garden(world: Node) -> String:
	var tune: RefCounted=world.developer_tuning
	if not tune.authorized(world) or not Developer.toggle_workbench(world): return "developer Garden workbench"
	var panel: Control=world.developer_workbench
	if panel.tuning_editor.rows.size()!=Tune.PROPERTIES.size() or panel.tuning_editor.category.get_tab_count()!=5: return "property catalog UI"
	panel.toggle()
	if not is_equal_approx(tune.baseline(Tune.SUN),world.get_node("Stage/Sun").light_energy) or not is_equal_approx(tune.baseline(Tune.SUN),1.05): return "active Garden baseline"
	if not is_equal_approx(tune.baseline(Tune.SPEAR),3.1) or not is_equal_approx(tune.baseline(Tune.WATER),3.5) or not is_equal_approx(tune.baseline(Tune.FLORA),40.0) or not is_equal_approx(tune.baseline(Tune.IMPACT),.65): return "owner baselines"
	for entry in [[Tune.SPEAR,NAN],[Tune.WATER,-1],[Tune.FLORA,101],[Tune.SUN,"2"],["unknown",1]]:
		if tune.request(world,entry[0],entry[1]): return "bad property accepted"
	var fake:=Node.new()
	var refused: bool=not tune.request(fake,Tune.SUN,3.0) and not tune.replace(fake,{}) and tune.directory(fake).is_empty()
	fake.free()
	if not refused: return "forged session"
	tune.request(world,Tune.SUN,2.4)
	world.stage.focus(Vector3.ZERO,false)
	if not is_equal_approx(world.get_node("Stage/Sun").light_energy,2.4): return "light lost during presentation"
	tune.reset(world,[Tune.SUN])
	if not is_equal_approx(world.get_node("Stage/Sun").light_energy,1.05): return "light reset"
	var store:=Presets.new(world)
	tune.request(world,Tune.SPEAR,4.6)
	var tracked := {}
	for d: Dictionary in Tune.PROPERTIES.values(): tracked[d.source]=FileAccess.get_sha256("res://"+str(d.source))
	var origin:=store.snapshot("Pair")
	if origin.properties.size()!=1 or str(origin.properties[0].fingerprint).length()<64 or (FileAccess.file_exists("res://.git") and origin.commit.length()!=40): return "fingerprints, differences or git"
	if not store.save_new("Pair").is_empty() or store.save_new("Pair").is_empty() or store.save_new("../outside").is_empty(): return "new preset"
	if not store.copy_named("Pair","Copy",false).is_empty() or not store.copy_named("Copy","Restart",true).is_empty() or "Copy" in store.names(): return "duplicate/rename"
	if store.remove("Pair",false).is_empty() or not store.remove("Pair",true).is_empty(): return "confirmed delete"
	var conflict:=store.read("Restart")
	conflict.name="Historical"
	conflict.properties[0].original=3.4
	if not store._new_file(tune.directory(world),conflict).is_empty(): return "historical fixture"
	var report:=store.compare(conflict)
	if report.conflicts.size()!=1 or not report.invalid.is_empty() or store.load_named("Historical").is_empty(): return "unreviewed baseline conflict"
	if not store.load_named("Historical",store.review_token(conflict,report)).is_empty(): return "explicit baseline conflict resolution"
	var export:=store.export_review("Historical")
	for path in tracked:
		if FileAccess.get_sha256("res://"+path)!=tracked[path]: return "export changed a production source"
	var proposal: Dictionary=store._read(export.path_join("changes.json"))
	if proposal.get("differences",[]).size()!=1 or proposal.conflicts.size()!=1 or not FileAccess.file_exists(export.path_join("changes.md")): return "bounded review export"
	conflict.properties[0].original=3.1
	conflict.properties[0].fingerprint="sha256:other"
	if store.compare(conflict).conflicts.size()!=1: return "uncommitted source conflict"
	var bad:=origin.duplicate(true)
	bad.name="Bad"
	bad.properties.append({"id":"retired"})
	bad.properties[0].modified=3.9
	if not store._new_file(tune.directory(world),bad).is_empty() or store.load_named("Bad").is_empty() or not is_equal_approx(tune.applied(Tune.SPEAR),4.6): return "partial invalid preset"
	bad.properties[0].modified=900
	if store.compare(bad).invalid.size()!=2: return "invalid experimental value"
	bad.format=999
	if store.compare(bad).invalid.is_empty(): return "incompatible format"
	tune.reset(world,Tune.PROPERTIES.keys())
	return ""

static func coverage(world: Node) -> String:
	var tune: RefCounted=world.developer_tuning
	var g=world.progress
	var water=g.irrigation
	var inventory: Dictionary=g.structures.duplicate(true)
	inventory.instances[91001]={"kind":"intake","placed":true,"at":Vector2.ZERO}
	inventory.instances[91002]={"kind":"sprinkler","placed":true,"at":Vector2.ZERO}
	var old: Dictionary=g.structures
	var bed: Dictionary=g.plots[0].duplicate(true)
	var actor: Dictionary=world.players[1]
	actor.pos=world.stage.bed_position(0)
	world.seed_reserve(actor).stock[0]=1
	if not world.cultivation.plant_seed(1,0): return "fixture crop"
	g.structures=inventory
	for entry in g.structures.instances.values():
		if entry.kind=="bed" and entry.slot==0: entry.at=Vector2(4,0)
	g.structures.revision+=1
	water.resolve(g.structures,g.heart.unlocked)
	world.growth_clock=.5
	tune.request(world,Tune.WATER,4.0)
	if water.watered_slots.has(0) or not is_equal_approx(water.radius("sprinkler"),3.5): return "premature coverage"
	var age: float=g.plots[0].age
	tune.apply(world,[Tune.WATER])
	if not is_equal_approx(g.plots[0].age,age+.5) or not water.beds_in_range(Vector2.ZERO).has(0) or not world.cultivation.projection(1).beds[0].sprinkler: return "inclusive preview, partial tick and inspector"
	g.advance_growth(4)
	if not is_equal_approx(g.plots[0].age,age+5.5): return "covered watering rate"
	var upgraded: Array=g.heart.unlocked.duplicate()
	upgraded.append("sprinkler_coverage")
	water.resolve(g.structures,upgraded)
	if not is_equal_approx(water.radius("sprinkler"),5.0): return "coverage upgrade precedence"
	g.structures=old
	g.plots[0]=bed
	tune.reset(world,[Tune.WATER])
	return ""

static func arena(world: Node) -> String:
	var tune: RefCounted=world.developer_tuning
	var before: Dictionary=world.round_stats().party.duplicate(true)
	var fx: Node=world.stage.get_node("CombatEffects")
	var events: Array=world.combat_events.duplicate(true)
	tune.request(world,Tune.IMPACT,2.5)
	if not tune.replay(world) or not is_equal_approx(fx.preview_effects[1].material.get_shader_parameter("energy"),2.5): return "visual-only replay"
	if not tune.replay(world,true) or not is_equal_approx(fx.preview_effects[1].material.get_shader_parameter("energy"),.65): return "baseline and tuned replay use real impact materials"
	var packet={"id":812,"kind":"impact","shape":"hit","duration":.2,"from":[0,0,0],"to":[0,0,0],"color":Color.WHITE,"reach":1,"amount":1,"form":"blade"}
	fx.sync([packet],[],"test",Vector3.ZERO)
	if not is_equal_approx(fx.active[812].material.get_shader_parameter("energy"),2.5): return "next confirmed hit presentation"
	var lab=world.workbench.tuning_editor.lab
	lab.formation.select(2)
	lab.arrange_targets()
	lab.selection.select(2)
	lab.select_effect()
	lab.mode.select(0)
	lab.play(false)
	lab.single_step()
	var age: float=lab.clock
	if lab.samples.size()!=6 or not is_equal_approx(age,lab.FRAME) or lab.running: return "six stepped isolated effects"
	var first=lab.samples[0]
	if first.mesh.mesh!=lab.samples[1].mesh.mesh or first.material==lab.samples[1].material: return "shared geometry or isolated clock"
	if tune.request(world,"rupture.count",4.5) or tune.request(world,"impact.lifetime",2.0): return "invalid VFX bounds"
	if not tune.request(world,"rupture.size",1.65): return "VFX tuning rejected"
	lab.mode.select(1)
	lab.compare_at_phase()
	if lab.clock!=age or lab.running or not is_equal_approx(lab.samples[0].material.get_shader_parameter("size_scale"),1.65): return "phase-matched experimental replay"
	lab.pause_resume()
	lab.repeat.button_pressed=true
	var material_before: ShaderMaterial=lab.samples[0].material
	var children_before: int=lab.scene.get_child_count()
	for repeat_index in 120: lab._process(lab.CYCLE)
	if lab.samples[0].material!=material_before or lab.scene.get_child_count()!=children_before: return "repeat allocated extra particles or materials"
	if not lab.running or lab.samples.size()!=6: return "loop rewind"
	lab.stop()
	if not lab.samples.is_empty() or lab.started: return "lab cleanup"
	var rupture={"id":830,"kind":"ability","shape":"frost_rupture","label":"Brittle rupture","from":[0,0,0],"to":[0,0,0],"color":Color.WHITE,"duration":.55}
	var second: Dictionary=rupture.duplicate(); second.id+=1
	fx.clear()
	fx.sync([rupture,second,rupture],[],"cold",Vector3.ZERO)
	if fx.active.size()!=2 or fx.feedback.labels.size()!=1: return "two ruptures, one nearby caption"
	tune.request(world,"rupture.repeat_labels",1)
	fx.clear()
	fx.sync([rupture,second],[],"cold",Vector3.ZERO)
	if fx.active.size()!=2 or fx.feedback.labels.size()!=2: return "show both confirmed captions"
	fx.step(.56)
	if not fx.active.is_empty(): return "expired bursts"
	fx.clear()
	tune.reset(world,["rupture.repeat_labels"])
	var presets:=Presets.new(world)
	if not presets.save_new("VFX02 Test").is_empty(): return "save VFX preset"
	tune.reset(world,["rupture.size",Tune.IMPACT])
	if not presets.load_named("VFX02 Test").is_empty() or not is_equal_approx(tune.applied("rupture.size"),1.65): return "restore VFX preset"
	var exported:=presets.export_review("VFX02 Test")
	if presets._read(exported.path_join("changes.json")).differences.size()!=2: return "VFX export mismatch"
	tune.reset(world,["rupture.size"])
	if world.round_stats().party!=before or world.combat_events!=events: return "visual replay modified combat"
	tune.reset(world,[Tune.IMPACT])
	var actor: Dictionary=world.players[1]
	actor.frame=0
	actor.weapon_kind=1
	actor.mouse_aim=true
	actor.aim_direction=Vector3.RIGHT
	world.spawn_selection("Target",0,1,"Single",true)
	var now: int=world.CombatClock.now()
	var port=world.weapon_attack_world
	var queue=world.weapon_attacks
	var base_stats: Dictionary=world.combat_build(actor).basic_stats()
	var reach: float=base_stats.reach
	world.encounter.scout(0).pos=actor.pos+Vector3.RIGHT*(reach+1.2)
	if not queue.try_start(port,1,actor.pos,now): return "first actual spear attack"
	tune.request(world,Tune.SPEAR,6.1)
	tune.apply(world,[Tune.SPEAR])
	if not is_equal_approx(queue.savepoint().pending[0].stats.reach,reach): return "accepted attack changed"
	queue.advance(port,now+900)
	if world.round_stats().party.damage!=before.damage: return "short spear reached distant target"
	if not queue.try_start(port,1,actor.pos,now+2000): return "second actual spear attack"
	var shot: Dictionary=queue.savepoint().pending[0]
	if not is_equal_approx(shot.stats.reach,reach+3.0) or not is_equal_approx(shot.origin.distance_to(shot.aim),shot.stats.reach): return "indicator and contact reach"
	queue.advance(port,now+3000)
	if world.round_stats().party.damage<=before.damage: return "extended spear did not hit"
	actor.weapon_kind=0
	if not is_equal_approx(port.capture_attack(1,now+4000).reach,world.combat_build(actor).basic_stats().reach): return "non-spear changed"
	tune.reset(world,Tune.PROPERTIES.keys())
	world.reset_statistics()
	world.clear_enemies()
	return ""

static func wild(world: Node) -> String:
	var tune: RefCounted=world.developer_tuning
	if not Developer.toggle_workbench(world) or not world.developer_workbench.visible: return "developer Wilds workbench"
	world.developer_workbench.toggle()
	var specimen: Dictionary=world.wild_flora_view(1)
	if specimen.is_empty(): return "introductory specimen"
	world.players[1].pos=specimen.position
	if not world.harvest_wild_flora(1,specimen.identity): return "fixture claim"
	var first: Dictionary=world.wild_flora.savepoint()
	tune.request(world,Tune.FLORA,0.0)
	tune.apply(world,[Tune.FLORA])
	if world.wild_flora.savepoint()!=first: return "existing specimen or claims changed"
	var field=world.battlefield
	if field.generate_flora(1,0,[],0.0).is_empty(): return "introductory override"
	world.participation.advance(world.participation.epoch(),world.ROUTE_ROOMS-1)
	world.participation.begin_floor(0)
	world.participation.advance(world.participation.epoch(),world.ROUTE_ROOMS-1)
	world.boss_floors[str(world.participation.floor())]=-1
	if not "checkpoint_deposit" in world.progress.heart.unlocked: world.progress.heart.unlocked.append("checkpoint_deposit")
	world.map_rng.seed=310719
	world.rng.seed=1589
	var terrain_rng: int=world.map_rng.state
	for attempt in 128:
		terrain_rng=world.map_rng.state
		var map_seed: int=world.map_rng.randi_range(1,2147483647)
		var next_key:=Vector3i(world.participation.route(),world.participation.depth(),map_seed)
		if world.Battlefield.root_random(next_key,world.participation.floor()).randf()<world.WildFlora.ROOT_CHANCE: break
	world.map_rng.state=terrain_rng
	var combat_rng: int=world.rng.state
	world.start_encounter()
	var key: Vector3i=world.battlefield.configured_key
	var spawn: Array=world.battlefield.spawn_points.duplicate()
	var cache: bool=world.battlefield.has_seed_cache()
	var root_position: Vector3=world.wild_flora.savepoint().root_position
	if not root_position.is_finite(): return "expected a real Returning Root on the fixed seed"
	if not world.wild_flora.view("test").is_empty(): return "zero chance"
	world.wild_flora.clear()
	world.map_rng.state=terrain_rng
	world.rng.state=combat_rng
	tune.request(world,Tune.FLORA,100.0)
	tune.apply(world,[Tune.FLORA])
	world.start_encounter()
	if world.battlefield.configured_key!=key or world.battlefield.spawn_points!=spawn or world.battlefield.has_seed_cache()!=cache or world.wild_flora.savepoint().root_position!=root_position: return "unrelated generation changed"
	if world.wild_flora.view("test").is_empty(): return "certain flora on eligible floor"
	world.save_and_quit(false)
	if world.expedition_saved_for_exit or not world.progress.suspended_expedition.is_empty() or not world.status.contains("tuning"): return "unsafe suspension"
	tune.reset(world,Tune.PROPERTIES.keys())
	return ""

static func restarted(world: Node) -> String:
	var store:=Presets.new(world)
	var tune: RefCounted=world.developer_tuning
	if tune.gameplay_modified() or "Restart" not in store.names() or "Pair" in store.names(): return "preset lost or auto-activated"
	if not store.load_named("Restart").is_empty() or not is_equal_approx(tune.applied(Tune.SPEAR),4.6): return "load after process restart"
	tune.reset(world,Tune.PROPERTIES.keys())
	return ""
