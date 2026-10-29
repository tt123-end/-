#!/usr/bin/env python3
"""Offline contract checks; these do not replace Isaac/REPENTOGON playtesting."""
from __future__ import annotations

import ctypes
import ctypes.util
import json
from pathlib import Path
import tempfile
import xml.etree.ElementTree as ET

from PIL import Image, ImageChops


CHECKOUT = Path(__file__).resolve().parent.parent
MOD = CHECKOUT / 'zzzz_revolver_samson'


def execute_lua(source: str) -> None:
    library = ctypes.util.find_library('lua5.4')
    if not library:
        raise RuntimeError('Lua 5.4 shared library is required')
    lua = ctypes.CDLL(library)
    lua.luaL_newstate.restype = ctypes.c_void_p
    lua.luaL_openlibs.argtypes = [ctypes.c_void_p]
    lua.luaL_loadstring.argtypes = [ctypes.c_void_p, ctypes.c_char_p]
    lua.lua_pcallk.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_int,
                             ctypes.c_int, ctypes.c_longlong, ctypes.c_void_p]
    lua.lua_tolstring.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_void_p]
    lua.lua_tolstring.restype = ctypes.c_char_p
    lua.lua_close.argtypes = [ctypes.c_void_p]
    state = lua.luaL_newstate()
    try:
        lua.luaL_openlibs(state)
        loaded = lua.luaL_loadstring(state, source.encode())
        result = loaded or lua.lua_pcallk(state, 0, 0, 0, 0, None)
        if result:
            raise AssertionError(lua.lua_tolstring(state, -1, None).decode())
    finally:
        lua.lua_close(state)


def nonempty_difference(a: Image.Image, b: Image.Image) -> bool:
    # RGBA getbbox() alone can miss RGB changes when the alpha difference is 0.
    return any(channel.getbbox() is not None
               for channel in ImageChops.difference(a, b).split())


