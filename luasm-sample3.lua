module("luasm-sample1", package.seeall)
require "luasm"
------Test------
print("Start " .. collectgarbage("count"));

local A = luasm.AtomicState:new{name = "A"}
function A:onEntry() --ThingML attributes/functions can be accessed via self.component
	local component = self.component
	print("A.onEntry " .. component.count)
	component.count = component.count + 1 
end
function A:onExit()
	print "A.onExit"
end

local B = luasm.AtomicState:new{name = "B"}
function B:onEntry()
	print("B.onEntry")
	self.component:addSession(Comp:new{count = self.component.count})
end
function B:onExit()
	print(B.name .. ".onExit")
end

local T = luasm.Transition:new{name = "T", source = A, target = B, eventType = luasm.NullEvent}:init()--should be triggered unconditionally (NullEvent)
function T:execute(event) 
		print("execute T") 
end
function T:check(event)
	local component = self.source.component
	return luasm.Handler.check(self, event) and (component.count < 10)
end

local R = luasm.Region:new{name = "R", initial = A, states = {A, B}}

local CS = luasm.CompositeState:new{name = "CS", regions = {R}}
function CS:executeOnEntry()
	print "CS.onEntry"
end
function CS:executeOnExit()
	print "CS.onExit"
end

Comp = luasm.Component:new{name = "Cpt", behavior = CS, count = 0}:init() --count is a ThingML attribute

collectgarbage("collect")
print("After init " .. collectgarbage("count"));

Comp:start()
Comp:stop()
Comp:kill()

collectgarbage("collect")
print("After kill " .. collectgarbage("count"));
print("stop")
----End Test----