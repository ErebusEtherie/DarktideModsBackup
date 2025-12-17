local mod = get_mod("A la Mode")

return {
	name = mod:localize("mod_name"),
	description = mod:localize("mod_description"),
	is_togglable = true,
	  options = {
		widgets = {
      {
        setting_id = "alm_open_setup",
        type = "checkbox",
        default_value = false,      
      },      
    }
  }
}
