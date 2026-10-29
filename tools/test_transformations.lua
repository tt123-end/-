-- Meaningful interface simulations, including the actual patched wardrobe UI.
-- This does not load or claim to replace the Isaac executable.
return function(T)
    local api,make,fire=T.api,T.player,T.fire
    local bridge=assert(HunterWardrobe178)
    local forms=api.transformations.definitions
    assert(#forms==15 and forms[15].form==14)
    local vt={}
    function Vector(x,y)return setmetatable({X=x,Y=y},vt)end
    vt.__add=function(a,b)return Vector(a.X+b.X,a.Y+b.Y)end
    vt.__sub=function(a,b)return Vector(a.X-b.X,a.Y-b.Y)end
    vt.__mul=function(a,b)
        if type(a)=='number'then return Vector(a*b.X,a*b.Y)end
        return Vector(a.X*b,a.Y*b)
    end
    local colourMeta={}
    function Color(r,g,b,a,ro,go,bo)
        return setmetatable({R=r,G=g,B=b,A=a,RO=ro or 0,GO=go or 0,BO=bo or 0},colourMeta)
    end
    colourMeta.__mul=function(a,b)
        local colour=Color(a.R*b.R,a.G*b.G,a.B*b.B,a.A*b.A,a.RO+b.RO,a.GO+b.GO,a.BO+b.BO)
        colour.left,colour.right=a,b
        return colour
    end
    local renders,loads={},0
    function Sprite()
        local sprite={}
        function sprite:Load(path)self.path=path;loads=loads+1 end
        function sprite:SetFrame(animation,frame)self.animation,self.frame=animation,frame end
        function sprite:Render(position)
            renders[#renders+1]={kind='wings',position=position,frame=self.frame,
                animation=self.animation,path=self.path,scale=self.Scale,color=self.Color}
        end
        return sprite
    end
    local function player()
        local p=make();p.forms={};p.CanFly=false;p.Visible=true
        p.Position=Vector(320,240);p.SpriteOffset=Vector(2,-3)
        p.sprite.Scale=Vector(1,1);p.sprite.Color=Color(.9,.8,.7,.6)
        return p
    end
    local function near(a,b)assert(math.abs(a-b)<1e-6,tostring(a)..' ~= '..tostring(b))end
    local camera=Vector(110,70)
    Isaac.WorldToScreen=function(position)return position+camera end

    -- Every real transformation plus the defensive engine fallback is reachable.
    for _,entry in ipairs(forms)do
        local p=player();T.setPlayers({p})
        p.forms[entry.form]=true;p.CanFly=entry.wing~=nil
        local originalItems=p.items
        api.sync(p)
        assert(api.selected(p)==entry,'form unreachable: '..entry.label)
        assert(p.sprite.file==entry.actor and p.sprite.sheet==entry.sheet)
        assert(p.items==originalItems and next(p.items)==nil,'form added an item')
        if entry.native then assert(p.nulls[entry.native]==nil,'native skin survived replacement')end
        assert(api.state(p).wingStyle==(entry.wing or nil))
        local writes=p.sprite.writes;api.sync(p);assert(p.sprite.writes==writes,'form reloads every tick')
        p.forms={};api.sync(p)
        assert(not api.selected(p)and not api.state(p).wingStyle,'lost form was not cleared')
    end
    -- Later transformations override items; manual dress overrides both.
    local p,q=player(),player();T.setPlayers({p,q})
    p.items[1]=1;api.sync(p);assert(api.selected(p).id==1)
    p.forms[0]=true;p.CanFly=true;api.sync(p);assert(api.selected(p).form==0)
    p.forms[10]=true;api.sync(p);assert(api.selected(p).form==10 and api.state(p).wingStyle=='guppy')
    q.forms[3]=true;q.CanFly=true;api.sync(q);assert(api.selected(q).form==3)
    assert(bridge.select(p,'H178:F8'));assert(api.selected(p).form==8 and api.state(p).wingStyle=='devil')
    assert(api.selected(q).form==3,'coop selection leaked')
    assert(bridge.select(p,'H178:I1'));assert(api.selected(p).id==1 and next(p.nulls))
    assert(bridge.select(p,'H178:BASE'));assert(not api.selected(p)and not next(p.nulls))
    assert(not api.state(p).wingStyle and p.CanFly,'base appearance removed flight')
    assert(bridge.select(p,'H178:AUTO'));assert(api.selected(p).form==10)
    assert(bridge.undress(p,'H178:F10'));assert(api.selected(p).form==0)
    assert(bridge.undress(p,'H178:F0'));assert(api.selected(p).id==1 and not api.state(p).wingStyle)
    bridge.item(p,{id=1,visible=false});assert(not api.selected(p))
    bridge.item(p,{id=1,visible=true});assert(api.selected(p).id==1)
    assert(not bridge.select(p,'unrelated')and not bridge.select(p,'H178:I373'))
    p.CanFly=false;local selected=api.selected(p);bridge.select(p,'H178:F3')
    assert(api.selected(p)==selected and p.CanFly==false,'wardrobe granted flight')
    p.CanFly=true
    bridge.select(p,'H178:F3')
    -- Wing art changes without rewriting the body or resetting shooting frames.
    p.sprite.animation='WalkRight';p.sprite.frame=7;p.sprite.overlay='HeadUp';p.sprite.overlayFrame=2
    bridge.select(p,'H178:F8')
    assert(p.sprite.animation=='WalkRight'and p.sprite.frame==7 and p.sprite.overlay=='HeadUp'and p.sprite.overlayFrame==2)
    -- The recorded slow folding beat advances while the player stays on frame0.
    p.sprite.animation='WalkDown';p.sprite.frame=0
    local previousLoads=loads
    local frames={}
    for tick=0,39 do
        T.setFrame(tick);renders={};fire('pre_render',p)
        assert(#renders==1 and renders[1].kind=='wings')
        local wing=renders[1];frames[wing.frame]=true
        near(wing.position.X,p.Position.X+camera.X+p.SpriteOffset.X)
        near(wing.position.Y,p.Position.Y+camera.Y+p.SpriteOffset.Y-3.6)
        local rgb=api.transformations.wingMotion.colours.devil
        assert(wing.color.left==p.sprite.Color and p.sprite.frame==0)
        near(wing.color.R,p.sprite.Color.R*rgb[1]);near(wing.color.G,p.sprite.Color.G*rgb[2])
        near(wing.color.B,p.sprite.Color.B*rgb[3]);near(wing.color.A,p.sprite.Color.A)
    end
    assert(loads==previousLoads+1,'wing sprite loaded every render')
    local count=0;for _ in pairs(frames)do count=count+1 end;assert(count==40)
    local tick=renders[1].frame;fire('pre_render',p);assert(renders[#renders].frame==tick,'paused game tick advanced')
    for _,direction in ipairs({'Down','Right','Up','Left'})do
        p.sprite.animation='Walk'..direction;renders={};fire('pre_render',p)
        assert(renders[1].animation==direction,'wrong wing direction')
    end
    p.sprite.animation='WalkDown';p.sprite.Scale=Vector(1.4,.9)
    renders={};fire('pre_render',p);near(renders[1].scale.X,.33*1.4);near(renders[1].scale.Y,.33*.9)
    renders={};api.transformations.renderWings(p,Vector(258,111),true)
    near(renders[1].position.X,258);near(renders[1].position.Y,111-3.6*.9)
    p.sprite.Rotation=90;renders={};api.transformations.renderWings(p,Vector(258,111),true)
    near(renders[1].position.X,258+3.6*.9);near(renders[1].position.Y,111)
    p.sprite.Rotation=0
    p.Visible=false;renders={};fire('pre_render',p);assert(#renders==0);p.Visible=true
    p.dead=true;fire('pre_render',p);assert(#renders==0);p.dead=false
    p.sprite.animation='Death';fire('pre_render',p);assert(#renders==0)
    p.sprite.animation='WalkDown';p.lost=true;fire('pre_render',p);assert(#renders==0);p.lost=false
    p.ghost=true;fire('pre_render',p);assert(#renders==0);p.ghost=false
    p.sprite.file='gfx/special_other_form.anm2';fire('pre_render',p);assert(#renders==0)
    p.sprite.file=forms[9].actor
    p.CanFly=false;api.sync(p);assert(not api.state(p).wingStyle)
    p.CanFly=true;api.sync(p);assert(api.state(p).wingStyle=='devil')
    -- Native wing providers must not render an additional white pair over
    -- the selected form. Cancellation/restoration is cosmetic and reversible.
    p.items[179]=1;p.items[33]=1;p.effects[33]=1;api.sync(p)
    assert(p.nativeRemoved[179]and p.nativeRemoved[33])
    assert(p.items[179]==1 and p.items[33]==1 and p.effects[33]==1 and p.CanFly)
    for _,callback in ipairs(T.callbacks.costume_pre)do
        assert(callback(nil,{ID=179},p,false)==true)
        assert(callback(nil,{ID=33},p,false)==true)
    end
    bridge.select(p,'H178:BASE')
    assert(p.nativeAdded[179]and p.nativeAdded[33]and p.CanFly)
    for _,callback in ipairs(T.callbacks.costume_pre)do assert(callback(nil,{ID=179},p,false)==nil)end
    p.nativeRemoved[33]=nil;p.effects[33]=nil;bridge.select(p,'H178:F8')
    assert(not p.nativeRemoved[33],'merely holding Bible should not be treated as an active effect')

    -- Appearance, hidden rows, observed form order survive an actual save/load.
    T.setPlayers({p});bridge.undress(p,'H178:I7');bridge.select(p,'H178:F8')
    fire('exit',true)
    assert(T.savedRoot().existingGameplayState.ammo==2)
    local oldState=api.state(p);p.data.hunterDynamic174=nil
    fire('start',true)
    assert(api.selected(p).form==8 and api.state(p).wingStyle=='devil')
    assert(api.state(p).wardrobe.hiddenItems[7])
    assert(api.state(p).formAcquired[10]==oldState.formAcquired[10])
    fire('room');assert(api.selected(p).form==8)
    p.kind=0;api.sync(p);assert(not api.state(p).wingStyle and p.CanFly)
    assert(p.nulls[5],'type exit did not restore native owned Guppy costume')
    assert(not bridge.select(p,'H178:F3'),'wardrobe modified another character')
    p.kind=42;api.sync(p)

    -- Execute the uploaded wardrobe's patched main.lua, then drive its real
    -- RenderList/RenderUI code. Only drawing/input infrastructure is mocked.
    PlayerForm={PLAYERFORM_GUPPY=0,PLAYERFORM_LORD_OF_THE_FLIES=1,PLAYERFORM_MUSHROOM=2,
        PLAYERFORM_ANGEL=3,PLAYERFORM_BOB=4,PLAYERFORM_DRUGS=5,PLAYERFORM_MOM=6,
        PLAYERFORM_BABY=7,PLAYERFORM_EVIL_ANGEL=8,PLAYERFORM_POOP=9,
        PLAYERFORM_BOOK_WORM=10,PLAYERFORM_ADULTHOOD=11,PLAYERFORM_SPIDERBABY=12}
    local nullNames={'ID_GUPPY','ID_LORD_OF_THE_FLIES','ID_MUSHROOM','ID_ANGEL','ID_BOB','ID_DRUGS',
        'ID_MOM','ID_BABY','ID_EVIL_ANGEL','ID_POOP','ID_BOOKWORM','ID_ADULTHOOD','ID_SPIDERBABY'}
    for i,name in ipairs(nullNames)do NullItemID[name]=forms[i].native end
    ButtonAction={ACTION_MENUCONFIRM=1,ACTION_PILLCARD=2,ACTION_BOMB=3}
    package.preload.main_default=function()DefaultCostumes={};return true end
    Isaac.GetEntityTypeByName=function()return 987 end
    Isaac.GetEntityVariantByName=function()return 654 end
    function RegisterMod()
        return{AddCallback=function()end}
    end
    local compat=T.root..'../compat/old wardrobe_2488945061/main.lua'
    local originalCostumeLookup=Isaac.GetCostumeIdByPath
    Isaac.GetCostumeIdByPath=function(path)
        if path=='gfx/characters/hunter_forms178/wardrobe_selector.anm2'then return 9000 end
        if path==''then return -1 end
        return originalCostumeLookup(path)
    end
    assert(loadfile(compat))()
    local function upvalue(fn,name,value,write,visited)
        visited=visited or{};if visited[fn]then return end;visited[fn]=true
        local children={}
        for i=1,100 do
            local key,item=debug.getupvalue(fn,i);if not key then break end
            if key==name then
                if write then debug.setupvalue(fn,i,value);return true end
                return item
            end
            if type(item)=='function'and key~='_ENV'then children[#children+1]=item end
        end
        for _,child in ipairs(children)do
            local found=upvalue(child,name,value,write,visited)
            if found~=nil then return found end
        end
    end
    local function set(fn,name,value)assert(upvalue(fn,name,value,true),'missing wardrobe upvalue '..name)end
    local renderList=assert(upvalue(OWR.RenderUI,'RenderList'))
    local drawPlayer=assert(upvalue(OWR.RenderUI,'DrawPlayer'))
    local createList=assert(upvalue(OWR.UpdateWardrobe,'CreateCostumesList'))
    local function wardrobePlayer()
        local value=player();value.CanFly=true
        for _,name in ipairs({'RenderGlow','RenderBody','RenderHead','RenderTop'})do
            value[name]=function(_,position)renders[#renders+1]={kind=name,position=position}end
        end
        return value
    end
    p=wardrobePlayer();T.setPlayers({p});p.forms[0]=true;api.sync(p)
    fire('post')
    assert(OWR.GetCostumeName('H178:AUTO'))
    assert(OWR.GetCostumeName('H178:F13')and not OWR.GetCostumeName('H178:F14'))
    assert(OWR.GetCostumeName('H178:I342'))
    assert(OWR.GetCostumeName('H178:I1')=='H-Item: Sad Onion','production UI contains art prompt text')
    set(renderList,'player',p)
    createList()
    local all=assert(upvalue(createList,'pid'));local count=0
    for _,key in pairs(all)do if key:sub(1,5)=='H178:'then count=count+1 end end
    assert(count==82,'incomplete Hunter wardrobe list')
    -- The actual original DrawPlayer calls wings before its four native draws.
    renders={};drawPlayer(p)
    assert(#renders==5 and renders[1].kind=='wings'and renders[2].kind=='RenderGlow'and renders[5].kind=='RenderTop')
    near(renders[1].position.X,renders[3].position.X)
    near(renders[1].position.Y,renders[3].position.Y-3.6)
    set(renderList,'DrawList',function()end)
    local furniture={ToNPC=function(self)return self end,PlaySound=function()end,Exists=function()return true end}
    set(renderList,'dressingEnt',furniture)
    local function clickList(key,button)
        set(renderList,'pid',{key});set(renderList,'selectionline',1)
        set(renderList,'actionbutton',button or ButtonAction.ACTION_MENUCONFIRM)
        renderList()
    end
    clickList('H178:F3');assert(api.selected(p).form==3 and api.state(p).wingStyle=='angel')
    clickList('H178:I1');assert(api.selected(p).id==1)
    clickList('H178:I1',ButtonAction.ACTION_PILLCARD);assert(api.selected(p).form==0)
    clickList('H178:BASE');assert(not api.selected(p))
    clickList('H178:AUTO');assert(api.selected(p).form==0)
    assert(not next(p.nulls),'list selection installed a marker costume')
    local writes=p.sprite.writes
    set(renderList,'actionbutton',-1);renderList()
    assert(p.sprite.writes==writes,'holding a list button reloads graphics every render')
    -- Hiding in native grid and then selecting the custom row must unhide it.
    set(renderList,'nocostume',{[1]=true})
    bridge.item(p,{id=1,visible=false});clickList('H178:I1')
    bridge.visibility(p,upvalue(renderList,'nocostume'),{})
    assert(api.selected(p).id==1,'legacy hidden row overrode explicit manual dress')
    clickList('H178:AUTO')
    set(OWR.RenderUI,'DrawUI',function()end)
    set(OWR.RenderUI,'verso',false);set(OWR.RenderUI,'selPos',Vector(0,0));set(OWR.RenderUI,'pageUI',1)
    set(OWR.RenderUI,'totalforms',1);set(OWR.RenderUI,'transfocostume',{5})
    set(OWR.RenderUI,'transfo',{[5]=3});set(OWR.RenderUI,'flyingcostumes',2)
    set(OWR.RenderUI,'phase',3);set(OWR.RenderUI,'actionbutton',ButtonAction.ACTION_MENUCONFIRM)
    OWR.RenderUI()
    assert(not api.selected(p)and not api.state(p).wingStyle and p.CanFly,'native form undress ignored')
    set(OWR.RenderUI,'phase',3);set(OWR.RenderUI,'actionbutton',ButtonAction.ACTION_MENUCONFIRM)
    OWR.RenderUI()
    assert(api.selected(p).form==0 and api.state(p).wingStyle=='guppy','native form dress ignored')
    assert(p.nulls[5]==nil,'native form costume overwrote Hunter head')
    p=wardrobePlayer();p.CanFly=false;p.items[1]=1;api.sync(p);set(OWR.RenderUI,'player',p);T.setPlayers({p})
    local item=Isaac.GetItemConfig():GetCollectible(1);item.Costume={ID=9,IsFlying=false}
    set(OWR.RenderUI,'totalforms',0);set(OWR.RenderUI,'totalcostumes',1)
    set(OWR.RenderUI,'iteminfos',{item});set(OWR.RenderUI,'nocostume',{})
    set(OWR.RenderUI,'phase',3);set(OWR.RenderUI,'actionbutton',ButtonAction.ACTION_MENUCONFIRM)
    OWR.RenderUI();assert(not api.selected(p),'native item undress ignored')
    set(OWR.RenderUI,'phase',3);set(OWR.RenderUI,'actionbutton',ButtonAction.ACTION_MENUCONFIRM)
    OWR.RenderUI();assert(api.selected(p).id==1,'native item dress ignored')
    set(OWR.RenderUI,'phase',3);set(OWR.RenderUI,'actionbutton',ButtonAction.ACTION_BOMB)
    OWR.RenderUI();assert(not api.selected(p)and api.state(p).wardrobe.mode=='base')
    -- A fresh character cannot see Hunter-specific list entries.
    p.kind=0;createList();all=upvalue(createList,'pid')
    local maxlines=upvalue(createList,'maxlines')
    for i=1,maxlines do assert(all[i]:sub(1,5)~='H178:','Hunter rows shown for another character')end
    p.nulls[9010]=true -- an unrelated character's own default/dance costume
    clickList('!2')
    assert(p.nulls[9010],'hidden Hunter rows removed another character costume')
    p.kind=42
    local dataBefore=api.state(p).wardrobe
    bridge.clear(p);assert(api.state(p).wardrobe.mode=='base')
    assert(p.items[1]==1 and p.CanFly==false,'wardrobe changed ownership or flight')
    -- EID character descriptions register the cosmetic relationship in both languages.
    local texts={}
    EID={addCharacterInfo=function(_,kind,text,name,language)texts[language]=text end}
    include('tainted_hunter_eid')(T.mod,42)
    assert(texts.zh_cn:find('14种套装',1,true)and texts.en_us:find('14 transformation',1,true))
    print('PASS:14forms+fallback, form/item/manual precedence,40tick feather beat/4directions, '
        ..'native anchors/tint/scale/visibility, death/ghost/special guards, no flight/inventory changes, '
        ..'coop isolation, saved filters/order, native wing deduplication/Bible activity, actual uploaded wardrobe list/grid/preview/bulk actions, bilingual EID.')
end
