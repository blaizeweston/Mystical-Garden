extends SceneTree
const Core=preload("res://core_combat.gd")
var failed:=false
func check(ok: bool,message: String):
 if not ok: failed=true;printerr("FAIL graft menu: ",message)
func roll_seed(game,chance: float,success: bool) -> int:
 for value in 10000:
  var sample:=RandomNumberGenerator.new();sample.seed=value
  if (sample.randf()<chance)==success: return value
 return 0
func _initialize():
 preload("res://combat_balance_preview.gd").enabled = false
 call_deferred("run")
func run():
 var game=load("res://world.tscn").instantiate()
 var token=Crypto.new().generate_random_bytes(8).hex_encode()
 game.progress.path="res://.godot/graft_menu_"+token+".cfg"
 game.local_character.path=game.progress.path+".character"
 root.add_child(game);game.set_process(false);game.set_physics_process(false)
 var p: Dictionary=game.players[1]
 p.character=game.Character.blank()
 p.wild=true;p.weapon=1;p.secondary=2;p.catalyst=3;p.power=2;p.technique=1;p.rift_hook=true
 p.carried_parts.fill(0);p.carried_parts[4]=3;p.carried_parts[18]=3;p.carried_parts[19]=2;p.carried_parts[1]=4
 game.encounter_number=8;p.pos=game.battlefield.graft
 var found:=0
 for floor_number in range(1,81):
  game.encounter_number=floor_number
  found+=int(game.graft_altar_open())
 check(found==10,"altars are half as frequent: every eighth encounter")
 game.encounter_number=4
 check(not game.graft_altar_open(),"old fourth encounter no longer spawns a shrine")
 game.encounter_number=8
 var counts: Array=p.carried_parts.duplicate()
 game.send_action(false)
 check(game.graft_menu.visible and p.carried_parts==counts and p.graft_part==0,"E opens a specialized menu without consuming parts")
 var options: Array=game.graft_menu_data(p).options
 check(options.size()==3 and game.graft_view.part_pick.item_count==3,"only carried monster parts appear")
 check(game.graft_view.current.text.contains("Core:") and game.graft_view.current.text.contains("Catalyst:"),"plant slots are read-only context")
 game.toggle_overlay(null);game.send_garden_action("graft")
 check(game.graft_menu.visible and p.carried_parts==counts,"G also opens the menu instead of attempting immediately")
 game.graft_view.selected=4;game.graft_view.update_selection()
 check(game.graft_view.component.text.contains("Success chance:") and game.graft_view.preview.text.contains("After grafting"),"menu shows probability and resolved weapon preview")
 game.rng.seed=roll_seed(game,game.graft_chance(p,4),true)
 game.graft_view.attempt.pressed.emit()
 check(p.graft_part==4 and p.graft_floor==8 and p.carried_parts[4]==2,"explicit menu attempt installs and consumes exactly one")
 check(game.graft_view.current.text.contains("Briar Hook") and game.graft_view.current.text.contains("Draws a caught enemy"),"installed component and its Core effect appear in the workbench")
 var before: int=p.carried_parts[18]
 game.send_garden_action("graft_install_18")
 check(p.graft_part==4 and p.carried_parts[18]==before,"replacement cannot happen at the installation altar")
 game.encounter_number=9
 purchase(game,p,"quickroot")
 game.encounter_number=12
 purchase(game,p,"graft_0")
 var reach_with_hook: float=game.weapon_stats(p).get("reach",0)
 trip(game,p,true)
 game.encounter_number=16
 p.pos=game.battlefield.graft
 game.rng.seed=roll_seed(game,game.graft_chance(p,18),false)
 game.send_garden_action("graft_install_18")
 check(p.graft_part==4 and p.carried_parts[18]==before-1 and p.graft_floor==8,"failed later replacement consumes new part and preserves old graft")
 var preview_text: String=""
 for item in game.graft_menu_data(p).options:
  if item.part==18: preview_text=item.preview
 game.rng.seed=roll_seed(game,game.graft_chance(p,18),true)
 game.send_garden_action("graft_install_18")
 check(p.graft_part==18 and p.graft_floor==16 and p.carried_parts[18]==before-2 and p.carried_parts[4]==2,"successful replacement sacrifices old graft without returning an item")
 check([p.weapon,p.secondary,p.catalyst,p.power,p.technique,p.rift_hook]==[1,2,3,2,1,true],"replacement preserves all plant slots and purchased upgrades")
 check(game.Weapons.describe(game.weapon_stats(p))==preview_text,"preview equals actual resolved weapon after replacement")
 var stats: Dictionary=game.weapon_stats(p)
 check(not stats.core_build.skill.has("trip_pull") and preview_text.contains("Quickroot") and not preview_text.contains("Draws a caught enemy"),"replacement preview keeps purchased behavior and drops the live Hook effect")
 check(is_equal_approx(float(stats.get("reach",0)),reach_with_hook) and is_equal_approx(float(stats.get("pull",0)),.4),"the purchased graft-specific bonus stays after replacement")
 trip(game,p,false)
 game.encounter_number=24
 counts=p.carried_parts.duplicate()
 game.send_garden_action("graft_install_1");game.send_garden_action("graft_install_999")
 check(p.carried_parts==counts and p.graft_part==18,"plant and invalid candidate requests are harmless")
 p.pos=game.battlefield.graft+Vector3(5,0,0)
 game.send_garden_action("graft_install_19")
 check(p.carried_parts==counts,"distant request cannot install or consume")
 game.graft_view._process(.016)
 check(not game.graft_menu.visible,"leaving range closes the menu")
 p.pos=game.battlefield.graft;p.wild=false
 game.attempt_graft(1,p,19)
 check(p.carried_parts==counts,"Garden does not allow monster grafts")
 p.wild=true;game.destination=game.Campaign.HEART
 check(not game.graft_altar_open(),"normal altars remain excluded from finale")
 game.return_to_garden(p)
 check(p.graft_floor==0 and p.graft_part==0,"run return clears graft location and component")
 game.free()
 if not failed: print("PASS: rare altar schedule, E/G menu, carried-only candidates, previews, explicit graft costs, later replacement success/failure, retained upgrades and authority validation")
 quit(1 if failed else 0)


