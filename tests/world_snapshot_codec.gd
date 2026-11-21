extends SceneTree

const ExpeditionCase = preload("res://tests/support/expedition_case.gd")
const SessionCase = preload("res://tests/support/session_case.gd")

const Codec = preload("res://world_snapshot.gd")
const Encounter = preload("res://encounter_config.gd")
const Network = preload("res://network_settings.gd")
var failed := false


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		printerr("FAIL snapshot: ", message)


func run() -> void:
	var game := preload("res://world.tscn").instantiate()
	game.progress.path = "user://snapshot-codec/garden.cfg"
	game.local_character.path = "user://snapshot-codec/profile.cfg"
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)

	var people: Dictionary = {}
	var appearance := PackedByteArray([3, 2, 1, 2, 1, 1, 100, 0, 37, 83, 75, 41, 98, 0, 1, 0, 1])
	var p: Dictionary = game.player_snapshot(1, false)[1]
	for i in Network.MAX_PLAYERS:
		people[i + 1] = p.duplicate(true)
		var actor: Dictionary = people[i + 1]
		actor.pos = Vector3(i+.125, 0, i-.25)
		actor.velocity = Vector3(-2.5, 0, 3.125)
		actor.appearance = appearance
		actor.motion_ack = {"ack":65537, "partial":.03125, "partial_sequence":65538}
		actor.pose = 12350
		actor.party_slot = i
		actor.wild = i > 0
		if i>0: actor.erase("garden_layout_revision")
		actor.wallet = i * 7
		actor.fallen = i == 3
		actor.hp = 87.5
		actor.lost_health = 15
		actor.vitals_revision = 10
		actor.damage_seq = 7
		actor.damage_amount = 11
	actor_attack(people[2], false)
	actor_attack(people[3], true)
	people[1].garden_layout_revision = -1
	for profile in preload("res://weapon_motion.gd").PROFILES.values():
		check(Codec.CLIPS.has(profile.clip) and Codec.DELIVERIES.has(profile.delivery), "weapon presentation IDs are in the wire dictionary")
		for clip in profile.get("variants", {}).values():
			check(Codec.CLIPS.has(clip), "weapon variant clip is in the wire dictionary")
	for clip in preload("res://subclass_combat.gd").CLIPS.values():
		check(Codec.CLIPS.has(clip), "class presentation IDs are in the wire dictionary")

	var campaign: PackedInt32Array = game.campaign_snapshot()
	campaign[8] = 2147483647
	campaign[9] = 74
	var scouts := PackedFloat32Array()
	for i in Encounter.MAX_SCOUTS:
		scouts.append_array(PackedFloat32Array([i+.125,-i-.25,99-i,i%2,i%4,(i+1)%2,i+.5,-i-.5]))
	var leader := Vector3(2.5, 0, -3.125)
	var drop := Vector3(-8.5, 0, 4.25)
	var frame := Codec.encode(10, people, campaign, scouts, leader, 487, 500, drop, 74, 25)
	var viewer := Codec.for_viewer(frame, 317, true, true)
	check(frame.size() == Codec.MAX_FRAME and frame.size() <= Codec.PAYLOAD_BUDGET, "full four-player and twenty-scout frame fits the budget")
	var decoded := Codec.decode(viewer)
	if not decoded.is_empty():
		check(decoded.enemy == leader and decoded.drop == drop and decoded.hp == 487 and decoded.depth == 74
			and decoded.scouts == scouts and decoded.campaign == campaign, "world and all twenty scout states round-trip")
		check(decoded.carried == 317 and decoded.flags == 31 and Codec.decode(frame).flags == 25, "private drop, pouch and inventory stay recipient-specific")
		var actor: Dictionary = decoded.people[4]
		check(actor.pos == people[4].pos and actor.velocity == people[4].velocity and actor.motion_ack == people[4].motion_ack
			and actor.motion_epoch == str([campaign[0],74,2147483647,true,true]), "motion inputs and reconstructed epoch match")
		check(actor.appearance == appearance and actor.pose == 12350 and actor.hp == 87.5 and actor.damage_seq == 7
			and actor.damage_amount == 11 and actor.enemy_max_hp == 500, "all appearance controls, vitals and maximum round-trip")
		check(actor.wallet == 21 and decoded.people[2].wallet == 7, "per-player wallets use the existing fast-frame field")
		check(decoded.people[2].attack_anim == people[2].attack_anim and decoded.people[3].attack_anim == people[3].attack_anim,
			"weapon and class pose fields including null direction round-trip")
		check(decoded.people[1].garden_layout_revision == -1 and not actor.has("garden_layout_revision"), "Garden reveal sentinel is distinct from an absent layout")
	else:
		check(false, "valid full frame decodes")

	game.receive_state(viewer)
	check(game.guest_replication.sequence() == 10 and game.guest_replication.enemy_hp() == 487 and game.encounter.hp() != 487, "production receive commits a valid snapshot")
	var events: int = game.combat_event_serial
	# Application-level loss/reorder injection through the production receiver.
	# Sequence 11 is missed, then arrives late. An invalid 13 must not poison the sequence.
	game.receive_vitals({1:{"revision":11,"hp":61,"max_hp":100,"damage_seq":8,"damage_amount":12}})
	var newest_people := people.duplicate(true)
	newest_people[1].wild = true
	newest_people[1].wallet = 11
	var newest := Codec.for_viewer(Codec.encode(12, newest_people, campaign, scouts, leader, 455, 500, drop, 74, 25), 317, true, true)
	game.receive_state(newest)
	var late := viewer.duplicate()
	late.encode_u64(0, 11)
	game.receive_state(late)
	game.receive_state(newest)
	var invalid := newest.duplicate()
	invalid.encode_u64(0, 13)
	game.receive_state(invalid.slice(0, -1))
	check(game.guest_replication.sequence() == 12 and game.guest_replication.gap_count() == 1 and game.guest_replication.rejected_count() == 2,
		"skipped, reordered, duplicate and truncated frames are distinguished")
	check(game.guest_replication.enemy_hp() == 455 and game.players[1].hp == 61 and game.players[1].damage_seq == 8
		and game.players[1].wallet == 11, "latest wallet and newer reliable vitals survive reordered frames")
	game.receive_state(invalid)
	check(game.guest_replication.sequence() == 13 and game.combat_event_serial == events, "valid successor applies without replaying combat events")
	newest_people[1].wild = false
	newest_people[1].wallet = 0
	var recovered := Codec.for_viewer(Codec.encode(16, newest_people, campaign, scouts, leader, 314, 500, drop, 74, 25), 317, true, true)
	# The reliable receiver now requires an accepted connection binding. Keep
	# codec actors above as detached wire data, then set up this receiving guest.
	SessionCase.set_role(game,"Guest")
	var connection: String = game.network_session.accepted_connection_key()
	var owner_details := {"snapshot_recovery":recovered, "snapshot_roster":{1:"Recovered name"},"session_binding":connection}
	var details := var_to_bytes(owner_details).compress(FileAccess.COMPRESSION_DEFLATE)
	var garden_state: Array = game.garden_snapshot()
	if game.stage.experimental_garden != null: garden_state.append(game.stage.experimental_garden.snapshot())
	var garden := var_to_bytes(garden_state).compress(FileAccess.COMPRESSION_DEFLATE)
	var old_details := owner_details.duplicate(true)
	old_details.session_binding = "obsolete-connection-binding"
	game.receive_details(var_to_bytes(old_details).compress(FileAccess.COMPRESSION_DEFLATE),garden,[],"obsolete")
	check(game.guest_replication.sequence() == 13 and not game.guest_replication.has_details() and game.guest_replication.details_key().is_empty(),
		"old connection details cannot replace the owner view or apply recovery")
	game.receive_details(details, garden, [], "fixture")
	check(game.guest_replication.sequence() == 16 and game.guest_replication.enemy_hp() == 314 and game.players[1].hp == 61
		and game.players[1].display_name == "Recovered name" and game.players[1].wallet == 0,
		"reliable details recover the latest wallet after fast-channel silence")
	game.receive_state(recovered)
	game.receive_details(details, garden, [], "fixture")
	game.apply_world_snapshot(newest, true)
	check(game.guest_replication.sequence() == 16 and game.combat_event_serial == events
		and not ExpeditionCase.is_wild(game.players[1]) and game.players[1].wallet == 0,
		"duplicate and stale frames cannot replay effects or restore a departed wallet")
	invalid[49] = Network.MAX_PLAYERS + 1
	check(Codec.decode(invalid).is_empty(), "impossible player count refused")
	var over := scouts.duplicate()
	over.append_array(PackedFloat32Array([0,0,0,0,0,0,0,0]))
	check(Codec.encode(1, people, campaign, over, leader, 1, 1, drop, 1, 0).is_empty(), "oversized occupancy is never silently truncated")
	game.session_world.offline()
	game.queue_free()
	await process_frame
	if not failed:
		print("PASS: bounded full world snapshot, receiver convergence, sequence and reliable-vitals isolation")
	quit(int(failed))


func actor_attack(player: Dictionary, cast: bool) -> void:
	player.attack_anim = {"active":true, "phase":.25, "combo":321, "duration":550,
		"clip":"Attack_whip" if cast else "Attack_blade_line", "form":"cast" if cast else "weapon",
		"direction":null if cast else Vector3(-.5, 0, .25)}
	if not cast:
		player.attack_anim.merge({"aim_live":true, "delivery":"projectile", "reach":8.25, "span":1.5})
