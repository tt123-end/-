-- Inventory, actual-damage observation, state persistence and optional EID.
return function(mod,playerType,R)
    local I={};local game=Game();local token=Isaac.GetItemIdByName(R.chemicalName)
    local chocolate=Isaac.GetItemIdByName(R.chocolateName)
    local function hunter(p)return p and p:Exists()and p:GetPlayerType()==playerType end
    local function d(p)
        local data=p:GetData();data.hunterItems163=data.hunterItems163 or {};return data.hunterItems163
    end
    local function real(p,id)return p:GetCollectibleNum(id,true)end
    function I.flatDamage(p)
        return 1.5*((token and token>0 and(real(p,token)+p:GetEffects():GetCollectibleEffectNum(token))or 0)+p:GetEffects():GetCollectibleEffectNum(154))
    end
    mod:AddCallback(ModCallbacks.MC_EVALUATE_CACHE,function(_,p,flag)
        if flag==CacheFlag.CACHE_DAMAGE and not hunter(p)and token and token>0 then
            -- The replacement remains a real +1.5 passive during temporary
            -- white-fire Lost; permanent character changes restore item154.
            p.Damage=p.Damage+1.5*(real(p,token)+p:GetEffects():GetCollectibleEffectNum(token))
        end
    end)
    local function replace(p,from,to,multiple)
        local n=real(p,from)
        if n<=0 or not to or to<=0 then return end
        for i=1,n do p:RemoveCollectible(from,true)end
        for i=1,n*multiple do p:AddCollectible(to,0,false)end
        return true
    end
    local function refreshWeapon(p)
        p:AddCacheFlags((CacheFlag.CACHE_WEAPON or 256)|CacheFlag.CACHE_FIREDELAY)
        p:EvaluateItems()
    end
    function I.update(p)
        if hunter(p)then
            replace(p,114,172,3);replace(p,637,359,1)
            if token and token>0 then replace(p,154,token,1)end
            if chocolate and chocolate>0 and replace(p,69,chocolate,1)then refreshWeapon(p)end
        elseif token and token>0 then
            -- Temporary white-fire Lost is not a permanent character conversion.
            if not p:GetEffects():HasNullEffect(NullItemID.ID_LOST_CURSE or 112)then replace(p,token,154,1)end
        end
        if not hunter(p)and chocolate and chocolate>0 and replace(p,chocolate,69,1)then refreshWeapon(p)end
        local state=d(p);local e=p:GetEffects()
        for _,rule in ipairs({{114,172,3},{637,359,1}})do
            local key="temp"..rule[1]
            local wanted=hunter(p)and e:GetCollectibleEffectNum(rule[1])*rule[3]or 0
            local previous=state[key]or 0
            if wanted>previous then e:AddCollectibleEffect(rule[2],false,wanted-previous)
            elseif wanted<previous then e:RemoveCollectibleEffect(rule[2],previous-wanted)end
            state[key]=wanted
        end
    end
    if ModCallbacks.MC_PRE_PLAYER_TAKE_DMG then
        mod:AddCallback(ModCallbacks.MC_PRE_PLAYER_TAKE_DMG,function(_,p)
            if hunter(p)and R.has(p,316)and R.scripted(p)then
                local weapon=p:GetWeapon(1)
                if weapon then weapon:SetCharge(0)end
            end
        end)
    end
    local function busy(p)
        local combat=p:GetData().hunterCombat155
        return combat and combat.untilFrame and game:GetFrameCount()<combat.untilFrame
    end
    local function qualifying(p,amount,flags,source)
        if not hunter(p)or amount<=0 or not R.has(p,316)or R.has(p,260)or not busy(p)then return false end
        -- Cursed Eye reacts to accepted self-damage as well: cursed doors,
        -- blood donation/beggars, sacrifice spikes and paid health costs.
        -- This rule is independent of the broken-heart damage exclusions.
        if flags&(DamageFlag.DAMAGE_FAKE or 0)~=0 then return false end
        return true
    end
    local function queueTeleport(p,flags)
        local state=d(p)
        state.cursedPending168={frame=game:GetFrameCount(),stage=game:GetLevel():GetStage(),room=game:GetLevel():GetCurrentRoomIndex(),
            throughDoor=(flags or 0)&(DamageFlag.DAMAGE_CURSED_DOOR or 0)~=0}
        state.cursedDiag168='accepted reload hit queued'
    end
    mod:AddPriorityCallback(ModCallbacks.MC_ENTITY_TAKE_DMG,-1000,function(_,entity,amount,flags,source)
        local p=entity:ToPlayer();if not hunter(p)then return end
        if R.blastCombo(p)and flags&(DamageFlag.DAMAGE_EXPLOSION or 0)~=0 then return false end
        d(p).reactionFrame=game:GetFrameCount()
        -- REPENTOGON confirms accepted damage in POST. Vanilla keeps only a
        -- health snapshot fallback, never a retained callback EntityRef.
        if not ModCallbacks.MC_POST_ENTITY_TAKE_DMG and qualifying(p,amount,flags,source)then
            d(p).cursedHealth168={hp=p:GetHearts()+p:GetSoulHearts()+p:GetBoneHearts()*2,frame=game:GetFrameCount(),flags=flags}
        end
    end,EntityType.ENTITY_PLAYER)
    if ModCallbacks.MC_POST_ENTITY_TAKE_DMG then
        mod:AddCallback(ModCallbacks.MC_POST_ENTITY_TAKE_DMG,function(_,entity,amount,flags,source)
            local p=entity:ToPlayer()
            if qualifying(p,amount,flags,source)then queueTeleport(p,flags)end
        end,EntityType.ENTITY_PLAYER)
    end
    mod:AddCallback(ModCallbacks.MC_POST_UPDATE,function()
        for i=0,game:GetNumPlayers()-1 do
            local p=Isaac.GetPlayer(i);local state=p:GetData().hunterItems163
            if state then
                local fallback=state.cursedHealth168
                if fallback then
                    state.cursedHealth168=nil
                    if hunter(p)and game:GetFrameCount()<=fallback.frame+2 and p:GetHearts()+p:GetSoulHearts()+p:GetBoneHearts()*2<fallback.hp then queueTeleport(p,fallback.flags)end
                end
                local event=state.cursedPending168
                if event and game:GetFrameCount()>event.frame then
                    local permitted=hunter(p)and not p:IsDead()and R.has(p,316)and not R.has(p,260)
                        and game:GetFrameCount()<=event.frame+120 and game:GetLevel():GetStage()==event.stage
                        and(event.throughDoor or game:GetLevel():GetCurrentRoomIndex()==event.room)
                    if not permitted then
                        state.cursedPending168=nil;state.cursedDiag168='queued teleport cancelled: player or floor changed'
                    elseif p:AreControlsEnabled()and p:IsExtraAnimationFinished()and game:GetRoom():GetFrameCount()>=2 then
                        -- Cursed-door damage may occur immediately before a
                        -- door transition. Carry that event into the new room
                        -- and wait for native transition/player update to end.
                        state.cursedPending168=nil
                        local seed=p:GetCollectibleRNG(316):RandomInt(2147483646)+1
                        state.cursedDiag168='random room teleport requested; seed='..seed
                        game:MoveToRandomRoom(false,seed,p)
                    end
                end
            end
        end
    end)
    if ModCallbacks.MC_PRE_USE_ITEM then
        mod:AddCallback(ModCallbacks.MC_PRE_USE_ITEM,function(_,id,_,p)
            if not hunter(p)then return end
            d(p).activeShot={frame=game:GetFrameCount(),item=id}
        end)
    end
    for _,name in ipairs({"MC_USE_CARD","MC_USE_PILL"})do
        if ModCallbacks[name]then
            mod:AddCallback(ModCallbacks[name],function(_,id,p)
                if hunter(p)then d(p).activeShot={frame=game:GetFrameCount(),item=name..":"..id}end
            end)
        end
    end
    function I.activeShot(p)
        local a=d(p).activeShot
        if a and a.frame==game:GetFrameCount()then return a.item end
    end
    function I.isReaction(p)return d(p).reactionFrame==game:GetFrameCount()end
    function I.clearRoom(p)
        local state=d(p)
        state.hurt=nil;state.cursedHealth168=nil;state.activeShot=nil;state.reactionFrame=nil
        if state.cursedPending168 and not state.cursedPending168.throughDoor then state.cursedPending168=nil end
        local red=p:GetData().hunterRedDamage157;if red then red.pending=nil end
    end
    -- The original item and its replacement share the normal save/rewind/reroll
    -- lifecycle. Only transient ammo/cooldowns need a separate native mod save.
    local json=require("json");local saved
    local function seed()return game:GetSeeds():GetStartSeed()end
    local function key(p)return tostring(p.InitSeed)..":"..tostring(p.ControllerIndex)end
    function I.capture(p)
        local b=p:GetData().hunterCombat155 or {};local f=game:GetFrameCount()
        return {ammo=b.ammo,capacity=b.capacity,reload=b.untilFrame and math.max(0,b.untilFrame-f)or nil,
            duration=b.duration,shot=math.max(0,(b.nextShotFrame or f)-f),scriptGate=p:GetData().hunterCompat163 and p:GetData().hunterCompat163.locked163 or nil}
    end
    function I.restore(p,s)
        if not s then return end
        local b=p:GetData().hunterCombat155 or {};p:GetData().hunterCombat155=b
        local f=game:GetFrameCount();b.ammo=s.ammo;b.capacity=s.capacity;b.duration=s.duration
        b.nextShotFrame=f+(s.shot or 0)
        b.untilFrame=s.reload and s.reload>0 and f+s.reload or nil
        b.startedFrame=b.untilFrame and b.untilFrame-(s.duration or s.reload)or nil
        b.lastVolleyFrame=nil;b.group=nil
        p.FireDelay=math.max(0,s.reload or s.shot or 0)
    end
    mod:AddCallback(ModCallbacks.MC_POST_GAME_STARTED,function(_,continued)
        saved=nil
        if continued and mod:HasData()then
            local ok,value=pcall(json.decode,mod:LoadData())
            if ok and value and value.hunterCompat163 and value.hunterCompat163.seed==seed()then saved=value.hunterCompat163.players end
        end
        for i=0,game:GetNumPlayers()-1 do
            local p=Isaac.GetPlayer(i)
            if saved then
                local record=saved[key(p)]
                if hunter(p)then I.restore(p,record)
                elseif record and record.scriptGate then p.FireDelay=0 end
            end
        end
    end)
    mod:AddCallback(ModCallbacks.MC_PRE_GAME_EXIT,function(_,shouldSave)
        if not shouldSave then return end
        local root={}
        if mod:HasData()then local ok,value=pcall(json.decode,mod:LoadData());if ok and type(value)=="table"then root=value end end
        local data={seed=seed(),players={}}
        for i=0,game:GetNumPlayers()-1 do
            local p=Isaac.GetPlayer(i);local gate=p:GetData().hunterCompat163
            if hunter(p)or(gate and gate.locked163)then
                local record=I.capture(p);data.players[key(p)]=record
                if gate and gate.locked163 then p.FireDelay=math.max(0,record.reload or record.shot or 0)end
            end
        end
        root.hunterCompat163=data;mod:SaveData(json.encode(root))
    end)
    I.token=token;I.chocolate=chocolate
    return I
end
