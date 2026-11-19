extends SceneTree
## Public build values, invalidation and real cast/presentation agreement.
const Resolved = preload("res://resolved_combat_build.gd")
const Build = preload("res://affinity_build.gd")
const Cards = preload("res://affinity_cards.gd")
const Catalog = preload("res://affinity_card_catalog.gd")
const Grafts = preload("res://expedition_grafts.gd")
const Classes = preload("res://class_catalog.gd")
const Cooldowns = preload("res://player_cooldowns.gd")
const Preview = preload("res://combat_balance_preview.gd")
const Protection = preload("res://player_protection.gd")
const Balance = preload("res://class_skill_balance.gd")
const BuildView = preload("res://ui/gameplay/player_build_projection.gd")
const Expedition = preload("res://tests/support/expedition_case.gd")
const Sessions = preload("res://tests/support/session_case.gd")
const Actions = preload("res://native_class_actions.gd")
const Transactions = preload("res://game_transaction.gd")
var failed := false

func _initialize() -> void: call_deferred("run")

func check(ok: bool, label: String) -> void:
	if not ok:
		failed = true
		printerr("FAIL resolved build: ",label)

func copy(id: String, rarity: int, identity: int) -> Dictionary:
	return {"id":id,"rarity":Catalog.RARITIES[rarity],"amount":Catalog.DEFINITIONS[id].values[rarity],"acquisition_id":identity,"floor":3}

func purchase(world: Node, actor: Dictionary, ledger: Grafts.Ledger, floor_number: int, id: String) -> Grafts.Ledger:
	var carried: Array = world.Parts.empty_counts()
	carried[world.Items.get_item("monster_0").legacy_part] = 4
	var data := ledger.details(floor_number)
	var intent := {"run":data.run,"floor":floor_number,"revision":data.revision,"id":id,"item":"monster_0"}
	var projector: Callable = world.combat_build(actor).graft_value_resolver(world.MAX_HEALTH,0,0)
	var plan := ledger.plan_purchase(intent,floor_number,carried,projector)
	check(plan.has("ledger"),"public graft plan has useful resolved values: "+id)
	return plan.get("ledger",ledger)

