local constants = require("constants")

-- Allow recipe settings copy/paste to the craft and provider chests.
-- Explicit self-targets also enable copy/paste between built chests of the same type.
local function add_target(prototype, name)
    local targets = prototype.additional_pastable_entities or {}
    for _, target in pairs(targets) do
        if target == name then return end
    end
    targets[#targets + 1] = name
    prototype.additional_pastable_entities = targets
end

add_target(data.raw["linked-container"][constants.GLOBAL_CHEST_ENTITY_NAME], constants.GLOBAL_CHEST_ENTITY_NAME)

local chests = {
    data.raw["linked-container"][constants.GLOBAL_CRAFT_CHEST_ENTITY_NAME],
    data.raw["logistic-container"][constants.GLOBAL_PROVIDER_CHEST_ENTITY_NAME]
}
for _, chest in ipairs(chests) do
    add_target(chest, chest.name)
    for _, category in ipairs({ "assembling-machine", "furnace" }) do
        for _, machine in pairs(data.raw[category] or {}) do
            add_target(machine, chest.name)
            add_target(chest, machine.name)
        end
    end
end

-- Add global provider chest unlock to construction-robotics technology
if data.raw["technology"]["construction-robotics"] then
    table.insert(data.raw["technology"]["construction-robotics"].effects, {
        type = "unlock-recipe",
        recipe = constants.GLOBAL_PROVIDER_CHEST_ENTITY_NAME
    })
end
