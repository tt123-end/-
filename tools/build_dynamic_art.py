"""Assemble generated directional artwork into the existing Hunter animation layout.

This is sprite extraction/asset assembly; illustration is provided by the new
image-generation atlases. No drawn content from the rejected 1.73 pack is used.
"""
from pathlib import Path
import copy,json,re,shutil,subprocess,sys
import xml.etree.ElementTree as E
from PIL import Image

REPO=Path(__file__).resolve().parents[1]
MOD=REPO/'zzzz_revolver_samson'
WORK=Path(sys.argv[1]) if len(sys.argv)>1 else REPO/'art_sources'
REF=Path('/workspace/marisa-review/marisacain_2825019716')
BASE=MOD/'resources/gfx/characters/costumes/hunter_b_heads_v152.png'
OUT=MOD/'resources/gfx/characters/hunter_art174'
OUT.mkdir(parents=True,exist_ok=True)
TEMP=WORK/'assembly';TEMP.mkdir(exist_ok=True)
items=json.loads((WORK/'items.json').read_text())
oldManifest=(MOD/'hunter_costume_manifest.lua').read_text()
zh={int(id):text for id,text in re.findall(r'id=(\d+).*?zh="([^"]*)"',oldManifest)}
def run(args):subprocess.run(['magick',*map(str,args)],check=True)

def build_item(id,atlas,row):
    if (OUT/f'{id}.png').exists():return
    im=Image.open(atlas).convert('RGBA');w,h=im.size
    # Detect alpha only: transparent pixels may carry arbitrary RGB background.
    # A shared vertical crop across all six poses avoids animation size pumping.
    boxes=[];cleaned=[]
    for col in range(6):
        x0,x1=round(col*w/6),round((col+1)*w/6)
        y0,y1=round(row*h/4),round((row+1)*h/4)
        raw=TEMP/f'{id}_{col}_raw.png'
        mask=TEMP/f'{id}_{col}_mask.png'
        clean=TEMP/f'{id}_{col}_clean.png'
        run([atlas,'-crop',f'{x1-x0}x{y1-y0}+{x0}+{y0}','+repage',raw])
        report=subprocess.run(['magick',str(raw),'-alpha','extract','-threshold','8%',
            '-define','connected-components:verbose=true','-connected-components','8','null:'],
            check=True,capture_output=True,text=True)
        component=re.search(r'^\s*(\d+):\s+(\d+)x(\d+)\+(\d+)\+(\d+).*?srgb\(255',
                            report.stdout+report.stderr,re.M)
        if not component:raise ValueError(f'No main head component: {id}/{col}')
        identity,bw,bh,bx,by=map(int,component.groups())
        boxes.append((bx,by,bx+bw,by+bh))
        # Keep only the actual contiguous head. Adjacent-row collars/skull
        # slivers in generated atlases are extraction noise, not accessory art.
        run([raw,'-alpha','extract','-threshold','8%','-connected-components','8',
             '-fx',f'round(u*quantumrange)=={identity}?1:0',mask])
        run([raw,'(',mask,'-alpha','copy',')','-compose','DstIn','-composite',clean])
        cleaned.append(clean)
    top=min(b[1]for b in boxes);bottom=min(max(b[3]for b in boxes),round(h/4)-14)
    pieces=[]
    for col in range(6):
        x0,x1=round(col*w/6),round((col+1)*w/6)
        y0=top
        cell=TEMP/f'{id}_{col}.png'
        # Shared frame size and fixed top/chin anchoring. Whole-head variants
        # include their own hair/hood occlusion instead of stacking accessories.
        run([cleaned[col],'-crop',f'{x1-x0}x{bottom-top}+0+{y0}','+repage',
             '-resize','128x104!','-background','none','-gravity','north',
             '-splice','0x12','-gravity','north','-extent','128x128','-background','none','-alpha','background',cell])
        pieces.append(cell)
    strip=TEMP/f'{id}_strip.png';run([*pieces,'+append',strip])
    right=TEMP/'right.png';below=TEMP/'below.png'
    if not right.exists():run([BASE,'-crop','1280x128+768+0','+repage',right])
    if not below.exists():run([BASE,'-crop','2048x1920+0+128','+repage',below])
    upper=TEMP/f'{id}_top.png';run([strip,right,'+append',upper])
    run([upper,below,'-append',OUT/f'{id}.png'])

# Cached head sheets still need the untouched lower atlas during action assembly.
if not (TEMP/'below.png').exists():
    run([BASE,'-crop','2048x1920+0+128','+repage',TEMP/'below.png'])
