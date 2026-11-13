extends SceneTree
const Enemies = preload("res://enemy_catalog.gd")
const Progress = preload("res://progress.gd")
var failed := false
func check(ok: bool, message: String):
	if not ok:
		failed = true
		printerr("FAIL: ",message)
func _initialize():
	preload("res://combat_balance_preview.gd").enabled = false
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
	p.wild=true
	p.hp=10
	p.pos=Vector3(0,0,5.4)
	game.enemy_pos=p.pos
	game.enemy_hp=10
	game.scouts.clear()
	p.power=3
	p.strike_at=0
	game.enemy_mutations=Enemies.BARK
	game.send_action(true)
	game.update_projectiles(Time.get_ticks_msec()+1000)
	check(game.enemy_hp==7,"bark plates reduce a heavy hit by one point")
	game.enemy_hp=10
	game.enemy_mutations=0
	p.strike_at=0
	game.send_action(true)
	game.update_projectiles(Time.get_ticks_msec()+1000)
	check(game.enemy_hp==6,"unarmored enemy takes the full heavy hit")
	game.enemy_hp=0
	game.scouts.clear()
	var snare: Dictionary=game.make_scout(5,p.pos,1)
	snare.mode="snare";snare.blast=p.pos
	game.scouts.append(snare)
	var now:=Time.get_ticks_msec()
	game.resolve_scout(snare,Enemies.get_kind(5),now)
	check(p.hp==9 and p.slow_until>now,"Willow strike damages and entangles")
	p.slow_until=0;p.hp=10;p.hurt_until=0
	var volley: Dictionary=game.make_scout(1,p.pos,1)
	volley.mode="volley";volley.blast=p.pos;volley.repeat=1
	game.scouts.assign([volley])
	game.resolve_scout(volley,Enemies.get_kind(1),now)
	check(p.hp==9 and volley.windup>now,"Nightbloom retains a second telegraphed pulse")
	game.resolve_scout(volley,Enemies.get_kind(1),now+500)
	check(p.hp==8 and volley.windup==0,"volley ends after two pulses")
	var cantor: Dictionary=game.make_scout(3,p.pos,1)
	var ally: Dictionary=game.make_scout(0,p.pos+Vector3.RIGHT,2)
	cantor.mode="chant"
	game.scouts.assign([cantor,ally])
	game.resolve_scout(cantor,Enemies.get_kind(3),now)
	check(ally.haste_until>now and p.hp==8,"Cantor hastens allies instead of hurting the player")
	var brood: Dictionary=game.make_scout(9,Vector3(0,0,5.4),1)
	brood.mode="brood";p.pos=Vector3(0,0,10)
	game.scouts.assign([brood])
	for attempt in 4: game.resolve_scout(brood,Enemies.get_kind(9),now+attempt*4000)
	check(game.scouts.size()==3 and brood.summons==2 and int(game.scouts[1].mutations)&Enemies.JUVENILE,"Broodmother has a finite two-seedling brood")
	game.scouts.clear()
	game.enemy_hp=3
	game.battlefield.configure(0,1)
	game.encounter_number=5
	game.enemy_kind=0
	game.enemy_mutations=Enemies.MOBILITY
	game.enemy_pos=Vector3(-6.5,0,-4.5)
	p.pos=Vector3(-6.5,0,-1)
	p.hp=10
	game.enemy_engaged=true
	game.enemy_ready_at=0
	game.enemy_stagger_until=0
	game.update_enemy(.016,Time.get_ticks_msec())
	check(game.enemy_attack_mode=="vault" and game.enemy_winding_up,"mobility growth telegraphs a vault across cover")
	var landing: Vector3=game.enemy_landing
	game.resolve_briar_strike(Time.get_ticks_msec()+1100)
	check(game.enemy_pos==landing and not game.battlefield.occupied(landing,.34),"vault lands safely beyond cover")
	# Exercise each role through the actual director update, not only its resolver.
	game.enemy_mutations=0
	game.enemy_hp=0
	game.enemy_winding_up=false
	for kind in Enemies.all().size():
		p.wild=true;p.hp=10;p.pos=Vector3(0,0,5.4);p.slow_until=0;p.guard_until=0
		var mob: Dictionary=game.make_scout(kind,p.pos+Vector3.RIGHT*.8,1)
		game.scouts.assign([mob])
		var at:=Time.get_ticks_msec()
		game.update_scouts(.016,at)
		check(mob.windup>at,"every enemy role can telegraph through the director")
		game.update_scouts(.016,at+int(Enemies.get_kind(kind).windup)+10)
	game.enemy_mutations=Enemies.MOBILITY
	game.encounter_number=4
	game.progress.burst_pressure=0
	game.burst_clears=2
	check((game.current_mutations(0,0,0)&Enemies.BARK)==0,"recent tactics do not cause immediate early counters")
	game.encounter_number=10
	check((game.current_mutations(0,0,0)&Enemies.BARK)!=0,"deeper encounters can respond faster within the same run")
	var metadata: PackedInt32Array=game.campaign_snapshot()
	check(metadata.size()==game.EncounterConfig.BOSS_PHASE+1 and Enemies.decode(metadata[18]).mask==Enemies.MOBILITY,"appearance and landing metadata synchronize compactly")
	await process_frame
	if not failed: print("PASS: twenty-four enemy templates, behavior roles, morphology, tactic memory, armor, volleys, snares, buffs, finite brood and cover vaults")
	quit(1 if failed else 0)
