local math_deg = math.deg
local math_atan2 = math.atan2
local math_floor = math.floor
local math_abs = math.abs
local math_max = math.max
local math_min = math.min
local math_cos = math.cos
local math_sin = math.sin
local math_pi = math.pi
local table_insert = table.insert
local table_clear = table.clear
local table_clone = table.clone
local udim2_new = UDim2.new
local vector2_new = Vector2.new
local vector2_zero = Vector2.zero
local instance_new = Instance.new
local color3_new = Color3.new

local drawing = {}
drawing.signature = "_DRAWING-INSTANCE"

local run_service = cloneref(game:GetService("RunService"))
local core_gui = cloneref(game:GetService("CoreGui"))

local get_hui = typeof(gethui) == "function" and gethui or function()
    return core_gui
end

local left_triangle_asset = "http://www.roblox.com/asset/?id=18975909718"
local right_triangle_asset = "http://www.roblox.com/asset/?id=18975907988"

local container_gui = instance_new("ScreenGui")
container_gui.Name = "\0"
container_gui.IgnoreGuiInset = true
container_gui.Parent = get_hui()

local cache = {
    updates = {},
    instances = {},
    shapes = {}
}

local universal_defaults = {
    visible = false,
    transparency = 1,
    color = color3_new(0, 0, 0),
    z_index = 1
}

local shape_defaults = {
    Square = {
        position = vector2_zero,
        size = vector2_zero,
        thickness = 1,
        filled = false
    },
    Circle = {
        position = vector2_zero,
        num_sides = 8,
        radius = 200,
        thickness = 1,
        filled = false
    },
    Line = {
        from = vector2_zero,
        to = vector2_zero,
        thickness = 1
    },
    Text = {
        text = "",
        size = 14,
        center = false,
        outline = false,
        outline_color = color3_new(0, 0, 0),
        position = vector2_zero,
        text_bounds = vector2_zero,
        font = 0
    },
    Triangle = {
        thickness = 1,
        point_a = vector2_zero,
        point_b = vector2_zero,
        point_c = vector2_zero,
        filled = false
    },
    Image = {
        position = vector2_zero,
        size = vector2_zero,
        data = ""
    },
    Quad = {
        thickness = 1,
        point_a = vector2_zero,
        point_b = vector2_zero,
        point_c = vector2_zero,
        point_d = vector2_zero,
        filled = false
    }
}

drawing.fonts = {
    UI = 0,
    System = 1,
    Plex = 2,
    Monospace = 3
}

local font_indexes = {
    [0] = Enum.Font.Legacy,
    [1] = Enum.Font.Ubuntu,
    [2] = Enum.Font.Code,
    [3] = Enum.Font.Jura
}

local metatable = {
    __index = function(self, index)
        if index == "text_bounds" and self._data.shape == "Text" then
            return self._data.drawings.label.TextBounds
        end
        return self._data[index]
    end,
    __newindex = function(self, index, value)
        local data = self._data
        if data[index] == nil or data[index] == value then 
            return 
        end

        local shape_index = data.index

        if data.shape == "Text" then
            if index == "text" then
                data.drawings.label.Text = value
                data[index] = value
                return
            elseif index == "font" then
                data.drawings.label.Font = font_indexes[value] or Enum.Font.Legacy
                data[index] = value
                return
            elseif index == "size" then
                data.drawings.label.TextSize = value * 0.66
                data[index] = value
                return
            end
        end

        if not cache.updates[shape_index] then
            cache.updates[shape_index] = {}
        end

        if index == "thickness" or index == "num_sides" then
            value = math_max(math_abs(value), 1)
        end

        if index == "num_sides" then
            value = math_min(value, 64)
        end

        cache.updates[shape_index][index] = value
        data[index] = value
    end
}

local function destroy_entity(entity)
    local data = entity._data
    if data.shape == "Circle" or data.shape == "Quad" then
        for _, object in ipairs(data.drawings.lines) do
            object:Destroy()
        end
        for _, pair in ipairs(data.drawings.triangles) do
            pair[1]:Destroy()
            pair[2]:Destroy()
        end
    else
        for _, object in pairs(data.drawings) do
            object:Destroy()
        end
    end
    cache.shapes[data.index] = nil
