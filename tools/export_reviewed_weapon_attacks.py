"""Run in background Blender with -- --reviews DIRECTORY --project DIRECTORY.

Sample the final review timelines, including finger poses, grips and strings.
Held props follow the retargeted wrist; the game owns projectile flight.
"""
import argparse
import hashlib
import json
import sys
from pathlib import Path

import bpy
from mathutils import Matrix, Vector

args = argparse.ArgumentParser()
args.add_argument("--reviews", type=Path, required=True)
args.add_argument("--project", type=Path, required=True)
options = args.parse_args(sys.argv[sys.argv.index("--") + 1:])
destination = options.project / "assets/characters"
# Timeline frames at 24 fps, in ready, attack A, return A, attack B, return B order.
reviews = {
    "bow": ("Vine Bow - 1.5x Upright and Canted Shots.blend", "upright", "canted",
            (1, 19, 59, 73, 90, 130, 144), 22),
    "crossbow": ("Bark Arbalest - Straight Wrist.blend", "raised", "low",
                 (1, 16, 66, 80, 91, 141, 155), 17),
    "ring": ("Thorn Ring - Reversed Wrist Turn.blend", "sidearm", "rising",
             (1, 16, 66, 80, 91, 141, 155), 21),
    "knives": ("Graft Knives - Alternating Cuts.blend", "right", "left",
               (1, 10, 35, 47, 56, 81, 93), 9),
}
axes = Matrix(((1, 0, 0), (0, 0, 1), (0, -1, 0)))
parts = {"bow": ["Vine Bow | grip"], "crossbow": ["Bark Arbalest | presentation"],
         "ring": ["Thorn Ring | presentation"], "knives": ["Graft Knife | right", "Graft Knife | left"]}

def rounded(values):
    return [round(v, 6) for v in values]

def pack_mount(matrix, wrist):
    q = (axes @ matrix.to_quaternion().to_matrix() @ axes.transposed()).to_quaternion()
    return rounded([*(axes @ (matrix.translation - wrist)), q.x, q.y, q.z, q.w])

def fingers(form, side):
    def joint(name):
        return rig.matrix_world @ rig.pose.bones[name+"_"+side].head
    if form == "knives":
        return sum((joint(digit+"_"+part)*weight/4 for digit in ("index","middle","ring","pinky")
                    for part, weight in (("01",.4),("02",.15),("03",.45))),Vector())
    if form == "bow" and side == "r":
        return (joint("index_03")+joint("middle_03"))/2
    return sum((joint(bone) for bone in ("index_02","pinky_02","middle_03","ring_03")), Vector())/4

def bow_mesh():
    # Restore the game's original mesh origin. The reviewed scale is applied about its grip at runtime.
    mesh = bpy.data.objects["Vine Bow | game mesh"].copy()
    mesh.data = mesh.data.copy()
    bpy.context.collection.objects.link(mesh)
    mesh.parent = None
    mesh.matrix_world = Matrix.Identity(4)
    mesh.data.shape_keys.animation_data_clear()
    mesh.data.shape_keys.key_blocks["Draw"].value = 0
    mesh.data.transform(Matrix.Translation((0, 0, .2)), shape_keys=True)
    bpy.ops.object.select_all(action='DESELECT')
    mesh.select_set(True)
    bpy.context.view_layer.objects.active = mesh
    bpy.ops.export_scene.gltf(filepath=str(options.project / "assets/weapons/vine_bow.glb"),
                              use_selection=True, export_animations=False, export_format='GLB')
    bpy.data.objects.remove(mesh, do_unlink=True)

