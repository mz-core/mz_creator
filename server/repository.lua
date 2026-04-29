MZCreatorRepository = {}

function MZCreatorRepository.getByCitizenId(citizenid)
  return MySQL.single.await([[
    SELECT *
    FROM mz_creator_appearances
    WHERE citizenid = ?
    LIMIT 1
  ]], { citizenid })
end

function MZCreatorRepository.upsert(citizenid, model, appearance)
  local encoded = json.encode(appearance or {})

  MySQL.insert.await([[
    INSERT INTO mz_creator_appearances (citizenid, model, appearance_json)
    VALUES (?, ?, ?)
    ON DUPLICATE KEY UPDATE
      model = VALUES(model),
      appearance_json = VALUES(appearance_json)
  ]], {
    citizenid,
    model,
    encoded
  })

  return MZCreatorRepository.getByCitizenId(citizenid)
end
