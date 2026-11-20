extends SceneTree

const SessionCase = preload("res://tests/support/session_case.gd")
const Roster=preload("res://character_slots.gd")
const Slots=preload("res://save_slots.gd")
const Profile=preload("res://character_profile.gd")
var failed:=false
func check(ok: bool,message: String):
 if not ok: failed=true;printerr("FAIL character roster: ",message)
func _initialize(): call_deferred("run")
func run():
 var base:="res://.godot/roster_"+Crypto.new().generate_random_bytes(8).hex_encode()
 var worlds:=Slots.new();worlds.root_path=base;worlds.prepare(false)
 var roster:=Roster.new();roster.root_path=base.path_join("characters")
 check(roster.prepare(worlds)==OK and roster.count()==3,"three independent character slots start empty")
 check(roster.create(0,"  Rowan  ",2,[2,1,2,1,1])==OK,"named customized character created")
 check(roster.create(0,"Overwrite",0,[])==ERR_ALREADY_EXISTS and roster.create(3,"Beyond",0,[])==ERR_INVALID_PARAMETER,"creation never overwrites an existing profile or aliases a slot")
 check(roster.create(1,"Mira",4,[1,2,0,2,2])==OK,"second distinct class character created")
 var rowan:=Profile.new();rowan.path=roster.paths(0).character;rowan.load_profile()
 rowan.data.xp[2]=350;rowan.data.plants[1]=9;rowan.save_profile()
 var identity:=rowan.identity
 check(rowan.data.name=="Rowan" and rowan.data.active_class==2 and rowan.data.appearance.slice(0,5) == [2,1,2,1,1],"name, starting class and appearance persist")
 check(roster.set_capacity(5)==OK and roster.count()==5 and roster.create(4,"Future",1,[])==OK,"capacity can grow without clamping new slots to the first three")
 check(roster.summary(4).identity!=identity and roster.summary(0).identity==identity,"expansion keeps identities stable")
 var menu=load("res://main_menu.tscn").instantiate();menu.storage=worlds;menu.import_legacy=false;menu.restore_last_selection=false
 root.add_child(menu);current_scene=menu
 check(menu.character_buttons.size()==5 and menu.slot_buttons.size()==3,"roster UI expands independently from world slots")
 menu.select_character(2);menu.select_slot(0)
 check(not menu.new_button.disabled and menu.continue_button.disabled and menu.join_button.disabled,"an empty character can start setup from New Garden")
 menu.request_create_character();check(menu.creator.visible,"main menu opens live character creator")
 menu.creator.name_field.text="Thistle";menu.creator.class_choice.select(3);menu.creator.options[0].select(1)
 menu.creator.confirmed.emit();menu.creator.hide()
 check(menu.characters.summary(2).name=="Thistle" and menu.characters.summary(2).class_name==Profile.Classes.DEFINITIONS[3].name,"creator submits the captured empty slot and class")
 menu.select_character(0);menu.select_slot(0);menu.new_game()
 var world=current_scene;await process_frame
 check(world.local_character.identity==identity and world.players[1].frame==2 and world.local_character.data.plants[1]==9,"new world uses selected existing character progression")
 check(roster.is_active(0) and worlds.is_active(0),"host owns independent character and world leases")
 world.progress.knowledge=18;world.return_to_main_menu();await process_frame;menu=current_scene
 check(not roster.is_active(0) and not worlds.is_active(0),"return releases both leases")
 menu.select_character(1);menu.select_slot(0);menu.continue_game();world=current_scene;await process_frame
 check(world.local_character.data.name=="Mira" and world.players[1].frame==4 and world.progress.knowledge==18 and world.local_character.data.xp[2]==0,"same saved world accepts a different independent character")
 world.return_to_main_menu();await process_frame;menu=current_scene
 menu.request_delete_save();menu.confirm_delete_save();menu.deletion_confirmation.hide()
 check(not worlds.summary(0).exists and roster.summary(0).identity==identity and roster.summary(1).name=="Mira","world deletion preserves every character")
 check(worlds.new_world(0)==OK and worlds.new_world(0,true)==OK and roster.summary(0).level==4,"world replacement preserves character levels")
 roster.claim(1)
 # An active profile may be in a journaled commit; browsing must never recover it.
 var link:=FileAccess.open(roster.paths(1).character+".transaction",FileAccess.WRITE);link.store_string("unfinished live journal");link.close()
 check(roster.summary(1).error==OK,"browsing an active character never invokes save recovery")
 DirAccess.remove_absolute(roster.paths(1).character+".transaction")
 menu.select_character(1)
 check(menu.new_button.disabled and menu.join_button.disabled,"a character cannot enter two sessions simultaneously")
 roster.release(1);menu.select_character(0)
 worlds.claim(0);menu.select_slot(0)
 check(menu.new_button.disabled and menu.continue_button.disabled and not menu.join_button.disabled,"joining only requires its character, not ownership of the selected world")
 var world_bytes:=FileAccess.get_file_as_bytes(worlds.paths(0).garden)
 menu.join_game();world=current_scene
 check(not world.slot_claimed and world.character_slot_claimed and worlds.is_active(0),"guest claims its character without stealing an active world")
 world.session_world.connection_failed();await process_frame;menu=current_scene
 check(not roster.is_active(0) and FileAccess.get_file_as_bytes(worlds.paths(0).garden)==world_bytes,"failed connection releases character and leaves host world untouched")
 worlds.release(0);menu.free()
 # Existing profiles import by identity, once, leaving their source intact.
 var legacy:=Slots.new();legacy.root_path=base.path_join("legacy");legacy.prepare(false);legacy.ensure_character(0)
 var original:=Profile.new();original.path=legacy.paths(0).character;original.load_profile();original.data.xp[1]=15;original.save_profile()
 var bytes:=FileAccess.get_file_as_bytes(original.path)
 var migrated:=Roster.new();migrated.root_path=legacy.root_path.path_join("characters")
 check(migrated.prepare(legacy)==OK and migrated.summary(0).identity==original.identity and FileAccess.get_file_as_bytes(original.path)==bytes,"legacy migration preserves identity, progress and source")
 check(migrated.prepare(legacy)==OK and not migrated.summary(1).exists,"migration is repeatable without duplicate characters")
 var corrupt:=FileAccess.open(original.path,FileAccess.WRITE);corrupt.store_string("invalid legacy profile");corrupt.close()
 check(legacy.new_world(0)==OK and legacy.summary(0).error==OK and migrated.prepare(legacy)==OK,"retired per-world character files cannot block independent world loading or reimport")
 if not failed: print("PASS: independent expandable roster, creation, world selection, progression, leases, migration and world deletion safety")
 quit(1 if failed else 0)
