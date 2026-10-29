"""Recover clipped face cells from complete source components (no redrawing)."""
from pathlib import Path
import json,re,subprocess
from PIL import Image
REPO=Path(__file__).resolve().parents[1];GFX=REPO/'zzzz_revolver_samson/resources/gfx'
ART=REPO/'art_sources';TMP=ART/'assembly/full_faces';TMP.mkdir(parents=True,exist_ok=True)
items=json.loads((ART/'items.json').read_text())
landmarks=json.loads((ART/'head_landmarks176.json').read_text())
# Only recover cells whose face actually meets the old clipping boundary.
targets={int(item)for item,poses in landmarks['outfits'].items()
         if any(p.get('method')=='skin-contour'and(p['y']>=112 or p.get('area',9999)<150)for p in poses[:4])}
def run(args):subprocess.run(['magick',*map(str,args)],check=True)
cache={}
for index,(item,_)in enumerate(items):
    if item not in targets:continue
    atlas=ART/f'atlas{index//4}.png';row=index%4
    w,h=Image.open(atlas).size;cleaned=[];boxes=[]
    for column in range(6):
        key=(index//4,column)
        raw=TMP/f'a{key[0]}c{column}.png'
        if key not in cache:
            left,right=round(column*w/6),round((column+1)*w/6)
            run([atlas,'-crop',f'{right-left}x{h}+{left}+0','+repage',raw])
            report=subprocess.run(['magick',str(raw),'-alpha','extract','-threshold','8%',
                '-define','connected-components:verbose=true','-connected-components','8','null:'],capture_output=True,text=True,check=True)
            parts=[]
            for line in (report.stdout+report.stderr).splitlines():
                match=re.search(r'^\s*(\d+):\s+(\d+)x(\d+)\+(\d+)\+(\d+)\s+[^ ]+\s+([\d.]+)\s+srgb\(255',line)
                if match:
                    identity,bw,bh,bx,by,area=map(float,match.groups())
                    if bw>(right-left)*.35 and bh>(right-left)*.4 and area>4000:
                        parts.append((area,int(by),int(identity),int(bh)))
            assert len(parts)>=4,(key,parts)
            cache[key]=(right-left,sorted(sorted(parts,reverse=True)[:4],key=lambda p:p[1]))
        width,parts=cache[key];_,top,identity,height=parts[row];boxes.append((top,top+height))
        mask=TMP/f'{item}_{column}_mask.png';clean=TMP/f'{item}_{column}_clean.png'
        run([raw,'-alpha','extract','-threshold','8%','-connected-components','8','-fx',f'round(u*quantumrange)=={identity}?1:0',mask])
        run([raw,'(',mask,'-alpha','copy',')','-compose','DstIn','-composite',clean]);cleaned.append((clean,width))
    top=min(a for a,b in boxes);bottom=max(b for a,b in boxes);poses=[]
    for column,(source,width)in enumerate(cleaned):
        pose=TMP/f'{item}_{column}.png'
        run([source,'-crop',f'{width}x{bottom-top}+0+{top}','+repage','-resize','128x104!',
            '-background','none','-gravity','north','-splice','0x12','-extent','128x128',pose]);poses.append(pose)
    base=GFX/'characters/costumes/hunter_b_heads_v152.png';args=[]
    for column in range(16):
        i={6:1,9:0,10:1}.get(column,column)
        args+=['(',poses[i],')']if column<6 or column in(6,9,10)else['(',base,'-crop',f'128x128+{column*128}+0','+repage',')']
    upper=TMP/f'{item}_upper.png';lower=TMP/'lower.png';run(args+['+append',upper])
    if not lower.exists():run([base,'-crop','2048x1920+0+128','+repage',lower])
    run([upper,lower,'-append',GFX/f'characters/hunter_art174/{item}.png'])
print('Recovered complete source faces:',sorted(targets))
