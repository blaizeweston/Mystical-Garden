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
	var refused: bool=not tune.request(fake,Tune.SUN,3.0) and not tune.request(fake,"fire.height",1.3) and not tune.replace(fake,{}) and tune.directory(fake).is_empty()
	fake.free()
	if not refused: return "forged session"
	tune.request(world,Tune.SUN,2.4)
	world.stage.focus(Vector3.ZERO,false)
	if not is_equal_approx(world.get_node("Stage/Sun").light_energy,2.4): return "light lost during presentation"
	tune.reset(world,[Tune.SUN])
	if not is_equal_approx(world.get_node("Stage/Sun").light_energy,1.05): return "light reset"
	var plot=world.stage.experimental_garden
	var digest:=var_to_bytes([world.progress.plots,world.progress.structures,world.progress.heart.unlocked,world.progress.garden_development])
	var editor=panel.tuning_editor
	var lab=editor.lab
	for i in 5:
		lab.selection.select(4+i)
		lab.select_effect()
		editor.populate_visual_properties()
		lab.play(false)
		lab.seek(1.375)
		var group: String=lab.Exhibit.GROUPS[i]
		var knob: String=["heart.duration","root.width","intake.opacity","spray.height","pollen.size"][i]
		var mat: ShaderMaterial=lab.exhibit.controlled.back()
		var base: float=tune.baseline(knob)
		if not is_equal_approx(mat.get_shader_parameter(knob.get_slice(".",1)),base): return "ambient baseline "+group
		var proposed: float=Tune.PROPERTIES[knob].maximum
		if not tune.request(world,knob,proposed): return "ambient edit "+group
		lab.mode.select(1)
		lab.compare_at_phase()
		mat=lab.exhibit.controlled.back()
		if not is_equal_approx(mat.get_shader_parameter(knob.get_slice(".",1)),proposed) or not is_equal_approx(mat.get_shader_parameter("sample_time"),1.375): return "ambient phase comparison "+group
		if i==0:
			for age in 5:
				lab.heart_stage.select(age)
				lab.rebuild_at_phase()
				if not lab.exhibit.get_child(0).sculpt_models[age].visible: return "missing Heart stage"
		if group in ["intake","spray"]:
			lab.water.button_pressed=false
			if not lab.exhibit.controlled.is_empty(): return "dry station emitting"
			lab.water.button_pressed=true
		if group=="spray" and not is_equal_approx(plot.infrastructure.spray.material_override.get_shader_parameter("height"),proposed): return "Garden did not use experimental water height"
		lab.stop()
		lab.mode.select(0)
	if digest!=var_to_bytes([world.progress.plots,world.progress.structures,world.progress.heart.unlocked,world.progress.garden_development]): return "ambient lab changed Garden activity"
	var store:=Presets.new(world)
	if not store.save_new("Living Garden").is_empty(): return "ambient preset"
	tune.reset(world,Tune.PROPERTIES.keys())
	if not store.load_named("Living Garden").is_empty() or tune.ambient_values().size()!=5: return "ambient load"
	var review:=store.export_review("Living Garden")
	if store._read(review.path_join("changes.json")).differences.size()!=5: return "ambient review export"
	tune.reset(world,Tune.PROPERTIES.keys())
	if not is_equal_approx(plot.infrastructure.spray.material_override.get_shader_parameter("height"),tune.baseline("spray.height")): return "ambient reset"
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
	lab.selection.select(lab.WEAPON_SEQUENCE)
	lab.select_effect()
	lab.mode.select(0)
	for i in 15:
		lab.weapon_choice.select(i)
		lab.play(false)
		var example=lab.weapon_exhibit
		lab.seek(example.duration*float(example.profile.release))
		if example.form in example.Trail.FORMS:
			var trail=example.actor.visual_weapon.get_node("MotionTrail")
			if trail.tips.size()<2 or not trail.visible: return "missing sampled edge "+example.form
			if trail.tips.size()>trail.MAX_SAMPLES: return "unbounded edge"
			if example.form!="whip" and trail.tips.back().distance_to(example.actor.visual_weapon.get_node("WeaponTip").global_position)>.08: return "detached tip "+example.form
		if not example.flight.is_empty():
			lab.seek(example.duration*float(example.profile.release)+.02)
			if not example.flight.mesh.visible: return "missing preview flight "+example.form
		lab.seek(lab.duration())
		if example.form in example.Trail.FORMS and example.actor.visual_weapon.get_node("MotionTrail").visible: return "edge survived recovery "+example.form
		lab.stop()
	lab.weapon_choice.select(0)
	lab.play(false)
	lab.seek(.14)
	if not tune.request(world,"trail.opacity",.32): return "trail tuning"
	lab.mode.select(1)
	lab.compare_at_phase()
	if not is_equal_approx(lab.clock,.14) or lab.weapon_exhibit.values.get("trail.opacity")!=.32 or world.stage.weapon_vfx_values.get("trail.opacity")!=.32: return "same-phase tuned sequence"
	if not presets.save_new("Blade edge").is_empty(): return "edge preset"
	tune.reset(world,["trail.opacity"])
	if not presets.load_named("Blade edge").is_empty() or tune.applied("trail.opacity")!=.32: return "edge reload"
	var edge_export:=presets.export_review("Blade edge")
	if not presets._read(edge_export.path_join("changes.json")).differences.any(func(row):return row.id=="trail.opacity"): return "missing edge export"
	tune.reset(world,["trail.opacity"])
	lab.stop()
	lab.selection.select(lab.DODGE)
	lab.select_effect()
	lab.play(false)
	lab.single_step()
	if not lab.scuff.visible or lab.scuff.mesh.get_surface_count()!=1: return "foot scuff replay"
	lab.seek(.4)
	if lab.scuff.visible: return "foot dust survived decay"
	lab.stop()
	var affinity_error:=affinity_replay(world,lab,tune,presets)
	if not affinity_error.is_empty():return affinity_error
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

