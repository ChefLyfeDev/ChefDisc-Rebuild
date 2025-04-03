-- Ramp Module
-- Handles damage ramping functionality for Discipline Priest rotation
-- Ramping is the process of applying Atonement to allies before high damage events,
-- then using Evangelism to extend those Atonements and dealing damage to provide healing

local ramp = {}

-- Required modules
local utility = require("modules/utility")
local plugin_helper = require("common/utility/plugin_helper")

-- Ramping variables
ramp.is_ramping = false
ramp.ramp_start_time = 0
ramp.ramp_phase = 0  -- 0: not ramping, 1: applying shields, 2: applying radiance, 3: evangelism, 4: damage
ramp.next_big_damage_time = 0
ramp.ramping_target_count = 0
ramp.is_mini_ramp = false
ramp.is_voidweaver_ramp = false
ramp.is_voidweaver_mini_ramp = false
ramp.last_health_check_time = 0
ramp.health_check_interval = 1.0  -- Check group health every second
ramp.renew_count = 0
ramp.shield_count = 0

-- Start ramping sequence
function ramp.start_ramping(is_mini)
    if ramp.is_ramping then return end
    
    if is_mini then
        core.log("Starting mini-ramp sequence")
        ramp.is_mini_ramp = true
    else
        core.log("Starting full damage ramping sequence")
        ramp.is_mini_ramp = false
    end
    
    ramp.is_ramping = true
    ramp.ramp_start_time = core.time()
    ramp.ramp_phase = 1
    ramp.ramping_target_count = 0
end

-- Stop ramping sequence
function ramp.stop_ramping()
    if not ramp.is_ramping then return end
    
    if ramp.is_mini_ramp then
        core.log("Stopping mini-ramp sequence")
    else
        core.log("Stopping damage ramping sequence")
    end
    
    ramp.is_ramping = false
    ramp.is_mini_ramp = false
    ramp.ramp_phase = 0
    ramp.ramping_target_count = 0
end

-- Check for automatic ramping based on BigWigs timers
---@param ramp_automatically boolean
---@param ramp_threshold number
---@return boolean
function ramp.check_auto_ramp(ramp_automatically, ramp_threshold)
    if not ramp_automatically or ramp.is_ramping then
        return false
    end
    
    local should_ramp, next_damage_time, is_major_damage = utility.check_bigwigs_timers(ramp_threshold)
    if should_ramp and next_damage_time then
        ramp.next_big_damage_time = next_damage_time
        -- Use the is_major_damage flag to determine ramp type
        local is_mini = not is_major_damage
        ramp.start_ramping(is_mini)
        return true
    end
    
    return false
end

-- Check for manual ramp key press
---@param manual_ramp_key table
---@return boolean
function ramp.check_manual_ramp(manual_ramp_key)
    if ramp.is_ramping then
        return false
    end
    
    if plugin_helper:is_keybind_enabled(manual_ramp_key) then
        ramp.next_big_damage_time = core.time() + 10.0  -- Assume damage in 10 seconds for manual ramp
        ramp.start_ramping(false)  -- Start full ramp
        return true
    end
    
    return false
end

-- Check for Voidweaver ramp key press
---@param voidweaver_ramp_key table
---@return boolean
function ramp.check_voidweaver_ramp(voidweaver_ramp_key)
    if ramp.is_ramping then
        return false
    end
    
    if plugin_helper:is_keybind_enabled(voidweaver_ramp_key) then
        ramp.next_big_damage_time = core.time() + 8.0  -- Assume damage in 8 seconds for Voidweaver ramp
        ramp.is_voidweaver_ramp = true
        ramp.is_voidweaver_mini_ramp = false
        ramp.is_ramping = true
        ramp.ramp_start_time = core.time()
        ramp.ramp_phase = 1
        ramp.ramping_target_count = 0
        ramp.renew_count = 0
        return true
    end
    
    return false
end

