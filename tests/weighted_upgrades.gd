extends SceneTree
const Catalog=preload("res://run_upgrade_catalog.gd")
const Core=preload("res://core_combat.gd")
var failed:=false
func check(ok: bool,message: String):
 if not ok: failed=true;printerr("FAIL weighted upgrades: ",message)
func _initialize():
 preload("res://combat_balance_preview.gd").enabled = false
 call_deferred("run")
func gate(game,p: Dictionary,floor_number: int):
 p.wild=true;game.encounter_number=floor_number;game.deepest_milestone=floor_number
 game.enemy_hp=0;game.scouts.clear();p.pos=game.battlefield.advance;p.last_offer=0
func run():
 var game=load("res://world.tscn").instantiate()
 var token=Crypto.new().generate_random_bytes(8).hex_encode()
 game.progress.path="res://.godot/weighted_test_"+token+".cfg";game.local_character.path=game.progress.path+".character"
 root.add_child(game);game.set_process(false);game.set_physics_process(false)
 var p: Dictionary=game.players[1]
 p.frame=0;p.weapon_kind=0;p.weapon=0;p.secondary=0;p.catalyst=0;p.graft_part=0;p.run_upgrades={}
 var original: Array=JSON.parse_string(FileAccess.get_file_as_string("res://assets/upgrades/checkpoint_upgrades.json"))
 check(Catalog.all().size()==original.size()+Catalog.CoreRules.RULES.size()-1+Catalog.Classes.Warden.CARDS.size()+Catalog.Classes.Subclasses.cards().size(),"base catalog, Core cards and Warden subclass cards")
 var ids: Array=[]
 for entry in Catalog.all():
  check(not ids.has(entry.id),"unique upgrade ID "+entry.id);ids.append(entry.id)
  check((not entry.effects.is_empty() or entry.has("behavior") or entry.has("core_tuning") or entry.has("class_behavior")) and Catalog.core_errors(entry).is_empty() and int(entry.cost)>0 and Catalog.RARITY_WEIGHT.has(entry.rarity),"valid effects and rarity for "+entry.id)
 check(Catalog.weight(Catalog.get_upgrade("class_0_0"),p,5)>0 and Catalog.weight(Catalog.get_upgrade("class_1_0"),p,5)==0,"class matching controls eligibility")
 check(Catalog.weight(Catalog.get_upgrade("weapon_0_0"),p,5)>0 and Catalog.weight(Catalog.get_upgrade("weapon_0_1"),p,5)==0,"equipped basic weapon controls eligibility")
 check(Catalog.weight(Catalog.get_upgrade("plant_piercing"),p,5)==0,"uninstalled plant affinity is unavailable")
 p.weapon=1
 var core_weight:=Catalog.weight(Catalog.get_upgrade("plant_piercing"),p,5)
 p.secondary=1
 check(core_weight>0 and Catalog.weight(Catalog.get_upgrade("plant_piercing"),p,5)>core_weight,"matching installed plant parts increase affinity weight")
 p.weapon=0;p.secondary=0;p.graft_part=18
 check(Catalog.weight(Catalog.get_upgrade("graft_1"),p,5)>0 and Catalog.weight(Catalog.get_upgrade("graft_2"),p,5)==0,"installed monster species unlocks only its component upgrades")
 check(Catalog.weight(Catalog.get_upgrade("plant_arcane"),p,5)==0,"graft tags do not impersonate installed plant tags")
 for c in 5:
  p.frame=c
  for weapon in 3:
   p.weapon_kind=weapon
   check(Catalog.weight(Catalog.get_upgrade("weapon_%d_%d"%[c,weapon]),p,10)>0,"all fifteen weapon identities have a matching upgrade")
 for part in range(1,game.Parts.DEFINITIONS.size()):
  if not game.Parts.is_monster(part): continue
  p.graft_part=part
  var monster:=int(game.Parts.DEFINITIONS[part].monster)
  check(Catalog.all().any(func(card):return card.get("grafts",[]).has(monster) and Catalog.weight(card,p,10)>0),"all monster components have an upgrade")
 p.frame=0;p.weapon_kind=0;p.weapon=3;p.secondary=1;p.catalyst=2;p.graft_part=4
 var fourth:=0
 for seed_value in 2000:
  var offers:=Catalog.roll(p,10,seed_value,20)
  check(offers.size() in [3,4],"every roll contains exactly three or four choices")
  if offers.size()==4: fourth+=1
  var unique: Array=[]
  for id in offers:
   check(not unique.has(id) and Catalog.requirement(Catalog.get_upgrade(id),p).is_empty(),"draw without replacement and eligible components")
   unique.append(id)
 check(fourth>=120 and fourth<=200,"fourth-card rate stays near eight percent")
 print("Fourth-card sample: ",fourth," / 2000")
 var seed_four:=0
 for candidate in 1000:
  if Catalog.roll(p,12,candidate,20).size()==4: seed_four=candidate;break
 gate(game,p,12);p.upgrade_seed=seed_four
 var initial: Array=game.checkpoint_offer_ids(p).duplicate()
 p.upgrade_seed=999999
 check(game.checkpoint_offer_ids(p)==initial,"changing RNG or reopening cannot reroll cached cards")
 var first_data: Array=game.checkpoint_card_data(p)
 check(first_data.size()==4 and first_data[3].choice==3,"fourth choice is transmitted as a purchasable card")
 game.checkpoint_pending=true
 game.choose_checkpoint_card(1,p,99)
 check(game.wallet_for(p).spent_essence()==0 and game.encounter_number==12,"invalid indices cannot spend or advance")
 var chosen: String=initial[3];var cost:=int(Catalog.get_upgrade(chosen).cost)
 game.choose_checkpoint_card(1,p,3)
 check(game.encounter_number==13 and int(p.run_upgrades.get(chosen,0))==1 and game.wallet_for(p).spent_essence()==cost,"fourth card applies once and advances only after purchase")
 var ranks: Dictionary=p.run_upgrades.duplicate()
 game.choose_checkpoint_card(1,p,3)
 check(p.run_upgrades==ranks,"duplicate request cannot buy the same offer twice")
 # Fund a known class card to verify its live health effect.
 p.run_upgrades={};p[game.ExpeditionWallet.STATE] = game.ExpeditionWallet.Wallet.new(game.wallet_for(p).earned_sparks(), 0);gate(game,p,18)
 p.offer_floor=18;p.checkpoint_offers=["class_0_0","power","reach"]
 p.hp=8;p.max_hp=10
 check(game.buy_upgrade(1,p,0) and p.max_hp==12 and p.hp==10,"health upgrades update current max health and grant added capacity")
 check(not game.buy_upgrade(1,p,1),"one purchase per checkpoint")
 p.run_upgrades={"class_0_0":3}
 check(Catalog.weight(Catalog.get_upgrade("class_0_0"),p,20)==0,"rank cap removes exhausted upgrades")
 # Once purchased, a graft echo is independent of its original component.
 p.run_upgrades={"graft_1":1};p.weapon=0;p.secondary=0;p.catalyst=0;p.graft_part=4
 var stats: Dictionary=game.weapon_stats(p)
 check(int(stats.get("recovery",0))>=400 and int(stats.get("windup_damage",0))>=1,"purchased monster effects remain after the graft is replaced")
 # A cached card's missing prerequisite disables purchase without rolling new choices.
 p.run_upgrades={};gate(game,p,24);p.offer_floor=24;p.checkpoint_offers=["graft_1","power","reach"]
 check(not game.checkpoint_card_data(p)[0].enabled and not game.buy_upgrade(1,p,0),"current loadout is validated when purchasing a cached card")
 check(p.checkpoint_offers==["graft_1","power","reach"],"changed loadout does not create a free reroll")
 p[game.ExpeditionWallet.STATE] = game.ExpeditionWallet.Wallet.new(game.wallet_for(p).earned_sparks(), game.deepest_milestone*game.ExpeditionWallet.ESSENCE_PER_CLEARED_FLOOR)
 var before: Dictionary=p.run_upgrades.duplicate()
 check(not game.buy_upgrade(1,p,1) and p.run_upgrades==before,"cannot purchase without essence")
 # Full restoration link still teaches the Garden exactly once.
 p[game.ExpeditionWallet.STATE] = game.ExpeditionWallet.Wallet.new(game.wallet_for(p).earned_sparks(), 0);p.weapon=3;p.graft_part=4;p.run_upgrades={};p.last_offer=0;p.checkpoint_offers=["rift_hook","power","reach"]
 var knowledge: int=game.progress.knowledge
 check(game.buy_upgrade(1,p,0) and p.rift_hook and game.progress.rift_hook_discovered and game.progress.knowledge==knowledge+4,"Rift Hook link is an actual upgrade and permanent first discovery")
 game.return_to_garden(p)
 check(p.run_upgrades.is_empty() and p.checkpoint_offers.is_empty() and p.power==0 and p.technique==0 and not p.rift_hook,"return clears all expedition upgrades and cached cards")
 core_cards(game,p)
 p.weapon=game.Parts.index_of("plant:ember_fern")
 p[game.ExpeditionWallet.STATE] = game.ExpeditionWallet.Wallet.new(game.wallet_for(p).earned_sparks(), 0)
 gate(game,p,12)
 p.offer_floor=12
 p.checkpoint_offers=["core_ember_wake","power","reach"]
 check(game.checkpoint_card_data(p)[0].description.contains("smolders for longer"),"authored effect is described on the live card")
 check(game.buy_upgrade(1,p,0) and Core.equipped(p).get("field_ms",0)==2750,"buying Banked Coals extends the live trail")
 check(not game.buy_upgrade(1,p,0),"authored effect has the same bounded purchase flow")
 game.free()
 if not failed: print("PASS: weighted pools, authored Core cards, unique draws, rarity, cached purchase, slot requirements, bounded Core behaviors, rank caps and graft persistence")
 quit(1 if failed else 0)


