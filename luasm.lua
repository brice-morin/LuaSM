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
Component = {name = "component", on = false, behavior = nil, queue = Queue.new(), sched = nil, connectors = {}}

function Component:new (o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function Component:receive(port, event)
    event.port = port
    Queue.push(self.queue, event)
    if (self.on) then
        coroutine.resume(self.sched)
    end
end

function Component:send(port, event)
    for i = 1, #self.connectors[port] do
	self.connectors[port][i](event)
    end      	
end

function Component:init()
    self.behavior:init(self)
    self.on = false
    self.queue = Queue.new()
    return self
end

function Component:start()
    self.sched = coroutine.create(function()
        while self.on do
	    if (not Queue.empty(self.queue)) then
                local event = Queue.pop(self.queue)
          	self.behavior:handle(event)    
            else            
	        coroutine.yield()
            end
        end
    end)
    self.behavior:onEntry()
    self.on = true
    coroutine.resume(self.sched)    
end

function Component:stop()--Should we also empty/delete the queue?
    self.on = false
    self.sched = nil
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
        self.source.outgoing[#self.source.outgoing + 1] = self
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
function A:onEntry() --ThingML attributes/functions can be accessed via self.component
	print("A.onEntry " .. self.component.count)
	self.component.count = self.component.count + 1
        self.component:myFunction("hello", "world")
end
function A:onExit()
	print "A.onExit"
end

B = AtomicState:new{name = "B"}
function B:onEntry()
	print(B.name .. ".onEntry " .. self.component.count)
	self.component.count = self.component.count + 1
end
function B:onExit()
	print(B.name .. ".onExit")
end



C = AtomicState:new{name = "C"}
function C:onEntry()
	print("C.onEntry " .. self.component.count)
	self.component.count = self.component.count + 1
end
function C:onExit()
	print "C.onExit"
end

D = AtomicState:new{name = "D"}
function D:onEntry()
	print(D.name .. ".onEntry " .. self.component.count)
	self.component.count = self.component.count + 1
end
function D:onExit()
	print(D.name .. ".onExit")
end

--Event types
E1 = Event:new{name = "t", port = "p"} --ThingML messages
E2 = Event:new{name = "t", port = "p2"}
E3 = Event:new{name = "t2", port = "p"}


T = Transition:new{name = "T", source = A, target = B, eventType = E1}:init()
function T:execute(event) 
    if (event.params.p2) then
        print("execute T true " .. event.params.p1 .. " " .. event.params.p3) 
    else
       	print("execute T false " .. event.params.p1 .. " " .. event.params.p3) 
    end
    e6 = E1:create({p1 = "zzz", p2 = true, p3 = 42})
    e7 = E1:create({p1 = "www", p2 = false, p3 = -42})
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
    if (event.params.p2) then
        print("execute T5 true " .. event.params.p1 .. " " .. event.params.p3) 
    else
       	print("execute T5 false " .. event.params.p1 .. " " .. event.params.p3) 
        error("the guard should have prevented that!!!!")
    end
end
function T5:check(event)
    return Handler.check(self, event) and (event.params.p2)
end

T6 = Transition:new{name = "T6", source = G, target = F, eventType = E1}:init()
function T6:execute(event) 
    if (event.p2) then
        print("execute T6 true " .. event.params.p1 .. " " .. event.params.p3) 
    else
       	print("execute T6 false " .. event.params.p1 .. " " .. event.params.p3) 
        error("the guard should have prevented that!!!!")
    end
end
function T6:check(event)
    return Handler.check(self, event) and (event.params.p2)
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

Comp = Component:new{name = "Cpt", behavior = CS, count = 0}:init() --count is a ThingML attribute
Comp2 = Component:new{name = "Cpt2", behavior = CS2}:init()
Comp.connectors.p = {
    function(event) Comp2:receive("p", event) end, --Can be used as ThingML connectors
    function(event) print("receive " .. event.name) end -- or to register external listeners
}

function Comp:myFunction(a, b) -- ThingML function
  print("myFunction(" .. a .. ", " .. b .. ")")
end


--Events
e1 = E1:create({p1 = "a", p2 = true, p3 = 0})
e2 = E1:create({p1 = "a", p2 = false, p3 = -1})
e3 = E2:create({})
e4 = E3:create({p = 3.14})
e5 = E1:create({p1 = "a", p2 = false, p3 = -3})

--CS:onEntry()
for i = 1, 5000 do
print("========== " .. i .. " ==========")
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
end
----End Test----
