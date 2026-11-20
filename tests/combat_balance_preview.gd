extends SceneTree
const WorldViewCase = preload("res://tests/support/world_presentation_case.gd")
const WeaponCase = preload("res://tests/support/weapon_attack_case.gd")
const OutgoingHits = preload("res://outgoing_hits.gd")
const HitSession = preload("res://network_session.gd")
const ClassActions = preload("res://native_class_actions.gd")
const UIFixture = preload("res://tests/support/gameplay_ui_case.gd")
const Conditions = preload("res://player_hit_conditions.gd")
const Protection = preload("res://player_protection.gd")

const WeaponActions = preload("res://player_weapon_actions.gd")

const SessionCase = preload("res://tests/support/session_case.gd")

const ExpeditionCase = preload("res://tests/support/expedition_case.gd")

const IncomingPlayerHit = preload("res://incoming_player_hit.gd")

const PlayerLifecycle = preload("res://player_lifecycle.gd")

const PlayerVitals = preload("res://player_vitals.gd")

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
	Preview.playtest = true
	Preview.strike_rng.seed = 28389
	var game: Node = load("res://world.tscn").instantiate()
	game.progress.path = "res://.godot/combat-preview-" + str(Time.get_ticks_usec()) + ".cfg"
	game.local_character.path = game.progress.path + ".character"
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	var player: Dictionary = game.players[1]
	player.character[game.Classes.Warden.Connected.PROFILE_KEY]=game.Classes.Warden.Connected.state(["vanguard"])
	check(PlayerVitals.current_hp(player) == 100 and PlayerVitals.maximum_hp(player) == 100, "new Warden starts at 100 HP")
	player.pos = game.stage.gate_position()
	ExpeditionCase.Transitions.enter(game, 1, player)
	check(ExpeditionCase.is_wild(player) and game.encounter.scout_count() >= 6 and game.enemy_health() in range(62,72), "normal early Wilds entrance uses converted pack and elite")
	check(game.make_scout(0,Vector3.ZERO,1).hp == 32 and game.make_scout(0,Vector3.ZERO,1,0,0,true).hp == 12, "scout and summoned health use the same unit")
	ExpeditionCase.set_world(game, {"map_seed": 0})
	game.battlefield.configure(0,1)
	preload("res://tests/support/terrain_case.gd").walls(game.battlefield,[])
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
		print("PASS: 100 HP Warden, rolled melee, defensive skill, Core, orb, healing, revival and Orchard phase parity")
	quit(1 if failed else 0)


