extends SceneTree

const WeaponActions = preload("res://player_weapon_actions.gd")

const ExpeditionCase = preload("res://tests/support/expedition_case.gd")

const PlayerVitals = preload("res://player_vitals.gd")

const Preview = preload("res://combat_balance_preview.gd")
const Summary = preload("res://run_summary_panel.gd")
const SPREADS := [2,2,3, 2,1,3, 2,4,2, 1,3,2, 2,3,1]

var failed := false


func check(ok: bool, detail: String) -> void:
	if not ok:
		failed=true
		printerr("FAIL CB-03: ",detail)


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	Preview.strike_rng.seed=71893
	var game: Node=load("res://world.tscn").instantiate()
	game.progress.path="res://.godot/cb03-weapons-"+str(Time.get_ticks_usec())+".cfg"
	game.local_character.path=game.progress.path+".character"
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	var p: Dictionary=game.players[1]
	ExpeditionCase.set_membership(game, p, true)
	p[PlayerVitals.STATE] = p[PlayerVitals.STATE].with_hp(100)
	p.pos=Vector3.ZERO
	p.mouse_aim=true
	p.facing=Vector3.BACK
	p.aim_direction=Vector3.BACK
	game.battlefield.configure(0,1)
	game.battlefield.barriers.clear()
	game.tactics.boss_kind=-1
	game.enemy_kind=0
	verify_catalogue(game,p)
	verify_roster(game,p)
	verify_delivery(game,p)
	verify_profile(game,p)
	game.queue_free()
	await process_frame
	if not failed:
		print("PASS: 15 weapons, 72 components, shared native ranges, melee, projectiles, misses, native pierce/chain and profile references")
	quit(1 if failed else 0)


func equip(p: Dictionary, class_id: int, weapon: int) -> void:
	p.frame=class_id
	var graph=preload("res://class_catalog.gd").connected_tree(class_id)
	p.character[graph.profile_key]=graph.state([graph.nodes[0].id])
	p.weapon_kind=weapon
	p.weapon=0
	p.secondary=0
	p.catalyst=0
	p[WeaponActions.STATE] = p[WeaponActions.STATE].with_ready_at(0)


func clear_targets(game: Node, at: Vector3) -> void:
	game.encounter.clear_scouts()
	game.projectile_queue.clear()
	game.combat_events.clear()
	game.trait_events.clear()
	game.enemy_traits.clear()
	game.encounter.set_hp(-1, 600)
	game.tactics.position=at
	game.enemy_mutations=0
	game.tactics.winding_up=false


func verify_catalogue(game: Node, p: Dictionary) -> void:
	equip(p,0,0)
	var plants:=0
	var grafts:=0
	for part in range(1,game.Parts.DEFINITIONS.size()):
		var entry: Dictionary=game.Parts.DEFINITIONS[part]
		var id: String=entry.id
		check(game.Parts.index_of(id)==part and game.Items.get_item(entry.item_id).legacy_part==part,"stable ID "+id)
		if game.Parts.is_plant(part):
			plants+=1
			for slot in 3:
				var parts: Array=[0,0,0];parts[slot]=part
				var build:=preload("res://affinity_build.gd").resolve(0,0,parts,p.character)
				check(build[["core","form","catalyst"][slot]].executable,"explicit material identity in slot "+str(slot)+" "+id)
		elif game.Parts.is_monster(part):
			grafts+=1
	check(plants==48 and grafts==24,"all 72 existing components are covered")


func verify_roster(game: Node, p: Dictionary) -> void:
	for class_id in game.Classes.DEFINITIONS.size():
		for weapon in game.Classes.DEFINITIONS[class_id].weapons.size():
			equip(p,class_id,weapon)
			var base: Dictionary=game.Classes.DEFINITIONS[class_id].weapons[weapon]
			var spread: int=SPREADS[class_id*3+weapon]
			var band:=Vector2i(int(base.damage)*10-spread,int(base.damage)*10+spread)
			var stats: Dictionary=game.weapon_stats(p)
			var label:=Preview.range_label(band)
			check(stats.damage_min==band.x and stats.damage_max==band.y,"authored spread for "+base.name)
			check(game.Weapons.describe(stats).contains(label+" damage") and Summary.project(game,p,stats).totals[0]==["Damage",label],"matching previews for "+base.name)
			var reach:=3.0 if game.WeaponMotion.is_projectile(str(base.visual)) else 1.35
			clear_targets(game,Vector3(0,0,reach))
			game.strike_enemy(1,p,p.pos)
			if game.projectile_queue.is_empty():
				check(false,"attack queued for "+base.name)
				continue
			var shot: Dictionary=game.projectile_queue[0]
			var roll: int=shot.stats.preview_strike_hp
			check(roll>=band.x and roll<=band.y,"committed roll for "+base.name)
			game.update_projectiles(int(shot.due)+500)
			check(game.enemy_health()==600-roll,"actual hit uses the committed roll for "+base.name)


func verify_delivery(game: Node,p: Dictionary) -> void:
	equip(p,2,1)
	clear_targets(game,Vector3(0,0,2))
	game.encounter.register_scout(game.make_scout(0,Vector3(0,0,4.1),1))
	var scout_before: int=game.encounter.hp(0)
	game.strike_enemy(1,p,p.pos)
	var shot: Dictionary=game.projectile_queue[0]
	var roll: int=shot.stats.preview_strike_hp
	game.update_projectiles(int(shot.due)+500)
	check(game.enemy_health()==600-roll and game.encounter.hp(0)==maxi(0,scout_before-roll),"piercing contacts share one roll")
	equip(p,2,2)
	clear_targets(game,Vector3(0,0,2))
	game.encounter.register_scout(game.make_scout(0,Vector3(1.6,0,2.1),1))
	scout_before=game.encounter.hp(0)
	game.strike_enemy(1,p,p.pos)
	shot=game.projectile_queue[0]
	roll=shot.stats.preview_strike_hp
	game.update_projectiles(int(shot.due)+500)
	check(game.enemy_health()==600-roll and game.encounter.hp(0)==maxi(0,scout_before-roll),"chain contacts share one roll")
	equip(p,2,0)
	clear_targets(game,Vector3(5,0,1.4))
	game.strike_enemy(1,p,p.pos)
	shot=game.projectile_queue[0]
	game.update_projectiles(int(shot.due)+500)
	check(game.enemy_health()==600 and game.combat_events.all(func(event):return event.shape!="hit"),"miss has no damage or hit feedback")


func verify_profile(game: Node,p: Dictionary) -> void:
	var profile: Dictionary=game.Character.blank()
	profile.active_class=2
	profile.loadouts[2]={"weapon":1,"parts":[game.Parts.THORN,game.Parts.VEIL,game.Parts.HEARTWOOD]}
	game.local_character.data=profile
	check(game.local_character.save_profile()==OK,"save existing-format weapon references")
	var reload=game.Character.new()
	reload.path=game.local_character.path
	check(reload.load_profile()==OK,"reload existing-format profile")
	p.character=reload.data
	game.restore_class_loadout(p)
	check(p.frame==2 and p.weapon_kind==1 and [p.prepared,p.prepared_secondary,p.prepared_catalyst]==profile.loadouts[2].parts,"crafted loadout keeps its stable references")
