local ffi = require("ffi")

ffi.cdef[[
    typedef struct {
        float x, y;
        uint8_t r, g, b, a;
    } Vertex;

    typedef struct {
        float x, y, z;
        float vx, vy, vz;
    } Entity3D;
]]

RLengine = {
    _VERSION = "1.5",
    count = 0,
    maxCount = 2000000,
    fov = 450,
    bounds = {w = 1280, h = 720},
    cam = {x = 0, y = 0, z = -400},
    light = {x = 0, y = 0, z = 100}
}

function RLengine.init(w, h)
    RLengine.bounds.w = w or love.graphics.getWidth()
    RLengine.bounds.h = h or love.graphics.getHeight()

    local vSize = ffi.sizeof("Vertex")
    local eSize = ffi.sizeof("Entity3D")

    RLengine.data = love.data.newByteData(vSize * RLengine.maxCount)
    RLengine.entityData = love.data.newByteData(eSize * RLengine.maxCount)

    RLengine.ptr = ffi.cast("Vertex*", RLengine.data:getFFIPointer())
    RLengine.entities = ffi.cast("Entity3D*", RLengine.entityData:getFFIPointer())

    local layout = {
        {"VertexPosition", "float", 2},
        {"VertexColor", "byte", 4}
    }

    RLengine.mesh = love.graphics.newMesh(layout, RLengine.maxCount, "points", "stream")
    RLengine.addEntities(500000)
end

function RLengine.addEntities(amount)
    local target = math.min(RLengine.maxCount, RLengine.count + amount)
    local entities = RLengine.entities

    for i = RLengine.count, target - 1 do
        local e = entities[i]
        e.x = math.random(-800, 800)
        e.y = math.random(-500, 500)
        e.z = math.random(50, 1500)
        e.vx = math.random(-100, 100)
        e.vy = math.random(-100, 100)
        e.vz = math.random(-100, 100)
    end

    RLengine.count = target
end

function RLengine.removeEntities(amount)
    RLengine.count = math.max(0, RLengine.count - amount)
end

function RLengine.update(dt)
    local count = RLengine.count
    if count == 0 then return end

    local ptr = RLengine.ptr
    local entities = RLengine.entities

    local cx = RLengine.bounds.w * 0.5
    local cy = RLengine.bounds.h * 0.5
    local fov = RLengine.fov

    local camX, camY, camZ = RLengine.cam.x, RLengine.cam.y, RLengine.cam.z

    local mx, my = love.mouse.getPosition()
    local lx = (mx - cx) * 1.5 + camX
    local ly = (my - cy) * 1.5 + camY
    local lz = RLengine.light.z

    local isLmb = love.mouse.isDown(1)
    local damp = 1 - dt * 0.15

    if isLmb then
        local forceBase = 8000000 * dt
        for i = 0, count - 1 do
            local e = entities[i]
            local v = ptr[i]

            local dx = lx - e.x
            local dy = ly - e.y
            local dz = lz - e.z
            local distSq = dx * dx + dy * dy + dz * dz + 5000
            local force = forceBase / distSq

            local vx = (e.vx + dx * force) * damp
            local vy = (e.vy + dy * force) * damp
            local vz = (e.vz + dz * force) * damp

            local x = e.x + vx * dt
            local y = e.y + vy * dt
            local z = e.z + vz * dt

            if x < -900 then x = -900; vx = -vx * 0.8 elseif x > 900 then x = 900; vx = -vx * 0.8 end
            if y < -600 then y = -600; vy = -vy * 0.8 elseif y > 600 then y = 600; vy = -vy * 0.8 end
            if z < 50 then z = 50; vz = -vz * 0.8 elseif z > 1800 then z = 1800; vz = -vz * 0.8 end

            e.x = x; e.y = y; e.z = z
            e.vx = vx; e.vy = vy; e.vz = vz

            local relZ = z - camZ
            local invZ = fov / relZ

            v.x = cx + (x - camX) * invZ
            v.y = cy + (y - camY) * invZ

            local ldx = lx - x
            local ldy = ly - y
            local ldz = lz - z
            local lDistSq = ldx * ldx + ldy * ldy + ldz * ldz

            local lightIntensity = 1.0 - (lDistSq * 0.000000444444)
            if lightIntensity < 0.1 then lightIntensity = 0.1 end

            local depthFog = 1.0 - (relZ * 0.000454545)
            if depthFog < 0 then depthFog = 0 end

            local finalBrightness = lightIntensity * depthFog

            v.r = 70 + (185 * finalBrightness)
            v.g = 120 + (135 * finalBrightness)
            v.b = 255 * finalBrightness
            v.a = 255 * depthFog
        end
    else
        for i = 0, count - 1 do
            local e = entities[i]
            local v = ptr[i]

            local vx = e.vx * damp
            local vy = e.vy * damp
            local vz = e.vz * damp

            local x = e.x + vx * dt
            local y = e.y + vy * dt
            local z = e.z + vz * dt

            if x < -900 then x = -900; vx = -vx * 0.8 elseif x > 900 then x = 900; vx = -vx * 0.8 end
            if y < -600 then y = -600; vy = -vy * 0.8 elseif y > 600 then y = 600; vy = -vy * 0.8 end
            if z < 50 then z = 50; vz = -vz * 0.8 elseif z > 1800 then z = 1800; vz = -vz * 0.8 end

            e.x = x; e.y = y; e.z = z
            e.vx = vx; e.vy = vy; e.vz = vz

            local relZ = z - camZ
            local invZ = fov / relZ

            v.x = cx + (x - camX) * invZ
            v.y = cy + (y - camY) * invZ

            local ldx = lx - x
            local ldy = ly - y
            local ldz = lz - z
            local lDistSq = ldx * ldx + ldy * ldy + ldz * ldz

            local lightIntensity = 1.0 - (lDistSq * 0.000000444444)
            if lightIntensity < 0.1 then lightIntensity = 0.1 end

            local depthFog = 1.0 - (relZ * 0.000454545)
            if depthFog < 0 then depthFog = 0 end

            local finalBrightness = lightIntensity * depthFog

            v.r = 70 + (185 * finalBrightness)
            v.g = 120 + (135 * finalBrightness)
            v.b = 255 * finalBrightness
            v.a = 255 * depthFog
        end
    end

    RLengine.mesh:setVertices(RLengine.data, 1, count)