static func affinity_replay(world:Node,lab:Control,tune:RefCounted,presets:RefCounted) -> String:
	var fx:Node=world.stage.get_node("CombatEffects")
	var strip:={"kind":"capsule","from":[-1.,0.,0.],"to":[2.,0.,0.],"width":.68}
	var field:={"id":"field-5","role":"core_field","skill":"ember_wake","from":[0,0,0],"to":[0,0,0],"radius":2.15,"remaining":2.,"core_phase":1200,"color":"f29b57","core_shapes":[strip]}
	var wake:={"id":907,"kind":"ability","shape":"ember_trail","from":[-1,0,0],"to":[2,0,0],"duration":3.2,"reach":.68,"color":"f29b57","core_shapes":[strip],"label":"Ember Wake"}
	fx.sync([wake,wake],[field],"affinity-floor",Vector3.ZERO)
	var plant:MeshInstance3D=fx.hints[field.id].plants[0]
	if fx.active.has(907) or plant.position!=Vector3(.5,0,0) or plant.material_override.get_shader_parameter("extent")!=Vector2(1.5,.68):return "duplicate or displaced Ember Wake"
	if not is_equal_approx(plant.material_override.get_shader_parameter("elapsed"),1.2):return "mid-field snapshot phase"
	fx.sync([],[field],"affinity-floor",Vector3.ZERO)
	if fx.hints[field.id].plants[0]!=plant:return "field rebuilt on repeated snapshot"
	fx.sync([],[],"affinity-floor",Vector3.ZERO)
	if not fx.hints.is_empty() or not plant.get_parent().is_queued_for_deletion():return "stale field after withdrawal"
	var well:={"id":"well-6","role":"core_field","skill":"gravity_well","from":[2.,0.,1.],"to":[2.,0.,1.],"radius":2.8,"remaining":.8,"core_phase":240,"form":"singularity"}
	var admission:={"id":960,"kind":"field","shape":"gravity_well","from":well.from,"to":well.to,"reach":2.8,"duration":1.04,"color":"ad8bcb","combo":1}
	fx.sync([admission,admission],[well],"void-floor",Vector3.ZERO)
	var current:MeshInstance3D=fx.hints[well.id].astral
	if not fx.active.is_empty() or current.get_meta("astral_kind")!="singularity" or current.position!=Vector3(2,0,1) or not is_equal_approx(current.material_override.get_shader_parameter("extent"),2.8):return "duplicate or displaced field art"
	fx.sync([],[well],"void-floor",Vector3.ZERO)
	if fx.hints[well.id].astral!=current:return "field visual allocated again for unchanged snapshot"
	fx.sync([],[],"void-floor",Vector3.ZERO)
	if not fx.hints.is_empty() or not current.get_parent().is_queued_for_deletion():return "withdrawn field survived"
	for payoff in ["flashover","wildfire","hemorrhagic_rupture"]:
		var receipt:=wake.duplicate(true)
		receipt.id+=payoff.length()
		receipt.shape=payoff
		receipt.erase("core_shapes")
		fx.sync([receipt,receipt],[],"payoff-"+payoff,Vector3.ZERO)
		if fx.active.size()!=1 or not fx.active[receipt.id].has("payoff"):return "missing or duplicate "+payoff
	fx.clear()
	var wave:={"id":905,"kind":"projectile","shape":"dewfall","from":[-1,0,0],"to":[2,0,0],"duration":.55,"age":.275,"reach":1.05,"combo":1,"color":"82d7ec"}
	fx.sync([wave,wave],[],"water-floor",Vector3.ZERO)
	if fx.active.size()!=1 or not fx.active[905].shelter.position.is_equal_approx(Vector3(.5,0,0)):return "Dewfall phase or duplicated receipt"
	var ending:={"id":906,"kind":"projectile_end","shape":"905"}
	fx.sync([ending,wave],[],"water-floor",Vector3.ZERO)
	if not fx.active.is_empty():return "retired wave replayed"
	for shape in ["drenched","bark_armor","vitality"]:
		var status:={"id":911,"kind":"status","shape":shape,"from":[0,0,0],"to":[0,0,0],"duration":6.,"reach":20,"color":"82d7ec",
			"form":"enemy" if shape=="drenched" else "player","combo":-1 if shape=="drenched" else 1,"height":2.35,"target_token":77}
		fx.sync([status,status],[],shape,Vector3.ZERO)
		if fx.statuses.active.size()!=1 or not fx.statuses.active[911].has("shelter"):return "missing or duplicated body art "+shape
		var mark:MeshInstance3D=fx.statuses.active[911].shelter
		fx.sync([{"id":912,"kind":"status_end","shape":"911"}],[],shape,Vector3.ZERO)
		if not fx.statuses.active.is_empty() or not mark.get_parent().is_queued_for_deletion():return "expired body art "+shape
	fx.clear()
	lab.formation.select(2)
	lab.arrange_targets()
	for i in lab.AFFINITY_KINDS.size():
		lab.selection.select(lab.AFFINITY_START+i)
		lab.select_effect()
		lab.mode.select(0)
		lab.play(false)
		lab.seek(.22)
		var count:=12 if i==1 else 6
		if lab.affinity_samples.size()!=count:return "affinity formation"
		if i==1:
			lab.seek(lab.Affinities.OPEN_SECONDS+.01)
			if lab.affinity_samples[0].visible or not lab.affinity_samples[1].visible:return "opening/closing handoff"
		var stamp:float=lab.clock
		var id:String=["fire.height","frost.petals","thorn.bark","fire.embers","affinity.status","affinity.status","thorn.spines","water.crest","water.opacity","water.crest","water.opacity","wood.grain","wood.thickness","wood.grain","wood.thickness","vital.petals","vital.pollen","vital.pollen","storm.width","spirit.wisp","spirit.veil","spirit.veil","void.flow","void.shade","void.flow","spirit.veil","void.flow"][i] if i<lab.AFFINITY_KINDS.find("quake") else "class.ink"
		var proposed:float=Tune.PROPERTIES[id].maximum
		if not tune.request(world,id,proposed):return "affinity slider "+id
		lab.mode.select(1)
		lab.compare_at_phase()
		if not is_equal_approx(stamp,lab.clock) or not is_equal_approx(lab.affinity_samples[0].material_override.get_shader_parameter(id.replace(".","_")),proposed):return "affinity phase or value "+id
		tune.reset(world,[id])
		lab.stop()
		if not lab.affinity_samples.is_empty():return "affinity reset"
	if not tune.request(world,"storm.width",1.4) or not tune.request(world,"spirit.veil",.32) or not tune.request(world,"void.shade",.65):return "astral controls"
	if not presets.save_new("Spectral currents").is_empty():return "astral preset save"
	tune.reset(world,["storm.width","spirit.veil","void.shade"])
	if not presets.load_named("Spectral currents").is_empty() or not is_equal_approx(tune.applied("spirit.veil"),.32):return "astral preset reload"
	var review:String=presets.export_review("Spectral currents")
	if not presets._read(review.path_join("changes.json")).differences.any(func(row):return row.id=="void.shade"):return "astral export"
	tune.reset(world,["storm.width","spirit.veil","void.shade"])
	if not tune.request(world,"water.crest",1.35) or not tune.request(world,"fire.smoke",.43) or not presets.save_new("Smoldering roots").is_empty():return "affinity preset write"
	tune.reset(world,["fire.smoke","water.crest"])
	if not presets.load_named("Smoldering roots").is_empty() or not is_equal_approx(tune.applied("water.crest"),1.35) or not is_equal_approx(tune.applied("fire.smoke"),.43):return "affinity preset read"
	var export_path:String=presets.export_review("Smoldering roots")
	if not presets._read(export_path.path_join("changes.json")).differences.any(func(row):return row.id=="fire.smoke"):return "affinity preset export"
	tune.reset(world,["fire.smoke","water.crest"])
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
