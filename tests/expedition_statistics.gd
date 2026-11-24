extends SceneTree
## Drive the host's actual combat paths. All save writes use fixture storage.
const Outgoing = preload("res://outgoing_hits.gd")
const Frost = preload("res://frost_combat.gd")
const Incoming = preload("res://incoming_player_hit.gd")
const Protection = preload("res://player_protection.gd")
const Life = preload("res://player_lifecycle.gd")
const Vitals = preload("res://player_vitals.gd")
const Fixture = preload("res://tests/support/expedition_case.gd")
var failed := false

func check(ok: bool, reason: String) -> void:
	if not ok:
		failed = true
		printerr("FAIL expedition statistics: ",reason)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var world = load("res://world.tscn").instantiate()
	var prefix := "res://.godot/er01-" + Crypto.new().generate_random_bytes(8).hex_encode()
	world.progress.path = prefix + ".garden"
	world.local_character.path = prefix + ".character"
	world.guest_character.path = prefix + ".guest"
	root.add_child(world)
	world.set_process(false)
	world.set_physics_process(false)
	world.add_player(2)
	Fixture.Sessions.set_identity(world,world.players[2],"guest-fixture")
	var stats: RefCounted = world.expedition_statistics
	var now := Time.get_ticks_msec()
	for id in [1,2]:
		var player: Dictionary = world.players[id]
		Fixture.set_membership(world,player,true)
		player.pos = Vector3.ZERO
		stats.admit(world.participation.run_id(),world.expedition_stat_identity(id),"Traveller "+str(id),"Warden",1,now)
	var run_id: int = world.participation.run_id()
	var owner: String = world.expedition_stat_identity(1)
	var guest: String = world.expedition_stat_identity(2)
	var source := func(peer): return {"actor":peer,"epoch":world.participation.epoch(),"life":Life.generation(world.players[peer]),"binding":world.network_session.binding(peer),"activation":peer}
	world.encounter.clear_scouts()
	world.encounter.set_hp(-1,100)
	Frost.resolve_stacks(world,source.call(1),9000,.08,{},-1,2,now)
	Frost.resolve_stacks(world,source.call(2),12000,.08,{},-1,1,now)
	var scout: Dictionary = world.make_scout(0,Vector3.ZERO,1)
	scout.hp = 3
	var slot: int = world.encounter.register_scout(scout)
	var token: int = world.encounter.spawn_identity(slot)
	Outgoing.hit_world(world,1,slot,Vector3.ZERO,{"damage":100.0},now,token)
	Outgoing.hit_world(world,1,slot,Vector3.ZERO,{"damage":100.0},now,token)
	world.record_enemy_death(slot,Vector3.ZERO,Vector3.ZERO,token)
	var ally: Dictionary = world.players[2]
	ally[Vitals.STATE] = ally[Vitals.STATE].with_hp(17)
	ally[Protection.STATE] = ally[Protection.STATE].grant(now+500,1,now,world.participation.epoch())
	Incoming.resolve_world(world,2,Life.generation(ally),now,500)
	Incoming.resolve_world(world,2,Life.generation(ally),now+600,1.0)
	var missing := Vitals.maximum_hp(ally) - Vitals.current_hp(ally)
	world.Life.Sustain.restore(world,ally,999,"fixture",-1,1)
	world.Life.Sustain.restore(world,ally,999,"fixture",-1,1)
	stats.clear_encounter(run_id,1)
	stats.clear_encounter(run_id,1)
	stats.reached(run_id,2)
	stats.finish(run_id,guest,"Voluntary return",now+5000)
	stats.publishable()
	var early: Dictionary = stats.result_for(guest)
	check(early.party.kills==1 and early.clears==1 and early.floor==2,"duplicate death and clearance rejected")
	check(early.party.damage==13 and early.players[0].damage==9 and early.players[1].damage==4,"overkill excluded and three frozen Brittle contributions split six to four")
	check(early.players[0].affinity.get("Brittle rupture")==6 and early.players[1].affinity.get("Brittle rupture")==4,"affinity subset matches applied damage")
	check(early.players[0].kills==1 and early.players[1].kills==0,"death credit independent of shared rewards")
	check(early.players[1].prevented==17 and early.players[1].taken==10,"blocked lethal contact caps at available HP and counts defense once")
	check(early.players[0].healing==missing and early.players[1].healing==0,"only effective allied healing credited to provider")
	check(early.elapsed_ms==5000 and early.party_outcome=="In progress at departure" and early.players[0].outcome=="In the Wilds","partial-party snapshot time and status")
	early.players[0].name = "tampered"
	world.tactics.begin_boss(22)
	world.encounter.set_hp(-1,0)
	world.record_enemy_death(-1,Vector3.ZERO,Vector3.ZERO)
	stats.damage(run_id,3,{guest:1},"Burning")
	stats.finish(run_id,owner,"Extraction",now+9000)
	stats.publishable()
	var final: Dictionary = stats.result_for(owner)
	check(final.party.bosses==1 and final.players[0].bosses==0 and final.party.kills==2,"confirmed boss without a known finisher counts only for the party")
	check(final.party.unattributed_damage==3 and final.players[1].damage==4 and final.players[0].name=="Traveller 1","frozen rows, detached reads and unattributed damage")
	world.ui.expedition_result("fixture",run_id,final)
	check(world.ui.visible_expedition_result()==final,"local UI shows detached final results")
	var panel: Control = world.ui._panels.expedition_results
	var tabs: TabContainer = panel.find_children("*","TabContainer",true,false)[0]
	check(tabs.get_tab_count()==3 and tabs.get_tab_title(1).contains("Traveller 1") and tabs.get_tab_title(2).contains("Traveller 2"),"overview and named tabs match the participants")
	check(tabs.get_tab_bar().has_focus(),"summary opens with keyboard and controller navigation focused")
	tabs.current_tab = 2
	var values := tabs.get_current_tab_control().find_children("*","Label",true,false)
	check(values.any(func(label):return label.text=="Brittle rupture damage") and values.any(func(label):return label.text=="Voluntary return"),"guest tab shows the guest's affinity and departure")
	for button: Button in panel.find_children("*","Button",true,false):
		if button.text=="Continue": button.pressed.emit()
	world.ui.expedition_result("fixture",run_id,final)
	check(not world.ui.is_overlay_open(),"duplicate delivery after dismissal stays closed")
	world.ui.expedition_result("fixture",run_id+1,{})
	world.ui.expedition_result("fixture",run_id,final)
	check(not world.ui.is_overlay_open(),"earlier expedition cannot reopen its report")
	stats.admit(run_id+1,guest,"New visit","Oracle",1,now)
	stats.freeze_departure(run_id+1,guest,now+1000)
	var pending: Dictionary = stats.savepoint()
	stats.settled_disconnect(guest)
	check(stats.result_for(guest).is_empty(),"tentative settlement stays private")
	stats.restore_savepoint(pending)
	stats.settled_disconnect(guest)
	stats.publishable()
	stats.settled_disconnect(guest)
	check(stats.result_for(guest).get("outcome")=="Disconnected" and stats.result_for(guest).elapsed_ms==1000,"disconnect freeze survives confirmed rollback and retry")
	stats.admit(run_id+2,owner,"New visit","Oracle",1,now)
	stats.finish(run_id+2,owner,"Extraction",now+1000)
	stats.hold_uncertain()
	check(stats.publishable().is_empty() and stats.result_for(owner).is_empty(),"uncertain completion cannot leak through a later successful publication")
	world.free()
	if not failed: print("PASS: expedition statistics, real HP and weighted attribution, personal finalization, rollback and UI")
	quit(int(failed))