-- Check for Voidweaver mini-ramp key press
---@param voidweaver_mini_ramp_key table
---@return boolean
function ramp.check_voidweaver_mini_ramp(voidweaver_mini_ramp_key)
    if ramp.is_ramping then
        return false
    end
    
    if plugin_helper:is_keybind_enabled(voidweaver_mini_ramp_key) then
        ramp.next_big_damage_time = core.time() + 5.0  -- Assume damage in 5 seconds for mini-ramp
        ramp.is_voidweaver_ramp = false
        ramp.is_voidweaver_mini_ramp = true
        ramp.is_ramping = true
        ramp.ramp_start_time = core.time()
        ramp.ramp_phase = 1
        ramp.ramping_target_count = 0
        ramp.shield_count = 0
        return true
    end
    
    return false
end

-- Check for mini ramp key press
---@param mini_ramp_key table
---@return boolean
function ramp.check_mini_ramp(mini_ramp_key)
    if ramp.is_ramping then
        return false
    end
    
    if plugin_helper:is_keybind_enabled(mini_ramp_key) then
        ramp.next_big_damage_time = core.time() + 6.0  -- Shorter damage window for mini ramp
        ramp.start_ramping(true)  -- Start mini ramp
        return true
    end
    
    return false
end

-- Check group health to see if we need to mini-ramp
---@param enable_health_ramp boolean
---@param health_threshold number
---@param heal_targets_list table
---@return boolean
function ramp.check_health_based_ramp(enable_health_ramp, health_threshold, heal_targets_list)
    if not enable_health_ramp or ramp.is_ramping then
        return false
    end
    
    -- Only check periodically to avoid constant ramping
    local current_time = core.time()
    if current_time - ramp.last_health_check_time < ramp.health_check_interval then
        return false
    end
    
    ramp.last_health_check_time = current_time
    
    -- Calculate group average health
    local total_health = 0
    local player_count = 0
    
    for _, target in ipairs(heal_targets_list) do
        if target and target:is_valid() and target:is_player() then
            total_health = total_health + unit_helper:get_health_percentage(target)
            player_count = player_count + 1
        end
    end
    
    -- Only ramp if we have valid targets
    if player_count > 0 then
        local average_health = total_health / player_count
        
        -- If average health is below threshold, start mini-ramp
        if average_health < health_threshold then
            ramp.next_big_damage_time = core.time() + 6.0
            ramp.start_ramping(true)  -- Start mini ramp
            return true
        end
    end
    
    return false
end

