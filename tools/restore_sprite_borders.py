"""Compile padded sprites from complete source silhouettes; never redraw artwork.

The old128px centre is retained losslessly wherever it already has a visible
pixel. Restored borders come from the original atlas, at its existing scale.
"""
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
import hashlib,json,subprocess
from collections import deque
import numpy as np
from scipy import ndimage as ndi
from PIL import Image

REPO=Path(__file__).resolve().parents[1];ART=REPO/'art_sources'
GFX=REPO/'zzzz_revolver_samson/resources/gfx';OUT=GFX/'characters/hunter_art174'
TMP=ART/'assembly/borders177';TMP.mkdir(parents=True,exist_ok=True)
items=json.loads((ART/'items.json').read_text())
full_rows={1,6,17,46,48,51,69,77,79,83,87,91,110,115,134,300}
def run(args):subprocess.run(['magick',*map(str,args)],check=True,capture_output=True)
def parts(mask):
    labels,n=ndi.label(mask,np.ones((3,3)))
    areas=np.bincount(labels.ravel());result=[]
    for label,sl in enumerate(ndi.find_objects(labels),1):
        if areas[label]>=4000:result.append((int(areas[label]),label,sl))
    return labels,result
atlases={};geometry={}
for group in range(17):
    path=ART/f'atlas{group}.png';rgba=np.array(Image.open(path).convert('RGBA'));h,w=rgba.shape[:2];cw=w//6
    alpha=rgba[:,:,3]>20;labels,components=parts(alpha);regions=[]
    for area,label,(ys,xs)in components:
        mask=labels[ys,xs]==label
        count=max(1,round((xs.stop-xs.start)/cw))
        if count==1:regions.append((ys.start,xs.start,mask));continue
        # A few adjacent poses touch at their outlines. Separate the touching
        # neck/wing bridge with interior seeds rather than cutting a fixed tile.
        assert count==2,(group,count)
        start=round(((xs.start+xs.stop)/2)/cw-count/2)
        distance=ndi.distance_transform_edt(mask);markers=np.zeros(mask.shape,np.int32)
        for seed in range(count):
            lo=max(0,(start+seed)*cw-xs.start);hi=min(mask.shape[1],(start+seed+1)*cw-xs.start)
            field=distance[:,lo:hi];y,x=np.unravel_index(field.argmax(),field.shape)
            markers[y,lo+x]=seed+1
        # Geodesic multi-source flood follows the narrow touching outline;
        # background pixels cannot steal the foreground from either seed.
        split=markers.copy();split[~mask]=-1
        queue=deque(tuple(p)for p in np.argwhere(markers>0))
        while queue:
            yy,xx=queue.popleft()
            for dy,dx in ((0,1),(0,-1),(1,0),(-1,0),(1,1),(1,-1),(-1,1),(-1,-1)):
                ny,nx=yy+dy,xx+dx
                if 0<=ny<mask.shape[0]and 0<=nx<mask.shape[1]and split[ny,nx]==0:
                    split[ny,nx]=split[yy,xx];queue.append((ny,nx))
        for seed in range(count):
            piece=(split==seed+1)&mask;y,x=np.where(piece)
            assert len(x)>10000,(group,seed,len(x))
            box=(slice(y.min(),y.max()+1),slice(x.min(),x.max()+1))
            regions.append((ys.start+box[0].start,xs.start+box[1].start,piece[box]))
    assert len(regions)==24,(group,len(regions))
    regions.sort(key=lambda p:p[0]+p[2].shape[0]/2)
    rows=[sorted(regions[row*6:row*6+6],key=lambda p:p[1]+p[2].shape[1]/2)for row in range(4)]
    atlases[group]=(path,rgba,rows)
    for row in range(4):
        index=group*4+row
        if index>=len(items):continue
        item=items[index][0];boxes=[]
        for column in range(6):
            a=alpha[:,column*cw:(column+1)*cw]
            if item in full_rows:
                ls,ps=parts(a)
                selected=sorted(sorted(ps,reverse=True)[:4],key=lambda p:p[2][0].start)[row][2]
                boxes.append((selected[0].start,selected[0].stop))
            else:
                a=a[row*h//4:(row+1)*h//4];ls,ps=parts(a)
                selected=max(ps)[2];boxes.append((row*h//4+selected[0].start,row*h//4+selected[0].stop))
        top=min(a for a,b in boxes);bottom=max(b for a,b in boxes)
        if item not in full_rows:bottom=min(bottom,(row+1)*h//4-14)
        geometry[item]=(group,row,top,104/(bottom-top),cw)

def restore(item):
    group,row,top,sy,cw=geometry[item];atlas,rgba,rows=atlases[group]
    image=Image.open(OUT/f'{item}.png').convert('RGBA');base=image.crop((0,0,2048,2048))
    records=[];poses=[]
    for pose in range(6):
        y,x,mask=rows[row][pose];mh,mw=mask.shape
        raw=TMP/f'{item}_{pose}_isolated.png';maskfile=TMP/f'{item}_{pose}_mask.png'
        Image.fromarray(mask.astype(np.uint8)*255).save(maskfile)
        run([atlas,'-crop',f'{mw}x{mh}+{x}+{y}','+repage','(',maskfile,'-alpha','copy',')','-compose','DstIn','-composite',raw])
        recovered=TMP/f'{item}_{pose}_recovered.png'
        tx=64-pose*cw*.5+(.5-1)/2+x*.5
        ty=76-top*sy+(sy-1)/2+y*sy
        run([raw,'-filter','Lanczos','-virtual-pixel','transparent','-define','distort:viewport=256x256+0+0',
             '-distort','AffineProjection',f'.5,0,0,{sy},{tx},{ty}','+repage',recovered])
        old=np.array(base.crop((pose*128,0,(pose+1)*128,128)))
        # Lossless texture packing: all visible old pixels keep their values.
        # Only empty pixels/borders may gain source artwork.
        pixels=np.array(Image.open(recovered).convert('RGBA'));core=pixels[64:192,64:192]
        overlap=(old[:,:,3]>128)&(core[:,:,3]>128)
        coverage=float(overlap.sum()/max(1,(old[:,:,3]>128).sum()))
        median=float(np.median(np.abs(old[:,:,:3].astype(float)[overlap]-core[:,:,:3].astype(float)[overlap])))
        assert coverage>.98 and median<8,(item,pose,coverage,median,'source registration disagrees with existing head')
        keep=old[:,:,3]>0;core[keep]=old[keep]
        assert np.array_equal(core[keep],old[keep])
        alpha=pixels[:,:,3];ys,xs=np.where(alpha>20)
        bounds=[int(xs.min()),int(ys.min()),int(xs.max()+1),int(ys.max()+1)]
        assert min(bounds[:2])>=6 and max(bounds[2:])<=250,(item,pose,bounds)
        outside=alpha.copy();outside[64:192,64:192]=0
        records.append({'pose':pose,'bounds':bounds,'restored_border_pixels':int((outside>20).sum()),
                        'restored_empty_core_pixels':int(((core[:,:,3]>20)&~keep).sum()),
                        'preserved_visible_pixels':int(keep.sum()),'source_overlap':coverage,'source_rgb_median':median})
        path=TMP/f'{item}_{pose}.png';Image.fromarray(pixels).save(path);poses.append(path)
    rowfile=TMP/f'{item}_row.png';prefix=TMP/f'{item}_base.png'
    base.save(prefix)
    run([*poses,'(','-size','512x256','xc:none',')','+append',rowfile])
    run([prefix,rowfile,'-append',OUT/f'{item}.png'])
    result=Image.open(OUT/f'{item}.png').convert('RGBA')
    assert np.array_equal(np.array(result.crop((0,0,2048,2048))),np.array(base))
    return str(item),records

with ThreadPoolExecutor(max_workers=4)as pool:records=dict(pool.map(restore,[id for id,_ in items]))
(ART/'border_recovery177.json').write_text(json.dumps({'version':177,'canvas':[256,256],'unchanged_origin':[64,64],
    'outfits':records},indent=2)+'\n')
print('PASS:396direction/action frames restored from full source silhouettes; old visible pixels and face positions retained.')
