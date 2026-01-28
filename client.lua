-- client.lua (QB-Ambulancejob ready) ✅
-- ✅ Cura SIEMPRE (vivo / herido / laststand / muerto)
-- ✅ Blips por cada doctor (Config.Blip)
-- ✅ Progressbar estable (export cuando down)
-- ✅ No spam: blocks si ya hay progressbar activo
-- ✅ Mantiene: jg-textui / ox_target / qb-target

local FW = nil
local ESX = nil
local isQB = false
local isESX = false

local lastUse = 0
local doctorPeds = {}
local doctorBlips = {} 
local showingJG = false
local busy = false

local function getResState(name)
  local ok, st = pcall(GetResourceState, name)
  if not ok then return "missing" end
  return st or "missing"
end

local function detectFramework()
  local qbState  = getResState('qb-core')
  local qbxState = getResState('qbx_core')
  local esxState = getResState('es_extended')

  local cfg = tostring((Config and Config.Framework) or "auto"):lower()

  if cfg == "qb" and qbState == "started" then
    FW = exports['qb-core']:GetCoreObject()
    isQB, isESX = true, false
    return true
  end

  if cfg == "qbx" and qbxState == "started" then
    FW = exports['qbx_core']:GetCoreObject()
    isQB, isESX = true, false
    return true
  end

  if cfg == "esx" and esxState == "started" then
    ESX = exports["es_extended"]:getSharedObject()
    isQB, isESX = false, true
    return true
  end

  if qbState == "started" then
    FW = exports['qb-core']:GetCoreObject()
    isQB, isESX = true, false
    return true
  end

  if qbxState == "started" then
    FW = exports['qbx_core']:GetCoreObject()
    isQB, isESX = true, false
    return true
  end

  if esxState == "started" then
    ESX = exports["es_extended"]:getSharedObject()
    isQB, isESX = false, true
    return true
  end

  return false
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
    return
  end

  if isESX and ESX and ESX.ShowNotification then
    ESX.ShowNotification(msg)
    return
  end

  TriggerEvent('chat:addMessage', { args = { 'Doctor', msg } })
end

RegisterNetEvent('izaap_npc:client:notify', function(msg, msgType)
  Notify(msg, msgType)
end)

local function IsPlayerDown()
  local ped = PlayerPedId()

  if LocalPlayer and LocalPlayer.state then
    local st = LocalPlayer.state
    if st.isDead == true then return true end
    if st.inLastStand == true then return true end
    if st.dead == true then return true end
    if st.laststand == true then return true end
    if st.isLaststand == true then return true end
  end

  if IsEntityDead(ped) or IsPedDeadOrDying(ped, true) then
    return true
  end

  return false
end

local function ApplyTreatment()
  local ped = PlayerPedId()
  local maxH = GetEntityMaxHealth(ped)
  if not maxH or maxH <= 0 then maxH = 200 end

  if IsPlayerDown() then
    TriggerEvent('izaap_npc:client:doRevive')
    return
  end

  SetEntityHealth(ped, maxH)

  pcall(function() TriggerEvent('hospital:client:ResetLimbs') end)
  pcall(function() TriggerEvent('hospital:client:RemoveBleed') end)
  pcall(function() TriggerEvent('hospital:client:ResetBloodDamage') end)
end

local function JG_Show(text)
  if getResState('jg-textui') ~= "started" then return false end
  local inter = Config and Config.Interaction or {}
  local pos = (inter.JGTextUI and inter.JGTextUI.Position) or "left"

  pcall(function()
    exports['jg-textui']:DrawText(text, pos)
  end)

  showingJG = true
  return true
end

local function JG_Hide()
  if not showingJG then return end
  if getResState('jg-textui') ~= "started" then
    showingJG = false
    return
  end

  pcall(function()
    exports['jg-textui']:HideText()
  end)

  showingJG = false
end

local function loadAnimDict(dict)
  if HasAnimDictLoaded(dict) then return true end
  RequestAnimDict(dict)
  local t = 0
  while not HasAnimDictLoaded(dict) and t < 200 do
    Wait(10)
    t = t + 1
  end
  return HasAnimDictLoaded(dict)
