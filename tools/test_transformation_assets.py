"""Check the new art, actual ANM2 coordinate transforms and companion archive."""
from pathlib import Path
import copy
import json
import xml.etree.ElementTree as E
import zipfile
from PIL import Image, ImageChops, ImageOps

ROOT=Path(__file__).resolve().parents[1]
MOD=ROOT/'zzzz_revolver_samson'
GFX=MOD/'resources/gfx'


def rendered_alpha(actor,name,folder,origin=(96,120),scale=1,tick=0):
    """Rasterize actual ANM2 masks to test occlusion, not illustration style."""
    result=Image.new('L',(192,176))
    sheets={node.get('Id'):folder/node.get('Path').replace('\\','/')for node in actor.findall('Content/Spritesheets/Spritesheet')}
    layers={node.get('Id'):node.get('SpritesheetId')for node in actor.findall('Content/Layers/Layer')}
    animation=actor.find(f"Animations/Animation[@Name='{name}']")
    for layer in animation.findall('LayerAnimations/LayerAnimation'):
        frames=layer.findall('Frame')
        if not frames:continue
        remaining=tick%sum(int(frame.get('Delay','1'))for frame in frames)
        frame=frames[-1]
        for candidate in frames:
            if remaining<int(candidate.get('Delay','1')):frame=candidate;break
            remaining-=int(candidate.get('Delay','1'))
        path=sheets[layers[layer.get('LayerId')]]
        if not path.is_file()or frame.get('Visible')=='false':continue
        value=lambda key:float(frame.get(key,'0'))
        x,y,w,h=[int(value(key))for key in ['XCrop','YCrop','Width','Height']]
        sx=value('XScale')/100*2*scale;sy=value('YScale')/100*2*scale
        crop=Image.open(path).convert('RGBA').crop((x,y,x+w,y+h)).getchannel('A')
        crop=crop.resize((max(1,round(w*abs(sx))),max(1,round(h*abs(sy)))),Image.Resampling.NEAREST)
        if sx<0:crop=ImageOps.mirror(crop)
        left=round(origin[0]+value('XPosition')*2-value('XPivot')*abs(sx))
        top=round(origin[1]+value('YPosition')*2-value('YPivot')*abs(sy))
        layer_image=Image.new('L',result.size);layer_image.paste(crop,(left,top))
        result=ImageChops.screen(result,layer_image)
    return result


