-- Constants Module
-- Contains all spell data, buff IDs, and other constants for the Discipline Priest rotation

local enums = require("common/enums")

local constants = {}

-- Define buff IDs for checking
constants.buff_ids = {
    ATONEMENT = enums.buff_db.ATONEMENT,
    WEAKENED_SOUL = 6788, -- Not in buff_db, use direct ID
    SHADOW_WORD_PAIN = enums.buff_db.SHADOW_WORD_PAIN, -- Replaced Purge the Wicked
    POWER_OF_THE_DARK_SIDE = enums.buff_db.POWER_OF_THE_DARK_SIDE,
    POWER_WORD_SHIELD = enums.buff_db.POWER_WORD_SHIELD,
    POWER_INFUSION = 10060, -- Direct ID
    SPIRIT_SHELL = 109964, -- Direct ID
    
    -- Voidweaver specific buffs
    VOIDWRAITH = 425251, -- Placeholder ID
    SHADOW_COVENANT = 314867, -- Placeholder ID
    ENTROPIC_RIFT = 425261, -- Placeholder ID
    RENEW = 139 -- Real ID for Renew
}

-- Define spell data for all relevant spells
constants.spell_data = {
    -- Damage spells
    shadow_word_pain = {
        id = 589,
        name = "Shadow Word: Pain",
        range = 40
    },
    mindbender = {
        id = 123040,
        name = "Mindbender",
        range = 40
    },
    halo = {
        id = 120517,
        name = "Halo",
        range = 30
    },
    -- Voidweaver specific spells
    voidwraith = {
        id = 425250, -- Using a placeholder ID
        name = "Voidwraith",
        range = 40
    },
    ultimate_penitence = {
        id = 425252, -- Using a placeholder ID
        name = "Ultimate Penitence",
        range = 40
    },
    shadow_covenant = {
        id = 314867, -- Using a placeholder ID
        name = "Shadow Covenant",
        range = 40
    },
    void_blast = {
        id = 425255, -- Using a placeholder ID
        name = "Void Blast",
        range = 40
    },
    entropic_rift = {
        id = 425260, -- Using a placeholder ID
        name = "Entropic Rift",
        range = 40
    },
    collapsing_void = {
        id = 425265, -- Using a placeholder ID
        name = "Collapsing Void",
        range = 40
    },
    renew = {
        id = 139, -- Using a real ID for Renew spell
        name = "Renew",
        range = 40
    },
    penance = {
        id = 47540,
        name = "Penance",
        range = 40
    },
    mind_blast = {
        id = 8092,
        name = "Mind Blast",
        range = 40
    },
    smite = {
        id = 585,
        name = "Smite",
        range = 40
    },
    shadow_word_death = {
        id = 32379,
        name = "Shadow Word: Death",
        range = 40
    },
    mind_games = {
        id = 375901,
        name = "Mind Games",
        range = 40
    },
    
    -- Healing spells
    power_word_shield = {
        id = 17,
        name = "Power Word: Shield",
        range = 40
    },
    shadow_mend = {
        id = 186263,
        name = "Shadow Mend",
        range = 40
    },
    pain_suppression = {
        id = 33206,
        name = "Pain Suppression",
        range = 40
    },
    power_word_radiance = {
        id = 194509,
        name = "Power Word: Radiance",
        range = 40
    },
    
    -- Cooldowns
    power_infusion = {
        id = 10060,
        name = "Power Infusion",
        range = 40
    },
    },
    evangelism = {
        id = 246287,
        name = "Evangelism",
        range = 0
    },
    spirit_shell = {
        id = 109964,
        name = "Spirit Shell",
        range = 0
    }
}

return constants