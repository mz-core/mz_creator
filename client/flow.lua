MZCreatorFlow = {
  open = false,
  mode = 'manual',
  savedAppearance = nil,
  currentAppearance = nil,
  previousCoords = nil,
  previousHeading = nil,
  securityLifecycleId = nil
}

local autoOpenChecked = false
local spawnAppearanceApplying = false

local function suppressHud(suppressed)
  TriggerEvent('mz_hud:client:setSuppressed', 'mz_creator', suppressed == true)
end

local function notify(message)
  if lib and lib.notify then
    lib.notify(message)
    return
  end

  print(('[mz_creator] %s'):format(message.description or message.message or message.title or 'notification'))
end

local function getDefaultAppearance(model)
  return MZCreatorAppearance.defaultForModel(model or 'mp_m_freemode_01')
end

local function isFirstLoginMode()
  local autoConfig = Config.AutoOpen or {}
  return MZCreatorFlow.mode == (autoConfig.mode or 'first_login')
end

local function shouldApplySavedAppearance()
  local creatorConfig = Config.Creator or {}
  return creatorConfig.applySavedAppearanceOnSpawn == true
end

local function applySavedAppearance(state)
  if not state or state.ok ~= true or state.hasAppearance ~= true or type(state.appearance) ~= 'table' then
    return false
  end

  return MZCreatorAppearance.apply(state.appearance) == true
end

local function applySavedAppearanceAfterSpawn()
  if not shouldApplySavedAppearance() or spawnAppearanceApplying then
    return
  end

  spawnAppearanceApplying = true

  CreateThread(function()
    local creatorConfig = Config.Creator or {}
    local delay = tonumber(creatorConfig.applySavedAppearanceDelayMs) or 800
    if delay > 0 then
      Wait(delay)
    end

    if not MZCreatorFlow.open then
      local state = lib.callback.await('mz_creator:server:getState', false)
      if state and state.characterCreated == true then
        applySavedAppearance(state)
      end
    end

    spawnAppearanceApplying = false
  end)
end

local function closeCreator(cancelled)
  if not MZCreatorFlow.open then
    return true
  end

  if cancelled and isFirstLoginMode() then
    SetNuiFocus(true, true)
    notify({
      type = 'error',
      title = 'Creator',
      description = 'Voce precisa salvar seu personagem antes de sair.'
    })
    return false
  end

  SetNuiFocus(false, false)
  SendNUIMessage({ action = 'close' })
  MZCreatorCamera.close()
  suppressHud(false)

  if cancelled and MZCreatorFlow.savedAppearance then
    MZCreatorAppearance.apply(MZCreatorFlow.savedAppearance)
  end

  -- Restaurar posição anterior se existir
  if MZCreatorFlow.previousCoords then
    local ped = PlayerPedId()
    SetEntityCoords(ped, MZCreatorFlow.previousCoords.x, MZCreatorFlow.previousCoords.y, MZCreatorFlow.previousCoords.z, false, false, false, false)
    if MZCreatorFlow.previousHeading then
      SetEntityHeading(ped, MZCreatorFlow.previousHeading)
    end
  end

  local securityLifecycleId = MZCreatorFlow.securityLifecycleId
  MZCreatorFlow.open = false
  MZCreatorFlow.mode = 'manual'
  MZCreatorFlow.previousCoords = nil
  MZCreatorFlow.previousHeading = nil
  MZCreatorFlow.securityLifecycleId = nil
  if type(securityLifecycleId) == 'string' and securityLifecycleId ~= '' then
    TriggerServerEvent('mz_creator:server:endSecuritySession', securityLifecycleId,
      cancelled == true and 'creator_cancelled' or 'creator_saved')
  end
  return true
end

function MZCreatorFlow.openCreator(mode, preloadedState)
  if MZCreatorFlow.open then
    return
  end

  local state = preloadedState
  if type(state) ~= 'table' or type(state.securityLifecycleId) ~= 'string' then
    state = lib.callback.await('mz_creator:server:beginSecuritySession', false)
  end
  if not state or state.ok ~= true then
    notify({
      type = 'error',
      title = 'Creator',
      description = 'Player ainda nao carregado no mz_core.'
    })
    return
  end

  local appearance = state.appearance or getDefaultAppearance('mp_m_freemode_01')

  MZCreatorFlow.open = true
  MZCreatorFlow.mode = mode or 'manual'
  MZCreatorFlow.savedAppearance = state.appearance
  MZCreatorFlow.currentAppearance = appearance
  MZCreatorFlow.securityLifecycleId = state.securityLifecycleId
  suppressHud(true)

  -- Salvar posição anterior
  local ped = PlayerPedId()
  MZCreatorFlow.previousCoords = GetEntityCoords(ped)
  MZCreatorFlow.previousHeading = GetEntityHeading(ped)

  -- Teleportar para spawn location do creator
  local creatorConfig = Config.Creator or {}
  local spawnLoc = creatorConfig.spawnLocation
  if spawnLoc and spawnLoc.coords then
    SetEntityCoords(ped, spawnLoc.coords.x, spawnLoc.coords.y, spawnLoc.coords.z, false, false, false, false)
    if spawnLoc.heading then
      SetEntityHeading(ped, spawnLoc.heading)
    end
  end

  MZCreatorAppearance.apply(appearance)
  MZCreatorCamera.open(Config.Creator and Config.Creator.defaultCameraMode or 'face')

  SetNuiFocus(true, true)
  SendNUIMessage({
    action = 'open',
    mode = MZCreatorFlow.mode,
    state = state,
    appearance = appearance,
    defaults = MZCreatorDefaults.byModel,
    allowedModels = {
      'mp_m_freemode_01',
      'mp_f_freemode_01'
    },
    allowCameraRotation = (Config.Creator and Config.Creator.allowCameraRotation) ~= false
  })
