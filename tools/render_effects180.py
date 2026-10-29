"""Stationary-body particle previews from the runtime's actual ANM2 assets."""
from pathlib import Path
import xml.etree.ElementTree as E
from PIL import Image,ImageDraw,ImageFont
from render_dynamic_preview import card,GFX,OUT,REPO

TMP=REPO/'art_sources/assembly/effects180_preview'
TMP.mkdir(parents=True,exist_ok=True)
ITEMS={1:'Sad Onion',19:'Boom',342:'Blue Cap'}


def main():
    font=ImageFont.truetype('DejaVuSans.ttf',11)
    cached={};timelines={}
    for item,label in ITEMS.items():
        actor=E.parse(GFX/f'characters/hunter_art174/{item}.anm2')
        for direction in ['Down','Right','Up','Left']:
            frames=actor.findall(f"Animations/Animation[@Name='Head{direction}_Overlay']/LayerAnimations/LayerAnimation/Frame")
            timeline=[];tick=0
            for pose,frame in enumerate(frames):
                path=TMP/f'{item}_{direction}_{pose}.png';card(item,direction,tick,path)
                image=Image.open(path).convert('RGB');draw=ImageDraw.Draw(image)
                draw.text((64,137),label,font=font,fill='white',anchor='ms')
                cached[item,direction,pose]=image
                delay=int(frame.get('Delay'));timeline.extend([pose]*delay);tick+=delay
            timelines[item,direction]=timeline
    result=[]
    for direction in ['Down','Right','Up','Left']:
        for tick in range(24):
            frame=Image.new('RGB',(384,144),'#283832')
            for column,item in enumerate(ITEMS):
                timeline=timelines[item,direction]
                frame.paste(cached[item,direction,timeline[tick%len(timeline)]] ,(column*128,0))
            result.append(frame)
    result[0].save(OUT/'effects-idle.gif',save_all=True,append_images=result[1:],duration=40,loop=0,optimize=True)
    cry=[]
    for direction in ['Down','Right','Up','Left']:
        for pose in range(3):cry.append(cached[1,direction,pose].resize((384,432),Image.Resampling.NEAREST))
    cry[0].save(OUT/'crying-animation.gif',save_all=True,append_images=cry[1:],duration=70,loop=0,optimize=True)
    print('Rendered four-direction droplets/fuse/cap particles with stationary bodies and fixed head poses.')


if __name__=='__main__':main()
