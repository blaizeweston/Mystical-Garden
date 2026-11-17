extends SceneTree

const PlayerVitals = preload("res://player_vitals.gd")

const Cooldowns = preload("res://player_cooldowns.gd")
const Skills=preload("res://skill_catalog.gd")
const Character=preload("res://character_profile.gd")
var game: Node
var failed:=false
func check(value: bool,message: String):
	if not value: failed=true;printerr("FAIL dual skills: ",message)
func _initialize(): call_deferred("run")
func arena(c: int,mask: int=0) -> Dictionary:
	var p: Dictionary=game.players[1]
	game.encounter.clear_scouts()
	game.battlefield.procedural=false
	game.battlefield.barriers=[]
	game.tactics.position=Vector3.ZERO
	game.encounter.set_hp(-1, 80)
	game.enemy_mutations=0
	game.tactics.engaged=true
	game.tactics.winding_up=false
	game.tactics.rooted_until=0
	game.tactics.stagger_until=0
	game.destination=0
	game.depth=1
	p.frame=c
	p.weapon_kind=0
	p.weapon=0
	p.secondary=0
	p.catalyst=0
	p.graft_part=0
	p.wild=true
	p.pos=Vector3(0,0,-1.5)
	p.facing=Vector3.BACK
	p[PlayerVitals.STATE] = p[PlayerVitals.STATE].with_hp(5)
	p[PlayerVitals.STATE] = p[PlayerVitals.STATE].with_native_max_hp(10)
	p[Cooldowns.STATE] = p[Cooldowns.STATE].with_deadline(Cooldowns.Q, 0)
	p[Cooldowns.STATE] = p[Cooldowns.STATE].with_deadline(Cooldowns.R, 0)
	p.strike_at=0
	p.guard_until=0
	p.guard_charges=0
	p.focus_until=0
	p.renewal_until=0
	p.technique=0
	p.power=0
	p.character=Character.blank()
	p.character.xp[c]=int(game.Character.LEVEL_THRESHOLDS.back())
	p.character.active_class=c
	p.character.upgrades[c]=mask
	game.local_character.data=p.character
	return p