-- Execute Voidweaver-specific ramping logic
---@param local_player game_object
---@param heal_targets_list table
---@param damage_targets_list table
---@param menu_elements table
---@return boolean
function ramp.execute_voidweaver_ramp(local_player, heal_targets_list, damage_targets_list, menu_elements)
    if not ramp.is_ramping or not ramp.is_voidweaver_ramp then
        return false
    end
    
    local current_time = core.time()
    local elapsed_time = current_time - ramp.ramp_start_time
    
    -- Get the main damage target
    local damage_target = nil
    if #damage_targets_list > 0 and damage_targets_list[1]:is_valid() then
        damage_target = damage_targets_list[1]
    end
    
    -- Phases for Voidweaver ramp:
    -- 1: Refresh SWP, apply shields and renews
    -- 2: Apply Radiance
    -- 3: Cast Evangelism
    -- 4: Damage phase
    
    -- Phase 1: Refresh SWP, apply shields and renews
    if ramp.ramp_phase == 1 then
        -- 1. Refresh Shadow Word: Pain
        if damage_target then
            local dot_refresh_threshold = menu_elements.dot_refresh_threshold:get() * 1000
            local dot_data = buff_manager:get_debuff_data(damage_target, constants.buff_ids.SHADOW_WORD_PAIN)
            if not dot_data.is_active or dot_data.remaining < dot_refresh_threshold then
                if utility.cast_shadow_word_pain(local_player, damage_target, menu_elements.enable_shadow_word_pain:get_state(), dot_refresh_threshold) then
                    return true
                end
            end
        end
        
        -- 2. Cast Power Word: Shield on targets
        for _, target in ipairs(heal_targets_list) do
            if not utility.has_atonement(target) then
                if utility.cast_power_word_shield(local_player, target, menu_elements.enable_shield:get_state()) then
                    return true
                end
            end
        end
        
        -- 3. Apply Renews to spread Atonements
        local renew_target = menu_elements.voidweaver_renew_count:get()
        
        if ramp.renew_count < renew_target then
            for _, target in ipairs(heal_targets_list) do
                if not utility.has_atonement(target) then
                    if utility.cast_renew(local_player, target, menu_elements.enable_renew:get_state()) then
                        ramp.renew_count = ramp.renew_count + 1
                        return true
                    end
                end
            end
        end
        
        -- If we've applied enough renews or spent enough time, move to phase 2
        if ramp.renew_count >= renew_target or elapsed_time > 4.0 then
            ramp.ramp_phase = 2
            return false
        end
    end
    
    end
    
    -- Phase 2: Use Power Word: Radiance
    if ramp.ramp_phase == 2 then
        -- Apply Flash Heal to a target if needed
        for _, target in ipairs(heal_targets_list) do
            if not utility.has_atonement(target) and unit_helper:get_health_percentage(target) < 90 then
                if utility.cast_flash_heal(local_player, target, menu_elements.enable_flash_heal:get_state()) then
                    return true
                end
                break
            end
        end
        
        -- Cast Power Word: Shield again if needed
        for _, target in ipairs(heal_targets_list) do
            if not utility.has_atonement(target) then
                if utility.cast_power_word_shield(local_player, target, menu_elements.enable_shield:get_state()) then
                    return true
                end
                break
            end
        end
        
        -- Use both Radiance charges
        local radiance_cast_count = 0
        
        -- First Radiance on melee group
        local melee_target = nil
        local max_melee_nearby = 0
        
        for _, center_target in ipairs(heal_targets_list) do
            local nearby_count = 0
            for _, nearby_target in ipairs(heal_targets_list) do
                -- Check if target is in melee range (10 yards of another player)
                if center_target:get_position():dist_to(nearby_target:get_position()) <= 10 then
                    nearby_count = nearby_count + 1
                end
            end
            
            if nearby_count > max_melee_nearby then
                max_melee_nearby = nearby_count
                melee_target = center_target
            end
        end
        
        if melee_target and utility.cast_power_word_radiance(
            local_player, 
            melee_target, 
            menu_elements.enable_power_word_radiance:get_state(),
            heal_targets_list,
            true) then
            radiance_cast_count = radiance_cast_count + 1
            return true
        end
        
        -- Second Radiance on ranged group
        local ranged_target = nil
        local max_ranged_nearby = 0
        
        for _, center_target in ipairs(heal_targets_list) do
            -- Skip the previous melee target
            if center_target == melee_target then
                goto continue
            end
            
            local nearby_count = 0
            for _, nearby_target in ipairs(heal_targets_list) do
                -- Check if target is in range but not in melee group
                if center_target:get_position():dist_to(nearby_target:get_position()) <= 20 and 
                   (not melee_target or nearby_target:get_position():dist_to(melee_target:get_position()) > 12) then
                    nearby_count = nearby_count + 1
                end
            end
            
            if nearby_count > max_ranged_nearby then
                max_ranged_nearby = nearby_count
                ranged_target = center_target
            end
            
            ::continue::
        end
        
        if ranged_target and utility.cast_power_word_radiance(
            local_player, 
            ranged_target, 
            menu_elements.enable_power_word_radiance:get_state(),
            heal_targets_list,
            true) then
            radiance_cast_count = radiance_cast_count + 1
            return true
        end
        
        -- Move to phase 3 after enough time
        if elapsed_time > 6.0 then
            ramp.ramp_phase = 3
            return false
        end
    end
    
    -- Phase 3: Evangelism and Voidwraith
    elseif ramp.ramp_phase == 3 then
        -- Extend active Atonements with Evangelism
        local atonement_count = utility.count_atonements(heal_targets_list)
        if atonement_count >= 4 then
            if utility.cast_evangelism(local_player, 
                                      menu_elements.enable_evangelism:get_state(),
                                      heal_targets_list,
                                      true) then
                return true
            end
        end
        
        -- Cast Voidwraith
        if damage_target and utility.cast_voidwraith(local_player, damage_target, menu_elements.enable_voidwraith:get_state()) then
            ramp.ramp_phase = 4
            return true
        end
        
        -- Move to phase 4 if too much time has passed
        if elapsed_time > 8.0 then
            ramp.ramp_phase = 4
            return false
        end
    end
    
    -- Phase 4: Damage phase
    elseif ramp.ramp_phase == 4 then
        if not damage_target then
            return false
        end
        
        -- Follow damage priority:
        -- 1. Mind Blast
        if utility.cast_mind_blast(local_player, damage_target, menu_elements.enable_mind_blast:get_state()) then
            return true
        end
        
        -- 2. Penance
        if utility.cast_penance(
            local_player, damage_target, true, 
            menu_elements.enable_penance_damage:get_state(),
            menu_elements.enable_penance_heal:get_state()) then
            return true
        end
        
        -- 3. Shadow Word: Death in execute
        local health_percentage = unit_helper:get_health_percentage(damage_target)
        if health_percentage < 20 and utility.cast_shadow_word_death(
            local_player, damage_target, menu_elements.enable_shadow_word_death:get_state()) then
            return true
        end
        
        -- 4. Void Blast until Penance is back
        if utility.cast_void_blast(local_player, damage_target, menu_elements.enable_void_blast:get_state()) then
            return true
        end
        
        -- If we reach the damage time or exceed max duration, end the ramp
        if current_time >= ramp.next_big_damage_time or elapsed_time > 16.0 then
            ramp.stop_ramping()
            return false
        end
    end
    
    return false
