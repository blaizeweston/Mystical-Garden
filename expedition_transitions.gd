extends RefCounted
const Conditions = preload("res://player_hit_conditions.gd")
const Protection = preload("res://player_protection.gd")

const Participation = preload("res://expedition_participation.gd")
## World transition adapter for expedition admission, return, floor advance,
## and teardown. Participation owns identity and membership. Existing ledgers,
## inventory, rewards and guarded transaction owners retain their state.

const PlayerVitals = preload("res://player_vitals.gd")
const WeaponActions = preload("res://player_weapon_actions.gd")
const Session = preload("res://network_session.gd")

var _world: WeakRef

func _init(world: Node) -> void:
	_world = weakref(world)


## A captured binding cannot authorize a replacement character on a reused peer.
func _actor(peer: int, expected_binding := 0) -> Dictionary:
	var game = _world.get_ref()
	if not game.players.has(peer): return {}
	if expected_binding != 0 and not game.network_session.matches(peer, expected_binding): return {}
	var actor: Dictionary = game.players[peer]
	if not Session.belongs_to(actor, game.network_session) or Session.peer_for(actor) != peer: return {}
	return actor

func enter(id: int) -> void:
	var game = _world.get_ref()
	var p := _actor(id)
	if p.is_empty(): return
	var binding: int = game.network_session.binding(id)
	var refusal := preload("res://affinity_build.gd").departure_refusal(p)
	if not refusal.is_empty():
		game.tell(id,refusal)
		return
	if game.players.size()>1: game.PartyTravel.request(game,id,"depart")
	elif game.persistence_session.is_guarded():
		if not game.at_weapon_gate(p) or Participation.is_wild(p) or game.participation.active(): return
		game.run_guarded_action(id, game.Transactions.Scope.PAIR, func(effects):
			game.settle_expedition_rewards(effects)
			if not _admit(id,binding,[],effects): return false
			effects.append(game.close_flow_for.bind(id))
			return true)
	else: game.Transactions.run(game,func(): _admit(id,binding))


func admit(id: int, reserved_override: Array = [], effects = null, expected_binding := 0) -> bool:
	var game = _world.get_ref()
	return _admit(id, game.network_session.binding(id) if expected_binding == 0 else expected_binding, reserved_override, effects)

