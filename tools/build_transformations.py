"""Compile generated transformation illustrations; retain native body/face anchors.

Only extraction, affine packing and ANM2 assembly happen here. Illustrations
come from the image-generation source sheets, not procedural drawing.
"""
from pathlib import Path
from collections import deque
import copy
import json
import xml.etree.ElementTree as E
import numpy as np
from PIL import Image
from scipy import ndimage as ndi

REPO = Path(__file__).resolve().parents[1]
MOD = REPO / 'zzzz_revolver_samson'
GFX = MOD / 'resources/gfx'
SRC = REPO / 'art_sources/transformations178'
OUT = GFX / 'characters/hunter_forms178'
OUT.mkdir(parents=True, exist_ok=True)
# PlayerForm enums, native null costume, Chinese/English labels, source row.
FORMS = [
    (0, 5, '嗝屁', 'Guppy', 0, 0, 'guppy'),
    (1, 3, '蝇王', 'Beelzebub', 0, 1, 'fly'),
    (2, 20, '真菌', 'Fun Guy', 0, 2, None),
    (3, 21, '炽天使', 'Seraphim', 0, 3, 'angel'),
    (4, 22, '鲍勃', 'Bob', 1, 0, None),
    (5, 23, '药物过量', 'Spun', 1, 1, None),
    (6, 24, '妈宝', 'Yes Mother', 1, 2, None),
    (7, 25, '连体婴', 'Conjoined', 1, 3, None),
    (8, 26, '利维坦', 'Leviathan', 2, 0, 'devil'),
    (9, 27, '大便套装', 'Oh Crap', 2, 1, None),
    (10, 37, '书虫', 'Bookworm', 2, 2, None),
    (11, 38, '成人', 'Adulthood', 2, 3, None),
    (12, 39, '蜘蛛宝宝', 'Spider Baby', 3, 0, None),
    (13, None, '践踏', 'Stompy', 3, 1, None),
    # Engine enum 14 is unused in normal play; defensive support only.
    (14, None, '翡翠飞行（备用）', 'Emerald Flight (engine fallback)', 3, 2, 'emerald'),
]


