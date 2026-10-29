"""Offline ANM2-coordinate previews, not a substitute for game screenshots."""
from pathlib import Path
import subprocess,xml.etree.ElementTree as E

REPO=Path(__file__).resolve().parents[1];GFX=REPO/'zzzz_revolver_samson/resources/gfx'
OUT=REPO/'deliverables';OUT.mkdir(exist_ok=True)
TMP=REPO/'art_sources/assembly/render';TMP.mkdir(parents=True,exist_ok=True)
native=E.parse(GFX/'001.000_player_hunter_b_v153.anm2').getroot()
def run(args):subprocess.run(['magick',*map(str,args)],check=True,stderr=subprocess.DEVNULL)
def render(canvas,actor,folder,name,tick,override=None,origin=(64,108),sprite_scale=1,tint=None):
    sheets={x.get('Id'):folder/x.get('Path').replace('\\','/')for x in actor.findall('Content/Spritesheets/Spritesheet')}
    layers={x.get('Id'):x.get('SpritesheetId')for x in actor.findall('Content/Layers/Layer')}
    a=actor.find(f"Animations/Animation[@Name='{name}']")
    if a is None:return
    root_frames=a.findall('RootAnimation/Frame')
    root=root_frames[0]if root_frames else None
    root_x=float(root.get('XPosition','0'))if root is not None else 0
    root_y=float(root.get('YPosition','0'))if root is not None else 0
    for layer in a.findall('LayerAnimations/LayerAnimation'):
        frames=layer.findall('Frame')
        if not frames:continue
        duration=sum(int(f.get('Delay','1'))for f in frames);t=tick%duration
        f=frames[-1]
        for candidate in frames:
            if t<int(candidate.get('Delay','1')):f=candidate;break
            t-=int(candidate.get('Delay','1'))
        path=override if override and layer.get('LayerId')=='4'else sheets[layers[layer.get('LayerId')]]
        if not path.exists()or f.get('Visible')=='false':continue
        v=lambda k:float(f.get(k,'0'))
        sx=v('XScale')/100*2*sprite_scale;sy=v('YScale')/100*2*sprite_scale
        w=max(1,round(v('Width')*abs(sx)));h=max(1,round(v('Height')*abs(sy)))
        x=round(origin[0]+(root_x+v('XPosition'))*2-v('XPivot')*abs(sx));y=round(origin[1]+(root_y+v('YPosition'))*2-v('YPivot')*abs(sy))
        piece=canvas.with_name(canvas.stem+'_piece.png')
        args=[path,'-crop',f"{int(v('Width'))}x{int(v('Height'))}+{int(v('XCrop'))}+{int(v('YCrop'))}",'+repage','-resize',f'{w}x{h}!']
        if sx<0:args+=['-flop']
        if tint:
            for channel,factor in zip(('R','G','B'),tint):
                args+=['-channel',channel,'-evaluate','multiply',str(factor)]
            args+=['+channel']
        run(args+[piece]);run([canvas,piece,'-geometry',f'{x:+}{y:+}','-composite',canvas])
def card(id,direction,tick,dest,move=False,shoot=False):
    run(['-size','128x144','xc:#283832',dest])
    actor=E.parse(GFX/f'001.000_player_hunter_b_v177_{id}.anm2').getroot()
    render(dest,actor,GFX,'Walk'+direction,tick if move else 0)
    sheet=GFX/f'characters/hunter_art174/{id}.png'
    render(dest,actor,GFX,'Head'+direction,2 if shoot else 0,sheet)
    loop=GFX/f'characters/hunter_art174/{id}.anm2'
    if loop.exists():render(dest,E.parse(loop).getroot(),loop.parent,'Head'+direction+'_Overlay',tick)
if __name__=='__main__':
    cards=[]
    for id in [1,2,7,19,51,52,68,82,91,118,300,342]:
        path=TMP/f'item{id}.png';card(id,'Down',0,path)
        run([path,'-font','DejaVu-Sans','-fill','white','-gravity','south','-pointsize','11','-annotate','+0+2',str(id),path]);cards.append(path)
    subprocess.run(['magick','montage',*map(str,cards),'-tile','4x3','-geometry','+4+4','-background','#19231f',str(OUT/'costume-preview.png')],check=True,stderr=subprocess.DEVNULL)
    frames=[]
    for direction in ['Down','Right','Up','Left']:
        for tick in range(12):
            path=TMP/f'cry_{direction}_{tick}.png';card(1,direction,tick,path)
            run([path,'-resize','384x432',path]);frames.append(path)
    run(['-delay','10','-loop','0',*frames,OUT/'crying-animation.gif'])
    print('Rendered12outfits and48-frame four-direction crying preview (offline).')
