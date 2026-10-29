-- v1.53: layered pickup and bounded graphics recovery after costume/type exits.
-- The ANM2 is cloned from Isaac: timing, events, pivots and trajectories are retained.
-- No screen-space render callback, input interception, collision or stat modification.
return function(mod, playerType, normalType)
    local DEFAULT = "gfx/001.000_player.anm2"
    local LEGACY = "gfx/001.000_player_hunter_b.anm2"
    local PREVIOUS = "gfx/001.000_player_hunter_b_v135.anm2"
    local PREVIOUS_FINAL = "gfx/001.000_player_hunter_b_v135_final.anm2"
    local PREVIOUS_136 = "gfx/001.000_player_hunter_b_v136.anm2"
    local PREVIOUS_137 = "gfx/001.000_player_hunter_b_v137.anm2"
    local PREVIOUS_138 = "gfx/001.000_player_hunter_b_v138.anm2"
    local PREVIOUS_139 = "gfx/001.000_player_hunter_b_v139.anm2"
    local PREVIOUS_140 = "gfx/001.000_player_hunter_b_v140.anm2"
    local PREVIOUS_141 = "gfx/001.000_player_hunter_b_v141.anm2"
    local PREVIOUS_142 = "gfx/001.000_player_hunter_b_v142.anm2"
    local PREVIOUS_143 = "gfx/001.000_player_hunter_b_v143.anm2"
    local PREVIOUS_144 = "gfx/001.000_player_hunter_b_v144.anm2"
    local PREVIOUS_145 = "gfx/001.000_player_hunter_b_v145.anm2"
    local PREVIOUS_146 = "gfx/001.000_player_hunter_b_v146.anm2"
    local PREVIOUS_147 = "gfx/001.000_player_hunter_b_v147.anm2"
    local PREVIOUS_148 = "gfx/001.000_player_hunter_b_v148.anm2"
    local PREVIOUS_149 = "gfx/001.000_player_hunter_b_v149.anm2"
    local PREVIOUS_150 = "gfx/001.000_player_hunter_b_v150.anm2"
    local PREVIOUS_151 = "gfx/001.000_player_hunter_b_v151.anm2"
    local PREVIOUS_152 = "gfx/001.000_player_hunter_b_v152.anm2"
    local NATIVE = "gfx/001.000_player_hunter_b_v153.anm2"
    local SKIN = "gfx/characters/costumes/hunter_b_engine_blank_v147.png"
    local NORMAL_SKIN = "gfx/characters/costumes/character_revolver_silent_blank.png"
    -- ReplaceSpritesheet takes a LAYER id, not an ANM2 spritesheet id.
    -- Engine costume removal can overwrite these while GetFilename stays NATIVE.
    local LAYERS = {
        [0]=SKIN,
        [1]="gfx/characters/costumes/hunter_b_body_layers_v153.png",
        [2]="gfx/characters/costumes/hunter_b_front_reference_detail_v151.png",
        [3]="gfx/characters/costumes/hunter_b_cape_v148.png",
        [4]="gfx/characters/costumes/hunter_b_heads_v152.png",
        [5]=SKIN, [6]=SKIN, [7]=SKIN, [8]=SKIN, [9]=SKIN, [10]=SKIN, [11]=SKIN,
        [12]="gfx/characters/costumes/character_hunter_b_v136.png",
        [13]="gfx/Characters/costumes/ghost.png",
        [14]="gfx/characters/costumes/hunter_b_cape_v148.png",
        [15]="gfx/characters/costumes/hunter_b_body_layers_v153.png",
        [16]="gfx/characters/costumes/hunter_b_death_v141.png"
    }
    local function bindHunterLayers(sprite, player)
        for layer=0,16 do sprite:ReplaceSpritesheet(layer, LAYERS[layer]) end
        sprite:LoadGraphics()
        local data=player:GetData()
        data.hunterArtGraphicsRevision174=(data.hunterArtGraphicsRevision174 or 0)+1
    end
    local function appearanceState(player)
        local now={kind=player:GetPlayerType(),lost=false,forms=0,items=0,effects={}}
        if player.HasPlayerForm then
            local count=PlayerForm and PlayerForm.NUM_PLAYER_FORMS or 15
            for form=0,count-1 do
                if player:HasPlayerForm(form) then now.forms=now.forms | (1 << form) end
            end
        end
        if player.GetCollectibleCount then now.items=player:GetCollectibleCount() end
        if player.GetEffects then
            local effects=player:GetEffects()
            local lostId=NullItemID and NullItemID.ID_LOST_CURSE
            if effects and lostId then now.lost=effects:HasNullEffect(lostId) end
            if effects and effects.GetEffectsList then
                local list=effects:GetEffectsList()
                for i=0,list.Size-1 do
                    local effect=list:Get(i)
                    if effect and effect.Item and effect.Count>0 then
                        local key=tostring(effect.Item.Type)..":"..tostring(effect.Item.ID)
                        now.effects[key]=(now.effects[key] or 0)+effect.Count
                    end
                end
            end
        end
        return now
    end
    local function trackAppearance(player, data)
        local now=appearanceState(player)
        local state=data.hunterVisualState153 or {
            -- Also repair a continued/recreated player whose custom ANM2 name
            -- survived but whose previous per-entity observation did not.
            remaining=(now.kind==playerType and now.forms==0 and not now.lost) and 3 or 0
        }
        local old=state.observed
        local returned=old and old.kind~=playerType and now.kind==playerType
        local removed=old and ((old.lost and not now.lost)
            or (old.forms & (~now.forms))~=0 or now.items<old.items)
        local added=old and ((now.forms & (~old.forms))~=0 or now.items>old.items)
        if old then
            for key,count in pairs(old.effects) do
                if (now.effects[key] or 0)<count then removed=true;break end
            end
            if not added then
                for key,count in pairs(now.effects) do
                    if count>(old.effects[key] or 0) then added=true;break end
                end
            end
        end
        if now.kind==playerType and (returned or removed) then
            state.remaining=3 -- one full restore, followed by two graphics-only passes
            state.reason=returned and "player-type-return" or "costume/effect-exit"
        elseif added then
            -- Do not let a pending late-clear pass overwrite a newly applied
            -- transformation/costume. Its eventual removal will queue recovery.
            state.remaining=0
        end
        if now.kind~=playerType or now.lost then state.remaining=0 end
        state.observed=now
        data.hunterVisualState153=state
        return state,now.lost
    end
    local function filename(sprite)
        return (sprite:GetFilename() or ""):lower():gsub("\\", "/"):gsub("001%.000_player_hunter_b_v175%.anm2", "001.000_player_hunter_b_v153.anm2")
    end
    local function changeAnimationFile(player)
        if not player or playerType == -1 then return end
        local sprite = player:GetSprite()
        local source = filename(sprite)
        local hunter = player:GetPlayerType() == playerType
        local data = player:GetData()
        local target
        local own = source == NATIVE or source == LEGACY or source == PREVIOUS or source == PREVIOUS_FINAL or source == PREVIOUS_136 or source == PREVIOUS_137 or source == PREVIOUS_138 or source == PREVIOUS_139 or source == PREVIOUS_140 or source == PREVIOUS_141 or source == PREVIOUS_142 or source == PREVIOUS_143 or source == PREVIOUS_144 or source == PREVIOUS_145 or source == PREVIOUS_146 or source == PREVIOUS_147 or source == PREVIOUS_148 or source == PREVIOUS_149 or source == PREVIOUS_150 or source == PREVIOUS_151 or source == PREVIOUS_152
        -- Keep state on this player entity across white-fire type changes. Do not
        -- inspect or modify unrelated players or replace an active Lost costume.
        if not hunter and not own and not data.hunterVisualState153 and not data.hunterWasB136 then return end
        local state,lost=trackAppearance(player,data)
        if (hunter and lost) or (player.IsCoopGhost and player:IsCoopGhost()) then return end
        local recover=state.remaining>0 and not player:IsDead()
        if hunter and own then data.hunterWasB136 = true end
        if hunter and (source == DEFAULT or (own and source ~= NATIVE)
            or (source==NATIVE and recover and state.remaining==3)) then
            target = NATIVE
        elseif not hunter and (own or (data.hunterWasB136 and player:GetPlayerType() == normalType and source == DEFAULT)) then
            target = DEFAULT
        elseif hunter and source==NATIVE and recover then
            -- A delayed engine skin rebuild can arrive after the exit update.
            -- Rebind without Load/Play/SetFrame, so animation events never replay.
            bindHunterLayers(sprite, player)
            state.remaining=state.remaining-1
            return
        else
            -- Keep engine/other-mod special animation files intact.
            return
        end
        local animation, frame = sprite:GetAnimation(), sprite:GetFrame()
        local overlay, overlayFrame = sprite:GetOverlayAnimation(), sprite:GetOverlayFrame()
        local scale, color, rotation = sprite.Scale, sprite.Color, sprite.Rotation
        local flipX, flipY, speed = sprite.FlipX, sprite.FlipY, sprite.PlaybackSpeed
        sprite:Load(target, true)
        if hunter then
            data.hunterWasB136 = true
            bindHunterLayers(sprite, player)
            state.remaining=2
            if state.reason then
                Isaac.DebugString("[Revolver Samson] v1.53 restored Hunter layers after "..state.reason.."; source="..source)
                state.reason=nil
            end
        elseif normalType and player:GetPlayerType() == normalType then
            -- Returning to the regular Hunter must restore its transparent base,
            -- otherwise an Isaac body would appear under the separate renderer.
            sprite:ReplaceSpritesheet(0, NORMAL_SKIN)
            sprite:LoadGraphics()
            data.silentMotion124, data.hunterFacing136, data.hunterWasB136 = nil, nil, nil
            rotation, flipX, flipY, speed = 0, false, false, 1
            if not player:IsDead() and (animation == "Death" or animation == "ForgottenDeath" or overlay == "Death" or overlay == "ForgottenDeath") then
                animation, frame, overlay = "WalkDown", 0, ""
            end
        end
        if not hunter then data.hunterWasB136, data.hunterFacing136 = nil, nil end
        -- SetFrame(int) preserves playback; SetFrame(animation,int) would stop it.
        if animation and animation ~= "" then
            sprite:Play(animation, true)
            sprite:SetFrame(frame)
        end
        if overlay and overlay ~= "" then
            sprite:PlayOverlay(overlay, true)
            sprite:SetOverlayFrame(overlay, overlayFrame)
        end
        sprite.Scale, sprite.Color, sprite.Rotation = scale, color, rotation
        sprite.FlipX, sprite.FlipY, sprite.PlaybackSpeed = flipX, flipY, speed
    end
    -- Only ordinary locomotion is affected. Pickup, damage, death, special
    -- engine animations and the head overlay remain owned by the engine.
    local ordinary = {WalkDown=true, WalkUp=true, WalkLeft=true, WalkRight=true}
    local function synchronizeBodyAim(player)
        if playerType == -1 or player:GetPlayerType() ~= playerType or player:IsDead() then return end
        local visual=player:GetData().hunterVisualState153
        if visual and visual.observed.lost then return end
        if player.IsCoopGhost and player:IsCoopGhost() then return end
        local sprite = player:GetSprite()
        if filename(sprite) ~= NATIVE or not ordinary[sprite:GetAnimation()] then return end
        local shoot = player:GetShootingInput()
        if shoot:Length() <= 0.1 then return end
        local direction
        if math.abs(shoot.X) > math.abs(shoot.Y) then
            direction = shoot.X < 0 and "Left" or "Right"
        else
            direction = shoot.Y < 0 and "Up" or "Down"
        end
        local target = "Walk" .. direction
        local frame = sprite:GetFrame()
        -- Preserve playback with Play + single-index SetFrame. The two-argument
        -- SetFrame overload would stop walking, so never use it here.
        if player.Velocity:Length() < 0.1 then frame = 0 end
        local overlay, overlayFrame = sprite:GetOverlayAnimation(), sprite:GetOverlayFrame()
        if sprite:GetAnimation() ~= target then
            sprite:Play(target, true)
            sprite:SetFrame(frame)
            if overlay and overlay ~= "" then sprite:SetOverlayFrame(overlay, overlayFrame) end
        elseif player.Velocity:Length() < 0.1 then
            sprite:SetFrame(0)
        end
    end
    mod:AddCallback(ModCallbacks.MC_POST_PLAYER_INIT, function(_, player)
        changeAnimationFile(player)
    end)
    -- Handles continue, character changes and engine costume rebuilds without
    -- replacing the Sprite during rendering or restarting an animation each frame.
    mod:AddCallback(ModCallbacks.MC_POST_PLAYER_UPDATE, function(_, player)
        changeAnimationFile(player)
        synchronizeBodyAim(player)
        if mod.HunterDynamicArt174 then
            mod.HunterDynamicArt174.sync(player, player:GetData().hunterArtGraphicsRevision174)
        end
    end)
    Isaac.DebugString("[Revolver Samson] v1.53 Tainted Hunter: connected pickup and costume-exit recovery loaded")
end
