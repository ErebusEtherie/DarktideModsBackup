CHANGELOG
1.15.00 Text options

1.15.00 Planned changes
-- [ ] Terminus Warrant changes
-- [ ] Performance pass
-- [ ] Text alignment tweaks

1.14.2 Beyond the Hive first update
-- [Fixed] Fixed ALIVE check error from Fatshark hotfix (with help from POLIVOX)

1.14.1 Beyond the Hive first update
-- [Updated] Ogryn power maul recharge 10s
-- [Fixed] Fixed potential crash if FS retires a font

1.14.00 Bugfix
-- [Fixed] Corruption segment of player toughness/hp bar was misaligned when increasing HUD spread

1.13.00 Paul, ammo and FPS
-- [New] Charge bar can show ogryn power maul recharge progress
-- [New] Streamline Popups will show ammo waste (only if you are not running Numeric UI)
-- [New] Show class icons in assist interaction popups (if using Streamline Popups)
-- [Better] Shiv charges shown while using other weapons if grenade viz "hide when empty" (suggested by IroskTheOrc)
-- [Better] Option to show loaded ammo all the time (suggested by Wobin and IroskTheOrc)
-- [Better] Options to show numeric player toughness ("Always (Toughness and HP Text)")
-- [Better] Team HUD performance improvement (suggested by POLIVOX)
-- [Better] Some tooltip improvements
-- [Better] Player HUD performance improvement

1.12.00 Real ammo for charged weapons
-- [New] Ammo text options to calculate remaining shots available e.g. for plasma (suggested by jcyl2023)
-- [New] Option to always have player HP text visible below toughness bar, for those who like clutter
-- [Better] If stamina viz threshold is 10% or less then the hide threshold will be 50% rather than 100% (inspired by IroskTheOrc)
-- [Better] Improved handling of player status icons with vanilla hud in spectate mode
-- [Better] Minor tweaks to team hud aesthetics
-- [Fixed] Setting always show toughness without hp segments now no longer shows hp segments (reported by jcyl2023)

1.11.00 Grenade icons
-- [New] Charge bar can now show Pinpoint Targeting blessing stacks (suggested by Bullgryn Onion)
-- [Better] More noticeable pulsing cartel stimm icon alert 10 secs before Chem Dependency decay
-- [Better] Stimm visibility contexts improved for Cartel stimm
-- [Better] Tweaks to vanilla UI streamlining
-- [Better] Tweaks to status icons
-- [Better] Overhauled proximity context to be simpler and break less often
-- [Fixed] Better compatibility with Profile Pictures mod when using minimalist vanilla team panel
-- [Fixed] Fixed medicae context (again)
-- [Fixed] Replaced placeholder squares with real grenade icons in docked and nameplate team HUDs

1.10.00 Tracking Major Buffs
-- [New] Talent buff bar: Ability buff timer option expanded to include second widget for important talent buffs
-- [New] Talent buff bar: Support for showing remaining cooldown on Until Death/Holy Revenant
-- [New] Talent buff bar: Support for showing stacks of Terminus Warrant (suggested by Wobin)
-- [New] Talent buff bar: Support for showing stacks of Empowered Psionics (suggested by Norkkom)
-- [New] Talent buff bar: Support for showing remaining cooldown on Burst of Energy (suggested by Norkkom)
-- [New] Charge bar can show Thrust stacks and similar melee buffs eg crowbar (suggested by Bullgryn Onion)
-- [New] Cartel Stimm visual alert to maintain Chemical Dependency (stimm pulses and grows)
-- [New] Audible alert when Cartel Stimm comes off cooldown (green stimm injection sound)
-- [Better] Option to keep loaded ammo visible while wielding ranged weapons (suggested by Algramic)
-- [Fixed] Fixed grenade bar cap that was stuck on 6 (reported by Simrathe)
-- [Fixed] Fixed medicae context (again)

1.09.02 More tweaks
-- [New] If using a needle pistol, loaded ammo bar colour will indicate mode (suggested by Wobin)
-- [Better] XY offset sliders now bigger (suggested by blayzekiller)
-- [Better] Minimalist vanilla team panel will now show ammo reserve percentage if team ammo not disabled
-- [Better] Minimalist vanilla team panel will not show icons for "grenades" that can't use pickups
-- [Better] Tidied up settings layout
-- [Better] Updated Chinese localisation from jcyl2023
-- [Fixed] Boom Bringer (missile launcher) no longer triggers charge bar (reported by Norkkom)
-- [Fixed] Added some missing localisation
-- [Fixed] Nameplate names fixed for (hopefully) all combos of True Level and Who Are You (reported by Kaarug)
-- [Known] Sometimes DT bugs and gives invalid team slot colours (RH defaults to white). This will break nameplate names.

