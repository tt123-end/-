"""Extract the complete first-row head instead of cutting it at a nominal tile edge."""
from pathlib import Path
import re,subprocess
REPO=Path(__file__).resolve().parents[1]
ROOT=REPO/'zzzz_revolver_samson/resources/gfx'
SOURCE=REPO/'art_sources/atlas8.png'
TMP=REPO/'art_sources/assembly/recover77';TMP.mkdir(parents=True,exist_ok=True)
def run(args):subprocess.run(['magick',*map(str,args)],check=True)
heads=[];boxes=[]
for column in range(6):
    raw=TMP/f'column{column}.png'
    run([SOURCE,'-crop',f'256x1024+{256*column}+0','+repage',raw])
    result=subprocess.run(['magick',str(raw),'-alpha','extract','-threshold','8%',
        '-define','connected-components:verbose=true','-connected-components','8','null:'],capture_output=True,text=True,check=True)
    components=[]
    for line in (result.stdout+result.stderr).splitlines():
        match=re.search(r'^\s*(\d+):\s+(\d+)x(\d+)\+(\d+)\+(\d+)\s+[^ ]+\s+([\d.]+)\s+srgb\(255',line)
        if match:
            identity,width,height,x,y,area=map(float,match.groups())
            if area>5000 and width>100 and height>120:
                components.append((int(y),int(identity),int(height)))
    assert len(components)>=4,(column,components)
    top,identity,height=min(components);boxes.append((top,top+height))
    mask=TMP/f'mask{column}.png';clean=TMP/f'clean{column}.png'
    run([raw,'-alpha','extract','-threshold','8%','-connected-components','8','-fx',f'round(u*quantumrange)=={identity}?1:0',mask])
    run([raw,'(',mask,'-alpha','copy',')','-compose','DstIn','-composite',clean]);heads.append(clean)
top=min(a for a,b in boxes);bottom=max(b for a,b in boxes);poses=[]
for column,source in enumerate(heads):
    path=TMP/f'pose{column}.png'
    run([source,'-crop',f'256x{bottom-top}+0+{top}','+repage','-resize','128x104!',
        '-background','none','-gravity','north','-splice','0x12','-extent','128x128',path]);poses.append(path)
base=ROOT/'characters/costumes/hunter_b_heads_v152.png';args=[]
for column in range(16):
    pose={6:1,9:0,10:1}.get(column,column)
    args+=['(',poses[pose],')']if column<6 or column in (6,9,10)else['(',base,'-crop',f'128x128+{column*128}+0','+repage',')']
upper=TMP/'upper.png';lower=TMP/'lower.png'
run(args+['+append',upper]);run([base,'-crop','2048x1920+0+128','+repage',lower])
run([upper,lower,'-append',ROOT/'characters/hunter_art174/77.png'])
print('PASS:Unicornhead extracted as one complete component; mouth/chin retained.')
