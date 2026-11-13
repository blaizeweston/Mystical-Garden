extends SceneTree

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
	Preview.enabled=true
	Preview.strike_rng.seed=71893
	var game: Node=load("res://world.tscn").instantiate()
	game.progress.path="res://.godot/cb03-weapons-"+str(Time.get_ticks_usec())+".cfg"
	game.local_character.path=game.progress.path+".character"
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	var p: Dictionary=game.players[1]
	p.wild=true
	p.hp=100
	p.pos=Vector3.ZERO
	p.mouse_aim=true
	p.facing=Vector3.BACK
	p.aim_direction=Vector3.BACK
	game.battlefield.configure(0,1)
	game.battlefield.barriers.clear()
	game.boss_kind=-1
	game.enemy_kind=0
	verify_catalogue(game,p)
	verify_roster(game,p)
	verify_delivery(game,p)
	verify_components(game,p)
	verify_graft(game,p)
	verify_profile(game,p)
	game.queue_free()
	await process_frame
	if not failed:
		print("PASS: 15 weapons, 72 components, shared ranges, melee, projectiles, misses, pierce, chain, delayed effects and live graft replacement")
	quit(1 if failed else 0)


func equip(p: Dictionary, class_id: int, weapon: int) -> void:
	p.frame=class_id
	p.weapon_kind=weapon
	p.weapon=0
	p.secondary=0
	p.catalyst=0
	p.graft_part=0
	p.power=0
	p.strike_at=0


func clear_targets(game: Node, at: Vector3) -> void:
	game.scouts.clear()
	game.projectile_queue.clear()
	game.combat_events.clear()
	game.trait_events.clear()
	game.enemy_traits.clear()
	game.enemy_hp=600
	game.enemy_pos=at
	game.enemy_mutations=0
	game.enemy_winding_up=false


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
				var slots: Array=[0,0,0]
				slots[slot]=part
				var result: Dictionary=game.Weapons.resolve(0,0,slots,0,0,p.character)
				check(entry.tags.all(func(tag):return result.tags.has(tag)),"plant tags resolve in slot "+str(slot)+" "+id)
				var band:=Preview.weapon_range(result,0)
				check(band.x>0 and band.y>band.x,"plant keeps a valid damage band")
		elif game.Parts.is_monster(part):
			grafts+=1
			var result: Dictionary=game.Weapons.resolve(0,0,[0,0,0],part,0,p.character)
			check(entry.tags.all(func(tag):return result.tags.has(tag)),"graft tags resolve "+id)
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
			check(game.Weapons.describe(stats).contains(label+" damage") and Summary.project(game,p,stats).totals[0][1]==label+" HP","matching previews for "+base.name)
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
			check(game.enemy_hp==600-roll,"actual hit uses the committed roll for "+base.name)


func verify_delivery(game: Node,p: Dictionary) -> void:
	equip(p,2,0)
	p.graft_part=game.Parts.monster_part(13)
	clear_targets(game,Vector3(0,0,2))
	game.scouts.append(game.make_scout(0,Vector3(0,0,4.1),1))
	var scout_before: int=game.scouts[0].hp
	game.strike_enemy(1,p,p.pos)
	var shot: Dictionary=game.projectile_queue[0]
	var roll: int=shot.stats.preview_strike_hp
	game.update_projectiles(int(shot.due)+500)
	check(game.enemy_hp==600-roll and game.scouts[0].hp==scout_before-roll,"piercing contacts share one roll")
	equip(p,2,2)
	clear_targets(game,Vector3(0,0,2))
	game.scouts.append(game.make_scout(0,Vector3(1.6,0,2.1),1))
	scout_before=game.scouts[0].hp
	game.strike_enemy(1,p,p.pos)
	shot=game.projectile_queue[0]
	roll=shot.stats.preview_strike_hp
	game.update_projectiles(int(shot.due)+500)
	check(game.enemy_hp==600-roll and game.scouts[0].hp==scout_before-roll,"chain contacts share one roll")
	equip(p,2,0)
	clear_targets(game,Vector3(5,0,1.4))
	game.strike_enemy(1,p,p.pos)
	shot=game.projectile_queue[0]
	game.update_projectiles(int(shot.due)+500)
	check(game.enemy_hp==600 and game.combat_events.all(func(event):return event.shape!="hit"),"miss has no damage or hit feedback")
	equip(p,2,0)
	clear_targets(game,Vector3(0,0,2))
	game.scouts.append(game.make_scout(0,Vector3(1.5,0,2),1))
	scout_before=game.scouts[0].hp
	var parent: Dictionary={"damage":1.0,"preview_strike_hp":11,"preview_roll_delta":1,"link_damage":.35,"link":1}
	game.Traits.queue_hit(game,p,0,parent,1000,100,true)
	game.Traits.tick(game,1100)
	check(game.scouts[0].hp==scout_before-9,"delayed link uses half of the frozen 11 HP plus its fractional bonus")


