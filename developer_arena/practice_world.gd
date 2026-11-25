extends "res://game.gd"
## Ordinary combat in a local, unsaved world. Garden state is never borrowed.
const Developer = preload("res://developer_mode.gd")
var session: CanvasLayer
var workbench: Control

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

func _unhandled_key_input(event: InputEvent) -> void:
	if is_instance_valid(workbench) and not workbench.opened:
		super(event)

func _physics_process(delta: float) -> void:
	if is_practice_world() and is_instance_valid(workbench) and not workbench.opened:
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
