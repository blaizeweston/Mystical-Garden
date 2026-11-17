extends RefCounted
## A host-owned move locks the same geometry used by resolution and warning projection.
const Catalog = preload("res://enemy_catalog.gd")
const Variants = preload("res://enemy_variants.gd")
const Support = preload("res://enemy_support.gd")
const SkillResponses = preload("res://enemy_skill_responses.gd")
const PILGRIM_SWEEP := 2.25
const VAULT_ID := "cover_vault"
const VAULT_ROLES := ["swipe", "charge", "pounce", "skirmish"]
const VAULT_WINDUP := 1000
const CONTACT_PADDING := preload("res://enemy_attack_hits.gd").CONTACT_PADDING
const SCOUT_COMMIT := &"scout_commit"
const REQUIRES_SCOUT_COMMIT := &"requires_scout_commit"

static func vault_target(game: Node, actor: Dictionary, target: Vector3) -> Vector3:
 var role: String = Catalog.get_kind(actor.kind).role
 if game.participation.floor() < 3 or not (int(actor.mutations) & Catalog.MOBILITY) or role not in VAULT_ROLES:
  return Vector3.INF
 # A mobile gate elite can still cross actual cover when its signature lacks a clear approach.
 if not actor.get("gate_elite",false) and not str(actor.get("variant","")).is_empty():
  return Vector3.INF
 var origin: Vector3 = actor.pos
 var distance := origin.distance_to(target)
 var landing := origin.move_toward(target, minf(3.0, distance))
 return landing if distance > 1.5 and game.can_vault(origin, landing) else Vector3.INF

const Thorn = preload("res://thorn_adaptation.gd")

static func try_thorn_vault(game: Node, actor: Dictionary, victim: Vector3, now: int) -> bool:
 var jump := Thorn.plan(game, actor, victim, now)
 if jump.is_empty():
  return false
 lock(game, actor, "vault", jump.landing, now + Thorn.WINDUP)
 actor.attack.variant=Thorn.MOVE
 actor.attack.thorn_line=jump.line_id
 actor.attack.radius=Thorn.LANDING_RADIUS
 actor.attack.cue=Thorn.CUE
 actor.attack.recovery_bonus=450
 actor.thorn_vault_used=true
 game.Journal.event("combat", "wilds_thorn_vault_locked", {"species": Catalog.get_kind(actor.kind).id,
  "target_token": game.encounter.token_for(actor), "cast_id": jump.line_id, "floor": game.participation.floor()})
 return true

# Directed volleys have an impact radius, but no authored flight thickness.
static func attack_sight(field: RefCounted, from: Vector3, to: Vector3, mode: String) -> bool:
 return field.combat_sight(from,to) if mode=="volley" else field.clear_line(from,to)

static func aim(game: Node, actor: Dictionary, role: String, player: int) -> Vector3:
 var kind:=int(actor.kind)
 var variant: String=actor.get("variant","")
 if role in ["charge","pounce","volley","artillery","snare","lure","swipe"] or kind in [7,11,19]:
  var lead:=.28 if role in ["volley","artillery","snare"] else .18
  if kind==14:lead=.25
  if kind==4:lead=.35 if variant=="leading_pounce" else .12
  return game.Director.predict(game,player,lead)
 return actor.pos

