"""Pack generated, video-referenced feather art; no procedural redrawing.

Source wings are separate components. Register each at a shoulder joint,
using a shared physical scale per view, so changing pose never moves the root.
"""
from pathlib import Path
import json
import xml.etree.ElementTree as E
import numpy as np
from PIL import Image
from scipy import ndimage as ndi

ROOT=Path(__file__).resolve().parents[1]
MOD=ROOT/'zzzz_revolver_samson'
SOURCE=ROOT/'art_sources/wings179'
OUT=MOD/'resources/gfx/characters/hunter_wings179'
DELAYS=[10,7,3,10,5,5]
PALETTES={
    'guppy':[1.,.80,.89],
    'fly':[.58,1.,.86],
    'angel':[1.,.98,.91],
    'devil':[.73,.57,1.],
    'emerald':[.48,1.,.74],
}
DIRECTIONS=['Down','Right','Up','Left']


def components():
    pixels=np.asarray(Image.open(SOURCE/'feather-poses.png').convert('RGBA'))
    labels,_=ndi.label(pixels[:,:,3]>20,structure=np.ones((3,3)))
    counts=np.bincount(labels.ravel())
    boxes=ndi.find_objects(labels)
    grouped={}
    for identity,box in enumerate(boxes,1):
        if box is None or counts[identity]<300:continue
        yy,xx=np.where(labels[box]==identity)
        yy=yy+box[0].start;xx=xx+box[1].start
        row,col=int(yy.mean()//256),int(xx.mean()//256)
        mask=ndi.binary_dilation(labels==identity,iterations=2)
        image=pixels.copy();image[~mask]=0
        bounds=(box[1].start,box[0].start,box[1].stop,box[0].stop)
        assert bounds[0]>0 and bounds[1]>0 and bounds[2]<pixels.shape[1]and bounds[3]<pixels.shape[0],bounds
        grouped.setdefault((row,col),[]).append((Image.fromarray(image),bounds))
    for row in range(4):
        for col in range(6):
            grouped[row,col].sort(key=lambda entry:entry[1][0])
            assert len(grouped[row,col])==(2 if row in (0,2)else 1),(row,col)
    return grouped


def root_fraction(pose,left):
    # Native-looking articulated feather strokes: DOWN / folding / tucked /
    # UP behind the head / horizontal return / rounded downward recovery.
    if pose==3:return (.65 if left else .35),.92
    if pose==4:return (.94 if left else .06),.38
    return (.72 if left else .28),(.12 if pose==5 else .10)


def attributes(**values):
    result=dict(XPosition='0',YPosition='0',XScale='100',YScale='100',Delay='1',Visible='true',
                RedTint='255',GreenTint='255',BlueTint='255',AlphaTint='255',
                RedOffset='0',GreenOffset='0',BlueOffset='0',Rotation='0',Interpolated='false')
    result.update({key:str(value)for key,value in values.items()})
    return result


def main():
    OUT.mkdir(parents=True,exist_ok=True)
    grouped=components()
    sheet=Image.new('RGBA',(1536,1024))
    records=[]
    for row,direction in enumerate(DIRECTIONS):
        references=grouped[row,0]
        for pose in range(6):
            cell=Image.new('RGBA',(256,256))
            for part,(image,box)in enumerate(grouped[row,pose]):
                left=part==0 if row in (0,2)else row==1
                reference=references[part][1]
                sx=45/(reference[2]-reference[0])
                sy=42/(reference[3]-reference[1])
                fx,fy=root_fraction(pose,left)
                source_x=box[0]+fx*(box[2]-box[0])
                source_y=box[1]+fy*(box[3]-box[1])
                target_x=(104 if left else 152)if row in (0,2)else(116 if left else 140)
                target_y=128
                tx=target_x-source_x*sx;ty=target_y-source_y*sy
                packed=image.transform((256,256),Image.Transform.AFFINE,
                    (1/sx,0,-tx/sx,0,1/sy,-ty/sy),Image.Resampling.NEAREST)
                cell.alpha_composite(packed)
                records.append({'direction':direction,'pose':pose,'part':part,'source_bounds':box,
                    'source_root':[source_x,source_y],'joint':[target_x,target_y],
                    'scale':[sx,sy],'translation':[tx,ty]})
            bounds=cell.getchannel('A').point(lambda value:255 if value>20 else 0).getbbox()
            assert bounds and min(bounds[:2])>=56 and max(bounds[2:])<=200,(direction,pose,bounds)
            sheet.paste(cell,(pose*256,row*256))
    sheet.save(OUT/'feathers.png')
    actor=E.Element('AnimatedActor')
    E.SubElement(actor,'Info',CreatedBy='Hunter',Fps='30',Version='1')
    content=E.SubElement(actor,'Content')
    E.SubElement(E.SubElement(content,'Spritesheets'),'Spritesheet',Id='0',Path='feathers.png')
    E.SubElement(E.SubElement(content,'Layers'),'Layer',Id='0',Name='wings',SpritesheetId='0')
    E.SubElement(content,'Nulls');E.SubElement(content,'Events')
    animations=E.SubElement(actor,'Animations',DefaultAnimation='Down')
    for row,direction in enumerate(DIRECTIONS):
        animation=E.SubElement(animations,'Animation',Name=direction,FrameNum=str(sum(DELAYS)),Loop='true')
        E.SubElement(E.SubElement(animation,'RootAnimation'),'Frame',**attributes(Delay=sum(DELAYS)))
        layer=E.SubElement(E.SubElement(animation,'LayerAnimations'),'LayerAnimation',LayerId='0',Visible='true')
        for pose,delay in enumerate(DELAYS):
            E.SubElement(layer,'Frame',**attributes(XPivot=128,YPivot=128,XCrop=pose*256,YCrop=row*256,
                                                   Width=256,Height=256,Delay=delay))
        E.SubElement(animation,'NullAnimations');E.SubElement(animation,'Triggers')
    E.ElementTree(actor).write(OUT/'wings.anm2',encoding='utf-8',xml_declaration=True)
    config={'version':179,'frames':sum(DELAYS),'scale':.33,'delays':DELAYS,'colours':PALETTES,
            'actor':'gfx/characters/hunter_wings179/wings.anm2'}
    (SOURCE/'motion.json').write_text(json.dumps(config,indent=2)+'\n')
    (SOURCE/'registration.json').write_text(json.dumps(records,indent=2)+'\n')
    colours=',\n'.join('  [%s]={%s}'%(json.dumps(key),','.join(map(str,value)))for key,value in PALETTES.items())
    (MOD/'hunter_wing_motion.lua').write_text(
        'return {version=179,frames=%d,scale=.33,actor=%s,colours={\n%s\n}}\n'%
        (sum(DELAYS),json.dumps(config['actor']),colours))
    # Remove the rejected ornament/membrane/bat design from the install folder.
    legacy=MOD/'resources/gfx/characters/hunter_forms178'
    for path in legacy.glob('wings_*'):
        if path.suffix in ('.png','.anm2'):path.unlink()
    print('Built compact native-style feathers: 4views,6strokes,40ticks;36fixed-root components and4form palettes.')


if __name__=='__main__':main()
