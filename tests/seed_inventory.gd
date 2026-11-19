extends SceneTree
const UIFixture = preload("res://tests/support/gameplay_ui_case.gd")

const ExpeditionCase = preload("res://tests/support/expedition_case.gd")
var failed:=false
func check(ok: bool,message: String):
 if not ok: failed=true;printerr("FAIL seed inventory: ",message)
func _initialize(): call_deferred("run")
func run():
 var game=load("res://world.tscn").instantiate();game.progress.path="res://.godot/seed_inventory_"+Crypto.new().generate_random_bytes(8).hex_encode()+".cfg";game.local_character.path=game.progress.path+".character";root.add_child(game);game.set_process(false);game.set_physics_process(false)
 var p: Dictionary=game.players[1];var reserve: Dictionary=game.seed_reserve(p);var g=game.progress
 p.pos=game.stage.altar_position();reserve.stock.fill(0);reserve.unknown.assign([0,1,0,2])
 game.send_garden_action('altar:'+JSON.stringify({"operation":"identify_all","draft":[{},{}],"revision":1}))
 check(reserve.unknown.is_empty() and reserve.stock[0]==2 and reserve.stock[1]==1 and reserve.stock[2]==1,"identify all preserves duplicates and every species")
 check(UIFixture.control(game,"altar_view").identify_all_button.disabled,"empty batch disables identify all")
 var before: Array=reserve.stock.duplicate();reserve.unknown.assign([0,2]);var path: String=g.path;g.path="res://.godot/nonexistent-seed-directory/fail.cfg"
 game.Altar.identify_all(game,p);check(reserve.stock==before and reserve.unknown==[0,2],"failed batch save restores all seeds")
 g.path=path;reserve.unknown.clear()
 p.pos=game.Stage.PLOTS[0];game.send_action(false)
 check(UIFixture.control(game,"planting_menu").visible and g.plots[0].species==-1 and reserve.stock==before,"empty bed opens picker without consuming seed")
 check(UIFixture.control(game,"planting_view").grid.get_child_count()==3,"inventory has one square per available seed species")
 UIFixture.control(game,"planting_view").grid.get_child(1).pressed.emit();check(UIFixture.control(game,"planting_view").selected==1 and not UIFixture.control(game,"planting_view").confirm.disabled,"seed selection enables planting")
 UIFixture.control(game,"planting_view").confirm.pressed.emit();check(g.plots[0].species==1 and reserve.stock[1]==0 and not UIFixture.control(game,"planting_menu").visible,"confirmation plants chosen seed and consumes exactly one")
 game.send_garden_action("plant_at_0_0");check(reserve.stock[0]==2,"occupied bed rejects replay")
 p.pos=game.Stage.HEART;game.send_garden_action("plant_at_1_0");check(g.plots[1].species==-1,"remote bed planting rejected")
 p.pos=game.Stage.PLOTS[1];game.send_action(false);game.ui.close_panels();check(g.plots[1].species==-1,"cancel leaves bed empty")
 g.path="res://.godot/nonexistent-seed-directory/fail.cfg";game.send_garden_action("plant_at_1_0");check(g.plots[1].species==-1 and reserve.stock[0]==2,"failed planting save returns seed")
 g.path=path
 p.character.traits[p.frame]=2;ExpeditionCase.set_membership(game, p, true);p.contributed=true;var familiarity: int=p.character.monsters[game.enemy_kind];game._queue_monster_reward("retired-affinity-test",game.enemy_kind,0,p.pos,false);game.award_combat_progress();check(p.character.monsters[game.enemy_kind]==familiarity+1,"stale scholar affinity cannot double familiarity")
 check(game.Character.normalize(p.character).traits.all(func(value): return value==0),"legacy affinity selections are neutralized")
 if not failed: print("PASS: identify all, duplicates, rollback, seed grid, selection, planting confirmation, cancellation, stale requests, save failure and retired affinity migration")
 game.queue_free();await process_frame;quit(1 if failed else 0)

