extends RefCounted
## One finished terrain mask, baked after ALL clearings/corridors are combined.
## Closing narrow shoulder gaps happens before collision, navigation or rendering.
const CELL:=0.5
const BIN:=4.0
const MAX_DISTANCE:=3.5
var cells: Dictionary={}
var edges: Dictionary={}
var region: Rect2i
func build(field: RefCounted) -> void:
 region=Rect2i(field.REGION.position*2,field.REGION.size*2)
 var raw: Dictionary={}
 for x in range(region.position.x,region.end.x):
  for z in range(region.position.y,region.end.y):
   if field.source_distance(Vector3((x+.5)*CELL,0,(z+.5)*CELL))>=0:raw[Vector2i(x,z)]=true
 # Morphological closing: near-touching shoulders become a proper crossing,
 # not a strip that looks joined but is narrower than the player diameter.
 var offsets: Array[Vector2i]=[]
 for x in range(-2,3):
  for z in range(-2,3):
   if x*x+z*z<=5:offsets.append(Vector2i(x,z))
 var expanded: Dictionary={}
 for cell in raw:
  for offset in offsets:
   var next: Vector2i=cell+offset
   if region.has_point(next):expanded[next]=true
 for cell in expanded:
  var inside:=true
  for offset in offsets:
   if not expanded.has(cell+offset):inside=false;break
  if inside:cells[cell]=true
 # Preserve every original walkable cell. Baking can only join shoulders.
 cells.merge(raw)
 for cell in cells:
  var at:=Vector2(cell)*CELL
  for side in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
   if cells.has(cell+side):continue
   var a: Vector2;var b: Vector2
   if side==Vector2i.LEFT:a=at;b=at+Vector2(0,CELL)
   elif side==Vector2i.RIGHT:a=at+Vector2(CELL,0);b=at+Vector2(CELL,CELL)
   elif side==Vector2i.UP:a=at;b=at+Vector2(CELL,0)
   else:a=at+Vector2(0,CELL);b=at+Vector2(CELL,CELL)
   var key:=Vector2i(floori(((a+b)*.5).x/BIN),floori(((a+b)*.5).y/BIN))
   if not edges.has(key):edges[key]=[]
   edges[key].append([a,b])
func distance(at: Vector3) -> float:
 var p:=Vector2(at.x,at.z);var cell:=Vector2i(floori(p.x/CELL),floori(p.y/CELL))
 var key:=Vector2i(floori(p.x/BIN),floori(p.y/BIN));var best:=MAX_DISTANCE*MAX_DISTANCE
 # Local boundary bins make this independent of the number of painted routes.
 for x in range(-1,2):
  for y in range(-1,2):
   for edge in edges.get(key+Vector2i(x,y),[]):
    var delta: Vector2=edge[1]-edge[0]
    var t:=clampf((p-edge[0]).dot(delta)/delta.length_squared(),0,1)
    best=minf(best,p.distance_squared_to(edge[0]+delta*t))
 return sqrt(best)*(1.0 if cells.has(cell) else -1.0)
