dofile "$MOD_DATA/Scripts/Config.lua"

FlightControlSystem_LF = class(nil)

FlightControlSystem_LF.maxParentCount = 0
FlightControlSystem_LF.maxChildCount = 1
FlightControlSystem_LF.connectionInput = sm.interactable.connectionType.none
FlightControlSystem_LF.connectionOutput = sm.interactable.connectionType.data
FlightControlSystem_LF.colorNormal = sm.color.new(0x0000ffff)
FlightControlSystem_LF.colorHighlight = sm.color.new(0xff0000ff)

-- PID 速度
function FlightControlSystem_LF:PID_vel(self, timeStep, target_vel, kp, ki, kd)
    local error_vel = target_vel - self.vel
    self.pre_error_vel = self.pre_error_vel or error_vel

    local adaptiveKi = ki * (1 - sm.util.clamp(error_vel:length(), 0, 1))
    self.integral_vel = self.integral_vel + error_vel * adaptiveKi * timeStep
    self.integral_vel = self.integral_vel:safeNormalize(self.integral_vel) * sm.util.clamp(self.integral_vel:length(), -1, 1)

    local error_rate_of_change = (error_vel - self.pre_error_vel) / timeStep
    
    local impulse_vel = error_vel * kp + self.integral_vel * ki + error_rate_of_change * kd

    self.pre_error_vel = error_vel
    
    return impulse_vel * timeStep
end

-- PID 坐标
-- PS: 内环使用 [PID 速度]
function FlightControlSystem_LF:PID_pos(self, timeStep, target_pos, kp, ki, kd)
    local error_pos = target_pos - self.pos
    self.pre_error_pos = self.pre_error_pos or error_pos

    local adaptiveKi = ki * (0.2 - sm.util.clamp(error_pos:length(), 0, 0.2)) * 5
    self.integral_pos = self.integral_pos + error_pos * adaptiveKi * timeStep
    self.integral_pos = self.integral_pos:safeNormalize(self.integral_pos) * sm.util.clamp(self.integral_pos:length(), -1, 1)

    local error_rate_of_change = (error_pos - self.pre_error_pos) / timeStep

    local target_vel = error_pos * kp + self.integral_pos * ki - error_rate_of_change * kd

    self.pre_error_pos = error_pos

    return self:PID_vel(self, timeStep, target_vel, 23, 19, 0.3)
end

-- 计算惯性张量
function FlightControlSystem_LF:CalculateMomentOfInertia(theBody)
    local Ixx, Iyy, Izz = 0, 0, 0
    local Ixy, Ixz, Iyz = 0, 0, 0
    local com_pos = theBody.centerOfMassPosition

    for _, theShape in ipairs(theBody:getShapes()) do
        local pos = theShape.worldPosition - com_pos
        local x, y, z = pos.x, pos.y, pos.z
        local m = theShape.mass

        Ixx = Ixx + m * (y*y + z*z)
        Iyy = Iyy + m * (x*x + z*z)
        Izz = Izz + m * (x*x + y*y)
        Ixy = Ixy - m * x * y
        Ixz = Ixz - m * x * z
        Iyz = Iyz - m * y * z
    end

    return {
        xx = Ixx, xy = Ixy, xz = Ixz,
        yy = Iyy, yz = Iyz,
        zz = Izz
    }
end


--[[ 计算目标轴的有效转动惯量
function FlightControlSystem_LF:getEffectiveInertia(tensor, axis)
    local u = axis:normalize()
    return u.x*(tensor.xx*u.x + tensor.xy*u.y + tensor.xz*u.z) +
           u.y*(tensor.xy*u.x + tensor.yy*u.y + tensor.yz*u.z) +
           u.z*(tensor.xz*u.x + tensor.yz*u.y + tensor.zz*u.z)
end

--[[
-- 根据当前旋转轴动态调整PID参数
function adaptivePID(pid, body, targetAxis)
    local inertia = getEffectiveInertia(body.inertiaTensor, targetAxis)
    pid.Kp = baseKp / inertia  -- 转动惯量越大，P增益越小
end
]]

----  SERVER  ----

function FlightControlSystem_LF.server_onCreate(self)
    -- 确定载具主体
    local child = self.interactable:getChildren(sm.interactable.connectionType.data)[1]
    self.main_body = child and child:getShape():getShapeUuid() == sm.uuid.new("38fe2119-f676-4e4f-b1bf-139344d03a8c") and child.body or self.shape.body
    
    -- 数据记录
    self.pre_vel = self.main_body.velocity
    self.integral_vel = sm.vec3.zero()
    self.integral_pos = sm.vec3.zero()
    
    --self.inertialTensor = self:CalculateMomentOfInertia(self.main_body)
    
    -- 载具id
    self.id = self.main_body:getCreationId()

    for _, theBody in pairs(self.shape.body:getCreationBodies()) do
    end

    -- test
    self.test_pos = self.main_body.centerOfMassPosition + sm.vec3.new(0, 0, 3)


    sm.gui.chatMessage("FlightControlSystem_LF Created")
end

function FlightControlSystem_LF.server_onFixedUpdate(self, timeStep)
    -- 更新载具主体
    local child = self.interactable:getChildren(sm.interactable.connectionType.data)[1]
    self.main_body = child and child:getShape():getShapeUuid() == sm.uuid.new("38fe2119-f676-4e4f-b1bf-139344d03a8c") and child.body or self.shape.body

    -- 载具更新
    if self.id ~= self.main_body:getCreationId() then
        self.inertialTensor = self:CalculateMomentOfInertia(self.main_body)
        sm.gui.chatMessage("update")
        self.id = self.main_body:getCreationId()
    end

    self.vel = self.main_body.velocity
    self.acceleration = (self.vel - self.pre_vel) / timeStep
    self.pre_vel = self.vel

    self.pos = self.main_body.centerOfMassPosition

    local impulse_gravity = sm.vec3.new(0, 0, sm.physics.getGravity() * 0.02618734925)
    --local impulse_vel = self:PID_vel(self, timeStep, sm.vec3.new(0, 0, 0), 23, 19, 0.3)
    --local impluse = impulse_gravity + impulse_vel
    local impulse_pos = self:PID_pos(self, timeStep, self.test_pos, 7, 5.7, 0.15)
    local impluse = impulse_gravity + impulse_pos

    for _, theBody in pairs(self.main_body:getCreationBodies()) do
        sm.physics.applyImpulse(theBody, impluse * theBody:getMass(), true)
    end
end

function FlightControlSystem_LF.server_onDestroy(self)
    sm.gui.chatMessage("FlightControlSystem_LF Destroy")
end