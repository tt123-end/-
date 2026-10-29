-- v1.70: no negative tears-multiplier compensation; selected item stats replaced.
return function(mod,playerType)
    local stats={speed=1,baseTears=2.4,tearsMultiplier=.2,softCap=1,baseDamage=3.5,damageMultiplier=1.2,shotSpeed=1.6,range=12}
    local balance=include('tainted_hunter_balance')(mod,playerType);stats.balance=balance;mod.HunterBalance170=balance
    local function hunter(p)return playerType~=-1 and p:GetPlayerType()==playerType end
    local function evaluate(_,p,flag)
        if not hunter(p)then return end
        if flag==CacheFlag.CACHE_SPEED then p.MoveSpeed=p.MoveSpeed+(stats.speed-1)
        elseif flag==CacheFlag.CACHE_FIREDELAY then
            local native=30/math.max(.001,p.MaxFireDelay+1)
            p.MaxFireDelay=30/(native*stats.tearsMultiplier)-1
            if balance.active(p,flag)then
                local d=p:GetData();d.hunterTears161=d.hunterTears161 or{}
                d.hunterTears161.capRate=balance.cap(p,native)
            end
        elseif flag==CacheFlag.CACHE_DAMAGE then
            local flat=mod.HunterCompat163 and mod.HunterCompat163.flatDamage(p)or 0
            p.Damage=(p.Damage+flat)*stats.damageMultiplier*balance.damageMultiplier(p)
        elseif flag==CacheFlag.CACHE_SHOTSPEED then
            p.ShotSpeed=p.ShotSpeed+(stats.shotSpeed-1)
            if balance.has(p,310)then p.ShotSpeed=math.min(2,p.ShotSpeed)end
        elseif flag==CacheFlag.CACHE_RANGE then p.TearRange=p.TearRange+(stats.range-6.5)*40 end
        balance.mark(p,flag)
    end
    mod:AddCallback(ModCallbacks.MC_EVALUATE_CACHE,evaluate)
    local flags=CacheFlag.CACHE_SPEED|CacheFlag.CACHE_FIREDELAY|CacheFlag.CACHE_DAMAGE|CacheFlag.CACHE_SHOTSPEED|CacheFlag.CACHE_RANGE
    local function refresh(p)
        if hunter(p)then p:AddCacheFlags(flags);p:EvaluateItems();balance.refresh(p)end
    end
    mod:AddCallback(ModCallbacks.MC_POST_PLAYER_INIT,function(_,p)refresh(p)end)
    mod:AddCallback(ModCallbacks.MC_POST_GAME_STARTED,function()
        local game=Game();for i=0,game:GetNumPlayers()-1 do refresh(Isaac.GetPlayer(i))end
    end)
    return stats
end
