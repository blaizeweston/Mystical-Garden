extends SceneTree

const PlayerVitals = preload("res://player_vitals.gd")
const Status=preload("res://combat_status.gd")
var failed:=false
func check(ok: bool,message: String):
 if not ok:failed=true;printerr("FAIL status feedback: ",message)
func _initialize():
 preload("res://combat_balance_preview.gd").enabled = false
 call_deferred("run")
func run():
 var game=load("res://world.tscn").instantiate();var token:=str(Time.get_ticks_usec())
 game.progress.path="res://.godot/status-"+token;game.local_character.path=game.progress.path+".character";root.add_child(game)
 game.set_process(false);game.set_physics_process(false);game.combat_visuals.set_process(false)
 var p: Dictionary=game.players[1];p.wild=true;p[PlayerVitals.STATE] = p[PlayerVitals.STATE].with_hp(10);p.pos=Vector3(0,0,-1);p.power=0
 game.battlefield.configure(0,1);game.battlefield.barriers.clear();game.encounter.set_hp(-1, 80);game.tactics.position=Vector3(0,0,1);game.enemy_traits.clear();game.encounter.clear_scouts();game.tactics.winding_up=false
 var now:=Time.get_ticks_msec();p.slow_until=now+4000
 var stats: Dictionary=game.weapon_stats(p);stats.damage=1;stats.mark_damage=2
 game.apply_weapon_hit(p,-1,p.pos,stats,now);Status.sync(game,now)
 check(game.enemy_traits.marked_until>now,"first contact applies a mark")
 var events:=Status.snapshot(game,now);var marks: Array=events.filter(func(e):return e.shape=="marked")
 check(marks.size()==1 and events.any(func(e):return e.form=="player" and e.shape=="slow"),"marked icon and slowed player callout")
 var mark_id: int=marks[0].id;var count: int=game.combat_event_serial;Status.sync(game,now+1)
 check(game.combat_event_serial==count,"no per-frame event spam")
 game._process(.016);var fx=game.combat_visuals;fx.sync(game.combat_events_snapshot(),[],"status-test",p.pos);fx.statuses.step(.016)
 check(fx.statuses.active.has(mark_id),"renderer creates a persistent mark icon")
 var icon: Dictionary=fx.statuses.active[mark_id];game.stage.foe.position.x+=.5;fx.statuses.step(.016)
 check(absf(icon.node.position.x-game.stage.foe.position.x)<.5,"icon follows rendered monster")
 var hp: int=game.enemy_health();game.apply_weapon_hit(p,-1,p.pos,stats,now+2);Status.sync(game,now+2)
 check(not game.combat_events_snapshot().any(func(e):return e.kind=="status" and e.id==mark_id),"late-join snapshot excludes a consumed mark")
 check(game.enemy_traits.marked_until==0 and hp-game.enemy_health()==3,"eligible contact consumes the mark and grants its damage once")
 check(game.combat_events.any(func(e):return e.kind=="proc" and e.shape=="mark_break"),"consumption has its own effect")
 fx.sync(game.combat_events_snapshot(),[],"status-test",p.pos)
 check(not fx.statuses.active.has(mark_id),"consumed icon removed immediately")
 fx.statuses.consume(marks[0]);check(not fx.statuses.active.has(mark_id),"late old snapshot cannot resurrect consumed mark")
 game.apply_weapon_hit(p,-1,p.pos,stats,now+3);Status.sync(game,now+3);check(Status.snapshot(game,now+3).any(func(e):return e.shape=="marked"),"later contact may apply a fresh mark")
 game.combat_events.clear();check(Status.snapshot(game,now+4).size()>=2 and game.combat_events_snapshot().any(func(e):return e.kind=="status"),"active statuses survive transient event eviction for late joiners")
 p.slow_until=0;game.enemy_traits.marked_until=0;Status.sync(game,now+5);check(not Status.snapshot(game,now+5).any(func(e):return e.shape in ["marked","slow"]),"cleansing and consumption remove live state")
 game.enemy_traits.marked_until=now+4000
 var omen: Dictionary=stats.duplicate();omen.mark_damage=0;omen.omen=1
 game.Traits.augment_hit(game,p,-1,omen,now+6)
 check(game.enemy_traits.marked_until>0,"omen preserves a mark when the enemy is not winding up")
 game.tactics.winding_up=true;game.Traits.augment_hit(game,p,-1,omen,now+7);game.tactics.winding_up=false
 check(game.enemy_traits.marked_until==0,"omen consumes its mark when its wind-up bonus really triggers")
 p.slow_until=now+20;Status.sync(game,now+10);Status.sync(game,now+21)
 check(not Status.snapshot(game,now+21).any(func(e):return e.shape=="slow"),"timed expiry clears status independently of text")
 stats.mark_damage=0;stats.brittle=1
 for i in 3:game.apply_weapon_hit(p,-1,p.pos,stats,now+10+i)
 check(game.enemy_traits.brittle==0 and game.combat_events.any(func(e):return e.kind=="proc" and e.shape=="shatter"),"brittle stacks shatter visibly")
 game.encounter.clear_scouts();game.encounter.register_scout(game.make_scout(0,Vector3(1,0,1),0));game.encounter.set_hp(0, 80);game.encounter.scout(0).pos=Vector3(1,0,1);game.encounter.scout(0).engaged=false;game.trait_events.clear()
 var secondary: Dictionary={"damage":2,"reach":4.0}
 for kind in ["echo","link","chorus"]:
  game.Traits.queue_hit(game,p,0,secondary,now,20,false,game.tactics.position,kind)
  hp=game.encounter.hp(0);game.Traits.tick(game,now+25)
  check(game.encounter.hp(0)<hp and game.combat_events.any(func(e):return e.kind=="proc" and e.shape==kind),"confirmed "+kind+" hit has a matching effect")
 game.combat_events.clear();game.Traits.queue_hit(game,p,0,secondary,now,20,false,game.tactics.position,"echo")
 var replacement: Dictionary=game.make_scout(0,game.encounter.scout(0).pos,0)
 game.encounter.register_scout(replacement, 0);game.Traits.tick(game,now+25)
 check(not game.combat_events.any(func(e):return e.kind=="proc"),"stale delayed attack cannot show a false proc on a new enemy")
 game.encounter.scout(0).traits={"marked_until":now+5000};Status.sync(game,now+30);game.encounter.set_hp(0, 0);Status.sync(game,now+31)
 check(not Status.snapshot(game,now+31).any(func(e):return e.form=="enemy" and e.combo==0),"dead enemy loses status")
 fx.clear();check(fx.statuses.active.is_empty(),"floor cleanup clears status nodes")
 var pending: Dictionary={"kind":"status","shape":"slow","form":"player","id":32000,"combo":99000,"duration":.5,"age":0.0,"height":2.35,"color":"95d7ed"}
 fx.statuses.consume(pending);fx.statuses.step(.1)
 check(fx.statuses.active.has(pending.id) and not fx.statuses.active[pending.id].node.visible,"short status waits for an out-of-order actor snapshot")
 var remote:=Node3D.new();game.stage.add_child(remote);remote.position=game.stage.WILD_OFFSET+p.pos;game.stage.avatars[pending.combo]=remote
 fx.statuses.step(.1)
 check(fx.statuses.active.has(pending.id) and fx.statuses.active[pending.id].node.visible and fx.statuses.active[pending.id].label.text=="Slowed","pending callout attaches when the avatar arrives")
 fx.statuses.step(.4)
 check(not fx.statuses.active.has(pending.id),"waiting for the avatar does not prolong the status")
 game.stage.avatars.erase(pending.combo);remote.queue_free()
 game.queue_free();await process_frame
 if not failed:print("PASS: status transitions, consumed marks, brittle, true delayed procs, stale targets, renderer following, eviction, expiry and cleanup")
 quit(1 if failed else 0)