func verify_health_pool_layout(game: Node, player: Dictionary) -> void:
	var hud: Control = UIFixture.control(game,"player_hud")
	var chart_script := preload("res://exploration.gd")
	player[PlayerVitals.STATE] = player[PlayerVitals.STATE].with_hp(54)
	player[PlayerVitals.STATE] = player[PlayerVitals.STATE].with_native_max_hp(80)
	player.lost_health = 20
	game._process(.016)
	var orb: Control = hud.get_node("HealthPool")
	var compact := chart_script.chart_bounds(hud.size, false)
	check(orb.visible and orb.get_rect().end.x <= compact.position.x, "main orb sits left of the compact floor map")
	check(orb.position.x >= 672 and orb.get_rect().end.y <= hud.size.y, "orb clears the widest action bar at the base viewport")
	check(hud.pool_vitals.text == "54 / 80 HP" and hud.pool_capacity.text == "−20 max HP", "main orb reads health and sealed capacity")
	var material := orb.material as ShaderMaterial
	check(is_equal_approx(material.get_shader_parameter("health"), .54) and is_equal_approx(material.get_shader_parameter("capacity"), .8), "liquid and sealed levels share the correct scale")
	WorldViewCase.component(game,"map").expanded = true
	game._process(.016)
	check(orb.get_rect().end.y < chart_script.chart_bounds(hud.size, true).position.y, "expanded map clears the main orb")
	WorldViewCase.component(game,"map").expanded = false
	ExpeditionCase.set_membership(game, player, false)
	game._process(.016)
	check(orb.get_rect().end.x > compact.end.x - 8, "Garden places the orb in the lower-right corner")
	ExpeditionCase.set_membership(game, player, true)
	player[PlayerVitals.STATE] = player[PlayerVitals.STATE].with_native_max_hp(100)
	player.lost_health = 0
	player[PlayerVitals.STATE] = player[PlayerVitals.STATE].with_hp(100)
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
			player[WeaponActions.STATE] = player[WeaponActions.STATE].with_ready_at(0)
			game.encounter.clear_scouts()
			game.weapon_attacks.clear()
			game.encounter.set_hp(-1, 600)
			game.enemy_mutations=0
			game.tactics.position=Vector3(0,0,1.4)
			var stats: Dictionary=game.weapon_stats(player)
			check(stats.damage_min==band.x and stats.damage_max==band.y,"loadout resolves the configured band")
			if trial==0:
				check(game.Weapons.describe(stats).contains(Preview.range_label(band)+" damage"),"weapon preview shows that same band")
				var summary: Dictionary=UIFixture.summary(game,player,stats)
				check(summary.totals[0]==["Damage",Preview.range_label(band)],"Tab summary shows the same band")
			WeaponCase.start(game,1,player.pos)
			if game.weapon_attacks.is_empty():
				check(false,"attack was committed")
				return
			var shot: Dictionary=game.weapon_attacks.views()[0]
			var locked: int=Preview.hp(int(stats.damage))+int(shot.stats.preview_roll_delta)
			player.power=3
			WeaponCase.advance(game,int(shot.due)+1)
			var applied: int=600-game.enemy_health()
			check(applied==locked and applied>=band.x and applied<=band.y,"resolved contact uses the frozen roll and bonus")
			seen[applied]=true
		check(seen.size()>2,"weapon has multiple real roll results")
		player.power=1
		var upgraded: Dictionary=game.weapon_stats(player)
		check(upgraded.damage_min==band.x and upgraded.damage_max==band.y,"retired expedition power cannot alter the current damage band")
	player.power=0


func verify_multi_target(game: Node, player: Dictionary) -> void:
	player.weapon_kind=2
	player[WeaponActions.STATE] = player[WeaponActions.STATE].with_ready_at(0)
	game.encounter.set_hp(-1, 600)
	game.tactics.position=Vector3(0,0,1.4)
	game.encounter.clear_scouts()
	game.encounter.register_scout(game.make_scout(0,Vector3(.75,0,1.4),1))
	var before: int=game.encounter.hp(0)
	WeaponCase.start(game,1,player.pos)
	if game.weapon_attacks.is_empty():
		check(false,"multi-target strike commits")
		return
	var shot: Dictionary=game.weapon_attacks.views()[0]
	WeaponCase.advance(game,int(shot.due)+1)
	check(game.enemy_health()<600 and before-int(game.encounter.hp(0))==600-game.enemy_health(),"one Maul roll applies to every contact")


