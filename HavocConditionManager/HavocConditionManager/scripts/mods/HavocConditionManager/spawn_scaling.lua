local M = { default = 1, minimum = 1, maximum = 5 }
M.categories = { common = "common", elite = "elite", special = "special", boss = "boss" }
M.setting_ids, M.ordered_setting_ids = {}, {}
for _, category in ipairs({"common", "elite", "special", "boss"}) do
    M.setting_ids[category] = "spawn_multiplier_" .. category
    M.ordered_setting_ids[#M.ordered_setting_ids + 1] = M.setting_ids[category]
end
M.normalize = function(value)
    return math.max(1, math.min(5, math.floor((tonumber(value) or 1) + 0.5)))
end
M.category_for_breed = function(breed)
    if type(breed) ~= "table" or breed.is_untargetable or breed.breed_type and breed.breed_type ~= "minion" then return end
    local tags = breed.tags or {}
    if tags.witch or tags.ritualist then return end
    if tags.monster or tags.captain or tags.cultist_captain then return "boss" end
    if tags.special then return "special" end
    if tags.elite then return "elite" end
    return "common"
end
M.factors = function(value, mode)
    local multiplier = M.normalize(value)
    if mode == "speed" then return multiplier, 1 end
    if mode == "mixed" then
        local speed = math.sqrt(multiplier)
        return speed, multiplier / speed
    end
    return 1, multiplier
end
-- Carry fractional remainders rather than biasing every single spawn upward.
M.extra_count = function(factor, remainder)
    local total = (remainder or 0) + math.max(0, factor - 1)
    local count = math.floor(total + 0.000001)
    return count, total - count
end
return M
