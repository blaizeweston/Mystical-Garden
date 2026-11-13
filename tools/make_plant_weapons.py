"""Build the Briar Spear, Heartwood Maul and Harvest Scythe in their Godot grip coordinates."""
from math import cos, sin, pi, tau
from pathlib import Path

import bpy
import bmesh
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "assets/weapons"


def material(name, color, roughness=.8, texture=None):
    result = bpy.data.materials.new(name)
    result.use_nodes = True
    shader = next(node for node in result.node_tree.nodes if node.type == "BSDF_PRINCIPLED")
    shader.inputs["Base Color"].default_value = (*color, 1)
    shader.inputs["Roughness"].default_value = roughness
    if texture:
        image = result.node_tree.nodes.new("ShaderNodeTexImage")
        image.image = bpy.data.images.load(str(texture), check_existing=True)
        result.node_tree.links.new(image.outputs["Color"], shader.inputs["Base Color"])
    return result


class WeaponMesh:
    def __init__(self, name, palette):
        self.name = name
        self.palette = palette
        self.points = []
        self.faces = []
        self.style = []
        self.uvs = []

    def surface(self, rings, sides, face_material, cap_material=None):
        base = len(self.points)
        self.points.extend((point.x, -point.z, point.y) for ring in rings for point in ring)
        for i in range(len(rings)-1):
            for j in range(sides):
                nxt = (j+1) % sides
                a = base+i*sides
                b = a+sides
                self.faces.append((a+j, a+nxt, b+nxt, b+j))
                self.style.append(face_material(i,j) if callable(face_material) else face_material)
                self.uvs.append(((j/sides, i/len(rings)), ((j+1)/sides, i/len(rings)),
                                 ((j+1)/sides, (i+1)/len(rings)), (j/sides, (i+1)/len(rings))))
        if cap_material is not None:
            self.faces.extend((tuple(range(base+sides-1,base-1,-1)),
                               tuple(range(base+(len(rings)-1)*sides,base+len(rings)*sides))))
            self.style.extend((cap_material,cap_material))
            self.uvs.extend(([(0,0)]*sides,[(1,1)]*sides))

    def tube(self, raw_points, radii, color, sides=12, aspect=1.0):
        path = [Vector(point) for point in raw_points]
        rings = []
        for i,(at,radius) in enumerate(zip(path,radii)):
            tangent = (path[min(len(path)-1,i+1)]-path[max(0,i-1)]).normalized()
            guide = Vector((1,0,0)) if abs(tangent.x)<.90 else Vector((0,1,0))
            side = (guide-tangent*guide.dot(tangent)).normalized()
            normal = tangent.cross(side)
            rings.append([at+radius*(side*cos(tau*j/sides)+normal*sin(tau*j/sides)*aspect) for j in range(sides)])
        self.surface(rings,sides,color,color)

    def blade(self, sections):
        rings = []
        for i,(x,y,width,thick) in enumerate(sections):
            prior = Vector(sections[max(0,i-1)][:2])
            after = Vector(sections[min(len(sections)-1,i+1)][:2])
            tangent = (after-prior).normalized()
            side = Vector((tangent.y,-tangent.x,0))
            at = Vector((x,y,0))
            rings.append([
                at+side*width,
                at+side*(width*.64)+Vector((0,0,thick)),
                at+Vector((0,0,thick*1.19)),
                at-side*(width*.57)+Vector((0,0,thick)),
                at-side*width,
                at-side*(width*.52)-Vector((0,0,thick*.60)),
                at-Vector((0,0,thick*.66)),
                at+side*(width*.63)-Vector((0,0,thick*.60)),
            ])
        self.surface(rings,8,lambda _i,j: "edge" if j in [0,3,4,7] else "leaf", "leaf")

    def export(self, filename):
        mesh = bpy.data.meshes.new(self.name)
        mesh.from_pydata(self.points,[],self.faces)
        mesh.update()
        material_names = sorted(set(self.style))
        for name in material_names:
            mesh.materials.append(self.palette[name])
        uv = mesh.uv_layers.new(name="SurfaceUV")
        for polygon, style, coords in zip(mesh.polygons,self.style,self.uvs):
            polygon.material_index = material_names.index(style)
            polygon.use_smooth = style not in ["edge","leaf"]
            for loop,coord in zip(polygon.loop_indices,coords):
                uv.data[loop].uv = coord
        shell = bmesh.new()
        shell.from_mesh(mesh)
        bmesh.ops.remove_doubles(shell,verts=list(shell.verts),dist=1e-6)
        bmesh.ops.recalc_face_normals(shell,faces=list(shell.faces))
        shell.to_mesh(mesh)
        shell.free()
        obj = bpy.data.objects.new(self.name,mesh)
        bpy.context.collection.objects.link(obj)
        bpy.ops.object.select_all(action="DESELECT")
        obj.select_set(True)
        bpy.context.view_layer.objects.active = obj
        bpy.ops.export_scene.gltf(filepath=str(OUTPUT/filename),export_format="GLB",use_selection=True,export_animations=False)


def branch(mesh, lo, hi, radius, curve):
    points = []
    sizes = []
    for i in range(30):
        t = i/29
        y = lo+(hi-lo)*t
        # The shaft runs through the grip points at y=0 and the middle of the wrap.
        displacement = curve*sin(t*pi)*(min(1,abs(y)*4)*min(1,abs(y-.31)*4))
        points.append((displacement,y,sin(t*tau)*.65*displacement))
        sizes.append(radius*(.88+.09*sin(t*17)+.04*cos(t*40))*(.65+.42*sin(t*pi)))
    mesh.tube(points,sizes,"bark",14)


