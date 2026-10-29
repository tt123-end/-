-- v1.33: Specialist dance; fitted emerald outline and camera/transition rules retained.
-- Screen-space rendering stays unchanged. Gameplay and held items
-- remain controlled by the engine; only this character's skin is drawn here.
return function(mod, playerType)
    local game = Game()
    local zero = Vector(0, 0)
    local VISUAL_SCALE = 1.15 -- Sprite instances only; never modify player collision/Size.
    local outlineDirections = {Vector(-1,0), Vector(1,0), Vector(0,-1), Vector(0,1)}
    local danceSequence = {0,1,0,1,2,3,4,2,5,6,5,6,7,2,7,2}

    local function renderReadyOutline(sprite, position, color, frame, scale)
        local breath = 0.5 + 0.5 * math.sin(frame * 0.055)
        local opacity = color.A or 1
        local radiusScale = math.max(math.abs(scale.X), math.abs(scale.Y))
        -- Zero multiplicative RGB plus emerald offsets makes a silhouette from the
        -- SAME alpha mask/frame/flip/rotation as the character, without tinting skin.
        local outer = Color(0,0,0,(0.035 + 0.015 * breath) * opacity,0.12,0.54,0.30)
        local inner = Color(0,0,0,(0.13 + 0.04 * breath) * opacity,0.20,0.76,0.44)
        sprite.Color = outer
        for _,direction in ipairs(outlineDirections) do
            sprite:Render(position + direction * (1.35 * radiusScale), zero, zero)
        end
        sprite.Color = inner
        for _,direction in ipairs(outlineDirections) do
            sprite:Render(position + direction * (0.55 * radiusScale), zero, zero)
        end
        sprite.Color = color
    end
    local function isCharacter(player)
        return player and player:GetPlayerType() == playerType
    end
    local function getState(player)
        local data = player:GetData()
        if not data.silentMotion124 then
            local state = {distance = 0, lastPosition = Vector(player.Position.X, player.Position.Y)}
            state.body = Sprite()
            state.body:Load("gfx/silent_body_v124.anm2", true)
            state.idle = Sprite()
            state.idle:Load("gfx/silent_idle_v125.anm2", true)
            state.head = Sprite()
            state.head:Load("gfx/silent_head_v124.anm2", true)
            state.action = Sprite()
            state.action:Load("gfx/silent_action_v124.anm2", true)
            state.hurt = Sprite()
            state.hurt:Load("gfx/silent_hurt_v127.anm2", true)
            state.death = Sprite()
            state.death:Load("gfx/silent_death_v127.anm2", true)
            state.dance = Sprite()
            state.dance:Load("gfx/silent_dance_v133.anm2", true)
            state.ready = state.body:IsLoaded() and state.idle:IsLoaded()
                and state.head:IsLoaded() and state.action:IsLoaded()
                and state.hurt:IsLoaded() and state.death:IsLoaded()
            data.silentMotion124 = state
        end
        return data.silentMotion124
    end
    local ordinary = {WalkDown=true, WalkUp=true, WalkLeft=true, WalkRight=true,
        FlyDown=true, FlyUp=true, FlyLeft=true, FlyRight=true}

    -- Record visibility from the engine's world pass, but draw later in screen space
    -- to retain the large-room camera fix. A paused/cutscene frame is not a world pass.
    mod:AddCallback(ModCallbacks.MC_POST_PLAYER_RENDER, function(_, player)
        if isCharacter(player) and not game:IsPaused() then
            getState(player).worldRenderFrame = Isaac.GetFrameCount()
        end
    end)

    local function resetRoomMotion()
        for index = 0, game:GetNumPlayers() - 1 do
            local player = Isaac.GetPlayer(index)
            if isCharacter(player) then
                local state = getState(player)
                state.worldRenderFrame = nil
                state.distance, state.moving = 0, false
                state.lastPosition = Vector(player.Position.X, player.Position.Y)
                state.shotFrame, state.hurtStart, state.pendingHitFrame = nil, nil, nil
                state.holding, state.pickupStart, state.queueKey = false, nil, nil
            end
        end
    end
    mod:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, resetRoomMotion)
    mod:AddCallback(ModCallbacks.MC_POST_NEW_LEVEL, resetRoomMotion)

    local function updateActions(player, state, now)
        local sprite = player:GetSprite()
        local animation = sprite:GetAnimation()
        local overlay = sprite:GetOverlayAnimation()
        local deathAnimation = animation == "Death" or overlay == "Death"
            or animation == "ForgottenDeath" or overlay == "ForgottenDeath"
        state.dead = player:IsDead() or deathAnimation
        if state.dead then
            if not state.deathStart then state.deathStart = now end
            return
        elseif state.deathStart then
            -- Resurrection must leave the corpse state rather than freezing the revived player.
            state.deathStart = nil
            state.hurtStart = nil
        end

        local queued = player.QueuedItem and player.QueuedItem.Item
        local holding = queued ~= nil or (player.IsHoldingItem and player:IsHoldingItem())
            or animation == "Pickup" or animation == "Happy"
            or overlay == "Pickup" or overlay == "Happy"
        local queueKey = queued and tostring(queued.Type) .. ":" .. tostring(queued.ID) or "held"
        if holding then
            if not state.holding or state.queueKey ~= queueKey then state.pickupStart = now end
            state.queueKey = queueKey
        else
            state.pickupStart = nil
            state.queueKey = nil
        end
        state.holding = holding

        local cooldown = player:GetDamageCooldown()
        local hitAnimation = animation == "Hit" or overlay == "Hit"
        local pendingHit = state.pendingHitFrame and now - state.pendingHitFrame <= 2
        -- TAKE_DMG runs before damage resolution and can be cancelled by other mods.
        -- Confirm a new reaction using a newly raised damage cooldown or native Hit state.
        if (hitAnimation and not state.nativeHit)
            or (pendingHit and cooldown > (state.lastDamageCooldown or 0)) then
            state.hurtStart = now
            state.pendingHitFrame = nil
        end
        if state.pendingHitFrame and now - state.pendingHitFrame > 2 then state.pendingHitFrame = nil end
        state.nativeHit = hitAnimation
        state.lastDamageCooldown = cooldown
    end

    mod:AddCallback(ModCallbacks.MC_ENTITY_TAKE_DMG, function(_, entity)
        local player = entity and entity:ToPlayer()
        if isCharacter(player) then getState(player).pendingHitFrame = game:GetFrameCount() end
        -- Cosmetic observer only: never return a value that changes damage resolution.
    end)

    mod:AddCallback(ModCallbacks.MC_POST_PEFFECT_UPDATE, function(_, player)
        if not isCharacter(player) then return end
        local state = getState(player)
        local displacement = (player.Position - state.lastPosition):Length()
        state.moving = displacement > 0.15 and displacement < 25
        if state.moving then state.distance = state.distance + displacement end
        state.lastPosition = Vector(player.Position.X, player.Position.Y)
        local animation = player:GetSprite():GetAnimation()
        if state.animation ~= animation then
            state.animation = animation
            state.animationStart = game:GetFrameCount()
        end
        updateActions(player, state, game:GetFrameCount())
    end)

    mod:AddCallback(ModCallbacks.MC_POST_FIRE_TEAR, function(_, tear)
        local player = tear.SpawnerEntity and tear.SpawnerEntity:ToPlayer()
        if isCharacter(player) then
            -- All projectiles in one volley share this cosmetic pulse, never consume ammo.
            getState(player).shotFrame = game:GetFrameCount()
        end
    end)

    local function renderPlayer(player)
        if not isCharacter(player) then return end
        local state = getState(player)
        if not state.ready then return end
        if state.worldRenderFrame ~= Isaac.GetFrameCount() and not player:IsDead() then return end
        local native = player:GetSprite()
        local animation = native:GetAnimation()
        -- This function runs ONLY in MC_POST_RENDER, where Sprite:Render uses screen
        -- coordinates. WorldToScreen already handles the current scrolling camera.
        -- Mixing this with MC_POST_PLAYER_RENDER's offset displaced the skin toward
        -- the top/left when the camera entered the lower/right half of a large room.
        local anchor = Isaac.WorldToScreen(player.Position) + player.SpriteOffset
        local scale = Vector(native.Scale.X * VISUAL_SCALE, native.Scale.Y * VISUAL_SCALE)
        local color = native.Color
        local now = game:GetFrameCount()
        -- Death may stop PEFFECT_UPDATE or hide the native skin. Continue advancing
        -- the corpse from render frames while keeping normal invisibility behavior.
        updateActions(player, state, now)
        if not player.Visible and not state.dead then return end

        local action, actionName, pose
        if state.dead then
            local age = now - state.deathStart
            pose = age < 6 and 0 or age < 12 and 1 or age < 20 and 2
                or age < 28 and 3 or age < 36 and 4 or 5
            action, actionName = state.death, "Death"
        elseif state.hurtStart and now - state.hurtStart < 16 then
            pose = math.min(3, math.floor((now - state.hurtStart) / 4))
            action, actionName = state.hurt, "Hurt"
        elseif state.holding then
            -- Raise, then HOLD for the entire real queued/held-item interval. The
            -- engine continues to draw the actual item and grants it normally.
            pose = math.min(3, math.floor((now - state.pickupStart) / 4))
            action, actionName = state.action, "Pickup"
        elseif player:GetData().silentSpecialist133 and state.dance:IsLoaded()
            and ordinary[animation] and player.Velocity:Length() < 0.1
            and player:GetShootingInput():Length() < 0.1 then
            -- Specialist owns activation; the skin renderer owns the matching poses.
            -- Pause dance for movement/fire and all higher-priority native reactions.
            local elapsed = now - player:GetData().silentSpecialist133
            pose = danceSequence[math.floor(elapsed / 6) % #danceSequence + 1]
            action, actionName = state.dance, "Dance"
        elseif not ordinary[animation] and animation ~= "" then
            action, actionName, pose = state.action, "Pickup", 0
        end

        if action then
            action:SetFrame(actionName, pose)
            action.Scale = scale
            action.Color = color
            action.Rotation = 0
            action.FlipX = false
            action:Render(anchor, zero, zero)
            return
        end

        local velocity = player.Velocity
        local moving = state.moving and velocity:Length() > 0.1
        local phase = moving and (math.floor(state.distance / 5) % 4) or 0
        -- One direction for both parts: shooting input > actual movement > front.
        -- Never let tiny residual velocity or a remembered engine head direction
        -- keep one half facing sideways after the player has stopped.
        local shootingInput = player:GetShootingInput()
        local facingInput = shootingInput:Length() > 0.1 and shootingInput
            or (moving and velocity) or nil
        local facingAnimation, facingFlip = "Front", false
        if facingInput then
            if math.abs(facingInput.X) > math.abs(facingInput.Y) then
                facingAnimation, facingFlip = "Side", facingInput.X < 0
            elseif facingInput.Y < 0 then
                facingAnimation = "Back"
            end
        end
        local firing = state.shotFrame and now - state.shotFrame < 6
        local body = moving and state.body or state.idle
        body:SetFrame(facingAnimation, phase)
        body.FlipX = facingFlip
        body.Scale = scale
        body.Color = color
        body.Rotation = 0
        state.head:SetFrame(facingAnimation, firing and 1 or 0)
        state.head.FlipX = facingFlip
        state.head.Scale = scale
        state.head.Color = color
        -- Small launch recoil is visible from side/back too; front additionally opens mouth.
        state.head.Rotation = firing and (facingFlip and -2 or 2) or 0
        local bob = moving and ((phase % 2 == 0) and -0.5 or 0) or 0
        local headPosition = anchor + Vector(0, (bob + (firing and -0.5 or 0)) * VISUAL_SCALE)
        local playerData = player:GetData()
        local reloading = playerData.revolverReloadTimer and playerData.revolverReloadTimer > 0
        if playerData.revolverShots == 3 and not reloading then
            -- Draw BOTH masks behind BOTH normal parts, so no green seam appears
            -- between the head and collar. Extra-action poses returned above.
            renderReadyOutline(body, anchor, color, now, scale)
            renderReadyOutline(state.head, headPosition, color, now, scale)
        end
        body:Render(anchor, zero, zero)
        state.head:Render(headPosition, zero, zero)
    end

    mod:AddCallback(ModCallbacks.MC_POST_RENDER, function()
        -- Room slides, boss VS screens and floor transitions all pause world logic.
        -- Do not paint a live-room skin over those screens or reuse an outgoing frame.
        if game:IsPaused() then return end
        for index = 0, game:GetNumPlayers() - 1 do
            renderPlayer(Isaac.GetPlayer(index))
        end
    end)
    Isaac.DebugString("[Revolver Samson] v1.33 motion loaded: Specialist dance and fitted emerald outline")
end
