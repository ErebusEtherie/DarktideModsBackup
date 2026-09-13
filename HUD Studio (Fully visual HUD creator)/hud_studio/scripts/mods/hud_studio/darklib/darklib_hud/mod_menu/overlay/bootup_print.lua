---@param Module DLH_ModMenu
---@param mod mod
return function(Module, mod)
	if Module.bootup_print then
		return Module.bootup_print
	end

	local print = mod.dl.loc_helpers.lines(
		"==============================================================",
		" MARS FORGE NETWORK :: COGITATOR ACCESS TERMINAL",
		" DIVISIO CYBERNETICA :: SECURE DATASTACK",
		"==============================================================",
		"",
		"BOOTSTRAP..............................................COMPLETE",
		"MACHINE SPIRIT.........................................RESPONSIVE",
		"NOOSPHERIC LINK........................................ESTABLISHED",
		"",
		"> initialize()",
		"[0001] Loading binharic kernel.................................OK",
		"[0002] Initializing cogitator memory banks.....................OK",
		"[0003] Verifying logic engines................................OK",
		"[0004] Synchronizing chronometer...............................OK",
		"[0005] Loading lexmechanic libraries...........................OK",
		"[0006] Establishing noosphere interface........................OK",
		"[0007] Mounting primary data-loom..............................OK",
		"[0008] Loading cipher lexicon.................................OK",
		"",
		"> operator.status",
		"Designation.........................ENGINSEER PRIME",
		"Forge World.........................MARS",
		"Rank Authentication.................VALID",
		"Binharic Cipher.....................CURRENT",
		"Access Level........................MAGENTA",
		"",
		"> system.status",
		"Machine Spirit......................RESPONSIVE",
		"Logic Engine........................OPTIMAL",
		"Core Temperature....................41C",
		"Data Integrity......................99.99996%",
		"Memory Utilization..................18.4%",
		"Fault Registers.....................NONE",
		"",
		"> archive.index",
		"/liber_mechanicus/",
		"/stc_fragment_index/",
		"/expurgated/",
		"",
		"> security.audit",
		"Operator Clearance..................VERIFIED",
		"Gene-Lock...........................MATCH",
		"Cipher Authorization................ACCEPTED",
		"Archive Restrictions................ENFORCED",
		"Execution Privileges................GRANTED",
		"",
		"NOTICE:",
		'"Knowledge is power. Guard it well."',
		"",
		"WARNING:",
		"UNAUTHORIZED DATA RECOVERY WILL BE LOGGED.",
		"SCRAPCODE CONTAINMENT PROTOCOLS ARE ACTIVE.",
		"ALL COGITATOR TRANSACTIONS ARE RECORDED.",
		"",
		"==============================================================",
		" COGITATOR READY",
		" ENTER COMMAND",
		"==============================================================",
		">"
	)

	Module.bootup_print = print

	return print
end
