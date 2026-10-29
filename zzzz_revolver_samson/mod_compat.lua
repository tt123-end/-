-- v1.33: optional Specialist and EID integrations. No dependency files are edited.
return function(mod, playerType)
    local game = Game()
    local registeredEID, registeredAPI, observedEpic
    local marker = Isaac.GetCostumeIdByPath("gfx/characters/silent_specialist_marker.anm2")

    local descriptions = {
        zh_cn = table.concat({
            "{{ShotSpeed}} 弹速上限3；每1点超额弹速转为+3攻击力",
            "{{Tears}} 射速倍率降低的惩罚逐渐减弱",
            "普通射速软上限最低降至1（不保底实际射速）",
            "{{Damage}} 每轮前3发各造成面板攻击力300%的伤害",
            "{{Damage}} 第4发造成600%伤害，并穿透敌人",
            "每轮4发后换弹，耗时为2倍攻击间隔"
        }, "#"),
        en_us = table.concat({
            "{{ShotSpeed}} Shot speed caps at 3; each excess point grants +3 damage",
            "{{Tears}} Diminishing penalties from negative fire-rate multipliers",
            "Normal tears soft cap bottoms out at 1; actual tears are not floored",
            "{{Damage}} First 3 shots each deal 300% of sheet damage",
            "{{Damage}} Fourth shot deals 600% damage and pierces enemies",
            "Reload after 4 shots; takes twice the attack interval"
        }, "#")
    }

    local function clearDance()
        for i = 0, game:GetNumPlayers() - 1 do
            local player = Isaac.GetPlayer(i)
            if player:GetPlayerType() == playerType then
                player:GetData().silentSpecialist133 = nil
            end
        end
    end

    local function install()
        if playerType == -1 then return end
        if EID and EID.addCharacterInfo and registeredEID ~= EID then
            EID:addCharacterInfo(playerType, descriptions.en_us, "HUNTER", "en_us")
            EID:addCharacterInfo(playerType, descriptions.zh_cn, "HUNTER", "zh_cn")
            registeredEID = EID
        end
        if not SpecialistModAPI or not SpecialistModAPI.AddDanceCostume
            or not Epic or type(Epic.DoCostume) ~= "function" or marker == -1 then return end
        if registeredAPI ~= SpecialistModAPI then
            -- A transparent costume replaces Specialist's fallback Isaac skin for
            -- this player only. The dedicated screen renderer supplies the dancer.
            SpecialistModAPI:AddDanceCostume(playerType, marker, true)
            registeredAPI = SpecialistModAPI
        end
        if observedEpic ~= Epic or Epic.DoCostume ~= Epic._hunterDanceObserver133 then
            local original = Epic.DoCostume
            local wrapper = function(self, apply, ...)
                local results = table.pack(original(self, apply, ...))
                -- Observe the mod's final decision rather than scanning items again:
                -- quality settings, custom lists, blindness and music stay upstream.
                local active = apply and results[1] == true
                for i = 0, game:GetNumPlayers() - 1 do
                    local player = Isaac.GetPlayer(i)
                    if player:GetPlayerType() == playerType then
                        local data = player:GetData()
                        if active then
                            data.silentSpecialist133 = data.silentSpecialist133 or game:GetFrameCount()
                        else
                            data.silentSpecialist133 = nil
                        end
                    end
                end
                return table.unpack(results, 1, results.n)
            end
            Epic.DoCostume = wrapper
            Epic._hunterDanceObserver133 = wrapper
            observedEpic = Epic
        end
    end

    install()
    mod:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, function()
        clearDance()
        install()
    end)
    mod:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, clearDance)
    -- Also supports dependencies that publish their API after MC_POST_GAME_STARTED.
    -- Registration and wrapping run once per dependency instance, never every frame.
    mod:AddCallback(ModCallbacks.MC_POST_UPDATE, install)
end
