"""Measure the face contour, excluding headwear, for coordinate registration.

This analyses pixels; it does not redraw or rescale illustrations. Occluded
landmarks are explicitly recorded instead of treating headwear as face skin.
"""
from pathlib import Path
from collections import deque
import json
from PIL import Image

REPO=Path(__file__).resolve().parents[1]
GFX=REPO/'zzzz_revolver_samson/resources/gfx'
def measure(image,pose):
    pixels=image.crop((pose*128,0,(pose+1)*128,128)).convert('RGBA').load()
    skin=set()
    for y in range(55,117):
        for x in range(24,119):
            r,g,b,a=pixels[x,y]
            if a>128 and 1.1*g<r<1.85*g and .45*g<b<.92*g and r>140 and 80<g<210:
                skin.add((x,y))
    candidates=[]
    while skin:
        first=skin.pop();queue=deque([first]);points=[first]
        while queue:
            x,y=queue.popleft()
            for p in ((x-1,y),(x+1,y),(x,y-1),(x,y+1)):
                if p in skin:skin.remove(p);queue.append(p);points.append(p)
        xs,ys=zip(*points);left,right=min(xs),max(xs);cx=(left+right)/2
        if len(points)<150 or right-left<(30 if pose<2 else 20):continue
        if not ((40<=cx<=90)if pose<2 else(75<=cx<=116)):continue
        candidates.append((len(points),cx,max(ys)))
    if not candidates:raise ValueError(f'No trustworthy face contour, pose{pose}')
    area,x,y=max(candidates)
    return {'x':x,'y':y,'area':area,'method':'skin-contour'}

base=Image.open(GFX/'characters/costumes/hunter_b_heads_v152.png')
neutral=[measure(base,i)for i in range(4)]+[{'x':64,'y':116,'method':'back-frame'}]*2
outfits={}
for path in sorted((GFX/'characters/hunter_art174').glob('*.png')):
    if not path.stem.isdigit():continue
    image=Image.open(path);item=int(path.stem)
    if item==92:
        # Mouth/chin is covered by the bandage. Measure the enclosing face
        # outline rather than the exposed patch around one eye.
        points=[(69,107),(67,106),(96,104),(89.5,105)]
        poses=[{'x':x,'y':y,'method':'bandage-face-outline'}for x,y in points]
    else:poses=[measure(image,i)for i in range(4)]
    poses += [{'x':64,'y':116,'method':'back-frame'}]*2
    outfits[str(item)]=poses
assert len(outfits)==66
result={'version':176,'neutral':neutral,'outfits':outfits}
(REPO/'art_sources/head_landmarks176.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
for item in ['1','2','7','77','91','92','93']:
    shifts=[(p['x']-b['x'],p['y']-b['y'])for p,b in zip(outfits[item],neutral)]
    print(item,shifts)
