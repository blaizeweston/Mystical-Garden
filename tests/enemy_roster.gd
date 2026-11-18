extends SceneTree
const Conditions = preload("res://player_hit_conditions.gd")
const Protection = preload("res://player_protection.gd")

const ExpeditionCase = preload("res://tests/support/expedition_case.gd")

const PlayerVitals = preload("res://player_vitals.gd")
const Enemies = preload("res://enemy_catalog.gd")
const Progress = preload("res://progress.gd")
var failed := false
func check(ok: bool, message: String):
	if not ok:
		failed = true
		printerr("FAIL: ",message)
func _initialize():
	call_deferred("run")
func run():
	check(Enemies.all().size() == 24, "roster has twenty-four unique enemies")
	var roles := {}
	var ids := {}
	var observed := {}
	var game = load("res://world.tscn").instantiate()
	var token := Crypto.new().generate_random_bytes(8).hex_encode()
	game.progress.path = "res://.godot/enemies_"+token+".cfg"
	game.local_character.path = game.progress.path+".character"
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	for kind in Enemies.all().size():
		var spec := Enemies.get_kind(kind)
		roles[spec.role] = true
		ids[spec.id] = true
		var actor := {}
		var node := Node3D.new()
		root.add_child(node)
		game.stage.ensure_enemy(node,actor,Enemies.encode(kind,15,2))
		check(actor.model.find_child("EnemyCore",true,false)!=null,"enemy has shared core socket")
		for group in ["Growth1","Growth2","AdaptReach","AdaptBark","AdaptSpore","AdaptMobility"]:
			check(actor.model.find_child(group,true,false).visible,"growth and trait sockets are usable")
		game.stage.ensure_enemy(node,actor,Enemies.encode(kind,0,0))
		check(not actor.model.find_child("AdaptBark",true,false).visible,"base form hides unequipped adaptations")
		node.free()
	for site in 3:
		for encounter in range(1,25):
			for seed_value in range(1,31):
				for slot in [0,1,2,4]:
					observed[Enemies.choose(site,encounter,slot,seed_value)] = true
	check(ids.size()==24 and roles.size()>=10 and observed.size()==20,"all unique roles can appear in biome encounters")
	var memory := Progress.new()
	memory.path = game.progress.path+".memory"
	for run_index in 3: memory.remember_expedition(1,1,1)
	check(memory.ranged_pressure==3 and memory.burst_pressure==3 and memory.choke_pressure==3,"repeated tactics build host-world memory")
	var traits := 0
	for stamp in 12: traits |= Enemies.mutations(0,0,3,3,3,8,stamp)
	check((traits & 11)==11 and Enemies.mutations(0,2,8,8,8,1,0)==0,"tactic counters emerge gradually and spare the opening encounter")
	memory.save_garden()
	var reload := Progress.new()
	reload.path=memory.path
	check(reload.load_garden()==OK and reload.choke_pressure==3,"adaptation memory persists")
	check(Progress.new().burst_pressure==0,"other host worlds start with separate memory")
	reload.remember_expedition(0,0,0)
	check(reload.burst_pressure==3,"counters persist after one change of tactics")
	reload.remember_expedition(0,0,0)
	check(reload.burst_pressure==2,"unused counters fade slowly")
	var p: Dictionary=game.players[1]
	ExpeditionCase.set_membership(game, p, true)
	p[PlayerVitals.STATE] = p[PlayerVitals.STATE].with_hp(100)
	p.pos=Vector3(0,0,5.4)
	game.tactics.position=p.pos
	game.encounter.set_hp(-1, 100)
	game.encounter.clear_scouts()
	game.enemy_mutations=Enemies.BARK
	game.apply_weapon_hit(p,-1,p.pos,{"damage":4},Time.get_ticks_msec())
	check(game.enemy_health()==70,"bark plates reduce a 40-damage native hit by 25 percent")
	game.encounter.set_hp(-1, 100)
	game.enemy_mutations=0
	game.apply_weapon_hit(p,-1,p.pos,{"damage":4},Time.get_ticks_msec())
	check(game.enemy_health()==60,"unarmored enemy takes the full 40-damage native hit")
	game.encounter.set_hp(-1, 0)
	game.encounter.clear_scouts()
	var snare: Dictionary=game.make_scout(5,p.pos,1)
	snare.mode="snare";snare.blast=p.pos
	game.encounter.register_scout(snare)
	var now:=Time.get_ticks_msec()
	var snare_damage: int=game.Life.Preview.effect_hp(game.Director.Balance.scout_hit(game,Enemies.get_kind(5),snare))
	preload("res://scout_behavior.gd").release(game, snare,Enemies.get_kind(5),now)
	check(PlayerVitals.current_hp(p)==100-snare_damage and p[Conditions.STATE].slow_until_ms()>now,"Willow strike damages and entangles")
	p[Conditions.STATE] = p[Conditions.STATE].cleanse_slow();p[PlayerVitals.STATE] = p[PlayerVitals.STATE].with_hp(100);p[Conditions.STATE] = p[Conditions.STATE].clear_grace()
	var volley: Dictionary=game.make_scout(1,p.pos,1)
	volley.mode="volley";volley.blast=p.pos;volley.repeat=1
	game.encounter.clear_scouts();game.encounter.register_scout(volley)
	var volley_damage: int=game.Life.Preview.effect_hp(game.Director.Balance.scout_hit(game,Enemies.get_kind(1),volley))
	preload("res://scout_behavior.gd").release(game, volley,Enemies.get_kind(1),now)
	check(PlayerVitals.current_hp(p)==100-volley_damage and volley.windup>now,"Nightbloom retains a second telegraphed pulse")
	preload("res://scout_behavior.gd").release(game, volley,Enemies.get_kind(1),now+500)
	check(PlayerVitals.current_hp(p)==100-2*volley_damage and volley.windup==0,"volley ends after two pulses")
	var cantor: Dictionary=game.make_scout(3,p.pos,1)
	var ally: Dictionary=game.make_scout(0,p.pos+Vector3.RIGHT,2)
	cantor.mode="chant"
	game.encounter.clear_scouts();game.encounter.register_scout(cantor);game.encounter.register_scout(ally)
	preload("res://scout_behavior.gd").release(game, cantor,Enemies.get_kind(3),now)
	check(ally.haste_until>now and PlayerVitals.current_hp(p)==100-2*volley_damage,"Cantor hastens allies instead of hurting the player")
	var brood: Dictionary=game.make_scout(9,Vector3(0,0,5.4),1)
	brood.mode="brood";p.pos=Vector3(0,0,10)
	game.encounter.clear_scouts();game.encounter.register_scout(brood)
	for attempt in 4: preload("res://scout_behavior.gd").release(game, brood,Enemies.get_kind(9),now+attempt*4000)
	check(game.encounter.scout_count()==3 and brood.summons==2 and int(game.encounter.scout(1).mutations)&Enemies.JUVENILE,"Broodmother has a finite two-seedling brood")
	game.encounter.clear_scouts()
	game.encounter.set_hp(-1, 3)
	game.battlefield.configure(0,1)
	ExpeditionCase.set_world(game, {"encounter_number": 5})
	game.enemy_kind=0
	game.enemy_mutations=Enemies.MOBILITY
	game.tactics.position=Vector3(-6.5,0,-4.5)
	p.pos=Vector3(-6.5,0,-1)
	p[PlayerVitals.STATE] = p[PlayerVitals.STATE].with_hp(100)
	game.tactics.engaged=true
	game.tactics.ready_at=0
	game.tactics.stagger_until=0
	preload("res://leader_behavior.gd").tick(game, .016,Time.get_ticks_msec())
	check(game.tactics.attack_mode=="vault" and game.tactics.winding_up,"mobility growth telegraphs a vault across cover")
	var landing: Vector3=game.tactics.landing
	preload("res://leader_behavior.gd").resolve(game, Time.get_ticks_msec()+1100)
	check(game.tactics.position==landing and not game.battlefield.occupied(landing,.34),"vault lands safely beyond cover")
	# Exercise each role through the actual director update, not only its resolver.
	game.enemy_mutations=0
	game.encounter.set_hp(-1, 0)
	game.tactics.winding_up=false
	for kind in Enemies.all().size():
		ExpeditionCase.set_membership(game, p, true);p[PlayerVitals.STATE] = p[PlayerVitals.STATE].with_hp(100);p.pos=Vector3(0,0,5.4);p[Conditions.STATE] = p[Conditions.STATE].cleanse_slow();p[Protection.STATE] = p[Protection.STATE].clear_guard()
		var mob: Dictionary=game.make_scout(kind,p.pos+Vector3.RIGHT*.8,1)
		game.encounter.clear_scouts();game.encounter.register_scout(mob)
		var at:=Time.get_ticks_msec()
		preload("res://scout_behavior.gd").tick(game, .016,at)
		check(mob.windup>at,"every enemy role can telegraph through the director")
		preload("res://scout_behavior.gd").tick(game, .016,at+int(Enemies.get_kind(kind).windup)+10)
	game.enemy_mutations=Enemies.MOBILITY
	ExpeditionCase.set_world(game, {"encounter_number": 4})
	game.progress.burst_pressure=0
	game.burst_clears=2
	check((game.current_mutations(0,0,0)&Enemies.BARK)==0,"recent tactics do not cause immediate early counters")
	ExpeditionCase.set_world(game, {"encounter_number": 10})
	check((game.current_mutations(0,0,0)&Enemies.BARK)!=0,"deeper encounters can respond faster within the same run")
	var metadata: PackedInt32Array=game.campaign_snapshot()
	check(metadata.size()==game.EncounterConfig.BOSS_PHASE+1 and Enemies.decode(metadata[18]).mask==Enemies.MOBILITY,"appearance and landing metadata synchronize compactly")
	await process_frame
	if not failed: print("PASS: twenty-four enemy templates, behavior roles, morphology, tactic memory, armor, volleys, snares, buffs, finite brood and cover vaults")
	quit(1 if failed else 0)
