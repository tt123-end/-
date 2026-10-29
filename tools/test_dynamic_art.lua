-- Lua engine-contract simulation, executed by test_dynamic_art.py with Lua5.4.
-- This intentionally exercises lifecycle behavior rather than claiming to run Isaac.
local root=assert(TEST_MOD_ROOT)
function include(name)return assert(loadfile(root..name..'.lua'))()end
local callbacks={}
local mod={AddCallback=function(_,event,fn)
    callbacks[event]=callbacks[event]or{};table.insert(callbacks[event],fn)
end}
ModCallbacks={MC_POST_PEFFECT_UPDATE='tick',MC_USE_ITEM='use',
    MC_POST_NEW_ROOM='room',MC_POST_GAME_STARTED='start',MC_POST_UPDATE='post',
    MC_PRE_GAME_EXIT='exit',MC_EXECUTE_CMD='command',MC_PRE_PLAYER_ADD_COSTUME='costume_pre',MC_PRE_PLAYER_RENDER='pre_render'}
NullItemID={ID_LOST_CURSE=112}
local frame=0;local players={};local nullId=8000;local config={};local playerSerial=0
local diagnostic
-- The game owns JSON. This codec stub supplies an isolated round-trip object,
-- allowing tests to exercise save callbacks and merging without claiming JSON
-- library correctness. No user-controlled source is loaded here.
local snapshots={};local snapshotSerial=0
local function clone(value)
    if type(value)~='table'then return value end
    local out={};for key,item in pairs(value)do out[key]=clone(item)end;return out
end
package.preload.json=function()return{
    encode=function(value)snapshotSerial=snapshotSerial+1
        local key='snapshot-'..snapshotSerial;snapshots[key]=clone(value);return key
    end,
    decode=function(key)return assert(clone(snapshots[key]),'unknown snapshot')end
}end
local codec=require('json')
local savedData=codec.encode({existingGameplayState={ammo=2}})
local saves=0
function mod:HasData()return savedData~=nil end
function mod:LoadData()return savedData end
function mod:SaveData(value)savedData=value;saves=saves+1 end
function Game()return{GetFrameCount=function()return frame end,
    GetNumPlayers=function()return #players end,
    GetSeeds=function()return{GetStartSeed=function()return 321 end}end}end
Isaac={GetCostumeIdByPath=function(path)
        assert(path and path:find('174',1,true),'loop uses a legacy resource')
        nullId=nullId+1;return nullId
    end,
    GetItemIdByName=function(name)return name=='Hunter Chocolate Milk'and 999 or -1 end,
    GetItemConfig=function()return{GetCollectible=function(_,id)
        config[id]=config[id]or{id=id,ID=id};return config[id]
    end}end,
    GetPlayer=function(index)return assert(players[index+1])end,
    ConsoleOutput=function(text)diagnostic=text end,
    DebugString=function(text)diagnostic=text end}
