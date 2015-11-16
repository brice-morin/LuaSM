------Queue------
Queue = {}
 
function Queue.new()
    return { first = 0, last = -1 }
end
 
function Queue.push( queue, value )
    queue.last = queue.last + 1
    queue[queue.last] = value
end
 
function Queue.pop( queue )
    if queue.first > queue.last then
        return nil
    end
 
    local val = queue[queue.first]
    queue[queue.first] = nil
    queue.first = queue.first + 1
    return val
end
 
function Queue.empty( queue )
    return queue.first > queue.last
end
----End Queue----



------Component------
Component = {name = "component", behavior = nil, queue = Queue.new(), sched = nil, connectors = {}}

function Component:new (o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function Component:subscribe(port, callback)
    if (self.connectors == nil) then
	self.connectors = {}
    end
    if (self.connectors[port] == nil) then
        self.connectors[port] = {}
    end
    table.insert(self.connectors[port], callback)
end

function Component:receive(port, event)
    event.port = port
    Queue.push(self.queue, event)
    if (coroutine.status(self.sched) == "suspended") then
        coroutine.resume(self.sched)
    end
end

function Component:send(port, event)
    for i = 1, #self.connectors[port] do
	self.connectors[port][i](event)
    end      	
end

function Component:start()
    self.behavior:init(self)
    self.sched = coroutine.create(function()
        while true do
            event = Queue.pop(self.queue)
            if (not (event == nil)) then
		self.behavior:handle(event)    
            end
            if (Queue.empty(self.queue)) then
	        coroutine.yield()
            end
        end
    end)
    self.behavior:onEntry()
    coroutine.resume(self.sched)    
end

function Component:stop()
    self.behavior:onExit()
end
----End Component----



------Atomic State------
AtomicState = {name = "atomic state", outgoing = nil, component = nil}

function AtomicState:new (o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function AtomicState:init(component)
    self.component = component
end

function AtomicState:onEntry()
	--by default, do nothing
end

function AtomicState:onExit()
	--by default, do nothing
end

function AtomicState:handle(event)
    for i=1, #self.outgoing do
        if (self.outgoing[i]:check(event)) then
	    return self.outgoing[i]:trigger(event), true
	end
    end
    return self, false
end
----End Atomic State----



------Composite State------
CompositeState = AtomicState:new{name = "composite state", regions = nil}

function CompositeState:new (o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function CompositeState:init(component)
    self.component = component
    for i=1, #self.regions do
        for j=1, #self.regions[i].states do
            self.regions[i].states[j]:init(component)
        end
    end
end

function CompositeState:handle(event)
    for i=1, #self.regions do
        self.regions[i]:handle(event)
    end
end

function CompositeState:onEntry()
    self:executeOnEntry()
    for i=1, #self.regions do
        self.regions[i]:onEntry()
    end
end

function CompositeState:onExit()
    for i=1, #self.regions do
        self.regions[i]:onExit()
    end
    self:executeOnExit()
end

-- /!\ In case of composite do not redefine directly onEntry and on onExit, but rather those 2 methods /!\ --
function CompositeState:executeOnEntry()
    --by default, do nothing
end

function CompositeState:executeOnExit()
    --by default, do nothing
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
    if (not(self.keepHistory) or self.current == nil) then
        self.current = self.initial
    end
    self.current:onEntry()
end

function Region:onExit()
    self.current:onExit()
end

function Region:handle(event) 
    next, isHandled = self.current:handle(event);
    self.current = next
    return isHandled
end
----End Region----



------Event------
Event = {name = "default", port = nil, params = nil}

function Event:new (o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function Event:create(params)
    return Event:new{name = self.name, port = self.port, params = params}
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
    return self
end

function Handler:check(event)
    return event.name == self.eventType.name and event.port == self.eventType.port
end

function Handler:trigger(event)
    self:execute(event)
    return self.source
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
    self.source:onExit()
    self:execute(event)
    self.target:onEntry()
    return self.target
end
----End Transition----





------Test------
A = AtomicState:new{name = "A"}
function A:onEntry()
	print "A.onEntry"
end
function A:onExit()
	print "A.onExit"
end

B = AtomicState:new{name = "B"}
function B:onEntry()
	print(B.name .. ".onEntry")
end
function B:onExit()
	print(B.name .. ".onExit")
end



C = AtomicState:new{name = "C"}
function C:onEntry()
	print "C.onEntry"
end
function C:onExit()
	print "C.onExit"
end

D = AtomicState:new{name = "D"}
function D:onEntry()
	print(D.name .. ".onEntry")
end
function D:onExit()
	print(D.name .. ".onExit")
end

--Event types
E1 = Event:new{name = "t", port = "p"}
E2 = Event:new{name = "t", port = "p2"}
E3 = Event:new{name = "t2", port = "p"}


T = Transition:new{name = "T", source = A, target = B, eventType = E1}:init()
function T:execute(event) 
    if (event.params[2]) then
        print("execute T true " .. event.params[1] .. " " .. event.params[3]) 
    else
       	print("execute T false " .. event.params[1] .. " " .. event.params[3]) 
    end
    e6 = E1:create({"zzz", true, 42})
    e7 = E1:create({"www", false, -42})
    self.source.component:send("p", e6)
    self.source.component:send("p", e7)
end

T3 = Transition:new{name = "T3", source = C, target = D, eventType = E2}:init()
function T3:execute(event) print "execute T3" end

T2 = Transition:new{name = "T2", source = B, target = A, eventType = E1}:init()
function T2:execute(event) print "execute T2" end

T4 = Transition:new{name = "T4", source = D, target = C, eventType = E3}:init()
function T4:execute(event) print "execute T4" end


R = Region:new{name = "R", initial = A, states = {A, B}}

R2 = Region:new{name = "R2", initial = C, states = {C, D}}

CS = CompositeState:new{name = "CS", regions = {R, R2}}
function CS:executeOnEntry()
	print "CS.onEntry"
end
function CS:executeOnExit()
	print "CS.onExit"
end


----------
F = AtomicState:new{name = "F"}
function F:onEntry()
	print "F.onEntry"
end
function F:onExit()
	print "F.onExit"
end

G = AtomicState:new{name = "G"}
function G:onEntry()
	print(G.name .. ".onEntry")
end
function G:onExit()
	print(G.name .. ".onExit")
end
T5 = Transition:new{name = "T5", source = F, target = G, eventType = E1}:init()
function T5:execute(event) 
    if (event.params[2]) then
        print("execute T5 true " .. event.params[1] .. " " .. event.params[3]) 
    else
       	print("execute T5 false " .. event.params[1] .. " " .. event.params[3]) 
        error("the guard should have prevented that!!!!")
    end
end
function T5:check(event)
    return Handler.check(self, event) and (event.params[2])
end

T6 = Transition:new{name = "T6", source = G, target = F, eventType = E1}:init()
function T6:execute(event) 
    if (event.params[2]) then
        print("execute T6 true " .. event.params[1] .. " " .. event.params[3]) 
    else
       	print("execute T6 false " .. event.params[1] .. " " .. event.params[3]) 
        error("the guard should have prevented that!!!!")
    end
end
function T6:check(event)
    return Handler.check(self, event) and (event.params[2])
end
R3 = Region:new{name = "R3", initial = F, states = {F, G}}
CS2 = CompositeState:new{name = "CS2", regions = {R3}}
function CS2:executeOnEntry()
	print "CS2.onEntry"
end
function CS2:executeOnExit()
	print "CS2.onExit"
end
-------------

Comp = Component:new{name = "Cpt", behavior = CS, ports = {}, queue = Queue.new(), sched = nil}
Comp2 = Component:new{name = "Cpt2", behavior = CS2, ports = {}, queue = Queue.new(), sched = nil}
Comp.connectors.p = {function(event) print("receive") Comp2:receive("p", event) end}



--Events
e1 = E1:create({"a", true, 0})
e2 = E1:create({"a", false, -1})
e3 = E2:create({})
e4 = E3:create({3.14})
e5 = E1:create({"a", false, -3})

--CS:onEntry()
Comp:start()
Comp2:start()
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
Comp:stop()
Comp2:stop()
----End Test----
