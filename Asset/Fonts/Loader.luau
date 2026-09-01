--!strict

local http_service = game:GetService("HttpService")

export type font_data_input = {
    id: string,
    url: string,
}

export type custom_font_type = typeof(setmetatable({} :: {
    name: string,
    weight: number,
    style: string,
    data: font_data_input,
    font_object: Font,
}, {}))

local custom_font = {} :: {
    __index: any,
    folder_path: string,
    loaded: {[string]: custom_font_type},
    set_folder: (path: string) -> (),
    new: (name: string, weight: number, style: string, data: font_data_input) -> custom_font_type?,
    get_font_object: (self: custom_font_type) -> Font,
}

custom_font.__index = custom_font
custom_font.folder_path = "custom_fonts"
custom_font.loaded = {}

function custom_font.set_folder(path: string)
    custom_font.folder_path = path
    if not isfolder(path) then
        makefolder(path)
    end
end

if not isfolder(custom_font.folder_path) then
    makefolder(custom_font.folder_path)
end

function custom_font.new(name: string, weight: number, style: string, data: font_data_input): custom_font_type?
    if custom_font.loaded[name] then
        return custom_font.loaded[name]
    end

    local self = setmetatable({}, custom_font)
    
    self.name = name
    self.weight = weight
    self.style = style
    self.data = data
    
    local assets_folder = custom_font.folder_path
    if not isfolder(assets_folder) then
        makefolder(assets_folder)
    end
    
    local raw_font_path = assets_folder .. "/" .. data.id
    
    if not isfile(raw_font_path) then
        local success, response = pcall(function()
            return game:HttpGet(data.url)
        end)
        
        if success and response then
            writefile(raw_font_path, response)
        else
            warn("CustomFont: Failed to download asset for -> " .. name)
            return nil
        end
    end
    
    local font_data = {
        name = name,
        faces = {
            {
                name = name,
                weight = weight,
                style = style,
                assetId = getcustomasset(raw_font_path)
            }
        }
    }
    
    local font_path = assets_folder .. "/" .. name .. ".font"
    
    local encode_success, encoded_json = pcall(function()
        return http_service:JSONEncode(font_data)
    end)
    
    if encode_success and encoded_json then
        writefile(font_path, encoded_json)
    else
        warn("CustomFont: Failed to encode JSON for -> " .. name)
        return nil
    end
    
    self.font_object = Font.new(getcustomasset(font_path))
    
    custom_font.loaded[name] = (self :: any) :: custom_font_type
    return custom_font.loaded[name]
end

function custom_font:get_font_object(): Font
    return self.font_object
end

return custom_font
