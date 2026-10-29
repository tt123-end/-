"""Track independent particles against the unchanged native head motion."""
from pathlib import Path
import json
import math
import xml.etree.ElementTree as E
import numpy as np
from PIL import Image
from scipy import ndimage as ndi

ROOT=Path(__file__).resolve().parents[1]
MOD=ROOT/'zzzz_revolver_samson'
GFX=MOD/'resources/gfx'


def main():
    actor=E.parse(GFX/'001.000_player_hunter_b_v153.anm2')
    neutral=json.loads((ROOT/'art_sources/head_landmarks176.json').read_text())['neutral']
    def world(frame,pose):
        sx=float(frame.get('XScale','100'))/100;sy=float(frame.get('YScale','100'))/100
        angle=math.radians(float(frame.get('Rotation','0')))
        x=(neutral[pose]['x']-float(frame.get('XPivot','0')))*sx
        y=(neutral[pose]['y']-float(frame.get('YPivot','0')))*sy
        return (float(frame.get('XPosition','0'))+x*math.cos(angle)-y*math.sin(angle),
                float(frame.get('YPosition','0'))+x*math.sin(angle)+y*math.cos(angle),sx,sy)
    defaults={}
    for direction,poses in [('Down',[0,1]),('Right',[2,3]),('Up',[4,5]),('Left',[2,3])]:
        frames=actor.findall(f"Animations/Animation[@Name='Head{direction}']/LayerAnimations/LayerAnimation[@LayerId='4']/Frame")
        for frame,pose in zip(frames,poses):defaults[direction,pose]=world(frame,pose)
    lines=['return {loops={']
    # Particle roots are independent now. Fit the existing droplets to the
    # registered Hunter eyes rather than inheriting the old costume offsets.
    crying=E.parse(GFX/'characters/hunter_art174/1.anm2')
    for animation in crying.findall('Animations/Animation'):
        name=animation.get('Name','')
        if not name.endswith('_Overlay'):continue
        x=1 if 'Right'in name else -1 if 'Left'in name else 0
        for root in animation.findall('RootAnimation/Frame'):
            root.set('XPosition',str(x));root.set('YPosition','-1')
        for frame in animation.findall('LayerAnimations/LayerAnimation/Frame'):
            frame.set('XScale','45')
    crying.write(GFX/'characters/hunter_art174/1.anm2',encoding='utf-8',xml_declaration=True)
    # The new integrated Boom head has its fuse in a different place from
    # Marisa's original. Register sparks to the visible orange fuse flame.
    boom=E.parse(GFX/'characters/hunter_art174/19.anm2')
    boom_head=E.parse(GFX/'001.000_player_hunter_b_v177_19.anm2')
    head_image=Image.open(GFX/'characters/hunter_art174/19.png').convert('RGBA')
    particle_image=Image.open(GFX/'characters/hunter_art174/loop_19_0.png').convert('RGBA')
    for direction in ['Down','Right','Up','Left']:
        frame=boom_head.find(f"Animations/Animation[@Name='Head{direction}']/LayerAnimations/LayerAnimation[@LayerId='4']/Frame")
        get=lambda key:float(frame.get(key,'0'))
        x,y,w,h=[int(get(key))for key in ['XCrop','YCrop','Width','Height']]
        pixels=np.asarray(head_image.crop((x,y,x+w,y+h)))
        r,g,b,a=[pixels[:,:,i].astype(float)for i in range(4)]
        rows=np.arange(h)[:,None]
        wy=get('YPosition')+(rows-get('YPivot'))*get('YScale')/100
        mask=(a>128)&(r>180)&(r>g*1.1)&(g>60)&(b<110)&(wy<-28)
        labels,_=ndi.label(mask);counts=np.bincount(labels.ravel());counts[0]=0
        assert counts.max()>5,(direction,'no trustworthy fuse landmark')
        yy,xx=np.where(labels==int(np.argmax(counts)))
        assert len(xx)>5,(direction,'no trustworthy fuse landmark')
        target_x=get('XPosition')+(float(xx.mean())-get('XPivot'))*get('XScale')/100
        target_y=get('YPosition')+(float(yy.mean())-get('YPivot'))*get('YScale')/100
        animation=boom.find(f"Animations/Animation[@Name='Head{direction}_Overlay']")
        particle=animation.find('LayerAnimations/LayerAnimation/Frame')
        val=lambda key:float(particle.get(key,'0'))
        px,py,pw,ph=[int(val(key))for key in ['XCrop','YCrop','Width','Height']]
        box=particle_image.crop((px,py,px+pw,py+ph)).getchannel('A').getbbox()
        source_x=val('XPosition')+((box[0]+box[2])/2-val('XPivot'))*val('XScale')/100
        source_y=val('YPosition')+((box[1]+box[3])/2-val('YPivot'))*val('YScale')/100
        for root in animation.findall('RootAnimation/Frame'):
            root.set('XPosition',str(round(target_x-source_x,4)))
            root.set('YPosition',str(round(target_y-source_y,4)))
    boom.write(GFX/'characters/hunter_art174/19.anm2',encoding='utf-8',xml_declaration=True)
    for item in [1,19,342]:
        path=GFX/f'characters/hunter_art174/{item}.anm2'
        durations={a.get('Name'):int(a.get('FrameNum'))for a in E.parse(path).findall('Animations/Animation')if a.get('Name').endswith('_Overlay')}
        lines.append('[%d]={%s},'%(item,','.join('[%s]=%s'%(json.dumps(k),v)for k,v in durations.items())))
    lines.append('},motion={')
    for animation in actor.findall('Animations/Animation'):
        samples=[]
        for frame in animation.findall("LayerAnimations/LayerAnimation[@LayerId='4']/Frame"):
            if frame.get('YCrop')!='0':continue
            column=int(frame.get('XCrop','-128'))//128
            pose={6:1,9:0,10:1}.get(column,column)
            if pose not in range(6):continue
            direction='Down'if pose<2 else'Up'if pose>=4 else'Left'if float(frame.get('XScale','1'))<0 else'Right'
            x,y,sx,sy=world(frame,pose);bx,by,bsx,bsy=defaults[direction,pose]
            value=[round(x-bx,6),round(y-by,6),round(abs(sx/bsx),6),round(abs(sy/bsy),6),float(frame.get('Rotation','0'))]
            samples.extend([value]*int(frame.get('Delay','1')))
        if samples:
            lines.append('[%s]={%s},'%(json.dumps(animation.get('Name')),','.join('{'+','.join(map(str,v))+'}'for v in samples)))
    lines.append('}}')
    (MOD/'hunter_effect_motion.lua').write_text('\n'.join(lines)+'\n')
    print('Compiled independent effect durations and native head-motion offsets.')


if __name__=='__main__':main()
