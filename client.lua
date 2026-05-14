-- client.lua
local FW      = nil
local ESX     = nil
local isQB    = false
local isESX   = false

local lastUse    = 0
local doctorPeds = {}
local doctorBlips = {}
local showingJG  = false
local busy       = false

local CFG_Inter    = {}
local CFG_Messages = {}
local CFG_Blip     = {}
local CFG_Doctors  = {}

local function getResState(name)
  return GetResourceState(name) or "missing"
end

local function detectFramework()
  local qbState  = getResState('qb-core')
  local qbxState = getResState('qbx_core')
  local esxState = getResState('es_extended')
  local cfg      = tostring((Config and Config.Framework) or "auto"):lower()

  local function tryQB(res, export)
    if getResState(res) == "started" then
      FW = exports[export]:GetCoreObject()
      isQB, isESX = true, false
      return true
    end
  end

  local function tryESX()
    if esxState == "started" then
      ESX = exports["es_extended"]:getSharedObject()
      isQB, isESX = false, true
      return true
    end
  end

  if cfg == "qb"  then return tryQB('qb-core',  'qb-core')  end
  if cfg == "qbx" then return tryQB('qbx_core', 'qbx_core') end
  if cfg == "esx" then return tryESX() end

  return tryQB('qb-core',  'qb-core')
      or tryQB('qbx_core', 'qbx_core')
      or tryESX()
end

CreateThread(function()
  local tries = 0
  while not detectFramework() and tries < 200 do
    tries = tries + 1
    Wait(250)
  end
end)

local function Notify(msg, msgType)
  msg = tostring(msg or "")
  if msg == "" then return end

  if isQB and FW and FW.Functions and FW.Functions.Notify then
    FW.Functions.Notify(msg, msgType or 'primary')
  elseif isESX and ESX and ESX.ShowNotification then
    ESX.ShowNotification(msg)
  else
    TriggerEvent('chat:addMessage', { args = { 'Doctor', msg } })
  end
end

RegisterNetEvent('izaap_npc:client:notify', function(msg, msgType)
  Notify(msg, msgType)
end)

local DOWN_STATES = { isDead=true, inLastStand=true, dead=true, laststand=true, isLaststand=true }

local function IsPlayerDown()
  local ped = PlayerPedId()
  if LocalPlayer and LocalPlayer.state then
    local st = LocalPlayer.state
    for key in pairs(DOWN_STATES) do
      if st[key] == true then return true end
    end
  end
  return IsEntityDead(ped) or IsPedDeadOrDying(ped, true)
end

local function ApplyTreatment()
  local ped = PlayerPedId()
  if IsPlayerDown() then
    TriggerEvent('izaap_npc:client:doRevive')
    return
  end
  local maxH = GetEntityMaxHealth(ped)
  SetEntityHealth(ped, (maxH and maxH > 0) and maxH or 200)
  pcall(TriggerEvent, 'hospital:client:ResetLimbs')
  pcall(TriggerEvent, 'hospital:client:RemoveBleed')
  pcall(TriggerEvent, 'hospital:client:ResetBloodDamage')
end

local jgStarted = nil 

local function isJGStarted()
  if jgStarted == nil then
    jgStarted = getResState('jg-textui') == "started"
  end
  return jgStarted
end

local function JG_Show(text)
  if not isJGStarted() then return false end
  pcall(exports['jg-textui'].DrawText, exports['jg-textui'], text, CFG_Inter.JGTextUI and CFG_Inter.JGTextUI.Position or "left")
  showingJG = true
  return true
end

local function JG_Hide()
  if not showingJG then return end
  if isJGStarted() then
    pcall(exports['jg-textui'].HideText, exports['jg-textui'])
  end
  showingJG = false
end

local function loadAnimDict(dict)
  if HasAnimDictLoaded(dict) then return true end
  RequestAnimDict(dict)
  for _ = 1, 200 do
    if HasAnimDictLoaded(dict) then return true end
    Wait(10)
  end
  return false
end

local function loadModel(model)
  local m = joaat(model)
  if HasModelLoaded(m) then return m end
  RequestModel(m)
  for _ = 1, 250 do
    if HasModelLoaded(m) then return m end
    Wait(10)
  end
  return nil
end

local ANIM_DICT = "amb@medic@standing@tendtodead@base"
local ANIM_CLIP = "base"

local pbStarted = nil
local function isPBStarted()
  if pbStarted == nil then pbStarted = getResState('progressbar') == "started" end
  return pbStarted
end

