if _leafLoaded then return end
_leafLoaded = true

Leaf = class(nil)

function Leaf:InstallHooks()
    -- 用于储存 sm.player.placeLift 原始函数
    Origin_sm_player_placeLift = Origin_sm_player_placeLift or sm.player.placeLift

    -- 对 sm.player.placeLift 进行重写
    function sm.player.placeLift(player, creation, position, level, rotation)
        Origin_sm_player_placeLift(player, creation, position, level, rotation)

        LF.Lift[player:getId()] = {
            player = player,
            creation = creation,
            position = position * sm.construction.constants.subdivideRatio,
            level = level * sm.construction.constants.subdivideRatio,
            rotation = rotation
        }
    end

    --[[
    Origin_sm_localPlayer_getRaycast = Origin_sm_localPlayer_getRaycast or sm.localPlayer.getRaycast

    function sm.localPlayer.getRaycast(range, origin, direction)
        sm.gui.chatMessage("sm.localPlayer.getRaycast")
        
        return Origin_sm_localPlayer_getRaycast(range, origin, direction)
    end

    --[[
    Origin_sm_body_createBlock = Origin_sm_body_createBlock or sm.body.createBlock
    function sm.body.createBlock(body, uuid, size, position, forceAccept)
        sm.gui.chatMessage("sm.body.createBlock")
        
        return Origin_sm_body_createBlock(body, uuid, size, position, forceAccept)
    end

    Origin_sm_body_createPart = Origin_sm_body_createBlock or sm.body.createPart
    function sm.body.createPart(body, uuid, position, z_axis, x_axis, forceAccept)
        sm.gui.chatMessage("sm.body.createPart")
        
        return Origin_sm_body_createPart(body, uuid, position, z_axis, x_axis, forceAccept)
    end

    Origin_sm_body_createWedge = Origin_sm_body_createBlock or sm.body.createWedge
    function sm.body.createWedge(body, uuid, size, position, z_axis, x_axis, forceAccept)
        sm.gui.chatMessage("sm.body.createWedge")
        
        return Origin_sm_body_createWedge(body, uuid, size, position, z_axis, x_axis, forceAccept)
    end
    ]]
end

----  UTIL  ----
Leaf.Util = class(nil)

function Leaf.Util:safe_divide(dividend, divisor)
    return divisor == 0 and 0 or dividend / divisor
end