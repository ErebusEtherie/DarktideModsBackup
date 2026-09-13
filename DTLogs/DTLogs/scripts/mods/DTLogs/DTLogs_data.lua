local mod = get_mod("DTLogs")

return {
	name = mod:localize("mod_name"),
	description = mod:localize("mod_description"),
	is_togglable = true,
	allow_rehooking = true,
	options = {
		widgets = {
			{
				setting_id = "auto_upload_completed_missions",
				type = "checkbox",
				default_value = true,
				tooltip = "auto_upload_completed_missions_tooltip",
			},
			{
				setting_id = "auto_upload_scope",
				type = "dropdown",
				default_value = "successful_only",
				options = {
					{text = "auto_upload_scope_successful_only", value = "successful_only"},
					{text = "auto_upload_scope_all_missions", value = "all_missions"},
				},
				tooltip = "auto_upload_scope_tooltip",
			},
			{
				setting_id = "account_link_status",
				type = "dropdown",
				default_value = "not_linked",
				options = {
					{text = "account_link_status_not_linked", value = "not_linked"},
					{text = "account_link_status_linked", value = "linked"},
				},
				tooltip = "account_link_status_tooltip",
			},
			{
				setting_id = "account_link_action",
				type = "dropdown",
				default_value = "none",
				options = {
					{text = "account_link_action_none", value = "none"},
					{text = "account_link_action_show_command", value = "show_command"},
				},
				tooltip = "account_link_action_tooltip",
			},
			{
				setting_id = "account_unlink_action",
				type = "dropdown",
				default_value = "keep",
				options = {
					{text = "account_unlink_keep", value = "keep"},
					{text = "account_unlink_disconnect", value = "disconnect"},
				},
				tooltip = "account_unlink_action_tooltip",
			},
		},
	},
}
