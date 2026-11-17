extends RefCounted

const CLAIMS := "affinity_ward_claims"
const PENDING := "affinity_ward_grant"


static func accepted(game: Node, player: Dictionary, before_until: int, before_charges: int, requested_until: int, now: int) -> void:
	if not game.has_meta(&"combat_affinity_ruleset"):
		return
	if before_until <= now or before_charges <= 0:
		player.erase(CLAIMS)
	if player.guard_until <= now or (player.guard_until == before_until and player.guard_charges == before_charges):
		return
	var pending: Dictionary = player.get(PENDING, {})
	var event: RefCounted = pending.get("event")
	if event != null and not event.accept_grant(game, player):
		return
	var order: int = int(game.get_meta(&"ward_grant_order", 0)) + 1
	game.set_meta(&"ward_grant_order", order)
	var claims: Array = player.get(CLAIMS, []).filter(func(claim): return int(claim.until) > now and int(claim.epoch) == game.participation.epoch())
	claims.append({"event": event, "adapter": pending.get("adapter", {}),
		"until": requested_until, "order": order, "epoch": game.participation.epoch()})
	player[CLAIMS] = claims


static func block(game: Node, player: Dictionary, id: int, now: int) -> RefCounted:
	var claims: Array = player.get(CLAIMS, [])
	var chosen: Dictionary = {}
	var kept: Array = []
	for claim in claims:
		if int(claim.until) <= now or int(claim.epoch) != game.participation.epoch():
			continue
		var event: RefCounted = claim.event
		if event != null and not event.block_available(id, claim.adapter, now):
			continue
		kept.append(claim)
		if chosen.is_empty() or int(claim.until) < int(chosen.until) or (claim.until == chosen.until and int(claim.order) < int(chosen.order)):
			chosen = claim
	if not chosen.is_empty():
		kept.erase(chosen)
	if player.guard_charges > 0 and not kept.is_empty():
		player[CLAIMS] = kept
	else:
		player.erase(CLAIMS)
	# Claims without an enhancement take their ordinary priority and consume
	# just their own response budget. Protection has already been consumed.
	if not chosen.is_empty() and chosen.event != null:
		if chosen.event.publish(game, "actual_block", "ward", chosen.event.block_scope(id, chosen.adapter), now,
				{"adapter": chosen.adapter.id, "recipient": id, "center": player.pos}):
			return chosen.event
	return null
