-- Vanilla Repentance exposes native charge wheels only through this option.
-- The reload sprite is rendered independently and never consults ChargeBars.
-- Preserve the user's option and restore it on mode exit, death, run end,
-- game exit, or mod unload. No changes to input or active-item charge.
return function(mod,playerType,R)
    local previous;local owning=false
    local function restore()
        if owning and Options then Options.ChargeBars=previous end
        owning=false;previous=nil
    end
    local function update()
        if not Options then return end
        local hide=false
        local game=Game()
        for i=0,game:GetNumPlayers()-1 do
            local p=Isaac.GetPlayer(i)
            if p:GetPlayerType()==playerType and not p:IsDead()and R.scripted(p)then
                for _,id in ipairs({69,114,118,229,316,395,440,556,579,678})do
                    -- The Chocolate replacement has no native charge wheel.
                    local native=id~=69 or p:GetCollectibleNum(69,true)+p:GetEffects():GetCollectibleEffectNum(69)>0
                    if native and R.has(p,id)then hide=true;break end
                end
                if hide then break end
            end
        end
        if hide then
            if not owning then previous=Options.ChargeBars;owning=true end
            Options.ChargeBars=false
        else restore()end
    end
    mod:AddCallback(ModCallbacks.MC_POST_UPDATE,update)
    for _,name in ipairs({'MC_PRE_GAME_EXIT','MC_POST_GAME_END','MC_PRE_MOD_UNLOAD'})do
        if ModCallbacks[name]then mod:AddCallback(ModCallbacks[name],restore)end
    end
    if ModCallbacks.MC_POST_GAME_STARTED then
        mod:AddCallback(ModCallbacks.MC_POST_GAME_STARTED,function()restore();update()end)
    end
    return {update=update,restore=restore}
end
