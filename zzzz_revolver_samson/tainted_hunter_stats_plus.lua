-- Public Stats+ API only. Replace listed native multiplier entries rather than
-- multiplying them again; all other characters/providers retain their values.
return function(mod,playerType,stats)
    local B=stats.balance
    local function hunter(p)return p and playerType~=-1 and p:GetPlayerType()==playerType end
    mod:AddCallback('STATS_PLUS_REGISTER',function(_,api)
        local function middleware(id,provider,computable,intercept)
            return api:middleware({id=id,name=id,description='Tainted Hunter v1.70 stat policy',priority=100,
                target={provider={addon='stats-plus-essentials',id=provider},computable=computable},intercept=intercept})
        end
        local damage=middleware('tainted-hunter-character-damage','damage-multiplier-provider','getCharacterMultiplier',function(ctx)
            if hunter(ctx.args[1])then return ctx:updateWith(ctx.current*stats.damageMultiplier)end
            return ctx:ignore()
        end)
        local affected=middleware('tainted-hunter-affected-items','damage-multiplier-provider','getAffectedCollectibles',function(ctx)
            local result={};local seen={}
            for _,id in ipairs(ctx.current)do result[#result+1]=id;seen[id]=true end
            for _,id in ipairs({2,153,152,169,229,310,52,531,245})do if not seen[id]then result[#result+1]=id end end
            return ctx:updateWith(result)
        end)
        local items=middleware('tainted-hunter-item-multipliers','damage-multiplier-provider','getCollectibleMultiplier',function(ctx)
            local id,p=ctx.args[1],ctx.args[2]
            if hunter(p)then
                local value=B.itemMultiplier(p,id)
                if value~=nil then return ctx:updateWith(value)end
            end
            return ctx:ignore()
        end)
        local cap=middleware('tainted-hunter-tears-cap','tear-cap-provider','computeTearCap',function(ctx)
            local p=ctx.args[1];if not hunter(p)then return ctx:ignore()end
            -- Stats+'s native temporary-tears test can dirty the normal cache.
            -- Restore the current corrected stats before exposing its result.
            B.refresh(p)
            if ctx.current=='UNKNOWN'then return ctx:ignore()end
            local d=p:GetData().hunterBalance170;local value=d and d.capRate or 1
            if ctx.current=='MAX'and math.abs(30/(p.MaxFireDelay+1)-value)<.001 then return ctx:ignore()end
            return ctx:updateWith(30/value-1)
        end)
        local tears=api:provider({id='tainted-hunter-tears-multiplier',name='Tainted Hunter Tears Multiplier',description='Character tears multiplier x0.20; no negative-multiplier compensation.',
            targets={api.stat.tears},color='BLUE',state={multiplier={initial=function()return 1 end}},
            display={value={get=function(state)return state.multiplier end,format=function(value)if value~=1 then return string.format('x%.2f',value)end end}},
            mount=function(ctx)
                local function update(_,p)
                    if p and p.Index~=ctx.player.Index then return end
                    local v=hunter(ctx.player)and stats.tearsMultiplier or 1
                    if ctx.state.multiplier:current()~=v then ctx.state.multiplier:set(v)end
                end
                update();mod:AddCallback(ModCallbacks.MC_POST_PLAYER_UPDATE,update)
                return function()mod:RemoveCallback(ModCallbacks.MC_POST_PLAYER_UPDATE,update)end
            end})
        api:register({id='tainted-hunter-stats',name='Tainted Hunter Stats',middleware={damage,affected,items,cap},providers={tears}})
    end)
end
