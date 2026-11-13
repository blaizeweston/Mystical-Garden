"""Adapt the CC0 weapon donors. Run in Blender with -- <donor directory>."""
from math import cos, sin, pi, tau
from pathlib import Path
import sys

import bpy
from mathutils import Vector

sys.path.insert(0, str(Path(__file__).resolve().parent))
from make_plant_weapons import ROOT, WeaponMesh, material, branch, winding_root


def library(path, names):
    with bpy.data.libraries.load(str(path), link=False) as (source, target):
        missing = set(names) - set(source.objects)
        if missing:
            raise ValueError(f"Missing donor objects in {path}: {missing}")
        target.objects = list(names)
    for obj in target.objects:
        bpy.context.collection.objects.link(obj)
    bpy.context.view_layer.update()
    return target.objects


def glb(folder, name):
    before = set(bpy.context.scene.objects)
    bpy.ops.import_scene.gltf(filepath=str(folder / f"donor-{name}.glb"))
    return [obj for obj in bpy.context.scene.objects if obj not in before and obj.type == "MESH"]


def append_donor(mesh, obj, transform, surface, keep=None, local=False):
    """Copy donor geometry in Godot grip coordinates, preserving its UV layout."""
    data = obj.data
    points = [v.co.copy() if local else obj.matrix_world @ v.co for v in data.vertices]
    indices = {}
    uv = data.uv_layers.active
    count = 0
    for polygon in data.polygons:
        face = [points[i] for i in polygon.vertices]
        if keep is not None and not keep(face):
            continue
        for i in polygon.vertices:
            if i not in indices:
                indices[i] = len(mesh.points)
                x, y, z = transform(points[i])
                mesh.points.append((x, -z, y))
        mesh.faces.append(tuple(indices[i] for i in polygon.vertices))
        mesh.style.append(surface(face) if callable(surface) else surface)
        mesh.uvs.append([tuple(uv.data[i].uv) if uv else (0, 0) for i in polygon.loop_indices])
        count += 1
    if not count:
        raise ValueError(f"No donor faces retained for {obj.name}")


def leaf(mesh, centers, widths, side, color, ridge=.018):
    """A tapered leaf with a raised midrib and thin, beveled edges."""
    cross = Vector(side).normalized()
    rings = []
    for at, width in zip(map(Vector, centers), widths):
        normal = cross.cross(Vector(centers[-1]) - Vector(centers[0])).normalized()
        rings.append([at-cross*width, at-cross*width*.52+normal*ridge,
                      at+normal*ridge*1.4, at+cross*width*.52+normal*ridge,
                      at+cross*width, at-normal*ridge*.23])
    mesh.surface(rings, 6, color, color)
    vein = [Vector(center)+normal*ridge*1.43 for center in centers]
    mesh.tube(vein, [.004]*(len(vein)-1)+[.001], "vein", 6)


def husk(mesh, center, radius, bands, color, ribs=14):
    x, y, z = center
    rings = [[Vector((x+radius*width*cos(tau*i/ribs),
                     y+height, z+radius*width*sin(tau*i/ribs))) for i in range(ribs)]
             for height, width in bands]
    mesh.surface(rings, ribs, color, color(0, 0) if callable(color) else color)


def arbalest(source, palette):
    mesh = WeaponMesh("BarkArbalest", palette)

    def transform(v):
        return (v.x*.556, .2+(v.z+.018)*.65, (-v.y-.15)*.60)

    def keep(face):
        # Remove the baked string across the limbs. Godot drives both moving halves.
        return not (max(v.x for v in face)-min(v.x for v in face)>.55
                    and all(-.81 < v.y < -.77 for v in face))

    def surface(face):
        return "bark" if max(abs(v.x) for v in face)<.13 else "vine"

    append_donor(mesh, source, transform, surface, keep, local=True)
    for sign in [-1,1]:
        limb = [(0,.20,.585),(.193*sign,.22,.594),(.347*sign,.23,.530),(.47*sign,.215,.405)]
        mesh.tube(limb,[.021,.028,.022,.009],"briar",10,.85)
        mesh.tube([(x,y+.026,z-.016) for x,y,z in limb],[.008,.011,.009,.003],"vein",7)
        for x,z in [( .15,.59),(.26,.56),(.40,.48)]:
            x *= sign
            mesh.tube([(x,.203,z),(x+.044*sign,.23,z+.055),(x+.053*sign,.24,z+.069)],
                      [.016,.010,.001],"edge",7)
    wrap = [(cos(tau*i/22)*.045,.2+sin(tau*i/22)*.045,-.19+.48*i/49) for i in range(50)]
    mesh.tube(wrap,[.011]*len(wrap),"vine",8)
    mesh.export("bark_arbalest.glb")


