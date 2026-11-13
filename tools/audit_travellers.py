"""Run Blender against assets/source/travellers.blend; never edits the source."""
from pathlib import Path
import json
import bpy

project=Path(__file__).resolve().parents[1]
manifest=json.loads((project/'assets/characters/rig_manifest.json').read_text(encoding='utf-8'))
missing=set(manifest['animations'])-set(bpy.data.actions.keys())
assert not missing, f'Missing saved authoring actions: {sorted(missing)}'
rigs=[o for o in bpy.data.objects if o.type=='ARMATURE']
assert len(rigs)==2, 'Source must retain both editable rigs'
for rig in rigs:
    assert set(rig.data.bones.keys())==set(manifest['bones'])
    assert all(abs(v-1)<1e-6 for v in rig.scale), 'Apply source object scale'
    bodies=[o for o in bpy.data.objects if o.parent==rig and o.type=='MESH' and o.name.startswith('TravellerBody')]
    assert len(bodies)==1
    for body in bodies:
        assert set(body.data.shape_keys.key_blocks.keys())=={'Basis',*manifest['morphs']}
        for vertex in body.data.vertices:
            assert abs(sum(g.weight for g in vertex.groups)-1)<1e-4, 'Skin normalization'
print('PASS: editable Blender source retains both rigs, normalized skins, six morphs and every locomotion/weapon action')
