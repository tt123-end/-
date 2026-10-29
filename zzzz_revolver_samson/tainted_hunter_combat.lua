-- v1.57: Tainted Hunter, one volley then one attack interval of reload.
-- Character stats/appearance and the regular Hunter module are independent.
return function(mod, playerType)
    local game = Game()
    local compat = assert(mod.HunterCompat163,"Hunter compatibility module must load first")
    local rules = compat.rules
    local KNIFE = "gfx/tainted_hunter_knife_v155.anm2"
    local CHARGE = "gfx/chargebar.anm2" -- same circle/charge animation as regular Hunter
    local DAMAGE_MULTIPLIER = 4
    local SIZE_MULTIPLIER = 1.5
    local KNIFE_BASE_SCALE = 0.80 -- regular Hunter's baseline projectile size
    local COMPLETE_FLASH_FRAMES = 6
    local SHOOT = {
        [ButtonAction.ACTION_SHOOTLEFT]=true, [ButtonAction.ACTION_SHOOTRIGHT]=true,
        [ButtonAction.ACTION_SHOOTUP]=true, [ButtonAction.ACTION_SHOOTDOWN]=true
    }
    local function isHunter(player)
        return player and playerType ~= -1 and player:GetPlayerType() == playerType
    end
    local function state(player)
        local data = player:GetData()
        if not data.hunterCombat155 then data.hunterCombat155 = {} end
        return data.hunterCombat155
    end
    local function reloading(player)
        local data = player:GetData().hunterCombat155
        return data and data.untilFrame and game:GetFrameCount() < data.untilFrame
    end
    local function chargeSprite(data)
        if not data.charge then
            local sprite=Sprite();sprite:Load(CHARGE,true)
            if not sprite:IsLoaded() then return nil end
            sprite:Play("Charging",true);data.charge=sprite
        end
        return data.charge
    end
    local function startReload(player,data,frame)
        -- Run in parallel with native FireDelay. Never add another interval or
        -- reset player.FireDelay every update; that would halve effective rate.
        data.duration=math.max(1,math.ceil((player.MaxFireDelay or 10)+1-0.000001))
        data.startedFrame=frame;data.untilFrame=frame+data.duration
        data.flashUntil=nil
        local sprite=chargeSprite(data)
        if sprite then sprite:Play("Charging",true);sprite:SetFrame("Charging",0)end
        -- Spirit Sword now triggers on an actual attack, not on reload start.
    end
    local function directOwner(tear)
        local owner=tear.SpawnerEntity
        local player=owner and owner:ToPlayer()
        if not player and tear.Parent then player=tear.Parent:ToPlayer()end
        return player
    end
    local function hasKnife(sprite)
        return (sprite:GetFilename()or ""):lower():find("tainted_hunter_knife_v155.anm2",1,true)~=nil
    end
    local probe=Sprite();probe:Load(KNIFE,true)
    local knifeReady=probe:IsLoaded() and hasKnife(probe)
    if knifeReady then probe:Play("Idle",true);knifeReady=probe:IsPlaying("Idle")end
    local function updateKnife(tear)
        local data=tear:GetData()
        if not data.hunterKnifeApplied155 or tear:IsDead()then return end
        local sprite=tear:GetSprite()
        if not hasKnife(sprite) then return end -- retain external/special sprite overrides
        if not sprite:IsPlaying("Idle") then sprite:Play("Idle",true)end
        local scale=KNIFE_BASE_SCALE*math.max(0,tonumber(tear.Scale)or 1)*SIZE_MULTIPLIER
        sprite.Scale=Vector(scale,scale)
        if tear.Velocity and tear.Velocity:Length()>0.01 then
            sprite.Rotation=tear.Velocity:GetAngleDegrees()
        end
        -- In particular, NEVER reset CollisionDamage here. TEAR_PERSISTENT's
        -- remaining damage after a kill must survive every subsequent update.
    end
    local function applyKnife(tear)
        if not knifeReady then return end
        local sprite=tear:GetSprite()
        local oldFile,oldAnim,oldFrame=sprite:GetFilename(),sprite:GetAnimation(),sprite:GetFrame()
        local color=sprite.Color
        sprite:Load(KNIFE,true);sprite:Play("Idle",true)
        if not sprite:IsLoaded() or not hasKnife(sprite) or not sprite:IsPlaying("Idle")then
            if oldFile and oldFile~="" then
                sprite:Load(oldFile,true)
                if oldAnim and oldAnim~="" then sprite:Play(oldAnim,true);sprite:SetFrame(oldFrame)end
            end
            sprite.Color=color
            return
        end
        sprite.Color=color
        tear:GetData().hunterKnifeApplied155=true
        updateKnife(tear)
    end
    local serial=0
    local function beginAttack(player)
        local data=state(player);local frame=game:GetFrameCount()
        if data.lastVolleyFrame==frame then return data.group end
        if reloading(player) or frame<(data.nextShotFrame or 0)then return nil end
        local cap=rules.capacity(player)
        data.ammo=math.min(cap,data.ammo or cap)
        if data.ammo<=0 then return nil end
        serial=serial+1
        data.group={id=serial,owner=player,frame=frame,live=0,hit=false,room=compat.roomKey()}
        data.lastVolleyFrame=frame;data.ammo=data.ammo-1
        data.nextShotFrame=frame+math.max(1,math.ceil(rules.roundInterval(player)-0.000001))
        compat.registerGroup(data.group)
        if data.ammo<=0 then startReload(player,data,frame)end
        return data.group
    end
    compat.bind({state=state,reloading=reloading,beginAttack=beginAttack,applyKnife=applyKnife,
        updateKnife=updateKnife,startReload=startReload})
    mod:AddCallback(ModCallbacks.MC_POST_FIRE_TEAR,function(_,tear)
        compat.onFireTear(tear)
    end)
    mod:AddCallback(ModCallbacks.MC_POST_TEAR_UPDATE,function(_,tear)
        updateKnife(tear)
    end)
    -- Keep raw aim/held-input visible to native familiars, Epiphora,
    -- Neptunus, IBS and secondary charge effects. Reload is a firing cooldown,
    -- never a fake key release. Scripted weapons use an independent fire gate.
    mod:AddCallback(ModCallbacks.MC_POST_PEFFECT_UPDATE,function(_,player)
        if not isHunter(player)then return end
        local data=player:GetData().hunterCombat155
        if not data then data=state(player)end
        local frame=game:GetFrameCount()
        if data.untilFrame and frame>=data.untilFrame then
            data.flashUntil=data.untilFrame+COMPLETE_FLASH_FRAMES
            data.untilFrame=nil
            data.ammo=rules.capacity(player)
            local sprite=chargeSprite(data)
            if sprite then sprite:Play("Charged",true)end
        elseif data.flashUntil and frame<data.flashUntil then
            local sprite=chargeSprite(data)
            if sprite then sprite:Update()end
        end
        local cap=rules.capacity(player)
        if data.capacity and data.capacity~=cap and not reloading(player)then
            data.ammo=math.max(0,math.min(cap,(data.ammo or cap)+cap-data.capacity))
        end
        data.capacity=cap
        if reloading(player)then player.FireDelay=math.max(player.FireDelay or 0,data.untilFrame-frame)end
        if cap==2 and (data.ammo or 0)>0 and not reloading(player)then
            player.FireDelay=math.min(player.FireDelay or 0,math.max(0,(data.nextShotFrame or frame)-frame))
        end
        compat.updatePlayer(player)
    end)
    -- A single damage handler owns reload doubling and red-heart penalties.
    include("tainted_hunter_damage")(mod,playerType,reloading)
    local ammo
    mod:AddCallback(ModCallbacks.MC_POST_RENDER,function()
        if game:IsPaused()then return end
        for i=0,game:GetNumPlayers()-1 do
            local player=Isaac.GetPlayer(i)
            if isHunter(player)and not player:IsDead()then
                local data=state(player);local frame=game:GetFrameCount();local busy=reloading(player)
                -- One chamber: same lower-left ammo location, one readable knife.
                if knifeReady then
                    if not ammo then
                        ammo=Sprite();ammo:Load(KNIFE,true);ammo:Play("Idle",true)
                        ammo.Scale=Vector(0.65,0.65);ammo.Rotation=-90
                    end
                    for slot=1,rules.capacity(player)do
                        local loaded=not busy and slot<=(data.ammo or rules.capacity(player))
                        ammo.Color=loaded and Color(0.6,1,0.9,1)or Color(0.3,0.3,0.3,0.5)
                        ammo:Render(Vector(25+(slot-1)*14,Isaac.GetScreenHeight()-61),Vector(0,0),Vector(0,0))
                    end
                end
                if player.Visible and (busy or(data.flashUntil and frame<data.flashUntil))then
                    local sprite=chargeSprite(data)
                    if sprite then
                        if busy then
                            local progress=math.max(0,math.min(1,(frame-data.startedFrame)/data.duration))
                            sprite:SetFrame("Charging",math.floor(progress*100+0.5))
                        end
                        sprite:Render(Isaac.WorldToScreen(player.Position)+Vector(0,-34),Vector(0,0),Vector(0,0))
                    end
                end
            end
        end
    end)
    mod:AddCallback(ModCallbacks.MC_POST_PLAYER_INIT,function(_,player)
        if isHunter(player)then player:GetData().hunterCombat155=nil end
    end)
end
