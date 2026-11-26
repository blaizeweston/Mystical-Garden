extends SceneTree
const UIFixture = preload("res://tests/support/gameplay_ui_case.gd")

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
	call_deferred("run")
func ingredients(a: int,b: int) -> Array:
	var items=preload("res://item_catalog.gd")
	return [{"source":"stash","item":items.seed_id(a)},{"source":"stash","item":items.seed_id(b)}]
func verify_closure(game: Node) -> void:
	var available: Array=[]
	var recipes: Array=game.Altar.Recipes.all().filter(func(r):return r.mode=="seeds")
	check(recipes.size()==16,"sixteen active seed recipes")
	for step in [["thorn_bloom",0],["lantern_moss",5],["ember_fern",15],["moon_lotus",17],["mirror_mint",19],["star_orchid",21],["sun_spire",23],["crownroot",24]]:
		available.append("seed_"+str(step[0]))
		var previous := -1
		while previous!=available.size():
			previous=available.size()
			for recipe in recipes:
				if available.has(recipe.inputs[0]) and available.has(recipe.inputs[1]) and not available.has(recipe.output): available.append(recipe.output)
		if step[1]>0: check(available.size()==step[1],"reachable after "+str(step[0])+": "+str(available.size()))
	for plant in Seeds.DEFINITIONS:
		if plant.parents.is_empty(): continue
		var parents: Array=plant.parents
		check(game.Altar.Recipes.find("parts",game.Items.part_id(Seeds.DEFINITIONS[parents[0]].part),game.Items.part_id(Seeds.DEFINITIONS[parents[1]].part)).get("output","")==game.Items.part_id(plant.part),"material synthesis "+plant.id)
