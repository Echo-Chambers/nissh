pico-8 cartridge // http://www.pico-8.com
version 32
__lua__
--Pico-Ranger
-- GLOBAL DATA
--  --  --  --  ----  --  --  --  --  --
--  --  --  --  DATA  --  --  --  --  --
local picoranger = {}





-- -- -- MATH -- -- --
picoranger.math = {}
local pmath = picoranger.math

-- Angles

pmath.convertAngle = function(n) -- returns a value between 0 and 1 when given an angle, for PICO-8's system.
    local max = n > math.pi and 360 or 2*math.pi
    return 1/(max/90)
end

pmath.getAngleVector = function(angle)
    local quad = {{x = 1, y = 1},{x = -1, y = 1},{x = -1, y = -1},{x = 1, y = -1}}

    function findquadrant(ang)
        ang = abs(ang)
        local quadrant = (ang > 90 and flr( ang/90 )) or 1
        return quadrant
    end

    adjacent = cos(angle)*16
    opposite = tan(angle)*adjacent

    quad = quad[findquadrant(angle)]
    return {x = adjacent*quad.x, y = opposite*quad.y}
end

-- Vectors

vector = {}

pmath.applyLinearImpulse = function(vec,imp)
    local t = {}
    for k,v in pairs(vec)do
        t[k] = v + imp[k]
    end
    return t
end

vector.add = function(a,b)
    local type_a, type_b = type(a), type(b)
    local c = {}
    if(type_b == 'number')then
        for k,v in pairs(a)do
            c[k] = v + b
        end
    else
        for k,v in pairs(a) do
            c[k] = a[k] + (b[k] or 0)
        end
    end
    return c
end

vector.subtract = function(a,b)
    if(type(b) == 'number')then
        return vector.add(a,-b)
    else
        for k,v in pairs(b)do
        b[k] = -v
        end
        return vector.add(a,b)
    end
end

vector.multiply = function(a,b)
    local type_a, type_b = type(a), type(b)
    local c = {}
    if(type_b == 'number')then
        for k,v in pairs(a)do
            c[k] = v * b
        end
    else
        for k,v in pairs(a) do
            c[k] = a[k] * (b[k] or 1)
        end
    end
    return c
end

vector.divide = function(a,b)
    if(type(b) == 'number')then
        vector.multiply(a,1/b)
    elseif(type(b) == 'table')then
        local c = {}
        for k,v in pairs(b)do -- will brak without numbers
            c[k] = 1/v
        end
    end
end

vector.distance = function(a,b)
    local dist = ((abs(a.x) + abs(b.x))^2 + (abs(a.y) + abs(b.y))^2)^0.5
    return dist
end

vector.difference = function(a,b)
    local bigx = a.x >= b.x and a.x or b.x
    local bigy = a.y >= b.y and a.y or b.y
    local smallx = bigx == a.x and b.x or a.x
    local smally = bigy == a.y and b.y or a.y
    local signx = b.x < 0 and -1 or 1
    local signy = b.y < 0 and -1 or 1
    return {x = (bigx - smallx) * signx, y = (bigy - smally) * signy}
end

vector.direction = function(a,b)
    local vec = vector.difference(a,b)
    local dis = vector.distance(a,b)
    return {x = vec.x/dis, y = vec.y/dis}
end
-- -- -- GRAPHICS -- -- --

picoranger.draw_queue = {}
for n = 1, 6 do
    picoranger.draw_queue[n] = {}
end


picoranger.processDrawQueue = function()
local queue = picoranger.draw_queue
    for n = 1, #queue do
        local layer = queue[n]
        for nn = 1,#layer do
            if(layer[nn])then
                entities[layer[nn]]:drawSelf()
            end
        end
    end
end

picoranger.sprite = {}
local psprite = picoranger.sprite