complete=[]
for i,(id,label)in enumerate(items):
    source=WORK/f'atlas{i//4}.path'
    if not source.exists():continue
    atlas=Path(source.read_text().strip())
    if not atlas.is_absolute():atlas=WORK/atlas
    build_item(id,atlas,i%4);complete.append(id)

# Retain the outfit through native Hit/Pickup/Lift/Use animation crops.
# Only the head textures change: all original motion curves remain untouched.
for id in complete:
    output=OUT/f'{id}.png'
    args=[]
    for target in range(16):
        pose={6:1,9:0,10:1}.get(target,target)
        source=output if target<6 or target in (6,9,10) else BASE
        args+=['(',source,'-crop',f'128x128+{pose*128}+0','+repage',')']
    upper=TEMP/f'{id}_action_top.png'
    run(args+['+append',upper])
    run([upper,TEMP/'below.png','-append',output])

# Copy only independent loop particles from the reference. Do NOT copy the
# reference face or its static costume layers into Hunter's head.
for id,name in [(1,'m1_the_marisad_onion.anm2'),(19,'019_boom.anm2'),(342,'342_blue cap.anm2')]:
    source=WORK/'reference_loops'/name
    if not source.exists():source=REF/'resources/gfx/characters'/name
    actor=E.parse(source).getroot()
    used=set()
    for a in actor.findall('Animations/Animation'):
        if not a.get('Name','').endswith('_Overlay'):
            for la in a.findall('LayerAnimations/LayerAnimation'):
                for f in list(la):la.remove(f)
        else:
            for la in a.findall('LayerAnimations/LayerAnimation'):
                if la.findall('Frame'):used.add(la.get('LayerId'))
            for f in a.findall('LayerAnimations/LayerAnimation/Frame'):
                # Original reference particles are tiny, not enlarged jewelry.
                f.set('YPosition',str(float(f.get('YPosition','0'))-2))
                if id==1:
                    f.set('XScale','60');f.set('YScale','70')
    content=actor.find('Content')
    for layer in list(content.find('Layers')):
        if layer.get('Id')not in used:content.find('Layers').remove(layer)
    for a in actor.findall('Animations/Animation'):
        for la in list(a.find('LayerAnimations')):
            if la.get('LayerId')not in used:a.find('LayerAnimations').remove(la)
    sheetIds={x.get('SpritesheetId')for x in content.find('Layers')}
    for sheet in list(content.find('Spritesheets')):
        if sheet.get('Id')not in sheetIds:
            content.find('Spritesheets').remove(sheet);continue
        path=sheet.get('Path').replace('\\','/')
        original=source.parent/path
        texture=f'loop_{id}_{sheet.get("Id")}.png'
        if original.exists():shutil.copyfile(original,OUT/texture)
        elif not(OUT/texture).exists():raise FileNotFoundError(original)
        sheet.set('Path',texture)
    E.ElementTree(actor).write(OUT/f'{id}.anm2',encoding='utf-8',xml_declaration=True)

entries=[]
for id,label in items:
    fields=[f'id={id}',f'sheet="gfx/characters/hunter_art174/{id}.png"',
            'label='+json.dumps(label), 'zh='+json.dumps(zh.get(id,label.split(':')[0]),ensure_ascii=False)]
    if id in [1,19,342]:fields+=['loop=true',f'path="gfx/characters/hunter_art174/{id}.anm2"']
    entries.append('{'+','.join(fields)+'}')
(MOD/'hunter_costume_manifest.lua').write_text('return {\n'+',\n'.join(entries)+'\n}\n')
costumes=E.parse(MOD/'content/costumes2.xml')
for node in list(costumes.getroot()):
    if 'hunter_art17'in node.get('anm2path',''):costumes.getroot().remove(node)
for id in [1,19,342]:
    E.SubElement(costumes.getroot(),'costume',anm2path=f'hunter_art174/{id}.anm2',type='none',priority='105',hasOverlay='true')
costumes.write(MOD/'content/costumes2.xml',encoding='utf-8',xml_declaration=True)
legacy=MOD/'resources/gfx/characters/hunter_art173'
if legacy.exists():shutil.rmtree(legacy)
print(f'Assembled {len(complete)}/66 integrated heads; registered three real overlay loops.')

# Apply the conditional outfit actor geometry after regenerating loop files.
import runpy
runpy.run_path(str(REPO/'tools/recover_full_unicorn.py'))
runpy.run_path(str(REPO/'tools/measure_head_landmarks.py'))
runpy.run_path(str(REPO/'tools/recover_complete_faces.py'))
runpy.run_path(str(REPO/'tools/measure_head_landmarks.py'))
runpy.run_path(str(REPO/'tools/restore_sprite_borders.py'))
runpy.run_path(str(REPO/'tools/align_head_anchors.py'))
