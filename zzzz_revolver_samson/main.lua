-- v1.72 - selected item stat replacements; no tears penalty compensation
-- Based on the user-tested v1.16 mechanics; preserves character stats, ammo HUD, bullet visuals/hitbox and reload.
-- Standalone character with a custom Silent-inspired skin. Vanilla Samson is untouched.
-- Four attack events per cylinder, then an attack-speed-scaled reload. Three normal
-- volleys deal 3x damage; the fourth deals 6x damage and pierces enemies. Lethal fourth-round
-- hits also damage freshly spawned split enemies; excess shot speed converts 1:3 to damage.
-- Ordinary tears keep native collision size; the special fourth volley gets a matching 1.5x collision-size multiplier and piercing.
-- The bullet sprite scales with EntityTear.Scale.

local mod = RegisterMod("Revolver Samson - Revolver Prototype", 1)
local game = Game()
local PLAYER_TYPE = Isaac.GetPlayerTypeByName("RevolverSamson")
include("mod_compat")(mod, PLAYER_TYPE)
include("silent_visuals")(mod, PLAYER_TYPE)
include("tainted_hunter_visuals")(mod, Isaac.GetPlayerTypeByName("RevolverSamson", true), PLAYER_TYPE)
local TAINTED_PLAYER_TYPE = Isaac.GetPlayerTypeByName("RevolverSamson", true)
mod.HunterCompat163 = include("tainted_hunter_compat")(mod, TAINTED_PLAYER_TYPE)
include("tainted_hunter_charge_ui")(mod, TAINTED_PLAYER_TYPE, mod.HunterCompat163.rules)
local taintedStats = include("tainted_hunter_stats")(mod, TAINTED_PLAYER_TYPE)
include("tainted_hunter_stats_plus")(mod, TAINTED_PLAYER_TYPE, taintedStats)
include("tainted_hunter_combat")(mod, TAINTED_PLAYER_TYPE)
include("tainted_hunter_eid")(mod, TAINTED_PLAYER_TYPE)
include("tainted_hunter_compat_eid")(mod, TAINTED_PLAYER_TYPE)

local SHOTS_PER_CYLINDER = 4
local COMPLETE_FLASH_FRAMES = 6

local AMMO_UI_ANM2 = "gfx/revolver_ammo.anm2"
local AMMO_UI_ANM2_BASENAME = "revolver_ammo.anm2"
local AMMO_ICON_COUNT = 4
local AMMO_ICON_SPACING = 15
local AMMO_UI_LEFT = 18
local AMMO_UI_BOTTOM_MARGIN = 61

-- Requested character baseline (regular Repentance API, without REPENTOGON XML stat modifiers).
-- Standard Isaac defaults: speed 1.0, tears 30/(10+1), damage 3.5, range 6.5 tiles, shot speed 1.0, luck 0.
local TARGET_SPEED = 1.0
local TARGET_BASE_TEAR_RATE = 2.1       -- target baseline Tears/sec before the flat delay penalty
local TARGET_BASE_DAMAGE = 3.5
local DAMAGE_MULTIPLIER = 1.20
local BASE_GAME_FIRE_DELAY = 10
local STANDARD_BASE_TEAR_RATE = 30 / (BASE_GAME_FIRE_DELAY + 1)
local FIRE_RATE_MULTIPLIER = 0.33       -- custom tear-rate modifier
local TARGET_RATE_AT_NATIVE_SOFT_CAP = 1.67 -- calibration reference at native rate 5.0; NOT a hard cap
local MINIMUM_NORMAL_TEAR_RATE_SOFT_CAP = 1.0 -- floor for the normal soft cap, NOT actual fire rate
local NATIVE_SOFT_CAP_TEAR_RATE = 5.0    -- reference point for the game's ordinary tear-rate soft cap
local INTRINSIC_TEAR_BONUS = 0.35       -- replaces Analog Stick's Tears stat, without its aiming effect
-- Vanilla Isaac with Analog Stick has an effective rate of ~3.073 before this character's
-- custom fire-rate penalty. Calibrate that starting point to 2.1/(30/11) of its native value,
-- giving ~0.78 after the 0.33 multiplier. The native 5.0 rate is only a calibration reference
-- that maps to ~1.67 final tears/sec. Crucially, rates above that reference are allowed to keep
-- increasing, so tear-up items are not blocked by an artificial 1.67 hard cap.
local ANALOG_STICK_NATIVE_DELAY = 16 - 6 * math.sqrt(1 + 1.3 * INTRINSIC_TEAR_BONUS)
local ANALOG_STICK_NATIVE_RATE = 30 / (ANALOG_STICK_NATIVE_DELAY + 1)
local TARGET_START_RATE_AFTER_CALIBRATION = ANALOG_STICK_NATIVE_RATE * (TARGET_BASE_TEAR_RATE / STANDARD_BASE_TEAR_RATE)
local CALIBRATED_RATE_AT_REFERENCE = TARGET_RATE_AT_NATIVE_SOFT_CAP / FIRE_RATE_MULTIPLIER
local TARGET_RANGE_TILES = 8.0
local DEFAULT_RANGE_TILES = 6.5
local RANGE_UNITS_PER_TILE = 40
local TARGET_SHOT_SPEED = 2.0
local DEFAULT_SHOT_SPEED = 1.0
local MAX_SHOT_SPEED = 3.0
local DAMAGE_PER_EXCESS_SHOT_SPEED = 3.0 -- +3 final damage for every 1.0 excess shot speed
local NORMAL_TEAR_DAMAGE_MULTIPLIER = 3.0 -- attacks 1-3
local LAST_TEAR_DAMAGE_MULTIPLIER = 6.0   -- attack 4 only; includes piercing
local RELOAD_INTERVAL_MULTIPLIER = 2.0

