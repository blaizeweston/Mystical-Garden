extends SceneTree
const Custody=preload("res://inventory_custody.gd")
const Profile=preload("res://character_profile.gd")
const Progress=preload("res://progress.gd")
const DevMode=preload("res://assets/terrain_m02/experimental/experiment_mode.gd")
const Tx=preload("res://game_transaction.gd")
const Ops=preload("res://persistence_operations.gd")
var failed:=false

func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> bool:
 if not ok:failed=true;printerr("FAIL INV01: ",label)
 return ok

func verified() -> bool:
 var path:=OS.get_user_data_dir().replace("\\","/").simplify_path()
 var root_path:=OS.get_environment("APPDATA").replace("\\","/").simplify_path()
 return root_path.get_base_dir()==ProjectSettings.globalize_path("res://.godot/vd").replace("\\","/").simplify_path() and path.begins_with(root_path+"/") and DevMode.verified()

func until(predicate: Callable) -> bool:
 var deadline:=Time.get_ticks_msec()+15000
 while not predicate.call() and Time.get_ticks_msec()<deadline:await process_frame
 return predicate.call()

func is_world() -> bool:return is_instance_valid(current_scene) and current_scene.has_method("seed_reserve")
func is_title() -> bool:return is_instance_valid(current_scene) and current_scene.has_method("continue_game")

func read_profile(path: String) -> Profile:
 var p:=Profile.new();p.path=path
 if not check(p.load_profile()==OK,"reload committed character"):return null
 return p

func pure() -> void:
 var p:=Profile.new()
 var a:=Progress.new();var b:=Progress.new()
 a.stock[0]=3;a.unknown.append(1);a.personal_parts[1]=2
 a.reserve(p.identity).stock[1]=2
 a.reserve("__shared_garden_inventory__").stock[0]=7
 var lock:=Custody.checkout({},a.archive.origin,"")
 check(Custody.admit(b,p.identity,lock,true)=="invalid","another origin cannot import the same lock")
 check(Custody.admit(a,p.identity,lock,true)=="active","explicitly assigned local and keyed historical reserves imported once")
 check(a.stock[0]==0 and a.legacy_personal_owner==p.identity and a.reserve(p.identity).stock[0]==3 and a.reserve(p.identity).stock[1]==2,"legacy ownership and quantities")
 a.reserve(p.identity).stock[0]-=1
 check(Custody.admit(a,p.identity,lock,true)=="active" and a.reserve(p.identity).stock[0]==2,"duplicate admission does not restore used seeds")
 check(a.reserve("__shared_garden_inventory__").stock[0]==7,"shared seeds untouched")
 var released:=Custody.release(a,p.identity)
 check(Custody.capture(a,p.identity)==Custody.blank_payload() and released.state=="returned","host freezes return and clears spendable reserve")
 var home:=Custody.accept_return(lock,a.archive.origin,released)
 check(home.payload.seeds.thorn_bloom==2 and home.payload.unknown==["lantern_moss"],"returned inventory preserves identified and concealed seed identities")
 check(Custody.accept_return(home,a.archive.origin,released).is_empty(),"return replay cannot apply to a home profile")
 check(Custody.close_return(a,p.identity,released) and Custody.admit(a,p.identity,lock)=="closed","acknowledgment retains stale checkout tombstone")
 var next:=Custody.checkout(home,b.archive.origin,"")
 check(Custody.admit(b,p.identity,next)=="active" and b.reserve(p.identity).stock[0]==2,"subsequent visit imports only the remaining inventory")

