-- Item descriptions apply only to the player whose EID page is being shown.
return function(mod,playerType)
    local installed
    local text={
        [2]={"保留三发；无原生射速惩罚，伤害×0.5；与变异蜘蛛/萌死戳的肺只取最低倍率；完美视力取消此降伤","Triple shot retained; no native tears penalty; x0.5 damage. Inner Eye/Mutant Spider/Monstro Lung use only the lowest multiplier;20/20 cancels it"},
        [153]={"保留四发；无原生射速惩罚，伤害×0.42；与内眼/萌死戳的肺只取最低倍率；完美视力取消此降伤","Quad shot retained; no native tears penalty; x0.42 damage. Use only the lowest of the three multishot penalties;20/20 cancels it"},
        [152]={"保留现有攻击方式；无原生射速惩罚，伤害倍率改为×0.75","Keep the existing attack; no native tears penalty; damage multiplier replaced with x0.75"},
        [169]={"取消原生伤害倍率与射速惩罚，只提供+8攻击力；飞刀获得真正穿透；同时持有完美视力时取消其0.8倍降伤","No native damage multiplier or tears penalty;+8 flat damage, true piercing knives. Also removes20/20's x0.8 penalty"},
        [310]={"仅伤害×1.35，不叠加原生×2；无射速惩罚、不降低弹速，改为弹速上限2","Only x1.35 damage, replacing native x2; no tears/shot-speed reduction; shot speed capped at2"},
        [531]={"保留当前攻击方式；无原生射速惩罚，移除原生伤害增幅，改为+3攻击力","Keep the current attack; no native tears penalty; replace native damage bonuses with+3 flat damage"},
        [245]={"取消内眼/变异蜘蛛/萌死戳的肺的伤害惩罚；同时持有巨人独眼时取消本身0.8倍降伤","Removes Inner Eye/Mutant Spider/Monstro Lung damage penalties; Polyphemus also cancels this item's x0.8 damage penalty"},
        [52]={"保留直线飞刀与原爆炸公式200%面板+30；无射速惩罚，伤害×0.8；与吐根组合时取消该降伤","Keep straight knives and native compatibility explosion200% sheet+30; no tears penalty, x0.8 damage. Ipecac removes that penalty"},
        [68]={"保留科技直线激光；每次命中造成400%面板伤害，遵守角色换弹机制","Technology straight lasers deal400% sheet damage per hit, with normal Hunter reload"},
        [69]={"替换为里猎手专用被动，完全移除原版蓄力/点按攻击；仅按当前射速/最高射速增伤：比例≤0.25时×4，比例1时×1.2；保持正常装填","Hunter replacement removes native charge/tap fire; only rate/cap damage scaling, x4 at0.25 and x1.2 at1; normal reload retained"},
        [114]={"转换为3把献祭匕首，不替换飞刀攻击","Replaced with3 Sacrificial Daggers; knives remain the primary weapon"},
        [118]={"每轮立即同时发射飞刀和50%原生伤害的硫磺火；血激光不因装填中断；取消原生射速惩罚","Fire a knife and a half-damage native Brimstone beam immediately; reload does not cancel it; no native tears penalty"},
        [168]={"保留原生准星导弹；爆炸后向随机方向射出3把400%面板伤害飞刀，继承弹速和射程","Native targeted rocket; explosion releases3 random knives, each400% sheet damage with player speed/range"},
        [229]={"保留立即散弹与换弹；取消原生射速惩罚，伤害×0.23；与内眼/变异蜘蛛只取最低倍率；完美视力取消此降伤","Immediate shotgun and reload retained; no native tears penalty, x0.23 damage. Use only the lowest multishot penalty;20/20 cancels it"},
        [316]={"不需蓄力；每轮5把飞刀，各80%面板伤害；装填期间受到真实伤害后随机传送，包含刺门等自伤；黑蜡烛可阻止传送","Immediate5-knife volley, each80% sheet damage; real damage during reload, including self-damage, teleports you; Black Candle prevents it"},
        [395]={"飞刀携带满蓄力伤害的科技X环；同时持有硫磺火则为加粗血环，不再额外发射直线血激光","A full-charge-damage Tech X ring follows each knife; Brimstone makes it a thick blood ring instead of a separate beam"},
        [556]={"在本房间获得里猎手的无蓄力硫磺火兼容","Grants Tainted Hunter's instant Brimstone compatibility for the room"},
        [579]={"仍发射飞刀，保留满血剑气；实际出手时调用原版满蓄力旋斩，需要REPENTOGON的旋斩接口；不再使用模拟挥砍","Keep knives and full-health beams; real native charged spin per actual attack, requiring REPENTOGON's spin-state API; no simulated slash"},
        [678]={"无蓄力携刀胎儿形态不变；伤害为v1.64兼容的25%（基础为1倍原生伤害），子实体不重复削减","Immediate knife-carrying fetuses retained;25% of v1.64 damage, base1x native; descendants inherit the reduction once"},
        [352]={"玻璃大炮原生伤害×4；其他原生效果保留","Glass Cannon native damage x4; its other effects remain native"},
        [149]={"保持直线飞刀与命中爆炸，可自伤；取消原生+40面板伤害及射速惩罚；飞刀与爆炸各为2×面板+40","Straight impact-exploding knives with self-damage; no native+40 sheet bonus or tears penalty; knife and explosion each2x sheet+40"},
        [533]={"保留原版光束弹；实际命中伤害为原版的4倍，角色面板不变","Keep native light projectiles;4x actual native hit damage; sheet damage unchanged"},
        [104]={"原飞刀及所有合法分裂弹全部落空，才尝试重置死亡之眼","Dead Eye can reset only when the entire primary/descendant group misses"},
        [150]={"触发时仍为飞刀，造成3.2倍普通飞刀伤害","Tooth procs keep the knife appearance and deal3.2x normal knife damage"},
        [154]={"替换为里猎手版本：原生属性加法阶段伤害+1.5，不再左右眼交替增伤","Hunter replacement: +1.5 additive damage instead of alternating-eye damage"},
        [237]={"保留其原生属性、尺寸和穿透；仍为深色飞刀","Native stats, size and piercing retained; dark knives replace the scythe visual"},
        [331]={"原生神性光环伤害×5；其他原生效果保留","Native Godhead aura damage x5; other effects retained"},
        [398]={"缩小效果触发概率改为50%","Shrink proc chance50%"},
        [429]={"有效泪弹命中掉币概率改为25%","25% coin-drop chance on an effective tear hit"},
        [443]={"触发时仍为飞刀，造成4倍普通飞刀伤害","Razor procs keep the knife appearance and deal4x normal knife damage"},
        [503]={"原生触发概率×5，最高100%","Native proc probability x5, capped at100%"},
        [637]={"转换为八寸钉","Replaced with8 Inch Nails"},
        [619]={"弹仓2发；两发之间为面板攻击间隔的20%；打空后按完整面板攻击间隔装填","2-round chamber;20% of the sheet interval between rounds; full-interval reload when empty"}
    }
    local function install()
        if installed==EID or not EID or type(EID.addDescriptionModifier)~="function"then return end
        EID:addDescriptionModifier("Hunter workbook163",function(desc)
            local p=EID.player or Isaac.GetPlayer(0)
            return p and p:GetPlayerType()==playerType and desc.ObjType==5 and desc.ObjVariant==100 and text[desc.ObjSubType]~=nil
        end,function(desc)
            local zh=EID:getLanguage()=="zh_cn";local p=EID.player or Isaac.GetPlayer(0)
            desc.Description=text[desc.ObjSubType][zh and 1 or 2]
            if (desc.ObjSubType==52 or desc.ObjSubType==149)and p:HasCollectible(52)and p:HasCollectible(149)then
                desc.Description=zh and "保留飞刀与爆炸；无原生射速惩罚，不再固定最高射速0.6；取消吐根+40面板与博士×0.8降伤；飞刀和爆炸均为2×面板+40；免疫爆炸"or"Knives and explosions; no native tears penalties or fixed0.6 cap; no Ipecac+40 sheet bonus or Dr Fetus x0.8 penalty; both2x sheet+40; explosion immunity"
            end
            return desc
        end)
        local token=Isaac.GetItemIdByName("Hunter Chemical Peel")
        if token and token>0 and type(EID.addCollectible)=="function"then
            EID:addCollectible(token,"{{Damage}} 原生属性加法阶段伤害+1.5，不再有左右眼差异","化学剥皮法（里猎手）","zh_cn")
            EID:addCollectible(token,"{{Damage}} +1.5 additive damage; no alternating-eye bonus","Chemical Peel (Hunter)","en_us")
        end
        local chocolate=Isaac.GetItemIdByName("Hunter Chocolate Milk")
        if chocolate and chocolate>0 and type(EID.addCollectible)=="function"then
            EID:addCollectible(chocolate,text[69][1],"巧克力牛奶（里猎手）","zh_cn")
            EID:addCollectible(chocolate,text[69][2],"Chocolate Milk (Hunter)","en_us")
        end
        installed=EID
    end
    install();mod:AddCallback(ModCallbacks.MC_POST_UPDATE,install)
end
