-- scripts/mods/Ammonia/Ammonia.lua
local mod = get_mod("Ammonia")

mod:hook(CLASS.ConstantElementChat, "_add_message", function(orig, self, message, sender, channel_tag)
  if message and message:lower():find("ammo", 1, true) then
    return
  end
  return orig(self, message, sender, channel_tag)
end)

mod:hook_require("scripts/utilities/vo", function(Vo)
  local orig_play = Vo.play_event
  function Vo.play_event(self, event)
    if not event then
      return orig_play(self, event)
    end
    local se = event.sound_event and event.sound_event:lower()
    if se and (se:find("ammo", 1, true) or se:find("reload", 1, true)) then
      return
    end
    return orig_play(self, event)
  end

  if Vo.play_combat_ability_event then
    local orig_ability = Vo.play_combat_ability_event
    function Vo.play_combat_ability_event(self, player_unit, vo_tag)
      local tag = vo_tag and vo_tag:lower()
      if tag and (tag:find("ammo", 1, true) or tag:find("reload", 1, true)) then
        return
      end
      return orig_ability(self, player_unit, vo_tag)
    end
  end
end)
