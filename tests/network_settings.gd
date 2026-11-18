extends SceneTree
const UIFixture = preload("res://tests/support/gameplay_ui_case.gd")

const SessionCase = preload("res://tests/support/session_case.gd")

const ExpeditionCase = preload("res://tests/support/expedition_case.gd")
const Settings=preload("res://network_settings.gd")
var failed:=false
func check(ok: bool,message: String):
 if not ok: failed=true;printerr("FAIL networking: ",message)
func _initialize(): call_deferred("run")
func run():
 check(Settings.error("192.168.1.20",24576).is_empty() and Settings.error("[::1]",24576).is_empty() and Settings.address(" localhost ")=="127.0.0.1","IPv4, IPv6 and local addresses accepted")
 check(not Settings.error("https://example.com",24576).is_empty() and not Settings.error("127.0.0.1:24576",24576).is_empty() and not Settings.error("127.0.0.1",0).is_empty(),"invalid addresses and ports rejected before connection")
 var ipv6 := Settings.parse_endpoint("[2001:db8::1]:32123",24576)
 check(ipv6.address=="2001:db8::1" and ipv6.port==32123 and ipv6.error.is_empty() and Settings.format_endpoint(ipv6.address,ipv6.port)=="[2001:db8::1]:32123","bracketed IPv6 shares and parses a custom port")
 check(Settings.parse_endpoint("192.168.1.20:32124",24576).port==32124 and Settings.parse_endpoint("2001:db8::1",24576).port==24576,"pasted IPv4 endpoint and raw IPv6 use the intended ports")
 check(not Settings.parse_endpoint("127.0.0.1:",24576).error.is_empty() and not Settings.parse_endpoint("[::1]:65536",24576).error.is_empty(),"malformed pasted ports are rejected")
 var menu=load("res://main_menu.tscn").instantiate()
 menu.storage.root_path="res://.godot/net_settings_"+Crypto.new().generate_random_bytes(8).hex_encode();menu.import_legacy=false;menu.restore_last_selection=false
 root.add_child(menu);current_scene=menu
 menu.characters.create(0,"Fern",1,[]);menu.select_character(0)
 check(not menu.creator.visible and not menu.network_dialog.visible,"creation and connection windows start closed")
 menu.request_ip_join();menu.network_dialog.address_field.text="invalid";menu.network_dialog.confirm()
 check(menu.network_dialog.visible and not menu.network_dialog.feedback.text.is_empty() and current_scene==menu,"invalid join remains reviewable without claiming character")
 menu.network_dialog.dismiss();menu.apply_network_settings("",Settings.DEFAULT_PORT+2,false)
 menu.request_ip_join()
 menu.network_dialog.address_field.text=Settings.format_endpoint("127.0.0.1",Settings.DEFAULT_PORT+5)
 menu.network_dialog.confirm()
 var game=current_scene
 check(game.network_session.role()=="Connecting" and game.network_session.port()==Settings.DEFAULT_PORT+5 and not game.slot_claimed,"pasting host endpoint joins its port without claiming a world")
 var saved := Settings.load_settings(game.slot_storage_root)
 check(saved.port==Settings.DEFAULT_PORT+5 and saved.host_port==Settings.DEFAULT_PORT+2,"hosting port stays separate from the last join port")
 SessionCase.World.update(game)
 check(UIFixture.control(game,"connection_label").text.contains("1 of 4") and UIFixture.control(game,"connection_label").text.contains(str(game.network_session.port())),"initial connection names the endpoint")
 game.network_session.compatibility_started()
 SessionCase.World.update(game)
 check(UIFixture.control(game,"connection_label").text.contains("2 of 4"),"compatibility check has its own phase")
 var cancel: Button=UIFixture.control(game,"connection_panel").find_children("*","Button",true,false)[0]
 cancel.pressed.emit()
 await process_frame
 menu=current_scene
 check(not menu.characters.is_active(0) and menu.notice.text.contains("cancelled") and not menu.network_dialog.visible,"cancel returns to co-op and releases the selected character")
 menu.join_game();game=current_scene;SessionCase.World.update(game,game.network_session.deadline()+1);await process_frame;menu=current_scene
 check(not menu.characters.is_active(0) and menu.notice.text.contains("timed out"),"connection timeout preserves selected profile and releases character")
 check(menu.network_dialog.visible and menu.network_dialog.feedback.text.contains("timed out") and int(menu.network_dialog.port_field.value)==Settings.DEFAULT_PORT+5,"failure reopens the join form with the attempted endpoint and reason")
 check(not FileAccess.file_exists(menu.storage.paths(0).garden),"join attempts never create a local Garden")
 menu.network_dialog.dismiss()
 menu.free()
 game=load("res://world.tscn").instantiate();game.progress.path="res://.godot/network_policy_"+Crypto.new().generate_random_bytes(8).hex_encode()+".cfg";game.local_character.path=game.progress.path+".character";root.add_child(game)
 game.network_session.configure_endpoint(game.network_session.address(),Settings.DEFAULT_PORT+4)
 UIFixture.control(game,"host_button").pressed.emit()
 check(game.network_session.role()=="Host" and game.network_dialog.visible and game.network_dialog.lan_choices.get_item_text(0).ends_with(":"+str(game.network_session.port())),"host opens a share panel for the live listening port")
 game.network_dialog.dismiss()
 var identity:="a".repeat(32);var manifest: Dictionary=game.progress.ContentIDs.manifest()
 check(SessionCase.World.admission_error(game,identity,manifest,Settings.PROTOCOL).is_empty(),"compatible guest admitted in Garden")
 check(not SessionCase.World.admission_error(game,identity,manifest,0).is_empty() and not SessionCase.World.admission_error(game,identity,{},Settings.PROTOCOL).is_empty(),"protocol and content mismatch rejected")
 check(not SessionCase.World.admission_error(game,game.local_character.identity,manifest,Settings.PROTOCOL).is_empty(),"host character cannot join itself")
 ExpeditionCase.set_membership(game, game.players[1], true)
 check(SessionCase.World.admission_error(game,identity,manifest,Settings.PROTOCOL).contains("Wilds"),"late joining an expedition is explicitly blocked")
 ExpeditionCase.set_membership(game, game.players[1], false);game.add_player(2)
 check(not SessionCase.World.allow_remote(game,2,"action",30),"unregistered peers cannot issue gameplay actions")
 SessionCase.set_ready(game, game.players[2], true);SessionCase.set_identity(game, game.players[2], identity)
 check(not SessionCase.World.admission_error(game,identity,manifest,Settings.PROTOCOL).is_empty(),"duplicate connected character rejected")
 for i in 30: check(SessionCase.World.allow_remote(game,2,"action",30),"normal action budget allowed")
 check(not SessionCase.World.allow_remote(game,2,"action",30),"request burst bounded")
 ExpeditionCase.remove_actor(game, 2);game.queue_free();await process_frame
 if not failed: print("PASS: direct-IP settings, validation, cancel, timeout, character safety, admission and request limits")
 quit(1 if failed else 0)
