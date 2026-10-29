-- v1.62: broken hearts only for red HP lost from ordinary Heart Containers.
-- Vanilla Repentance APIs only. Native broken hearts persist in engine saves.
return function(mod, playerType, reloading)
    local game=Game()
    local function isHunter(player)
        return player and playerType~=-1 and player:GetPlayerType()==playerType
    end
    local function hasFlag(flags,name)
        local flag=DamageFlag[name]
        return flag and (flags & flag)~=0
    end
    local exemptMask=0
    for _,name in ipairs({
        "DAMAGE_FAKE", "DAMAGE_DEVIL", "DAMAGE_IV_BAG", "DAMAGE_CURSED_DOOR",
        "DAMAGE_CHEST", "DAMAGE_NO_PENALTIES"
    })do exemptMask=exemptMask | (DamageFlag[name]or 0)end
    local paidSlots={
        [2]=true, -- blood donation machine
        [5]=true, -- devil beggar (6 is the shell game)
        [15]=true, -- hell game
        [17]=true -- confessional
    }
    local function sourceKind(source)
        local entity=source and source.Entity
        return (entity and entity.Type)or(source and source.Type)or 0,
            (entity and entity.Variant)or(source and source.Variant)or 0
    end
    local function exempt(flags,source)
        if (flags & exemptMask)~=0 then return true end
        local kind,variant=sourceKind(source)
        local hostile=kind==(EntityType.ENTITY_PROJECTILE or 9)or(kind>=10 and kind<1000)
        -- Razor/Blood Rights/Sharp Plug and similar self-costs use RED_HEARTS.
        -- A real enemy explicitly targeting red HP is still a qualifying hit.
        if hasFlag(flags,"DAMAGE_RED_HEARTS")and not hostile then return true end
        if kind==(EntityType.ENTITY_SLOT or 6)and paidSlots[variant]then return true end
        if hasFlag(flags,"DAMAGE_SPIKES")then
            -- Only sacrifice spikes, not enemy damage elsewhere in the room.
            -- Ordinary floor spikes outside sacrifice rooms remain mistakes.
            local room=game:GetRoom()
            if not hostile and room:GetType()==RoomType.ROOM_SACRIFICE then return true end
        end
        return false
    end
    local function tracker(player)
        local data=player:GetData()
        if not data.hunterRedDamage157 then data.hunterRedDamage157={}end
        return data.hunterRedDamage157
    end
    -- GetHearts includes red fill in Bone Hearts. Ordinary containers are
    -- filled first; their red HP is capped by GetMaxHearts (which excludes
    -- bones). Compare using the pre-hit container capacity throughout a hit.
    local function containerRed(player,maxHearts)
        return math.max(0,math.min(player:GetHearts(),maxHearts))
    end
    local function boneCount(player)
        return player.GetBoneHearts and player:GetBoneHearts()or 0
    end
    local function award(player,data)
        data.pending=nil -- capacity loss must never be mistaken for another hit
        if isHunter(player)then player:AddBrokenHearts(1)end
    end
    local function settle(player,data)
        local event=data.pending
        if not event then return end
        if event.containerRedHearts==nil then data.pending=nil;return end
        if not isHunter(player)then data.pending=nil;return end
        local frame=game:GetFrameCount()
        if frame>event.frame+2 then data.pending=nil;return end
        -- Some damage paths settle after TakeDamage returns. Only inspect a
        -- queued, accepted damage event, never general room-to-room HP changes.
        if player.GetMaxHearts and player:GetMaxHearts()<event.maxHearts then data.pending=nil;return end
        if containerRed(player,event.maxHearts)>=event.containerRedHearts then
            -- A bone-fill/shell hit has already settled. Discard it rather
            -- than keeping it armed for a later, unrelated red-health loss.
            if player:GetHearts()<event.redHearts or boneCount(player)<event.boneHearts then
                data.pending=nil
            end
            return
        end
        if player.GetLastDamageFlags and player:GetLastDamageFlags()~=event.flags then data.pending=nil;return end
        if player.GetLastDamageSource then
            local kind,variant=sourceKind(player:GetLastDamageSource())
            if kind~=event.sourceType or variant~=event.sourceVariant then data.pending=nil;return end
        end
        data.processing=true
        local ok,err=pcall(award,player,data)
        data.processing=nil
        if not ok then error(err)end
    end
    local function onDamage(_,entity,amount,flags,source,countdown)
        local player=entity and entity:ToPlayer()
        if not isHunter(player)or amount<=0 then return end
        local data=tracker(player)
        if data.processing then return end
        settle(player,data)
        -- A new hit/payment starts a new attribution boundary. Never charge a
        -- later donation, cancelled hit, health-cost item or door to an old hit.
        data.pending=nil
        if hasFlag(flags,"DAMAGE_FAKE")then return end
        local doubled=reloading(player)
        local redBefore=player:GetHearts()
        local maxBefore=player:GetMaxHearts()
        local containerBefore=containerRed(player,maxBefore)
        local bonesBefore=boneCount(player)
        local eligible=containerBefore>0 and not exempt(flags,source)
        if not doubled and not eligible then return end
        data.processing=true
        local ok,err=pcall(function()
            -- One shared reissue for both mechanics, so a reload hit does not
            -- double recursively or add two broken hearts. Preserve all flags.
            local accepted=player:TakeDamage(amount*(doubled and 2 or 1),flags,source,countdown)
            if not eligible or not isHunter(player)then return end
            if containerRed(player,maxBefore)<containerBefore then
                award(player,data)
            elseif accepted and player:GetHearts()>=redBefore and boneCount(player)>=bonesBefore then
                local kind,variant=sourceKind(source)
                data.pending={redHearts=redBefore,containerRedHearts=containerBefore,boneHearts=bonesBefore,
                    frame=game:GetFrameCount(),flags=flags,
                    sourceType=kind,sourceVariant=variant,
                    maxHearts=maxBefore}
            end
        end)
        data.processing=nil
        if not ok then error(err)end
        return false
    end
    mod:AddPriorityCallback(ModCallbacks.MC_ENTITY_TAKE_DMG,CallbackPriority.LATE,onDamage,EntityType.ENTITY_PLAYER)
    mod:AddCallback(ModCallbacks.MC_POST_PEFFECT_UPDATE,function(_,player)
        local data=player:GetData().hunterRedDamage157
        if data and not data.processing then settle(player,data)end
    end)
    mod:AddCallback(ModCallbacks.MC_POST_PLAYER_INIT,function(_,player)
        if isHunter(player)then player:GetData().hunterRedDamage157=nil end
    end)
end