func verify_guard_and_core(game: Node, player: Dictionary) -> void:
	player.weapon_kind=0
	player[Cooldowns.STATE] = player[Cooldowns.STATE].with_deadline(Cooldowns.Q, 0)
	player[PlayerVitals.STATE] = player[PlayerVitals.STATE].with_hp(100)
	player[Conditions.STATE] = player[Conditions.STATE].clear_grace()
	ClassActions.cast_world(game, 1, 0)
	check(int(player[Protection.STATE].charge_count())>0,"real Warden Guard granted")
	var now:=Time.get_ticks_msec()
	var guarded_health: PlayerVitals.Health = player[PlayerVitals.STATE]
	IncomingPlayerHit.resolve_world(game, 1, PlayerLifecycle.generation(player), now, 1)
	check(is_same(player[PlayerVitals.STATE],guarded_health) and int(player[Protection.STATE].charge_count())==0,"guard prevents an authored monster hit before health changes")
	IncomingPlayerHit.resolve_world(game, 1, PlayerLifecycle.generation(player), now+300, 1)
	check(guarded_health.hp()==100.0 and PlayerVitals.current_hp(player)==90.0,"a landed authored monster hit installs exactly 10 HP damage")
	player.weapon=game.Parts.index_of("plant:frostbell")
	player.core_ready_at=0
	player.core_cast_until=0
	player.cast_until=0
	player[WeaponActions.STATE] = player[WeaponActions.STATE].clear_active()
	player.pos=Vector3.ZERO
	game.encounter.set_hp(-1, 600)
	game.encounter.clear_scouts()
	game.garden_action(1,Core.request(game,player,Vector2(0,1)))
	var line: Dictionary=game.effect_timeline.core_records().get(1,{})
	check(line.get("skill",{}).get("id","")=="rime_bloom","actual affinity Core activation")
	if line.is_empty():
		return
	game.tactics.position=line.center
	Core.tick(game,line.armed)
	check(game.enemy_health()==591,"Rime Bloom applies its fixed native 9 HP opening")
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
	var revived := {PlayerVitals.STATE:PlayerVitals.Health.new(79.0, 80)}
	check(Preview.heal(revived,2.0)==1 and PlayerVitals.current_hp(revived)==80,"overheal clamps to revived capacity and reports applied HP")


func verify_recovery(game: Node, player: Dictionary) -> void:
	var ally: Dictionary=game.players[2]
	ExpeditionCase.set_world(game, {"encounter_number": 1})
	ExpeditionCase.set_world(game, {"depth": 1})
	ExpeditionCase.set_world(game, {"destination": 0})
	game.encounter.clear_scouts()
	game.encounter.set_hp(-1, 0)
	player.pos=game.battlefield.advance
	ally.pos=player.pos
	player[PlayerVitals.STATE] = player[PlayerVitals.STATE].with_hp(20)
	ally[PlayerVitals.STATE] = ally[PlayerVitals.STATE].with_hp(21)
	ExpeditionCase.Transitions.checkpoint(game, 1,true)
	var floor_heal := int(PlayerVitals.current_hp(player))-20
	check(game.participation.floor()==2 and floor_heal in range(8,13) and int(PlayerVitals.current_hp(ally))-21==floor_heal,"floor recovery shares a roll across the living party")

	ally.pos=player.pos
	player[PlayerVitals.STATE] = player[PlayerVitals.STATE].with_hp(20)
	ally[PlayerVitals.STATE] = ally[PlayerVitals.STATE].with_hp(21)
	game.effect_timeline.clear_native()
	game.Traits.zone(game,player,"tide",player.pos,2.0,2600,.4,3000)
	game.effect_timeline.advance_native(game.native_effects_world,3000)
	var pulse := int(PlayerVitals.current_hp(player))-20
	check(pulse in range(3,6) and int(PlayerVitals.current_hp(ally))-21==pulse,"one healing pool pulse shares a roll")
	game.effect_timeline.advance_native(game.native_effects_world,3500)
	check(int(PlayerVitals.current_hp(player))-20==pulse,"pool cannot heal between pulses")
	game.effect_timeline.clear_native()


	preload("res://tests/support/terrain_case.gd").walls(game.battlefield,[])
	game.encounter.clear_scouts()
	var corpse: Dictionary=game.make_scout(0,Vector3.ZERO,1)
	corpse.hp=0
	game.encounter.register_scout(corpse)
	var enemy: Dictionary=game.make_scout(15,Vector3(0,0,1),2)
	enemy.hp=20
	enemy.max_hp=100
	game.encounter.register_scout(enemy)
	var rite := {"corpse":{"token":game.encounter.token_for(corpse),"point":corpse.pos},"from":enemy.pos,"radius":2.0}
	var support=preload("res://enemy_support.gd")
	support.resolve_corpse(game,enemy,rite,4000)
	var restored: int = game.encounter.hp_for(enemy)
	check(restored-20 in range(18,23),"Pallbearer restoration also rolls in preview HP")
	support.resolve_corpse(game,enemy,rite,4200)
	check(game.encounter.hp_for(enemy)==restored,"spent corpse cannot roll a second heal")


