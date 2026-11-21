extends RefCounted
## Stateless composition. Each family owns its own short-lived speed record.
static func temporary_percent(world: Node, player: Dictionary, now: int) -> int:
 return load("res://fire_combat.gd").tempo_percent(world,player,now)+load("res://storm_affinity.gd").tempo_percent(world,player,now)+load("res://spirit_affinity.gd").tempo_percent(world,player,now)
static func interval(base_ms: int, percent: int) -> int:
 return load("res://fire_combat.gd").interval_with_tempo(base_ms,percent)