func run():
	game=load("res://world.tscn").instantiate()
	var token:=Crypto.new().generate_random_bytes(8).hex_encode()
	game.progress.path="res://.godot/dual_skill_"+token+".cfg"
	game.local_character.path=game.progress.path+".character"
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	var names: Dictionary={}
	for c in 5:
		for slot in 2:
			var skill:=Skills.resolve(c,slot,Character.blank())
			names[skill.name]=true
			var p:=arena(c)
			var before: Vector3=p.pos
			game.send_garden_action("class_skill" if slot==0 else "class_skill_two")
			check(p[Cooldowns.STATE].deadline(Cooldowns.Q if slot==0 else Cooldowns.R)>Time.get_ticks_msec(),"base skill casts through action dispatch: "+skill.name)
			if slot==0: check(p[Cooldowns.STATE].deadline(Cooldowns.R)==0,"Q leaves R cooldown ready")
			else: check(p[Cooldowns.STATE].deadline(Cooldowns.Q)==0,"R leaves Q cooldown ready")
			match str(skill.mode):
				"guard": check(p.guard_charges==1 and p.guard_until>Time.get_ticks_msec(),"Guard blocks one attack")
				"quake": check(game.enemy_health()<80 and game.tactics.stagger_until>Time.get_ticks_msec(),"Quake damages and staggers")
				"bind": check(game.tactics.rooted_until>Time.get_ticks_msec(),"Rootbind roots")
				"nova": check(game.enemy_health()<80 and game.tactics.rooted_until>Time.get_ticks_msec(),"Nova damages and roots")
				"volley":
					game.update_projectiles(Time.get_ticks_msec()+600)
					check(game.enemy_health()<80 and p.focus_until>Time.get_ticks_msec(),"Volley empowers strikes")
				"snare":
					check(game.enemy_health()==80 and game.tactics.rooted_until==0,"Bramble Snare has an arming delay")
					game.Traits.tick(game,Time.get_ticks_msec()+300)
					check(game.enemy_health()<80 and game.tactics.rooted_until>Time.get_ticks_msec(),"Bramble Snare roots after arming")
				"reap":
					game.update_projectiles(Time.get_ticks_msec()+1000)
					check(p.pos.distance_to(before)>.1 and game.enemy_health()<80,"Reaping Step approaches safely")
				"siphon": check(game.enemy_health()<80 and PlayerVitals.current_hp(p)>5,"Siphon Cut drains health")
				"heal": check(PlayerVitals.current_hp(p)>5 and p.renewal_until>Time.get_ticks_msec(),"Renewal heals and grants regrowth")
				"ward": check(p.guard_charges==1,"Warding Chime guards")
			var seq: int=p.skill_fx_seq
			game.send_garden_action("class_skill" if slot==0 else "class_skill_two")
			check(p.skill_fx_seq==seq,"cooldown rejects repeat casts")
	check(names.size()==10,"ten distinct starting skills")
	# All replacement modes must function, preserving the original eight-bit profile schema.
	for c in 5:
		var profile:=Character.blank()
		profile.xp[c]=int(game.Character.LEVEL_THRESHOLDS.back())
		profile.upgrades[c]=170
		var normalized:=Character.normalize(profile)
		check(normalized.upgrades[c]==170,"replacement/mastery choices normalize without loss")
		for slot in 2:
			var p:=arena(c,170)
			var skill:=Skills.resolve(c,slot,p.character)
			names[skill.name]=true
			check(skill.variant=="replacement","class choice replaces the selected slot")
			game.send_garden_action("class_skill" if slot==0 else "class_skill_two")
			check(p[Cooldowns.STATE].deadline(Cooldowns.Q if slot==0 else Cooldowns.R)>Time.get_ticks_msec(),"replacement casts: "+skill.name)
			match str(skill.mode):
				"bastion": check(p.guard_charges>=2,"Bastion grants layered guard")
				"charge","harvest": check(game.enemy_health()<80 and not game.battlefield.occupied(p.pos,.34),"replacement approach is safe and attacks")
				"strangle": check(game.enemy_health()<80 and game.tactics.rooted_until>Time.get_ticks_msec(),"Strangling Bloom damages and roots")
				"snare_field":
					game.Traits.tick(game,Time.get_ticks_msec()+300)
					check(game.tactics.rooted_until>Time.get_ticks_msec(),"Mycelial Snare roots after arming")
				"salvo": check(game.enemy_health()<80,"Piercing Salvo damages")
				"windstep": check(p.pos.z< -1.6 and p.focus_until>Time.get_ticks_msec(),"Windstep withdraws and empowers")
				"bloodmoon": check(game.enemy_health()<80 and PlayerVitals.current_hp(p)>5,"Blood Moon drains")
				"sanctuary": check(p.renewal_until>Time.get_ticks_msec() and p.guard_charges>=1,"Sanctuary protects and regenerates")
				"judgement": check(game.enemy_health()<80 and game.tactics.recovery_bonus>=700,"Judgement prolongs recovery")
	check(names.size()==20,"ten distinct replacement skills")
	for c in 5:
		var p:=arena(c,85)
		for slot in 2:
			var skill:=Skills.resolve(c,slot,p.character)
			var base:=Skills.resolve(c,slot,Character.blank())
			check(skill.augmented and skill.variant=="base" and skill.cooldown<base.cooldown,"augmentation keeps identity and improves cooldown")
	# Normal R input uses second skill in the Wilds, research in the Garden.
	var p:=arena(0)
	game.send_garden_action("class_skill")
	var q_timer: int=p[Cooldowns.STATE].deadline(Cooldowns.Q)
	var key:=InputEventKey.new()
	key.physical_keycode=KEY_R
	key.pressed=true
	game._unhandled_key_input(key)
	check(p[Cooldowns.STATE].deadline(Cooldowns.R)==0,"holding R leaves the second cooldown untouched")
	key.pressed=false
	game._input(key)
	check(p[Cooldowns.STATE].deadline(Cooldowns.R)>0 and p[Cooldowns.STATE].deadline(Cooldowns.Q)==q_timer,"releasing R casts slot two independently")
	p.wild=false
	p.pos=game.Stage.HEART
	game.progress.studying_flowering=false
	game.progress.flowering_unlocked=false
	key.pressed=true
	game._unhandled_key_input(key)
	key.pressed=false
	game._input(key)
	check(not game.progress.studying_flowering,"retired Garden R does not trigger research")
	# Failed targeted casts do not spend cooldowns.
	p=arena(1)
	p.pos=Vector3(20,0,20)
	game.send_garden_action("class_skill")
	check(p[Cooldowns.STATE].deadline(Cooldowns.Q)==0,"out-of-range cast preserves cooldown")
	p=arena(1)
	game.battlefield.barriers=[Rect2(-.6,-.6,1.2,.35)]
	game.send_garden_action("class_skill_two")
	check(game.enemy_health()==80 and game.tactics.rooted_until==0,"area skills cannot hit through cover")
	# Guards refresh safely after expiration; plant Catalyst still modifies both skills.
	p=arena(0)
	p.guard_until=1
	p.guard_charges=4
	game.grant_guard(p,Time.get_ticks_msec()+1000,1)
	check(p.guard_charges==1,"expired guard does not retain stale charges")
	p=arena(4)
	p.catalyst=8
	var now:=Time.get_ticks_msec()
	game.send_garden_action("class_skill")
	check(p.renewal_until-now>=2300,"Catalyst extends Q duration")
	game.send_garden_action("class_skill_two")
	check(p.guard_until-now>=1800,"Catalyst extends R duration")
	game._process(.016)
	check(game.player_hud.state.skill_names.size()==2 and not game.player_hud.state.skill_two_ready,"HUD exposes both skill names and cooldowns")
	var snapshot: Dictionary=game.player_snapshot(1)[1]
	check(snapshot.skill_cooldowns.size()==2 and snapshot.has("skill_two_ready") and not snapshot.skill_fx.is_empty(),"private cooldown and public effect metadata")
	# Skill replacements and augments persist entirely in existing class-choice masks.
	var profile:=Character.new()
	profile.path=game.progress.path+".skills"
	profile.data=p.character.duplicate(true)
	profile.data.upgrades[4]=170
	check(profile.save_profile()==OK,"save skill build")
	var loaded:=Character.new()
	loaded.path=profile.path
	check(loaded.load_profile()==OK and Skills.resolve(4,1,loaded.data).name=="Judgement Bell","skill replacements survive save/load")
	if not failed: print("PASS: ten base skills, ten replacements, augments, independent Q/R cooldowns, input context, cover, Catalyst, guard refresh, HUD and saves")
	quit(1 if failed else 0)

