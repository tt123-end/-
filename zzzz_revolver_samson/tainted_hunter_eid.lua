-- v1.58: optional character-trait descriptions for the uploaded EID API.
-- This only registers text. Character mechanics and EID's own files are untouched.
return function(mod, playerType)
    local registeredEID
    local descriptions={
        zh_cn=table.concat({
            "{{Damage}} 单发泪弹造成角色面板攻击力400%的伤害",
            "默认每次攻击后进入换弹，持续1个攻击间隔",
            "长子权：弹仓2发，发间隔为面板间隔的20%，打空后正常换弹",
            "{{Warning}} 换弹期间受到的伤害翻倍",
            "{{BrokenHeart}} 非主动付血型伤害实际扣到心之容器内的红心时，每次+1碎心",
            "骨心外壳及其中填充的红心受伤不触发碎心",
            "献血机、恶魔乞丐、献祭刺、诅咒房刺门等不触发碎心",
            "{{Collectible169}} 默认巨人独眼式伪穿透：击杀后保留剩余伤害继续飞行；持有巨人独眼后改为真正穿透",
            "{{Tears}} 固有射速倍率×0.2，不再补偿负射速倍率惩罚",
            "指定道具的射速惩罚改为伤害调整；内眼/变异蜘蛛/萌死戳的肺仅取最低倍率",
            "完美视力取消上述三者降伤；与巨人独眼同时持有时取消完美视力的0.8倍降伤"
        },"#"),
        en_us=table.concat({
            "{{Damage}} Each tear deals 400% of the character's displayed damage",
            "Normally reload after every attack for one attack interval",
            "Birthright: 2 rounds, 20% of the sheet interval between rounds; normal reload when empty",
            "{{Warning}} Damage taken is doubled while reloading",
            "{{BrokenHeart}} Gain 1 Broken Heart per non-payment hit that actually removes Red Hearts from regular Heart Containers",
            "Bone Heart shells and the Red Hearts inside them do not trigger this penalty",
            "Blood donations, Devil Beggars, sacrifice spikes, Curse Room doors and similar health payments do not trigger this penalty",
            "{{Collectible169}} Default Polyphemus-style pseudo-piercing: killing blows retain excess damage and keep flying; owning Polyphemus grants true piercing",
            "{{Tears}} Innate x0.2 tears; no negative-multiplier compensation",
            "Listed item tears penalties are replaced by damage changes; Inner Eye/Mutant Spider/Monstro Lung use only the lowest multiplier",
            "20/20 removes those three damage penalties; Polyphemus also removes 20/20's x0.8 penalty"
        },"#")
    }
    local function install()
        if playerType==-1 then return end
        if EID and type(EID.addCharacterInfo)=="function" and registeredEID~=EID then
            EID:addCharacterInfo(playerType,descriptions.en_us,"TAINTED HUNTER","en_us")
            EID:addCharacterInfo(playerType,descriptions.zh_cn,"里猎手","zh_cn")
            registeredEID=EID
        end
    end
    install()
    mod:AddCallback(ModCallbacks.MC_POST_GAME_STARTED,install)
    -- As with regular Hunter, support EID loading after the character mod.
    -- The instance guard prevents duplicate registration on repeated updates.
    mod:AddCallback(ModCallbacks.MC_POST_UPDATE,install)
end
