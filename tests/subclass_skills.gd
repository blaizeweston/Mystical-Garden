extends SceneTree

const PlayerVitals = preload("res://player_vitals.gd")

const Cooldowns = preload("res://player_cooldowns.gd")

const Aim = preload("res://ability_aim.gd")
const Combat = preload("res://subclass_combat.gd")
const Status = preload("res://combat_status.gd")

var game: Node
var player: Dictionary
var failed := false


func _initialize() -> void:
	call_deferred("run")


func check(value: bool, message: String) -> void:
	if not value:
		failed = true
		printerr("FAIL subclasses: ",message)


func prepare(class_id: int, lane: int) -> void:
	game.combat_epoch += 1
	game.trait_events.clear()
	game.encounter.clear_scouts()
	game.combat_events.clear()
	game.enemy_traits.clear()
	game.encounter.set_hp(-1, 100)
	game.enemy_pos = Vector3(0,0,-2.4)
	game.enemy_winding_up = false
	game.rooted_until = 0
	game.battlefield.barriers.clear()
	player.character = game.Character.blank()
	player.character.xp[class_id] = 2600
	player.frame = class_id
	player.pos = Vector3.ZERO
	player[PlayerVitals.STATE] = player[PlayerVitals.STATE].with_hp(5)
	player[PlayerVitals.STATE] = player[PlayerVitals.STATE].with_native_max_hp(10)
	player.guard_until = 0
	player.slow_until = Time.get_ticks_msec()+2000
	player[Cooldowns.STATE] = player[Cooldowns.STATE].with_deadline(Cooldowns.Q, 0)
	player[Cooldowns.STATE] = player[Cooldowns.STATE].with_deadline(Cooldowns.R, 0)
	player.cast_until = 0
	player.core_cast_until = 0
	player.run_upgrades = {}
	var levels := [1,2,4,7]
	var path := [lane,1,lane,1]
	for tier in 4:
		var index: int = 12 + tier*3 + path[tier]
		check(game.Classes.can_learn(player.character,class_id,index,levels[tier]),"adjacent branch is available")
		player.character.upgrades[class_id] |= 1 << index
	var restored: Dictionary = game.Character.normalize(player.character)
	check(restored.upgrades[class_id] == player.character.upgrades[class_id],"learned class path survives normalization")


func add_foe(at: Vector3) -> Dictionary:
	var foe: Dictionary = game.make_scout(0,at,game.encounter.scout_count()+1)
	foe.hp = 50
	game.encounter.register_scout(foe)
	return foe


