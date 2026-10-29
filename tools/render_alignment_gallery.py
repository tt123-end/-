"""Reproducible offline comparison with identical body and animation coordinates."""
import copy,json,subprocess,xml.etree.ElementTree as E
from pathlib import Path
from render_dynamic_preview import GFX,TMP,REPO,run,render,card
base=E.parse(GFX/'001.000_player_hunter_b_v153.anm2').getroot()
old=copy.deepcopy(base)
for animation in old.findall('Animations/Animation'):
    for frame in animation.findall("LayerAnimations/LayerAnimation[@LayerId='4']/Frame"):
        if frame.get('YCrop')=='0'and int(frame.get('XCrop','-1'))in [0,128,256,384,768,1152,1280]:
            frame.set('XPivot',str(float(frame.get('XPivot'))+8))
            frame.set('YPivot',str(float(frame.get('YPivot'))+7))
scenes=[('Normal',base,None),('v1.75',old,7)]
for label,item in [('Fixed crown',7),('Fixed eye',2)]:
    scenes.append((label,E.parse(GFX/f'001.000_player_hunter_b_v176_{item}.anm2').getroot(),item))
cards=[]
for label,actor,item in scenes:
    path=TMP/(label.replace(' ','_')+'comparison176.png')
    run(['-size','128x144','xc:#283832',path]);render(path,actor,GFX,'WalkDown',0)
    render(path,actor,GFX,'HeadDown',0,GFX/f'characters/hunter_art174/{item}.png'if item else None)
    run([path,'-font','DejaVu-Sans','-fill','white','-gravity','south','-pointsize','10','-annotate','+0+2',label,path]);cards.append(path)
subprocess.run(['magick','montage',*map(str,cards),'-tile','4x1','-geometry','+4+4','-background','#19231f',str(REPO/'deliverables/alignment-comparison.png')],check=True)
cards=[]
for item,_ in json.loads((REPO/'art_sources/items.json').read_text()):
    path=TMP/f'gallery176_{item}.png';card(item,'Down',0,path)
    run([path,'-font','DejaVu-Sans','-fill','white','-gravity','south','-pointsize','10','-annotate','+0+2',str(item),path]);cards.append(path)
subprocess.run(['magick','montage',*map(str,cards),'-tile','11x6','-geometry','+2+2','-background','#19231f',str(REPO/'deliverables/alignment-all-outfits.png')],check=True)
print('Rendered66outfits against one common body anchor; offline artwork, not game screenshots.')
