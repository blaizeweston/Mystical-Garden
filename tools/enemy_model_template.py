"""Shared parametric enemy kit. Z-up authoring; Godot imports GLB as Y-up.
Keep EnemyCore, Root0..5, Growth1/2 and Adapt* nodes for the shared runtime rig.
Change catalogue dimensions/palette/role, add a form builder, then regenerate.
"""
import math, random
import bpy
from mathutils import Vector

def material(name, rgb, glow=0):
    m=bpy.data.materials.new(name);m.diffuse_color=(*rgb,1)
    s=m.node_tree.nodes.get("Principled BSDF")
    s.inputs["Base Color"].default_value=(*rgb,1);s.inputs["Roughness"].default_value=.78
    s.inputs["Emission Color"].default_value=(*rgb,1);s.inputs["Emission Strength"].default_value=glow
    return m
def empty(name,parent=None,loc=(0,0,0)):
    o=bpy.data.objects.new(name,None);bpy.context.collection.objects.link(o);o.parent=parent;o.location=loc;return o
def blob(name,parent,p,size,mat,sub=2):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=sub,radius=1)
    o=bpy.context.object;o.name=name;o.parent=parent;o.location=p;o.scale=size;o.data.materials.append(mat)
    for face in o.data.polygons:face.use_smooth=True
    return o
def vine(name,parent,points,r,mat):
    c=bpy.data.curves.new(name,"CURVE");c.dimensions="3D";c.resolution_u=7;c.bevel_depth=r;c.bevel_resolution=2
    s=c.splines.new("BEZIER");s.bezier_points.add(len(points)-1)
    for i,(b,p) in enumerate(zip(s.bezier_points,points)):
        b.co=p;b.handle_left_type=b.handle_right_type="AUTO";b.radius=1-.94*i/(len(points)-1)
    o=bpy.data.objects.new(name,c);bpy.context.collection.objects.link(o);o.parent=parent;o.data.materials.append(mat);return o
def petal(name,parent,a,z,length,width,mat,radius=.35,up=False):
    r=Vector((math.cos(a),math.sin(a),0));t=Vector((-r.y,r.x,0))
    verts=[];faces=[];rings=14;columns=6
    for i in range(rings+1):
        v=i/rings;bulge=math.sin(math.pi*v)
        center=r*(.10+(radius-.1)*bulge*.7+radius*.7*v)+Vector((0,0,z+length*v*(1 if up else -1)))
        for j in range(columns+1):
            u=j/columns*2-1
            point=center+t*u*width*max(.015,bulge)**.75+Vector((0,0,.055*bulge*(1-u*u)))
            verts.append(point)
    for i in range(rings):
        for j in range(columns):
            a=i*(columns+1)+j;faces.append((a,a+1,a+columns+2,a+columns+1))
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(verts,[],faces);mesh.materials.append(mat)
    for face in mesh.polygons:face.use_smooth=True
    o=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(o);o.parent=parent
    o.modifiers.new("Living thickness","SOLIDIFY").thickness=.014
    return o
def radial_roots(parent,bark,count=6,radius=.75,height=.5):
    for i in range(count):
        a=math.tau*i/count
        vine("Root",parent,[(0,0,height),(math.cos(a)*radius*.45,math.sin(a)*radius*.45,.18),
            (math.cos(a+.18)*radius,math.sin(a+.18)*radius,.035)],.095,bark)
def hex_rgb(value):
    return tuple(int(value.lstrip("#")[i:i+2],16)/255 for i in (0,2,4))

