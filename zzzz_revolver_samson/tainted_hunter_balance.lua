-- Tainted-only native stat replacement. Inventory and weapon effects remain
-- real: selected native item stats are masked only during numeric cache work.
return function(mod,playerType)
    -- Isaac does not expose the Lua debug library. Keep both protected calls
    -- independent of it so initialization and cleanup work in the game sandbox.
    local B={};local game=Game()
    B.ids={2,153,152,169,229,310,118,52,149,531,245,556}
    -- Native negative tears use an additional -6*ups branch. Use that same
    -- piecewise delay for baseline inversion and cap accounting.
    local function basicDelay(ups)
        if ups<-.77 then return 16-6*ups end
        local delay=16-6*math.sqrt(math.max(0,1+1.3*ups))
        if ups<0 then delay=delay-6*ups end
        return delay
    end
    local lo,hi=-10,10
    local targetDelay=30/2.4-1
    for _=1,64 do
        local mid=(lo+hi)/2
        if basicDelay(mid)>targetDelay then lo=mid else hi=mid end
    end
    local baseTearsUp=(lo+hi)/2
    -- These weapon-type bits survive BlockCollectible and retain their own
    -- native delay penalties. Mask only their numerical evaluation; restore
    -- the exact flags before returning, without replacing any Weapon object.
    local statWeapons={
        {id=229,kind=WeaponType.WEAPON_MONSTROS_LUNGS},
        {id=118,kind=WeaponType.WEAPON_BRIMSTONE},
        {id=52,kind=WeaponType.WEAPON_BOMBS},
    }
    local fields={[CacheFlag.CACHE_DAMAGE]='Damage',[CacheFlag.CACHE_FIREDELAY]='MaxFireDelay',[CacheFlag.CACHE_SHOTSPEED]='ShotSpeed'}
    local numeric=CacheFlag.CACHE_DAMAGE|CacheFlag.CACHE_FIREDELAY|CacheFlag.CACHE_SHOTSPEED
    local function hunter(p)return p and p:Exists()and p:GetPlayerType()==playerType end
    local function state(p)local d=p:GetData();d.hunterBalance170=d.hunterBalance170 or{dirty=numeric};return d.hunterBalance170 end
    local function raw(p,id)
        if p:IsCollectibleBlocked(id)then return 0 end
        local e=p:GetEffects()
        return p:GetCollectibleNum(id,true,true)+(e and e:GetCollectibleEffectNum(id)or 0)
    end
    function B.count(p,id)
        local d=state(p)
        if d.counts and d.counts[id]~=nil then return d.counts[id]end
        return raw(p,id)
    end
    function B.has(p,id)return B.count(p,id)>0 end
    function B.group(p)
        if B.has(p,245)then return 0,1 end
        if B.has(p,229)then return 229,.23 end
        if B.has(p,153)then return 153,.42 end
        if B.has(p,2)then return 2,.5 end
        return 0,1
    end
    function B.itemMultiplier(p,id)
        local group,m=B.group(p)
        if id==2 or id==153 or id==229 then return id==group and m or 1 end
        if id==152 then return .75 end
        if id==310 then return 1.35 end
        if id==52 then return B.has(p,149)and 1 or .8 end
        if id==169 or id==531 then return 1 end
        if id==245 and B.has(p,169)then return 1 end
    end
    function B.damageMultiplier(p)
        local _,m=B.group(p)
        if B.has(p,152)then m=m*.75 end
        if B.has(p,310)then m=m*1.35 end
        if B.has(p,52)and not B.has(p,149)then m=m*.8 end
        return m
    end
    function B.flatDamage(p)return 8*B.count(p,169)+3*B.count(p,531)end
    function B.active(p,flag)return state(p).active==flag end
    function B.mark(p,flag)
        local d=state(p)
        if not d.active and not d.working then d.dirty=d.dirty|(flag&numeric)end
    end
    local function selected(p,flag)
        if flag==CacheFlag.CACHE_FIREDELAY then return{2,153,152,169,229,310,118,52,149,531,556}end
        if flag==CacheFlag.CACHE_SHOTSPEED then return{310}end
        local ids={152,169,310,149,531}
        if B.has(p,169)then ids[#ids+1]=245 end
        return ids
    end
    local function signature(p)
        local t={}
        for _,id in ipairs(B.ids)do t[#t+1]=id..':'..raw(p,id)end
        return table.concat(t,';')
    end
    -- Only called outside MC_EVALUATE_CACHE, after draining pending native
    -- caches. Setting CacheFlags=0 prevents Block/Unblock from rebuilding a
    -- weapon: their automatic EvaluateItems calls have no queued work.
    local function numericCache(p,flag)
        local d=state(p);local edits={};local blocked={};local effectEdits={};local weaponEdits={};local field=fields[flag]
        local prior=p[field];local counts={}
        for _,id in ipairs(B.ids)do counts[id]=raw(p,id)end
        d.counts=counts;d.active=flag
        local config=Isaac.GetItemConfig()
        local rock=p:HasCollectible(562,true,true)or p:GetEffects():HasCollectibleEffect(562)
        local savedRock
        if rock then
            if flag==CacheFlag.CACHE_DAMAGE then savedRock=p:GetRockBottomDamage()
            elseif flag==CacheFlag.CACHE_FIREDELAY then savedRock=p:GetRockBottomMaxFireDelay()
            elseif flag==CacheFlag.CACHE_SHOTSPEED then savedRock=p:GetRockBottomShotSpeed()end
        end
        local ok,result=xpcall(function()
            for _,id in ipairs(selected(p,flag))do
                if (counts[id]or 0)>0 and not p:IsCollectibleBlocked(id)then
                    local item=assert(config:GetCollectible(id),'Missing native item config '..id)
                    edits[#edits+1]={item=item,flags=item.CacheFlags,id=id};item.CacheFlags=0
                end
            end
            for _,edit in ipairs(edits)do
                local effect=p:GetEffects():GetCollectibleEffect(edit.id)
                if effect and effect.Count>0 then
                    effectEdits[#effectEdits+1]={effect=effect,count=effect.Count};effect.Count=0
                end
            end
            for _,edit in ipairs(edits)do blocked[#blocked+1]=edit.id;p:BlockCollectible(edit.id)end
            if flag==CacheFlag.CACHE_FIREDELAY then
                for _,entry in ipairs(statWeapons)do
                    if (counts[entry.id]or 0)>0 and p:HasWeaponType(entry.kind)then
                        weaponEdits[#weaponEdits+1]=entry.kind
                        p:EnableWeaponType(entry.kind,false)
                    end
                end
            end
            p:AddCacheFlags(flag);p:EvaluateItems()
            return p[field]
        end,tostring)
        -- Keep every config mask quiet until *all* item blocks are undone.
        -- Cleanup runs on both success and failure and never removes inventory.
        local cleanupError
        for i=#weaponEdits,1,-1 do
            local clean,err=pcall(p.EnableWeaponType,p,weaponEdits[i],true)
            if not clean then clean,err=pcall(p.EnableWeaponType,p,weaponEdits[i],true)end
            if not clean then cleanupError=err end
        end
        for i=#blocked,1,-1 do
            local clean,err=pcall(p.UnblockCollectible,p,blocked[i])
            if not clean then clean,err=pcall(p.UnblockCollectible,p,blocked[i])end
            if not clean then cleanupError=err end
        end
        for _,edit in ipairs(effectEdits)do edit.effect.Count=edit.count end
        for _,edit in ipairs(edits)do edit.item.CacheFlags=edit.flags end
        d.active=nil;d.counts=nil
        if rock and savedRock~=nil then
            -- A numeric recomputation must not permanently improve the native
            -- Rock Bottom history simply because penalties were masked.
            if flag==CacheFlag.CACHE_DAMAGE then p:SetRockBottomDamage(savedRock)
            elseif flag==CacheFlag.CACHE_FIREDELAY then p:SetRockBottomMaxFireDelay(savedRock)
            elseif flag==CacheFlag.CACHE_SHOTSPEED then p:SetRockBottomShotSpeed(savedRock)end
        end
        if not ok or cleanupError then p[field]=prior;error(cleanupError or result)end
        p[field]=result
    end
    function B.refresh(p)
        if not hunter(p)or p:IsDead()then return end
        local d=state(p);if d.working or d.active then return end
        local key=signature(p)
        if key~=d.signature then d.signature=key;d.dirty=numeric end
        if d.dirty==0 then return end
        local wanted=d.dirty;d.dirty=0;d.working=true
        local ok,err=xpcall(function()
            -- Drain original cache requests before changing any per-item flags.
            p:EvaluateItems()
            for _,flag in ipairs({CacheFlag.CACHE_DAMAGE,CacheFlag.CACHE_FIREDELAY,CacheFlag.CACHE_SHOTSPEED})do
                if wanted&flag~=0 then numericCache(p,flag)end
            end
        end,tostring)
        d.working=nil
        if not ok then
            d.dirty=d.dirty|wanted
            if d.error~=err then Isaac.DebugString('[Hunter v1.72 balance] '..tostring(err))end
            d.error=err
        else d.error=nil end
    end
    if ModCallbacks.MC_EVALUATE_STAT then
        mod:AddCallback(ModCallbacks.MC_EVALUATE_STAT,function(_,p,stage,value)
            if not hunter(p)then return end
            local d=state(p)
            if stage==EvaluateStatStage.TEARS_UP then
                -- Native Isaac starts at30/11. Shift the basic tears-up input
                -- to a native2.4, retain the native5 soft cap, then apply x0.2.
                -- No cap probe, penalty compensation or0.6 floor remains.
                d.tearsUp=value+baseTearsUp
                return d.tearsUp
            elseif stage==EvaluateStatStage.FLAT_TEARS then d.flatTears=value
            elseif stage==EvaluateStatStage.FLAT_DAMAGE and d.active==CacheFlag.CACHE_DAMAGE then
                return value+B.flatDamage(p)
            end
        end)
    end
    function B.cap(p,nativeRate)
        local d=state(p);local flat=d.flatTears
        if flat and flat>0 and d.tearsUp then
            local cap=p.GetTearsCap and p:GetTearsCap()or 5
            local basicDelay=math.max(30/math.max(.001,cap)-1,basicDelay(d.tearsUp))
            local flatBonus=flat-30/(basicDelay+1)
            d.capRate=math.max(.0001,(cap+flatBonus)*(nativeRate/flat)*.2)
        else d.capRate=1 end
        return d.capRate
    end
    local function update(_,p)
        if hunter(p)then B.refresh(p)end
    end
    if ModCallbacks.MC_PRE_PLAYER_UPDATE then mod:AddPriorityCallback(ModCallbacks.MC_PRE_PLAYER_UPDATE,-900000,update)end
    mod:AddPriorityCallback(ModCallbacks.MC_POST_PEFFECT_UPDATE,-900000,update)
    return B
end