end

RegisterNetEvent('mz_creator:client:open', function(mode)
  MZCreatorFlow.openCreator(mode or 'manual')
end)

RegisterNetEvent('mz_creator:client:close', function()
  closeCreator(true)
end)

RegisterNetEvent('mz_creator:client:applyAppearance', function(appearance)
  MZCreatorAppearance.apply(appearance)
end)

RegisterNetEvent('mz_core:client:playerLoaded', function()
  local autoConfig = Config.AutoOpen or {}
  if autoConfig.enabled ~= true or autoOpenChecked then
    return
  end

  autoOpenChecked = true

  CreateThread(function()
    local delay = tonumber(autoConfig.delayMs) or 1200
    if delay > 0 then
      Wait(delay)
    end

    if MZCreatorFlow.open then
      return
    end

    local state = lib.callback.await('mz_creator:server:getState', false)
    if not state or state.ok ~= true then
      return
    end

    if state.characterCreated ~= true then
      MZCreatorFlow.openCreator(autoConfig.mode or 'first_login', state)
    else
      applySavedAppearance(state)
    end
  end)
end)

AddEventHandler('playerSpawned', function()
  applySavedAppearanceAfterSpawn()
end)

RegisterNUICallback('ready', function(_, cb)
  cb({ ok = true })
end)

RegisterNUICallback('close', function(_, cb)
  local closed = closeCreator(true)
  cb({
    ok = closed == true,
    error = closed == true and nil or 'character_required',
    detail = closed == true and nil or 'Voce precisa salvar seu personagem antes de sair.'
  })
end)

RegisterNUICallback('previewAppearance', function(data, cb)
  local appearance = data and (data.appearance_json or data.appearance or data) or nil
  if type(appearance) ~= 'table' then
    cb({ ok = false, error = 'invalid_appearance' })
    return
  end

  MZCreatorFlow.currentAppearance = appearance
  local ok, err = MZCreatorAppearance.apply(appearance)
  cb({ ok = ok == true, error = err })
end)

RegisterNUICallback('setModel', function(data, cb)
  local model = data and data.model or 'mp_m_freemode_01'
  local appearance = getDefaultAppearance(model)
  MZCreatorFlow.currentAppearance = appearance
  local ok, err = MZCreatorAppearance.apply(appearance)
  cb({
    ok = ok == true,
    error = err,
    appearance = appearance
  })
end)

RegisterNUICallback('rotate', function(data, cb)
  MZCreatorCamera.rotate(data and data.amount or 0)
  cb({ ok = true })
end)

RegisterNUICallback('setCameraMode', function(data, cb)
  MZCreatorCamera.setMode(data and data.mode or 'face')
  cb({ ok = true })
end)

RegisterNUICallback('saveAppearance', function(data, cb)
  if isFirstLoginMode() then
    cb({
      ok = false,
      error = 'character_required',
      detail = 'Preencha a identidade e salve o personagem.'
    })
    return
  end

  local appearance = data and (data.appearance_json or data.appearance or data) or nil
  if type(appearance) ~= 'table' then
    cb({ ok = false, error = 'invalid_appearance' })
    return
  end

  local result = lib.callback.await('mz_creator:server:saveAppearance', false, {
    model = appearance.model,
    appearance_json = appearance
  })

  if result and result.ok == true then
    MZCreatorFlow.savedAppearance = result.appearance
    MZCreatorAppearance.apply(result.appearance)
    closeCreator(false)
  end

  cb(result or { ok = false, error = 'save_failed' })
end)

RegisterNUICallback('saveCharacter', function(data, cb)
  local identity = data and data.identity or nil
  local appearance = data and data.appearance or nil

  if type(identity) ~= 'table' or type(appearance) ~= 'table' then
    cb({ ok = false, error = 'invalid_payload' })
    return
  end

  local result = lib.callback.await('mz_creator:server:saveCharacter', false, {
    identity = identity,
    appearance = {
      model = appearance.model,
      appearance_json = appearance
    },
    spawn = data.spawn
  })

  if result and result.ok == true then
    MZCreatorFlow.savedAppearance = result.appearance
    MZCreatorAppearance.apply(result.appearance)
    closeCreator(false)
  end

  cb(result or { ok = false, error = 'save_failed' })
end)

CreateThread(function()
  while true do
    if MZCreatorFlow.open then
      HideHudAndRadarThisFrame()
      DisableControlAction(0, 1, true)
      DisableControlAction(0, 2, true)
      DisableControlAction(0, 24, true)
      DisableControlAction(0, 25, true)
      DisableControlAction(0, 22, true)
      DisableControlAction(0, 23, true)
      DisableControlAction(0, 30, true)
      DisableControlAction(0, 31, true)
      DisableControlAction(0, 32, true)
      DisableControlAction(0, 33, true)
      DisableControlAction(0, 34, true)
      DisableControlAction(0, 35, true)
      DisableControlAction(0, 37, true)
      DisableControlAction(0, 44, true)
      DisableControlAction(0, 45, true)
      DisableControlAction(0, 75, true)
      DisableControlAction(0, 140, true)
      DisableControlAction(0, 141, true)
      DisableControlAction(0, 142, true)
      DisablePlayerFiring(PlayerId(), true)
      MZCreatorCamera.update()
      Wait(0)
    else
      Wait(500)
    end
  end
end)

AddEventHandler('onResourceStop', function(resourceName)
  if resourceName ~= GetCurrentResourceName() then
    return
  end

  suppressHud(false)
end)

AddEventHandler('onClientResourceStart', function(resourceName)
  if resourceName == 'mz_hud' and MZCreatorFlow.open then
    suppressHud(true)
  end
end)
