dofile "$MOD_DATA/Scripts/Config.lua"

FlightControlSystem_BodyLocator_LF = class(nil)

FlightControlSystem_BodyLocator_LF.maxParentCount = 1
FlightControlSystem_BodyLocator_LF.maxChildCount = 0
FlightControlSystem_BodyLocator_LF.connectionInput = sm.interactable.connectionType.data
FlightControlSystem_BodyLocator_LF.connectionOutput = sm.interactable.connectionType.none
FlightControlSystem_BodyLocator_LF.colorNormal = sm.color.new(0x0000ffff)
FlightControlSystem_BodyLocator_LF.colorHighlight = sm.color.new(0xff0000ff)

--[[
临时测试使用
function FlightControlSystem_BodyLocator_LF.server_onCreate(self)
    self.thebody = self.shape.body
    sm.gui.chatMessage("FlightControlSystem_LF Created")
end

function FlightControlSystem_BodyLocator_LF.server_onFixedUpdate(self, timeStep)
    if self.thebody ~= self.shape.body then
        sm.gui.chatMessage("1")
    end
    self.thebody = self.shape.body
end
]]