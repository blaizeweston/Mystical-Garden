extends SceneTree

const Roster = preload("res://encounter_roster.gd")

var failed := false


func check(ok: bool, description: String) -> void:
	if not ok:
		failed = true
		printerr("FAIL encounter roster: ", description)


func spawn_plan(roster, hp: int) -> Dictionary:
	return {"spawn_token": roster.reserve_token(), "hp": hp, "pos": Vector3(2, 0, 3),
		"windup": 0, "rooted_until": 0, "ranged": true, "blast": Vector3.ZERO,
		"traits": {"slow": 100}}


func _initialize() -> void:
	var roster := Roster.new(20)
	var plan := spawn_plan(roster, 10)
	check(roster.register_scout(plan) == 0 and roster.scout_count() == 1,
		"spawn enters the active roster in its packet seat")
	var first := roster.token(0)
	check(not plan.has("hp") and not plan.has("spawn_token"), "tactics cannot write authoritative HP or identity")
	var view := roster.scout_view(0)
	view.hp = 200
	view.traits.slow = 500
	check(roster.hp(0) == 10 and roster.scout(0).traits.slow == 100,
		"detached views cannot change health or nested tactics")
	var savepoint := roster.savepoint()

	check(roster.apply_damage(0, 100, first) == 10 and roster.death_pending(0) and not roster.cleared(),
		"resolved damage clamps to remaining HP and a living leader holds the gate")
	check(roster.confirm_death(0) and not roster.confirm_death(0), "a death is published once")
	var replacement := spawn_plan(roster, 12)
	roster.register_scout(replacement, 0)
	var second := roster.token(0)
	check(second != first and roster.apply_damage(0, 5, first) == 0 and roster.hp(0) == 12,
		"delayed damage cannot cross a reused scout seat")
	check(roster.scout_pack(0) == PackedFloat32Array([2, 3, 12, 0, 0, 1, 0, 0]),
		"the roster supplies detached scalar projections in existing packet order")
	check(roster.apply_damage(-1, 20) == 20 and not roster.cleared(),
		"a surviving scout holds clearance after the leader dies")
	roster.despawn(0)
	check(roster.cleared() and not roster.death_pending(0), "despawn clears membership without creating a kill")

	roster.restore_savepoint(savepoint)
	check(roster.token(0) == first and roster.hp(0) == 10 and not roster.cleared(),
		"rollback restores the original occupancy and hit points")
	var replay := roster.scout_view(0)
	roster.register_scout(replay, 0)
	var replay_identity := roster.token(0)
	check(replay_identity > second and roster.apply_damage(0, 5, first) == 0,
		"a copied view cannot replay a consumed spawn token")
	roster.begin_floor(30)
	check(roster.scout_count() == 0 and roster.hp(-1) == 30,
		"the next floor replaces active membership and leader health")
	roster.register_scout(spawn_plan(roster, 10))
	check(roster.token(0) > replay_identity and roster.apply_damage(0, 5, first) == 0,
		"floor travel and rollback never recycle a consumed identity")

	if not failed:
		print("PASS: encounter roster membership, detached projections, damage, death, stale token, clearance and rollback")
	quit(int(failed))
