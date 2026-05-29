local phrases = {

    --------------------------------------------------
    -- FUNNY
    --------------------------------------------------
    funny = {
        { text = "404'd" },
        { text = "absolutely ended" },
        { text = "made corpse starch out of the", use_determiner = false },
        { text = "audited" },
        { text = "[CENSORED]" },
        { text = "deported" },
		{ text = "mopped the floor with" },
        { text = "called SKILL ISSUE against the", use_determiner = false },
        { text = "ego checked" },
        { text = "straight disrespected" },
        { text = "alt-F4'd" },
        { text = "emotionally damaged the", use_determiner = false },
        { text = "made a statistic of"},
        { text = "salted" },
        { text = "publicly humiliated" },
        { text = "did unspeakable things to" },
    },

    --------------------------------------------------
    -- MELEE (fallback) use this for generic phrases
    --------------------------------------------------
    melee = {
        { text = "bashed" },
        { text = "battered" },
        { text = "beat" },
        { text = "canned" },
        { text = "handled" },
        { text = "mauled" },
        { text = "ragdolled" },
        { text = "laid out" },
        { text = "stomped" },
        { text = "wrecked" },
		{ text = "massacred" },
		{ text = "brutalized" },
		{ text = "beat down" },
		{ text = "roughed up" },
		{ text = "worked over" },
    },

    --------------------------------------------------
    -- SHARP (blades / chain weapons)
    --------------------------------------------------
    sharp = {
        { text = "butchered" },
        { text = "carved" },
        { text = "hacked" },
        { text = "chopped" },
        { text = "split" },
        { text = "cleaved" },
        { text = "cut down" },
        { text = "deboned" },
        { text = "dismembered" },
        { text = "filleted" },
        { text = "julienned" },
        { text = "shredded" },
        { text = "executed" },
		{ text = "sliced" },
		{ text = "skewered" },
    },

    --------------------------------------------------
    -- BLUNT (hammers / clubs)
    --------------------------------------------------
    blunt = {
        { text = "bonked" },
        { text = "compressed" },
        { text = "juiced" },
        { text = "crushed" },
        { text = "tenderized" },
        { text = "flattened" },
        { text = "folded" },
        { text = "hammered" },
        { text = "pancaked" },
        { text = "pasted" },
        { text = "pounded" },
        { text = "pulped" },
        { text = "pummeled" },
		{ text = "ragdolled" },
		{ text = "bludgeoned" },
    },

    --------------------------------------------------
    -- RANGED
    --------------------------------------------------
    ranged = {
        { text = "airholed" },
        { text = "blasted" },
        { text = "capped" },
        { text = "headshot" },
        { text = "drilled" },
        { text = "dropped" },
        { text = "gunned down" },
        { text = "iced" },
        { text = "picked off" },
        { text = "lit up" },
        { text = "perforated" },
        { text = "plugged" },
        { text = "riddled" },
        { text = "shot" },
        { text = "ventilated" },
    },

    --------------------------------------------------
    -- BURN
    --------------------------------------------------
    burn = {
        { text = "ashed" },
        { text = "burned" },
        { text = "charred" },
        { text = "cooked" },
        { text = "cremated" },
        { text = "fired" },
        { text = "crisped" },
        { text = "roasted" },
        { text = "melted" },
        { text = "incinerated" },
        { text = "blackened" },
        { text = "carbonized" },
        { text = "scorched" },
        { text = "seared" },
        { text = "torched" },
    },

    --------------------------------------------------
    -- EXPLOSIVE
    --------------------------------------------------
    explosive = {
        { text = "cratered" },
        { text = "blasted" },
        { text = "blew apart" },
        { text = "confettied" },
        { text = "fragmented" },
        { text = "launched" },
        { text = "nuked" },
        { text = "obliterated" },
		{ text = "popped" },
        { text = "scattered" },
        { text = "pulverized" },
		{ text = "bombed" },
		{ text = "shockwaved" },
		{ text = "shellshocked" },
		{ text = "fragged" },
		
    },

    --------------------------------------------------
    -- WARP
    --------------------------------------------------
    warp = {
        { text = "banished" },
        { text = "brain-fried" },
        { text = "consumed" },
        { text = "erased" },
        { text = "mind-spiked" },
        { text = "reality-checked" },
        { text = "unmade" },
        { text = "undid" },
        { text = "unraveled" },
		{ text = "mind-flayed" },
		{ text = "warped apart" },
		{ text = "willed away" },
		{ text = "psy-blasted" },
		{ text = "soul-scoured" },
		{ text = "thought-crushed" },
    },

    --------------------------------------------------
    -- ELECTRIC
    --------------------------------------------------
    electric = {
        { text = "arc burned" },
        { text = "zapped" },
		{ text = "jolted" },
        { text = "electrocuted" },
        { text = "sparked out" },
        { text = "current-cooked" },
        { text = "defibrillated" },
        { text = "overloaded" },
        { text = "overvolted" },
        { text = "convulsed" },
        { text = "shocked" },
        { text = "thunderstruck" },
        { text = "nerve-fried" },
		{ text = "ionized" },
		{ text = "voltage-spiked" },
    },

    --------------------------------------------------
    -- BLEED
    --------------------------------------------------
    bleed = {
        { text = "bled" },
        { text = "spilled" },
        { text = "cut open" },
        { text = "lacerated" },
        { text = "vein-split" },
        { text = "fed on" },
        { text = "emptied" },
        { text = "gutted" },
        { text = "eviscerated" },
        { text = "redlined" },
        { text = "harvested" },
        { text = "bled out" },
        { text = "slashed open" },
        { text = "split open" },
        { text = "unzipped" },
    },

    --------------------------------------------------
    -- TOXIN
    --------------------------------------------------
    toxin = {
        { text = "acid-washed" },
        { text = "broke down" },
        { text = "plague-kissed" },
        { text = "contaminated" },
        { text = "corroded" },
        { text = "dosed" },
        { text = "decayed" },
        { text = "decomposed" },
        { text = "dissolved" },
        { text = "septicized" },
        { text = "spoiled" },
        { text = "withered" },
        { text = "pickled" },
        { text = "poisoned" },
        { text = "rotted" },
    },

    --------------------------------------------------
    -- PLAYER DEATH / DOWNED PHRASES
    --------------------------------------------------
    death = {
        bulwark = {
            { text = "shield-checked" },
            { text = "walled off" },
            { text = "tenderized" },
            { text = "body-blocked" },
            { text = "trampled" },
        },
        crusher = {
            { text = "steamrolled" },
            { text = "folded" },
            { text = "caved in" },
            { text = "ground down" },
            { text = "hammer-checked" },
        },
        gunner = {
            { text = "shredded" },
            { text = "bullet hosed" },
            { text = "mulched" },
            { text = "used a full auto eraser on" },
            { text = "grated" },
            { text = "permanently suppressed" },
            { text = "gunned down" },
            { text = "drilled" },
            { text = "pinned" },
            { text = "riddled" },
            { text = "lit up" },
        },
        rager = {
            { text = "carved up" },
            { text = "cut down" },
            { text = "butchered" },
            { text = "rage-checked" },
            { text = "made a mess of" },
			{ text = "made confetti of" }
        },
        shotgunner = {
            { text = "blasted" },
            { text = "point-blanked" },
            { text = "buckshot-baptized" },
            { text = "painted the walls with" },
            { text = "buckshot-taxed" },
            { text = "peppered" },
			{ text = "gave both barrels to" },
			{ text = "practiced shell therapy on" },
        },
        mauler = {
            { text = "executed" },
            { text = "axe-checked" },
            { text = "split" },
            { text = "chopped down" },
            { text = "bisected" },
			{ text = "made a mess out of" },
			{ text = "processed" },
			
        },
        sniper = {
            { text = "blue-screened" },
            { text = "zeroed" },
            { text = "picked off" },
            { text = "domed" },
            { text = "headshot headshot headshot" },
            { text = "longshotted" },
            { text = "assassinated" },
        },
        hound = {
            { text = "mauled" },
            { text = "hunted down" },
            { text = "fetched" },
            { text = "tackled" },
            { text = "pinned" },
            { text = "chewed up" },
            { text = "pounced" },
            { text = "pack-checked" },
            { text = "fetched" },
        },
        poxburster = {
            { text = "hugged" },
            { text = "delivered itself to" },
            { text = "rang the doorbell against" },
            { text = "went critical on" },
            { text = "became the problem of" },
        },
        flamer = {
            { text = "roasted" },
            { text = "flame-broiled" },
            { text = "over-cooked" },
            { text = "made kindling of" },
            { text = "burned off the board" },
			{ text = "catered the funeral of" },
        },
        tox_flamer = {
            { text = "gassed" },
            { text = "made breathing optional for" },
            { text = "gave lung cancer to" },
            { text = "seasoned for Nurgle" },
            { text = "put the stink on" },
			{ text = "gave the sewer facial to" },
        },
        bomber = {
            { text = "bombed" },
            { text = "fragged" },
            { text = "sent shrapnel to" },
            { text = "redecorated the room with" },
            { text = "gave the frag special to" },
			{ text = "played hot potato with" },
        },
        tox_bomber = {
            { text = "mailed lung damage to" },
            { text = "threw OSHA violations at" },
            { text = "served the green cloud to" },
            { text = "sent a plague parcel to" },
            { text = "committed air crime against" },
        },
        mutant = {
            { text = "trucked" },
            { text = "charged down" },
            { text = "wall-slammed" },
            { text = "shoulder-checked" },
            { text = "got launched" },
        },
        trapper = {
            { text = "hogtied" },
            { text = "bagged and tagged" },
            { text = "made a package of" },
            { text = "served a restraining order to" },
            { text = "gift-wrapped" },
			{ text = "wrapped for later" },
        },
        beast_of_nurgle = {
            { text = "swallowed" },
            { text = "slimed" },
            { text = "made a snack of" },
            { text = "made Nurgle gumbo of" },
            { text = "digested" },
        },
        daemonhost = {
            { text = "punished" },
            { text = "gave the bad ending to" },
            { text = "processed the soul of" },
            { text = "turned hope off for" },
            { text = "gave the forever nap to" },
			{ text = "made the room colder for" },
        },
        plague_ogryn = {
            { text = "slapped flat" },
            { text = "body-slammed" },
            { text = "gave the rot hug to" },
            { text = "mopped the floor with" },
            { text = "plague-pounded" },
        },
        chaos_spawn = {
            { text = "mangled" },
            { text = "ragdolled" },
            { text = "made a medical mystery of" },
            { text = "gave the nightmare hug to" },
            { text = "violently rearranged" },
        },
        lesser_enemy = {
            { text = "overwhelmed" },
            { text = "mobbed" },
            { text = "crowdsourced the end of" },
            { text = "proved numbers matter to" },
            { text = "embarrassed" },
			{ text = "taught humility to" },
			{ text = "made a cautionary tale of" },
        },
        environment = {
            { text = "claimed" },
            { text = "punished" },
            { text = "deleted" },
            { text = "humbled" },
            { text = "took" },
        },
    },
}

return phrases
