"""Blender background export. Open the reviewed .blend and pass -- PROJECT_DIRECTORY."""
import hashlib
import json
import sys
from pathlib import Path

import bpy
from mathutils import Matrix, Vector

sys.path.insert(0, str(Path(__file__).resolve().parent))
from reviewed_rig_export import export_clips

destination = Path(sys.argv[-1]) / "assets/characters"
scene = bpy.context.scene
rig = bpy.data.objects["Armature"]
vine = bpy.data.objects["Root Lash | vine rig"]
handle = bpy.data.objects["Root Lash | bark grip"]
axes = Matrix(((1, 0, 0), (0, 0, 1), (0, -1, 0)))
source = Path(bpy.data.filepath)
data = {"source": source.name, "sha256": hashlib.sha256(source.read_bytes()).hexdigest(),
        "impact_seconds": 16 / 24, "clips": {}}

def play(obj, name):
    anim = obj.animation_data
    anim.use_nla = False
    anim.action = bpy.data.actions[name]
    anim.action_slot = anim.action.slots[0]

def xyzw(transform):
    basis = axes @ transform.to_quaternion().to_matrix() @ axes.transposed()
    q = basis.to_quaternion()
    return [q.x, q.y, q.z, q.w]

play(rig, "Idle_Loop")
scene.frame_set(4)
spine = rig.pose.bones["spine_01"]
# Retarget the reviewed hip turn onto the spine. In-game legs retain locomotion.
standing_parent = spine.parent.matrix @ spine.parent.bone.matrix_local.inverted() @ spine.bone.matrix_local
clips = {"Ready_whip_review": "Ready", "Attack_whip_forehand": "Forward flick",
         "Attack_whip_backhand": "Returning lash", "Recover_whip_forehand": "Recover forward",
         "Recover_whip_backhand": "Recover return"}
poses = {}
for clip, label in clips.items():
    play(rig, "MG_RootLash_" + label.replace(" ", "_"))
    play(vine, "Root Lash vine | " + label)
    count = round(rig.animation_data.action.frame_range[1]-1)*2 + 1
    samples = data["clips"][clip] = []
    keys = poses[clip] = []
    for i in range(count):
        scene.frame_set(1+i//2, subframe=(i%2)*.5)
        pose = {b.name: b.matrix_basis.to_quaternion() for b in rig.pose.bones}
        pose[spine.name] = (standing_parent.inverted() @ spine.matrix).to_quaternion()
        keys.append(pose)
        palm = sum((rig.matrix_world @ rig.pose.bones[n+"_r"].head
                    for n in ("index_02","pinky_02","middle_03","ring_03")), Vector()) / 4
        if "grip_r" not in data:
            data["grip_r"] = [round(x,6) for x in axes @ (handle.matrix_world.inverted() @ palm)]
        sample = [*(axes @ (handle.matrix_world.translation-palm)), *xyzw(handle.matrix_world)]
        for b in vine.pose.bones:
            sample.extend(xyzw(b.matrix @ b.bone.matrix_local.inverted()))
        samples.append([round(x,6) for x in sample])

export_clips(rig, poses, destination/"root_lash_attacks.glb")
(destination/"root_lash_grips.json").write_text(json.dumps(data,separators=(",",":"))+"\n",encoding="utf8")
