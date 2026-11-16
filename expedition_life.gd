extends RefCounted
const Vitals=preload("res://combat_vitals.gd")
const Preview=preload("res://combat_balance_preview.gd")
const Sustain=preload("res://expedition_sustain.gd")
const REVIVE_COST:=Vitals.REVIVE_POINTS*Vitals.LIVE_HP_PER_POINT
const REVIVE_REACH:=1.65
static func alive(p: Dictionary) -> bool:
 return p.get("wild",false) and not p.get("fallen",false) and float(p.get("hp",0))>0
static func living_ids(game: Node) -> Array[int]:
 var ids: Array[int]=[]
 for id in game.players:
  if alive(game.players[id]): ids.append(int(id))
 ids.sort();return ids
static func maximum(game: Node,p: Dictionary,prepared := false) -> int:
 return native_maximum(game,p,prepared)+int(p.get("affinity_vital_bonus",0))
static func native_maximum(game: Node,p: Dictionary,prepared := false) -> int:
 var extra := preload("res://affinity_cards.gd").amount(p,"run_health") if not prepared else 0
 return Vitals.maximum(Preview.hp(game.MAX_HEALTH),Preview.effect_hp(Preview.authored_amount(float(game.weapon_stats(p,prepared).get("max_health",0))))+extra,int(p.get("lost_health",0)),Preview.scale())
static func down(game: Node,id: int,p: Dictionary,effects = null) -> void:
 p.hp=0;p.fallen=true;p.velocity=Vector3.ZERO;p.attack_until=0;p.swing_until=0
 p.erase("affinity_ward_claims");p.erase("frost_response");p.erase("affinity_ember_response")
 preload("res://vital_combat.gd").clear(game,p)
 preload("res://wood_affinity.gd").clear(p)
 preload("res://storm_affinity.gd").clear(p)
 preload("res://spirit_affinity.gd").clear(p)
 preload("res://native_grafts.gd").clear(p)
 p.erase("affinity_void_form_ready")
 preload("res://oracle_combat.gd").clear(p)
 p.guard_until=0;p.renewal_until=0;p.focus_until=0;p.skill_fx_until=0
 game.motions.erase(id);game.checkpoint_ready.erase(id)
 game.PartyTravel.cancel(game,"A teammate has fallen. Readiness was cleared.",effects)
 var cost: String="%d maximum HP"%Preview.revive_cost() if Preview.enabled else "one maximum heart"
 game.action_feedback(effects,id,"You have fallen. Watch a living ally while a teammate reaches you. Revival costs %s for this expedition."%cost)
 if living_ids(game).is_empty():
  if effects == null: game.finish_failed_expedition()
  else: game._finish_failed_expedition(effects)
static func nearest(game: Node,p: Dictionary) -> int:
 if not alive(p): return 0
 var result:=0;var distance:=REVIVE_REACH
 for id in game.players:
  var other: Dictionary=game.players[id]
  if not other.get("wild",false) or not other.get("fallen",false): continue
  var length: float=p.pos.distance_to(other.pos)
  if length<distance and game.battlefield.clear_line(p.pos,other.pos): distance=length;result=int(id)
 return result
static func revive(game: Node,helper_id: int,target_id: int,effects = null) -> bool:
 if not game.players.has(helper_id) or not game.players.has(target_id) or helper_id==target_id: return false
 var helper: Dictionary=game.players[helper_id];var target: Dictionary=game.players[target_id]
 if not alive(helper) or not target.get("wild",false) or not target.get("fallen",false): return false
 if helper.pos.distance_to(target.pos)>REVIVE_REACH or not game.battlefield.clear_line(helper.pos,target.pos): return false
 if not Vitals.can_revive(native_maximum(game,target),Preview.scale()):
  game.action_feedback(effects,helper_id,"This ally has too little maximum health to revive." if Preview.enabled else "No full heart remains to sacrifice. This ally cannot be revived again during this expedition.");return false
 target.lost_health=int(target.get("lost_health",0))+Preview.revive_cost()
 target.max_hp=maximum(game,target);target.hp=float(target.max_hp);target.fallen=false
 target.erase("affinity_ward_claims");target.erase("frost_response");target.erase("affinity_ember_response")
 target.hurt_until=Time.get_ticks_msec()+1500;target.guard_until=0;target.renewal_until=0
 target.velocity=Vector3.ZERO;game.motions.erase(target_id)
 game.PartyTravel.cancel(game,"A teammate was revived. Confirm readiness again at the gate.",effects)
 if Preview.enabled:
  game.action_feedback(effects,target_id,"Revived. %d maximum HP is lost until you return to the Garden."%Preview.revive_cost())
 else:
  game.action_feedback(effects,target_id,"Revived. One maximum heart was sacrificed until you return to the Garden.")
 game.action_feedback(effects,helper_id,"Revived %s. Their maximum health is now %d."%[target.character.get("name","Ally"),target.max_hp])
 return true
