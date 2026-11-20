extends RefCounted
## An inert valid record for capacity fixtures; it cannot damage or grant effects.
static func add_inert(world: Node) -> void:
 var actor: Dictionary=world.players[world.HOST]
 world.effect_timeline.schedule_native({"kind":"hit","owner":world.HOST,
  "epoch":world.participation.epoch(),"life":preload("res://player_lifecycle.gd").generation(actor),
  "binding":world.network_session.binding(world.HOST),"due":0x7fffffffffffffff,
  "target":-2,"token":-1,"stats":{},"origin":Vector3.ZERO})
static func fill(world: Node) -> void:
 while world.effect_timeline.native_count()<world.effect_timeline.NATIVE_LIMIT:add_inert(world)
