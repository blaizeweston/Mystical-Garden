from pathlib import Path
import math,random,bpy
from mathutils import Vector
p=Path(__file__).resolve().parents[1]; rng=random.Random(86271)
bpy.ops.wm.read_factory_settings(use_empty=True)
def mat(name,c):
 m=bpy.data.materials.new(name);m.use_nodes=True;m.diffuse_color=(*c,1);s=m.node_tree.nodes.get('Principled BSDF');s.inputs['Base Color'].default_value=(*c,1);s.inputs['Roughness'].default_value=.92;return m
bark=mat('Fissured umber bark',(.095,.064,.033));edge=mat('Exposed warm grain',(.18,.125,.061));moss=mat('Muted moss',(.085,.11,.042));leaves=[mat('Leaf olive '+str(i),c) for i,c in enumerate([(.055,.09,.029),(.085,.12,.041),(.12,.145,.057),(.068,.105,.05)])];slate=mat('Weathered grey sandstone',(.18,.17,.14));split=mat('Eroded stone edge',(.23,.215,.18))
def root(name):
 o=bpy.data.objects.new(name,None);bpy.context.collection.objects.link(o);return o
def vine(parent,points,r,material=bark,name='Flowing root'):
 c=bpy.data.curves.new(name,'CURVE');c.dimensions='3D';c.resolution_u=8;c.bevel_resolution=3;c.bevel_depth=r
 s=c.splines.new('BEZIER');s.bezier_points.add(len(points)-1)
 for i,(b,pos) in enumerate(zip(s.bezier_points,points)):
  b.co=pos;b.handle_left_type='AUTO';b.handle_right_type='AUTO';b.radius=max(.025,(1-i/(len(points)-1))**.8)
 o=bpy.data.objects.new(name,c);bpy.context.collection.objects.link(o);o.parent=parent;o.data.materials.append(material);return o
def leaf(parent,point,angle,size,material):
 # Bent pointed leaf, with a raised midrib rather than a rounded blob.
 mesh=bpy.data.meshes.new('Lanceolate leaf');w=size*.32
 coords=[(0,0,0),(size*.43,w,.025),(size,0,-.045),(size*.43,-w,.025),(size*.48,0,.07)]
 mesh.from_pydata(coords,[],[(0,1,4),(1,2,4),(2,3,4),(3,0,4)]);mesh.materials.append(material)
 o=bpy.data.objects.new('Leaf',mesh);bpy.context.collection.objects.link(o);o.parent=parent;o.location=point;o.rotation_euler=(rng.uniform(-.3,.3),rng.uniform(-.4,.3),angle)
def tree(name,dead=False):
 r=root(name)
 for k in range(3):
  a=k*math.tau/3
  points=[(math.cos(a)*.22,math.sin(a)*.22,0),(.15+math.cos(a+.6)*.17,.07+math.sin(a+.6)*.17,1.0),(-.08+math.cos(a+1)*.15,.1+math.sin(a+1)*.15,2.3),(.22,.08,4.1)]
  vine(r,points,.26,bark,'Braided trunk')
 for k in range(9):
  a=k*math.tau/9+.1
  vine(r,[(.05,0,.55),(math.cos(a)*.45,math.sin(a)*.45,.14),(math.cos(a+.2)*.95,math.sin(a+.2)*.95,.04),(math.cos(a+.4)*1.65,math.sin(a+.4)*1.65,.008)],.16)
 for k in range(11):
  a=k*2.399;z=1.35+k*.19;length=rng.uniform(.85,1.65);v=Vector((math.cos(a),math.sin(a),0))
  points=[(.1,0,z),tuple(v*.55+Vector((0,0,z+.18))),tuple(v*length+Vector((.1,0,z+.52))),tuple(v*(length+.26)+Vector((0,0,z+1.0)))]
  vine(r,points,.13,bark,'Swept bough')
  for j in range(3):
   base=Vector(points[1]).lerp(Vector(points[2]),j/3);aa=a+(-.65 if j%2 else .65);out=Vector((math.cos(aa),math.sin(aa),.5));end=base+out*.62
   vine(r,[tuple(base),tuple(base+out*.28),tuple(end)],.035,bark,'Fine twig')
   if not dead:
    for t in range(14):
     pos=base.lerp(end,t/14)+Vector((rng.uniform(-.18,.18),rng.uniform(-.18,.18),rng.uniform(-.03,.13)))
     leaf(r,pos,aa+(-.9 if t%2 else .9),rng.uniform(.18,.35),rng.choice(leaves))
 # Irregular longitudinal raised grain on the lower trunk.
 for k in range(18):
  a=k*math.tau/18
  vine(r,[(math.cos(a)*.30,math.sin(a)*.30,.04),(.1+math.cos(a+.4)*.25,math.sin(a+.4)*.25,.6),(.15+math.cos(a+.7)*.20,.06+math.sin(a+.7)*.20,1.3),(-.02+math.cos(a+1)*.16,.1+math.sin(a+1)*.16,2.4)],.016,edge if k%3==0 else bark,'Bark ridge')
 return r
