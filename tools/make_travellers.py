"""Authoritative clothed traveller meshes, shared rig, morphs and animation clips."""
from pathlib import Path
from math import sin, cos, pi, exp, atan2
import json
import bpy
from mathutils import Vector

P=Path(__file__).resolve().parents[1]
OUT=P/'assets/characters'; OUT.mkdir(exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.scene.render.fps=30
bpy.context.preferences.filepaths.save_version=0
MORPHS=['Build','Shoulders','FaceWidth','Jaw','Nose','Eyes']

def mat(name,c):
    m=bpy.data.materials.new(name);m.use_nodes=True;m.diffuse_color=(*c,1)
    s=m.node_tree.nodes.get('Principled BSDF');s.inputs['Base Color'].default_value=(*c,1);s.inputs['Roughness'].default_value=.78
    if name=='Skin': s.inputs['Subsurface Weight'].default_value=.06
    return m
M={k:mat(k,v) for k,v in {'Skin':(.51,.31,.18),'Lips':(.25,.105,.072),'Tunic':(.12,.17,.08),'Trousers':(.055,.067,.04),'Cloak':(.075,.09,.065),'Leather':(.075,.038,.016),'Trim':(.26,.25,.09),'Hair':(.075,.032,.013),'HairDetail':(.105,.05,.02),'EyeWhite':(.6,.57,.47),'Iris':(.15,.21,.12),'Pupil':(.008,.011,.008)}.items()}

def rig():
    data=bpy.data.armatures.new('TravellerSkeleton');obj=bpy.data.objects.new('TravellerRig',data);bpy.context.collection.objects.link(obj)
    bpy.context.view_layer.objects.active=obj;obj.select_set(True);bpy.ops.object.mode_set(mode='EDIT')
    spec=[('root',(0,0,0),(0,0,.12),None),('pelvis',(0,0,.89),(0,0,1.02),'root'),('spine',(0,0,1.02),(0,0,1.20),'pelvis'),('chest',(0,0,1.20),(0,0,1.39),'spine'),('neck',(0,0,1.39),(0,0,1.49),'chest'),('head',(0,0,1.49),(0,0,1.75),'neck'),('cape',(0,.10,1.34),(0,.17,.77),'chest')]
    for side,sg in [('L',1),('R',-1)]:
        spec += [(f'clavicle.{side}',(0,0,1.35),(sg*.205,0,1.35),'chest'),(f'upper_arm.{side}',(sg*.205,0,1.35),(sg*.32,0,1.10),f'clavicle.{side}'),(f'forearm.{side}',(sg*.32,0,1.10),(sg*.37,-.005,.88),f'upper_arm.{side}'),(f'hand.{side}',(sg*.37,-.005,.88),(sg*.385,-.012,.79),f'forearm.{side}'),(f'fingers.{side}',(sg*.385,-.012,.81),(sg*.385,-.045,.765),f'hand.{side}'),(f'thumb.{side}',(sg*.36,-.01,.845),(sg*.345,-.045,.805),f'hand.{side}'),(f'thigh.{side}',(sg*.095,0,.90),(sg*.105,0,.48),'pelvis'),(f'shin.{side}',(sg*.105,0,.48),(sg*.105,0,.13),f'thigh.{side}'),(f'foot.{side}',(sg*.105,0,.13),(sg*.105,-.13,.065),f'shin.{side}')]
    for name,a,b,parent in spec:
        bone=data.edit_bones.new(name);bone.head=a;bone.tail=b
        if parent: bone.parent=data.edit_bones[parent]
    bpy.ops.object.mode_set(mode='OBJECT');obj.select_set(False)
    return obj,spec

def mesh(name,verts,faces,material,bones,arm):
    data=bpy.data.meshes.new(name);data.from_pydata(verts,[],faces);data.materials.append(M[material]);data.update()
    uv=data.uv_layers.new(name='SurfaceUV')
    for polygon in data.polygons:
        coords=[]
        for loop in polygon.loop_indices:
            co=data.vertices[data.loops[loop].vertex_index].co
            coords.append((loop,atan2(co.y,co.x)/(2*pi)+.5,co.z/1.8))
        seam=max(v[1] for v in coords)-min(v[1] for v in coords)>.5
        for loop,u,v in coords: uv.data[loop].uv=(u+1 if seam and u<.5 else u,v)
    obj=bpy.data.objects.new(name,data);bpy.context.collection.objects.link(obj);obj.parent=arm
    for face in data.polygons: face.use_smooth=True
    for bone in bones: obj.vertex_groups.new(name=bone)
    # Anatomical regions keep cloth continuous across joints. Inverse-distance
    # weighting across unrelated torso/limb bones produced pinched shoulders.
    def ease(a,b,z):
        t=max(0,min(1,(z-a)/(b-a)));return t*t*(3-2*t)
    for vertex in data.vertices:
        z=vertex.co.z
        if len(bones)==1:weights={bones[0]:1.0}
        elif name=='ContinuousTunic':
            chest=ease(1.10,1.27,z);pelvis=1-ease(.96,1.10,z)
            upper=ease(1.06,1.28,z);outer=ease(.235,.285,abs(vertex.co.x))
            mix=ease(.17,.245,abs(vertex.co.x))*(upper+(1-upper)*outer)
            side='L' if vertex.co.x>0 else 'R';fore=1-ease(1.055,1.15,z)
            weights={'pelvis':pelvis*(1-mix),'spine':max(0,1-pelvis-chest)*(1-mix),'chest':chest*(1-mix),'upper_arm.'+side:mix*(1-fore),'forearm.'+side:mix*fore}
        elif bones==['pelvis','spine','chest']:
            chest=ease(1.10,1.27,z);pelvis=1-ease(.96,1.10,z);weights={'pelvis':pelvis,'chest':chest,'spine':max(0,1-pelvis-chest)}
        elif 'cape' in bones:
            cape=1-ease(1.16,1.38,z);weights={'cape':cape,'chest':1-cape}
        elif any(n.startswith('upper_arm.') for n in bones):
            side=next(n.split('.')[1] for n in bones if n.startswith('upper_arm.'))
            fore=1-ease(1.055,1.15,z) if 'forearm.'+side in bones else 0
            chest=ease(1.33,1.40,z) if 'chest' in bones else 0
            weights={'upper_arm.'+side:max(0,1-fore-chest)}
            if 'forearm.'+side in bones:weights['forearm.'+side]=fore
            if 'chest' in bones:weights['chest']=chest
        elif any(n.startswith('thigh.') for n in bones):
            side=next(n.split('.')[1] for n in bones if n.startswith('thigh.'))
            shin=1-ease(.43,.54,z) if 'shin.'+side in bones else 0
            pelvis=ease(.84,.94,z) if 'pelvis' in bones else 0
            weights={'thigh.'+side:max(0,1-shin-pelvis)}
            if 'shin.'+side in bones:weights['shin.'+side]=shin
            if 'pelvis' in bones:weights['pelvis']=pelvis
        elif any(n.startswith('foot.') for n in bones):
            side=next(n.split('.')[1] for n in bones if n.startswith('foot.'))
            shin=ease(.15,.24,z);weights={'shin.'+side:shin,'foot.'+side:1-shin}
        else:
            distances=[]
            for bone in bones:
                joint=arm.data.bones[bone];line=joint.tail_local-joint.head_local
                t=max(0,min(1,(vertex.co-joint.head_local).dot(line)/max(1e-8,line.length_squared)))
                distances.append((1/max(.02,(vertex.co-joint.head_local-line*t).length)**2,bone))
            total=sum(v for v,_ in distances);weights={n:v/total for v,n in distances}
        total=sum(weights.values())
        for bone,weight in weights.items():
            if weight>1e-6:obj.vertex_groups[bone].add([vertex.index],weight/total,'REPLACE')
        assert abs(sum(weights.values())/total-1)<1e-5
    mod=obj.modifiers.new('Weighted animation joints','ARMATURE');mod.object=arm
    return obj

def sphere(name,at,size,material,bones,arm,segments=20,rings=12,head=False):
    v=[];f=[]
    for i in range(rings+1):
        theta=pi*i/rings
        for j in range(segments):
            phi=2*pi*j/segments;x=sin(theta)*cos(phi);y=sin(theta)*sin(phi);z=cos(theta)
            if head:
                x*=1-.10*max(0,-z)**.7
                if y<0: y+=.06*exp(-((abs(x)-.43)/.22)**2-((z-.23)/.18)**2)
            v.append((at[0]+x*size[0],at[1]+y*size[1],at[2]+z*size[2]))
    for i in range(rings):
        for j in range(segments): a=i*segments+j;b=i*segments+(j+1)%segments;f.append((a,b,b+segments,a+segments))
    return mesh(name,v,f,material,bones,arm)

def tube(name,points,radii,material,bones,arm,sides=16,flatten=1):
    dense=[];sizes=[]
    for a,b,ra,rb in zip(points,points[1:],radii,radii[1:]):
        count=max(1,round((Vector(b)-Vector(a)).length/.035))
        for step in range(count):
            t=step/count;dense.append(Vector(a).lerp(Vector(b),t));sizes.append(ra*(1-t)+rb*t)
    points=dense+[Vector(points[-1])];radii=sizes+[radii[-1]]
    verts=[];faces=[]
    previous_right=None
    for i,p in enumerate(points):
        tangent=Vector(points[min(i+1,len(points)-1)])-Vector(points[max(i-1,0)])
        tangent.normalize()
        if previous_right is None:
            right=tangent.cross(Vector((0,1,0)))
            if right.length<.01:right=tangent.cross(Vector((1,0,0)))
        else:right=previous_right-tangent*previous_right.dot(tangent)
        right.normalize();other=right.cross(tangent).normalized();previous_right=right.copy()
        for j in range(sides):
            a=j*2*pi/sides;verts.append(Vector(p)+right*cos(a)*radii[i]+other*sin(a)*radii[i]*flatten)
    for i in range(len(points)-1):
        for j in range(sides): a=i*sides+j;b=i*sides+(j+1)%sides;faces.append((a,b,b+sides,a+sides))
    faces += [tuple(range(sides-1,-1,-1)),tuple((len(points)-1)*sides+j for j in range(sides))]
    return mesh(name,verts,faces,material,bones,arm)

def torso(name,rings,material,bones,arm):
    verts=[];faces=[];n=48
    dense=[]
    for a,b in zip(rings,rings[1:]):
        for step in range(5):
            t=step/5;dense.append(tuple(a[i]*(1-t)+b[i]*t for i in range(3)))
    rings=dense+[rings[-1]]
    for z,rx,ry in rings:
        for j in range(n):
            a=2*pi*j/n;wrinkle=1+.018*sin(a*7+z*28);verts.append((cos(a)*rx*wrinkle,sin(a)*ry*wrinkle,z))
    for i in range(len(rings)-1):
        for j in range(n): a=i*n+j;b=i*n+(j+1)%n;faces.append((a,b,b+n,a+n))
    faces+=[tuple(range(n-1,-1,-1)),tuple((len(rings)-1)*n+j for j in range(n))]
    return mesh(name,verts,faces,material,bones,arm)

def join(objects,name):
    bpy.ops.object.select_all(action='DESELECT')
    for o in objects: o.select_set(True)
    bpy.context.view_layer.objects.active=objects[0];bpy.ops.object.join();o=bpy.context.object;o.name=name;return o

def morph(obj):
    obj.shape_key_add(name='Basis',from_mix=False)
    materials={v.index:set() for v in obj.data.vertices}
    for face in obj.data.polygons:
        for index in face.vertices:materials[index].add(obj.data.materials[face.material_index].name)
    def ease(a,b,z):
        t=max(0,min(1,(z-a)/(b-a)));return t*t*(3-2*t)
    centers={}
    for vertex in obj.data.vertices:
        center=Vector((0,0,0));total=0
        # Blend the deformation field using the same smooth skin influences.
        # A dominant-bone switch made adjacent garment vertices jump apart.
        for group in vertex.groups:
            name=obj.vertex_groups[group.group].name;at=Vector((0,0,vertex.co.z))
            if name.startswith(('upper_arm.','forearm.','hand.','fingers.','thumb.','thigh.','shin.','foot.')):
                bone=obj.parent.data.bones[name];line=bone.tail_local-bone.head_local
                t=max(0,min(1,(vertex.co-bone.head_local).dot(line)/line.length_squared));at=bone.head_local+line*t
            center+=at*group.weight;total+=group.weight
        centers[vertex.index]=center/max(total,1e-8)

    for name in MORPHS:
        key=obj.shape_key_add(name=name,from_mix=False)
        for vertex_index,vertex in enumerate(key.data):
            x,y,z=obj.data.shape_keys.key_blocks["Basis"].data[vertex_index].co;v=Vector((x,y,z))
            if name=='Build' and z<1.43:
                gain=.10*max(0,min(1,(z-.12)/.7))*(1-ease(1.33,1.43,z))
                center=centers[vertex_index];v+=Vector((x-center.x,y-center.y,0))*gain
            if name=='Shoulders' and .99<z<1.46:
                gain=exp(-((z-1.31)/.13)**2)*ease(1.02,1.12,z)*(1-ease(1.38,1.46,z))
                v.x+=x*.09*gain
            if name=='FaceWidth' and z>1.46:v.x+=x*.15*ease(1.46,1.55,z)
            if name=='Jaw' and 1.46<z<1.60:v.x+=x*.15*sin(pi*(z-1.46)/.14)**2
            if name=='Nose' and z>1.46 and 'Skin' in materials[vertex_index]:
                v.y-=.015*exp(-(x/.022)**2-((z-1.608)/.035)**2)*ease(.090,.115,-y)
            if name=='Eyes' and materials[vertex_index].intersection({'EyeWhite','Iris','Pupil'}):
                center=Vector((.052 if x>0 else -.052,-.108,1.633));v=center+(v-center)*1.16
            vertex.co=v
    basis=obj.data.shape_keys.key_blocks['Basis']
    for key in obj.data.shape_keys.key_blocks:
        key.value=0
        if key.name in ['FaceWidth','Jaw','Nose','Eyes']:
            assert all((a.co-b.co).length<1e-6 for a,b in zip(key.data,basis.data) if b.co.z<1.46), f'{key.name} changed body'
        if key.name=='Nose':
            assert all(abs(a.co.x-b.co.x)<1e-6 for a,b in zip(key.data,basis.data)), 'Nose changed width'
        if key.name=='Shoulders':
            assert all((a.co-b.co).length<1e-6 for a,b in zip(key.data,basis.data) if b.co.z<.99 or b.co.z>1.60), 'Shoulders changed unrelated region'


def bust(x,y,z):
    # Paired breast volume beneath the tunic, blended into chest and ribs.
    return .061*exp(-((abs(x)-.071)/.061)**2-((z-1.265)/.072)**2)*min(1,max(0,-y/.07))

def build(female):
    arm,spec=rig();arm.name='FemaleRig' if female else 'MaleRig';parts=[]
    def sph(name,at,size,material,bones=('head',),**kw):
        o=sphere(name,at,size,material,bones,arm,**kw);parts.append(o);return o
    def line(name,pts,rads,material,bones,**kw):
        o=tube(name,pts,rads,material,bones,arm,**kw);parts.append(o);return o
    waist=.139 if female else .153;hip=.180 if female else .172;shoulder=.214 if female else .235
    tunic=torso('Linen tunic',[(.84,hip,.102),(.91,hip*.98,.101),(1.00,waist,.090),(1.10,waist*1.04,.096),(1.22,shoulder*.81,.110 if female else .106),(1.32,shoulder,.097),(1.37,shoulder*.87,.084),(1.425,.067,.064)],'Tunic',['pelvis','spine','chest'],arm)
    parts.append(tunic)
    if female:
        for vertex in tunic.data.vertices:
            x,y,z=vertex.co
            if y<0: vertex.co.y-=bust(x,y,z)
    parts.append(torso('Leather belt',[(.985,waist+.009,.103),(1.025,waist+.007,.102)],'Leather',['pelvis','spine'],arm))
    sph('Belt clasp',(0,-.107,1.004),(.023,.008,.020),'Trim',('spine',),segments=16,rings=8)
    line('Neck',[(0,0,1.36),(0,0,1.46),(0,0,1.50)],[.056,.048,.045],'Skin',['chest','neck','head'])
    sph('Human face',(0,0,1.606),(.117 if female else .124,.102,.148),'Skin',head=True,segments=32,rings=24)
    for sg in [-1,1]:
        sph('Ear',(sg*.119,.003,1.616),(.016,.020,.033),'Skin',segments=16,rings=12)
        sph('Eye white',(sg*.052,-.101,1.633),(.023,.009,.009),'EyeWhite',segments=20,rings=12)
        sph('Iris',(sg*.052,-.109,1.633),(.007,.0035,.007),'Iris',segments=16,rings=12)
        sph('Pupil',(sg*.052,-.112,1.633),(.003,.001,.004),'Pupil',segments=12,rings=8)
        line('Brow',[(sg*.026,-.105,1.653),(sg*.050,-.109,1.658),(sg*.077,-.097,1.650)],[.002,.003,.0015],'Hair',['head'],sides=8)
    sph('Nose bridge',(0,-.104,1.619),(.012,.019,.032),'Skin',segments=20,rings=16)
    sph('Nose tip',(0,-.125,1.598),(.016,.017,.012),'Skin',segments=20,rings=12)
    line('Upper lip',[(-.021,-.101,1.563),(0,-.111,1.565),(.021,-.101,1.563)],[.001,.003,.001],'Lips',['head'],sides=10)
    line('Lower lip',[(-.020,-.101,1.560),(0,-.110,1.557),(.020,-.101,1.560)],[.001,.003,.001],'Lips',['head'],sides=10)
    for side,sg in [('L',1),('R',-1)]:
        upper=f'upper_arm.{side}';lower=f'forearm.{side}';hand=f'hand.{side}';thigh=f'thigh.{side}';shin=f'shin.{side}';foot=f'foot.{side}'
        line('Sleeve',[(sg*.19,0,1.35),(sg*.255,0,1.28),(sg*.32,0,1.10),(sg*.347,-.003,1.00)],[.074,.074 if not female else .067,.056,.046],'Tunic',['chest',upper,lower],sides=20)
        line('Leather bracer',[(sg*.34,-.003,1.015),(sg*.365,-.005,.91),(sg*.37,-.005,.884)],[.047,.037,.035],'Leather',[lower],sides=20)
        sph('Hand',(sg*.38,-.006,.836),(.033,.024,.049),'Skin',(hand,),segments=20,rings=12)
        for j in range(4):
            x=sg*(.357+j*.014)
            line('Finger',[(x,-.010,.811),(x,-.025,.78),(x,-.040,.789)],[.0065,.006,.004],'Skin',[f'fingers.{side}'],sides=10)
        line('Thumb',[(sg*.352,-.005,.85),(sg*.340,-.025,.826),(sg*.347,-.043,.81)],[.01,.008,.006],'Skin',[f'thumb.{side}'],sides=12)
        line('Fitted trousers',[(sg*.095,0,.92),(sg*.102,0,.79),(sg*.105,0,.60),(sg*.105,0,.48),(sg*.105,0,.36),(sg*.105,0,.19)],[.084,.080,.066,.055,.051,.039],'Trousers',['pelvis',thigh,shin],sides=24)
        line('Boot shaft',[(sg*.105,0,.35),(sg*.105,0,.21),(sg*.105,0,.115)],[.050,.046,.047],'Leather',[shin,foot],sides=20)
        sph('Boot',(sg*.105,-.040,.064),(.058,.115,.061),'Leather',(foot,),segments=24,rings=12)
        sph('Boot sole',(sg*.105,-.042,.022),(.060,.118,.018),'Leather',(foot,),segments=24,rings=8)
        line('Trouser seam',[(sg*.160,.002,.87),(sg*.163,.002,.71),(sg*.153,.002,.51)],[.0018,.0018,.0018],'Trim',[thigh,shin],sides=6)
    # Real surface cloth with folds, weighted to a dedicated cape bone.
    verts=[];faces=[]
    for i in range(21):
        t=i/20
        for j in range(25):
            u=j/24*2-1
            verts.append((u*shoulder*(1-.24*t),.09+.14*t+.035*(1-u*u)+.011*sin(u*pi*4)*t,1.38-.63*t+.025*cos(u*pi)*t))
    for i in range(20):
        for j in range(24):a=i*25+j;faces.append((a,a+1,a+26,a+25))
    parts.append(mesh('Folded travelling cloak',verts,faces,'Cloak',['chest','cape'],arm))
    for sg in [-1,1]:
        line('Cloak stitched edge',[(sg*shoulder,.092,1.38),(sg*shoulder*.88,.16,1.05),(sg*shoulder*.76,.23,.75)],[.0025,.0025,.0025],'Trim',['chest','cape'],sides=8)
    line('Shoulder strap',[(.125,-.080,1.35),(.065,-.115,1.23),(-.02,-.105,1.10),(-.11,-.10,1.01)],[.013,.013,.013,.013],'Leather',['chest','spine'],sides=12,flatten=.3)
    if female:
        for vertex in parts[-1].data.vertices:
            x,y,z=vertex.co
            if y<0: vertex.co.y-=bust(x,y,z)
    sph('Root clasp',(.122,-.087,1.35),(.018,.006,.028),'Trim',('chest',),segments=16,rings=10)
    parts.append(torso('Folded cowl',[(1.35,.19,.105),(1.385,.145,.092),(1.415,.09,.075),(1.44,.065,.064)],'Cloak',['chest','neck'],arm))
    # Union only the cloth shell. Remeshing before morph/skin authoring keeps
    # shoulder loops continuous; accessories, hands and face retain their detail.
    cloth=[o for o in parts if o.name.startswith(('Linen tunic','Sleeve'))]
    for o in cloth:parts.remove(o)
    garment=join(cloth,'Continuous cloth source')
    for modifier in list(garment.modifiers):garment.modifiers.remove(modifier)
    remesh=garment.modifiers.new('Weld shoulder garment surface','REMESH');remesh.mode='VOXEL';remesh.voxel_size=.008;remesh.use_smooth_shade=True
    bpy.ops.object.modifier_apply(modifier=remesh.name)
    polish=garment.modifiers.new('Relax cloth topology','SMOOTH');polish.factor=.65;polish.iterations=4;bpy.ops.object.modifier_apply(modifier=polish.name)
    vertices=[v.co.copy() for v in garment.data.vertices];faces=[tuple(face.vertices) for face in garment.data.polygons]
    bpy.data.objects.remove(garment,do_unlink=True)
    parts.append(mesh('ContinuousTunic',vertices,faces,'Tunic',['pelvis','spine','chest','upper_arm.L','forearm.L','upper_arm.R','forearm.R'],arm))
    body=join(parts,'TravellerBody');morph(body)
    hairs=[]
    for style in range(3):
        group=[];v=[];f=[];segments=32;rings=14
        for i in range(rings+1):
            for j in range(segments):
                phi=2*pi*j/segments;front=max(0,-sin(phi));theta=(1.9-front*.7)*i/rings
                v.append((sin(theta)*cos(phi)*.131,sin(theta)*sin(phi)*.115,1.609+cos(theta)*.159))
        for i in range(rings):
            for j in range(segments): a=i*segments+j;b=i*segments+(j+1)%segments;f.append((a,b,b+segments,a+segments))
        group.append(mesh('Hair cap',v,f,'Hair',['head'],arm))
        for j in range(11):
            x=-.083+j*.016
            group.append(tube('Swept hair',[(x*.4,-.035,1.760),(x,-.087,1.730),(x+.018,-.113,1.677)],[.008,.011,.002],'HairDetail',['head'],arm,sides=10))
        if style==1: group.append(tube('Tied hair',[(0,.090,1.64),(0,.135,1.55),(.015,.14,1.39)],[.035,.038,.009],'Hair',['head','neck'],arm,sides=20))
        if style==2:
            for j in range(9):
                x=(j-4)*.024
                group.append(tube('Long hair',[(x*.75,.072,1.69),(x,.107,1.55),(x*1.10,.103,1.36)],[.016,.020,.003],'Hair' if j%2 else 'HairDetail',['head','neck'],arm,sides=12))
        h=join(group,f'AdventurerHair{style}');morph(h);hairs.append(h)
    return arm,[body]+hairs,spec

def actions(arm):
    result=[]
    for name,length in [('Idle',60),('Walk',30),('Run',24),('Attack',24),('Cast',36),('Guard',36)]:
        action=bpy.data.actions.new(name);action.use_fake_user=True;arm.animation_data_create();arm.animation_data.action=action
        for b in arm.pose.bones: b.rotation_mode='XYZ'
        for frame in range(1,length+2):
            t=(frame-1)/length;phase=t*2*pi;pulse=sin(t*pi)
            for b in arm.pose.bones: b.rotation_mode="XYZ";b.rotation_euler=(0,0,0)
            if name=='Idle':
                arm.pose.bones['chest'].rotation_euler.x=.025*sin(phase);arm.pose.bones['head'].rotation_euler.z=.018*sin(phase)
                for side,sg in [('L',1),('R',-1)]:
                    arm.pose.bones[f'upper_arm.{side}'].rotation_euler.x=.025*sin(phase+sg*.5)
                    arm.pose.bones[f'forearm.{side}'].rotation_euler.x=-.08+.025*sin(phase)
                arm.pose.bones['cape'].rotation_euler.x=.018*sin(phase+.4)
            if name in ['Walk','Run']:
                stride=1.35 if name=='Run' else 1.0
                for side,sg in [('L',1),('R',-1)]:
                    swing=sin(phase)*sg
                    arm.pose.bones[f'thigh.{side}'].rotation_euler.x=.55*swing*stride
                    arm.pose.bones[f'shin.{side}'].rotation_euler.x=max(0,-swing)**2*.95*stride
                    arm.pose.bones[f'foot.{side}'].rotation_euler.x=-.15*swing
                    arm.pose.bones[f'upper_arm.{side}'].rotation_euler.x=-.32*swing*stride
                    arm.pose.bones[f'forearm.{side}'].rotation_euler.x=-.12
                arm.pose.bones['pelvis'].rotation_euler.z=.025*sin(phase);arm.pose.bones['chest'].rotation_euler.z=-.022*sin(phase);arm.pose.bones['chest'].rotation_euler.x=.025 if name=='Run' else .008;arm.pose.bones['cape'].rotation_euler.x=.06*sin(phase+.5)
            if name in ['Attack','Cast','Guard']:
                arm.pose.bones['chest'].rotation_euler.z=(.20 if name=='Attack' else -.04)*pulse
                for side,factor in [('R',1.0),('L',.35 if name=='Attack' else 1.0)]:
                    arm.pose.bones[f'upper_arm.{side}'].rotation_euler.x=-.85*pulse*factor
                    arm.pose.bones[f'forearm.{side}'].rotation_euler.x=-.65*pulse*factor
            bpy.context.view_layer.update()
            for side,sg in [('L',1),('R',-1)]:
                if name in ['Idle','Walk','Run']:
                    swing=sin(phase)*sg if name!='Idle' else .04*sin(phase)
                    palm=(sg*.245,.12*swing,.865+.015*abs(swing))
                else:palm=(sg*.17,-.16-.17*pulse,1.08+.15*pulse)
                arm_ik(arm,side,palm,(sg*.30,.11,1.01))
                if name=='Idle':
                    arm.pose.bones['fingers.'+side].rotation_euler.x=.12
                    arm.pose.bones['thumb.'+side].rotation_euler.x=.10
            for b in arm.pose.bones: b.keyframe_insert(data_path='rotation_euler',frame=frame)
        result.append(action)
    arm.animation_data.action=result[0]
    return result

import sys
sys.path.insert(0,str(P/'tools'))
from weapon_animation_template import author, arm_ik
WEAPON_PROFILES=json.loads((P/'assets/characters/weapon_actions.json').read_text(encoding='utf-8'))
male,mm,spec=build(False);clips=actions(male)
clips+=author(male,WEAPON_PROFILES)
female,fm,_=build(True);female.animation_data_create();female.animation_data.action=clips[0]
for arm in [male,female]:
    arm.animation_data.action=None
    for b in arm.pose.bones: b.rotation_mode="XYZ";b.rotation_euler=(0,0,0)
bpy.context.scene.frame_set(1)
bpy.ops.wm.save_as_mainfile(filepath=str(P/'assets/source/travellers.blend'))
for arm,objects,name in [(male,mm,'traveller_male'),(female,fm,'traveller_female')]:
    bpy.ops.object.select_all(action='DESELECT');arm.select_set(True)
    for o in objects: o.select_set(True)
    bpy.context.view_layer.objects.active=arm
    bpy.ops.export_scene.gltf(filepath=str(OUT/(name+'.glb')),export_format='GLB',use_selection=True,export_skins=True,export_morph=True,export_morph_animation=False,export_animations=True,export_animation_mode='ACTIONS',export_anim_single_armature=True,export_force_sampling=True,export_apply=False,export_extras=True)
(OUT/'rig_manifest.json').write_text(json.dumps({'version':3,'weapon_profiles':WEAPON_PROFILES,'bones':[r[0] for r in spec],'morphs':MORPHS,'animations':['Idle','Walk','Run','Attack','Cast','Guard']+[v[k] for v in WEAPON_PROFILES.values() for k in ['clip','ready']]+[clip for v in WEAPON_PROFILES.values() for clip in v.get('variants',{}).values()],'models':['traveller_male','traveller_female'],'cosmetic_height_range':[.92,1.08],'skin_policy':'anatomical normalized joint weights','grip':'palm sockets','authoring_fps':30},indent=2),encoding='utf-8')
print('TRAVELLER EXPORT COMPLETE',[(o.name,len(o.data.vertices)) for o in mm+fm])
