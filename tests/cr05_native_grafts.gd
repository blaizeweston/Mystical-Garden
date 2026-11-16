extends SceneTree

const Rules = preload("res://combat_ruleset.gd")
const Grafts = preload("res://native_grafts.gd")
const Frost = preload("res://frost_combat.gd")
const Parts = preload("res://weapon_parts.gd")
var game: Node
var player: Dictionary
var failed := false


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, label: String) -> void:
	if not ok:
		failed = true
		printerr("FAIL CR05 grafts: ",label)


func part(id: String) -> int:
	for index in Parts.DEFINITIONS.size():
		if Parts.DEFINITIONS[index].id == "monster:"+id: return index
	return 0


func at_altar(floor_number: int) -> void:
	game.encounter_number = floor_number
	player.pos = game.battlefield.graft


func set_roll(material: int, success: bool) -> void:
	var chance: float = game.graft_chance(player,material)
	for value in 1000:
		game.rng.seed = value
		var before: int = game.rng.state
		var roll: float = game.rng.randf()
		if (roll < chance) == success:
			game.rng.state = before
			return
	check(false,"deterministic graft roll exists")


func install(id: String, floor_number: int, success := true) -> void:
	var material := part(id)
	at_altar(floor_number)
	player.carried_parts[material] = 1
	var previous: int = player.graft_part
	set_roll(material,success)
	game.send_garden_action("graft_install_%d"%material)
	check(player.carried_parts[material]==0 and player.graft_part==(material if success else previous),
		"%s consumes once and %s (%s)" % [id,"installs" if success else "retains old graft",game.status])


func arena() -> void:
	player.strike_at = 0
	player.pos = Vector3.ZERO
	player.facing = Vector3.FORWARD
	player.hp = 50
	game.enemy_hp = 150
	game.enemy_pos = Vector3(0,0,-.95)
	game.enemy_winding_up = false
	game.enemy_traits.clear()
	game.leader_brain.clear()
	game.scouts.clear()
	var scout: Dictionary = game.make_scout(0, Vector3(1.6,0,-1.65), 2)
	scout.hp = 150
	game.scouts.append(scout)


func strike() -> int:
	player.strike_at = 0
	player.pos = Vector3.ZERO
	player.facing = Vector3.FORWARD
	game.enemy_pos = Vector3(0,0,-.95)
	game.strike_enemy(1,player,player.pos)
	var now := Time.get_ticks_msec()+510
	game.update_projectiles(now)
	return now


func queued(kind: String) -> Array:
	return game.trait_events.filter(func(entry): return entry.get("visual",entry.kind)==kind and entry.has("graft_source"))


