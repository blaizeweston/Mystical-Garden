extends "res://game.gd"
## Ordinary combat in a local, unsaved world. Garden state is never borrowed.
const Developer = preload("res://developer_mode.gd")
var session: CanvasLayer
var workbench: Control
const BuildPlan = preload("res://developer_arena/build_plan.gd")
const PracticeEncounter = preload("res://developer_arena/practice_encounter.gd")
var practice_targets := false
var encounter_selection := {}
var replay_effect := false
var next_effect := 0
var round_elapsed_ms := 0.0

class MemoryGarden extends Progress:
	func load_garden(_recover := true) -> Error: return OK
	func save_garden() -> Error: return ERR_UNAUTHORIZED

class MemoryCharacter extends Character:
	func load_profile(_recover := true) -> Error: return OK
	func save_profile() -> Error: return ERR_UNAUTHORIZED

class PracticeAccess extends GuardedTitleSession:
	func can_write() -> bool: return false

func is_practice_world() -> bool:
	return Developer.authorized_build() and is_instance_valid(session) and session.authorized(self) and Developer.is_solo(self)

func _ready() -> void:
	if not is_practice_world():
		process_mode = Node.PROCESS_MODE_DISABLED
		queue_free()
		return
	developer_tuning = session.garden.developer_tuning
	progress = MemoryGarden.new()
	local_character = MemoryCharacter.new()
	local_character.identity=session.practice_identity
	guest_character = MemoryCharacter.new()
	progress.path = ""
	local_character.path = ""
	guest_character.path = ""
	local_character.data = session.garden.local_character.data.duplicate(true)
	encounter = PracticeEncounter.Targets.new()
	persistence_session = PracticeAccess.new()
	settings_path = session.garden.settings_path
	super()
	developer_tuning.sync_scene(self)
	ui.configure_arena_menu(false)
	_initialize_round()
	var overlay := CanvasLayer.new()
	overlay.layer = 10
	add_child(overlay)
	workbench = load("res://developer_arena/workbench.gd").new()
	workbench.world = self
	overlay.add_child(workbench)
	ui.get_node("%MenuButton").hide()
	ui.get_node("Surface/Prompts").hide()
	var open_button:=Button.new()
	open_button.text="Workbench"
	open_button.theme=ui.get_node("Surface").theme
	overlay.add_child(open_button)
	open_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	open_button.offset_left=-132
	open_button.offset_right=-14
	open_button.offset_top=12
	open_button.offset_bottom=48
	open_button.pressed.connect(workbench.toggle)

func _initialize_round() -> void:
	if not is_practice_world(): return
	var actor: Dictionary = players[HOST]
	participation.leave(HOST)
	participation.reset_run()
	participation.enter(HOST)
	for step in range(1,session.encounter_depth):
		participation.advance(participation.epoch(),ROUTE_ROOMS)
		participation.begin_floor(0)
	boss_floors[str(participation.floor())] = -1
	reset_encounter(session.terrain_seed)
	encounter.clear_scouts()
	encounter.set_hp(-1,0)
	actor.pos = Vector3.ZERO if session.terrain_seed==0 else battlefield.entry
	actor.still_point = actor.pos
	if session.build.is_empty(): session.build=BuildPlan.initial(actor)
	var plan:=BuildPlan.plan(self,session.build)
	if not plan.error.is_empty() or not plan.removed.is_empty():
		session.close()
		return
	plan.profile.name=actor.character.name
	plan.profile.appearance=actor.character.appearance.duplicate(true)
	local_character.data=plan.profile
	actor.character=local_character.data
	restore_class_loadout(actor)
	actor.weapon=actor.prepared
	actor.secondary=actor.prepared_secondary
	actor.catalyst=actor.prepared_catalyst
	actor[AffinityCards.STATE]=plan.cards
	actor[BuildPlan.Grafts.STATE]=plan.grafts
	actor[PlayerVitals.STATE]=actor[PlayerVitals.STATE].with_native_max_hp(Life.native_maximum(self,actor)).refilled()
	reset_statistics()
	status = "Developer Testing Arena"

