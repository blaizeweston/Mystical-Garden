extends RefCounted
## Shared-status phases reuse the real title/Garden/Wilds and RPC fixture.
## Equipment changes below are explicit runtime fixture setup, never a new API.
const Core = preload("res://core_combat.gd")
const Thorn = preload("res://thorn_affinity.gd")
const Fire = preload("res://fire_combat.gd")
const Water = preload("res://water_combat.gd")
const Vital = preload("res://vital_combat.gd")
const Wood = preload("res://wood_affinity.gd")
const Clock = preload("res://affinity_time.gd")
const Vitals = preload("res://player_vitals.gd")
const Life = preload("res://player_lifecycle.gd")
const Protection = preload("res://player_protection.gd")
const Conditions = preload("res://player_hit_conditions.gd")
const Hit = preload("res://incoming_player_hit.gd")
const STEPS := ["thorn","fire","water-a","water-b","wood","vital"]
const MATERIALS := {
	"thorn":["part_1","part_5"],
	"fire":["part_6","plant_part_rare_ember_fern"],
	"water":["part_8","plant_part_rare_dewcap"],
	"wood":["part_17","plant_part_rare_ironroot"],
	"vital":["part_2","plant_part_rare_lantern_moss"],
}

static func cast_all(test: RefCounted, game: Node, actors: Array, events: Array,
		step: String, entry: Vector3, target: Vector3) -> bool:
	var family: String=step.split("-")[0]
	Core.reset(game)
	var before := {}
	var aim := (target-entry).normalized()
	for index in actors.size():
		var id: int=actors[index]
		var player: Dictionary=game.players[id]
		before[id]=events.filter(func(e):return e.kind=="core_action" and e.source_actor==id and e.primary_affinity==family).size()
		var material: Dictionary=game.Items.get_item(MATERIALS[family][index%2])
		if not test.check(material.has("legacy_part"),"shared phase uses a recognized plant material"):return false
		player.weapon=int(material.legacy_part)
		player.secondary=0;player.catalyst=0;player.pos=entry;player.facing=aim
		player.core_ready_at=0;player.core_cast_until=0;player.cast_until=0
		if id!=1: test.mark("shared-"+step+"-"+str(id),"%d|%s|%s" % [player.weapon,aim.x,aim.z])
	game.garden_action(1,Core.request(game,game.players[1],Vector2(aim.x,aim.z),1.1))
	return test.check(await test.until(func():return actors.all(func(id):
		return events.filter(func(e):return e.kind=="core_action" and e.source_actor==id and e.primary_affinity==family).size()>before[id])),
		"four actual "+step+" Core casts are admitted by the authoritative host")

