-- Continuous particles have their own Sprite and clock. Actor/wardrobe swaps
-- cannot clear the effect, and holding the body still does not stop droplets.
return function(mod,definitions,isHunter,owned)
    local game=Game()
    local states=include('hunter_sprite_state')
    local data=include('hunter_effect_motion')
    local entries={}
    for _,entry in ipairs(definitions)do if entry.loop then entries[entry.id]=entry end end
    local ordinary={WalkDown=true,WalkUp=true,WalkRight=true,WalkLeft=true,
        PickupWalkDown=true,PickupWalkUp=true,PickupWalkRight=true,PickupWalkLeft=true,
        Pickup=true,Hit=true,Happy=true,Sad=true,LiftItem=true,HideItem=true,UseItem=true}
    local function render(p,position)
        if not isHunter(p)or p.Visible==false or(p.IsDead and p:IsDead())then return end
        local s=p:GetData().hunterDynamic174
        local entry=s and entries[s.loopId]
        if not entry then return end
        local body=p:GetSprite();local animation=body:GetAnimation()
        local source=(body:GetFilename()or''):lower():gsub('\\','/')
        if not owned(source)or not ordinary[animation]then return end
        local overlay=body.GetOverlayAnimation and body:GetOverlayAnimation()or''
        local direction=overlay:match('^Head(Down)')or overlay:match('^Head(Up)')
            or overlay:match('^Head(Left)')or overlay:match('^Head(Right)')
            or animation:match('(Down)$')or animation:match('(Up)$')
            or animation:match('(Left)$')or animation:match('(Right)$')or'Down'
        local name='Head'..direction..'_Overlay'
        local duration=data.loops[entry.id][name]
        if not duration then return end
        s.particleSprites=s.particleSprites or{}
        local particle=s.particleSprites[entry.id]
        if not particle then particle=Sprite();particle:Load(entry.path,true);s.particleSprites[entry.id]=particle end
        local motion=data.motion[animation]
        local frame=body:GetFrame()
        if not motion then
            motion=data.motion[overlay]
            frame=body.GetOverlayFrame and body:GetOverlayFrame()or 0
        end
        local offset=motion and motion[frame%#motion+1]or{0,0,1,1,0}
        local scale=body.Scale or Vector(1,1)
        particle.Scale=Vector(scale.X*offset[3],scale.Y*offset[4])
        particle.Color=states.colour(body.Color)
        particle.Rotation=(body.Rotation or 0)+offset[5]
        particle.FlipX,particle.FlipY=body.FlipX,body.FlipY
        particle:SetFrame(name,game:GetFrameCount()%duration)
        local angle=math.rad(body.Rotation or 0)
        local x,y=offset[1]*scale.X,offset[2]*scale.Y
        particle:Render(position+Vector(x*math.cos(angle)-y*math.sin(angle),x*math.sin(angle)+y*math.cos(angle)),Vector(0,0),Vector(0,0))
    end
    mod:AddCallback(ModCallbacks.MC_POST_PLAYER_RENDER,function(_,p)
        render(p,Isaac.WorldToScreen(p.Position)+(p.SpriteOffset or Vector(0,0)))
    end)
    return {render=render}
end