func _input(event: InputEvent) -> void:
	if workbench != null and (Developer.workbench_input(event) or event.is_action_pressed("session_menu")):
		workbench.toggle()
		get_viewport().set_input_as_handled()
	elif is_instance_valid(workbench) and not workbench.opened and preload("res://ability_aim.gd").release_event(self,event):
		get_viewport().set_input_as_handled()

func _unhandled_key_input(event: InputEvent) -> void:
	if is_instance_valid(workbench) and not workbench.opened:
		super(event)

func _physics_process(delta: float) -> void:
	if is_practice_world() and is_instance_valid(workbench) and not workbench.opened:
		round_elapsed_ms+=delta*1000.0
		if session.settings.no_cooldowns: reset_abilities()
		if replay_effect and Time.get_ticks_msec()>=next_effect:
			preview_effect()
		super(delta)

func _handle_ui_request(_command: String, _data: Dictionary) -> void:
	pass

func _act(id: int, strike: bool) -> void:
	if strike and is_practice_world(): super(id,true)

func garden_action(id: int, action: String) -> void:
	if not is_practice_world() or id!=HOST: return
	var actor: Dictionary=players[HOST]
	if session.settings.no_cooldowns and CombatClock.now()<maxi(int(actor.get("cast_until",0)),int(actor.get("core_cast_until",0))): return
	if action in ["class_skill","class_skill_two"]:
		action=preload("res://ability_aim.gd").request_native(self,actor,0 if action=="class_skill" else 1)
	if action.begins_with("class_cast:") or action.begins_with("core_cast:") or action.begins_with("card_cast:"):
		super(id,action)

func finish_combat(_id: int, _position: Vector3) -> void:
	encounter_rewarded = true

func _queue_monster_reward(_spawn_token: String, _kind: int, _mask: int, _position: Vector3, _leader: bool, _summoned := false) -> bool:
	return is_practice_world()

func return_to_main_menu(_message: String = "") -> void:
	if is_practice_world(): session.close()

func spawn_selection(type: String, kind: int, count: int, formation: String, endless: bool) -> String:
	var reason := PracticeEncounter.place(self,type,kind,count,formation,endless)
	if reason.is_empty():
		encounter_selection={"type":type,"kind":kind,"count":count,"formation":formation,"endless":endless,"origin":players[HOST].pos,"facing":players[HOST].facing}
	return reason

func clear_enemies() -> void:
	if not is_practice_world(): return
	encounter_selection.clear()
	encounter.begin_floor(0)
	tactics.begin_boss(-1)
	tactics.stop_attack()
	enemy_hazards.clear()

func capture_round(mode: String) -> Dictionary:
	if not is_practice_world(): return {}
	var saved := {"selection":encounter_selection.duplicate(),"mode":mode}
	if mode=="effects":
		saved.statistics=expedition_statistics.savepoint()
		saved.elapsed=round_elapsed_ms
		saved.roster=[]
		for slot in range(-1,encounter.scout_count()):
			var data: Dictionary=encounter.scout(slot) if slot>=0 else {}
			saved.roster.append({"hp":encounter.hp(slot),"pos":enemy_position(slot),"kind":data.get("kind",enemy_kind),"route":data.get("route",0),
				"mutations":data.get("mutations",0),"growth":data.get("growth",0),"summoned":data.get("summoned",false),"max_hp":data.get("max_hp",0)})
		saved.cooldowns=players[HOST][Cooldowns.STATE]
		saved.position=players[HOST].pos
		saved.health=players[HOST][PlayerVitals.STATE]
		saved.fallen=PlayerLifecycle.fallen(players[HOST])
	return saved