func _admit(id: int, binding: int, reserved_override: Array = [], effects = null) -> bool:
	var game = _world.get_ref()
	var p := _actor(id, binding)
	if binding == 0 or p.is_empty() or game.participation.contains(id): return false
	var refusal := preload("res://affinity_build.gd").departure_refusal(p)
	if not refusal.is_empty():
		game.action_feedback(effects,id,refusal)
		return false
	var starting: bool = not game.participation.active()
	var available: bool = game.progress.finale_available() if game.participation.route() == game.Campaign.HEART else game.progress.campaign.available(game.participation.route())
	if starting and not available:
		game.action_feedback(effects,id, "This path is still sealed.")
		return false
	if game.participation.active() and game.PlayerLifecycle.fallen(p):
		game.action_feedback(effects,id, "Wait for your party to finish the expedition.")
		return false
	var selected: Array = [p.prepared, p.prepared_secondary, p.get("prepared_catalyst",0)]
	var available_parts: Array = game.Parts.empty_counts()
	for part in range(1, available_parts.size()): available_parts[part] = game.available_parts(p, part)
	var plan: Dictionary = preload("res://loadout_materials.gd").departure_plan(
		selected, p.cargo_plan, available_parts, game.seed_reserve(p).parts)
	if not plan.error.is_empty():
		game.action_feedback(effects, id, plan.error)
		return false
	var reserved: Array = plan.reserved
	if starting:
		var cost: int = 0 if game.participation.route() == game.Campaign.HEART else game.Campaign.SHORTCUT_COST[game.participation.route()]
		if cost > 0:
			if id != game.HOST:
				game.action_feedback(effects,id, "The host must open this paid route first.")
				return false
			var paid: int = game.progress.pay_shortcut(cost,reserved_override if not reserved_override.is_empty() else reserved)
			if paid != OK:
				game.action_feedback(effects,id, "Need %d shared plant parts to open this route." % cost if paid == ERR_UNAVAILABLE
					else "Could not save the route payment. Your parts were returned.")
				return false
		reset()
		game.start_encounter()
	if starting:game.garden_commands.begin_returns()
	if not game.participation.enter(id): return false
	var profile_owner: String = game._kill_reward_identity(id, p)
	if not game.monster_rewards.begin_expedition(profile_owner, game.participation.run_id(), p.character.xp, p.character.monsters):
		game.SaveBatch.record_serializer_error(ERR_UNAUTHORIZED, game.progress.path)
		game.action_feedback(effects,id,"Could not establish this expedition's reward boundary. Nothing was consumed.")
		return false
	game.expedition_statistics.bind_session(game.network_session.session_identity())
	game.expedition_statistics.admit(game.participation.run_id(),profile_owner,str(p.character.name),game.Frames.DEFINITIONS[int(p.frame)].name,game.participation.floor(),Time.get_ticks_msec())
	game.garden_commands.join_returns(id)
	p[game.PlayerLifecycle.STATE] = game.PlayerLifecycle.start_life()
	p.lost_health=0
	p.grave_charges=0
	p.still_since=preload("res://combat_clock.gd").now();p.still_point=game.wild_entry(id)
	p[game.ExpeditionWallet.STATE] = game.ExpeditionWallet.Wallet.new()
	p.pos = game.wild_entry(id)
	p[game.Cooldowns.STATE] = game.Cooldowns.Timers.new()
	p.core_ready_at=0
	p.core_cast_until=0
	p[Conditions.STATE] = p[Conditions.STATE].clear_grace()
	p[Protection.STATE] = p[Protection.STATE].clear_expedition()
	p.erase("frost_response")
	p.erase("affinity_ember_response")
	p.erase("affinity_thorn_form_ready")
	preload("res://wood_affinity.gd").clear(p)
	preload("res://storm_affinity.gd").clear(p)
	preload("res://spirit_affinity.gd").clear(p)
	p.erase("affinity_void_form_ready")
	if p.has("affinity_vital_sources"): preload("res://vital_combat.gd").clear(game,p)
	p.weapon = p.prepared
	p.secondary = p.prepared_secondary
	p.catalyst = p.prepared_catalyst
	var grafts = preload("res://expedition_grafts.gd")
	var identity := int(game.get_meta(grafts.SERIAL, 0)) + 1
	game.set_meta(grafts.SERIAL, identity)
	p[grafts.STATE] = grafts.Ledger.new(identity)
	p.erase("graft_message")
	p.prepared_catalyst = 0
	p.prepared = game.Parts.EMPTY
	p.prepared_secondary = game.Parts.EMPTY
	var gained := 0
	for part in selected:
		if part != game.Parts.EMPTY:
			var reserve = game.seed_reserve(p)
			if reserve.parts[part] > 0:
				reserve.parts[part] -= 1
			else:
				game.progress.add_parts(part, -1)
			gained += game.progress.record_part_craft(part)
	for part in range(1,game.Parts.DEFINITIONS.size()):
		var amount: int=p.cargo_plan[part]
		if amount>0 and game.Parts.is_monster(part):
			var reserve =game.seed_reserve(p)
			var personal:=mini(int(reserve.parts[part]),amount)
			reserve.parts[part]-=personal
			game.progress.add_parts(part,-(amount-personal))
			p.carried_parts[part]+=amount
	p.cargo_plan.fill(0)
	var health: PlayerVitals.Health = p[game.PlayerVitals.STATE].with_native_max_hp(game.Life.native_maximum(game,p))
	p[game.PlayerVitals.STATE] = health.healed(maxi(0,health.max_hp()-game.Life.Preview.hp(game.MAX_HEALTH)))
	if gained > 0:
		var message: String = "Weapon assembled. The Heart gained %d knowledge." % gained
		if effects == null: game.save_progress(id,message)
		else: game.action_feedback(effects,id,message)
	else:
		if effects == null: game.progress.save_garden()
		game.action_feedback(effects,id,"Entered %s." % game.Campaign.NAMES[game.participation.route()])
	return true


