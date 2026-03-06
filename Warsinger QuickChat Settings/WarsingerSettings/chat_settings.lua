--[[
    You can add your custom chat messages by editing this file.
    Each setting must follow the template below.

    {
        id = "<id>",
        title = "<title>",
        message = "<message>"
    },

    id      -- Unique string that does not duplicate others. Use "_" (underscore) instead of " " (space) .
    title   -- Text that appears on the option menu.
    message -- Text that you want to send. If you use a table (array), a message is randomly selected from it.

    You can use "[name]" as a place holder.
    It will be replaced by the character name of the player who triggered the event.
]]

-- The following settings are just examples. Feel free to remove or edit them. Credits and thank u's to Zombine ~ (Omimpotent)

return {
    {
        id = "alert_daemonhost",
        title = "Daemonhost",
        message = {
            "Daemonhost!",
            "I sense a Daemonhost!",
            "I think I hear a Daemonhost?",
            "Oh hel… It's a Daemonhost!",
            "Stay alert! A Daemonhost!",
            "Throne… It's a fragging Daemonhost!",
        }
    },
    {
        id = "alert_need_help",
        title = "Need Help",
        message = "I need help!"
    },
    {
        id = "alert_stay_together",
        title = "Stay Together",
        message = {"Close up! Stay together!",
		"Fall into defensive positions! the enemy rallies!",
		"Regroup before the heretics close in! You watch my back i'll watch yours!"
		}
		
    },
    {
        id = "greeting_good_game",
        title = "Good Game",
        message = "gg :3"
    },
    {
        id = "greeting_player_joined",
        title = "Greeting",
        message = "Hi [name]"
    },
    {
        id = "response_yes",
        title = "Yes",
        message = "{#color(0, 200, 0)}Yes",
    },
    {
        id = "response_no",
        title = "No",
        message = "{#color(255, 0, 0)}No"
    },
    {
        id = "response_sorry",
        title = "Sorry",
        message = "{#color(100, 57, 64)}Sorry!"
    },
    {
        id = "deploy_med_self",
        title = "Deploy Med (self)",
        message = "Medi-pack downed"
    },
    {
        id = "deploy_med_others",
        title = "Deploy Med (others)",
        message = "[name] deployed a medi-pack"
    },
    {
        id = "deploy_ammo_self",
        title = "Deploy Ammo (self)",
        message = "Ammo crate downed"
    },
    {
        id = "deploy_ammo_others",
        title = "Deploy Ammo (others)",
        message = "[name] deployed an ammo crate"
    },
	{
		id = " Im_Charging",
		title = "Im Charging",
		message = {"Charge, in the name of the Emperor!",
					"Grut it, I'm Charging!",
					"The Emperor is speaking to me, and he says CHARGE!",
					"Are you lot allergic to taking ground? Charge for Atoma!",
					"You all lookin for the hero of Atoma Prime? I'm right here! CHARGE!"
					}
	},
	{
		id = "Grimoire",
        title = "Grimoire",
        message = "{#color(100, 149, 237)}Grimoire!"
		
    },
	{
		id = "Thanks!",
        title = "Thanks",
        message = "Thanks!"
		
    },
		{
		id = " Hold_Ground",
		title = "Hold Ground",
		message = {"Stand your ground and lay waste to the slaves of Darkness!",
					"We are the wrath of the Empra! Allow them not to profane hive Tertium a second longer!",
					"Take cover, hold ground, make them bleed!",
					"Stay out of the open! Dig in and repel the traitorus filth!" 
					}
	},
		{
		id = " Kark",
		title = "kark",
		message = {"Kark!",
					"Kark these heretics!",
					"Come at me ya Karkers!"
					"Pray to your filthy god for some cologne Kark-heads!"
					}
	},
		{
		id = " Frag",
		title = "Frag",
		message = {"Open fire on these fraggin' heretics!",
					"Frag me! These idiots smell!",
					"RAAAAAWR! Put the fraggers six feet under! ",
					"By the fraggin' throne!"
					}
	},
		{
		id = "I_Need_Healing!",
        title = "I Need Healing!",
        message = {"I require healing, else Nurgle claim my soul!",
		"Lord of Terra, grant the healing touch to my weary body!",
		"Help me to the Medicae, fore i turn into a corpse please!"
					}
	},
    
		{
		id = "Morale_Check",
        title = "Morale Check",
        message = {"Morale Check:Absolute!: By the Master of Mankind We cast you from our domain Nurgle! To admit defeat is to blaspheme against the Emperor! Hear our Warsong miserable apostates!", 
		"Morale Check:6:I feel the hand of the Emperor on my shoulder, we cannot lose!",
		"Morale Check:6:Hold your heads high! We are the finest Rejects the Moebain domain has to offer!",
		"Morale Check:5:Lookin' good Rejects! let's do this 'un fer the big T!",
		"Morale Check:5:That's it lads! Show the Admonition what a REAL fight looks like!",
		"Morale Check:4:I heard we're getting fed today! dibs on the chocolate corpse starch!",
		"Morale Check:4:This might be a rough skirmish comin' up, pass the stimms will ya? Some of us still like to party!",
		"Morale Check:3:It occurs to me... i might not make it back this time.",
		"Morale Check:2:We might die in this Hel-bitten corpse heap.",
		"Morale Check:1:The situation is Frakin' hopeless... maybe we should try desertion?",
		"Morale Check:0:I can feel the shame of the Emperor creeping over me."
		"Morale Check:-6:Indulge in violence! Revel in excess!",
		"Morale Check:-7:The pox, its in me lungs... HAHAHAHA I AM A WORM IN HUMAN SKIN!",
		"Morale Check:-8:Show yourself heretics! This battleground shall run red with your ruin!",
		"Morale Check:-9:Nurgle's entropy shall no longer be tolerated. The wheels of fate crush these heretics!"
					}
	},
		{
		id = "Cooldown_Perils",
		title = "Cooldown Perils",
		message = {"I feel the perils of the warp closing in on me! Lend me cover!",
		"Get out of my mind! cover me as i quell the never-born!",
		"Agh, the buzzing is becoming too much! give me cover as i regain focus of my witch-senses!"
		}
	},
		{
		id = "Cooldown_Shield",
		title = "Coolddown Shield",
		message = "10 seconds to deployment of telekine dome! Stand defiant to the maniacs!"
	},
		{
		id = "Cooldown_Book",
		title = "Cooldown Book",
		message = "10 seconds until the next prayer! Rejoice sinners!"
	},
		{
		id = "Objective_Cover",
		title = "Objective Cover",
		message = {"Lord of Mankind, send me a servant who will cover me whilst i do the objective!",
		"You Muckers keep their heads down while i do the objective!",
		"Did Chegorach send you jokers? Fire on the heretics while i do the objective!"}
	},
		{
		id = "Revive_Cover",
		title = "Revive Cover",
		message = {"Shephards of Atoma, cover me while i help this lost lamb to their feet!",
		"Oi squaddies, push them off to the grave while i recover our friend will ya!",
		"You lot keep firing with your eyes closed while i get the lil un', Sahs!"}
	}
	
    
}