end

local function runProgress(label, durationMs, onDone, onCancel)
  local ped = PlayerPedId()
  local animDict = "amb@medic@standing@tendtodead@base"
  local animClip = "base"

  local downNow = IsPlayerDown()

  if getResState('progressbar') == "started" then
    local okBusy, isBusyNow = pcall(function()
      return exports['progressbar']:isDoingSomething()
    end)
    if okBusy and isBusyNow then
      return
    end
  end

  busy = true
  JG_Hide()

  local function cleanup()
    busy = false
    if not downNow then
      ClearPedTasks(ped)
    end
  end

  local function done()
    cleanup()
    if onDone then onDone() end
  end

  local function cancel()
    cleanup()
    if onCancel then onCancel() end
  end

  if downNow and getResState('progressbar') == "started" then
    local ok = pcall(function()
      exports['progressbar']:Progress({
        name = "izaap_npc_doctor",
        duration = durationMs or 5000,
        label = label or "Receiving medical attention...",
        useWhileDead = true,
        canCancel = true,
        controlDisables = {
          disableMovement = true,
          disableCarMovement = true,
          disableMouse = false,
          disableCombat = true,
        },
        animation = {}, -- sin anim down
        prop = {},
        propTwo = {}
      }, function(cancelled)
        if cancelled then cancel() else done() end
      end)
    end)
    if ok then return end
  end

  if isQB and FW and FW.Functions and FW.Functions.Progressbar then
    local animData = {}
    if not downNow then
      animData = { animDict = animDict, anim = animClip, flags = 1 }
      if loadAnimDict(animDict) then
        TaskPlayAnim(ped, animDict, animClip, 1.0, 1.0, -1, 1, 0.0, false, false, false)
      end
    end

    FW.Functions.Progressbar(
      "izaap_npc_doctor",
      label or "Receiving medical attention...",
      durationMs or 5000,
      true,
      true,
      { disableMovement = true, disableCarMovement = true, disableMouse = false, disableCombat = true },
      animData,
      {}, {},
      function() done() end,
      function() cancel() end
    )
    return
  end

  if getResState('progressbar') == "started" then
    if not downNow then
      if loadAnimDict(animDict) then
        TaskPlayAnim(ped, animDict, animClip, 1.0, 1.0, -1, 1, 0.0, false, false, false)
      end
    end

    local ok = pcall(function()
      exports['progressbar']:Progress({
        name = "izaap_npc_doctor",
        duration = durationMs or 5000,
        label = label or "Receiving medical attention...",
        useWhileDead = true,
        canCancel = true,
        controlDisables = {
          disableMovement = true,
          disableCarMovement = true,
          disableMouse = false,
          disableCombat = true,
        },
        animation = downNow and {} or { animDict = animDict, anim = animClip, flags = 1 },
        prop = {},
        propTwo = {}
      }, function(cancelled)
        if cancelled then cancel() else done() end
      end)
    end)
    if ok then return end
  end

  CreateThread(function()
    local endT = GetGameTimer() + (durationMs or 5000)
    while GetGameTimer() < endT do
      DisableControlAction(0, 24, true)
      DisableControlAction(0, 25, true)
      DisableControlAction(0, 21, true)
      DisableControlAction(0, 22, true)
      DisableControlAction(0, 23, true)
      DisableControlAction(0, 75, true)
      DisableControlAction(0, 30, true)
      DisableControlAction(0, 31, true)
      if IsControlJustPressed(0, 177) then
        cancel()
        return
      end
      Wait(0)
    end
    done()
  end)
end

local function loadModel(model)
  local m = joaat(model)
  if HasModelLoaded(m) then return m end
  RequestModel(m)
  local t = 0
  while not HasModelLoaded(m) and t < 250 do
    Wait(10)
    t = t + 1
  end
  if not HasModelLoaded(m) then return nil end
  return m
end