1.09.01 Grenade patch and Team Layouts
-- [New] Alternative layout and positioning settings for docked team panels
-- [New] Setting to separate/spread the player's Ring HUD while using an auspex
-- [Fixed] Fixed a crash relating to team grenade icons, will be using placeholder items until better solution found
-- [Fixed] Corrected some localisations

1.09 Hive Scum
-- [New] Hive Scum stimm cooldown, buff timer and icon colour (can change colour with RecolorStimms mod)
-- [New] Hive Scum Desperado and Rampage buffs added to ability timer feature
-- [New] Hive Scum throwing shiv ammo shown in charge bar
-- [New] Settings to control x,y position of player hud element
-- [New] Option for showing extra ability charges
-- [New] If carrying two weapons that overheat (plasma+falchion) the peril bar prioritises current weapon but shows a thin line for the other weapon
-- [New] Additional ability ready sounds to choose from
-- [New] Decluttering vanilla team panels added as team hud option
-- [New] Hive Scum grenade regen now shown in grenades widget (when the buff doesn't bug out)
-- [Better] Performance overhaul
-- [Better] Class agnostic team grenade icon logic
-- [Better] Reworked HUD element scaling
-- [Better] More robust player state indicator icon logic
-- [Better] More efficient interaction with Ration Pack and Markers All in One
-- [Better] Reorganised team settings for clarity
-- [Better] Enhanced ability to declutter default HUD
-- [Better] More granular control over teammate status icons
-- [Better] Improvements to contextual teammate settings
-- [Fixed] Grimoire/scripture icon colours
-- [Fixed] Fixed an issue with the MeowBeep crosshair feature
-- [Fixed] No longer removes tag skulls

1.08a Hive Scum crash fix
-- [Fixed] Fixed crash caused by new Hive Scum class

1.08 Audible Ability Recharge Fix
-- [Fixed] Fix conflict with Audible Ability Recharge
-- [Fixed] Removed options for feature that is not yet implemented

1.07 Team Tiles
-- [New] ADS scale and separation controls
-- [New] Team health bars (ignores bots), gold toughness, broken toughness (red border)
-- [New] Team panels docked and undocked modes
-- [New] Team rescue progress (green border), ledge time to fall (red border)
-- [New] Team reserve ammo, blitz, pocketables, cooldown
-- [New] Team toughness counter, hp counter
-- [New] RecolorStimms compatibility
-- [Better] Moved player stimm widget
-- [Better] Altered outlines and fills to make bars more readable
-- [Better] Force show no longer shows grenade bar for smite / brain burst
-- [Fixed] Apply "enhanced blitz" mutator and other buffs to grenade bar max grenades

1.06 Pocketables and layout
-- [New] Pocketables and optional contextual visibility for pocketables
-- [New] Dynamic hp text label -- text label is always dynamic to reduce clutter
-- [New] Scale slider to make this thing huge
-- [New] Separation slider to make this thing square
-- [Better] Enhanced context sensitivity for toughness/health bar
-- [Better] Overhauled mod structure
-- [Fixed] Prevented Ring HUD visual elements persisting after mod is disabled

1.05 Arbites
-- Arbite/adamant grenade regen
-- Control adamant shield charge with helbore setting instead of FGS setting
-- Improved compatibility with Ration Pack mod

1.04 Chinese language
-- Chinese localisation by jcyl2023

1.03 Compatibility and immersion
-- Deadshot stamina
-- Move with crosshair
-- Options to hide native HUD elements
-- Fix Nuncio Aquila crash
-- No longer disrupts Stimms Pickup Icon mod

1.02 Munitions and toughness
-- Toughness/HP bar.
-- Green dodges border if full.
-- White charge up border if no peril.
-- Always show stamina if threshold set to 0, always hide if set to negative. Same as dodges.
-- Change peril color progression. Skip blue.
-- Ammo clip bar.
-- Ammo clip text widget.
-- Ammo reserve text label.
-- Grenade bar.
-- Hot key to show all while held.
-- Detect proximity to ammo for dynamic setting.
-- Detect proximity to healing for dynamic setting.

1.01 Initial release (required a reupload)
