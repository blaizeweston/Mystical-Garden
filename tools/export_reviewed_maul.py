"""Blender batch export of the reviewed Maul actions; never saves the review file.

Usage: blender --background approved.blend --python this.py -- --output directory
The quarter-frame source keys are sampled at 96 Hz. Pelvis turn is folded into
the first spine joint so the game can retain its original lower-body locomotion.
"""
import bpy,hashlib,json,sys
from pathlib import Path
from mathutils import Matrix,Vector

def motion_json(value, depth=0):
    """Keep each generated frame on one diff line; named fields stay readable."""
    if isinstance(value,dict) and 'right_point' in value:
        return json.dumps(value,separators=(',',': '))
    pad='  '*depth;child='  '*(depth+1)
    if isinstance(value,dict):
        return '{\n'+',\n'.join(child+json.dumps(key)+': '+motion_json(item,depth+1) for key,item in value.items())+'\n'+pad+'}'
    if isinstance(value,list) and value and isinstance(value[0],dict):
        return '[\n'+',\n'.join(child+motion_json(item,depth+1) for item in value)+'\n'+pad+']'
    return json.dumps(value)

args=sys.argv[sys.argv.index('--')+1:]
out=Path(args[args.index('--output')+1]);out.mkdir(parents=True,exist_ok=True)
rig=bpy.data.objects['Armature'];grip=bpy.data.objects['MG_Maul_Review_Grip'];scene=bpy.context.scene
source=Path(bpy.data.filepath);source_hash=hashlib.sha256(source.read_bytes()).hexdigest()
def digest(action):
    curves=[(c.data_path,c.array_index,[(tuple(p.co),tuple(p.handle_left),tuple(p.handle_right),p.interpolation) for p in c.keyframe_points])
        for layer in action.layers for strip in layer.strips for bag in strip.channelbags for c in bag.fcurves]
    return hashlib.sha256(repr(curves).encode()).hexdigest()
before={a.name:digest(a) for a in bpy.data.actions}
original=source.parent/'Mannequin - Maul Attack Review - 20261121-201956.blend'
with bpy.data.libraries.load(str(original),link=False) as (available,loaded):
    loaded.objects=['MG_Maul_Review_Grip']
constant_mount=loaded.objects[0].matrix_basis.copy()
bpy.data.objects.remove(loaded.objects[0],do_unlink=True)
for obj in [rig,grip]:
    if obj.animation_data:
        for track in obj.animation_data.nla_tracks:track.mute=True;track.is_solo=False
grip.animation_data.action=None
grip.matrix_basis=constant_mount
idle=bpy.data.actions['Idle_Loop']
rig.animation_data.action=idle;rig.animation_data.action_slot=idle.slots[0]
scene.frame_set(4);bpy.context.view_layer.update()
idle_pelvis=rig.pose.bones['pelvis'].matrix.copy()
idle_pelvis_basis=rig.pose.bones['pelvis'].matrix_basis.copy()
convert=Matrix(((1,0,0),(0,0,1),(0,-1,0)))
def vec(v):return [round(x,8) for x in convert@v]
def quat(m):
    q=(convert@m.to_3x3().normalized()@convert.inverted()).to_quaternion()
    return [round(q.x,8),round(q.y,8),round(q.z,8),round(q.w,8)]
clips=[
 ('Attack_maul_overhead','MG_Maul_Overhead','maul_overhead.glb',56,38,False),
 ('Attack_maul_sweep','MG_Maul_Sweep','maul_sweep.glb',56,36,True),
 ('Recover_maul_overhead','MG_Maul_Recover_Overhead','maul_recover_overhead.glb',32,0,False),
 ('Recover_maul_sweep','MG_Maul_Recover_Sweep','maul_recover_sweep.glb',32,0,True),
 ('Ready_maul','MG_Maul_Ready','maul_ready.glb',24,0,False),
 ('Ready_maul_sweep','MG_Maul_Sweep_Ready','maul_sweep_ready.glb',24,0,True)]
metadata={'fps':96,'source_fps':24,'source_weapon_scale':.9,'source_review':source.name,
 'source_review_sha256':source_hash,'source_action_sha256':{name:before[name] for _,name,*_ in clips},
 'striking_faces':'Local +/-X; shaft local +Y in Godot.','clips':{}}