func return_member(id: int) -> void:
	var p := _actor(id)
	if not p.is_empty(): _return_member(p)

func _return_member(p: Dictionary, outcome := "Voluntary return") -> void:
	var game = _world.get_ref()
	var peer := Participation.peer_for(p)
	if peer == 0 or not game.players.has(peer) or not is_same(game.players[peer],p): return
	if not game.SaveBatch.guarded_active(): game.flush_kill_rewards()
	var identity: String = game._kill_reward_identity(peer,p)
	game.expedition_statistics.reached(game.participation.run_id(),game.participation.floor())
	game.expedition_statistics.finish(game.participation.run_id(),identity,outcome,Time.get_ticks_msec())
	game.monster_rewards.finish_expedition(identity, game.participation.run_id())
	p[WeaponActions.STATE] = p[WeaponActions.STATE].clear_active()
	p.cast_until=0
	preload("res://oracle_combat.gd").clear(p)
	game.AffinityCards.clear(p)
	p[game.ExpeditionWallet.STATE] = game.ExpeditionWallet.Wallet.new()
	game.participation.leave(peer)
	p[game.PlayerLifecycle.STATE] = game.PlayerLifecycle.start_life()
	p.lost_health=0
	p.weapon = 0
	p[Protection.STATE] = p[Protection.STATE].clear_expedition()
	p.erase("frost_response")
	p.erase("affinity_ember_response")
	p.erase("affinity_thorn_form_ready")
	preload("res://wood_affinity.gd").clear(p)
	preload("res://storm_affinity.gd").clear(p)
	preload("res://spirit_affinity.gd").clear(p)
	p.erase("affinity_void_form_ready")
	if p.has("affinity_vital_sources"): preload("res://vital_combat.gd").clear(game,p)
	p.grave_charges=0
	p.skill_fx_until=0
	p.carried_parts.fill(0)
	p.carried_seeds.clear()
	p.safe_items=[]
	p.carried_items={}
	p.pouch = false
	p.loot_pending = false
	game.refresh_drop()
	p.secondary = game.Parts.EMPTY
	p.catalyst=0
	p.erase(preload("res://expedition_grafts.gd").STATE)
	preload("res://native_grafts.gd").clear(p)
	p.erase("graft_message")
	p.pos = game.stage.experimental_garden.return_position() if game.stage.experimental_garden != null else game.stage.gate_position() + Vector3(0, 0, 2.0)
	p[Conditions.STATE] = p[Conditions.STATE].clear_all()
	game.restore_class_loadout(p)
	p[game.PlayerVitals.STATE] = p[game.PlayerVitals.STATE].refilled()


func checkpoint(id: int, descend: bool) -> void:
	var game = _world.get_ref()
	if _actor(id).is_empty(): return
	var binding: int = game.network_session.binding(id)
	if game.persistence_session.is_guarded():
		if not game.persistence_session.can_write() or not game.encounter_rewarded or not game.Life.alive(game.players.get(id,{})): return
	if game.PartyTravel.members(game,"advance").size()>1:
		game.PartyTravel.request(game,id,"advance" if descend else "extract");return
	if descend and game.activate_checkpoint(id): return
	if game.persistence_session.is_guarded():
		game.run_guarded_action(id, game.Transactions.Scope.PAIR, func(effects):
			if not game.network_session.matches(id,binding): return false
			if not commit_checkpoint(id,descend,effects,binding): return false
			if not descend: effects.append(game.close_flow_for.bind(id))
			return true)
		return
	var returned=game.Transactions.run(game,func(): commit_checkpoint(id,descend))
	if returned==false and game.persistence_session.can_write():game.battlefield.configure(game.participation.route(),game.participation.depth(),game.participation.seed())

# Opening cards is presentation. Buying a card and consenting to a floor
# change remain separate actions in the guarded route.


