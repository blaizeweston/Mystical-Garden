extends SceneTree
## Direct ownership contracts. Integrated travel and guarded fixtures cover orchestration.

const Participation = preload("res://expedition_participation.gd")
var failed := false

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		printerr("FAIL expedition participation: ", message)

func run() -> void:
	var owner := Participation.new()
	var first := {Participation.STATE: owner.attach(1)}
	var ally := {Participation.STATE: owner.attach(8)}
	check(not owner.active() and not Participation.is_wild(first), "attached player starts in Garden")
	check(owner.reset_run(), "inactive expedition can initialize")
	var run_id := owner.run_id()
	check(owner.enter(8) and owner.enter(1) and not owner.enter(1), "one admission per peer")
	check(owner.participants() == [1,8] and owner.participants().is_read_only(), "sorted detached participant projection")
	check(not owner.reset_run(), "active expedition cannot reset")
	check(Participation.peer_for(first) == 1 and Participation.is_wild(first), "actor link queries authoritative membership")
	check(Participation.is_wild({"wild": true}) and not Participation.is_wild({}), "wire and frozen projections retain their explicit membership")
	var world := owner.world()
	check(world.is_read_only() and int(world.run_id) == run_id, "world projection is detached and read-only")
	check(owner.select_route(1) and not owner.select_route(3) and not owner.select_route(-1), "only playable biomes can be selected")
	owner.project_world({"destination":3,"encounter_number":99})
	check(owner.route() == 1 and owner.floor() == 1, "retired route cannot replace a live world projection")
	check(int(world.destination) == 0 and owner.route() == 1, "published world does not alias current state")
	owner.begin_floor(938)
	var epoch := owner.epoch()
	check(not owner.advance(epoch-1,6), "stale floor cannot advance")
	check(owner.advance(epoch,6) and owner.floor() == 2 and owner.depth() == 2, "current floor advances once")
	check(not owner.advance(epoch,6), "repeated floor commit cannot advance twice")
	owner.begin_floor(939)
	check(owner.run_id() == run_id and owner.participants() == [1,8], "floor change preserves run and participants")
	check(owner.leave(1) and not owner.contains(1) and owner.contains(8), "partial return removes only the departing member")
	check(not owner.enter(1) and Participation.is_waiting(first), "departed player cannot rejoin an unfinished run")
	owner.begin_travel("advance", [8])
	var consent := owner.travel_epoch()
	check(not owner.set_vote(1,"wrong") and owner.set_vote(8,"current"), "vote only accepts current travel members")
	check(owner.vote_count() == 1 and owner.has_vote(8) and owner.vote_signature(8) == "current", "vote reads have explicit operations")
	var voters := owner.travel_members()
	check(voters.is_read_only() and voters == [8], "travel membership is read-only")
	check(not owner.withdraw(8,consent-1) and owner.has_vote(8), "stale unready request cannot remove current consent")
	check(owner.withdraw(8,consent) and owner.vote_count() == 0, "current unready request removes one vote")
	owner.clear_travel()
	check(owner.travel_epoch() > consent and owner.travel_kind().is_empty() and voters == [8], "clear retires consent identity without mutating old projections")
	# Confirmed rollback restores the real owner, not a duplicate Game cache.
	var saved := owner.savepoint()
	saved.world.destination = 2
	check(owner.route() == 1, "savepoint is detached")
	saved.world.destination = 1
	var discarded := {Participation.STATE: owner.attach(99)}
	owner.enter(99)
	owner.begin_floor(940)
	var discarded_floor := owner.epoch()
	owner.begin_travel("extract", [8,99])
	var discarded_vote := owner.travel_epoch()
	owner.restore_savepoint(saved)
	check(not owner.attached(99) and Participation.peer_for(discarded) == 0 and not Participation.is_wild(discarded), "rollback invalidates discarded bindings")
	check(owner.seed() == 939 and owner.floor() == 2 and owner.contains(8) and Participation.is_waiting(first), "rollback restores world, membership and return hold together")
	owner.begin_floor(941)
	check(owner.epoch() > discarded_floor, "rollback never reuses an aborted floor identity")
	owner.begin_travel("advance", [8])
	check(owner.travel_epoch() > discarded_vote, "rollback never reuses discarded consent identity")
	var previous_link = ally[Participation.STATE]
	owner.detach(8)
	var replacement := {Participation.STATE: owner.attach(8)}
	check(previous_link.peer_id() == 0 and not previous_link.active() and Participation.peer_for(replacement) == 8,
		"reused peer cannot inherit previous actor membership")
	check(owner.reset_run() and owner.run_id() > run_id and owner.floor() == 1 and owner.depth() == 1,
		"completed expedition starts a distinct run")
	check(owner.enter(1) and owner.enter(8), "completed return releases per-run admission hold")
	owner.detach_all()
	check(not owner.active() and owner.participants().is_empty() and not Participation.is_wild(first), "session teardown invalidates all links")
	var guest := Participation.new()
	guest.project_world({"destination":2,"depth":4,"encounter_number":16,"difficulty_cycle":1,"map_seed":456})
	var links := guest.project_participants({1:true,8:false})
	var projected := {Participation.STATE: links[1]}
	check(links.is_read_only() and guest.active() and guest.participants() == [1] and guest.contains(1),
		"accepted guest facts reconstruct one participation authority")
	check(guest.route() == 2 and guest.floor() == 16 and Participation.is_wild(projected), "guest world and actor views agree")
	guest.project_participants({1:false,8:false})
	check(not guest.active() and not Participation.is_wild(projected), "later guest state clears membership through the same link")
	guest.project_participants({8:false})
	check(Participation.peer_for(projected) == 0, "departed snapshot peer invalidates its old link")
	guest.project_participants({1:true})
	check(not Participation.is_wild(projected), "reappearing guest peer cannot revive an obsolete projection")
	if not failed:
		print("PASS: expedition participation ownership, readonly projections, identity, travel consent, rollback and teardown")
	quit(1 if failed else 0)
