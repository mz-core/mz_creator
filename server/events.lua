lib.callback.register('mz_creator:server:getState', function(source)
  return MZCreatorService.getState(source)
end)

local function beginCreatorSecuritySession(source)
  if GetResourceState('mz_banguard') == 'started' then
    local called, valid = pcall(function()
      return exports['mz_banguard']:ValidateEventContract(source, 'lifecycle.creator.open', {})
    end)
    if not called or valid ~= true then return { ok = false, error = 'invalid_security_contract' } end
  end
  local state = MZCreatorService.getState(source)
  if type(state) ~= 'table' or state.ok ~= true then return state end
  if GetResourceState('mz_banguard') ~= 'started' then return state end

  local ped = GetPlayerPed(source)
  local previous = ped and ped ~= 0 and DoesEntityExist(ped) and GetEntityCoords(ped) or nil
  local spawn = Config.Creator and Config.Creator.spawnLocation
  local destination = spawn and spawn.coords or nil
  local models = {}
  for model, allowed in pairs(Config.Creator and Config.Creator.allowedModels or {}) do
    if allowed == true then models[#models + 1] = GetHashKey(model) end
  end
  local context = {
    models = models,
    bucket = GetPlayerRoutingBucket(source),
    x = destination and destination.x, y = destination and destination.y, z = destination and destination.z,
    returnX = previous and previous.x, returnY = previous and previous.y, returnZ = previous and previous.z,
    reason = 'creator_open'
  }
  local ok, lifecycleId = pcall(function()
    return exports['mz_banguard']:BeginSecurityLifecycle(source, 'character_creation', 300000, context)
  end)
  if not ok or type(lifecycleId) ~= 'string' then
    return { ok = false, error = 'security_session_failed' }
  end
  state.securityLifecycleId = lifecycleId
  return state
end

lib.callback.register('mz_creator:server:beginSecuritySession', function(source)
  return beginCreatorSecuritySession(source)
end)

lib.callback.register('mz_creator:server:saveAppearance', function(source, payload)
  return MZCreatorService.saveAppearance(source, payload)
end)

lib.callback.register('mz_creator:server:saveCharacter', function(source, payload)
  return MZCreatorService.saveCharacter(source, payload)
end)

lib.callback.register('mz_creator:server:cancelPendingCharacter', function(source)
  local ok, cancelled, err = pcall(function()
    return exports['mz_core']:CancelPendingCharacter(source)
  end)
  if not ok then return { ok = false, error = 'core_unavailable' } end
  return { ok = cancelled == true, error = cancelled == true and nil or err }
end)

RegisterNetEvent('mz_creator:server:saveAppearance', function(payload)
  local src = source
  local result = MZCreatorService.saveAppearance(src, payload)
  if result and result.ok == true then
    TriggerClientEvent('mz_creator:client:applyAppearance', src, result.appearance)
  end
end)

RegisterNetEvent('mz_creator:server:saveCharacter', function(payload)
  local src = source
  local result = MZCreatorService.saveCharacter(src, payload)
  if result and result.ok == true then
    TriggerClientEvent('mz_creator:client:applyAppearance', src, result.appearance)
  end
end)

RegisterNetEvent('mz_creator:server:endSecuritySession', function(sessionId, reason)
  if GetResourceState('mz_banguard') ~= 'started' then return end
  pcall(function()
    exports['mz_banguard']:EndSecurityLifecycle(source, sessionId, tostring(reason or 'creator_closed'))
  end)
end)
