extends SceneTree

const Rules = preload("res://combat_ruleset.gd")
const Build = preload("res://affinity_build.gd")
const Events = preload("res://combat_action_events.gd")
const Classes = preload("res://class_catalog.gd")
const Parts = preload("res://weapon_parts.gd")
const Cards = preload("res://run_upgrade_catalog.gd")
var failures := 0
var recorded: Array[Dictionary] = []


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL CR02: ", message)


func run() -> void:
	var profiles := check_mappings()
	var game: Node = preload("res://world.tscn").instantiate()
	game.set_meta(Rules.META, Rules.ID)
	game.settings_path = "user://cr02-settings.cfg"
	game.progress.path = "user://cr02-garden.cfg"
	game.local_character.path = "user://cr02-character.cfg"
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.set_meta(Events.RECORD, func(event): recorded.append(event))
	var player: Dictionary = game.players[1]
	player.wild = true
	player.hp = 30
	player.pos = Vector3.ZERO
	game.enemy_hp = 50
	game.enemy_pos = Vector3(0,0,-1)
	game.battlefield.configure(0,1,0)
	game.battlefield.barriers.clear()
	game.scouts.clear()
	player.weapon = Parts.THORN
	player.technique = 80
	player.power = 80
	player.run_upgrades = {"vanguard_briar_wake": 1, "rift_hook": 1}
	player.checkpoint_offers = ["rift_hook"]
	var active: Dictionary = game.weapon_stats(player)
	var native := Build.native_stats(Build.resolve(0,0,[0,0,0],0,player.character))
	check(active.reach == native.reach and active.interval == native.interval and active.class_power == 0 and active.core_build.is_empty(), "old ranks, empty-Core haste and old slot stats are excluded")
	check(Cards.roll(player,6,7,99).is_empty() and Cards.effects(player).is_empty()
		and Cards.core_cards(player,"thorn_line").is_empty()
		and not preload("res://warden_combat.gd").has_card(player,"vanguard_briar_wake"), "offer, modifier and event consumer quarantine")
	var wallet: int = game.run_wallet(player)
	var ranks: Dictionary = player.run_upgrades.duplicate()
	check(not game.buy_upgrade(1,player,0) and game.checkpoint_offer_ids(player).is_empty()
		and game.run_wallet(player)==wallet and player.run_upgrades==ranks
		and player.checkpoint_offers==["rift_hook"], "stale offers cannot purchase and are not erased")
	player.secondary = Parts.THORN
	player.catalyst = Parts.VEIL
	var timers: Array = [player.strike_at,player.skill_at]
	game.strike_enemy(1,player,player.pos)
	game.use_class_skill(1,player,0)
	game.garden_action(1,"core_cast:unavailable")
	check([player.strike_at,player.skill_at] == timers and game.projectile_queue.is_empty()
		and "pending" in game.status, "pending Form, Catalyst and Core do not execute")

	player.secondary = 0
	player.catalyst = 0
	player.character.upgrades[0] = 1 << 1
	game.use_class_skill(1,player,0)
	check(recorded.is_empty() and player.guard_charges==2, "Living Bastion activation grants native Guard only")
	var now := Time.get_ticks_msec()
	game.apply_enemy_hit(1,player,now,1)
	game.apply_enemy_hit(1,player,now+1,1)
	check(recorded.size()==1 and recorded[0].kind=="actual_block" and player.guard_charges==0,
		"actual multi-block Guard records its first consumption once")
	player.skill_two_at=0
	game.use_class_skill(1,player,1)
	check(recorded.size()==2 and recorded[1].kind=="class_action", "actual Root Quake emits one activation")

	player.facing = Vector3.FORWARD
	game.enemy_pos = Vector3(0,0,-1)
	game.strike_enemy(1,player,player.pos)
	game.update_projectiles(Time.get_ticks_msec()+2000)
	check(recorded.size()==3 and recorded[2].kind=="weapon_contact"
		and recorded[2].source=="native_weapon", "native melee labels the real contact separately from the class action")

	# A scoped recording test, with an ally's refined potency snapshot.
	var potency := {"duration_ms": 600, "nested": {"bonus": 7}}
	var material := preload("res://plant_affinities.gd").for_part(Parts.HEARTWOOD)
	var source := Events.begin(game,20,"catalyst",material,potency,["periodic","secondary"],now+1000)
	var refresh := Events.begin(game,20,"catalyst",material,potency,["periodic"],now+1000)
	potency.nested.bonus=100
	check(source.publish(game,"periodic","pulse1","recipient1",now), "first pulse records")
	check(not source.publish(game,"periodic","pulse1","recipient1",now), "duplicate is refused")
	check(source.publish(game,"periodic","pulse1","recipient2",now), "same pulse may reach a second recipient")
	check(source.publish(game,"periodic","pulse2","recipient1",now), "distinct scheduled pulse remains valid")
	check(not source.publish(game,"weapon_contact","pulse2","recipient1",now), "secondary source cannot impersonate a direct hit")
	check(source.publish(game,"secondary","followup","recipient1",now), "explicit secondary event records")
	check(refresh.publish(game,"periodic","pulse1","recipient1",now), "separate activation records independently")
	var sample: Dictionary = recorded[-2]
	check(sample.potency.nested.bonus==7 and sample.source_actor==20 and sample.quality=="refined"
		and sample.stack_source==recorded[-1].stack_source and sample.activation!=recorded[-1].activation, "grant provenance survives, stack key excludes cast ID")
	check(not source.publish(game,"periodic","late","recipient1",now+1000), "expired response is refused")
	var one := Events.begin(game,20,"native_class",{}, {},["actual_block"],now+100,1)
	check(one.publish(game,"actual_block","ward","recipient1",now)
		and not one.publish(game,"actual_block","ward","recipient2",now), "charge scope is enforced")
	game.queue_free()
	await process_frame
	if failures == 0:
		print("PASS: CR02 contracts across ",profiles," skill resolutions and event boundaries")
	quit(int(failures!=0))