local native='gfx/001.000_player_hunter_b_v153.anm2'
local base='gfx/characters/costumes/hunter_b_heads_v152.png'
local function player()
    playerSerial=playerSerial+1
    local p={kind=42,items={},effects={},data={},lost=false,ghost=false,dead=false,
        nulls={},nativeRemoved={},nativeAdded={},sprite={file=native,writes=0,loads=0},
        InitSeed=playerSerial,ControllerIndex=playerSerial}
    function p:GetPlayerType()return self.kind end
    function p:HasPlayerForm(id)return self.forms and self.forms[id]or false end
    function p:GetData()return self.data end
    function p:IsCoopGhost()return self.ghost end
    function p:IsDead()return self.dead end
    function p:GetCollectibleNum(id)return self.items[id]or 0 end
    function p:GetEffects()return{
        GetCollectibleEffectNum=function(_,id)return p.effects[id]or 0 end,
        HasNullEffect=function(_,id)assert(id==112);return p.lost end}
    end
    function p:GetSprite()return self.sprite end
    function p.sprite:GetFilename()return self.file end
    function p.sprite:GetAnimation()return self.animation or 'WalkDown' end
    function p.sprite:GetFrame()return self.frame or 0 end
    function p.sprite:GetOverlayAnimation()return self.overlay or '' end
    function p.sprite:GetOverlayFrame()return self.overlayFrame or 0 end
    function p.sprite:Load(file)self.file=file;self.animation='';self.frame=0;self.overlay='';self.overlayFrame=0 end
    function p.sprite:Play(animation)self.animation=animation end
    function p.sprite:SetFrame(frame)self.frame=frame end
    function p.sprite:PlayOverlay(animation)self.overlay=animation end
    function p.sprite:SetOverlayFrame(animation,frame)self.overlay=animation;self.overlayFrame=frame end
    function p.sprite:ReplaceSpritesheet(layer,path)
        assert(layer==4,'cosmetic modified a body, cape, ghost or collision layer')
        self.writes=self.writes+1;self.sheet=path
    end
    function p.sprite:LoadGraphics()self.loads=self.loads+1 end
    function p:RemoveCostume(item)
        self.nativeRemoved[item.id]=true;self.sprite.sheet='native-rebuild-clobbered'
    end
    function p:AddCostume(item)
        self.nativeAdded[item.id]=true;self.sprite.sheet='native-rebuild-clobbered'
    end
    function p:AddNullCostume(id)
        assert(not self.nulls[id],'duplicate animation instance');self.nulls[id]=true
        self.sprite.sheet='null-costume-rebuild-clobbered'
    end
    function p:TryRemoveNullCostume(id)
        self.nulls[id]=nil;self.sprite.sheet='null-costume-rebuild-clobbered'
    end
    return p
end
local function fire(event,...)
    for _,callback in ipairs(callbacks[event]or{})do callback(nil,...)end
