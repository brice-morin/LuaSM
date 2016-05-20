# LuaSM
UML-like State Machine (including composites, concurrent regions, etc) for Lua

## Hello World

```lua
require "luasm"
------Test------
-- Create a State A
local A = luasm.AtomicState:new{name = "A"}
function A:executeOnEntry() --on entry/exit actions are defined like this
  print("hello")
end
function A:executeOnExit()
	print("bye")
end

-- Create a State B
local B = luasm.AtomicState:new{name = "B"} -- on entry/exit are optional

-- Create a Transition between A and B
local T = luasm.Transition:new{name = "T", source = A, target = B, eventType = luasm.NullEvent}:init()
function T:execute(event) --actions on transitions are defined like this
		print("executing transition") 
end

local R = luasm.Region:new{name = "R", initial = A, states = {A, B}}
local CS = luasm.CompositeState:new{name = "CS", regions = {R}} --root state machine

local Comp = luasm.Component:new{name = "Cpt", behavior = CS}:init():start()
```

## Define some properties in the component

Let's say you want your component to define a property `count`:

```lua
local Comp = luasm.Component:new{name = "Cpt", behavior = CS, count = 0}:init():start()
```

You can then access this property from a state:
```lua
function A:executeOnEntry()
  local component = self.component
  print("hello " .. component.count)
  component.count = component.count + 1
end
```

Or from a transition:
```lua
function T:execute(event)
    local component = self.source.component
		print("executing transition " .. component.count) 
end
```

## Communication among components

State machines are wrapped into lightweight components. Component can communicate through message passing. 

First, define a message (or event) type:

```lua
--TODO
```

TODO
