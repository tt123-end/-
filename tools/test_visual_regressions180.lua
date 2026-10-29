-- Exercise the real shared update/render paths, including late Sprite.Update.
return function(T)
    local api=T.api
    local function near(a,b)assert(math.abs(a-b)<1e-6,tostring(a)..' ~= '..tostring(b))end
    local function pnew()
        local p=T.player();p.allowVisualLayerBindings=true
        p.Velocity=Vector(0,0);p.shooting=Vector(0,0)
        function p:GetShootingInput()return self.shooting end
        p.sprite:Play('WalkDown',true);p.sprite:PlayOverlay('HeadDown',true)
        p.sprite:SetOverlayFrame(0)
        return p
    end
    -- Passing Color userdata into __mul is an error in this fixture. Run long
    -- enough for the previous repeated multiplication to converge to red/blue.
    for _,style in ipairs({0,1,3,8})do
        local p=pnew();p.forms[style]=true;p.CanFly=true;api.sync(p)
        local original=Color(.91,.83,.75,.62,.07,.08,.09,1.2,.7,.9,.4)
        p.sprite.Color=original
        for tick=1,2500 do
            T.setFrame(tick);T.clearRenders();api.transformations.renderWings(p,Vector(100,100),false)
            local out=T.getRenders();assert(#out==1)
            assert(p.sprite.Color==original and out[1].color~=original,'renderer reused player-owned Color')
            near(original.R,.91);near(original.G,.83);near(original.B,.75);near(original.A,.62)
            near(original.RO,.07);near(original.GO,.08);near(original.BO,.09)
            local c=out[1].color:GetColorize();near(c.R,1.2);near(c.G,.7);near(c.B,.9);near(c.A,.4)
        end
    end
    -- A different costume must preserve both track states/frames. The named
    -- overlay SetFrame overload in the fixture deliberately stops playback.
    local p=pnew();p.items[7]=1;p.sprite:SetFrame(5);p.sprite:SetOverlayFrame(2)
    api.sync(p);assert(p.sprite:IsPlaying()and p.sprite:IsOverlayPlaying())
    assert(p.sprite:GetFrame()==5 and p.sprite:GetOverlayFrame()==2)
    p.sprite:Update();assert(p.sprite:GetFrame()==6 and p.sprite:GetOverlayFrame()==3)
    p.sprite:Stop(false);p.items[1]=1;api.sync(p)
    assert(not p.sprite:IsPlaying()and p.sprite:IsOverlayPlaying())
    p.sprite:Update();assert(p.sprite:GetFrame()==6 and p.sprite:GetOverlayFrame()==0)

    include('tainted_hunter_visuals')(T.mod,42,0)
    -- All66 outfits use the actual visual callback: idle WITHOUT shooting,
    -- idle WITH shooting, movement restart, then a non-locomotion action.
    for _,entry in ipairs(api.definitions)do
        local player=pnew();T.setPlayers({player});player.effects[entry.id]=1
        for tick=1,8 do
            T.setFrame(tick);player.sprite:Update();T.fire('player_update',player)
            assert(player.sprite:GetFrame()==0 and not player.sprite:IsPlaying(),'idle gait advanced for '..entry.id)
            assert(player.sprite:IsOverlayPlaying(),'idle hold stopped head overlay '..entry.id)
            player.sprite:Update();assert(player.sprite:GetFrame()==0,'late engine update stepped the idle body')
        end
        assert(api.selected(player).id==entry.id)
        player.shooting=Vector(1,0);player.sprite:PlayOverlay('HeadRight',true);player.sprite:SetOverlayFrame(2)
        T.fire('player_update',player)
        assert(player.sprite:GetAnimation()=='WalkRight'and player.sprite:GetFrame()==0)
        assert(player.sprite:IsOverlayPlaying()and player.sprite:GetOverlayFrame()==2)
        player.sprite:Update();assert(player.sprite:GetFrame()==0 and player.sprite:GetOverlayFrame()==3)
        player.Velocity=Vector(2,0);player.shooting=Vector(0,0)
        for tick=1,5 do T.fire('player_update',player);player.sprite:Update()end
        assert(player.sprite:IsPlaying()and player.sprite:GetFrame()>0,'movement failed to resume '..entry.id)
        player.Velocity=Vector(0,0);T.fire('player_update',player);player.sprite:Update()
        assert(player.sprite:GetFrame()==0 and not player.sprite:IsPlaying())
        player.sprite:Play('Pickup',true);player.sprite:SetFrame(5)
        T.fire('player_update',player);player.sprite:Update()
        assert(player.sprite:GetAnimation()=='Pickup'and player.sprite:GetFrame()==6,'idle control rewound Pickup')
        -- Force a graphics rebuild in the middle of a shooting overlay.
        player.sprite:Play('WalkDown',true);player.sprite:PlayOverlay('HeadDown',true)
        player.sprite:SetOverlayFrame(2);api.sync(player,true)
        assert(player.sprite:IsOverlayPlaying()and player.sprite:GetOverlayFrame()==2)
    end
    p=pnew();T.setPlayers({p});T.fire('player_update',p)
    assert(not p.sprite:IsPlaying()and p.data.hunterBodyHeld180)
    p.kind=0;T.fire('player_update',p);p.sprite:Update()
    assert(p.sprite:IsPlaying()and p.sprite:GetFrame()>0,'leaving Hunter retained the idle hold')
    -- No native costume is needed for droplets, fuse sparks or cap particles.
    -- Verify their real render callback while the entire body remains stopped.
    local loops=include('hunter_effect_motion').loops
    for _,id in ipairs({1,19,342})do
        local player=pnew();T.setPlayers({player});player.items[id]=1
        api.sync(player);T.fire('player_update',player)
        assert(api.state(player).loopId==id and not next(player.nulls))
        for _,direction in ipairs({'Down','Right','Up','Left'})do
            player.sprite.animation='Walk'..direction
            player.sprite:PlayOverlay('Head'..direction,true);player.sprite:SetOverlayFrame(0)
            local period=loops[id]['Head'..direction..'_Overlay']
            local loads=T.getLoads();local seen={}
            for tick=0,period*3-1 do
                T.setFrame(tick);T.clearRenders();T.fire('player_render',player)
                local out=T.getRenders();assert(#out==1 and out[1].path:find('/'..id..'.anm2',1,true))
                assert(out[1].animation=='Head'..direction..'_Overlay'and out[1].frame==tick%period)
                seen[out[1].frame]=true
                assert(player.sprite:GetFrame()==0 and not player.sprite:IsPlaying(),'particles restarted walking')
            end
            local count=0;for _ in pairs(seen)do count=count+1 end;assert(count==period)
            assert(T.getLoads()<=loads+1,'particle sprite loaded every frame')
        end
        T.setFrame(17);api.sync(player,true);T.clearRenders();T.fire('player_render',player)
        assert(#T.getRenders()==1 and T.getRenders()[1].frame==17%loops[id].HeadLeft_Overlay)
        T.clearRenders();HunterWardrobe178.renderItemEffects(player,Vector(258,111))
        assert(#T.getRenders()==1,'wardrobe omitted the selected continuous effect')
        player.dead=true;T.clearRenders();T.fire('player_render',player);assert(#T.getRenders()==0);player.dead=false
        player.lost=true;T.clearRenders();T.fire('player_render',player);assert(#T.getRenders()==0);player.lost=false
        player.ghost=true;T.clearRenders();T.fire('player_render',player);assert(#T.getRenders()==0);player.ghost=false
        player.Visible=false;T.clearRenders();T.fire('player_render',player);assert(#T.getRenders()==0);player.Visible=true
        player.sprite.file='gfx/unrelated_special_form.anm2';T.clearRenders();T.fire('player_render',player);assert(#T.getRenders()==0)
        player.sprite.file='gfx/001.000_player_hunter_b_v177_'..id..'.anm2'
        player.items[id]=nil;api.sync(player);T.clearRenders();T.fire('player_render',player);assert(#T.getRenders()==0)
    end
    -- A formed transformation may take precedence; wardrobe manual choice
    -- restores particles without losing the transformation's independent wings.
    p=pnew();p.items[1]=1;p.forms[0]=true;p.CanFly=true;api.sync(p)
    assert(not api.state(p).loopId and api.state(p).wingStyle=='guppy')
    HunterWardrobe178.select(p,'H178:I1');assert(api.state(p).loopId==1)
    T.clearRenders();T.fire('pre_render',p);T.fire('player_render',p)
    assert(#T.getRenders()==2,'manual outfit lost either wings or item particles')
    print('PASS:10000colour renders preserve all player channels; all66real visual updates hold idle/resume walking, '
        ..'head overlays survive actor/graphics swaps, all3particle loops x4directions run independently, '
        ..'wardrobe/lifecycle/form precedence and simultaneous wings+particles.')
end
