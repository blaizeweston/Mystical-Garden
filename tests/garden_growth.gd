extends SceneTree

const SessionCase = preload("res://tests/support/session_case.gd")

const ExpeditionCase = preload("res://tests/support/expedition_case.gd")
const State=preload("res://garden_growth_state.gd")
const Service=preload("res://garden_growth_service.gd")
const Transactions=preload("res://game_transaction.gd")
var failed:=false
func check(ok: bool,message: String) -> void:
 if not ok:failed=true;printerr("FAIL Garden growth: ",message)
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var game=load("res://world.tscn").instantiate();var base: String="res://.godot/growth-"+Crypto.new().generate_random_bytes(8).hex_encode()
 game.progress.path=base+".cfg";game.local_character.path=base+".character";game.guest_character.path=base+".guest";root.add_child(game);game.set_process(false);game.set_physics_process(false)
 var g=game.progress;var view=game.get_node("GardenInteractions/GrowthScenes");view.set_process(false)
 check(g.garden_interactions.growth.events.is_empty(),"new and migrated worlds establish a baseline without replaying history")
 var initial: Dictionary=g.garden_interactions.duplicate(true)
 g.heart.complete(g,"cultivation_grounds")
 var prepared:=State.prepare(g)
 check(g.garden_interactions==initial and prepared.growth.events.size()==1 and prepared.growth.events[0].kind=="heart","preparing a new bed is pure and identifies the real destination")
 var path: String=g.path;g.path=base+"-missing/fail.cfg"
 check(g.save_garden()!=OK and g.garden_interactions==initial,"failed save cannot publish a growth event")
 g.path=path;check(g.save_garden()==OK,"growth commits")
 var count: int=g.garden_interactions.growth.events.size();g.save_garden()
 check(g.garden_interactions.growth.events.size()==count,"ordinary repeated saves cannot duplicate a reveal")
 var loaded=game.Progress.new();loaded.path=path
 check(loaded.load_garden()==OK and loaded.garden_interactions.growth==g.garden_interactions.growth,"queue and viewer receipts survive a reload")
 var first: Dictionary=Service.projection(game,1).pending[0]
 game.add_player(7878);SessionCase.set_ready(game, game.players[7878], true);SessionCase.set_identity(game, game.players[7878], "new-growth-viewer")
 check(Service.register(game,7878) and Service.projection(game,7878).pending.is_empty(),"a new character starts at the current Garden rather than replaying past scenes")
 check(Service.register(game,1) and Service.projection(game,1).pending.size()==1,"registering an existing viewer preserves their unwatched scene")
 ExpeditionCase.set_membership(game, game.players[1], true)
 check(not Service.projection(game,1).ready and not Service.acknowledge(game,1,str(first.sequence)),"expedition completion waits until return and cannot be dismissed from the Wilds")
 ExpeditionCase.set_membership(game, game.players[1], false);game.participation.begin_travel("enter", [1])
 check(not Service.projection(game,1).ready,"ready-check transition postpones a reveal")
 game.participation.clear_travel()
 check(not Service.acknowledge(game,1,"999") and not Service.acknowledge(game,1,"not-a-number"),"forged acknowledgements cannot skip unseen future scenes")
 game._process(.016)
 check(g.plots.size()==3 and game.stage.garden_beds.get_child_count()==3,"bed research grants permission without silently constructing a bed")
 # This renderer fixture supplies an already-earned saved bed. Real guarded
 # construction and its debit/placement rules remain in experimental_terrain.
 check(preload("res://tests/support/terrain_case.gd").place_structure(game,"bed"),"place inventory bed")
 game.stage.plot_key=""
 game._process(.016)
 if game.stage.garden_beds.get_child_count()<4:
  game.free();quit(1);return
 var bed: Node3D=game.stage.garden_beds.get_child(3)
 check(bed.global_position.is_equal_approx(game.stage.bed_position(3)),"the reveal uses the actually placed bed position")
 var parts: Array=g.parts.duplicate();var stock: Array=g.stock.duplicate();var knowledge: int=g.knowledge
 # Exercise a saved pre-HG02 bed reveal against the current, movable bed.
 var historical_bed := first.merged({"kind":"bed","slot":3},true)
 view.begin(historical_bed);view.animate(2.0);game.stage.focus(game.players[1].pos,false,1)
 var menu_key:=InputEventKey.new();menu_key.physical_keycode=KEY_ESCAPE;menu_key.pressed=true
 game._input(menu_key)
 check(view.is_active() and not game.ui.is_overlay_open(),"actual Game input obeys the cinematic owner while playback is active")
 var start: Vector3=game.stage.get_meta("garden_growth_camera").target;var start_camera: Vector3=game.stage.camera.position
 view.animate(4.8);game.stage.focus(game.players[1].pos,false,1)
 check(start.distance_to(game.stage.get_meta("garden_growth_camera").target)>2 and start_camera.distance_to(game.stage.camera.position)>2,"camera moves with the growing tip instead of waiting at the destination")
 check(game.stage.get_meta("garden_growth_camera").target.is_equal_approx(view.tip),"the travelling shot targets the visible root tip")
 check(bed.visible,"existing generated construction stays visible; research does not reconstruct or move it")
 view.animate(6.3)
 check(bed.visible and bed.scale.is_equal_approx(Vector3.ONE) and bed.global_position.is_equal_approx(game.stage.bed_position(3)),"a research cinematic preserves the placed structure and transform")
 view.finish(false)
 check(not game.ui.cinematic_active() and not game.stage.has_meta("garden_growth_camera") and bed.visible and bed.scale.is_equal_approx(Vector3.ONE) and not Service.projection(game,1).pending.is_empty(),"interruption releases input/camera, restores scenery and keeps the scene pending")
 view.begin(first);view.finish(true)
 var acknowledged:=Service.projection(game,1)
 check(acknowledged.seen==int(first.sequence) and not acknowledged.pending.any(func(e):return int(e.sequence)==int(first.sequence)) and not game.stage.has_meta("garden_growth_phase"),"skip acknowledges exactly the displayed receipt while preserving later phase events")
 check(g.parts==parts and g.stock==stock and g.knowledge==knowledge,"watching/skipping creates no material, seed or Knowledge reward")
 var before: Dictionary=g.garden_interactions.duplicate(true);var plots: Array=g.plots.duplicate(true);var profile_path: String=game.local_character.path
 game.local_character.path=base+"-missing/character"
 check(Transactions.run(game,func():g.heart.complete(g,"seed_archive");return true)!=true,"multi-file commit failure is surfaced")
 check(g.garden_interactions==before and g.plots==plots and not g.heart.has("seed_archive"),"failed transaction rolls queue and research back together")
 game.local_character.path=profile_path
 # Research produces the spring scene only once, even when several prerequisites commit together.
 g.heart.complete(g,"clearing_1");g.heart.complete(g,"flowering");g.heart.complete(g,"irrigation");g.save_garden()
 var springs: Array=g.garden_interactions.growth.events.filter(func(e):return e.kind=="spring")
 check(springs.size()==1,"the last spring prerequisite produces exactly one spring reveal")
 game._process(.016)
 view.begin(springs[0]);view.animate(6.0)
 check(not game.stage.station_position("spring").is_finite(),"spring research does not silently construct a watering basin")
 check(game.stage.get_meta("garden_growth_camera").target.is_finite(),"the authored spring reveal retains a finite camera destination")
 view.finish(false)
 check(not game.stage.station_position("spring").is_finite(),"finishing a reveal cannot grant a free station")
 var seen_before: int=Service.projection(game,1).seen
 view.force_playback=true;game.app_settings.values.garden_cinematics=false;view._process(0);view.force_playback=false
 check(Service.projection(game,1).seen>seen_before and not game.ui.cinematic_active() and not game.stage.has_meta("garden_growth_camera"),"disabling scenes records a local skip without forcing the camera")
 verify_permanent_structures(game,view)
 var reload_path: String=g.path;var expected_plots: int=g.plots.size()
 # Existing saves and future additive fields remain safe.
 var old: Dictionary=g.garden_interactions.duplicate(true);old.erase("growth");g.garden_interactions=State.initialize(old,State.snapshot(g))
 check(State.prepare(g).growth.events.is_empty(),"loading an established Garden does not replay historical unlocks")
 var bounded: Dictionary=g.garden_interactions.duplicate(true)
 for index in 80:bounded.growth.events.append({"sequence":index+1,"kind":"heart"})
 bounded.growth.sequence=80;g.garden_interactions=bounded
 check(State.prepare(g).growth.events.size()==64 and State.prepare(g).growth.events[0].sequence==17,"history is bounded while sequence numbers remain stable")
 var root_future: Dictionary={"version":7,"future":{"keep":true}}
 check(State.initialize(root_future,State.snapshot(g))==root_future,"unknown outer schema is preserved verbatim")
 g.garden_interactions.growth.version=99;var future: Dictionary=g.garden_interactions.duplicate(true)
 check(State.prepare(g)==future and Service.projection(game,1).is_empty(),"future presentation versions are retained without execution")
 game.queue_free();await process_frame
 verify_reloaded_structures(reload_path,expected_plots)
 if not failed:print("PASS: Garden growth persistence, transaction rollback, deferred reveals, root-tip camera, actual construction boundaries and skip safety")
 quit(1 if failed else 0)

