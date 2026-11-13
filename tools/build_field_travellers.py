"""Build playable traveller skins from Quaternius's CC0 body, outfit and hair exports."""
from pathlib import Path
import math
import bmesh
import bpy
from mathutils import Vector

def import_model(path):
    before = set(bpy.context.scene.objects)
    bpy.ops.import_scene.gltf(filepath=str(path.resolve()))
    bpy.context.view_layer.update()
    objects = set(bpy.context.scene.objects) - before
    rig = next(obj for obj in objects if obj.type == "ARMATURE")
    return rig, [obj for obj in objects if obj.type == "MESH" and obj.find_armature() == rig]

def cut_below(mesh, height):
    geometry = bmesh.new()
    geometry.from_mesh(mesh.data)
    removed = [vertex for vertex in geometry.verts if (mesh.matrix_world @ vertex.co).z < height]
    bmesh.ops.delete(geometry, geom=removed, context="VERTS")
    geometry.to_mesh(mesh.data)
    geometry.free()

def attach(mesh, rig, offset=Vector()):
    transform = mesh.matrix_world.copy()
    transform.translation += offset
    mesh.parent = rig
    mesh.matrix_world = transform
    for modifier in mesh.modifiers:
        if modifier.type == "ARMATURE":
            modifier.object = rig

def bell(value, center, width):
    return math.exp(-((value-center)/width)**2)

def shape(mesh, head_height, face):
    basis = mesh.shape_key_add(name="Basis")
    keys = ["FaceWidth","Jaw","Nose","Eyes"] if face else ["Build","Shoulders"]
    matrix = mesh.matrix_world
    inverse = matrix.inverted()
    for name in keys:
        target = mesh.shape_key_add(name=name)
        target.slider_min = -1.0
        target.slider_max = 1.0
        for i, base in enumerate(basis.data):
            at = matrix @ base.co
            x, y, z = at
            if name == "Build":
                region = bell(z,1.16,.31)*bell(abs(x),.13,.22)
                at.x += x*.13*region
                at.y += y*.12*region
            elif name == "Shoulders":
                at.x += x*.14*bell(z,head_height-.17,.17)*bell(abs(x),.24,.23)
            elif name == "FaceWidth":
                at.x += x*.14*bell(z,head_height+.065,.106)
            elif name == "Jaw":
                at.x += x*.16*bell(z,head_height+.015,.045)
                at.z -= .013*bell(z,head_height+.006,.045)
            elif name == "Nose":
                at.y -= .022*bell(x,0,.026)*bell(z,head_height+.087,.04)*bell(y,-.082,.07)
            elif name == "Eyes":
                cx = .038 if x > 0 else -.038
                cz = head_height+.098
                strength = .24*bell(x,cx,.038)*bell(z,cz,.044)*bell(y,-.075,.07)
                at.x += (x-cx)*strength
                at.z += (z-cz)*strength
            target.data[i].co = inverse @ at

def tint_group(mesh, mode):
    for index, material in enumerate(mesh.data.materials):
        if not material:
            continue
        if mode == "hair":
            group = "FieldHair"
        elif material.name.startswith("MI_Ranger"):
            group = "FieldHood" if any(k in mesh.name for k in ("Hood","Pauldron")) else "FieldCloth"
        elif "Superhero" in material.name or "Regular" in material.name:
            group = "FieldSkin"
        else:
            continue
        copy = material.copy()
        copy.name = group
        mesh.data.materials[index] = copy

def build(kind, input_root, output_root):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    outfit_file = next((input_root/"outfits").rglob(f"{kind}_Ranger.gltf"))
    head_file = next((input_root/"universal-base-characters").rglob(f"Superhero_{kind}_FullBody.gltf"))
    rig, clothes = import_model(outfit_file)
    donor, head_meshes = import_model(head_file)
    assert set(rig.data.bones.keys()) == set(donor.data.bones.keys())
    neck = rig.matrix_world @ rig.data.bones["neck_01"].head_local
    head = rig.matrix_world @ rig.data.bones["Head"].head_local
    for mesh in clothes:
        tint_group(mesh,"outfit")
        if "Hood" not in mesh.name:
            shape(mesh,head.z,False)
    for mesh in head_meshes:
        cut_below(mesh,neck.z-.025)
        assert mesh.data.polygons
        attach(mesh,rig)
        tint_group(mesh,"head")
        shape(mesh,head.z,True)
    hair_meshes = []
    for index, style in enumerate(("SimpleParted","Buns","Long")):
        hair_rig, parts = import_model(next((input_root/"hair").rglob(f"Hair_{style}.gltf")))
        old_head = hair_rig.matrix_world @ hair_rig.data.bones["Head"].head_local
        for mesh in parts:
            attach(mesh,rig,head-old_head)
            mesh.name = f"FieldHair{index}"
            tint_group(mesh,"hair")
            hair_meshes.append(mesh)
    bpy.ops.object.select_all(action="DESELECT")
    for obj in [rig,*clothes,*head_meshes,*hair_meshes]:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.export_scene.gltf(
        filepath=str(output_root / f"field_traveller_{kind.lower()}.glb"),
        export_format="GLB", use_selection=True, export_animations=False, export_yup=True,
    )

if __name__ == "__main__":
    import sys
    source, output = (Path(value).resolve() for value in sys.argv[sys.argv.index("--")+1:])
    for body in ("Male","Female"):
        build(body,source,output)