def knives(source, palette):
    mesh = WeaponMesh("GraftKnife", palette)

    def transform(v):
        y=(.048-v.y)*.62
        return (v.x*.70+.069*max(0,(y-.15)/.44)**2,y,v.z*.80)

    def surface(face):
        y=sum(v.y for v in face)/len(face)
        return "edge" if y<-.17 and max(abs(v.z) for v in face)<.015 else "leaf" if y<-.17 else "briar" if y<-.085 else "bark"

    append_donor(mesh,source,transform,surface,local=True)
    winding_root(mesh,-.105,.102,.026,.008,3.5,"vine")
    mesh.tube([(0,.12,.032),(.008,.29,.030),(.039,.48,.018),(.062,.57,.004)],
              [.013,.011,.006,.001],"vein",8)
    mesh.tube([(-.045,.13,.018),(-.069,.17,.031),(-.081,.22,.02)],
              [.017,.012,.001],"briar",8)
    mesh.export("graft_knives.glb")


def wand(source, palette):
    mesh = WeaponMesh("ThornWand", palette)
    append_donor(mesh,source,lambda v:(v.x*.96+.034*max(0,-v.y),(.056-v.y)*.56,v.z),
                 "bark",local=True)
    winding_root(mesh,-.09,.49,.022,.009,4.7,"vine")
    for side in [-1,1]:
        mesh.tube([(.024,.34,0),(.038+side*.055,.46,.015*side),
                   (.039+side*.049,.57,.02),(.037+side*.021,.62,.022)],
                  [.018,.015,.009,.001],"briar",9)
    leaf(mesh,[(.02,.31,0),(-.033,.39,.012),(-.064,.48,.018)],
         [.003,.032,.001],(1,0,0),"leaf",.008)
    mesh.export("thorn_wand.glb")


def staff(folder, palette):
    mesh = WeaponMesh("SporeStaff", palette)
    [source] = glb(folder,"staff")
    # Use the main spiral and shaft. Replace the decorative head with fungi.
    append_donor(mesh,source,lambda v:(v.y*1.09,(v.x+.025)*1.06,(v.z-.022)*1.25),
                 "bark",lambda face: not all(v.x>.61 and v.z>.044 for v in face))
    winding_root(mesh,-.53,.49,.031,.012,6.2,"vine",.5)
    for x,y,z,r in [(-.037,.72,.040,.074),(.047,.76,.016,.060),(.010,.82,.028,.048),(.06,.68,.048,.038)]:
        mesh.tube([(x*.5,y-.10,z*.35),(x*.82,y-.037,z*.78),(x,y,z)],
                  [.014,.011,.008],"gill",9)
        husk(mesh,(x,y,z),r,[(-.013,.10),(-.006,1.0),(.015,.86),(.041,.40),(.047,.04)],
             lambda i,_j: "gill" if i==0 else "spore",16)
    leaf(mesh,[(.01,.42,.02),(.095,.47,.04),(.153,.51,.055)],
         [.002,.038,.001],(0,1,0),"leaf",.009)
    mesh.export("spore_staff.glb")


def ring(folder, palette):
    mesh = WeaponMesh("ThornRing", palette)
    [rim] = library(folder/"donor-ring.blend",["Blades"])
    append_donor(mesh,rim,lambda v:(v.x*.272,.282+v.y*.272,v.z*.7),"briar")
    for twist in [0,pi]:
        points = []
        for i in range(101):
            a = i*tau/100
            radius = .278+cos(a*6+twist)*.014
            points.append((cos(a)*radius,.282+sin(a)*radius,.022*sin(a*6+twist)))
        mesh.tube(points,[.023]*len(points),"vine" if twist else "bark",10)
    for i in range(7):
        a=.19+i*tau/7
        x,y=cos(a),sin(a)
        if y<-.72:
            continue
        mesh.tube([(x*.263,.282+y*.263,0),(x*.322-y*.035,.282+y*.322+x*.035,.03),
                   (x*.357-y*.07,.282+y*.357+x*.07,.035)],
                  [.031,.019,.001],"edge",8)
    mesh.export("thorn_ring.glb")


def focus(folder, palette):
    mesh = WeaponMesh("SeedFocus", palette)
    [source] = glb(folder,"poppy")
    append_donor(mesh,source,lambda v:((v.x+.016)*8,.445+(v.z-.517)*6,(-v.y+.067)*8),
                 "vein",lambda face: all(-.03<v.x<-.003 and .051<v.y<.082 and v.z>.515 for v in face))
    husk(mesh,(0,.30,0),.174,[(-.17,.10),(-.13,.52),(-.071,.92),(.015,1.0),
                              (.095,.82),(.148,.49),(.16,.12)],"pod",22)
    for i in range(5):
        a=i*tau/5
        radial=Vector((cos(a),0,sin(a)))
        centers = [Vector((0,y,0))+radial*r for y,r in [(.13,.036),(.20,.12),(.28,.17),(.37,.16),(.47,.056)]]
        leaf(mesh,centers,[.003,.043,.057,.044,.001],(-sin(a),0,cos(a)),"leaf",.012)
    mesh.export("seed_focus.glb")