psprite.getSpritePos = function(id)
    local ret = id/16
    local row = -flr(-(ret)) + (id == 0 and 1 or 0)
    local col = ((ret)-(flr(ret)))*16+1
    if(col > 16)then
        row = row + flr(col/16)
        col = (col%16)
    end
    row = 8*(row-1) -- here 8 is sprite pixel width 
    col = 8*(col-1)
    return {x =col,y =row}
end


-- -- -- TIMERS -- -- --
picoranger.timer = {}
picoranger.timer.queue = {}
ptimer = picoranger.timer

ptimer.newTimer = function(n, func, rep)
    local timer = {}
    local ind = #ptimer.queue
    timer.start = time()
    timer.finish = timer.start + n
    timer.id = ind + 1
    timer.rep = rep
    timer.action = function(self)

        if(func)then -- perform specified action
            func()
        end

        if self.rep and self.rep > 0 then -- check for repeater and refresh timer if persist
        self.start = time()
        self.finish = self.start + n
        self.rep = self.rep - 1
        else ptimer.queue[self.id] = nil end -- else finally remove the timer
    return true
    end

    ptimer.queue[ind+1] = timer
    return ind
end

function ptimer:processQueue()
    local queue = self.queue
    for n = 1, #queue do
        local timer = queue[n]
        local is_due = timer and (timer.finish <= time()) and timer:action()
    end
end

-- -- -- ENTITY MANAGEMENT -- -- --
entities = {}
entity = {
    form = 'none',
    visual = 'sprite',
    visualprops = {spriteid = 1, layer = 1},
    position = {x = 110, y = 110},
    velocity = {x = 0, y = 0},
    action = '',

}

function entity:new(o)
    o = o or {}
    setmetatable(o,self)
    self.__index = self
    local num = #entities + 1
    entities[num] = o
    local layer = o.visualprops.layer
    local layerpos = #picoranger.draw_queue[layer] + 1
    picoranger.draw_queue[o.visualprops.layer][layerpos] = num
    return o
end


--[[------------------------DRAWING------------------------]]


function entity:drawSelf()
    local visual = self.visual
    local props = self.visualprops
    local pos = self.position

    if(visual == 'sprite' and props.spriteid)then
        spr(props.spriteid,pos.x, pos.y)
    elseif(visual == 'sprites' and props.spriteid)then
        local range_w = props.sprange_w
        local range_h = props.sprange_h
        local spos = psprite.getSpritePos(props.spriteid)
        local dir = self.velocity.x > 0
        sspr(spos.x, spos.y, range_w, range_h, pos.x, pos.y,16,16,not dir)
        pset(pos.x, pos.y, 8)
    end
end

function entity:animateSelf()
    local visual = self.visual
    local props = self.visualprops
    local aprops = self.animprops
    local action = self.action
    local anim = aprops.current
    if(aprops[action])then
        if(anim.name)then
            anim.frame = anim.frame + 1 <= #aprops[anim.name] and anim.frame + 1 or 1
            props.spriteid = aprops[anim.name][anim.frame]
        else
            anim.name = action
            anim.frame = 1
        end
    end
    
end


--[[------------------------LOGIC------------------------]]


function entity:act(action) -- oh boy...
    if(action and type(action) == 'string')then
        self.action = self.possible_actions[action] and action or ''
    end
end

function entity:think() -- change ridiculously pretentious name
    local form = self.form
    if(form ~= 'player')then

    else
        --local controlmap = self:getControls()
        
    end
end


--[[------------------------PLAYER------------------------]]

function entity:getControls()
    local controlmap = {}
    for n = 0, 5 do
        controlmap[n] = btn(n)
    end
    return controlmap
end

--[[------------------------MOTION------------------------]]

function entity:setVelocity(vel)
    self.velocity = vel
end

function entity:move()
    if(self.position and self.velocity)then

        local bounds = {x = 128 - 16, y = 128 - 16}
        local addedvel = vector.add(self.position,self.velocity)
        local inxbound = addedvel.x > 0 and addedvel.x < bounds.x
        local inybound = addedvel.y > 0 and addedvel.y < bounds.y

        if(inxbound and inybound)then
        self.position = addedvel
        end
    end