static func plan(game: Node, actor: Dictionary, mode: String, target: Vector3) -> Dictionary:
 var origin: Vector3 = actor.pos
 var landing := target
 var kind := int(actor.kind)
 var variant: String=actor.get("variant","")
 var via:=Vector3.INF
 var role:=mode
 var span_value:=0.0
 var recovery_bonus:=0
 if variant in ["angled_charge","wide_flank"] and not actor.get("approach_used",false):
  variant=""
 if mode=="charge" and variant=="cutoff_charge":
  var cutoff:=Variants.cutoff(game,origin,target,int(actor.route))
  if cutoff.is_equal_approx(target):variant=""
  else:landing=cutoff
 var radius := 0.95 if mode == "desperate" else Catalog.radius(kind, int(actor.mutations))
 var width := maxf(0.75, radius * 0.65)
 if mode in ["charge", "pounce"]:
  landing = game.battlefield.dash(origin, landing)
 if kind==0 and mode=="swipe":
  role="enemy_sweep";span_value=PILGRIM_SWEEP+(.24 if actor.get("gate_elite",false) else 0.0)
 if kind==1 and mode=="volley" and actor.get("gate_elite",false):
  radius+=.16
 if kind==2 and mode=="charge":recovery_bonus=300
 if kind==4 and mode=="pounce":recovery_bonus=280
 if kind==13 and mode=="charge":
  role="burrow";recovery_bonus=500
  if variant=="bent_seam":
   via=Variants.seam(game,origin,target,int(actor.route))
   if via.is_finite():landing=target
   else:variant=""
 if mode == "charge" and kind in [13, 17]:
  width = 0.8 if kind == 13 else 0.85
  radius = 1.0 if kind == 13 else 1.25
 if mode in ["swipe", "stomp", "skirmish", "chant", "shepherd", "brood", "desperate"]:
  landing = origin
 if kind == 19 and mode == "shepherd":
  radius = 4.6;role="stomp"
 var spots: Array[Vector3]=[]
 var spot_radius:=.7
 var patches: Array[Vector3]=[]
 if kind==14 and mode=="snare":
  if variant=="split_web" and origin.distance_to(landing)>=3.7:
   spots=Variants.spread(game,origin,origin.lerp(landing,.57),[Vector2(-1.6,-.65),Vector2(-1.6,.65),Vector2(1.6,-.65),Vector2(1.6,.65)],.7)
  if spots.is_empty():
   variant=""
   for index in 4:spots.append(origin.lerp(landing,index/3.0))
 if kind==5 and mode=="snare" and variant=="root_line":
  spot_radius=.94
  spots=Variants.spread(game,origin,landing,[Vector2(-.95,0),Vector2(.95,0)],spot_radius)
  if spots.is_empty():variant=""
 if kind==6 and mode=="artillery":
  radius=1.28
  patches.assign([landing])
  if variant=="offset_spores":
   var side:=1.0 if int(actor.route)%2==0 else -1.0
   var extra:=Variants.spread(game,origin,landing,[Vector2(side*3.2,.25)],radius)
   if extra.is_empty():variant=""
   else:patches.append_array(extra)
 var trail: Array[Vector3]=[]
 if kind==17 and mode=="charge":
  var length:=origin.distance_to(landing)
  var count:=clampi(floori(length/2.1)+1,1,3)
  for index in count:
   trail.append(origin.lerp(landing,float(index)/maxi(1,count-1)))
 var attack: Dictionary={"mode":mode,"variant":VAULT_ID if mode=="vault" else variant,"from":origin,"face":target,
  "to":landing,"via":via,"radius":radius,"width":width,"spots":spots,"spot_radius":spot_radius,"trail":trail,"patches":patches,
  "role":role,"span":span_value,"recovery_bonus":recovery_bonus,"cue":Variants.cue(variant,kind),
  "pulse":1 if kind==1 and mode=="volley" else 0}
 Support.decorate_plan(game,actor,attack,target)
 return attack

static func try_skill_approach(game: Node, actor: Dictionary, target: Vector3, now: int) -> bool:
 var mode: String = SkillResponses.APPROACH.get(actor.kind,"")
 if mode.is_empty():return false
 var profile := SkillResponses.ready_profile(game,actor)
 if profile.is_empty():return false
 var move := plan(game,actor,mode,target)
 if not SkillResponses.approach(game,actor,move,target,profile):return false
 lock(game,actor,mode,target,now+SkillResponses.MIN_WINDUP,move)
 return true

static func lock(game: Node, actor: Dictionary, mode: String, target: Vector3, until: int,
  prepared: Dictionary = {}, intent: Dictionary = {}) -> void:
 actor.mode = mode
 actor.attack = prepared if not prepared.is_empty() else plan(game, actor, mode, target)
 if prepared.is_empty():SkillResponses.decorate(game,actor,actor.attack,target)
 actor.blast = actor.attack.to
 actor.windup = maxi(until,Time.get_ticks_msec()+SkillResponses.MIN_WINDUP) if actor.attack.get("learned",false) else until
 if intent.is_empty():
  actor.erase(REQUIRES_SCOUT_COMMIT)
 else:
  actor[REQUIRES_SCOUT_COMMIT] = true
  actor.attack[SCOUT_COMMIT] = {
   "epoch": int(intent.epoch), "slot": int(intent.slot), "token": int(intent.token),
   "target": int(intent.target), "target_life": int(intent.target_life),
  }
 preload("res://oracle_omens.gd").begin_attack(game,actor,actor.attack,Time.get_ticks_msec())
 preload("res://wilds_skill_tactics.gd").lock_response(game,actor,actor.attack)
 preload("res://event_audio.gd").enemy(game,actor.attack,false)

