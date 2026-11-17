extends SceneTree

const Cooldowns = preload("res://player_cooldowns.gd")

const Preview = preload("res://combat_balance_preview.gd")
const Orb = preload("res://health_orb.gd")
const Core = preload("res://core_combat.gd")

var failed := false


func check(ok: bool, detail: String) -> void:
	if not ok:
		failed = true
		printerr("FAIL CB-02 preview: ", detail)


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	Preview.enabled = true
	Preview.playtest = true
	Preview.strike_rng.seed = 28389
	var game: Node = load("res://world.tscn").instantiate()
	game.progress.path = "res://.godot/combat-preview-" + str(Time.get_ticks_usec()) + ".cfg"
	game.local_character.path = game.progress.path + ".character"
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	var player: Dictionary = game.players[1]
	check(player.hp == 100 and player.max_hp == 100, "new Warden starts at 100 HP")
	player.pos = game.Stage.GATE
	game.enter_wilds(1, player)
	check(player.wild and game.scouts.size() >= 6 and game.enemy_hp in range(62,72), "normal early Wilds entrance uses converted pack and elite")
	check(game.make_scout(0,Vector3.ZERO,1).hp == 32 and game.make_scout(0,Vector3.ZERO,1,0,0,true).hp == 12, "scout and summoned health use the same unit")
	game.map_seed=0
	game.battlefield.configure(0,1)
	game.battlefield.barriers.clear()
	player.pos=Vector3.ZERO
	player.aim_direction=Vector3.BACK
	player.facing=Vector3.BACK
	player.mouse_aim=true
	verify_strikes(game,player)
	verify_multi_target(game,player)
	verify_guard_and_core(game,player)
	verify_healing_rolls(game)
	verify_vitals(game,player)
	verify_health_pool_layout(game, player)
	verify_recovery(game,player)
	verify_orchard(game,player)
	game.queue_free()
	await process_frame
	var menu: Control=load("res://main_menu.tscn").instantiate()
	root.add_child(menu)
	check(menu.storage.root_path==Preview.STORAGE_PATH.path_join("saves") and not menu.import_legacy,"preview menu uses its own Garden and character saves")
	menu.queue_free()
	await process_frame
	if not failed:
		print("PASS: 100 HP Warden, rolled melee, defensive skill, Core, orb, regeneration, revival and Orchard phase parity")
	quit(1 if failed else 0)


func verify_health_pool_layout(game: Node, player: Dictionary) -> void:
	var hud: Control = game.player_hud
	var chart_script := preload("res://exploration.gd")
	player.hp = 54
	player.max_hp = 80
	player.lost_health = 20
	game._process(.016)
	var orb: Control = hud.get_node("HealthPool")
	var compact := chart_script.chart_bounds(hud.size, false)
	check(orb.visible and orb.get_rect().end.x <= compact.position.x, "main orb sits left of the compact floor map")
	check(orb.position.x >= 672 and orb.get_rect().end.y <= hud.size.y, "orb clears the widest action bar at the base viewport")
	check(hud.pool_vitals.text == "54 / 80 HP" and hud.pool_capacity.text == "−20 max HP", "main orb reads health and sealed capacity")
	var material := orb.material as ShaderMaterial
	check(is_equal_approx(material.get_shader_parameter("health"), .54) and is_equal_approx(material.get_shader_parameter("capacity"), .8), "liquid and sealed levels share the correct scale")
	game.exploration.expanded = true
	game._process(.016)
	check(orb.get_rect().end.y < chart_script.chart_bounds(hud.size, true).position.y, "expanded map clears the main orb")
	game.exploration.expanded = false
	player.wild = false
	game._process(.016)
	check(orb.get_rect().end.x > compact.end.x - 8, "Garden places the orb in the lower-right corner")
	player.wild = true
	player.max_hp = 100
	player.lost_health = 0
	player.hp = 100
	game._process(.016)