func core_cards(game: Node,p: Dictionary) -> void:
 var fork := Catalog.get_upgrade("forking_roots")
 var quick := Catalog.get_upgrade("quickroot")
 p.frame=0;p.weapon_kind=0;p.weapon=game.Parts.THORN;p.secondary=0;p.catalyst=0;p[game.ExpeditionWallet.STATE] = game.ExpeditionWallet.Wallet.new(game.wallet_for(p).earned_sparks())
 check(Catalog.weight(fork,p,6)==0 and Catalog.weight(quick,p,6)>0,"Core secondary piercing does not qualify as Form")
 p.secondary=game.Parts.index_of("plant:cinder_vine")
 check(Catalog.weight(fork,p,6)>0,"Thorn Core and piercing Form qualify")
 var seed_value:=0
 while "forking_roots" not in Catalog.roll(p,6,seed_value,12) and seed_value<64: seed_value+=1
 p.upgrade_seed=seed_value
 gate(game,p,6)
 var offers: Array=game.checkpoint_offer_ids(p).duplicate()
 check(offers[0] in ["forking_roots","quickroot"] and offers.has("forking_roots"),"an affordable compatible Core card gets first pick")
 var fork_index := offers.find("forking_roots")
 if fork_index<0: return
 var card: Dictionary=game.checkpoint_card_data(p)[fork_index]
 check(card.enabled and card.description.contains("Piercing Form") and card.description.contains("nearby enemy"),"text card explains its behavior")
 p.secondary=0
 check(not game.buy_upgrade(1,p,fork_index) and game.wallet_for(p).spent_essence()==0 and game.checkpoint_offer_ids(p)==offers,"live slot change invalidates cached offer without reroll or spend")
 p.secondary=game.Parts.index_of("plant:cinder_vine")
 check(game.buy_upgrade(1,p,fork_index) and game.wallet_for(p).spent_essence()==int(fork.cost),"Forking Roots purchase spends the owner's essence")
 check(Catalog.weight(fork,p,9)==0 and not game.buy_upgrade(1,p,fork_index),"bounded card can only be acquired once")
 gate(game,p,9)
 offers=game.checkpoint_offer_ids(p)
 check(offers[0]=="quickroot" and game.buy_upgrade(1,p,0) and game.wallet_for(p).spent_essence()==int(fork.cost)+int(quick.cost),"the next gate prioritizes the available timing card")
 check(Catalog.core_behaviors(p,"thorn_line")==["thorn_fork","thorn_rebate"],"purchased behavior IDs are independent of card order")

 game.battlefield.configure(0,9,0)
 game.battlefield.barriers.clear()
 game.enemy_hp=20;game.enemy_kind=0;game.enemy_mutations=0
 p.pos=Vector3.ZERO;p.core_ready_at=0;p.core_cast_until=0;p.cast_until=0
 p.secondary=0
 game.enemy_pos=Vector3(0,0,-3.22)
 game.scouts.assign([game.make_scout(0,Vector3(0,0,-4.05),1),game.make_scout(0,Vector3(.8,0,-4.3),2)])
 game.garden_action(1,Core.request(game,p,Vector2(0,-1)))
 var line: Dictionary=game.get_meta(Core.STATE,{}).get(1,{})
 check(not line.is_empty(),"purchased effects follow a valid Thorn Line cast")
 if line.is_empty(): return
 var original_ready: int=p.core_ready_at
 Core.tick(game,line.armed)
 game.enemy_pos=line.center
 Core.tick(game,line.armed+60)
 check(game.rooted_until==0 and int(game.scouts[0].rooted_until)>line.armed and int(game.scouts[1].rooted_until)==0,"Forking Roots takes one nearby target and cannot chain again")
 check(Core.hints(game).size()==1 and p.core_ready_at==original_ready-3000,"first contact refunds three seconds once and leaves the line active")
 Core.tick(game,line.armed+100)
 check(p.core_ready_at==original_ready-3000,"extra simulation ticks cannot refund again")
 check(game.combat_events.any(func(e):return e.kind=="link" and e.shape=="Forking Roots") and game.combat_events.any(func(e):return e.kind=="proc" and e.shape=="Quickroot"),"both behaviors have readable combat events")
 Core.tick(game,line.expires)
 p.core_ready_at=0;p.core_cast_until=0;p.cast_until=0
 game.enemy_pos=Vector3(0,0,-3.22)
 game.garden_action(1,Core.request(game,p,Vector2(0,-1)))
 line=game.get_meta(Core.STATE,{}).get(1,{})
 check(not line.is_empty(),"a second cast can be tested after cooldown")
 if line.is_empty(): return
 original_ready=p.core_ready_at
 Core.tick(game,line.armed)
 game.enemy_pos=line.center
 Core.tick(game,line.armed+2001)
 check(p.core_ready_at==original_ready,"late trips do not refund the timer")
 game.return_to_garden(p)
 check(Catalog.core_behaviors(p,"thorn_line").is_empty(),"expedition ends the purchased behaviors")