-- Assets are stored under resources/gfx/; the Lua API resource path is gfx/revolver_bullet.anm2.
local BULLET_ANM2 = "gfx/revolver_bullet.anm2"
local BULLET_ANM2_BASENAME = "revolver_bullet.anm2"
local BULLET_ANIMATION = "Idle"
local BULLET_SCALE = 0.80
local LAST_ROUND_BULLET_SCALE_MULTIPLIER = 1.50 -- visual size boost for the 4th volley
local LAST_ROUND_COLLISION_SIZE_MULTIPLIER = 1.50 -- matching hitbox radius boost for the 4th volley
local TEAR_GRID_COLLISION_POINTS = 8 -- standard tear grid-collision point count

local CHARGEBAR_ANM2 = "gfx/chargebar.anm2"
local CHARGEBAR_ANM2_NAME = "chargebar.anm2"

local ammoUISprites = nil
local ammoUIAssetReady = nil

-- Fourth-round split-child damage patch. A piercing tear cannot hit an enemy that is
-- created only after its parent dies, so we track lethal fourth-round hits and briefly
-- apply that same shot's damage to fresh NPCs spawning near the parent's death position.
local SPLIT_PATCH_RADIUS = 72
local SPLIT_PATCH_WINDOW_FRAMES = 20
local LETHAL_HIT_PENDING_GRACE_FRAMES = 2
local pendingFourthRoundSplitEvents = {}
local globalVolleySerial = 0

local SHOOT_ACTIONS = {
    [ButtonAction.ACTION_SHOOTLEFT] = true,
    [ButtonAction.ACTION_SHOOTRIGHT] = true,
    [ButtonAction.ACTION_SHOOTUP] = true,
    [ButtonAction.ACTION_SHOOTDOWN] = true,
}

local function isRevolverSamson(player)
    return player ~= nil and PLAYER_TYPE ~= -1 and player:GetPlayerType() == PLAYER_TYPE
end


local function getPlayerFromEntity(entity)
    if entity and entity:ToPlayer() then
        return entity:ToPlayer()
    end
    return nil
end

local function hasBasename(path, basename)
    return string.find(string.lower(tostring(path or "")), string.lower(basename), 1, true) ~= nil
end

-- Verify the custom animation asset before touching any real tear sprite.
-- This makes missing/corrupt files fail safe: the game's original tear remains visible.
local function validateBulletAsset()
    local probe = Sprite()
    probe:Load(BULLET_ANM2, true)
    local resolvedFile = probe:GetFilename()
    if not probe:IsLoaded() or not hasBasename(resolvedFile, BULLET_ANM2_BASENAME) then
        Isaac.DebugString("[Revolver Samson] Bullet ANM2 failed validation; leaving vanilla tears untouched. path=" .. BULLET_ANM2 .. "; resolved=" .. tostring(resolvedFile) .. "; IsLoaded=" .. tostring(probe:IsLoaded()))
        return false
    end

    probe:Play(BULLET_ANIMATION, true)
    if not probe:IsPlaying(BULLET_ANIMATION) then
        Isaac.DebugString("[Revolver Samson] Bullet animation '" .. BULLET_ANIMATION .. "' is missing; leaving vanilla tears untouched. file=" .. tostring(resolvedFile))
        return false
    end

    Isaac.DebugString("[Revolver Samson] Bullet ANM2 validated: " .. tostring(resolvedFile) .. "; animation=" .. BULLET_ANIMATION)
    return true
end

local BULLET_ASSET_READY = validateBulletAsset()

-- Preserve the v1.6 bullet's approved baseline size and the existing native
-- EntityTear.Scale relationship for ordinary shots. The 4th volley gets a separate
-- 1.5x visual boost and a matching 1.5x entity hitbox-size boost. Damage, tear.Scale,
-- and the normal first-three-shot collision sizes remain independent.
local function getBulletSpriteScale(tear)
    local nativeTearScale = tonumber(tear and tear.Scale) or 1.0
    nativeTearScale = math.max(0, nativeTearScale)
    local data = tear and tear:GetData() or nil
    local roundMultiplier = (data and data.revolverShotNumber == SHOTS_PER_CYLINDER)
        and LAST_ROUND_BULLET_SCALE_MULTIPLIER or 1.0
    local visualScale = BULLET_SCALE * nativeTearScale * roundMultiplier
    return Vector(visualScale, visualScale)
end

local function getData(player)
    local data = player:GetData()
    if data.revolverShots == nil then data.revolverShots = 0 end
    return data
end

local function getAmmoUISprites()
    if ammoUISprites ~= nil then
        return ammoUIAssetReady and ammoUISprites or nil
    end

    local sprites = {}
    for i = 1, AMMO_ICON_COUNT do
        local sprite = Sprite()
        sprite:Load(AMMO_UI_ANM2, true)
        local resolved = sprite:GetFilename()
        if not sprite:IsLoaded() or not hasBasename(resolved, AMMO_UI_ANM2_BASENAME) then
            Isaac.DebugString("[Revolver Samson] Ammo UI ANM2 failed validation. expected=" .. AMMO_UI_ANM2 .. "; resolved=" .. tostring(resolved))
            ammoUISprites = {}
            ammoUIAssetReady = false
            return nil
        end
        sprite:Play("Idle", true)
        sprite:SetFrame("Idle", 0)
        sprites[i] = sprite
    end

    ammoUISprites = sprites
    ammoUIAssetReady = true
    Isaac.DebugString("[Revolver Samson] Ammo UI sprites loaded: " .. AMMO_UI_ANM2)
    return ammoUISprites
end