func check_mappings() -> int:
	var total := 0
	for class_id in Classes.DEFINITIONS.size():
		var masks: Array[int] = [0, 1 << 1, 1 << 3]
		var frame: Dictionary = Classes.DEFINITIONS[class_id]
		for index in frame.nodes.size():
			masks.append(1 << index)
		for lane in 3:
			masks.append(1 << (Classes.Warden.OFFSET + lane))
			masks.append((1 << (Classes.Warden.OFFSET + lane)) | (1 << 3) | (1 << 11))
		for mask in masks:
			var profile := {"upgrades": [0,0,0,0,0]}
			profile.upgrades[class_id] = mask
			var build := Build.resolve(class_id,2,[Parts.THORN,Parts.MOSS,Parts.VEIL],Parts.HOOK,profile)
			for adapter in build.class_skills:
				check(not adapter.is_empty() and adapter.responses.size()==9
					and not str(adapter.get("id","")).is_empty() and not adapter.response.is_empty(), "explicit adapter for %s mask %s" % [frame.id,mask])
				total += 1
	var base := Build.resolve(0,0,[Parts.THORN, Parts.MOSS, Parts.VEIL],Parts.HOOK,{})
	var refined := Build.resolve(0,0,[Parts.HEARTWOOD, Parts.MOSS, Parts.VEIL],Parts.HOOK,{})
	var other := Build.resolve(0,0,[Parts.THORN, Parts.VEIL, Parts.MOSS],Parts.HOOK,{})
	check(base.core.card_requirements==refined.core.card_requirements
		and base.core.affinity_core_skill_id==refined.core.affinity_core_skill_id
		and base.core.potency_profile.id!=refined.core.potency_profile.id, "quality retains identity and selects its own potency profile")
	check(base.core==other.core and base.form!=other.form and base.catalyst!=other.catalyst
		and Build.native_stats(base)==Build.native_stats(other), "plant slots are isolated from core and native stats")
	check(base.graft.has("native_effects") and not base.core.card_requirements.has("graft"), "graft cannot satisfy plant cards")
	for part in range(1,Parts.DEFINITIONS.size()):
		if not Parts.is_monster(part): continue
		var definition: Dictionary = Parts.MONSTER_DEFINITIONS[int(Parts.DEFINITIONS[part].monster)]
		var build := Build.resolve(0,0,[0,0,0],part,{})
		var effects: Dictionary = build.graft.native_effects.merged(build.graft.pending_effects)
		check(effects==definition.effects, "each native graft effect is applied or explicitly pending")
	return total
