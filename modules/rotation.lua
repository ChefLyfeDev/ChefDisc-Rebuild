-- Rotation Module
-- Handles the main combat rotation logic for Discipline Priest

local rotation = {}

-- Required modules
local enums = require("common/enums")
local unit_helper = require("common/utility/unit_helper")
local plugin_helper = require("common/utility/plugin_helper")
local buff_manager = require("common/modules/buff_manager")
local target_selector = require("common/modules/target_selector")
local spell_helper = require("common/utility/spell_helper")
local spell_queue = require("common/modules/spell_queue")

-- Local modules
local constants = require("modules/constants")
local utility = require("modules/utility")
local ramp = require("modules/ramp")

-- Target selector override
local is_ts_overriden = false

-- Setup target selector override for Discipline Priest
function rotation.override_ts_settings(menu_elements)
if is_ts_overriden then
    return
end

local is_override_allowed = menu_elements.ts_custom_logic_override:get_state()
if not is_override_allowed then
    return
end

-- If the menu elements don't exist yet, wait until they do
if not target_selector.menu_elements or 
   not target_selector.menu_elements.settings or 
   not target_selector.menu_elements.damage or 
   not target_selector.menu_elements.healing then
    return
end

-- Set safe values for range
if target_selector.menu_elements.settings.max_range_damage then
    target_selector.menu_elements.settings.max_range_damage:set(40)
end

if target_selector.menu_elements.settings.max_range_heal then
    target_selector.menu_elements.settings.max_range_heal:set(40)
end

-- Emphasize nearby targets for damage
if target_selector.menu_elements.damage.weight_distance then
    target_selector.menu_elements.damage.weight_distance:set(true)
end

if target_selector.menu_elements.damage.slider_weight_distance then
    target_selector.menu_elements.damage.slider_weight_distance:set(3)
end

-- Prioritize low health for healing
if target_selector.menu_elements.healing.weight_health then
    target_selector.menu_elements.healing.weight_health:set(true)
end

if target_selector.menu_elements.healing.slider_weight_health then
    target_selector.menu_elements.healing.slider_weight_health:set(4)
end

is_ts_overriden = true
end

-- Check keybinds and handle specific key presses
---@param local_player game_object
---@param heal_targets_list table
---@param menu_elements table
---@return boolean
function rotation.handle_keybinds(local_player, heal_targets_list, menu_elements)
-- Check for ramp key
if menu_elements.enable_ramping:get_state() then
    -- Check for manual ramp key press
    if ramp.check_manual_ramp(menu_elements.manual_ramp_key) then
        return true
    end
    
    -- Check for mini-ramp key press
    if ramp.check_mini_ramp(menu_elements.mini_ramp_key) then
        return true
    end
    
    -- Check for Voidweaver ramp key press (only if Voidweaver spec is selected)
    if menu_elements.voidweaver_spec:get_state() and menu_elements.enable_voidweaver_ramp:get_state() then
        if ramp.check_voidweaver_ramp(menu_elements.voidweaver_ramp_key) then
            return true
        end
    end
    
    -- Check for Voidweaver mini-ramp key press (only if Voidweaver spec is selected)
    if menu_elements.voidweaver_spec:get_state() and menu_elements.enable_voidweaver_mini_ramp:get_state() then
        if ramp.check_voidweaver_mini_ramp(menu_elements.voidweaver_mini_ramp_key) then
            return true
        end
    end
    
    -- Check for auto-ramp from BigWigs
    if ramp.check_auto_ramp(
        menu_elements.ramp_automatically:get_state(), 
        menu_elements.ramp_time_before_event:get()
    ) then
        return true
    end
    
    -- Check for health-based mini-ramp
    if ramp.check_health_based_ramp(
        menu_elements.enable_health_based_ramp:get_state(),
        menu_elements.health_ramp_threshold:get(),
        heal_targets_list
    ) then
        return true
    end
end

-- Check for Pain Suppression key press
local is_defensive_allowed = plugin_helper:is_defensive_allowed()
if is_defensive_allowed and plugin_helper:is_keybind_enabled(menu_elements.pain_suppression_key) then
    for _, heal_target in ipairs(heal_targets_list) do
        if utility.cast_pain_suppression(local_player, heal_target, menu_elements.enable_pain_suppression:get_state()) then
            plugin_helper:set_defensive_block_time(3.0)
            return true
        end
        break  -- Only try the first target
    end
end

-- Check for Power Infusion key press
if plugin_helper:is_keybind_enabled(menu_elements.power_infusion_key) then
    if menu_elements.power_infusion_self:get_state() then
        if utility.cast_power_infusion(local_player, local_player, menu_elements.enable_power_infusion:get_state()) then
            return true
        end
    else
        -- Find a DPS player to buff
        for _, target in ipairs(heal_targets_list) do
            if unit_helper:get_role_id(target) == enums.group_role.DAMAGER and target:is_player() then
                if utility.cast_power_infusion(local_player, target, menu_elements.enable_power_infusion:get_state()) then
                    return true
                end
                break
            end
        end
    end