end

-- Execute ramping logic based on current phase
---@param local_player game_object
---@param heal_targets_list table
---@param menu_elements table
---@return boolean
-- Execute Voidweaver mini-ramp for minor damage events
---@param local_player game_object
---@param heal_targets_list table
---@param damage_targets_list table
---@param menu_elements table
---@return boolean
function ramp.execute_voidweaver_mini_ramp(local_player, heal_targets_list, damage_targets_list, menu_elements)
    if not ramp.is_ramping or not ramp.is_voidweaver_mini_ramp then
        return false
    end
    
    local current_time = core.time()
    local elapsed_time = current_time - ramp.ramp_start_time
    
    -- Get the main damage target
    local damage_target = nil
    if #damage_targets_list > 0 and damage_targets_list[1]:is_valid() then
        damage_target = damage_targets_list[1]
    end
    
    -- Phases for Voidweaver mini-ramp:
    -- 1: Apply shields to key targets (tank + priority DPS)
    -- 2: Minor burst phase (quick damage)
    
    -- Phase 1: Apply shields to key targets
    if ramp.ramp_phase == 1 then
        -- Refresh Shadow Word: Pain
        if damage_target then
            local dot_refresh_threshold = menu_elements.dot_refresh_threshold:get() * 1000
            local dot_data = buff_manager:get_debuff_data(damage_target, constants.buff_ids.SHADOW_WORD_PAIN)
            if not dot_data.is_active or dot_data.remaining < dot_refresh_threshold then
                if utility.cast_shadow_word_pain(local_player, damage_target, menu_elements.enable_shadow_word_pain:get_state(), dot_refresh_threshold) then
                    return true
                end
            end
        end
        
        -- Shield count target (based on menu setting)
        local shield_target = menu_elements.voidweaver_mini_shield_count:get()
        
        -- First priority: Tank
        for _, target in ipairs(heal_targets_list) do
            if unit_helper:is_tank(target) and not utility.has_atonement(target) then
                if utility.cast_power_word_shield(local_player, target, menu_elements.enable_shield:get_state()) then
                    ramp.shield_count = ramp.shield_count + 1
                    return true
                end
            end
        end
        
        -- Then priority DPS or low health targets
        for _, target in ipairs(heal_targets_list) do
            if not utility.has_atonement(target) and 
               (unit_helper:get_role_id(target) == enums.group_role.DAMAGER or 
                unit_helper:get_health_percentage(target) < 90) then
                if utility.cast_power_word_shield(local_player, target, menu_elements.enable_shield:get_state()) then
                    ramp.shield_count = ramp.shield_count + 1
                    return true
                end
            end
        end
        
        -- Move to phase 2 if we've applied enough shields or spent enough time
        if ramp.shield_count >= shield_target or elapsed_time > 3.0 then
            ramp.ramp_phase = 2
            return false
        end
    end
    
    -- Phase 2: Burst damage
    elseif ramp.ramp_phase == 2 then
        if not damage_target then
            return false
        end
        
        -- Short damage burst rotation
        
        -- 1. Voidwraith if available for quick burst
        if utility.cast_voidwraith(local_player, damage_target, menu_elements.enable_voidwraith:get_state()) then
            return true
        end
        
        -- 2. Mind Blast
        if utility.cast_mind_blast(local_player, damage_target, menu_elements.enable_mind_blast:get_state()) then
            return true
        end
        
        -- 3. Penance for quick damage
        if utility.cast_penance(
            local_player, damage_target, true, 
            menu_elements.enable_penance_damage:get_state(),
            menu_elements.enable_penance_heal:get_state()) then
            return true
        end
        
        -- 4. Void Blast
        if utility.cast_void_blast(local_player, damage_target, menu_elements.enable_void_blast:get_state()) then
            return true
        end
        
        -- End the mini-ramp after damage time or duration
        if current_time >= ramp.next_big_damage_time or elapsed_time > 6.0 then
            ramp.stop_ramping()
            return false
        end
    end
    
    return false
