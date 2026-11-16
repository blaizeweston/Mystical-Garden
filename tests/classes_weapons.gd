extends SceneTree
const Catalog=preload("res://class_catalog.gd")
const Parts=preload("res://weapon_parts.gd")
const Weapons=preload("res://weapon_system.gd")
const Character=preload("res://character_profile.gd")
const Progress=preload("res://progress.gd")
var game: Node
var failed:=false
func check(ok: bool,message: String):
	if not ok: failed=true;printerr("FAIL classes: ",message)
func _initialize():
	preload("res://combat_balance_preview.gd").enabled = false
	call_deferred("run")
func arena(p: Dictionary):
	game.scouts.clear()
	game.battlefield.procedural=false
	game.battlefield.barriers=[]
	game.enemy_hp=100
	game.enemy_pos=Vector3.ZERO
	game.enemy_winding_up=false
	game.enemy_mutations=0
	game.enemy_engaged=true
	game.enemy_stagger_until=0
	game.depth=1
	game.destination=0
	p.wild=true
	p.pos=Vector3(0,0,-1)
	p.weapon=0
	p.secondary=0
	p.catalyst=0
	p.graft_part=0
	p.power=0
	p.technique=0
	p.skill_at=0
	p.focus_until=0
	p.renewal_until=0
	p.guard_until=0
	p.strike_at=0
	p.max_hp=10
	p.hp=5
	p.character=Character.blank()
