extends SceneTree

const Cooldowns = preload("res://player_cooldowns.gd")
var game: Node
var role: String
var base: String
var failed:=false
const MASK: int=(1<<1)|(1<<3)|(1<<5)|(1<<7)|(1<<9)|(1<<11)
func check(ok: bool,message: String) -> void:
 if not ok:failed=true;printerr("FAIL Warden depth co-op ",role,": ",message)
func mark(key: String) -> void:
 var file:=FileAccess.open(base+"-"+key,FileAccess.WRITE);file.store_string("ok")
func marked(key: String) -> bool:return FileAccess.file_exists(base+"-"+key)
func until(predicate: Callable) -> bool:
 var deadline:=Time.get_ticks_msec()+20000
 while not predicate.call() and Time.get_ticks_msec()<deadline:await process_frame
 return predicate.call()
func _initialize() -> void:
 preload("res://combat_balance_preview.gd").enabled = false
 call_deferred("run")
func run() -> void:
 role=OS.get_cmdline_user_args()[0];base="res://.godot/warden-depth-net-"+OS.get_cmdline_user_args()[1]
 game=load("res://world.tscn").instantiate();game.progress.path=base+role+".cfg";game.local_character.path=game.progress.path+".character";game.guest_character.path=game.progress.path+".guest";root.add_child(game)
 if role=="host":await host_run()
 else:await guest_run()
 game.queue_free();await process_frame
 if not failed:print("PASS: Warden depth co-op ",role," portable specialization, remote counter/charge, plant and monster links, three-card purchase and no cleared-floor casts")
 quit(1 if failed else 0)
func host_run() -> void:
 check(game.host_game()==OK,"host opens")
 if not await until(func():return game.players.size()==2 and game.players.values().all(func(p):return p.profile_ready)):
  check(false,"guest registers");return
 var id:=int(game.players.keys()[1]);var p: Dictionary=game.players[id]
 check(p.character.upgrades[0]==MASK,"specialization survives registration")
 game.battlefield.configure(0,1);game.enemy_hp=100;game.enemy_pos=Vector3(0,0,-2);game.enemy_stagger_until=Time.get_ticks_msec()+60000;game.scouts.clear()
 for player in game.players.values():player.wild=true;player.pos=Vector3(0,0,-1)
 p.weapon=44;p.secondary=game.Seeds.DEFINITIONS[18].part;p.graft_part=game.Parts.HOOK
 check(await until(func():return p[Cooldowns.STATE].deadline(Cooldowns.Q)>0),"guest sends counter skill")
 game.apply_enemy_hit(id,p,Time.get_ticks_msec(),1,0,game.enemy_pos)
 check(p.hp==10 and p.counter_until>0,"host creates counter after blocked monster hit")
 mark("counter-ready")
 check(await until(func():return p[Cooldowns.STATE].deadline(Cooldowns.R)>0),"guest sends specialized charge")
 check(game.enemy_hp<95 and p.counter_until==0,"host resolves contact with counter and installed plant/graft")
 game.enemy_hp=0;game.encounter_rewarded=true;game.encounter_number=6;game.checkpoint_pending=true;game.checkpoint_ready.clear()
 for player in game.players.values():player.pos=game.battlefield.advance
 p[game.ExpeditionWallet.STATE] = game.ExpeditionWallet.Wallet.new(10000, game.wallet_for(p).spent_essence());p.offer_floor=6;p.checkpoint_offers=["warden_guard_counter","warden_frost_link","plant_frostbell_shatter"]
 game.present_checkpoint_cards(id)
 check(await until(func():return p.get("run_upgrades",{}).get("warden_guard_counter",0)==1),"real guest checkpoint choice buys counter upgrade")
 check(p.character.upgrades[0]==MASK and p.weapon==44 and p.graft_part==game.Parts.HOOK,"purchase preserves permanent branch and loadout")
 check(await until(func():return marked("verified")),"guest observes purchase and cleared-floor stability")
 mark("done");check(await until(func():return game.players.size()==1),"guest leaves");game.leave_game("Warden depth fixture complete")
func guest_run() -> void:
 game.guest_character.data.active_class=0;game.guest_character.data.xp[0]=2600;game.guest_character.data.upgrades[0]=MASK;game.guest_character.save_profile()
 check(game.join_game()==OK,"guest joins")
 check(await until(func():return game.session=="Guest" and not game.client_details.is_empty()),"guest admitted")
 var id:=game.multiplayer.get_unique_id()
 check(await until(func():return game.players[id].wild and game.players[id].get("core_part",0)==44),"loadout arrives")
 check(game.Skills.resolve(0,0,game.guest_character.data).name=="Thorn Counter" and game.Skills.resolve(0,1,game.guest_character.data).name=="Shattering Advance","portable skill identities")
 game.send_garden_action("class_skill")
 check(await until(func():return marked("counter-ready")),"host confirms guard")
 game.send_garden_action("class_skill_two")
 check(await until(func():return game.checkpoint_menu.visible and game.checkpoint_cards.get_child_count()==3),"three actual text cards reach guest")
 var buttons=game.checkpoint_cards.find_children("*","Button",true,false)
 check(buttons.size()==3,"three selectable card buttons")
 buttons[0].pressed.emit()
 check(await until(func():return game.players[id].get("run_upgrades",{}).get("warden_guard_counter",0)==1),"owner upgrade state arrives")
 game.send_garden_action("class_skill");game.send_garden_action("class_skill_two")
 await create_timer(.3).timeout
 check(game.session=="Guest" and game.encounter_cleared(),"new abilities safe after cleared floor")
 mark("verified");check(await until(func():return marked("done")),"host finishes");game.leave_game("Warden depth fixture complete")