def stone(parent,pos,size,material=slate):
 bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=3,radius=1)
 o=bpy.context.object;o.name='Waterworn fractured stone';o.parent=parent;o.location=pos
 for v in o.data.vertices:
  q=v.co;fac=1+.09*math.sin(q.x*9+q.y*3)+.055*math.cos(q.z*17+q.x*5);q*=fac
 o.scale=size;o.data.materials.append(material)
 bevel=o.modifiers.new('Soften eroded edges','SMOOTH');bevel.factor=.25;bevel.iterations=2
 for f in o.data.polygons:f.use_smooth=True
 return o
t=tree('AncientWovenTree');s=tree('WeatheredSnag',True);rock=root('RootboundStone')
stone(rock,(0,0,.38),(.78,.58,.53));stone(rock,(.42,.1,.17),(.43,.42,.26))
for k in range(5):
 a=k*math.tau/5;vine(rock,[(math.cos(a),math.sin(a)*.8,.015),(math.cos(a+.1)*.6,math.sin(a+.1)*.5,.25),(math.cos(a+.4)*.3,math.sin(a+.4)*.3,.7)],.075)
ruin=root('WeatheredRuins')
# Broad, dark, irregular wall remnants retain a readable cover footprint.
for i in range(5):
 for j in range(3 if i in [0,1,3] else 2):
  o=stone(ruin,(-1.3+i*.65+rng.uniform(-.07,.07),rng.uniform(-.07,.07),.22+j*.39),(.41,.53,.28),slate if j%2 else split)
for k in range(7):
 a=k*.9;vine(ruin,[(-1.5+k*.45,-.59,.01),(-1.2+k*.4,-.5,.5),(-1+k*.36,-.32,1.12)],.045)
path=root('SunkenFlagstones')
for i in range(4):
 o=stone(path,((i%2-.5)*.54,(i//2-.5)*.59,-.015),(.32,.34,.055),split);o.rotation_euler.z=rng.uniform(-.2,.2)
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(p/'assets/source/natural_world.blend'))
for r,name in [(t,'root_tree'),(s,'root_snag'),(rock,'root_stone'),(ruin,'wild_ruin'),(path,'wild_path')]:
 bpy.ops.object.select_all(action='DESELECT')
 pieces=[o for o in r.children_recursive if o.type in {'MESH','CURVE'}]
 for o in pieces:o.select_set(True)
 bpy.context.view_layer.objects.active=pieces[0];bpy.ops.object.convert(target='MESH');bpy.ops.object.join()
 r.select_set(True);bpy.context.view_layer.objects.active=r
 bpy.ops.export_scene.gltf(filepath=str(p/f'assets/{name}.glb'),export_format='GLB',use_selection=True,export_materials='EXPORT')
 print('EXPORTED',name)
