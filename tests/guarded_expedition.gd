extends SceneTree

const WeaponActions = preload("res://player_weapon_actions.gd")

const SessionCase = preload("res://tests/support/session_case.gd")

const ExpeditionCase = preload("res://tests/support/expedition_case.gd")
const Cards = preload("res://affinity_cards.gd")

const IncomingPlayerHit = preload("res://incoming_player_hit.gd")

const PlayerLifecycle = preload("res://player_lifecycle.gd")
const PlayerVitals = preload("res://player_vitals.gd")

const Cooldowns = preload("res://player_cooldowns.gd")

const Tx=preload("res://game_transaction.gd")
const Plan=preload("res://persistence_recovery_plan.gd")
const Ops=preload("res://persistence_operations.gd")
const Slots=preload("res://save_slots.gd")
const Gate=preload("res://persistence_writer_integration.gd")
const G="user://saves/slot_1/garden.cfg"
const C="user://saves/characters/slot_1/character.cfg"
var failed:=false
var world: Node

func _initialize() -> void:
 call_deferred("run")

func check(ok: bool, message: String) -> void:
 if not ok:
  failed=true
  printerr("FAIL: ",message)

func disk() -> Dictionary:
 var result:={}
 for p in [G,C]:
  for suffix in [""]+Plan.ARTIFACTS: result[p+suffix]=Slots._save_digest(p+suffix)
 return result

func record(label: String,before: Dictionary) -> void:
 print("CASE ",JSON.stringify({"case":label,"run_id":OS.get_environment("MYSTICAL_VALIDATION_RUN"),"before":before,"after":disk(),
  "floor":world.participation.floor(),"wild":world.participation.active(),"pending":world.persistence_session.pending_notice(),"status":world.status,
  "queued_kills":world.monster_rewards.pending_count(),"queued_departures":world.departure_settlement.count(),"event_serial":world.combat_event_serial}))

func open_world(fresh := false) -> bool:
 var title: Node = current_scene
 if title == null:
  var scene: String = ProjectSettings.get_setting("application/run/main_scene")
  title = load(scene).instantiate()
  root.add_child(title)
  current_scene = title
 check(title.production_route and title.guarded_persistence, "configured title selects guarded route")
 if fresh:
  title.new_button.pressed.emit()
  check(title.creator.visible, "New opens title character creator")
  title.creator.name_field.text = "Candidate Keeper"
  title.creator.confirmed.emit()
  if current_scene == title: title.new_button.pressed.emit()
 else:
  title.continue_button.pressed.emit()
 if current_scene == title or not SessionCase.has_guarded_session(current_scene):
  check(false, "guarded title handoff failed: " + title.notice.text)
  return false
 world = current_scene
 check(world.persistence_session.owns_leases(), "title handoff owns Garden and profile leases")
 world.set_process(false)
 world.set_physics_process(false)
 var actor: Dictionary=world.players[1]
 var tree=world.Classes.connected_tree(int(actor.frame))
 if tree.focus(actor.character).is_empty():
  var prior_position: Vector3=actor.pos
  actor.pos=world.Stage.HEART
  world.handle_loadout_action(1,actor,"learn_0_64")
  actor.pos=prior_position
  world.toggle_overlay(null)
 return true

func close_world() -> void:
 world.return_to_main_menu()
 check(current_scene != world and root.get_multiplayer().multiplayer_peer is OfflineMultiplayerPeer,
  "guarded title return installs offline peer")

func fail_stage(phase: String,path: String) -> Error:
 return ERR_FILE_CANT_WRITE if phase=="stage" and path==C+".txn_stage" else OK

func fail_restore(phase: String,path: String) -> Error:
 if phase=="replace" and path==G: return ERR_CANT_CREATE
 return ERR_FILE_CANT_WRITE if phase=="restore" else OK

func fail_receipt(phase: String,_path: String) -> Error:
 return ERR_CANT_CREATE if phase=="publish_receipt" else OK