local function runProgress(label, durationMs, onDone, onCancel)
  local ped     = PlayerPedId()
  local downNow = IsPlayerDown()
  durationMs    = durationMs or 5000
  label         = label or "Receiving medical attention..."

  if isPBStarted() then
    local ok, isBusy = pcall(function() return exports['progressbar']:isDoingSomething() end)
    if ok and isBusy then return end
  end

  busy = true
  JG_Hide()

  local function cleanup()
    busy = false
    if not downNow then ClearPedTasks(ped) end
  end

  local function done()   cleanup(); if onDone   then onDone()   end end
  local function cancel() cleanup(); if onCancel then onCancel() end end

  local controls = { disableMovement=true, disableCarMovement=true, disableMouse=false, disableCombat=true }
  local animData = {}
  if not downNow then
    animData = { animDict=ANIM_DICT, anim=ANIM_CLIP, flags=1 }
    if loadAnimDict(ANIM_DICT) then
      TaskPlayAnim(ped, ANIM_DICT, ANIM_CLIP, 1.0, 1.0, -1, 1, 0.0, false, false, false)
    end
  end


  if isQB and FW and FW.Functions and FW.Functions.Progressbar then
    FW.Functions.Progressbar(
      "izaap_npc_doctor", label, durationMs,
      true, true, controls, animData, {}, {},
      function() done() end,
      function() cancel() end
    )
    return
  end

  if isPBStarted() then
    local ok = pcall(function()
      exports['progressbar']:Progress({
        name            = "izaap_npc_doctor",
        duration        = durationMs,
        label           = label,
        useWhileDead    = true,
        canCancel       = true,
        controlDisables = controls,
        animation       = downNow and {} or animData,
        prop = {}, propTwo = {}
      }, function(cancelled)
        if cancelled then cancel() else done() end
      end)
    end)
    if ok then return end
  end

  CreateThread(function()
    local endT = GetGameTimer() + durationMs
    while GetGameTimer() < endT do
      for _, ctrl in ipairs({ 24,25,21,22,23,75,30,31 }) do
        DisableControlAction(0, ctrl, true)
      end
      if IsControlJustPressed(0, 177) then cancel(); return end
      Wait(0)
    end
    done()
  end)
end


local function spawnOneDoctor(def)
  if not def then return nil end
  local model = loadModel(def.Model or "s_m_m_doctor_01")
  if not model then
    print('Doctor model could not be loaded: ' .. tostring(def.Model))
    return nil
  end
  local c = def.Coords
  if not c then
    print('Doctor entry has no Coords in config.')
    return nil
  end

  local ped = CreatePed(4, model, c.x, c.y, c.z - 1.0, c.w or 0.0, false, true)

  SetEntityAsMissionEntity(ped, true, true)
  SetPedFleeAttributes(ped, 0, 0)
  SetPedDiesWhenInjured(ped, false)
  SetPedCanRagdollFromPlayerImpact(ped, false)
  SetPedCanRagdoll(ped, false)
  SetPedCombatAttributes(ped, 46, true)
  SetPedSeeingRange(ped, 0.0)
  SetPedHearingRange(ped, 0.0)
  SetPedAlertness(ped, 0)
  SetBlockingOfNonTemporaryEvents(ped, def.BlockEvents == true)
  if def.Invincible then SetEntityInvincible(ped, true) end
  if def.Freeze     then FreezeEntityPosition(ped, true) end
  if def.Scenario and def.Scenario ~= "" then
    TaskStartScenarioInPlace(ped, def.Scenario, 0, true)
  end
  return ped
end


local function ClearDoctorBlips()
  for _, b in ipairs(doctorBlips) do
    if DoesBlipExist(b) then RemoveBlip(b) end
  end
  doctorBlips = {}
end

