lib.callback.register('mz_creator:server:getState', function(source)
  return MZCreatorService.getState(source)
end)

lib.callback.register('mz_creator:server:saveAppearance', function(source, payload)
  return MZCreatorService.saveAppearance(source, payload)
end)

lib.callback.register('mz_creator:server:saveCharacter', function(source, payload)
  return MZCreatorService.saveCharacter(source, payload)
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
