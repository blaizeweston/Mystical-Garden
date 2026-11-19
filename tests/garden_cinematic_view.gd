extends SceneTree
## Exercise the real renderer/Stage with no Game, player registry or save owner.
const View = preload("res://garden_growth_view.gd")
const Stage = preload("res://stage.gd")
const Shell = preload("res://ui/gameplay/gameplay_ui.tscn")
var failed := false
var requests: Array = []
var refreshes := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failed=true
		printerr("FAIL cinematic view: ",message)

func facts(pending: Array) -> Dictionary:
	return {"context":"viewer-A","pending":pending,"player_present":true,
		"player_position":Stage.SPAWN,"blocked":false,"safe":true,"skip_playback":false,"can_start":true}

func run() -> void:
	var stage := Stage.new()
	var camera := Camera3D.new()
	camera.name="Camera"
	stage.add_child(camera)
	root.add_child(stage)
	stage.heart_unlocked=["plot_4"]
	# Authored visual targets use the existing formation metadata contract.
	# Current generated construction placement is tested separately.
	var bed := Node3D.new()
	bed.position=Stage.PLOTS[0]
	bed.set_meta("garden_plot_position",Stage.PLOTS[0])
	stage.garden_beds.add_child(bed)
	var label := Label3D.new()
	label.visible=false
	stage.add_child(label)
	var ui = Shell.instantiate()
	root.add_child(ui)
	var hidden := CanvasLayer.new()
	hidden.visible=false
	root.add_child(hidden)
	var view := View.new()
	view.configure(stage,{})
	view.refresh_requested.connect(func():refreshes+=1)
	view.interfaces_requested.connect(func():view.capture_interfaces([ui,hidden]))
	view.requested.connect(func(command: String,data: Dictionary):requests.append({"command":command,"data":data.duplicate(true)}))
	root.add_child(view)
	view.set_process(false)
	view.force_playback=true
	ui.bind_cinematic(view)
	var event := {"sequence":7,"technology":"plot_4","kind":"bed","slot":0,"name":"A new bed",
		"from_growth":0,"to_growth":1,"from_phase":0,"to_phase":0}
	var incoming := facts([event.duplicate(true)])
	view.present(incoming)
	incoming.context="changed-after-presentation"
	incoming.pending[0].sequence=99
	view.begin(event)
	check(view.is_active() and ui.cinematic_active() and not ui.visible,"one renderer owns playback and the shell queries its active state")
	check(view.context()=="viewer-A" and refreshes==1,"display facts are detached and refresh is an explicit request")
	var inspected: Dictionary=view.event
	inspected.sequence=999
	check(view.event.sequence==7,"inspection cannot mutate the owned cinematic event")
	view.animate(2.0)
	var first: Vector3=stage.get_meta("garden_growth_camera").target
	view.animate(4.8)
	check(first.distance_to(stage.get_meta("garden_growth_camera").target)>1
		and stage.get_meta("garden_growth_camera").target.is_equal_approx(view.tip),"the camera tracks the actual root tip")
	check(not bed.visible,"an authored destination waits for the root to arrive")
	view.animate(6.3)
	check(bed.visible and bed.scale.x>0 and bed.scale.x<1,"the existing formation geometry is preserved")
	view.finish(false)
	check(not view.is_active() and not ui.cinematic_active() and ui.visible and not hidden.visible
		and not label.visible and bed.visible and bed.scale.is_equal_approx(Vector3.ONE),"interruption restores each original interface/model visibility without a duplicate active flag")
	check(requests.all(func(request):return request.command!="garden_action"),"interruption cannot acknowledge a host receipt")
	view.begin(event)
	view.finish(true)
	check(requests.back()=={"command":"garden_action","data":{"action":"growth_ack:7"}},"finishing requests only the displayed viewer acknowledgement")
	var count := requests.size()
	view.finish(true)
	check(requests.size()==count,"a completed scene cannot submit a second acknowledgement")
	var held := facts([event])
	held.blocked=true
	view.present(held)
	view._process(0)
	check(not view.is_active() and requests.size()==count,"a persistence hold cannot begin or acknowledge a scene")
	view.present(facts([event]))
	view.begin(event)
	var changed := facts([event])
	changed.context="another-viewer"
	view.present(changed)
	view._process(0)
	check(not view.is_active() and requests.size()==count+1,"a changed viewer cancels playback without acknowledging the former viewer")
	var next_event: Dictionary=event.duplicate(true)
	next_event.sequence=8
	var skipped := facts([next_event])
	skipped.skip_playback=true
	view.present(skipped)
	view._process(0)
	count=requests.size()
	check(requests.back().data.action=="growth_ack:8" and not view.is_active(),"disabled cinematics request a skip rather than a camera shot")
	view._process(.4)
	check(requests.size()==count,"a pending acknowledgement is not sent every frame")
	view._process(.7)
	check(requests.size()==count+1 and requests.back().data.action=="growth_ack:8","a delayed acknowledgement retains the existing one-second retry")
	view.present(facts([event]))
	view.begin(event)
	view.free()
	check(not ui.cinematic_active() and ui.visible and not stage.has_meta("garden_growth_camera"),"removing the renderer releases input, interface and camera ownership")
	ui.free()
	hidden.free()
	stage.free()
	await process_frame
	if not failed:print("PASS: standalone cinematic ownership, detached observations, root camera, formation, interface restoration, cancellation and bounded acknowledgement retry")
	quit(1 if failed else 0)
