extends SceneTree
var failed=false
func check(ok: bool,message: String):
 if not ok:failed=true;printerr("FAIL timed research: ",message)
func _initialize():call_deferred("run")
func run():
 var game=load("res://world.tscn").instantiate();game.progress.path="res://.godot/timed-research-"+str(Time.get_ticks_usec())+".cfg";game.local_character.path=game.progress.path+".character";root.add_child(game);game.set_process(false);game.set_physics_process(false)
 var g=game.progress;var h=g.heart;var p=game.players[1];p.pos=game.Stage.HEART;g.knowledge=4;g.parts.fill(0)
 var ui=game.progression_view;ui.tabs.current_tab=1;ui.chosen="heart_plot_4";ui.refresh()
 check(not ui.heart_start_button.disabled,"Knowledge can start a visible node with no plant parts")
 ui.heart_start_button.pressed.emit()
 check(h.active=="plot_4" and h.spent==2 and h.available_insight(g)==2 and g.plots.size()==3,"start spends Knowledge once and begins timed research")
 h.start(g,"plot_4");check(h.spent==2,"resuming funded research never pays twice")
 h.tick(g,30,false);check(g.plots.size()==3 and is_equal_approx(h.work.plot_4,30),"Garden research advances by elapsed time")
 h.tick(g,10,true);check(g.plots.size()==4,"Wilds research advances three times faster")
 g.knowledge=400;h.start(g,"flowering");h.tick(g,10,false);g.parts[0]=2
 h.infuse(g);check(g.parts[0]==0 and h.work.flowering==70,"plant offering removes one minute before infusion technology")
 var before=h.serialize();var path=g.path;g.path="res://.godot/missing-timed-research/fail.cfg"
 h.tick(g,10,true);check(h.serialize()==before,"failed timer save rolls back research")
 g.parts[0]=2;h.infuse(g);check(h.serialize()==before and g.parts[0]==2,"failed offering restores parts and research")
 g.path=path;g.save_garden()
 var reload=game.Progress.new();reload.path=path;reload.load_garden()
 check(reload.heart.work==h.work and reload.heart.spent==h.spent,"partial seconds and spent Knowledge survive reload")
 var file=ConfigFile.new();file.load(path);var old=h.serialize();old.version=1;old.erase("work");old.progress.flowering=1;file.set_value("heart","state",old);file.save(path+".old")
 var legacy=game.Progress.new();legacy.path=path+".old";legacy.load_garden()
 check(legacy.heart.work.flowering==120 and legacy.heart.has("plot_4") and legacy.heart.spent==h.spent,"legacy milestone research migrates without losing unlocks or charging again")
 var before_offer=h.work.flowering
 game.garden_action(1,'heart_infusion:'+JSON.stringify({"project":"flowering","plan":{"lantern_moss":2}}))
 check(g.parts[0]==2 and h.work.flowering==before_offer,"stale ingredient plan cannot substitute or consume materials")
 legacy.save_garden();check(FileAccess.file_exists(path+".old.pre-timed-research-v2.bak"),"migration creates a recovery copy before writing new timers")
 h.unlock_direct("infusion")
 game.garden_action(1,'heart_infusion:'+JSON.stringify({"project":"flowering","plan":{"thorn_bloom":2}}))
 check(h.work.flowering==190,"Infusion technology doubles offering effectiveness")
 game.queue_free();await process_frame
 if not failed:print("PASS: spendable Knowledge, timed research, Wilds acceleration, optional offerings, rollback, persistence and migration")
 quit(1 if failed else 0)
