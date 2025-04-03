-- Discipline Priest Rotation
-- Author: ChefLyfe
-- Version: 1.0
-- Description: Advanced Discipline Priest rotation with Atonement management and damage ramping

local plugin = {}

plugin["name"] = "Discipline Priest"
plugin["version"] = "1.0"
plugin["author"] = "ChefLyfe"
plugin["load"] = true

-- Check if local player exists before loading the script
local local_player = core.object_manager.get_local_player()
if not local_player then
    plugin["load"] = false
    return plugin
end

---@type enums
local enums = require("common/enums")
local player_class = local_player:get_class()

-- Only load for Priest class
local is_valid_class = player_class == enums.class_id.PRIEST

if not is_valid_class then
    plugin["load"] = false
    return plugin
end

-- Only load for Discipline specialization
local player_spec_id = core.spell_book.get_specialization_id()
local discipline_priest_id = 1 -- Discipline spec ID

if player_spec_id ~= discipline_priest_id then
    plugin["load"] = false
    return plugin
end

return plugin