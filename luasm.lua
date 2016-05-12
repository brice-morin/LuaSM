--package.preload['luasm'] = function()
	module("luasm", package.seeall)
	------Component------
	Component = {name = "component", on = false, behavior = nil, sched = nil, connectors = {}}

	function Component:new (o)
		o = o or {}
		setmetatable(o, self)
		self.__index = self
		return o
	end

	function Component:receive(port, event)
		event.port = port
		coroutine.resume(self.sched, event)
	end

	function Component:send(port, event)
		local connectors = self.connectors[port]
		for i = 1, #connectors do
			connectors[i](event)
		end      	
	end

	function Component:init()
		self.behavior:init(self)
		self.sched = coroutine.create(function(event)
			while self.on do
				local next, consumed = self.behavior:handle(event)  
				--if (next.final) then
					--return
				--end
				coroutine.yield()
			end
		end)
		self.on = true
		return self
	end

	function Component:start()
		self.behavior:onEntry()  
	end

	function Component:stop()
		self.on = false
		self.sched = nil
		self.behavior:onExit()
	end

	function Component:kill()
		if (not self.on) then
			self:stop()
		end
		self.behavior = nil
		self.connectors = nil
	end
	----End Component----


	------Atomic State------
	AtomicState = {name = "atomic state", outgoing = nil, component = nil, final = false}

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
			local handler = self.outgoing[i]
			if (handler:check(event)) then
				return handler:trigger(event), true
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
			local region = self.regions[i]
			for j=1, #region.states do
				region.states[j]:init(component)
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
--end