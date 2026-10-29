-- Copy values out of engine userdata before rendering or replacing an actor.
-- Never use a player-owned Color as a multiplication operand.
local M={}
function M.colour(source,palette)
    if not source then return nil end
    local colourize=source.GetColorize and source:GetColorize()or{}
    return Color(source.R*(palette and palette[1]or 1),
        source.G*(palette and palette[2]or 1),source.B*(palette and palette[3]or 1),source.A,
        source.RO or 0,source.GO or 0,source.BO or 0,
        colourize.R or colourize[1]or 0,colourize.G or colourize[2]or 0,
        colourize.B or colourize[3]or 0,colourize.A or colourize[4]or 0)
end
function M.capture(sprite)
    local overlay=sprite.GetOverlayAnimation and sprite:GetOverlayAnimation()or''
    return {animation=sprite:GetAnimation(),frame=sprite:GetFrame(),overlay=overlay,
        overlayFrame=sprite.GetOverlayFrame and sprite:GetOverlayFrame()or 0,
        playing=not sprite.IsPlaying or sprite:IsPlaying(sprite:GetAnimation()),
        overlayPlaying=overlay~=''and(not sprite.IsOverlayPlaying or sprite:IsOverlayPlaying(overlay)),
        scale=sprite.Scale and Vector(sprite.Scale.X,sprite.Scale.Y),colour=M.colour(sprite.Color),
        rotation=sprite.Rotation,flipX=sprite.FlipX,flipY=sprite.FlipY,speed=sprite.PlaybackSpeed}
end
function M.restore(sprite,snapshot)
    if snapshot.animation~=''then
        sprite:Play(snapshot.animation,true)
        sprite:SetFrame(snapshot.frame)
        if not snapshot.playing and sprite.Stop then sprite:Stop(false)end
    end
    if snapshot.overlay~=''then
        sprite:PlayOverlay(snapshot.overlay,true)
        -- REPENTOGON exposes the integer overload. It preserves the current
        -- overlay instead of selecting/stopping it through the named overload.
        sprite:SetOverlayFrame(snapshot.overlayFrame)
        if snapshot.overlayPlaying and sprite.ContinueOverlay then sprite:ContinueOverlay()
        elseif not snapshot.overlayPlaying and sprite.StopOverlay then sprite:StopOverlay()end
    end
    sprite.Scale,sprite.Color,sprite.Rotation=snapshot.scale,snapshot.colour,snapshot.rotation
    sprite.FlipX,sprite.FlipY,sprite.PlaybackSpeed=snapshot.flipX,snapshot.flipY,snapshot.speed
end
return M
