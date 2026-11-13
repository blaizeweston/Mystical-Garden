"""New silhouettes using the common organic mesh and animation-socket kit."""
import math
from enemy_model_template import blob,vine,petal,empty,radial_roots
def build_form(form,root,base,m):
    bark,wood,leaf,bone,fungus,core,glow=m
    if form=='burrower':
        blob('EnemyCore',root,(0,0,.4),(.35,.95,.3),wood,3)
        for i in range(7):
            y=-.9+i*.28
            blob('Segmented earth armor',base,(0,y,.4),(.39,.18,.29),bark)
            for s in [-1,1]:vine('Digging claw',base,[(s*.22,y,.35),(s*.55,y-.15,.16),(s*.65,y-.35,.04)],.08,bone)
        for s in [-1,1]:vine('Splitting mandible',base,[(s*.16,-.8,.3),(s*.3,-1.3,.2),(s*.1,-1.5,.25)],.12,bone)
        return 1.0
    if form=='widow':
        blob('EnemyCore',root,(0,.3,.7),(.38,.6,.4),fungus,3)
        blob('Veiled head',base,(0,-.48,.7),(.22,.25,.25),bone)
        for i in range(8):
            s=-1 if i%2 else 1;y=-.4+(i//2)*.28
            joint=empty('Root'+str(i),root,(s*.25,y,.65))
            vine('Articulated root leg',joint,[(0,0,0),(s*.65,.1,.4),(s*1.0,-.15,-.6)],.07,bark)
            vine('Hanging spore thread',base,[(s*.35,y,.75),(s*.72,y-.1,.3),(s*.9,y-.2,.06)],.012,glow)
        for i in range(5):blob('Egg sac',base,((i%2-.5)*.35,.2+i*.12,.85),(.13,.18,.2),core)
        return 1.3
    if form=='pallbearer':
        radial_roots(base,bark,8,1,.7)
        vine('Funeral stem',base,[(0,0,.2),(.1,0,1.2),(0,0,2.1)],.18,bark)
        blob('EnemyCore',root,(0,0,1.6),(.32,.28,.5),core)
        for i in range(7):petal('Funeral shroud',base,i*math.tau/7,2.1,1.4,.35,leaf,.8)
        for s in [-1,1]:
            vine('Pall bearing arm',base,[(s*.2,0,1.7),(s*.7,0,1.5),(s*.85,-.2,1.85)],.12,wood)
            blob('Carried host skull',base,(s*.8,-.2,1.75),(.17,.2,.23),bone)
        return 2.4
    if form=='thief':
        blob('EnemyCore',root,(0,0,.6),(.25,.45,.32),wood,3)
        blob('Hunched seed sack',base,(0,.25,.92),(.36,.45,.44),leaf,3)
        blob('Rat host skull',base,(0,-.4,.75),(.18,.3,.18),bone)
        for i in range(4):
            s=-1 if i%2 else 1;y=-.25 if i<2 else .3
            joint=empty('Root'+str(i),root,(s*.18,y,.4))
            vine('Thieving limb',joint,[(0,0,0),(s*.15,-.1,-.17),(s*.22,-.3,-.38)],.065,bark)
        vine('Long grasping tail',base,[(0,.3,.6),(.25,1,.4),(.65,1.2,.15),(.8,.9,.1)],.07,bark)
        return 1.4
    if form=='ashen_hart':
        blob('EnemyCore',root,(0,.1,1.2),(.36,.7,.38),bark,3)
        vine('Burned neck',base,[(0,-.4,1.2),(0,-.65,1.9),(0,-.8,2.0)],.22,wood)
        blob('Charred skull',base,(0,-.85,2),(.22,.35,.22),bone)
        for i in range(4):
            s=-1 if i%2 else 1;y=-.35 if i<2 else .55
            joint=empty('Root'+str(i),root,(s*.23,y,.95))
            vine('Charred hoof',joint,[(0,0,0),(s*.08,.08,-.5),(s*.04,-.2,-.9)],.095,bark)
        for s in [-1,1]:
            vine('Cinder antler',base,[(s*.1,-.8,2.1),(s*.4,-.6,2.55),(s*.75,-.55,3.0)],.09,wood)
            for j in range(4):
                vine('Burning tine',base,[(s*(.25+j*.12),-.62,2.4+j*.1),(s*(.27+j*.18),-.85,2.8+j*.15)],.04,bone)
                blob('Ember blossom',base,(s*(.27+j*.18),-.85,2.8+j*.15),(.07,)*3,glow)
        return 3.1
    if form=='glasscap':
        radial_roots(base,bark,5,.7,.3)
        vine('Translucent stem',base,[(0,0,.1),(.1,.1,1.1),(0,0,1.8)],.16,fungus)
        blob('EnemyCore',root,(0,0,1.6),(.24,.24,.4),glow)
        for i in range(11):
            a=i*math.tau/11
            petal('Prismatic gill',base,a,1.9,.7,.19,core,.9)
            vine('Glass rib',base,[(0,0,2.1),(math.cos(a)*.7,math.sin(a)*.7,1.95),(math.cos(a)*1.0,math.sin(a)*1.0,1.55)],.023,bone)
        return 2.3
    if form=='choir':
        radial_roots(base,bark,8,1.0,.3)
        blob('EnemyCore',root,(0,0,.45),(.5,.35,.32),wood)
        for i in range(3):
            x=(i-1)*.55;h=1.6+(.4 if i==1 else 0)
            joint=empty('Root'+str(i),root,(x,0,.3))
            vine('Shared throat',joint,[(0,0,0),(x*.1,0,.7),(0,0,h-.3)],.13,wood)
            blob('Choir skull',base,(x,0,h),(.24,.2,.31),bone)
            blob('Open singing hollow',base,(x,-.18,h-.05),(.1,.04,.17),bark)
            blob('Vocal light',base,(x,-.19,h-.05),(.04,.02,.08),glow)
        return 2.4
    raise ValueError(form)
