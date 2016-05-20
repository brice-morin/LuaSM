module("luasm-sample1", package.seeall)
require "luasm"
------Test------
print("Start " .. collectgarbage("count"));

local A = luasm.AtomicState:new{name = "A"}
function A:executeOnEntry() --ThingML attributes/functions can be accessed via self.component
	print("A.onEntry")
end
function A:executeOnExit()
	print "A.onExit"
end

local B = luasm.AtomicState:new{name = "B"}
function B:executeOnEntry()
	print("B.onEntry")
end
function B:executeOnExit()
	print(B.name .. ".onExit")
end

local T = luasm.Transition:new{name = "T", source = A, target = B, eventType = luasm.NullEvent}:init()--should be triggered unconditionally (NullEvent)
function T:execute(event) 
		print("execute T") 
end

local R = luasm.Region:new{name = "R", initial = A, states = {A, B}}

local CS = luasm.CompositeState:new{name = "CS", regions = {R}}
function CS:executeOnEntry()
	print "CS.onEntry"
end
function CS:executeOnExit()
	print "CS.onExit"
end

local Comp = luasm.Component:new{name = "Cpt", behavior = CS}:init() --count is a ThingML attribute

collectgarbage("collect")
print("After init " .. collectgarbage("count"));

Comp:start()
Comp:stop()
Comp:kill()

collectgarbage("collect")
print("After kill " .. collectgarbage("count"));
print("stop")
----End Test----