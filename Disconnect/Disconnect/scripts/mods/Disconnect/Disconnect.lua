local mod = get_mod("Disconnect")

mod.Disconnect_func = function()
	local disconnect = mod:get("mod_disconnect")
	if disconnect == "exit_to_main_menu" and not mod:get("mod_disconnect_party") then	
		Managers.multiplayer_session:leave("exit_to_main_menu")
	elseif disconnect == "leave_to_hub" and not mod:get("mod_disconnect_party") then
		Managers.multiplayer_session:leave("leave_to_hub")
	elseif disconnect == "exit_to_main_menu" and mod:get("mod_disconnect_party") then	
		Managers.party_immaterium:leave_party()
		Managers.multiplayer_session:leave("exit_to_main_menu")
	elseif disconnect == "leave_to_hub" and mod:get("mod_disconnect_party") then
		Managers.party_immaterium:leave_party()
		Managers.multiplayer_session:leave("leave_to_hub")	
	end	
end

mod:command("dis", mod:localize("disconnect_description"), function()
	mod:Disconnect_func()
end)

mod.disconnect_keybind_func = function()
	if not Managers.ui:chat_using_input() then
		mod:Disconnect_func()
	end
end