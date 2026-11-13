from pathlib import Path

import bpy

project = Path(__file__).resolve().parents[1]
bpy.ops.wm.read_factory_settings(use_empty=True)


def material(name, color, metallic=0):
    result = bpy.data.materials.new(name)
    result.use_nodes = True
    shader = result.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = (*color, 1)
    shader.inputs["Metallic"].default_value = metallic
    return result


stone = material("Moss stone", (0.24, 0.23, 0.17))
gold = material("Bronze trim", (0.34, 0.27, 0.12), 0.35)
gem = material("Seed crystal", (0.38, 0.57, 0.22), 0.2)
shader = gem.node_tree.nodes.get("Principled BSDF")
shader.inputs["Emission Color"].default_value = (0.20, 0.38, 0.08, 1)
shader.inputs["Emission Strength"].default_value = 0.7

for name, radius, depth, height, surface in [
    ("Plinth", 0.83, 0.24, 0.12, stone),
    ("Pedestal", 0.45, 0.64, 0.43, stone),
    ("Rim", 0.69, 0.12, 0.79, gold),
    ("Basin", 0.58, 0.13, 0.86, stone),
]:
    bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=radius, depth=depth, location=(0, 0, height))
    bpy.context.object.name = name
    bpy.context.object.data.materials.append(surface)

bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=0.31, location=(0, 0, 1.29))
bpy.context.object.name = "Seed crystal"
bpy.context.object.scale.z = 1.5
bpy.context.object.data.materials.append(gem)

bpy.ops.wm.save_as_mainfile(filepath=str(project / "assets/source/altar.blend"))
bpy.ops.export_scene.gltf(filepath=str(project / "assets/altar.glb"), export_format="GLB")
