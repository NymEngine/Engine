--!strict

local WEAK_VALUE_METATABLE = table.freeze({ __mode = "v" })

local Connection = {}
Connection.__index = Connection

type ConnectionImpl<T... = ...any> = {
	Connected: boolean,
	_Callback: ((T...) -> ())?,
	_Next: Connection<T...>?,
	_Prev: Connection<T...>?,
	_Event: { Event<T...> }?,
}

export type Connection<T... = ...any> = typeof(setmetatable({} :: ConnectionImpl<T...>, Connection))

local Event = {}
Event.__index = Event

type EventImpl<T... = ...any> = {
	_Head: Connection<T...>?,
}

export type Event<T... = ...any> = typeof(setmetatable({} :: EventImpl<T...>, Event))

function Event.New<T...>(): Event<T...>
	local self = setmetatable({
		_Head = nil,
	}, Event)
	return (self :: any) :: Event<T...>
end
Event.new = Event.New

function Event.Connect<T...>(self: Event<T...>, callback: (T...) -> ()): Connection<T...>
	assert(type(callback) == "function", "callback must be a function")

	local eventRef = setmetatable({ self }, WEAK_VALUE_METATABLE)

	local conn: Connection<T...> = setmetatable({
		Connected = true,
		_Callback = callback,
		_Next = self._Head,
		_Prev = nil,
		_Event = eventRef,
	}, Connection) :: any

	if self._Head then
		self._Head._Prev = conn
	end
	self._Head = conn

	return conn
end

function Connection.Disconnect<T...>(self: Connection<T...>)
	if not self.Connected then
		return
	end
	self.Connected = false
	self._Callback = nil

	local evt = self._Event and self._Event[1]

	if self._Prev then
		self._Prev._Next = self._Next
	elseif evt then
		evt._Head = self._Next
	end

	if self._Next then
		self._Next._Prev = self._Prev
	end

	self._Prev = nil
	-- Note: self._Next is intentionally preserved so active Fire() traversals
	-- can reach remaining nodes if a connection is disconnected mid-fire.
	self._Event = nil
end

function Event.Once<T...>(self: Event<T...>, callback: (T...) -> ()): Connection<T...>
	assert(type(callback) == "function", "callback must be a function")
	local conn: Connection<T...>
	conn = self:Connect(function(...: T...)
		conn:Disconnect()
		callback(...)
	end)
	return conn
end

function Event.Fire<T...>(self: Event<T...>, ...: T...)
	local item = self._Head
	while item do
		local nextItem = item._Next
		if item.Connected and item._Callback then
			task.spawn(item._Callback, ...)
		end
		item = nextItem
	end
end

function Event.Wait<T...>(self: Event<T...>): T...
	local thread = coroutine.running()
	local conn: Connection<T...>
	conn = self:Connect(function(...: T...)
		conn:Disconnect()
		task.spawn(thread, ...)
	end)
	return coroutine.yield()
end

function Event.DisconnectAll<T...>(self: Event<T...>)
	local item = self._Head
	while item do
		local nextItem = item._Next
		item:Disconnect()
		item = nextItem
	end
	self._Head = nil
end

function Event.Destroy<T...>(self: Event<T...>)
	self:DisconnectAll()
end

return Event