func verify_vitals(game: Node, player: Dictionary) -> void:
	# Collision-only fixtures omit scenery such as ExitGate. These checks render
	# the real HUD, so restore a complete modern authored floor first.
	game.battlefield.configure(0,1)
	player[PlayerVitals.STATE] = player[PlayerVitals.STATE].with_hp(20)
	game._process(.016)
	game.Life.Sustain.restore(game,player,4,"fixture_heal")
	game._process(.016)
	check(PlayerVitals.current_hp(player)==24 and UIFixture.control(game,"player_hud").health_orb.hp==24 and UIFixture.control(game,"player_hud").health_orb.from_hp==20,"orb tracks a current authoritative heal")
	game.Life.Sustain.restore(game,player,4,"fixture_heal")
	game._process(.016)
	check(PlayerVitals.current_hp(player)==28 and UIFixture.control(game,"player_hud").health_orb.from_hp==24,"separate authoritative heals receive separate highlights")
	game.add_player(2)
	var helper: Dictionary=game.players[2]
	ExpeditionCase.set_membership(game, helper, true)
	helper.pos=player.pos
	IncomingPlayerHit.apply_health_loss(game, 1, PlayerLifecycle.generation(player), int(PlayerVitals.current_hp(player)))
	check(PlayerLifecycle.fallen(player),"downed player can be revived with a living ally")
	check(game.Life.revive(game,2,1),"revive is accepted")
	game._process(.016)
	check(PlayerVitals.current_hp(player)==80 and PlayerVitals.maximum_hp(player)==80 and player.lost_health==20,"revival fills the reduced pool")
	check(Orb.fractions(80,80,20).is_equal_approx(Vector2(.8,.8)),"orb leaves a fifth visibly sealed")
	var rows: Array=UIFixture.control(game,"player_hud").party_panel.members(game.players,2)
	check(rows.size()==1 and rows[0].lost_health==20 and rows[0].hp==80,"compact orb receives only authoritative party vitals")


func verify_orchard(game: Node, player: Dictionary) -> void:
	ExpeditionCase.set_world(game, {"encounter_number": 10})
	ExpeditionCase.set_world(game, {"depth": 4})
	ExpeditionCase.set_world(game, {"destination": 1})
	ExpeditionCase.set_world(game, {"map_seed": 91681})
	game.boss_floors.clear()
	game.used_bosses.clear()
	SessionCase.set_ready(game, game.players[2], false)
	game.reset_encounter()
	check(game.tactics.boss_kind==game.Bosses.Lair.Routes.ORCHARD and game.enemy_health()==600,"the regular preview route reaches the Orchard on floor 10")
	game.encounter.set_hp(-1, 391)
	check(game.Bosses.phase(game)==0,"just above 65 percent")
	game.encounter.set_hp(-1, 390)
	check(game.Bosses.phase(game)==1,"below 65 percent")
	game.encounter.set_hp(-1, 180)
	check(game.Bosses.phase(game)==2,"at 30 percent")
	game.enemy_mutations=0
	game.tactics.winding_up=false
	game.tactics.memory.lair_open={"kind":"uprooting","until":5000}
	OutgoingHits.hit_world(game, HitSession.peer_for(player), -1, game.tactics.position, {"damage":1,"trait_secondary":true}, 4000)
	check(game.enemy_health()==167,"uprooting adds the preview vulnerability bonus")
