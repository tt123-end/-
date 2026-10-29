-- User-approved v163 compatibility policy. Pure calculations and native queries.
local R={version=172,baseShot=4,chemicalName="Hunter Chemical Peel",chocolateName="Hunter Chocolate Milk"}
function R.count(p,id)
    local n=p:GetCollectibleNum(id,true)
    local e=p:GetEffects()
    n=n+(e and e:GetCollectibleEffectNum(id)or 0)
    if id==69 then
        local token=Isaac.GetItemIdByName(R.chocolateName)
        if token and token>0 then n=n+p:GetCollectibleNum(token,true)+(e and e:GetCollectibleEffectNum(token)or 0)end
    end
    return n
end
function R.has(p,id)return R.count(p,id)>0 end
function R.blastCombo(p)return R.has(p,52)and R.has(p,149)end
function R.brim(p)return R.has(p,118)or R.has(p,556)end
function R.interval(p)return math.max(1,(p.MaxFireDelay or 10)+1)end
function R.capacity(p)return R.has(p,619)and 2 or 1 end
function R.roundInterval(p)return R.interval(p)*(R.has(p,619)and .2 or 1)end
function R.chocolate(rate,cap)
    if not cap or cap<=0 then return 1.2 end
    local ratio=math.max(.25,math.min(1,rate/cap))
    return 1.2+2.8*((1-ratio)/.75)^2
end
function R.chocolateFor(p)
    if not R.has(p,69)then return 1 end
    local d=p:GetData().hunterTears161
    return R.chocolate(30/R.interval(p),d and d.capRate or 1)
end
function R.hornChance(luck)return math.min(1,5*math.min(.2,1/math.max(1,20-luck)))end
function R.isEpic(p)return R.has(p,168)end
function R.technology(p)
    return R.has(p,68)and not R.brim(p)and not R.has(p,395)and not R.has(p,678)
        and not R.has(p,52)and not R.has(p,149)and not R.isEpic(p)
end
function R.scripted(p)
    if R.isEpic(p)then return false end
    if p.HasWeaponType then
        for _,name in ipairs({"WEAPON_NOTCHED_AXE","WEAPON_URN_OF_SOULS","WEAPON_UMBILICAL_WHIP"})do
            if WeaponType[name]and p:HasWeaponType(WeaponType[name])then return false end
        end
    end
    if R.technology(p)then return true end
    if R.has(p,678)then return true end
    if R.has(p,579)then return true end
    for _,id in ipairs({52,69,114,118,149,154,229,316,395,440,533,556,579,678})do
        if R.has(p,id)then return true end
    end
    if R.has(p,329)then return false end
    if p.HasWeaponType and WeaponType.WEAPON_BONE and p:HasWeaponType(WeaponType.WEAPON_BONE)then return false end
    return false
end
function R.clearFlag(tear,name)
    local flag=TearFlags[name]
    if flag then tear:ClearTearFlags(flag)end
end
function R.addFlag(tear,name)
    local flag=TearFlags[name]
    if flag then tear:AddTearFlags(flag)end
end
function R.inherits(familiar)
    local names={INCUBUS=true,FATES_REWARD=true,CAINS_OTHER_EYE=true,
        PAPA_FLY=true,SPRINKLER=true,TWISTED_BABY=true,UMBILICAL_BABY=true,BLOOD_BABY=true}
    for name in pairs(names)do if FamiliarVariant[name]and familiar.Variant==FamiliarVariant[name]then return true end end
    return false
end
return R
