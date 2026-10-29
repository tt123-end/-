-- v170: selected item stat replacements; Ipecac formula and true Polyphemus piercing.
return function(mod,playerType)
    local R=include("tainted_hunter_rules")
    local items=include("tainted_hunter_compat_items")(mod,playerType,R)
    local C={rules=R,flatDamage=items.flatDamage};local api
    local game=Game();local groups={};local explosions={};local observations={}
    local trisagionHits={};local trisagionProcessing={};local cSectionProcessing={}
    local lightContacts167={}
    local sword=include("tainted_hunter_sword")(mod,playerType,R)
    local function hunter(p)return p and p:Exists()and playerType~=-1 and p:GetPlayerType()==playerType end
    local function own(e,depth)
        if not e or (depth or 0)>6 then return nil end
        local p=e.ToPlayer and e:ToPlayer();if p then return p end
        local f=e.ToFamiliar and e:ToFamiliar();if f and f.Player then return f.Player end
        return own(e.SpawnerEntity,(depth or 0)+1)or own(e.Parent,(depth or 0)+1)
    end
    local function data(p)
        local d=p:GetData();d.hunterCompat163=d.hunterCompat163 or {};return d.hunterCompat163
    end
    local function valid(e)return e and e:Exists()and not e:IsDead()end
    local function hasflag(e,name)return TearFlags[name]and e:HasTearFlags(TearFlags[name])end
    local function enemy(e)
        return e and e:ToNPC()and not e:IsDead()and not e:HasEntityFlags(EntityFlag.FLAG_FRIENDLY)
            and (e:IsVulnerableEnemy()or(e.Type==(EntityType.ENTITY_FIREPLACE or 33)and(e.HitPoints or 1)>0))
    end
    local function sourceParent(e)
        local a=e.SpawnerEntity;local b=e.Parent
        if a and a.Type==EntityType.ENTITY_TEAR then return a end
        if b and b.Type==EntityType.ENTITY_TEAR then return b end
    end
    local function context(p,ctx,fn)
        local d=data(p);local old=d.context;d.context=ctx
        local ok,result=pcall(fn);d.context=old
        if not ok then error(result)end
        return result
    end
    function C.roomKey()
        local level=game:GetLevel();return tostring(level:GetStage())..":"..tostring(level:GetCurrentRoomIndex())
    end
    function C.bind(value)api=value end
    function C.registerGroup(g)groups[g.id]=g end
    local function member(entity,g,primary)
        if not g then return end
        local td=entity:GetData()
        local identity=tostring(entity.InitSeed)..":"..tostring(GetPtrHash and GetPtrHash(entity)or entity.InitSeed)
        g.members165=g.members165 or {}
        if g.members165[identity]then return end
        g.members165[identity]={entity=entity,finished=false}
        td.hunterGroup163=g;td.hunterPrimary163=primary
        td.registeredMember163=true;td.memberIdentity163=identity;td.memberRemoved163=nil
        g.live=g.live+1;g.lastSpawn=game:GetFrameCount()
    end
    local function markHit(g,nativeTear)
        if not g or g.hit then return end
        g.hit=true
        -- Native tears retain their original successful-hit charge behavior;
        -- never add a second charge for that same engine hit. Non-tear primary
        -- attacks gain one charge here. Miss/reset attempts are grouped below.
        if not nativeTear and hunter(g.owner)and R.has(g.owner,373)then g.owner:AddDeadEyeCharge()end
    end
    local function aim(p)
        local v=p:GetShootingInput()
        if R.has(p,394)then
            local d=data(p)
            if Input.IsActionTriggered(ButtonAction.ACTION_DROP,p.ControllerIndex)then d.marked=false end
            if v:Length()>.05 then d.marked=true end
            if d.marked~=false then local a=p:GetAimDirection();if a:Length()>.05 then v=a end end
        end
        if v:Length()>.05 then return v:Normalized()end
        return nil
    end
    local function rng(p,id)return p:GetCollectibleRNG(id)end
    local function chance(p,id,probability)return rng(p,id):RandomFloat()<probability end
    local function clearMainFlags(t)
        for _,name in ipairs({"TEAR_EXPLOSIVE","TEAR_FETUS_BOMBER","TEAR_FETUS_BRIMSTONE","TEAR_FETUS_TECHX","TEAR_FETUS_SWORD",
            "TEAR_SAD_BOMB","TEAR_BUTT_BOMB","TEAR_GLITTER_BOMB","TEAR_SCATTER_BOMB","TEAR_CROSS_BOMB","TEAR_BLOOD_BOMB",
            "TEAR_BRIMSTONE_BOMB","TEAR_GHOST_BOMB","TEAR_GIGA_BOMB","TEAR_GOLDEN_BOMB","TEAR_FAST_BOMB"})do R.clearFlag(t,name)end
    end
    local function procFlags(t,p,td)
        if R.has(p,637)then
            R.clearFlag(t,"TEAR_PUNCH")
            if t.Variant==(TearVariant.FIST or 39)then t:ChangeVariant(TearVariant.NAIL or 13)end
        end
        if R.has(p,398)then
            R.clearFlag(t,"TEAR_GODS_FLESH")
            if t.Variant==16 or t.Variant==17 then t:ChangeVariant(TearVariant.BLUE or 0)end
            if chance(p,398,.5)then R.addFlag(t,"TEAR_GODS_FLESH")end
        end
        if R.has(p,429)then
            R.clearFlag(t,"TEAR_GREED_COIN");R.clearFlag(t,"TEAR_COIN_DROP");td.coin25=true
            if t.Variant==(TearVariant.COIN or 20)then t:ChangeVariant(TearVariant.BLUE or 0)end
        end
        if R.has(p,503)then
            R.clearFlag(t,"TEAR_HORN")
            local luck=(p.Luck or 0)+4*(p.GetTrinketMultiplier and p:GetTrinketMultiplier(139)or 0)
            if chance(p,503,R.hornChance(luck))then R.addFlag(t,"TEAR_HORN")end
        end
    end
    local function configureMain(t,p,ctx)
        local td=t:GetData();local native=t.CollisionDamage
        if not native or native<=0 then native=p.Damage end
        local variant=t.Variant
        local explosiveKnife=R.has(p,52)or R.has(p,149)
        -- These weapons use ordinary ENTITY_TEAR knives, not the weapon's
        -- bomb/charge damage. Retain explicit tooth/razor proc ratios below.
        if explosiveKnife then native=p.Damage end
        if variant==(TearVariant.TOOTH or 2)and R.has(p,150)and native<p.Damage*3 then native=native*3.2 end
        if variant==(TearVariant.RAZOR or 28)and R.has(p,443)and native<p.Damage*3.8 then native=native*4 end
        local multiplier=ctx and ctx.multiplier or (R.blastCombo(p)and 1 or R.has(p,316)and .8 or R.has(p,149)and 1 or 4)
        if ctx and ctx.damage then t.CollisionDamage=ctx.damage else t.CollisionDamage=native*multiplier*R.chocolateFor(p)end
        if R.has(p,149)and not(ctx and(ctx.damage or ctx.noExplosion))then
            t.CollisionDamage=(2*p.Damage+40)*R.chocolateFor(p)
        end
        td.nativeDamage163=native;td.panel163=ctx and ctx.realPanel166 or p.Damage;td.owner163=p
        td.hunterShot155=true;t.CanTriggerStreakEnd=false
        if explosiveKnife then
            clearMainFlags(t)
            if not(ctx and ctx.noExplosion)then
                td.explosionDamage163=R.has(p,149)and(2*p.Damage+40)or(2*p.Damage+30)
            end
            if not R.has(p,531)then
                td.flight164={range=math.max(1,p.TearRange),distance=0,position=Vector(t.Position.X,t.Position.Y)}
                t.FallingSpeed=0;t.FallingAcceleration=0;t.Height=-10
            end
            if t.Variant==(TearVariant.BOBS_HEAD or 4)then t:ChangeVariant(TearVariant.BLUE or 0)end
        end
        procFlags(t,p,td)
        if R.has(p,169)then R.clearFlag(t,"TEAR_PERSISTENT");R.addFlag(t,"TEAR_PIERCING")end
        local fetus=R.has(p,678)and not(ctx and ctx.noFetus)
        local trisagion=R.has(p,533)and not fetus and not explosiveKnife and not(ctx and ctx.noFetus)
        if ctx and ctx.noFetus then
            R.clearFlag(t,"TEAR_LASERSHOT")
            for _,name in ipairs({"TEAR_FETUS","TEAR_FETUS_KNIFE","TEAR_FETUS_BONE","TEAR_FETUS_TECH"})do R.clearFlag(t,name)end
            if t.Variant==(TearVariant.FETUS or 50)then t:ChangeVariant(TearVariant.BLUE or 0)end
        end
        if fetus then
            -- Keep native parent/child ratios intact. Apply the requested
            -- quarter once at actual damage, including independent knife hits.
            td.cSection165=true
            t:ChangeVariant(TearVariant.FETUS or 50)
            clearMainFlags(t)
            R.addFlag(t,"TEAR_FETUS");R.addFlag(t,"TEAR_FETUS_KNIFE")
            R.addFlag(t,"TEAR_HOMING");R.addFlag(t,"TEAR_SPECTRAL")
            td.explosionDamage163=nil
        elseif trisagion then
            R.addFlag(t,"TEAR_LASERSHOT")
            -- Preserve the native carrier/beam proportions. The exact light
            -- collision supplies the actual-hit override, not this field.
            td.trisagion164=true
            td.nativeTris166=false
            td.lightMultiplier164=4*R.chocolateFor(p)
            t.CollisionDamage=native
            trisagionHits[t.InitSeed]=t
        else
            if explosiveKnife then R.clearFlag(t,"TEAR_LASERSHOT")end
            if R.has(p,169)then
                R.clearFlag(t,"TEAR_PERSISTENT");R.addFlag(t,"TEAR_PIERCING")
            else R.addFlag(t,"TEAR_PERSISTENT")end
            if R.has(p,237)then t.Color=Color(.16,.16,.19,1,0,0,0);t:GetSprite().Color=t.Color end
            api.applyKnife(t)
        end
        if t.Size>0 and not td.size163 then t:SetSize(t.Size*1.5,t.SizeMulti,8);td.size163=true end
        td.nativeVisual163=fetus or trisagion
    end
    function C.onFireTear(t)
        t=t and t:ToTear();if not t then return end
        local td=t:GetData()
        local p=td.owner163 or own(t)
        if hunter(p)then
            if td.originalStreak164==nil then td.originalStreak164=t.CanTriggerStreakEnd end
            -- Also covers rejected/auxiliary/familiar tears. In v163 a rejected
            -- tear was removed with this still true, causing random native
            -- Dead Eye resets even when the real volley had hit.
            t.CanTriggerStreakEnd=false
            if R.has(p,169)then R.clearFlag(t,"TEAR_PERSISTENT");R.addFlag(t,"TEAR_PIERCING")end
        end
        if td.configured163 then if td.hunterGroup163 then member(t,td.hunterGroup163,false)end;return end
        if not hunter(p)or p:IsDead()then return end
        local d=data(p);local ctx=d.context;local parent=sourceParent(t)
        local inherited=(parent and parent:GetData().hunterGroup163)or(td.lineage163 and td.hunterGroup163)
        if inherited then
            td.configured163=true;td.owner163=p;t.CanTriggerStreakEnd=false
            td.coin25=parent and parent:GetData().coin25 or td.coin25
            td.trisagion164=parent and parent:GetData().trisagion164 or td.trisagion164
            td.lightMultiplier164=parent and parent:GetData().lightMultiplier164 or td.lightMultiplier164
            td.nativeTris166=parent and parent:GetData().nativeTris166 or td.nativeTris166
            td.cSection165=parent and parent:GetData().cSection165 or td.cSection165
            if td.trisagion164 then trisagionHits[t.InitSeed]=t end
            member(t,inherited,false)
            if t.Size>0 and not td.size163 then t:SetSize(t.Size*1.5,t.SizeMulti,8);td.size163=true end
            if R.has(p,169)then R.clearFlag(t,"TEAR_PERSISTENT");R.addFlag(t,"TEAR_PIERCING")end
            if not hasflag(t,"TEAR_FETUS")and not hasflag(t,"TEAR_LASERSHOT")then api.applyKnife(t)end
            return -- Native child damage already comes from the modified parent.
        end
        if ctx and ctx.kind=="aux"then
            td.configured163=true;td.owner163=p;td.aux163=true;t.CanTriggerStreakEnd=false
            if ctx.damage then t.CollisionDamage=ctx.damage end
            return
        end
        local spawner=t.SpawnerEntity
        if not ctx and spawner and spawner.Type~=EntityType.ENTITY_PLAYER and spawner.Type~=EntityType.ENTITY_FAMILIAR and spawner.Type~=EntityType.ENTITY_TEAR then
            -- Friendly NPCs, wisps/effects and unrelated independent attacks
            -- are not new player rounds merely because their owner is a player.
            td.configured163=true;td.aux163=true;t.CanTriggerStreakEnd=false;return
        end
        local familiar=t.SpawnerEntity and t.SpawnerEntity:ToFamiliar()
        if familiar then
            td.configured163=true;t.CanTriggerStreakEnd=false
            if R.inherits(familiar)then
                td.owner163=p;td.inherited163=true
                t.CollisionDamage=t.CollisionDamage*4;t.CanTriggerStreakEnd=false
                if R.has(p,678)and(t.Variant==(TearVariant.FETUS or 50)or hasflag(t,"TEAR_FETUS"))then td.cSection165=true end
                procFlags(t,p,td)
                if not hasflag(t,"TEAR_FETUS")and not hasflag(t,"TEAR_LASERSHOT")then api.applyKnife(t)end
            end
            if FamiliarVariant.MULTIDIMENSIONAL_BABY and familiar.Variant==FamiliarVariant.MULTIDIMENSIONAL_BABY and R.has(p,429)then td.owner163=p;td.coin25=true end
            return
        end
        local active=items.activeShot(p)
        local activeOutput=active and(active~=352 or t.CollisionDamage>=p.Damage*5)
        if not ctx and(activeOutput or items.isReaction(p)or hasflag(t,"TEAR_ORBIT_ADVANCED"))then
            td.configured163=true;td.aux163=true;td.owner163=p
            if active==352 then t.CollisionDamage=t.CollisionDamage*4 end
            t.CanTriggerStreakEnd=false
            return
        end
        if R.scripted(p)and not ctx then
            -- A native charged release must not duplicate our immediate attack.
            data(p).suppressed165=(data(p).suppressed165 or 0)+1
            td.configured163=true;td.suppressed163=true;t:Remove();return
        end
        td.configured163=true
        if R.has(p,329)and not R.scripted(p)and not ctx then
            td.owner163=p;td.ludo163=true;t.CollisionDamage=t.CollisionDamage*4
            t.CanTriggerStreakEnd=false;api.applyKnife(t);return
        end
        local g=ctx and ctx.group
        if not g then
            local b=api.state(p);b.aim163=t.Velocity:Normalized()
            g=api.beginAttack(p)
            if not g then
                if td.originalStreak164 then td.suppressed163=true;t:Remove();return end
                -- Delayed burst/extra effects stay with the original group and
                -- keep their native relative damage. They never refill ammo.
                g=b.group;td.owner163=p;t.CanTriggerStreakEnd=false
                if g then member(t,g,false)end
                api.applyKnife(t);return
            end
        end
        configureMain(t,p,ctx)
        member(t,g,true)
        if R.has(p,395)and not(ctx and ctx.noRing)then C.attachRing(t,p,g)end
    end
    local function fire(p,position,dir,g,opts)
        opts=opts or {};opts.group=g;opts.kind=opts.kind or "primary"
        return context(p,opts,function()
            local effects=p:GetEffects();local chemical=effects:GetCollectibleEffectNum(154)
            local swap=chemical>0 and items.token and items.token>0
            local milk=effects:GetCollectibleEffectNum(69)
            local swapMilk=milk>0 and items.chocolate and items.chocolate>0
            if swap then effects:RemoveCollectibleEffect(154,chemical);effects:AddCollectibleEffect(items.token,false,chemical)end
            if swapMilk then effects:RemoveCollectibleEffect(69,milk);effects:AddCollectibleEffect(items.chocolate,false,milk)end
            -- Leave the player sheet and native tear base untouched. v167
            -- modifies the actual light hit via REPENTOGON, not cached values.
            local ok,t=pcall(p.FireTear,p,position,dir*math.max(.1,p.ShotSpeed)*10,true,false,false,p,1)
            if swapMilk then effects:RemoveCollectibleEffect(items.chocolate,milk);effects:AddCollectibleEffect(69,false,milk)end
            if swap then effects:RemoveCollectibleEffect(items.token,chemical);effects:AddCollectibleEffect(154,false,chemical)end
            if not ok then error(t)end
            if not t:GetData().configured163 then C.onFireTear(t)end
            return t
        end)
    end
    local function technology(p,position,dir,g)
        return context(p,{kind="technology",group=g},function()
            local laser=p:FireTechLaser(position,(LaserOffset and LaserOffset.LASER_TECH1_OFFSET)or 0,dir,false,true,p,4)
            local ld=laser:GetData();ld.owner163=p;ld.tech168=true;ld.seen163=true
            ld.techDamage168=4*p.Damage*R.chocolateFor(p)
            laser.CollisionDamage=ld.techDamage168;member(laser,g,true)
            return laser
        end)
    end
    function C.attachRing(t,p,g)
        local laser
        if R.brim(p)then
            laser=Isaac.Spawn(EntityType.ENTITY_LASER,LaserVariant.BRIM_TECH or 9,2,t.Position,Vector(0,0),p):ToLaser()
            laser.Radius=40;laser.CollisionDamage=p.Damage
        else laser=p:FireTechXLaser(t.Position,Vector(0,0),40,p,1)end
        laser.Parent=t;laser.DisableFollowParent=true;laser:SetTimeout(3)
        local ld=laser:GetData();ld.followTear163=t;ld.owner163=p
        ld.aux163=nil
        member(laser,g,false)
    end
    local function brim(p,dir,g)
        local laser=p:FireBrimstone(dir,p,.5)
        local duration=laser.Timeout and laser.Timeout>0 and laser.Timeout or 20
        local ld=laser:GetData();ld.owner163=p;ld.until163=game:GetFrameCount()+duration
        ld.aux163=nil
        laser:SetTimeout(duration);member(laser,g,false)
    end
    function C.onAttack(p,g)
        if not R.has(p,579)then return end
        sword.attack(p,api.state(p).aim163 or Vector(1,0))
    end
    local function shotAngles(p)
        local count=R.has(p,153)and 4 or R.has(p,2)and 3 or 1
        count=count+R.count(p,245)
        local out={}
        local cursed=R.has(p,316)
        local lung=R.has(p,229)and not cursed
        local n=cursed and 5*count or lung and 14*count or count
        for i=1,n do
            local a=lung and (rng(p,229):RandomFloat()-.5)*65 or (i-(n+1)/2)*(cursed and 3 or 9)
            if R.has(p,358)then out[#out+1]=a-45;out[#out+1]=a+45 else out[#out+1]=a end
        end
        if p:HasPlayerForm(PlayerForm.PLAYERFORM_BABY)then out[#out+1]=-45;out[#out+1]=45 end
        if p:HasPlayerForm(PlayerForm.PLAYERFORM_BOOK_WORM)and chance(p,245,.25)then out[#out+1]=5 end
        if R.has(p,55)and chance(p,55,math.min(1,.5+(p.Luck or 0)*.1))then out[#out+1]=180 end
        if R.has(p,87)and chance(p,87,math.min(1,.25+math.max(0,p.Luck or 0)*.05))then
            out[#out+1]=90;out[#out+1]=180;out[#out+1]=270
        end
        if R.has(p,558)and chance(p,558,.4)then for i=1,1+rng(p,558):RandomInt(3)do out[#out+1]=rng(p,558):RandomFloat()*360 end end
        return out
    end
    local function shoot(p,dir)
        local b=api.state(p);b.aim163=dir
        local g=api.beginAttack(p);if not g then return end
        C.onAttack(p,g)
        for _,angle in ipairs(shotAngles(p))do
            if R.technology(p)then technology(p,p.Position,dir:Rotated(angle),g)
            else fire(p,p.Position,dir:Rotated(angle),g)end
        end
        local d=data(p)
        if d.kidneyPending163 then
            d.kidneyPending163=nil
            for i=1,13 do fire(p,p.Position,dir:Rotated((rng(p,440):RandomFloat()-.5)*70),g)end
            local stone=fire(p,p.Position,dir,g);stone:ChangeVariant(TearVariant.STONE or 22)
        end
        if R.brim(p)and not R.has(p,395)then brim(p,dir,g)end
        if R.has(p,579)and p:HasFullHearts()then
            context(p,{kind="aux",damage=3*p.Damage+3.5},function()
                local t=p:FireTear(p.Position,dir*p.ShotSpeed*10,false,false,false,p,1)
                t:ChangeVariant(TearVariant.SWORD_BEAM or 47);t.CollisionDamage=3*p.Damage+3.5
                R.addFlag(t,"TEAR_PIERCING")
            end)
        end
    end
    function C.updatePlayer(p)
        if not hunter(p)or p:IsDead()then return end
        items.update(p)
        local d=data(p);local b=api.state(p)
        if sword.engineWindow(p)then p.FireDelay=0;return end
        if R.has(p,440)then
            d.kidneyNext163=d.kidneyNext163 or game:GetFrameCount()+750
            if game:GetFrameCount()>=d.kidneyNext163 then d.kidneyPending163=true;d.kidneyNext163=game:GetFrameCount()+750 end
        else d.kidneyNext163=nil;d.kidneyPending163=nil end
        if R.scripted(p)and (p:CanShoot()or R.has(p,440))and p:AreControlsEnabled()and p:IsExtraAnimationFinished()and not p:IsCoopGhost()then
            -- Native held-input and secondary attacks remain visible. Native
            -- primary fire is gated by FireDelay, never by a fake key release.
            p.FireDelay=1000000;d.locked163=true
            local direction=aim(p)
            if direction and not api.reloading(p)and game:GetFrameCount()>=(b.nextShotFrame or 0)then shoot(p,direction)end
        elseif d.locked163 then
            d.locked163=nil;p.FireDelay=api.reloading(p)and math.max(0,b.untilFrame-game:GetFrameCount())or 0
        end
    end
    local function add(name,fn,filter)
        if ModCallbacks[name]then mod:AddCallback(ModCallbacks[name],fn,filter)end
    end
    local function explode(t,td)
        if not td.explosionDamage163 or td.exploded163 then return end
        td.exploded163=true
        explosions[#explosions+1]={position=t.Position,damage=td.explosionDamage163,owner=td.owner163,group=td.hunterGroup163,room=C.roomKey()}
    end
    local function poopContact(t,td)
        local room=game:GetRoom()
        if not room.GetGridEntityFromPos then return end
        local velocity=t.Velocity;local forward=velocity:Length()>.01 and velocity:Normalized()*12 or Vector(0,0)
        for _,position in ipairs({t.Position,t.Position+forward,t.Position-forward})do
            local grid=room:GetGridEntityFromPos(position)
            if grid and grid:GetType()==(GridEntityType and GridEntityType.GRID_POOP or 14)and (grid.State or 0)<1000 then
                td.poopCandidate165={grid=grid,position=grid.Position or position,state=grid.State or 0}
                if t:CollidesWithGrid()then markHit(td.hunterGroup163,true)end
            end
        end
        local candidate=td.poopCandidate165
        if candidate and (candidate.position-t.Position):Length()<=28+(t.Size or 0)then
            if t:CollidesWithGrid()or(candidate.grid.State or 0)>candidate.state then markHit(td.hunterGroup163,true)end
        end
    end
    add("MC_POST_TEAR_INIT",function(_,t)
        if not api then return end
        local parent=sourceParent(t)
        local g=parent and parent:GetData().hunterGroup163
        if g then t:GetData().lineage163=true;t:GetData().owner163=g.owner;member(t,g,false)end
    end)
    add("MC_PRE_TEAR_COLLISION",function(_,t,npc)
        local td=t:GetData()
        if hunter(td.owner163 or own(t))then t.CanTriggerStreakEnd=false end
        if npc:ToNPC()then td.directTarget163=npc.InitSeed;td.directFrame163=game:GetFrameCount()end
        -- A contact with a vulnerable enemy counts as a hit even when a target
        -- restores HP, armor rounds damage, or another callback rewrites HP.
        if enemy(npc)then markHit(td.hunterGroup163,true)end
        if td.explosionDamage163 and enemy(npc)then
            explode(t,td);if not R.has(td.owner163 or own(t),169)then td.removeAfterHit163=true end
        end
    end)
    add("MC_POST_TEAR_UPDATE",function(_,t)
        if not api then return end
        local td=t:GetData();local p=own(t)
        if hunter(td.owner163 or p)then
            t.CanTriggerStreakEnd=false
            if R.has(td.owner163 or p,169)then R.clearFlag(t,"TEAR_PERSISTENT");R.addFlag(t,"TEAR_PIERCING")end
        end
        if not td.configured163 and hunter(p)then
            local parent=sourceParent(t)
            if parent and parent:GetData().hunterGroup163 then C.onFireTear(t)end
        end
        if td.explosionDamage163 and t:CollidesWithGrid()then explode(t,td);td.removeAfterHit163=true end
        poopContact(t,td)
        if td.removeAfterHit163 then t:Remove()end
        if t:IsDead()then
            -- Knife sprites have no tear-death animation. Let native death
            -- effects/splits finish, then remove instead of replaying Idle.
            td.deadFrame165=td.deadFrame165 or game:GetFrameCount()
            if game:GetFrameCount()>=td.deadFrame165+2 then t:Remove()end
        end
        local flight=td.flight164
        if flight and not td.removeAfterHit163 then
            local delta=(t.Position-flight.position):Length()
            -- Continuum/teleports must not spend an entire room's width.
            flight.distance=flight.distance+math.min(delta,math.max(1,t.Velocity:Length()*2))
            flight.position=Vector(t.Position.X,t.Position.Y)
            t.FallingSpeed=0;t.FallingAcceleration=0;t.Height=-10
            if flight.distance>=flight.range then t:Remove()end
        end
    end)
    local function lightSource(laser)
        laser=laser and laser:ToLaser();if not laser then return end
        local ld=laser:GetData()
        if ld.trisagion164 then return ld.owner163 end
        if ld.aux163 or ld.followTear163 or ld.until163 then return end
        local parent=sourceParent(laser)
        local lightVariant=laser.Variant==(LaserVariant.LIGHT_BEAM or 5)
        if not lightVariant and not(parent and parent:GetData().trisagion164)then return end
        if not lightVariant and(laser.Variant==1 or laser.Variant==2 or laser.Variant==6 or laser.Variant==9 or laser.Variant==10 or laser.Variant>=11)then return end
        local p=own(laser);if not hunter(p)then return end
        if not(parent and parent:GetData().trisagion164)then
            local nearest=math.huge
            for _,tear in pairs(trisagionHits)do
                local td=tear:GetData()
                if tear:Exists()and td.owner163==p then
                    local distance=(tear.Position-laser.Position):Length()
                    if distance<nearest and distance<=80 then parent=tear;nearest=distance end
                end
            end
        end
        if parent and parent:GetData().trisagion164 then
            local td=parent:GetData();ld.owner163=p;ld.trisagion164=true;ld.nativeTris166=td.nativeTris166;ld.lightMultiplier164=td.lightMultiplier164;ld.coin25=td.coin25
            ld.aux163=false;ld.seen163=true;member(laser,td.hunterGroup163,false)
            return p
        end
    end
    -- REPENTOGON 1.0.12 already provides both collision callbacks. Source
    -- may only be the player, with no DAMAGE_LASER bit. Scope the precise laser
    -- to its collider until DoDamage's post callback, then discard the context.
    if ModCallbacks.MC_PRE_LASER_COLLISION then
    mod:AddPriorityCallback(ModCallbacks.MC_PRE_LASER_COLLISION,1000000,function(_,laser,collider)
        if not REPENTOGON or not api or not collider:ToNPC()then return end
        lightContacts167[collider.InitSeed]=nil
        local ld=laser:GetData();local p=lightSource(laser)or(ld.tech168 and ld.owner163)
        if p and(ld.trisagion164 or ld.tech168)then
            lightContacts167[collider.InitSeed]={laser=laser,owner=p,frame=game:GetFrameCount()}
        end
    end)
    end
    add("MC_POST_LASER_COLLISION",function(_,laser,collider)
        local contact=lightContacts167[collider.InitSeed]
        if contact and contact.laser.InitSeed==laser.InitSeed then lightContacts167[collider.InitSeed]=nil end
    end)
    add("MC_POST_FIRE_TECH_LASER",function(_,laser)
        if not api then return end
        local p=own(laser);if not hunter(p)then return end
        local ctx=data(p).context;local ld=laser:GetData()
        if ctx and ctx.kind=="technology"then
            ld.owner163=p;ld.tech168=true;ld.seen163=true;ld.techDamage168=4*p.Damage*R.chocolateFor(p)
            laser.CollisionDamage=ld.techDamage168;member(laser,ctx.group,true)
        elseif R.technology(p)and laser.OneHit and not sourceParent(laser)
            and laser.SpawnerEntity and laser.SpawnerEntity.Type==EntityType.ENTITY_PLAYER
            and not items.activeShot(p)and not items.isReaction(p)then
            ld.suppressed163=true;laser:Remove()
        end
    end)
    add("MC_POST_LASER_UPDATE",function(_,laser)
        if not api then return end
        lightSource(laser)
        local ld=laser:GetData()
        if ld.followTear163 then
            if valid(ld.followTear163)then laser.Position=ld.followTear163.Position;laser:SetTimeout(3)else laser:Remove()end
        elseif ld.until163 then laser:SetTimeout(math.max(1,ld.until163-game:GetFrameCount()));if game:GetFrameCount()>=ld.until163 then laser:Remove()end
        elseif not ld.seen163 then
            ld.seen163=true;local p=own(laser);if not hunter(p)then return end
            local parent=sourceParent(laser)
            if R.has(p,329)and R.scripted(p)and laser.SubType==1 then
                laser:Remove()
            elseif R.has(p,329)and laser.SubType==1 then
                ld.owner163=p;ld.ludo163=true;laser.CollisionDamage=laser.CollisionDamage*4
            elseif parent and parent:GetData().hunterGroup163 then
                ld.owner163=p;member(laser,parent:GetData().hunterGroup163,false)
            elseif R.has(p,68)and not R.scripted(p)and laser.SpawnerEntity and laser.SpawnerEntity.Type==EntityType.ENTITY_PLAYER and laser.CollisionDamage>=p.Damage*.5 and laser.SubType==0 then
                local g=api.beginAttack(p)
                if g then laser.CollisionDamage=laser.CollisionDamage*4;ld.owner163=p;member(laser,g,true)
                else ld.suppressed163=true;laser:Remove()end
            else
                local familiar=laser.SpawnerEntity and laser.SpawnerEntity:ToFamiliar()
                if familiar and R.inherits(familiar)then laser.CollisionDamage=laser.CollisionDamage*4;ld.owner163=p;ld.aux163=true end
            end
        end
    end)
    add("MC_POST_LASER_INIT",function(_,laser)
        if api and lightSource(laser)then return end
        local p=own(laser)
        if hunter(p)and(items.activeShot(p)or items.isReaction(p))then
            local ld=laser:GetData();ld.aux163=true;ld.seen163=true;ld.owner163=p
        end
    end)
    add("MC_POST_KNIFE_UPDATE",function(_,knife)
        if not api then return end
        local nativeOwner,priming=sword.isHitbox(knife)
        if nativeOwner then
            local kd=knife:GetData();kd.owner163=nativeOwner;kd.aux163=true;kd.nativeSwordHitbox166=true;kd.blockedSwing163=priming or nil
            return -- The original swing's native hitbox is not an extra weapon.
        end
        local kd=knife:GetData();local p=own(knife)
        local parent=sourceParent(knife)
        if not parent and knife.SpawnerEntity and knife.SpawnerEntity.Type~=EntityType.ENTITY_PLAYER then return end
        if parent and parent:GetData().hunterGroup163 then
            kd.owner163=own(parent);kd.cSection165=parent:GetData().cSection165;member(knife,parent:GetData().hunterGroup163,false)
        elseif kd.spin163 then
            if not valid(p)or game:GetFrameCount()>=kd.until163 then knife:Remove()
            elseif not kd.nativeSword166 then knife.Position=p.Position end
        elseif hunter(p)and R.scripted(p)and (knife.Variant==0 or knife.Variant==3 or knife.Variant==10 or knife.Variant==11)then
            local parent=knife.Parent
            if not parent or parent.Type~=EntityType.ENTITY_TEAR then knife:Remove()end
        elseif hunter(p)and knife.Variant<=3 then
            local sprite=knife:GetSprite();local animation=sprite:GetAnimation();local f=sprite:GetFrame()
            local attacking=animation:find("Swing")or animation:find("Attack")or animation=="Spin"
            if attacking and f==0 and(not kd.swinging163 or(kd.knifeFrame163 or 0)>0 or animation~=kd.knifeAnim163)then
                local g=api.beginAttack(p)
                kd.blockedSwing163=not g
                if g then kd.owner163=p;member(knife,g,true)end
            end
            kd.swinging163=attacking;kd.knifeFrame163=f;kd.knifeAnim163=animation
        end
    end)
    add("MC_POST_EFFECT_UPDATE",function(_,effect)
        if not api or effect.Variant~=(EffectVariant.ROCKET or 31)then return end
        local ed=effect:GetData();local p=own(effect)
        local source=effect.SpawnerEntity
        if source and(source.Type==EntityType.ENTITY_FAMILIAR or(source.Type>=10 and source.Type<1000))then return end
        if not ed.rocket163 and hunter(p)and R.isEpic(p)then
            ed.rocket163=true;ed.owner163=p;ed.room163=C.roomKey()
            local g=api.beginAttack(p);if g then member(effect,g,true)end
        end
    end)
    add("MC_POST_ENTITY_REMOVE",function(_,entity)
        if not api then return end
        local td=entity:GetData();local frame=game:GetFrameCount()
        if entity.Type==EntityType.ENTITY_TEAR and hunter(td.owner163 or own(entity))then
            local tear=entity:ToTear()
            if tear then tear.CanTriggerStreakEnd=false end
            trisagionHits[entity.InitSeed]=nil
        end
        if td.suppressed163 then return end
        if entity.Type==EntityType.ENTITY_TEAR then
            local tear=entity:ToTear();if tear then poopContact(tear,td)end
        end
        if td.explosionDamage163 and not td.exploded163 and C.roomKey()==(td.hunterGroup163 and td.hunterGroup163.room)then
            if entity:CollidesWithGrid()or game:GetRoom():GetGridCollisionAtPos(entity.Position)~=0 then explode(entity,td)end
        end
        if td.rocket163 and td.hunterGroup163 and td.room163==C.roomKey()and game:GetRoom():GetFrameCount()>0 then
            local p=td.owner163
            if hunter(p)then
                for i=1,3 do
                    fire(p,entity.Position,Vector.FromAngle(rng(p,168):RandomFloat()*360),td.hunterGroup163,
                        {damage=p.Damage*4,noExplosion=true,noFetus=true})
                end
            end
        end
        local g=td.hunterGroup163
        if g and td.registeredMember163 and not td.memberRemoved163 then g.live=math.max(0,g.live-1);g.lastRemove=frame;td.memberRemoved163=true end
    end)
    local auraProcessing={}
    -- Transform damage before default-priority test dummies/observers can
    -- cancel the event. LATE meant they could see only the unscaled hit.
    mod:AddPriorityCallback(ModCallbacks.MC_ENTITY_TAKE_DMG,-9000,function(_,npc,amount,flags,source,countdown,extraSource)
        if not api or not npc:ToNPC()or auraProcessing[npc.InitSeed]then return end
        local entity=extraSource and extraSource.Entity or source and source.Entity
        local contact=lightContacts167[npc.InitSeed]
        -- Consume once, even if a later callback cancels the damage. Check the
        -- owner so an unrelated nested damage event cannot borrow this laser.
        if contact and contact.frame==game:GetFrameCount()then
            lightContacts167[npc.InitSeed]=nil
            if entity and (entity.InitSeed==contact.laser.InitSeed or own(entity)==contact.owner)then entity=contact.laser end
        end
        if not entity then return end
        if entity.Type==EntityType.ENTITY_LASER then lightSource(entity)end
        local td=entity:GetData();local p=td.owner163 or own(entity)
        if not hunter(p)then return end
        local parent=sourceParent(entity)
        if parent and parent:GetData().cSection165 then td.cSection165=true end
        if not REPENTOGON and entity.Type==EntityType.ENTITY_PLAYER and R.has(p,533)and flags&(DamageFlag.DAMAGE_LASER or 0)~=0 then
            local nearest=math.huge;local carrier
            for _,candidate in pairs(trisagionHits)do
                if candidate:Exists()and candidate:GetData().owner163==p then
                    local distance=(candidate.Position-npc.Position):Length()
                    if distance<nearest and distance<=80 then carrier=candidate;nearest=distance end
                end
            end
            if carrier then td=carrier:GetData()end
        end
        if td.blockedSwing163 then return false end
        local tear=entity:ToTear()
        local pulse=math.abs(amount-2)<.001 or math.abs(amount-4)<.001
        local direct=td.directFrame163==game:GetFrameCount()and td.directTarget163==npc.InitSeed
        local aura=tear and R.has(p,331)and hasflag(tear,"TEAR_GLOW")and pulse and not direct
            and flags&((DamageFlag.DAMAGE_POISON_BURN or 0)|(DamageFlag.DAMAGE_LASER or 0))==0
        if enemy(npc)and amount>0 and flags&(DamageFlag.DAMAGE_FAKE or 0)==0 and not td.aux163 and not td.ludo163 then
            markHit(td.hunterGroup163,entity.Type==EntityType.ENTITY_TEAR or td.trisagion164)
        end
        if td.tech168 and not td.aux163 and flags&((DamageFlag.DAMAGE_POISON_BURN or 0)|(DamageFlag.DAMAGE_FIRE or 0)|(DamageFlag.DAMAGE_EXPLOSION or 0))==0 then
            local applied=td.techDamage168 or 4*p.Damage
            data(p).lastTech168={incoming=amount,applied=applied,frame=game:GetFrameCount()}
            if REPENTOGON then return {Damage=applied}end
        end
        if td.cSection165 and not td.aux163 and not aura and not cSectionProcessing[npc.InitSeed]
            and flags&((DamageFlag.DAMAGE_POISON_BURN or 0)|(DamageFlag.DAMAGE_FIRE or 0))==0 then
            local key=npc.InitSeed;cSectionProcessing[key]=true
            local hp=npc.HitPoints
            data(p).lastCSection165={incoming=amount,applied=amount*.25,frame=game:GetFrameCount()}
            local ok,err=pcall(npc.TakeDamage,npc,amount*.25,flags,source,countdown)
            cSectionProcessing[key]=nil
            if not ok then error(err)end
            if td.coin25 then observations[#observations+1]={npc=npc,hp=hp,group=td.hunterGroup163,position=npc.Position,owner=p,coin=true,nativeTear=true,room=C.roomKey()}end
            return false
        elseif td.cSection165 and cSectionProcessing[npc.InitSeed]then return end
        if td.trisagion164 and not td.nativeTris166 and not aura and not trisagionProcessing[npc.InitSeed]
            and flags&((DamageFlag.DAMAGE_POISON_BURN or 0)|(DamageFlag.DAMAGE_EXPLOSION or 0)|(DamageFlag.DAMAGE_FIRE or 0))==0 then
            if REPENTOGON then
                local applied=amount*(td.lightMultiplier164 or 4)
                data(p).lastLight165={incoming=amount,applied=applied,source=entity.Type,variant=entity.Variant,frame=game:GetFrameCount()}
                if td.coin25 then observations[#observations+1]={npc=npc,hp=npc.HitPoints,group=td.hunterGroup163,position=npc.Position,owner=p,coin=true,nativeTear=true,room=C.roomKey()}end
                return {Damage=applied}
            end
            local key=npc.InitSeed;trisagionProcessing[key]=true
            local hp=npc.HitPoints
            data(p).lastLight165={incoming=amount,applied=amount*(td.lightMultiplier164 or 4),source=entity.Type,variant=entity.Variant,frame=game:GetFrameCount()}
            local ok,err=pcall(npc.TakeDamage,npc,amount*(td.lightMultiplier164 or 4),flags,source,countdown)
            trisagionProcessing[key]=nil
            if not ok then error(err)end
            if td.coin25 then observations[#observations+1]={npc=npc,hp=hp,group=td.hunterGroup163,position=npc.Position,owner=p,coin=true,nativeTear=true,room=C.roomKey()}end
            return false
        elseif td.trisagion164 and not td.nativeTris166 and trisagionProcessing[npc.InitSeed]then return end
        -- Match native fixed aura pulses, not physical tear hits or DOT.
        -- PRE_TEAR_COLLISION identifies real contacts even with low damage,
        -- armor or distance modifiers; never multiply the body hit by5.
        if aura then
            auraProcessing[npc.InitSeed]=true
            local ok,err=pcall(npc.TakeDamage,npc,amount*5,flags,source,countdown)
            auraProcessing[npc.InitSeed]=nil
            if not ok then error(err)end
            return false
        end
        if td.ludo163 then
            local b=api.state(p)
            if api.reloading(p)and b.lastVolleyFrame~=game:GetFrameCount()then return false end
            local g=api.beginAttack(p)
            if not g then return false end
            td.hunterGroup163=g
            if enemy(npc)and amount>0 and flags&(DamageFlag.DAMAGE_FAKE or 0)==0 then
                markHit(g,tear~=nil)
            end
        end
        if (td.hunterGroup163 or td.coin25)and not td.aux163 then
            observations[#observations+1]={npc=npc,hp=npc.HitPoints,group=td.hunterGroup163,
                position=npc.Position,owner=p,coin=td.coin25,nativeTear=tear~=nil,frame=game:GetFrameCount(),room=C.roomKey()}
        end
    end)
    add("MC_POST_UPDATE",function()
        if not api then return end
        local frame=game:GetFrameCount()
        local completed=observations;observations={}
        for _,o in ipairs(completed)do
            if o.room==C.roomKey()then
                if not o.npc:Exists()or o.npc.HitPoints<o.hp or o.npc:IsDead()then
                    markHit(o.group,o.nativeTear)
                    if o.coin and hunter(o.owner)and chance(o.owner,429,.25)then
                        Isaac.Spawn(EntityType.ENTITY_PICKUP,PickupVariant.PICKUP_COIN,CoinSubType.COIN_PENNY,o.position,Vector(0,0),o.owner)
                    end
                end
            end
        end
        local queued=explosions;explosions={}
        for _,e in ipairs(queued)do
            if e.room==C.roomKey()and valid(e.owner)then
                local source=Isaac.Spawn(EntityType.ENTITY_EFFECT,EffectVariant.POOF01 or 15,0,e.position,Vector(0,0),e.owner)
                source.Visible=false;source:GetData().hunterGroup163=e.group;source:GetData().owner163=e.owner
                game:BombExplosionEffects(e.position,e.damage,TearFlags.TEAR_NORMAL,Color(1,1,1,1),source,1,true,true,DamageFlag.DAMAGE_EXPLOSION)
            end
        end
        for id,g in pairs(groups)do
            -- Native Kill/Die and missed removal callbacks must not leave an
            -- all-miss volley permanently waiting for live to reach zero.
            if g.members165 then
                local live=0
                for _,m in pairs(g.members165)do
                    local expiredLaser=m.entity.Type==EntityType.ENTITY_LASER and m.entity.Timeout and m.entity.Timeout<=0
                    if m.entity:Exists()and not m.entity:IsDead()and not expiredLaser then live=live+1
                    elseif not m.finished then m.finished=true;g.lastFinish165=frame end
                end
                g.live=live
            end
            if g.room~=C.roomKey()then groups[id]=nil
            elseif g.live==0 and frame>=math.max(g.lastRemove or 0,g.lastSpawn or g.frame,g.lastFinish165 or 0)+2 then
                if not g.hit and hunter(g.owner)and R.has(g.owner,373)then
                    local state=data(g.owner);state.missRequests165=(state.missRequests165 or 0)+1
                    g.owner:ClearDeadEyeCharge()
                end
                groups[id]=nil
            end
        end
    end)
    add("MC_POST_NEW_ROOM",function()
        groups={};observations={};explosions={};trisagionHits={};lightContacts167={}
        for i=0,game:GetNumPlayers()-1 do
            local p=Isaac.GetPlayer(i);if hunter(p)then
                local d=data(p);items.clearRoom(p)
                if d.rewind163 then items.restore(p,d.rewind163);d.rewind163=nil end
                d.roomEntry163=items.capture(p)
                local b=api and api.state(p);if b then b.group=nil;b.lastVolleyFrame=nil end
            end
        end
    end)
    add("MC_POST_GAME_STARTED",function()
        groups={};observations={};explosions={};trisagionHits={};lightContacts167={}
        local loaded="[Hunter v1.72] loaded; REPENTOGON="..tostring(not not REPENTOGON)
        if Isaac.DebugString then Isaac.DebugString(loaded)end
        if Isaac.ConsoleOutput then Isaac.ConsoleOutput(loaded.."\n")end
    end)
    add("MC_EXECUTE_CMD",function(_,command)
        if command~="hunterdiag"then return end
        local lines={"[Hunter v1.72] REPENTOGON="..tostring(not not REPENTOGON)}
        for i=0,game:GetNumPlayers()-1 do
            local p=Isaac.GetPlayer(i)
            if hunter(p)then
                local state=data(p);local live=0
                for _,g in pairs(groups)do if g.owner==p then live=live+1 end end
                lines[#lines+1]=string.format("P%d: groups=%d native_miss_requests=%d blocked_native_shots=%d native_milk=%d logical_milk=%d",
                    i,live,state.missRequests165 or 0,state.suppressed165 or 0,p:GetCollectibleNum(69,true),R.count(p,69))
                local light=state.lastLight165
                if light then lines[#lines+1]=string.format("light: incoming=%.4f applied=%.4f source=%d.%d frame=%d",light.incoming,light.applied,light.source,light.variant,light.frame)end
                local balance=p:GetData().hunterBalance170
                if balance then
                    local policy=mod.HunterBalance170
                    lines[#lines+1]=string.format("balance: damage=%.4f item_multiplier=%.4f tears=%.4f cap=%.4f shot_speed=%.4f",p.Damage,policy and policy.damageMultiplier(p)or 1,30/(p.MaxFireDelay+1),balance.capRate or 1,p.ShotSpeed)
                    if balance.error then lines[#lines+1]="balance error: "..balance.error end
                end
                local tech=state.lastTech168
                if tech then lines[#lines+1]=string.format("technology: incoming=%.4f applied=%.4f frame=%d",tech.incoming,tech.applied,tech.frame)end
                local inventory=p:GetData().hunterItems163
                if inventory and inventory.cursedDiag168 then lines[#lines+1]="cursed eye: "..inventory.cursedDiag168 end
                if p:GetData().hunterNativeSword166 then lines[#lines+1]="sword: "..p:GetData().hunterNativeSword166 end
                local fetus=state.lastCSection165
                if fetus then lines[#lines+1]=string.format("fetus: incoming=%.4f applied=%.4f frame=%d",fetus.incoming,fetus.applied,fetus.frame)end
            end
        end
        local result=table.concat(lines,"\n").."\n"
        if Isaac.ConsoleOutput then Isaac.ConsoleOutput(result)end
        if Isaac.DebugString then Isaac.DebugString(result)end
    end)
    add("MC_POST_BOMB_UPDATE",function(_,bomb)
        local p=own(bomb)
        if hunter(p)and R.has(p,52)and R.scripted(p)and bomb.IsFetus
            and bomb.SpawnerEntity and bomb.SpawnerEntity.Type==EntityType.ENTITY_PLAYER
            and not items.activeShot(p)then
            bomb.ExplosionDamage=0;bomb.CollisionDamage=0;bomb.Flags=TearFlags.TEAR_NORMAL
            bomb:GetData().suppressed163=true;bomb:Remove()
        end
    end)
    if ModCallbacks.MC_PRE_USE_ITEM then
        add("MC_PRE_USE_ITEM",function(_,id,_,p)
            if hunter(p)and id==422 then data(p).rewind163=data(p).roomEntry163 end
        end)
    end
    -- Temporary item replacement effects must also expire after type changes.
    add("MC_POST_PEFFECT_UPDATE",function(_,p)
        if not hunter(p)then
            local d=p:GetData().hunterCompat163
            if d and d.locked163 then d.locked163=nil;p.FireDelay=0 end
            if p:GetData().hunterItems163 then items.update(p)end
        end
    end)
    C._testing={own=own,configure=configureMain,shoot=shoot,groups=function()return groups end,items=items,sword=sword}
    return C
end