func run() -> void:
 if not verified():printerr("REFUSED unsafe INV01 fixture");quit(2);return
 pure()
 var menu: Node=load("res://main_menu.tscn").instantiate()
 root.add_child(menu);current_scene=menu
 menu.new_game();menu.create_character("Portable tester",0,preload("res://character_appearance.gd").DEFAULT)
 if not await until(is_world):
  check(false,"open first guarded Garden: "+str(current_scene.get("notice").text if is_title() else current_scene.get("status")))
  if is_title():print("TITLE ",current_scene.character_summary(0)," / ",current_scene.garden_summary(0))
  quit(1);return
 var game: Node=current_scene
 var owner: String=game.local_character.identity
 var profile_path: String=game.local_character.path
 var a_path: String=game.progress.path
 check(game.portable_inventory and Custody.locked(game.local_character.inventory_custody) and Custody.active(game.progress,owner),"ordinary title entry checks out local inventory")
 var item: int=game.Seeds.index_of("eclipse_root")
 var award: Dictionary=Tx.run_gameplay(game,Tx.Scope.GARDEN,func():
  var reserve: Dictionary=game.seed_reserve(game.players[1])
  reserve.stock[item]=2;reserve.unknown.append(0);reserve.parts[1]=3
  game.InventoryModel.put(game,game.players[1],"stash",{"item":"boss_mystery_seed","quantity":1,"lineages":{"ember_fern":1}})
  game.progress.reserve(game.InventoryModel.SHARED_OWNER).stock[0]=6
  return true)
 check(Tx.committed(award.persistence),"fixture grant via ordinary Garden transaction")
 game.local_character.data.name="Portable tester updated"
 game.character_dirty=true
 check(game.prepare_guarded_exit(false),"stopping hosting preserves the existing character-save boundary")
 var updated:=read_profile(profile_path)
 check(updated!=null and updated.data.name=="Portable tester updated" and Custody.locked(updated.inventory_custody) and Custody.active(game.progress,owner),"remaining in the Garden saves dirty character data without returning inventory")
 var before: PackedByteArray=FileAccess.get_file_as_bytes(a_path)
 var profile_before: PackedByteArray=FileAccess.get_file_as_bytes(profile_path)
 game.set_meta(&"guarded_gameplay_test_fault",func(phase,_path):return ERR_FILE_CANT_WRITE if phase=="stage" else OK)
 game.return_to_main_menu()
 game.remove_meta(&"guarded_gameplay_test_fault")
 check(is_world() and game.seed_reserve(game.players[1]).stock[item]==2 and Custody.locked(game.local_character.inventory_custody) and before==FileAccess.get_file_as_bytes(a_path) and profile_before==FileAccess.get_file_as_bytes(profile_path),"verified rollback preserves both Garden and locked profile")
 game.return_to_main_menu()
 if not await until(is_title):check(false,"return to title");quit(1);return
 await process_frame
 var p:=read_profile(profile_path)
 if p==null:quit(1);return
 check(p.inventory_custody.state=="home" and p.inventory_custody.payload.seeds.eclipse_root==2 and p.inventory_custody.payload.parts.has(Profile.Parts.DEFINITIONS[1].id),"local checkout returns to character profile")
 var old:=Progress.new();old.path=a_path
 check(old.load_garden()==OK and Custody.capture(old,owner)==Custody.blank_payload() and old.reserve("__shared_garden_inventory__").stock[0]==6,"first Garden has no remaining personal copy, retains shared stock")
 menu=current_scene
 menu.select_slot(1);menu.new_game()
 if not await until(is_world):check(false,"open different local Garden: "+str(current_scene.get("notice").text if is_title() else current_scene.get("status")));quit(1);return
 game=current_scene
 var reserve: Dictionary=game.seed_reserve(game.players[1])
 check(reserve.stock[item]==2 and reserve.unknown==[0] and reserve.parts[1]==3 and game.InventoryModel.extras(game,game.players[1],"stash")["boss_mystery_seed"]=={"ember_fern":1},"personal items arrive intact in second Garden")
 check(game.progress.reserve(game.InventoryModel.SHARED_OWNER).stock[0]==0 and not game.progress.discoveries[item],"no shared inventory or arrival-only discovery")
 game.players[1].pos=game.stage.bed_position(0)
 var knowledge: int=game.progress.knowledge
 check(game.cultivation.plant_seed(1,0,item,"stash") and reserve.stock[item]==1 and game.progress.discoveries[item] and game.progress.knowledge==knowledge+4,"transported rare identified seed plants without identification; first Garden discovery")
 game.return_to_main_menu()
 if not await until(is_title):check(false,"return after personal spending");quit(1);return
 await process_frame
 p=read_profile(profile_path)
 if p==null:quit(1);return
 check(p.inventory_custody.payload.seeds.eclipse_root==1,"spent personal seed stays consumed")
 # Re-enter the second Garden: no further award or legacy import.
 # Isolated terrain's title intentionally disables ordinary Continue, but
 # the same guarded launch used by ordinary production exercises custody.
 menu=current_scene;menu.select_slot(1);menu.launch(false)
 if not await until(is_world):check(false,"reopen Garden");quit(1);return
 game=current_scene
 check(game.progress.knowledge==knowledge+4 and game.seed_reserve(game.players[1]).stock[item]==1,"reload preserves discovery receipt and exact remaining inventory")
 # Force the existing paired transaction into uncertain durability. The
 # tentative profile may have changed, but the session and title must not
 # treat it as spendable until the linked journal is recovered.
 var second_path: String=game.progress.path
 var second_before:=FileAccess.get_file_as_bytes(second_path)
 var char_before:=FileAccess.get_file_as_bytes(profile_path)
 game.set_meta(&"guarded_gameplay_test_fault",func(phase,path):
  if phase=="replace" and path==second_path:return ERR_CANT_CREATE
  return ERR_FILE_CANT_WRITE if phase=="restore" else OK)
 game.return_to_main_menu()
 game.remove_meta(&"guarded_gameplay_test_fault")
 check(is_world() and not game.persistence_session.can_write() and game.persistence_session.pending_notice().begins_with("Save state is uncertain"),"uncertain local handoff blocks further spending")
 game.return_to_main_menu()
 if not await until(is_title):check(false,"leave blocked session without replay");quit(1);return
 await process_frame
 var recovered:=Ops.recover(PackedStringArray([profile_path]))
 check(recovered.get("value",{}).get("verified",false) and FileAccess.get_file_as_bytes(second_path)==second_before and FileAccess.get_file_as_bytes(profile_path)==char_before,"paired recovery restores both inventory authority and exact previous bytes")
 menu=current_scene;menu.select_slot(1);menu.launch(false)
 if not await until(is_world):check(false,"reopen custody after recovery");quit(1);return
 game=current_scene
 check(game.seed_reserve(game.players[1]).stock[item]==1 and Custody.locked(game.local_character.inventory_custody),"recovered active reserve can be used once")
 game.set_meta(&"guarded_gameplay_test_fault",func(phase,_path):return ERR_CANT_CREATE if phase=="publish_receipt" else OK)
 game.return_to_main_menu()
 if not await until(is_title):check(false,"confirmed cleanup-pending return reaches title");quit(1);return
 await process_frame
 recovered=Ops.recover(PackedStringArray([profile_path]))
 check(recovered.get("value",{}).get("verified",false),"confirmed return cleanup recovered")
 p=read_profile(profile_path)
 check(p!=null and p.inventory_custody.get("state")=="home" and p.inventory_custody.payload.seeds.eclipse_root==1,"cleanup-pending committed inventory returns exactly once")
 # Exercise the actual explicit legacy-assignment prompt on a third Garden.
 menu=current_scene
 check(menu.storage.new_world_guarded(2).get("ran",false),"create third disposable legacy-shaped Garden")
 var legacy:=Progress.new();legacy.path=menu.storage.paths(2).garden
 check(legacy.load_garden()==OK,"load legacy-shaped Garden")
 legacy.stock[0]=4;legacy.unknown.append(1);legacy.personal_parts[1]=3
 legacy.reserve(owner).stock[0]=2
 check(Tx.committed(legacy.save_garden_guarded()),"commit historical host and keyed reserve")
 var legacy_bytes:=FileAccess.get_file_as_bytes(legacy.path)
 menu.select_slot(2);menu.launch(false)
 var prompt: ConfirmationDialog
 for child in menu.get_children():
  if child is ConfirmationDialog and child.title=="Assign legacy personal resources":prompt=child
 if not check(is_title() and is_instance_valid(prompt),"historical unkeyed reserve requires explicit confirmation"):quit(1);return
 prompt.confirmed.emit()
 if not await until(is_world):check(false,"confirmed historical assignment opens Garden");quit(1);return
 game=current_scene
 check(game.progress.legacy_personal_owner==owner and game.progress.stock[0]==0 and game.seed_reserve(game.players[1]).stock[0]==6 and game.seed_reserve(game.players[1]).parts[1]==6,"historical host and guest reserve imported once, profile inventory preserved")
 check(FileAccess.get_file_as_bytes(legacy.path+".pre-portable-inventory-v1.bak")==legacy_bytes,"migration retains pre-conversion recovery bytes")
 game.return_to_main_menu()
 if not await until(is_title):check(false,"return historical custody");quit(1);return
 await process_frame
 p=read_profile(profile_path)
 check(p!=null and p.inventory_custody.payload.seeds.thorn_bloom==6 and p.inventory_custody.payload.seeds.eclipse_root==1,"migrated reserve and prior portable seed coexist")
 menu=current_scene;menu.select_slot(2);menu.launch(false)
 if not await until(is_world):check(false,"repeat legacy Garden load");quit(1);return
 game=current_scene
 check(game.seed_reserve(game.players[1]).stock[0]==6,"repeated migration cannot duplicate reserve")
 game.return_to_main_menu();await until(is_title)
 if not failed:print("PASS: portable inventory state, guarded local title checkout/return, transactional rollback, two Gardens, rare cultivation and exact legacy reserve ownership")
 quit(int(failed))