func purchase(game: Node,p: Dictionary,card: String) -> void:
 game.deepest_milestone=game.encounter_number
 game.enemy_hp=0;game.scouts.clear()
 p.pos=game.battlefield.advance
 p.offer_floor=game.encounter_number;p.checkpoint_offers=[card,"power","reach"]
 check(game.buy_upgrade(1,p,0) and int(p.run_upgrades.get(card,0))==1,"eligible card bought at a real checkpoint: "+card)


func trip(game: Node,p: Dictionary,with_hook: bool) -> void:
 game.battlefield.configure(0,1,0)
 game.battlefield.barriers.clear()
 p.pos=Vector3.ZERO
 Core.reset(game)
 p.core_ready_at=0;p.core_cast_until=0;p.cast_until=0
 game.enemy_hp=30;game.enemy_kind=0;game.enemy_winding_up=false;game.boss_kind=-1;game.scouts.clear()
 game.garden_action(1,Core.request(game,p,Vector2(0,-1)))
 var line: Dictionary=game.get_meta(Core.STATE,{}).get(1,{})
 check(not line.is_empty(),"Thorn Line casts with either graft")
 if line.is_empty(): return
 var original: Vector3=line.center+Vector3.RIGHT
 game.enemy_pos=original
 var ready: int=p.core_ready_at
 Core.tick(game,line.armed)
 check(game.enemy_hp==29 and Core.hints(game).size()==1,"one contact deals damage and leaves the thorns active")
 check(game.enemy_pos.is_equal_approx(line.center if with_hook else original),"only the installed grasp graft pulls toward line center")
 check(p.core_ready_at==ready-3000,"purchased Quickroot remains active with either graft")
 p.pos=game.battlefield.graft
