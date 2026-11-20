extends SceneTree
const Effects=preload("res://combat_effect_timeline.gd")
class Execution extends RefCounted:
 var effects: RefCounted
 var hits:=0
 var expired:=0
 var pulses:=0
 var alive:=true
 var reenter:=false
 func _init(owner: RefCounted):effects=owner
 func prepare(_now: int):pass
 func source_current(_row: Dictionary) -> bool:return alive
 func end(_row: Dictionary):expired+=1
 func route(row: Dictionary,_now: int):row.routed=true
 func hit(row: Dictionary,_now: int):
  hits+=1
  if reenter:
   reenter=false;effects.schedule_native(row)
 func pulse(row: Dictionary,now: int):pulses+=1;row.next=now+1000
var failed:=false
func check(ok: bool, message: String):
 if not ok:failed=true;printerr("FAIL combat effects: ",message)
func _initialize():
 var effects:=Effects.new();var runtime:=Execution.new(effects)
 var facts: Dictionary={"kind":"hit","owner":1,"epoch":3,"life":2,"binding":4,"due":100,"stats":{"damage":10}}
 var admitted:=effects.schedule_native(facts)
 facts.stats.damage=999;admitted.stats.damage=20
 check(effects.native_records()[0].stats.damage==10,"admission and inspection do not lend writable records")
 check(effects.update_native(admitted) and effects.native_records()[0].stats.damage==20,"explicit update modifies its accepted record")
 var foreign:=admitted.duplicate(true);foreign.life+=1
 check(not effects.update_native(foreign),"another life cannot amend an accepted record")
 var saved:=effects.savepoint()
 effects.advance_native(runtime,99);check(runtime.hits==0,"delayed hit remains pending before its deadline")
 runtime.reenter=true;effects.advance_native(runtime,100)
 check(runtime.hits==1 and effects.native_count()==1,"a generated callback cannot recursively execute a newly scheduled record")
 effects.advance_native(runtime,100);check(runtime.hits==2 and effects.native_count()==0,"next-frame completion retires each hit exactly once")
 effects.restore_savepoint(saved);check(effects.native_count()==1 and effects.native_records()[0].stats.damage==20,"rollback restores the pending timeline")
 effects.clear_native()
 for index in Effects.NATIVE_LIMIT:effects.schedule_native(facts)
 check(effects.native_count()==24 and effects.schedule_native(facts).is_empty(),"shared native capacity is bounded without truncating active effects")
 runtime.alive=false;effects.advance_native(runtime,100)
 check(effects.native_count()==0 and runtime.expired==24,"invalid sources retire without resolving damage")
 runtime.alive=true
 var zone:=effects.schedule_native({"kind":"growth","owner":1,"epoch":3,"life":2,"binding":4,"next":200,"until":1200,"ranger_route":{}})
 effects.advance_native(runtime,200)
 check(runtime.pulses==1 and effects.native_records()[0].next==1200 and effects.native_records()[0].routed,"route and pulse bookkeeping commit to the same owned field")
 effects.advance_native(runtime,1200);check(effects.native_count()==0 and runtime.expired==25,"expiry precedes another pulse")
 var core: Dictionary={"id":"cast-a","epoch":3,"life":2,"armed":100,"skill":{"damage":10}}
 check(effects.begin_core(1,core) and not effects.begin_core(1,core),"one active Core cast per source")
 var before:=effects.core_records();var after:=before.duplicate(true);after[1].armed=500
 effects.commit_cores(before,after);check(effects.core(1).armed==500,"Core progression has an explicit commit")
 after[1].skill.damage=999;check(effects.core(1).skill.damage==10,"Core inspection stays detached")
 effects.clear_cores();core.id="cast-b";effects.begin_core(1,core)
 effects.commit_cores(before,{})
 check(effects.core(1).id=="cast-b","an older cast cannot cancel or replace a newer cast")
 if not failed:print("PASS: owned native/Core timelines, bounded scheduling, detached facts, exact completion, expiry, stale identity and rollback")
 quit(1 if failed else 0)
