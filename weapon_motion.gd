extends RefCounted
const Classes=preload("res://class_catalog.gd")
static var PROFILES: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/characters/weapon_actions.json"))
static func form(player: Dictionary) -> String:
 var c:=clampi(int(player.get("frame",0)),0,Classes.DEFINITIONS.size()-1)
 return Classes.DEFINITIONS[c].weapons[clampi(int(player.get("weapon_kind",0)),0,Classes.DEFINITIONS[c].weapons.size()-1)].visual
static func profile(name: String) -> Dictionary:
 return PROFILES.get(name,PROFILES.blade)
static func is_projectile(name: String) -> bool:
 return bool(profile(name).get("projectile",false))
# Skeletal poses are authored in Blender. Runtime adds no second arm/body animation.
static func pose(name: String,phase: float,active: bool,combo: int=0) -> Dictionary:
 var t:=clampf(phase,0,1);var p:=profile(name);var pulse:=sin(t*PI) if active else 0.0
 return {"body":0.0,"yaw":0.0,"arm":0.0,"offhand":0.0,"pulse":pulse,"clip":p.clip,"contact":p.release,"combo":combo}

# Snapshot phases advance on the render clock; held 20 Hz packets cannot freeze a pose.
static func advance(actor: Dictionary,snapshot: Dictionary,delta: float) -> Dictionary:
 var key:=str(snapshot.get("form","weapon"))+":"+str(snapshot.get("combo",0))
 var phase:=clampf(float(snapshot.get("phase",1)),0,1)
 var duration:=maxf(.08,float(snapshot.get("duration",340))/1000.0)
 if actor.get("motion_key","")!=key:
  actor.motion_key=key;actor.motion_phase=phase
 elif snapshot.get("active",false):actor.motion_phase=maxf(phase,minf(1,float(actor.get("motion_phase",phase))+delta/duration))
 else:actor.motion_phase=1.0
 return {"phase":float(actor.motion_phase),"active":bool(snapshot.get("active",false)) and float(actor.motion_phase)<1,"form":snapshot.get("form","weapon")}