end

-- Check for Spirit Shell key press
if plugin_helper:is_keybind_enabled(menu_elements.spirit_shell_key) then
    if utility.cast_spirit_shell(local_player, menu_elements.enable_spirit_shell:get_state()) then
        return true
    end
end

return false
end

-- Handle emergency defensives and critical situations
---@param local_player game_object
---@param heal_targets_list table
---@param menu_elements table
---@return boolean
function rotation.handle_defensives(local_player, heal_targets_list, menu_elements)
local is_defensive_allowed = plugin_helper:is_defensive_allowed()
if not is_defensive_allowed then
    return false
end

for _, heal_target in ipairs(heal_targets_list) do
    if not heal_target or not heal_target:is_valid() then
        goto continue
    end

    -- Critical situation for tank
    if unit_helper:get_role_id(heal_target) == enums.group_role.TANK then
        local health_percentage = unit_helper:get_health_percentage(heal_target)
        if health_percentage < 0.4 then  -- 40% health or lower
            if utility.cast_pain_suppression(local_player, heal_target, menu_elements.enable_pain_suppression:get_state()) then
                plugin_helper:set_defensive_block_time(3.0)
                return true
            end
        end
    end

    -- Critical situation for any player
    if heal_target:is_player() then
        local health_percentage = unit_helper:get_health_percentage(heal_target)
        if health_percentage < 0.3 then  -- 30% health or lower
            if utility.cast_pain_suppression(local_player, heal_target, menu_elements.enable_pain_suppression:get_state()) then
                plugin_helper:set_defensive_block_time(3.0)
                return true
            end
        end
    end

    ::continue::
end

return false
end