end

function RLengine.draw()
    if RLengine.count > 0 then
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.setPointSize(2)
        RLengine.mesh:setDrawRange(1, RLengine.count)
        love.graphics.draw(RLengine.mesh)
    end

    local memMB = collectgarbage("count") / 1024
    love.graphics.setColor(0, 0, 0, 0.85)
    love.graphics.rectangle("fill", 10, 10, 460, 180)

    love.graphics.setColor(0, 1, 0.5)
    love.graphics.print("RLengine 1.5 | REVERTED & CLEAN 2.5D", 20, 20)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("FPS: " .. love.timer.getFPS() .. " (" .. string.format("%.2f", 1000 / math.max(1, love.timer.getFPS())) .. " ms)", 20, 45)
    love.graphics.print("Active 3D Entities: " .. RLengine.count .. " / " .. RLengine.maxCount, 20, 65)
    love.graphics.print("Lua Memory: " .. string.format("%.2f MB", memMB), 20, 85)
    love.graphics.print("[LMB] 3D Point Attractor", 20, 115)
    love.graphics.print("[UP / DOWN] +250k / -250k Entities", 20, 135)
    love.graphics.print("[WASD / Wheel] Camera 3D Position & FOV", 20, 155)
end

function love.load()
    love.window.setMode(1280, 720, {resizable = false, vsync = false})
    love.window.setTitle("RLengine 1.5 - Optimized 2.5D")
    RLengine.init()
end

function love.update(dt)
    local cam = RLengine.cam
    local speed = 500 * dt
    if love.keyboard.isDown("w") then cam.y = cam.y - speed end
    if love.keyboard.isDown("s") then cam.y = cam.y + speed end
    if love.keyboard.isDown("a") then cam.x = cam.x - speed end
    if love.keyboard.isDown("d") then cam.x = cam.x + speed end

    RLengine.update(dt)
end

function love.draw()
    RLengine.draw()
end

function love.wheelmoved(x, y)
    if y > 0 then
        RLengine.cam.z = math.min(-100, RLengine.cam.z + 50)
    elseif y < 0 then
        RLengine.cam.z = math.max(-1500, RLengine.cam.z - 50)
    end
end

function love.keypressed(key)
    if key == "up" then
        RLengine.addEntities(250000)
    elseif key == "down" then
        RLengine.removeEntities(250000)
    end
end