func verify_strikes(game: Node, player: Dictionary) -> void:
	var expected := {0: Vector2i(8,12), 2: Vector2i(17,23)}
	for weapon in expected:
		player.weapon_kind=weapon
		player.weapon=0
		var band: Vector2i=expected[weapon]
		var seen: Dictionary={}
		for trial in 16:
			player.power=0
			player.strike_at=0
			game.scouts.clear()
			game.projectile_queue.clear()
			game.enemy_hp=600
			game.enemy_mutations=0
			game.enemy_pos=Vector3(0,0,1.4)
			var stats: Dictionary=game.weapon_stats(player)
			check(stats.damage_min==band.x and stats.damage_max==band.y,"loadout resolves the configured band")
			if trial==0:
				check(game.Weapons.describe(stats).contains(Preview.range_label(band)+" damage"),"weapon preview shows that same band")
				var summary: Dictionary=preload("res://run_summary_panel.gd").project(game,player,stats)
				check(summary.totals[0]==["Damage",Preview.range_label(band)],"Tab summary shows the same band")
			game.strike_enemy(1,player,player.pos)
			if game.projectile_queue.is_empty():
				check(false,"attack was committed")
				return
			var shot: Dictionary=game.projectile_queue[0]
			var locked: int=Preview.hp(int(stats.damage))+int(shot.stats.preview_roll_delta)
			player.power=3
			game.update_projectiles(int(shot.due)+1)
			var applied: int=600-game.enemy_hp
			check(applied==locked and applied>=band.x and applied<=band.y,"resolved contact uses the frozen roll and bonus")
			seen[applied]=true
		check(seen.size()>2,"weapon has multiple real roll results")
		player.power=1
		var upgraded: Dictionary=game.weapon_stats(player)
		check(upgraded.damage_min==band.x+10 and upgraded.damage_max==band.y+10,"authored flat bonus moves both endpoints")
	player.power=0


func verify_multi_target(game: Node, player: Dictionary) -> void:
	player.weapon_kind=2
	player.strike_at=0
	game.enemy_hp=600
	game.enemy_pos=Vector3(0,0,1.4)
	game.scouts.clear()
	game.scouts.append(game.make_scout(0,Vector3(.75,0,1.4),1))
	var before: int=game.scouts[0].hp
	game.strike_enemy(1,player,player.pos)
	if game.projectile_queue.is_empty():
		check(false,"multi-target strike commits")
		return
	var shot: Dictionary=game.projectile_queue[0]
	game.update_projectiles(int(shot.due)+1)
	check(game.enemy_hp<600 and before-int(game.scouts[0].hp)==600-game.enemy_hp,"one Maul roll applies to every contact")


func verify_guard_and_core(game: Node, player: Dictionary) -> void:
	player.weapon_kind=0
	player[Cooldowns.STATE] = player[Cooldowns.STATE].with_deadline(Cooldowns.Q, 0)
	player.hp=100
	player.hurt_until=0
	game.use_class_skill(1,player,0)
	check(int(player.guard_charges)>0,"real Warden Guard granted")
	var now:=Time.get_ticks_msec()
	game.apply_enemy_hit(1,player,now,1)
	check(player.hp==100 and int(player.guard_charges)==0,"guard prevents an authored monster hit")
	game.apply_enemy_hit(1,player,now+300,1)
	check(player.hp==90,"a landed authored monster hit removes 10 HP")
	player.weapon=game.Parts.THORN
	player.core_ready_at=0
	player.core_cast_until=0
	player.cast_until=0
	player.attack_until=0
	player.pos=Vector3.ZERO
	game.enemy_hp=600
	game.scouts.clear()
	game.garden_action(1,Core.request(game,player,Vector2(0,1)))
	var line: Dictionary=game.get_meta(Core.STATE,{}).get(1,{})
	check(line.get("skill",{}).get("id","")=="thorn_line","real Warden Core activation")
	if line.is_empty():
		return
	game.enemy_pos=line.center
	Core.tick(game,line.armed)
	check(game.enemy_hp==590,"Thorn Line applies a fixed 10 HP tick")
	Core.reset(game)


func verify_healing_rolls(game: Node) -> void:
	Preview.heal_rng.seed=92123
	var damage_state := Preview.strike_rng.state
	var world_state: int = game.rng.state
	var rolls := {}
	for draw in 80:
		rolls[Preview.roll_heal(1.0)]=true
	check(rolls.size()==5 and rolls.keys().all(func(hp):return hp in range(8,13)),"healing reaches every integer in its displayed band")
	check(Preview.strike_rng.state==damage_state and game.rng.state==world_state,"healing uses an independent random stream")
	var healing_state := Preview.heal_rng.state
	check(Preview.heal_label(1.0)=="8–12 HP" and Preview.heal_label(1.5)=="13–17 HP","five flat HP shifts both bounds equally")
	check(Preview.roll_heal(0.0)==0 and Preview.roll_heal(.1)==1 and Preview.heal_rng.state==healing_state,"display, zero healing and single-value bands consume no roll")
	var revived := {"hp":79,"max_hp":80}
	check(Preview.heal(revived,2.0)==1 and revived.hp==80,"overheal clamps to revived capacity and reports applied HP")
	Preview.enabled=false
	check(Preview.roll_heal(2.0)==2 and Preview.renewal({"hp":3,"max_hp":10})==1,"ordinary mode retains flat authored healing")
	Preview.enabled=true