def bell(folder, palette):
    mesh = WeaponMesh("BloomBell", palette)
    [source] = glb(folder,"bell")
    append_donor(mesh,source,lambda v:(v.x*3.35,v.z*3.35,-v.y*3.35),
                 lambda face: "bark" if min(v.z for v in face)>.097 else "bronze")
    winding_root(mesh,.34,.65,.044,.009,3.1,"vine")
    for i in range(7):
        a=i*tau/7
        radial=Vector((cos(a),0,sin(a)))
        centers=[Vector((0,y,0))+radial*r for y,r in [(.305,.049),(.23,.099),(.14,.148),(.045,.18),(.014,.206)]]
        leaf(mesh,centers,[.003,.036,.063,.074,.002],(-sin(a),0,cos(a)),"petal",.012)
    mesh.export("bloom_bell.glb")


def censer(folder, palette):
    mesh = WeaponMesh("SporeCenser", palette)
    for obj in glb(folder,"censer"):
        append_donor(mesh,obj,lambda v:(v.x*1.8,v.z*1.8,-v.y*1.8),
                     "bronze" if obj.name.endswith("_0") else "spore")
    for i in range(5):
        a=i*tau/5
        radial=Vector((cos(a),0,sin(a)))
        centers=[Vector((0,y,0))+radial*r for y,r in [(.036,.066),(.069,.14),(.135,.165),(.18,.155)]]
        leaf(mesh,centers,[.003,.039,.042,.001],(-sin(a),0,cos(a)),"pod",.012)
    for index in range(3):
        a = (index+.35)*tau/3
        radial = Vector((cos(a),0,sin(a)))
        tangent = Vector((-sin(a),0,cos(a)))
        points = [Vector((0,y,0))+radial*r+tangent*curve for y,r,curve in
                  [(.20,.115,0),(.32,.131,.021),(.45,.094,-.013),(.59,.068,.012),(.72,.035,0)]]
        mesh.tube(points,[.016,.016,.013,.011,.009],"vine",9)
    winding_root(mesh,.64,.77,.038,.009,1.7,"briar")
    mesh.export("spore_censer.glb")


def fan(folder, palette):
    mesh = WeaponMesh("PetalFan", palette)
    [source] = glb(folder,"fan")
    append_donor(mesh,source,lambda v:(v.x*1.7,(v.y+.118)*2.1,v.z*2.2),
                 "briar",lambda face: min(v.z for v in face)<.0031)
    for i in range(9):
        a=(i-4)*.255
        x,y=sin(a),cos(a)
        length=.63+.07*y
        centers=[(x*r,y*r,z) for r,z in [(.06,.01),(.20,.025),(.38,.055),(.54,.065),(length,.031)]]
        leaf(mesh,centers,[.002,.035,.077,.083,.002],(y,-x,0),
             "petal" if i%2==0 else "petal_light",.012)
    mesh.export("petal_fan.glb")


def lash(palette):
    mesh = WeaponMesh("RootLashGrip",palette)
    branch(mesh,-.21,.16,.042,.021)
    winding_root(mesh,-.18,.15,.046,.010,4,"vine")
    mesh.export("root_lash.glb")
    mesh = WeaponMesh("RootLashSegment",palette)
    mesh.tube([(0,-.52,0),(.003,0,-.002),(0,.52,0)],[.018,.017,.017],"bark",8)
    for offset in [0,pi]:
        points = [(cos(offset+i*tau/8)*.011, -.52+1.04*i/8,
                   sin(offset+i*tau/8)*.011) for i in range(9)]
        mesh.tube(points,[.009]*len(points),"vine" if offset else "vein",6)
    mesh.tube([(.011,.24,0),(.025,.32,.009),(.034,.44,.014)],
              [.008,.006,.001],"edge",6)
    mesh.export("root_lash_segment.glb")


def main(folder):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    palette = {
        "bark": material("Weathered bark",(.29,.18,.08),.92,ROOT/"assets/garden/field/bark.jpg"),
        "briar": material("Dark briar",(.13,.072,.031),.87),
        "vine": material("Dried vine",(.17,.25,.074),.83),
        "leaf": material("Hardened leaf",(.09,.23,.107),.72),
        "edge": material("Pale thorn",(.47,.58,.28),.67),
        "vein": material("Leaf veins",(.45,.47,.23),.77),
        "spore": material("Lilac fungus",(.35,.18,.43),.61),
        "gill": material("Fungal gills",(.53,.36,.50),.85),
        "pod": material("Seed husk",(.19,.32,.22),.73),
        "bronze": material("Patinated copper",(.28,.153,.065),.79),
        "petal": material("Muted rose",(.35,.12,.16),.73),
        "petal_light": material("Faded petal",(.54,.26,.24),.72),
    }
    crossbow, dagger, twig = library(folder/"medieval/medieval_weapon_pack/medieval_weapon_pack.blend",
                                   ["crossbow_1","dagger_1","wand_1"])
    arbalest(crossbow,palette)
    knives(dagger,palette)
    staff(folder,palette)
    wand(twig,palette)
    ring(folder,palette)
    focus(folder,palette)
    bell(folder,palette)
    censer(folder,palette)
    fan(folder,palette)
    lash(palette)


if __name__ == "__main__":
    main(Path(sys.argv[sys.argv.index("--")+1]))
