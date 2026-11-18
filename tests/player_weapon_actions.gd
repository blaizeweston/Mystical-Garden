extends SceneTree
const Actions = preload("res://player_weapon_actions.gd")
const Motion = preload("res://weapon_motion.gd")
var failed := false

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		printerr("FAIL player weapon actions: ",message)

func run() -> void:
	var empty := Actions.State.new()
	check(empty.ready(0) and empty.sequence()==0 and empty.pose_until_ms()==0,"new player has a ready, inactive weapon action")
	var first := empty.try_start(1000,600,800,3.25)
	check(first!=null and first.ready_at_ms()==1600 and first.duration_ms()==540 and first.pose_until_ms()==1540,
		"ordinary attack uses the resolved interval and existing animation cap")
	check(empty.ready_at_ms()==0 and empty.sequence()==0 and first.sequence()==1,"starting creates a successor without changing the rollback value")
	check(first.try_start(1599,600,800,3.25)==null and first.ready(1600),"one admission at the exact deadline")
	var bow := first.with_pose(Vector3.RIGHT,"Attack_bow","projectile",1.9).follow_cursor_until(1300)
	var live := bow.animation(1299,Vector3.FORWARD,true,Vector3.BACK,"fallback")
	check(live.active and live.aim_live and live.direction==Vector3.BACK and live.clip=="Attack_bow" and live.reach==3.25,
		"current ranged windup projects current aim without changing committed state")
	check(not bow.aim_is_live(1300,true) and not bow.aim_is_live(1200,false),"release boundary and input release end live aiming")
	var released := bow.sample_release(1,Vector3.BACK)
	check(released.animation(1300,Vector3.FORWARD,true,Vector3.LEFT,"").direction==Vector3.BACK
		and bow.animation(1300,Vector3.FORWARD,true,Vector3.LEFT,"").direction==Vector3.RIGHT,"release freezes one direction and preserves the old value")
	var second := released.try_start(1600,120,90,2.0).with_pose(Vector3.LEFT,"Attack_blade","sweep",2.2)
	check(second.duration_ms()==Motion.MIN_BASIC_POSE_MS and second.sequence()==2,"fast weapons retain the existing minimum pose duration")
	check(is_same(second.sample_release(1,Vector3.BACK),second) and not second.aim_is_live(1601,true),"an older queued action cannot overwrite the newest pose or claim its windup")
	live.combo=999
	live.direction=Vector3.ZERO
	check(bow.sequence()==1 and bow.animation(1200,Vector3.FORWARD,false,Vector3.ZERO,"").direction==Vector3.RIGHT,"presentation results cannot mutate action state")
	var core := second.core_pose(1700,700,5.0,Vector3.FORWARD,"Attack_staff","line",2.4,true)
	check(core.ready_at_ms()==2400 and core.sequence()==3 and core.pose_until_ms()==2400
		and core.animation(1800,Vector3.RIGHT,true,Vector3.LEFT,"").direction==Vector3.FORWARD,"Core shares only its existing exclusion deadline and pose")
	var blade_core := core.core_pose(1800,200,2.0,Vector3.LEFT,"cast","sweep",1.9,false)
	check(blade_core.ready_at_ms()==2400 and blade_core.pose_until_ms()==0,"blade cast hides the weapon pose and never shortens existing recovery")
	var pulse := core.swing_until(2200)
	check(pulse.swing_ticks(2000)==20 and is_equal_approx(pulse.swing_fraction(2080),0.5),"compact swing projection keeps its existing units")
	var cleared := pulse.clear_active()
	check(cleared.pose_until_ms()==0 and cleared.swing_ticks(2000)==0 and cleared.ready_at_ms()==pulse.ready_at_ms()
		and cleared.sequence()==pulse.sequence(),"fall/return clears presentation while retaining recovery and action sequence")
	check(cleared.with_ready_at(0).ready(0) and not cleared.ready(2000),"explicit basic-attack readiness does not mutate the original value")
	if not failed: print("PASS: typed weapon action admission, immutable rollback, aim identity, Core pose and detached projections")
	quit(1 if failed else 0)
