"""Blender: bake shared-rig, weapon-specific two-arm poses into portable actions.

The mesh weights and 25 deformation bones remain stable. Analytic two-bone IK
places wrists; resulting local bone rotations are keyed (no runtime IK dependency).
"""
from math import sin, cos, pi, sqrt
import bpy
from mathutils import Vector, Matrix

def smooth(value):
    t=max(0,min(1,value));return t*t*(3-2*t)

def orient(bone,head,tail,plane=None,rest_plane=None):
    rest=bone.bone.matrix_local.to_3x3();direction=(Vector(tail)-Vector(head)).normalized()
    if plane is None:
        matrix=(rest.col[1].normalized().rotation_difference(direction).to_matrix()@rest).to_4x4()
    else:
        # Resolve twist from the elbow bend plane, not a rest-to-direction
        # quaternion that becomes singular when a forearm points upward.
        def frame(axis,normal):
            x=normal.normalized();y=axis.normalized();z=x.cross(y).normalized()
            return Matrix((x,y,z)).transposed()
        rest_frame=frame(rest.col[1],rest_plane)
        matrix=(frame(direction,plane)@rest_frame.transposed()@rest).to_4x4()
    matrix.translation=Vector(head);bone.matrix=matrix

def arm_ik(rig,side,wrist,pole):
    upper=rig.pose.bones['upper_arm.'+side];fore=rig.pose.bones['forearm.'+side]
    hand=rig.pose.bones['hand.'+side];wrist=Vector(wrist)+Vector((0,0,.045));bpy.context.view_layer.update()
    shoulder=upper.head.copy();target=Vector(wrist);direction=target-shoulder
    first=upper.bone.length;second=fore.bone.length
    distance=max(abs(first-second)+.004,min(direction.length,first+second-.004))
    direction.normalize();target=shoulder+direction*distance
    bend=Vector(pole)-shoulder;bend-=direction*bend.dot(direction)
    if bend.length<.001:bend=Vector((1,0,0))
    bend.normalize();along=(first*first-second*second+distance*distance)/(2*distance)
    elbow=shoulder+direction*along+bend*sqrt(max(0,first*first-along*along))
    normal=(elbow-shoulder).cross(target-elbow).normalized()
    rest_plane=upper.bone.matrix_local.col[1].xyz.cross(fore.bone.matrix_local.col[1].xyz).normalized()
    orient(upper,shoulder,elbow,normal,rest_plane);bpy.context.view_layer.update()
    orient(fore,elbow,target,normal,rest_plane);bpy.context.view_layer.update()
    # Fingers close around the grip; hand alignment remains bone-relative.
    orient(hand,target,target+Vector((0,0,-.09)))
    rig.pose.bones['fingers.'+side].rotation_euler.x=.45
    rig.pose.bones['thumb.'+side].rotation_euler.x=.25