func commit_checkpoint(id: int, descend: bool,effects = null, expected_binding := 0) -> bool:
	var game = _world.get_ref()
	if _actor(id,expected_binding).is_empty(): return false
	if not game.players.has(id) or not game.Life.alive(game.players[id]):
		return false
	if not descend and not game.extraction_checkpoint_open():
		game.action_feedback(effects,id, "Extraction opens after clearing every sixth gate.")
		return false
	if game.players[id].pos.distance_to(game.battlefield.advance) > preload("res://gate_interaction.gd").RANGE:
		game.action_feedback(effects,id, "Use the onward gate to continue or extract at a checkpoint.")
		return false
	if not game.encounter_cleared():
		game.action_feedback(effects,id, "Defeat the enemies to open the checkpoint.")
		return false
	var checkpoint_index: Vector3 = game.battlefield.advance
	for player in game.players.values():
		if game.Life.alive(player) and checkpoint_index.distance_to(player.pos) > preload("res://gate_interaction.gd").RANGE+preload("res://gate_interaction.gd").READY_MARGIN:
			game.action_feedback(effects,id, "Gather your expedition party at this checkpoint.")
			return false
	if descend and game.upgrade_checkpoint_open():
		if not game.checkpoint_all_ready(): return false
		game.checkpoint_pending=false
		game.checkpoint_ready.clear()
		if effects == null:
			game.close_run_flow_panel()
			for peer_id in game.players:
				if peer_id!=game.HOST and game.network_session.transport()!=null: game.close_run_flow_panel.rpc_id(peer_id)
		else:
			for peer_id in game.players: effects.append(game.close_flow_for.bind(peer_id))
	if descend:
		if game.participation.route() == game.Campaign.HEART:
			return false
		if effects != null: game.settle_expedition_rewards(effects)
		var crossed_biome: bool = game.participation.depth() == game.ROUTE_ROOMS
		if not game.participation.advance(game.participation.epoch(),game.ROUTE_ROOMS,game.Campaign.HEART): return false
		game.expedition_statistics.reached(game.participation.run_id(),game.participation.floor())
		game.start_encounter()
		var recovery_hp: int =game.Life.Sustain.recovery_hp(crossed_biome,game.participation.cycle())
		for peer_id in game.players:
			var player: Dictionary = game.players[peer_id]
			if Participation.is_wild(player):
				player.pos = game.wild_entry(peer_id)
				if game.Life.alive(player): game.Life.Sustain.restore(game,player,recovery_hp,"floor_recovery")
				game.action_feedback(effects,peer_id, "%s · Encounter %d. %s awaits.%s" % [
					game.Campaign.NAMES[game.participation.route()], game.participation.floor(), game.enemy_name(),
					" A grafting shrine waits off the main path." if game.graft_altar_open() else ""])
		return true
	if effects != null: game.settle_expedition_rewards(effects, true)
	var banked := 0
	var banked_parts := 0
	for player in game.players.values():
		if Participation.is_wild(player) and game.PlayerLifecycle.fallen(player):
			if effects == null: game.recover_pouch(player)
			else: game._recover_pouch(player)
		elif Participation.is_wild(player):
			game.InventoryModel.bank_safe(game,player)
			game.InventoryModel.bank_extra(game,player)
			banked += player.carried_seeds.size()
			game.garden_commands.credit_return(preload("res://garden_return_service.gd").Member.new(str(player.get("garden_run_actor","")),str(player.get("garden_run_id","")),preload("res://expedition_participation.gd").is_wild(player)),player.carried_seeds,"extract")
			game.seed_reserve(player).unknown.append_array(player.carried_seeds)
			for part in range(1, game.Parts.DEFINITIONS.size()):
				var count: int = player.carried_parts[part]
				game.seed_reserve(player).parts[part] += count
				banked_parts += count
	var milestone: int = game.deepest_milestone
	var message: String = game.milestone_message("Extracted with %d seed(s) and %d weapon part(s)." % [banked, banked_parts], true)
	if game.participation.route() != game.Campaign.HEART:
		game.progress.campaign.record_guardian_memories(game.run_guardians,game.guardian_counts)
	for site in game.Campaign.HEART:
		if (game.run_guardians & (1 << site)) != 0 and game.progress.campaign.record_clear(site):
			message += " %s awaits at the Heart." % game.Campaign.OFFSHOOTS[site]
	for peer_id in game.players:
		var player: Dictionary = game.players[peer_id]
		if Participation.is_wild(player):
			game.garden_commands.return_outcome(preload("res://garden_return_service.gd").Member.new(str(player.get("garden_run_actor","")),str(player.get("garden_run_id","")),preload("res://expedition_participation.gd").is_wild(player)),"fallen" if game.PlayerLifecycle.fallen(player) else "extracted")
			_return_member(player,"Returned fallen" if game.PlayerLifecycle.fallen(player) else "Extraction")
			if peer_id != id:
				game.action_feedback(effects,peer_id, message)
	game.participation.select_route(game.Campaign.GROVE)
	reset()
	if effects == null and (banked > 0 or banked_parts > 0 or milestone > 0):
		game.save_progress(id, message)
	else:
		game.action_feedback(effects,id,message)
	return true


