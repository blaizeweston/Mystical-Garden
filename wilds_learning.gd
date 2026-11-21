extends RefCounted
const TACTICS=["ranged","burst","choke","kite","thorn_line","cast_denial","area_pressure","route_denial","shelter_break"]
static func blank() -> Dictionary:
 return {"version":1,"encounters":0,"score":{},"peak":{},"quiet":{}}
static func normalize(source) -> Dictionary:
 var result:=blank()
 if not source is Dictionary: return result
 result.encounters=clampi(int(source.get("encounters",0)),0,1000000)
 for group in ["score","peak","quiet"]:
  if not source.get(group) is Dictionary: continue
  for key in TACTICS: result[group][key]=clampi(int(source[group].get(key,0)),0,100)
 return result
static func observe(memory: Dictionary,evidence: Dictionary,floor_number: int) -> void:
 memory.encounters+=1
 for key in TACTICS:
  var score:=int(memory.score.get(key,0));var peak:=int(memory.peak.get(key,score));var quiet:=int(memory.quiet.get(key,0))
  if evidence.get(key,false):
   score=mini(100,score+(3 if floor_number>=18 else 2));quiet=0;peak=maxi(peak,score)
  else:
   quiet+=1
   if quiet>=6: score=maxi(ceili(peak*.35),score-1);quiet=0
  memory.score[key]=score;memory.peak[key]=peak;memory.quiet[key]=quiet
# Knowledge awards use whole strength bands.
@warning_ignore_start("integer_division")
static func traits(memory: Dictionary,floor_number: int,stamp: int,legacy: Dictionary={}) -> int:
 if floor_number<3: return 0
 var mask:=0
 for pair in [["ranged",1],["burst",2],["choke",8],["kite",8]]:
  # The save formats record the same tactics on different scales. Use one roll.
  var strength:=maxi(int(memory.score.get(pair[0],0)),int(legacy.get(pair[0],0))*2)
  if strength>=6 and posmod(stamp+int(pair[1]),10)<mini(8,2+strength/4): mask|=int(pair[1])
 # Independent, slow world variation even with varied player tactics.
 if int(memory.encounters)>=20 and floor_number>=8 and posmod(stamp,5)==0: mask|=4
 return mask
@warning_ignore_restore("integer_division")
static func bounded(mask: int,floor_number: int,stamp: int) -> int:
 if floor_number<3: return 0
 var cap:=1 if floor_number<9 else 2 if floor_number<24 else 3
 var result:=0;var count:=0;var flags: Array=[1,2,4,8]
 for i in flags.size():
  var flag: int=flags[posmod(i+stamp,flags.size())]
  if mask&flag and count<cap: result|=flag;count+=1
 return result

static func notice(before: Dictionary,after: Dictionary) -> String:
 for key in TACTICS:
  if int(before.get(key,0))<6 and int(after.get(key,0))>=6: return " The mycelium remembers. The Wilds are responding to your repeated tactics."
 return ""
