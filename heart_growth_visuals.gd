extends RefCounted
const Catalog=preload("res://heart_catalog.gd")
static func count(unlocked: Array) -> int:
 var known: Dictionary={}
 for node in Catalog.DEFINITIONS:
  if node.id!="heart" and Catalog.enabled(node.id) and unlocked.has(node.id):known[node.id]=true
 return known.size()
static func trunk_height(completed: float) -> float:return .85+minf(8.8,.9+completed*.25) if completed>=3 else 0.0
static func height(completed: float) -> float:return trunk_height(completed) if completed>=3 else 1.4+completed*.18
static func counts(event: Dictionary,pending: Array,unlocked: Array) -> Vector2i:
 var total:=count(unlocked)
 if event.has("from_growth") and event.has("to_growth"):return Vector2i(maxi(0,int(event.from_growth)),maxi(0,int(event.to_growth)))
 # Old queued scenes infer their place from the remaining researched unlocks.
 var after:=total
 for value in pending:
  if int(value.get("sequence",0))>int(event.get("sequence",0)) and count([value.get("technology","")])>0:after-=1
 return Vector2i(maxi(0,after-int(count([event.get("technology","")])>0)),maxi(0,after))
static func hold(stage: Node3D,value: int) -> void:
 stage.set_meta("garden_growth_heart",{"from":value,"to":value,"amount":1.0})
 sync(stage,{"unlocked":stage.heart_unlocked})
static func animate(stage: Node3D,range_value: Vector2i,amount: float) -> void:
 stage.set_meta("garden_growth_heart",{"from":range_value.x,"to":range_value.y,"amount":smoothstep(0,1,amount)})
 sync(stage,{"unlocked":stage.heart_unlocked})
static func clear(stage: Node3D) -> void:
 stage.remove_meta("garden_growth_heart");sync(stage,{"unlocked":stage.heart_unlocked})
static func sync(stage: Node3D,state: Dictionary) -> void:
 var actual := int(state.get("development",stage.heart_development));var reveal: Dictionary=stage.get_meta("garden_growth_heart",{})
 var target:=clampi(int(reveal.get("to",actual)),0,actual)
 if stage.experimental_garden==null:return
 var sculpt: Node3D=stage.experimental_garden.heart
 var previous_growth:=clampi(int(reveal.get("from",target)),0,target)
 var growth_amount:=clampf(float(reveal.get("amount",1)),0,1)
 var rendered:=lerpf(previous_growth,target,growth_amount)
 sculpt.set_meta("heart_visual_count",target)
 sculpt.set_meta("rendered_growth",rendered)
 sculpt.set_research_growth(rendered)
