module("luasm-sample1", package.seeall)
require "luasm"
------Test------
print("Start " .. collectgarbage("count"));

local A = luasm.AtomicState:new{name = "A"}
function A:executeOnEntry() --ThingML attributes/functions can be accessed via self.component
	print("A.onEntry " .. self.component.count)
	self.component.count = self.component.count + 1
	self.component:myFunction("hello", "world")
end
function A:executeOnExit()
	print "A.onExit"
end

local B = luasm.AtomicState:new{name = "B"}
function B:executeOnEntry()
	print(B.name .. ".onEntry " .. self.component.count)
	self.component.count = self.component.count + 1
end
function B:executeOnExit()
	print(B.name .. ".onExit")
end

local C = luasm.AtomicState:new{name = "C"}
function C:executeOnEntry()
	print("C.onEntry " .. self.component.count)
	self.component.count = self.component.count + 1
end
function C:executeOnExit()
	print "C.onExit"
end

local D = luasm.AtomicState:new{name = "D"}
function D:executeOnEntry()
	print(D.name .. ".onEntry " .. self.component.count)
	self.component.count = self.component.count + 1
end
function D:executeOnExit()
	print(D.name .. ".onExit")
end

--Event types
local E1 = luasm.Event:new{name = "t", port = "p"} --ThingML messages
local E2 = luasm.Event:new{name = "t", port = "p2"}
local E3 = luasm.Event:new{name = "t2", port = "p"}


local T = luasm.Transition:new{name = "T", source = A, target = B, eventType = E1}:init()
function T:execute(event) 
	local component = self.source.component
	if (event.params.p2) then
		print("execute T true " .. event.params.p1 .. " " .. event.params.p3) 
	else
		print("execute T false " .. event.params.p1 .. " " .. event.params.p3) 
	end
	local e6 = E1:create({p1 = "zzz", p2 = true, p3 = 42})
	local e7 = E1:create({p1 = "www", p2 = false, p3 = -42})
	local e8 = E1:create({p1 = "zzz", p2 = true, p3 = 42})
	print(component.name .. " sending...")
	component:send("p", e6)
	component:send("p", e7)
	component:send("p", e8)
end

local T3 = luasm.Transition:new{name = "T3", source = C, target = D, eventType = E2}:init()
function T3:execute(event) 
	print "execute T3" 
end

local T2 = luasm.Transition:new{name = "T2", source = B, target = A, eventType = E1}:init()
function T2:execute(event) 
	print "execute T2" 
end

local T4 = luasm.Transition:new{name = "T4", source = D, target = C, eventType = E3}:init()
function T4:execute(event) 
	print "execute T4"
end


local R = luasm.Region:new{name = "R", initial = A, states = {A, B}}

local R2 = luasm.Region:new{name = "R2", initial = C, states = {C, D}}

local CS = luasm.CompositeState:new{name = "CS", regions = {R, R2}}
function CS:executeOnEntry()
	print "CS.onEntry"
end
function CS:executeOnExit()
	print "CS.onExit"
end


----------
local F = luasm.AtomicState:new{name = "F"}
function F:executeOnEntry()
	print "F.onEntry"
end
function F:executeOnExit()
	print "F.onExit"
end

local G = luasm.AtomicState:new{name = "G", final = true}
function G:executeOnEntry()
	print(G.name .. ".onEntry")
end

local T5 = luasm.Transition:new{name = "T5", source = F, target = G, eventType = E1}:init()
function T5:execute(event) 
	if (event.params.p2) then
		print("execute T5 true " .. event.params.p1 .. " " .. event.params.p3) 
	else
		print("execute T5 false " .. event.params.p1 .. " " .. event.params.p3) 
		error("the guard should have prevented that!!!!")
	end
end
function T5:check(event)
	return luasm.Handler.check(self, event) and (event.params.p2)
end

local R3 = luasm.Region:new{name = "R3", initial = F, states = {F, G}}
local CS2 = luasm.CompositeState:new{name = "CS2", regions = {R3}}
function CS2:executeOnEntry()
	print "CS2.onEntry"
end
function CS2:executeOnExit()
	print "CS2.onExit"
end
-------------

local Comp = luasm.Component:new{name = "Cpt", behavior = CS, count = 0}:init() --count is a ThingML attribute
local Comp2 = luasm.Component:new{name = "Cpt2", behavior = CS2}:init()
Comp.connectors = {
	p = { 
		Comp2 = function(event) if not Comp2.terminated then Comp2:receive("p", event) else Comp.connectors.p.Comp2 = nil end end, --Can be used as ThingML connectors
		ext = function(event) print("receive " .. event.name) end -- or to register external listeners
	}
}

function Comp:myFunction(a, b) -- ThingML function
  print("myFunction(" .. a .. ", " .. b .. ")")
end


--Events
local e1 = E1:create({p1 = "a", p2 = true, p3 = 0})
local e2 = E1:create({p1 = "a", p2 = false, p3 = -1})
local e3 = E2:create({})
local e4 = E3:create({p = 3.14})
local e5 = E1:create({p1 = "a", p2 = false, p3 = -3})

print("After init " .. collectgarbage("count"));

print("start")
Comp:start()
Comp2:start()

print("After start " .. collectgarbage("count"));



local bench = coroutine.create(function()
	for i = 1, 10 do
		print(i .. " : " .. collectgarbage("count"));
		print("========== " .. i .. " ==========")
		print("e1")
		Comp:receive("p", e1)
		print("e2")
		Comp:receive("p", e2)
		print("e3")
		Comp:receive("p2", e3)
		print("e4")
		Comp:receive("p", e4)
		print("e5")
		Comp:receive("p", e5)
		coroutine.yield()
	end
end)
while coroutine.status(bench) ~= 'dead' do
	coroutine.resume(bench)
end

--collectgarbage("collect")
print("Before stop " .. collectgarbage("count"));

Comp:stop()
--Comp2:stop()

--collectgarbage("collect")
print("Before kill " .. collectgarbage("count"));

Comp:kill()
--Comp2:kill()

collectgarbage("collect")
print("After kill " .. collectgarbage("count"));
print("stop")
----End Test----