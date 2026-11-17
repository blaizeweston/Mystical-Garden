extends RefCounted
## Host-side expedition recovery. Authoring still uses points, while budgets use HP.
const PlayerVitals = preload("res://player_vitals.gd")
const Preview = preload("res://combat_balance_preview.gd")
const KILL_BUDGET_HP := 24
const FLOOR_BONUS_PER_LOOP_HP := 3
const FLOOR_BONUS_CAP_HP := 9
const POOL_HEAL_RATIO := .4
const HEAL_TINT := Color("#a7e3a5")


static func restore(game: Node, actor: Dictionary, rolled_hp: int, source: String, limit_hp: int = -1) -> float:
	if Preview.enabled and (not game.multiplayer.is_server() or not game.Life.alive(actor)):
		return 0.0
	var applied := Preview.apply_heal(actor,rolled_hp,source,limit_hp)
	if Preview.enabled and applied>0.0 and game.multiplayer.is_server():
		for id in game.players:
			if not is_same(actor,game.players[id]):
				continue
			game.emit_combat_event("impact","heal",actor.pos,actor.pos,.85,HEAL_TINT,applied,int(id))
			break
	return applied


static func heal(game: Node, actor: Dictionary, points: float, source: String, spread: int = Preview.HEAL_SPREAD_HP) -> float:
	return restore(game,actor,Preview.roll_heal(points,spread),source)


static func recovery_center_hp(boundary: bool, cycle: int) -> int:
	var center := Preview.Vitals.floor_recovery(boundary,Preview.scale())
	if Preview.enabled:
		center += mini(FLOOR_BONUS_CAP_HP,maxi(0,cycle)*FLOOR_BONUS_PER_LOOP_HP)
	return center


static func recovery_hp(boundary: bool, cycle: int) -> int:
	return Preview.roll_heal_hp(recovery_center_hp(boundary,cycle))


static func pool_points(points: float) -> float:
	return points*POOL_HEAL_RATIO if Preview.enabled else points


static func begin_renewal(actor: Dictionary, now: int, duration: int, interval: int) -> void:
	if Preview.enabled and now<int(actor.get("renewal_until",0)):
		actor.renewal_until=maxi(int(actor.renewal_until),now+duration)
	else:
		actor.renewal_until=now+duration
		actor.renewal_tick=now+interval


static func renewal_tick(game: Node, actor: Dictionary) -> void:
	var center := Preview.RENEWAL_HP if Preview.enabled else Preview.hp(1)
	restore(game,actor,Preview.roll_heal_hp(center,Preview.HEAL_TICK_SPREAD_HP),"renewal")


static func eligible(game: Node, target: int) -> bool:
	return target==-1 or (target>=0 and target<game.encounter.scout_count() and not game.encounter.scout(target).get("summoned",false))


static func kill_remaining(actor: Dictionary, epoch: int) -> int:
	var spent := int(actor.get("kill_heal_spent",0)) if int(actor.get("kill_heal_epoch",-1))==epoch else 0
	return maxi(0,KILL_BUDGET_HP-spent)


static func heal_on_kill(game: Node, actor: Dictionary, target: int, points: float) -> float:
	if not Preview.enabled:
		return Preview.heal(actor,points,Preview.HEAL_SPREAD_HP,"heal_on_kill")
	var remaining := kill_remaining(actor,game.combat_epoch)
	if points<=0.0 or remaining==0 or not eligible(game,target) or not game.Life.alive(actor) or PlayerVitals.current_hp(actor)>=PlayerVitals.maximum_hp(actor):
		return 0.0
	var applied := restore(game,actor,Preview.roll_heal(points),"heal_on_kill",remaining)
	actor.kill_heal_epoch=game.combat_epoch
	actor.kill_heal_spent=KILL_BUDGET_HP-remaining+roundi(applied)
	return applied
