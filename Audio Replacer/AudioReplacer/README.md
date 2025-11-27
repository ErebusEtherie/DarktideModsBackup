# AudioReplacer
AudioReplacer by Claytor

 -- This mod is an edited version of Danktide (EnemyAudioReplacer) by Jortune1

Very WIP, need to add more hooks to sounds in the future.

Check requirements! You need to refresh mods by using CTRL + SHIFT + R after changing options.

Need to have developer mode and console enabled, as described in Audio Plugin mod 

Known issues: Small stutters when playing some sounds, probably because it's reading files directly

How to install:
1: Install requirements
2: Move AudioReplacer to your mods folder
3: Add AudioReplacer to mod_load_order
4: In mod options, check which sounds you want changed.
5: Overwrite the files in AudioReplacer\audio with whatever sounds you want, .opus is recommended file format but mp3 works too. Right now you need to have the same names as the names in the existing folders


Changelog:

1.0

Added the following hooks:

Psyker Dome Shield
Stub Revolver
Player Death
Medpack Deploy
Healing Syringe Use
Buff Syringe Use
Veteran Infiltrate
Veteran Killshot Stance
Pox Burster

Changed Bolstering Prayer replacer to play only once per use.

Separated Veteran & Psyker shouts into independant files.

1.1

Added the following hooks:

Veteran Frag Grenade
Veteran Smoke Grenade
Veteran Krak Grenade
Zealot Stun Grenade
Zealot Fire Grenade
Ogryn Box Grenade
Ogryn Frag Grenade

1.2

Added the following hooks:

Pox Hound Group Spawn (Special Modifier Missions)

1.3

Added 10 second cooldown to Flame grenade to mitigate situations where Bombers could spam the audio.
^ Also slightly reduced volume.

1.4

Fixed XIV Stub Revolver and reduced volume.
^ You can use the PewPew mod by tinybike (GlaresAtKoalas on Nexus) to change other weapons to the same SFX.

1.5

Added the following hooks:

Ogryn Blunt Weapons (Bully Clubs, Shield, ect.)

1.6

Added the following hooks:

Special Enemy Killed
Elite Enemy Killed
^ Both of these will use the same audio files for now.

1.7

Added the following hooks:

Ogryn Point-Blank Barrage Ability
Zealot Fury of the Faithful Dash Ability
Psyker Scrier's Gaze Ability

1.8

Added the following hooks:

Radio Operator "Calling for Backup"
Horde Incoming Warning
Pox Hound Tackled Player

Changed the following default sounds:

Pox Hound Jump

1.9

Added the following hooks:

Accatran Shotgun Firing
Accatran Shotgun Reload
Accatran Shotgun Pump
Accatran Shotgun Special
Psyker Force Block (Force Swords)
Ogryn Rumbler/Kickback Reload
Ogryn Rumbler Firing (Silent by default)
Ogryn Grenade Gauntlet Firing (Silent by default)
Explosion Echo (Silent by default)

1.10

Added the following hooks:

Arbites Castigan's Stance Ability
Arbites Break the Line Ability (Empty Placeholder)
Arbites Shield Special Attack
Arbites Dog Voice
Arbites Dog Bite
Arbites Dog Jump Attack

1.11

Weapon changes that are 3D audio will no longer be recommended for usage.

Grenade audio also doesnt work properly, but they are much less noticable.

I implemented 3D player audio in a way that doesnt work properly, and leads to other
player audio changes to be played at maximum volume or to not work at all.

I am not actively seeking a fix for this problem as this is just a funny hobby of mine
and would require coding work that I am not familiar with.


Added the following hooks:

Ranged Backstab Warning


Changed the following default sounds:

Ogryn Blunt Weapons (Shortened to reduce overlapping)

1.12

Added the following hooks:

Reaper Death
Reaper Attack
Reaper Hurt
Reaper Melee Attack

1.13

Added the following hooks:

Arbites Remote Detonation Blitz
Renegade Netgunner Attack
Force Greatsword Charge


Changed the following default sounds:

Player Netted


1.14

Added the following hooks:

Psyker Staff Primary (Silent by default)


1.15

Added the following hooks:

Psyker Staff Impact (Silent by default, DOESNT WORK WITH SURGE!)
Psyker Critical Peril
Psyker Peril Overload
Psyker Long Scream/Heavy Damage Silencer (For use with Overloading sounds, MIGHT NOT WORK PROPERLY ON ALL PERSONALITY TYPES!)


1.16

Added the following hooks:

Renegade Grenadier Fuse/Pre-explosion
Renegade Grenadier Footsteps
Renegade Grenadier Explosion
Renegade Grenadier Throwing


1.17

Changed the following default sounds:

Arbites Break the Line Ability