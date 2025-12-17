return {
	mod_name = {
		en = "Stimm Supply Rings",
	},
	mod_description = {
		en = "Adds different color rings to Hive Scum Stimm Supply crates to indicate which buffs they provide",
	},
	show_attack_speed = {
		en = "Show Attack Speed Ring (Blue)",
	},
	show_cooldown = {
		en = "Show Cooldown Ring (Yellow)",
	},
	show_strength = {
		en = "Show Strength Ring (Red)",
	},
	show_toughness = {
		en = "Show Toughness Ring (Purple)",
	},
	min_investment = {
		en = "Minimum Node Threshold",
	},
	min_investment_tooltip = {
		en = "Minimum nodes taken in a particular line in order to show the ring at all",
	},
	min_opacity = {
		en = "Minimum Ring Opacity",
	},
	max_opacity = {
		en = "Maximum Ring Opacity",
	},
	opacity_scaling_power = {
		en = "Opacity Scaling Power",
	},
	opacity_scaling_power_tooltip = {
		en = "Determines how dramatically opacity scales up with node investment.\n\n0 = No Scaling. All visible rings at max opacity.\n1 = Linear\n2 = Quadratic\n3 = Cubic"
	},
	enable_logging = {
		en = "Enable Logging",
	},
	enable_logging_tooltip = {
		en = "Prints a message to the chat and console explaining why rings are not displayed (e.g. stimm on cooldown). Useful for troubleshooting.",
	},

	-- Echo messages
	owner_not_alive = {
		en = "Owner is not alive",
	},
	missing_player_unit = {
		en = "Owner '%s' missing player unit",
	},
	missing_ability_system = {
		en = "Owner '%s' missing ability system",
	},
	missing_cartel_stimm = {
		en = "Owner '%s' not using Cartel Stimm",
	},
	missing_buff_extension = {
		en = "Owner '%s' missing buff extension",
	},
	stimm_on_cooldown = {
		en = "Owner '%s' has %.2f remaining on stimm cooldown",
	},
	personal_stimm_active = {
		en = "Owner '%s' has personal stimm active for %.2f more seconds"
	},

	-- Experimental
	has_stimm_pickup = {
		en = "Owner '%s' has stimm pickup: %s"
	}
}