func verify_permanent_structures(game: Node,view: Node) -> void:
 var g=game.progress
 while not Service.projection(game,1).pending.is_empty():
  Service.acknowledge(game,1,str(Service.projection(game,1).pending[0].sequence))
 for id in ["seed_archive","monster_studies"]:
  g.heart.complete(g,id);g.save_garden();game._process(.016)
  var pending: Array=Service.projection(game,1).pending
  check(pending.size()==1 and pending[0].kind=="station" and pending[0].station==id,"research queues one station reveal: "+id)
  if pending.is_empty():continue
  view.begin(pending[0]);view.animate(0);view.animate(view.DURATION);view.finish(true);game._process(.016)
  check(Service.projection(game,1).pending.is_empty(),"watching acknowledges this viewer once: "+id)
  check(not game.stage.station_position(id).is_finite(),"research grants placement permission: "+id)
 g.heart.complete(g,"seed_conservation");g.save_garden();game._process(.016)
 check(game.stage.heart_stations.living_archive.visible,"later research preserves the native Archive")
 ExpeditionCase.set_membership(game,game.players[1],true);game._process(.016)
 ExpeditionCase.set_membership(game,game.players[1],false);game._process(.016)
 check(game.stage.heart_stations.living_archive.visible,"Garden return preserves the native Archive")

func verify_reloaded_structures(path: String,expected_plots: int) -> void:
 var fresh=load("res://world.tscn").instantiate();fresh.progress.path=path;fresh.local_character.path=path+".reload-character";fresh.guest_character.path=path+".reload-guest"
 root.add_child(fresh);fresh.set_process(false);fresh.set_physics_process(false);fresh.get_node("GardenInteractions/GrowthScenes").set_process(false)
 check(fresh.progress.load_garden()==OK,"reload uses saved fixture research")
 fresh._process(.016)
 check(not fresh.progress.heart.has("living_archive") and fresh.stage.heart_stations.living_archive.visible,"saved research reconstructs the supported native Archive")
 check(fresh.stage.active_plots==expected_plots,"saved crops retain their owned bed slots")
 for index in expected_plots:check(fresh.stage.bed_position(index).is_finite(),"owned beds have a valid adopted position on load")
 check(not fresh.stage.station_position("spring").is_finite(),"loading research alone cannot build a watering basin")
 fresh.free()
