MZCreatorState = MZCreatorState or {
  prepareDone = false,
  prepareOk = false
}

CreateThread(function()
  local ok, err = pcall(function()
    MySQL.query.await([[
      CREATE TABLE IF NOT EXISTS mz_creator_appearances (
        id INT AUTO_INCREMENT PRIMARY KEY,
        citizenid VARCHAR(32) NOT NULL,
        model VARCHAR(64) NOT NULL,
        appearance_json LONGTEXT NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        UNIQUE KEY uq_mz_creator_appearances_citizenid (citizenid),
        KEY idx_mz_creator_appearances_model (model)
      )
    ]])
  end)

  MZCreatorState.prepareDone = true
  MZCreatorState.prepareOk = ok == true

  if not ok then
    print(('[mz_creator] prepare failed: %s'):format(tostring(err)))
    return
  end

  print('[mz_creator] prepare completed')
end)