local function AddDoctorBlipAtCoords(coords)
  if CFG_Blip.Enabled ~= true or not coords then return end
  local b = AddBlipForCoord(coords.x, coords.y, coords.z)
  SetBlipSprite(b, CFG_Blip.Sprite  or 61)
  SetBlipDisplay(b, 4)
  SetBlipScale(b,   CFG_Blip.Scale  or 0.8)
  SetBlipColour(b,  CFG_Blip.Color  or 2)
  SetBlipAsShortRange(b, true)
  BeginTextCommandSetBlipName("STRING")
  AddTextComponentString(tostring(CFG_Blip.Name or "Doctor"))
  EndTextCommandSetBlipName(b)
  doctorBlips[#doctorBlips + 1] = b
end


local function getDoctorList()
  if type(CFG_Doctors) == "table" and #CFG_Doctors > 0 then
    return CFG_Doctors
  end
  if Config and Config.Doctor and Config.Doctor.Coords then
    return { Config.Doctor }
  end
  return nil
end

local function spawnDoctors()
  doctorPeds = {}
  local list = getDoctorList()
  if not list then print("Config.Doctors is empty."); return end
  for _, def in ipairs(list) do
    local ped = spawnOneDoctor(def)
    if ped and DoesEntityExist(ped) then
      doctorPeds[#doctorPeds + 1] = ped
    end
  end
end

local function BuildDoctorBlipsFromConfig()
  ClearDoctorBlips()
  if CFG_Blip.Enabled ~= true then return end
  local list = getDoctorList()
  if not list then return end
  for _, d in ipairs(list) do
    if d.Coords then AddDoctorBlipAtCoords(d.Coords) end
  end
end


local function getNearestDoctor(maxDist)
  maxDist = maxDist or CFG_Inter.Distance or 2.2
  local pcoords = GetEntityCoords(PlayerPedId())
  local bestPed, bestD = nil, maxDist + 0.01

  for _, dp in ipairs(doctorPeds) do
    if dp and DoesEntityExist(dp) then
      local d = #(pcoords - GetEntityCoords(dp))
      if d < bestD then bestD = d; bestPed = dp end
    end
  end
  return bestPed
end


local function canUseNow()
  if busy then return false, "busy" end
  local now = GetGameTimer()
  if (now - lastUse) < (Config and Config.CooldownMs or 5000) then return false, "cooldown" end
  lastUse = now
  return true
end

local function doPayAndTreat()
  local ok, why = canUseNow()
  if not ok then
    Notify(why == "busy" and (CFG_Messages.Busy or "You cannot use this service right now.")
                          or (CFG_Messages.Cooldown or "Wait a moment before using the doctor again."), "error")
    return
  end

  runProgress(
    "Doctor: applying treatment...", 5000,
    function() TriggerServerEvent('izaap_npc:server:payAndRevive') end,
    function() Notify("Cancelled.", "error") end
  )
end


RegisterNetEvent('izaap_npc:client:doRevive', function()
  local choice = tostring((Config and Config.ReviveEvent) or "qb"):lower()

  if choice == "qb" then
    pcall(TriggerEvent, 'hospital:client:Revive')
  elseif choice == "qbplayer" then
    pcall(TriggerEvent, 'hospital:client:RevivePlayer')
  elseif choice == "custom" then
    local ev = tostring((Config and Config.CustomReviveEvent) or "")
    if ev ~= "" then
      pcall(TriggerEvent, ev)
    else
      Notify("Config.CustomReviveEvent is empty.", "error")
    end
  else
    Notify("Invalid Config.ReviveEvent. (qb/qbplayer/custom)", "error")
  end

  ApplyTreatment()
end)


local function addTargetsForAll()
  local targetCfg = CFG_Inter.Target or {}
  local label = targetCfg.Label or "Doctor - Treatment"
  local icon  = targetCfg.Icon  or "fas fa-user-doctor"
  local dist  = CFG_Inter.Distance or 2.2
  local added = false

  local hasOX = getResState('ox_target')  == "started"
  local hasQB = getResState('qb-target') == "started"

  for i, ped in ipairs(doctorPeds) do
    if ped and DoesEntityExist(ped) then
      if hasOX then
        exports.ox_target:addLocalEntity(ped, {{
          name     = 'izaap_npc_doctor_' .. i,
          label    = label,
          icon     = icon,
          distance = dist,
          onSelect = doPayAndTreat,
        }})
        added = true
      elseif hasQB then
        exports['qb-target']:AddTargetEntity(ped, {
          options  = {{ icon=icon, label=label, action=doPayAndTreat }},
          distance = dist,
        })
        added = true
      end
    end
  end
  return added
end

local function runJGTextUI()
  local jgCfg = CFG_Inter.JGTextUI or {}
  local label = jgCfg.Label or "Doctor ($500) - Press [E]"
  local dist  = CFG_Inter.Distance or 2.2

  CreateThread(function()
    while true do
      Wait(250)
      if busy then JG_Hide() goto continue end

      if getNearestDoctor(dist) then
        JG_Show(label)
        if IsControlJustPressed(0, 38) then
          doPayAndTreat()
          Wait(500)
        end
      else
        JG_Hide()
      end

      ::continue::
    end
  end)
end

local function setupInteraction()
  local mode = tostring(CFG_Inter.Mode or "auto"):lower()

  if mode == "auto" then
    local ok = addTargetsForAll()
    if not ok and CFG_Inter.JGTextUI and CFG_Inter.JGTextUI.Enabled then
      runJGTextUI(); ok = true
    end
    if not ok then Notify("No interaction method available (target/jg-textui).", "error") end
    return
  end

  if mode == "jg-textui" or mode == "jg_textui" then
    if not isJGStarted() then
      Notify("jg-textui is not started. Change Config.Interaction.Mode or start the resource.", "error")
      return
    end
    runJGTextUI()
    return
  end

  -- ox-target / qb-target
  if not addTargetsForAll() then
    Notify("Target is not started. Change Config.Interaction.Mode.", "error")
  end
end


CreateThread(function()
  Wait(500)
  CFG_Inter    = (Config and Config.Interaction) or {}
  CFG_Messages = (Config and Config.Messages)    or {}
  CFG_Blip     = (Config and Config.Blip)        or {}
  CFG_Doctors  = (Config and Config.Doctors)     or {}

  spawnDoctors()
  BuildDoctorBlipsFromConfig()
  Wait(500)
  setupInteraction()
end)


AddEventHandler('onResourceStop', function(res)
  if res ~= GetCurrentResourceName() then return end
  JG_Hide()
  ClearDoctorBlips()
  for _, ped in ipairs(doctorPeds) do
    if ped and DoesEntityExist(ped) then DeleteEntity(ped) end
  end
end)