func verify_recovery(game: Node, player: Dictionary) -> void:
	var ally: Dictionary=game.players[2]
	game.encounter_number=1
	game.depth=1
	game.destination=0
	game.scouts.clear()
	game.enemy_hp=0
	player.pos=game.battlefield.advance
	ally.pos=player.pos
	player.hp=20
	ally.hp=21
	game.use_checkpoint(1,true)
	var floor_heal := int(player.hp)-20
	check(game.encounter_number==2 and floor_heal in range(8,13) and int(ally.hp)-21==floor_heal,"floor recovery shares a roll across the living party")

	ally.pos=player.pos
	player.hp=20
	ally.hp=21
	game.trait_events.clear()
	game.Traits.zone(game,player,"tide",player.pos,2.0,2600,.4,3000)
	game.Traits.tick(game,3000)
	var pulse := int(player.hp)-20
	check(pulse in range(3,6) and int(ally.hp)-21==pulse,"one healing pool pulse shares a roll")
	game.Traits.tick(game,3500)
	check(int(player.hp)-20==pulse,"pool cannot heal between pulses")
	game.trait_events.clear()

	game.battlefield.procedural=false
	game.battlefield.barriers.clear()
	game.scouts.clear()
	var corpse: Dictionary=game.make_scout(0,Vector3.ZERO,1)
	corpse.hp=0
	game.scouts.append(corpse)
	var enemy: Dictionary=game.make_scout(15,Vector3(0,0,1),2)
	enemy.hp=20
	enemy.max_hp=100
	var rite := {"corpse":{"token":corpse.spawn_token,"point":corpse.pos},"from":enemy.pos,"radius":2.0}
	var support=preload("res://enemy_support.gd")
	support.resolve_corpse(game,enemy,rite,4000)
	var restored := int(enemy.hp)
	check(restored-20 in range(18,23),"Pallbearer restoration also rolls in preview HP")
	support.resolve_corpse(game,enemy,rite,4200)
	check(enemy.hp==restored,"spent corpse cannot roll a second heal")


func verify_vitals(game: Node, player: Dictionary) -> void:
	player.hp=20
	player.renewal_until=8000
	player.renewal_tick=1000
	game._process(.016)
	game.update_support_effects(1000)
	game._process(.016)
	var first_hp := int(player.hp)
	check(first_hp-20 in range(3,6) and game.player_hud.health_orb.hp==first_hp and game.player_hud.health_orb.from_hp==20,"orb tracks the first rolled Renewal tick")
	game.update_support_effects(2000)
	game._process(.016)
	check(int(player.hp)-first_hp in range(3,6) and game.player_hud.health_orb.from_hp==first_hp,"second rolled tick gets its own highlight")
	game.add_player(2)
	var helper: Dictionary=game.players[2]
	helper.wild=true
	helper.pos=player.pos
	game.damage_player(1,player,int(player.hp))
	check(player.fallen,"downed player can be revived with a living ally")
	check(game.Life.revive(game,2,1),"revive is accepted")
	game._process(.016)
	check(player.hp==80 and player.max_hp==80 and player.lost_health==20,"revival fills the reduced pool")
	check(Orb.fractions(80,80,20).is_equal_approx(Vector2(.8,.8)),"orb leaves a fifth visibly sealed")
	var rows: Array=game.player_hud.party_panel.members(game.players,2)
	check(rows.size()==1 and rows[0].lost_health==20 and rows[0].hp==80,"compact orb receives only authoritative party vitals")


func verify_orchard(game: Node, player: Dictionary) -> void:
	game.encounter_number=10
	game.depth=4
	game.destination=1
	game.map_seed=91681
	game.boss_floors.clear()
	game.used_bosses.clear()
	game.players[2].profile_ready=false
	game.reset_encounter()
	check(game.boss_kind==game.Bosses.Lair.Routes.ORCHARD and game.enemy_hp==600,"the regular preview route reaches the Orchard on floor 10")
	game.enemy_hp=391
	check(game.Bosses.phase(game)==0,"just above 65 percent")
	game.enemy_hp=390
	check(game.Bosses.phase(game)==1,"below 65 percent")
	game.enemy_hp=180
	check(game.Bosses.phase(game)==2,"at 30 percent")
	game.enemy_mutations=0
	game.enemy_winding_up=false
	game.leader_brain.lair_open={"kind":"uprooting","until":5000}
	game.apply_weapon_hit(player,-1,game.enemy_pos,{"damage":1,"trait_secondary":true},4000)
	check(game.enemy_hp==167,"uprooting adds the preview vulnerability bonus")