local function computeReloadFrames(player)
    -- Repentance fire interval is MaxFireDelay + 1 frames.
    -- Reload for exactly 1.5 actual firing intervals, rounded up to whole frames.
    local delay = player.MaxFireDelay or BASE_GAME_FIRE_DELAY
    local intervalFrames = math.max(1, delay + 1)
    return math.max(1, math.ceil(intervalFrames * RELOAD_INTERVAL_MULTIPLIER))
end

local function getChargeSprite(player)
    local data = getData(player)
    if not data.revolverChargeSprite then
        local sprite = Sprite()
        sprite:Load(CHARGEBAR_ANM2, true)
        local loadedFile = sprite:GetFilename()
        if not hasBasename(loadedFile, CHARGEBAR_ANM2_NAME) then
            Isaac.DebugString("[Revolver Samson] Chargebar ANM2 did not resolve. Expected: " .. CHARGEBAR_ANM2 .. "; Sprite:GetFilename()=" .. tostring(loadedFile))
        else
            Isaac.DebugString("[Revolver Samson] Chargebar ANM2 loaded: " .. tostring(loadedFile))
        end
        sprite:Play("Charging", true)
        data.revolverChargeSprite = sprite
        data.revolverChargeMode = "Charging"
    end
    return data.revolverChargeSprite
end

local function startReload(player)
    local data = getData(player)
    if data.revolverReloadTimer and data.revolverReloadTimer > 0 then
        return
    end

    data.revolverReloadDuration = computeReloadFrames(player)
    data.revolverReloadTimer = data.revolverReloadDuration
    data.revolverReloadCompleteFrames = 0
    data.revolverShots = SHOTS_PER_CYLINDER
    data.revolverChargeMode = "Charging"

    local sprite = getChargeSprite(player)
    sprite:Play("Charging", true)
    sprite:SetFrame("Charging", 0)
    Isaac.DebugString("[Revolver Samson] Reload started; duration=" .. tostring(data.revolverReloadDuration) .. " frames")
end

local function restoreOriginalSprite(sprite, filename, animation, frame)
    if not filename or filename == "" then
        return
    end
    sprite:Load(filename, true)
    if animation and animation ~= "" then
        sprite:Play(animation, true)
        if frame and frame >= 0 then
            sprite:SetFrame(animation, frame)
        end
    end
end

-- The fourth volley must be physically larger as well as visibly larger.
-- Entity.Size is the actual hitbox radius in Repentance; SetSize updates the engine
-- collision size. Preserve SizeMulti so any native/modded elliptical hitbox shape
-- remains the same, and scale only the radius. This is applied once per tear.
local function applyBulletCollisionSize(tear, shotNumber)
    local data = tear:GetData()
    if data.revolverCollisionSizeHandled then
        return
    end
    data.revolverCollisionSizeHandled = true

    if shotNumber ~= SHOTS_PER_CYLINDER then
        return
    end

    local originalSize = tonumber(tear.Size) or 0
    if originalSize <= 0 then
        Isaac.DebugString("[Revolver Samson] Fourth-round collision size skipped: invalid original size=" .. tostring(tear.Size))
        return
    end

    local sizeMulti = tear.SizeMulti
    if not sizeMulti then
        sizeMulti = Vector(1, 1)
    end

    local enlargedSize = originalSize * LAST_ROUND_COLLISION_SIZE_MULTIPLIER
    tear:SetSize(enlargedSize, sizeMulti, TEAR_GRID_COLLISION_POINTS)
    data.revolverOriginalCollisionSize = originalSize
    data.revolverCollisionSizeApplied = true
    Isaac.DebugString("[Revolver Samson] Fourth-round hitbox enlarged: " .. tostring(originalSize) .. " -> " .. tostring(enlargedSize))
end

local function applyBulletSprite(tear)
    local data = tear:GetData()
    if data.revolverBulletLoadAttempted then
        return
    end
    data.revolverBulletLoadAttempted = true

    -- Use the tear's own Sprite. No extra Sprite objects are allocated per bullet.
    -- Projectile behavior remains native except for the explicitly adjusted fourth-round
    -- collision radius, damage multiplier, and piercing flag.
    if not BULLET_ASSET_READY then
        return
    end

    local sprite = tear:GetSprite()
    local originalFilename = sprite:GetFilename()
    local originalAnimation = sprite:GetAnimation()
    local originalFrame = sprite:GetFrame()

    sprite:Load(BULLET_ANM2, true)
    local resolvedFile = sprite:GetFilename()
    if not sprite:IsLoaded() or not hasBasename(resolvedFile, BULLET_ANM2_BASENAME) then
        Isaac.DebugString("[Revolver Samson] Tear sprite load failed; restoring vanilla sprite. resolved=" .. tostring(resolvedFile) .. "; IsLoaded=" .. tostring(sprite:IsLoaded()))
        restoreOriginalSprite(sprite, originalFilename, originalAnimation, originalFrame)
        data.revolverBulletLoadFailed = true
        return
    end

    sprite:Play(BULLET_ANIMATION, true)
    if not sprite:IsPlaying(BULLET_ANIMATION) then
        Isaac.DebugString("[Revolver Samson] Tear sprite could not play Idle; restoring vanilla sprite. file=" .. tostring(resolvedFile))
        restoreOriginalSprite(sprite, originalFilename, originalAnimation, originalFrame)
        data.revolverBulletLoadFailed = true
        return
    end

    sprite.Scale = getBulletSpriteScale(tear)
    if tear.Velocity and tear.Velocity:Length() > 0.01 then
        sprite.Rotation = tear.Velocity:GetAngleDegrees()
    end

    data.revolverBulletSpriteApplied = true
    Isaac.DebugString("[Revolver Samson] Bullet sprite applied to native tear; file=" .. tostring(resolvedFile) .. "; nativeScale=" .. tostring(tear.Scale) .. "; visualScale=" .. tostring(BULLET_SCALE * (tonumber(tear.Scale) or 1.0)))
end