end

local function create_entity(shape)
    local entity = table_clone(universal_defaults)
    for index, value in pairs(shape_defaults[shape]) do
        entity[index] = value
    end
    return entity
end

local function create_frame()
    local frame = instance_new("Frame", container_gui)
    frame.Visible = false
    frame.BorderSizePixel = 0
    frame.BackgroundColor3 = color3_new(0, 0, 0)
    return frame
end

local function create_triangle()
    local right = instance_new("ImageLabel", container_gui)
    right.Image = right_triangle_asset
    right.Visible = false
    right.BackgroundTransparency = 1
    right.AnchorPoint = vector2_new(0.5, 0.5)
    right.ImageColor3 = color3_new(0, 0, 0)

    local left = instance_new("ImageLabel", container_gui)
    left.Image = left_triangle_asset
    left.Visible = false
    left.BackgroundTransparency = 1
    left.AnchorPoint = vector2_new(0.5, 0.5)
    left.ImageColor3 = color3_new(0, 0, 0)

    return right, left
end

function drawing.new(shape)
    if not shape_defaults[shape] then return nil end

    local data = create_entity(shape)
    local wrapper = {
        _data = data,
        remove = destroy_entity,
        destroy = destroy_entity
    }

    data._data = data
    data.index = #cache.shapes + 1
    data.shape = shape
    cache.shapes[data.index] = wrapper

    if shape == "Square" then
        data.drawings = {
            box = create_frame(),
            line1 = create_frame(),
            line2 = create_frame(),
            line3 = create_frame(),
            line4 = create_frame()
        }
    elseif shape == "Circle" then
        data.drawings = { lines = {}, triangles = {} }
        for _ = 1, 8 do
            local line = create_frame()
            line.AnchorPoint = vector2_new(0.5, 0.5)
            table_insert(data.drawings.lines, line)
            
            local right, left = create_triangle()
            table_insert(data.drawings.triangles, { right, left })
        end
    elseif shape == "Image" then
        local image_label = instance_new("ImageLabel", container_gui)
        image_label.Image = ""
        image_label.Visible = false
        image_label.BackgroundTransparency = 1
        image_label.Size = udim2_new(0, 0, 0, 0)
        data.drawings = { image = image_label }
    elseif shape == "Line" then
        local line = create_frame()
        line.AnchorPoint = vector2_new(0.5, 0.5)
        data.drawings = { line = line }
    elseif shape == "Text" then
        local label = instance_new("TextLabel", container_gui)
        label.Text = ""
        label.TextColor3 = color3_new(0, 0, 0)
        label.BackgroundTransparency = 1
        label.AutomaticSize = Enum.AutomaticSize.XY
        label.Size = udim2_new(0, 0, 0, 0)
        label.Font = font_indexes[0]
        label.Visible = false
        data.drawings = { label = label }
    elseif shape == "Triangle" then
        local right, left = create_triangle()
        data.drawings = {
            left = left,
            right = right,
            a = create_frame(),
            b = create_frame(),
            c = create_frame()
        }
        data.drawings.a.AnchorPoint = vector2_new(0.5, 0.5)
        data.drawings.b.AnchorPoint = vector2_new(0.5, 0.5)
        data.drawings.c.AnchorPoint = vector2_new(0.5, 0.5)
    elseif shape == "Quad" then
        data.drawings = { lines = {}, triangles = {} }
        for _ = 1, 4 do
            local line = create_frame()
            line.AnchorPoint = vector2_new(0.5, 0.5)
            table_insert(data.drawings.lines, line)
        end
        for _ = 1, 2 do
            local right, left = create_triangle()
            table_insert(data.drawings.triangles, { right, left })
        end
    end

    table_insert(cache.instances, data.drawings)
    return setmetatable(wrapper, metatable)
end