-- Mythic+ rotation logic
---@param local_player game_object The local player object
---@param targets_list table<game_object> List of damage targets from target selector
---@param heal_targets_list table<game_object> List of healing targets from target selector
---@param menu_elements table UI menu elements containing user settings
---@return boolean Returns true if an action was taken
function rotation.execute_mythic_plus_rotation(local_player, targets_list, heal_targets_list, menu_elements)
    -- Safety check for valid parameters
    if not local_player or not local_player:is_valid() then
        return false
    end
    
    if not targets_list or #targets_list == 0 then
        targets_list = {}
    end
    
    if not heal_targets_list or #heal_targets_list == 0 then
        heal_targets_list = {}
    end
    
    -- Check if we're in ramping mode - if so, execute ramp logic
    if ramp.is_ramping and ramp.execute_ramp(local_player, heal_targets_list, menu_elements) then
        return true
    end
    
    -- During ramping phase 4 (damage phase), we prioritize damage without stopping ramping
    local in_damage_phase = ramp.is_in_damage_phase()
    
    -- Get healing style and content settings
    local prioritize_atonement = menu_elements.prioritize_atonement:get_state()
    local allow_reactive_healing = menu_elements.allow_reactive_healing:get_state()
    
    -- Get thresholds from menu elements
    local emergency_threshold = menu_elements.emergency_heal_threshold:get() / 100.0
    local critical_threshold = menu_elements.critical_heal_threshold:get() / 100.0
    local shield_threshold = menu_elements.shield_threshold:get() / 100.0
    local tank_shield_threshold = menu_elements.tank_shield_threshold:get() / 100.0
    local execute_threshold = menu_elements.execute_threshold:get() / 100.0
    local dot_refresh_threshold = menu_elements.dot_refresh_threshold:get() * 1000 -- Convert to ms
    
    -- Determine if we need to do healing or damage
    local is_healing_needed = false
    for _, target in ipairs(heal_targets_list) do
        if unit_helper:get_health_percentage(target) < 90 then
            is_healing_needed = true
            break
        end
    end
    
    -- HEALING ROTATION
    if is_healing_needed then
        -- 1. Maintain Atonement on Group via Power Word: Radiance if entire Group is taking damage
        local group_damage = 0
        for _, target in ipairs(heal_targets_list) do
            if unit_helper:get_health_percentage(target) < 90 then
                group_damage = group_damage + 1
            end
        end
        
        -- If most of the group is taking damage, use Power Word: Radiance
        if group_damage >= 3 then
            -- Find best target for Radiance (most grouped allies)
            local best_target = nil
            local max_nearby = 0
            
            for _, center_target in ipairs(heal_targets_list) do
                local nearby_count = 0
                for _, nearby_target in ipairs(heal_targets_list) do
                    if center_target:get_position():dist_to(nearby_target:get_position()) <= 10 then
                        nearby_count = nearby_count + 1
                    end
                end
                
                if nearby_count > max_nearby then
                    max_nearby = nearby_count
                    best_target = center_target
                end
            end
            
            if best_target and utility.cast_power_word_radiance(
                local_player, 
                best_target, 
                menu_elements.enable_power_word_radiance:get_state(),
                heal_targets_list,
                false) then
                return true
            end
        end
        
        -- 2. Apply Atonement via Power Word: Shield to targets who require healing
        for _, target in ipairs(heal_targets_list) do
            if not utility.has_atonement(target) and unit_helper:get_health_percentage(target) < 90 then
                if utility.cast_power_word_shield(local_player, target, menu_elements.enable_shield:get_state()) then
                    return true
                end
            end
        end
        
        -- Check if we have a valid damage target
        local damage_target = nil
        if #targets_list > 0 and targets_list[1]:is_valid() and targets_list[1]:is_in_combat() then
            damage_target = targets_list[1]
        end
        
        if damage_target then
            -- 3. Cast Mindbender on Cooldown
            if utility.cast_mindbender(local_player, damage_target, menu_elements.enable_mindbender:get_state()) then
                return true
            end
            
            -- 4. Cast Mind Blast on Cooldown
            if utility.cast_mind_blast(local_player, damage_target, menu_elements.enable_mind_blast:get_state()) then
                return true
            end
            
            -- 5. Cast Penance on Cooldown
            if utility.cast_penance(
                local_player, damage_target, true, 
                menu_elements.enable_penance_damage:get_state(),
                menu_elements.enable_penance_heal:get_state()) then
                return true
            end
            
            -- 6. Cast Shadow Word: Death on Cooldown
            if utility.cast_shadow_word_death(local_player, damage_target, menu_elements.enable_shadow_word_death:get_state()) then
                return true
            end
            
            -- 7. Keep Shadow Word: Pain on your target
            local dot_data = buff_manager:get_debuff_data(damage_target, constants.buff_ids.SHADOW_WORD_PAIN)
            if not dot_data.is_active or dot_data.remaining < dot_refresh_threshold then
                if utility.cast_shadow_word_pain(local_player, damage_target, menu_elements.enable_shadow_word_pain:get_state(), dot_refresh_threshold) then
                    return true
                end
            end
            
            -- 8. Cast Smite
            if utility.cast_smite(local_player, damage_target, menu_elements.enable_smite:get_state()) then
                return true
            end
        else
            -- 9. Cast Flash Heal if there is no enemy to hit
            -- Find the most injured player
            local lowest_health_target = nil
            local lowest_health = 100
            
            for _, target in ipairs(heal_targets_list) do
                local health = unit_helper:get_health_percentage(target)
                if health < lowest_health then
                    lowest_health = health
                    lowest_health_target = target
                end
            end
            
            if lowest_health_target and utility.cast_flash_heal(local_player, lowest_health_target, menu_elements.enable_flash_heal:get_state()) then
                return true
            end
        end
    
    -- DAMAGE ROTATION
    else
        -- Check if we have a valid damage target
        if #targets_list == 0 or not targets_list[1]:is_valid() or not targets_list[1]:is_in_combat() then
            return false
        end
        
        local damage_target = targets_list[1]
        
        -- 1. Keep Shadow Word: Pain on your target
        local dot_data = buff_manager:get_debuff_data(damage_target, constants.buff_ids.SHADOW_WORD_PAIN)
        if not dot_data.is_active or dot_data.remaining < dot_refresh_threshold then
            if utility.cast_shadow_word_pain(local_player, damage_target, menu_elements.enable_shadow_word_pain:get_state(), dot_refresh_threshold) then
                return true
            end
        end
        
        -- 2. Cast Mindbender on Cooldown
        if utility.cast_mindbender(local_player, damage_target, menu_elements.enable_mindbender:get_state()) then
            return true
        end
        
        -- 3. Cast Mind Blast on Cooldown
        if utility.cast_mind_blast(local_player, damage_target, menu_elements.enable_mind_blast:get_state()) then
            return true
        end
        
        -- 4. Cast Penance on Cooldown
        if utility.cast_penance(
            local_player, damage_target, true, 
            menu_elements.enable_penance_damage:get_state(),
            menu_elements.enable_penance_heal:get_state()) then
            return true
        end
        
        -- 5. Cast Shadow Word: Death on Cooldown
        if utility.cast_shadow_word_death(local_player, damage_target, menu_elements.enable_shadow_word_death:get_state()) then
            return true
        end
        
        -- 6. Cast Halo on Cooldown
        if utility.cast_halo(local_player, menu_elements.enable_halo:get_state()) then
            return true
        end
        
        -- 7. Cast Smite
        if utility.cast_smite(local_player, damage_target, menu_elements.enable_smite:get_state()) then
            return true
        end
    }
    
    return false
