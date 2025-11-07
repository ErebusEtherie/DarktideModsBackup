local mod = get_mod("MoreGraphicsOptions")

return {
	name = "MoreGraphicsOptions",
	is_togglable = false,
	options = {
		widgets = {
			{
				setting_id  = "keybinds",
				type        = "group",
				sub_widgets = {
					{
						setting_id      = "apply",
						type            = "keybind",
						default_value   = {},
						keybind_global  = true,
						keybind_trigger = "pressed",
						keybind_type    = "function_call",
						function_name   = "apply"
					},
				}
			},
			{
				setting_id  = "rendersettings",
				type        = "group",
				sub_widgets = {
					{
						setting_id      = "meshquality",
						type            = "numeric",
						default_value   = 0.5,
						range           = { 0.1, 5.0 },
						decimals_number = 1
					},
					{
						setting_id      = "particles_capacity_multiplier",
						type            = "numeric",
						default_value   = 1,
						range           = { 0.65, 1.0 },
						decimals_number = 2
					},
				}
			},
			{
				setting_id  = "lightquality",
				type        = "group",
				sub_widgets = {
					{
						setting_id    = "sunshadows",
						type          = "checkbox",
						default_value = false,
					},
					{
						setting_id    = "sun_shadow_map_size",
						type          = "dropdown",
						default_value = 4,
						options       = {
							{ text = "four",   value = 4 },
							{ text = "two56",  value = 256 },
							{ text = "five12", value = 512 },
							{ text = "one024", value = 1024 },
							{ text = "two048", value = 2048 },
						},
					},
					{
						setting_id    = "local_lights_shadows_enabled",
						type          = "checkbox",
						default_value = false,
					},
					{
						setting_id    = "local_lights_shadow_atlas_size",
						type          = "dropdown",
						default_value = 512,
						options       = {
							{ text = "two56",  value = 256 },
							{ text = "five12", value = 512 },
							{ text = "one024", value = 1024 },
							{ text = "two048", value = 2048 },
						},
					},
					{
						setting_id    = "static_sun_shadows",
						type          = "checkbox",
						default_value = false,
					},
					{
						setting_id    = "static_sun_shadow_map_size",
						type          = "dropdown",
						default_value = 2048,
						options       = {
							{ text = "two56",  value = 256 },
							{ text = "five12", value = 512 },
							{ text = "one024", value = 1024 },
							{ text = "two048", value = 2048 },
						},
					},
				}
			},
			{
				setting_id  = "volumetricfogquality",
				type        = "group",
				sub_widgets = {
					{
						setting_id    = "Volenabled",
						type          = "checkbox",
						default_value = true,
					},
					{
						setting_id    = "high_quality",
						type          = "checkbox",
						default_value = false,
					},
					{
						setting_id    = "volumetric_shadows",
						type          = "checkbox",
						default_value = false,
					},
					{
						setting_id    = "light_shafts",
						type          = "checkbox",
						default_value = false,
					},
					{
						setting_id    = "volumetric_local_lights",
						type          = "checkbox",
						default_value = false,
					},
				}
			},
			{
				setting_id  = "globalillumination",
				type        = "group",
				sub_widgets = {
					{
						setting_id    = "GIenabled",
						type          = "checkbox",
						default_value = true,
					},
					{
						setting_id      = "rtxgi_scale",
						type            = "numeric",
						default_value   = 0.5,
						range           = { 0.25, 1 },
						decimals_number = 2
					},
				}
			},
			{
				setting_id  = "performancesettings",
				type        = "group",
				sub_widgets =
				{
					{
						setting_id      = "maxragdolls",
						type            = "numeric",
						default_value   = 3,
						range           = { 1, 50 },
						decimals_number = 0
					},
					{
						setting_id      = "maximpactdecals",
						type            = "numeric",
						default_value   = 5,
						range           = { 0, 100 },
						decimals_number = 0
					},
					{
						setting_id      = "maxblooddecals",
						type            = "numeric",
						default_value   = 5,
						range           = { 0, 100 },
						decimals_number = 0
					},
					{
						setting_id      = "decallifetime",
						type            = "numeric",
						default_value   = 10,
						range           = { 0, 60 },
						decimals_number = 0
					},
				}
			},
		}
	}
}