function drawing.create(self, class_name, properties)
    if type(self) == "string" then
        properties = class_name
        class_name = self
    end

    properties = properties or {}

    if shape_defaults[class_name] then
        local drawing_object = drawing.new(class_name)
        for property, value in pairs(properties) do
            drawing_object[property] = value
        end
        return drawing_object
    else
        local success, instance_object = pcall(instance_new, class_name)
        if not success then
            error(string.format("Invalid Drawing shape or Instance class name: '%s'", tostring(class_name)), 2)
        end

        local parent_value = nil
        for property, value in pairs(properties) do
            if property == "parent" or property == "Parent" then
                parent_value = value
            else
                instance_object[property] = value
            end
        end

        if parent_value ~= nil then
            instance_object.Parent = parent_value
        end

        return instance_object
    end
end

local function fix_vec(vec)
    return vector2_new(math_floor(vec.X + 0.5), math_floor(vec.Y + 0.5))
end

local function get_point_order(a, b, c)
    local p0, p1, p2
    local d1, d2, d3 = (a - b).Magnitude, (c - b).Magnitude, (a - c).Magnitude
    local h1, h2, c0, h1d, h2d

    if d1 > d2 and d1 > d3 then
        h1, h2, c0, h1d, h2d = a, b, c, d3, d2
    elseif d2 > d3 and d2 > d1 then
        h1, h2, c0, h1d, h2d = c, b, a, d3, d1
    else
        h1, h2, c0, h1d, h2d = c, a, b, d2, d1
    end

    if h1d < h2d then
        p0, p1, p2 = h1, h2, c0
    else
        p0, p1, p2 = h2, h1, c0
    end

    return p0, p1, p2
end

local function render_triangle(left_side, right_side, p0, p1, p2)
    local hmxo = p1.X - p0.X
    local hmyo = p1.Y - p0.Y
    local hm = (hmyo == 0 and 1 or hmyo) / (hmxo == 0 and 1 or hmxo)
    local hb = p0.Y - hm * p0.X
    local lm = -1 / hm
    local lb = p2.Y - lm * p2.X
    local sxo = (hm - lm)
    local sx = (lb - hb) / (sxo == 0 and 1 or sxo)
    local s = vector2_new(sx, lm * sx + lb)

    local ho = p2 - s
    local height = ho.Magnitude
    local b1o = p1 - s
    local base1 = b1o.Magnitude
    local b2o = p0 - s
    local base2 = b2o.Magnitude

    local m1 = s + ho * 0.5 + b1o * 0.5
    local m2 = s + ho * 0.5 + b2o * 0.5

    local d1 = p1 - p0
    local left, right = left_side, right_side
    local rotation = math_deg(math_atan2(d1.Y, d1.X))

    local horizontal_dot = b1o:Dot(vector2_new(1, 0))
    local vertical_dot = ho:Dot(vector2_new(0, -1))
    
    if (horizontal_dot > 0 and vertical_dot < 0) or (horizontal_dot < 0 and vertical_dot > 0) then
        if d1.X ~= 0 then
            left, right = right_side, left_side
            rotation += 180
        end
    elseif d1.X == 0 then
        left, right = right_side, left_side
        rotation += 180
    end

    left.Position = udim2_new(0, m1.X, 0, m1.Y)
    left.Size = udim2_new(0, base1, 0, height)
    left.Rotation = rotation

    right.Position = udim2_new(0, m2.X, 0, m2.Y)
    right.Size = udim2_new(0, base2, 0, height)
    right.Rotation = rotation
end