for key,name,filename,last,contact,sweep in clips:
    rig.animation_data.action=idle;rig.animation_data.action_slot=idle.slots[0];scene.frame_set(4)
    action=bpy.data.actions[name]
    rig.animation_data.action=action;rig.animation_data.action_slot=action.slots[0]
    grip.animation_data.action=None;grip.matrix_basis=constant_mount
    if sweep:grip.animation_data.action=action;grip.animation_data.action_slot=action.slots[1]
    samples=[];poses=[];end=(last-1)*4+1
    for frame in range(end):
        source_frame=1+frame/4
        scene.frame_set(int(source_frame),subframe=source_frame%1);bpy.context.view_layer.update()
        weapon=grip.evaluated_get(bpy.context.evaluated_depsgraph_get()).matrix_world
        right,left=(-.10,-.35) if sweep else (-.25,-.10)
        shoulders=[rig.pose.bones['upperarm_'+s].matrix.translation for s in ['r','l']]
        hand=rig.pose.bones['hand_r'].matrix.translation;elbow=rig.pose.bones['lowerarm_r'].matrix.translation
        samples.append({'weapon':quat(weapon),'right':quat(rig.pose.bones['hand_r'].matrix),
            'left':quat(rig.pose.bones['hand_l'].matrix),'right_grip':right,'left_grip':left,
            'right_elbow':vec(elbow-shoulders[0]),
            'left_elbow':vec(rig.pose.bones['lowerarm_l'].matrix.translation-shoulders[1]),
            'right_point':vec(weapon@Vector((0,0,right))),
            'shoulder_center':vec((shoulders[0]+shoulders[1])*.5),
            'arm_length':round((elbow-shoulders[0]).length+(hand-elbow).length,8)})
        pose={b.name:b.matrix_basis.copy() for b in rig.pose.bones}
        spine=rig.pose.bones['spine_01']
        # Preserve the reviewed torso's global rotation, with a neutral pelvis.
        pose['spine_01']=spine.bone.matrix_local.inverted()@rig.data.bones['pelvis'].matrix_local@idle_pelvis.inverted()@spine.matrix
        pose['pelvis']=idle_pelvis_basis.copy()
        poses.append(pose)
    baked=bpy.data.actions.new('Export_'+key)
    rig.animation_data.action=baked
    rig.animation_data.action_slot=baked.slots.new('OBJECT',rig.name)
    scene.render.fps=96;scene.render.fps_base=1
    scene.frame_start,scene.frame_end=1,end
    for frame,pose in enumerate(poses,1):
        scene.frame_set(frame)
        for bone in rig.pose.bones:
            bone.matrix_basis=pose[bone.name];bone.rotation_mode='QUATERNION'
            for channel in ['rotation_quaternion','location','scale']:
                bone.keyframe_insert(data_path=channel,frame=frame,group=bone.name)
    for layer in baked.layers:
        for strip in layer.strips:
            for bag in strip.channelbags:
                for curve in bag.fcurves:
                    for point in curve.keyframe_points:point.interpolation='LINEAR'
    if rig.mode!='OBJECT':bpy.ops.object.mode_set(mode='OBJECT')
    bpy.ops.object.select_all(action='DESELECT');rig.select_set(True);bpy.data.objects['Mannequin'].select_set(True)
    bpy.context.view_layer.objects.active=rig;scene.frame_set(1)
    bpy.ops.export_scene.gltf(filepath=str(out/filename),export_format='GLB',use_selection=True,
        export_animations=True,export_animation_mode='ACTIVE_ACTIONS',export_frame_range=True,
        export_frame_step=1,export_force_sampling=True,export_optimize_animation_size=False,
        export_rest_position_armature=True)
    metadata['clips'][key]={'action':name,'file':filename,'duration_seconds':(last-1)/24,
        'contact_seconds':(contact-1)/24 if contact else 0,'samples':samples}
    print('EXPORTED',key,flush=True)
assert all(digest(bpy.data.actions[name])==value for name,value in before.items())
assert hashlib.sha256(source.read_bytes()).hexdigest()==source_hash
(out/'maul_motion.json').write_text(motion_json(metadata)+'\n',encoding='utf8')
print('VERIFIED: saved review and all original action curves unchanged',source_hash,flush=True)
