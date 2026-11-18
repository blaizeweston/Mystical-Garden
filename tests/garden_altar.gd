extends SceneTree
const UIFixture = preload("res://tests/support/gameplay_ui_case.gd")

const ExpeditionCase = preload("res://tests/support/expedition_case.gd")
const Service=preload("res://altar_service.gd")
const Recipes=preload("res://altar_recipes.gd")
const Items=preload("res://item_catalog.gd")
var failed:=false
func check(ok: bool,message: String):
 if not ok: failed=true;printerr("FAIL Garden altar: ",message)
func _initialize(): call_deferred("run")
func pair(first: String,second: String,source: String="stash") -> Array:
 return [{"item":first,"source":source},{"item":second,"source":source}]
func run():
 var game=load("res://world.tscn").instantiate()
 var token=Crypto.new().generate_random_bytes(8).hex_encode()
 game.progress.path="res://.godot/altar_test_"+token+".cfg";game.local_character.path=game.progress.path+".character"
 root.add_child(game);game.set_process(false);game.set_physics_process(false)
 var g=game.progress;var p: Dictionary=game.players[1];var reserve: Dictionary=game.seed_reserve(p)
 p.pos=game.Stage.ALTAR;reserve.stock[0]=5;reserve.stock[1]=5;reserve.parts[1]=5;reserve.parts[2]=5
 game.send_action(false)
 check(UIFixture.control(game,"altar_menu").visible and reserve.stock[0]==5,"E opens altar without identifying, crafting or spending")
 var seeds:=pair(Items.seed_id(0),Items.seed_id(1))
 var preview:=Service.preview(game,p,seeds)
 check(preview.can_combine and not preview.known and preview.item=="","unknown result is a concealed question mark")
 var before_knowledge: int=g.knowledge
 var outcome:=Service.combine(game,p,seeds)
 check(outcome.contains("Discovered") and reserve.stock[0]==4 and reserve.stock[1]==4 and reserve.stock[2]==1 and g.discoveries[2] and g.knowledge==before_knowledge+4,"seed sacrifice consumes one per slot and discovers a higher plant")
 check(Service.preview(game,p,seeds).known and Service.preview(game,p,seeds).item==Items.seed_id(2),"known seed result replaces question mark")
 var reverse: Array=[seeds[1],seeds[0]]
 check(Service.preview(game,p,reverse).item==Items.seed_id(2),"recipe order does not matter")
 Service.combine(game,p,reverse)
 check(g.knowledge==before_knowledge+4 and reserve.stock[2]==2,"repeat recipe grants output without farming discovery Knowledge")
 var parts:=pair(Items.part_id(1),Items.part_id(2))
 preview=Service.preview(game,p,parts)
 check(not preview.known,"part recipe discovery is distinct from seed recipe")
 Service.combine(game,p,parts)
 check(reserve.parts[1]==4 and reserve.parts[2]==4 and reserve.parts[3]==1,"plant materials combine into the higher-lineage crafting part")
 check(Items.RARITIES.find(Items.get_item(Items.part_id(3)).rarity)>Items.RARITIES.find(Items.get_item(Items.part_id(1)).rarity),"part outcome is a higher rarity")
 check(reserve.stock[2]==2,"part sacrifice does not create a seed")
 check(Service.preview(game,p,parts).known,"successful material recipe is remembered")
 # A same-species unknown pair consumes two, returns one material and records the salvage preview.
 var duplicate:=pair(Items.seed_id(0),Items.seed_id(0))
 var old_parts: int=reserve.parts[1];var old_seeds: int=reserve.stock[0]
 outcome=Service.combine(game,p,duplicate)
 check(outcome.contains("Clue:") and reserve.stock[0]==old_seeds-2 and reserve.parts[1]==old_parts+1,"failed seed offering returns partial material and a clue")
 check(Service.preview(game,p,duplicate).known and Service.preview(game,p,duplicate).item==Items.part_id(1),"failed combinations remember their salvage result")
 reserve.stock[0]=1
 var before: int=reserve.stock[0]
 Service.combine(game,p,duplicate)
 check(reserve.stock[0]==before,"one seed cannot fill two consumed slots")
 var mixed:=pair(Items.seed_id(0),Items.part_id(2))
 check(not Service.preview(game,p,mixed).can_combine,"mixed seed/material offerings are rejected")
 var monster:=pair(Items.part_id(4),Items.part_id(2))
 check(Service.clean_draft(monster)[0].is_empty(),"monster components cannot enter Garden plant experiments")
 # Shared and personal parts can form an offering, with one result owned by the player.
 g.parts[0]=2
 var mixed_ownership: Array=[{"item":Items.part_id(1),"source":"shared"},{"item":Items.part_id(2),"source":"stash"}]
 old_parts=reserve.parts[3]
 Service.combine(game,p,mixed_ownership)
 check(g.parts[0]==1 and reserve.parts[3]==old_parts+1,"shared and personal inputs are accounted separately")
 # A material discovery does not silently unlock its seed, even after moving it to shared storage.
 var parent_part:=int(Items.Seeds.DEFINITIONS[3].part)
 var result_part:=int(Items.Seeds.DEFINITIONS[4].part)
 reserve.parts[parent_part]=2
 Service.combine(game,p,pair(Items.part_id(1),Items.part_id(parent_part)))
 check(reserve.parts[result_part]==1 and reserve.stock[4]==0 and not g.discoveries[4],"higher material discovery is separate from seed discovery")
 game.InventoryModel.transfer(game,p,"stash","shared",Items.part_id(result_part),1)
 var separate=load("res://progress.gd").new();separate.path=g.path;separate.load_garden()
 check(not separate.discoveries[4],"shared material storage does not unlock its plant species on reload")
 # Save failure restores ingredients, output, discoveries, recipe book and Knowledge.
 var saved_path: String=g.path
 reserve.stock[0]=3;reserve.stock[3]=3
 var novel:=pair(Items.seed_id(0),Items.seed_id(3))
 var captured:=Service.capture(game,p)
 g.path="res://.godot/absent-altar-dir/garden.cfg"
 outcome=Service.combine(game,p,novel)
 check(outcome.contains("returned") and Service.capture(game,p)==captured,"failed save rolls the complete offering back")
 g.path=saved_path
 reserve.unknown.append(4)
 var unknown_before: int=reserve.unknown.size()
 Service.identify(game,p)
 check(reserve.unknown.size()==unknown_before-1 and reserve.stock[4]==1,"explicit identification is still available from altar")
 ExpeditionCase.set_membership(game, p, true)
 captured=Service.capture(game,p);Service.combine(game,p,parts)
 check(Service.capture(game,p)==captured,"Wilds request cannot use Garden altar")
 ExpeditionCase.set_membership(game, p, false);p.pos=game.Stage.GATE
 Service.combine(game,p,parts)
 check(Service.capture(game,p)==captured,"remote altar request fails range validation")
 p.pos=game.Stage.ALTAR
 g.save_garden()
 var reload=load("res://progress.gd").new();reload.path=g.path;reload.load_garden()
 check(reload.altar_recipes==g.altar_recipes,"recipe book persists in Garden save")
 var legacy=ConfigFile.new();legacy.load(g.path);legacy.erase_section("altar")
 var legacy_path: String=g.path+".legacy";legacy.save(legacy_path)
 var migrated=load("res://progress.gd").new();migrated.path=legacy_path;migrated.load_garden();migrated.save_garden()
 check(FileAccess.file_exists(legacy_path+".pre-altar-v1.bak") and not migrated.altar_recipes.is_empty(),"legacy attempts migrate with an altar recovery backup")
 for recipe in Recipes.all():
  if recipe.mode!="parts": continue
  var result_rarity:=Items.RARITIES.find(Items.get_item(recipe.output).rarity)
  for input in recipe.inputs: check(result_rarity>Items.RARITIES.find(Items.get_item(input).rarity) or (result_rarity==4 and Items.get_item(input).rarity=="Mythic" and recipe.output!=input),"material recipes improve rarity or capped Mythic quality")
 game.free()
 if not failed: print("PASS: interactive altar, seed and material recipes, concealed/known previews, higher rarities, partial salvage, repeat costs, ownership, save rollback, identification and recipe persistence")
 quit(1 if failed else 0)
