"""Geometry-only alignment; artwork and the neutral actor remain unchanged."""
from pathlib import Path
import xml.etree.ElementTree as E

ROOT=Path(__file__).resolve().parents[1]/'zzzz_revolver_samson/resources/gfx'
tree=E.parse(ROOT/'001.000_player_hunter_b_v153.anm2')
shifted={0,128,256,384,768,1152,1280}
for animation in tree.findall('Animations/Animation'):
    for frame in animation.findall("LayerAnimations/LayerAnimation[@LayerId='4']/Frame"):
        if frame.get('YCrop')=='0' and int(frame.get('XCrop','-1'))in shifted:
            frame.set('XPivot',str(float(frame.get('XPivot','0'))+8))
            frame.set('YPivot',str(float(frame.get('YPivot','0'))+7))
tree.write(ROOT/'001.000_player_hunter_b_v175.anm2',encoding='utf-8',xml_declaration=True)
for item in (1,19,342):
    path=ROOT/f'characters/hunter_art174/{item}.anm2'
    tree=E.parse(path)
    for animation in tree.findall('Animations/Animation'):
        name=animation.get('Name','')
        if not name.endswith('_Overlay'):continue
        for frame in animation.findall('RootAnimation/Frame'):
            frame.set('XPosition',str(0 if 'Up'in name else 2.64 if 'Left'in name else -2.64))
            frame.set('YPosition',str(0 if 'Up'in name else -2.31))
    tree.write(path,encoding='utf-8',xml_declaration=True)

# The clone differs ONLY in head pivots for the replacement artwork's cells.
base=E.parse(ROOT/'001.000_player_hunter_b_v153.anm2')
aligned=E.parse(ROOT/'001.000_player_hunter_b_v175.anm2')
changed=0
for a,b in zip(base.iter(),aligned.iter()):
    if a.attrib==b.attrib:continue
    assert a.tag==b.tag=='Frame'
    assert set(k for k in a.attrib if a.get(k)!=b.get(k))=={'XPivot','YPivot'}
    assert float(b.get('XPivot'))-float(a.get('XPivot'))==8
    assert float(b.get('YPivot'))-float(a.get('YPivot'))==7
    changed+=1
assert changed==48,changed
print('PASS:48head pivots corrected; neutral actor, body, timing, back views and artwork unchanged.')
