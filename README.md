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
local E1 = luasm.Event:new{name = "t"} --Message type (basically just a name)
```

To create/instantiate a message:
```lua
local e1 = E1:create({p1 = "zzz", p2 = true, p3 = 42}) -- parameters can be passed in table (with arbitrary names)
```

To programmatically send a message to a component (e.g. in your "main", for testing purpose):
```lua
Comp:receive("p", e1)
```

For a component to send a message to another one, we should first add a connector/callback:
```lua
---Comp2 will be notified whenever Comp emits/sends a message on port p
Comp.connectors = {
	p = { 
		Comp2 = function(event) if not Comp2.terminated then Comp2:receive("p", event) else Comp.connectors.p.Comp2 = nil end end
	}
}
---note: it is a good idea to check that Comp2 is not "terminated" before sending something to it
```

Now in the implementation of Comp (in a state or transition):

```lua
...
component:send("p", e1) --sends message e1 (of type E1, see above) on port p
...
```

Now in the implementation of Comp2, we can define a transition that will react to that event
```lua
local T = luasm.Transition:new{name = "T", source = B, target = A, eventType = E1, port = "p"}:init()
function T:execute(event) 
	print "received!" 
end
```
