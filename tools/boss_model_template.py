"""Boss variant of the common enemy contract, with dedicated limbs and attack sockets.
Authored at world size: never apply the ordinary checkpoint guardian scale again.
"""
import math,random,bpy
from enemy_model_template import empty,blob,vine,petal,material,hex_rgb
def build(spec):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    root=empty('Enemy');base=empty('Base',root)
    bark=material('Wet ancient bark',(.07,.045,.038));wood=material('Exposed living wood',(.26,.17,.12))
    bone=material('Old host remains',(.48,.43,.33));leaf=material('Ancient foliage',(.025,.043,.018))
    core=material('Boss flesh',hex_rgb(spec['core']));glow=material('Corrupted sap',hex_rgb(spec['glow']),.7)
    form=spec['form'];height=5
    if form=='orchard':
        blob('EnemyCore',root,(0,0,2.5),(1.25,1.1,1.6),wood,3)
        rng=random.Random(8041)
        for i in range(6):
            a=i*math.tau/6+.13*math.sin(i*2);joint=empty('Root'+str(i),root,(math.cos(a)*.7,math.sin(a)*.7,1.8))
            vine('Walking root anchor',joint,[(0,0,0),(math.cos(a)*1.5,math.sin(a)*1.5,-.6),(math.cos(a+.12)*2.2,math.sin(a+.12)*2.2,-1.7)],.22,bark)
            for j in range(3):
                angle=a+(j-1)*.25
                vine('Split anchor roots',joint,[(math.cos(a)*1.2,math.sin(a)*1.2,-.5),(math.cos(angle)*2.0,math.sin(angle)*2,-1.35),(math.cos(angle)*2.7,math.sin(angle)*2.7,-1.75)],.09,wood)
            x=math.cos(a)*1.1;y=math.sin(a)*1.1;h=4.0+rng.random()*1.8
            vine('Grove trunk',base,[(x*.4,y*.4,1),(x,y,2.9),(x+.35,y-.2,h)],.25,bark)
            for j in range(5):
                b=a+j*1.6;dx=math.cos(b)*rng.uniform(.5,1.1);dy=math.sin(b)*rng.uniform(.5,1.1)
                z=h+rng.uniform(-.7,.5)
                vine('Crown branch',base,[(x,y,2.9),(x+dx*.6,y+dy*.6,z-.4),(x+dx,y+dy,z)],.085,wood)
                for k in range(3):
                    v=b+k*.8
                    vine('Fine orchard twigs',base,[(x+dx*.6,y+dy*.6,z-.3),(x+dx+math.cos(v)*.4,y+dy+math.sin(v)*.4,z+.2)],.025,bark)
                if j%2==0:
                    blob('Sparse leaf cluster',base,(x+dx,y+dy,z),(.4,.27,.18),leaf,3)
                    blob('Bitter hanging fruit',base,(x+dx,y+dy,z-.45),(.09,.09,.16),glow)
        height=6
    elif form=='drowned':
        blob('EnemyCore',root,(0,0,1.8),(.7,.7,1.1),glow,3)
        for i in range(7):
            a=i*math.tau/7;x=math.cos(a)*1.1;y=math.sin(a)*1.1
            joint=empty('Root'+str(i),root,(x,y,.3))
            blob('Drowned ribcage',joint,(0,0,1.65),(.24,.18,.5),core,3)
            blob('Sunken hips',joint,(0,0,.95),(.21,.18,.24),wood)
            blob('Drowned host skull',base,(x,y,2.7),(.18,.2,.27),bone,3)
            for s in [-1,1]:
                blob('Empty eye hollow',base,(x+s*.075,y-.17,2.76),(.04,.035,.055),bark)
                vine('Hanging host arm',joint,[(s*.18,0,1.9),(s*.35,-.05,1.2),(s*.4,-.2,.55)],.08,wood)
                vine('Trailed leg',joint,[(s*.1,0,.95),(s*.16,.08,.4),(s*.22,-.1,0)],.09,bark)
                for j in range(3):vine('Sodden fungal veil',base,[(x+s*.12,y,2.8),(x+s*(.22+j*.07),y-.02,2.1),(x+s*(.3+j*.1),y-.1,1.35)],.014,leaf)
            vine('Connected fungal cord',base,[(x,y,1.4),(x*.4,y*.4,1.1),(0,0,1.8)],.1,wood)
        height=3.8
    elif form=='matriarch':
        blob('EnemyCore',root,(0,.7,1.3),(1.1,1.7,.9),core,3)
        blob('Brood chamber',base,(0,1.3,1.5),(1.15,1.1,1),wood,3)
        blob('Hollow mother skull',base,(0,-1.2,1.5),(.55,.65,.6),bone,3)
        for i in range(8):
            s=-1 if i%2 else 1;y=-.9+i//2*.7
            joint=empty('Root'+str(i),root,(s*.65,y,1.1))
            vine('Nursery reshaping limb',joint,[(0,0,0),(s*1.1,-.25,.8),(s*1.65,-.6,-1.05)],.16,bark)
        for i in range(9):petal('Chitin bark plate',base,i*math.tau/9,2.3,1.3,.45,bark,1.1)
        height=3.4
    else:
        blob('EnemyCore',root,(0,0,2.5),(.6,.6,.9),glow,3)
        vine('Root spine',base,[(0,0,.1),(.2,0,1.3),(0,0,3.5)],.32,bark)
        for tier in range(3):
            for i in range(9):petal('Impossible flower',base,i*math.tau/9+tier*.35,3.5-tier*.55,1.6,.35,core,1.7-tier*.25,True)
        for i in range(7):
            a=i*math.tau/7;joint=empty('Root'+str(i),root,(math.cos(a)*.4,math.sin(a)*.4,1.5))
            vine('Seeking memory root',joint,[(0,0,0),(math.cos(a)*1.2,math.sin(a)*1.2,-.6),(math.cos(a)*2,math.sin(a)*2,-1.4)],.13,bark)
        height=5.5
    for i in range(3):empty('AttackSocket'+str(i),root,(0,-1-i*.5,height*.5))
    for name in ['Growth1','Growth2','AdaptReach','AdaptBark','AdaptSpore','AdaptMobility']:
        socket=empty(name,root)
        if name=='AdaptBark':
            for s in [-1,1]:blob('Remembered armor',socket,(s*.7,0,height*.45),(.4,.5,.9),bark)
        elif name=='AdaptSpore':
            for i in range(6):blob('Remembered spore',socket,(math.cos(i)*.8,math.sin(i)*.8,height*.6),(.2,.2,.3),glow)
        else:
            for s in [-1,1]:vine('Growing memory',socket,[(s*.4,0,height*.5),(s*1.2,0,height*.8),(s*1.6,-.3,height*.9)],.1,wood)
    return root