static func host(test: RefCounted, game: Node, guests: Array, events: Array, entry: Vector3, target: Vector3) -> bool:
	var actors := [1]+guests
	var original := {}
	for id in actors:
		var p: Dictionary=game.players[id]
		original[id]=[p.weapon,p.secondary,p.catalyst]
	game.encounter.set_hp(-1,10000)
	game.tactics.stagger_until=Time.get_ticks_msec()+60000
	for index in game.encounter.scout_count(): game.encounter.scout(index).stagger_until=Time.get_ticks_msec()+60000
	game.tactics.memory.clear()
	var extra_position: Vector3=game.encounter.scout(game.encounter.scout_count()-1).pos
	while game.encounter.scout_count()<game.EncounterConfig.MAX_SCOUTS:
		var scout: Dictionary=game.make_scout(0,extra_position,game.encounter.scout_count()+1)
		scout.stagger_until=Time.get_ticks_msec()+60000
		game.encounter.register_scout(scout)
	var pulses := {}
	var sample := {"peak_burning":0}
	var observe := func():
		sample.peak_burning=maxi(int(sample.peak_burning),Fire.count(game.tactics.memory.get(Fire.BURNING,{})))
		for effect: Dictionary in game.combat_events:
			if effect.get("label","")=="Surge": pulses[effect.id]=true
	test.tree.process_frame.connect(observe)
	if not await cast_all(test,game,actors,events,"thorn",entry,target):
		test.tree.process_frame.disconnect(observe);return false
	var four_bleeds := func() -> bool:
		return game.tactics.memory.get(Thorn.BLEED,{}).get("contributors",{}).size()==4
	if not test.check(await test.until(four_bleeds),"all four clients contribute to one enemy Bleed record"):
		test.tree.process_frame.disconnect(observe);return false
	var bleed: Dictionary=game.tactics.memory[Thorn.BLEED]
	test.check(Thorn.cap_units(bleed)==60000 and Thorn.potency_units(bleed)>0,
		"two ordinary and two refined players share exactly one 60 HP tick ceiling")
	print("SHARED_BLEED ",JSON.stringify({"contributors":bleed.contributors.size(),"cap_hp":Thorn.cap_units(bleed)/1000.0,"potency_hp":Thorn.potency_units(bleed)/1000.0}))
	# Isolate the subsequent live Burning cadence from prior accepted wounds.
	Core.reset(game)
	if game.has_meta(Thorn.FIELDS): game.remove_meta(Thorn.FIELDS)
	game.tactics.memory.erase(Thorn.BLEED)
	if not await cast_all(test,game,actors,events,"fire",entry,target):
		test.tree.process_frame.disconnect(observe);return false
	if not test.check(await test.until(func():return game.tactics.memory.get(Fire.BURNING,{}).get("contributors",{}).size()==4),
		"all four clients contribute to one Burning count"):
		test.tree.process_frame.disconnect(observe);return false
	var fire: Dictionary=game.tactics.memory[Fire.BURNING]
	test.check(Fire.count(fire)>0 and fire.contributors.size()==4,"shared live Burning preserves all four contributions without a fixed ceiling")
	print("SHARED_FIRE ",JSON.stringify({"contributors":fire.contributors.size(),"stacks":Fire.count(fire)}))
	test.mark("shared-fire-present")
	await test.sample_host_snapshots(game,guests)
	test.check(int(sample.peak_burning)>96,"independent four-client Fire casts build beyond the former fixed ceiling")
	print("SHARED_FIRE_PEAK ",sample.peak_burning)
	game.tactics.memory.erase(Fire.BURNING)
	for step: String in ["water-a","water-b"]:
		if not await cast_all(test,game,actors,events,step,entry,target):
			test.tree.process_frame.disconnect(observe);return false
		if not test.check(await test.until(func():return game.effect_timeline.core_records().is_empty()),"Dewfall curtains finish their actual sweep"):
			test.tree.process_frame.disconnect(observe);return false
	var water: Dictionary=game.tactics.memory.get(Water.DRENCHED,{})
	test.check(pulses.size()==3 and int(water.get("saturation",-1))==60,
		"two four-client Water applications trigger three Surges and retain 60 overflow without recursion")
	test.check(is_equal_approx(Water.reduction(game.tactics.memory,Clock.now(game)),.30),"four providers retain one bounded Drenched reduction")
	print("SHARED_WATER ",JSON.stringify({"surges":pulses.size(),"saturation":water.get("saturation",-1)}))
	test.mark("shared-water-present")
	if not test.check(await test.until(func():return guests.all(func(id):return test.read("shared-water-seen-"+str(id))=="ok")),
		"each guest receives the authoritative shared Saturation meter"):
		test.tree.process_frame.disconnect(observe);return false
	for id in actors: Wood.clear(game.players[id])
	if not await cast_all(test,game,actors,events,"wood",entry,target):
		test.tree.process_frame.disconnect(observe);return false
	if not test.check(await test.until(func():return actors.all(func(id):return Wood.capacity(Wood.live_grants(game.players[id],Clock.now(game)))==140)),
		"four native Ironbarks fill one additive 140-point Bark pool on every recipient"):
		test.tree.process_frame.disconnect(observe);return false
	var local: Dictionary=game.players[1]
	local[Protection.STATE]=local[Protection.STATE].clear_expedition()
	local[Conditions.STATE]=local[Conditions.STATE].clear_grace()
	var hp: float=Vitals.current_hp(local)
	Hit.resolve_world(game,1,Life.generation(local),Time.get_ticks_msec(),1.0)
	test.check(Vitals.current_hp(local)==hp-6 and Wood.capacity(Wood.live_grants(local,Clock.now(game)))==136,
		"one actual unblocked 10 HP contact consumes four Bark and six HP")
	for id in actors:
		var p: Dictionary=game.players[id]
		Vital.clear(game,p)
		p[Vitals.STATE]=p[Vitals.STATE].with_hp(60)
	if not await cast_all(test,game,actors,events,"vital",entry,target):
		test.tree.process_frame.disconnect(observe);return false
	test.check(actors.all(func(id):return (Vitals.temporary_hp(game.players[id])==18
		and game.players[id].get(Vital.SOURCES,{}).size()==4)),
		"four Vital providers preserve source credit while sharing strongest capacity and regeneration")
	test.tree.process_frame.disconnect(observe)
	if not test.check(await test.until(func():return game.effect_timeline.core_records().is_empty()),"last native Core action completes"):
		return false
	for id in actors:
		var p: Dictionary=game.players[id]
		p.weapon=original[id][0];p.secondary=original[id][1];p.catalyst=original[id][2]
	test.mark("shared-done")
	return not test.failed

static func guest(test: RefCounted, game: Node, id: int) -> bool:
	for step: String in STEPS:
		var marker := "shared-"+step+"-"+str(id)
		if not test.check(await test.until(func():return not test.read(marker).is_empty()),"host begins shared "+step):return false
		var request: PackedStringArray=test.read(marker).split("|")
		var part := int(request[0])
		if not test.check(await test.until(func():return int(game.players[id].get("core_part",0))==part and not Core.cast_key(game,game.players[id]).is_empty()),
			"guest receives current equipment and authoritative action identity for "+step):return false
		game.send_garden_action(Core.request(game,game.players[id],Vector2(float(request[1]),float(request[2])),1.1))
		if step=="fire":
			if not test.check(await test.until(func():return (test.read("shared-fire-present")=="ok"
				and game.guest_combat_events(game.players[id]).any(func(e):return e.kind=="status" and e.shape=="burning" and e.combo==-1 and e.reach>0))),
				"guest receives one live shared Burning intensity"):return false
			await test.sample_guest_snapshots(game,id)
		if step=="water-b":
			if not test.check(await test.until(func():return (test.read("shared-water-present")=="ok"
				and game.guest_combat_events(game.players[id]).any(func(e):return e.kind=="status" and e.shape=="drenched" and e.combo==-1 and int(e.reach)==60))),
				"guest sees the same Saturation overflow through detailed status synchronization"):return false
			test.mark("shared-water-seen-"+str(id))
	return test.check(await test.until(func():return test.read("shared-done")=="ok"),"shared phase completes before actual floor and extraction votes")