end

-- Raid rotation logic
---@param local_player game_object The local player object
---@param targets_list table<game_object> List of damage targets from target selector
---@param heal_targets_list table<game_object> List of healing targets from target selector
---@param menu_elements table UI menu elements containing user settings
---@return boolean Returns true if an action was taken
function rotation.execute_raid_rotation(local_player, targets_list, heal_targets_list, menu_elements)
    -- Safety check for valid parameters
    if not local_player or not local_player:is_valid() then
        return false
    end
    
    if not targets_list or #targets_list == 0 then
        targets_list = {}
    end
    
    if not heal_targets_list or #heal_targets_list == 0 then
        heal_targets_list = {}
    end
    
    -- Check if we're in ramping mode - if so, execute ramp logic
    if ramp.is_ramping and ramp.execute_ramp(local_player, heal_targets_list, menu_elements) then
        return true
    end
    
    -- During ramping phase 4 (damage phase), we prioritize damage without stopping ramping
    local in_damage_phase = ramp.is_in_damage_phase()
    
    -- Get healing style and content settings
    local prioritize_atonement = menu_elements.prioritize_atonement:get_state()
    local allow_reactive_healing = menu_elements.allow_reactive_healing:get_state()
    
    -- Get thresholds from menu elements
    local emergency_threshold = menu_elements.emergency_heal_threshold:get() / 100.0
    local critical_threshold = menu_elements.critical_heal_threshold:get() / 100.0
    local shield_threshold = menu_elements.shield_threshold:get() / 100.0
    local tank_shield_threshold = menu_elements.tank_shield_threshold:get() / 100.0
    local execute_threshold = menu_elements.execute_threshold:get() / 100.0
    local min_atonement_count = menu_elements.min_atonement_count:get()
    local refresh_atonement_threshold = menu_elements.refresh_atonement_threshold:get() * 1000 -- Convert to ms
    local prioritize_tank_atonement = menu_elements.prioritize_tank_atonement:get_state()
    local dot_refresh_threshold = menu_elements.dot_refresh_threshold:get() * 1000 -- Convert to ms
    
    -- First priority: Emergency healing when someone is critically low
    if (allow_reactive_healing || in_damage_phase) then
        for _, target in ipairs(heal_targets_list) do
            local health_percentage = unit_helper:get_health_percentage(target)
            local is_tank = unit_helper:is_tank(target)
            
            -- Always protect tanks regardless of healing style settings
            if (health_percentage < emergency_threshold and (allow_reactive_healing or is_tank)) then -- Critical health - under threshold
                -- Use emergency cooldowns for tanks or very low health
                if health_percentage < critical_threshold or is_tank then
                    if menu_elements.enable_pain_suppression:get_state() and 
                       utility.cast_pain_suppression(local_player, target, menu_elements.enable_pain_suppression:get_state()) then
                        return true
                    end
                    
                    if is_tank and 
                       utility.cast_power_word_shield(local_player, target, menu_elements.enable_shield:get_state()) then
                        return true
                    end
                end
                
                -- Use direct healing
                if utility.cast_shadow_mend(local_player, target, menu_elements.enable_shadowmend:get_state()) then
                    return true
                end
                
                if utility.cast_penance(local_player, target, false, 
                                       menu_elements.enable_penance_damage:get_state(),
                                       menu_elements.enable_penance_heal:get_state()) then
                    return true
                end
            end
        end
    end
    
    -- Second priority: Atonement maintenance for raid-wide coverage
    local atonement_count = utility.count_atonements(heal_targets_list)
    
    -- In raid, we prioritize wide atonement coverage
    if not in_damage_phase and atonement_count < min_atonement_count then
        -- First prioritize tanks if setting enabled
        if prioritize_tank_atonement then
            for _, target in ipairs(heal_targets_list) do
                if unit_helper:is_tank(target) and not utility.has_atonement(target) then
                    if utility.cast_power_word_shield(local_player, target, menu_elements.enable_shield:get_state()) then
                        return true
                    end
                end
            end
        end
        
        -- Then regular targets for wide coverage
        for _, target in ipairs(heal_targets_list) do
            if not utility.has_atonement(target) then
                if utility.cast_power_word_shield(local_player, target, menu_elements.enable_shield:get_state()) then
                    return true
                end
            end
        end
    end
    
    -- Third priority: Shield tanks or targets taking damage based on thresholds
    if not in_damage_phase then
        -- Prioritize tank atonement refreshing
        if prioritize_tank_atonement then
            for _, target in ipairs(heal_targets_list) do
                if unit_helper:is_tank(target) then
                    local atonement_remaining = utility.get_atonement_remaining(target)
                    if atonement_remaining > 0 and atonement_remaining < refresh_atonement_threshold then
                        if utility.cast_power_word_shield(local_player, target, menu_elements.enable_shield:get_state()) then
                            return true
                        end
                    end
                end
            end
        end
        
        -- Shield based on specific thresholds
        for _, target in ipairs(heal_targets_list) do
            local health_percentage = unit_helper:get_health_percentage(target)
            local threshold_to_use = unit_helper:is_tank(target) and tank_shield_threshold or shield_threshold
            
            if health_percentage <= threshold_to_use then
                if not utility.has_atonement(target) then
                    if utility.cast_power_word_shield(local_player, target, menu_elements.enable_shield:get_state()) then
                        return true
                    end
                end
            end
        end
        
        -- Refresh any atonements about to expire
        for _, target in ipairs(heal_targets_list) do
            local atonement_remaining = utility.get_atonement_remaining(target)
            if atonement_remaining > 0 and atonement_remaining < refresh_atonement_threshold then
                if utility.cast_power_word_shield(local_player, target, menu_elements.enable_shield:get_state()) then
                    return true
                end
            end
        end
    end
    
    -- Fourth priority: DoT maintenance with multi-dotting for raid
    -- In raid we can multi-DoT for more atonement healing
    local dotted_count = 0
    for _, target in ipairs(targets_list) do
        if target:is_in_combat() then
            local dot_data = buff_manager:get_debuff_data(target, constants.buff_ids.SHADOW_WORD_PAIN)
            if not dot_data.is_active or dot_data.remaining < dot_refresh_threshold then
                if utility.cast_shadow_word_pain(local_player, target, menu_elements.enable_shadow_word_pain:get_state(), dot_refresh_threshold) then
                    dotted_count = dotted_count + 1
                    if dotted_count >= 3 then -- Limit to 3 targets for multi-dotting
                        break
                    end
                    return true
                end
            end
        end
    end
    
    -- Fifth priority: Damage rotation for Atonement healing
    for _, target in ipairs(targets_list) do
        if not target:is_in_combat() then
            goto continue
        end
        
        -- Check for execute range
        local health_percentage = unit_helper:get_health_percentage(target)
        if health_percentage < execute_threshold and utility.cast_shadow_word_death(
            local_player, target, menu_elements.enable_shadow_word_death:get_state()) then
            return true
        end
        
        -- Use Mind Games if available
        if utility.cast_mind_games(local_player, target, menu_elements.enable_mind_games:get_state()) then
            return true
        end
        
        -- Dark Side Penance prioritization
        local dark_side_buff = buff_manager:get_buff_data(local_player, constants.buff_ids.POWER_OF_THE_DARK_SIDE)
        if dark_side_buff.is_active and utility.cast_penance(
            local_player, target, true, 
            menu_elements.enable_penance_damage:get_state(),
            menu_elements.enable_penance_heal:get_state()) then
            return true
        end
        
        -- Mind Blast as it's more mana efficient
        if utility.cast_mind_blast(local_player, target, menu_elements.enable_mind_blast:get_state()) then
            return true
        end
        
        -- Regular Penance
        if utility.cast_penance(
            local_player, target, true, 
            menu_elements.enable_penance_damage:get_state(),
            menu_elements.enable_penance_heal:get_state()) then
            return true
        end
        
        -- Lastly, Smite as filler
        if utility.cast_smite(local_player, target, menu_elements.enable_smite:get_state()) then
            return true
        end
        
        ::continue::
    end
    
    -- If nothing else to do, shield people preemptively
    if not in_damage_phase then
        for _, target in ipairs(heal_targets_list) do
            if target and target:is_valid() and not utility.has_atonement(target) then
                if utility.cast_power_word_shield(local_player, target, menu_elements.enable_shield:get_state()) then
                    return true
                end
            end
        end
    end
    
    return false