func reset() -> void:
	var game = _world.get_ref()
	# Releasing the old party hold starts a fresh life, as the retired lifecycle
	# phase did. Capture query facts before reset_run clears participation holds.
	var held_peers: Array[int] = []
	for player in game.players.values():
		if Participation.is_waiting(player): held_peers.append(Participation.peer_for(player))
	if not game.participation.reset_run(): return
	game.mouse_controls.clear(game)
	game.tactics.begin_boss(-1);game.boss_floors.clear();game.used_bosses.clear();game.enemy_hazards.clear()
	game.PartyTravel.clear(game)
	game.guardian_counts.fill(0)
	game.wild_item_drops.clear()
	game.checkpoint_pending=false
	game.checkpoint_ready.clear()
	game.run_guardians = 0
	game.deepest_milestone = 0
	game.ranged_clears = 0
	game.burst_clears = 0
	game.choke_clears = 0
	for player in game.players.values():
		player[game.PlayerLifecycle.STATE] = game.PlayerLifecycle.start_life() if Participation.peer_for(player) in held_peers \
			else player[game.PlayerLifecycle.STATE].clear_inactive()
		player.lost_health=0
		player[game.ExpeditionWallet.STATE] = game.ExpeditionWallet.Wallet.new()
		game.AffinityCards.clear(player)
		player.upgrade_seed=Crypto.new().generate_random_bytes(8).hex_encode().hash()
		player.last_deposit=0
		player.carried_parts.fill(0)
		player.carried_seeds.clear()
		player.pouch = false
		player.safe_items=[]
		player.carried_items={}
		player.secondary = game.Parts.EMPTY
	game.reset_encounter()


func finish_if_empty() -> void:
	var game = _world.get_ref()
	if game.participation.active() and game.Life.living_ids(game).is_empty():
		finish_failed()
	elif not game.participation.active() and (game.enemy_health() < game.encounter_health() or game.deepest_milestone > 0):
		finish_failed()


func finish_failed() -> bool:
	var game = _world.get_ref()
	if game.persistence_session.is_guarded() or (not game.SaveBatch.active and not game.departure_settlement.is_empty()):
		var result: Dictionary = game.run_guarded_action(game.HOST, game.Transactions.Scope.PAIR, func(effects): commit_failed(effects))
		return game.Transactions.committed(result.persistence)
	var returned=game.Transactions.run(game,func(): commit_failed())
	if returned==false and game.persistence_session.can_write():game.battlefield.configure(game.participation.route(),game.participation.depth(),game.participation.seed())
	return returned!=false


