-- server.lua
local FW = nil
local ESX = nil
local isQB = false
local isESX = false

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

local function hasAndRemoveMoney(src, amount)
  amount = tonumber(amount) or 0
  if amount <= 0 then return true, "free" end

  local allowCash = (Config and Config.AllowCash) ~= false
  local allowBank = (Config and Config.AllowBank) ~= false
  local preferCash = (Config and Config.PreferCashFirst) == true

  if isQB and FW and FW.Functions then
    local Player = FW.Functions.GetPlayer(src)
    if not Player then return false end

    local money = Player.PlayerData.money or {}
    local cash = tonumber(money.cash) or 0
    local bank = tonumber(money.bank) or 0

    local function pay(acc)
      Player.Functions.RemoveMoney(acc, amount, 'izaap_npc-doctor')
    end

    if preferCash then
      if allowCash and cash >= amount then pay('cash'); return true, "cash" end
      if allowBank and bank >= amount then pay('bank'); return true, "bank" end
    else
      if allowBank and bank >= amount then pay('bank'); return true, "bank" end
      if allowCash and cash >= amount then pay('cash'); return true, "cash" end
    end

    return false
  end

  if isESX and ESX then
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return false end

    local cash = tonumber(xPlayer.getMoney()) or 0
    local bank = 0

    if xPlayer.getAccount then
      local acc = xPlayer.getAccount('bank')
      bank = tonumber((acc and acc.money) or 0) or 0
    end

    local function payCash()
      xPlayer.removeMoney(amount)
    end

    local function payBank()
      if xPlayer.removeAccountMoney then
        xPlayer.removeAccountMoney('bank', amount)
      else
        return false
      end
      return true
    end

    if preferCash then
      if allowCash and cash >= amount then payCash(); return true, "cash" end
      if allowBank and bank >= amount then
        local ok = payBank()
        if ok then return true, "bank" end
      end
    else
      if allowBank and bank >= amount then
        local ok = payBank()
        if ok then return true, "bank" end
      end
      if allowCash and cash >= amount then payCash(); return true, "cash" end
    end

    return false
  end


  return false
end

RegisterNetEvent('izaap_npc:server:payAndRevive', function()
  local src = source

  local price = tonumber((Config and Config.Price) or 0) or 0
  local msgs = (Config and Config.Messages) or {}

  local ok = hasAndRemoveMoney(src, price)
  if not ok then
    TriggerClientEvent('izaap_npc:client:notify', src, msgs.NotEnough or ("No tienes suficiente dinero para pagar $"..tostring(price)), 'error')
    return
  end

  TriggerClientEvent('izaap_npc:client:notify', src, msgs.Paid or ("Has pagado $"..tostring(price)..". Te están reviviendo..."), 'success')
  TriggerClientEvent('izaap_npc:client:doRevive', src)
end)