local function render()
    for shape_index, update_list in pairs(cache.updates) do
        local entity = cache.shapes[shape_index]
        if not entity then continue end
        
        local shape = entity._data
        local drawings = shape.drawings

        if shape.shape == "Line" then
            local line = drawings.line
            
            if update_list.from or update_list.to then
                local a, b = shape.from, shape.to
                local offset = b - a
                local middle = a + offset * 0.5
                
                line.Position = udim2_new(0, middle.X, 0, middle.Y)
                line.Rotation = math_deg(math_atan2(offset.Y, offset.X))
                line.Size = udim2_new(0, math_floor(offset.Magnitude + 0.5), 0, math_abs(shape.thickness))
            end
            
            if update_list.thickness then
                local distance = (shape.from - shape.to).Magnitude
                line.Size = udim2_new(0, math_floor(distance + 0.5), 0, math_abs(update_list.thickness))
            end
            
            if update_list.color then 
                line.BackgroundColor3 = update_list.color 
            end
            
            if update_list.visible ~= nil then 
                line.Visible = update_list.visible 
            end
            
            if update_list.transparency then 
                line.Transparency = 1 - update_list.transparency 
            end
            
            if update_list.z_index then 
                line.ZIndex = update_list.z_index 
            end

        elseif shape.shape == "Text" then
            local label = drawings.label
            
            if update_list.position then 
                label.Position = udim2_new(0, update_list.position.X, 0, update_list.position.Y + 2) 
            end
            
            if update_list.center ~= nil then 
                label.AutomaticSize = update_list.center and Enum.AutomaticSize.Y or Enum.AutomaticSize.XY 
            end
            
            if update_list.outline ~= nil then 
                label.TextStrokeTransparency = update_list.outline and 0 or 1 
            end
            
            if update_list.outline_color then 
                label.TextStrokeColor3 = update_list.outline_color 
            end
            
            if update_list.color then 
                label.TextColor3 = update_list.color 
            end
            
            if update_list.visible ~= nil then 
                label.Visible = update_list.visible 
            end
            
            if update_list.transparency then 
                label.TextTransparency = 1 - update_list.transparency 
            end
            
            if update_list.z_index then 
                label.ZIndex = update_list.z_index 
            end

        elseif shape.shape == "Square" then
            if update_list.position or update_list.thickness or update_list.size then
                local size = fix_vec(shape.size)
                local position = shape.position

                if size.X < 0 then 
                    size = vector2_new(math_abs(size.X), size.Y)
                    position = vector2_new(position.X - size.X, position.Y) 
                end
                
                if size.Y < 0 then 
                    size = vector2_new(size.X, math_abs(size.Y))
                    position = vector2_new(position.X, position.Y - size.Y) 
                end

                local real_thick = shape.thickness
                local thick = real_thick - 1
                local offset = math_floor(thick * 0.5 + 0.5)
                local box_pos = fix_vec(vector2_new(position.X - offset, position.Y - offset))

                drawings.box.Position = udim2_new(0, box_pos.X, 0, box_pos.Y)
                drawings.box.Size = udim2_new(0, size.X + thick, 0, size.Y + thick)
                
                drawings.line1.Position = drawings.box.Position
                drawings.line2.Position = udim2_new(0, box_pos.X + size.X - 1, 0, box_pos.Y + real_thick)
                drawings.line3.Position = udim2_new(0, box_pos.X, 0, box_pos.Y + size.Y - 1)
                drawings.line4.Position = udim2_new(0, box_pos.X, 0, box_pos.Y + real_thick)
                
                drawings.line2.Size = udim2_new(0, real_thick, 0, size.Y - real_thick - 1)
                drawings.line1.Size = udim2_new(0, size.X + thick, 0, real_thick)
                drawings.line4.Size = udim2_new(0, real_thick, 0, size.Y - real_thick - 1)
                drawings.line3.Size = udim2_new(0, size.X + thick, 0, real_thick)
            end

            if update_list.filled ~= nil and shape.visible then
                drawings.box.Visible = update_list.filled
                drawings.line1.Visible = not update_list.filled
                drawings.line2.Visible = not update_list.filled
                drawings.line3.Visible = not update_list.filled
                drawings.line4.Visible = not update_list.filled
            end
            
            if update_list.visible ~= nil then
                local state = update_list.visible
                if shape.filled then 
                    drawings.box.Visible = state
                else 
                    drawings.line1.Visible = state
                    drawings.line2.Visible = state
                    drawings.line3.Visible = state
                    drawings.line4.Visible = state 
                end
            end
            
            if update_list.transparency then
                local transparency = 1 - update_list.transparency
                drawings.box.Transparency = transparency
                drawings.line1.Transparency = transparency
                drawings.line2.Transparency = transparency
                drawings.line3.Transparency = transparency
                drawings.line4.Transparency = transparency
            end
            
            if update_list.color then
                for _, object in pairs(drawings) do 
                    object.BackgroundColor3 = update_list.color 
                end
            end
            
            if update_list.z_index then
                for _, object in pairs(drawings) do 
                    object.ZIndex = update_list.z_index 
                end
            end

        elseif shape.shape == "Image" then
            local image = drawings.image
            
            if update_list.position then 
                image.Position = udim2_new(0, update_list.position.X, 0, update_list.position.Y) 
            end
            
            if update_list.size then 
                image.Size = udim2_new(0, update_list.size.X, 0, update_list.size.Y) 
            end
            
            if update_list.data then 
                image.Image = update_list.data 
            end
            
            if update_list.visible ~= nil then 
                image.Visible = update_list.visible 
            end
            
            if update_list.transparency then 
                image.ImageTransparency = 1 - update_list.transparency 
            end
            
            if update_list.z_index then 
                image.ZIndex = update_list.z_index 
            end

        elseif shape.shape == "Circle" then
            if update_list.num_sides then
                for _, pair in ipairs(drawings.triangles) do 
                    pair[1]:Destroy()
                    pair[2]:Destroy() 
                end
                
                for _, line in ipairs(drawings.lines) do 
                    line:Destroy() 
                end

                drawings.lines = {}
                drawings.triangles = {}

                for _ = 1, update_list.num_sides do
                    local line = create_frame()
                    line.AnchorPoint = vector2_new(0.5, 0.5)
                    table_insert(drawings.lines, line)
                    
                    local right, left = create_triangle()
                    table_insert(drawings.triangles, { right, left })
                end

                update_list.filled = shape.filled
                update_list.visible = shape.visible
                update_list.transparency = shape.transparency
                update_list.color = shape.color
                update_list.z_index = shape.z_index
            end

            if update_list.position or update_list.thickness or update_list.radius or update_list.num_sides then
                local position = shape.position
                local size = shape.radius
                local num = shape.num_sides
                local interval = 2 * math_pi / num

                for index = 1, num do
                    local origin = (index - 1) * interval
                    local target = index * interval
                    local o0 = vector2_new(math_cos(origin), math_sin(origin))
                    local o1 = vector2_new(math_cos(target), math_sin(target))
                    local p0 = position + o0 * size
                    local p1 = position + o1 * size
                    local offset = p1 - p0
                    local middle = p0 + offset * 0.5
                    local distance = offset.Magnitude
                    local new_size = (middle - position).Magnitude
                    local line = drawings.lines[index]
                    local left = drawings.triangles[index][1]
                    local right = drawings.triangles[index][2]

                    line.Position = udim2_new(0, middle.X, 0, middle.Y)
                    line.Rotation = math_deg(math_atan2(offset.Y, offset.X))
                    line.Size = udim2_new(0, math_floor(distance + 0.5), 0, math_abs(shape.thickness))

                    local rotation = math_deg((index - 0.5) * interval - (math_pi * 0.5))
                    local left_pos = position + vector2_new(math_cos((index - 1) * interval), math_sin((index - 1) * interval)) * size * 0.5
                    left.Position = udim2_new(0, left_pos.X, 0, left_pos.Y)
                    left.Size = udim2_new(0, distance * 0.5, 0, new_size)
                    left.Rotation = rotation

                    local right_pos = position + vector2_new(math_cos(index * interval), math_sin(index * interval)) * size * 0.5
                    right.Position = udim2_new(0, right_pos.X, 0, right_pos.Y)
                    right.Size = udim2_new(0, distance * 0.5, 0, new_size)
                    right.Rotation = rotation
                end
            end

            if update_list.filled ~= nil and shape.visible then
                for _, pair in ipairs(drawings.triangles) do 
                    pair[1].Visible = update_list.filled
                    pair[2].Visible = update_list.filled 
                end
                for _, line in ipairs(drawings.lines) do 
                    line.Visible = not update_list.filled 
                end
            end
            
            if update_list.visible ~= nil then
                if shape.filled then
                    for _, pair in ipairs(drawings.triangles) do 
                        pair[1].Visible = update_list.visible
                        pair[2].Visible = update_list.visible 
                    end
                else
                    for _, line in ipairs(drawings.lines) do 
                        line.Visible = update_list.visible 
                    end
                end
            end
            
            if update_list.transparency then
                local transparency = 1 - update_list.transparency
                for _, line in ipairs(drawings.lines) do 
                    line.Transparency = transparency 
                end
                for _, pair in ipairs(drawings.triangles) do 
                    pair[1].ImageTransparency = transparency
                    pair[2].ImageTransparency = transparency 
                end
            end
            
            if update_list.color then
                for _, line in ipairs(drawings.lines) do 
                    line.BackgroundColor3 = update_list.color 
                end
                for _, pair in ipairs(drawings.triangles) do 
                    pair[1].ImageColor3 = update_list.color
                    pair[2].ImageColor3 = update_list.color 
                end
            end
            
            if update_list.z_index then
                for _, line in ipairs(drawings.lines) do 
                    line.ZIndex = update_list.z_index 
                end
                for _, pair in ipairs(drawings.triangles) do 
                    pair[1].ZIndex = update_list.z_index
                    pair[2].ZIndex = update_list.z_index 
                end
            end

        elseif shape.shape == "Triangle" then
            if update_list.point_a or update_list.point_b or update_list.point_c or update_list.thickness then
                local a, b, c = shape.point_a, shape.point_b, shape.point_c
                if a and b and c and a ~= b and a ~= c and b ~= c then
                    local p0, p1, p2 = get_point_order(a, b, c)
                    local line1, line2, line3 = drawings.a, drawings.b, drawings.c

                    local d1 = p1 - p0
                    local mp1 = p0 + d1 * 0.5
                    line1.Position = udim2_new(0, mp1.X, 0, mp1.Y)
                    line1.Rotation = math_deg(math_atan2(d1.Y, d1.X))
                    line1.Size = udim2_new(0, math_floor(d1.Magnitude + 0.5), 0, math_abs(shape.thickness))

                    local d2 = p2 - p1
                    local mp2 = p1 + d2 * 0.5
                    line2.Position = udim2_new(0, mp2.X, 0, mp2.Y)
                    line2.Rotation = math_deg(math_atan2(d2.Y, d2.X))
                    line2.Size = udim2_new(0, math_floor(d2.Magnitude + 0.5), 0, math_abs(shape.thickness))

                    local d3 = p0 - p2
                    local mp3 = p2 + d3 * 0.5
                    line3.Position = udim2_new(0, mp3.X, 0, mp3.Y)
                    line3.Rotation = math_deg(math_atan2(d3.Y, d3.X))
                    line3.Size = udim2_new(0, math_floor(d3.Magnitude + 0.5), 0, math_abs(shape.thickness))

                    render_triangle(drawings.left, drawings.right, p0, p1, p2)
                end
            end

            if update_list.filled ~= nil and shape.visible then
                drawings.left.Visible = update_list.filled
                drawings.right.Visible = update_list.filled
                drawings.a.Visible = not update_list.filled
                drawings.b.Visible = not update_list.filled
                drawings.c.Visible = not update_list.filled
            end
            
            if update_list.visible ~= nil then
                if shape.filled then
                    drawings.left.Visible = update_list.visible
                    drawings.right.Visible = update_list.visible
                else
                    drawings.a.Visible = update_list.visible
                    drawings.b.Visible = update_list.visible
                    drawings.c.Visible = update_list.visible
                end
            end
            
            if update_list.color then
                drawings.left.ImageColor3 = update_list.color
                drawings.right.ImageColor3 = update_list.color
                drawings.a.BackgroundColor3 = update_list.color
                drawings.b.BackgroundColor3 = update_list.color
                drawings.c.BackgroundColor3 = update_list.color
            end
            
            if update_list.transparency then
                local transparency = 1 - update_list.transparency
                drawings.left.ImageTransparency = transparency
                drawings.right.ImageTransparency = transparency
                drawings.a.Transparency = transparency
                drawings.b.Transparency = transparency
                drawings.c.Transparency = transparency
            end
            
            if update_list.z_index then
                for _, object in pairs(drawings) do 
                    object.ZIndex = update_list.z_index 
                end
            end

        elseif shape.shape == "Quad" then
            if update_list.point_a or update_list.point_b or update_list.point_c or update_list.point_d or update_list.thickness then
                local p0, p1, p2, p3 = shape.point_a, shape.point_b, shape.point_c, shape.point_d
                if p0 and p1 and p2 and p3 and p0 ~= p1 and p0 ~= p2 and p0 ~= p3 and p1 ~= p2 and p1 ~= p3 and p2 ~= p3 then
                    local intersects = false
                    local intersection

                    local m1 = (p1.Y - p0.Y) / (p1.X - p0.X)
                    local m2 = (p2.Y - p1.Y) / (p2.X - p1.X)
                    local m3 = (p3.Y - p2.Y) / (p3.X - p2.X)
                    local m4 = (p0.Y - p3.Y) / (p0.X - p3.X)
                    
                    local lines = {
                        {p0, p1, m1, p0.Y - m1 * p0.X},
                        {p1, p2, m2, p1.Y - m2 * p1.X},
                        {p2, p3, m3, p2.Y - m3 * p2.X},
                        {p3, p0, m4, p3.Y - m4 * p3.X}
                    }

                    for index = 1, 2 do
                        local line_data = lines[index]
                        local o1, t1, s1, b1 = line_data[1], line_data[2], line_data[3], line_data[4]
                        
                        if not intersects then
                            local opposite = index + 2
                            local o2, t2, s2, b2 = lines[opposite][1], lines[opposite][2], lines[opposite][3], lines[opposite][4]
                            local ix = (b2 - b1) / (s1 - s2)

                            local x11, x12 = o1.X, t1.X
                            if x11 > x12 then x11, x12 = x12, x11 end
                            
                            local x21, x22 = o2.X, t2.X
                            if x21 > x22 then x21, x22 = x22, x21 end

                            if ix > x11 + 1 and ix < x12 - 1 and ix > x21 + 1 and ix < x22 - 1 then
                                intersects = index + 1
                                intersection = vector2_new(ix, s2 * ix + b2)
                            end
                        end
                    end

                    local obtuse
                    if not intersects then
                        local biggest_angle = 0
                        local biggest_line

                        for index = 1, 4 do
                            local o0 = lines[(index == 1 and 4) or index - 1][1]
                            local o1, t1 = lines[index][1], lines[index][2]
                            local sup_angle = (o0 - o1).Unit:Dot((t1 - o1).Unit)
                            local angle = sup_angle < 0 and (2 + sup_angle) or (1 - math_abs(sup_angle))

                            if angle >= biggest_angle then
                                biggest_line = index
                                biggest_angle = angle
                            end
                        end
                        obtuse = biggest_line
                    end

                    for side_index = 1, 4 do
                        local line = drawings.lines[side_index]
                        local h1, h2 = lines[side_index][1], lines[side_index][2]
                        local d = h2 - h1
                        local mp = h1 + d * 0.5
                        line.Position = udim2_new(0, mp.X, 0, mp.Y)
                        line.Rotation = math_deg(math_atan2(d.Y, d.X))
                        line.Size = udim2_new(0, math_floor(d.Magnitude + 0.5), 0, math_abs(shape.thickness))
                    end

                    if intersects then
                        local l1 = lines[intersects]
                        local l2 = lines[intersects == 3 and 1 or 4]
                        local lt1, rt1 = drawings.triangles[1][1], drawings.triangles[1][2]
                        local lt2, rt2 = drawings.triangles[2][1], drawings.triangles[2][2]
                        local a1, b1, c1 = get_point_order(intersection, l1[1], l1[2])
                        local a2, b2, c2 = get_point_order(intersection, l2[1], l2[2])
                        render_triangle(lt1, rt1, a1, b1, c1)
                        render_triangle(lt2, rt2, a2, b2, c2)
                    else
                        local l0 = lines[(obtuse < 3 and obtuse + 2) or obtuse - 2]
                        local l1 = lines[obtuse]
                        local lt1, rt1 = drawings.triangles[1][1], drawings.triangles[1][2]
                        local lt2, rt2 = drawings.triangles[2][1], drawings.triangles[2][2]
                        local a1, b1, c1 = get_point_order(l1[1], l1[2], l0[1])
                        local a2, b2, c2 = get_point_order(l1[1], l0[2], l0[1])
                        render_triangle(lt1, rt1, a1, b1, c1)
                        render_triangle(lt2, rt2, a2, b2, c2)
                    end
                end
            end

            if update_list.filled ~= nil and shape.visible then
                for _, pair in ipairs(drawings.triangles) do 
                    pair[1].Visible = update_list.filled
                    pair[2].Visible = update_list.filled 
                end
                for _, line in ipairs(drawings.lines) do 
                    line.Visible = not update_list.filled 
                end
            end
            
            if update_list.visible ~= nil then
                if shape.filled then
                    for _, pair in ipairs(drawings.triangles) do 
                        pair[1].Visible = update_list.visible
                        pair[2].Visible = update_list.visible 
                    end
                else
                    for _, line in ipairs(drawings.lines) do 
                        line.Visible = update_list.visible 
                    end
                end
            end
            
            if update_list.transparency then
                local transparency = 1 - update_list.transparency
                for _, line in ipairs(drawings.lines) do 
                    line.Transparency = transparency 
                end
                for _, pair in ipairs(drawings.triangles) do 
                    pair[1].ImageTransparency = transparency
                    pair[2].ImageTransparency = transparency 
                end
            end
            
            if update_list.color then
                for _, line in ipairs(drawings.lines) do 
                    line.BackgroundColor3 = update_list.color 
                end
                for _, pair in ipairs(drawings.triangles) do 
                    pair[1].ImageColor3 = update_list.color
                    pair[2].ImageColor3 = update_list.color 
                end
            end
            
            if update_list.z_index then
                for _, line in ipairs(drawings.lines) do 
                    line.ZIndex = update_list.z_index 
                end
                for _, pair in ipairs(drawings.triangles) do 
                    pair[1].ZIndex = update_list.z_index
                    pair[2].ZIndex = update_list.z_index 
                end
            end
        end
    end

    table_clear(cache.updates)
end

function drawing.clear_draw_cache()
    for _, instance_list in ipairs(cache.instances) do
        for _, instance_object in pairs(instance_list) do
            if type(instance_object) == "table" then
                for _, sub_object in pairs(instance_object) do
                    if typeof(sub_object) == "Instance" then 
                        sub_object:Destroy() 
                    end
                end
            elseif typeof(instance_object) == "Instance" then
                instance_object:Destroy()
            end
        end
    end
    table_clear(cache.instances)
    table_clear(cache.shapes)
    table_clear(cache.updates)
end

function drawing.is_render_object(object)
    return type(object) == "table" and object._data ~= nil and table.find(cache.shapes, object) ~= nil
end

function drawing.get_render_property(object, index)
    return object[index]
end

function drawing.set_render_property(object, index, value)
    object[index] = value
end

function drawing.get_gui()
    return container_gui
end

getgenv().drawing = drawing
getgenv().cleardrawcache = drawing.clear_draw_cache
getgenv().isrenderobj = drawing.is_render_object
getgenv().getrenderproperty = drawing.get_render_property
getgenv().setrenderproperty = drawing.set_render_property
getgenv().getdrawingcontainer = drawing.get_gui

run_service.RenderStepped:Connect(render)

return drawing
