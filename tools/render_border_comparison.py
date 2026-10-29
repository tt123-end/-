"""Compare the previous clipping rectangle with the padded source frames."""
import copy,json,subprocess,xml.etree.ElementTree as E
from render_dynamic_preview import REPO,GFX,TMP,run,render
landmarks=json.loads((REPO/'art_sources/head_landmarks176.json').read_text())
base=E.parse(GFX/'001.000_player_hunter_b_v153.anm2').getroot();cards=[]
for item in [91,82,118]:
    old=copy.deepcopy(base)
    points=landmarks['outfits'][str(item)]
    for animation in old.findall('Animations/Animation'):
        for frame in animation.findall("LayerAnimations/LayerAnimation[@LayerId='4']/Frame"):
            column=int(frame.get('XCrop','-128'))//128;pose={6:1,9:0,10:1}.get(column,column)
            if frame.get('YCrop')!='0'or pose not in range(6):continue
            dx=points[pose]['x']-landmarks['neutral'][pose]['x'];dy=points[pose]['y']-landmarks['neutral'][pose]['y']
            frame.set('XPivot',str(float(frame.get('XPivot'))+dx));frame.set('YPivot',str(float(frame.get('YPivot'))+dy))
    new=E.parse(GFX/f'001.000_player_hunter_b_v177_{item}.anm2').getroot()
    for label,actor in [('Before',old),('Restored',new)]:
        path=TMP/f'border_{item}_{label}.png';run(['-size','128x144','xc:#283832',path])
        render(path,actor,GFX,'WalkDown',0)
        render(path,actor,GFX,'HeadDown',0,GFX/f'characters/hunter_art174/{item}.png')
        run([path,'-font','DejaVu-Sans','-fill','white','-gravity','south','-pointsize','10','-annotate','+0+2',f'{item} {label}','-resize','256x288',path]);cards.append(path)
subprocess.run(['magick','montage',*map(str,cards),'-tile','2x3','-geometry','+4+4','-background','#19231f',str(REPO/'deliverables/border-comparison.png')],check=True)
print('Rendered miner, wing and horn border comparisons; offline ANM2 composition.')
