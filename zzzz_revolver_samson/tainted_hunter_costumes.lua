-- Dynamic Hunter outfits. One integrated head owns the complete face/hood;
-- reference outfits with an independent effect use a native looping overlay.
-- This module never changes inventory, numerical caches, attacks or health.
return function(mod, playerType)
    local game = Game()
    local definitions = include('hunter_costume_manifest')
    local jsonOK, json = pcall(require, 'json')
    local nativeFile = 'gfx/001.000_player_hunter_b_v153.anm2'
    local alignment=include('hunter_head_alignment')
    local legacyAlignedFile = 'gfx/001.000_player_hunter_b_v175.anm2'
    local function owned(source)return source==nativeFile or source==legacyAlignedFile or source:match('^gfx/001%.000_player_hunter_b_v17[67]_%d+%.anm2$')~=nil end
    local baseSheet = 'gfx/characters/costumes/hunter_b_heads_v152.png'
    local byId, serial = {}, 0
    local nativeActive = {[34]=true, [77]=true, [83]=true, [93]=true}
    -- Short use reactions, never an estimate of the item's lasting duration.
    local reactions = {[39]=12, [49]=20, [123]=24, [126]=18}
    local defaultPriority = {[1]=1000, [118]=900, [122]=900, [83]=900}
    for _, entry in ipairs(definitions) do
        byId[entry.id] = entry
        if entry.loop then entry.costume = Isaac.GetCostumeIdByPath(entry.path) end
    end
    local function state(p)
        local d = p:GetData()
        d.hunterDynamic174 = d.hunterDynamic174 or {
            acquired={}, present={}, nativeSuppressed={}, reactions={}
        }
        return d.hunterDynamic174
    end
    local function normalized(path)
        return tostring(path or ''):lower():gsub('\\', '/')
    end
    local function isHunter(p)
        if not p or p:GetPlayerType() ~= playerType then return false end
        if p.IsCoopGhost and p:IsCoopGhost() then return false end
        local lost = NullItemID and NullItemID.ID_LOST_CURSE
        return not (lost and p:GetEffects():HasNullEffect(lost))
    end
    local function count(p, id)
        local e = p:GetEffects()
        local n = p:GetCollectibleNum(id, true) + e:GetCollectibleEffectNum(id)
        if id == 69 then
            local token = Isaac.GetItemIdByName('Hunter Chocolate Milk')
            if token and token > 0 then
                n = n + p:GetCollectibleNum(token, true) + e:GetCollectibleEffectNum(token)
            end
        end
        return n
    end
    local function enabled(p, s, id)
        local effects = p:GetEffects()
        if id == 122 or nativeActive[id] then return effects:GetCollectibleEffectNum(id) > 0 end
        if reactions[id] then
            return effects:GetCollectibleEffectNum(id) > 0
                or (s.reactions[id] or -1) >= game:GetFrameCount()
        end
        return count(p, id) > 0
    end
    local function choose(p, s)
        local winner, winnerPriority, winnerAcquired
        local signature = {}
        for _, entry in ipairs(definitions) do
            local n = count(p, entry.id)
            local yes = enabled(p, s, entry.id)
            if yes and not s.present[entry.id] then
                serial = serial + 1
                s.acquired[entry.id] = serial
            end
            s.present[entry.id] = yes
            signature[#signature+1] = entry.id .. ':' .. n .. ':' .. tostring(yes)
            if yes and entry.sheet then
                local priority = entry.priority or defaultPriority[entry.id] or 100
                local acquired = s.acquired[entry.id] or 0
                if not winner or priority > winnerPriority
                    or (priority == winnerPriority and acquired > winnerAcquired)
                    or (priority == winnerPriority and acquired == winnerAcquired and entry.id > winner.id) then
                    winner, winnerPriority, winnerAcquired = entry, priority, acquired
                end
            end
        end
        signature[#signature+1]='hidden373:'..count(p,373)
        return winner, table.concat(signature, ';')
    end
    local function removeLoop(p, s)
        if s.loopCostume then
            p:TryRemoveNullCostume(s.loopCostume)
            s.loopCostume = nil
        end
    end
    local function restoreNative(p, s)
        for id in pairs(s.nativeSuppressed) do
            -- Never resurrect native art for a hidden Hunter replacement.
            if p:GetCollectibleNum(id, true) + p:GetEffects():GetCollectibleEffectNum(id) > 0 then
                local item = Isaac.GetItemConfig():GetCollectible(id)
                if item then p:AddCostume(item) end
            end
        end
        s.nativeSuppressed = {}
    end
    local function suppressNative(p, s)
        for _, entry in ipairs(definitions) do
            if count(p, entry.id) > 0 or s.present[entry.id] then
                local item = Isaac.GetItemConfig():GetCollectible(entry.id)
                if item then
                    p:RemoveCostume(item)
                    s.nativeSuppressed[entry.id] = true
                end
            end
        end
        if count(p,373)>0 then
            local item=Isaac.GetItemConfig():GetCollectible(373)
            if item then p:RemoveCostume(item);s.nativeSuppressed[373]=true end
        end
    end
    -- REPENTOGON's documented return value TRUE cancels only the costume.
    -- Item ownership, Dead Eye charge and native damage remain untouched.
    if ModCallbacks.MC_PRE_PLAYER_ADD_COSTUME then
        mod:AddCallback(ModCallbacks.MC_PRE_PLAYER_ADD_COSTUME,function(_,item,p)
            if item and item.ID==373 and isHunter(p)then return true end
        end)
    end
    -- Keep all native animation state while changing only the head pivot table.
    local function actor(sprite, target)
        if normalized(sprite:GetFilename())==target then return false end
        local animation=sprite:GetAnimation()
        local frame=sprite.GetFrame and sprite:GetFrame()or 0
        local overlay=sprite.GetOverlayAnimation and sprite:GetOverlayAnimation()or ''
        local overlayFrame=sprite.GetOverlayFrame and sprite:GetOverlayFrame()or 0
        local scale,color,rotation=sprite.Scale,sprite.Color,sprite.Rotation
        local flipX,flipY,speed=sprite.FlipX,sprite.FlipY,sprite.PlaybackSpeed
        sprite:Load(target,true)
        if animation~=''then sprite:Play(animation,true);sprite:SetFrame(frame)end
        if overlay~=''then sprite:PlayOverlay(overlay,true);sprite:SetOverlayFrame(overlay,overlayFrame)end
        sprite.Scale,sprite.Color,sprite.Rotation=scale,color,rotation
        sprite.FlipX,sprite.FlipY,sprite.PlaybackSpeed=flipX,flipY,speed
        return true
    end
    local function sync(p, revision)
        if not p then return end
        local existing = p:GetData().hunterDynamic174
        if not isHunter(p) and not existing then return end
        local s = existing or state(p)
        local sprite = p:GetSprite()
        local source = normalized(sprite:GetFilename())
        local force = revision == true or (revision ~= nil and revision ~= s.revision)
        if owned(source) and s.source and s.source ~= source then force = true end
        s.source = source
        if revision ~= nil and revision ~= true then s.revision = revision end
        if not isHunter(p) then
            removeLoop(p, s)
            restoreNative(p, s)
            sprite = p:GetSprite()
            source = normalized(sprite:GetFilename())
            if s.sheet and owned(source) then
                -- The owning visual module handles Lost/special sprite files.
                local lost = NullItemID and NullItemID.ID_LOST_CURSE
                if not (lost and p:GetEffects():HasNullEffect(lost)) then
                    actor(sprite,nativeFile)
                    sprite:ReplaceSpritesheet(4, baseSheet)
                    sprite:LoadGraphics()
                end
            end
            s.sheet, s.selectedId, s.signature = nil, nil, nil
            s.present, s.reactions = {}, {}
            return
        end
        local entry, signature = choose(p, s)
        local changed = signature ~= s.signature
        if changed or force then suppressNative(p, s) end
        s.signature = signature
        s.selectedId = entry and entry.id or nil
        local sheet = entry and entry.sheet or baseSheet
        local previousLoop = s.loopCostume
        local animation = sprite.GetAnimation and sprite:GetAnimation() or ''
        local dead = (p.IsDead and p:IsDead())
            or tostring(animation):lower():find('death', 1, true) ~= nil
        local looping = entry and entry.loop and entry.costume and entry.costume >= 0
        if looping and owned(source) and not dead then
            if s.loopCostume ~= entry.costume or force then
                removeLoop(p, s)
                p:AddNullCostume(entry.costume)
                s.loopCostume = entry.costume
            end
        else removeLoop(p, s) end
        -- Costume removal/addition can rebuild native graphics. Apply the
        -- integrated head LAST, including on a signature change with the same
        -- selected head, so a costume rebuild cannot erase it in this frame.
        sprite = p:GetSprite()
        source = normalized(sprite:GetFilename())
        local target=entry and assert(alignment[entry.id],'Missing outfit alignment')or nativeFile
        local swapped=owned(source) and actor(sprite,target)
        if owned(source) and (swapped or sheet ~= s.sheet or force or changed or previousLoop ~= s.loopCostume) then
            sprite:ReplaceSpritesheet(4, sheet)
            sprite:LoadGraphics()
            s.sheet = sheet
        elseif not owned(source) then
            -- Reapply when the native Hunter sprite returns from a special form.
            s.sheet = nil
        end
        s.source=normalized(sprite:GetFilename())
    end
    local api = {sync=sync, state=state, definitions=definitions}
    function api.selected(p)
        local s = p:GetData().hunterDynamic174
        return s and byId[s.selectedId] or nil
    end
    mod.HunterDynamicArt174 = api
    if ModCallbacks.MC_EXECUTE_CMD then
        mod:AddCallback(ModCallbacks.MC_EXECUTE_CMD, function(_, command)
            if command ~= 'hunterartdiag' then return end
            local lines = {'[Hunter art v1.77] integrated heads and native dynamic overlays'}
            for i=0,game:GetNumPlayers()-1 do
                local p = Isaac.GetPlayer(i)
                local s = p:GetData().hunterDynamic174
                if p:GetPlayerType() == playerType or s then
                    lines[#lines+1] = string.format('P%d: selected=%s sheet=%s loop=%s source=%s',
                        i, tostring(s and s.selectedId or 'none'), tostring(s and s.sheet or baseSheet),
                        tostring(s and s.loopCostume or 'none'), normalized(p:GetSprite():GetFilename()))
                end
            end
            local output = table.concat(lines, '\n') .. '\n'
            if Isaac.ConsoleOutput then Isaac.ConsoleOutput(output)
            elseif Isaac.DebugString then Isaac.DebugString(output) end
        end)
    end
    -- Main visuals call sync after texture recovery. The safety pass also cleans
    -- up a previous Hunter whose player type no longer uses the Hunter visuals.
    mod:AddCallback(ModCallbacks.MC_POST_PEFFECT_UPDATE, function(_, p) sync(p) end)
    mod:AddCallback(ModCallbacks.MC_USE_ITEM, function(_, id, _, p)
        if isHunter(p) and reactions[id] then
            state(p).reactions[id] = game:GetFrameCount() + reactions[id]
        end
    end)
    mod:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, function()
        for i=0,game:GetNumPlayers()-1 do
            local p = Isaac.GetPlayer(i)
            local s = p:GetData().hunterDynamic174
            if s then s.reactions = {}; sync(p) end
        end
    end)
    local function runSeed()
        if game.GetSeeds then return game:GetSeeds():GetStartSeed() end
        return nil
    end
    local function playerKey(p)
        return tostring(p.InitSeed) .. ':' .. tostring(p.ControllerIndex)
    end
    local function savedRoot()
        if jsonOK and mod.HasData and mod:HasData() then
            local ok, value = pcall(json.decode, mod:LoadData())
            if ok and type(value) == 'table' then return value end
        end
        return {}
    end
    mod:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, function(_, continued)
        local root = continued and savedRoot() or {}
        local saved = root.hunterDynamic174
        if not saved or saved.seed ~= runSeed() then saved = nil end
        for i=0,game:GetNumPlayers()-1 do
            local p = Isaac.GetPlayer(i)
            local s = p:GetData().hunterDynamic174
            if s then removeLoop(p,s) end
            p:GetData().hunterDynamic174 = nil
            local record = saved and saved.players and saved.players[playerKey(p)]
            if record and type(record.acquired) == 'table' then
                s = state(p)
                for id, value in pairs(record.acquired) do
                    id = tonumber(id)
                    if id and byId[id] and type(value) == 'number' then
                        s.acquired[id] = value
                        s.present[id] = true
                        serial = math.max(serial, value)
                    end
                end
            end
            sync(p, true)
        end
    end)
    if ModCallbacks.MC_PRE_GAME_EXIT then
        mod:AddCallback(ModCallbacks.MC_PRE_GAME_EXIT, function(_, shouldSave)
            if not shouldSave or not jsonOK or not mod.SaveData then return end
            local root = savedRoot()
            local saved = {seed=runSeed(), players={}}
            for i=0,game:GetNumPlayers()-1 do
                local p = Isaac.GetPlayer(i)
                local s = p:GetData().hunterDynamic174
                if s and isHunter(p) then
                    local acquired = {}
                    for id, order in pairs(s.acquired) do
                        if s.present[id] then acquired[tostring(id)] = order end
                    end
                    saved.players[playerKey(p)] = {acquired=acquired}
                end
            end
            root.hunterDynamic174 = saved
            mod:SaveData(json.encode(root))
        end)
    end
    local registered
    local function installEID()
        if not EID or registered == EID or not EID.addDescriptionModifier then return end
        if EID.removeDescriptionModifier then EID:removeDescriptionModifier('Hunter cosmetic pack 173') end
        local function resolve(id)
            local token = Isaac.GetItemIdByName('Hunter Chocolate Milk')
            if token and token > 0 and id == token then id = 69 end
            if id==373 then return {id=373,zh='隐藏死亡之眼外观，保留连击与伤害效果',label='Dead Eye costume hidden; native charge and damage retained'}end
            return byId[id]
        end
        EID:addDescriptionModifier('Hunter dynamic outfits 174', function(desc)
            local p = EID.player or Isaac.GetPlayer(0)
            return p and p:GetPlayerType() == playerType and desc.ObjType == 5
                and desc.ObjVariant == 100 and resolve(desc.ObjSubType) ~= nil
        end, function(desc)
            local entry = resolve(desc.ObjSubType)
            local zh = EID:getLanguage() == 'zh_cn'
            local prefix = zh and '里猎手动态外观：' or 'Hunter dynamic outfit: '
            local suffix = prefix .. (zh and entry.zh or entry.label)
                .. (zh and '；整头造型按优先级及最近获得顺序显示一种' or '; one integrated outfit, chosen by priority then acquisition order')
            if entry.id==373 then suffix=prefix..(zh and entry.zh or entry.label)end
            local text = desc.Description or ''
            if not text:find(prefix, 1, true) then desc.Description = text .. '#' .. suffix end
            return desc
        end)
        registered = EID
    end
    mod:AddCallback(ModCallbacks.MC_POST_UPDATE, installEID)
    return api
end
