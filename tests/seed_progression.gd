extends SceneTree

const ExpeditionCase = preload("res://tests/support/expedition_case.gd")

const PlayerVitals = preload("res://player_vitals.gd")
const Seeds=preload("res://seed_catalog.gd")
const Progress=preload("res://progress.gd")
const Parts=preload("res://weapon_parts.gd")
const Character=preload("res://character_profile.gd")
var failed := false
func check(ok: bool,message: String) -> void:
	if not ok:
		failed=true
		printerr("FAIL seeds: ",message)
func _initialize():
	preload("res://combat_balance_preview.gd").enabled = false
	call_deferred("run")
func run():
	var game=load("res://world.tscn").instantiate()
	var token=Crypto.new().generate_random_bytes(8).hex_encode()
	game.progress.path="res://.godot/seed_test_"+token+".cfg"
	game.local_character.path=game.progress.path+".character"
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	var g=game.progress
	var player: Dictionary=game.players[1]
	for basic in [0,1,3]: g.discover(basic)
	check(Seeds.DEFINITIONS.size()==24 and Parts.DEFINITIONS.size()>=27,"complete stable registry")
	for i in Seeds.DEFINITIONS.size():
		var d: Dictionary=Seeds.DEFINITIONS[i]
		check(Parts.plant_source(d.part)==i,"part-to-species mapping "+d.name)
		if d.parents.size()==2:
			var a: int=d.parents[0]
			var b: int=d.parents[1]
			check(Seeds.DEFINITIONS[a].tier<d.tier and Seeds.DEFINITIONS[b].tier<d.tier,"acyclic tiered parent graph")
			g.stock.fill(0)
			g.stock[a]=1
			g.stock[b]+=1
			var knowledge: int=g.knowledge
			var outcome: String=g.breed(b,a,g.stock)
			check(not outcome.is_empty() and g.stock[i]==1 and g.stock[a]==0 and g.stock[b]==0,"reverse recipe consumes exactly parents "+d.name)
			check(g.discoveries[i] and g.knowledge==knowledge+4,"permanent first discovery "+d.name)
			g.stock[a]=1
			g.stock[b]+=1
			knowledge=g.knowledge
			g.breed(a,b,g.stock)
			check(g.stock[i]==2 and g.knowledge==knowledge,"repeat recipe does not farm discovery knowledge")
	g.stock.fill(0)
	g.stock[0]=2
	var before: int=g.parts[0]
	var outcome: String=g.breed(0,0,g.stock)
	check(outcome.contains("Clue:") and g.parts[0]==before+1 and g.stock[0]==0,"failed sacrifice returns material and clue")
	var empty_before: Array=g.stock.duplicate()
	check(g.breed(-1,999,g.stock).is_empty() and g.stock==empty_before,"invalid request is harmless")
	var personal: Dictionary=g.reserve("")
	personal.stock.fill(10)
	var seen: Dictionary={}
	for depth_value in [1,3,8,18,35,60]:
		for n in 5000:
			var kind: int=g.roll_seed(personal,[],[],n%3,n/5000.0,depth_value)
			check(int(Seeds.DEFINITIONS[kind].wild_min)<=depth_value,"loot obeys encounter gates")
			if depth_value==60: seen[kind]=true
	check(seen.size()==24,"every lineage can be found in the Wilds")
	for i in Seeds.NAMES.size():
		var d: Dictionary=Seeds.DEFINITIONS[i]
		player.pos=game.Stage.PLOTS[0]
		ExpeditionCase.set_membership(game, player, false)
		player.seed_choice=i
		g.stock[i]=1
		g.plots[0]=Progress.empty_plot()
		game.plant_seed(1,0)
		g.advance_growth(float(d.grow_seconds))
		before=g.part_count(d.part)
		game.harvest(1,0)
		check(g.part_count(d.part)==before+1 and g.plots[0].species==-1,"all species harvest into correct crafting part "+d.name)
		check(player.character.plants[i]>0,"per-character familiarity "+d.name)
		var crop: Node3D=game.stage.build_crop(i,3,false)
		check(crop.get_child_count()>0,"visible mature crop "+d.name)
		crop.queue_free()
	g.stock[14]=7
	g.unknown=[13,14]
	g.reserve("guest").stock[12]=3
	g.personal_parts[17]=4
	g.plots[0]={"species":14,"age":100.0,"stage":2,"flowering":true}
	check(g.save_garden()==OK,"save expanded progression")
	var reloaded=Progress.new()
	reloaded.path=g.path
	check(reloaded.load_garden()==OK and reloaded.stock[14]==7 and reloaded.unknown==[13,14] and reloaded.discoveries==g.discoveries and reloaded.reserve("guest").stock[12]==3 and reloaded.personal_parts[17]==4 and reloaded.plots[0].species==14,"round trip all expanded data")
	var old_profile: Dictionary=Character.normalize({"plants":[4,5,6]})
	check(old_profile.plants.size()==24 and old_profile.plants.slice(0,3)==[4,5,6] and old_profile.plants[14]==0,"legacy character migration")
	player.pos=game.Stage.ALTAR
	g.stock[0]=1
	g.stock[3]=1
	game.send_garden_action("breed_0_3")
	check(g.stock[4]>=1,"host validated UI breed action")
	game.toggle_overlay(game.progression_menu)
	var panel=game.progression_view
	panel.refresh()
	check(panel.tree.nodes.size()==24,"generic tree receives all seed nodes")
	panel.select_node("14")
	check(panel.details.text.contains("Worldseed"),"discovered node reveals details")
	panel.tabs.current_tab=1
	panel.refresh()
	check(panel.tree.nodes.size()==preload("res://heart_catalog.gd").DEFINITIONS.filter(func(n):return preload("res://heart_catalog.gd").enabled(n.id)).size(),"same tree accepts active Heart progression")
	panel.tabs.current_tab=2
	panel.refresh()
	check(panel.tree.nodes.size()==13,"same tree accepts selectable class choices")
	# Exercise actual host combat, rather than only checking catalog numbers.
	game.toggle_overlay(null)
	game.encounter.clear_scouts()
	game.battlefield.procedural=false
	game.battlefield.barriers=[]
	ExpeditionCase.set_world(game, {"destination": 0})
	ExpeditionCase.set_world(game, {"depth": 1})
	ExpeditionCase.set_membership(game, player, true)
	player.frame=0
	player.secondary=0
	player.technique=0
	player.power=0
	for kind in [3,7,8,9,14]:
		player.weapon=Seeds.DEFINITIONS[kind].part
		player.pos=Vector3(0,0,-1)
		player.strike_at=0
		game.tactics.position=Vector3.ZERO
		game.encounter.set_hp(-1, 20)
		game.enemy_mutations=0
		game.tactics.winding_up=kind==9
		game.tactics.recovery_bonus=0
		var now:=Time.get_ticks_msec()
		game.strike_enemy(1,player,player.pos)
		game.update_projectiles(Time.get_ticks_msec()+1000)
		if kind==3:
			check(game.enemy_health()==17 and player.strike_at-now>=560,"Ember Fern trades attack speed for real strike damage")
		if kind==7: check(game.tactics.recovery_bonus==850,"Ghost Fern applies real recovery modifier")
		if kind==8: check(game.tactics.position.z>0.9,"Storm Reed adds real knockback")
		if kind==9: check(game.enemy_health()==16,"Moon Lotus exploits real wind-up damage")
		if kind==14: check(game.tactics.stagger_until-now>=260,"Worldseed adds real hit stagger")
	player.weapon=Seeds.DEFINITIONS[6].part
	player.strike_at=0
	player[PlayerVitals.STATE] = player[PlayerVitals.STATE].with_hp(5)
	player.pos=Vector3(0,0,-1)
	game.tactics.position=Vector3.ZERO
	game.encounter.set_hp(-1, 1)
	game.tactics.winding_up=false
	game.strike_enemy(1,player,player.pos)
	game.update_projectiles(Time.get_ticks_msec()+1000)
	check(PlayerVitals.current_hp(player)==7,"Bloodbriar heals on a real killing strike")
	ExpeditionCase.set_membership(game, player, false)
	game._process(.016)
	check(game.inventory_snapshot(player)[6].size()==24 and game.garden_snapshot()[13].size()==24,"expanded network snapshots")
	if not failed: print("PASS: seed lineage graph, reversible recipes, sacrifice costs, first discoveries, all-tier Wilds loot, twenty-four crop/part mappings, familiarity, save migration and reusable trees")
	quit(1 if failed else 0)

