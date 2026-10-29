-- Hunter art pack: visual-only, per-player null costumes. No stat/inventory edits.
return function(mod, playerType)
    local game=Game()
    local definitions=include('hunter_costume_manifest')
    local byId={}
    local active={[34]=true,[39]=true,[49]=true,[77]=true,[83]=true,[93]=true,[123]=true,[126]=true,[130]=true}
    local timed={[39]=120,[49]=30,[77]=180,[93]=180,[130]=60}
    for _,entry in ipairs(definitions)do
        entry.costume=Isaac.GetCostumeIdByPath(entry.path)
        byId[entry.id]=entry
    end
    local function state(p)
        local d=p:GetData()
        d.hunterArt173=d.hunterArt173 or {applied={},uses={}}
        return d.hunterArt173
    end
    local function isHunter(p)
        return p:GetPlayerType()==playerType and not p:IsCoopGhost()
            and not p:GetEffects():HasNullEffect(NullItemID.ID_LOST_CURSE)
    end
    local function count(p,id)
        local n=p:GetCollectibleNum(id,true)+p:GetEffects():GetCollectibleEffectNum(id)
        if id==69 then
            local token=Isaac.GetItemIdByName('Hunter Chocolate Milk')
            if token>0 then n=n+p:GetCollectibleNum(token,true)+p:GetEffects():GetCollectibleEffectNum(token)end
        end
        return n
    end
    local function wanted(p,s,id)
        if not isHunter(p)then return false end
        if id==122 then return p:GetEffects():HasCollectibleEffect(id)end
        if active[id]then
            return p:GetEffects():HasCollectibleEffect(id)or(s.uses[id]and s.uses[id]>=game:GetFrameCount())or false
        end
        return count(p,id)>0
    end
    local function update(_,p)
        local s=state(p)
        for _,entry in ipairs(definitions)do
            local yes=wanted(p,s,entry.id)
            if yes and not s.applied[entry.id]and entry.costume>=0 then
                -- Suppress only this item's native outfit on this player.
                -- Keep item ownership and its effects entirely native.
                local item=Isaac.GetItemConfig():GetCollectible(entry.id)
                if item then p:RemoveCostume(item)end
                p:AddNullCostume(entry.costume)
                s.applied[entry.id]=true
            elseif not yes and s.applied[entry.id]then
                p:TryRemoveNullCostume(entry.costume)
                s.applied[entry.id]=nil
                if p:GetPlayerType()~=playerType and count(p,entry.id)>0 then
                    local item=Isaac.GetItemConfig():GetCollectible(entry.id)
                    if item then p:AddCostume(item)end
                end
            end
        end
    end
    mod:AddCallback(ModCallbacks.MC_POST_PEFFECT_UPDATE,update)
    mod:AddCallback(ModCallbacks.MC_USE_ITEM,function(_,id,_,p)
        if isHunter(p)and active[id]then state(p).uses[id]=game:GetFrameCount()+(timed[id]or 100000000)end
    end)
    mod:AddCallback(ModCallbacks.MC_POST_NEW_ROOM,function()
        for i=0,game:GetNumPlayers()-1 do
            local p=Isaac.GetPlayer(i);state(p).uses={};update(nil,p)
        end
    end)
    -- EID's item mechanics text remains owned by the existing compatibility
    -- module. This additional modifier only appends the cosmetic description.
    local registered
    mod:AddCallback(ModCallbacks.MC_POST_UPDATE,function()
        if not EID or registered==EID or not EID.addDescriptionModifier then return end
        EID:addDescriptionModifier('Hunter cosmetic pack 173',function(desc)
            local p=EID.player or Isaac.GetPlayer(0)
            return p and p:GetPlayerType()==playerType and desc.ObjType==5 and desc.ObjVariant==100 and byId[desc.ObjSubType]~=nil
        end,function(desc)
            local entry=byId[desc.ObjSubType]
            local zh=EID:getLanguage()=='zh_cn'
            desc.Description=(desc.Description or '')..'#'..(zh and '里猎手专属外观：'..entry.zh or 'Hunter costume: '..entry.label)
            return desc
        end)
        registered=EID
    end)
end