end

-- Main rotation dispatcher - calls appropriate rotation based on settings
---@param local_player game_object The local player object
---@param targets_list table<game_object> List of damage targets from target selector
---@param heal_targets_list table<game_object> List of healing targets from target selector
---@param menu_elements table UI menu elements containing user settings
---@return boolean Returns true if an action was taken
-- Voidweaver specific M+ rotation
---@param local_player game_object
---@param targets_list table<game_object>
---@param heal_targets_list table<game_object>
---@param menu_elements table
---@return boolean
function rotation.execute_voidweaver_mythic_plus_rotation(local_player, targets_list, heal_targets_list, menu_elements)
    -- Safety check for valid parameters
    if not local_player or not local_player:is_valid() then
        return false
    end
    
    if not targets_list or #targets_list == 0 then
        targets_list = {}
    end
    
    if not heal_targets_list or #heal_targets_list == 0 then
        heal_targets_list = {}
    end

    -- Get thresholds from menu elements
    local dot_refresh_threshold = menu_elements.dot_refresh_threshold:get() * 1000 -- Convert to ms
    
    -- Check if we have a valid damage target
    if #targets_list == 0 or not targets_list[1]:is_valid() then
        return false
    end
    
    local damage_target = targets_list[1]
    
    -- Determine if focused healing is needed
    local healing_needed = false
    local critical_healing = false
    local tank_target = nil
    
    for _, target in ipairs(heal_targets_list) do
        if unit_helper:is_tank(target) then
            tank_target = target
            if unit_helper:get_health_percentage(target) < 70 then
                healing_needed = true
            end
            if unit_helper:get_health_percentage(target) < 40 then
                critical_healing = true
            end
        elseif unit_helper:get_health_percentage(target) < 60 then
            healing_needed = true
        end
        if unit_helper:get_health_percentage(target) < 30 then
            critical_healing = true
        end
    end
    
    -- 1. Always maintain Shadow Word: Pain on the main target
    local dot_data = buff_manager:get_debuff_data(damage_target, constants.buff_ids.SHADOW_WORD_PAIN)
    if not dot_data.is_active or dot_data.remaining < dot_refresh_threshold then
        if utility.cast_shadow_word_pain(local_player, damage_target, menu_elements.enable_shadow_word_pain:get_state(), dot_refresh_threshold) then
            return true
        end
    end
    
    -- 2. Use Shadow Covenant/Voidwraith to empower damage abilities when needed
    if menu_elements.enable_shadow_covenant:get_state() and not critical_healing then
        if utility.cast_shadow_covenant(local_player, menu_elements.enable_shadow_covenant:get_state()) then
            return true
        end
    end
    
    if not critical_healing and menu_elements.enable_voidwraith:get_state() then
        if utility.cast_voidwraith(local_player, damage_target, menu_elements.enable_voidwraith:get_state()) then
            return true
        end
    end
    
    -- 3. Always shield the tank constantly
    if tank_target and not utility.has_atonement(tank_target) then
        if utility.cast_power_word_shield(local_player, tank_target, menu_elements.enable_shield:get_state()) then
            return true
        end
    end
    
    -- 4. Cast Penance to deal damage and spread Shadow Word: Pain
    if utility.cast_penance(local_player, damage_target, true, 
                           menu_elements.enable_penance_damage:get_state(), 
                           menu_elements.enable_penance_heal:get_state()) then
        return true
    end
    
    -- When producing large party healing, follow the priority
    if healing_needed then
        -- 5a. Cast Power Word: Shield on injured players
        for _, target in ipairs(heal_targets_list) do
            if unit_helper:get_health_percentage(target) < 75 and not utility.has_atonement(target) then
                if utility.cast_power_word_shield(local_player, target, menu_elements.enable_shield:get_state()) then
                    return true
                end
            end
        end
        
        -- 5b. Cast Mindbender for additional damage/healing
        if utility.cast_mindbender(local_player, damage_target, menu_elements.enable_mindbender:get_state()) then
            return true
        end
        
        -- 5c. Cast Power Word: Radiance for party-wide healing
        -- Find best target for Radiance (most grouped allies)
        local best_target = nil
        local max_nearby = 0
        
        for _, center_target in ipairs(heal_targets_list) do
            local nearby_count = 0
            for _, nearby_target in ipairs(heal_targets_list) do
                if center_target:get_position():dist_to(nearby_target:get_position()) <= 10 then
                    nearby_count = nearby_count + 1
                end
            end
            
            if nearby_count > max_nearby then
                max_nearby = nearby_count
                best_target = center_target
            end
        end
        
        if best_target and utility.cast_power_word_radiance(
            local_player, 
            best_target, 
            menu_elements.enable_power_word_radiance:get_state(),
            heal_targets_list,
            false) then
            return true
        end
    end
    
    -- 6. Cast Mind Blast
    if utility.cast_mind_blast(local_player, damage_target, menu_elements.enable_mind_blast:get_state()) then
        return true
    end
    
    -- 7. Check for execute range for Shadow Word: Death
    local health_percentage = unit_helper:get_health_percentage(damage_target)
    if health_percentage < 20 and utility.cast_shadow_word_death(
        local_player, damage_target, menu_elements.enable_shadow_word_death:get_state()) then
        return true
    end
    
    -- 8. Cast Void Blast until Penance is back
    if utility.cast_void_blast(local_player, damage_target, menu_elements.enable_void_blast:get_state()) then
        return true
    end
    
    -- 9. Use Evangelism if we have multiple Atonements and need healing
    if healing_needed then
        local atonement_count = utility.count_atonements(heal_targets_list)
        if atonement_count >= 3 and utility.cast_evangelism(
            local_player, 
            menu_elements.enable_evangelism:get_state(),
            heal_targets_list,
            false) then
            return true
        end
    end
    
    -- 10. Entropic Rift for major cooldown
    if menu_elements.enable_entropic_rift:get_state() and not critical_healing then
        if utility.cast_entropic_rift(local_player, damage_target, menu_elements.enable_entropic_rift:get_state()) then
            return true
        end
    end
    
    -- 11. Fallback to Smite
    if utility.cast_smite(local_player, damage_target, menu_elements.enable_smite:get_state()) then
        return true
    end
    
    return false