local function spawnOneDoctor(def)
  def = def or {}
  local model = loadModel(def.Model or "s_m_m_doctor_01")
  if not model then
    print('The doctors model could not be loaded: ' .. tostring(def.Model))
    return nil
  end

  local c = def.Coords
  if not c then
    print('Doctor without coordinates in configuration.')
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
  if def.Freeze then FreezeEntityPosition(ped, true) end

  if def.Scenario and def.Scenario ~= "" then
    TaskStartScenarioInPlace(ped, def.Scenario, 0, true)
  end

  return ped
end

local function ClearDoctorBlips()
  for i = 1, #doctorBlips do
    local b = doctorBlips[i]
    if b and DoesBlipExist(b) then
      RemoveBlip(b)
    end
  end
  doctorBlips = {}
end

local function AddDoctorBlipAtCoords(coords)
  local bl = (Config and Config.Blip) or {}
  if bl.Enabled ~= true then return nil end
  if not coords then return nil end

  local x, y, z
  if type(coords) == "vector4" then
    x, y, z = coords.x, coords.y, coords.z
  elseif type(coords) == "vector3" then
    x, y, z = coords.x, coords.y, coords.z
  elseif type(coords) == "table" then
    x, y, z = coords.x, coords.y, coords.z
  end
  if not x or not y or not z then return nil end

  local b = AddBlipForCoord(x, y, z)
  SetBlipSprite(b, tonumber(bl.Sprite) or 61)
  SetBlipDisplay(b, 4)
  SetBlipScale(b, tonumber(bl.Scale) or 0.8)
  SetBlipColour(b, tonumber(bl.Color) or 2)
  SetBlipAsShortRange(b, true)

  BeginTextCommandSetBlipName("STRING")
  AddTextComponentString(tostring(bl.Name or "Doctor"))
  EndTextCommandSetBlipName(b)

  doctorBlips[#doctorBlips + 1] = b
  return b
end

local function BuildDoctorBlipsFromConfig()
  ClearDoctorBlips()

  local bl = (Config and Config.Blip) or {}
  if bl.Enabled ~= true then return end

  local list = (Config and Config.Doctors) or nil
  if type(list) ~= "table" or #list == 0 then
    if Config and Config.Doctor and Config.Doctor.Coords then
      list = { Config.Doctor }
    else
      return
    end
  end

  for i = 1, #list do
    local d = list[i] or {}
    if d.Coords then
      AddDoctorBlipAtCoords(d.Coords)
    end
  end
end

local function spawnDoctors()
  doctorPeds = {}

  local list = (Config and Config.Doctors) or nil
  if type(list) ~= "table" or #list == 0 then
    if Config and Config.Doctor and Config.Doctor.Coords then
      list = { Config.Doctor }
    else
      print("Config.Doctors is empty.")
      return
    end
  end

  for i = 1, #list do
    local ped = spawnOneDoctor(list[i])
    if ped and DoesEntityExist(ped) then
      doctorPeds[#doctorPeds + 1] = ped
    end
  end
end

local function getNearestDoctor(maxDist)
  local inter = Config and Config.Interaction or {}
  maxDist = maxDist or (inter.Distance or 2.2)

  local ped = PlayerPedId()
  local pcoords = GetEntityCoords(ped)

  local bestPed, bestD = nil, 999999.0
  for i = 1, #doctorPeds do
    local dp = doctorPeds[i]
    if dp and DoesEntityExist(dp) then
      local d = #(pcoords - GetEntityCoords(dp))
      if d < bestD then
        bestD = d
        bestPed = dp
      end
    end
  end

  if bestPed and bestD <= maxDist then
    return bestPed, bestD
  end
  return nil, nil
end

local function canUseNow()
  local now = GetGameTimer()
  if busy then
    return false, "busy"
  end
  if (now - lastUse) < ((Config and Config.CooldownMs) or 5000) then
    return false, "cooldown"
  end
  lastUse = now
  return true, nil
end

local function doPayAndTreat()
  local ok, why = canUseNow()
  if not ok then
    local msgs = (Config and Config.Messages) or {}
    if why == "busy" then
      Notify(msgs.Busy or "You cannot use this service right now.", "error")
    else
      Notify(msgs.Cooldown or "Wait a moment before using the doctor again.", "error")
    end
    return
  end

  runProgress(
    "Doctor: applying treatment...",
    5000,
    function()
      TriggerServerEvent('izaap_npc:server:payAndRevive')
    end,
    function()
      Notify("Cancelled.", "error")
    end
  )
end

RegisterNetEvent('izaap_npc:client:doRevive', function()
  local choice = tostring((Config and Config.ReviveEvent) or "qb"):lower()

  if choice == "qb" then
    pcall(function()
      TriggerEvent('hospital:client:Revive')
    end)
  elseif choice == "qbplayer" then
    pcall(function()
      TriggerEvent('hospital:client:RevivePlayer')
    end)
  elseif choice == "custom" then
    local ev = tostring((Config and Config.CustomReviveEvent) or "")
    if ev ~= "" then
      pcall(function()
        TriggerEvent(ev)
      end)
    else
      Notify("Config.CustomReviveEvent is empty.", "error")
    end
  else
    Notify("Invalid Config.ReviveEvent. (qb/qbplayer/custom)", "error")
  end

  ApplyTreatment()
end)

local function addTargetsForAll()
  local inter = Config and Config.Interaction or {}
  local targetCfg = inter.Target or {}

  local label = targetCfg.Label or "Doctor - Treatment"
  local icon  = targetCfg.Icon  or "fas fa-user-doctor"
  local dist  = inter.Distance or 2.2

  local hasAny = false

  for i = 1, #doctorPeds do
    local ped = doctorPeds[i]
    if ped and DoesEntityExist(ped) then
      if getResState('ox_target') == "started" then
        exports.ox_target:addLocalEntity(ped, {
          {
            name = 'izaap_npc_doctor_' .. i,
            label = label,
            icon = icon,
            distance = dist,
            onSelect = function()
              doPayAndTreat()
            end
          }
        })
        hasAny = true
      elseif getResState('qb-target') == "started" then
        exports['qb-target']:AddTargetEntity(ped, {
          options = {
            {
              icon = icon,
              label = label,
              action = function()
                doPayAndTreat()
              end
            }
          },
          distance = dist
        })
        hasAny = true
      end
    end
  end

  return hasAny
end

local function runJGTextUI()
  local inter = Config and Config.Interaction or {}
  local jg = inter.JGTextUI or {}

  local label = jg.Label or "Doctor ($500) - Press [E]"
  local dist = inter.Distance or 2.2

  CreateThread(function()
    while true do
      Wait(250)

      if busy then
        JG_Hide()
        goto continue
      end

      local nearPed = getNearestDoctor(dist)
      if nearPed then
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
  local inter = Config and Config.Interaction or {}
  local mode = tostring(inter.Mode or "auto"):lower()

  if mode == "auto" then
    local ok = addTargetsForAll()
    if not ok and inter.JGTextUI and inter.JGTextUI.Enabled then
      runJGTextUI()
      ok = true
    end
    if not ok then
      Notify("No interaction method available (target/jg-textui).", "error")
    end
    return
  end

  if mode == "jg-textui" or mode == "jg_textui" then
    if getResState('jg-textui') ~= "started" then
      Notify("jg-textui is not started. Change Config.Interaction.Mode or start the resource.", "error")
      return
    end
    runJGTextUI()
    return
  end

  if mode == "ox-target" or mode == "ox_target" or mode == "qb-target" or mode == "qb_target" then
    local ok = addTargetsForAll()
    if not ok then
      Notify("Target is not started. Change Config.Interaction.Mode.", "error")
    end
    return
  end
end

CreateThread(function()
  Wait(500)
  spawnDoctors()
  BuildDoctorBlipsFromConfig()
  Wait(500)
  setupInteraction()
end)

AddEventHandler('onResourceStop', function(res)
  if res ~= GetCurrentResourceName() then return end
  JG_Hide()

  ClearDoctorBlips()

  for i = 1, #doctorPeds do
    local ped = doctorPeds[i]
    if ped and DoesEntityExist(ped) then
      DeleteEntity(ped)
    end
  end
end)
