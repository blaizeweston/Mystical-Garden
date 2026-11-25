extends RefCounted
## Suspensions live in the existing Garden transaction. A disconnected guest
## is detached from simulation; the host retains their single authoritative actor.
const Codec = preload("res://expedition_suspend_codec.gd")
const ProfileProjection = preload("res://guest_profile_projection.gd")
const Clock = preload("res://combat_clock.gd")
const Session = preload("res://network_session.gd")
const Participation = preload("res://expedition_participation.gd")
const Tx = preload("res://game_transaction.gd")
const Journal = preload("res://diagnostic_journal.gd")
const WORLD = ["enemy_kind","enemy_mutations","enemy_growth","enemy_death_serial","combat_event_serial",
	"combat_events","enemy_death_events","encounter_kills","guardian_counts","encounter_rewarded","reward_retry_at","combat_threat","combat_velocity",
	"combat_last_positions","encounter_kill_records","moving_ranged_hits","encounter_started_at","encounter_party_size",
	"burst_hits_this_room","choke_kills_this_room","burst_clears","choke_clears","run_guardians","pressure_at",
	"damage_this_room","ranged_damage_this_room","ranged_clears","deepest_milestone","checkpoint_pending",
	"checkpoint_ready","boss_floors","used_bosses","enemy_hazards","enemy_hazard_serial","enemy_traits","wild_item_drops"]
const META = [&"affinity_combat_time",&"affinity_thorn_fields",&"affinity_void_displacement",&"affinity_bark_order",
	&"cr02_activation_serial",&"graft_run_serial",&"affinity_offer_serial",&"gate_elite",&"wilds_skill_tactics"]
const PRIVATE_FIELDS = [Session.STATE,Participation.STATE,"projection_delivery"]

static func detached(actor: Dictionary) -> Dictionary:
	var copy := actor.duplicate(true)
	for key in PRIVATE_FIELDS: copy.erase(key)
	return copy

static func seat(game, peer: int) -> Dictionary:
	var actor: Dictionary = game.players[peer]
	return {"peer":peer,"actor":detached(actor),"run":game.participation.run_id(),"floor":game.participation.epoch(),
		"ready":game.checkpoint_ready.get(peer,0),"offline_at":Time.get_ticks_msec()}

static func park(game, peer: int) -> bool:
	var actor: Dictionary = game.players[peer]
	var identity := Session.identity_for(actor)
	if not Participation.is_wild(actor) or identity.is_empty() or actor.get("rejoin_digest","").is_empty(): return false
	game.parked_explorers[identity] = seat(game,peer)
	game.parked_explorers[identity].actor.seed_owner = identity
	game.expedition_statistics.freeze_departure(game.participation.run_id(),identity,Time.get_ticks_msec())
	game.checkpoint_ready.erase(peer)
	return true

static func authorized(game, identity: String, ticket: String) -> bool:
	var saved: Dictionary = game.parked_explorers.get(identity,{})
	return not saved.is_empty() and saved.run == game.participation.run_id() and ticket.length()==64 and ticket.is_valid_hex_number(false) and saved.actor.rejoin_digest==ticket.sha256_text()

## A saved seat can be newer than the last projection the guest received. Accept
## known versions, but never replace a profile subsequently played elsewhere.
static func profile_matches(saved_actor: Dictionary, incoming: Dictionary, record: Dictionary, receipt: Dictionary) -> bool:
	var digest := ProfileProjection.digest(incoming)
	return digest in [ProfileProjection.digest(saved_actor.character),saved_actor.get("admitted_profile_digest",""),
		saved_actor.get("projection_base",{}).get("digest",""),receipt.get("digest",""),
		record.get("projection",{}).get("digest","")] or (record.has("profile") and digest==ProfileProjection.digest(record.profile))

static func rejoin(game, peer: int, identity: String) -> void:
	var saved: Dictionary = game.parked_explorers[identity]
	var registration: Dictionary = game.players[peer]
	var actor: Dictionary = saved.actor
	for key in [Session.STATE,Participation.STATE,"projection_base","projection_delivery"]:
		if registration.has(key): actor[key] = registration[key]
	# The host retained the expedition profile, including any deferred combat XP.
	actor.character = registration.character
	game.players[peer] = actor
	game.participation.enter(peer)
	if saved.floor == game.participation.epoch():
		if saved.ready: game.checkpoint_ready[peer] = saved.ready
	else:
		actor.pos = game.wild_entry(peer)
		actor.cache_claimed = false
		actor.contributed = false
		game.clear_floor_effects(actor)
	actor.velocity = Vector3.ZERO
	for drop in game.wild_item_drops:
		if drop.get("owner_identity","") == identity: drop.owner = peer
	game.expedition_statistics.resume_guest(identity,Time.get_ticks_msec()-int(saved.offline_at),game.participation.floor())
	game.parked_explorers.erase(identity)
	Journal.event("expedition","guest_rejoined",{"actor":peer,"floor":game.participation.floor()})

