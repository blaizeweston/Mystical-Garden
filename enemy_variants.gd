extends RefCounted
## Authored responses reuse the host world's observed tactics.
const PROFILES := {
 0: {"id":"bark_guard","tactic":"ranged","floor":5,"cue":"Bark Guard"},
 1: {"id":"late_pulse","tactic":"late","floor":7,"cue":"Delayed pulse"},
 2: {"id":"angled_charge","tactic":"choke","floor":5,"cue":"Angled charge"},
 3: {"id":"covered_bell","tactic":"burst","floor":7,"cue":"Covered bell"},
 4: {"id":"leading_pounce","tactic":"kite","floor":5,"cue":"Long pounce"},
 5: {"id":"root_line","tactic":"choke","floor":7,"cue":"Root line"},
 6: {"id":"offset_spores","tactic":"ranged","floor":8,"cue":"Twin spore beds"},
 7: {"id":"fault_stomp","tactic":"burst","floor":9,"cue":"Aftershock"},
 8: {"id":"wide_flank","tactic":"ranged","floor":6,"cue":"Wide flank"},
 9: {"id":"split_nursery","tactic":"late","floor":11,"cue":"Split nursery"},
 10: {"id":"flank_command","tactic":"choke","floor":7,"cue":"Flank order"},
 11: {"id":"planted_canopy","tactic":"ranged","floor":7,"cue":"Planted canopy"},
 12: {"id":"side_lantern","tactic":"kite","floor":8,"cue":"Side lantern"},
 13: {"id":"bent_seam","tactic":"choke","floor":7,"cue":"Bent seam"},
 14: {"id":"split_web","tactic":"choke","floor":8,"cue":"Split web"},
 15: {"id":"long_tether","tactic":"late","floor":8,"cue":"Long tether"},
 16: {"id":"edge_thief","tactic":"late","floor":8,"cue":"Edge rush"},
 17: {"id":"cutoff_charge","tactic":"choke","floor":8,"cue":"Cutoff charge"},
 18: {"id":"early_decoys","tactic":"ranged","floor":8,"cue":"Glass feint"},
 19: {"id":"split_chorus","tactic":"burst","floor":10,"cue":"Split chorus"},
}

static func choose(game: Node, kind: int, route: int) -> String:
 var profile: Dictionary = PROFILES.get(kind, {})
 if profile.is_empty() or game.encounter_number < int(profile.floor):
  return ""
 var key: String = profile.tactic
 var score := 6 if key=="late" else int(game.progress.wilds_memory.score.get(key, 0))
 if key == "ranged": score = maxi(score, int(game.progress.ranged_pressure) * 2)
 if key == "choke": score = maxi(score, int(game.progress.choke_pressure) * 2)
 if key == "burst": score = maxi(score, int(game.progress.burst_pressure) * 2)
 if score < 6:
  return ""
 var roll := posmod(int(game.map_seed) + route * 37 + kind * 19 + int(game.encounter_number) * 11, 10)
 return profile.id if roll < mini(7, 2 + score / 4) else ""

static func cue(variant: String, kind: int) -> String:
 var entry: Dictionary = PROFILES.get(kind, {})
 return str(entry.get("cue", "")) if entry.get("id", "") == variant else ""

static func prepare(game: Node, actor: Dictionary, victim: Vector3, delta: float, now: int) -> bool:
 var variant: String = actor.get("variant", "")
 if variant not in ["angled_charge", "wide_flank"] or actor.get("approach_done", false):
  return false
 var field = game.battlefield
 var origin: Vector3 = actor.pos
 if not actor.has("approach"):
  var forward := (victim - origin).normalized()
  var side := forward.cross(Vector3.UP) * (1.0 if int(actor.route) % 2 == 0 else -1.0)
  var goal := origin + side * (1.35 if variant == "angled_charge" else 1.1)
  if variant == "angled_charge": goal -= forward * .6
  if not field.clear_line(origin, goal, game.Battlefield.CLEARANCE) or not field.clear_line(goal, victim, game.Battlefield.CLEARANCE):
   actor.approach_done = true
   return false
  actor.approach = {"target":goal,"until":now+720}
 var move: Dictionary = actor.approach
 if now >= int(move.until) or origin.distance_to(move.target) < .12 or now < int(actor.rooted_until):
  actor.approach_used=origin.distance_to(move.target)<.12
  actor.erase("approach")
  actor.approach_done = true
  return false
 actor.pos = field.slide(origin, origin.move_toward(move.target, 2.9 * delta))
 return true

static func seam(game: Node, from: Vector3, to: Vector3, route: int) -> Vector3:
 if from.distance_to(to) < 2.4:
  return Vector3.INF
 var side := (to - from).normalized().cross(Vector3.UP)
 for sign_value in ([1.0,-1.0] if route % 2 == 0 else [-1.0,1.0]):
  var via := from.lerp(to,.53)+side * 1.3 * float(sign_value)
  if game.battlefield.clear_line(from,via,game.Battlefield.CLEARANCE) and game.battlefield.clear_line(via,to,game.Battlefield.CLEARANCE):
   return via
 return Vector3.INF

static func cutoff(game: Node, from: Vector3, target: Vector3, route: int) -> Vector3:
 var travel := (target - from).normalized()
 var side := travel.cross(Vector3.UP)
 for sign_value in ([1.0,-1.0] if route % 2 == 0 else [-1.0,1.0]):
  var aim := target + side * 1.55 * float(sign_value)
  var exit := target - side * 2.1 * float(sign_value)
  if game.battlefield.clear_line(from,aim,game.Battlefield.CLEARANCE) and game.battlefield.clear_line(target,exit,game.Battlefield.CLEARANCE):
   return aim
 return target

static func spread(game: Node, origin: Vector3, center: Vector3, offsets: Array[Vector2], clearance: float) -> Array[Vector3]:
 var forward := (center - origin).normalized()
 if forward.is_zero_approx():return []
 var side := forward.cross(Vector3.UP)
 var result: Array[Vector3]=[]
 for offset in offsets:
  var point := center+side*offset.x+forward*offset.y
  if not game.battlefield.clear_line(center,point,clearance):
   return []
  result.append(point)
 return result

static func guards(actor: Dictionary, attacker: Vector3, now: int) -> bool:
 var attack: Dictionary = actor.get("attack",{})
 if attack.get("variant","") != "bark_guard" or int(actor.get("windup",0)) <= now:
  return false
 var origin: Vector3 = attack.from
 var facing: Vector3 = (Vector3(attack.face) - origin).normalized()
 return facing.dot((attacker-origin).normalized()) >= .65