func run():
	game=load("res://world.tscn").instantiate()
	var token:=Crypto.new().generate_random_bytes(8).hex_encode()
	game.progress.path="res://.godot/class_test_"+token+".cfg"
	game.local_character.path=game.progress.path+".character"
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	var p: Dictionary=game.players[1]
	check(Catalog.DEFINITIONS.size()==5 and Parts.DEFINITIONS.size()>=27,"five roles, plant materials and ten trophies")
	var names: Dictionary={}
	for c in Catalog.DEFINITIONS.size():
		check(Catalog.DEFINITIONS[c].weapons.size()==3 and Catalog.DEFINITIONS[c].nodes.size()==12,"three weapons and six choice rows per class")
		for w in 3:
			var d: Dictionary=Catalog.DEFINITIONS[c].weapons[w]
			names[d.name]=true
			var visual: Node3D=preload("res://weapon_visuals.gd").build(game.stage,c,w)
			check(visual.get_child_count()>0,"weapon model "+d.name)
			visual.free()
	check(names.size()==15,"fifteen unique weapon identities")
	var profile:=Character.blank()
	var core:=Weapons.resolve(0,0,[1,0,0],0,0,profile)
	var form:=Weapons.resolve(0,0,[0,1,0],0,0,profile)
	var catalyst:=Weapons.resolve(0,0,[0,0,1],0,0,profile)
	check(core.reach>form.reach and form.pattern=="line" and int(form.targets)>int(core.targets) and catalyst.interval<450,"same tag changes result by slot")
	var steam:=Weapons.resolve(0,0,[6,8,0],0,0,profile)
	check(steam.interactions.has("Steam Bloom"),"cross-slot tag interaction")
	var invalid:=Weapons.resolve(0,0,[Parts.HOOK,0,0],0,0,profile)
	check(float(invalid.get("pull",0))==0,"monster materials rejected in plant slots")
	var graft:=Weapons.resolve(0,0,[0,0,0],Parts.HOOK,0,profile)
	check(float(graft.pull)>0,"monster graft actually modifies weapon")
	var legacy:=Character.normalize({"xp":[12,7],"plants":[4,5,6],"monsters":[2,3],"traits":[1,2]})
	check(legacy.xp.size()==5 and legacy.xp.slice(0,2)==[120,70] and legacy.monsters.size()==preload("res://enemy_catalog.gd").all().size() and legacy.monsters.slice(0,2)==[2,3] and legacy.loadouts.size()==5,"legacy characters migrate without losing progress")
	for c in 5:
		p.wild=false
		p.pos=game.Stage.HEART
		p.character=Character.blank()
		p.character.xp[c]=int(game.Character.LEVEL_THRESHOLDS.back())
		game.select_class(1,p,c)
		for tier in 4:
			var choice: int=Catalog.Warden.OFFSET+tier*3
			game.handle_loadout_action(1,p,"learn_%d_%d"%[c,choice])
			check(bool(int(p.character.upgrades[c]) & (1<<choice)),"choice learned with prerequisites")
			var mask: int=p.character.upgrades[c]
			game.handle_loadout_action(1,p,"learn_%d_%d"%[c,choice+1])
			check(int(p.character.upgrades[c])==mask,"alternative in same row cannot be stacked")
		if c==0:
			check(Catalog.Warden.focus(p.character)=="vanguard" and Catalog.Warden.learned(p.character,"cracking_roots"),"Warden learns subclass and modifiers")
		else:
			check(not Catalog.focus_id(p.character,c).is_empty() and game.Skills.resolve(c,0,p.character).mode=="subclass","subclass and connected modifiers resolve")
		var saved:=Character.normalize(p.character)
		check(saved.upgrades[c]==p.character.upgrades[c],"class choices survive profile normalization")
		game.handle_loadout_action(1,p,"respec_%d"%c)
		check(p.character.upgrades[c]==0,"Garden refunds class choices")
	# Reserve duplicate plant materials and transfer cargo without installing it.
	p.character=Character.blank()
	game.select_class(1,p,2)
	game.progress.parts.fill(0)
	game.progress.personal_parts.fill(0)
	game.progress.parts[0]=1
	p.prepared=1
	p.prepared_secondary=1
	p.prepared_catalyst=1
	p.pos=game.Stage.GATE
	game.enter_wilds(1,p)
	check(not p.wild and game.progress.parts[0]==1,"duplicate slots require combined material quantity")
	game.progress.parts[0]=3
	game.progress.personal_parts[Parts.HOOK]=2
	p.cargo_plan[Parts.HOOK]=2
	game.enter_wilds(1,p)
	check(p.wild and game.progress.parts[0]==0 and [p.weapon,p.secondary,p.catalyst]==[1,1,1],"three slots consume three actual materials")
	check(p.carried_parts[Parts.HOOK]==2 and game.progress.personal_parts[Parts.HOOK]==0 and p.graft_part==0,"stash monster cargo is carried without pre-installing")
	game.encounter_number=game.GRAFT_ROOM
	game.reset_encounter()
	p.pos=game.battlefield.entry
	var amount: int=p.carried_parts[Parts.HOOK]
	game.attempt_graft(1,p)
	check(p.graft_part==0 and p.carried_parts[Parts.HOOK]==amount,"no graft away from altar")
	p.wild=false
	p.pos=game.battlefield.graft
	game.attempt_graft(1,p)
	check(p.graft_part==0,"no monster graft in the Garden")
	p.wild=true
	p.carried_parts.fill(0)
	p.carried_parts[1]=2
	p.graft_choice=1
	game.attempt_graft(1,p)
	check(p.graft_part==0 and p.carried_parts[1]==2,"plant cannot occupy monster slot")
	p.carried_parts[Parts.HOOK]=20
	p.graft_choice=Parts.HOOK
	game.rng.seed=2
	for attempt in 20:
		if p.graft_part!=0: break
		var before: int=p.carried_parts[Parts.HOOK]
		game.attempt_graft(1,p)
		check(p.carried_parts[Parts.HOOK]==before-1,"success or failure consumes exactly one trophy")
	check(p.graft_part==Parts.HOOK and p.secondary==1 and p.catalyst==1,"fourth slot preserves all plant slots")
	amount=p.carried_parts[Parts.HOOK]
	game.attempt_graft(1,p)
	check(p.carried_parts[Parts.HOOK]==amount,"filled monster slot cannot consume another trophy")
	game.return_to_garden(p)
	check(p.graft_part==0 and p.carried_parts[Parts.HOOK]==0,"failure loses unbanked cargo and clears graft")
	# Attack shapes affect real enemies.
	arena(p)
	p.frame=0
	var scout: Dictionary=game.make_scout(0,Vector3(.4,0,.3),1)
	scout.hp=20
	scout.engaged=true
	game.scouts.assign([scout])
	game.strike_enemy(1,p,p.pos)
	game.update_projectiles(Time.get_ticks_msec()+1000)
	check(game.scouts[0].hp==20,"plain single-target weapon stays single-target")
	p.strike_at=0
	p.secondary=1
	game.strike_enemy(1,p,p.pos)
	game.update_projectiles(Time.get_ticks_msec()+1000)
	check(game.scouts[0].hp<20,"Form piercing tag causes real line attack")
	for c in 5:
		arena(p)
		p.frame=c
		p.weapon_kind=0
		var old: Vector3=p.pos
		var now:=Time.get_ticks_msec()
		game.send_garden_action("class_skill")
		game.update_projectiles(Time.get_ticks_msec()+600)
		check(p.skill_at>now,"unique class skill starts cooldown")
		match c:
			0: check(p.guard_until>now,"Warden guards")
			1: check(game.rooted_until>now,"Weaver binds")
			2: check(game.enemy_hp<100,"Ranger volley attacks")
			3: check(p.pos.distance_to(old)>.1 and game.enemy_hp<100,"Reaper safely steps and strikes")
			4: check(p.hp>=7,"Oracle renews health")
	arena(p)
	p.frame=4
	p.catalyst=8
	var cast_time:=Time.get_ticks_msec()
	game.send_garden_action("class_skill")
	check(int(p.get("renewal_until",0))-cast_time>=2300,"Catalyst duration extends Oracle regrowth")
	var health: float=p.hp
	game.update_support_effects(cast_time+1100)
	check(p.hp==health+1,"Renewal regrowth performs real healing")
	var bonus_profile:=Character.blank()
	bonus_profile.upgrades[0]=1 << 4
	var extra_targets:=Weapons.resolve(0,0,[0,0,0],0,0,bonus_profile)
	check(extra_targets.targets==2 and extra_targets.pattern=="sweep","extra-target upgrades produce a valid multi-target pattern")
	# Unique monster stash and class-save round trips.
	p.wild=false
	game.progress.add_parts(26,3)
	check(game.progress.save_garden()==OK,"save monster stash")
	var loaded:=Progress.new()
	loaded.path=game.progress.path
	check(loaded.load_garden()==OK and loaded.part_count(26)==3,"unique monster stash survives reload")
	for kind in 10:
		var part:=Parts.monster_part(kind)
		check(Parts.is_monster(part) and Parts.DEFINITIONS[part].monster==kind,"monster source identity")
	game._process(.016)
	game.toggle_overlay(game.loadout_menu)
	game.loadout_view.refresh()
	game.toggle_overlay(game.progression_menu)
	game.progression_view.tabs.current_tab=2
	game.progression_view.refresh()
	check(game.progression_view.tree.nodes.size()==13,"class view shows origin and twelve selectable upgrades")
	if not failed: print("PASS: five classes, fifteen weapons, tagged slots, choices, migration, cargo costs, altar-only monster grafts, patterns and class skills")
	quit(1 if failed else 0)

