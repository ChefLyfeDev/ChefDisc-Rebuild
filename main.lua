-- Discipline Priest Rotation
-- This script implements a complete rotation for Discipline Priests focusing on
-- Atonement healing through damage, direct healing, and ramping for upcoming damage events

-- Import common modules
---@type enums
local enums = require("common/enums")
local spell_queue = require("common/modules/spell_queue")
local target_selector = require("common/modules/target_selector")
local control_panel_helper = require("common/utility/control_panel_helper")
local plugin_helper = require("common/utility/plugin_helper")
local pvp_helper = require("common/utility/pvp_helper")

-- Import local modules
local ui = require("modules/ui")
local constants = require("modules/constants")
local utility = require("modules/utility")
local ramp = require("modules/ramp")
local rotation = require("modules/rotation")

-- Main update function - called every frame
local function my_on_update()
    -- Control Panel Drag & Drop
    control_panel_helper:on_update(ui.menu_elements)

    -- No local player check
    local local_player = core.object_manager.get_local_player()
    if not local_player then
        return
    end

    -- Check if the user disabled the script
    if not ui.menu_elements.enable_script_check:get_state() then
        return
    end

    if not plugin_helper:is_toggle_enabled(ui.menu_elements.enable_toggle) then
        return
    end

    -- Check if currently casting or channeling
    local cast_end_time = local_player:get_active_spell_cast_end_time()
    if cast_end_time > 0.0 then
        return false
    end

    local channel_end_time = local_player:get_active_channel_cast_end_time()
    if channel_end_time > 0.0 then
        return false
    end

    -- Do not run the rotation code while mounted
    if local_player:is_mounted() then
        return
    end

    -- Override TS settings
    rotation.override_ts_settings(ui.menu_elements)

    -- Get all targets from the target selector
    local targets_list = target_selector:get_targets(5) -- Get up to 5 targets
    local heal_targets_list = target_selector:get_targets_heal(5) -- Get up to 5 healing targets
    
    -- Filter out cycloned targets from heal targets list
    local filtered_heal_targets = {}
    for _, heal_target in ipairs(heal_targets_list) do
        if not pvp_helper:is_crowd_controlled(heal_target, pvp_helper.cc_flags.combine("CYCLONE"), 100) then
            table.insert(filtered_heal_targets, heal_target)
        end
    end
    
    -- First, check for keybinds
    if rotation.handle_keybinds(local_player, filtered_heal_targets, ui.menu_elements) then
        return true
    end
    
    -- Next, check for critical defensive situations
    if rotation.handle_defensives(local_player, filtered_heal_targets, ui.menu_elements) then
        return true
    end

    -- Execute the main rotation logic
    return rotation.execute_rotation(local_player, targets_list, filtered_heal_targets, ui.menu_elements)
end

-- Function to count atonements for UI display
local function count_atonements_for_ui()
    local heal_targets = target_selector:get_targets_heal()
    local count = 0
    
    for _, target in ipairs(heal_targets) do
        if utility.has_atonement(target) then
            count = count + 1
        end
    end
    
    return count
end

-- Render on-screen elements
local function my_on_render()
    -- Pass needed data to UI module for rendering
    ui.render_screen(
        ramp.is_ramping,
        ramp.ramp_phase,
        ramp.ramp_start_time,
        ramp.next_big_damage_time,
        count_atonements_for_ui
    )
end

-- Control panel rendering
local function on_control_panel_render()
    return ui.render_control_panel()
end

-- Register Callbacks
core.register_on_update_callback(my_on_update)
core.register_on_render_callback(my_on_render)
core.register_on_render_menu_callback(ui.render_menu)
core.register_on_render_control_panel_callback(on_control_panel_render)

-- Return success to indicate the script loaded correctly
return true