func clear_floor(actor: Dictionary,floor: int) -> void:
 ExpeditionCase.set_world(world, {"encounter_number": floor})
 world.deepest_milestone=floor
 world.encounter.set_hp(-1, 0)
 world.encounter.clear_scouts()
 world.encounter_rewarded=true
 actor.pos=world.battlefield.advance

func start_save_set() -> bool:
 set_meta(Gate.VALIDATION_ROUTE, true)
 return open_world(true)

func check_departure_lifecycle() -> void:
 var ledger := preload("res://departure_settlement.gd").new()
 var phase := ledger.Phase
 var outcome := ledger.Result
 var identity := "detached-profile"
 var snapshot := {"wild":true, "character":{"xp":[7]}, "safe_items":[{"quantity":1}]}
 ledger.register(2,identity,snapshot)
 ledger.register(2,identity,{"wild":false})
 snapshot.character.xp[0]=99
 check(ledger.count()==1 and ledger.status(identity)==phase.WAITING and ledger.has_wild_departure(),
  "one detached departure owns captured profile and cargo")
 check(ledger.stage([identity]).is_empty() and ledger.blocks_admission(identity),
  "deferred Class XP prevents retirement and readmission")
 var work := ledger.stage([])
 check(work.size()==1 and work[0].actor.character.xp[0]==7 and ledger.stage([]).is_empty()
  and ledger.status(identity)==phase.SETTLING,"staging detaches captured state and admits no duplicate work")
 work[0].actor.safe_items[0].quantity=5
 ledger.finish(outcome.RESTORED)
 check(ledger.status(identity)==phase.RETRYABLE and ledger.blocks_admission(identity),
  "verified rollback leaves departure retryable and blocks readmission")
 work=ledger.stage([])
 check(work.size()==1 and work[0].actor.safe_items[0].quantity==1,"rollback retries original cargo")
 ledger.finish(outcome.CLEANUP_PENDING)
 check(ledger.status(identity)==phase.CLEANUP_PENDING and ledger.blocks_admission(identity)
  and ledger.stage([]).is_empty(),"committed cleanup hold retains identity without replaying cargo")
 ledger.register(3,"second-profile",snapshot)
 work=ledger.stage([])
 ledger.finish(outcome.UNCERTAIN)
 check(work.size()==1 and ledger.status("second-profile")==phase.UNCERTAIN
  and ledger.stage([]).is_empty(),"uncertain departure cannot replay")
 ledger.finish(outcome.COMMITTED)
 check(ledger.count()==2,"later unrelated confirmation cannot retire unresolved holds")

func run() -> void:
 check_departure_lifecycle()
 var interruption:=OS.get_environment("MYSTICAL_GROUP3B2B_MODE")
 if interruption=="recover":
  var before:=disk()
  var recovered:=Ops.recover(PackedStringArray([C]))
  var verified: bool=recovered.ran and recovered.value is Dictionary and recovered.value.get("verified",false)
  check(verified,"interrupted combat settlement restored through profile: "+str(recovered))
  print("CASE ",JSON.stringify({"case":"restart","before":before,"after":disk(),"verified":verified}))
 elif start_save_set():
  if interruption=="owner":
   interrupted()
  else:
   await exercise()
 if not failed: print("PASS: guarded expedition settlement and lifecycle")
 quit(1 if failed else 0)

func interrupted() -> void:
 var actor: Dictionary=world.players[1]
 actor.pos=world.Stage.GATE
 ExpeditionCase.Transitions.enter(world, 1,actor)
 world.encounter.set_hp(-1, 0)
 world.record_enemy_death(-1,world.tactics.position,Vector3.ZERO)
 world.encounter.clear_scouts()
 var before:=disk()
 world.set_meta(&"guarded_gameplay_test_fault",func(phase,path):
  if phase=="replace" and path==G:
   record("interruption_barrier",before)
   while true: OS.delay_msec(100)
  return OK)
 world.finish_combat(1,world.tactics.position)
 check(false,"must terminate the owner at replacement")