func run():
	var game=load("res://world.tscn").instantiate()
	var token=Crypto.new().generate_random_bytes(8).hex_encode()
	game.progress.path="res://.godot/seed_test_"+token+".cfg"
	game.local_character.path=game.progress.path+".character"
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	verify_closure(game)
	var g=game.progress
	var player: Dictionary=game.players[1]
	player.pos=game.stage.altar_position()
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
			if Seeds.wild_only(i):
				g.personal_parts[d.part]=game.reclamation_cost(i)
				var before_stock: Array=g.stock.duplicate()
				game._reclaim_seed(1,player,i,[])
				check(g.stock==before_stock and g.personal_parts[d.part]==game.reclamation_cost(i),"material alone cannot reclaim an undiscovered founder")
				var removed: Array=ingredients(a,b)
				var old_book: String=game.Altar.recipe_key(removed)
				g.altar_recipes[old_book]={"success":true,"item":game.Items.seed_id(i)}
				check(not game.Altar.preview(game,player,removed).known,"retired historical success cannot advertise a seed")
				game.Altar.combine(game,player,removed)
				check(g.altar_recipes[old_book].get("historical_success",false),"retrying a retired recipe preserves historical success in the Archive")
				check(g.stock[i]==0 and g.knowledge==knowledge and not g.altar_recipes[old_book].success,"disabled recipe only salvages")
				continue
			var outcome: String=game.Altar.combine(game,player,ingredients(b,a))
			check(not outcome.is_empty() and g.stock[i]==1 and g.stock[a]==0 and g.stock[b]==0,"reverse recipe consumes exactly parents "+d.name)
			check(g.discoveries[i] and g.knowledge==knowledge+6,"first recipe and permanent species discovery "+d.name)
			g.stock[a]=1
			g.stock[b]+=1
			knowledge=g.knowledge
			game.Altar.combine(game,player,ingredients(a,b))
			check(g.stock[i]==2 and g.knowledge==knowledge,"repeat recipe does not farm discovery knowledge")
	g.stock.fill(0)
	g.stock[0]=2
	var before: int=g.personal_parts[Seeds.DEFINITIONS[0].part]
	var outcome: String=game.Altar.combine(game,player,ingredients(0,0))
	check(outcome.contains("Clue:") and g.personal_parts[Seeds.DEFINITIONS[0].part]==before+1 and g.stock[0]==0,"failed sacrifice returns material and clue")
	var empty_before: Array=g.stock.duplicate()
	game.garden_action(1,"breed_0_1")
	check(g.stock==empty_before and not g.has_method("breed"),"retired command is harmless")
	var personal: Dictionary=g.reserve("")
	personal.stock.fill(10)
	var seen: Dictionary={}
	for depth_value in [1,3,8,18,35,60]:
		for n in 5000:
			var kind: int=g.roll_seed(personal,[],[],n%3,n/5000.0,depth_value)
			check(not Seeds.wild_only(kind) and int(Seeds.DEFINITIONS[kind].wild_min)<=depth_value,"loot obeys encounter gates")
			if depth_value==60: seen[kind]=true
	check(seen.size()==19,"all 19 open species can appear in caches")
	for i in Seeds.NAMES.size():
		var d: Dictionary=Seeds.DEFINITIONS[i]
		# Start each cultivation case with a genuinely identified seed.
		if Seeds.wild_only(i):
			player.pos=game.stage.altar_position()
			g.unknown.append(i)
			game.Altar.identify(game,player)
			var count: int=g.stock[i]
			game._reclaim_seed(1,player,i,[],game.reclamation_cost(i))
			check(g.stock[i]==count+1,"identified founder can be reclaimed")
		player.pos=game.Stage.PLOTS[0]
		ExpeditionCase.set_membership(game, player, false)
		player.seed_choice=i
		g.stock[i]=1
		g.plots[0]=Progress.empty_plot()
		game.cultivation.plant_seed(1,0)
		g.advance_growth(float(d.grow_seconds))
		before=g.part_count(d.part)
		game.cultivation.harvest(1,0)
		check(g.part_count(d.part)==before+1 and g.plots[0].species==-1,"all species harvest into correct crafting part "+d.name)
		check(player.character.plants[i]>0,"per-character familiarity "+d.name)
		if Seeds.wild_only(i):
			var shared: Dictionary=game.InventoryModel.reserve(game,player,"shared")
			var prior_shared:int=shared.stock[i]
			g.stock[i]=1

			game.cultivation.plant_seed(1,0)
			g.advance_growth(float(d.grow_seconds))
			game.cultivation.harvest_seeds(1,0)
			check(shared.stock[i]==prior_shared+2 and g.stock[i]==0 and g.plots[0].species==-1,"exclusive propagates into shared stock "+d.name)
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
	player.pos=game.stage.altar_position()
	g.stock[0]=1
	g.stock[3]=1
	game.send_altar_action("combine",ingredients(0,3),1)
	check(g.stock[4]>=1,"host validated UI breed action")
	game.ui.toggle_panel("progression")
	var panel=UIFixture.control(game,"progression_view")
	panel.refresh()
	check(panel.tree.nodes.size()==24,"generic tree receives all seed nodes")
	panel.select_node("14")
	check(panel.details.text.contains("Worldseed"),"discovered node reveals details")
	panel.tabs.current_tab=1
	panel.refresh()
	check(panel.research_tabs.tab_count==3 and panel.research_list.item_count==2,"Heart presents its two Garden Development purchases")
	panel.tabs.current_tab=2
	panel.refresh()
	check(panel.tree.nodes.size()==1+game.Classes.connected_tree(panel.inspected_class).nodes.size(),"same tree accepts selectable class choices")
	# Material identity affects its explicit affinity slot, never hidden species weapon passives.
	game.ui.close_panels()
	player.frame=0
	var tree=game.Classes.connected_tree(0)
	player.character[tree.profile_key]=tree.state(["vanguard"])
	player.weapon=0;player.secondary=0;player.catalyst=0
	var native: Dictionary=game.weapon_stats(player)
	var Builds=preload("res://affinity_build.gd")
	var Affinities=preload("res://plant_affinities.gd")
	for kind in [3,6,7,8,9,14]:
		player.weapon=Seeds.DEFINITIONS[kind].part
		var build: Dictionary=Builds.for_player(player)
		var identity: Dictionary=Affinities.for_part(player.weapon)
		var resolved: Dictionary=game.weapon_stats(player)
		check(build.core.executable and build.core.primary_affinity==identity.primary_affinity,"harvested material resolves to its approved Core family: "+Seeds.DEFINITIONS[kind].name)
		check(resolved.damage==native.damage and resolved.interval==native.interval and resolved.reach==native.reach,"Core identity cannot silently modify native basic attacks: "+Seeds.DEFINITIONS[kind].name)
	ExpeditionCase.set_membership(game, player, false)
	game._process(.016)
	check(game.inventory_snapshot(player)[6].size()==24 and game.garden_snapshot()[13].size()==24,"expanded network snapshots")
	if not failed: print("PASS: seed lineage graph, reversible recipes, sacrifice costs, first discoveries, all-tier Wilds loot, twenty-four crop/part mappings, familiarity, save migration and reusable trees")
	quit(1 if failed else 0)