func run() -> void:
	var menu := preload("res://main_menu.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	menu.new_game()
	menu.create_character("CR05 Graft Test",0,preload("res://character_appearance.gd").DEFAULT)
	var deadline := Time.get_ticks_msec()+5000
	while current_scene == menu and Time.get_ticks_msec()<deadline:
		await process_frame
	if current_scene == menu:
		check(false,"isolated title routes into the guarded affinity Garden")
		quit(1)
		return
	game = current_scene
	check(Rules.active(game) and game.has_meta(game.Transactions.SESSION),"real guarded affinity title admission")
	game.set_process(false)
	game.set_physics_process(false)
	player = game.players[1]
	player.wild = true
	player.mouse_aim = false
	player.weapon = 0
	player.secondary = game.Items.get_item("plant_part_plant_frostbell").legacy_part
	game.battlefield.configure(0,1,0)
	game.battlefield.barriers.clear()
	game.boss_kind = -1
	arena()
	check(Parts.MONSTER_DEFINITIONS.size()==24,"all 24 graft definitions are mapped")
	var unsupported := part("nameless")
	at_altar(8)
	player.carried_parts[unsupported] = 2
	var rng: int = game.rng.state
	game.send_garden_action("graft_install_%d"%unsupported)
	check(player.carried_parts[unsupported]==2 and player.graft_part==0 and game.rng.state==rng and "Mark" in game.status,
		"unsupported native Mark refuses before costs and randomness")

	install("spore_widow",8)
	arena()
	var now := strike()
	var links := queued("link")
	check(links.size()==1 and not Frost.state(game.leader_brain,now).is_empty(),
		"native Link and Frost Form respond to one real contact")
	if not links.is_empty():
		var target: int = links[0].target
		var hp: int = game.scouts[target].hp
		install("pallbearer",16,false)
		install("pallbearer",16)
		check(links[0].graft_source.item_id==Parts.DEFINITIONS[part("spore_widow")].item_id,
			"queued impact preserves its original graft identity")
		game.Traits.tick(game,now+200)
		check(game.scouts[target].hp<hp and queued("link").is_empty() and not player.has(Grafts.STATE),
			"committed Link resolves after replacement without chaining or granting new charges")
	else:
		install("pallbearer",16)

	arena()
	game.enemy_hp = 1
	now = strike()
	check(game.enemy_hp==0 and player.get(Grafts.STATE,{}).get("grave_charges")==1,"one real killing strike grants one Death Charge")
	arena()
	strike()
	check(player.get(Grafts.STATE,{}).get("grave_charges")==0,"the next direct hit spends the old charge")

	arena()
	player.frame = 3
	player.character.upgrades[3] = 1 << 8
	player.grave_charges = 2
	player[Grafts.STATE].grave_charges = 1
	strike()
	check(Grafts.grave_count(player)==2 and player[Grafts.STATE].grave_charges==1,
		"mixed class and graft spend one native Death Charge, with the class source first")
	arena()
	game.enemy_hp = 1
	strike()
	check(game.enemy_hp==0 and Grafts.grave_count(player)==3,
		"normal kill restores charges from eligible sources without exceeding the shared cap")
	player.grave_charges = 0
	player.frame = 0
	install("ashen_hart",24)
	arena()
	now = strike()
	check(queued("cinder").size()==1,"direct contact starts Cinder")
	var hp: int = game.enemy_hp
	game.Traits.tick(game,now+20)
	check(game.enemy_hp<hp and queued("cinder").size()==1 and not game.enemy_traits.has("marked_until"),
		"Cinder applies real field damage without replay or a plant Mark")

	# A ranged attack carries its rolled weapon damage across replacement.
	# Its obsolete graft cannot start another field after the swap.
	arena()
	player.frame = 2
	player.secondary = 0
	game.scouts.clear()
	game.enemy_pos = Vector3(0,0,-3.1)
	game.strike_enemy(1,player,player.pos)
	var arrow: Dictionary = game.projectile_queue.back()
	var expected_hp: int = game.enemy_hp - int(arrow.stats.preview_strike_hp)
	game.update_projectiles(int(arrow.release))
	install("gallhorn",32)
	game.update_projectiles(int(arrow.due)+500)
	check(game.enemy_hp==expected_hp and arrow.stats[Grafts.CONTEXT].component_id=="monster:ashen_hart",
		"an in-flight arrow keeps its damage roll and original equipment provenance (%d expected, %d actual)" % [expected_hp,game.enemy_hp])
	player.frame = 0
	player.secondary = game.Items.get_item("plant_part_plant_frostbell").legacy_part
	install("glasscap",40)
	game.trait_events.clear()
	arena()
	for hit in 3: now = strike()
	var echoes := queued("echo")
	check(echoes.size()==1 and echoes[0].target==0,"third impact sends a visible echo to a second enemy")
	hp = game.scouts[0].hp
	game.Traits.tick(game,now+250)
	check(game.scouts[0].hp<hp and player.get(Grafts.STATE,{}).get("echo_charge")==0,
		"Echo damage cannot count toward the next Echo")

	install("root_choir",48)
	arena()
	for hit in 4: now = strike()
	hp = game.scouts[0].hp
	check(queued("chorus").size()==1,"four direct contacts produce the Chorus pulse")
	game.Traits.tick(game,now+200)
	check(game.scouts[0].hp<hp and player.get(Grafts.STATE,{}).get("chorus_contacts")==0,
		"Chorus damages its recipient without recursion")

	install("orchard",56)
	arena()
	player.still_since = Time.get_ticks_msec()-550
	hp = int(player.hp)
	player.guard_until = 0
	game.apply_enemy_hit(1,player,Time.get_ticks_msec(),1)
	check(int(player.hp)==hp and "Heartwood" in game.status,"stationary Orchard brace absorbs a real hit")
	game.apply_enemy_hit(1,player,Time.get_ticks_msec()+10,1)
	check(int(player.hp)<hp,"brace has one defensive response per interval")

	player.secondary = 0
	arena()
	player.still_since = Time.get_ticks_msec()-550
	game.strike_enemy(1,player,player.pos)
	var braced_attack: Dictionary = game.projectile_queue.back()
	game.update_projectiles(int(braced_attack.due)+500)
	check(game.enemy_hp==150-int(braced_attack.stats.preview_strike_hp)-game.Life.Preview.hp(1),
		"a stationary Orchard strike adds one point of real damage")
	install("drowned",64)
	arena()
	now = strike()
	hp = int(player.hp)
	game.Traits.tick(game,now+5)
	check(queued("tide").size()==1 and int(player.hp)>hp,"graft healing pool restores actual HP")

	install("seamroot",72)
	arena()
	var stats: Dictionary = game.weapon_stats(player)
	check(stats.pattern=="line" and int(stats.targets)>1,"tendon selects native line geometry and an extra target")
	game.scouts[0].pos = Vector3(0,0,-1.6)
	strike()
	check(game.scouts[0].hp<150 and game.enemy_hp<150,"actual piercing strike reaches two aligned enemies")

	install("matriarch",80)
	arena()
	player.frame=1
	player.skill_at=0
	player.skill_two_at=0
	player.core_cast_until=0
	player.character.upgrades[1]=0
	player.catalyst=0
	game.use_class_skill(1,player,0)
	check(game.rooted_until>Time.get_ticks_msec() and game.scouts[0].rooted_until>Time.get_ticks_msec(),
		"Matriarch spreads native Bind to an actual nearby foe")

	install("graft_thief",88)
	arena()
	game.enemy_hp = 0
	game.scouts.clear()
	game.wild_item_drops = [{"position":[2.0,0,0]}]
	game.attract_loot(.1)
	check(float(game.wild_item_drops[0].position[0]) < 2.0,"loose loot moves toward the installed Rootlet")
	game.return_to_garden(player)
	check(player.graft_part==0 and not player.has(Grafts.STATE),"Garden return removes equipment proc state")
	game.return_to_main_menu()
	await process_frame
	if not failed: print("PASS: explicit native grafts, active gameplay effects, replacement and source-owned lifetimes")
	quit(int(failed))
