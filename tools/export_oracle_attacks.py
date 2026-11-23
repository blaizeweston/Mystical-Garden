"""Run Blender on the reviewed Bell, Censer or Fan scene with -- FORM PROJECT."""
import hashlib
import json
import sys
from pathlib import Path

import bpy
from mathutils import Matrix, Vector

sys.path.insert(0, str(Path(__file__).resolve().parent))
from reviewed_rig_export import export_clips

form, directory = sys.argv[-2:]
assets = Path(directory) / "assets"
source = Path(bpy.data.filepath)
scene = bpy.context.scene
rig = bpy.data.objects["Armature"]
axes = Matrix(((1, 0, 0), (0, 0, 1), (0, -1, 0)))
# Game clip suffix, reviewed attack and reviewed return.
strokes = {
    "bell": [("lift", "Lantern lift", "Recover lift"), ("outward", "Outward lift", "Recover outward")],
    "censer": [("forward", "Forward swing", "Recover forward"), ("diagonal", "Diagonal swing", "Recover diagonal")],
    "fan": [("forehand", "Forehand fan", "Recover forehand"), ("backhand", "Backhand fan", "Recover backhand")],
}
props = {"bell": "Bloom Bell | traveller right-hand grip", "censer": "Spore Censer | grip and bowl",
         "fan": "Petal Fan | game mesh"}
weapon = bpy.data.objects[props[form]]
clips = {"Ready_" + form + "_review": "Ready"}
for suffix, stroke, recovery in strokes[form]:
    clips["Attack_" + form + "_" + suffix] = stroke
    clips["Recover_" + form + "_" + suffix] = recovery


def play(obj, action):
    anim = obj.animation_data
    anim.use_nla = False
    anim.action = bpy.data.actions[action]
    anim.action_slot = anim.action.slots[0]


def rounded(values):
    return [round(v, 6) for v in values]


def orientation(matrix):
    q = (axes @ matrix.to_quaternion().to_matrix() @ axes.transposed()).to_quaternion()
    return [q.x, q.y, q.z, q.w]


play(rig, "Idle_Loop")
scene.frame_set(4)
spine = rig.pose.bones["spine_01"]
idle_parent = spine.parent.matrix @ spine.parent.bone.matrix_local.inverted() @ spine.bone.matrix_local
data = {"source": source.name, "sha256": hashlib.sha256(source.read_bytes()).hexdigest(), "clips": {}}
poses = {}
if form == "fan":
    data["rim_points"] = {}
    data["release_centers"] = {}
    data["release_palm_height"] = {}
for clip, label in clips.items():
    play(rig, "MG_" + form.capitalize() + "_" + label.replace(" ", "_"))
    if form == "censer":
        play(weapon, "Censer | " + label)
    action = rig.animation_data.action
    attack = clip.startswith("Attack_")
    contact = action[{"bell": "ring_frame", "censer": "contact_frame", "fan": "release_frame"}[form]] if attack else 0
    if attack:
        impact = (contact - 1) / scene.render.fps
        assert impact == data.setdefault("impact_seconds", impact)
    keys = poses[clip] = []
    samples = data["clips"][clip] = []
    for half in range(round(action.frame_range[1] - 1) * 2 + 1):
        scene.frame_set(1 + half // 2, subframe=(half % 2) * .5)
        pose = {b.name: b.matrix_basis.to_quaternion() for b in rig.pose.bones}
        pose[spine.name] = (idle_parent.inverted() @ spine.matrix).to_quaternion()
        keys.append(pose)
        fingers = ("index_02_r", "pinky_02_r", "middle_03_r", "ring_03_r")
        palm = sum((rig.matrix_world @ rig.pose.bones[n].head for n in fingers), Vector()) / len(fingers)
        basis = weapon.matrix_world
        sample = [*(axes @ (basis.translation - palm)), *orientation(basis),
                  *(axes @ (basis.inverted() @ palm))]
        if form == "censer":
            bone = weapon.pose.bones["Suspension"]
            sample.extend(orientation(bone.matrix @ bone.bone.matrix_local.inverted()))
        if form == "fan" and attack and half == (contact - 1) * 2:
            # Match outside rays to the rim's left/right locations for THIS stroke.
            rim = sorted(weapon.children, key=lambda p: p.matrix_world.translation.x)
            assert len(rim) == 3
            data["rim_points"][clip] = [rounded(axes @ p.location) for p in rim]
            data["release_centers"][clip] = [rounded(axes @ p.matrix_world.translation) for p in rim]
            data["release_palm_height"][clip] = round(palm.z, 6)
        samples.append(rounded(sample))
    if "scale" not in data:
        data["scale"] = round(weapon.matrix_world.to_scale().x, 4)

if form == "censer":
    # Preserve the same two weighted joints and original materials as the review.
    mesh = next(child for child in weapon.children if child.type == "MESH")
    weapon.animation_data_clear()
    for constraint in list(weapon.constraints):
        weapon.constraints.remove(constraint)
    weapon.matrix_world = Matrix.Identity(4)
    for bone in weapon.pose.bones:
        bone.matrix_basis = Matrix.Identity(4)
    bpy.ops.object.select_all(action="DESELECT")
    weapon.select_set(True)
    mesh.select_set(True)
    data["hinge"] = rounded(axes @ Vector(weapon["hinge"]))
    bpy.ops.export_scene.gltf(filepath=str(assets / "weapons/spore_censer.glb"), use_selection=True,
                              export_format="GLB", export_animations=False, export_rest_position_armature=True)

export_clips(rig, poses, assets / "characters" / (form + "_attacks.glb"))
(assets / "characters" / (form + "_grips.json")).write_text(json.dumps(data, separators=(",", ":")) + "\n", encoding="utf8")
