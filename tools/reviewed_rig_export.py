"""Bake sampled rotations into retargetable traveller animation clips."""
import json

import bpy


def export_clips(rig, poses, asset):
    scene = bpy.context.scene
    anim = rig.animation_data
    anim.action = None
    for track in list(anim.nla_tracks):
        anim.nla_tracks.remove(track)
    scene.render.fps = 48
    scene.frame_start = 0
    scene.frame_end = max(map(len,poses.values()))-1
    for clip, keys in poses.items():
        action = bpy.data.actions.new(clip)
        anim.action = action
        anim.action_slot = action.slots.new("OBJECT",rig.name)
        previous = {}
        for i, pose in enumerate(keys):
            for name, rotation in pose.items():
                bone = rig.pose.bones[name]
                if name in previous:
                    rotation.make_compatible(previous[name])
                previous[name] = rotation
                bone.rotation_mode = "QUATERNION"
                bone.rotation_quaternion = rotation
                bone.keyframe_insert(data_path="rotation_quaternion",frame=i,group=name)
        anim.action = None
        track = anim.nla_tracks.new()
        track.name = clip
        track.strips.new(clip,0,action)
        track.mute = True
    anim.use_nla = True
    for track in anim.nla_tracks:
        track.mute = False
    bpy.ops.object.select_all(action="DESELECT")
    rig.select_set(True)
    bpy.data.objects["Mannequin"].select_set(True)
    bpy.context.view_layer.objects.active = rig
    scene.frame_set(0)
    bpy.ops.export_scene.gltf(filepath=str(asset), use_selection=True, export_format="GLB",
                              export_animation_mode="NLA_TRACKS", export_frame_range=False,
                              export_force_sampling=True, export_rest_position_armature=True)
    blob = asset.read_bytes()
    gltf = json.loads(blob[20:20+int.from_bytes(blob[12:16], "little")])
    assert {a["name"] for a in gltf["animations"]} == set(poses)
    assert len(gltf["skins"][0]["joints"]) == 65
