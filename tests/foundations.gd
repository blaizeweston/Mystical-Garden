extends SceneTree

const ExpeditionCase = preload("res://tests/support/expedition_case.gd")
const IDs=preload("res://content_ids.gd")
const Batch=preload("res://save_batch.gd")
const Grafts=preload("res://expedition_grafts.gd")
var failed:=false
func check(ok: bool,message: String):
 if not ok: failed=true;printerr("FAIL foundations: ",message)
func _initialize(): call_deferred("run")
func run():
 var game=load("res://world.tscn").instantiate();var token=Crypto.new().generate_random_bytes(8).hex_encode()
 game.progress.path="res://.godot/foundations_"+token+".cfg";game.local_character.path=game.progress.path+".character";root.add_child(game);game.set_process(false);game.set_physics_process(false)
 var g=game.progress;var p: Dictionary=game.players[1];var reserve: Dictionary=game.seed_reserve(p)
 check(game.Parts.DEFINITIONS[18].id=="monster:nightbloom" and game.Parts.DEFINITIONS[26].id=="monster:broodmother","published part indices remain frozen")
 g.parts[0]=7;g.add_parts(999,1);check(g.part_count(999)==0 and g.parts[0]==7 and game.Seeds.species_for_part(999)==-1,"unknown part IDs cannot alias a valid resource")
 var manifest:=IDs.manifest();var moved:=manifest.duplicate(true);moved.parts.reverse();moved.seeds.reverse()
 var file:=ConfigFile.new();file.set_value("content","manifest",moved)
 var counts: Array=[];counts.resize(moved.parts.size());counts.fill(0);counts[moved.parts.find("monster:nightbloom")]=11
 file.set_value("garden","personal_parts",counts);file.set_value("garden","stock_"+str(moved.seeds.find("thorn_bloom")),9)
 IDs.remap_garden(file)
 check(file.get_value("garden","personal_parts")[18]==11 and file.get_value("garden","stock_0")==9,"stable IDs survive reordered content indices")
 check(game.Enemies.decode(game.Enemies.encode(300,31,2)).kind==300,"enemy protocol no longer aliases enemy 16")
 var old: Dictionary=game.Character.blank();old.xp[0]=20;old.erase(game.Character.Experience.VERSION_KEY)
 var migrated: Dictionary=game.Character.normalize(IDs.profile(old,IDs.legacy()))
 check(game.Character.level(migrated.xp[0])==5,"legacy class level remains earned under new pacing")
 for species in game.Seeds.DEFINITIONS.size(): check(game.Parts.rare_part(species)>0,"every species has a rare harvest component")
 # Inject a failed cross-file harvest: crop, shared yield and profile must all roll back.
 p.pos=game.Stage.PLOTS[0];g.plots[0]={"species":0,"age":80.,"stage":3,"flowering":false};var fam: int=p.character.plants[0];var before: int=g.parts[0]
 var path: String=g.path;g.path="res://.godot/missing-foundations-directory/fail.cfg";game.harvest(1,0)
 check(g.plots[0].species==0 and g.parts[0]==before and p.character.plants[0]==fam,"failed harvest restores crop, yield and character familiarity together")
 g.path=path
 # Interrupted multi-file commit restores both files before reading either one.
 var a: String=path+".a";var b: String=path+".b";Batch.write_bytes(a,"old-a".to_utf8_buffer());Batch.write_bytes(b,"old-b".to_utf8_buffer())
 var journal:=ConfigFile.new();journal.set_value("transaction","entries",{a:{"exists":true,"bytes":"old-a".to_utf8_buffer()},b:{"exists":true,"bytes":"old-b".to_utf8_buffer()}});journal.set_value("transaction","committed",false);journal.save(a+".transaction")
 Batch.write_bytes(b+".txn_link",(a+".transaction").to_utf8_buffer());Batch.write_bytes(a,"new-a".to_utf8_buffer())
 check(Batch.recover(b)==OK and FileAccess.get_file_as_string(a)=="old-a" and FileAccess.get_file_as_string(b)=="old-b","interrupted commit recovers a consistent pair")
 # An actual killed stag supplies its own familiarity and reward; no item injection.
 var tree=game.Classes.connected_tree(0)
 p.character[tree.profile_key]=tree.state(["vanguard"])
 ExpeditionCase.set_membership(game, p, true);p.pos=Vector3(0,0,4);p.frame=0;p.weapon_kind=0;p.weapon=0;p.secondary=0;p.catalyst=0;p.strike_at=0;p.contributed=false;p.character.monsters.fill(0)
 ExpeditionCase.set_world(game, {"destination": 0});ExpeditionCase.set_world(game, {"encounter_number": 3});ExpeditionCase.set_world(game, {"map_seed": 0});game.battlefield.configure(0,1);game.battlefield.barriers=[];game.encounter.set_hp(-1, 0);game.enemy_kind=0;game.encounter_rewarded=false;game.encounter_kills.clear()
 var stag: Dictionary=game.make_scout(2,Vector3(0,0,5),1);stag.hp=1;game.encounter.clear_scouts();game.encounter.register_scout(stag)
 # Choose a deterministic successful per-kill roll before the actual kill.
 for seed_value in 1000:
  game.rng.seed=seed_value
  if not game.roll_kill_trophy(2).is_empty():game.rng.seed=seed_value;break
 game.strike_enemy(1,p,p.pos);check(game.encounter.hp(0)==1,"melee damage waits for its contact window");game.update_projectiles(Time.get_ticks_msec()+1000)
 check(game.encounter.hp(0)==0 and p.character.monsters[2]==1 and p.character.monsters[0]==0,"real stag kill credits stag familiarity")
 var personal=game.inventory_floor_snapshot(p)
 check(personal.size()==1,"the killed stag creates one personal trophy pickup")
 p.pos=stag.pos;game.pickup_inventory_drop(1,p,personal[0].id);var antler: int=game.Parts.monster_part(2)
 check(p.carried_parts[antler]==1,"individual stag reward grants the killed species component")
 game.encounter.set_hp(-1, 0);game.encounter.clear_scouts();ExpeditionCase.set_world(game, {"encounter_number": 6});p.pos=game.battlefield.advance;ExpeditionCase.Transitions.checkpoint(game, 1,false)
 check(not ExpeditionCase.is_wild(p) and reserve.parts[antler]==1,"earned trophy survives extraction")
 p.pos=game.Stage.GATE;p.cargo_plan[antler]=1;ExpeditionCase.Transitions.enter(game, 1,p);check(ExpeditionCase.is_wild(p) and p.carried_parts[antler]==1,"stash trophy can be packed into next expedition")
 ExpeditionCase.set_world(game, {"encounter_number": 8});p.pos=game.battlefield.graft
 var graft_offer: Dictionary=Grafts.owner_details(p,game.participation.floor())
 game.send_garden_action(Grafts.request(graft_offer,"strike",game.Items.part_id(antler)))
 var improvements: Dictionary=Grafts.owner_details(p,game.participation.floor())
 check(p.carried_parts[antler]==0 and improvements.copies.size()==1 and improvements.copies[0].id=="strike","earned trophy funds one cumulative reinforcement at a Wilds altar")
 # Exact research plan rejects inadequate selected species without consuming another.
 g.parts.fill(0);g.parts[0]=4;g.parts[1]=5;g.heart.material_choice="lantern_moss";check(g.heart.spend_materials(g,3) and g.parts[0]==4 and g.parts[1]==2,"research spends the explicitly selected species")
 check(not g.heart.spend_materials(g,3) and g.parts[0]==4 and g.parts[1]==2,"research cannot silently substitute ingredients")
 # Complete a non-Thorn cultivation -> rare component -> weapon path.
 ExpeditionCase.set_membership(game, p, false);p.pos=game.Stage.ALTAR;reserve.unknown.assign([1]);reserve.stock.fill(0);game.Altar.identify_all(game,p)
 g.plots[0]=game.Progress.empty_plot();p.pos=game.Stage.PLOTS[0];game.act(1,false);game.garden_action(1,"plant_at_0_1");g.advance_growth(86400.)
 var rare_part: int=game.Parts.rare_part(1);var rare_before: int=g.part_count(rare_part)
 for seed_value in 1000:
  game.rng.seed=seed_value
  if game.rng.randf()<game.rare_harvest_chance(p.character.plants[1]): game.rng.seed=seed_value;break
 game.harvest(1,0);check(g.part_count(rare_part)==rare_before+1,"non-Thorn plant can naturally yield its refined material")
 p.pos=game.Stage.GATE;p.prepared=rare_part;p.prepared_secondary=0;p.prepared_catalyst=0;ExpeditionCase.Transitions.enter(game, 1,p)
 check(ExpeditionCase.is_wild(p) and p.weapon==rare_part and g.part_count(rare_part)==rare_before,"refined harvest component can craft an expedition weapon")
 check(not game.Items.register({"id":"invalid_component","name":"Invalid","category":"plant_part"}),"orphan component definitions are rejected")
 if not failed: print("PASS: stable identity migration, unknown IDs, legacy progression, every-species harvest templates, transaction rollback, crash recovery and earned stag-to-cumulative-reinforcement pipeline")
 game.queue_free();await process_frame;quit(1 if failed else 0)

