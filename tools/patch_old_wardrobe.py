"""Apply a narrow, inspectable Hunter bridge to the user's Old Wardrobe upload."""
from pathlib import Path
import shutil
import zipfile

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'compat_sources/old_wardrobe_2488945061.zip'
TARGET = ROOT / 'compat/old wardrobe_2488945061'


def main():
    with zipfile.ZipFile(SOURCE) as archive:
        archive.extractall(ROOT / 'compat')
    path = TARGET / 'main.lua'
    source = path.read_text(encoding='cp1252')

    def replace(old, new):
        nonlocal source
        assert source.count(old) == 1, (old[:100], source.count(old))
        source = source.replace(old, new)

    replace('CustomWardrobe = true', '''CustomWardrobe = true

-- Hunter v1.78 compatibility: explicit UI actions, never gameplay mutations.
-- All calls are optional and scoped to the currently dressed Hunter player.
local function HunterBridge(action, value)
    local api = HunterWardrobe178
    if api and player and api.isHunter(player) and api[action] then
        return api[action](player, value)
    end
    return false
end
local function HunterListAction(action, key)
    if not HunterBridge(action, key) then return false end
    if action == "select" and key == "H178:AUTO" then
        for k in pairs(nocostume) do nocostume[k] = nil end
        for k in pairs(transfo) do transfo[k] = nil end
    elseif action == "select" then
        local item = tonumber(string.match(key, "^H178:I(%d+)$"))
        local formId = tonumber(string.match(key, "^H178:F(%d+)$"))
        if item then nocostume[item] = nil end
        if formId and HunterWardrobe178.formNative then
            local null = HunterWardrobe178.formNative(formId)
            if null then transfo[null] = nil end
        end
    end
    return true
end''')
    replace('if (WardrobePlus == nil) or (WardrobePlus ~= nil and OWRP.IsCostumeAvailable(k)) then',
            'if (string.sub(k,1,5) ~= "H178:" or HunterBridge("isHunter")) and ((WardrobePlus == nil) or (WardrobePlus ~= nil and OWRP.IsCostumeAvailable(k))) then')
    replace('local function DrawPlayer(player)\n\tplayer:RenderGlow', '''local function DrawPlayer(player)
    if HunterWardrobe178 and HunterWardrobe178.isHunter(player) then
        HunterWardrobe178.renderWings(player, Vector(invPosition.X+148,invPosition.Y+29), true)
    end
\tplayer:RenderGlow''')
    replace('''\tplayer:RenderHead(Vector(invPosition.X+148,invPosition.Y+29))
\tplayer:RenderTop''','''\tplayer:RenderHead(Vector(invPosition.X+148,invPosition.Y+29))
    if HunterWardrobe178 and HunterWardrobe178.isHunter(player) and HunterWardrobe178.renderItemEffects then
        HunterWardrobe178.renderItemEffects(player, Vector(invPosition.X+148,invPosition.Y+29))
    end
\tplayer:RenderTop''')
    # Custom list selections choose Hunter art without adding marker costumes.
    replace('''local function RenderList()
\tDrawList()
''', '''local function RenderList()
    local hunterInput = actionbutton
\tDrawList()
    local key = pid[selectionline]
    local handled = false
    if actionbutton == ButtonAction.ACTION_MENUCONFIRM then
        handled = HunterListAction("select", key)
    elseif actionbutton == ButtonAction.ACTION_PILLCARD then
        handled = HunterListAction("undress", key)
    end
    if handled then
        actionbutton = -1
        dressingEnt:ToNPC():PlaySound(283,1,0,false,1)
        return
    end
''')
    replace('player:ClearCostumes()', 'player:ClearCostumes()\n                HunterBridge("clear")')
    replace('''\t\telseif pid[selectionline] == "!2" then -- wipe listed
''', '''\t\telseif pid[selectionline] == "!2" then -- wipe listed
            HunterBridge("clear")
''')
    # The original DrawList branch is silent when removing all listed art.
    replace('''\telseif (actionbutton == ButtonAction.ACTION_BOMB) then
\t\tfor k,v in pairs(paintname) do''', '''\telseif (actionbutton == ButtonAction.ACTION_BOMB) then
        HunterBridge("clear")
\t\tfor k,v in pairs(paintname) do''')
    replace('''\t\tdressingEnt:ToNPC():PlaySound(283,1,0,false,1)
\tend
end
---------------------------------------------------------------------------------------------
local function DrawUI()''', '''\t\tdressingEnt:ToNPC():PlaySound(283,1,0,false,1)
\tend
    if hunterInput > 0 then HunterBridge("refresh") end
end
---------------------------------------------------------------------------------------------
local function DrawUI()''')
    # Visibility is imported on opening; only explicit selection can re-enable
    # an appearance, preventing our own automatic removals from hiding it.
    replace('''function OWR.RenderUI()
\tlocal\tfirstitem = 1''', '''function OWR.RenderUI()
    local hunterInput = actionbutton
    local hunterRebuild = (phase == 1)
    if player and HunterWardrobe178 and HunterWardrobe178.isHunter(player) then
        HunterWardrobe178.visibility(player, nocostume, transfo)
    end
\tlocal\tfirstitem = 1''')
    replace('''\t\t\t\tphase = 1
\t\t\t\tactionbutton = -1
\t\t\t\tdressingEnt:ToNPC():PlaySound(283,1,0,false,1)
\t\t\telseif selection > totalcostumes then''', '''                HunterBridge("form", {id=form, visible=(transfo[form]==1 or transfo[form]==3)})
\t\t\t\tphase = 1
\t\t\t\tactionbutton = -1
\t\t\t\tdressingEnt:ToNPC():PlaySound(283,1,0,false,1)
\t\t\telseif selection > totalcostumes then''')
    replace('''\t\t\t\tphase = 1
\t\t\t\tactionbutton = -1
\t\t\t\tdressingEnt:ToNPC():PlaySound(283,1,0,false,1)
\t\t\tend
\t\telseif (actionbutton == ButtonAction.ACTION_PILLCARD) then''', '''                HunterBridge("item", {id=iteminfos[selection].ID, visible=not nocostume[iteminfos[selection].ID]})
\t\t\t\tphase = 1
\t\t\t\tactionbutton = -1
\t\t\t\tdressingEnt:ToNPC():PlaySound(283,1,0,false,1)
\t\t\tend
\t\telseif (actionbutton == ButtonAction.ACTION_PILLCARD) then''')
    # Original bulk undress stored costume IDs but later read collectible IDs.
    # Correct this only for Hunter; leave other character behavior unchanged.
    source = source.replace('nocostume[iteminfos[k].Costume.ID] = true',
                            'nocostume[HunterBridge("isHunter") and iteminfos[k].ID or iteminfos[k].Costume.ID] = true')
    replace('''\t\telseif (actionbutton == ButtonAction.ACTION_BOMB) then
\t\t\tfor k, v in pairs(iteminfos) do''', '''\t\telseif (actionbutton == ButtonAction.ACTION_BOMB) then
            HunterBridge("clear")
\t\t\tfor k, v in pairs(iteminfos) do''')
    replace('''\tif (phase > -1) then
\t\tDrawUI() --''', '''    if player and HunterWardrobe178 and HunterWardrobe178.isHunter(player) then
        HunterWardrobe178.visibility(player, nocostume, transfo)
        if hunterInput > 0 or hunterRebuild then HunterBridge("refresh") end
    end
\tif (phase > -1) then
\t\tDrawUI() --''')
    path.write_text(source)
    shutil.copyfile(ROOT / 'docs/OLD_WARDROBE_COMPAT.md', TARGET / 'HUNTER_COMPAT_README.md')
    print('Patched supplied Old Wardrobe: Hunter-only action/visibility bridge and wing preview.')


if __name__ == '__main__':
    main()
