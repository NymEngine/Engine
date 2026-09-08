local Writer = {}
Writer.__index = Writer

local WriterPool = {}
function Writer.new(InitialCapacity)
	local Capacity = InitialCapacity or 64
	local Obj = table.remove(WriterPool)
	if Obj then
		Obj.Buff = buffer.create(Capacity)
		Obj.Cursor = 0
		Obj.BitCursor = 0
		Obj.BitVal = 0
		Obj.Capacity = Capacity
		return Obj
	end
	return setmetatable({
		Buff = buffer.create(Capacity),
		Cursor = 0,
		BitCursor = 0,
		BitVal = 0,
		Capacity = Capacity,
	}, Writer)
end

function Writer:Release()
	self.Buff = nil
	table.insert(WriterPool, self)
end

function Writer:EnsureCapacity(BytesNeeded)
	if self.Cursor + BytesNeeded > self.Capacity then
		local NewCapacity = math.max(self.Capacity * 2, self.Cursor + BytesNeeded)
		local NewBuff = buffer.create(NewCapacity)
		buffer.copy(NewBuff, 0, self.Buff, 0, self.Cursor)
		self.Buff = NewBuff
		self.Capacity = NewCapacity
	end
end

function Writer:FlushBits()
	if self.BitCursor > 0 then
		self:EnsureCapacity(1)
		buffer.writeu8(self.Buff, self.Cursor, self.BitVal)
		self.Cursor += 1
		self.BitCursor = 0
		self.BitVal = 0
	end
end

function Writer:WriteBit(Val)
	if Val then
		self.BitVal = bit32.bor(self.BitVal, bit32.lshift(1, self.BitCursor))
	end
	self.BitCursor += 1
	if self.BitCursor == 8 then
		self:FlushBits()
	end
end

function Writer:WriteU8(Val)
	self:FlushBits()
	self:EnsureCapacity(1)
	buffer.writeu8(self.Buff, self.Cursor, Val)
	self.Cursor += 1
end

function Writer:WriteU16(Val)
	self:FlushBits()
	self:EnsureCapacity(2)
	buffer.writeu16(self.Buff, self.Cursor, Val)
	self.Cursor += 2
end

function Writer:WriteI32(Val)
	self:FlushBits()
	self:EnsureCapacity(4)
	buffer.writei32(self.Buff, self.Cursor, Val)
	self.Cursor += 4
end

function Writer:WriteF32(Val)
	self:FlushBits()
	self:EnsureCapacity(4)
	buffer.writef32(self.Buff, self.Cursor, Val)
	self.Cursor += 4
end

function Writer:WriteString(Val)
	self:FlushBits()
	local Len = #Val
	if Len > 65535 then
		error("string exceeds maximum length of 65535 bytes")
	end
	self:WriteU16(Len)
	self:EnsureCapacity(Len)
	buffer.writestring(self.Buff, self.Cursor, Val)
	self.Cursor += Len
end

function Writer:WriteVector3(Val)
	self:WriteF32(Val.X)
	self:WriteF32(Val.Y)
	self:WriteF32(Val.Z)
end

function Writer:WriteCFrame(Val)
	local X, Y, Z, R00, R01, R02, R10, R11, R12, R20, R21, R22 = Val:GetComponents()
	self:WriteF32(X)
	self:WriteF32(Y)
	self:WriteF32(Z)
	self:WriteF32(R00)
	self:WriteF32(R01)
	self:WriteF32(R02)
	self:WriteF32(R10)
	self:WriteF32(R11)
	self:WriteF32(R12)
	self:WriteF32(R20)
	self:WriteF32(R21)
	self:WriteF32(R22)
end

function Writer:Build()
	self:FlushBits()
	local FinalBuff = buffer.create(self.Cursor)
	buffer.copy(FinalBuff, 0, self.Buff, 0, self.Cursor)
	return FinalBuff
end

local Reader = {}
Reader.__index = Reader
local ReaderPool = {}

function Reader.new(Buff)
	local Obj = table.remove(ReaderPool)
	if Obj then
		Obj.Buff = Buff
		Obj.Cursor = 0
		Obj.BitCursor = 0
		Obj.BitVal = 0
		Obj.Length = buffer.len(Buff)
		return Obj
	end
	return setmetatable({
		Buff = Buff,
		Cursor = 0,
		BitCursor = 0,
		BitVal = 0,
		Length = buffer.len(Buff),
	}, Reader)
end

function Reader:Release()
	self.Buff = nil
	table.insert(ReaderPool, self)
end

function Reader:Align()
	if self.BitCursor > 0 then
		self.BitCursor = 0
		self.BitVal = 0
	end
end

function Reader:ReadBit()
	if self.BitCursor == 0 then
		if self.Cursor >= self.Length then
			error("attempt to read past buffer boundary")
		end
		self.BitVal = buffer.readu8(self.Buff, self.Cursor)
		self.Cursor += 1
	end
	local Res = bit32.band(bit32.rshift(self.BitVal, self.BitCursor), 1) == 1
	self.BitCursor = (self.BitCursor + 1) % 8
	return Res
end

function Reader:ReadU8()
	self:Align()
	if self.Cursor >= self.Length then
		error("attempt to read past buffer boundary")
	end
	local Val = buffer.readu8(self.Buff, self.Cursor)
	self.Cursor += 1
	return Val
end

function Reader:ReadU16()
	self:Align()
	if self.Cursor + 2 > self.Length then
		error("attempt to read past buffer boundary")
	end
	local Val = buffer.readu16(self.Buff, self.Cursor)
	self.Cursor += 2
	return Val
end

function Reader:ReadI32()
	self:Align()
	if self.Cursor + 4 > self.Length then
		error("attempt to read past buffer boundary")
	end
	local Val = buffer.readi32(self.Buff, self.Cursor)
	self.Cursor += 4
	return Val
end

function Reader:ReadF32()
	self:Align()
	if self.Cursor + 4 > self.Length then
		error("attempt to read past buffer boundary")
	end
	local Val = buffer.readf32(self.Buff, self.Cursor)
	self.Cursor += 4
	return Val
end

function Reader:ReadString()
	self:Align()
	local Len = self:ReadU16()
	if self.Cursor + Len > self.Length then
		error("attempt to read past buffer boundary")
	end
	local Val = buffer.readstring(self.Buff, self.Cursor, Len)
	self.Cursor += Len
	return Val
end

function Reader:ReadVector3()
	local X = self:ReadF32()
	local Y = self:ReadF32()
	local Z = self:ReadF32()
	return Vector3.new(X, Y, Z)
end

function Reader:ReadCFrame()
	local X = self:ReadF32()
	local Y = self:ReadF32()
	local Z = self:ReadF32()
	local R00 = self:ReadF32()
	local R01 = self:ReadF32()
	local R02 = self:ReadF32()
	local R10 = self:ReadF32()
	local R11 = self:ReadF32()
	local R12 = self:ReadF32()
	local R20 = self:ReadF32()
	local R21 = self:ReadF32()
	local R22 = self:ReadF32()
	return CFrame.new(X, Y, Z, R00, R01, R02, R10, R11, R12, R20, R21, R22)
end

return {
	Reader = Reader,
	Writer = Writer,
}
