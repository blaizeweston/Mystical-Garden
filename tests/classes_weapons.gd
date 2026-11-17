extends SceneTree
const ExpeditionCase=preload("res://tests/support/expedition_case.gd")
const Catalog=preload("res://class_catalog.gd")
const Build=preload("res://affinity_build.gd")
const Character=preload("res://character_profile.gd")
const Grafts=preload("res://expedition_grafts.gd")
var failed:=false
func check(ok: bool,message: String) -> void:
	if not ok:failed=true;printerr("FAIL classes: ",message)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var game: Node=load("res://world.tscn").instantiate()
	var token=Crypto.new().generate_random_bytes(8).hex_encode()
	game.progress.path="res://.godot/classes-modern-"+token+".cfg"
	game.local_character.path=game.progress.path+".character"
	root.add_child(game);game.set_process(false);game.set_physics_process(false)
	var player: Dictionary=game.players[1]
	var names: Dictionary={}
	for class_id in Catalog.DEFINITIONS.size():
		var graph=Catalog.connected_tree(class_id)
		check(Catalog.DEFINITIONS[class_id].weapons.size()==3 and graph.nodes.size()==18,"three weapons and six connected selection tiers per class")
		for weapon in 3:
			var definition: Dictionary=Catalog.DEFINITIONS[class_id].weapons[weapon]
			names[definition.id]=true
			var model: Node3D=preload("res://weapon_visuals.gd").build(game.stage,class_id,weapon)
			check(model.get_child_count()>0,"weapon model "+definition.name);model.free()
		player.pos=game.Stage.HEART
		player.character=Character.blank()
		player.character.xp[class_id]=2600
		game.select_class(1,player,class_id)
		for tier in 6:
			game.handle_loadout_action(1,player,"learn_%d_%d"%[class_id,graph.REQUEST_OFFSET+tier*3])
			check(graph.path(player.character).size()==tier+1,"host accepts one earned connected choice")
			var selected: Array=graph.path(player.character).duplicate()
			game.handle_loadout_action(1,player,"learn_%d_%d"%[class_id,graph.REQUEST_OFFSET+tier*3+1])
			check(graph.path(player.character)==selected,"one choice per tier excludes the alternative")
		check(Character.normalize(player.character)==player.character,"versioned connected choices survive normalization")
		game.handle_loadout_action(1,player,"respec_%d"%class_id)
		check(graph.path(player.character).is_empty() and player.character.xp[class_id]==2600,"Heart respec preserves earned Class XP")
	check(names.size()==15,"fifteen distinct native weapons")
	var historical:=Character.normalize({"xp":[12,7],"plants":[4,5,6],"monsters":[2,3],"traits":[1,2]})
	check(historical.xp.slice(0,2)==[120,70] and historical.monsters.slice(0,2)==[2,3] and historical.loadouts.size()==5,"historical profile data converts without loss")
	player.pos=game.Stage.HEART
	player.character=Character.blank()
	game.select_class(1,player,2)
	game.handle_loadout_action(1,player,"learn_2_64")
	var native:=Build.native_stats(Build.for_player(player))
	for slot in 3:
		var parts: Array=[0,0,0];parts[slot]=game.Parts.THORN
		var stats:=Build.native_stats(Build.resolve(2,0,parts,player.character))
		check(stats.damage==native.damage and stats.reach==native.reach and stats.interval==native.interval,"plant slots preserve native weapon properties")
	player.prepared=1;player.prepared_secondary=1;player.prepared_catalyst=1
	player.pos=game.Stage.GATE
	game.progress.parts.fill(0);game.progress.personal_parts.fill(0);game.progress.parts[0]=1
	ExpeditionCase.Transitions.enter(game,1,player)
	check(not ExpeditionCase.is_wild(player) and game.progress.parts[0]==1,"duplicate plant slots require combined material quantity")
	game.progress.parts[0]=3
	game.progress.personal_parts[game.Parts.HOOK]=2
	player.cargo_plan[game.Parts.HOOK]=2
	ExpeditionCase.Transitions.enter(game,1,player)
	check(ExpeditionCase.is_wild(player) and game.progress.parts[0]==0 and [player.weapon,player.secondary,player.catalyst]==[1,1,1],"three slots reserve and consume three real materials")
	check(player.carried_parts[game.Parts.HOOK]==2 and Grafts.active_ledger(player)!=null and not player.has("graft_part"),"monster cargo enters a cumulative run with no installed slot")
	ExpeditionCase.Transitions.return_member(game,player)
	check(Grafts.active_ledger(player)==null and player.carried_parts[game.Parts.HOOK]==0,"departure clears cumulative acquisitions and unbanked cargo")
	game.free();await process_frame
	if not failed:print("PASS: five connected classes, fifteen weapon models, explicit plant slots, profile conversion, respec and material reservations")
	quit(int(failed))
