module("luasm", package.seeall)
------Component------
Component = {name = "default", on = false, terminated = false, behavior = nil, sched = nil, connectors = {}, sessions = {}, root = nil}

function Component:new (o)
	o = o or {}
	setmetatable(o, self)
	self.__index = self
	return o
end

function Component:addSession(session)
	session.root = self
	session.connectors = self.connectors
	session.sessions = {}
	table.insert(self.sessions, session)
	session:init():start()
end

function Component:removeSession(session)
	if (session.root == self) then
		local index = -1
		for i, s in ipairs(self.sessions) do
			if s == session then
				index = i
				break
			end
		end
		if (index ~= -1) then
			session:kill()
			table.remove(sessions, index)
			session = nil
		else
			error("Cannot find session " .. session.name .. " within component " .. self.name)
		end
	else
		error("Cannot remove session " .. session.name .. " as it is not contained by component " .. self.name)
	end
end

function Component:receive(port, event)
	event.port = port
	coroutine.resume(self.sched, event)
	for i, session in ipairs(self.sessions) do
		session:receive(port, event)
	end
	event = nil	
end

function Component:send(port, event)
	for i, callback in pairs(self.connectors[port]) do
		callback(event)
	end      	
end

function Component:init()
	self.behavior:init(self)
	self.sched = coroutine.create(function(event) --returns true if terminated (reach a final state), false otherwise
		while self.on do
			local next, consumed = self.behavior:handle(event)  
			while(consumed) do
				next, consumed = self.behavior:handle(NullEvent)
			end
			event = coroutine.yield()
		end
	end)
	self.on = true
	return self
end

function Component:start()
	self.behavior:onEntry()  
	repeat
		local next, consumed = self.behavior:handle(NullEvent)  
	until(not consumed)
end

function Component:stop()
	for i, session in ipairs(self.sessions) do
		session:stop()
	end
	self.on = false
	self.sched = nil
	if (self.behavior ~= nil) then self.behavior:onExit() end
end

function Component:kill()
	print("killing " .. self.name)
	for i, session in ipairs(self.sessions) do
		session:kill()
	end
	if (self.on) then self:stop() end
	self.behavior = nil
	self.connectors = nil
	self.terminated = true
	self = nil
end
----End Component----


------Atomic State------
AtomicState = {name = "default", outgoing = nil, component = nil, region = nil, final = false}

function AtomicState:new (o)
	o = o or {}
	setmetatable(o, self)
	self.__index = self
	return o
end

function AtomicState:init(component, region)
	self.component = component
	self.region = region
end

function AtomicState:onEntry()
	self:executeOnEntry()
	if self.final then self.component:kill() end
end

function AtomicState:onExit()
	self:executeOnExit()
	if self.final then
		self.component:kill()
		error("Ooops! That should not have happened... " .. self.name .. " is final and should have terminated component " .. component.name .. " on entry.")
	end
end

function AtomicState:executeOnEntry()
	--by default, do nothing
end

function AtomicState:executeOnExit()
	--by default, do nothing
end

function AtomicState:handle(event)
	for i, handler in ipairs(self.outgoing or {}) do
		if (handler:check(event)) then
			return handler:trigger(event), true
		end
	end
	return self, false, self.final
end
----End Atomic State----


------Composite State------
CompositeState = AtomicState:new{name = "default", regions = nil}

function CompositeState:new (o)
	o = o or {}
	setmetatable(o, self)
	self.__index = self
	return o
end

function CompositeState:init(component, region)
	AtomicState:init(self, component, region)
	for i, region in ipairs(self.regions) do
		region:init(component)
	end
end

function CompositeState:handle(event)
	local isHandled = false
	for i, region in ipairs(self.regions) do
		local consumed, terminated = region:handle(event) 
		if consumed then isHandled = true end
	end
	if not isHandled then --if nothing has consumed event, it is available to the composite
		return AtomicState.handle(self, event)	
	end
	return self, isHandled
end

function CompositeState:onEntry()
	self:executeOnEntry()
	for i, region in ipairs(self.regions) do
		region:onEntry()
	end
end

function CompositeState:onExit()
	for i, region in ipairs(self.regions) do
		region:onExit()
	end
	self:executeOnExit()
end

function CompositeState:executeOnEntry()
	--by default, do nothing
end

function CompositeState:executeOnExit()
	--by default, do nothing
end
----End Composite State----


------Region------
Region = {name = "default", initial = nil, keepHistory = false, current = initial, states = nil}--fixme: current = initial not working

function Region:new (o)
	o = o or {}
	setmetatable(o, self)
	self.__index = self
	return o
end

function Region:init(component)
	self.current = self.initial
	for i, state in ipairs(self.states) do
		state:init(component, self)
	end
	return self
end

function Region:onEntry()
	if (not self.keepHistory) then
		self.current = self.initial
	end
	self.current:onEntry()
end

function Region:onExit()
	self.current:onExit()
end

function Region:handle(event) 
	local next, isHandled = self.current:handle(event);
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


------NullEvent------
NullEvent = Event:new{name = "NULL", port = "NULL", params = nil}

function NullEvent:new (o)
	o = o or {}
	setmetatable(o, self)
	self.__index = self
	return o
end

function NullEvent:create(params)
	return NullEvent
end
----End NullEvent----


------Handler------
Handler = {name = "default", eventType = nil, source = nil}

function Handler:new (o)
	o = o or {}
	setmetatable(o, self)
	self.__index = self
	return o
end

function Handler:init()
	if (self.source.final) then
		error(self.source.name .. " is a final state and cannot have outgoing transision (" .. self.name .. ")")
	end
	if (self.source.outgoing == nil) then
		self.source.outgoing = {}
	end
	table.insert(self.source.outgoing, self)
	return self
end

function Handler:check(event)
	if (self.eventType == NullEvent) then
		return event == NullEvent
	else
		return event.name == self.eventType.name and event.port == self.eventType.port
	end
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
Transition = Handler:new{name = "default", target = nil}

function Transition:new (o)
	o = o or {}
	setmetatable(o, self)
	self.__index = self
	return o
end

function Transition:trigger(event)
	self.source:onExit()
	self:execute(event)
	self.source.region.current = self.target
	self.target:onEntry()
	return self.target
end
----End Transition----