local function copyPosition(position)
    return Vector(position.X, position.Y)
end

local function getSpecialVolleyHitSet(npcData)
    if not npcData.revolverSpecialVolleyHits then
        npcData.revolverSpecialVolleyHits = {}
    end
    return npcData.revolverSpecialVolleyHits
end

local function markNpcHitBySpecialVolley(npcData, volleyId)
    if volleyId and volleyId > 0 then
        getSpecialVolleyHitSet(npcData)[volleyId] = true
    end
end

local function npcAlreadyHitByVolley(npcData, volleyId)
    return volleyId and volleyId > 0
        and npcData.revolverSpecialVolleyHits ~= nil
        and npcData.revolverSpecialVolleyHits[volleyId] == true
end

local function applySplitPatchDamage(npc, event, frameNow)
    if not npc or not npc:Exists() or npc:IsDead() then
        return
    end
    if event.parent and npc == event.parent then
        return
    end

    local npcData = npc:GetData()
    local spawnFrame = npcData.revolverSpawnFrame
    if type(spawnFrame) ~= "number" or spawnFrame < event.hitFrame or spawnFrame > event.expiresFrame then
        return
    end

    local hp = tonumber(npc.HitPoints) or 0
    if hp <= 0 then
        return
    end
    if (npc.Position - event.position):Length() > SPLIT_PATCH_RADIUS then
        return
    end

    -- If the normal special tear already hit this NPC during the same volley, do not
    -- apply scripted follow-up damage too. Also tag the exact original tear so its
    -- later collision with this child is suppressed after the patch damages it.
    if npcAlreadyHitByVolley(npcData, event.volleyId) then
        return
    end
    markNpcHitBySpecialVolley(npcData, event.volleyId)
    if event.tear then
        npcData.revolverSplitPatchedTears = npcData.revolverSplitPatchedTears or {}
        npcData.revolverSplitPatchedTears[event.tear] = true
    end

    -- Propagate the same shot context in case this spawned NPC also splits on death.
    npcData.revolverPendingSpecialKill = {
        hitFrame = frameNow,
        volleyId = event.volleyId,
        damage = event.damage,
        position = copyPosition(npc.Position),
        player = event.player,
        tear = event.tear,
    }

    local damageSourceEntity = event.player
    if not damageSourceEntity or not damageSourceEntity:Exists() then
        damageSourceEntity = Isaac.GetPlayer(0)
    end
    if not damageSourceEntity then
        return
    end

    npc:TakeDamage(event.damage, 0, EntityRef(damageSourceEntity), 0)
    Isaac.DebugString("[Revolver Samson] Fourth-round split patch: damaged spawned NPC at "
        .. tostring(npc.Position) .. " for " .. tostring(event.damage)
        .. " (volley=" .. tostring(event.volleyId) .. ")")
end

local function queueSplitPatchFromDeadNpc(npc)
    local npcData = npc:GetData()
    local hit = npcData.revolverPendingSpecialKill
    if not hit then
        return
    end

    local frameNow = game:GetFrameCount()
    local event = {
        position = copyPosition(npc.Position),
        hitFrame = hit.hitFrame or frameNow,
        createdFrame = frameNow,
        expiresFrame = frameNow + SPLIT_PATCH_WINDOW_FRAMES,
        volleyId = hit.volleyId,
        damage = tonumber(hit.damage) or 0,
        player = hit.player,
        tear = hit.tear,
        parent = npc,
    }
    npcData.revolverPendingSpecialKill = nil

    if event.damage <= 0 or event.volleyId == nil or event.volleyId <= 0 then
        return
    end

    pendingFourthRoundSplitEvents[#pendingFourthRoundSplitEvents + 1] = event
    Isaac.DebugString("[Revolver Samson] Fourth-round split patch armed at "
        .. tostring(event.position) .. "; radius=" .. tostring(SPLIT_PATCH_RADIUS)
        .. "; window=" .. tostring(SPLIT_PATCH_WINDOW_FRAMES)
        .. "; volley=" .. tostring(event.volleyId))
end

-- Mark when an NPC is created so only freshly spawned enemies near the dead parent are
-- eligible for the patch. This avoids hitting monsters that were already in the room.
mod:AddCallback(ModCallbacks.MC_POST_NPC_INIT, function(_, npc)
    npc:GetData().revolverSpawnFrame = game:GetFrameCount()
end)

-- Detect lethal damage from the fourth-round tear. HitPoints is read before this damage
-- is applied, so comparing it with Amount records likely lethal hits only.
mod:AddCallback(ModCallbacks.MC_ENTITY_TAKE_DMG, function(_, entity, amount, damageFlags, source, countdown)
    local npc = entity and entity:ToNPC()
    if not npc then
        return
    end

    local sourceEntity = source and source.Entity
    local tear = sourceEntity and sourceEntity:ToTear()
    if not tear then
        return
    end

    local tearData = tear:GetData()
    if tearData.revolverShotNumber ~= SHOTS_PER_CYLINDER then
        return
    end

    local volleyId = tonumber(tearData.revolverVolleyId)
    if not volleyId or volleyId <= 0 then
        return
    end

    local npcData = npc:GetData()
    if npcData.revolverSplitPatchedTears and npcData.revolverSplitPatchedTears[tear] then
        -- This exact tear already damaged this spawned child through the patch; cancel
        -- its later native collision so the same projectile cannot damage it twice.
        return false
    end

    markNpcHitBySpecialVolley(npcData, volleyId)
    local hpBeforeHit = tonumber(npc.HitPoints) or math.huge
    if tonumber(amount) and amount >= hpBeforeHit then
        npcData.revolverPendingSpecialKill = {
            hitFrame = game:GetFrameCount(),
            volleyId = volleyId,
            damage = tonumber(tear.CollisionDamage) or tonumber(amount) or 0,
            position = copyPosition(npc.Position),
            player = getPlayerFromEntity(tear.SpawnerEntity),
            tear = tear,
        }
    end
end)

-- Clear a predicted lethal marker if the NPC survives the hit. HitPoints update on the
-- next frame; retain the marker while the NPC is dead or at zero HP during its death anim.
mod:AddCallback(ModCallbacks.MC_NPC_UPDATE, function(_, npc)
    local npcData = npc:GetData()
    local pending = npcData.revolverPendingSpecialKill
    if pending and game:GetFrameCount() > (pending.hitFrame or 0) + LETHAL_HIT_PENDING_GRACE_FRAMES then
        if not npc:IsDead() and (tonumber(npc.HitPoints) or 0) > 0 then
            npcData.revolverPendingSpecialKill = nil
        end
    end
end)

mod:AddCallback(ModCallbacks.MC_POST_NPC_DEATH, function(_, npc)
    queueSplitPatchFromDeadNpc(npc)
end)

-- Process nearby freshly-created NPCs only while a fourth-round death event is active.
mod:AddCallback(ModCallbacks.MC_POST_UPDATE, function()
    if #pendingFourthRoundSplitEvents == 0 then
        return
    end

    local frameNow = game:GetFrameCount()
    local roomEntities = Isaac.GetRoomEntities()
    for eventIndex = #pendingFourthRoundSplitEvents, 1, -1 do
        local event = pendingFourthRoundSplitEvents[eventIndex]
        if frameNow > event.expiresFrame then
            table.remove(pendingFourthRoundSplitEvents, eventIndex)
        else
            for _, entity in ipairs(roomEntities) do
                local npc = entity:ToNPC()
                if npc then
                    applySplitPatchDamage(npc, event, frameNow)
                end
            end
        end
    end
end)

-- Do not carry spawn-hit windows into a different room.
mod:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, function()
    pendingFourthRoundSplitEvents = {}
end)

