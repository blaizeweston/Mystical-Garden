extends RefCounted
const Scenarios=preload("res://developer_arena/scenarios.gd")
const Tune=preload("res://developer_arena/tuning.gd")

static func run(session: Node) -> String:
	var world: Node=session.combat
	var library:=Scenarios.new(world)
	for name in Scenarios.STARTERS:
		var result:=library.inspect(library.builtin(name))
		if not result.error.is_empty(): return name+" — "+result.error
	if not library.copy_scenario("Spirit echoes","Pair",false).is_empty(): return "duplicate built-in"
	if not library.copy_scenario("Pair","Saved Spirit",true).is_empty() or "Pair" in library.names(): return "rename"
	if library.copy_scenario("Spirit echoes","Renamed",true).is_empty(): return "mutable built-in"
	var saved:=library.read("Saved Spirit")
	saved.preferred_preset="Restart"
	var tune: RefCounted=world.developer_tuning
	tune.reset(world,Tune.PROPERTIES.keys())
	var invalid:=saved.duplicate(true)
	invalid.participants[0].parts[1]="retired-part"
	if library.start(invalid).is_empty() or session.replacing: return "unknown component applied"
	invalid=saved.duplicate(true)
	invalid.participants[0].upgrades=[{"id":"lingering_echoes","rarity":"Rare"}]
	if library.start(invalid).is_empty(): return "lost dependency"
	invalid=saved.duplicate(true)
	invalid.encounter.count=2.5
	if library.start(invalid).is_empty(): return "fractional roster"
	invalid=saved.duplicate(true)
	invalid.encounter.origin=[2100,2100]
	if library.start(invalid).is_empty(): return "invalid terrain placement"
	invalid=saved.duplicate(true)
	invalid.fingerprint="earlier source"
	if library.start(invalid).is_empty(): return "changed source not reviewed"
	saved.controls.attacks=false
	saved.controls.no_cooldowns=true
	world.workbench.tabs.current_tab=world.workbench.pages.Scenarios.get_parent().get_index()
	var error:=library.start(saved)
	if not error.is_empty(): return error
	await session.get_tree().process_frame
	await session.get_tree().process_frame
	if is_instance_valid(world): return "old scene retained"
	world=session.combat
	if world.encounter.scout_count()!=1 or not world.encounter.inexhaustible or not session.settings.no_cooldowns or session.settings.attacks: return "round settings or target lost"
	if session.build.upgrades.size()!=3 or not is_equal_approx(tune.applied(Tune.SPEAR),3.1): return "build or preset mixed"
	world.dodge_player(1,Vector2.RIGHT)
	if world.players[1].get(preload("res://spirit_affinity.gd").ECHOES,[]).is_empty(): return "advanced Spirit build did not produce an echo"
	var before: Vector3=world.encounter.position(0)
	tune.request(world,Tune.SPEAR,4.8)
	tune.apply(world,[Tune.SPEAR])
	library=Scenarios.new(world)
	error=library.start(session.active_scenario)
	if not error.is_empty(): return error
	await session.get_tree().process_frame
	await session.get_tree().process_frame
	world=session.combat
	if not is_equal_approx(tune.applied(Tune.SPEAR),4.8) or world.encounter.position(0)!=before or world.players[1].has(preload("res://spirit_affinity.gd").ECHOES) or world.weapon_attacks.pending_count()!=0 or world.round_stats().party.damage!=0: return "replay did not retain tuning and restore a clean matching setup"
	if world.workbench.tabs.get_current_tab_control().name!="Scenarios": return "workbench page lost"
	library=Scenarios.new(world)
	var record:=library.current("Named terrain","Seeded test","Restart",117,9)
	record.encounter={}
	if not library.save_record(record).is_empty(): return "save current configuration"
	error=library.start(record)
	if not error.is_empty(): return error
	await session.get_tree().process_frame
	await session.get_tree().process_frame
	world=session.combat
	if world.participation.floor()!=9 or world.battlefield.configured_key.z!=117 or world.encounter.scout_count()!=0: return "seeded environment"
	library=Scenarios.new(world)
	var cluster:=library.builtin("Pilgrim cluster")
	error=library.start(cluster)
	if not error.is_empty(): return error
	await session.get_tree().process_frame
	await session.get_tree().process_frame
	world=session.combat
	if world.encounter.scout_count()!=3 or world.encounter_selection.formation!="Cluster" or world.encounter_selection.type!="Enemy": return "cluster roster"
	for body in world.encounter.scout_tactics():
		if world.Enemies.get_kind(body.kind).id!="rootbound": return "cluster identity"
	tune.reset(world,Tune.PROPERTIES.keys())
	return ""

static func restart(world: Node) -> String:
	var library:=Scenarios.new(world)
	var saved:=library.read("Saved Spirit")
	if library.inspect(saved).get("error","")!="" or library.read("Named terrain").get("preferred_preset")!="Restart": return "named scenarios across restart"
	if library.remove("Saved Spirit",false).is_empty() or not library.remove("Saved Spirit",true).is_empty() or "Saved Spirit" in library.names(): return "delete confirmation"
	return ""