def targets(form,t,release,ready=False):
    if ready:
        r=Vector((-.23,-.10,1.02));l=Vector((.24,-.03,.91));yaw=0
        if form=='bow':l=Vector((.12,-.30,1.18));r=l+Vector((0,.20*.9,0))
        elif form=='crossbow':r=Vector((-.12,-.27,1.14));l=r+Vector((0,-.20,-.02))
        elif form in ['hammer','scythe','staff','spear']:
            r=Vector((-.16,-.22,1.18));axis=Vector((0,-1,0)) if form=='spear' else Vector((0,0,1))
            l=r-axis*({'spear':.17,'hammer':.12,'scythe':.16,'staff':.18}[form]*.9)
        elif form=='orb':r=Vector((-.13,-.23,1.20));l=Vector((.13,-.23,1.20))
        elif form=='knives':l=Vector((.23,-.10,1.02))
        elif form in ['bell','censer']:r=Vector((-.18,-.18,1.12))
        elif form=='fan':r=Vector((-.20,-.18,1.10))
        return r,l,yaw
    draw=smooth(t/release) if t<release else 1-smooth((t-release)/(1-release))
    anticipation=smooth(t/max(.01,release*.65))
    strike=smooth((t-release*.65)/max(.01,release*.7))
    recovery=1-smooth((t-.72)/.28)
    pulse=sin(pi*t) if not ready else .12
    r=Vector((-.20,-.26,1.17));l=Vector((.20,-.24,1.17));yaw=0
    if form=='bow':
        l=Vector((.12,-.46,1.42));r=l+Vector((0,(.20+.25*draw)*.9,0));yaw=-.08*draw
    elif form=='crossbow':
        r=Vector((-.12,-.30,1.18));l=Vector((-.12,-.50,1.16));r.y+=.06*max(0,1-abs(t-release)/.09)
        if t>release+.12:l=l.lerp(Vector((.08,-.28,1.12-.10*sin((t-release)*pi))),smooth((t-release-.12)/.12))
    elif form in ['blade','knives','scythe','hammer']:
        span={'blade':1.9,'knives':1.3,'scythe':2.7,'hammer':2.1}[form]
        angle=-span*.5+span*strike
        radius=.34 if form=='knives' else .24 if form in ['hammer','scythe'] else .39
        r=Vector((sin(angle)*radius,-cos(angle)*radius,1.25+(.18 if form=='hammer' else .04)*sin(pi*t)))
        if form=='scythe':r.y-=.12  # Keep support wrist clear of the shoulder singularity.
        yaw=.18*sin(angle)*recovery
        if form in ['hammer','scythe']:l=r+Vector((0,.10,-.03))
        elif form=='knives':l=Vector((-r.x,-.30,1.18+.06*pulse))
        else:l=Vector((.22,.02,1.17))
    elif form in ['spear','whip']:
        extension=draw if form=='spear' else smooth(t/release) if t<release else 1-smooth((t-release)/(1-release))
        r=Vector((-.11,-.20-.22*extension,1.18+.05*pulse))
        l=Vector((-.11,-.27,1.18)) if form=='spear' else Vector((.22,.01,1.17))
        yaw=.06 if form=='spear' else -.12*pulse
    elif form in ['staff','wand','orb','fan','ring']:
        if form=='orb':r=Vector((-.13,-.23-.17*draw,1.30));l=Vector((.13,r.y,1.30))
        elif form=='staff':r=Vector((-.17,-.27-.11*draw,1.23));l=Vector((-.15,-.29,1.12))
        elif form=='wand':r=Vector((-.13,-.27-.15*draw,1.25));l=Vector((.23,.01,1.17))
        else:
            angle=-.7+1.4*strike
            if form=='fan':r=Vector((-.10+sin(angle)*.16,-.34,1.29));l=Vector((.21,-.05,1.15));yaw=-.1*draw
            else:r=Vector((sin(angle)*.38,-cos(angle)*.38,1.23));l=Vector((.22,.02,1.18));yaw=.13*sin(angle)
    elif form=='bell':r=Vector((-.14,-.27,1.28-.14*draw));l=Vector((.16,-.22,1.17))
    elif form=='censer':r=Vector((-.16+.10*sin(t*pi*2),-.29,1.34));l=Vector((.19,-.12,1.20));yaw=.10*pulse
    if form in ['spear','hammer','scythe','staff']:
        strength=smooth(t/(release*.6))*(1-smooth((t-.72)/.28)) if not ready else 0
        if form=='spear':axis=Vector((0,-1,0))
        elif form=='staff':axis=Vector((0,-sin(strength*pi/2),cos(strength*pi/2)))
        else:
            span={'hammer':2.1,'scythe':2.7}[form];angle=-span*.5+span*min(1,t/(release*2))
            axis=Vector((sin(angle)*sin(strength*pi/2),-cos(angle)*sin(strength*pi/2),cos(strength*pi/2)))
        l=r-axis*({'spear':.17,'hammer':.12,'scythe':.16,'staff':.18}[form]*.9)
    if t<.12:
        rr,ll,yy=targets(form,0,release,True);blend=smooth(t/.12)
        r=rr.lerp(r,blend);l=ll.lerp(l,blend);yaw=yy*(1-blend)+yaw*blend
    return r,l,yaw

def author(rig,profiles):
    actions=[];rig.animation_data_create()
    for form,profile in profiles.items():
        entries=[(profile['ready'],form,True),(profile['clip'],form,False)]
        for delivery,clip in profile.get('variants',{}).items():
            pose_kind='spear' if delivery=='line' and profile['delivery']!='radial' else ('scythe' if form=='spear' else 'blade') if delivery=='sweep' and profile['delivery']=='line' else form
            entries.append((clip,pose_kind,False))
        for name,pose_kind,ready in entries:
            action=bpy.data.actions.new(name);action.use_fake_user=True;rig.animation_data.action=action
            action.pose_markers.new('contact').frame=round(profile['release']*60)+1
            previous={}
            for frame in range(1,62):
                t=(frame-1)/60
                bpy.context.scene.frame_set(frame)
                for bone in rig.pose.bones:
                    bone.rotation_mode='XYZ';bone.rotation_euler=(0,0,0);bone.location=(0,0,0);bone.scale=(1,1,1)
                r,l,yaw=targets(pose_kind,t,profile['release'],ready)
                if not ready and t>.72:
                    rr,ll,yy=targets(pose_kind,0,profile['release'],True);recovery=smooth((t-.72)/.28)
                    r=r.lerp(rr,recovery);l=l.lerp(ll,recovery);yaw=yaw*(1-recovery)+yy*recovery
                rig.pose.bones['chest'].rotation_euler.z=yaw
                bpy.context.view_layer.update()
                arm_ik(rig,'R',r,(-.33,.10,.92));arm_ik(rig,'L',l,(.33,.10,.92))
                for bone in rig.pose.bones:
                    if bone.name in previous:bone.rotation_euler.make_compatible(previous[bone.name])
                    previous[bone.name]=bone.rotation_euler.copy()
                    bone.keyframe_insert(data_path='rotation_euler',frame=frame)
            actions.append(action)
    rig.animation_data.action=None
    for bone in rig.pose.bones:bone.rotation_euler=(0,0,0)
    return actions