def main() -> None:
    execute_lua('\n'.join('assert(loadfile(%s))' % json.dumps(str(path))
                          for path in sorted(MOD.glob('*.lua'))))
    with tempfile.TemporaryDirectory(prefix='hunter-art-tests-') as temporary:
        exported = Path(temporary) / 'manifest.tsv'
        source = ('TEST_MOD_ROOT=%s\nTEST_MANIFEST_OUTPUT=%s\n' %
                  (json.dumps(str(MOD) + '/'), json.dumps(str(exported))))
        source += 'assert(loadfile(%s))()' % json.dumps(
            str(Path(__file__).with_suffix('.lua')))
        execute_lua(source)
        entries = [line.split('\t') for line in exported.read_text().splitlines()]

    assert len(entries) == 66, f'Expected 66 designs, received {len(entries)}'
    assert len({entry[0] for entry in entries}) == 66, 'Duplicate design IDs'
    gfx = MOD / 'resources/gfx'
    original_path = gfx / 'characters/costumes/hunter_b_heads_v152.png'
    original = Image.open(original_path).convert('RGBA')
    assert original.size == (2048, 2048)
    for item_id, sheet, *_ in entries:
        assert sheet.startswith('gfx/'), sheet
        path = MOD / 'resources' / sheet
        image = Image.open(path).convert('RGBA')
        assert image.size == original.size, (item_id, image.size)
        assert image.getchannel('A').getextrema()[0] == 0, (item_id, 'no alpha')
        for index in range(6):
            cell_alpha = image.crop((index*128, 0, (index+1)*128, 128)).getchannel('A')
            bbox = cell_alpha.point(lambda value: 255 if value >= 64 else 0).getbbox()
            assert bbox is not None, (item_id, index, 'empty directional state')
            assert 12 <= bbox[1] < bbox[3] <= 116, (
                item_id, index, bbox, 'head escaped native vertical anchor band')
        assert nonempty_difference(image.crop((0, 0, 768, 128)),
                                   original.crop((0, 0, 768, 128))), (
                                       item_id, 'unchanged ordinary head states')
        # Three original action cells now deliberately inherit the selected
        # outfit. Geometry/timings stay in the original native ANM2.
        for destination, source in [(768, 128), (1152, 0), (1280, 128)]:
            assert not nonempty_difference(
                image.crop((destination, 0, destination+128, 128)),
                image.crop((source, 0, source+128, 128))), (
                    item_id, destination, 'action cell lost the selected outfit')
        for box in [(896, 0, 1152, 128), (1408, 0, 2048, 128),
                    (0, 128, 2048, 2048)]:
            assert not nonempty_difference(image.crop(box), original.crop(box)), (
                item_id, 'special-action pixels were modified', box)
        assert nonempty_difference(image.crop((0, 0, 128, 128)),
                                   image.crop((128, 0, 256, 128))), (
                                       item_id, 'idle/shoot pixels identical')

    sad = Image.open(MOD / 'resources' / next(
        entry[1] for entry in entries if entry[0] == '1')).convert('RGBA')
    # A crying expression must visibly replace the face, not just add tiny dots.
    before = original.crop((20, 40, 110, 105))
    after = sad.crop((20, 40, 110, 105))
    assert nonempty_difference(before, after), 'Sad Onion leaves the face unchanged'

    for path in list(MOD.rglob('*.xml')) + list(MOD.rglob('*.anm2')):
        ET.parse(path)
    # Test measured face points through actual per-pose XML transforms, not
    # merely that the same hard-coded offset was written into every outfit.
    landmarks=json.loads((CHECKOUT/'art_sources/head_landmarks176.json').read_text())
    neutral=ET.parse(gfx/'001.000_player_hunter_b_v153.anm2').getroot()
    for item_id,*_ in entries:
        actor=ET.parse(gfx/f'001.000_player_hunter_b_v176_{item_id}.anm2').getroot()
        assert ET.tostring(actor.find('Content'))==ET.tostring(neutral.find('Content'))
        for original_animation,new_animation in zip(neutral.findall('Animations/Animation'),actor.findall('Animations/Animation')):
            assert original_animation.attrib==new_animation.attrib
            for old_layer,new_layer in zip(original_animation.findall('LayerAnimations/LayerAnimation'),new_animation.findall('LayerAnimations/LayerAnimation')):
                assert old_layer.attrib==new_layer.attrib
                for old,new in zip(old_layer.findall('Frame'),new_layer.findall('Frame')):
                    column=int(old.get('XCrop','-128'))//128
                    pose={6:1,9:0,10:1}.get(column,column)
                    if old_layer.get('LayerId')!='4' or old.get('YCrop')!='0' or pose not in range(6):
                        assert old.attrib==new.attrib;continue
                    assert {k:v for k,v in old.attrib.items()if k not in ('XPivot','YPivot')}=={k:v for k,v in new.attrib.items()if k not in ('XPivot','YPivot')}
                    point=landmarks['outfits'][item_id][pose];reference=landmarks['neutral'][pose]
                    for axis,pivot,scale in [('x','XPivot','XScale'),('y','YPivot','YScale')]:
                        actual=(point[axis]-float(new.get(pivot)))*float(new.get(scale))/100
                        expected=(reference[axis]-float(old.get(pivot)))*float(old.get(scale))/100
                        assert abs(actual-expected)<1e-7,(item_id,pose,axis,actual,expected)
    assert len(list(gfx.glob('001.000_player_hunter_b_v176_*.anm2')))==66
    print('PASS:66individual pose tables; face-centre/chin coordinates match neutral under actual native/mirrored/action transforms; body/timing preserved.')
    registrations = ET.parse(MOD / 'content/costumes2.xml').getroot()
    assert not any('hunter_art173/' in node.get('anm2path', '')
                   for node in registrations), 'Old static costumes still registered'
    assert not (gfx / 'characters/hunter_art173').exists(), (
        'Obsolete static accessory resources remain in the installation')
    expected_loops = {entry[2].removeprefix('gfx/characters/')
                      for entry in entries if entry[2]}
    assert len(expected_loops) == 3, expected_loops
    registered_loops = [node for node in registrations
                        if node.get('anm2path') in expected_loops]
    assert len(registered_loops) == 3, 'Missing or duplicate loop registrations'
    assert all(node.get('hasOverlay') == 'true' for node in registered_loops), (
        'Continuous costume animation lacks hasOverlay=true')
    loops = []
    for path in gfx.rglob('*.anm2'):
        if '174' not in str(path) and 'dynamic' not in str(path):
            continue
        root = ET.parse(path).getroot()
        sheets = {}
        for sheet in root.findall('Content/Spritesheets/Spritesheet'):
            texture = path.parent / sheet.get('Path').replace('\\', '/')
            assert texture.is_file(), ('Missing texture', path, texture)
            sheets[sheet.get('Id')] = Image.open(texture).convert('RGBA')
        layers = {node.get('Id'): node.get('SpritesheetId')
                  for node in root.findall('Content/Layers/Layer')}
        for animation in root.findall('Animations/Animation'):
            crops = []
            for layer in animation.findall('LayerAnimations/LayerAnimation'):
                image = sheets[layers[layer.get('LayerId')]]
                for frame in layer.findall('Frame'):
                    x, y, w, h = [int(frame.get(key, '0'))
                                  for key in ('XCrop', 'YCrop', 'Width', 'Height')]
                    assert 0 <= x < x+w <= image.width
                    assert 0 <= y < y+h <= image.height
                    assert int(frame.get('Delay', '0')) > 0
                    crops.append(image.crop((x, y, x+w, y+h)))
            if animation.get('Name', '').endswith('_Overlay'):
                assert animation.get('Loop') == 'true'
                unique = {crop.tobytes() for crop in crops}
                assert len(unique) >= 3, (path, animation.get('Name'),
                                          'loop repeats one static picture')
                loops.append(animation.get('Name'))
    assert set(loops) >= {'HeadDown_Overlay', 'HeadRight_Overlay',
                         'HeadUp_Overlay', 'HeadLeft_Overlay'}, loops
    assert len(loops) == 12, ('Expected 3 effects x 4 directions', loops)
    print('PASS: Lua syntax, 66 full-head sheets, native head anchor bounds, '
          'distinct idle/shoot pixels, Hit/Pickup outfit cells, '
          'other special-action preservation, '
          'XML/texture/crop references, 3 effects x 4 genuinely animated '
          'directional loops; game testing pending.')


if __name__ == '__main__':
    main()