-- Identify supported vanilla negative multipliers so the cache callback can replace
-- their full penalty with a diminishing one. Flat Tears downs / delay changes remain native.
-- Recompute from current inventory; never accumulate a penalty or compensation balance.
local function getNegativeTearRateMultiplier(player)
    local multiplier = 1.0
    local hasDrFetus = player:HasCollectible(168)
    local hasBrimstone = player:HasCollectible(118)
    local hasIpecac = player:HasCollectible(149)
    local hasCSection = player:HasCollectible(678)
    -- C Section overrides Monstro's Lung's ordinary tear behavior/rate penalty.
    local hasMonstroLung = player:HasCollectible(229) and not hasCSection

    -- Repentance's Dr. Fetus / Brimstone / Ipecac / Monstro's Lung priority and stacking rules.
    -- Dr. Fetus uses x0.4 unless Monstro's Lung takes priority; Brimstone overrides Ipecac;
    -- Monstro's Lung and Ipecac stack when neither Dr. Fetus nor Brimstone is present.
    if hasDrFetus then
        if hasMonstroLung then
            multiplier = multiplier * (1.0 / 4.3)
        else
            multiplier = multiplier * 0.4
        end
    elseif hasBrimstone then
        multiplier = multiplier * (1.0 / 3.0)
    elseif hasMonstroLung then
        multiplier = multiplier * (1.0 / 4.3)
        if hasIpecac then
            multiplier = multiplier * (1.0 / 3.0)
        end
    elseif hasIpecac then
        multiplier = multiplier * (1.0 / 3.0)
    end

    -- Polyphemus, Mutant Spider and The Inner Eye share a non-stacking fire-rate penalty.
    -- 20/20 removes this penalty. Polyphemus + C Section also removes Polyphemus's rate penalty.
    if not player:HasCollectible(245) then -- 20/20
        if player:HasCollectible(169) or player:HasCollectible(153) then -- Polyphemus / Mutant Spider
            if not (hasCSection and player:HasCollectible(169)) then
                multiplier = multiplier * 0.42
            end
        elseif player:HasCollectible(2) then -- The Inner Eye
            multiplier = multiplier * 0.51
        end
    end

    -- Eve's Mascara's x0.66 tears multiplier stacks with the above groups.
    if player:HasCollectible(310) then
        multiplier = multiplier * 0.66
    end

    return multiplier
end

-- Apply the intrinsic bonus in ordinary Tears-stat space, not as +0.35 final shots/sec.
-- The standard API exposes only effective delay, so reconstruct the ordinary curve.
-- Preserve existing rate above the native soft cap rather than clamping cap-breakers.
-- Exotic positive multipliers / other mods' delay rewrites cannot be separated here.
local function withIntrinsicTearBonus(rate)
    local function rateFromTears(tears)
        local delay
        if tears < -0.77 then
            delay = 16 - 6 * tears
        else
            delay = 16 - 6 * math.sqrt(math.max(0, 1 + 1.3 * tears))
            if tears < 0 then delay = delay - 6 * tears end
        end
        return 30 / math.max(6, delay + 1)
    end

    if rate >= NATIVE_SOFT_CAP_TEAR_RATE then return rate end
    local lower = math.min(-100, (17 - 30 / math.max(0.000001, rate)) / 6 - 1)
    local upper = (((17 - 5) / 6) ^ 2 - 1) / 1.3 -- Tears value at native delay 5
    for _ = 1, 48 do
        local middle = (lower + upper) / 2
        if rateFromTears(middle) < rate then lower = middle else upper = middle end
    end
    return rateFromTears((lower + upper) / 2 + INTRINSIC_TEAR_BONUS)
end

if PLAYER_TYPE == -1 then
    Isaac.DebugString("[Revolver Samson] PlayerType 'RevolverSamson' was not found. Check content/players.xml.")
