extends SceneTree

const SessionCase = preload("res://tests/support/session_case.gd")
const Slots=preload("res://save_slots.gd")
const Progress=preload("res://progress.gd")
const Character=preload("res://character_profile.gd")
const TitleMusic=preload("res://title_music.gd")
var failed:=false
func check(ok: bool,message: String):
	if not ok:
		failed=true
		printerr("FAIL: ",message)
func _initialize():
	call_deferred("run")
func run():
	var base: String="res://.godot/menu_"+Crypto.new().generate_random_bytes(8).hex_encode()
	DirAccess.make_dir_recursive_absolute(base)
	var slots:=Slots.new()
	slots.root_path=base.path_join("slots")
	slots.legacy_garden=base.path_join("legacy_garden.cfg")
	slots.legacy_character=base.path_join("legacy_character.cfg")
	slots.legacy_guest=base.path_join("legacy_guest.cfg")
	check(slots.prepare(false)==OK and Slots.COUNT==3,"three empty slots can be prepared")
	for i in 3: check(not slots.summary(i).exists,"new slot starts empty")
	var original:=Progress.new()
	original.path=slots.legacy_garden
	original.knowledge=27
	original.stock[1]=4
	original.save_garden()
	var character:=Character.new()
	character.path=slots.legacy_character
	character.data.xp[0]=7
	character.save_profile()
	var guest:=Character.new()
	guest.path=slots.legacy_guest
	guest.data.xp[1]=3
	guest.save_profile()
	check(slots.prepare(true)==OK,"old progress imports without replacing source files")
	check(slots.summary(0).knowledge==27 and slots.summary(1).character and not slots.summary(1).exists,"old Garden and guest character remain accessible")
	check(FileAccess.file_exists(slots.legacy_garden) and FileAccess.file_exists(slots.legacy_guest),"legacy originals remain untouched")
	check(slots.new_game(2)==OK and slots.new_game(3)==ERR_INVALID_PARAMETER,"fresh Garden uses a valid slot only")
	var third:=Progress.new()
	third.path=slots.paths(2).garden
	third.load_garden()
	third.knowledge=12
	third.save_garden()
	check(slots.summary(0).knowledge==27 and slots.summary(2).knowledge==12,"slot progress remains separate")
	check(slots.new_game(2)==ERR_ALREADY_EXISTS and slots.summary(2).knowledge==12,"occupied slot cannot be replaced without confirmation")
	check(slots.new_game(2,true)==OK and slots.summary(2).knowledge==0,"confirmed new game resets only the selected Garden")
	var archives:=DirAccess.open(slots.paths(2).directory.path_join("backups")).get_directories()
	check(archives.size()==1,"replacement creates a recovery archive")
	var archived:=ConfigFile.new()
	archived.load(slots.paths(2).directory.path_join("backups").path_join(archives[0]).path_join("garden.cfg"))
	check(archived.get_value("garden","knowledge",-1)==12,"archive preserves the previous Garden")
	check(slots.claim(0)==OK and slots.is_active(0),"active slot is claimed by the running game")
	check(slots.new_game(0,true)==ERR_BUSY and slots.ensure_character(0)==ERR_BUSY,"active slot cannot be replaced or reused")
	slots.release(0)
	check(not slots.is_active(0),"returning from a game releases its slot")
	var menu=load("res://main_menu.tscn").instantiate()
	menu.storage.root_path=slots.root_path
	menu.import_legacy=false
	menu.restore_last_selection=false
	root.add_child(menu)
	current_scene=menu
	TitleMusic.enter(menu)
	var title: AudioStreamPlayer=root.get_node(NodePath(str(TitleMusic.PLAYER_NAME)))
	check(title.playing,"the title menu starts its own Music voice")
	check(menu.slot_buttons.size()==3 and not menu.continue_button.disabled,"startup menu shows three slots and Continue")
	check(menu.pages[0].visible and not menu.pages[1].visible and not menu.pages[2].visible,"Play is the initial title page")
	var roots=menu.navigation[0].get_node("ReachingRoots")
	check(roots.mouse_filter==Control.MOUSE_FILTER_IGNORE and roots.highlighted,"the focused button starts growing noninteractive roots")
	roots.animation.custom_step(0.12)
	check(roots.growth>0.0 and roots.growth<1.0,"the reaching roots reveal progressively")
	await process_frame
	await process_frame
	check(roots.tendrils.size()>=7 and roots.perimeter.size()>30,"the frame grows multiple root branches")
	var button_rect:=Rect2(Vector2.ZERO,roots.size)
	check(not Array(roots.perimeter).any(func(point):return button_rect.has_point(point)),"the roots follow the outside of the button face")
	for tendril in roots.tendrils:
		check(not Array(tendril.points).any(func(point):return button_rect.has_point(point)),"branching tendrils stay outside the face")
	check(roots.perimeter[0].x<0 and roots.perimeter[-1].x>roots.size.x and Array(roots.perimeter).any(func(point):return point.y<0),"the root turns the corners and reaches the opposite side")
	menu.app_settings.values.ambient_motion=false
	menu.navigation[2].pressed.emit()
	check(menu.navigation[2].get_node("ReachingRoots").growth==1.0,"reduced motion keeps the static roots on the highlighted button")
	check(menu.pages[2].visible and menu.join_button.is_visible_in_tree() and not menu.continue_button.is_visible_in_tree(),"Co-op owns Join while hiding Garden save actions")
	menu.navigation[1].pressed.emit()
	check(menu.pages[1].visible and menu.create_character_button.is_visible_in_tree(),"Characters has its own roster and management actions")
	var escape:=InputEventKey.new();escape.keycode=KEY_ESCAPE;escape.pressed=true
	menu._unhandled_key_input(escape)
	check(menu.pages[2].visible,"Escape returns to the page that led to Characters")
	menu._unhandled_key_input(escape)
	check(menu.pages[0].visible,"Escape from Co-op returns to Play")
	menu.select_slot(1)
	check(menu.continue_button.disabled and not menu.join_button.disabled,"character-only slot can join without claiming an existing Garden")
	menu.select_slot(2)
	menu.new_game()
	check(menu.confirmation.visible,"occupied slot replacement has a concrete in-game confirmation")
	check(menu.confirmation.get_ok_button().has_node("ReachingRoots"),"title confirmations use the shared button highlight")
	menu.confirmation.hide()
	check(title.get_meta("title_active"),"title music continues through setup screens")
	menu.continue_game()
	check(not title.get_meta("title_active"),"launching a Garden starts fading the title theme")
	var world=current_scene
	await process_frame
	check(world.active_slot==2 and world.progress.path==slots.paths(2).garden,"Continue opens the selected world")
	world.toggle_overlay(world.session_menu)
	var resume: Button=world.session_menu.find_child("Resume",true,false)
	check(resume!=null and resume.has_focus(),"game menu focuses Resume")
	check(resume.get_node("ReachingRoots").highlighted,"keyboard focus highlights the in-game menu")
	resume.pressed.emit()
	check(not world.overlay.visible,"Resume closes the menu")
	world.toggle_overlay(world.pack_menu)
	var inventory_close: Button=world.pack_menu.find_children("*","Button",true,false).filter(func(button):return button.text=="Close")[0]
	inventory_close.grab_focus()
	check(inventory_close.get_node("ReachingRoots").highlighted,"inventory buttons use the same keyboard highlight")
	world.settings_dialog.begin(world.app_settings)
	var binding: Button=world.settings_dialog.binding_buttons.attack[0]
	check(binding.has_node("ReachingRoots"),"nested settings buttons use the shared highlight")
	world.settings_dialog.cancel()
	world.toggle_overlay(null)
	world.progress.knowledge=9
	world.return_to_main_menu()
	await process_frame
	menu=current_scene
	TitleMusic.enter(menu)
	check(root.get_node(NodePath(str(TitleMusic.PLAYER_NAME)))==title and title.get_meta("title_active"),"return to title reuses the music voice")
	check(menu.selected==2 and menu.storage.summary(2).knowledge==9,"returning to title saves and retains the selected slot")
	menu.select_slot(1)
	menu.select_character(1)
	menu.join_game()
	world=current_scene
	check(world.network_session.role()=="Connecting" and world.guest_character.path==menu.characters.paths(1).character,"main-menu Join uses the selected character")
	SessionCase.World.connection_failed(world)
	await process_frame
	menu=current_scene
	check(menu.notice.text.contains("Could not connect") and not slots.summary(1).exists,"failed Join returns to title without creating or replacing a Garden")
	check(menu.pages[2].visible and menu.network_dialog.visible and menu.network_dialog.feedback.text==menu.notice.text,"failure brings the user back to the filled join dialog")
	menu.network_dialog.dismiss()
	menu.new_game()
	world=current_scene
	check(world.active_slot==1 and world.local_character.data.xp[1]==3 and world.progress.knowledge==0,"first Garden preserves an existing guest character")
	world.queue_free()
	title.free()
	await process_frame
	if not failed: print("PASS: three isolated slots, legacy import, replacement backup, Continue, main-menu Join and failure recovery")
	quit(1 if failed else 0)
