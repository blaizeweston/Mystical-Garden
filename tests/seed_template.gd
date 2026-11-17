extends SceneTree

const ExpeditionCase = preload("res://tests/support/expedition_case.gd")
var failed:=false
func check(ok: bool,message: String) -> void:
 if not ok: failed=true;printerr("FAIL seed template: ",message)
func _initialize() -> void:
 preload("res://combat_balance_preview.gd").enabled = false
 call_deferred("run")
func pair(a: String,b: String,source: String="stash") -> Array:
 return [{"item":a,"source":source},{"item":b,"source":source}]
func run() -> void:
 var game=load("res://world.tscn").instantiate();game.progress.path="res://.godot/seed-template-"+str(Time.get_ticks_usec())+".cfg";game.local_character.path=game.progress.path+".character";root.add_child(game);game.set_process(false);game.set_physics_process(false)
 var p: Dictionary=game.players[1];var g=game.progress;var reserve: Dictionary=game.seed_reserve(p)
 var i: int=game.Seeds.index_of("frostbell");var seed: Dictionary=game.Seeds.DEFINITIONS[i];var part:=int(seed.part)
 var frozen: Array=JSON.parse_string(FileAccess.get_file_as_string("res://assets/content/legacy_v2_part_order.json"))
 for slot in frozen.size(): check(game.Parts.DEFINITIONS[slot].id==frozen[slot],"historical component prefix "+str(slot))
 check(i==15 and part==44 and game.Parts.index_of("monster:root_shepherd")==41 and game.Parts.index_of("monster:lantern_lure")==43,"published species and component indices stay fixed")
 p.pos=game.Stage.ALTAR
 var a:=int(seed.parents[0]);var b:=int(seed.parents[1]);reserve.stock[a]=3;reserve.stock[b]=3
 var draft:=pair(game.Items.seed_id(a),game.Items.seed_id(b))
 check(not game.Altar.preview(game,p,draft).known,"altar conceals unknown child")
 game.Altar.combine(game,p,draft)
 check(reserve.stock[i]==1 and g.discoveries[i] and game.Altar.preview(game,p,draft).item==game.Items.seed_id(i),"altar discovers and remembers Frostbell")
 reserve.unknown.append(i);game.Altar.identify_all(game,p)
 check(reserve.stock[i]==2,"Wilds mystery seed identifies as correct species")
 reserve.stock[0]=1;reserve.stock[1]=maxi(1,int(reserve.stock[1])) # satisfy introductory seed guarantee
 var reachable:=false
 for roll in 2000:
  if g.roll_seed(reserve,[],[],1,roll/2000.0,60)==i: reachable=true
 check(reachable,"species participates in weighted Wilds discovery")
 p.seed_choice=i;p.pos=game.Stage.PLOTS[0];game.plant_seed(1,0)
 for age in [0.0,float(seed.grow_seconds)*.225,float(seed.grow_seconds)*.3375,float(seed.grow_seconds)*.4375]:
  g.advance_growth(age)
  var crop=game.stage.build_crop(i,g.plots[0].stage,false);check(crop.get_child_count()>0,"visible growth stage");crop.free()
 game.harvest(1,0)
 check(g.part_count(part)>=1 and g.plots[0].species==-1 and p.character.plants[i]>0,"harvest produces craftable part and personal familiarity")
 g.add_parts(part,2);p.pos=game.Stage.ALTAR
 var refine:=pair(game.Items.part_id(part),game.Items.part_id(part),"shared")
 game.Altar.combine(game,p,refine)
 check(reserve.parts[game.Parts.rare_part(i)]==1,"altar refines matching materials to rare-harvest counterpart")
 game.show_garden_altar(1)
 check(game.altar_view.recipe_pick.item_count>1,"altar offers remembered recipes")
 for index in range(1,game.altar_view.recipe_pick.item_count):
  var recorded: Dictionary=game.altar_view.recipe_pick.get_item_metadata(index)
  if recorded.output==game.Items.seed_id(i):
   game.altar_view.recipe_pick.item_selected.emit(index)
   check(game.altar_view.draft[0].item==game.Items.seed_id(a) and game.altar_view.draft[1].item==game.Items.seed_id(b),"recorded recipe selector populates both real sacrifice slots")
   break
 game.toggle_overlay(null)
 var nodes: Array=game.progression_view.seed_nodes(g.discoveries,g.stock)
 check(nodes.any(func(n):return n.id==str(i) and n.parents.size()==2 and n.icon!=null),"tree contains portrait and lineage connections")
 ExpeditionCase.set_membership(game, p, true);p.weapon=part;p.secondary=0;p.catalyst=0;p.pos=Vector3(0,0,-1);game.battlefield.procedural=false;game.battlefield.barriers=[];game.encounter.clear_scouts();game.tactics.position=Vector3.ZERO;game.encounter.set_hp(-1, 50)
 var stats: Dictionary=game.weapon_stats(p);var before: int=game.enemy_health()
 game.apply_weapon_hit(p,-1,p.pos,stats,1000);var first: int=before-game.enemy_health()
 game.apply_weapon_hit(p,-1,p.pos,stats,1100);before=game.enemy_health()
 game.apply_weapon_hit(p,-1,p.pos,stats,1200);var shatter: int=before-game.enemy_health()
 check(first==1 and shatter>first and game.enemy_traits.brittle==0,"three contacts produce actual shatter damage")
 check(game.RunUpgrades.requirement(game.RunUpgrades.get_upgrade("plant_frostbell_shatter"),p).is_empty(),"frost-only upgrade eligible from installed component")
 game.encounter.set_hp(-1, 0);ExpeditionCase.set_world(game, {"encounter_number": 6});p.pos=game.battlefield.advance;p[game.ExpeditionWallet.STATE] = game.ExpeditionWallet.Wallet.new(10000, game.wallet_for(p).spent_essence());p.offer_floor=6;p.checkpoint_offers=["plant_frostbell_shatter"]
 check(game._buy_upgrade(1,p,0) and game.weapon_stats(p).shatter_damage>stats.shatter_damage,"checkpoint card strengthens installed plant behavior")
 ExpeditionCase.set_membership(game, p, false);g.save_garden()
 var reload=load("res://progress.gd").new();reload.path=g.path;reload.load_garden()
 check(reload.discoveries[i] and reload.altar_recipes==g.altar_recipes,"discovery and recipes survive reload")
 check(load("res://content_validator.gd").validate().is_empty(),"catalog, effects, component IDs and portraits validate")
 game.queue_free();await process_frame
 if not failed: print("PASS: Frostbell template altar, Wilds acquisition, growth, parts, refinement, tree, real shatter, checkpoint upgrade and persistence")
 quit(1 if failed else 0)
