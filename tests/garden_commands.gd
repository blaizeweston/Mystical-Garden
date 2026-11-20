extends SceneTree
## These decisions need no Game, profile, actor or active network session.
const Rules=preload("res://garden_interaction_service.gd")
const Conduit=preload("res://garden_conduit.gd")
const State=preload("res://garden_interaction_state.gd")
class ProgressFacts extends RefCounted:
 var garden_interactions: Dictionary={}
var failed:=false
func check(ok: bool, message: String) -> void:
 if not ok:failed=true;printerr("FAIL Garden commands: ",message)
func _initialize() -> void:
 var point: Dictionary=Rules.Catalog.point("heart_root_scar").duplicate(true)
 var state:=State.blank()
 var request: Dictionary={"point":point.id,"action":"observe","request":"one","revision":0}
 for invalid in ["[]","{",JSON.stringify({"point":point.id}),JSON.stringify({"point":point.id,"action":"observe","request":"x","revision":.5}),"x".repeat(401)]:
  check(Rules.parse(invalid).has("error"),"invalid request rejected without a world")
 var parsed: Dictionary=Rules.parse(JSON.stringify(request)).request
 check(parsed.point==request.point and parsed.request==request.request and parsed.action==request.action and int(parsed.revision)==0,"valid request retains exact identity and revision")
 var snapshot:=state.duplicate(true)
 check(Rules.observation(request,point,state,"character-a",true,true).key=="character-a:one","receipt identity belongs to the source character")
 check(Rules.observation(request,point,state,"character-a",false,true).has("error"),"unavailable observations cannot be admitted")
 check(Rules.observation(request,point,state,"character-a",true,false).has("error"),"remote observations cannot be admitted")
 check(state==snapshot,"decisions never mutate saved state")
 State.record(state,point,"character-a:one")
 check(Rules.observation(request,point,state,"character-a",true,true).operation=="unchanged","retry is recognized before the stale revision check")
 var unknown:=request.duplicate();unknown.point="unknown"
 check(Rules.observation(unknown,{},state,"character-a",true,true).has("error"),"unknown points cannot become commands")
 var coordinates: Dictionary={point.id:point.position}
 check(Rules.nearest(point.position,[point.id],coordinates,[])==point.id,"an eligible nearby point is selected")
 check(Rules.nearest(point.position+Vector3(.1,0,0),[point.id],coordinates,[point.position+Vector3(.1,0,0)]).is_empty(),"a closer native interaction retains priority")
 var before: Dictionary={"version":1,"revision":0,"mode":"gentle"}
 var change: Dictionary={"point":Conduit.POINT,"mode":"deep","revision":0}
 var decision:=Conduit.choose(change,before,true,true,true)
 check(decision.changed and decision.next.mode=="deep" and decision.next.revision==1 and before.mode=="gentle","conduit choice returns a successor without modifying the current configuration")
 for flags in [[false,true,true],[true,false,true],[true,true,false]]:
  check(Conduit.choose(change,before,flags[0],flags[1],flags[2]).has("error"),"host, Knowledge and reach requirements remain independent")
 change.revision=1
 check(Conduit.choose(change,before,true,true,true).has("error"),"stale configuration rejected")
 var returns=preload("res://garden_return_service.gd")
 var owner:=ProgressFacts.new();owner.garden_interactions={"version":1}
 returns.begin(owner)
 var run: String=returns.join(owner,"departed-character")
 var member=returns.Member.new("departed-character",run,true)
 returns.bank(owner,member,[0],"protected")
 returns.outcome(owner,member,"disconnected")
 var facts: Dictionary=returns.state(owner)
 check(facts.active.closed and facts.history.size()==1 and facts.history[0].outcomes.disconnected==1,"frozen return identity finishes after its peer is absent")
 facts.history.clear()
 check(returns.state(owner).history.size()==1,"return inspection cannot mutate authoritative records")
 if not failed:print("PASS: detached Garden observation admission, receipt identity, interaction priority and conduit transitions")
 quit(1 if failed else 0)
