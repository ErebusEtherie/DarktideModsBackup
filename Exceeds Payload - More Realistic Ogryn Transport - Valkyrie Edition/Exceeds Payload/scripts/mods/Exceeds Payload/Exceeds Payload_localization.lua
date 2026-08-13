return {
	mod_name = {
		en = "Exceeds Payload",
	},
	mod_description = {
		en = "Sags the mission-intro Valkyrie camera under the weight of its Ogryn passengers. The more Ogryn aboard, the lower it sits (with a slow strained bob), and it lists toward the heavier side when they crowd in unevenly.",
	},
	ep_sag_deg = {
		en = "Sag pitch per Ogryn (degrees)",
	},
	ep_sag_deg_description = {
		en = "Downward pitch applied per Ogryn aboard, tilting the view so the deck reads as sitting lower. Rotation only, so it never moves the camera into geometry.",
	},
	ep_settle_deg = {
		en = "Settle wobble per Ogryn (degrees)",
	},
	ep_settle_deg_description = {
		en = "Amplitude of the slow pitch 'settle' wobble, scaled by the number of Ogryn aboard.",
	},
	ep_list_deg = {
		en = "List per imbalance (degrees)",
	},
	ep_list_deg_description = {
		en = "Roll applied for each net side imbalance. One lone Ogryn lists toward their side; with three aboard it lists toward the two-Ogryn side.",
	},
}
