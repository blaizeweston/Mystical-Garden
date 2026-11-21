"""Export Quaternius foliage and forest-edge trees in Blender: -- source_dir output_dir.

Source: Ultimate Stylized Nature (May 2022), CC0. Keep original UVs and leaf
silhouettes, remove bark, centre each crown, and normalize its horizontal span
to one metre. Runtime palette and patch sizes live in garden_canopy_catalog.gd.
The exported GLBs contain geometry only; the three shared leaf maps stay PNGs.
Tree GLBs have separate Trunk/Crown nodes, a grounded origin and unit height.
Use --trees-only after output_dir to add trees without re-exporting existing crowns.
"""
from pathlib import Path
import hashlib
import json
import shutil
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

MODELS = {
    'birch_crown_01': 'BirchTree_1',
    'maple_crown_01': 'MapleTree_1',
    'maple_crown_02': 'MapleTree_2',
    'bush_crown': 'Bush_Large',
}
TEXTURES = {
    'birch_leaves.png': 'BirchTree_Leaves.png',
    'maple_leaves.png': 'MapleTree_Leaves.png',
    'bush_leaves.png': 'Bush_Leaves.png',
}
TREES = {'maple_tree_01': 'MapleTree_1', 'maple_tree_02': 'MapleTree_2', 'birch_tree_01': 'BirchTree_1'}
BARK_TEXTURES = {'maple_bark.jpg': 'MapleTree_Bark.jpg', 'birch_bark.jpg': 'BirchTree_Bark.jpg'}


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def export_crown(source, output, name, donor):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(source / (donor + '.gltf')))
    meshes = [obj for obj in bpy.context.scene.objects if obj.type == 'MESH']
    assert len(meshes) == 1, donor
    obj = meshes[0]
    mesh = obj.data
    leaves = {i for i, material in enumerate(mesh.materials) if material and 'Leaves' in material.name}
    assert leaves, donor
    geometry = bmesh.new()
    geometry.from_mesh(mesh)
    bmesh.ops.delete(geometry, geom=[face for face in geometry.faces if face.material_index not in leaves], context='FACES')
    bmesh.ops.delete(geometry, geom=[vertex for vertex in geometry.verts if not vertex.link_faces], context='VERTS')
    geometry.to_mesh(mesh)
    geometry.free()
    mesh.transform(obj.matrix_world)
    obj.matrix_world = Matrix.Identity(4)
    low = Vector(tuple(min(vertex.co[i] for vertex in mesh.vertices) for i in range(3)))
    high = Vector(tuple(max(vertex.co[i] for vertex in mesh.vertices) for i in range(3)))
    centre = (low + high) * 0.5
    span = max(high.x - low.x, high.y - low.y)
    assert span > 0.1
    for vertex in mesh.vertices:
        vertex.co = (vertex.co - centre) / span
    obj.name = name
    mesh.name = name
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    target = output / (name + '.glb')
    bpy.ops.export_scene.gltf(filepath=str(target), export_format='GLB', use_selection=True,
                              export_materials='NONE', export_animations=False, export_extras=False)
    triangles = sum(len(face.vertices) - 2 for face in mesh.polygons)
    print(f'CANOPY_ASSET {name}: {triangles} triangles, {target.stat().st_size} bytes')
    return {'donor': donor, 'gltf_sha256': digest(source / (donor + '.gltf')),
            'buffer_sha256': digest(source / (donor + '.bin')), 'triangles': triangles,
            'export_sha256': digest(target)}


def export_tree(source, output, name, donor):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(source / (donor + '.gltf')))
    objects = [obj for obj in bpy.context.scene.objects if obj.type == 'MESH']
    assert len(objects) == 1, donor
    original = objects[0]
    original.data.transform(original.matrix_world)
    original.matrix_world = Matrix.Identity(4)
    low = Vector(tuple(min(vertex.co[i] for vertex in original.data.vertices) for i in range(3)))
    high = Vector(tuple(max(vertex.co[i] for vertex in original.data.vertices) for i in range(3)))
    origin = Vector(((low.x + high.x) * .5, (low.y + high.y) * .5, low.z))
    height = high.z - low.z
    assert height > 0.1
    for vertex in original.data.vertices:
        vertex.co = (vertex.co - origin) / height
    leaves = {i for i, material in enumerate(original.data.materials) if material and 'Leaves' in material.name}
    assert leaves
    for part, want_leaves in [('Trunk', False), ('Crown', True)]:
        mesh = original.data.copy()
        geometry = bmesh.new()
        geometry.from_mesh(mesh)
        bmesh.ops.delete(geometry, geom=[face for face in geometry.faces
            if (face.material_index in leaves) != want_leaves], context='FACES')
        bmesh.ops.delete(geometry, geom=[vertex for vertex in geometry.verts if not vertex.link_faces], context='VERTS')
        geometry.to_mesh(mesh)
        geometry.free()
        mesh.name = part
        obj = bpy.data.objects.new(part, mesh)
        bpy.context.collection.objects.link(obj)
    bpy.data.objects.remove(original, do_unlink=True)
    target = output / (name + '.glb')
    bpy.ops.export_scene.gltf(filepath=str(target), export_format='GLB',
        export_materials='NONE', export_animations=False, export_extras=False)
    return {'donor': donor, 'gltf_sha256': digest(source / (donor + '.gltf')),
        'buffer_sha256': digest(source / (donor + '.bin')), 'export_sha256': digest(target)}


def main():
    arguments = sys.argv[sys.argv.index('--') + 1:]
    source, output = [Path(value).resolve() for value in arguments[:2]]
    assert source.is_dir() and source != output
    output.mkdir(parents=True, exist_ok=True)
    records = (json.loads((output / 'sources.json').read_text(encoding='utf-8'))['models'] if '--trees-only' in arguments
        else {name: export_crown(source, output, name, donor) for name, donor in MODELS.items()})
    trees = {name: export_tree(source, output, name, donor) for name, donor in TREES.items()}
    for name, donor in {**TEXTURES, **BARK_TEXTURES}.items():
        shutil.copyfile(source / donor, output / name)
    manifest = {
        'author': 'Quaternius', 'pack': 'Ultimate Stylized Nature, May 2022', 'license': 'CC0-1.0',
        'publisher': 'https://quaternius.com/packs/ultimatestylizednature.html',
        'download_mirror': 'https://github.com/agentkaerf/FreeModels/tree/db3df04d1e4714298a09510b26fb6de6645138a2/Ultimate%20Stylized%20Nature%20-%20May%202022/glTF',
        'download_note': 'Publisher Google Drive download was quota-limited. Only data models/maps were obtained from the pinned CC0 mirror.',
        'conversion': 'Leaf crowns retain original UVs and geometry, no bark, centred unit horizontal span; no collisions, animations or embedded materials.',
        'tree_conversion': 'Complete trees retain separate Trunk/Crown nodes, original UVs, a grounded origin and unit height; no collisions, animations or embedded materials.',
        'models': records,
        'trees': trees,
        'textures': {name: {'donor': donor, 'sha256': digest(source / donor)} for name, donor in {**TEXTURES, **BARK_TEXTURES}.items()},
    }
    (output / 'sources.json').write_text(json.dumps(manifest, indent=2) + '\n', encoding='utf-8')


if __name__ == '__main__':
    main()
