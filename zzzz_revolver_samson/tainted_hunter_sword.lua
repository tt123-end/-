-- Drive the actual Spirit Sword weapon across the complete input/weapon tick.
-- Native code owns its sword art, spin state, hitboxes and damage.
return function(mod,playerType,R)
    local S={active={},pending={}};local game=Game()
    local function method(object,name)
        local ok,value=pcall(function()return object[name]end)
        return ok and type(value)=='function'and value or nil
    end
    local function valid(p)return p and p:Exists()and not p:IsDead()and p:GetPlayerType()==playerType end
    local function owner(e,depth)
        if not e or(depth or 0)>6 then return end
        return e:ToPlayer()or owner(e.SpawnerEntity,(depth or 0)+1)or owner(e.Parent,(depth or 0)+1)
    end
    local function diag(p,s)p:GetData().hunterNativeSword166=s end
    local function weapon(p)
        local w=p:GetWeapon(1)
        return w and w:GetWeaponType()==(WeaponType.WEAPON_SPIRIT_SWORD or 13)and w or nil
    end
    local function counts(q)
        return string.format('; arm_calls=%d release_calls=%d input_polls=%d/%d sword_callbacks=%d',q.armCalls or 0,q.releaseCalls or 0,q.armPolls or 0,q.releasePolls or 0,q.factoryCalls or 0)
    end
    function S.attack(p,dir)
        if not REPENTOGON or not ModCallbacks.MC_PRE_PLAYER_UPDATE or not ModCallbacks.MC_POST_FIRE_SWORD then
            diag(p,'native weapon release API unavailable');return
        end
        if S.pending[p.InitSeed]then return S.pending[p.InitSeed]end
        local q={owner=p,dir=Vector(dir.X,dir.Y),stage='arm',start=game:GetFrameCount(),fired=0,knives={}}
        -- Input can be cached before EntityPlayer::Update. Keep the input
        -- request alive across the frame boundary, not just PRE/POST_PLAYER.
        q.inputActive=true;S.pending[p.InitSeed]=q
        diag(p,'native weapon full-tick arm queued')
        return q
    end
    function S.engineWindow(p)
        local q=S.pending[p.InitSeed];return q and q.engineOpen or false
    end
    local function restore(q,finish)
        q.engineOpen=nil
        local p=q.owner
        if not p:Exists()then return end
        if q.savedDelay~=nil then p.FireDelay=q.savedDelay end
        local w=weapon(p)
        if w and q.savedWeaponDelay~=nil then
            w:SetFireDelay(q.savedWeaponDelay)
            -- Do not erase the charge after the arm tick. v168 did exactly
            -- that before a later native weapon pass could observe it.
            if finish then w:SetCharge(0)end
        end
    end
    local function capture(k,p,q,reason)
        local kd=k:GetData()
        if kd.nativeSwordRequest169==q then return end
        kd.nativeSwordRequest169=q
        local priming=kd.nativeSwordPriming169
        if priming then k.Visible=priming.visible;k.EntityCollisionClass=priming.collision end
        kd.nativeSwordPriming169=nil;kd.nativeSwordCandidate168=nil;kd.blockedSwing163=nil
        kd.owner163=p;kd.aux163=true;kd.spin163=true;kd.nativeSword166=true
        kd.until163=game:GetFrameCount()+90
        q.fired=q.fired+1
        local tracked=false
        for _,state in ipairs(S.active)do if state.knife.InitSeed==k.InitSeed then state.start=game:GetFrameCount();tracked=true;break end end
        if not tracked then S.active[#S.active+1]={owner=p,knife=k,start=game:GetFrameCount()}end
        q.captureMessage='native spin observed via '..reason..'; animation='..k:GetSprite():GetAnimation()
        diag(p,q.captureMessage..counts(q))
    end
    local function track(k,p,q,fromCallback)
        if not k or not k:Exists()or k.SubType==4 then return end
        local kd=k:GetData();local spin=method(k,'GetIsSpinAttack')and k:GetIsSpinAttack()
        local entry=q.knives[k.InitSeed]
        if not entry then
            entry={knife=k,previousSpin=spin and not fromCallback and q.stage=='arm'or false};q.knives[k.InitSeed]=entry
        end
        if spin and(fromCallback or not entry.previousSpin)then capture(k,p,q,fromCallback and 'FireSword'or 'weapon entity');entry.previousSpin=true;return end
        entry.previousSpin=spin
        if kd.nativeSword166 then return end -- preserve an older spin already in flight
        if not kd.nativeSwordPriming169 then
            kd.nativeSwordPriming169={owner=p,visible=k.Visible,collision=k.EntityCollisionClass}
        end
        kd.owner163=p;kd.aux163=true;kd.spin163=true;kd.blockedSwing163=true
        kd.until163=game:GetFrameCount()+15
        -- A native ordinary swing may initialize the weapon's persistent main
        -- entity. Keep it alive for the real charge/release, but do not expose
        -- an extra ordinary attack alongside the requested charged spin.
        k.Visible=false;k.EntityCollisionClass=0
    end
    local function scan(q)
        local p=q.owner;local w=weapon(p)
        if w and method(w,'GetMainEntity')then
            local e=w:GetMainEntity();local k=e and e:ToKnife()
            if k then track(k,p,q,false)end
        end
        for _,entry in pairs(q.knives)do
            local k=entry.knife
            if k:Exists()then track(k,p,q,false)end
        end
    end
    local function finish(q)
        q.inputActive=nil;restore(q,true)
        for _,entry in pairs(q.knives)do
            local k=entry.knife
            if k:Exists()and k:GetData().nativeSwordPriming169 then k:Remove()end
        end
        S.pending[q.owner.InitSeed]=nil
    end
    if ModCallbacks.MC_PRE_PLAYER_UPDATE then
        mod:AddPriorityCallback(ModCallbacks.MC_PRE_PLAYER_UPDATE,900000,function(_,p)
            local q=S.pending[p.InitSeed];if not q then return end
            if not valid(p)or not R.has(p,579)or not p:AreControlsEnabled()or game:GetFrameCount()>q.start+12 then finish(q);return end
            local w=weapon(p)
            if not w then diag(p,'native Spirit Sword primary weapon unavailable');finish(q);return end
            if q.savedDelay==nil then q.savedDelay=p.FireDelay;q.savedWeaponDelay=w:GetFireDelay()end
            q.engineOpen=true;q.preFrame=game:GetFrameCount()
            p.FireDelay=0;w:SetFireDelay(0)
            if q.fired==0 then w:SetCharge(math.max(1,w:GetMaxCharge())+1)end
            scan(q)
        end)
    end
    if ModCallbacks.MC_INPUT_ACTION then
        mod:AddCallback(ModCallbacks.MC_INPUT_ACTION,function(_,entity,hook,action)
            local p=entity and entity:ToPlayer();local q=p and S.pending[p.InitSeed]
            if not q or not q.inputActive then return end
            local value
            if action==ButtonAction.ACTION_SHOOTLEFT then value=math.max(0,-q.dir.X)
            elseif action==ButtonAction.ACTION_SHOOTRIGHT then value=math.max(0,q.dir.X)
            elseif action==ButtonAction.ACTION_SHOOTUP then value=math.max(0,-q.dir.Y)
            elseif action==ButtonAction.ACTION_SHOOTDOWN then value=math.max(0,q.dir.Y)
            else return end
            if q.stage=='release'then value=0;q.releasePolls=(q.releasePolls or 0)+1
            else q.armPolls=(q.armPolls or 0)+1 end
            if hook==(InputHook.GET_ACTION_VALUE or 2)then return math.min(1,value)end
            if hook==(InputHook.IS_ACTION_PRESSED or 0)then return value>.01 end
            -- The initial native press is needed to create/arm its main sword.
            if hook==(InputHook.IS_ACTION_TRIGGERED or 1)then return q.stage=='arm'and value>.01 end
        end)
    end
    if ModCallbacks.MC_POST_FIRE_SWORD then
        mod:AddPriorityCallback(ModCallbacks.MC_POST_FIRE_SWORD,-1000000,function(_,k)
            local p=owner(k);local q=p and S.pending[p.InitSeed]
            if q and q.inputActive then q.factoryCalls=(q.factoryCalls or 0)+1;track(k,p,q,true)end
        end)
    end
    if ModCallbacks.MC_POST_WEAPON_FIRE then
        mod:AddCallback(ModCallbacks.MC_POST_WEAPON_FIRE,function(_,w,dir,isShooting,isInterpolated)
            if w:GetWeaponType()~=(WeaponType.WEAPON_SPIRIT_SWORD or 13)then return end
            local e=w:GetOwner();local p=e and e:ToPlayer();local q=p and S.pending[p.InitSeed]
            if not q then return end
            if isShooting then q.armCalls=(q.armCalls or 0)+1 else q.releaseCalls=(q.releaseCalls or 0)+1 end
            scan(q)
        end)
    end
    local function observeKnife(_,k)
        local kd=k:GetData();local p=kd.owner163 or owner(k);local q=p and S.pending[p.InitSeed]
        if q and q.knives[k.InitSeed]then track(k,p,q,false)end
    end
    if ModCallbacks.MC_PRE_KNIFE_UPDATE then mod:AddPriorityCallback(ModCallbacks.MC_PRE_KNIFE_UPDATE,-1000000,observeKnife)end
    mod:AddPriorityCallback(ModCallbacks.MC_POST_KNIFE_UPDATE,-1000000,observeKnife)
    function S.isActive(p)
        for _,state in ipairs(S.active)do
            if state.owner==p and state.knife:Exists()and not state.knife:IsDead()then return true end
        end
        return false
    end
    function S.isHitbox(k)
        if not REPENTOGON then return end
        local parent;local getter=method(k,'GetHitboxParentKnife')
        if getter then parent=getter(k)end
        if not parent and k.Parent and k.Parent.Type==EntityType.ENTITY_KNIFE then parent=k.Parent end
        if not parent and k.SpawnerEntity and k.SpawnerEntity.Type==EntityType.ENTITY_KNIFE then parent=k.SpawnerEntity end
        if parent then
            local pd=parent:GetData()
            if pd.nativeSword166 or pd.nativeSwordPriming169 then return pd.owner163,pd.nativeSwordPriming169~=nil end
        end
        if k.SubType==4 then
            local p=owner(k)
            if p and S.isActive(p)then return p,false end
        end
    end
    mod:AddCallback(ModCallbacks.MC_POST_UPDATE,function()
        -- Weapons/input can update after MC_POST_PLAYER_UPDATE. This is the
        -- boundary for advancing a phase and restoring the firing gate.
        for _,q in pairs(S.pending)do
            if not valid(q.owner)or not R.has(q.owner,579)then finish(q)
            else
                scan(q)
                if q.fired>0 then diag(q.owner,q.captureMessage..counts(q));finish(q)
                elseif game:GetFrameCount()>q.start+12 then
                    diag(q.owner,'native spin timeout at '..q.stage..counts(q));finish(q)
                elseif q.engineOpen and q.preFrame==game:GetFrameCount()then
                    if q.stage=='arm'then q.stage='release' end
                    restore(q,false)
                    diag(q.owner,'native full-tick '..q.stage..counts(q))
                end
            end
        end
        local active={}
        for _,state in ipairs(S.active)do
            local p=state.owner;local k=state.knife;local age=game:GetFrameCount()-state.start
            if k:Exists()then
                if not valid(p)or age>90 then k:Remove()
                elseif age>3 and method(k,'GetIsSwinging')and not k:GetIsSwinging()then k:Remove()
                else active[#active+1]=state end
            end
        end
        S.active=active
    end)
    local function clear()
        for _,q in pairs(S.pending)do finish(q)end
        for _,state in ipairs(S.active)do if state.knife:Exists()then state.knife:Remove()end end
        S.pending={};S.active={}
    end
    mod:AddCallback(ModCallbacks.MC_POST_NEW_ROOM,clear)
    mod:AddCallback(ModCallbacks.MC_POST_GAME_STARTED,clear)
    return S
end
