extends SceneTree

const ExpeditionCase = preload("res://tests/support/expedition_case.gd")
const Cards = preload("res://affinity_cards.gd")
var failed:=false
func check(ok: bool,message: String):
 if not ok: failed=true;printerr("FAIL run flow: ",message)
func _initialize(): call_deferred("run")
func cleared_gate(game,floor_number: int):
 ExpeditionCase.set_world(game, {"encounter_number": floor_number});game.deepest_milestone=floor_number
 game.encounter.set_hp(-1, 0);game.encounter.clear_scouts()
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
 game.handle_loadout_action(1,p,"learn_0_64")
 game.toggle_overlay(null)
 game.handle_loadout_action(1,p,"loadpart_0_1")
 check(p.prepared==0,"weapon editing no longer happens at the Heart")
 game.send_garden_action("depart")
 check(not ExpeditionCase.is_wild(p),"remote departure cannot bypass gate position")
 p.pos=game.Stage.GATE;g.parts[0]=3
 game.send_action(false)
 check(not ExpeditionCase.is_wild(p) and game.loadout_menu.visible and g.parts[0]==3,"gate opens preparation before charging or entering")
 game.handle_loadout_action(1,p,"loadpart_0_1")
 check(p.prepared==1 and g.parts[0]==3,"gate prepares modular weapon without premature spending")
 game.loadout_view.refresh()
 check(game.loadout_view.depart_button.visible and not game.loadout_view.depart_button.disabled,"gate has explicit Craft and enter button")
 game.loadout_view.depart_button.pressed.emit()
 check(ExpeditionCase.is_wild(p) and p.weapon==1 and g.parts[0]==2 and not game.overlay.visible,"departure crafts weapon once and enters")
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
 check(game.abandon_confirmation.visible and ExpeditionCase.is_wild(p),"abandon confirmation does not abandon before confirming")
 game.abandon_confirmation.hide()
 game.send_garden_action("abandon_run")
 check(not ExpeditionCase.is_wild(p) and p.carried_seeds.is_empty() and p.carried_parts[4]==0 and not p.pouch,"abandon drops all carried and protected loot")
 check(reserve.unknown.is_empty() and reserve.parts[4]==0 and g.heart.progress==research_before and g.campaign.memories==memories_before and g.knowledge==knowledge_before and p.character.xp==xp_before,"abandon gives no loot, milestone, memory or additional character reward")
 check(game.deepest_milestone==0 and not game.checkpoint_pending,"abandon resets empty expedition")
 p.pos=game.Stage.GATE;game.send_garden_action("depart")
 check(ExpeditionCase.is_wild(p),"another expedition can start after abandonment")
 cleared_gate(game,5)
 ExpeditionCase.Transitions.checkpoint(game, 1,true)
 check(game.participation.floor()==6 and not game.checkpoint_pending,"ordinary gate advances immediately")
 cleared_gate(game,6)
 ExpeditionCase.Transitions.checkpoint(game, 1,true)
 check(game.participation.floor()==6 and game.checkpoint_pending and game.checkpoint_menu.visible,"sixth gate presents cards before transport")
 check(game.checkpoint_cards.get_child_count()==3,"three distinct modern card choices")
 var offer: Dictionary=game.checkpoint_card_data(p)[0]
 var selected_id: String=offer.choices[0].id
 var wallet_before: int=game.wallet_for(p).spent_essence()
 game.send_garden_action(game.affinity_checkpoint_action(offer.revision,"42"))
 check(game.participation.floor()==6 and game.wallet_for(p).spent_essence()==wallet_before,"invalid card cannot advance or spend")
 var command: String=game.affinity_checkpoint_action(offer.revision,"0")
 game.send_garden_action(command)
 check(game.participation.floor()==7 and not game.checkpoint_pending and not game.checkpoint_menu.visible and Cards.ledger(p).count()==1 and Cards.ledger(p).copies()[0].id==selected_id and game.wallet_for(p).spent_essence()==wallet_before,"one free card applies before solo transport")
 game.send_garden_action(command)
 check(Cards.ledger(p).count()==1,"stale duplicate choice cannot acquire twice")
 cleared_gate(game,12)
 ExpeditionCase.Transitions.checkpoint(game, 1,true)
 offer=game.checkpoint_card_data(p)[0]
 check(offer.choices.size()==3,"a later checkpoint retains three eligible identities")
 game.send_garden_action(game.affinity_checkpoint_action(offer.revision,"0"))
 check(game.participation.floor()==13 and Cards.ledger(p).count()==2,"later earned selection preserves the earlier acquired copy")
 cleared_gate(game,18)
 p[game.ExpeditionWallet.STATE]=game.ExpeditionWallet.Wallet.new(0,game.deepest_milestone*game.ExpeditionWallet.ESSENCE_PER_CLEARED_FLOOR)
 ExpeditionCase.Transitions.checkpoint(game, 1,true)
 offer=game.checkpoint_card_data(p)[0]
 check(game.run_wallet(p)==0 and offer.choices.all(func(card):return card.enabled and int(card.cost)==0) and not offer.reroll_enabled,"zero Essence preserves free choices while paid rerolls remain unavailable")
 game.send_garden_action(game.affinity_checkpoint_action(offer.revision,"reroll"))
 check(game.participation.floor()==18 and Cards.ledger(p).offer().revision==offer.revision,"unaffordable reroll cannot change the offer or travel")
 game.send_garden_action(game.affinity_checkpoint_action(offer.revision,"skip"))
 check(game.participation.floor()==19 and Cards.ledger(p).count()==2,"explicit skip advances without acquiring a card")
 game.free()
 if not failed: print("PASS: gate preparation, explicit crafting departure, abandon confirmation and no rewards, free checkpoint cards, revision safety, paid reroll refusal, skip and transport sequencing")
 quit(1 if failed else 0)
