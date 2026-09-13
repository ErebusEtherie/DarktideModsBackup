---@class mod : DL_Mod
local mod = get_mod("hud_studio")

if mod.hud_studio_node_registry then
	return mod.hud_studio_node_registry
end

---@class ValueEditor : EditorDoc
---@field kind string                        e.g. "material_browser" | "text" | "number"
---@field modes string[]?                    text: e.g. { "fixed", "localized" }

---@class CallbackSlot : EditorDoc
---@field fields string[]?                   value slot: which node fields it binds
---@field scope string[]                     names in scope, for the editor legend

---@class NodeType

---@field id string                          preset id stored in the document (e.g. "text")
---@field label string?                      human name for the palette
---@field bindable string[]                  field names that accept a binding
---@field draw fun(ui_renderer: table, x: number, y: number, z: number, scale: number, values: table, style: table?)  immediate-mode draw at screen (x,y,z)
---@field implicit_material fun(values: table, style: table?): string|nil  a material the draw needs resident but that is NOT an authored `material` field (the curved progress bar's arc, implied by its shape); the canvas package-gates on it

---@field curved_orientations fun(): string[]  the `orientation` values valid for a curved progress bar, in dropdown order; node_form builds the picker from this rather than restating the set
---@field default_orientation fun(shape: string?): string  the `orientation` a node reset to `shape` should take (its first option); node_form calls this when the shape changes, since the two shapes' orientation sets are disjoint
---@field value_editor ValueEditor?       the static-value control
---@field style_knobs string[]?              which base-style knobs to expose
---@field callbacks table<string, CallbackSlot>?  slot name -> slot descriptor
---@field threshold_values { current: string, max: string }?  thresholds mode reuses these two of the node's OWN value fields as its ratio (the progress bar's current/max) instead of asking for them again

---@class NodeRegistry
local Registry = {}

---@type table<string, NodeType>
local node_types = {}

---@param node_type NodeType
function Registry.register(node_type)
	node_types[node_type.id] = node_type
end

---@param id string
---@return NodeType?
function Registry.get(id)
	return node_types[id]
end

---@return table<string, NodeType>
function Registry.all()
	return node_types
end

mod.hud_studio_node_registry = Registry

return Registry