end
local api=include('tainted_hunter_costumes')(mod,42)
assert(api==mod.HunterDynamicArt174)
local definitions=api.definitions;assert(#definitions==66,'wrong design count')
local alignmentProbe=player();players={alignmentProbe}
alignmentProbe.sprite.animation='Pickup';alignmentProbe.sprite.frame=3
alignmentProbe.sprite.overlay='HeadRight';alignmentProbe.sprite.overlayFrame=1
alignmentProbe.items[1]=1;api.sync(alignmentProbe)
assert(alignmentProbe.sprite.file=='gfx/001.000_player_hunter_b_v177_1.anm2')
assert(alignmentProbe.sprite.frame==3 and alignmentProbe.sprite.animation=='Pickup')
assert(alignmentProbe.sprite.overlay=='HeadRight'and alignmentProbe.sprite.overlayFrame==1)
alignmentProbe.items[1]=nil;api.sync(alignmentProbe)
assert(alignmentProbe.sprite.file==native,'neutral actor must retain its original head anchor')
-- Dead Eye hiding is cosmetic: ownership/effects and other characters remain intact.
local eye=player();players={eye};eye.items[373]=1;eye.effects[373]=2
api.sync(eye);assert(eye.nativeRemoved[373])
assert(eye.items[373]==1 and eye.effects[373]==2)
local writes=eye.sprite.writes;api.sync(eye);assert(eye.sprite.writes==writes,'hiding costume rebuilt every frame')
for _,callback in ipairs(callbacks.costume_pre)do
    assert(callback(nil,{ID=373},eye,false)==true)
    assert(callback(nil,{ID=373},eye,true)==true)
    assert(callback(nil,{ID=2},eye,false)==nil)
end
eye.kind=0
for _,callback in ipairs(callbacks.costume_pre)do assert(callback(nil,{ID=373},eye,false)==nil)end
api.sync(eye);assert(eye.nativeAdded[373],'type exit did not restore normal Dead Eye costume')
eye.kind=42;eye.nativeRemoved[373]=nil;players={eye};fire('start',true)
assert(eye.nativeRemoved[373]and eye.items[373]==1 and eye.effects[373]==2,'continue changed Dead Eye effects or restored its costume')
local legacy=player();legacy.items[7]=1;legacy.sprite.file='gfx/001.000_player_hunter_b_v176_7.anm2'
api.sync(legacy);assert(legacy.sprite.file=='gfx/001.000_player_hunter_b_v177_7.anm2')
local lookup={}
local exported=assert(io.open(TEST_MANIFEST_OUTPUT,'w'))
for _,entry in ipairs(definitions)do
    assert(entry.id and entry.sheet and entry.label and entry.zh,'incomplete design')
    assert(not lookup[entry.id],'duplicate design ID');lookup[entry.id]=entry
    exported:write(entry.id,'\t',entry.sheet,'\t',entry.path or '', '\n')
end
exported:close()

-- Every sheet is reachable on its own, with exactly one head replacement.
for _,entry in ipairs(definitions)do
    local p=player()
    if entry.id==122 or entry.id==34 or entry.id==77 or entry.id==83 or entry.id==93 then
        p.effects[entry.id]=1
    elseif entry.id==39 or entry.id==49 or entry.id==123 or entry.id==126 then
        fire('use',entry.id,nil,p)
    else p.items[entry.id]=1 end
    api.sync(p)
    assert(api.selected(p).id==entry.id,'unreachable costume '..entry.id)
    assert(p.sprite.sheet==entry.sheet)
    assert(p.sprite.writes==1 and p.sprite.loads==1)
    if entry.loop then assert(next(p.nulls),'loop not installed for '..entry.id)end
    local writes=p.sprite.writes;api.sync(p)
    assert(p.sprite.writes==writes,'unnecessary per-frame graphics reload')
end

-- Acquisition order and intrinsic priority, independent for each player.
local p,q=player(),player();players={p,q}
p.items[4]=1;q.items[68]=1;api.sync(p);api.sync(q)
p.items[7]=1;api.sync(p);assert(api.selected(p).id==7)
assert(api.selected(q).id==68)
p.items[118]=1;api.sync(p);assert(api.selected(p).id==118)
p.items[1]=1;api.sync(p);assert(api.selected(p).id==1)
p.items[51]=1;api.sync(p);assert(api.selected(p).id==1)
assert(p.sprite.sheet==lookup[1].sheet,'new non-winning item clobbered selected head')
local writes=p.sprite.writes;api.sync(p);assert(p.sprite.writes==writes)
p.items[1]=nil;api.sync(p);assert(api.selected(p).id==118)
assert(next(p.nulls)==nil,'cry loop survives removal')
p.items[118]=nil;api.sync(p);assert(api.selected(p).id==51)
assert(api.selected(q).id==68,'another player changed the choice')

-- Independent overlays and no costume instances leaking through shape changes.
p.items={[19]=1};q.items={[1]=1};api.sync(p);api.sync(q)
assert(next(p.nulls)and next(q.nulls))
p.items={};api.sync(p);assert(next(p.nulls)==nil and next(q.nulls))
assert(p.sprite.sheet==base)
q.lost=true;writes=q.sprite.writes;api.sync(q)
assert(q.sprite.writes==writes,'white-fire form texture was overwritten')
assert(next(q.nulls)==nil)
q.lost=false;api.sync(q);assert(api.selected(q).id==1 and next(q.nulls))
q.sprite.file='gfx/custom_special_form.anm2';writes=q.sprite.writes;api.sync(q)
assert(q.sprite.writes==writes and next(q.nulls)==nil)
q.sprite.file=native;api.sync(q);assert(q.sprite.writes==writes+1 and next(q.nulls))
q.kind=0;api.sync(q);assert(q.sprite.sheet==base and next(q.nulls)==nil)
assert(q.nativeAdded[1],'native costume not restored on permanent type exit')

local corpse=player();corpse.items[1]=1;api.sync(corpse)
assert(next(corpse.nulls)and corpse.sprite.sheet==lookup[1].sheet)
corpse.dead=true;api.sync(corpse)
assert(next(corpse.nulls)==nil,'cry loop appears over dead player')
assert(corpse.sprite.sheet==lookup[1].sheet,'removing death loop erased head binding')
corpse.dead=false;api.sync(corpse)
assert(next(corpse.nulls)and corpse.sprite.sheet==lookup[1].sheet)
corpse.sprite.animation='ForgottenDeath';api.sync(corpse)
assert(next(corpse.nulls)==nil,'death animation not respected before IsDead')
corpse.sprite.animation='WalkDown';api.sync(corpse)
assert(next(corpse.nulls)and corpse.sprite.sheet==lookup[1].sheet)

-- Native short/long active effects are observed, not guessed from ownership.
p=player();p.items[34]=1;api.sync(p);assert(not api.selected(p))
p.effects[34]=1;api.sync(p);assert(api.selected(p).id==34)
frame=100000;p.effects[34]=0;api.sync(p);assert(not api.selected(p))
p.items[130]=1;api.sync(p);assert(api.selected(p).id==130,'held pony state missing')
p.items={};fire('use',49,nil,p);api.sync(p);assert(api.selected(p).id==49)
frame=frame+21;api.sync(p);assert(not api.selected(p),'short reaction never expired')
fire('use',49,nil,p);api.sync(p);players={p};fire('room');assert(not api.selected(p))

-- Hidden replacement items, stale native graphics repair, and no stat mutation.
p.items={[999]=1};api.sync(p);assert(api.selected(p).id==69)
assert(p.items[999]==1 and p.items[69]==nil,'inventory was rewritten')
writes=p.sprite.writes;api.sync(p,true);assert(p.sprite.writes==writes+1)
writes=p.sprite.writes;api.sync(p,'appearance-revision-2');assert(p.sprite.writes==writes+1)
writes=p.sprite.writes;api.sync(p,'appearance-revision-2');assert(p.sprite.writes==writes)
players={p};fire('start');assert(api.selected(p).id==69)

-- Continue must retain observed acquisition order, preserving shared save data.
p=player();players={p};p.items[7]=1;api.sync(p);p.items[4]=1;api.sync(p)
assert(api.selected(p).id==4)
local previousSaves=saves;fire('exit',false);assert(saves==previousSaves)
fire('exit',true);assert(saves==previousSaves+1)
assert(codec.decode(savedData).existingGameplayState.ammo==2,'shared save data lost')
fire('start',true);assert(api.selected(p).id==4,'continue changed acquisition order')
diagnostic=nil;fire('command','unrelated');assert(diagnostic==nil)
writes=p.sprite.writes;fire('command','hunterartdiag')
assert(diagnostic:find('[Hunter art v1.78]',1,true)
    and diagnostic:find('selected=4',1,true)
    and diagnostic:find('sheet='..lookup[4].sheet,1,true),'diagnostic missing actual outfit')
assert(p.sprite.writes==writes,'diagnostic changed outfit state')
Isaac.ConsoleOutput=nil;diagnostic=nil;fire('command','hunterartdiag')
assert(diagnostic and diagnostic:find('selected=4',1,true),'DebugString fallback missing')

-- Use the uploaded EID modifier signature; preserve mechanics and avoid repeats.
local modifier,registrationCount,removedName
EID={player=p,getLanguage=function()return'zh_cn'end,
    removeDescriptionModifier=function(_,name)removedName=name end,
    addDescriptionModifier=function(_,name,condition,change)
        registrationCount=(registrationCount or 0)+1;modifier={condition,change}
    end}
fire('post');fire('post');assert(registrationCount==1)
assert(removedName=='Hunter cosmetic pack 173')
local desc={ObjType=5,ObjVariant=100,ObjSubType=999,Description='Existing gameplay details'}
assert(modifier[1](desc),'hidden milk item has no EID cosmetic description')
modifier[2](desc);local text=desc.Description;modifier[2](desc)
assert(desc.Description==text and text:find('Existing gameplay details',1,true)==1)
local deadEyeDesc={ObjType=5,ObjVariant=100,ObjSubType=373,Description='Native Dead Eye mechanics'}
assert(modifier[1](deadEyeDesc));modifier[2](deadEyeDesc)
assert(deadEyeDesc.Description:find('隐藏死亡之眼外观',1,true))
assert(not deadEyeDesc.Description:find('显示一种',1,true))
p.kind=0;assert(not modifier[1](desc),'EID modified a different character')
print('PASS: all66 reachable, actual lifecycle simulation, native-active effects, '
    ..'per-player precedence, three loop registrations, removal and form recovery, '
    ..'forced rebind, hidden milk, unchanged inventory, save-order restoration, '
    ..'shared save preservation, costume-rebuild binding order, death/revive loops, '
    ..'diagnostic output, Dead Eye costume-only cancellation/continue/effects, EID idempotence.')

assert(loadfile(root..'../tools/test_transformations.lua'))()({
    api=api,player=player,fire=fire,mod=mod,callbacks=callbacks,config=config,
    setFrame=function(value)frame=value end,
    setPlayers=function(value)players=value end,
    savedRoot=function()return codec.decode(savedData)end,
    root=root,
})
