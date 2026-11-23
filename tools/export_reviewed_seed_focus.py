"""Blender --background review.blend --python this.py -- --output directory.

Bake the five approved upper-body clips into one glTF. Sample the review's
held seed relative to the wrist midpoint. Projectile travel belongs to Godot.
"""
import hashlib
import json
import sys
from pathlib import Path

import bpy
from mathutils import Vector

destination = Path(sys.argv[sys.argv.index("--output") + 1])
destination.mkdir(parents=True, exist_ok=True)
scene = bpy.context.scene
rig = bpy.data.objects["Armature"]
seed = bpy.data.objects["Seed Focus | held seed and release preview"]
source = Path(bpy.data.filepath)
metadata = {"source": source.name, "sha256": hashlib.sha256(source.read_bytes()).hexdigest(),
            "samples_per_second": 48, "clips": {}}
# First/last frames of each action on the approved review timeline.
ranges = {"Ready_focus": (1, 18), "Attack_focus_push": (19, 44),
          "Recover_focus_push": (44, 57), "Attack_focus_gather": (76, 101),
          "Recover_focus_gather": (101, 114)}
poses = {}
for name, (first, last) in ranges.items():
    poses[name] = []
    attachments = []
    for step in range(2 * (last - first) + 1):
        t = step / 2
        scene.frame_set(first + int(t), subframe=t % 1)
        poses[name].append({bone.name: bone.matrix_basis.to_quaternion()
                            for bone in rig.pose.bones})
        wrist_midpoint = sum((rig.matrix_world @ rig.pose.bones["hand_" + side].head
                              for side in ("l", "r")), Vector()) * .5
        offset = seed.matrix_world.translation - wrist_midpoint
        # After release the review animates the same mesh through the air.
        # The held mesh disappears until the replacement reforms in the palms.
        flying = name.startswith("Attack_") and 12 <= t < 17.5
        if flying and t > 12:
            attachments.append(attachments[-1])
        else:
            attachments.append([round(n, 5) for n in
                                (offset.x, offset.z, -offset.y, 0 if flying else seed.scale.x / .9)])
    metadata["clips"][name] = attachments

# Export only these baked actions. The opened review is never saved.
anim = rig.animation_data
anim.action = None
for track in list(anim.nla_tracks):
    anim.nla_tracks.remove(track)
scene.render.fps = 48
scene.frame_start = 0
scene.frame_end = max(map(len, poses.values())) - 1
for name, frames in poses.items():
    action = bpy.data.actions.new(name)
    anim.action = action
    anim.action_slot = action.slots.new('OBJECT', rig.name)
    previous = {}
    for index, pose in enumerate(frames):
        for bone in rig.pose.bones:
            q = pose[bone.name]
            if bone.name in previous:
                q.make_compatible(previous[bone.name])
            previous[bone.name] = q
            bone.rotation_mode = 'QUATERNION'
            bone.rotation_quaternion = q
            bone.keyframe_insert(data_path='rotation_quaternion', frame=index, group=bone.name)
    anim.action = None
    track = anim.nla_tracks.new()
    track.name = name
    track.strips.new(name, 0, action)
    track.mute = True
for track in anim.nla_tracks:
    track.mute = False
bpy.ops.object.select_all(action='DESELECT')
rig.select_set(True)
bpy.data.objects['Mannequin'].select_set(True)
bpy.context.view_layer.objects.active = rig
scene.frame_set(0)
asset = destination / "seed_focus_casts.glb"
bpy.ops.export_scene.gltf(filepath=str(asset), export_format='GLB', use_selection=True,
                         export_animation_mode='NLA_TRACKS', export_frame_range=False,
                         export_force_sampling=True, export_rest_position_armature=True)
binary = asset.read_bytes()
gltf = json.loads(binary[20:20 + int.from_bytes(binary[12:16], 'little')])
assert {a['name'] for a in gltf['animations']} == set(ranges)
assert len(gltf['skins'][0]['joints']) == 65
(destination / "seed_focus_motion.json").write_text(json.dumps(metadata, separators=(',', ':'))+'\n',encoding='utf8')
print("Verified five clips and 65 joints", metadata["sha256"])