def winding_root(mesh, lo, hi, orbit, thickness, turns, color, phase=0):
    points = []
    sizes = []
    for i in range(55):
        t = i/54
        angle = phase+t*tau*turns
        width = orbit*(.88+.12*sin(t*pi))
        points.append((cos(angle)*width,lo+(hi-lo)*t,sin(angle)*width))
        sizes.append(thickness*(.28+.72*sin(t*pi)**.4))
    mesh.tube(points,sizes,color,8)


def briar(palette):
    mesh = WeaponMesh("BriarSpear",palette)
    branch(mesh,-.53,1.30,.043,.044)
    winding_root(mesh,-.22,.48,.049,.012,4.4,"vine")
    winding_root(mesh,.64,1.37,.046,.024,2.4,"briar")
    mesh.blade([(0,1.10,.042,.017),(.008,1.23,.076,.030),
                (.020,1.34,.091,.034),(.028,1.45,.062,.024),
                (.045,1.58,.024,.014),(.051,1.67,.001,.001)])
    for i,(side,y) in enumerate([(-1,.88),(1,1.06),(-1,1.22),(1,1.36)]):
        mesh.tube([(0,y,0),(.055*side,y+.016,.028),(.13*side,y+.10,.025),(.15*side,y+.16,-.012)],
                  [.029,.024,.012,.001],"briar" if i<3 else "edge",8,.76)
    mesh.tube([(0,1.15,.03),(.02,1.32,.046),(.043,1.53,.019)],
              [.012,.011,.002],"vine",6)
    mesh.export("briar_spear.glb")


def heartwood(palette):
    mesh = WeaponMesh("HeartwoodMaul",palette)
    branch(mesh,-.45,.94,.060,.032)
    winding_root(mesh,-.32,.43,.059,.017,4.7,"vine")
    winding_root(mesh,.43,1.04,.079,.032,2.2,"briar",.7)
    sides = 24
    ranges = [(-.38,.70),(-.34,.93),(-.25,1.04),(-.03,1.10),(.19,1.03),(.34,.88),(.38,.70)]
    def ring(x,scale):
        return [Vector((x,.88+sin(tau*i/sides)*.211*scale*(1+.07*cos(i*1.64)),
                          cos(tau*i/sides)*.193*scale*(1+.08*sin(i*1.91)))) for i in range(sides)]
    mesh.surface([ring(x,r) for x,r in ranges],sides,lambda i,j: "briar" if (i+j*3)%13==0 else "bark")
    for sign in [-1,1]:
        bands = [.70,.61,.56,.43,.38,.25,.20,.08,.002]
        rings = [ring(sign*(.38+.014*(1-band/.70)),band) for band in bands]
        if sign<0:
            rings.reverse()
        mesh.surface(rings,sides,lambda i,_j: "grain_dark" if i%2 else "grain")
    for side in [-1,1]:
        mesh.tube([(side*.08,.52,.018),(side*.17,.64,.105),(side*.24,.79,.168),
                   (side*.19,.98,.161),(side*.13,1.05,.072)],
                  [.036,.046,.037,.026,.008],"briar",10)
        mesh.tube([(side*.03,.59,-.035),(side*.12,.77,-.16),(side*.21,1.03,-.149),(side*.32,1.08,-.068)],
                  [.032,.035,.025,.006],"vine",9)
    mesh.export("heartwood_maul.glb")


def harvest(palette):
    mesh = WeaponMesh("HarvestScythe",palette)
    branch(mesh,-.54,1.24,.046,-.064)
    winding_root(mesh,-.27,.44,.052,.012,4.4,"vine")
    winding_root(mesh,.72,1.22,.052,.022,2.0,"briar")
    mesh.blade([(-.006,1.07,.045,.020),(.105,1.21,.090,.035),
                (.247,1.27,.112,.042),(.415,1.23,.092,.035),
                (.564,1.15,.069,.027),(.681,1.037,.041,.019),(.765,.900,.001,.001)])
    mesh.tube([(0,1.08,.018),(.11,1.215,.044),(.26,1.267,.051),(.43,1.222,.041),
               (.58,1.136,.031),(.716,.99,.013)],
              [.021,.023,.014,.011,.008,.001],"vine",9)
    for x,y in [(.18,1.23),(.32,1.245),(.47,1.18)]:
        mesh.tube([(x,y,.042),(x+.04,y-.041,.036),(x+.055,y-.068,.019)],
                  [.007,.005,.001],"briar",6)
    mesh.export("harvest_scythe.glb")


if __name__ == "__main__":
    bpy.ops.wm.read_factory_settings(use_empty=True)
    palette = {
        "bark":material("WeatheredBark",(.28,.18,.089),.93,ROOT/"assets/garden/field/bark.jpg"),
        "briar":material("DarkBriar",(.108,.067,.029),.91),
        "vine":material("OldVine",(.30,.36,.122),.83),
        "leaf":material("HardenedLeaf",(.107,.204,.111),.69),
        "edge":material("LeafEdge",(.35,.49,.217),.59),
        "grain":material("Heartwood",(.43,.229,.099),.9),
        "grain_dark":material("GrowthRings",(.208,.088,.032),.97),
    }
    briar(palette)
    heartwood(palette)
    harvest(palette)
