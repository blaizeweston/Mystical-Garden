extends SceneTree
## Narrow identity values. Actual request acceptance is covered by aim/Core peers.
const Identity = preload("res://network_action_identity.gd")
const Session = preload("res://network_session.gd")
const Participation = preload("res://expedition_participation.gd")
const Life = preload("res://player_lifecycle.gd")
var failed := false

class IdentityFixture extends Node:
	var network_session := Session.new()
	var participation := Participation.new()

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		printerr("FAIL network action identity: ",message)

func run() -> void:
	var world := {"run_id":3,"combat_epoch":17,"destination":0,"depth":2,
		"encounter_number":8,"difficulty_cycle":1,"map_seed":752}
	var stamp := Identity.build("connection-one","character-one",12,world,true)
	check(stamp.begins_with("a1/") and stamp == Identity.build("connection-one","character-one",12,world,true),
		"same explicit session, character, life and world produce the same versioned stamp")
	check(stamp != Identity.build("connection-two","character-one",12,world,true),"reused peer connection has a different identity")
	check(stamp != Identity.build("connection-one","character-two",12,world,true),"another character cannot inherit a request")
	check(stamp != Identity.build("connection-one","character-one",13,world,true),"a new player life rejects previous-life identity")
	for field: String in Identity.WORLD_FIELDS:
		var next := world.duplicate()
		next[field] = int(next[field])+1
		check(Identity.build("connection-one","character-one",12,next,true) != stamp,"world ownership includes "+field)
		next[field] = "invalid"
		check(Identity.build("connection-one","character-one",12,next,true).is_empty(),"noninteger world identity is refused: "+field)
		next.erase(field)
		check(Identity.build("connection-one","character-one",12,next,true).is_empty(),"missing world identity is refused: "+field)
	var with_health := world.duplicate()
	with_health.lost_health = 8
	with_health.hp = 1
	check(Identity.build("connection-one","character-one",12,with_health,true) == stamp,
		"health and revival penalties are not identity fields")
	check(Identity.build("","character-one",12,world,true).is_empty()
		and Identity.build("connection-one","",12,world,true).is_empty()
		and Identity.build("connection-one","character-one",0,world,true).is_empty()
		and Identity.build("connection-one","character-one",12,world,false).is_empty(),
		"unbound, invalid-life and nonparticipant actions receive no authorization stamp")
	var invalid := world.duplicate()
	invalid.run_id = 0
	check(Identity.build("connection-one","character-one",12,invalid,true).is_empty(),"run identity is required")
	invalid = world.duplicate()
	invalid.encounter_number = 0
	check(Identity.build("connection-one","character-one",12,invalid,true).is_empty(),"floor identity is required")
	var first := IdentityFixture.new()
	var second := IdentityFixture.new()
	root.add_child(first)
	root.add_child(second)
	var actor := {Session.STATE:first.network_session.admit_peer(1,100,"character-one",true),
		Participation.STATE:first.participation.attach(1),Life.STATE:Life.start_life()}
	check(first.participation.enter(1),"native actor enters through the participation owner")
	first.participation.begin_floor(951)
	var live := Identity.current_stamp(first,actor)
	check(not live.is_empty(),"current authoritative session/life/participation resolves a native request identity")
	var foreign := actor.duplicate()
	foreign[Session.STATE] = second.network_session.admit_peer(1,100,"character-one",true)
	check(Identity.current_stamp(first,foreign).is_empty(),"same peer from another owner cannot authorize this character")
	actor.lost_health = 8
	check(Identity.current_stamp(first,actor) == live,"changing revival penalty leaves actual native identity unchanged")
	actor[Life.STATE] = Life.start_life()
	check(Identity.current_stamp(first,actor) != live,"new life invalidates actual native requests even with unchanged injury")
	var renewed := Identity.current_stamp(first,actor)
	first.participation.begin_floor(951)
	check(Identity.current_stamp(first,actor) != renewed,"same terrain seed on a different floor epoch cannot replay an action")
	first.network_session.release_peer(1)
	var next = first.network_session.admit_peer(1,110,"character-two",true)
	check(Identity.current_stamp(first,actor).is_empty(),"reused peer invalidates the prior actor's request capability")
	actor[Session.STATE] = next
	check(not Identity.current_stamp(first,actor).is_empty() and Identity.current_stamp(first,actor) != live,
		"new character receives only its own fresh identity")
	first.free()
	second.free()
	if not failed: print("PASS: source-owned action identity, connection/character/life/world invalidation and independence from injury")
	quit(1 if failed else 0)
