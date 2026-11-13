extends SceneTree
var failed:=false
func check(ok: bool,message: String) -> void:
 if not ok: failed=true;printerr("FAIL species depth: ",message)
func _initialize() -> void: call_deferred("run")
func arena(game: Node,p: Dictionary) -> void:
 game.enemy_traits.clear();game.trait_events.clear();game.scouts.clear();game.enemy_hp=100;game.enemy_pos=Vector3.ZERO;game.enemy_mutations=0;game.enemy_winding_up=false;game.enemy_stagger_until=0
 game.battlefield.procedural=false;game.battlefield.barriers=[];game.encounter_number=1;game.depth=1;game.destination=0;p.wild=true;p.fallen=false;p.pos=Vector3(0,0,-1);p.weapon=0;p.secondary=0;p.catalyst=0;p.graft_part=0;p.run_upgrades={};p.power=0;p.hp=5;p.max_hp=10
 for key in ["echo_charge","grave_charges","tide_ready","decoy_ready","link_ready","counter_until"]: p[key]=0
func run() -> void:
 var game=load("res://world.tscn").instantiate();game.progress.path="res://.godot/species-depth-"+str(Time.get_ticks_usec())+".cfg";game.local_character.path=game.progress.path+".character";root.add_child(game);game.set_process(false);game.set_physics_process(false)
 var p: Dictionary=game.players[1]
 check(game.Seeds.DEFINITIONS.size()==24,"exactly 24 species")
 for i in range(15,24):
  var d: Dictionary=game.Seeds.DEFINITIONS[i];var part:=int(d.part)
  check(game.Parts.plant_source(part)==i and game.Parts.rare_part(i)>0,"ordinary and refined mapping "+d.id)
  for slot in 3:
   var slots: Array=[0,0,0];slots[slot]=part
   var stats: Dictionary=game.Weapons.resolve(0,0,slots,0,0,p.character)
   check(not game.Traits.describe(stats).is_empty(),"behavior works in each slot "+d.id)
  for growth in 4:
   var crop=game.stage.build_crop(i,growth,false);check(crop.get_child_count()>0,"growth model "+d.id);crop.free()
  var a:=int(d.parents[0]);var b:=int(d.parents[1])
  check(game.Seeds.recipe(b,a)==i,"tiered crossbreeding route "+d.id)
  check(not game.Altar.Recipes.find("parts",game.Items.part_id(part),game.Items.part_id(part)).is_empty(),"material refinement route "+d.id)
 # Mark setup: the first hit marks; only subsequent contacts exploit it.
 arena(game,p);p.weapon=game.Seeds.DEFINITIONS[17].part
 var stats: Dictionary=game.weapon_stats(p);game.apply_weapon_hit(p,-1,p.pos,stats,1000);var first: int=100-game.enemy_hp;var hp: int=game.enemy_hp;game.apply_weapon_hit(p,-1,p.pos,stats,1100)
 check(hp-game.enemy_hp>first,"Whispervine needs setup before bonus damage")
 # Echo is bounded and secondary contacts do not generate more echoes.
 arena(game,p);p.weapon=game.Seeds.DEFINITIONS[18].part;stats=game.weapon_stats(p)
 for i in 3:game.apply_weapon_hit(p,-1,p.pos,stats,1000+i*100)
 check(game.trait_events.size()==1,"Mirror Mint queues one echo")
 hp=game.enemy_hp;game.Traits.tick(game,1600);check(game.enemy_hp<hp and game.trait_events.is_empty(),"echo deals damage once without recursion")
 arena(game,p);p.weapon=game.Seeds.DEFINITIONS[19].part;stats=game.weapon_stats(p);game.enemy_hp=1
 game.apply_weapon_hit(p,-1,p.pos,stats,1000);check(p.grave_charges>0,"Gravemoss stores a death charge")
 game.enemy_hp=100;hp=p.grave_charges;game.apply_weapon_hit(p,-1,p.pos,stats,1100);check(p.grave_charges==hp-1,"death charge is consumed on a later hit")
 arena(game,p);p.weapon=game.Seeds.DEFINITIONS[20].part;stats=game.weapon_stats(p);game.apply_weapon_hit(p,-1,p.pos,stats,1000);p.slow_until=2000
 game.Traits.tick(game,1100);check(p.hp>5 and p.slow_until==0,"Tide Lily pool heals and cleanses living player")
 arena(game,p);p.weapon=game.Seeds.DEFINITIONS[21].part;stats=game.weapon_stats(p);game.enemy_winding_up=true
 game.apply_weapon_hit(p,-1,p.pos,stats,1000);check(not game.enemy_winding_up,"Hush Orchid interrupts a timed wind-up")
 game.enemy_winding_up=true;game.apply_weapon_hit(p,-1,p.pos,stats,1100);check(game.enemy_winding_up,"same enemy resists immediate repeated silence")
 arena(game,p);p.weapon=game.Seeds.DEFINITIONS[22].part;stats=game.weapon_stats(p);var now:=Time.get_ticks_msec();game.apply_weapon_hit(p,-1,p.pos,stats,now)
 check(game.Traits.decoy_point(game,1)!=Vector3.INF and game.Director.predict(game,1,0)!=p.pos,"Dream Poppy diverts enemy pursuit to a decoy")
 arena(game,p);p.weapon=game.Seeds.DEFINITIONS[23].part;p.secondary=game.Seeds.DEFINITIONS[15].part;stats=game.weapon_stats(p)
 game.scouts.append(game.make_scout(0,Vector3(.5,0,.2),0));game.scouts[0].hp=20
 game.apply_weapon_hit(p,-1,p.pos,stats,1000);game.Traits.tick(game,1300)
 check(game.scouts[0].hp<20 and game.scouts[0].get("traits",{}).get("brittle",0)>0,"Crownroot links reduced damage and carries brittle once")
 arena(game,p);p.weapon=game.Seeds.DEFINITIONS[16].part;p.still_since=1000;stats=game.weapon_stats(p)
 hp=game.enemy_hp;game.apply_weapon_hit(p,-1,p.pos,stats,1800);check(hp-game.enemy_hp>int(stats.damage),"Ironroot rewards braced impact")
 check(game.Traits.try_brace(game,p,2000) and not game.Traits.try_brace(game,p,2100),"brace blocks once, then recovers")
 check(load("res://content_validator.gd").validate().is_empty(),"all content validates")
 game.queue_free();await process_frame
 if not failed:print("PASS: 24 species, all slot behaviors, growth, refinement and actual authored combat effects")
 quit(1 if failed else 0)
