"""Offline native-coordinate previews of forms and independently animated wings."""
from pathlib import Path
import subprocess
import xml.etree.ElementTree as E
from render_dynamic_preview import render, run, REPO, GFX, OUT

TMP=REPO/'art_sources/assembly/forms178_preview'
TMP.mkdir(parents=True,exist_ok=True)
LABELS=['Guppy','Beelzebub','Fun Guy','Seraphim','Bob','Spun','Yes Mother',
        'Conjoined','Leviathan','Oh Crap','Bookworm','Adulthood','Spider Baby','Stompy']
WINGS={0:'guppy',1:'fly',3:'angel',8:'devil'}


def card(id,direction,tick,dest,shoot=0):
    run(['-size','192x176','xc:#283832',dest])
    actor=E.parse(GFX/f'001.000_player_hunter_b_v178_f{id}.anm2').getroot()
    if id in WINGS:
        folder=GFX/'characters/hunter_forms178'
        wing=E.parse(folder/f'wings_{WINGS[id]}.anm2').getroot()
        render(dest,wing,folder,direction,tick,origin=(96,120-8.4*2),sprite_scale=.33)
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
    frames=[]
    for direction in ['Down','Right','Up','Left']:
        for tick in range(12):
            tiles=[]
            for id in [0,1,3,8]:
                path=TMP/f'wing_{id}_{direction}_{tick}.png'
                card(id,direction,tick,path);tiles.append(path)
            combined=TMP/f'wing_frame_{direction}_{tick}.png'
            run([*tiles,'+append',combined]);frames.append(combined)
    run(['-delay','7','-loop','0',*frames,OUT/'transformation-wings.gif'])
    print('Rendered14transformations and48-frame four-direction idle wing preview; offline only.')


if __name__=='__main__':main()
