extends RefCounted
# Input prediction is disposable presentation state. Only the host changes gameplay.
const MAX_PENDING:=120
const REDUNDANCY:=18
const REMOTE_DELAY_MS:=100
const PREDICTION_LIMIT:=.25
var sequence:=0
var pending: Array=[]
var epoch:=""
var servers: Dictionary={}
var remote: Dictionary={}
var last_packet_ms:=0
var gap_max_ms:=0
var gap_count:=0
var correction_max:=0.0
var correction_count:=0
var host_frame_max_ms:=0.0
var host_stalls:=0
var input_expiries:=0
var frame_at_usec:=0

func clear() -> void:
 sequence=0;pending.clear();epoch="";servers.clear();remote.clear();last_packet_ms=0
 gap_max_ms=0;gap_count=0;correction_max=0;correction_count=0;host_frame_max_ms=0;host_stalls=0;input_expiries=0;frame_at_usec=0

func world_key(game: Node,p: Dictionary) -> String:
 return str([game.destination,game.encounter_number,game.map_seed,p.get("wild",false),p.get("fallen",false)])

func accept(id: int,commands: Array,key: String,expected: String,now: int) -> void:
 if key!=expected or commands.size()>REDUNDANCY:return
 var s: Dictionary=servers.get(id,{})
 if s.get("epoch","")!=key:s={"epoch":key,"ack":0,"latest":0,"queue":[],"partial":0.0,"at":now}
 # Validate the complete redundant batch before changing its acknowledgement.
 var previous:=0
 for c in commands:
  if not c is Array or c.size()!=3 or not c[0] is int or not c[1] is Vector2 or not (c[2] is float or c[2] is int):return
  if c[0]<=previous or c[0]<1 or c[0]>2147483647 or not c[1].is_finite() or not is_finite(float(c[2])) or float(c[2])<=0 or float(c[2])>1.0/30.0:return
  previous=c[0]
 for c in commands:
  if int(c[0])>int(s.latest):
   s.queue.append([c[0],c[1].limit_length(),float(c[2])]);s.latest=c[0]
 # Never replay an unbounded backlog as a burst of accelerated movement.
 while s.queue.size()>30:
  s.ack=s.queue.pop_front()[0];s.partial=0.0
 s.at=now;servers[id]=s

func server_tick(game: Node,id: int,delta: float,now: int) -> void:
 var s: Dictionary=servers.get(id,{})
 if s.is_empty():return
 if s.epoch!=world_key(game,game.players[id]):servers.erase(id);return
 if now-int(s.at)>350:
  if not s.queue.is_empty():input_expiries+=1
  s.queue.clear();s.ack=s.latest;s.partial=0.0;return
 var budget:=minf(delta,1.0/30.0)
 var start: Vector3=game.players[id].pos
 while budget>.000001 and not s.queue.is_empty():
  var c: Array=s.queue[0]
  var used:=minf(budget,float(c[2])-float(s.partial))
  game.move_player(id,c[1],used);budget-=used;s.partial+=used
  if float(s.partial)>=float(c[2])-.000001:s.ack=c[0];s.queue.pop_front();s.partial=0.0
 game.players[id].velocity=(game.players[id].pos-start)/maxf(delta,.001)

func acknowledgement(id: int,key: String) -> Dictionary:
 var s: Dictionary=servers.get(id,{})
 if s.get("epoch","")!=key:return {"ack":0,"partial":0.0,"partial_sequence":0}
 return {"ack":s.ack,"partial":s.partial,"partial_sequence":s.queue[0][0] if not s.queue.is_empty() else 0}

func predict_step(game: Node,p: Dictionary,direction: Vector2,delta: float) -> void:
 if p.get("fallen",false):p.velocity=Vector3.ZERO;return
 var field=game.stage.visual_field
 if p.wild and field!=null and field.configured_key!=Vector3i(game.destination,game.depth,game.map_seed):p.velocity=Vector3.ZERO;return
 var start: Vector3=p.pos
 var desired: Vector3=start+game.world_direction(direction)*game.WALK_SPEED*float(p.get("motion_scale",1.0))*delta
 if not p.wild and p.has("motion_radius"):
  var flat:=Vector2(desired.x,desired.z).limit_length(float(p.motion_radius));desired=Vector3(flat.x,0,flat.y)
 elif p.wild and field!=null and field.procedural:
  desired.x=clampf(desired.x,field.REGION.position.x+.5,field.REGION.end.x-.5)
  desired.z=clampf(desired.z,field.REGION.position.y+.5,field.REGION.end.y-.5)
 else:desired=game.bound_position(desired,p.wild)
 p.pos=field.slide(start,desired) if p.wild and field!=null else desired
 p.velocity=(p.pos-start)/maxf(delta,.001)

