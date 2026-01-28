Config = Config or {}

-- =========================================================
-- Framework
-- "auto" | "qb" | "qbx" | "esx"
-- =========================================================
Config.Framework = "qb"

-- =========================================================
Config.Price = 500

Config.AllowCash = true
Config.AllowBank = true
Config.PreferCashFirst = true

Config.CooldownMs = 5000

-- =========================================================
Config.Doctors = {
  {
    Id = "doctor_1",
    Model = "s_m_m_doctor_01",
    Coords = vector4(311.25, -592.78, 43.28, 340.0),
    Scenario = "WORLD_HUMAN_CLIPBOARD",
    Freeze = true,
    Invincible = true,
    BlockEvents = true,

    -- Optional per-NPC (not used by current script unless you extend it):
    -- Price = 500,
    -- Label = "Doctor ($500) - Press [E]",
  },
  {
    Id = "doctor_2",
    Model = "s_m_m_doctor_01",
    Coords = vector4(473.5833, -1633.8907, 29.2668, 70.3621),
    Scenario = "WORLD_HUMAN_CLIPBOARD",
    Freeze = true,
    Invincible = true,
    BlockEvents = true,
  },
  -- Add more doctors here...
}

-- =========================================================
-- Interaction
-- Mode:
--  - "auto"       -> tries ox_target / qb-target, fallback to jg-textui
--  - "jg-textui"  -> forced
--  - "qb-target"  -> forced
--  - "ox-target"  -> forced
-- =========================================================
Config.Interaction = {
  Mode = "auto",
  Distance = 2.2,

  JGTextUI = {
    Enabled = true,
    Position = "left", -- "left" | "right" | "top" | "bottom" (depends on jg-textui)
    Label = "Doctor ($500) - Press [E] to revive",
  },

  Target = {
    Label = "Doctor ($500) - Revive",
    Icon  = "fas fa-user-doctor",
  }
}

-- =========================================================
Config.Messages = {
  NotEnough = "You don't have enough money (cash/bank) to pay $500.",
  Paid      = "You paid $500. The doctor is reviving you...",
  Cooldown  = "Please wait a moment before using the doctor again.",
  Busy      = "You can't use this service right now.",
}

-- =========================================================
Config.Blip = {
  Enabled = true,
  Sprite  = 61,
  Scale   = 0.8,
  Color   = 2,
  Name    = "Doctor"
}

-- =========================================================
-- Options:
--  "qb"        -> TriggerEvent('hospital:client:Revive')
--  "qbplayer"  -> TriggerEvent('hospital:client:RevivePlayer')
--  "pambulance"-> TriggerEvent('p_ambulancejob/client/death/revive')
--  "esx"       -> TriggerEvent('esx_ambulancejob:revive')
--  "custom"    -> TriggerEvent(Config.CustomReviveEvent)
--
Config.ReviveEvent = "qb" 

Config.CustomReviveEvent = "hospital:client:Revive" 
