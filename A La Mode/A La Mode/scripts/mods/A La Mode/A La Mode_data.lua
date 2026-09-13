local mod = get_mod("A la Mode")

local valid_weapons = mod:io_dofile("A La Mode/scripts/mods/A La Mode/data/weapon_info")
local WeaponOptions = mod:io_dofile("A La Mode/scripts/mods/A La Mode/data/weapon_options")

mod.weapon_options = WeaponOptions

return {
	name = mod:localize("mod_name"),
	description = mod:localize("mod_description"),
	is_togglable = true,
	options = {
		widgets = {
			WeaponOptions.build(valid_weapons),
		},
	},
}
