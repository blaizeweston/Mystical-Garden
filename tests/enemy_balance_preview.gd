extends SceneTree

const PlayerLifecycle = preload("res://player_lifecycle.gd")

const PlayerVitals = preload("res://player_vitals.gd")

const Preview = preload("res://combat_balance_preview.gd")
const Balance = preload("res://enemy_balance.gd")
const Pressure = preload("res://expedition_pressure.gd")
const Attacks = preload("res://enemy_attack.gd")
const Lair = preload("res://boss_lair_fights.gd")
const Phases = preload("res://boss_phase_fights.gd")

var game: Node
var player: Dictionary
var failed := false


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, detail: String) -> void:
	if not ok:
		failed=true
		printerr("FAIL CB-06: ",detail)


func run() -> void:
	Preview.enabled=true
	game=load("res://world.tscn").instantiate()
	game.progress.path="res://.godot/cb06-enemies-"+str(Time.get_ticks_usec())+".cfg"
	game.local_character.path=game.progress.path+".character"
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	player=game.players[1]
	for id in range(2,5):
		game.add_player(id)
	roster()
	depth_curves()
	contact_and_hazards()
	bosses()
	reinforcements()
	game.queue_free()
	await process_frame
	if not failed:
		print("PASS: CB-06 24 species, early/biome/deep scaling, party snapshot, boss openings, warning geometry, hazards and bounded reinforcements")
	quit(1 if failed else 0)


func party(size: int) -> void:
	for id in range(1,5):
		var actor: Dictionary=game.players[id]
		actor.profile_ready=id<=size
		actor.wild=id<=size
		actor[PlayerLifecycle.STATE] = actor[PlayerLifecycle.STATE].clear_inactive()
		actor[PlayerVitals.STATE] = actor[PlayerVitals.STATE].with_hp(100)
		actor[PlayerVitals.STATE] = actor[PlayerVitals.STATE].with_native_max_hp(100)
		actor.guard_until=0
		actor.hurt_until=0


func floor_state(floor_number: int, size: int, boss: int = -1) -> void:
	party(size)
	game.encounter_number=floor_number
	game.depth=(floor_number-1)%6+1
	game.destination=((floor_number-1)/6)%3
	game.difficulty_cycle=(floor_number-1)/18
	game.map_seed=91300+floor_number
	game.boss_floors[str(floor_number)]=boss
	game.reset_encounter()
	for actor in game.players.values():
		actor.pos=game.battlefield.entry


func roster() -> void:
	var definitions: Array=game.Enemies.all()
	check(definitions.size()==24 and Balance.errors(definitions).is_empty(),"every roster entry has native preview HP and contact damage")
	for definition in definitions:
		if definition.get("boss",false):
			check(Balance.boss_hp(definition,10,0,1)==int(definition.preview_hp),"boss authored HP survives on first eligible floor")
			continue
		var early := Balance.scout_hp(definition,1,0,0,1)
		var deep := Balance.scout_hp(definition,48,2,2,1)
		check(early==int(definition.preview_hp) and deep>early,"scout health grows by depth for "+definition.id)
		check(Balance.scout_hp(definition,48,2,2,4)>deep,"party scales the same species")
	check(Balance.scout_hp(definitions[7],1,0,0,1)>2*Balance.scout_hp(definitions[8],1,0,0,1),"Colossus is substantially tougher than Wicker Wasp")