end

-- -- -- DUNGEONBUILDING -- -- --



--[[------------------------DUNGEONS------------------------]]


picoranger.dungeon = {} -- table for all dungeon-related data
pdungeon = picoranger.dungeon
pdungeon.dungeons = {} -- hold list of registered dungeons, will rename

--[[------------------------FLOORS------------------------]]


pdungeon.floor = { -- basically dungeons, they hold a bunch of rooms that form a 'floor' of a dungeon.
    max_room_count = 10,
    width = 128,
    height = 128,
    rooms = {},
    position = {x = 999, y = 999}
}
floor = pdungeon.floor

function floor:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function floor:newRoom(o)
    local room = room:new(o)
    local id = #self.rooms + 1
    room.id = id
    room.position = {x = rnd(128), y = rnd(128)}
    local dq = 0
    local admit = false
    local bounds = room:checkBounds()
    for n = 1, #bounds do
        local integer = 0
        for nn = 1, #bounds[n] do

            if(v == true)then
                dq = dq + 1
            end
        end
    end

    if(dq < 3)then
        self.rooms[id] = room
    end
end

function floor:placeRoom(room)
    local w, h = room.width, room.height

end

--[[------------------------ROOMS------------------------]]--
bounds_enum = {'xmin','xmax','ymin','ymax'}
pdungeon.room = { -- the things players walk around and fight in. Many of these comprise a floor.
    width = 16,
    height = 16,
    id = 0,
    floor = 1,
    position = {x = 0,y = 0},
    center = {},
}
room = pdungeon.room

function room:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function room:getBounds() -- returns a boundtable containing min/max values for the room's area
    local w, h = self.width, self.height
    local x, y = self.position.x, self.position.y
    local bounds = {
        id = self.id,
        x,
        x + w,
        y,
        y + h 
    }
    return bounds
end

function room:checkBounds()
    local bounds = self:getBounds()
    local floor = self.floor
    local rooms = pdungeon.dungeons['test'][self.floor].rooms
    local infractions = {}
    local room = self:getBounds()
    for n = 1, #rooms do
        local room2 = rooms[n]:getBounds()
        local data = {
            --id = room2.id,
            room[1] >= room2[1] and room[1] <= room2[2],
            room[2] <= room2[2] and room[2] >= room2[1],
            room[3] >= room2[3] and room[3] <= room2[4],
            room[4] <= room2[4] and room[4] >= room2[3],
        }
        add(infractions, data)
    end
    return infractions
end
--  --  --  --  DATA  --  --  --  --  ----  --  --  --  ----  --  --  --  ----  --  --  --  ----  --  --  --  --
--  --  --  --  ----  --  --  --  --  ----  --  --  --  ----  --  --  --  ----  --  --  --  ----  --  --  --  --
--  --  --  --  ----  --  --  --  --  ----  --  --  --  ----  --  --  --  ----  --  --  --  ----  --  --  --  --
--  --  --  --  ----  --  --  --  --  ----  --  --  --  ----  --  --  --  ----  --  --  --  ----  --  --  --  --
--  --  --  --  ----  --  --  --  --  ----  --  --  --  ----  --  --  --  ----  --  --  --  ----  --  --  --  --
--  --  --  --  ----  --  --  --  --  ----  --  --  --  ----  --  --  --  ----  --  --  --  ----  --  --  --  --


--poke(0x5f2c,3) -- 64x64 resolution
local pp = {x = 0, y = 0}
local n = 0
local timertime = 0
local timertime2 = 0


