extends RefCounted

const Participation = preload("res://expedition_participation.gd")
## World transition adapter for expedition admission, return, floor advance,
## and teardown. Participation owns identity and membership. Existing ledgers,
## inventory, rewards and guarded transaction owners retain their state.

const PlayerVitals = preload("res://player_vitals.gd")

static func enter(game: Node, id: int, p: Dictionary) -> void:
	var refusal := preload("res://affinity_build.gd").departure_refusal(p)
	if not refusal.is_empty():
		game.tell(id,refusal)
		return
	if game.players.size()>1: game.PartyTravel.request(game,id,"depart")
	elif game.has_meta(game.Transactions.SESSION):
		if not game.at_weapon_gate(p) or Participation.is_wild(p) or game.participation.active(): return
		game.run_guarded_action(id, game.Transactions.Scope.PAIR, func(effects):
			game.settle_expedition_rewards(effects)
			if not admit(game, id,p,[],effects): return false
			effects.append(game.close_flow_for.bind(id))
			return true)
	else: game.Transactions.run(game,func(): admit(game, id,p))


static func admit(game: Node, id: int, p: Dictionary,reserved_override: Array=[],effects = null) -> bool:
	if Participation.peer_for(p) != id or not game.players.has(id) or not is_same(game.players[id],p) \
			or game.participation.contains(id):
		return false
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
	var needed: Array = game.Parts.empty_counts()
	for part in selected:
		if part!=0 and not game.Parts.is_plant(part):
			game.action_feedback(effects,id,"Only plant materials fit the first three slots.")
			return false
		needed[part]+=1
	for part in range(1,needed.size()):
		needed[part]+=int(p.cargo_plan[part])
		if game.available_parts(p,part)<needed[part]:
			game.action_feedback(effects,id,"Not enough %s for the loadout and cargo."%game.Parts.part_name(part))
			return false
	var reserved: Array = game.Seeds.counts()
	for part in range(1,needed.size()):
		if game.Parts.is_plant(part) and part!=game.Parts.HEARTWOOD:
			reserved[game.Parts.plant_source(part)]+=maxi(0,int(needed[part])-int(game.seed_reserve(p).parts[part]))
	for part in selected:
		if part != game.Parts.EMPTY and game.available_parts(p, part) == 0:
			game.action_feedback(effects,id, "%s is unavailable. Change the slot at the Wilds gate." % game.Parts.part_name(part))
			return false
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
		reset(game)
		game.start_encounter()
	if starting:preload("res://garden_return_service.gd").begin(game)
	if not game.participation.enter(id): return false
	preload("res://garden_return_service.gd").join(game,id,p)
	p[game.PlayerLifecycle.STATE] = game.PlayerLifecycle.start_life()
	p.lost_health=0
	for key in ["grave_charges","counter_until","front_guard_until","counter_guard_until"]: p[key]=0
	p.still_since=Time.get_ticks_msec();p.still_point=game.wild_entry(id)
	p[game.ExpeditionWallet.STATE] = game.ExpeditionWallet.Wallet.new()
	p.pos = game.wild_entry(id)
	p[game.Cooldowns.STATE] = game.Cooldowns.Timers.new()
	p.core_ready_at=0
	p.core_cast_until=0
	p.hurt_until=0
	p.erase("affinity_ward_claims")
	p.erase("frost_response")
	p.erase("affinity_ember_response")
	p.erase("affinity_thorn_form_ready")
	preload("res://wood_affinity.gd").clear(p)
	preload("res://storm_affinity.gd").clear(p)
	preload("res://spirit_affinity.gd").clear(p)
	p.erase("affinity_void_form_ready")
	if p.has("affinity_vital_sources"): preload("res://vital_combat.gd").clear(game,p)
	p.guard_charges=0
	p.guard_until = 0
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


static func return_member(game: Node, p: Dictionary) -> void:
	var peer := Participation.peer_for(p)
	if peer == 0 or not game.players.has(peer) or not is_same(game.players[peer],p): return
	if not game.SaveBatch.guarded_active(): game.flush_kill_rewards()
	p.attack_until=0;p.swing_until=0;p.cast_until=0
	preload("res://oracle_combat.gd").clear(p)
	game.AffinityCards.clear(p)
	p[game.ExpeditionWallet.STATE] = game.ExpeditionWallet.Wallet.new()
	game.participation.leave(peer)
	p[game.PlayerLifecycle.STATE] = game.PlayerLifecycle.start_life()
	p.lost_health=0
	p.weapon = 0
	p.erase("affinity_ward_claims")
	p.erase("frost_response")
	p.erase("affinity_ember_response")
	p.erase("affinity_thorn_form_ready")
	preload("res://wood_affinity.gd").clear(p)
	preload("res://storm_affinity.gd").clear(p)
	preload("res://spirit_affinity.gd").clear(p)
	p.erase("affinity_void_form_ready")
	if p.has("affinity_vital_sources"): preload("res://vital_combat.gd").clear(game,p)
	p.guard_until = 0
	p.front_guard_until=0;p.counter_guard_until=0;p.counter_until=0;p.grave_charges=0
	p.skill_fx_until=0
	p.guard_charges=0
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
	p.slow_until = 0
	p.hurt_until=0
	game.restore_class_loadout(p)
	p[game.PlayerVitals.STATE] = p[game.PlayerVitals.STATE].refilled()