func run() -> void:
	var world: Node = load("res://world.tscn").instantiate()
	var base := "res://.godot/resolved-build-"+str(OS.get_process_id())
	world.progress.path=base+".garden";world.local_character.path=base+".character"
	world.guest_character.path=base+".guest";world.settings_path=base+".settings"
	root.add_child(world)
	world.set_process(false);world.set_physics_process(false)
	var actor: Dictionary=world.players[1]
	Sessions.set_ready(world,actor,true);Expedition.set_membership(world,actor,true)
	actor.pos=Vector3.ZERO;actor.facing=Vector3.BACK
	actor.weapon=0;actor.secondary=0;actor.catalyst=0
	world.encounter.clear_scouts();world.encounter.set_hp(-1,1000)
	world.tactics.position=Vector3(0,0,1);world.enemy_kind=0;world.enemy_mutations=0;world.enemy_growth=0;world.tactics.boss_kind=-1
	preload("res://tests/support/terrain_case.gd").walls(world.battlefield,[])
	var rng_before := [world.rng.state,Preview.strike_rng.state,Preview.heal_rng.state]
	# Cheap source-equivalence control for all fifteen real weapon definitions.
	for class_id in Classes.DEFINITIONS.size():
		actor.frame=class_id
		var tree=Classes.connected_tree(class_id)
		actor.character[tree.profile_key]=tree.state([tree.nodes[1].id])
		for weapon_index in 3:
			actor.weapon_kind=weapon_index
			var native := Build.native_stats(Build.for_player(actor))
			native.affinity_build=Build.for_player(actor);native.class_power=0
			var band := Preview.weapon_range(native,0)
			native.damage_min=band.x;native.damage_max=band.y
			check(world.weapon_stats(actor)==native,"native wire/combat values retain the authored weapon: %d/%d"%[class_id,weapon_index])
	check([world.rng.state,Preview.strike_rng.state,Preview.heal_rng.state]==rng_before,"resolving values consumes no combat RNG")
	actor.frame=1;actor.weapon_kind=0
	var tree=Classes.connected_tree(1)
	actor.character.xp[1]=2600
	actor.character[tree.profile_key]=tree.state([tree.nodes[1].id])
	var original = world.combat_build(actor)
	var count: int=world.combat_builds.compilation_count()
	check(is_same(original,world.combat_build(actor)) and world.combat_builds.compilation_count()==count,"unchanged facts reuse the same immutable value")
	actor.character.monsters[0]+=1
	check(is_same(original,world.combat_build(actor)),"unrelated monster familiarity cannot invalidate class combat values")
	var detached: Dictionary=original.native_stats()
	detached.affinity_build.class_skills[0].native_skill.weaver_nodes.clear()
	detached.damage=900
	check(tree.focus(actor.character)=="bloomcaller" and world.weapon_stats(actor).damage!=900,"inspection cannot edit profiles or cached values")
	var records: Array[Dictionary]=[copy("ordinary_weapon_damage",0,1),copy("ordinary_weapon_interval",1,2),copy("nova_impact",2,3),copy("run_dodge_recovery",0,4)]
	var run := Cards.Ledger.new(records)
	actor[Cards.STATE]=run
	var armed = world.combat_build(actor)
	check(not is_same(original,armed),"a new acquired-card ledger invalidates the derived value")
	var native: Dictionary=armed.native_stats()
	var basic: Dictionary=armed.basic_stats()
	check(is_equal_approx(basic.damage,float(native.damage)+float(records[0].amount)/Preview.scale())
		and basic.interval==Cards.attack_interval(int(native.interval),int(records[1].amount)),"basic damage and attack speed use actual acquired contributions once")
	check(armed.class_skill(0).get("damage",0)==original.class_skill(0).get("damage",0)
		and is_equal_approx(armed.class_skill(1).damage,float(original.class_skill(1).damage)+float(records[2].amount)/Preview.scale()),"native R card is shared while basic bonuses stay separate from Q/R")
	var hints: Array=armed.tooltips()
	check(hints[1].contains(Preview.range_label(Vector2i(Preview.effect_hp(armed.class_skill(1).damage),Preview.effect_hp(armed.class_skill(1).damage)))+" HP"),"class tooltip reflects its real card-enhanced R damage")
	var before: int=world.enemy_health()
	Actions.cast_world(world,1,1)
	check(before-world.enemy_health()==Preview.effect_hp(armed.class_skill(1).damage),"real Spore Nova consumes the same resolved damage shown by its tooltip")
	var running: int=actor[Cooldowns.STATE].deadline(Cooldowns.R)
	var facts: Dictionary=world.run_summary_ui_data()
	var shown := BuildView.summary(facts)
	check(shown.totals.any(func(row): return row[0]=="Attack speed" and row[1]==Preview.attack_speed(int(basic.interval))+" attacks/sec"),"Tab attack speed agrees with the actual launch value")
	var dodge_before := preload("res://combat_clock.gd").now()
	world.dodge_player(1,Vector2.RIGHT)
	var dodge_after := preload("res://combat_clock.gd").now()
	check(actor[Cooldowns.STATE].deadline(Cooldowns.DODGE)>=dodge_before+armed.dodge_ms(world.DODGE_COOLDOWN_MS)
		and actor[Cooldowns.STATE].deadline(Cooldowns.DODGE)<=dodge_after+armed.dodge_ms(world.DODGE_COOLDOWN_MS),"dodge recovery uses the same bounded value as Stats")
	var loadout=load("res://loadout_panel.gd").new();root.add_child(loadout)
	loadout.present(world.loadout_ui_data())
	check(loadout.description.text.contains(str(Preview.effect_hp(armed.class_skill(1).damage))+" HP"),"standalone loadout description uses resolved class-card damage")
	loadout.free()
	var lineage: Array=actor.character[tree.profile_key].path.duplicate()
	actor.character[tree.profile_key].path.append(tree.nodes[3].id)
	check(not is_same(armed,world.combat_build(actor)),"in-place connected-node selection invalidates the cache")
	actor.character[tree.profile_key].path=lineage
	check(world.combat_build(actor).class_skill(1)==armed.class_skill(1),"respec/rollback of selections restores their original meaning")
	var first_graft := Grafts.Ledger.new(52)
	actor[Grafts.STATE]=first_graft
	first_graft=purchase(world,actor,first_graft,8,"reach")
	actor[Grafts.STATE]=first_graft
	var extended = world.combat_build(actor)
	check(is_equal_approx(float(extended.basic_stats().reach),float(basic.reach)+float(Grafts.REINFORCEMENTS.reach.amount)/100.0)
		and extended.native_stats().reach==native.reach,"ordinary graft reach cannot leak into native class stats")
	var faster := purchase(world,actor,first_graft,16,"cooldown")
	actor[Grafts.STATE]=faster
	var quickened = world.combat_build(actor)
	check(quickened.tooltips()!=extended.tooltips() and actor[Cooldowns.STATE].deadline(Cooldowns.R)==running,"graft cooldown refreshes tooltips without rewriting a running timer")
	# All three equipment slots and the equipped weapon are invalidation inputs.
	for field in ["weapon","secondary","catalyst"]:
		var old = world.combat_build(actor)
		actor[field]=world.Items.get_item("plant_part_rare_dewcap").legacy_part
		check(not is_same(old,world.combat_build(actor)),"slot change invalidates: "+field)
	actor.weapon_kind=1
	check(world.combat_build(actor).native_stats().id==Classes.DEFINITIONS[1].weapons[1].id,"weapon delivery changes invalidate values")
	actor.prepared=0;actor.prepared_secondary=0;actor.prepared_catalyst=0
	var prepared = world.combat_build(actor,true)
	check(prepared.affinity_build().core.state=="empty" and prepared.native_stats().get("skill_cooldown",0)==0
		and prepared.basic_stats().damage==Classes.DEFINITIONS[1].weapons[1].damage,"prepared equipment cannot inherit active run cards or grafts")
	var current = world.combat_build(actor)
	var wire: Dictionary=current.native_stats()
	var projected: Array=Cards.project_owned(actor,wire,world.DODGE_COOLDOWN_MS)
	var guest := Resolved.Cache.new()
	var received = guest.received(wire,Cards.applied_totals(projected))
	check(received.basic_stats()==current.basic_stats() and received.class_skills()==current.class_skills(),"guest reconstructs the same values from unchanged reliable details")
	wire.damage+=1
	check(not is_same(received,guest.received(wire,Cards.applied_totals(projected))) and received.native_stats().damage!=wire.damage,"in-place accepted details refresh cannot edit an older snapshot")
	var verdict := {}
	var old_run = Cards.ledger(actor)
	var old = world.combat_build(actor)
	var result = Transactions.run(world,func():
		actor[Cards.STATE]=Cards.Ledger.new()
		world.combat_build(actor)
		preload("res://save_batch.gd").record_serializer_error(ERR_FILE_CANT_WRITE,world.progress.path)
		return true,verdict)
	check(not result and Cards.ledger(actor)==old_run and world.combat_build(actor).basic_stats()==old.basic_stats(),"confirmed transaction rollback cannot retain a new contribution cache")
	Expedition.set_world(world,{"encounter_number":2})
	check(world.combat_build(actor).basic_stats()==old.basic_stats(),"floor travel preserves the current run contributions")
	Expedition.set_membership(world,actor,false)
	check(world.combat_build(actor).native_stats().get("skill_cooldown",0)==0,"Garden return cannot retain run grafts")
	for index in 20:
		actor.weapon_kind=index%3
		actor.character.xp[1]=index
		world.combat_build(actor)
	check(world.combat_builds.entry_count()<=Resolved.MAX_CACHED_BUILDS,"bounded eviction never accumulates per-peer histories")
	var skill_api: Script = load("res://skill_catalog.gd")
	check(not skill_api.get_script_method_list().any(func(entry): return entry.name=="wild_tooltips")
		and not world.has_meta("class_skill_tooltip_stats"),"obsolete metadata tooltip cache is retired")
	# Flat Chime cards previously affected real Wards but not the description.
	Expedition.set_membership(world,actor,true)
	actor.frame=4;actor.weapon_kind=0;actor.weapon=0;actor.secondary=0;actor.catalyst=0;actor.pos=Vector3.ZERO
	actor.erase(Grafts.STATE)
	actor[Cards.STATE]=Cards.Ledger.new([copy("chime_ward_time",2,7)])
	actor[Cooldowns.STATE]=actor[Cooldowns.STATE].with_deadline(Cooldowns.R,0)
	actor[Protection.STATE]=actor[Protection.STATE].clear_expedition()
	var oracle=world.combat_build(actor)
	var chime: Dictionary=oracle.class_skill(1)
	var expected_ms:=int(chime.duration)+int(chime.get("ward_ms",0))
	var before_chime:=preload("res://combat_clock.gd").now()
	Actions.cast_world(world,1,1)
	var after_chime:=preload("res://combat_clock.gd").now()
	check(oracle.tooltips()[1].contains("for "+Balance.seconds(expected_ms))
		and actor[Protection.STATE].guard_until_ms()>=before_chime+expected_ms
		and actor[Protection.STATE].guard_until_ms()<=after_chime+expected_ms,"Chime tooltip and real Ward include the same card duration")
	world.free()
	if not failed: print("PASS: shared combat values, fifteen native weapons, live class/card/graft/UI agreement, cache invalidation, rollback and guest projection")
	quit(1 if failed else 0)