else
    Isaac.DebugString("[Revolver Samson] Requested base Tears/sec setting: " .. tostring(TARGET_BASE_TEAR_RATE)
        .. "; fire-rate multiplier=" .. tostring(FIRE_RATE_MULTIPLIER)
        .. "; calibrated reference rate at native 5.0=" .. tostring(TARGET_RATE_AT_NATIVE_SOFT_CAP)
        .. "; no custom hard cap")
end

-- All character stat changes are applied through cache callbacks so collectible
-- bonuses are retained. In the fire-delay cache, calibrate the incoming native fire rate so
-- the initial Analog Stick start is about 0.78 after the x0.33 modifier, and the native 5.0
-- reference maps to about 1.67. This is not a hard cap: values above the reference continue
-- through the same linear calibration. Cache callbacks start from recalculated native stats,
-- so this does not multiply a previously modified delay repeatedly.
mod:AddCallback(ModCallbacks.MC_EVALUATE_CACHE, function(_, player, cacheFlag)
    if not isRevolverSamson(player) then
        return
    end

    local data = getData(player)

    if cacheFlag == CacheFlag.CACHE_SPEED then
        -- Isaac baseline 1.0 -> requested 1.0.
        player.MoveSpeed = player.MoveSpeed + (TARGET_SPEED - 1.0)

    elseif cacheFlag == CacheFlag.CACHE_FIREDELAY then
        -- The engine gives us an already-computed effective rate. Keep the calibrated ~0.78
        -- start with Analog Stick, and map native rate 5.0 to a ~1.67 reference after x0.33.
        -- Do not clamp calibrationProgress to 1: this lets fire-rate upgrades continue to
        -- increase the final rate above 1.67 rather than treating that reference as a hard cap.
        local incomingDelay = tonumber(player.MaxFireDelay) or BASE_GAME_FIRE_DELAY
        local rawIncomingRate = 30 / math.max(0.01, incomingDelay + 1)
        local negativeMultiplier = getNegativeTearRateMultiplier(player)
        -- First recover the rate before the supported negative multipliers so calibration
        -- does not distort their replacement. Positive/cap-breaking effects remain present.
        local currentRate = withIntrinsicTearBonus(rawIncomingRate / math.max(0.000001, negativeMultiplier))
        local baselineRatio = TARGET_BASE_TEAR_RATE / STANDARD_BASE_TEAR_RATE
        local baseAdjustedRate
        local calibrationProgress = 0

        if currentRate <= ANALOG_STICK_NATIVE_RATE then
            -- At/under the initial-with-Analog-Stick point, retain the 2.1 baseline ratio.
            baseAdjustedRate = currentRate * baselineRatio
        else
            -- Interpolate from the calibrated starting rate to 1.67/0.33 at the native 5.0
            -- reference rate. The progress is intentionally not capped at 1, so higher rates
            -- continue to scale instead of being frozen at the reference point.
            calibrationProgress = math.max(0,
                (currentRate - ANALOG_STICK_NATIVE_RATE)
                / math.max(0.001, NATIVE_SOFT_CAP_TEAR_RATE - ANALOG_STICK_NATIVE_RATE))
            baseAdjustedRate = TARGET_START_RATE_AFTER_CALIBRATION
                + (CALIBRATED_RATE_AT_REFERENCE - TARGET_START_RATE_AFTER_CALIBRATION) * calibrationProgress
        end

        local multipliedRate = baseAdjustedRate * FIRE_RATE_MULTIPLIER
        -- At the native ordinary soft cap, map M to C = 1 + (1.67 - 1) * M.
        -- Scale the whole calibrated rate by C/1.67: actual low rates may stay below 1,
        -- while cap-breaking bonuses can still exceed C. Never hard-clamp the final rate.
        local normalSoftCap = MINIMUM_NORMAL_TEAR_RATE_SOFT_CAP
            + (TARGET_RATE_AT_NATIVE_SOFT_CAP - MINIMUM_NORMAL_TEAR_RATE_SOFT_CAP) * negativeMultiplier
        local effectiveNegativeMultiplier = normalSoftCap / TARGET_RATE_AT_NATIVE_SOFT_CAP
        local finalRate = math.max(0.01, multipliedRate * effectiveNegativeMultiplier)
        local finalDelay = (30 / finalRate) - 1
        player.MaxFireDelay = finalDelay
        Isaac.DebugString("[Revolver Samson] Fire-rate calculation: incomingDelay=" .. tostring(incomingDelay)
            .. ", rawIncomingRate=" .. tostring(rawIncomingRate)
            .. ", nativeNegativeMultiplier=" .. tostring(negativeMultiplier)
            .. ", rateBeforeNegativeMultipliers=" .. tostring(currentRate)
            .. ", normalSoftCap=" .. tostring(normalSoftCap)
            .. ", effectiveNegativeMultiplier=" .. tostring(effectiveNegativeMultiplier)
            .. ", baseSetting=" .. tostring(TARGET_BASE_TEAR_RATE)
            .. ", standardBaseline=" .. tostring(STANDARD_BASE_TEAR_RATE)
            .. ", analogStickReferenceRate=" .. tostring(ANALOG_STICK_NATIVE_RATE)
            .. ", calibratedRateBeforeMultiplier=" .. tostring(baseAdjustedRate)
            .. ", calibrationProgress=" .. tostring(calibrationProgress)
            .. ", fireRateMultiplier=" .. tostring(FIRE_RATE_MULTIPLIER)
            .. ", rateAtNativeSoftCapReference=" .. tostring(TARGET_RATE_AT_NATIVE_SOFT_CAP)
            .. ", rateAfterMultiplier=" .. tostring(multipliedRate)
            .. ", customHardCap=none"
            .. ", finalRate=" .. tostring(finalRate)
            .. ", resultingMaxFireDelay=" .. tostring(player.MaxFireDelay))

    elseif cacheFlag == CacheFlag.CACHE_DAMAGE then
        -- Preserve the native 3.5 base stat, add shot-speed overflow damage,
        -- then apply the requested 1.2x damage modifier once per cache evaluation.
        -- Cache evaluation starts from the engine's recomputed values, so the
        -- multiplier does not compound on itself. At run start: 3.5 * 1.2 = 4.2.
        local excess = data.revolverShotSpeedExcess or 0
        -- The baseline stat gets the character's 1.2x modifier. Shot-speed overflow
        -- is added afterward so 1.0 excess speed means exactly +3.0 final damage.
        player.Damage = (player.Damage + (TARGET_BASE_DAMAGE - 3.5)) * DAMAGE_MULTIPLIER
            + excess * DAMAGE_PER_EXCESS_SHOT_SPEED

    elseif cacheFlag == CacheFlag.CACHE_RANGE then
        -- TearRange is measured in 1/40-tile units in the Lua API.
        player.TearRange = player.TearRange + ((TARGET_RANGE_TILES - DEFAULT_RANGE_TILES) * RANGE_UNITS_PER_TILE)

    elseif cacheFlag == CacheFlag.CACHE_SHOTSPEED then
        -- Isaac baseline 1.0 -> requested 2.0. Anything over 3 adds 3 final damage per excess speed.
        local previousExcess = data.revolverShotSpeedExcess or 0
        local uncappedSpeed = player.ShotSpeed + (TARGET_SHOT_SPEED - DEFAULT_SHOT_SPEED)
        local excess = math.max(0, uncappedSpeed - MAX_SHOT_SPEED)
        player.ShotSpeed = math.min(uncappedSpeed, MAX_SHOT_SPEED)
        data.revolverShotSpeedExcess = excess
        if math.abs(excess - previousExcess) > 0.001 then
            Isaac.DebugString("[Revolver Samson] ShotSpeed conversion: raw=" .. tostring(uncappedSpeed) .. ", capped=" .. tostring(player.ShotSpeed) .. ", excess=" .. tostring(excess) .. ", final damage bonus=" .. tostring(excess * DAMAGE_PER_EXCESS_SHOT_SPEED))
            -- CACHE_SHOTSPEED alone does not necessarily recalculate damage.
            -- Re-evaluate damage once on the next player update, after this cache pass.
            data.revolverPendingDamageRecalc = true
        end
    end
end)