poses = {}
catalog = {}
for form, (filename, first, second, frames, contact) in reviews.items():
    source = options.reviews / filename
    bpy.ops.wm.open_mainfile(filepath=str(source))
    rig = bpy.data.objects["Armature"]
    scene = bpy.context.scene
    a, b, c, d, e, f, g = frames
    ranges = {f"Ready_{form}_review": (a, b-1), f"Attack_{form}_{first}": (b, c),
              f"Recover_{form}_{first}": (c, d), f"Attack_{form}_{second}": (e, f),
              f"Recover_{form}_{second}": (f, g)}
    data = {"source": filename, "sha256": hashlib.sha256(source.read_bytes()).hexdigest(),
            "impact_seconds": contact / 24, "clips": {}, "release_centers": {}}
    catalog[form] = data
    if form == "crossbow":
        scene.frame_set(1)
        stock = bpy.data.objects[parts[form][0]].matrix_world
        for side in ("l", "r"):
            pads = [rig.matrix_world @ rig.pose.bones[bone+"_"+side].head
                    for bone in ("index_02", "pinky_02", "middle_03", "ring_03")]
            data["grip_"+side] = rounded(axes @ (stock.inverted() @ (sum(pads,Vector())/4))/.9 + Vector((0,.2,0)))
    for name, (start, end) in ranges.items():
        poses[name] = []
        samples = []
        data["clips"][name] = samples
        for step in range(2*(end-start)+1):
            scene.frame_set(start+step//2, subframe=(step%2)*.5)
            poses[name].append({bone.name: bone.matrix_basis.to_quaternion().copy() for bone in rig.pose.bones})
            attacking = name.startswith("Attack_")
            sample = []
            for index, obj in enumerate(parts[form]):
                side = "l" if form == "bow" or index == 1 else "r"
                sample.extend(pack_mount(bpy.data.objects[obj].matrix_world, fingers(form,side)))
            if form == "ring":
                flight = attacking and contact < step/2 < 41
                if flight:
                    sample = samples[-1][:7]
                scale = bpy.data.objects[parts[form][0]].scale.x
                sample.append(0 if flight else round(scale, 5))
            if form in ("bow", "crossbow"):
                bow = form == "bow"
                strings = (["Vine Bow | lower string", "Vine Bow | upper string"] if bow else
                           ["Arbalest | string -1", "Arbalest | string 1"])
                grip = bpy.data.objects[parts[form][0]].matrix_world
                # Store endpoints in the original game mesh's local coordinates.
                scale = .9 if not bow else 1.35
                inverse = grip.to_quaternion().inverted()
                for string, z in ((strings[0], -.5), (strings[1], -.5), (strings[0], .5)):
                    world = bpy.data.objects[string].matrix_world @ Vector((0, 0, z))
                    point = axes @ (inverse @ (world - grip.translation)) / scale + Vector((0,.2,0))
                    sample.extend(rounded(point))
                arrow = bpy.data.objects["Vine Bow | review arrow" if bow else "Arbalest | bolt"]
                sample.append(0 if attacking and step/2 >= contact else round(arrow.scale.x,5))
                sample.append(round(bpy.data.objects["Vine Bow | game mesh"].data.shape_keys.key_blocks["Draw"].value,5) if bow else 0)
                support = fingers(form, "r" if bow else "l")
                sample.extend(rounded(axes @ (inverse @ (support-grip.translation))))
            if form!="knives" and attacking and step==2*contact:
                if form=="ring":
                    center=bpy.data.objects[parts[form][0]].matrix_world @ Vector((0,0,.282*.9))
                else:
                    center=world  # Last cable endpoint is the nock shared by both strings.
                data["release_centers"][name]=rounded(axes @ center)
            samples.append(sample)
    if form == "bow":
        bow_mesh()

# All four previews share the same original 65-joint mannequin. Export only the baked clips.
anim = rig.animation_data
anim.action = None
for track in list(anim.nla_tracks):
    anim.nla_tracks.remove(track)
scene.render.fps = 48
scene.frame_start = 0
scene.frame_end = max(map(len, poses.values())) - 1
for name, keys in poses.items():
    action = bpy.data.actions.new(name)
    anim.action = action
    anim.action_slot = action.slots.new('OBJECT', rig.name)
    previous = {}
    for i, pose in enumerate(keys):
        for bone in rig.pose.bones:
            q = pose[bone.name]
            if bone.name in previous:
                q.make_compatible(previous[bone.name])
            previous[bone.name] = q
            bone.rotation_mode = 'QUATERNION'
            bone.rotation_quaternion = q
            bone.keyframe_insert(data_path='rotation_quaternion', frame=i, group=bone.name)
    anim.action = None
    track = anim.nla_tracks.new()
    track.name = name
    track.strips.new(name, 0, action)
    track.mute = True
for track in anim.nla_tracks:
    track.mute = False
bpy.ops.object.select_all(action='DESELECT')
rig.select_set(True)
bpy.data.objects["Mannequin"].select_set(True)
bpy.context.view_layer.objects.active = rig
scene.frame_set(0)
asset = destination / "ranger_and_knife_attacks.glb"
bpy.ops.export_scene.gltf(filepath=str(asset), use_selection=True, export_format='GLB',
                          export_animation_mode='NLA_TRACKS', export_frame_range=False,
                          export_force_sampling=True, export_rest_position_armature=True)
blob = asset.read_bytes()
gltf = json.loads(blob[20:20+int.from_bytes(blob[12:16], "little")])
assert {clip["name"] for clip in gltf["animations"]} == set(poses)
assert len(gltf["skins"][0]["joints"]) == 65
(destination / "ranger_and_knife_grips.json").write_text(json.dumps(catalog,separators=(",",":"))+"\n", encoding="utf8")
print("Verified 20 reviewed clips on the 65-joint rig")