end

function rotation.execute_rotation(local_player, targets_list, heal_targets_list, menu_elements)
    -- Check which rotation mode is selected
    local is_mythic_plus = menu_elements.mythic_plus_mode:get_state()
    local is_raid_mode = menu_elements.raid_mode:get_state()
    
    -- Check specialization
    local is_oracle = menu_elements.oracle_spec:get_state()
    local is_voidweaver = menu_elements.voidweaver_spec:get_state()
    
    -- Default to raid rotation if nothing selected
    if not is_mythic_plus and not is_raid_mode then
        is_raid_mode = true
    end
    
    -- Default to Oracle spec if none selected
    if not is_oracle and not is_voidweaver then
        is_oracle = true
    end
    
    -- Dispatch to the correct rotation based on spec and content type
    if is_voidweaver and is_mythic_plus then
        return rotation.execute_voidweaver_mythic_plus_rotation(local_player, targets_list, heal_targets_list, menu_elements)
    elseif is_mythic_plus then
        return rotation.execute_mythic_plus_rotation(local_player, targets_list, heal_targets_list, menu_elements)
    else
        return rotation.execute_raid_rotation(local_player, targets_list, heal_targets_list, menu_elements)
    end

-- Check if we're in ramping mode - if so, execute ramp logic
if ramp.is_ramping and ramp.execute_ramp(local_player, heal_targets_list, menu_elements) then
    return true