function _init()
--poke(0x5f2d,1) -- devtools
    
    rands = {}
    for n = 1, 1000 do
        rands[n] = rnd(50)
    end

    cls()
    local poses = {
    {x = 32, y = 32},
    {x = 64, y = 32},
    {x = 43, y = 40},
    {x = 23, y = 26},
    {x = 44, y = 33},
    {x = 33, y = 9}
    }
    local classsprites = {
        {6,8,10,12,14},
        {102,104,106,108,110},
        {38,40,42,44,46}
    }
    for n = 1, #poses do
        poses[n].y = poses[n].y
    local cleric = {
        form = 'player',
        visual = 'sprites',
        position = poses[n],
        action = 'idle',
        visualprops = {spriteid = 006, sprange_w = 16, sprange_h = 16, layer = 1},
        animprops = {current = {name = nil, frame = 1}, idle = classsprites[n<=2 and 2 or n <= 4 and 3 or 1]}
    }
    entity:new(cleric)
    end
    -- DUNGEONTEST
    pdungeon.dungeons['test'] = {floor:new()}
    local floor = pdungeon.dungeons['test'][1]
    for n = 1, 20 do
        floor:newRoom()
    end
    -- DUNGEONTEST
end


function _update()
    --[[cleric = psprite.getSpritePos(102+(n*2))
    timertime = timertime + 1 < 4 and timertime + 1 or 0
    if(timertime == 3)then
        timertime2 = timertime2 + 1 < 9 and timertime2 + 1 or 0
        ptimer:processQueue()
        for n = 1, #entities do
            local pos = entities[n].position
            if(timertime2 == 8) then
                entities[n]:setVelocity(vector.multiply({x = rnd(10)/10, y = rnd(10)/10},rnd(50) > 25 and -1 or 1))
            end
            entities[n]:animateSelf()
            entities[n]:move()

        end
    end]]
    --updating mouse
    --pp.x = stat(32)
    --pp.y = stat(33)
    -----------------
end