func depth_curves() -> void:
	var rows := []
	for floor_number in [1,6,18,19,36,48,72]:
		for size in [1,2,4]:
			floor_state(floor_number,size)
			var total_hp: int=game.enemy_health()
			var budget: int=game.Director.scout_count(game)
			check(game.encounter_party_size==size and game.encounter.scout_count()<=budget,"party population fits the generated floor and snapshot")
			for scout in game.encounter.scout_tactics():
				total_hp+=int(scout.max_hp)
				check(game.encounter.hp_for(scout)==scout.max_hp and scout.pos.distance_to(game.battlefield.entry)>=8.0,"fresh scout capacity and arrival spacing")
			rows.append([floor_number,size,game.encounter.scout_count(),game.enemy_health(),total_hp])
			check(game.enemy_health()==game.encounter_health(),"leader capacity uses the selected elite species")
			if floor_number==1 and size==4:
				check(game.encounter.scout_count()==15,"first four-player floor gets fifteen scouts with room to spread")
				var ceiling: int=game.enemy_health()
				game.players[4].wild=false
				game.players[4][PlayerLifecycle.STATE] = game.players[4][PlayerLifecycle.STATE].fall()
				check(game.encounter_health()==ceiling,"mid-fight departure cannot change the existing HP pool")
	print("CB-06 depth sample [floor, party, scouts, elite HP, total enemy HP]: ",JSON.stringify(rows))
	check(rows[0][4]<rows[3][4] and rows[3][4]<rows[6][4] and rows[15][4]<rows[18][4],"regular floor HP budget grows across the sample")
	check(float(rows[2][4])/float(rows[0][4])<4.1,"early party scaling avoids multiplying a larger pack by the old health ramp")
	var rootbound: Dictionary=game.Enemies.get_kind(0)
	check(Balance.elite_hp(rootbound,6,6,0,1)-Balance.elite_hp(rootbound,6,5,0,1)==26,"last biome gate has an authored guardian premium")


func contact_and_hazards() -> void:
	floor_state(1,1)
	game.battlefield.configure(0,1,0)
	game.battlefield.procedural=false
	game.battlefield.barriers.clear()
	game.encounter.clear_scouts()
	player.pos=Vector3(0,0,.5)
	var rootbound: Dictionary=game.Enemies.get_kind(0)
	var wasp: Dictionary=game.Enemies.get_kind(8)
	var colossus: Dictionary=game.Enemies.get_kind(7)
	var actor: Dictionary=game.make_scout(0,Vector3.ZERO,1)
	Attacks.lock(game,actor,"swipe",player.pos,1000)
	preload("res://scout_behavior.gd").release(game, actor,rootbound,1000)
	check(PlayerVitals.current_hp(player)==90,"an actual Rootbound sweep applies 10 HP")
	check(Preview.effect_hp(Balance.scout_hit(game,wasp,{}))==7 and Preview.effect_hp(Balance.scout_hit(game,colossus,{}))==19,"fast and heavy scouts have distinct contact damage")
	check(Preview.effect_hp(Balance.scout_hit(game,rootbound,{"gate_elite":true}))==12,"elite contact premium follows its species")
	var juvenile: Dictionary=game.make_scout(0,Vector3.ZERO,1,0,0,true)
	check(juvenile.max_hp==12 and Preview.effect_hp(Balance.scout_hit(game,rootbound,juvenile))==6,"juvenile has its own lower hit and HP budget")
	game.encounter_number=48
	game.difficulty_cycle=2
	check(Preview.effect_hp(Balance.scout_hit(game,rootbound,{}))==28,"deep damage rises within a loop")
	check(Preview.armor(8)==6 and Preview.armor(20)==15,"armor reduces light and heavy attacks proportionally")
	game.enemy_hazards.clear()
	player[PlayerVitals.STATE] = player[PlayerVitals.STATE].with_hp(100)
	player.hurt_until=0
	game.Bosses.hazard(game,Vector3.ZERO,1.2,2000,2300,"spores",800)
	game.Bosses.tick_hazards(game,2799)
	check(PlayerVitals.current_hp(player)==100,"hazard windup applies no damage")
	game.Bosses.tick_hazards(game,2800)
	check(PlayerVitals.current_hp(player)==82,"preview hazard applies its own scaled native damage on contact")
	player.pos=Vector3(0,0,2)
	game.Bosses.tick_hazards(game,3800)
	check(PlayerVitals.current_hp(player)==82,"walking out of the telegraph avoids the next tick")