end

-- During ramping phase 4 (damage phase), we prioritize damage without stopping ramping
local in_damage_phase = ramp.is_in_damage_phase()

-- Get healing style and content settings
local prioritize_atonement = menu_elements.prioritize_atonement:get_state()
local allow_reactive_healing = menu_elements.allow_reactive_healing:get_state()
local is_mythic_plus = menu_elements.mythic_plus_mode:get_state()

-- Get thresholds from menu elements
local emergency_threshold = menu_elements.emergency_heal_threshold:get() / 100.0
local critical_threshold = menu_elements.critical_heal_threshold:get() / 100.0
local shield_threshold = menu_elements.shield_threshold:get() / 100.0
local tank_shield_threshold = menu_elements.tank_shield_threshold:get() / 100.0
local execute_threshold = menu_elements.execute_threshold:get() / 100.0
local min_atonement_count = menu_elements.min_atonement_count:get()
local refresh_atonement_threshold = menu_elements.refresh_atonement_threshold:get() * 1000 -- Convert to ms
local prioritize_tank_atonement = menu_elements.prioritize_tank_atonement:get_state()
local dot_refresh_threshold = menu_elements.dot_refresh_threshold:get() * 1000 -- Convert to ms

-- First priority: Emergency healing when someone is critically low
-- Only do this if reactive healing is allowed or if it's a tank (who always get priority)
if (allow_reactive_healing or is_mythic_plus) and not in_damage_phase then
    for _, target in ipairs(heal_targets_list) do
        local health_percentage = unit_helper:get_health_percentage(target)
        local is_tank = unit_helper:is_tank(target)
        
        -- Always protect tanks regardless of healing style settings
        if (health_percentage < emergency_threshold and (allow_reactive_healing or is_tank)) then -- Critical health - under threshold
            -- Use emergency cooldowns for tanks or very low health
            if health_percentage < critical_threshold or is_tank then
                if menu_elements.enable_pain_suppression:get_state() and 
                   utility.cast_pain_suppression(local_player, target, menu_elements.enable_pain_suppression:get_state()) then
                    return true
                end
                
                if is_tank and 
                   utility.cast_power_word_shield(local_player, target, menu_elements.enable_shield:get_state()) then
                    return true
                end
            end
            
            -- Use direct healing
            if utility.cast_shadow_mend(local_player, target, menu_elements.enable_shadowmend:get_state()) then
                return true
            end
            
            if utility.cast_penance(local_player, target, false, 
                                    menu_elements.enable_penance_damage:get_state(),
                                    menu_elements.enable_penance_heal:get_state()) then
                return true
            end
        end
    end
end

-- Second priority: Atonement maintenance through shields
-- This is the core of proactive healing for Discipline
-- Count how many targets have atonement
local atonement_count = utility.count_atonements(heal_targets_list)

-- Determine if we should focus on Atonement coverage
local should_maintain_atonement = prioritize_atonement or not in_damage_phase

