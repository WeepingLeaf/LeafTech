dofile "$MOD_DATA/Scripts/Config.lua"

CreationProtector_LF = class(nil)

CreationProtector_LF.maxParentCount = 0
CreationProtector_LF.maxChildCount = 0
CreationProtector_LF.connectionInput = sm.interactable.connectionType.none
CreationProtector_LF.connectionOutput = sm.interactable.connectionType.none

function CreationProtector_LF.server_onCreate(self)
    sm.gui.chatMessage("CreationProtector_LF redy 2 Created")
    for _, theShape in pairs(self.shape.body.getCreationShapes(self.shape.body)) do
        if theShape.uuid == self.shape.uuid and theShape ~= self.shape then
            self.shape:destroyPart()
            return
        else
            --Origin_theShape_client_canErase = Origin_theShape_client_canErase or theShape.client_canErase

            function theShape.client_canErase(self)
                sm.gui.chatMessage("test")
                return true
            end
        end
    end
    
    sm.gui.chatMessage("CreationProtector_LF Created")
end

function CreationProtector_LF.client_canErase(self)
    local theLocalPlayer = sm.localPlayer.getPlayer()
    local theName = theLocalPlayer:getName()
    if self.master == nil then
        return true

    else
        return false
    end
end

----  SERVER  ----
--[[
function CreationProtector_LF.server_onCreate(self)
    self.ready = false
    -- 造物保护器上限检测
	local selfCount = 0
	for _, theShape in pairs(self.shape.body.getCreationShapes(self.shape.body)) do
		if theShape.uuid == self.shape.uuid then
			selfCount = selfCount + 1
		end 
	end
	if selfCount > 1 then
		self.shape:destroyPart()
	end

    self.ready = true

    -- 数据初始化
    self.theConnectTool = sm.uuid.new("8c7efc37-cd7c-4262-976e-39585f8527bf")
    self.theLift = sm.uuid.new("5cc12f03-275e-4c8e-b013-79fc0f913e1b")
    self.thePaintTool = sm.uuid.new("c60b9627-fc2b-4319-97c5-05921cb976c6")

    self.masterActiveItem = sm.uuid.getNil()

    local data = self.storage:load()
    if data == nil then
        data = {
            theMaster = nil,
            theMode = 0
        }
    end
    self.master = data.theMaster
    self.mode = data.theMode

    self.storage:save(data)

    self.proactiveDefense = {}

    self.theBody = self.shape.body

    self.delay = 0

    --self.master = self.storage:load()
    --self.storage:save(self.master)

	self.network:sendToClients("client_freshData", {theMaster = self.master, theMode = self.mode})
end

function CreationProtector_LF.server_onFixedUpdate(self, timeStep)
    self.theBody = self.shape.body
    local buildable = true
    local connectable = true
    local destructable = true
    local erasable = true
    local liftable = true
    local paintable = true

    if self.master ~= nil then
        local masterPlayer = nil
        for _, thePlayer in pairs(sm.player.getAllPlayers()) do
            if thePlayer:getName() == self.master then
                if masterPlayer == nil then
                    masterPlayer = thePlayer
                else
                    sm.gui.chatMessage("#ff0000这个世界有好多"..self.master.."，人家会出错的QAQ")
                end
            end
        end

        if masterPlayer == nil then
            sm.gui.chatMessage("#ff99cc主人走了，我也溜了qwq")
            for _, theBody in pairs(self.shape.body:getCreationBodies()) do
                for _, theShape in pairs(theBody:getShapes()) do
                    theShape:destroyShape()
                end
            end
            return
        end

        destructable = false
        if self.mode == 0 then
            connectable = self.masterActiveItem == self.theConnectTool
            liftable = self.masterActiveItem == self.theLift
            paintable = self.masterActiveItem == self.thePaintTool
    
        elseif self.mode == 1 then
            for _, theData in pairs(self.proactiveDefense) do
                if sm.exists(theData.player) then
                    if theData.body ~= nil and sm.exists(theData.body) then
                        local theCreationId = theData.body:getCreationId()
                        local selfCreationId = self.shape.body:getCreationId()
                        if theCreationId == selfCreationId and self.delay == 0 then
                            buildable = false
                            erasable = false
                            connectable = not (theData.activeItem == self.theConnectTool)
                            liftable = not (theData.activeItem == self.theLift)
                            paintable = not (theData.activeItem == self.thePaintTool)
                            self.network:sendToClient(masterPlayer, "client_masterAlert")
                            
                            self.o_buildable = buildable
                            self.o_connectable = erasable
                            self.o_erasable = connectable
                            self.o_liftable = liftable
                            self.o_paintable = paintable
                            
                            self.delay = 40
                        end
                    end
                end
            end
        end

        if self.shape.body:isOnLift() then
            for _, theLift in pairs(LF.Lift) do
                if sm.exists(theLift.player) and theLift.player:getName() ~= self.master then
                    local theLevel = 0
                    local liftHit, liftResult = sm.physics.raycast(theLift.position + sm.vec3.new(0, 0, 0), theLift.position + sm.vec3.new(0, 0, 0.25))
                    if liftHit and liftResult.type == "lift" then
                        theLevel = liftResult:getLiftData():getLevel() * sm.construction.constants.subdivideRatio
                    else
                        theLevel = theLift.level
                    end

                    local bodyHit, bodyResult = sm.physics.spherecast(theLift.position + sm.vec3.new(0, 0, theLevel + 0.25), theLift.position + sm.vec3.new(0, 0, theLevel + 0.5), 0.5, nil, sm.physics.filter.staticBody)
                    if bodyHit then
                        if bodyResult:getBody():getCreationId() == self.shape.body:getCreationId() then
                            theLift.player:removeLift()
                            self.network:sendToClient(masterPlayer, "client_masterAlert")
                            self.network:sendToClient(theLift.player, "client_otherAlert")
                        end
                    end
                end
            end
        end
    end

    if self.delay > 0 then
        self.delay = self.delay - 1

        buildable = self.o_buildable
        erasable = self.o_connectable
        connectable = self.o_erasable
        liftable = self.o_liftable
        paintable = self.o_paintable
    end

    for _, theBody in pairs(self.shape.body:getCreationBodies()) do
        theBody:setBuildable(buildable)
        theBody:setConnectable(connectable)
        theBody:setDestructable(destructable)
        theBody:setErasable(erasable)
        theBody:setLiftable(liftable)
        theBody:setPaintable(paintable)
    end
    
    self.proactiveDefense = {}
end

function CreationProtector_LF.server_onDestroy(self)
    if self.master ~= nil and self.ready then
        sm.gui.chatMessage("#ff0000同归于尽QAQ")
        for _, theBody in pairs(self.theBody:getCreationBodies()) do
            for _, theShape in pairs(theBody:getShapes()) do
                theShape:destroyShape()
            end
        end
    end
end

-- 用于认主
function CreationProtector_LF.server_masterChange(self, thePlayer)
    if thePlayer == nil then
        self.master = nil
    else
        self.master = thePlayer:getName()
    end

    local data = {
        theMaster = self.master,
        theMode = self.mode
    }
    self.storage:save(data)
    --self.storage:save(self.master)
	self.network:sendToClients("client_freshData", {theMaster = self.master, theMode = self.mode})
end

function CreationProtector_LF.server_masterActiveItem(self, theActiveItem)
    self.masterActiveItem = theActiveItem
end

function CreationProtector_LF.server_modeChange(self, theMode)
    self.mode = theMode

    local data = {
        theMaster = self.master,
        theMode = self.mode
    }
    self.storage:save(data)
	self.network:sendToClients("client_freshData", {theMaster = self.master, theMode = self.mode})
end

function CreationProtector_LF.server_proactiveDefense(self, theData)
    self.proactiveDefense[theData.player.id] = theData
end

function CreationProtector_LF.server_proactiveDefenseClear(self)
    self.proactiveDefense = {}
end



----  CLIENT  ----

function CreationProtector_LF.client_onFixedUpdate(self, timeStep)
    local theLocalPlayer = sm.localPlayer.getPlayer()
    local theActiveItem = sm.localPlayer.getActiveItem()
    if self.master == theLocalPlayer:getName() then
        self.network:sendToServer("server_masterActiveItem", theActiveItem)
    elseif self.master ~= nil then
        local theHit, theResult = sm.localPlayer.getRaycast(7.5, sm.localPlayer.getRaycastStart(), sm.localPlayer.getDirection())
        local theBody = nil
        if theHit and theResult.type == "body" then
            theBody = theResult:getBody()
        end
        local data = {
            player = theLocalPlayer,
            body = theBody,
            activeItem = theActiveItem
        }
        self.network:sendToServer("server_proactiveDefense", data)
    end
end

-- 同步更新master
function CreationProtector_LF.client_freshData(self, theData)
    self.master = theData.theMaster
    self.mode = theData.theMode
end

function CreationProtector_LF.client_canErase(self)
    local theLocalPlayer = sm.localPlayer.getPlayer()
    local theName = theLocalPlayer:getName()
    if self.master == nil then
        return true

    else
        return false
    end
end

-- 用于修改按键提示
function CreationProtector_LF.client_canInteract(self, character)
    local theLocalPlayer = sm.localPlayer.getPlayer()
    local theName = theLocalPlayer:getName()
    if self.master == nil then
        sm.gui.setInteractionText("#ff99cc还没有主人呢，要和人家签订契约嘛？")

    elseif self.master == theName then
        sm.gui.setInteractionText("#ff99cc主人您好qwq")

    else
        sm.gui.setInteractionText("#ff99cc人家的主人是："..self.master)
    end
    
    local modeDescription = ""
    if self.mode == 0 then
        modeDescription = "低安全模式"

    elseif self.mode == 1 then
        modeDescription = "高安全模式"

    else
        modeDescription = "出错啦Σ(ŎдŎ|||)ﾉﾉ"

    end

    sm.gui.setInteractionText("#ff99cc当前模式："..modeDescription)

    return true
end

-- 触发按键时
function CreationProtector_LF.client_onInteract(self, character, state)
    if not state then return end

    local theLocalPlayer = sm.localPlayer.getPlayer()
    local theName = theLocalPlayer:getName()
    if self.master == nil then
        self.network:sendToServer("server_masterChange", theLocalPlayer)
        sm.gui.displayAlertText("#ff99cc从现在开始，你就是人家的主人啦qwq", 3)

    elseif self.master == theName then
        self.network:sendToServer("server_masterChange", nil)
        self.network:sendToServer("server_proactiveDefenseClear")
        sm.gui.displayAlertText("#ff99cc再见啦主人QAQ", 3)

    else
        sm.gui.displayAlertText("#ff0000坏人走开，你不是人家的主人，哼╯^╰", 3)
    end
end

function CreationProtector_LF.client_onTinker(self, character, state)
    if not state then return end

    local theLocalPlayer = sm.localPlayer.getPlayer()
    local theName = theLocalPlayer:getName()
    if self.master == nil then
        sm.gui.displayAlertText("#ff99cc请先雇佣人家呢", 3)

    elseif self.master == theName then
        -- 使用该方式是为了便于未来更新添加模式
        self.mode = (self.mode + 1) % 2
        self.network:sendToServer("server_modeChange", self.mode)

        if self.mode == 0 then
            sm.gui.displayAlertText("#ff99cc人家会尽量避免打扰主人的qwq", 3)

        elseif self.mode == 1 then
            sm.gui.displayAlertText("#ff99cc人家会保护好主人的东西(｡ì _ í｡)", 3)

        else
            sm.gui.displayAlertText("#ff99cc出错啦Σ(ŎдŎ|||)ﾉﾉ", 3)

        end
    else
        sm.gui.displayAlertText("#ff0000坏人走开，你不是人家的主人，哼╯^╰", 3)
    end
end

function CreationProtector_LF.client_masterAlert()
    sm.gui.displayAlertText("#ff0000主人，有人在盯着你的东西看д´)ﾉ", 1.5)
end

function CreationProtector_LF.client_otherAlert()
    sm.gui.displayAlertText("#ff0000这不是你的东西，走开啦д´)ﾉ", 1.5)
end
]]