def segments(path, roots=None):
    """Use complete source components, including art outside nominal grid cells.

    Touching neighbours use multi-source geodesic separation. This prevents
    the column-edge clipping fixed in v1.77 from reappearing in new artwork.
    """
    pixels = np.asarray(Image.open(path).convert('RGBA'))
    labels, _ = ndi.label(pixels[:, :, 3] > 20, structure=np.ones((3, 3)))
    objects = ndi.find_objects(labels)
    counts = np.bincount(labels.ravel())
    masks = [np.zeros(labels.shape, dtype=bool) for _ in range(24)]
    for identity, box in enumerate(objects, 1):
        if box is None or counts[identity] < 8:
            continue
        yy, xx = np.where(labels[box] == identity)
        xx = xx + box[1].start
        yy = yy + box[0].start
        row = min(3, max(0, int(np.mean(yy) // 256)))
        columns = [c for c in range(6)
                   if box[1].start < c * 256 + 128 < box[1].stop]
        if len(columns) < 2 or box[1].stop - box[1].start < 360:
            col = min(5, max(0, int(np.mean(xx) // 256)))
            masks[row * 6 + col][yy, xx] = True
            continue
        region = labels[box] == identity
        distance = ndi.distance_transform_edt(region)
        assignment = np.full(region.shape, -1, dtype=np.int8)
        queue = deque()
        for col in columns:
            if roots is not None:
                rx, ry = roots[row][col]
                metric = (xx - rx) ** 2 + (yy - ry) ** 2
                index = int(np.argmin(metric))
                x, y = int(xx[index]) - box[1].start, int(yy[index]) - box[0].start
            else:
                inside = distance.copy()
                gx = np.arange(inside.shape[1]) + box[1].start
                inside[:, (gx < col * 256 + 72) | (gx > col * 256 + 184)] = 0
                y, x = np.unravel_index(np.argmax(inside), inside.shape)
            assignment[y, x] = col
            queue.append((y, x))
        while queue:
            y, x = queue.popleft()
            for dy, dx in ((-1, 0), (1, 0), (0, -1), (0, 1),
                           (-1, -1), (-1, 1), (1, -1), (1, 1)):
                ny, nx = y + dy, x + dx
                if (0 <= ny < region.shape[0] and 0 <= nx < region.shape[1]
                        and region[ny, nx] and assignment[ny, nx] < 0):
                    assignment[ny, nx] = assignment[y, x]
                    queue.append((ny, nx))
        for col in columns:
            masks[row * 6 + col][box] |= assignment == col
    output = []
    for mask in masks:
        assert mask.any(), (path, 'empty sprite')
        # Retain antialias pixels bordering the measured silhouette, keeping
        # independently touching regions separate at the original alpha edge.
        expanded = ndi.binary_dilation(mask, iterations=2)
        result = pixels.copy()
        result[~expanded] = 0
        output.append(Image.fromarray(result))
    return output


def face(image):
    p = np.asarray(image)
    r, g, b, a = [p[:, :, n].astype(float) for n in range(4)]
    skin = ((a > 128) & (r > 140) & (g > 80) & (g < 210)
            & (r > 1.1 * g) & (r < 1.85 * g) & (b > .45 * g) & (b < .92 * g))
    labels, _ = ndi.label(skin)
    counts = np.bincount(labels.ravel())
    counts[0] = 0
    identity = int(np.argmax(counts))
    yy, xx = np.where(labels == identity)
    assert len(xx) > 150, 'face must be measurable independently of headwear'
    return {'x': float((xx.min() + xx.max()) / 2), 'y': int(yy.max()),
            'width': int(xx.max() - xx.min()), 'area': len(xx)}


def warp(image, scale, tx, ty):
    # PIL's affine inverse maps pixel centres; this is technical packing only.
    return image.transform((256, 256), Image.Transform.AFFINE,
                           (1 / scale, 0, -tx / scale,
                            0, 1 / scale, -ty / scale),
                           Image.Resampling.BICUBIC)


def build_heads():
    sheets = [segments(SRC / f'heads{i}.png') for i in range(4)]
    repaired = segments(SRC / 'heads_repaired.png')
    neutral_image = Image.open(GFX / 'characters/costumes/hunter_b_heads_v152.png').convert('RGBA')
    neutral = json.loads((REPO / 'art_sources/head_landmarks176.json').read_text())['neutral']
    neutral_actor = E.parse(GFX / '001.000_player_hunter_b_v153.anm2')
    metadata = {}
    manifest = ['-- Generated from tools/build_transformations.py; native forms remain authoritative.', 'return {']
    for form_id, null, zh, label, atlas, row, wing in FORMS:
        source = repaired[:6] if form_id == 6 else repaired[12:18] if form_id == 14 else sheets[atlas][row * 6:row * 6 + 6]
        packed = []
        points = []
        raw_points = []
        # Match neutral face width; accessories do not determine character size.
        reference_width = face(neutral_image.crop((0, 0, 128, 128)))['width']
        scale = reference_width / face(source[0])['width']
        assert .35 < scale < .85, (form_id, scale)
        for pose, image in enumerate(source):
            box = image.getchannel('A').point(lambda x: 255 if x > 20 else 0).getbbox()
            if pose < 4:
                point = face(image)
                tx = neutral[pose]['x'] + 64 - point['x'] * scale
                ty = neutral[pose]['y'] + 64 - point['y'] * scale
            else:
                point = {'x': (box[0] + box[2]) / 2, 'y': box[3] - 1}
                tx = 128 - point['x'] * scale
                ty = 180 - point['y'] * scale
            cell = warp(image, scale, tx, ty)
            bounds = cell.getchannel('A').point(lambda x: 255 if x > 20 else 0).getbbox()
            assert bounds and min(bounds[:2]) > 6 and max(bounds[2:]) < 250, (form_id, pose, bounds)
            if pose < 4:
                measured = face(cell.crop((64, 64, 192, 192)))
            else:
                measured = {'x': 64., 'y': 116}
            points.append(measured)
            raw_points.append({'source': point, 'scale': scale, 'tx': tx, 'ty': ty, 'bounds': bounds})
            packed.append(cell)
        sheet = Image.new('RGBA', (2048, 2304))
        sheet.paste(neutral_image, (0, 0))
        for pose, cell in enumerate(packed):
            sheet.paste(cell, (pose * 256, 2048))
            sheet.paste(cell.crop((64, 64, 192, 192)), (pose * 128, 0))
        for destination, pose in [(768, 1), (1152, 0), (1280, 1)]:
            sheet.paste(packed[pose].crop((64, 64, 192, 192)), (destination, 0))
        sheet.save(OUT / f'form_{form_id}.png')
        tree = copy.deepcopy(neutral_actor)
        tree.find("Content/Spritesheets/Spritesheet[@Id='3']").set('Path', f'characters/hunter_forms178/form_{form_id}.png')
        for frame in tree.findall("Animations/Animation/LayerAnimations/LayerAnimation[@LayerId='4']/Frame"):
            if frame.get('YCrop') != '0':
                continue
            column = int(frame.get('XCrop', '-128')) // 128
            pose = {6: 1, 9: 0, 10: 1}.get(column, column)
            if pose not in range(6):
                continue
            for axis, pivot in [('x', 'XPivot'), ('y', 'YPivot')]:
                frame.set(pivot, str(float(frame.get(pivot)) + 64 + points[pose][axis] - neutral[pose][axis]))
            for key, value in {'XCrop': pose * 256, 'YCrop': 2048, 'Width': 256, 'Height': 256}.items():
                frame.set(key, str(value))
        actor = f'gfx/001.000_player_hunter_b_v178_f{form_id}.anm2'
        tree.write(MOD / 'resources' / actor, encoding='utf-8', xml_declaration=True)
        manifest.append('  {form=%d,id="form%d",native=%s,zh=%s,label=%s,sheet="gfx/characters/hunter_forms178/form_%d.png",actor=%s,wing=%s},' % (
            form_id, form_id, str(null) if null is not None else 'nil', json.dumps(zh, ensure_ascii=False),
            json.dumps(label), form_id, json.dumps(actor), json.dumps(wing) if wing else 'nil'))
        metadata[str(form_id)] = {'points': points, 'packing': raw_points}
    manifest.append('}')
    (MOD / 'hunter_form_manifest.lua').write_text('\n'.join(manifest) + '\n')
    (SRC / 'landmarks.json').write_text(json.dumps({'neutral': neutral, 'forms': metadata}, ensure_ascii=False, indent=2) + '\n')



def frame_attributes(**values):
    result = dict(XPosition='0', YPosition='0', XPivot='128', YPivot='128',
                  XScale='100', YScale='100', Delay='2', Visible='true',
                  RedTint='255', GreenTint='255', BlueTint='255', AlphaTint='255',
                  RedOffset='0', GreenOffset='0', BlueOffset='0', Rotation='0', Interpolated='false')
    result.update({key: str(value) for key, value in values.items()})
    return result


def build_wings():
    import runpy
    runpy.run_path(str(REPO / 'tools/build_native_wings.py'), run_name='__main__')


def build_anchors():
    # User feedback: attach at the upper back (source y58); the old y80
    # attachment put short feathers beside the feet in live gameplay.
    # Preserve each body transform, including item-holding motion and scale.
    actor = E.parse(GFX / '001.000_player_hunter_b_v153.anm2')
    lines = ['return {']
    for animation in actor.findall('Animations/Animation'):
        layer = animation.find("LayerAnimations/LayerAnimation[@LayerId='14']")
        frames = layer.findall('Frame') if layer is not None else []
        if not frames:
            layer = animation.find("LayerAnimations/LayerAnimation[@LayerId='1']")
            frames = layer.findall('Frame') if layer is not None else []
        if not frames:
            continue
        values = []
        for frame in frames:
            x = float(frame.get('XPosition', '0')) + (64 - float(frame.get('XPivot', '64'))) * float(frame.get('XScale', '30')) / 100
            y = float(frame.get('YPosition', '0')) + (58 - float(frame.get('YPivot', '100'))) * float(frame.get('YScale', '30')) / 100
            # Only regular body crops have the common 128-pixel anatomy.
            if frame.get('Width') != '128':
                x, y = 0, -10.2
            values.extend(['{%s,%s}' % (round(x, 4), round(y, 4))] * int(frame.get('Delay', '1')))
        lines.append('  [%s]={%s},' % (json.dumps(animation.get('Name')), ','.join(values)))
    lines.append('}')
    (MOD / 'hunter_wing_anchors.lua').write_text('\n'.join(lines) + '\n')


def build_selector():
    # Listed Hunter entries are intercepted by the companion bridge. Give
    # legacy bulk-removal code a dedicated inert ID, never another character's
    # default/dance costume or an isFlying marker.
    Image.new('RGBA', (1, 1)).save(OUT / 'wardrobe_selector.png')
    tree = E.Element('AnimatedActor')
    E.SubElement(tree, 'Info', CreatedBy='Hunter', Version='1', Fps='30')
    content = E.SubElement(tree, 'Content')
    sheets = E.SubElement(content, 'Spritesheets')
    E.SubElement(sheets, 'Spritesheet', Id='0', Path='wardrobe_selector.png')
    layers = E.SubElement(content, 'Layers')
    E.SubElement(layers, 'Layer', Id='0', Name='head0', SpritesheetId='0')
    E.SubElement(content, 'Nulls'); E.SubElement(content, 'Events')
    animations = E.SubElement(tree, 'Animations', DefaultAnimation='HeadDown')
    for name in [kind + direction for kind in ['Head', 'Walk'] for direction in ['Down', 'Right', 'Up', 'Left']]:
        animation = E.SubElement(animations, 'Animation', Name=name, FrameNum='1', Loop='false')
        E.SubElement(E.SubElement(animation, 'RootAnimation'), 'Frame', **frame_attributes(Delay=1))
        layer = E.SubElement(E.SubElement(animation, 'LayerAnimations'), 'LayerAnimation', LayerId='0', Visible='true')
        E.SubElement(layer, 'Frame', **frame_attributes(XPivot=0, YPivot=0, XCrop=0, YCrop=0, Width=1, Height=1, Delay=1, AlphaTint=0))
        E.SubElement(animation, 'NullAnimations'); E.SubElement(animation, 'Triggers')
    E.ElementTree(tree).write(OUT / 'wardrobe_selector.anm2', encoding='utf-8', xml_declaration=True)
    costumes = E.parse(MOD / 'content/costumes2.xml')
    path = 'hunter_forms178/wardrobe_selector.anm2'
    if not any(node.get('anm2path') == path for node in costumes.getroot()):
        E.SubElement(costumes.getroot(), 'costume', anm2path=path, type='none', priority='-999')
    costumes.write(MOD / 'content/costumes2.xml', encoding='utf-8', xml_declaration=True)


if __name__ == '__main__':
    build_heads()
    build_wings()
    build_anchors()
    build_selector()
    print('Built14gameplay transformations, unused-engine fallback, six-frame wings and native shoulder anchors.')