func verify_components(game: Node,p: Dictionary) -> void:
	equip(p,0,0)
	p.secondary=game.Parts.HEARTWOOD
	var stats: Dictionary=game.weapon_stats(p)
	check(stats.damage_min==13 and stats.damage_max==17,"half-strength Form keeps five HP of the Barb's strike damage")
	var barb: Dictionary=game.Items.get_item(game.Items.part_id(game.Parts.HEARTWOOD))
	check(game.Items.describe(barb).contains("+10 HP strike damage"),"Barb tooltip shows its full-strength effect")
	equip(p,0,0)
	p.secondary=game.Parts.VEIL
	clear_targets(game,Vector3(0,0,1.35))
	game.enemy_winding_up=true
	stats=game.weapon_stats(p)
	var extra:=Preview.effect_hp(float(stats.windup_damage))
	check(extra>0 and extra%10!=0,"a Veilcap Form retains fractional wind-up damage")
	game.strike_enemy(1,p,p.pos)
	var shot: Dictionary=game.projectile_queue[0]
	var roll: int=shot.stats.preview_strike_hp
	game.update_projectiles(int(shot.due)+500)
	check(game.enemy_hp==600-roll-extra,"confirmed wind-up bonus matches the resolved amount")
	equip(p,0,0)
	p.graft_part=game.Parts.monster_part(6)
	p.hp=60
	clear_targets(game,Vector3(0,0,1.4))
	game.scouts.append(game.make_scout(0,Vector3(.4,0,1),1))
	game.scouts[0].hp=3
	game.apply_weapon_hit(p,0,p.pos,game.weapon_stats(p),2000)
	check(int(p.hp) in range(68,73),"Orchid Sac rolls 8–12 HP once on a confirmed kill")


func verify_graft(game: Node,p: Dictionary) -> void:
	equip(p,2,0)
	p.graft_part=game.Parts.monster_part(4)
	p.graft_floor=8
	var antler: int=game.Parts.monster_part(2)
	p.carried_parts[antler]=1
	game.encounter_number=16
	p.pos=game.battlefield.graft
	clear_targets(game,p.pos+Vector3.BACK*3.1)
	var prior: Dictionary=game.weapon_stats(p)
	var offer: Dictionary=game.graft_menu_data(p).options[0]
	check(offer.part==antler and offer.preview.contains("8–12 damage"),"the candidate graft shows the resulting range")
	game.strike_enemy(1,p,p.pos)
	var shot: Dictionary=game.projectile_queue[0]
	var roll: int=shot.stats.preview_strike_hp
	game.update_projectiles(int(shot.release))
	check(shot.emitted and game.enemy_hp==600,"arrow is in flight")
	install_graft(game,p,antler)
	check(p.graft_part==antler and p.carried_parts[antler]==0,"regular graft action replaces the Fang")
	game.update_projectiles(int(shot.due)+500)
	check(game.enemy_hp==600-roll and roll>=prior.damage_min and roll<=prior.damage_max,"the in-flight arrow keeps the old component's roll")
	var after: Dictionary=game.weapon_stats(p)
	check(after.damage_min==8 and after.damage_max==12,"the next attack uses the new graft")
	var carapace: int=game.Parts.monster_part(11)
	game.encounter_number=24
	p.carried_parts[carapace]=1
	p.hp=70
	install_graft(game,p,carapace)
	check(p.graft_part==carapace and p.max_hp==120 and p.hp==70,"the new graft grants capacity without healing")
	game.encounter_number=32
	p.carried_parts[antler]=1
	p.hp=110
	install_graft(game,p,antler)
	check(p.graft_part==antler and p.max_hp==100 and p.hp==100,"losing the graft clamps health to the new capacity")


func install_graft(game: Node,p: Dictionary,part: int) -> void:
	var random:=RandomNumberGenerator.new()
	for seed_value in 500:
		random.seed=seed_value
		if random.randf()<game.graft_chance(p,part):
			game.rng.seed=seed_value
			game.attempt_graft(1,p,part)
			return
	check(false,"fixture can seed a successful graft")


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