## Called inside the terminal departure transaction. Parked actors have no new
## loot eligibility. Only their existing protected cargo follows disconnect rules.
static func settle_absent(game) -> void:
	if game.parked_explorers.is_empty(): return
	for identity: String in game.parked_explorers:
		var saved: Dictionary = game.parked_explorers[identity]
		var actor: Dictionary = saved.actor
		actor.wild = true
		actor.seed_owner = identity
		game._recover_pouch(actor)
		var returns := preload("res://garden_return_service.gd")
		game.garden_commands.return_outcome(returns.Member.new(actor.garden_run_actor,actor.garden_run_id,true),"disconnected")
		var report: Dictionary = game.expedition_statistics.settled_disconnect(identity)
		game.Progress.Archive.settle(game.progress,actor.garden_run_id,identity,report)
		game.record_character(saved.peer,actor)
		game.monster_rewards.finish_expedition(identity,game.participation.run_id())
	game.parked_explorers.clear()
	if not game.persistence_session.is_guarded(): game.progress.save_garden()

static func capture(game) -> Dictionary:
	var point := {"fields":{},"meta":{},"host":detached(game.players[1]),"guests":game.parked_explorers.duplicate(true),
		"host_binding":game.network_session.binding(1),"participation":game.participation.savepoint(),"clock":Clock.now(),"real":Time.get_ticks_msec(),
		"routes":game.battlefield.routes.duplicate(true),"repath_at":game.battlefield.retry_at,
		"encounter":game.encounter.savepoint(),"tactics":Tx.snapshot(game.tactics),"flora":game.wild_flora.savepoint(),
		"statistics":game.expedition_statistics.savepoint(),"rewards":game.monster_rewards.savepoint(),
		"weapons":game.weapon_attacks.savepoint(),"effects":game.effect_timeline.savepoint(),
		"rng":game.rng.state,"map_rng":game.map_rng.state,"heal_rng":game.Life.Preview.heal_rng.state}
	for key in WORLD: point.fields[key] = game.get(key)
	for key in META:
		if game.has_meta(key): point.meta[key] = game.get_meta(key)
	for peer in game.participation.participants():
		if peer != 1: point.guests[Session.identity_for(game.players[peer])] = seat(game,peer)
	var codec := Codec.new()
	var data := codec.encode(point)
	if data.is_empty():
		game.status = codec.error
		return {}
	var hash_context := HashingContext.new()
	hash_context.start(HashingContext.HASH_SHA256)
	hash_context.update(data)
	return {"version":1,"owner":game.local_character.identity,"floor":game.participation.floor(),
		"host_profile":ProfileProjection.digest(game.players[1].character),
		"hosted":game.network_session.role()=="Host","port":game.network_session.port(),"data":data,"digest":hash_context.finish().hex_encode()}

static func suspend(game) -> bool:
	if not game.multiplayer.is_server() or not game.slot_claimed or not game.persistence_session.can_write(): return false
	if not game.departure_settlement.is_empty():
		if not game.flush_kill_rewards() or not game.departure_settlement.is_empty() or not game.persistence_session.can_write():
			game.status = Tx.feedback_text(game,"Resolve the pending departure before saving the expedition.")
			return false
	if not game.participation.active() and game.parked_explorers.is_empty(): return false
	var record := capture(game)
	if record.is_empty(): return false
	var result := Tx.run_gameplay(game,Tx.Scope.PAIR,func():
		game.progress.suspended_expedition = record
		if not game.persistence_session.is_guarded():
			return game.progress.save_garden()==OK and game.local_character.save_profile()==OK
		return true)
	if not (result.completed or Tx.committed(result.persistence)) or result.value!=true:
		game.status = Tx.feedback_text(game,"The expedition could not be saved.")
		return false
	Journal.event("expedition","suspended",{"floor":record.floor})
	return true