func commit_failed(effects = null, outcome := "Party wipe") -> void:
	var game = _world.get_ref()
	if effects != null: game.settle_expedition_rewards(effects, true)
	for player in game.players.values():
		if effects == null: game.recover_pouch(player)
		else: game._recover_pouch(player)
		if Participation.is_wild(player):
			game.garden_commands.return_outcome(preload("res://garden_return_service.gd").Member.new(str(player.get("garden_run_actor","")),str(player.get("garden_run_id","")),preload("res://expedition_participation.gd").is_wild(player)),"wipe")
			_return_member(player,outcome)
	var milestone: int = game.deepest_milestone
	var message: String = game.milestone_message("Expedition ended. Only safe-pouch contents are kept.", false)
	game.participation.select_route(game.Campaign.GROVE)
	reset()
	if milestone > 0 and effects == null:
		game.save_progress(game.HOST, message)
	else:
		game.action_feedback(effects,game.HOST,message)
	for id in game.players:
		if id != game.HOST:
			game.action_feedback(effects,id,message)


## Restore only personal combat rewards. Prepared equipment, old learned
## investments, plants, appearance and pre-run inventory are not rewound.
func _forfeit_progress(id: int, player: Dictionary, effects = null) -> bool:
	var game = _world.get_ref()
	var owner: String = game._kill_reward_identity(id, player)
	var prior: Dictionary = game.monster_rewards.forfeit_expedition(owner, game.participation.run_id())
	if prior.is_empty():
		game.SaveBatch.record_serializer_error(ERR_UNAUTHORIZED, game.progress.path)
		game.action_feedback(effects,id,"Could not verify this expedition's rewards. Abandonment was not saved.")
		return false
	var lost_xp := 0
	for index in player.character.xp.size(): lost_xp += maxi(0, int(player.character.xp[index]) - int(prior.xp[index]))
	player.character.xp = prior.xp
	player.character.monsters = prior.monsters
	game.record_settlement_metric(effects,"expedition_forfeited",{"actor":id,"run":game.participation.run_id(),"class_xp":lost_xp})
	return true

func abandon(id: int, exit_nonce := "") -> void:
	var game = _world.get_ref()
	var player := _actor(id)
	if player.is_empty(): return
	var binding: int = game.network_session.binding(id)
	if not exit_nonce.is_empty() and (exit_nonce.length() != 32 or not exit_nonce.is_valid_hex_number(false)): return
	if not Participation.is_wild(player):
		# Retransmit a committed correction, never replay forfeiture. This also
		# handles an exit request arriving just after a successful extraction.
		if not exit_nonce.is_empty() and game.persistence_session.can_publish_state():
			confirm_departure(id,exit_nonce)
		return
	if game.persistence_session.is_guarded():
		game.run_guarded_action(id, game.Transactions.Scope.PAIR, func(effects):
			if not game.network_session.matches(id,binding): return false
			if not _forfeit_progress(id,player,effects): return false
			game.settle_expedition_rewards(effects, true)
			game.garden_commands.return_outcome(preload("res://garden_return_service.gd").Member.new(str(player.get("garden_run_actor","")),str(player.get("garden_run_id","")),preload("res://expedition_participation.gd").is_wild(player)),"abandoned")
			_return_member(player,"Abandonment")
			game.checkpoint_ready.erase(id)
			if not exit_nonce.is_empty(): effects.append(game.network_session.mark_departure_saved.bind(id,game.network_session.binding(id),exit_nonce))
			game.save_action_profile(id,effects)
			effects.append(game.tell_profile_action.bind(id,"Expedition abandoned. This run's rewards were forfeited, including banked Class XP and safe-pouch contents."))
			game.PartyTravel.cancel(game,"A teammate left the expedition. Confirm readiness again at the gate.",effects)
			if game.participation.active() and game.Life.living_ids(game).is_empty():
				commit_failed(effects)
			elif not game.participation.active():
				game.participation.select_route(game.Campaign.GROVE)
				reset()
			effects.append(game.close_flow_for.bind(id)))
		return
	var saved: Variant = game.Transactions.run(game,func():
		if not game.network_session.matches(id,binding): return false
		if not _forfeit_progress(id,player): return false
		game.garden_commands.return_outcome(preload("res://garden_return_service.gd").Member.new(str(player.get("garden_run_actor","")),str(player.get("garden_run_id","")),preload("res://expedition_participation.gd").is_wild(player)),"abandoned")
		_return_member(player,"Abandonment")
		game.checkpoint_ready.erase(id)
		game.save_action_profile(id,null)
		if game.participation.active() and game.Life.living_ids(game).is_empty():
			finish_failed()
		elif not game.participation.active():
			game.participation.select_route(game.Campaign.GROVE)
			reset()
		else:
			game.resume_checkpoint_if_ready()
		return true)
	if saved:
		game.tell(id,"Expedition abandoned. This run's rewards were forfeited, including banked Class XP and safe-pouch contents.")
		game.close_flow_for(id)
		if not exit_nonce.is_empty(): confirm_departure(id,exit_nonce)

