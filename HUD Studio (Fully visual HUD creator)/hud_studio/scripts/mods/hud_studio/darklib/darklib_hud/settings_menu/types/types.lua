
---@class DarkLibHUD
---@field settings_menu DLH_SettingsMenu

---@generic T
---@class DLH_SettingsMenuWidget
---@field key string
---@field label_key string | nil  nil for a label-less row (:no_label, or a button with no :label)
---@field description_key string
---@field type "checkbox" | "keybind" | "numeric" | "dropdown" | "button" | "heading"
---@field col integer
---@field row integer  first grid unit of the row this sits in, assigned by Tab:rows
---@field row_span integer  height in grid units (C.ROW_UNITS for a normal row)
---@field col_span integer
---@field hidden_fn DLH_SettingsMenuPredicate | nil  set by :hidden; true drops the control from the panel
---@field disabled_fn DLH_SettingsMenuPredicate | nil  set by :disabled; true draws it dimmed and inert
---@field at fun(self : T, col ?: integer, row ?: integer) : T
---@field span fun(self : T, col_span:integer) : T
---@field label fun(self : T, loc_key: string) : T
---@field no_label fun(self : T) : T  drop the label, keep the row's band and height
---@field description fun(self : T, loc_key: string? ) : T
---@field hidden fun(self : T, predicate : DLH_SettingsMenuPredicate) : T

---@alias DLH_SettingsMenuPredicate boolean | string | fun(): boolean

---@generic T
---@class DLH_SettingsMenuControlWidget : DLH_SettingsMenuWidget<T>
---@field on_change fun(self : T, handler : string | fun(value: any)) : T
---@field disabled fun(self : T, predicate : DLH_SettingsMenuPredicate) : T

---@alias DLH_SettingsMenuTabElement DLH_SettingsMenuNumeric | DLH_SettingsMenuCheckbox | DLH_SettingsMenuKeybind | DLH_SettingsMenuDropdown | DLH_SettingsMenuButton | DLH_SettingsMenuHeading

---@alias DLH_SettingsMenuSchema table<number, DLH_SettingsMenuTabElement | DLH_SettingsMenuTab>