function _draw()
    cls()

    

    -- Dungeondrawing test
    --[[rectfill(0,0,128,128,3)


    for n = 0, 15 do
        for nn = 0, 15 do
            local idx = rands[(nn*n)]
            spr(idx and ((idx < 21 and 33) or (idx < 25 and 35) or (idx < 34 and 34)) or 16,8*nn,8*n)
        end
    end]]

    local dungeons = pdungeon.dungeons
    local forest = dungeons['test']
    local floor = forest[1]
    local rooms = floor.rooms
    for n = 1, #rooms do
        local room = rooms[n]
        local pos = room.position
        local corner = {x = pos.x + room.width, y = pos.y + room.height}
        color(8)
        rect(pos.x, pos.y, corner.x, corner.y)
    end
    -- Dungeondrawing test
    

    -- DRAWQUEUE
    --picoranger.processDrawQueue()
    -- DRAWQUEUE


    -- TEXTUAL DEV DATA
    color(5)
    print('time: ' .. time())
    print('timer Queue Count: ' .. #ptimer.queue)
    --print('entity Count: '.. #entities)
    print('dungeon count: '..#pdungeon.dungeons)
    --print(entities[1].visualprops.spriteid)
    print('vectest: '..vector.direction({x = 0, y = 0},{x = -10, y = -10}).x)
    --print('vv: '.. tostring(entities[1].velocity.x > 0))


    for n = 1, #pdungeon.dungeons['test'][1].rooms do
        local room = pdungeon.dungeons['test'][1].rooms[n]
        --print('room at: '.. room.position.x .. '<>'..room.position.y)
        --print(room:checkBounds()[2].ymax)
    end
    print('roomct: '..#pdungeon.dungeons['test'][1].rooms)
    -- TEXTUAL DEV DATA
    --[[print(n)
    print(atan2(64-pp.x, 64-pp.y)*360)]]
end
__gfx__
00000000666666660000000770000000111111110000000000000066660000300000006666000300000000666600300000000066660003000000006666000030
00000000600000060000077777700000177661610000000000000666f66003b300000666f6603b3000000666f663b30000000666f6603b3000000666f66003b3
0070070060000006000077777777000016666161000000000000066ff66003b30000066ff6603b300006666ff663b3000000066ff6603b300000066ff66003b3
0007700060000006000777777777700011111111000000000000066f660005b50000666f66005b500066606f6605b5000006666f66005b500000066f660005b5
0007700060000006000977777777900017617761000000000000661ff10000500006601ff10005000660001ff10050000066601ff10005000000661ff1000050
00700700600000060099997777999900166166610000000000666921221000400666092122120400660009212212400006600921221004000066692122100040
00000000600000060099999999999900166166610000000006669221221204006660922122122f000000922122222f0006009221221204000666922122120400
0000000066666666099999999999999011111111000000000609222222222f00600922222222240000092222222224000009222222222f000609222222222f00
00000000000000000999999999999990111111111111111100922212212224000009221221220400009222122122040000092212212224000009221221222400
00000000000000000999999999999990177661666617766600922222222204000092222222200400092222222200040000922222222204000092222222220400
00000000000000000aaa99999999aaa0166661666616666600922122122040000092212212204000092221221200040009222122122004000092212212204000
000000000000000000aaaaa99aaaaa00111111111111111100992222229040000092222222904000922222222200040009222222229004000092222222904000
000000000000000000aaaaaaaaaaaa00176177666677176600092222990040000922222299004000922222229900040009222222990004000922222299004000
0000000000000000000aaaaaaaaaa000166166666666167600092299020400000922229902050000099222992000500009222299200040000922229902040000
000000000000000000000aaaaaa00000166166666666166600009940040500000099994404050000000999044400500000999902440050000099994004050000
00000000000000000000000aa0000000111111111111111100000044044500000000000004400000000000004400000000000004400050000000004404450000
00000000000000000000000000000000000000000004400000000055000000000000005500000000000000550000000000000055000000000000005500000000
00000000000000000000000000000000000000000044440000000555500000000000055550000000000005555000006000000555500000000000055550000000
000000000000000000000000000000000000000000555500000055ff50000000000055ff50000060000055ff50000786000055ff50000060000055ff50000000
00000000000000000000000000000000000000000444444000005fff5000006000005fff5000078600005fff5000077600005fff5000078600005fff50000060
000000000000000000055000000000000500055005555550000055f500000786000055f500000776000055f500007660000055f500000776000055f500000786
0000000000b00000005555000000000055505555044444400000122f210007760000122f210076600000122f2107600000001222210076600000122f21000776
000000000b00b0000555550000000000050055555555555500011122111076600001112211176000000111161176000000011122110760000001112211107660
000000000b0b00b005555550055000500500555544444444000111111117600000011116117600000001116f6760000000011116117600000001111111176000
000000000000000022d22d2200000000000000005555555500001116117600000000116f6760000000001117f60000000000116f176000000000111611760000
00000000000000002dddddd20000000000044000444444440000016f6760000000000116f6000000000001761000000000000111660000000000016f67600000
0000000000000000dd2222dd00000000045445405555595500000116f60000000000011760000000000007611000000000000117f000000000000116f6000000
00000000000000002d2222d200000000445445444444499400000117600000000000017610000000000076111000000000000176100000000000011760000000
00000000000000002d2222d200800000999a99995555559500000176100000000000076110000000000761111000000000000761100000000000017610000000
0000000000000000dd2222dd00b009004459a5444444494400000761100000000000761110000000000011511000000000007615100000000000076110000000
00000000000000002dddddd280b00bc0445445445555555500007611100000000007651110000000000011051000000000076110500000000000761110000000
000000000000000022d22d22bbbbbbbb045445404444444400076550550000000000005055000000000000055000000000000055000000000007655055000000
00000077000000770000000700000000000000000000000000000aaa000000000000000000000000000000000000000000000000000000000000000000000000
0000076600000760000000700000000000000000000000000000afaaa00000000000000000000000000000000000000000000000000000000000000000000000
0000766000007600000006000000000000000000000000000000affaa00000900000000000000000000000000000000000000000000000000000000000000000
050766000007600000066000000000000000000000000000000affaa000006090000000000000000000000000000000000000000000000000000000000000000
055660000256000005666000000000000000000000000000000aafa0000060040000000000000000000000000000000000000000000000000000000000000000
00450000002500000056000000000000000000000000000000a399a9300600040000000000000000000000000000000000000000000000000000000000000000
040550000202000005050000000000000000000000000000003339933b6000440000000000000000000000000000000000000000000000000000000000000000
4000000020000000500000000000000000000000000000000033333ff6b055400000000000000000000000000000000000000000000000000000000000000000
44000000044000000900000000000000000000000000000000a33333633450000000000000000000000000005000000000000000000000000000000000000000
60440000400440009004900000000000000000000000000000aa333600ff40000000000000000000000000000000000000000000000000000000000000000000
060040006000040064400a0000000000000000000000000000aa3363055004000000000000000000000000000000000000000000000000000000000000000000
0060040006000040060000900000000000000000000000000aa02622250000600000000000000000000000000000000000000000000000000000000000000000
00060040006000400060004000000000000000000000000000009202440000070000000000000000000000000000000000000000000000000000000000000000
00006040000600040006040000000000000000000000000000022944420000000000000000000000000000000000000000000000000000000000000000000000
00000604000060040000640900000000000000000000000000055000220000000000000000000000000000000000000000000000000000000000000000000000
00000064000006400000069000000000000000000000000000055500555000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000004400000000000000440000000000000044000000000000004400000000000000440000000
00000000000000000000000000000000000000000000000000000044440000000000004444000000000000444400000000000044440000000000004444000000
0000000000000000000000000000000000000000000000000000044ff40000000000044ff400000000000444f400000000000444f40000000000044ff4000000
000000000000000000000000000000000000000000000000000004fff4000000000004fff400000000000444f400000000000444f4000000000004fff4000000
0000000000000000000000000000000000000000000000000000044f404000000000044f404000000000044f404000000000044f404000000000044f40400000
00000000000000000000000000000000000000000000000000004755f570000000004755f570000000000475f570000000000445f570000000004755f5700000
00000000000000000000000000000000000000000000000000007775577700000000777557770000000044755770000000004445577000000000777557770000
00000000000000000000000000000000000000000000000000007777777700000000777777770000000004777770000000000447777000000000777777770000
00000000000000000000000000000000000000000000000000004775f577000000004775f5770000000004775f500000000004475f50000000004775f5770000
00000000000000000000000000000000000000000000000000004475f570000000004475f57000000000047755500000000004475f50000000004475f5700000
00000000000000000000000000000000000000000000000000004477760000000000447776000000000004777700000000000447770000000000447776000000
00000000000000000000000000000000000000000000000000004466660000000000446666000000000004666600000000000466660000000000446666000000
00000000000000000000000000000000000000000000000000000466660000000000046666000000000000666600000000000066660000000000046666000000
00000000000000000000000000000000000000000000000000000066660000000000006666000000000000055600000000000066660000000000006666000000
00000000000000000000000000000000000000000000000000000066660000000000005566000000000000066600000000000066550000000000006666000000
00000000000000000000000000000000000000000000000000000055055000000000000005500000000000005500000000000005500000000000005505500000
__map__
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
6667666766676667000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
7677767776777677000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2020202020202020202020202020202000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
001000000051000510005000050000510005100050000500005100051000500005000051000510005000050000510005100050000500005100051000500005000051000510005000050000510005100050000500
001000000050000500000000050006510065100551009500055000000000000000000000000000000000000000000000000000000000065100651005510005000000000000000000000000000000000000000000
001000000101001010000000000001010010100000000000010100201000000000000101001010000000000001010020100000000000020100201000000000000101001010000000000001010020100000000000
__music__
00 00010244