## A committed plan is still associated with the same roster member. After contact,
## the source can be defeated by defense effects without redirecting the attack.
static func scout_source_current(roster: RefCounted, attack: Dictionary, epoch: int, require_living: bool = false) -> bool:
 var commit: Dictionary = attack.get(SCOUT_COMMIT, {})
 if commit.is_empty():
  return true
 var slot := int(commit.slot)
 var token := int(commit.token)
 return int(commit.epoch) == epoch and slot >= 0 and token > 0 and roster.token(slot) == token \
  and (not require_living or roster.alive(slot, token))

## Claim the original locked geometry before calling any effects. Keep the route
## marker after consumption so that a retry cannot rebuild a synthetic attack.
static func claim_scout_attack(roster: RefCounted, actor: Dictionary, epoch: int, now: int,
  expected_plan: Dictionary = {}, expected_due: int = -1) -> Dictionary:
 var due := int(actor.get("windup", 0))
 if due <= 0 or now < due or (expected_due >= 0 and due != expected_due):
  return {}
 var attack: Dictionary = actor.get("attack", {})
 if not expected_plan.is_empty() and not is_same(attack, expected_plan):
  return {}
 var commit: Dictionary = attack.get(SCOUT_COMMIT, {})
 actor.windup = 0
 actor.erase("attack")
 if commit.is_empty() or attack.get("mode") != actor.mode:
  return {}
 if not scout_source_current(roster, attack, epoch, true) or not is_same(roster.scout(int(commit.slot)), actor):
  return {}
 return attack

## Nightbloom reuses the original locked point and source. Its new due time
## belongs to the next pulse, so a callback for the first pulse cannot claim it.
static func rearm_scout_attack(roster: RefCounted, actor: Dictionary, attack: Dictionary,
  epoch: int, due: int) -> bool:
 var commit: Dictionary = attack.get(SCOUT_COMMIT, {})
 if not commit.is_empty():
  if not scout_source_current(roster, attack, epoch, true) or not is_same(roster.scout(int(commit.slot)), actor):
   return false
  if int(actor.get("windup", 0)) > 0 or actor.has("attack"):
   return false
 actor.attack = attack
 actor.windup = due
 return true

static func current(game: Node, actor: Dictionary) -> Dictionary:
 var saved: Dictionary = actor.get("attack", {})
 if not saved.is_empty() and saved.mode == actor.mode:
  return saved
 # Synthetic fixtures and legacy direct calls may supply a mode and target.
 return plan(game, actor, str(actor.mode), actor.blast)

## Use the same locked plan for release and warning projection. Scripted
## moves can still supply their own authored geometry through the fallback.
static func scout_hints(roster: RefCounted, epoch: int, now: int, fallback: Callable) -> Array:
 var result: Array = []
 for slot in roster.scout_count():
  if not roster.alive(slot):
   continue
  var actor: Dictionary = roster.scout(slot)
  var due := int(actor.windup)
  if due <= 0:
   continue
  var attack: Dictionary
  if actor.get(REQUIRES_SCOUT_COMMIT, false):
   attack = actor.get("attack", {})
   if attack.get(SCOUT_COMMIT, {}).is_empty() or attack.get("mode") != actor.mode \
     or not scout_source_current(roster, attack, epoch, true):
    continue
  else:
   attack = fallback.call(actor)
  result.append_array(hints(attack, slot, maxf(0, (due-now)/1000.0)))
 return result

