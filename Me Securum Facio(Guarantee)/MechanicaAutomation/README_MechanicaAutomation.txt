Mechanica Automation
====================

Scope
-----
Mechanica Automation is a standalone Darktide Mod Framework mod for the Skitarii/Cryptic servo-skull kit.
It does not edit Darktide binaries or installed game files. It only emits normal SmartTag/companion-order
requests when the game exposes a valid servo-skull command for the current target.

Main features
-------------
- Servo Artificer tasks: visible hacking, puzzle, scan, and objective targets are ordered when the
  game exposes a companion-order template for them.
- Noospheric Command helper: repeats servo-skull enemy orders at the configured interval, with trapper /
  netgunner priority set above all other enemies.
- Smart Pox and threat alerts: pox bursters and trappers remain prioritized by the auto ping logic when
  their safety rules are met.
- Menu language selector for English, Spanish, and Portuguese Brazil notifications.

Install
-------
Copy or deploy the MechanicaAutomation folder into the Darktide mods folder, then add this line to
mods/mod_load_order.txt:

MechanicaAutomation

Compatibility notes
-------------------
- The mod is rate-limited and uses physics-safe callbacks by default.
- The mod disables itself in hubs by default.
- If AutoMark is also enabled, both mods may issue servo-skull enemy orders. You can reduce overlap by
  disabling AutoMark's Skitarii servo-skull automation or disabling Mechanica Automation's Noospheric helper.