func confirm_departure(id: int, nonce: String) -> void:
	var game = _world.get_ref()
	if not game.network_session.mark_departure_saved(id,game.network_session.binding(id),nonce): return
	if game.persistence_session.is_guarded():
		game.send_committed_profile(id)
	elif game.network_session.transport() != null and game.multiplayer.get_peers().has(id):
		var profile: Dictionary = game.players[id].character.duplicate(true)
		profile.departure_receipt = nonce
		game.receive_character.rpc_id(id,profile)

func request_guest_exit(intent: int) -> bool:
	var game = _world.get_ref()
	if game.network_session.role() != "Guest" or game.network_session.abandonment_exit_confirmed(): return false
	var transport: ENetMultiplayerPeer = game.network_session.transport()
	if transport == null or transport.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED: return false
	if not game.network_session.awaiting_abandonment_save() and not Participation.is_wild(game.players.get(game.local_player_id(),{})): return false
	var nonce: String = game.network_session.request_abandonment_exit(intent)
	if nonce.is_empty(): return false # A lost host follows the existing disconnect path.
	game.send_garden_action("abandon_run:" + nonce)
	game.status = "Abandoning expedition. Waiting for your corrected character save before leaving."
	return true

func confirm_guest_exit(nonce: String) -> void:
	var game = _world.get_ref()
	var intent: int = game.network_session.confirm_abandonment_exit(nonce)
	if intent != Session.Exit.NONE: complete_guest_exit.call_deferred(intent)

func complete_guest_exit(intent: int) -> void:
	var game = _world.get_ref()
	if not is_instance_valid(game) or game.returning_to_title: return
	match intent:
		Session.Exit.TITLE: game.return_to_main_menu()
		Session.Exit.SESSION: game.session_world.leave("Back in your own Garden.")
		Session.Exit.APPLICATION:
			if game.persistence_session.is_guarded():
				if not game.prepare_guarded_exit(): return
				game.persistence_session.begin_shutdown()
			elif game.character_dirty and not game.save_local_character(): return
			game.session_world.offline()
			game.release_slot()
			game.get_tree().quit()

## A local host's voluntary quit forfeits that character. Other players are
## involuntarily disconnected and retain the existing failed-run settlement.
func finish_voluntary() -> bool:
	var game = _world.get_ref()
	if not game.participation.active(): return game.persistence_session.can_publish_state()
	if game.persistence_session.is_guarded():
		var saved: Dictionary = game.run_guarded_action(game.HOST,game.Transactions.Scope.PAIR,func(effects): return commit_voluntary(effects))
		return game.Transactions.committed(saved.persistence)
	return game.Transactions.run(game,func(): return commit_voluntary()) == true

func commit_voluntary(effects = null) -> bool:
	var game = _world.get_ref()
	var player: Dictionary = game.players.get(game.HOST,{})
	if Participation.is_wild(player):
		if not _forfeit_progress(game.HOST,player,effects): return false
		game.garden_commands.return_outcome(preload("res://garden_return_service.gd").Member.new(str(player.get("garden_run_actor","")),str(player.get("garden_run_id","")),preload("res://expedition_participation.gd").is_wild(player)),"abandoned")
		_return_member(player,"Abandonment")
		game.save_action_profile(game.HOST,effects)
	commit_failed(effects,"Host ended expedition")
	return true
