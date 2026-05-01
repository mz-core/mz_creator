exports('GetAppearance', function(citizenid)
  return MZCreatorService.getAppearance(citizenid)
end)

exports('ApplyAppearance', function(source)
  return MZCreatorService.applyAppearance(source)
end)

exports('MergeClothingAppearance', function(source, clothingAppearance)
  return MZCreatorService.mergeClothingAppearance(source, clothingAppearance)
end)

exports('HasCreatedCharacter', function(source)
  return MZCreatorService.hasCreatedCharacter(source)
end)

exports('OpenCreator', function(source, mode)
  TriggerClientEvent('mz_creator:client:open', source, mode or 'manual')
  return true
end)