static func open(game) -> bool:
	var record: Dictionary = game.progress.suspended_expedition
	if record.is_empty(): return true
	if record.get("version")!=1 or record.get("owner")!=game.local_character.identity or not record.get("data") is PackedByteArray:
		game.status = "Choose the character who saved this expedition."
		return false
	var hash_context := HashingContext.new()
	hash_context.start(HashingContext.HASH_SHA256)
	hash_context.update(record.data)
	if hash_context.finish().hex_encode()!=record.get("digest",""):
		game.status = "The saved expedition is damaged."
		return false
	if record.get("host_profile","")!=ProfileProjection.digest(game.local_character.data):
		game.status = "This character changed after Save & Quit. Its newer progress and the saved expedition have been preserved."
		return false
	var point := Codec.new().decode(record.data)
	if not point.has_all(["host_binding","routes","repath_at","fields","meta","host","guests","participation","encounter","statistics","rewards","weapons","effects","clock","real","tactics","flora","rng","map_rng","heal_rng"]) or not point.fields.has_all(WORLD):
		game.status = "This saved expedition could not be read."
		return false
	if not point.participation.get("members",{}).has(1) or not point.host.get("character") is Dictionary:
		game.status = "The saved expedition is missing its host."
		return false
	if record.hosted and game.session_world.host(record.port)!=OK: return false
	# Rebuild on the unopened scene. A failed restore or write returns to the title
	# with the durable suspension available for recovery.
	if not _restore_world(game,point):
		game.status = "Could not restore the saved fight."
		return false
	# Consume the resume point before play can advance and later purchases, kills
	# or deposits could otherwise be replayed. Rollback keeps it available.
	var result := Tx.run_gameplay(game,Tx.Scope.GARDEN,func():
		game.progress.suspended_expedition = {}
		return true if game.persistence_session.is_guarded() else game.progress.save_garden()==OK)
	if not (result.completed or Tx.committed(result.persistence)) or result.value!=true: return false
	# Disk and terrain loading are outside combat time, even on a slow drive.
	Clock.resume_at(point.clock)
	var elapsed: int = Time.get_ticks_msec()-int(point.real)
	game.expedition_statistics.restore_savepoint(point.statistics)
	game.expedition_statistics.resume_clock(game.network_session.session_identity(),elapsed)
	for identity in game.parked_explorers:
		var saved: Dictionary = game.parked_explorers[identity]
		saved.offline_at += elapsed
		saved.actor.seed_owner = identity
		game.expedition_statistics.freeze_departure(game.participation.run_id(),identity,saved.offline_at)
	game.status = "Resumed expedition at encounter %d." % record.floor
	Journal.event("expedition","resumed",{"floor":record.floor})
	return true

static func _restore_world(game, point: Dictionary) -> bool:
	var host_link = game.network_session.restore_expedition_host(point.host_binding)
	if host_link == null: return false
	game.players[1][Session.STATE] = host_link
	var membership: Dictionary = point.participation
	for peer in membership.members.keys():
		if peer!=1: membership.members.erase(peer)
	membership.members[1].binding = game.players[1][Participation.STATE]._binding
	game.participation.restore_savepoint(membership)
	game.participation.clear_travel()
	var actor: Dictionary = point.host
	for key in [Session.STATE,Participation.STATE]: actor[key] = game.players[1][key]
	game.players[1] = actor
	game.local_character.data = actor.character
	for key in WORLD: game.set(key,point.fields[key])
	for key in point.meta: game.set_meta(key,point.meta[key])
	game.parked_explorers = point.guests
	game.checkpoint_ready = {1:game.checkpoint_ready[1]} if game.checkpoint_ready.has(1) else {}
	game.Transactions.restore(game.tactics,point.tactics)
	game.encounter.restore_savepoint(point.encounter)
	game.battlefield.configure(game.participation.route(),game.participation.depth(),game.participation.seed(),game.tactics.boss_kind,game.tactics.boss_phase)
	game.battlefield.routes = point.routes
	game.battlefield.retry_at = point.repath_at
	game.wild_flora.restore(point.flora)
	game.weapon_attacks.restore_savepoint(point.weapons)
	game.effect_timeline.restore_savepoint(point.effects)
	game.rng.state = point.rng
	game.map_rng.state = point.map_rng
	game.Life.Preview.heal_rng.state = point.heal_rng
	game.monster_rewards.restore_savepoint(point.rewards)
	return true
