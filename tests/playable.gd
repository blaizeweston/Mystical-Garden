extends SceneTree

const WeaponActions = preload("res://player_weapon_actions.gd")
## Current integrated solo smoke. Historical species/paid-card/graft branches
## are retired; focused Garden and independent co-op fixtures retain coverage.
const ExpeditionCase=preload("res://tests/support/expedition_case.gd")
const Cards=preload("res://affinity_cards.gd")
const Vitals=preload("res://player_vitals.gd")
const Cooldowns=preload("res://player_cooldowns.gd")
var failed:=false

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool,label: String) -> void:
	if not ok:
		failed=true
		printerr("FAIL playable modern: ",label)

func run() -> void:
	var world: Node=load("res://world.tscn").instantiate()
	var path: String="res://.godot/playable-modern-"+Crypto.new().generate_random_bytes(8).hex_encode()
	world.progress.path=path+".garden"
	world.local_character.path=path+".character"
	world.guest_character.path=path+".guest"
	world.settings_path=path+".settings"
	root.add_child(world)
	world.set_process(false)
	world.set_physics_process(false)
	var actor: Dictionary=world.players[1]
	check(not ExpeditionCase.is_wild(actor) and world.network_session.role()=="Solo","fresh integrated Garden starts offline")
	actor.pos=world.Stage.GATE
	world.handle_loadout_action(1,actor,"learn_0_64")
	var graph=world.Classes.connected_tree(0)
	check(graph.focus(actor.character)=="vanguard" and actor.character.xp[0]==0,"starting focus is a real host-validated zero-XP selection")
	world.send_action(false)
	check(world.loadout_menu.visible and not ExpeditionCase.is_wild(actor),"Gate presents preparation before entry")
	world.send_garden_action("depart")
	check(ExpeditionCase.is_wild(actor) and actor.weapon==0 and actor.secondary==0 and actor.catalyst==0,"empty plant slots permit native class combat")
	if not ExpeditionCase.is_wild(actor):
		world.free()
		quit(1)
		return
	world.battlefield.configure(0,1,0)
	world.battlefield.barriers.clear()
	world.encounter.clear_scouts()
	world.encounter.set_hp(-1,100)
	world.tactics.position=Vector3(0,0,-1)
	actor.pos=Vector3.ZERO
	actor.facing=Vector3.FORWARD
	world.use_class_skill(1,actor,0)
	check(actor.guard_charges==1 and actor[Cooldowns.STATE].deadline(Cooldowns.Q)>0,"native Thorn Counter works without plants or upgrades")
	world.use_class_skill(1,actor,1)
	check(world.enemy_health()<100 and actor[Cooldowns.STATE].deadline(Cooldowns.R)>0,"native Root Quake damages a real enemy")
	world.encounter.set_hp(-1,1)
	actor.cast_until=0
	actor[WeaponActions.STATE] = actor[WeaponActions.STATE].with_ready_at(0)
	world.strike_enemy(1,actor,actor.pos)
	world.update_projectiles(Time.get_ticks_msec()+2000)
	check(world.enemy_health()==0 and world.monster_rewards.pending_count()>=0,"a real ordinary weapon contact resolves an authoritative kill")
	ExpeditionCase.set_world(world,{"encounter_number":3})
	world.deepest_milestone=3
	world.encounter.clear_scouts()
	world.encounter.set_hp(-1,0)
	world.encounter_rewarded=true
	actor.pos=world.battlefield.advance
	ExpeditionCase.Transitions.checkpoint(world,1,true)
	var offer: Dictionary=world.checkpoint_card_data(actor)[0]
	check(world.checkpoint_menu.visible and offer.choices.size()==3,"cleared checkpoint opens three modern choices")
	var spent: int=world.wallet_for(actor).spent_essence()
	var command: String=world.affinity_checkpoint_action(offer.revision,"0")
	world.send_garden_action(command)
	check(Cards.ledger(actor).count()==1 and world.wallet_for(actor).spent_essence()==spent and world.participation.floor()==4,"free acquisition precedes solo floor travel")
	world.send_garden_action(command)
	check(Cards.ledger(actor).count()==1,"stale acquisition cannot duplicate a copy")
	world.send_garden_action("abandon_run")
	check(not ExpeditionCase.is_wild(actor) and Cards.ledger(actor)==null and world.run_wallet(actor)==0 and Vitals.current_hp(actor)>0,"Garden return clears run cards and Essence while restoring native health")
	world.free()
	await process_frame
	if not failed:
		print("PASS: modern integrated Garden preparation, native class combat, real kill, free cards, floor travel and expedition cleanup")
	quit(int(failed))