def main():
    data=json.loads((ROOT/'art_sources/transformations178/landmarks.json').read_text())
    neutral=E.parse(GFX/'001.000_player_hunter_b_v153.anm2').getroot()
    original=Image.open(GFX/'characters/costumes/hunter_b_heads_v152.png').convert('RGBA')
    assert len(data['forms'])==15
    for form in range(15):
        image=Image.open(GFX/f'characters/hunter_forms178/form_{form}.png').convert('RGBA')
        assert image.size==(2048,2304)
        assert image.crop((0,128,2048,2048)).tobytes()==original.crop((0,128,2048,2048)).tobytes()
        points=data['forms'][str(form)]['points']
        for pose in range(6):
            crop=image.crop((pose*256,2048,(pose+1)*256,2304))
            bounds=crop.getchannel('A').point(lambda x:255 if x>20 else 0).getbbox()
            assert bounds and min(bounds[:2])>6 and max(bounds[2:])<250,(form,pose,bounds)
        for a,b in [(0,1),(2,3),(4,5)]:
            # Rear poses can be subtle; even those are distinct source frames.
            assert image.crop((a*256,2048,(a+1)*256,2304)).tobytes()!=image.crop((b*256,2048,(b+1)*256,2304)).tobytes(),(form,a,b)
        actor=E.parse(GFX/f'001.000_player_hunter_b_v178_f{form}.anm2').getroot()
        expected=copy.deepcopy(neutral.find('Content'))
        expected.find("Spritesheets/Spritesheet[@Id='3']").set('Path',f'characters/hunter_forms178/form_{form}.png')
        assert E.tostring(actor.find('Content'))==E.tostring(expected)
        for old_animation,new_animation in zip(neutral.findall('Animations/Animation'),actor.findall('Animations/Animation')):
            assert old_animation.attrib==new_animation.attrib
            for old_layer,new_layer in zip(old_animation.findall('LayerAnimations/LayerAnimation'),new_animation.findall('LayerAnimations/LayerAnimation')):
                assert old_layer.attrib==new_layer.attrib
                for old,new in zip(old_layer.findall('Frame'),new_layer.findall('Frame')):
                    col=int(old.get('XCrop','-128'))//128
                    pose={6:1,9:0,10:1}.get(col,col)
                    if old_layer.get('LayerId')!='4' or old.get('YCrop')!='0' or pose not in range(6):
                        assert old.attrib==new.attrib;continue
                    changed={'XPivot','YPivot','XCrop','YCrop','Width','Height'}
                    assert {k:v for k,v in old.attrib.items()if k not in changed}=={k:v for k,v in new.attrib.items()if k not in changed}
                    assert (int(new.get('XCrop')),int(new.get('YCrop')),int(new.get('Width')),int(new.get('Height')))==(pose*256,2048,256,256)
                    for axis,pivot,scale in [('x','XPivot','XScale'),('y','YPivot','YScale')]:
                        actual=(points[pose][axis]+64-float(new.get(pivot)))*float(new.get(scale))/100
                        wanted=(data['neutral'][pose][axis]-float(old.get(pivot)))*float(old.get(scale))/100
                        assert abs(actual-wanted)<1e-7,(form,pose,axis,actual,wanted)
    motion=json.loads((ROOT/'art_sources/wings179/motion.json').read_text())
    assert motion['frames']==40 and motion['delays']==[10,7,3,10,5,5]
    assert len({tuple(motion['colours'][key])for key in ['guppy','fly','angel','devil']})==4
    image=Image.open(GFX/'characters/hunter_wings179/feathers.png').convert('RGBA')
    assert image.size==(1536,1024)
    actor=E.parse(GFX/'characters/hunter_wings179/wings.anm2').getroot()
    from scipy import ndimage as ndi
    import numpy as np
    for direction,animation in enumerate(actor.findall('Animations/Animation')):
        assert animation.get('FrameNum')=='40'and animation.get('Loop')=='true'
        frames=animation.findall('LayerAnimations/LayerAnimation/Frame')
        assert len(frames)==6 and [int(f.get('Delay'))for f in frames]==motion['delays']
        pixels=[];silhouettes=[]
        for pose,frame in enumerate(frames):
            x,y,w,h=[int(frame.get(key))for key in ['XCrop','YCrop','Width','Height']]
            assert (x,y,w,h)==(pose*256,direction*256,256,256)
            assert frame.get('XPivot')=='128'and frame.get('YPivot')=='128'
            crop=image.crop((x,y,x+w,y+h))
            alpha=crop.getchannel('A').point(lambda value:255 if value>20 else 0)
            bounds=alpha.getbbox()
            assert bounds and min(bounds[:2])>=56 and max(bounds[2:])<=200
            labels,total=ndi.label(np.asarray(alpha)>0,structure=np.ones((3,3)))
            areas=np.bincount(labels.ravel())[1:]
            main_components=int((areas>20).sum())
            assert main_components==(2 if direction in (0,2)else 1),(direction,pose,main_components)
            if direction==0 and pose==0:
                assert bounds[2]-bounds[0]<=126 and bounds[3]-bounds[1]<=48,'feathers exceed video proportions'
                assert alpha.crop((120,0,136,256)).getextrema()[1]==0,'central ornament survived'
            pixels.append(crop.tobytes());silhouettes.append(alpha.tobytes())
        assert len(set(pixels))==6 and len(set(silhouettes))==6,'feather beat reused one rigid sprite'
    roots=json.loads((ROOT/'art_sources/wings179/registration.json').read_text())
    assert len(roots)==36
    for record in roots:
        for axis in range(2):
            assert abs(record['source_root'][axis]*record['scale'][axis]+record['translation'][axis]-record['joint'][axis])<1e-9
    assert not list((GFX/'characters/hunter_forms178').glob('wings_*')),'rejected wing art remains installed'
    # Match the visible behavior in the supplied video: low feathers project
    # beside/below the body; the upward stroke disappears behind the head.
    head=E.parse(GFX/'001.000_player_hunter_b_v178_f3.anm2').getroot()
    body_mask=rendered_alpha(head,'WalkDown',GFX)
    head_mask=rendered_alpha(head,'HeadDown',GFX)
    occluder=ImageChops.screen(body_mask,head_mask)
    down=rendered_alpha(actor,'Down',GFX/'characters/hunter_wings179',origin=(96,120-3.6*2),scale=.33,tick=0)
    up=rendered_alpha(actor,'Down',GFX/'characters/hunter_wings179',origin=(96,120-3.6*2),scale=.33,tick=23)
    visible_down=ImageChops.multiply(down,ImageOps.invert(occluder))
    visible_up=ImageChops.multiply(up,ImageOps.invert(occluder))
    down_area=sum(value>100 for value in visible_down.getdata())
    up_area=sum(value>100 for value in visible_up.getdata())
    assert down_area>100 and up_area<down_area*.12,(down_area,up_area,'upstroke does not tuck behind the head')
    assert 6<=visible_down.getbbox()[3]-body_mask.getbbox()[3]<=18,'feathers are detached or do not drop below the body'
    selector='hunter_forms178/wardrobe_selector.anm2'
    registrations=E.parse(MOD/'content/costumes2.xml').getroot()
    node=next(node for node in registrations if node.get('anm2path')==selector)
    assert node.get('isFlying')is None
    assert Image.open(GFX/'characters/hunter_forms178/wardrobe_selector.png').getchannel('A').getextrema()==(0,0)
    # The artwork compiler substitutes clean regenerated rows for the two
    # source rows that touched the original image boundaries.
    sources=ROOT/'art_sources/transformations178'
    used_rows={'heads0.png':[0,1,2,3],'heads1.png':[0,1,3],'heads2.png':[0,1,2,3],
               'heads3.png':[0,1],'heads_repaired.png':[0,2]}
    for name,rows in used_rows.items():
        image=Image.open(sources/name).convert('RGBA')
        for row in rows:
            strip=image.crop((0,row*256,image.width,(row+1)*256)).getchannel('A').point(lambda value:255 if value>20 else 0)
            assert strip.crop((0,0,1,strip.height)).getextrema()[1]==0,(name,row,'source clipped at left edge')
            assert strip.crop((strip.width-1,0,strip.width,strip.height)).getextrema()[1]==0,(name,row,'source clipped at right edge')
    # All original wardrobe resources/configuration remain byte-identical.
    with zipfile.ZipFile(ROOT/'compat_sources/old_wardrobe_2488945061.zip')as archive:
        for info in archive.infolist():
            if info.is_dir()or info.filename.endswith('/main.lua'):continue
            assert (ROOT/'compat'/info.filename).read_bytes()==archive.read(info)
    source=(ROOT/'compat/old wardrobe_2488945061/main.lua').read_text()
    assert source.count('HunterBridge("form",')==1 and source.count('HunterBridge("item",')==1
    assert 'HunterWardrobe178.renderWings(player, Vector(invPosition.X+148,invPosition.Y+29), true)'in source
    print('PASS:15form actors/90pose crops preserve native body/timing and face anchors; '
          'video-referenced40tick feather beat,36fixed-root parts,pairedfront/back andsingle-side views,4palettes; '
          'all companion wardrobe resources unchanged.')


if __name__=='__main__':main()