-- If we're in Mythic+, always prioritize maintaining tank atonement
if is_mythic_plus then
    prioritize_tank_atonement = true
end

-- Apply shields to maintain atonement (unless in damage phase)
if should_maintain_atonement and atonement_count < min_atonement_count then
    -- First prioritize tanks if setting enabled
    if prioritize_tank_atonement then
        for _, target in ipairs(heal_targets_list) do
            if unit_helper:is_tank(target) and not utility.has_atonement(target) then
                if utility.cast_power_word_shield(local_player, target, menu_elements.enable_shield:get_state()) then
                    return true
                end
            end
        end
    end
    
    -- Then regular targets
    for _, target in ipairs(heal_targets_list) do
        if not utility.has_atonement(target) then
            if utility.cast_power_word_shield(local_player, target, menu_elements.enable_shield:get_state()) then
                return true
            end
        end
    end
end

-- Third priority: Shield tanks or targets taking damage based on thresholds
if not in_damage_phase then
    -- Prioritize tank atonement refreshing
    if prioritize_tank_atonement then
        for _, target in ipairs(heal_targets_list) do
            if unit_helper:is_tank(target) then
                local atonement_remaining = utility.get_atonement_remaining(target)
                if atonement_remaining > 0 and atonement_remaining < refresh_atonement_threshold then
                    if utility.cast_power_word_shield(local_player, target, menu_elements.enable_shield:get_state()) then
                        return true
                    end
                end
            end
        end
    end
    
    -- Shield based on specific thresholds
    for _, target in ipairs(heal_targets_list) do
        local health_percentage = unit_helper:get_health_percentage(target)
        local threshold_to_use = unit_helper:is_tank(target) and tank_shield_threshold or shield_threshold
        
        if health_percentage <= threshold_to_use then
            if not utility.has_atonement(target) then
                if utility.cast_power_word_shield(local_player, target, menu_elements.enable_shield:get_state()) then
                    return true
                end
            end
        end
    end
    
    -- Refresh any atonements about to expire
    for _, target in ipairs(heal_targets_list) do
        local atonement_remaining = utility.get_atonement_remaining(target)
        if atonement_remaining > 0 and atonement_remaining < refresh_atonement_threshold then
            if utility.cast_power_word_shield(local_player, target, menu_elements.enable_shield:get_state()) then
                return true
            end
        end
    end
end

-- Fourth priority: Maintain critical buffs for self
local dark_side_buff = buff_manager:get_buff_data(local_player, constants.buff_ids.POWER_OF_THE_DARK_SIDE)

-- Fifth priority: DoT maintenance with refresh threshold
for _, target in ipairs(targets_list) do
    if target:is_in_combat() then
        local dot_data = buff_manager:get_debuff_data(target, constants.buff_ids.SHADOW_WORD_PAIN)
        if not dot_data.is_active or dot_data.remaining < dot_refresh_threshold then
            if utility.cast_shadow_word_pain(local_player, target, menu_elements.enable_shadow_word_pain:get_state(), dot_refresh_threshold) then
                return true
            end
        end
    end
end

-- Sixth priority: Damage rotation for Atonement healing
for _, target in ipairs(targets_list) do
    if not target:is_in_combat() then
        goto continue
    end
    
    -- Check for execute range
    local health_percentage = unit_helper:get_health_percentage(target)
    if health_percentage < execute_threshold and utility.cast_shadow_word_death(
        local_player, target, menu_elements.enable_shadow_word_death:get_state()) then
        return true
    end
    
    -- Use Mind Games if available
    if utility.cast_mind_games(local_player, target, menu_elements.enable_mind_games:get_state()) then
        return true
    end
    
    -- If Power of the Dark Side is active, prioritize Penance
    if dark_side_buff.is_active and utility.cast_penance(
        local_player, target, true, 
        menu_elements.enable_penance_damage:get_state(),
        menu_elements.enable_penance_heal:get_state()) then
        return true
    end
    
    -- Mind Blast as it's more mana efficient
    if utility.cast_mind_blast(local_player, target, menu_elements.enable_mind_blast:get_state()) then
        return true
    end
    
    -- Regular Penance
    if utility.cast_penance(
        local_player, target, true, 
        menu_elements.enable_penance_damage:get_state(),
        menu_elements.enable_penance_heal:get_state()) then
        return true
    end
    
    -- Lastly, Smite as filler
    if utility.cast_smite(local_player, target, menu_elements.enable_smite:get_state()) then
        return true
    end
    
    ::continue::
end

-- If nothing else to do, shield people preemptively
if not in_damage_phase then
    for _, target in ipairs(heal_targets_list) do
        if target and target:is_valid() and not utility.has_atonement(target) then
            if utility.cast_power_word_shield(local_player, target, menu_elements.enable_shield:get_state()) then
                return true
            end
        end
    end
end

return false
end