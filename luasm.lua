------Component------
Component = {name = "component", behavior = nil, ports = {}}

function Component:new (o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function Component:start()
    self.behavior:onEntry()
end

function Component:stop()
    self.behavior:onExit()
end
----End Component----

------Atomic State------
AtomicState = {name = "atomic state", outgoing = nil, nbOutgoing = 0}--fixme: do not pass array size

function AtomicState:new (o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function AtomicState:onEntry()
	--by default, do nothing
end

function AtomicState:onExit()
	--by default, do nothing
end

function AtomicState:handle(event)
    print("debug " .. event.name)
    for i=1, self.nbOutgoing do
        if (self.outgoing[i].eventType.name == event.name and self.outgoing[i].eventType.port == event.port) then
	    print("debug2 " .. event.name)
	    return self.outgoing[i]:trigger(event), true
	end
    end
    return self, false
end
----End Atomic State----



------Composite State------
CompositeState = AtomicState:new{name = "composite state", regions = nil, nbRegion = 0}--fixme: do not pass array size

function CompositeState:new (o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function CompositeState:handle(event)
    for i=1, self.nbRegion do
        self.regions[i]:handle(event)
    end
end

function CompositeState:onEntry()
    --print(tostring(self.nbRegion))
    --print(self.regions)
    AtomicState.onEntry()
    for i=1, self.nbRegion do
        self.regions[i]:onEntry()
    end
end

function CompositeState:onExit()
    AtomicState.onExit()
    for i=1, self.nbRegion do
        self.regions[i]:onExit()
    end
end
----End Composite State----



------Region------
Region = {name = "region", initial = nil, keepHistory = false, current = initial, states = nil}--fixme: current = initial not working

function Region:new (o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function Region:onEntry()
    if (not self.keepHistory) then
        self.current = self.initial
    end
    self.current.onEntry()
end

function Region:onExit()
    self.current.onExit()
end

function Region:handle(event) 
    next, isHandled = self.current:handle(event);
    self.current = next
    return isHandled
end
----End Region----



------Event------
Event = {name = "default", port = nil, nbParam = nil, params = nil}

function Event:new (o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function Event:create(params)
    return Event:new{name = self.name, port = self.port, nbParam = self.nbParam, params = params}
end
----End Event----



------Handler------
Handler = {name = "handler", eventType = nil, source = nil}

function Handler:new (o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function Handler:init()
    if (self.source.outgoing == nil) then
        self.source.outgoing = {self}
    else
        table.insert(self.source.outgoing, self)
    end
    self.source.nbOutgoing = self.source.nbOutgoing + 1
    return self
end

function Handler:check(event)
    return event.name == self.eventType.name and event.port == self.eventType.port
end

function Handler:trigger(event)
    --by default, do nothing
end

function Handler:execute(event)
    --by default, do nothing
end
----End Handler----



------Transition------
Transition = Handler:new{name = "transition", target = nil}

function Transition:new (o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function Transition:trigger(event)
    print("debug3 " .. event.name)
    self.source:onExit()
    self:execute(event)
    self.target:onEntry()
    return self.target
end
----End Transition----





------Test------
A = AtomicState:new{name = "A"}
A.onEntry = function()
	print "A.onEntry"
end
A.onExit = function()
	print "A.onExit"
end

B = AtomicState:new{name = "B"}
B.onEntry = function()
	print(B.name .. ".onEntry")
end
B.onExit = function()
	print(B.name .. ".onExit")
end



C = AtomicState:new{name = "C"}
C.onEntry = function()
	print "C.onEntry"
end
C.onExit = function()
	print "C.onExit"
end

D = AtomicState:new{name = "D"}
D.onEntry = function()
	print(D.name .. ".onEntry")
end
D.onExit = function()
	print(D.name .. ".onExit")
end

--Event types
E1 = Event:new{name = "t", port = "p", nbParam = 3}
E2 = Event:new{name = "t", port = "p2", nbParam = 0}
E3 = Event:new{name = "t2", port = "p", nbParam = 1}


T = Transition:new{name = "T", source = A, target = B, eventType = E1}:init()
function T:execute(event) 
    if (event.params[2]) then
        print("execute T true " .. event.params[1] .. " " .. event.params[3]) 
    else
       	print("execute T false " .. event.params[1] .. " " .. event.params[3]) 
    end
end

T3 = Transition:new{name = "T3", source = C, target = D, eventType = E2}:init()
function T3.execute(event) print "execute T3" end

T2 = Transition:new{name = "T2", source = B, target = A, eventType = E1}:init()
function T2.execute(event) print "execute T2" end

T4 = Transition:new{name = "T4", source = D, target = C, eventType = E3}:init()
function T4.execute(event) print "execute T4" end


R = Region:new{name = "R", initial = A, current = A, states = {A, B}}

R2 = Region:new{name = "R2", initial = C, current = C, states = {C, D}}

CS = CompositeState:new{name = "C", regions = {R, R2}, nbRegion = 2}

--Events
e1 = E1:create({"a", true, 0})
e2 = E1:create({"a", false, -1})
e3 = E2:create({})
e4 = E3:create({3.14})
e5 = E1:create({"a", false, -3})

CS:onEntry()
--T.execute(e1)
CS:handle(e1)
CS:handle(e2)
CS:handle(e3)
CS:handle(e4)
CS:handle(e5)
----End Test----
