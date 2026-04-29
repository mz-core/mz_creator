MZCreatorFlow = {
  open = false,
  mode = 'manual',
  savedAppearance = nil,
  currentAppearance = nil
}

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

local function closeCreator(cancelled)
  if not MZCreatorFlow.open then
    return
  end

  SetNuiFocus(false, false)
  SendNUIMessage({ action = 'close' })
  MZCreatorCamera.close()

  if cancelled and MZCreatorFlow.savedAppearance then
    MZCreatorAppearance.apply(MZCreatorFlow.savedAppearance)
  end

  MZCreatorFlow.open = false
  MZCreatorFlow.mode = 'manual'
end

function MZCreatorFlow.openCreator(mode)
  if MZCreatorFlow.open then
    return
  end

  local state = lib.callback.await('mz_creator:server:getState', false)
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
    }
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

RegisterNUICallback('ready', function(_, cb)
  cb({ ok = true })
end)

RegisterNUICallback('close', function(_, cb)
  closeCreator(true)
  cb({ ok = true })
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
      DisableControlAction(0, 30, true)
      DisableControlAction(0, 31, true)
      DisableControlAction(0, 32, true)
      DisableControlAction(0, 33, true)
      DisableControlAction(0, 34, true)
      DisableControlAction(0, 35, true)
      DisableControlAction(0, 44, true)
      DisableControlAction(0, 75, true)
      MZCreatorCamera.update()
      Wait(0)
    else
      Wait(500)
    end
  end
end)
