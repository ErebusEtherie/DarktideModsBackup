

local UIWidget = require("scripts/managers/ui/ui_widget")
local UIWorkspaceSettings = require("scripts/settings/ui/ui_workspace_settings")

---@class DarkLib
---@field defs DL_Defs

return function(mod)

    local DEFAULT_FONT = "proxima_nova_medium"
    local WHITE = { 255, 255, 255, 255 }

    local function copy_argb(c)
        return { c[1], c[2], c[3], c[4] }
    end

    local Scene = {}
    Scene.__index = Scene

    local function new_scene()
        return setmetatable({
            _parent = nil, 
            _valign = "top",
            _halign = "left",
            _size = { 0, 0 },
            _pos = { 0, 0, 0 },
        }, Scene)
    end

    local function scene_inst(self)
        return self._proto and new_scene() or self
    end

    function Scene:at(x, y, z)
        local o = scene_inst(self)
        o._pos[1] = x or o._pos[1]
        o._pos[2] = y or o._pos[2]
        o._pos[3] = z or o._pos[3]
        return o
    end

    function Scene:z(z)
        local o = scene_inst(self)
        o._pos[3] = z or o._pos[3]
        return o
    end

    function Scene:align(vertical_alignment, horizontal_alignment)
        local o = scene_inst(self)
        o._valign = vertical_alignment or o._valign
        o._halign = horizontal_alignment or o._halign
        return o
    end

    function Scene:sizes(w, h)
        local o = scene_inst(self)
        o._size[1] = w or o._size[1]
        o._size[2] = h or o._size[2]
        return o
    end

    function Scene:child_of(parent)
        local o = scene_inst(self)
        o._parent = parent or o._parent
        return o
    end

    function Scene:_build()
        return {
            parent = self._parent,
            vertical_alignment = self._valign,
            horizontal_alignment = self._halign,
            size = { self._size[1], self._size[2] },
            position = { self._pos[1], self._pos[2], self._pos[3] },
        }
    end

    local Pass = {}
    Pass.__index = Pass

    local function pass_inst(self)
        return self._proto and self._new() or self
    end

    local function pass_base(t)
        t._id = nil
        t._offset = { 0, 0, 0 }
        t._size = nil
        t._size_addition = nil
        t._anchor_v = nil
        t._anchor_h = nil
        t._color = WHITE
        t._ignore = nil
        return t
    end

    local function pass_ignored(pass)
        local cond = pass._ignore
        if type(cond) == "function" then
            return cond() and true or false
        end
        return cond and true or false
    end

    local function base_style(self)
        local style = { offset = { self._offset[1], self._offset[2], self._offset[3] } }
        local anchor_v, anchor_h = self._anchor_v, self._anchor_h
        if self._size then
            style.size = { self._size[1], self._size[2] }
            anchor_v = anchor_v or "top"
            anchor_h = anchor_h or "left"
        end
        if self._size_addition then
            style.size_addition = { self._size_addition[1], self._size_addition[2] }
        end
        style.vertical_alignment = anchor_v
        style.horizontal_alignment = anchor_h
        style.color = copy_argb(self._color)
        return style
    end

    local function style_id_for(self, name, index)
        if self._id then
            return self._id
        end
        return index == 1 and name or (name .. "_" .. index)
    end

    function Pass:id(id)
        local o = pass_inst(self)
        o._id = id
        return o
    end

    function Pass:at(x, y, z)
        local o = pass_inst(self)
        o._offset[1] = x or o._offset[1]
        o._offset[2] = y or o._offset[2]
        o._offset[3] = z or o._offset[3]
        return o
    end

    function Pass:z(z)
        local o = pass_inst(self)
        o._offset[3] = z or o._offset[3]
        return o
    end

    function Pass:sizes(w, h)
        local o = pass_inst(self)
        o._size = { w, h }
        return o
    end

    function Pass:size_addition(w, h)
        local o = pass_inst(self)
        o._size_addition = { w, h }
        return o
    end

    function Pass:anchor(vertical, horizontal)
        local o = pass_inst(self)
        o._anchor_v = vertical or o._anchor_v
        o._anchor_h = horizontal or o._anchor_h
        return o
    end

    function Pass:color(color)
        local o = pass_inst(self)
        o._color = color or o._color
        return o
    end

    function Pass:ignore_if(condition)
        local o = pass_inst(self)
        o._ignore = condition
        return o
    end

    local TextPass = setmetatable({}, { __index = Pass })
    TextPass.__index = TextPass

    local function new_text()
        local t = pass_base(setmetatable({}, TextPass))
        t._color = Color.black(255, true)
        t._font = DEFAULT_FONT
        t._font_size = 16
        t._valign = "center"
        t._halign = "center"
        t._value = "<default widget text>"
        return t
    end
    TextPass._new = new_text

    function TextPass:font(font_type)
        local o = pass_inst(self)
        o._font = font_type or o._font
        return o
    end

    function TextPass:size(font_size)
        local o = pass_inst(self)
        o._font_size = font_size or o._font_size
        return o
    end

    function TextPass:align(vertical_alignment, horizontal_alignment)
        local o = pass_inst(self)
        o._valign = vertical_alignment or o._valign
        o._halign = horizontal_alignment or o._halign
        return o
    end

    function TextPass:val(value)
        local o = pass_inst(self)
        o._value = value or o._value
        return o
    end

    function TextPass:_build(name, index)
        local id = style_id_for(self, name, index)
        local style = base_style(self)
        style.font_type = mod.dl.fonts.validated(self._font)
        style.font_size = self._font_size
        style.text_vertical_alignment = self._valign
        style.text_horizontal_alignment = self._halign
        style.text_color = style.color
        style.color = nil
        return {
            pass_type = "text",
            style_id = id,
            value_id = id,
            value = self._value,
            style = style,
        }
    end

    local RectPass = setmetatable({}, { __index = Pass })
    RectPass.__index = RectPass

    local function new_rect()
        return pass_base(setmetatable({}, RectPass))
    end
    RectPass._new = new_rect

    function RectPass:_build(name, index)
        return {
            pass_type = "rect",
            style_id = style_id_for(self, name, index),
            style = base_style(self),
        }
    end

    local TexturePass = setmetatable({}, { __index = Pass })
    TexturePass.__index = TexturePass

    local function new_texture()
        local t = pass_base(setmetatable({}, TexturePass))
        t._material = ""
        t._scale = true
        t._uvs = nil
        t._color = {255, 255, 255, 255}
        return t
    end
    TexturePass._new = new_texture

    function TexturePass:material(material)
        local o = pass_inst(self)
        o._material = material or o._material
        return o
    end

    function TexturePass:scale(enabled)
        local o = pass_inst(self)
        if enabled == nil then
            enabled = true
        end
        o._scale = enabled
        return o
    end

    function TexturePass:uvs(uvs)
        local o = pass_inst(self)
        o._uvs = uvs or o._uvs
        return o
    end

    function TexturePass:flip_x()
        local o = pass_inst(self)
        o._uvs = mod.dl.uv.flip_x()
        return o
    end

    function TexturePass:flip_y()
        local o = pass_inst(self)
        o._uvs = mod.dl.uv.flip_y()
        return o
    end

    function TexturePass:_build(name, index)
        local style = base_style(self)
        style.scale_to_material = self._scale
        style.uvs = self._uvs
        return {
            pass_type = self._uvs and "texture_uv" or "texture",
            style_id = style_id_for(self, name, index),
            value_id = self._id, 
            value = self._material,
            style = style,
        }
    end

    local RotatedTexturePass = setmetatable({}, { __index = Pass })
    RotatedTexturePass.__index = RotatedTexturePass

    local function new_rotated()
        local t = pass_base(setmetatable({}, RotatedTexturePass))
        t._material = ""
        t._scale = false
        t._angle = 0
        return t
    end
    RotatedTexturePass._new = new_rotated

    function RotatedTexturePass:material(material)
        local o = pass_inst(self)
        o._material = material or o._material
        return o
    end

    function RotatedTexturePass:scale(enabled)
        local o = pass_inst(self)
        if enabled == nil then
            enabled = true
        end
        o._scale = enabled
        return o
    end

    function RotatedTexturePass:angle(radians)
        local o = pass_inst(self)
        o._angle = radians or o._angle
        return o
    end

    function RotatedTexturePass:_build(name, index)
        local style = base_style(self)
        style.scale_to_material = self._scale
        style.angle = self._angle
        return {
            pass_type = "rotated_texture",
            style_id = style_id_for(self, name, index),
            value = self._material,
            style = style,
        }
    end

    local scene = new_scene()
    scene._proto = true

    local function prototype(ctor)
        local p = ctor()
        p._proto = true
        return p
    end

    local passes = {
        text = prototype(new_text),
        rect = prototype(new_rect),
        texture = prototype(new_texture),
        rotated_texture = prototype(new_rotated),
    }

    local function is_pass(x)
        return type(x) == "table" and type(x._build) == "function" and x._offset ~= nil
    end

    local function is_entry(x)
        return type(x) == "table" and type(x.node) == "table" and type(x.passes) == "table"
    end

    local function collect_children(passes_out, children_out, item)
        if item == nil then
            return
        elseif type(item) == "function" then
            collect_children(passes_out, children_out, item())
        elseif is_pass(item) then
            if not pass_ignored(item) then
                passes_out[#passes_out + 1] = item
            end
        elseif is_entry(item) then
            children_out[#children_out + 1] = item
        elseif type(item) == "table" then
            for i = 1, #item do
                collect_children(passes_out, children_out, item[i])
            end
        end
    end

    local function make(name, node, ...)

        local pass_list = {}

        local children = {}
        for i = 1, select("#", ...) do
            collect_children(pass_list, children, (select(i, ...)))
        end

        local pass_defs = {}
        for i = 1, #pass_list do
            pass_defs[i] = pass_list[i]:_build(name, i)
        end

        for i = 1, #children do
            local child_node = children[i].node
            child_node.parent = child_node.parent or name
        end

        return {
            name = name,
            node = node:_build(),
            passes = pass_defs,
            children = children,
        }
    end

    local function add_entry(definitions, entry)
        if entry.name ~= "screen" then
            entry.node.parent = entry.node.parent or "screen"
        end
        definitions.scenegraph_definition[entry.name] = entry.node

        if #entry.passes > 0 then
            definitions.widget_definitions[entry.name] = UIWidget.create_definition(entry.passes, entry.name)
        end

        for i = 1, #entry.children do
            add_entry(definitions, entry.children[i])
        end
    end

    local function insert(definitions, entry)
        add_entry(definitions, entry)
        return definitions
    end

    local function screen()
        return {
            name = "screen",
            node = UIWorkspaceSettings.screen,
            passes = {},
            children = {},
        }
    end

    local function build(...)

        local definitions = {
            scenegraph_definition = {},
            widget_definitions = {},
        }

        for i = 1, select("#", ...) do
            add_entry(definitions, (select(i, ...)))
        end

        return definitions
    end

    local Defs = {
        build = build,
        insert = insert,
        make = make,
        screen = screen,
        passes = passes,
        scene = scene,
    }

    setmetatable(Defs, {
        __call = function()
            return build, make, passes, scene, insert, screen
        end,
    })

    return Defs

end
