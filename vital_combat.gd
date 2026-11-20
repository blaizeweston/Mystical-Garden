extends RefCounted

const Sources = preload("res://affinity_status_source.gd")
const Lifecycle = preload("res://player_lifecycle.gd")
const PlayerVitals = preload("res://player_vitals.gd")
const Clock = preload("res://affinity_time.gd")
const SOURCES := "affinity_vital_sources"
const NEXT := "affinity_vital_tick"
const COLOR := Color("#abd785")
const CORE_RADIUS := 2.65
const WARD_RADIUS := 2.4
const COOLDOWN_MS := 8000
# Harvest foundation only until the player-choice action is explicitly approved.
# Damage is whole HP after one final rounding. These are not card definitions.
const HARVEST_DAMAGE_PER_HP := 1.0
const NORMAL_HP_SAFETY_FRACTION := .50
const TICK_MS := 1000
const DURATIONS := {"core": 5500, "form": 2800, "catalyst": 4000}
const QUALITY := {
	"ordinary": {"bonus_hp": 12, "regen_per_second": 3},
	"refined": {"bonus_hp": 18, "regen_per_second": 5},
}
const VERSION_DATA := [CORE_RADIUS, WARD_RADIUS, COOLDOWN_MS, TICK_MS, DURATIONS, QUALITY, HARVEST_DAMAGE_PER_HP, NORMAL_HP_SAFETY_FRACTION]


static func description(slot: String, quality: String, resolved: Dictionary = {}) -> String:
	var p: Dictionary = QUALITY[quality] if resolved.is_empty() else resolved
	var line: String = {
		"core": "Vital Bloom · Grants Vitality to you and living allies within %.2f m. %.1f s cooldown." % [CORE_RADIUS, COOLDOWN_MS / 1000.0],
		"form": "Vital Strikes · Grants you Vitality on the first direct hit per weapon attack.",
		"catalyst": "Vital Catalyst · An offensive hit or movement landing grants you Vitality. Mapped heals grant their living recipients Vitality. Actual blocks grant it to the protected player and nearby living allies.",
	}[slot]
	return line + "\n+%d maximum HP without an instant heal, and %d HP/s regeneration for %.1f s. Each benefit uses its strongest active source." % [p.bonus_hp, p.regen_per_second, (int(DURATIONS[slot])+int(p.get("duration_bonus_ms",0))) / 1000.0]


static func strongest(sources: Dictionary, elapsed: int) -> Vector2i:
	var benefits := Vector2i.ZERO
	for source in sources.values():
		if int(source.start) <= elapsed and int(source.until) > elapsed:
			benefits.x = maxi(benefits.x,int(source.bonus_hp))
			benefits.y = maxi(benefits.y,int(source.regen_per_second))
	return benefits


## Expiring grants belong to the recipient. An accepted ally benefit finishes
## after provider loss, but cannot cross the recipient's life or floor boundary.
static func live_sources(game: Node, player: Dictionary, elapsed: int, include_expired := false) -> Dictionary:
	var result := {}
	for key in player.get(SOURCES,{}):
		var row: Dictionary=player[SOURCES][key]
		if int(row.epoch)==game.participation.epoch() and Lifecycle.matches(player,int(row.recipient_life)) \
				and (include_expired or int(row.until)>elapsed): result[key]=row
	return result

static func grant(game: Node, event: RefCounted, id: int, elapsed: int) -> void:
	var player: Dictionary=game.players.get(id,{})
	var origin := Sources.capture(event)
	if not game.multiplayer.is_server() or not game.Life.alive(player) or not Sources.current(game,origin): return
	var sources := live_sources(game,player,elapsed)
	if strongest(sources,elapsed).y==0: player[NEXT]=elapsed+TICK_MS
	var p: Dictionary=event.potency()
	# Different magnitudes keep independent expirations, including from the
	# same provider/slot. Weak reapplication never replaces/prolongs strength.
	var key: String=Sources.key(origin)+"/"+event.source+"/%d/%d" % [p.bonus_hp,p.regen_per_second]
	var row := origin.duplicate(true)
	row.merge({"bonus_hp":p.bonus_hp,"regen_per_second":p.regen_per_second,"start":elapsed,
		"until":elapsed+int(DURATIONS[event.source])+int(p.get("duration_bonus_ms",0)),
		"recipient_life":Lifecycle.generation(player)},true)
	sources[key]=row
	player[SOURCES]=sources
	set_capacity(game,player,strongest(sources,elapsed).x)

## A quote is not an action. No control, card acquisition or automatic drain is
## installed here. A future explicit action must validate its life/cast and
## commit health_after once, then resolve damage as secondary native HP.
static func harvest_plan(health: PlayerVitals.Health, allow_normal := false,
		safety_fraction := NORMAL_HP_SAFETY_FRACTION, efficiency := HARVEST_DAMAGE_PER_HP) -> Dictionary:
	if not is_finite(safety_fraction) or safety_fraction<=0.0 or safety_fraction>1.0 \
			or not is_finite(efficiency) or efficiency<=0.0:
		return {"accepted":false,"spent_hp":0.0,"damage_hp":0,"health_before":health,"health_after":health}
	var floor_hp := float(health.native_max_hp())*(safety_fraction if allow_normal else 1.0)
	var after := health.spent(health.hp(),floor_hp)
	var spent := health.hp()-after.hp()
	var damage := roundi(spent*efficiency)
	var accepted := spent>0.0 and damage>0
	var result := {"accepted":accepted,"spent_hp":spent if accepted else 0.0,"damage_hp":damage if accepted else 0,
		"health_before":health,"health_after":after if accepted else health,"minimum_hp":floor_hp}
	result.make_read_only()
	return result


static func set_capacity(game: Node, player: Dictionary, bonus: int) -> void:
	var vitals: PlayerVitals.Health = player[PlayerVitals.STATE]
	if bonus == vitals.temporary_hp():
		return
	var native_capacity: int = game.Life.native_maximum(game,player)
	player[PlayerVitals.STATE] = vitals.with_capacity(native_capacity,bonus)


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
		var sources := live_sources(game,player,elapsed,true)
		player[SOURCES]=sources
		var benefits := strongest(sources,elapsed)
		if benefits == Vector2i.ZERO:
			clear(game,player)
			continue
		set_capacity(game,player,benefits.x)
		var next: int = player[NEXT]
		while next <= elapsed:
			var regen := strongest(sources,next).y
			if regen > 0:
				player[PlayerVitals.STATE] = player[PlayerVitals.STATE].healed(regen)
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
