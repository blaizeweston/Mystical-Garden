extends SceneTree

const Preview = preload("res://combat_balance_preview.gd")
const Aim = preload("res://ability_aim.gd")

var game: Node
var player: Dictionary
var ally: Dictionary
var failed := false


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, detail: String) -> void:
	if not ok:
		failed=true
		printerr("FAIL CB-04: ",detail)


func run() -> void:
	Preview.enabled=true
	game=load("res://world.tscn").instantiate()
	game.progress.path="res://.godot/cb04-classes-"+str(Time.get_ticks_usec())+".cfg"
	game.local_character.path=game.progress.path+".character"
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.battlefield.configure(0,1)
	game.battlefield.procedural=false
	player=game.players[1]
	game.add_player(2)
	ally=game.players[2]
	ally.profile_ready=true
	ally.wild=true
	roster()
	guard_and_quake()
	class_fields_and_traps()
	drain_and_delayed_hit()
	heal_and_punish()
	game.queue_free()
	await process_frame
	if not failed:
		print("PASS: CB-04 all 5 class trees, 15 subclass focuses, 120 nodes, guard, direct/periodic healing, drain, trap, delayed damage and wind-up tooltips")
	quit(1 if failed else 0)


func arena(class_id: int, mask: int = 0) -> void:
	game.combat_epoch+=1
	game.scouts.clear()
	game.combat_events.clear()
	game.trait_events.clear()
	game.enemy_traits.clear()
	game.projectile_queue.clear()
	game.battlefield.barriers.clear()
	game.boss_kind=-1
	game.enemy_hp=600
	game.enemy_pos=Vector3(0,0,-2)
	game.enemy_winding_up=false
	game.enemy_mutations=0
	game.rooted_until=0
	player.character=game.Character.blank()
	player.character.upgrades[class_id]=mask
	player.character.xp[class_id]=260
	player.merge({"frame":class_id,"weapon_kind":0,"weapon":0,"secondary":0,"catalyst":0,"graft_part":0,
		"power":0,"technique":0,"run_upgrades":{},"wild":true,"fallen":false,"max_hp":100,"hp":20,
		"pos":Vector3.ZERO,"facing":Vector3.FORWARD,"lost_health":0},true)
	for key in ["skill_at","skill_two_at","core_cast_until","strike_at","hurt_until","guard_until","guard_charges",
		"counter_until","counter_guard_until","front_guard_until","renewal_until","grave_charges","focus_until"]:
		player[key]=0
	ally.pos=Vector3(0,0,-.4)
	ally.fallen=false
	ally.hp=25
	ally.max_hp=100
	ally.renewal_until=0
	ally.guard_until=0


func skills() -> Array:
	return [game.Skills.resolve(player.frame,0,player.character),game.Skills.resolve(player.frame,1,player.character)]


func tooltip(slot: int) -> String:
	return game.Skills.wild_tooltips(game,player,skills())[slot]


func cast_at(slot: int, distance: float) -> void:
	game.garden_action(1,Aim.request(game,player,slot,Vector2.UP,distance))


func add_foe(at: Vector3) -> void:
	var foe: Dictionary=game.make_scout(0,at,game.scouts.size()+1)
	foe.hp=600
	game.scouts.append(foe)


func roster() -> void:
	for class_id in 5:
		arena(class_id)
		for slot in 2:
			var base: Dictionary=game.Skills.resolve(class_id,slot,player.character)
			var replacement: Dictionary=game.Skills.DEFINITIONS[class_id]["replace"][slot]
			check(base.name!=replacement.name and tooltip(slot).contains("Cooldown:"),"base and replacement slot "+str([class_id,slot]))
			check(game.Skills.describe(replacement).contains(replacement.name),"replacement has a tooltip")
		var legacy: Array=game.Classes.DEFINITIONS[class_id].nodes
		var current: Array=game.Classes.branch_nodes(class_id)
		check(legacy.size()==12 and current.size()==12,"class keeps all saved bit positions")
		for lane in 3:
			var path := 0
			for tier in 4:
				var index := 12+tier*3+lane
				check(game.Classes.can_learn(player.character,class_id,index,7),"class lane stays learnable "+str([class_id,index]))
				path |= 1<<index
				player.character.upgrades[class_id]=path
			var normalized: Dictionary=game.Character.normalize(player.character)
			check(normalized.upgrades[class_id]==path and not game.Classes.focus_id(normalized,class_id).is_empty(),"subclass path survives profile normalization")
			check(tooltip(0).contains(skills()[0].name),"subclass has a resolved Wilds tooltip")
			player.character.upgrades[class_id]=0
		for i in legacy.size():
			var path := 1<<i
			var node: Dictionary=legacy[i]
			var expected := {}
			while true:
				for key in node.effects:
					expected[key]=float(expected.get(key,0.0))+float(node.effects[key])
				if node.parents.is_empty(): break
				var parent := legacy.find_custom(func(entry):return entry.id==node.parents[0])
				path |= 1<<parent
				node=legacy[parent]
			player.character.upgrades[class_id]=path
			var normalized: Dictionary=game.Character.normalize(player.character)
			check(normalized.upgrades[class_id]==path,"legacy choice survives profile normalization "+str([class_id,i]))
			check(game.Classes.bonuses(normalized,class_id)==expected,"legacy passives keep authored values")
			game.progression_view.inspected_class=class_id
			var nodes: Array=game.progression_view.class_nodes()
			check(nodes.size()==13 and nodes[i+1].unlocked,"legacy node stays learned in the tree")
			for slot in 2:
				check(tooltip(slot).contains("Cooldown:"),"legacy resolution has a numeric tooltip")
	arena(0,1)
	check(game.Classes.effect_text(game.Classes.bonuses(player.character,0),true).contains("+20 HP maximum health"),"old Warden maximum-health node displays 20 HP")
	game.progression_view.inspected_class=0
	check(game.progression_view.class_nodes()[1].detail.contains("+20 HP"),"class tree renders the health bonus in HP")
	game.local_character.data=player.character
	check(game.local_character.save_profile()==OK,"old mask saves through the normal profile writer")
	var loaded=game.Character.new()
	loaded.path=game.local_character.path
	loaded.load_profile()
	check(loaded.data.upgrades[0]==1,"profile round trip preserves the learned node")