def build(spec):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    rng=random.Random(spec["id"])
    bark=material("Ancient bark",(.075,.045,.037));wood=material("Split root flesh",(.28,.18,.12))
    leaf=material("Unhealthy leaves",(.17,.23,.12));bone=material("Pale exposed host",(.49,.45,.32))
    purple=material("Violet petals",(.18,.035,.31));fungus=material("Fungal skin",(.39,.34,.24))
    coremat=material("Living core",hex_rgb(spec["core"]),.18)
    glow=material("Spore light",hex_rgb(spec["glow"]),1.1)
    root=empty("Enemy");base=empty("Base",root)
    form=spec["form"]
    if form not in {"walker","flower","stag","cantor","hound","willow","moth","brute","wasp","brood","shepherd","grazer","lure","burrower","widow","pallbearer","thief","ashen_hart","glasscap","choir"}:
        raise ValueError("Add a form builder for: "+form)
    height=2.0
    if form in {"burrower","widow","pallbearer","thief","ashen_hart","glasscap","choir"}:
        from new_enemy_forms import build_form
        height=build_form(form,root,base,(bark,wood,leaf,bone,fungus,coremat,glow))
    elif form=="walker":
        blob("EnemyCore",root,(0,0,1.05),(.29,.23,.45),wood)
        blob("Hollow skull",base,(0,-.035,1.68),(.23,.21,.31),bone)
        blob("Face hollow",base,(0,-.205,1.7),(.13,.035,.18),bark)
        blob("Single eye",base,(0,-.239,1.7),(.055,.018,.065),glow)
        for i,s in enumerate([-1,1]):
            p=empty("Root"+str(i),root,(s*.16,0,.70))
            vine("Walking root",p,[(0,0,0),(s*.03,-.03,-.35),(s*.08,-.18,-.67)],.12,bark)
            arm=empty("Root"+str(i+2),root,(s*.28,0,1.32))
            vine("Hooked arm",arm,[(0,0,0),(s*.22,-.04,-.4),(s*.16,-.20,-.78),(s*.10,-.38,-.55)],.10,bark)
        for i in range(5):petal("Ragged bark cloak",base,i*math.tau/5,1.45,.85,.16,leaf,.38)
        height=1.9
    elif form=="flower":
        vine("Flower stalk",base,[(0,0,.05),(.06,0,.8),(-.04,.02,1.7),(0,0,2.3)],.19,bark)
        blob("EnemyCore",root,(0,0,2.28),(.28,.27,.43),coremat)
        radial_roots(base,bark)
        for tier in range(3):
            for i in range(5):petal("Layered violet petals",base,i*math.tau/5+tier*.5,1.9-tier*.38,.6,.18,purple,.45)
        for i in range(7):
            a=i*math.tau/7
            vine("Crown sepal",base,[(math.cos(a)*.12,math.sin(a)*.12,1.95),(math.cos(a)*.4,math.sin(a)*.4,2.2),
                (math.cos(a)*.31,math.sin(a)*.31,2.85)],.07,purple)
        for i in range(4):
            a=i*math.tau/4;p=empty("Root"+str(i),root,(math.cos(a)*.13,math.sin(a)*.13,1.55))
            vine("Flower tendril",p,[(0,0,0),(math.cos(a)*.65,math.sin(a)*.65,-.5),(math.cos(a)*.55,math.sin(a)*.55,-1.4)],.05,purple)
            blob("Pollen",p,(math.cos(a)*.55,math.sin(a)*.55,.08),(.085,)*3,glow)
        height=2.7
    elif form in ["stag","hound"]:
        stag=form=="stag";body_z=1.03 if stag else .67
        blob("EnemyCore",root,(0,.1,body_z),(.30,.62,.32) if stag else (.31,.55,.25),wood)
        blob("Infected rump",base,(0,.52,body_z),(.34,.32,.31),bark)
        neck_z=1.48 if stag else .87
        vine("Neck",base,[(0,-.3,body_z),(0,-.5,neck_z),(0,-.6,neck_z+.15)],.20,bone)
        blob("Skull",base,(0,-.68,neck_z+.13),(.20,.30,.23),bone)
        blob("Split muzzle",base,(0,-.94,neck_z+.05),(.13,.20,.11),bark)
        for s in [-1,1]:
            blob("Host eye",base,(s*.17,-.81,neck_z+.19),(.032,.065,.04),glow)
            if stag:
                vine("Antler",base,[(s*.1,-.55,neck_z+.28),(s*.40,-.43,2.15),(s*.60,-.35,2.65)],.07,wood)
                for j in range(3):
                    vine("Antler twig",base,[(s*(.25+j*.10),-.45,1.95+j*.18),(s*(.5+j*.1),-.60,2.12+j*.20)],.04,bone)
            else:
                petal("Ear",base,0 if s==1 else math.pi,neck_z+.24,.25,.06,bark,.23,True)
        for i,(x,y) in enumerate([(-.23,-.32),(.23,-.32),(-.24,.52),(.24,.52)]):
            p=empty("Root"+str(i),root,(x,y,body_z-.12))
            vine("Upright leg",p,[(0,0,0),(x*.22,.04,-body_z*.48),(x*.2,-.08,-body_z+.14)],.075 if stag else .09,bark)
        for i in range(4):
            vine("Infesting vine",base,[(-.30,.45-i*.2,body_z),(-.22,.48-i*.2,body_z+.35),(.25,.41-i*.2,body_z+.26)],.055,leaf)
        if not stag:
            for i in range(6):
                petal("Maw thorn",base,i*math.tau/6,neck_z,.25,.07,bone,.25)
        height=2.4 if stag else 1.3
    elif form=="cantor":
        vine("Fungal stem",base,[(0,0,.05),(.04,0,.8),(0,0,1.8)],.22,fungus)
        blob("EnemyCore",root,(0,0,1.45),(.25,.24,.35),coremat)
        blob("Bell cap",base,(0,0,2.0),(.66,.53,.29),fungus)
        for i in range(9):
            a=i*math.tau/9
            petal("Bell gill",base,a,2.03,.65,.15,bone,.56)
        for i in range(4):
            a=i*math.tau/4;p=empty("Root"+str(i),root,(math.cos(a)*.21,math.sin(a)*.21,1.4))
            vine("Chanting arm",p,[(0,0,0),(math.cos(a)*.5,math.sin(a)*.5,-.25),(math.cos(a)*.55,math.sin(a)*.55,.1)],.06,fungus)
            blob("Spore bell",p,(math.cos(a)*.50,math.sin(a)*.50,-.14),(.09,.09,.15),glow)
        radial_roots(base,bark,5,.62,.45);height=2.3
    elif form=="willow":
        blob("EnemyCore",root,(0,0,1.25),(.22,.19,.40),coremat)
        vine("Bent trunk",base,[(0,0,.1),(-.1,.02,.9),(.05,0,1.85)],.22,bark)
        blob("Veiled face",base,(0,-.14,1.72),(.18,.10,.22),bone)
        for i in range(8):
            a=i*math.tau/8;p=empty("Root"+str(i%4),root) if i<4 else base
            vine("Weeping branch",p,[(0,0,1.8),(math.cos(a)*.55,math.sin(a)*.55,2.2),
                (math.cos(a)*.85,math.sin(a)*.85,1.3),(math.cos(a)*.65,math.sin(a)*.65,.40)],.065,leaf)
        radial_roots(base,bark,7,.72,.6);height=2.3
    elif form in ["moth","wasp"]:
        moth=form=="moth"
        blob("EnemyCore",root,(0,0,1.15),(.18,.31,.22) if moth else (.14,.27,.16),coremat)
        blob("Host abdomen",base,(0,.37,1.1),(.22,.34,.22) if moth else (.13,.27,.15),bark)
        blob("Host head",base,(0,-.30,1.24),(.15,.14,.15),bone)
        for s in [-1,1]:
            vine("Antenna",base,[(s*.07,-.35,1.33),(s*.18,-.48,1.6),(s*.23,-.55,1.58)],.025,wood)
        for i,s in enumerate([-1,1]):
            p=empty("Root"+str(i),root,(s*.12,0,1.2))
            blob("Petal wing",p,(s*.40,.03,.04),(.45,.29,.07) if moth else (.42,.15,.025),purple if moth else bone)
            blob("Lower wing",p,(s*.29,.33,-.07),(.31,.23,.06) if moth else (.29,.10,.022),leaf)
            vine("Wing vein",p,[(0,0,0),(s*.35,.02,.10),(s*.76,.02,.04)],.025,wood)
        for i in range(3):
            a=i*math.tau/3
            if moth:petal("Carrion blossom",base,a,1.36,.55,.19,purple,.36,True)
            else:vine("Hanging sting",base,[(0,.45,1.1),(math.cos(a)*.16,.62,.85),(0,.8,.80)],.045,bark)
        height=1.75
    elif form=="brute":
        blob("EnemyCore",root,(0,0,1.15),(.58,.44,.65),coremat)
        blob("Buried stone",base,(0,.1,1.25),(.67,.45,.61),bark)
        blob("Empty head",base,(0,-.08,2.00),(.28,.26,.30),bone)
        for i,s in enumerate([-1,1]):
            p=empty("Root"+str(i),root,(s*.29,0,.62))
            vine("Trunk leg",p,[(0,0,0),(s*.08,-.03,-.30),(s*.08,-.12,-.60)],.23,bark)
            arm=empty("Root"+str(i+2),root,(s*.52,0,1.6))
            vine("Massive arm",arm,[(0,0,0),(s*.19,-.07,-.44),(s*.05,-.3,-.96)],.25,wood)
        for i in range(5):
            a=i*math.tau/5
            blob("Grave bud",base,(math.cos(a)*.48,math.sin(a)*.34,1.8),(.16,.15,.24),leaf)
        height=2.4
    elif form=="brood":
        blob("EnemyCore",root,(0,0,.48),(.46,.79,.37),coremat)
        for i in range(6):
            blob("Slug mantle",base,(0,.64-i*.23,.40),(.42-abs(i-2.5)*.045,.21,.32),fungus)
        for s in [-1,1]:
            vine("Sensory stalk",base,[(s*.17,-.6,.55),(s*.26,-.78,1.0),(s*.3,-.85,1.18)],.055,bark)
            blob("Stalk eye",base,(s*.3,-.85,1.18),(.08,)*3,glow)
        for i in range(5):
            a=i*math.tau/5
            blob("Brood pod",base,(math.cos(a)*.28,math.sin(a)*.55,.77),(.17,.20,.22),leaf)
        for i,s in enumerate([-1,1]):
            p=empty("Root"+str(i),root,(s*.32,0,.3))
            vine("Feelers",p,[(0,0,0),(s*.28,-.4,.05),(s*.24,-.7,-.16)],.055,wood)
        height=1.3
    elif form=="shepherd":
        blob("EnemyCore",root,(0,.03,1.15),(.22,.19,.57),wood)
        vine("Bowed spine",base,[(0,.05,.35),(0,.10,1.25),(0,-.18,1.91),(.02,-.36,2.05)],.17,bark)
        blob("Veiled crown",base,(0,-.28,1.97),(.19,.14,.24),wood,3)
        blob("Hollow face",base,(0,-.415,1.98),(.11,.024,.15),bark,3)
        for side in [-1,1]:blob("Narrow watchful eye",base,(side*.046,-.44,2.01),(.025,.011,.007),glow,2)
        for strand in range(9):
            a=strand*math.tau/9
            vine("Hanging mycelium",base,[(math.cos(a)*.2,math.sin(a)*.2,1.4),(math.cos(a)*.26,math.sin(a)*.26,1.05),(math.cos(a+.3)*.21,math.sin(a+.3)*.21,.75-strand%3*.08)],.018,wood)
        for side in [-1,1]:
            vine("Branch antler",base,[(side*.1,-.2,2.06),(side*.33,-.16,2.38),(side*.5,-.1,2.56)],.06,wood)
            vine("Antler fork",base,[(side*.29,-.15,2.33),(side*.44,-.31,2.42),(side*.46,-.41,2.52)],.032,bone)
        for i,side in enumerate([-1,1]):
            joint=empty("Root"+str(i),root,(side*.12,0,.7))
            vine("Trailing root leg",joint,[(0,0,0),(side*.09,.04,-.32),(side*.15,-.19,-.66)],.09,bark)
        vine("Crook arm",base,[(-.17,0,1.46),(-.48,-.13,1.2),(-.59,-.28,1.5)],.065,wood)
        vine("Shepherd crook",base,[(-.6,-.27,.07),(-.61,-.27,1.5),(-.60,-.27,2.32),(-.43,-.27,2.52),(-.29,-.27,2.37)],.045,bark)
        for i in range(7):petal("Hanging leaf mantle",base,i*math.tau/7,1.55,.85,.16,leaf,.31)
        height=2.5
    elif form=="grazer":
        blob("EnemyCore",root,(0,0,.84),(.48,.75,.44),wood,3)
        blob("Drooping head",base,(0,-.77,.64),(.27,.34,.28),bone,3)
        blob("Root muzzle",base,(0,-1.0,.5),(.19,.24,.15),bark)
        for side in [-1,1]:
            blob("Buried fungal eye",base,(side*.185,-.97,.72),(.035,.022,.011),glow)
            for j in range(5):vine("Hanging shelter gill",base,[(side*.43,-.4+j*.2,1.16),(side*.48,-.39+j*.2,.91),(side*.44,-.36+j*.2,.63)],.018,fungus)
        for i,(x,y) in enumerate([(-.32,-.43),(.32,-.43),(-.34,.46),(.34,.46)]):
            leg=empty("Root"+str(i),root,(x,y,.64))
            vine("Hoof root",leg,[(0,0,0),(x*.12,.05,-.28),(x*.2,-.09,-.60)],.115,bark)
        for i in range(7):
            angle=i*2.39996;x=math.cos(angle)*.35;y=math.sin(angle)*.50
            vine("Back shelf stalk",base,[(x,y,1.0),(x,y,1.16),(x+.04,y,1.31)],.08,wood)
            blob("Broad fungal shelf",base,(x,y,1.29),(.31,.28,.075),leaf,3)
            blob("Shelter gill light",base,(x,y,1.23),(.23,.20,.035),glow)
        for side in [-1,1]:vine("Infested horn",base,[(side*.15,-.7,.82),(side*.36,-.81,1.05),(side*.40,-.97,1.18)],.06,wood)
        height=1.5
    elif form=="lure":
        radial_roots(base,bark,6,.66,.42)
        blob("EnemyCore",root,(0,0,.62),(.24,.23,.35),wood)
        vine("Arched lantern stem",base,[(0,0,.15),(.12,.08,1.12),(.08,-.10,2.12),(-.08,-.53,2.18),(-.12,-.63,1.80)],.12,bark)
        blob("Lure bladder",base,(-.12,-.63,1.58),(.21,.21,.30),glow,3)
        for i in range(7):
            a=i*math.tau/7
            vine("Lantern cage rib",base,[(-.12,-.63,1.88),(-.12+math.cos(a)*.28,-.63+math.sin(a)*.28,1.60),(-.12+math.cos(a)*.13,-.63+math.sin(a)*.13,1.23)],.035,wood)
            petal("Downturned sepal",base,a,1.1,.56,.14,leaf,.42)
        for i in range(3):
            a=i*math.tau/3
            joint=empty("Root"+str(i),root,(math.cos(a)*.15,math.sin(a)*.15,.32))
            vine("Seeking root",joint,[(0,0,0),(math.cos(a)*.36,math.sin(a)*.36,-.15),(math.cos(a)*.6,math.sin(a)*.6,-.28)],.065,bark)
        height=2.3
    # Each form exposes the same modular morphology sockets.
    g1=empty("Growth1",root);g2=empty("Growth2",root)
    for i in range(4):
        a=i*math.tau/4
        petal("Older leaf",g1,a,height*.55,.35,.10,leaf,.40)
        vine("Crown growth",g2,[(math.cos(a)*.13,math.sin(a)*.13,height*.78),
            (math.cos(a)*.33,math.sin(a)*.33,height+0.1),
            (math.cos(a)*.37,math.sin(a)*.37,height+.35)],.055,wood)
    reach=empty("AdaptReach",root)
    for s in [-1,1]:
        vine("Extended strike tendril",reach,[(s*.2,-.1,height*.55),(s*.55,-.45,height*.5),
            (s*.42,-1.0,height*.42),(s*.30,-1.25,height*.5)],.065,wood)
    armor=empty("AdaptBark",root)
    for i in range(6):
        a=i*math.tau/6
        blob("Layered bark plate",armor,(math.cos(a)*.29,math.sin(a)*.28,height*.5),(.17,.11,.27),bark)
    spores=empty("AdaptSpore",root)
    for i in range(4):
        a=i*math.tau/4
        blob("Enlarged spore sac",spores,(math.cos(a)*.32,math.sin(a)*.32,height*.72),(.12,.12,.17),glow)
    mobility=empty("AdaptMobility",root)
    for s in [-1,1]:
        petal("Mobility frill",mobility,0 if s==1 else math.pi,height*.6,.65,.15,bone,.65,True)
        vine("Vaulting root",mobility,[(s*.2,.2,height*.35),(s*.55,.45,.2),(s*.65,.55,.025)],.09,wood)
    # Proportion variants keep the same rig and morphology sockets.
    proportions=Vector(spec.get("proportions",[1.0,1.0,1.0]))
    for obj in root.children_recursive:
        obj.location=Vector((obj.location.x*proportions.x,obj.location.y*proportions.y,obj.location.z*proportions.z))
        if obj.type in {"MESH","CURVE"}:
            obj.scale=Vector((obj.scale.x*proportions.x,obj.scale.y*proportions.y,obj.scale.z*proportions.z))
        if obj.type=="CURVE":
            obj.data.bevel_depth*=float(spec.get("root_thickness",1.0))
    return root

def bake_export(root, output):
    # Keep rig/socket nodes; combine static pieces under each socket for fewer draw calls.
    for group in list(root.children):
        if group.type!="EMPTY":continue
        pieces=[o for o in group.children_recursive if o.type in {"MESH","CURVE"}]
        if not pieces:continue
        bpy.ops.object.select_all(action="DESELECT")
        for o in pieces:o.select_set(True)
        bpy.context.view_layer.objects.active=pieces[0]
        bpy.ops.object.convert(target="MESH")
        pieces=[o for o in group.children_recursive if o.type=="MESH"]
        bpy.context.view_layer.objects.active=pieces[0]
        bpy.ops.object.join()
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(filepath=str(output),export_format="GLB",use_selection=True)
