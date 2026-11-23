"""Export the approved Spore Staff casts and returns without saving the review.

Blender --background approved.blend --python this.py -- --output directory
Quarter-frame sampling retains both grips; locomotion remains owned by the game.
"""
import bpy,hashlib,json,sys
from pathlib import Path
from mathutils import Matrix,Vector

def motion_json(value,depth=0):
    if isinstance(value,dict) and 'right_point' in value:return json.dumps(value,separators=(',',': '))
    pad='  '*depth;child='  '*(depth+1)
    if isinstance(value,dict):return '{\n'+',\n'.join(child+json.dumps(k)+': '+motion_json(v,depth+1) for k,v in value.items())+'\n'+pad+'}'
    if isinstance(value,list) and value and isinstance(value[0],dict):return '[\n'+',\n'.join(child+motion_json(v,depth+1) for v in value)+'\n'+pad+']'
    return json.dumps(value)
def digest(action):
    curves=[(c.data_path,c.array_index,[(tuple(p.co),tuple(p.handle_left),tuple(p.handle_right),p.interpolation) for p in c.keyframe_points])
        for layer in action.layers for strip in layer.strips for bag in strip.channelbags for c in bag.fcurves]
    return hashlib.sha256(repr(curves).encode()).hexdigest()
args=sys.argv[sys.argv.index('--')+1:];out=Path(args[args.index('--output')+1]);out.mkdir(parents=True,exist_ok=True)
source=Path(bpy.data.filepath);source_hash=hashlib.sha256(source.read_bytes()).hexdigest()
rig=bpy.data.objects['Armature'];grip=bpy.data.objects['MG_Staff_Review_Grip'];scene=bpy.context.scene
assert len(rig.data.bones)==65
before={a.name:digest(a) for a in bpy.data.actions}
for obj in [rig,grip]:
    if obj.animation_data:
        for track in obj.animation_data.nla_tracks:track.mute=True;track.is_solo=False
idle=bpy.data.actions['Idle_Loop'];rig.animation_data.action=idle;rig.animation_data.action_slot=idle.slots[0]
scene.frame_set(4);bpy.context.view_layer.update()
idle_pelvis=rig.pose.bones['pelvis'].matrix.copy();idle_basis=rig.pose.bones['pelvis'].matrix_basis.copy()
convert=Matrix(((1,0,0),(0,0,1),(0,-1,0)))
def vec(v):return [round(x,8) for x in convert@v]
def quat(m):
    q=(convert@m.to_3x3().normalized()@convert.inverted()).to_quaternion()
    return [round(q.x,8),round(q.y,8),round(q.z,8),round(q.w,8)]
clips=[
 ('Attack_staff_forward','MG_Staff_Forward_Cast','staff_forward.glb',48,28),
 ('Attack_staff_side','MG_Staff_Side_Cast','staff_side.glb',48,28),
 ('Recover_staff_forward','MG_Staff_Recover_Forward','staff_recover_forward.glb',24,0),
 ('Recover_staff_side','MG_Staff_Recover_Side','staff_recover_side.glb',24,0),
 ('Ready_staff_authored','MG_Staff_Ready','staff_ready.glb',24,0)]
metadata={'fps':96,'source_fps':24,'source_weapon_scale':float(grip['weapon_scale']),
 'source_review':source.name,'source_review_sha256':source_hash,
 'source_action_sha256':{name:before[name] for _,name,*_ in clips},'clips':{}}
for key,name,filename,last,contact in clips:
    rig.animation_data.action=idle;rig.animation_data.action_slot=idle.slots[0];scene.frame_set(4)
    action=bpy.data.actions[name];rig.animation_data.action=action;rig.animation_data.action_slot=action.slots[0]
    samples=[];poses=[];end=(last-1)*4+1
    for step in range(end):
        frame=1+step/4;scene.frame_set(int(frame),subframe=frame%1);bpy.context.view_layer.update()
        weapon=grip.evaluated_get(bpy.context.evaluated_depsgraph_get()).matrix_world
        shoulders=[rig.pose.bones['upperarm_'+side].matrix.translation for side in ['r','l']]
        elbow=rig.pose.bones['lowerarm_r'].matrix.translation;wrist=rig.pose.bones['hand_r'].matrix.translation
        right=float(grip['right_grip_local']);left=float(grip['left_grip_local'])
        samples.append({'weapon':quat(weapon),'right':quat(rig.pose.bones['hand_r'].matrix),'left':quat(rig.pose.bones['hand_l'].matrix),
            'right_grip':right,'left_grip':left,'right_elbow':vec(elbow-shoulders[0]),
            'left_elbow':vec(rig.pose.bones['lowerarm_l'].matrix.translation-shoulders[1]),
            'right_point':vec(weapon@Vector((0,0,right))),'shoulder_center':vec((shoulders[0]+shoulders[1])*.5),
            'arm_length':round((elbow-shoulders[0]).length+(wrist-elbow).length,8)})
        pose={b.name:b.matrix_basis.copy() for b in rig.pose.bones}
        spine=rig.pose.bones['spine_01']
        pose['spine_01']=spine.bone.matrix_local.inverted()@rig.data.bones['pelvis'].matrix_local@idle_pelvis.inverted()@spine.matrix
        pose['pelvis']=idle_basis.copy();poses.append(pose)
    baked=bpy.data.actions.new('Export_'+key);rig.animation_data.action=baked
    rig.animation_data.action_slot=baked.slots.new('OBJECT',rig.name)
    scene.render.fps=96;scene.render.fps_base=1;scene.frame_start,scene.frame_end=1,end
    for frame,pose in enumerate(poses,1):
        scene.frame_set(frame)
        for bone in rig.pose.bones:
            bone.matrix_basis=pose[bone.name];bone.rotation_mode='QUATERNION'
            for channel in ['rotation_quaternion','location','scale']:bone.keyframe_insert(data_path=channel,frame=frame,group=bone.name)
    for layer in baked.layers:
        for strip in layer.strips:
            for bag in strip.channelbags:
                for curve in bag.fcurves:
                    for point in curve.keyframe_points:point.interpolation='LINEAR'
    if rig.mode!='OBJECT':bpy.ops.object.mode_set(mode='OBJECT')
    bpy.ops.object.select_all(action='DESELECT');rig.select_set(True);bpy.data.objects['Mannequin'].select_set(True);bpy.context.view_layer.objects.active=rig
    scene.frame_set(1)
    bpy.ops.export_scene.gltf(filepath=str(out/filename),export_format='GLB',use_selection=True,export_animations=True,
        export_animation_mode='ACTIVE_ACTIONS',export_frame_range=True,export_frame_step=1,export_force_sampling=True,
        export_optimize_animation_size=False,export_rest_position_armature=True)
    metadata['clips'][key]={'action':name,'file':filename,'duration_seconds':(last-1)/24,
        'contact_seconds':(contact-1)/24 if contact else 0,'samples':samples}
    print('EXPORTED',key,flush=True)
assert all(digest(bpy.data.actions[name])==value for name,value in before.items())
assert hashlib.sha256(source.read_bytes()).hexdigest()==source_hash
(out/'staff_motion.json').write_text(motion_json(metadata)+'\n',encoding='utf8')
print('VERIFIED: saved review and all original actions unchanged',source_hash,flush=True)
