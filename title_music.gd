extends RefCounted

const THEME = preload("res://assets/audio/soundscape/title_theme.wav")
const PLAYER_NAME := &"GardenTitleMusic"
const LEVEL := -11.0
const SILENT := -70.0


static func enter(menu: Node) -> void:
	if is_instance_valid(menu) and menu.is_inside_tree() and not menu.transitioning:
		set_playing(menu.get_tree(),true)


static func set_playing(tree: SceneTree, active: bool) -> void:
	var player := tree.root.get_node_or_null(NodePath(str(PLAYER_NAME))) as AudioStreamPlayer
	if player == null:
		if not active:
			return
		player = AudioStreamPlayer.new()
		player.name = PLAYER_NAME
		player.bus = &"Music"
		player.stream = THEME
		player.volume_db = SILENT
		player.process_mode = Node.PROCESS_MODE_ALWAYS
		tree.root.add_child(player)
	if player.get_meta("title_active",false) == active:
		return
	player.set_meta("title_active",active)
	var previous: Tween = player.get_meta("title_fade") if player.has_meta("title_fade") else null
	if previous != null and previous.is_valid():
		previous.kill()
	if active and not player.playing:
		player.play()
	var fade := player.create_tween()
	player.set_meta("title_fade",fade)
	fade.tween_property(player,"volume_db",LEVEL if active else SILENT,1.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT if active else Tween.EASE_IN)
	if not active:
		fade.tween_callback(player.stop)
