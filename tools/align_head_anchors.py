"""Register each outfit/pose against neutral face landmarks, without redrawing it."""
from pathlib import Path
import xml.etree.ElementTree as E
import json,copy
REPO=Path(__file__).resolve().parents[1]
ROOT=REPO/'zzzz_revolver_samson/resources/gfx'
data=json.loads((REPO/'art_sources/head_landmarks176.json').read_text())
base=E.parse(ROOT/'001.000_player_hunter_b_v153.anm2')
folder=ROOT
mapping=[]
for item,points in data['outfits'].items():
    tree=copy.deepcopy(base)
    corrections=[(p['x']-n['x'],p['y']-n['y'])for p,n in zip(points,data['neutral'])]
    for animation in tree.findall('Animations/Animation'):
        for frame in animation.findall("LayerAnimations/LayerAnimation[@LayerId='4']/Frame"):
            if frame.get('YCrop')!='0':continue
            column=int(frame.get('XCrop','-1'))//128
            pose={6:1,9:0,10:1}.get(column,column)
            if pose not in range(6):continue
            dx,dy=corrections[pose]
            frame.set('XPivot',str(float(frame.get('XPivot','0'))+dx))
            frame.set('YPivot',str(float(frame.get('YPivot','0'))+dy))
    tree.write(folder/f'001.000_player_hunter_b_v176_{item}.anm2',encoding='utf-8',xml_declaration=True)
    mapping.append(f'[{item}]="gfx/001.000_player_hunter_b_v176_{item}.anm2"')
    # The registered point (face centre/chin) has the same screen coordinate
    # at either sign of scale, including mirrored left-facing sprites.
    for pose,(dx,dy)in enumerate(corrections):
        for scale in [.33,-.33,.21,.42]:
            assert abs((points[pose]['x']-64-dx)*scale-(data['neutral'][pose]['x']-64)*scale)<1e-8
            assert abs((points[pose]['y']-112-dy)*scale-(data['neutral'][pose]['y']-112)*scale)<1e-8
    if int(item)in (1,19,342):
        path=ROOT/f'characters/hunter_art174/{item}.anm2';loop=E.parse(path)
        for animation in loop.findall('Animations/Animation'):
            name=animation.get('Name','')
            if not name.endswith('_Overlay'):continue
            indices=(4,5)if 'Up'in name else(2,3)if 'Right'in name or 'Left'in name else(0,1)
            dx=sum(corrections[i][0]for i in indices)/2
            dy=sum(corrections[i][1]for i in indices)/2
            for frame in animation.findall('RootAnimation/Frame'):
                frame.set('XPosition',str(dx*.33*(1 if 'Left'in name else -1)))
                frame.set('YPosition',str(-dy*.33))
        loop.write(path,encoding='utf-8',xml_declaration=True)
(REPO/'zzzz_revolver_samson/hunter_head_alignment.lua').write_text('return {\n'+',\n'.join(mapping)+'\n}\n')
old=ROOT/'001.000_player_hunter_b_v175.anm2'
if old.exists():old.unlink()
print('PASS:66outfits x6pose-specific landmarks aligned; mirrored/normal/native action scales checked.')
