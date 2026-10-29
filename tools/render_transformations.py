"""Offline native-coordinate previews of forms and independently animated wings."""
from pathlib import Path
import subprocess,json
from PIL import Image
import xml.etree.ElementTree as E
from render_dynamic_preview import render, run, REPO, GFX, OUT

TMP=REPO/'art_sources/assembly/forms179_preview'
TMP.mkdir(parents=True,exist_ok=True)
LABELS=['Guppy','Beelzebub','Fun Guy','Seraphim','Bob','Spun','Yes Mother',
        'Conjoined','Leviathan','Oh Crap','Bookworm','Adulthood','Spider Baby','Stompy']
WINGS={0:'guppy',1:'fly',3:'angel',8:'devil'}
MOTION=json.loads((REPO/'art_sources/wings179/motion.json').read_text())


def card(id,direction,tick,dest,shoot=0):
    run(['-size','192x176','xc:#283832',dest])
    actor=E.parse(GFX/f'001.000_player_hunter_b_v178_f{id}.anm2').getroot()
    if id in WINGS:
        folder=GFX/'characters/hunter_wings179'
        wing=E.parse(folder/'wings.anm2').getroot()
        render(dest,wing,folder,direction,tick,origin=(96,120-3.6*2),
               sprite_scale=MOTION['scale'],tint=MOTION['colours'][WINGS[id]])
    render(dest,actor,GFX,'Walk'+direction,0,origin=(96,120))
    render(dest,actor,GFX,'Head'+direction,shoot,origin=(96,120))
    run([dest,'-font','DejaVu-Sans','-fill','white','-gravity','south','-pointsize','12','-annotate','+0+5',LABELS[id],dest])


def main():
    cards=[]
    for id in range(14):
        path=TMP/f'form_{id}.png';card(id,'Down',4,path);cards.append(path)
    subprocess.run(['magick','montage',*map(str,cards),'-tile','4x4','-geometry','+4+4',
                    '-background','#19231f',str(OUT/'transformation-preview.png')],check=True)
    rows=[]
    for id in range(14):
        tiles=[]
        for direction in ['Down','Right','Up','Left']:
            path=TMP/f'form_{id}_{direction}.png';card(id,direction,4,path);tiles.append(path)
        row=TMP/f'row_{id}.png'
        run([*tiles,'+append',row]);rows.append(row)
    run([*rows,'-append',OUT/'transformation-all-directions.png'])
    frames=[];durations=[]
    for direction in ['Down','Right','Up','Left']:
        tick=0
        for pose,delay in enumerate(MOTION['delays']):
            tiles=[]
            for id in [0,1,3,8]:
                path=TMP/f'wing_{id}_{direction}_{tick}.png'
                card(id,direction,tick,path);tiles.append(path)
            frame=Image.new('RGB',(192*4,176),'#283832')
            for col,path in enumerate(tiles):
                frame.paste(Image.open(path).convert('RGB'),(col*192,0))
            frames.append(frame);durations.append(round(delay/30*1000));tick+=delay
    frames[0].save(OUT/'transformation-wings.gif',save_all=True,append_images=frames[1:],
                   duration=durations,loop=0,optimize=True)
    print('Rendered14transformations and24keyframes: four-direction compact folding feathers,1.33second cycle; offline only.')


if __name__=='__main__':main()