func restore_round(saved: Dictionary) -> void:
	if not is_practice_world(): return
	var selection: Dictionary=saved.get("selection",{})
	if not selection.is_empty():
		if selection.has("origin") and selection.has("facing"):
			players[HOST].pos=selection.origin
			players[HOST].facing=selection.facing
		spawn_selection(selection.type,selection.kind,selection.count,selection.formation,selection.endless)
	if saved.has("statistics"):
		expedition_statistics.restore_savepoint(saved.statistics)
		round_elapsed_ms=saved.elapsed
		players[HOST][Cooldowns.STATE]=saved.cooldowns
		players[HOST].pos=saved.position
		players[HOST][PlayerVitals.STATE]=saved.health
		if saved.fallen: players[HOST][PlayerLifecycle.STATE]=players[HOST][PlayerLifecycle.STATE].fall()
		encounter.clear_scouts()
		encounter.anchors.clear()
		for slot in range(-1,saved.roster.size()-1):
			var row: Dictionary=saved.roster[slot+1]
			if slot==-1:
				encounter.set_hp(slot,row.hp)
				if row.pos.is_finite(): tactics.position=row.pos
				continue
			var body:=make_scout(row.kind,row.pos,row.route,row.mutations,row.growth)
			body.hp=row.hp
			body.max_hp=row.max_hp
			body.summoned=row.summoned
			encounter.register_scout(body)
			if practice_targets: encounter.anchors[encounter.token(slot)]=row.pos

func tick_enemies(delta: float, now: int) -> void:
	if not is_practice_world(): return
	if practice_targets:
		for body in encounter.scout_tactics():
			var token:=encounter.token_for(body)
			if encounter.anchors.has(token): body.pos=encounter.anchors[token]
		return
	var allow_attacks: bool=session.settings.attacks
	var allow_motion: bool=session.settings.movement
	if not allow_attacks: cancel_enemy_attacks()
	var old_leader := tactics.position
	var stationary := {}
	if not allow_motion:
		for body in encounter.scout_tactics(): stationary[encounter.token_for(body)]=body.pos
	super(delta if allow_motion else 0.0,now)
	if not allow_attacks: cancel_enemy_attacks()
	if not allow_motion:
		tactics.position=old_leader
		for body in encounter.scout_tactics():
			var token := encounter.token_for(body)
			if stationary.has(token): body.pos=stationary[token]

func cancel_enemy_attacks() -> void:
	if not is_practice_world(): return
	tactics.stop_attack()
	enemy_hazards.clear()
	for body in encounter.scout_tactics():
		body.windup=0
		body.erase("attack")

func set_control(key: String, enabled: bool) -> void:
	if not is_practice_world() or not session.settings.has(key): return
	session.settings[key]=enabled
	if key=="attacks" and not enabled: cancel_enemy_attacks()
	if key=="no_cooldowns" and enabled: reset_abilities()

func reset_abilities() -> void:
	if not is_practice_world(): return
	var actor: Dictionary=players[HOST]
	actor[Cooldowns.STATE]=actor[Cooldowns.STATE].with_deadline(Cooldowns.Q,0).with_deadline(Cooldowns.R,0)
	actor.core_ready_at=0
	for action in actor.get("card_active_state",{}).get("actions",{}).values(): action.ready=0

func restore_health() -> void:
	if not is_practice_world(): return
	var actor: Dictionary=players[HOST]
	if not Life.alive(actor):
		session.rebuild()
		return
	actor[PlayerVitals.STATE]=actor[PlayerVitals.STATE].refilled()

func reset_statistics() -> void:
	if not is_practice_world(): return
	round_elapsed_ms=0.0
	expedition_statistics=preload("res://expedition_statistics.gd").new()
	var actor: Dictionary=players[HOST]
	expedition_statistics.bind_session(session.practice_identity)
	expedition_statistics.admit(participation.run_id(),expedition_stat_identity(HOST),actor.character.name,Classes.DEFINITIONS[actor.frame].name,participation.floor(),0)

func round_stats() -> Dictionary:
	if not is_practice_world(): return {}
	return expedition_statistics.current_report(participation.run_id(),expedition_stat_identity(HOST),roundi(round_elapsed_ms))

func preview_effect() -> void:
	if not is_practice_world(): return
	next_effect=Time.get_ticks_msec()+1200
	developer_tuning.replay(self)

func apply_build(spec: Dictionary, removal_preview: Array) -> String:
	if not is_practice_world() or session.replacing: return "Practice round unavailable."
	var resolved:=BuildPlan.plan(self,spec)
	if not resolved.error.is_empty(): return resolved.error
	if resolved.removed!=removal_preview: return "The dependency preview changed. Review the build again."
	session.build=spec.duplicate(true)
	session.build.upgrades=resolved.accepted.duplicate(true)
	session.rebuild("build")
	return ""