func bosses() -> void:
	var expected := [600,550,570,590]
	for kind in range(20,24):
		var definition: Dictionary=game.Enemies.get_kind(kind)
		floor_state(10,1,kind)
		var ceiling: int=game.enemy_health()
		check(ceiling==expected[kind-20] and game.encounter.scout_count()<4,"solo boss starts at its authored HP with a smaller escort")
		game.encounter.set_hp(-1, floori(.65*ceiling)+1)
		check(game.Bosses.phase(game)==0,"just above first phase threshold")
		game.encounter.set_hp(-1, floori(.65*ceiling))
		check(game.Bosses.phase(game)==1,"first phase threshold follows the new health pool")
		game.encounter.set_hp(-1, floori(.30*ceiling))
		check(game.Bosses.phase(game)==2,"second phase threshold follows the new health pool")
		floor_state(48,4,kind)
		check(game.enemy_health()>ceiling*3 and game.encounter.scout_count()<=4,"deep four-player boss increases HP with finite escorts")
		var next_move: String=definition.moves.back()
		var phase_zero := Preview.effect_hp(Balance.boss_hit(game,definition,next_move))
		game.tactics.boss_phase=2
		check(Preview.effect_hp(Balance.boss_hit(game,definition,next_move))==phase_zero+4,"late phases add four HP to a landed attack")
		var now := 9000
		game.tactics.position=game.battlefield.leader
		player.pos=game.battlefield.entry
		if kind<=21:
			var mode := "orchard_march" if kind==20 else "drowned_surge"
			var plan:=Lair.draft(game,mode,1,false)
			check(not plan.is_empty() and not str(plan.open).is_empty(),"lair boss exposes its authored opening after the telegraph")
			if not plan.is_empty():
				player.pos=plan.from.lerp(plan.to,.55)
				var escape:=Lair.escape(game,plan,player.pos,now)
				check(escape.is_finite() and not Lair.covered(plan,escape),"lair warning keeps a legal exit")
				if escape.is_finite(): player.pos=escape
				game.tactics.memory.lair_plan=plan
				game.tactics.attack_mode=mode
				game.Bosses.resolve(game,now)
				check(PlayerVitals.current_hp(player)==100 and game.Bosses.exposed(game,now),"leaving the telegraph preserves health and opens the counter window")
		else:
			var mode := "matriarch_lunge" if kind==22 else "memory_lance"
			var plan:=Phases.draft(game,mode,1,"")
			check(not plan.is_empty() and not plan.lanes.is_empty() and not str(plan.open).is_empty(),"phase boss keeps its lane telegraph and opening")
			if not plan.is_empty():
				player.pos=Vector3(24,0,24)
				game.tactics.memory.phase_plan=plan
				game.tactics.attack_mode=mode
				game.Bosses.resolve(game,now)
				check(PlayerVitals.current_hp(player)==100 and game.Bosses.exposed(game,now),"phase boss resolves and leaves its damage window")
		game.enemy_mutations=0
		game.tactics.memory.lair_open={"kind":"core_exposed","until":now+2000}
		var before: int=game.enemy_health()
		game.apply_weapon_hit(player,-1,game.tactics.position,{"damage":3.0,"core_hit":true,"trait_secondary":true},now)
		check(before-game.enemy_health()==39,"vulnerable boss takes 30 percent extra HP damage")


func reinforcements() -> void:
	floor_state(19,1)
	game.encounter.clear_scouts()
	game.encounter.set_hp(-1, 100)
	var now := 1000
	var rng_state: int=game.rng.state
	game.update_pressure(now)
	check(game.pressure_at==33000,"preview pressure begins after 32 seconds")
	for wave in 2:
		now=game.pressure_at
		game.update_pressure(now)
		var warnings:=Pressure.hints(game,now)
		check(not warnings.is_empty() and warnings[0].remaining==3.0,"reinforcements are announced three seconds ahead")
		game.update_pressure(now+2999)
		check(game.encounter.scout_count()==0 and PlayerVitals.current_hp(player)==100,"no arrivals or damage before the warning resolves")
		game.update_pressure(now+3000)
		check(game.encounter.scout_count()>0 and PlayerVitals.current_hp(player)==100,"warning resolves into a real pack with no automatic damage")
		for scout in game.encounter.scout_tactics():
			var regular := Balance.scout_hp(game.Enemies.get_kind(scout.kind),19,1,int(scout.growth),1)
			check(scout.summoned and scout.max_hp==roundi(regular*.75),"arrivals use the reduced non-rewarding HP budget")
		game.encounter.clear_scouts()
	game.update_pressure(game.pressure_at)
	check(game.pressure_at==0 and Pressure.hints(game).is_empty(),"first loop has a finite reinforcement budget")
	check(Pressure.interval(40,20)==22000 and Balance.pressure_limit(40)==5,"deep reinforcement escalation remains bounded")
	check(game.rng.state==rng_state,"reinforcement planning preserves combat and loot RNG")
