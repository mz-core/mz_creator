MZCreatorFlow = {
  open = false,
  mode = 'manual',
  savedAppearance = nil,
  currentAppearance = nil,
  currentState = nil,
  previousCoords = nil,
  previousHeading = nil,
  securityLifecycleId = nil,
  sceneFocusOwned = false,
  awaitingCoreSpawn = false
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

local function creatorConfig()
  return Config.Creator or {}
end

local function debugLog(message, ...)
  if creatorConfig().debug ~= true then return end
  print(('[MZ_CREATOR][CLIENT] ' .. message):format(...))
end

local function errorLog(message, ...)
  print(('[MZ_CREATOR][CLIENT][ERROR] ' .. message):format(...))
end

local function nativeBool(value)
  return value == true or value == 1
end

local function waitForFadeOut()
  local cfg = creatorConfig()
  debugLog('screenFadedOut=%s', tostring(nativeBool(IsScreenFadedOut())))
  if nativeBool(IsScreenFadedOut()) then return true end

  local duration = tonumber(cfg.fadeOutMs) or 250
  DoScreenFadeOut(duration)
  local deadline = GetGameTimer() + duration + 2000
  while not nativeBool(IsScreenFadedOut()) and GetGameTimer() < deadline do Wait(0) end
  return nativeBool(IsScreenFadedOut())
end

local function fadeIn()
  local duration = tonumber(creatorConfig().fadeInMs) or 500
  DoScreenFadeIn(duration)
  debugLog('fadeIn')
  local deadline = GetGameTimer() + duration + 2000
  while not nativeBool(IsScreenFadedIn()) and GetGameTimer() < deadline do Wait(0) end
  return nativeBool(IsScreenFadedIn())
end

local function clearSceneFocus()
  if not MZCreatorFlow.sceneFocusOwned then return end
  ClearFocus()
  MZCreatorFlow.sceneFocusOwned = false
end

local function releaseCreatorVisuals()
  SetNuiFocus(false, false)
  SendNUIMessage({ action = 'close' })
  MZCreatorCamera.close()
  clearSceneFocus()
  suppressHud(false)
end

local function prepareCreatorScene(appearance)
  local cfg = creatorConfig()
  local spawn = cfg.spawnLocation
  local coords = spawn and spawn.coords or nil
  if not coords then return false, 'scene_coordinates_missing' end

  local appearanceOk, appearanceErr = MZCreatorAppearance.apply(appearance)
  if appearanceOk ~= true then return false, appearanceErr or 'appearance_apply_failed' end

  local ped = PlayerPedId()
  if not ped or ped == 0 or not nativeBool(DoesEntityExist(ped)) then return false, 'invalid_ped' end

  RequestCollisionAtCoord(coords.x, coords.y, coords.z)
  SetFocusPosAndVel(coords.x, coords.y, coords.z, 0.0, 0.0, 0.0)
  MZCreatorFlow.sceneFocusOwned = true

  SetEntityCoordsNoOffset(ped, coords.x, coords.y, coords.z, false, false, false)
  SetEntityHeading(ped, tonumber(spawn.heading) or 0.0)
  SetEntityVisible(ped, true, false)
  SetEntityCollision(ped, true, true)
  FreezeEntityPosition(ped, true)
  SetPlayerInvincible(PlayerId(), true)
  SetEntityInvincible(ped, true)

  local interior = GetInteriorAtCoords(coords.x, coords.y, coords.z)
  if interior and interior ~= 0 then LoadInterior(interior) end

  local deadline = GetGameTimer() + (tonumber(cfg.sceneTimeoutMs) or 5000)
  local collisionReady = nativeBool(HasCollisionLoadedAroundEntity(ped))
  local interiorReady = not interior or interior == 0 or nativeBool(IsInteriorReady(interior))
  while (not collisionReady or not interiorReady) and GetGameTimer() < deadline do
    RequestCollisionAtCoord(coords.x, coords.y, coords.z)
    Wait(50)
    collisionReady = nativeBool(HasCollisionLoadedAroundEntity(ped))
    interiorReady = not interior or interior == 0 or nativeBool(IsInteriorReady(interior))
  end

  local pedCoords = GetEntityCoords(ped)
  debugLog('pedPosition x=%.2f y=%.2f z=%.2f heading=%.2f',
    pedCoords.x, pedCoords.y, pedCoords.z, GetEntityHeading(ped))
  debugLog('sceneReady collision=%s interior=%s', tostring(collisionReady), tostring(interiorReady))
  if not collisionReady or not interiorReady then return false, 'scene_load_timeout' end
  return true
end

local function openCreatorVisuals(state, appearance)
  if not waitForFadeOut() then
    errorLog('fade_out_timeout')
    fadeIn()
    return false
  end

  local sceneOk, sceneErr = prepareCreatorScene(appearance)
  if not sceneOk then
    errorLog('scene_failed error=%s', tostring(sceneErr))
    releaseCreatorVisuals()
    fadeIn()
    return false
  end

  local cameraOk = MZCreatorCamera.open(creatorConfig().defaultCameraMode or 'face')
  if cameraOk ~= true then
    debugLog('cameraActive=false')
    errorLog('camera_creation_failed')
    releaseCreatorVisuals()
    fadeIn()
    return false
  end
  debugLog('cameraCreated')
  debugLog('cameraActive=true')

  if not fadeIn() then
    errorLog('fade_in_timeout')
    releaseCreatorVisuals()
    return false
  end
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
    allowCameraRotation = creatorConfig().allowCameraRotation ~= false
  })
  debugLog('uiOpened')
  return true
end