mod:AddCallback(ModCallbacks.MC_POST_PLAYER_INIT, function(_, player)
    if isRevolverSamson(player) then
        local data = getData(player)
        data.revolverShots = 0
        data.revolverReloadTimer = nil
        data.revolverReloadCompleteFrames = 0
        data.revolverShotSpeedExcess = data.revolverShotSpeedExcess or 0
        player:AddCacheFlags(CacheFlag.CACHE_SPEED)
        player:AddCacheFlags(CacheFlag.CACHE_FIREDELAY)
        player:AddCacheFlags(CacheFlag.CACHE_DAMAGE)
        player:AddCacheFlags(CacheFlag.CACHE_RANGE)
        player:AddCacheFlags(CacheFlag.CACHE_SHOTSPEED)
        player:EvaluateItems()
    end
end)

-- Count one attack per game frame, not each projectile in a multi-shot volley.
mod:AddCallback(ModCallbacks.MC_POST_FIRE_TEAR, function(_, tear)
    local player = getPlayerFromEntity(tear.SpawnerEntity)
    if not isRevolverSamson(player) then
        return
    end

    local data = getData(player)
    local frame = game:GetFrameCount()

    -- All tears created in the same frame belong to one volley. Keep the chosen
    -- round number on the player so multishot items share damage/flags correctly.
    if data.revolverLastAttackFrame ~= frame then
        data.revolverLastAttackFrame = frame
        if not data.revolverReloadTimer or data.revolverReloadTimer <= 0 then
            local shotNumber = math.min(SHOTS_PER_CYLINDER, (data.revolverShots or 0) + 1)
            data.revolverShots = shotNumber
            data.revolverLastVolleyNumber = shotNumber
            globalVolleySerial = globalVolleySerial + 1
            data.revolverLastVolleyId = globalVolleySerial
            Isaac.DebugString("[Revolver Samson] Attack count: " .. tostring(data.revolverShots) .. "/" .. tostring(SHOTS_PER_CYLINDER))
            if shotNumber >= SHOTS_PER_CYLINDER then
                startReload(player)
            end
        else
            -- If an auxiliary source still emits a tear during reload, it must
            -- not inherit the previous frame's special 4th-volley flag.
            data.revolverLastVolleyNumber = 0
            data.revolverLastVolleyId = 0
        end
    end

    local shotNumber = math.max(1, math.min(SHOTS_PER_CYLINDER, data.revolverLastVolleyNumber or 1))
    if shotNumber == SHOTS_PER_CYLINDER then
        tear.CollisionDamage = player.Damage * LAST_TEAR_DAMAGE_MULTIPLIER
        tear.TearFlags = tear.TearFlags | TearFlags.TEAR_PIERCING
    else
        tear.CollisionDamage = player.Damage * NORMAL_TEAR_DAMAGE_MULTIPLIER
    end
    -- Store the volley number on THIS tear. The visual-scale helper reads tear data;
    -- writing only the player's data would make the fourth-round visual multiplier ineffective.
    local tearData = tear:GetData()
    tearData.revolverShotNumber = shotNumber
    tearData.revolverVolleyId = tonumber(data.revolverLastVolleyId) or 0
    data.revolverShotNumber = shotNumber -- retained as player-side debug/state metadata

    applyBulletCollisionSize(tear, shotNumber)
    applyBulletSprite(tear)
end)