func exercise() -> void:
 var actor: Dictionary=world.players[1]
 actor.pos=world.Stage.GATE
 actor.prepared=1
 var garden_timers: Cooldowns.Timers = actor[Cooldowns.STATE].with_deadline(Cooldowns.Q, 2100).with_deadline(Cooldowns.R, 2200).with_deadline(Cooldowns.DODGE, 2300)
 actor[Cooldowns.STATE] = garden_timers
 world.progress.add_parts(1,3)
 var before:=disk()
 var field: RefCounted=world.battlefield
 var seed: int=world.map_rng.state
 world.open_gate_preparation()
 world.set_meta(&"guarded_gameplay_test_fault",fail_stage)
 world.garden_action(1,"depart")
 check(disk()==before and not ExpeditionCase.is_wild(actor) and actor.prepared==1 and world.battlefield==field and world.map_rng.state==seed
  and world.loadout_menu.visible and world.run_wallet(actor)==0,
  "departure abort restores map RNG, battlefield, material, actor and open UI")
 check(is_same(actor[Cooldowns.STATE],garden_timers) and garden_timers.deadline(Cooldowns.Q)==2100
  and garden_timers.deadline(Cooldowns.R)==2200 and garden_timers.deadline(Cooldowns.DODGE)==2300,
  "verified departure rollback restores all original cooldown deadlines and owner identity")
 record("departure_abort",before)
 world.remove_meta(&"guarded_gameplay_test_fault")
 world.garden_action(1,"depart")
 check(ExpeditionCase.is_wild(actor) and actor.weapon==1 and world.progress.part_count(1)==2 and not world.loadout_menu.visible
  and disk()[G]!=before[G] and world.run_wallet(actor)==0,"departure commits a fresh wallet before panel closure")
 var departed_timers: Cooldowns.Timers = actor[Cooldowns.STATE]
 check(not is_same(departed_timers,garden_timers) and departed_timers.deadline(Cooldowns.Q)==0
  and departed_timers.deadline(Cooldowns.R)==0 and departed_timers.deadline(Cooldowns.DODGE)==0,
  "successful expedition entry starts three fresh cooldowns")
 var initial_wallet = world.wallet_for(actor)
 var action_before: WeaponActions.State=actor[WeaponActions.STATE]
 var queue_before: int=world.projectile_queue.size()
 world.set_meta(&"guarded_gameplay_test_fault",fail_stage)
 var refused_attack: Dictionary=world.run_guarded_action(1,Tx.Scope.PAIR,func(_effects):
  world.strike_enemy(1,actor,actor.pos)
  return true)
 world.remove_meta(&"guarded_gameplay_test_fault")
 check(not Tx.committed(refused_attack.persistence) and is_same(actor[WeaponActions.STATE],action_before)
  and actor[WeaponActions.STATE].sequence()==0 and world.projectile_queue.size()==queue_before,
  "guarded attack abort restores the original weapon state and removes the attempted contact")
 check(not actor.has("strike_at") and not actor.has("attack_until") and not actor.has("ranged_windup"),
  "host actor has one authoritative weapon component, not duplicate raw fields")
 record("departure_commit",before)

 var trophy_config: Dictionary = world.Director.config()
 var previous_config := trophy_config.duplicate()
 trophy_config.merge({"trophy_chance":1.0,"trophy_cap":1.0},true)
 world.encounter.set_hp(-1, 0)
 world.record_enemy_death(-1,world.tactics.position,Vector3.ZERO)
 trophy_config.merge(previous_config,true)
 var frozen: int=world.rng.state
 world.record_enemy_death(-1,world.tactics.position,Vector3.ZERO)
 check(world.monster_rewards.pending_count()==1 and world.rng.state==frozen,"duplicate receipt does not reroll")
 var frozen_item: String = world.monster_rewards.pending_receipts()[0].rewards[0].item
 check(not frozen_item.is_empty(),"fixture freezes an actual trophy roll")
 world.encounter.set_hp(-1, 0)
 world.encounter.clear_scouts()
 world.burst_hits_this_room=3
 before=disk()
 var serial: int=world.combat_event_serial
 world.set_meta(&"guarded_gameplay_test_fault",fail_stage)
 world.finish_combat(1,world.tactics.position)
 check(not world.encounter_rewarded and not actor.loot_pending and actor.character.monsters[world.enemy_kind]==0 and world.monster_rewards.pending_count()==1
  and world.wild_item_drops.is_empty() and world.combat_event_serial==serial and world.rng.state==frozen and disk()==before
  and world.wallet_for(actor)==initial_wallet and world.run_wallet(actor)==0,"encounter abort keeps the frozen receipt and withholds rewards, drop and cue")
 record("encounter_abort",before)
 world.remove_meta(&"guarded_gameplay_test_fault")
 world.finish_combat(1,world.tactics.position)
 var earned_wallet = world.wallet_for(actor)
 var earned_balance: int = world.run_wallet(actor)
 check(world.encounter_rewarded and actor.loot_pending and earned_wallet.earned_sparks()>0
  and earned_balance>=2 and actor.character.monsters[world.enemy_kind]==1
  and world.wild_item_drops.size()==1 and world.wild_item_drops[0].stack.item==frozen_item
  and world.progress.wilds_memory.encounters==1 and disk()[G]!=before[G] and disk()[C]!=before[C],
  "encounter commits frozen XP, trophy, adaptation, and cue together")
 var committed:=disk()
 world.finish_combat(1,world.tactics.position)
 check(world.flush_kill_rewards() and disk()==committed and world.wild_item_drops.size()==1
  and world.wallet_for(actor)==earned_wallet and world.run_wallet(actor)==earned_balance,"repeat flush and completion cannot credit twice")
 record("encounter_commit",before)

 world.add_player(2)
 var ally: Dictionary=world.players[2]
 SessionCase.set_ready(world, ally, true)
 SessionCase.set_identity(world, ally, "ally")
 ExpeditionCase.set_membership(world, ally, true)
 world.battlefield.procedural=false
 world.battlefield.barriers.clear()
 actor.pos=Vector3.ZERO
 ally.pos=Vector3(.5,0,0)
 var combat_timers: Cooldowns.Timers = departed_timers.with_deadline(Cooldowns.Q, 3100).with_deadline(Cooldowns.R, 3200).with_deadline(Cooldowns.DODGE, 3300)
 actor[Cooldowns.STATE] = combat_timers
 var hp: int=int(PlayerVitals.current_hp(actor))
 var active_generation := PlayerLifecycle.generation(actor)
 IncomingPlayerHit.apply_health_loss(world, 1, PlayerLifecycle.generation(actor), 1)
 check(int(PlayerVitals.current_hp(actor))==hp-1 and disk()==committed,"nonlethal damage is runtime-only")
 var before_hit_health: PlayerVitals.Health=actor[PlayerVitals.STATE]
 var before_hit_status := [int(actor.hurt_until), int(actor.slow_until), int(actor.damage_seq), int(actor.damage_amount)]
 var impact_at := maxi(Time.get_ticks_msec(), int(actor.hurt_until)) + 1
 world.set_meta(&"guarded_gameplay_test_fault",fail_stage)
 var uncommitted := IncomingPlayerHit.resolve_world(world,1,active_generation,impact_at,999.0,750)
 world.remove_meta(&"guarded_gameplay_test_fault")
 check(uncommitted.kind==IncomingPlayerHit.Outcome.UNCOMMITTED and not uncommitted.damage_recorded
  and is_same(actor[PlayerVitals.STATE],before_hit_health) and PlayerLifecycle.matches(actor,active_generation)
  and not PlayerLifecycle.fallen(actor) and disk()==committed
  and before_hit_status==[int(actor.hurt_until),int(actor.slow_until),int(actor.damage_seq),int(actor.damage_amount)],
  "aborted lethal enemy contact restores the same HP owner, life, grace, Slow and damage sequence")
 IncomingPlayerHit.apply_health_loss(world, 1, PlayerLifecycle.generation(actor), 999)
 check(PlayerLifecycle.fallen(actor) and PlayerVitals.current_hp(actor)==0 and world.wallet_for(actor)==earned_wallet
  and world.run_wallet(actor)==earned_balance,"the downed player keeps their run wallet")
 check(is_same(actor[Cooldowns.STATE],combat_timers),"fall preserves existing cooldowns")
 check(PlayerLifecycle.matches(actor,active_generation),"fall keeps the current generation until successful revival")
 var fallen_life: PlayerLifecycle.Life = actor[PlayerLifecycle.STATE]
 var fallen_health: PlayerVitals.Health = actor[PlayerVitals.STATE]
 var revive_before := disk()
 world.set_meta(&"guarded_gameplay_test_fault",fail_stage)
 world.revive_player(2,1)
 world.remove_meta(&"guarded_gameplay_test_fault")
 check(PlayerLifecycle.fallen(actor) and is_same(actor[PlayerLifecycle.STATE],fallen_life)
  and is_same(actor[PlayerVitals.STATE],fallen_health) and int(actor.lost_health)==0 and disk()==revive_before,
  "guarded revival abort restores the fallen owner, generation, health and injury")
 world.revive_player(2,1)
 var paid: int=int(actor.lost_health)
 var revived_generation := PlayerLifecycle.generation(actor)
 check(not PlayerLifecycle.fallen(actor) and PlayerVitals.current_hp(actor)>0 and paid==world.Life.Preview.revive_cost()
  and world.wallet_for(actor)==earned_wallet and world.run_wallet(actor)==earned_balance,
  "revival commits one maximum-health cost without changing Essence")
 check(revived_generation!=active_generation and is_same(actor[Cooldowns.STATE],combat_timers),
  "revival starts a new life and preserves existing cooldowns")
 world.revive_player(2,1)
 check(actor.lost_health==paid and PlayerLifecycle.matches(actor,revived_generation),"duplicate revival cannot charge or change generation twice")
 ExpeditionCase.set_membership(world, ally, false)
 ExpeditionCase.remove_actor(world, 2)

 clear_floor(actor,3)
 ExpeditionCase.Transitions.checkpoint(world, 1,true)
 check(world.checkpoint_pending and world.checkpoint_menu.visible and world.participation.floor()==3,"checkpoint opens cards without travelling")
 var offer: Dictionary=world.checkpoint_card_data(actor)[0]
 var card_wallet: int=world.wallet_for(actor).spent_essence()
 world.send_garden_action(world.affinity_checkpoint_action(offer.revision,"0"))
 var selected_cards=Cards.ledger(actor)
 check(world.participation.floor()==3 and world.checkpoint_ready.get(1)==3 and selected_cards.count()==1 and world.wallet_for(actor).spent_essence()==card_wallet,"free card is accepted before guarded travel")
 actor[PlayerVitals.STATE] = actor[PlayerVitals.STATE].with_hp(1.0)
 var health_before_floor: PlayerVitals.Health = actor[PlayerVitals.STATE]
 var remains: Dictionary=world.make_scout(0,world.tactics.position,1)
 remains.hp=0
 var remains_slot: int=world.encounter.register_scout(remains)
 var remains_token: int=world.encounter.token(remains_slot)
 var tactical_position: Vector3=world.tactics.position
 var tactical_ready_at := Time.get_ticks_msec()+7000
 world.tactics.ready_at=tactical_ready_at
 world.tactics.memory["ar10_fixture_plan"]={"points":[Vector3.RIGHT]}
 field=world.battlefield
 seed=world.map_rng.state
 var healing_rng: int=world.Life.Preview.heal_rng.state
 before=disk()
 world.set_meta(&"guarded_gameplay_test_fault",fail_stage)
 ExpeditionCase.Transitions.checkpoint(world, 1,true)
 check(world.participation.floor()==3 and world.battlefield==field and world.map_rng.state==seed and world.Life.Preview.heal_rng.state==healing_rng
  and is_same(actor[PlayerVitals.STATE],health_before_floor) and PlayerVitals.current_hp(actor)==1
  and world.checkpoint_ready.get(1)==3 and is_same(Cards.ledger(actor),selected_cards) and disk()==before,"floor abort restores navigation, RNG, original health owner and acquired card owner")
 check(world.encounter.cleared() and world.encounter.scout_count()==1
  and world.encounter.token(remains_slot)==remains_token and world.encounter.hp(remains_slot)==0,
  "floor abort restores the cleared roster and its departed member identity")
 check(world.tactics.position==tactical_position and world.tactics.ready_at==tactical_ready_at
  and world.tactics.memory.get("ar10_fixture_plan",{}).get("points",[])==[Vector3.RIGHT],
  "floor abort restores the leader position, attack deadline and nested tactics")
 record("checkpoint_abort",before)
 world.remove_meta(&"guarded_gameplay_test_fault")
 ExpeditionCase.Transitions.checkpoint(world, 1,true)
 check(world.participation.floor()==4 and world.battlefield!=field and world.map_rng.state!=seed
  and health_before_floor.hp()==1.0 and PlayerVitals.current_hp(actor)>1.0,"checkpoint advances after confirmed save and installs recovered health")
 check(world.encounter.token(remains_slot)!=remains_token,"successful floor travel discards the previous roster identity")
 check(world.tactics.ready_at!=tactical_ready_at and not world.tactics.memory.has("ar10_fixture_plan"),
  "successful floor travel discards the previous deadline and behavior memory")

 clear_floor(actor,6)
 actor.carried_seeds=[0,1]
 actor.carried_parts[1]=2
 actor.safe_items=[{"item":"unidentified_seed","quantity":1,"seeds":[0]}]
 before=disk()
 world.set_meta(&"guarded_gameplay_test_fault",fail_receipt)
 ExpeditionCase.Transitions.checkpoint(world, 1,false)
 world.remove_meta(&"guarded_gameplay_test_fault")
 world.refresh_feedback()
 check(not ExpeditionCase.is_wild(actor) and world.progress.unknown.size()==3 and world.progress.campaign.best_extraction==6 and disk()[G]!=before[G]
  and world.feedback.text.contains("Extracted with") and world.feedback.text.contains(Tx.CLEANUP_NOTICE) and FileAccess.file_exists(G+".transaction"),
  "cleanup-pending extraction commits inventory and progression and retains notice")
 committed=disk()
 ExpeditionCase.Transitions.checkpoint(world, 1,false)
 check(disk()==committed and world.progress.unknown.size()==3,"pending extraction cannot replay")
 record("extraction_cleanup_pending",before)
 check(Ops.recover(PackedStringArray([G])).value.verified and disk()[G]==committed[G],"cleanup preserves committed extraction")
 close_world()
 await process_frame
 if not open_world(): return
 actor=world.players[1]

 actor.pos=world.Stage.GATE
 ExpeditionCase.Transitions.enter(world, 1,actor)
 clear_floor(actor,2)
 actor.safe_items=[{"item":"unidentified_seed","quantity":1,"seeds":[0]}]
 actor.carried_seeds=[1]
 var saved_seeds: int=world.progress.unknown.size()
 IncomingPlayerHit.apply_health_loss(world, 1, PlayerLifecycle.generation(actor), 999)
 check(not ExpeditionCase.is_wild(actor) and world.progress.unknown.size()==saved_seeds+1 and world.status.contains("safe-pouch"),"wipe keeps only protected cargo")
 actor.pos=world.Stage.GATE
 ExpeditionCase.Transitions.enter(world, 1,actor)
 actor.safe_items=[{"item":"unidentified_seed","quantity":1,"seeds":[0]}]
 saved_seeds=world.progress.unknown.size()
 ExpeditionCase.Transitions.abandon(world, 1,actor)
 check(not ExpeditionCase.is_wild(actor) and world.progress.unknown.size()==saved_seeds and world.status.contains("abandoned"),"abandonment discards safe pouch")

 actor.pos=world.Stage.GATE
 ExpeditionCase.Transitions.enter(world, 1,actor)
 clear_floor(actor,6)
 actor.carried_seeds=[1]
 world.record_enemy_death(-1,world.tactics.position,Vector3.ZERO)
 before=disk()
 world.open_gate_preparation()
 world.set_meta(&"guarded_gameplay_test_fault",fail_restore)
 ExpeditionCase.Transitions.checkpoint(world, 1,false)
 world.remove_meta(&"guarded_gameplay_test_fault")
 var split:=disk()
 check(not ExpeditionCase.is_wild(actor) and world.progress.unknown.size()==saved_seeds+1 and world.loadout_menu.visible and world.persistence_session.pending_notice().contains("uncertain")
  and split[C]!=before[C] and split[G]==before[G] and not world.status.contains("Extracted with"),"uncertain extraction keeps tentative memory and withholds notice/closure")
 ExpeditionCase.Transitions.checkpoint(world, 1,false)
 check(disk()==split,"uncertain operation does not replay")
 record("extraction_uncertain",before)
 close_world()
 await process_frame
 check(current_scene.recovery_notice.visible and current_scene.continue_button.disabled
  and disk()==split,"uncertain return preserves blocked title warning and evidence")
 current_scene.garden_recovery_button.pressed.emit()
 current_scene.recovery_confirmation.confirmed.emit()
 check(disk()==before and not current_scene.recovery_notice.visible,"title B2 restoration clears uncertain warning")
 if not open_world(): return
 actor=world.players[1]

 world.add_player(2)
 ally=world.players[2]
 SessionCase.set_ready(world, ally, true)
 var departed_identity := "0000000000000000000000000000a404"
 SessionCase.set_identity(world, ally, departed_identity)
 var departed_class := int(ally.frame)
 var guest_tree: RefCounted = world.Classes.connected_tree(departed_class)
 # Synthetic guest setup must supply an actual modern focus without banking
 # its profile before the pending-departure settlement under test.
 check(guest_tree.learn(ally.character,guest_tree.REQUEST_OFFSET).is_empty(),
  "guest selects a valid native starting focus before party admission")
 var xp_before := int(ally.character.xp[departed_class])
 actor.pos=world.Stage.GATE
 ally.pos=world.Stage.GATE
 ExpeditionCase.Transitions.enter(world, 1,actor)
 ExpeditionCase.Transitions.enter(world, 2,ally)
 check(ExpeditionCase.is_wild(actor) and ExpeditionCase.is_wild(ally),
  "host and focused guest commit actual party admission before freezing kill rewards")
 ally.safe_items=[{"item":"unidentified_seed","quantity":1,"seeds":[0]}]
 world.encounter.set_hp(-1, 0)
 world.record_enemy_death(-1,world.tactics.position,Vector3.ZERO)
 var receipt: Dictionary = world.monster_rewards.pending_receipts()[0]
 var earned_xp := 0
 for reward: Dictionary in receipt.rewards:
  if reward.id==2: earned_xp=int(reward.xp)
 before=disk()
 world.set_meta(&"guarded_gameplay_test_fault",fail_stage)
 SessionCase.World.remove(world,2)
 check(not world.players.has(2) and world.departure_settlement.status(departed_identity)==world.DepartureSettlement.Phase.RETRYABLE
  and world.monster_rewards.pending_count()==1 and disk()==before
  and not ally.has(world.ExpeditionWallet.STATE) and world.run_wallet(ally)==0,
  "failed disconnect settlement retains cargo and frozen reward and clears run-only currency")
 var catalog: Dictionary = world.progress.ContentIDs.manifest()
 check(SessionCase.World.admission_error(world,departed_identity,catalog,world.Network.PROTOCOL).contains("still being saved"),
  "verified rollback does not release the character before rewards settle")
 world.grant_run_essence(2,ally,4)
 check(not ally.has(world.ExpeditionWallet.STATE) and world.run_wallet(ally)==0,"pending departure cannot receive a credit")
 world.remove_meta(&"guarded_gameplay_test_fault")
 ally.character.xp[departed_class]+=100
 ally.safe_items.clear()
 # Simulate a non-banking operation between departure and the experimental
 # floor checkpoint without starting another terrain session.
 world.set_meta(&"experimental_terrain",true)
 var deferred: Dictionary=world.run_guarded_action(1,Tx.Scope.PAIR,func(effects):
  world.settle_expedition_rewards(effects)
  return true)
 world.remove_meta(&"experimental_terrain")
 check(Tx.committed(deferred.persistence) and world.departure_settlement.blocks_admission(departed_identity)
  and world.monster_rewards.pending_count()==1 and not world.progress.character_records.has(departed_identity),
  "non-banking transaction cannot retire the recipient of frozen Class XP")
 check(world.flush_kill_rewards() and world.departure_settlement.is_empty() and world.monster_rewards.pending_count()==0
  and earned_xp>0 and int(world.progress.character_records[departed_identity].profile.xp[departed_class])==xp_before+earned_xp
  and world.progress.character_records[departed_identity].profile.monsters[world.enemy_kind]==1
  and world.progress.reserve(departed_identity).unknown.size()==1
  and not ally.has(world.ExpeditionWallet.STATE) and world.run_wallet(ally)==0,
  "flush credits detached Class XP and pouch once without restoring a run wallet")
 var settled_disk:=disk()
 world._queue_monster_reward(receipt.key.get_slice(":",1),int(receipt.kind),0,receipt.position,false)
 check(world.flush_kill_rewards() and world.monster_rewards.pending_count()==0 and disk()==settled_disk
  and world.progress.reserve(departed_identity).unknown.size()==1,"delayed duplicate receipt cannot change settled profile or cargo")
 record("disconnect_abort_then_commit",before)

 var lease:=G.get_base_dir().path_join("session.cfg")
 var foreign:=ConfigFile.new()
 foreign.set_value("session","process_id",OS.get_process_id()+1)
 foreign.set_value("session","updated",Time.get_unix_time_from_system())
 check(foreign.save(lease)==OK,"inject foreign lease")
 before=disk()
 hp=int(PlayerVitals.current_hp(actor))
 IncomingPlayerHit.apply_health_loss(world, 1, PlayerLifecycle.generation(actor), 999)
 world.finish_combat(1,world.tactics.position)
 ExpeditionCase.Transitions.abandon(world, 1,actor)
 check(int(PlayerVitals.current_hp(actor))==hp and ExpeditionCase.is_wild(actor) and disk()==before,"lost lease prevents combat and settlement writes")
 world.return_to_main_menu()
 check(world.persistence_session.is_stopping() and disk()==before,"lost lease shuts down without saving")
 record("lost_lease_shutdown",before)
 await process_frame
 check(current_scene != world and root.get_multiplayer().multiplayer_peer is OfflineMultiplayerPeer,"lost lease shutdown detaches after offline")
 check(DirAccess.remove_absolute(lease)==OK,"remove disposable foreign marker")
 current_scene.select_slot(0)
 if not open_world(): return
 actor=world.players[1]
 actor.pos=world.Stage.GATE
 ExpeditionCase.Transitions.enter(world, 1,actor)

 actor.safe_items=[{"item":"unidentified_seed","quantity":1,"seeds":[0]}]
 before=disk()
 world.set_meta(&"guarded_gameplay_test_fault",fail_stage)
 world.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
 check(not world.persistence_session.is_stopping() and ExpeditionCase.is_wild(actor) and disk()==before and current_scene==world,
  "window-close settlement abort keeps the world and original saves")
 record("window_close_abort",before)
 world.return_to_main_menu()
 check(not world.returning_to_title and ExpeditionCase.is_wild(actor) and disk()==before,"title settlement abort stays in expedition")
 world.remove_meta(&"guarded_gameplay_test_fault")
 world.return_to_main_menu()
 check(world.returning_to_title and not ExpeditionCase.is_wild(actor) and world.multiplayer.multiplayer_peer is OfflineMultiplayerPeer and disk()[G]!=before[G],
  "title return settles exactly once and installs offline peer")
 record("title_commit",before)
