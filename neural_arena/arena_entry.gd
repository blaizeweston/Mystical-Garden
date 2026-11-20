extends RefCounted
## Opens the Neural Arena. Leaving for the arena ends the current session through its normal exit.

const Config = preload("res://neural_arena/arena_config.gd")

const WORLD_SCENE := "res://world.tscn"
const WORLD_SCRIPT := "res://neural_arena/arena_world.gd"
const WORLD_NAME := "MysticalGarden"


## Called by the Neural Arena button on the game menu.
static func open_from(game: Node) -> void:
	if game.participation.active() and game.network_session.role() in ["Solo", "Host"]:
		var dialog := ConfirmationDialog.new()
		dialog.title = "End this expedition?"
		dialog.dialog_text = "Opening the Neural Arena ends the expedition. Your run's Class XP, monster familiarity and carried items, including the safe pouch, are forfeited. Courier deliveries remain."
		dialog.ok_button_text = "Open Neural Arena"
		dialog.confirmed.connect(_leave_for_arena.bind(game))
		game.add_child(dialog)
		dialog.popup_centered(Vector2i(500, 190))
	else:
		_leave_for_arena(game)


static func _leave_for_arena(game: Node) -> void:
	var tree: SceneTree = game.get_tree()
	game.return_to_main_menu()
	if not is_instance_valid(game) or not game.is_queued_for_deletion():
		return
	var menu: Node = tree.current_scene
	if menu != null and menu != game:
		menu.queue_free()
	_launch_after_departure(tree, Config.new(), false)


## Creates the arena world. With start set, the session begins without showing the setup screen.
static func launch(tree: SceneTree, config: Config, start: bool) -> Node:
	var world: Node = load(WORLD_SCENE).instantiate()
	world.set_script(load(WORLD_SCRIPT))
	world.name = WORLD_NAME
	world.config = config
	world.auto_start = start
	tree.root.add_child(world)
	tree.current_scene = world
	if start:
		world.begin_session()
	return world


## Replaces a running arena when the session type changes.
static func relaunch(world: Node, config: Config) -> void:
	var tree: SceneTree = world.get_tree()
	world.returning_to_title = true
	world.session_world.offline()
	world.queue_free()
	_launch_after_departure(tree, config, true)

static func _launch_after_departure(tree: SceneTree, config: Config, start: bool) -> void:
	# process_frame is emitted before queued nodes are freed. Preserve the RPC root
	# name by admitting its replacement after the departed world is actually gone.
	await tree.process_frame
	await tree.process_frame
	launch(tree,config,start)