local function beginCoreHandoff()
  if not waitForFadeOut() then return false end
  releaseCreatorVisuals()
  MZCreatorFlow.awaitingCoreSpawn = true
  debugLog('coreHandoff')
  return true
end

local function getDefaultAppearance(model)
  return MZCreatorAppearance.defaultForModel(model or 'mp_m_freemode_01')
end

local function isFirstLoginMode()
  local autoConfig = Config.AutoOpen or {}
  return MZCreatorFlow.mode == (autoConfig.mode or 'first_login')
end

local function isMulticharCreationMode()
  return MZCreatorFlow.mode == 'multichar_create'
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

local function closeCreator(cancelled, options)
  options = options or {}
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


  if cancelled and isMulticharCreationMode() then
    local result = lib.callback.await('mz_creator:server:cancelPendingCharacter', false)
    if not result or result.ok ~= true then
      notify({
        type = 'error',
        title = 'Creator',
        description = 'Nao foi possivel cancelar a criacao.'
      })
      return false
    end
  end

  if options.visualsAlreadyClosed ~= true then
    releaseCreatorVisuals()
  end

  if cancelled and MZCreatorFlow.savedAppearance then
    MZCreatorAppearance.apply(MZCreatorFlow.savedAppearance)
  end

  -- Restaurar posição anterior se existir
  if MZCreatorFlow.previousCoords and not isMulticharCreationMode() then
    local ped = PlayerPedId()
    SetEntityCoords(ped, MZCreatorFlow.previousCoords.x, MZCreatorFlow.previousCoords.y, MZCreatorFlow.previousCoords.z, false, false, false, false)
    if MZCreatorFlow.previousHeading then
      SetEntityHeading(ped, MZCreatorFlow.previousHeading)
    end
  end

  local securityLifecycleId = MZCreatorFlow.securityLifecycleId
  MZCreatorFlow.open = false
  MZCreatorFlow.mode = 'manual'
  MZCreatorFlow.currentState = nil
  MZCreatorFlow.previousCoords = nil
  MZCreatorFlow.previousHeading = nil
  MZCreatorFlow.securityLifecycleId = nil
  if options.preserveCoreSpawn ~= true then
    MZCreatorFlow.awaitingCoreSpawn = false
  end
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

  debugLog('open mode=%s', tostring(mode or 'manual'))
  MZCreatorFlow.open = true
  MZCreatorFlow.mode = mode or 'manual'
  MZCreatorFlow.savedAppearance = state.appearance
  MZCreatorFlow.currentAppearance = appearance
  MZCreatorFlow.currentState = state
  MZCreatorFlow.securityLifecycleId = state.securityLifecycleId
  MZCreatorFlow.awaitingCoreSpawn = false
  suppressHud(true)

  -- Salvar posição anterior
  local ped = PlayerPedId()
  MZCreatorFlow.previousCoords = GetEntityCoords(ped)
  MZCreatorFlow.previousHeading = GetEntityHeading(ped)

  if not openCreatorVisuals(state, appearance) then
    local securityLifecycleId = MZCreatorFlow.securityLifecycleId
    MZCreatorFlow.open = false
    MZCreatorFlow.mode = 'manual'
    MZCreatorFlow.currentState = nil
    MZCreatorFlow.securityLifecycleId = nil
    if type(securityLifecycleId) == 'string' and securityLifecycleId ~= '' then
      TriggerServerEvent('mz_creator:server:endSecuritySession', securityLifecycleId, 'creator_scene_failed')
    end
    notify({
      type = 'error',
      title = 'Creator',
      description = 'A cena de criacao nao carregou. Consulte o F8 e reconecte.'
    })
  end
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

  local handingOffToCore = isMulticharCreationMode()
  if handingOffToCore and not beginCoreHandoff() then
    cb({ ok = false, error = 'creator_fade_out_failed' })
    return
  end

  local result = lib.callback.await('mz_creator:server:saveCharacter', false, {
    identity = identity,
    appearance = {
      model = appearance.model,
      appearance_json = appearance
    },
    spawn = data.spawn,
    requestId = ('creator:%s:%s'):format(GetGameTimer(), math.random(100000, 999999))
  })

  if result and result.ok == true then
    MZCreatorFlow.savedAppearance = result.appearance
    if not handingOffToCore then
      MZCreatorAppearance.apply(result.appearance)
    end
    closeCreator(false, {
      visualsAlreadyClosed = handingOffToCore,
      preserveCoreSpawn = handingOffToCore
    })
  elseif handingOffToCore then
    MZCreatorFlow.awaitingCoreSpawn = false
    suppressHud(true)
    if not openCreatorVisuals(MZCreatorFlow.currentState or {}, MZCreatorFlow.currentAppearance or appearance) then
      errorLog('handoff_recovery_failed error=%s', tostring(result and result.error or 'save_failed'))
    end
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

RegisterNetEvent('mz_core:client:pedModelReady', function(payload)
  if type(payload) ~= 'table' or payload.reason ~= 'core_spawn_complete'
    or MZCreatorFlow.awaitingCoreSpawn ~= true then return end
  MZCreatorFlow.awaitingCoreSpawn = false
  debugLog('spawnComplete')
  fadeIn()
end)

AddEventHandler('onResourceStop', function(resourceName)
  if resourceName ~= GetCurrentResourceName() then
    return
  end

  if MZCreatorFlow.open or MZCreatorCamera.active then
    releaseCreatorVisuals()
    fadeIn()
  else
    suppressHud(false)
    clearSceneFocus()
  end
end)

AddEventHandler('onClientResourceStart', function(resourceName)
  if resourceName == 'mz_hud' and MZCreatorFlow.open then
    suppressHud(true)
  end
end)
