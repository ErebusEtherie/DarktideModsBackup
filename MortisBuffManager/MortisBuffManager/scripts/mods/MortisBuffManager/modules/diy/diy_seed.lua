-- Seed controls belong to the owning manager, never an installed definition.
local S={maximum=2147483646}
function S.valid(value)
    return type(value)=="number" and value==value and value%1==0 and value>=1 and value<=S.maximum
end
function S.validate(raw)
    if type(raw)~="table" or getmetatable(raw) or type(raw.enabled)~="boolean" or not S.valid(raw.value) then return nil end
    for key in pairs(raw)do if key~="enabled" and key~="value" then return nil end end
    return {enabled=raw.enabled,value=raw.value}
end
function S.resolve(config,mission_seed)
    if config.enabled then return config.value end
    if S.valid(mission_seed) then return mission_seed end
    return math.random(1,S.maximum)
end
function S.new(mod)
    local self={}
    function self.get()
        local saved=mod:get("diy_seed_v1");local config=S.validate(saved)
        if config then return config end
        local old=mod:get("diy_options_v1");local seed=type(old)=="table" and old.seed
        return {enabled=S.valid(seed) and seed~=1 or false,value=S.valid(seed) and seed or 1}
    end
    function self.set(config)
        local clean=S.validate(config);if not clean then return false end
        mod:set("diy_seed_v1",clean);return true
    end
    function self.resolve(mission_seed) return S.resolve(self.get(),mission_seed) end
    return self
end
return S