func client_tick(game: Node,id: int,direction: Vector2,delta: float) -> Array:
 if not game.players.has(id):return []
 var p: Dictionary=game.players[id]
 var key:=str(p.get("motion_epoch",""))
 if key.is_empty():return []
 if key!=epoch:epoch=key;pending.clear()
 # A stalled client must not request seconds of movement on the next frame.
 var duration:=minf(delta,1.0/30.0)
 var horizon:=0.0
 for c in pending:horizon+=float(c[2])
 sequence+=1;pending.append([sequence,direction,duration])
 predict_step(game,p,direction,minf(duration,maxf(0,PREDICTION_LIMIT-horizon)))
 if pending.size()>MAX_PENDING:pending.pop_front()
 return pending.slice(maxi(0,pending.size()-REDUNDANCY)).duplicate(true)

func receive(game: Node,id: int,before: Dictionary,now: int) -> void:
 if last_packet_ms>0:
  var gap:=now-last_packet_ms;gap_max_ms=maxi(gap_max_ms,gap)
  if gap>100:gap_count+=1
 last_packet_ms=now
 for peer in game.players:
  var p: Dictionary=game.players[peer]
  var key:=str(p.get("motion_epoch",""))
  if peer==id:
   var same:=key==epoch and not key.is_empty()
   if not same:pending.clear();epoch=key
   var ack: Dictionary=p.get("motion_ack",{})
   var acknowledged:=int(ack.get("ack",0))
   pending=pending.filter(func(c):return int(c[0])>acknowledged)
   var replay_budget:=PREDICTION_LIMIT
   for index in pending.size():
    var c: Array=pending[index]
    var duration:=float(c[2])-float(ack.get("partial",0.0)) if int(c[0])==int(ack.get("partial_sequence",0)) else float(c[2])
    var replay:=minf(replay_budget,maxf(0,duration))
    predict_step(game,p,c[1],replay);replay_budget-=replay
   if same and before.has(id):
    var error: float=Vector3(before[id].pos).distance_to(p.pos)
    correction_max=maxf(correction_max,error)
    if error>.25:correction_count+=1
  else:
   var history: Array=remote.get(peer,[])
   if not history.is_empty() and (history[-1].epoch!=key or Vector3(history[-1].pos).distance_to(p.pos)>4):history.clear()
   history.append({"at":now,"pos":p.pos,"epoch":key})
   while history.size()>12:history.pop_front()
   remote[peer]=history
 for peer in remote.keys():
  if not game.players.has(peer):remote.erase(peer)

func render_players(people: Dictionary,id: int,now: int) -> Dictionary:
 var rendered:=people.duplicate()
 for peer in remote:
  if peer==id or not people.has(peer):continue
  var history: Array=remote[peer]
  if history.is_empty():continue
  var target:=now-REMOTE_DELAY_MS
  var position: Vector3=history[-1].pos
  if target<int(history[0].at):position=history[0].pos
  else:
   for i in range(1,history.size()):
    if target<=int(history[i].at):
     var a: Dictionary=history[i-1];var b: Dictionary=history[i]
     position=Vector3(a.pos).lerp(b.pos,clampf(float(target-int(a.at))/maxf(1,int(b.at)-int(a.at)),0,1));break
  rendered[peer]=people[peer].duplicate();rendered[peer].pos=position
 return rendered

func frame(delta: float,people: Dictionary={}) -> void:
 for id in servers.keys():
  if not people.has(id):servers.erase(id)
 var now:=Time.get_ticks_usec()
 var elapsed: float=float(now-frame_at_usec)/1000.0 if frame_at_usec>0 else delta*1000
 frame_at_usec=now
 host_frame_max_ms=maxf(host_frame_max_ms,elapsed)
 if elapsed>50:host_stalls+=1

func sample() -> Dictionary:
 var result={"snapshot_gap_max_ms":gap_max_ms,"snapshot_gaps_over_100ms":gap_count,"prediction_correction_max":correction_max,"prediction_corrections_over_025":correction_count,"unacknowledged_inputs":pending.size(),"host_frame_max_ms":host_frame_max_ms,"host_frames_over_50ms":host_stalls,"input_expiries":input_expiries}
 gap_max_ms=0;gap_count=0;correction_max=0;correction_count=0;host_frame_max_ms=0;host_stalls=0;input_expiries=0
 return result
