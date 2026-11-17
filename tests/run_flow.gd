extends SceneTree
var failed:=false
func check(ok: bool,message: String):
 if not ok: failed=true;printerr("FAIL run flow: ",message)
func _initialize(): call_deferred("run")
func cleared_gate(game,floor_number: int):
 game.encounter_number=floor_number;game.deepest_milestone=floor_number
 game.enemy_hp=0;game.scouts.clear()
 game.players[1].pos=game.battlefield.advance
func run():
 var game=load("res://world.tscn").instantiate()
 var token=Crypto.new().generate_random_bytes(8).hex_encode()
 game.progress.path="res://.godot/run_flow_"+token+".cfg"
 game.local_character.path=game.progress.path+".character"
 root.add_child(game);game.set_process(false);game.set_physics_process(false)
 var p: Dictionary=game.players[1]
 var g=game.progress
 p.pos=game.Stage.HEART
 game.handle_loadout_action(1,p,"loadpart_0_1")
 check(p.prepared==0,"weapon editing no longer happens at the Heart")
 game.send_garden_action("depart")
 check(not p.wild,"remote departure cannot bypass gate position")
 p.pos=game.Stage.GATE;g.parts[0]=3
 game.send_action(false)
 check(not p.wild and game.loadout_menu.visible and g.parts[0]==3,"gate opens preparation before charging or entering")
 game.handle_loadout_action(1,p,"loadpart_0_1")
 check(p.prepared==1 and g.parts[0]==3,"gate prepares modular weapon without premature spending")
 game.loadout_view.refresh()
 check(game.loadout_view.depart_button.visible and not game.loadout_view.depart_button.disabled,"gate has explicit Craft and enter button")
 game.loadout_view.depart_button.pressed.emit()
 check(p.wild and p.weapon==1 and g.parts[0]==2 and not game.overlay.visible,"departure crafts weapon once and enters")
 # Abandonment has no extraction, protected-seed, guardian or research payout.
 var reserve: Dictionary=game.seed_reserve(p)
 reserve.unknown.clear();reserve.parts.fill(0)
 p.carried_seeds.assign([0,1]);p.pouch=true;p.carried_parts[4]=2
 g.heart.start(g,"flowering")
 var research_before: Dictionary=g.heart.progress.duplicate()
 var memories_before: Array=g.campaign.memories.duplicate()
 var knowledge_before: int=g.knowledge
 var xp_before: Array=p.character.xp.duplicate()
 game.deepest_milestone=10;game.run_guardians=1
 game.request_abandon_run()
 check(game.abandon_confirmation.visible and p.wild,"abandon confirmation does not abandon before confirming")
 game.abandon_confirmation.hide()
 game.send_garden_action("abandon_run")
 check(not p.wild and p.carried_seeds.is_empty() and p.carried_parts[4]==0 and not p.pouch,"abandon drops all carried and protected loot")
 check(reserve.unknown.is_empty() and reserve.parts[4]==0 and g.heart.progress==research_before and g.campaign.memories==memories_before and g.knowledge==knowledge_before and p.character.xp==xp_before,"abandon gives no loot, milestone, memory or additional character reward")
 check(game.deepest_milestone==0 and not game.checkpoint_pending,"abandon resets empty expedition")
 p.pos=game.Stage.GATE;game.send_garden_action("depart")
 check(p.wild,"another expedition can start after abandonment")
 cleared_gate(game,5)
 game.use_checkpoint(1,true)
 check(game.encounter_number==6 and not game.checkpoint_pending,"ordinary gate advances immediately")
 cleared_gate(game,6)
 var power_before: int=p.power
 game.use_checkpoint(1,true)
 check(game.encounter_number==6 and game.checkpoint_pending and game.checkpoint_menu.visible,"sixth gate presents cards before transport")
 check(game.checkpoint_cards.get_child_count() in [3,4],"three normal cards with a possible fourth")
 var selected_id: String=game.checkpoint_offer_ids(p)[0]
 var selected_cost: int=game.RunUpgrades.get_upgrade(selected_id).cost
 var wallet_before: int=game.wallet_for(p).spent_essence()
 game.send_garden_action("checkpoint_choice_42")
 check(game.encounter_number==6 and game.wallet_for(p).spent_essence()==wallet_before,"invalid card cannot advance or spend")
 game.send_garden_action("checkpoint_choice_0")
 check(game.encounter_number==7 and not game.checkpoint_pending and not game.checkpoint_menu.visible and int(p.run_upgrades.get(selected_id,0))==1 and game.wallet_for(p).spent_essence()==wallet_before+selected_cost,"choosing a card applies exactly one upgrade then transports")
 game.send_garden_action("checkpoint_choice_0")
 check(int(p.run_upgrades.get(selected_id,0))==1,"stale duplicate choice cannot purchase twice")
 cleared_gate(game,12);p.weapon=3;p.graft_part=4;p[game.ExpeditionWallet.STATE] = game.ExpeditionWallet.Wallet.new(game.wallet_for(p).earned_sparks(), 0);p.offer_floor=12;p.checkpoint_offers=["power","technique","rift_hook"]
 game.use_checkpoint(1,true)
 check(game.checkpoint_cards.get_child_count()==3,"a fixed eligible rare-link fixture remains purchasable")
 game.send_garden_action("checkpoint_choice_2")
 check(game.encounter_number==13 and p.rift_hook,"rare linked upgrade applies before transport")
 cleared_gate(game,18);p[game.ExpeditionWallet.STATE] = game.ExpeditionWallet.Wallet.new(game.wallet_for(p).earned_sparks(), game.deepest_milestone*game.ExpeditionWallet.ESSENCE_PER_CLEARED_FLOOR)
 game.use_checkpoint(1,true)
 var choices: Array=game.checkpoint_card_data(p)
 check(not choices[0].enabled and not choices[1].enabled,"unaffordable cards are visibly disabled")
 game.send_garden_action("checkpoint_choice_1")
 check(game.encounter_number==18,"unaffordable purchase cannot bypass choice")
 game.send_garden_action("checkpoint_choice_-1")
 check(game.encounter_number==19,"explicit skip advances with no purchase")
 game.free()
 if not failed: print("PASS: gate preparation, explicit crafting departure, abandon confirmation and no rewards, checkpoint text cards, costs, rare synergy, skip and transport sequencing")
 quit(1 if failed else 0)
