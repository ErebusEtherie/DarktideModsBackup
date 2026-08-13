return {
	mod_name = {
		en = "Instant Hub",
	},
	mod_description = {
		en = "Preloads and retains Mourningstar, Meat Grinder, and current operative resources so much of the local package work can happen before transitions. Backend, host, and network synchronization still determine the remaining load time.",
	},
	hub_caching = {
		en = "Mourningstar Caching",
	},
	hub_caching_description = {
		en = "Keeps Mourningstar level, theme, UI, HUD, game-mode, and player/companion resources in memory after leaving the hub. This speeds up returns but adds roughly 500 MB-1 GB of memory use. Current operative resources also stay warm while this or Psykanium preloading is enabled. Disable if missions stutter or crash.",
	},
	show_notifications = {
		en = "Show Notifications",
	},
	show_notifications_description = {
		en = "Shows brief messages when Mourningstar or Meat Grinder preloading starts or finishes and when either destination is ready. This setting does not affect loading behavior.",
	},
	preload_hub = {
		en = "Preload Hub at Character Select",
	},
	preload_hub_description = {
		en = "Preloads Mourningstar level, UI, HUD, game-mode, and player/companion packages after backend sync, then preloads the selected operative at character select. This moves local package work ahead of the first hub transition and uses roughly 500 MB-1 GB plus operative resources. It runs again after returning to character select when needed.",
	},
	preload_psychanium = {
		en = "Preload Psychanium / Meat Grinder",
	},
	preload_psychanium_description = {
		en = "Preloads Meat Grinder level, theme, UI, HUD, game-mode, and breed packages, normally after Mourningstar enters gameplay. It can also start when enabled during gameplay or when Meat Grinder is selected. Packages and current operative resources stay warm while enabled. Uses additional memory and cannot skip host or network setup.",
	},
}
