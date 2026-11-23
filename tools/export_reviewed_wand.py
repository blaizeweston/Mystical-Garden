"""Export the approved Thorn Wand clips without saving or changing the review.

Blender --background approved.blend --python this.py -- --output directory
The source is 24 FPS; quarter-frame baking retains the grip and 15-degree sweep.
"""
import bpy, hashlib, json, sys
from pathlib import Path
from mathutils import Matrix, Vector

args = sys.argv[sys.argv.index('--') + 1:]
out = Path(args[args.index('--output') + 1]); out.mkdir(parents=True, exist_ok=True)
source = Path(bpy.data.filepath); source_hash = hashlib.sha256(source.read_bytes()).hexdigest()
rig = bpy.data.objects['Armature']; grip = bpy.data.objects['MG_Wand_Review_Grip']; scene = bpy.context.scene
assert len(rig.data.bones) == 65

def digest(action):
    curves = [(c.data_path, c.array_index, [(tuple(k.co), tuple(k.handle_left), tuple(k.handle_right), k.interpolation) for k in c.keyframe_points])
              for layer in action.layers for strip in layer.strips for bag in strip.channelbags for c in bag.fcurves]
    return hashlib.sha256(repr(curves).encode()).hexdigest()

before = {a.name: digest(a) for a in bpy.data.actions}
for track in rig.animation_data.nla_tracks: track.mute = True; track.is_solo = False
idle = bpy.data.actions['Idle_Loop']; rig.animation_data.action = idle; rig.animation_data.action_slot = idle.slots[0]
scene.frame_set(4); bpy.context.view_layer.update()
idle_pelvis = rig.pose.bones['pelvis'].matrix.copy(); idle_basis = rig.pose.bones['pelvis'].matrix_basis.copy()
convert = Matrix(((1, 0, 0), (0, 0, 1), (0, -1, 0)))

def vec(v): return [round(x, 8) for x in convert @ v]
def quat(m):
    q = (convert @ m.to_3x3().normalized() @ convert.inverted()).to_quaternion()
    return [round(q.x, 8), round(q.y, 8), round(q.z, 8), round(q.w, 8)]

clips = [
    ('Attack_wand_forward', 'MG_Wand_Forward_Flick', 'wand_forward.glb', 40, 18),
    ('Attack_wand_sweep', 'MG_Wand_Side_Flick', 'wand_sweep.glb', 40, 18),
    ('Recover_wand_forward', 'MG_Wand_Recover_Forward', 'wand_recover_forward.glb', 18, 0),
    ('Recover_wand_sweep', 'MG_Wand_Recover_Side', 'wand_recover_sweep.glb', 18, 0),
    ('Ready_wand_authored', 'MG_Wand_Ready', 'wand_ready.glb', 24, 0)]
metadata = dict(fps=96, source_fps=24, source_weapon_scale=float(grip['weapon_scale']),
                source_review=source.name, source_review_sha256=source_hash,
                source_action_sha256={n: before[n] for _, n, *_ in clips}, sweep_degrees=15, clips={})
ready = bpy.data.actions['MG_Wand_Ready']; rig.animation_data.action = ready; rig.animation_data.action_slot = ready.slots[0]
scene.frame_set(1); bpy.context.view_layer.update()
hand = rig.pose.bones['hand_r'].matrix
weapon = grip.evaluated_get(bpy.context.evaluated_depsgraph_get()).matrix_world
knuckles = sum((rig.pose.bones[f'{f}_{j:02d}_r'].head for f in ('index', 'middle', 'ring', 'pinky') for j in (2, 3)), Vector()) / 8
metadata['calibration'] = dict(hand=quat(hand), weapon=quat(weapon), grip=vec(hand.inverted() @ weapon.translation),
                               knuckle_distance=(knuckles - hand.translation).length)
for key, name, filename, last, contact in clips:
    rig.animation_data.action = bpy.data.actions[name]; rig.animation_data.action_slot = rig.animation_data.action.slots[0]
    poses = []; end = (last - 1) * 4 + 1
    for step in range(end):
        frame = 1 + step / 4; scene.frame_set(int(frame), subframe=frame % 1); bpy.context.view_layer.update()
        pose = {b.name: b.matrix_basis.copy() for b in rig.pose.bones}
        spine = rig.pose.bones['spine_01']
        pose['spine_01'] = spine.bone.matrix_local.inverted() @ rig.data.bones['pelvis'].matrix_local @ idle_pelvis.inverted() @ spine.matrix
        pose['pelvis'] = idle_basis.copy(); poses.append(pose)
    baked = bpy.data.actions.new('Export_' + key); rig.animation_data.action = baked
    rig.animation_data.action_slot = baked.slots.new('OBJECT', rig.name)
    scene.render.fps = 96; scene.render.fps_base = 1; scene.frame_start, scene.frame_end = 1, end
    for frame, pose in enumerate(poses, 1):
        scene.frame_set(frame)
        for bone in rig.pose.bones:
            bone.matrix_basis = pose[bone.name]; bone.rotation_mode = 'QUATERNION'
            for channel in ('rotation_quaternion', 'location', 'scale'): bone.keyframe_insert(data_path=channel, frame=frame, group=bone.name)
    for layer in baked.layers:
        for strip in layer.strips:
            for bag in strip.channelbags:
                for curve in bag.fcurves:
                    for point in curve.keyframe_points: point.interpolation = 'LINEAR'
    if rig.mode != 'OBJECT': bpy.ops.object.mode_set(mode='OBJECT')
    bpy.ops.object.select_all(action='DESELECT'); rig.select_set(True); bpy.data.objects['Mannequin'].select_set(True)
    bpy.context.view_layer.objects.active = rig; scene.frame_set(1)
    bpy.ops.export_scene.gltf(filepath=str(out / filename), export_format='GLB', use_selection=True, export_animations=True,
                            export_animation_mode='ACTIVE_ACTIONS', export_frame_range=True, export_frame_step=1,
                            export_force_sampling=True, export_optimize_animation_size=False, export_rest_position_armature=True)
    metadata['clips'][key] = dict(action=name, file=filename, duration_seconds=(last - 1) / 24,
                                  contact_seconds=(contact - 1) / 24 if contact else 0)
    print('EXPORTED', key, flush=True)
assert all(digest(bpy.data.actions[n]) == h for n, h in before.items())
assert hashlib.sha256(source.read_bytes()).hexdigest() == source_hash
(out / 'wand_motion.json').write_text(json.dumps(metadata, indent=2) + '\n', encoding='utf8')
print('VERIFIED: source review and all original Action curves unchanged', source_hash, flush=True)