func guard_and_quake() -> void:
	arena(0,1<<12)
	check(tooltip(0).contains("Guard: 1 hit") and tooltip(0).contains("Counter: +10 HP"),"guard counts and counter HP display separately")
	game.use_class_skill(1,player,0)
	var now:=Time.get_ticks_msec()
	game.apply_enemy_hit(1,player,now,3)
	check(player.hp==20 and player.guard_charges==0 and player.counter_until>now,"one charge fully blocks an incoming 30 HP hit")
	game.use_class_skill(1,player,1)
	check(game.enemy_hp==570 and player.counter_until==0,"Root Quake applies 20 HP plus the 10 HP counter once")


func class_fields_and_traps() -> void:
	arena(1,1<<13)
	cast_at(0,2.0)
	var now:=Time.get_ticks_msec()
	check(game.enemy_hp==600 and tooltip(0).contains("10 HP damage each second"),"Cultivate Bloom advertises field potency without an instant strike")
	game.Traits.tick(game,now)
	check(game.enemy_hp==590,"class growth applies its base pulse once")
	arena(2)
	var trap: Dictionary=game.Traits.tune_skill(skills()[1],{"trap_power":.5})
	var stats := {"trap_power":.5,"skill_duration":400}
	game.Traits.place_snare(game,player,game.enemy_pos,trap,stats,now)
	check(game.enemy_hp==600 and game.trait_events[0].until-now==4200,"trap stays active for its modified duration and waits to arm")
	game.Traits.tick(game,now+300)
	check(game.enemy_hp==585 and game.rooted_until>=now+2100,"trap applies the fractional 15 HP hit and modified root")
	check(game.Skills.describe(skills()[1],stats).contains("15 HP") and game.Skills.describe(skills()[1],stats).contains("4.2s"),"trap tooltip uses the same tuned values")


func drain_and_delayed_hit() -> void:
	arena(3,(1<<12)|(1<<16))
	for at in [Vector3(.4,0,-1.2),Vector3(-.4,0,-1.5),Vector3(0,0,-.6)]:
		add_foe(at)
	game.use_class_skill(1,player,0)
	check(game.enemy_hp==580 and int(player.hp)-20 in range(23,26),"Blood Harvest rolls around 24 HP at its learned extra-contact cap")
	check(tooltip(0).contains("5–7 HP with one enemy hit · 23–25 HP at the target cap"),"drain tooltip reflects the learned cap")
	arena(3,2730)
	player.power=1
	var skill: Dictionary=skills()[1]
	check(skill.mode=="requiem","legacy mask resolves Requiem")
	var before:=Time.get_ticks_msec()
	game.use_class_skill(1,player,1)
	check(game.enemy_hp==600 and not game.trait_events.is_empty(),"Requiem schedules its damage")
	game.Traits.tick(game,before+1500)
	var expected:=Preview.effect_hp(float(skill.damage)+1.0)
	check(game.enemy_hp==600-expected and tooltip(1).contains("%d HP"%expected),"Requiem applies the displayed amount and adds expedition power once")


func heal_and_punish() -> void:
	arena(4)
	ally.hp=97
	game.use_class_skill(1,player,0)
	var initial_hp := int(player.hp)
	check(initial_hp-20 in range(18,23) and ally.hp==100,"Renewal initial heal rolls and clamps overheal")
	game.update_support_effects(int(player.renewal_tick))
	check(int(player.hp)-initial_hp in range(3,6) and tooltip(0).contains("3–5 HP every second"),"Renewal tick and tooltip agree")
	arena(4,1<<14)
	player.run_upgrades={"class_4_0":1}
	var bonus: float=game.weapon_stats(player).skill_heal
	cast_at(0,0.0)
	var amount:=int(player.hp)-20
	var center:=Preview.effect_hp(1.0+bonus)
	check(bonus>0 and amount in range(center-2,center+3) and ally.hp==25+amount,"Living Sanctuary includes equipped class healing in one shared group roll")
	check(tooltip(0).contains("Heal living allies: "+Preview.heal_label(1.0+bonus)),"subclass tooltip shows the combined heal range")
	arena(4,1<<12)
	player.run_upgrades={"omenreader_signature":1}
	game.enemy_winding_up=true
	cast_at(0,2.0)
	check(game.enemy_hp==570 and tooltip(0).contains("+20 HP damage"),"Foretell deals 10 base and 20 wind-up damage with its signature")
