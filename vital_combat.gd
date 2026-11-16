extends RefCounted

const Clock = preload("res://affinity_time.gd")
const SOURCES := "affinity_vital_sources"
const BONUS := "affinity_vital_bonus"
const NEXT := "affinity_vital_tick"
const COLOR := Color("#abd785")
const CORE_RADIUS := 2.65
const WARD_RADIUS := 2.4
const COOLDOWN_MS := 8000
const TICK_MS := 1000
const DURATIONS := {"core": 5500, "form": 2800, "catalyst": 4000}
const QUALITY := {
	"ordinary": {"bonus_hp": 12, "regen_per_second": 3},
	"refined": {"bonus_hp": 18, "regen_per_second": 5},
}
const VERSION_DATA := [CORE_RADIUS, WARD_RADIUS, COOLDOWN_MS, TICK_MS, DURATIONS, QUALITY]


static func description(slot: String, quality: String) -> String:
	var p: Dictionary = QUALITY[quality]
	var line: String = {
		"core": "Vital Bloom · Grants Vitality to you and living allies within %.2f m. %.1f s cooldown." % [CORE_RADIUS, COOLDOWN_MS / 1000.0],
		"form": "Vital Strikes · Grants you Vitality on the first direct hit per weapon attack.",
		"catalyst": "Vital Catalyst · An offensive hit or movement landing grants you Vitality. Mapped heals grant their living recipients Vitality. Actual blocks grant it to the protected player and nearby living allies.",
	}[slot]
	return line + "\n+%d maximum HP without an instant heal, and %d HP/s regeneration for %.1f s. Each benefit uses its strongest active source." % [p.bonus_hp, p.regen_per_second, DURATIONS[slot] / 1000.0]


static func strongest(sources: Dictionary, elapsed: int) -> Vector2i:
	var benefits := Vector2i.ZERO
	for source in sources.values():
		if int(source.start) <= elapsed and int(source.until) > elapsed:
			benefits.x = maxi(benefits.x,int(source.bonus_hp))
			benefits.y = maxi(benefits.y,int(source.regen_per_second))
	return benefits


static func grant(game: Node, event: RefCounted, id: int, elapsed: int) -> void:
	var player: Dictionary = game.players.get(id,{})
	if not game.Life.alive(player):
		return
	var sources: Dictionary = player.get(SOURCES,{})
	# A recipient with ongoing regeneration keeps its next tick. A fully
	# expired effect starts a new cadence and never carries banked ticks.
	if strongest(sources,elapsed).y == 0:
		player[NEXT] = elapsed + TICK_MS
	for key in sources.keys():
		if int(sources[key].until) <= elapsed:
			sources.erase(key)
	var p: Dictionary = event.potency()
	sources["%d/%s" % [event.actor,event.source]] = {
		"bonus_hp":p.bonus_hp, "regen_per_second":p.regen_per_second,
		"start":elapsed, "until":elapsed + int(DURATIONS[event.source]) + int(p.get("duration_bonus_ms",0)), "quality":event.quality, "activation":event.identity, "item":event.material_id,
	}
	player[SOURCES] = sources
	set_capacity(game,player,strongest(sources,elapsed).x)


static func set_capacity(game: Node, player: Dictionary, bonus: int) -> void:
	if bonus == int(player.get(BONUS,0)):
		return
	if bonus == 0: player.erase(BONUS)
	else: player[BONUS] = bonus
	player.max_hp = game.Life.maximum(game,player)
	player.hp = minf(float(player.hp),float(player.max_hp))


static func clear(game: Node, player: Dictionary) -> void:
	player.erase(SOURCES)
	player.erase(NEXT)
	set_capacity(game,player,0)


static func tick(game: Node, elapsed: int) -> void:
	for player in game.players.values():
		if not player.has(SOURCES):
			continue
		if not game.Life.alive(player):
			clear(game,player)
			continue
		var sources: Dictionary = player[SOURCES]
		var benefits := strongest(sources,elapsed)
		if benefits == Vector2i.ZERO:
			clear(game,player)
			continue
		set_capacity(game,player,benefits.x)
		var next: int = player[NEXT]
		while next <= elapsed:
			var regen := strongest(sources,next).y
			if regen > 0:
				game.Life.Vitals.heal(player,regen)
			next += TICK_MS
		player[NEXT] = next
		for key in sources.keys():
			if int(sources[key].until) <= elapsed:
				sources.erase(key)


static func nearby(game: Node, center: Vector3, radius: float) -> Array[int]:
	return game.Life.living_ids(game).filter(func(id):
		var pos: Vector3 = game.players[id].pos
		return center.distance_to(pos) <= radius and game.battlefield.clear_line(center,pos))


static func bloom(game: Node, cast: Dictionary, player: Dictionary, now: int) -> void:
	var center: Vector3 = player.pos
	cast.affinity_action.publish(game,"core_action","bloom","",now,
		{"recipients":nearby(game,center,CORE_RADIUS),"center":center})


static func on_event(game: Node, event: RefCounted, kind: String, details: Dictionary, _now: int) -> void:
	var elapsed := Clock.now(game)
	match kind:
		"core_action", "actual_block":
			var center: Vector3 = details.center
			var radial := kind == "actual_block"
			var radius := WARD_RADIUS if radial else CORE_RADIUS
			game.emit_combat_event("ability","vital_ward" if radial else "vital_bloom",center,center,.55,COLOR,radius,event.actor,
				{"label":"Vital Ward" if radial else "Vital Bloom"})
			for id in nearby(game,center,radius) if radial else details.recipients:
				grant(game,event,id,elapsed)
		"weapon_contact", "class_contact", "class_field_contact":
			if event.take_response("vital_offense"):
				grant(game,event,event.actor,elapsed)
		"class_action":
			match details.get("response", ""):
				"recipient_vitality":
					for id in details.recipients:
						grant(game,event,id,elapsed)
				"landing_vitality":
					grant(game,event,event.actor,elapsed)
				"self_vitality":
					if not details.enemies.is_empty() and event.take_response("vital_offense"):
						grant(game,event,event.actor,elapsed)