static func checkpoint(game: Node, id: int, descend: bool) -> void:
	if game.has_meta(game.Transactions.SESSION):
		if not game.Transactions.session_writable(game) or not game.encounter_rewarded or not game.Life.alive(game.players.get(id,{})): return
	if game.PartyTravel.members(game,"advance").size()>1:
		game.PartyTravel.request(game,id,"advance" if descend else "extract");return
	if game.has_meta(game.Transactions.SESSION):
		if descend and game.players[id].pos.distance_to(game.battlefield.advance)<=preload("res://gate_interaction.gd").RANGE and game.activate_checkpoint(): return
		game.run_guarded_action(id, game.Transactions.Scope.PAIR, func(effects):
			if not commit_checkpoint(game, id,descend,effects): return false
			if not descend: effects.append(game.close_flow_for.bind(id))
			return true)
		return
	var returned=game.Transactions.run(game,func(): commit_checkpoint(game, id,descend))
	if returned==false:game.battlefield.configure(game.participation.route(),game.participation.depth(),game.participation.seed())

# Opening cards is presentation. Buying a card and consenting to a floor
# change remain separate actions in the guarded route.


static func commit_checkpoint(game: Node, id: int, descend: bool,effects = null) -> bool:
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
	var checkpoint: Vector3 = game.battlefield.advance
	for player in game.players.values():
		if game.Life.alive(player) and checkpoint.distance_to(player.pos) > preload("res://gate_interaction.gd").RANGE+preload("res://gate_interaction.gd").READY_MARGIN:
			game.action_feedback(effects,id, "Gather your expedition party at this checkpoint.")
			return false
	if descend and game.upgrade_checkpoint_open():
		if effects != null and not game.checkpoint_all_ready(): return false
		if not game.checkpoint_pending:
			game.checkpoint_pending=true
			game.checkpoint_ready.clear()
		if not game.checkpoint_all_ready():
			for peer_id in game.players:
				if game.Life.alive(game.players[peer_id]): game.present_checkpoint_cards(peer_id)
			return false
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
			preload("res://garden_return_service.gd").bank(game,player,player.carried_seeds,"extract")
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
			preload("res://garden_return_service.gd").outcome(game,player,"fallen" if game.PlayerLifecycle.fallen(player) else "extracted")
			return_member(game, player)
			if peer_id != id:
				game.action_feedback(effects,peer_id, message)
	game.participation.select_route(game.Campaign.GROVE)
	reset(game)
	if effects == null and (banked > 0 or banked_parts > 0 or milestone > 0):
		game.save_progress(id, message)
	else:
		game.action_feedback(effects,id,message)
	return true


static func reset(game: Node) -> void:
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


static func finish_if_empty(game: Node) -> void:
	if game.participation.active() and game.Life.living_ids(game).is_empty():
		finish_failed(game)
	elif not game.participation.active() and (game.enemy_health() < game.encounter_health() or game.deepest_milestone > 0):
		finish_failed(game)


static func finish_failed(game: Node) -> bool:
	if game.has_meta(game.Transactions.SESSION):
		var result: Dictionary = game.run_guarded_action(game.HOST, game.Transactions.Scope.PAIR, func(effects): commit_failed(game, effects))
		return game.Transactions.committed(result.persistence)
	var returned=game.Transactions.run(game,func(): commit_failed(game))
	if returned==false:game.battlefield.configure(game.participation.route(),game.participation.depth(),game.participation.seed())
	return returned!=false


static func commit_failed(game: Node, effects = null) -> void:
	if effects != null: game.settle_expedition_rewards(effects, true)
	for player in game.players.values():
		if effects == null: game.recover_pouch(player)
		else: game._recover_pouch(player)
		if Participation.is_wild(player):
			preload("res://garden_return_service.gd").outcome(game,player,"wipe")
			return_member(game, player)
	var milestone: int = game.deepest_milestone
	var message: String = game.milestone_message("Expedition ended. Only safe-pouch contents are kept.", false)
	game.participation.select_route(game.Campaign.GROVE)
	reset(game)
	if milestone > 0 and effects == null:
		game.save_progress(game.HOST, message)
	else:
		game.action_feedback(effects,game.HOST,message)
	for id in game.players:
		if id != game.HOST:
			game.action_feedback(effects,id,message)


static func abandon(game: Node, id: int,player: Dictionary) -> void:
	if not Participation.is_wild(player): return
	if game.has_meta(game.Transactions.SESSION):
		game.run_guarded_action(id, game.Transactions.Scope.PAIR, func(effects):
			game.settle_expedition_rewards(effects, true)
			preload("res://garden_return_service.gd").outcome(game,player,"abandoned")
			return_member(game,player)
			game.checkpoint_ready.erase(id)
			game.action_feedback(effects,id,"Expedition abandoned. All carried items lost, including the safe pouch. Class progress kept.")
			game.PartyTravel.cancel(game,"A teammate left the expedition. Confirm readiness again at the gate.",effects)
			if game.participation.active() and game.Life.living_ids(game).is_empty():
				commit_failed(game,effects)
			elif not game.participation.active():
				game.participation.select_route(game.Campaign.GROVE)
				reset(game)
			effects.append(game.close_flow_for.bind(id)))
		return
	game.Transactions.run(game,func():
		preload("res://garden_return_service.gd").outcome(game,player,"abandoned")
		return_member(game,player)
		game.checkpoint_ready.erase(id)
		game.tell(id,"Expedition abandoned. All carried items lost, including the safe pouch. Class progress kept.")
		if game.participation.active() and game.Life.living_ids(game).is_empty():
			finish_failed(game)
		elif not game.participation.active():
			game.participation.select_route(game.Campaign.GROVE)
			reset(game)
		else:
			game.resume_checkpoint_if_ready()
		if id==game.HOST: game.close_run_flow_panel()
		elif game.network_session.transport()!=null: game.close_run_flow_panel.rpc_id(id)
		return true)
