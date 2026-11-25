extends "res://game.gd"
## Ordinary combat in a local, unsaved world. Garden state is never borrowed.
const Developer = preload("res://developer_mode.gd")
var session: CanvasLayer
var workbench: Control
const PracticeEncounter = preload("res://developer_arena/practice_encounter.gd")
var practice_targets := false
var encounter_selection := {}
var replay_effect := false
var next_effect := 0

class MemoryGarden extends Progress:
	func load_garden(_recover := true) -> Error: return OK
	func save_garden() -> Error: return ERR_UNAUTHORIZED

class MemoryCharacter extends Character:
	func load_profile(_recover := true) -> Error: return OK
	func save_profile() -> Error: return ERR_UNAUTHORIZED

class PracticeAccess extends GuardedTitleSession:
	func can_write() -> bool: return false

func is_practice_world() -> bool:
	return is_instance_valid(session) and session.authorized(self) and Developer.is_solo(self)

func _ready() -> void:
	if not is_practice_world():
		process_mode = Node.PROCESS_MODE_DISABLED
		queue_free()
		return
	progress = MemoryGarden.new()
	local_character = MemoryCharacter.new()
	guest_character = MemoryCharacter.new()
	progress.path = ""
	local_character.path = ""
	guest_character.path = ""
	local_character.data = session.garden.local_character.data.duplicate(true)
	encounter = PracticeEncounter.Targets.new()
	persistence_session = PracticeAccess.new()
	settings_path = session.garden.settings_path
	super()
	ui.configure_arena_menu(false)
	start_round()
	var overlay := CanvasLayer.new()
	overlay.layer = 10
	add_child(overlay)
	workbench = load("res://developer_arena/workbench.gd").new()
	workbench.world = self
	overlay.add_child(workbench)

func start_round() -> void:
	if not is_practice_world(): return
	var actor: Dictionary = players[HOST]
	participation.leave(HOST)
	participation.reset_run()
	participation.enter(HOST)
	boss_floors[str(participation.floor())] = -1
	reset_encounter(0)
	encounter.clear_scouts()
	encounter.set_hp(-1,0)
	actor.pos = Vector3.ZERO
	actor.still_point = actor.pos
	actor.weapon = actor.prepared
	actor.secondary = actor.prepared_secondary
	actor.catalyst = actor.prepared_catalyst
	actor[preload("res://affinity_cards.gd").STATE] = preload("res://affinity_card_ledger.gd").Ledger.new()
	actor[preload("res://expedition_grafts.gd").STATE] = preload("res://expedition_grafts.gd").Ledger.new(participation.epoch())
	expedition_statistics.bind_session(network_session.session_identity())
	expedition_statistics.admit(participation.run_id(),expedition_stat_identity(HOST),actor.character.name,Classes.DEFINITIONS[actor.frame].name,1,Time.get_ticks_msec())
	status = "Developer Testing Arena"

func _input(event: InputEvent) -> void:
	if workbench != null and (event.is_action_pressed("developer_workbench") or event.is_action_pressed("session_menu")):
		workbench.toggle()
		get_viewport().set_input_as_handled()
	elif is_instance_valid(workbench) and not workbench.opened and preload("res://ability_aim.gd").release_event(self,event):
		get_viewport().set_input_as_handled()

func _unhandled_key_input(event: InputEvent) -> void:
	if is_instance_valid(workbench) and not workbench.opened:
		super(event)

func _physics_process(delta: float) -> void:
	if is_practice_world() and is_instance_valid(workbench) and not workbench.opened:
		if session.settings.no_cooldowns: reset_abilities()
		if replay_effect and Time.get_ticks_msec()>=next_effect:
			preview_effect()
		super(delta)

func _handle_ui_request(_command: String, _data: Dictionary) -> void:
	pass

func _act(id: int, strike: bool) -> void:
	if strike and is_practice_world(): super(id,true)

func garden_action(id: int, action: String) -> void:
	if is_practice_world() and id == HOST and (action.begins_with("class_cast:") or action.begins_with("core_cast:") or action.begins_with("card_cast:")):
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
		encounter_selection={"type":type,"kind":kind,"count":count,"formation":formation,"endless":endless}
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
		saved.roster=[]
		for slot in range(-1,encounter.scout_count()):
			saved.roster.append({"hp":encounter.hp(slot),"pos":enemy_position(slot)})
		saved.position=players[HOST].pos
		saved.health=players[HOST][PlayerVitals.STATE]
	return saved

func restore_round(saved: Dictionary) -> void:
	if not is_practice_world(): return
	var selection: Dictionary=saved.get("selection",{})
	if not selection.is_empty():
		spawn_selection(selection.type,selection.kind,selection.count,selection.formation,selection.endless)
	if saved.has("statistics"):
		expedition_statistics.restore_savepoint(saved.statistics)
		players[HOST].pos=saved.position
		players[HOST][PlayerVitals.STATE]=saved.health
		for slot in range(-1,mini(encounter.scout_count(),saved.roster.size()-1)):
			var row: Dictionary=saved.roster[slot+1]
			encounter.set_hp(slot,row.hp)
			if slot>=0: encounter.scout(slot).pos=row.pos
			elif row.pos.is_finite(): tactics.position=row.pos

func tick_enemies(delta: float, now: int) -> void:
	if not is_practice_world() or practice_targets: return
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
	expedition_statistics=preload("res://expedition_statistics.gd").new()
	var actor: Dictionary=players[HOST]
	expedition_statistics.bind_session(network_session.session_identity())
	expedition_statistics.admit(participation.run_id(),expedition_stat_identity(HOST),actor.character.name,Classes.DEFINITIONS[actor.frame].name,participation.floor(),Time.get_ticks_msec())

func round_stats() -> Dictionary:
	if not is_practice_world(): return {}
	return expedition_statistics.current_report(participation.run_id(),expedition_stat_identity(HOST),Time.get_ticks_msec())

func preview_effect() -> void:
	if not is_practice_world(): return
	next_effect=Time.get_ticks_msec()+1200
	var actor: Dictionary=players[HOST]
	stage.emit_skill_effect(actor.pos+actor.facing*2.0,1.2,weapon_effect_color(actor))