-- Keep the bullet tip aligned to the live tear velocity. This updates only the
-- Sprite rotation/scale; the fourth-round collision size is set once on fire.
mod:AddCallback(ModCallbacks.MC_POST_TEAR_UPDATE, function(_, tear)
    local data = tear:GetData()
    if not data.revolverBulletSpriteApplied then
        return
    end
    local player = getPlayerFromEntity(tear.SpawnerEntity)
    if not isRevolverSamson(player) then
        return
    end

    local sprite = tear:GetSprite()
    if not sprite:IsPlaying(BULLET_ANIMATION) then
        sprite:Play(BULLET_ANIMATION, true)
    end
    sprite.Scale = getBulletSpriteScale(tear)
    if tear.Velocity and tear.Velocity:Length() > 0.01 then
        sprite.Rotation = tear.Velocity:GetAngleDegrees()
    end
end)

-- Block four shoot directions during the reload. Movement input remains untouched.
mod:AddCallback(ModCallbacks.MC_INPUT_ACTION, function(_, entity, inputHook, buttonAction)
    local player = getPlayerFromEntity(entity)
    if not isRevolverSamson(player) or not SHOOT_ACTIONS[buttonAction] then
        return nil
    end

    local data = getData(player)
    if not data.revolverReloadTimer or data.revolverReloadTimer <= 0 then
        return nil
    end

    if inputHook == InputHook.GET_ACTION_VALUE then
        return 0.0
    end
    return false
end)

-- Reload timer and brief completion animation.
mod:AddCallback(ModCallbacks.MC_POST_PEFFECT_UPDATE, function(_, player)
    if not isRevolverSamson(player) then
        return
    end

    local data = getData(player)

    if data.revolverPendingDamageRecalc then
        data.revolverPendingDamageRecalc = false
        player:AddCacheFlags(CacheFlag.CACHE_DAMAGE)
        player:EvaluateItems()
    end

    if data.revolverReloadTimer and data.revolverReloadTimer > 0 then
        data.revolverReloadTimer = data.revolverReloadTimer - 1
        if data.revolverReloadTimer <= 0 then
            data.revolverReloadTimer = nil
            data.revolverShots = 0
            data.revolverReloadCompleteFrames = COMPLETE_FLASH_FRAMES
            local sprite = getChargeSprite(player)
            sprite:Play("Charged", true)
            data.revolverChargeMode = "Charged"
            Isaac.DebugString("[Revolver Samson] Reload complete")
        end
    elseif data.revolverReloadCompleteFrames and data.revolverReloadCompleteFrames > 0 then
        local sprite = getChargeSprite(player)
        if data.revolverChargeMode ~= "Charged" then
            sprite:Play("Charged", true)
            data.revolverChargeMode = "Charged"
        end
        sprite:Update()
        data.revolverReloadCompleteFrames = data.revolverReloadCompleteFrames - 1
    else
        data.revolverReloadCompleteFrames = 0
    end
end)

-- Render only the reload indicator here. Projectile visuals use the engine's
-- normal tear-render pipeline, avoiding a room-wide per-frame render pass.
mod:AddCallback(ModCallbacks.MC_POST_RENDER, function()
    if game:IsPaused() then return end
    for i = 0, game:GetNumPlayers() - 1 do
        local player = Isaac.GetPlayer(i)
        if isRevolverSamson(player) then
            local data = getData(player)
            local isReloading = data.revolverReloadTimer and data.revolverReloadTimer > 0
            local isFinishing = data.revolverReloadCompleteFrames and data.revolverReloadCompleteFrames > 0

            -- Four compact cartridge cells stay close to the lower-left screen edge.
            local sprites = getAmmoUISprites()
            if sprites then
                local screenHeight = Isaac.GetScreenHeight()
                local y = screenHeight - AMMO_UI_BOTTOM_MARGIN
                local shotsSpent = math.max(0, math.min(SHOTS_PER_CYLINDER, data.revolverShots or 0))
                for cell = 1, AMMO_ICON_COUNT do
                    local frameIndex
                    if isReloading or cell <= shotsSpent then
                        frameIndex = 0 -- spent / reloading
                    elseif cell == SHOTS_PER_CYLINDER then
                        frameIndex = 2 -- special emerald knife
                    else
                        frameIndex = 1 -- ready brass round
                    end
                    local sprite = sprites[cell]
                    sprite:SetFrame("Idle", frameIndex)
                    sprite.Color = frameIndex == 2
                        and Color(0.5,1,1,1,0,0.05,0.15) or Color(1,1,1,1)
                    local x = AMMO_UI_LEFT + (cell - 1) * AMMO_ICON_SPACING + 7
                    sprite:Render(Vector(x, y), Vector(0, 0), Vector(0, 0))
                end
            end

            -- The fitted emerald last-round outline is drawn by silent_visuals,
            -- behind the live character parts rather than as a detached ring.

            -- Native-style circular chargebar remains the reload progress indicator.
            if isReloading or isFinishing then
                local sprite = getChargeSprite(player)
                if isReloading then
                    if data.revolverChargeMode ~= "Charging" then
                        sprite:Play("Charging", true)
                        data.revolverChargeMode = "Charging"
                    end
                    local duration = math.max(1, data.revolverReloadDuration or 45)
                    local remaining = math.max(0, data.revolverReloadTimer or 0)
                    local progress = math.max(0, math.min(1, 1 - remaining / duration))
                    sprite:SetFrame("Charging", math.floor(progress * 100 + 0.5))
                end
                local renderPosition = Isaac.WorldToScreen(player.Position) + Vector(0, -34)
                sprite:Render(renderPosition, Vector(0, 0), Vector(0, 0))
            end
        end
    end
end)

include("tainted_hunter_costumes")(mod, TAINTED_PLAYER_TYPE)
