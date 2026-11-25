extends CanvasLayer
## One temporary viewport keeps the claimed Garden alive without advancing it.
const Developer = preload("res://developer_mode.gd")
var garden: Node
var combat: Node
var surface: SubViewport
var previous_mode: ProcessMode
var closing := false
var settings := {"invincible":false,"no_cooldowns":false,"movement":true,"attacks":true}
var build := {}
var practice_identity := Crypto.new().generate_random_bytes(16).hex_encode()
var replacing := false

func open(owner: Node) -> bool:
	if not Developer.can_enter_arena(owner) or get_parent() != owner:
		queue_free()
		return false
	garden = owner
	previous_mode = garden.process_mode
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100
	garden.mouse_controls.release(garden)
	garden.settings_dialog.hide()
	garden.ui.close_panels()
	garden.process_mode = Node.PROCESS_MODE_DISABLED
	var screen := SubViewportContainer.new()
	screen.stretch = true
	add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	surface = SubViewport.new()
	surface.own_world_3d = true
	surface.gui_embed_subwindows = true
	screen.add_child(surface)
	# Even a programmatic host/join attempt cannot attach to the Garden's transport.
	get_tree().set_multiplayer(SceneMultiplayer.new(),surface.get_path())
	_create_world()
	return true

func rebuild(mode := "round") -> void:
	if replacing or not authorized(combat): return
	replacing = true
	combat.set_physics_process(false)
	call_deferred("_replace",mode)

func _replace(mode: String) -> void:
	if not authorized(combat): return
	var capture: Dictionary = combat.capture_round(mode)
	combat.free()
	_create_world()
	combat.restore_round(capture)
	replacing = false

func _create_world() -> void:
	combat = load("res://world.tscn").instantiate()
	combat.set_script(load("res://developer_arena/practice_world.gd"))
	combat.session = self
	combat.name = "Practice"
	surface.add_child(combat)

func authorized(world: Node) -> bool:
	return not closing and is_instance_valid(garden) and get_parent() == garden and combat == world \
		and Developer.is_test_garden(garden) and Developer.is_solo(garden) and garden.slot_claimed \
		and not garden.participation.active() and garden.app_settings.values.developer_mode

func _process(_delta: float) -> void:
	if closing or garden == null: return
	if not authorized(combat):
		close()
		return
	if garden.persistence_session.is_guarded():
		if garden.persistence_session.tick().error != OK:
			close()
	else:
		garden.renew_legacy_slot()

func close() -> void:
	if closing: return
	closing = true
	if is_instance_valid(combat):
		combat.process_mode = Node.PROCESS_MODE_DISABLED
	call_deferred("_return")

func _return() -> void:
	if is_instance_valid(surface):
		var scope := surface.get_path()
		surface.free()
		get_tree().set_multiplayer(null,scope)
	if is_instance_valid(garden):
		garden.process_mode = previous_mode
		garden.mouse_controls.release(garden)
		garden.remove_child(self)
		garden.developer_tuning.sync_scene(garden)
	queue_free()