end

function ramp.execute_ramp(local_player, heal_targets_list, menu_elements)
    if not ramp.is_ramping then
        return false
    end
    
    -- Get targets for damage
    local targets_list = target_selector:get_targets(5)
    
    -- Route to the appropriate ramp execution function
    if ramp.is_voidweaver_ramp then
        return ramp.execute_voidweaver_ramp(local_player, heal_targets_list, targets_list, menu_elements)
    elseif ramp.is_voidweaver_mini_ramp then
        return ramp.execute_voidweaver_mini_ramp(local_player, heal_targets_list, targets_list, menu_elements)
    end
    
    local current_time = core.time()
    local elapsed_time = current_time - ramp.ramp_start_time
    
    -- Adjust parameters based on whether this is a mini-ramp or full ramp
    local shield_target, phase1_duration, phase2_duration, phase3_duration
    
    if ramp.is_mini_ramp then
        -- Mini-ramp uses simplified parameters
        shield_target = menu_elements.mini_ramp_shield_count:get()
        phase1_duration = menu_elements.mini_ramp_duration:get() * 0.3 -- 30% of time for shields
        phase2_duration = menu_elements.mini_ramp_duration:get() * 0.4 -- 40% of time for radiance
        phase3_duration = menu_elements.mini_ramp_duration:get() * 0.3 -- 30% of time for evangelism
    else
        -- Full ramp uses detailed parameters
        shield_target = menu_elements.ramp_shield_count:get()
        phase1_duration = menu_elements.ramp_phase1_duration:get()
        phase2_duration = menu_elements.ramp_phase2_duration:get()
        phase3_duration = menu_elements.ramp_phase3_duration:get()
    end
    
    -- Phase 1: Apply shields to as many targets as possible
    if ramp.ramp_phase == 1 then

        -- Shield as many targets as possible
        for _, target in ipairs(heal_targets_list) do
            if utility.cast_power_word_shield(local_player, target, menu_elements.enable_shield:get_state()) then
                ramp.ramping_target_count = ramp.ramping_target_count + 1
                return true
            end
        end
        
        -- If we've shielded enough targets or spent enough time, move to phase 2
        if ramp.ramping_target_count >= shield_target or elapsed_time > phase1_duration then
            ramp.ramp_phase = 2
            ramp.ramping_target_count = 0
            return false
        end
    
    -- Phase 2: Apply Radiance for group atonement spread (only for full ramp or if available for mini-ramp)
    elseif ramp.ramp_phase == 2 then
        -- For mini-ramp with minimal targets, we might skip radiance phase
        if ramp.is_mini_ramp and shield_target <= 3 then
            ramp.ramp_phase = 3
            return false
        end
        
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
        
        -- For mini-ramp, only use one radiance
        local radiance_target = ramp.is_mini_ramp and 1 or 2
        
        if best_target and utility.cast_power_word_radiance(
            local_player, 
            best_target, 
            menu_elements.enable_power_word_radiance:get_state(),
            heal_targets_list,
            true) then
            ramp.ramping_target_count = ramp.ramping_target_count + 1
            
            -- If we've used enough Radiance or spent enough time, move to phase 3
            local phase2_elapsed = elapsed_time - phase1_duration
            
            if ramp.ramping_target_count >= radiance_target or phase2_elapsed > phase2_duration then
                ramp.ramp_phase = 3
                return true
            end
            return true
        end
        
        -- If we couldn't cast Radiance but spent enough time, move to phase 3
        local phase2_elapsed = elapsed_time - phase1_duration
        
        if phase2_elapsed > phase2_duration then
            ramp.ramp_phase = 3
            return false
        end
    
    -- Phase 3: Cast Evangelism to extend Atonement
    elseif ramp.ramp_phase == 3 then
        -- Count atonements before using
        local atonement_count = utility.count_atonements(heal_targets_list)
        local min_evangelism_count = menu_elements.min_evangelism_count:get()
        
        -- Mini-ramp uses lower threshold for Evangelism
        if ramp.is_mini_ramp then
            min_evangelism_count = math.max(2, min_evangelism_count - 2)
        end
        
        -- Only cast Evangelism if we have enough Atonements
        if atonement_count >= min_evangelism_count or (elapsed_time > (phase1_duration + phase2_duration)) then
            if utility.cast_evangelism(local_player, 
                                      menu_elements.enable_evangelism:get_state(),
                                      heal_targets_list,
                                      true) then
                -- Apply Spirit Shell if enabled (only for full ramp)
                if not ramp.is_mini_ramp and menu_elements.enable_spirit_shell:get_state() then
                    utility.cast_spirit_shell(local_player, menu_elements.enable_spirit_shell:get_state())
                end
                
                -- Use Power Infusion if enabled (only for full ramp)
                if not ramp.is_mini_ramp and menu_elements.enable_power_infusion:get_state() and 
                   menu_elements.power_infusion_self:get_state() then
                    utility.cast_power_infusion(local_player, local_player, menu_elements.enable_power_infusion:get_state())
                end
                
                -- Move to damage phase
                ramp.ramp_phase = 4
                return true
            end
        end
        
        -- If we spent too much time without casting Evangelism, move on anyway
        local phase3_elapsed = elapsed_time - (phase1_duration + phase2_duration)
        
        if phase3_elapsed > phase3_duration then
            ramp.ramp_phase = 4
            return false
        end
    
    -- Phase 4: Damage phase - deal damage for atonement healing
    elseif ramp.ramp_phase == 4 then
        -- Mini-ramp has a shorter damage phase
        local max_damage_time = ramp.is_mini_ramp and 6.0 or 15.0
        
        -- Continue damage rotation until damage event or time runs out
        if current_time >= ramp.next_big_damage_time or elapsed_time > max_damage_time then
            ramp.stop_ramping()
            return false
        end
        
        -- No direct return here - will fall through to normal rotation
        -- with is_ramping still true to prioritize damage
    end
    
    return false
end

-- Check if we're in the damage phase of ramping
function ramp.is_in_damage_phase()
    return ramp.is_ramping and ramp.ramp_phase == 4
end

return ramp