func press_release(class_id: int, lane: int) -> void:
	prepare(class_id,lane)
	var skill: Dictionary = game.Skills.resolve(class_id,0,player.character)
	check(skill.mode=="subclass","level-one choice supplies its own Q skill")
	var outside := add_foe(Vector3(5.6,0,-2.4))
	var second := add_foe(Vector3(.25,0,-2.8))
	var by_start := add_foe(Vector3(.25,0,.8))
	var card: Dictionary = skill.card
	check(game.RunUpgrades.requirement(card,player,game.RunUpgrades.context(player)).is_empty(),"matching subclass can roll its card")
	player.run_upgrades[card.id] = 1
	var aim := Vector3.FORWARD
	var preview := Aim.footprint(game,player,game.battlefield,0,aim,2.4)
	check(preview.valid and not preview.shapes.is_empty(),"holding previews the "+str(skill.shape))
	check(game.enemy_health()==100 and player[Cooldowns.STATE].deadline(Cooldowns.Q)==0 and game.combat_events.is_empty(),"preview commits no effects")
	game.garden_action(1,Aim.request(game,player,0,Vector2.UP,2.4))
	var releases: Array = game.combat_events.filter(func(event): return event.kind=="subclass_release")
	check(releases.size()==1 and player[Cooldowns.STATE].deadline(Cooldowns.Q)>Time.get_ticks_msec(),"release starts one cooldown and publishes one cast")
	if releases.is_empty():
		return
	var cue: Dictionary = releases[0]
	check(cue.shape==skill.visual and cue.pattern==skill.shape and cue.label==skill.name,"correct release style")
	check(game.attack_animation_snapshot(player).clip==Combat.CLIPS[skill.visual],"host and guest snapshot contain the authored gesture")
	check(game.encounter.hp_for(outside)==50 and outside.rooted_until==0,"enemy outside the preview is untouched")
	if skill.shape in ["ground","line","dash","retreat"]:
		var shape: Dictionary = preview.shapes.filter(func(entry):return entry.kind in ["area","strip","travel"])[0]
		var expected: Vector3 = shape.get("to",shape.get("at",Vector3.ZERO))
		check(Vector3(cue.to[0],cue.to[1],cue.to[2]).is_equal_approx(expected),"host release uses preview endpoint")
	if skill.id in ["snarekeeper","wayfarer"]:
		check(game.trait_events.any(func(event): return event.kind == "snare"), "ability sets a lingering ground trap")
		game.Traits.tick(game,Time.get_ticks_msec()+300)
	if skill.id in ["thornbinder","silkwarden","snarekeeper"]:
		check(game.rooted_until>Time.get_ticks_msec(),"roots the intended enemy")
	if skill.id in ["wildstalker","veilwalker"]:
		check(game.enemy_health()<100 and game.enemy_traits.has("core_strike_mark"),"hit leaves the promised consumable mark")
	if skill.id=="wildstalker":
		check(second.traits.has("core_strike_mark") and game.encounter.hp_for(by_start)==50,"card marks the second forward target only")
	if skill.id=="wayfarer":
		check(player.pos.z>2.3 and by_start.rooted_until>0 and player.guard_until>0,"retreat roots behind and card wards landing")
	if skill.id=="blood_harvester":
		check(game.enemy_health()<100 and PlayerVitals.current_hp(player)>5,"harvest heals from actual contacts")
	if skill.id=="gravekeeper":
		check(game.enemy_health()<100 and game.encounter.hp_for(by_start)==50 and player.guard_until>0,"facing sweep excludes a rear target and wards on hit")
	if skill.id=="leykeeper":
		check(second.pos.distance_to(Vector3(0,0,-2.4))<.2,"bell pulls a visible foe to the impact")
	if skill.id in ["bloomcaller","snarekeeper","lifekeeper"]:
		check(game.trait_events.any(func(e):return e.kind==skill.field),"release starts its persistent field")
	Status.sync(game,Time.get_ticks_msec())
	check(game.combat_events.any(func(e):return e.kind=="status" and e.shape=="subclass_follow_ready"),"primed follow-up is visible")
	if skill.id in ["wildstalker","veilwalker"]:
		check(game.combat_events.any(func(e):return e.kind=="status" and e.shape=="marked"),"subclass mark is visible")
	var fx: Node = game.combat_visuals
	var effect: Dictionary = fx.visual(Color(cue.color))
	effect.event = cue
	effect.age = .3
	fx.pose(effect)
	check(effect.mesh.mesh.get_surface_count()>0,"release animation draws")
	effect.root.queue_free()
	if skill.id=="thornbinder":
		game.use_class_skill(1,player,1)
		check(Combat.follow_lane(game,player)==-1 and int(player[Cooldowns.STATE].deadline(Cooldowns.R))-Time.get_ticks_msec() < 6000,"paired R consumes the quick-recharge follow-up")


func input_lifecycle() -> void:
	prepare(3,0)
	var input := InputEventAction.new()
	input.action = &"class_skill"
	input.pressed = true
	check(Aim.input_event(game,input),"the press enters the actual input handler")
	var held = Aim.active(game)
	check(is_instance_valid(held) and held.slot==0 and held.drawing.get_surface_count()>0,"holding draws the live aiming mesh")
	check(game.enemy_health()==100 and player[Cooldowns.STATE].deadline(Cooldowns.Q)==0,"the held input has no gameplay effect")
	input.pressed = false
	check(Aim.input_event(game,input),"the release enters the actual input handler")
	check(is_instance_valid(held) and held.slot==-1 and held.drawing.get_surface_count()==0,"release removes the preview")
	check(game.enemy_health()<100 and player[Cooldowns.STATE].deadline(Cooldowns.Q)>Time.get_ticks_msec(),"the real input release casts and starts cooldown")


func run() -> void:
	game = load("res://world.tscn").instantiate()
	game.progress.path = "res://.godot/subclasses-"+str(Time.get_ticks_usec())
	game.local_character.path = game.progress.path+".character"
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.battlefield.configure(0,1,0)
	game.battlefield.procedural = false
	player = game.players[1]
	player.wild = true
	for class_id in range(1,5):
		for lane in 3:
			press_release(class_id,lane)
	input_lifecycle()
	game.queue_free()
	await process_frame
	if not failed:
		print("PASS: four subclass trees, 12 aim and release skills, checkpoint cards, gestures and visible conditions")
	quit(1 if failed else 0)