static func hints(attack: Dictionary, id: int, remaining: float) -> Array:
 var from: Vector3 = attack.from
 var to: Vector3 = attack.to
 var zones: Array=attack.spots if not attack.spots.is_empty() else attack.patches
 if not zones.is_empty():
  var result: Array=[]
  var zone_role: String="volley" if attack.mode=="snare" else "artillery"
  var zone_radius: float=attack.spot_radius if attack.mode=="snare" else attack.radius
  for index in zones.size():
   var hint:=warning(200+(id+1)*4+index,zone_role,from,zones[index],zone_radius,0.0,remaining)
   var face: Vector3=attack.face
   hint.actor=id;hint.pose=attack.mode;hint.face=[face.x,0,face.z]
   if not attack.patches.is_empty():hint.field=true
   if index==0:hint.cue=attack.cue
   result.append(hint)
  return result
 var padding := CONTACT_PADDING if attack.role == "charge" else 0.0
 var display_radius:=.54 if attack.role in ["corpse_tether","trophy_grab"] else float(attack.radius)+padding
 var rite_anchor: Dictionary=attack.get("rite_anchor",{})
 var center: Vector3=rite_anchor.get("point",from)
 var warning_to: Vector3=to if rite_anchor.is_empty() else center
 var bent_charge: bool=attack.get("variant")=="antler_hook"
 if bent_charge:warning_to=attack.via
 var display_width:=float(attack.width)+padding
 var hint := warning(id,attack.role,center,warning_to,display_width if bent_charge else display_radius,display_width,remaining)
 hint.actor=id
 if bent_charge:hint.face=[to.x,0,to.z]
 if attack.pulse>0:hint.pulse=attack.pulse
 hint.pose="burrow" if attack.role=="burrow" else attack.mode
 var face: Vector3=attack.face
 if attack.span>0 or attack.mode in ["stomp","shepherd"]:
  hint.face=[face.x,0,face.z]
  hint.span=attack.span
 if attack.via.is_finite():
  var via: Vector3=attack.via
  hint.via=[via.x,0,via.z]
 if attack.variant!="bark_guard":hint.cue=attack.cue
 var result: Array=[hint]
 var base:=2000+(id+1)*16
 if bent_charge:result.append(warning(base+14,"charge",attack.via,to,display_radius,display_width,remaining))
 if attack.mode=="canopy_shift":result.append(warning(base+13,"rally_link",from,to,.24,0.0,remaining))
 for index in attack.trail.size():
  result.append(warning(400+(id+1)*4+index,"ember_preview",from,attack.trail[index],.85,0.0,remaining))
 if attack.has("follow"):
  result.append(warning(base,"aftershock",from,attack.follow.point,attack.follow.radius,0.0,remaining))
 if not rite_anchor.is_empty():
  result.append(warning(base+13,"rally_link",from,center,.34,0.0,remaining))
 for at in attack.get("hatch",[]):
  result.append(warning(base+result.size(),"hatch",from,at,.72,0.0,remaining))
 if attack.has("flank"):
  result.append(warning(base+4,"rally_link",attack.flank.escort.point,attack.flank.via,.34,0.0,remaining))
 for ally in attack.get("escorts",[]).slice(0,8):
  result.append(warning(base+result.size()+4,"rally_link",from,ally.point,.25,0.0,remaining))
 if attack.has("anchor"):
  var anchor: Vector3=attack.anchor
  hint.anchor=[anchor.x,0,anchor.z]
 if attack.variant=="planted_canopy" and attack.mode=="stomp":
  var canopy:=warning(base+12,"canopy_sector",from,from,float(Catalog.get_kind(11).shelter_radius),0.0,remaining)
  canopy.face=[face.x,0,face.z];canopy.span=Support.CANOPY_SPAN
  result.append(canopy)
 return result

static func poses(warnings: Array) -> Dictionary:
 var result := {}
 for hint in warnings:
  if not hint.has("actor"): continue
  var at: Array=hint.get("face",hint.to)
  var entry: Dictionary={"mode":hint.pose,"target":Vector3(at[0],0.0,at[2]),"remaining":hint.remaining}
  if hint.has("via"):entry.via=Vector3(hint.via[0],0.0,hint.via[2])
  if hint.has("pulse"):entry.pulse=hint.pulse
  result[hint.actor]=entry
 for hint in warnings:
  if not hint.has("growth"):continue
  if not result.has(-1):result[-1]={}
  result[-1].growth=hint.growth
  result[-1].growth_phase=hint.phase
 return result

static func warning(id: int, mode: String, origin: Vector3, target: Vector3, radius: float, width: float, remaining: float) -> Dictionary:
 return {"id": id, "role": mode, "from": [origin.x, 0, origin.z], "to": [target.x, 0, target.z],
  "radius": radius, "width": width, "remaining": remaining}

static func landing_is_clear(game: Node, actor: Dictionary, attack: Dictionary, now: int = 0) -> bool:
 if attack.get("learned_move",false):
  if not SkillResponses.move_still_valid(actor,attack,now) or not SkillResponses.avoids_thorns(game,attack,now):
   return false
 if attack.variant == Thorn.MOVE:
  return Thorn.can_land(game, actor, attack, now)
 var target: Vector3 = attack.to
 if game.battlefield.occupied(target, game.Battlefield.CLEARANCE):
  return false
 if attack.mode == "vault":
  return game.can_vault(actor.pos, target)
 if attack.via.is_finite():
  return game.battlefield.clear_line(actor.pos,attack.via,game.Battlefield.CLEARANCE) and game.battlefield.clear_line(attack.via,target,game.Battlefield.CLEARANCE)
 return actor.pos.distance_to(target) < 0.05 or game.battlefield.dash(actor.pos, target).distance_to(target) < 0.05
