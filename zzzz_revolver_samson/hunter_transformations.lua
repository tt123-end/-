-- Visual-only PlayerForm and Old Wardrobe bridge. No inventory, effects,
-- CanFly, SpriteScale or numerical caches are ever written by this module.
return function(mod, playerType, items, isHunter)
    local game = Game()
    local definitions = include('hunter_form_manifest')
    local anchors = include('hunter_wing_anchors')
    local forms, native, byItem = {}, {}, {}
    for _, entry in ipairs(definitions) do
        forms[entry.form] = entry
        if entry.native then native[entry.native] = entry end
    end
    for _, entry in ipairs(items) do byItem[entry.id] = entry end
    local api = {definitions=definitions}
    local sync
    local function state(p)
        local data = p:GetData()
        data.hunterDynamic174 = data.hunterDynamic174 or {
            acquired={}, present={}, nativeSuppressed={}, reactions={}
        }
        local s = data.hunterDynamic174
        s.formPresent, s.formAcquired = s.formPresent or {}, s.formAcquired or {}
        s.wardrobe = s.wardrobe or {mode='auto', hiddenItems={}, hiddenForms={}}
        return s
    end
    local function has(p, id)
        return p.HasPlayerForm and p:HasPlayerForm(id) or false
    end
    local function visible(t, id)
        return not (t[id] or t[tostring(id)])
    end
    local function refresh(p)
        if sync then sync(p, true) end
    end
    function api.attach(callback) sync=callback end
    function api.itemVisible(p, id)
        return visible(state(p).wardrobe.hiddenItems, id)
    end
    function api.choose(p, s, item, signature)
        state(p)
        local wardrobe=s.wardrobe
        local winner, flight, newest, wingNewest
        local bits={signature, 'wardrobe:'..tostring(s.wardrobeRevision or 0)}
        for _, entry in ipairs(definitions) do
            local yes=has(p,entry.form)
            if yes and not s.formPresent[entry.form] then
                s.formSerial=(s.formSerial or 0)+1
                s.formAcquired[entry.form]=s.formSerial
            end
            s.formPresent[entry.form]=yes
            bits[#bits+1]='form'..entry.form..':'..tostring(yes)
            local order=s.formAcquired[entry.form] or 0
            if yes and visible(wardrobe.hiddenForms,entry.form) then
                if not winner or order>newest then winner,newest=entry,order end
                if entry.wing and (not flight or order>wingNewest) then flight,wingNewest=entry,order end
            end
        end
        if wardrobe.mode=='base' then
            winner,flight=nil,nil
        elseif wardrobe.mode=='form' and forms[wardrobe.id] then
            winner=forms[wardrobe.id]
            if winner.wing then flight=winner end
        elseif wardrobe.mode=='item' and byItem[wardrobe.id] and visible(wardrobe.hiddenItems,wardrobe.id) then
            winner=byItem[wardrobe.id]
        else winner=winner or item end
        local wing = p.CanFly and flight and flight.wing or nil
        s.selectedForm=winner and winner.form
        s.wingStyle=wing
        return winner,table.concat(bits,';')..';wing:'..tostring(wing)
    end
    function api.suppress(p,s)
        s.formNativeSuppressed=s.formNativeSuppressed or {}
        for _,entry in ipairs(definitions) do
            if entry.native and has(p,entry.form) then
                p:TryRemoveNullCostume(entry.native)
                s.formNativeSuppressed[entry.form]=true
            end
        end
    end
    function api.cleanup(p,s)
        s.wingStyle,s.wingSprite,s.wingSpriteStyle=nil,nil,nil
        for id in pairs(s.formNativeSuppressed or {}) do
            local entry=forms[id]
            if entry and entry.native and has(p,id) then p:AddNullCostume(entry.native) end
        end
        s.formNativeSuppressed={}
    end
    function api.selected(s)
        return s and s.selectedForm~=nil and forms[s.selectedForm] or nil
    end
    function api.save(s)
        return {wardrobe=s.wardrobe,formAcquired=s.formAcquired,formSerial=s.formSerial}
    end
    function api.restore(p,record)
        if type(record)~='table' then return end
        local s=state(p)
        if type(record.wardrobe)=='table' then
            local value=record.wardrobe
            local mode=value.mode
            local id=tonumber(value.id)
            if mode=='auto' or mode=='base' or (mode=='item' and byItem[id]) or (mode=='form' and forms[id]) then
                s.wardrobe.mode,s.wardrobe.id=mode,id
            end
            for key,lookup in pairs({hiddenItems=byItem,hiddenForms=forms}) do
                if type(value[key])=='table' then
                    for entry,hidden in pairs(value[key]) do
                        entry=tonumber(entry)
                        if lookup[entry] and hidden==true then s.wardrobe[key][entry]=true end
                    end
                end
            end
        end
        if type(record.formAcquired)=='table' then
            for id,order in pairs(record.formAcquired) do
                id=tonumber(id)
                if forms[id] and type(order)=='number' and order>=0 and order<1e12 then
                    s.formAcquired[id],s.formPresent[id]=order,true
                    s.formSerial=math.max(s.formSerial or 0,order)
                end
            end
        end
    end
    -- The supplied wardrobe has no visibility API. A small companion patch
    -- explicitly forwards user actions; our own RemoveCostume never looks like
    -- a request to undress. Native/custom UI previews share renderWings below.
    local bridge={isHunter=isHunter}
    function bridge.formNative(id) return forms[id] and forms[id].native end
    local function changed(p)
        local s=state(p)
        s.wardrobeRevision=(s.wardrobeRevision or 0)+1
        refresh(p)
    end
    function bridge.select(p,key)
        if not isHunter(p) or type(key)~='string' or key:sub(1,5)~='H178:' then return false end
        local s=state(p)
        if key=='H178:AUTO' then
            s.wardrobe={mode='auto',hiddenItems={},hiddenForms={}}
        elseif key=='H178:BASE' then
            s.wardrobe.mode,s.wardrobe.id='base',nil
        else
            local id=tonumber(key:match('^H178:F(%d+)$'))
            if id and forms[id] then
                if forms[id].wing and not p.CanFly then return true end
                s.wardrobe.mode,s.wardrobe.id='form',id
                s.wardrobe.hiddenForms[id]=nil;s.wardrobe.hiddenForms[tostring(id)]=nil
            else
                id=tonumber(key:match('^H178:I(%d+)$'))
                if not byItem[id] then return false end
                s.wardrobe.mode,s.wardrobe.id='item',id
                s.wardrobe.hiddenItems[id]=nil;s.wardrobe.hiddenItems[tostring(id)]=nil
            end
        end
        changed(p)
        return true
    end
    function bridge.undress(p,key)
        if not isHunter(p) or type(key)~='string' or key:sub(1,5)~='H178:' then return false end
        local s=state(p)
        if key=='H178:AUTO' or key=='H178:BASE' then return bridge.select(p,'H178:BASE') end
        local id=tonumber(key:match('^H178:F(%d+)$'))
        if id and forms[id] then
            s.wardrobe.hiddenForms[id]=true
            if s.wardrobe.mode=='form' and s.wardrobe.id==id then s.wardrobe.mode='auto' end
        else
            id=tonumber(key:match('^H178:I(%d+)$'))
            if not byItem[id] then return false end
            s.wardrobe.hiddenItems[id]=true
            if s.wardrobe.mode=='item' and s.wardrobe.id==id then s.wardrobe.mode='auto' end
        end
        changed(p)
        return true
    end
    function bridge.item(p,value)
        if not isHunter(p) or not value or not byItem[value.id] then return false end
        local s=state(p)
        if value.visible then
            s.wardrobe.hiddenItems[value.id]=nil;s.wardrobe.hiddenItems[tostring(value.id)]=nil
            s.wardrobe.mode,s.wardrobe.id='item',value.id
        else
            s.wardrobe.hiddenItems[value.id]=true
            if s.wardrobe.mode=='item' and s.wardrobe.id==value.id then s.wardrobe.mode='auto' end
        end
        changed(p)
        return true
    end
    function bridge.form(p,value)
        local entry=value and native[value.id]
        if not isHunter(p) or not entry then return false end
        if value.visible then return bridge.select(p,'H178:F'..entry.form) end
        return bridge.undress(p,'H178:F'..entry.form)
    end
    function bridge.visibility(p,itemsHidden,formVisibility)
        if not isHunter(p) then return end
        local s=state(p);local dirty=false
        for id,hidden in pairs(itemsHidden or {}) do
            if hidden and byItem[id] and visible(s.wardrobe.hiddenItems,id) then
                s.wardrobe.hiddenItems[id]=true;dirty=true
            end
        end
        for id,value in pairs(formVisibility or {}) do
            local entry=native[id]
            if entry and (value==0 or value==2) and visible(s.wardrobe.hiddenForms,entry.form) then
                s.wardrobe.hiddenForms[entry.form]=true;dirty=true
            end
        end
        if dirty then changed(p) end
    end
    function bridge.clear(p)
        if not isHunter(p) then return false end
        return bridge.select(p,'H178:BASE')
    end
    function bridge.refresh(p)
        if isHunter(p) then refresh(p);return true end
        return false
    end
    local ordinary={WalkDown=true,WalkUp=true,WalkRight=true,WalkLeft=true,
        Pickup=true,Hit=true,Happy=true,Sad=true,LiftItem=true,HideItem=true,UseItem=true,
        PickupWalkDown=true,PickupWalkUp=true,PickupWalkRight=true,PickupWalkLeft=true}
    function api.renderWings(p,position,preview)
        if not isHunter(p) or p.Visible==false or (p.IsDead and p:IsDead()) then return end
        local s=p:GetData().hunterDynamic174
        if not s or not s.wingStyle or not p.CanFly then return end
        local sprite=p:GetSprite();local animation=sprite:GetAnimation()
        local file=(sprite:GetFilename() or ''):lower():gsub('\\','/')
        if not file:find('001.000_player_hunter_b_v',1,true) or not ordinary[animation] then return end
        local style=s.wingStyle=='emerald' and 'fly' or s.wingStyle
        if not s.wingSprite or s.wingSpriteStyle~=style then
            s.wingSprite=Sprite()
            s.wingSprite:Load('gfx/characters/hunter_forms178/wings_'..style..'.anm2',true)
            s.wingSpriteStyle=style
        end
        local direction=animation:match('(Down)$') or animation:match('(Up)$')
            or animation:match('(Left)$') or animation:match('(Right)$') or 'Down'
        local path=anchors[animation]
        local index=sprite:GetFrame()+1
        local point=path and path[(index-1)%#path+1] or {0,-8.4}
        local scale=sprite.Scale or Vector(1,1)
        local wing=s.wingSprite
        wing.Scale=Vector(.33*scale.X,.33*scale.Y)
        wing.Color=sprite.Color
        wing.Rotation=sprite.Rotation or 0
        wing.FlipX,wing.FlipY=sprite.FlipX,sprite.FlipY
        -- Game ticks freeze on pause. Frame selection is independent of the
        -- walking/head frame, so standing and charging keep beating wings.
        wing:SetFrame(direction,game:GetFrameCount()%12)
        local angle=math.rad(wing.Rotation)
        local x,y=point[1]*scale.X,point[2]*scale.Y
        local offset=Vector(x*math.cos(angle)-y*math.sin(angle),x*math.sin(angle)+y*math.cos(angle))
        wing:Render(position+offset,Vector(0,0),Vector(0,0))
    end
    bridge.renderWings=api.renderWings
    HunterWardrobe178=bridge
    if ModCallbacks.MC_PRE_PLAYER_RENDER then
        mod:AddCallback(ModCallbacks.MC_PRE_PLAYER_RENDER,function(_,p)
            -- Same screen-space camera convention as Hunter's existing renderer.
            -- Wardrobe preview uses its explicit absolute screen anchor instead.
            api.renderWings(p,Isaac.WorldToScreen(p.Position)+(p.SpriteOffset or Vector(0,0)),false)
        end)
    end
    local function registerWardrobe()
        if not OWR or not OWR.AddCostumeToList or not OWR.GetCostumeName then return end
        local found=false
        for i=0,game:GetNumPlayers()-1 do if isHunter(Isaac.GetPlayer(i)) then found=true end end
        if not found or OWR.GetCostumeName('H178:AUTO') then return end
        local location='gfx/characters/hunter_forms178/wardrobe_selector.anm2'
        OWR.AddCostumeToList('H178:AUTO','HUNTER: Automatic / restore',location,false)
        OWR.AddCostumeToList('H178:BASE','HUNTER: Original appearance',location,false)
        for _,entry in ipairs(definitions) do
            if entry.form<14 then OWR.AddCostumeToList('H178:F'..entry.form,'H-Form: '..entry.label,location,entry.wing~=nil) end
        end
        for _,entry in ipairs(items) do
            local name=entry.label:match('^[^:]+') or entry.label
            OWR.AddCostumeToList('H178:I'..entry.id,'H-Item: '..name,location,false)
        end
    end
    mod:AddCallback(ModCallbacks.MC_POST_UPDATE,registerWardrobe)
    return api
end
