MZCreatorService = {}

local function encodeJson(value)
  local ok, result = pcall(json.encode, value or {})
  if not ok then
    return nil
  end
  return result
end

local function decodeJson(value, fallback)
  if type(value) == 'table' then
    return value
  end

  if type(value) ~= 'string' or value == '' then
    return fallback
  end

  local ok, result = pcall(json.decode, value)
  if not ok then
    return fallback
  end

  return result
end

local function cloneTable(value)
  if type(value) ~= 'table' then
    return value
  end

  local out = {}
  for key, child in pairs(value) do
    out[key] = cloneTable(child)
  end
  return out
end

local function getPayloadSize(value)
  if type(value) == 'string' then
    return #value
  end

  local encoded = encodeJson(value)
  return encoded and #encoded or 0
end

local function fail(code, detail)
  return nil, {
    ok = false,
    error = code,
    detail = detail
  }
end

local function getCreatorConfig()
  return Config.Creator or {}
end

local function isAllowedModel(model)
  local creatorConfig = getCreatorConfig()
  local allowedModels = creatorConfig.allowedModels or MZCreatorSchema.allowedModels
  return type(model) == 'string' and allowedModels[model] == true
end

local function getPlayer(source)
  local ok, player = pcall(function()
    return exports['mz_core']:GetPlayerSnapshot(source)
  end)

  if not ok then
    return nil
  end

  return player
end

local function getCoreMetadataAppearance(source)
  local ok, value = pcall(function()
    return exports['mz_core']:GetMetadataValue(source, 'appearance')
  end)

  if ok and type(value) == 'table' then
    return value
  end

  return nil
end

local function syncCoreAppearanceMetadata(source, appearance, markCharacterCreated)
  if type(appearance) ~= 'table' then
    return false
  end

  local ok, result = pcall(function()
    return exports['mz_core']:SetMetadataValue(source, 'appearance', appearance)
  end)

  if not ok or result ~= true then
    return false
  end

  pcall(function()
    exports['mz_core']:SetMetadataValue(source, 'appearance_updated_at', os.time())
  end)

  if markCharacterCreated == true then
    pcall(function()
      exports['mz_core']:SetMetadataValue(source, 'character_created', true)
    end)
  end

  return true
end

local function isPlainSafeKey(key)
  local keyType = type(key)
  if keyType ~= 'string' and keyType ~= 'number' then
    return false
  end

  if keyType == 'string' and key:sub(1, 2) == '__' then
    return false
  end

  return true
end

local function inspectTable(value, depth, path)
  if type(value) ~= 'table' then
    local valueType = type(value)
    if valueType == 'function' or valueType == 'userdata' or valueType == 'thread' then
      return false, ('invalid value at %s'):format(path)
    end
    return true
  end

  local creatorConfig = getCreatorConfig()
  local maxDepth = tonumber(creatorConfig.maxTableDepth) or 5
  if depth > maxDepth then
    return false, ('table too deep at %s'):format(path)
  end

  local count = 0
  for key, child in pairs(value) do
    count = count + 1
    if count > 128 then
      return false, ('too many keys at %s'):format(path)
    end

    if not isPlainSafeKey(key) then
      return false, ('unsafe key at %s'):format(path)
    end

    local childOk, childErr = inspectTable(child, depth + 1, ('%s.%s'):format(path, tostring(key)))
    if not childOk then
      return false, childErr
    end
  end

  return true
end

local function rejectUnknownKeys(value, allowed, path)
  if type(value) ~= 'table' then
    return false, ('%s must be table'):format(path)
  end

  for key, _ in pairs(value) do
    if allowed[key] == nil then
      return false, ('unknown field %s.%s'):format(path, tostring(key))
    end
  end

  return true
end

local function normalizeNumber(value, rule, path)
  local numeric = tonumber(value)
  if numeric == nil then
    return fail('invalid_number', path)
  end

  if rule.integer == true and math.floor(numeric) ~= numeric then
    return fail('invalid_integer', path)
  end

  if numeric < rule.min or numeric > rule.max then
    return fail('out_of_range', path)
  end

  if rule.integer == true then
    numeric = math.floor(numeric)
  end

  return numeric
end

local function normalizeNumberGroup(raw, defaults, rules, path)
  raw = raw or {}
  local ok, err = rejectUnknownKeys(raw, rules, path)
  if not ok then
    return fail('unknown_field', err)
  end

  local out = {}
  for key, rule in pairs(rules) do
    local value = raw[key]
    if value == nil then
      value = defaults and defaults[key] or nil
    end

    if value == nil and rule.optional == true then
      out[key] = nil
    else
      local normalized, numberErr = normalizeNumber(value, rule, ('%s.%s'):format(path, key))
      if not normalized then
        return nil, numberErr
      end
      out[key] = normalized
    end
  end

  return out
end

local function normalizeHeadOverlays(raw, defaults)
  raw = raw or {}
  local ok, err = rejectUnknownKeys(raw, MZCreatorSchema.headOverlays, 'headOverlays')
  if not ok then
    return fail('unknown_field', err)
  end

  local out = {}
  local overlayFields = {
    style = true,
    opacity = true,
    color = true,
    secondaryColor = true
  }

  for key, schema in pairs(MZCreatorSchema.headOverlays) do
    local overlayRaw = raw[key] or {}
    if type(overlayRaw) ~= 'table' then
      return fail('invalid_overlay', key)
    end

    local overlayOk, overlayErr = rejectUnknownKeys(overlayRaw, overlayFields, ('headOverlays.%s'):format(key))
    if not overlayOk then
      return fail('unknown_field', overlayErr)
    end

    local overlayDefaults = defaults and defaults[key] or {}
    local overlay = {}

    for field, rule in pairs(schema) do
      if field ~= 'colorType' then
        local value = overlayRaw[field]
        if value == nil then
          value = overlayDefaults[field]
        end

        if value ~= nil or rule.optional ~= true then
          local normalized, numberErr = normalizeNumber(value, rule, ('headOverlays.%s.%s'):format(key, field))
          if not normalized then
            return nil, numberErr
          end
          overlay[field] = normalized
        end
      end
    end

    out[key] = overlay
  end

  return out
end

local function normalizeDrawableMap(raw, defaults, allowedIds, rules, path)
  raw = raw or {}
  local ok, err = rejectUnknownKeys(raw, allowedIds, path)
  if not ok then
    return fail('unknown_field', err)
  end

  local out = {}
  local valueFields = {
    drawable = true,
    texture = true
  }

  for id, _ in pairs(allowedIds) do
    local rawValue = raw[id] or {}
    if type(rawValue) ~= 'table' then
      return fail('invalid_drawable', ('%s.%s'):format(path, id))
    end

    local valueOk, valueErr = rejectUnknownKeys(rawValue, valueFields, ('%s.%s'):format(path, id))
    if not valueOk then
      return fail('unknown_field', valueErr)
    end

    local defaultValue = defaults and defaults[id] or {}
    local normalizedValue = {}

    for field, rule in pairs(rules) do
      local value = rawValue[field]
      if value == nil then
        value = defaultValue[field]
      end

      local normalized, numberErr = normalizeNumber(value, rule, ('%s.%s.%s'):format(path, id, field))
      if not normalized then
        return nil, numberErr
      end
      normalizedValue[field] = normalized
    end

    out[id] = normalizedValue
  end

  return out
end

local function normalizeTattoos(raw)
  raw = raw or {}
  if type(raw) ~= 'table' then
    return fail('invalid_tattoos', 'tattoos must be array')
  end

  local maxTattoos = tonumber(getCreatorConfig().maxTattoos) or 50

  local count = 0
  for key, _ in pairs(raw) do
    if type(key) ~= 'number' or math.floor(key) ~= key or key < 1 then
      return fail('unknown_field', ('tattoos.%s'):format(tostring(key)))
    end
    count = count + 1
  end

  if count > maxTattoos then
    return fail('too_many_tattoos', 'tattoos')
  end

  local out = {}
  local allowedTattooFields = {
    collection = true,
    overlay = true
  }

  for index, tattoo in ipairs(raw) do
    if type(tattoo) ~= 'table' then
      return fail('invalid_tattoo', tostring(index))
    end

    local ok, err = rejectUnknownKeys(tattoo, allowedTattooFields, ('tattoos.%s'):format(index))
    if not ok then
      return fail('unknown_field', err)
    end

    local collection = tostring(tattoo.collection or '')
    local overlay = tostring(tattoo.overlay or '')
    if #collection > 64 or #overlay > 64 then
      return fail('invalid_tattoo', tostring(index))
    end

    out[#out + 1] = {
      collection = collection,
      overlay = overlay
    }
  end

  return out
end

local function trim(value)
  return tostring(value or ''):gsub('^%s+', ''):gsub('%s+$', '')
end

local function utf8Length(value)
  local ok, length = pcall(function()
    return utf8.len(value)
  end)

  if not ok then return nil end
  return length
end

local function isAllowedLetterCodepoint(codepoint)
  return (codepoint >= 65 and codepoint <= 90)
    or (codepoint >= 97 and codepoint <= 122)
    or (codepoint >= 192 and codepoint <= 214)
    or (codepoint >= 216 and codepoint <= 246)
    or (codepoint >= 248 and codepoint <= 255)
end

local function validateLettersAndSingleSpaces(value, minLength, maxLength, path)
  local text = trim(value)
  local length = utf8Length(text)

  if not length or length < minLength or length > maxLength then
    return fail('invalid_text_length', path)
  end

  if text:find('%s%s+') then
    return fail('invalid_spaces', path)
  end

  for _, codepoint in utf8.codes(text) do
    if codepoint ~= 32 and not isAllowedLetterCodepoint(codepoint) then
      return fail('invalid_characters', path)
    end
  end

  return text
end

local function isLeapYear(year)
  return (year % 4 == 0 and year % 100 ~= 0) or year % 400 == 0
end

local function validateBirthdate(value)
  local text = tostring(value or '')
  local yearText, monthText, dayText = text:match('^(%d%d%d%d)%-(%d%d)%-(%d%d)$')
  if not yearText then
    return fail('invalid_birthdate', 'identity.birthdate')
  end

  local year = tonumber(yearText)
  local month = tonumber(monthText)
  local day = tonumber(dayText)
  local daysByMonth = { 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 }

  if not year or not month or not day or year < 1900 or year > 2100 or month < 1 or month > 12 then
    return fail('invalid_birthdate', 'identity.birthdate')
  end

  local maxDay = daysByMonth[month]
  if month == 2 and isLeapYear(year) then
    maxDay = 29
  end

  if day < 1 or day > maxDay then
    return fail('invalid_birthdate', 'identity.birthdate')
  end

  return text
end

function MZCreatorService.normalizeIdentity(payload)
  if type(payload) ~= 'table' then
    return fail('invalid_identity', 'identity')
  end

  local ok, err = rejectUnknownKeys(payload, {
    firstname = true,
    lastname = true,
    birthdate = true,
    gender = true,
    nationality = true,
    phone = true
  }, 'identity')
  if not ok then
    return fail('unknown_field', err)
  end

  local firstname, firstnameErr = validateLettersAndSingleSpaces(payload.firstname, 2, 24, 'identity.firstname')
  if not firstname then return nil, firstnameErr end

  local lastname, lastnameErr = validateLettersAndSingleSpaces(payload.lastname, 2, 24, 'identity.lastname')
  if not lastname then return nil, lastnameErr end

  local birthdate, birthdateErr = validateBirthdate(payload.birthdate)
  if not birthdate then return nil, birthdateErr end

  local gender = tostring(payload.gender or '')
  if gender ~= 'male' and gender ~= 'female' then
    return fail('invalid_gender', 'identity.gender')
  end

  local nationality, nationalityErr = validateLettersAndSingleSpaces(payload.nationality, 2, 32, 'identity.nationality')
  if not nationality then return nil, nationalityErr end

  local phone = trim(payload.phone or '')
  if phone ~= '' then
    local phoneLength = utf8Length(phone)
    if not phoneLength or phoneLength > 32 or phone:find('[^%d%+%-%s%(%)]') then
      return fail('invalid_phone', 'identity.phone')
    end
  end

  return {
    firstname = firstname,
    lastname = lastname,
    birthdate = birthdate,
    gender = gender,
    nationality = nationality,
    phone = phone
  }
end

function MZCreatorService.normalizeAppearance(payload)
  local maxPayloadBytes = tonumber(getCreatorConfig().maxPayloadBytes) or 65536
  if getPayloadSize(payload) > maxPayloadBytes then
    return fail('payload_too_large', 'appearance')
  end

  local safeOk, safeErr = inspectTable(payload, 1, 'appearance')
  if not safeOk then
    return fail('unsafe_payload', safeErr)
  end

  local wrapperPayload = type(payload) == 'table' and (payload.appearance_json ~= nil or payload.appearance ~= nil)
  local rawAppearance = payload
  local wrapperModel = nil

  if wrapperPayload then
    local wrapperOk, wrapperErr = rejectUnknownKeys(payload, {
      model = true,
      appearance_json = true,
      appearance = true
    }, 'payload')
    if not wrapperOk then
      return fail('unknown_field', wrapperErr)
    end

    wrapperModel = payload.model
    rawAppearance = payload.appearance_json or payload.appearance
  end

  rawAppearance = decodeJson(rawAppearance, nil)
  if type(rawAppearance) ~= 'table' then
    return fail('invalid_appearance', 'appearance_json')
  end

  local rawSafeOk, rawSafeErr = inspectTable(rawAppearance, 1, 'appearance_json')
  if not rawSafeOk then
    return fail('unsafe_payload', rawSafeErr)
  end

  local allowedTopLevel = {
    version = true,
    model = true,
    headBlend = true,
    faceFeatures = true,
    headOverlays = true,
    hair = true,
    eyeColor = true,
    components = true,
    props = true,
    tattoos = true
  }

  local topOk, topErr = rejectUnknownKeys(rawAppearance, allowedTopLevel, 'appearance_json')
  if not topOk then
    return fail('unknown_field', topErr)
  end

  local version = tonumber(rawAppearance.version)
  if version ~= MZCreatorSchema.version then
    return fail('invalid_version', 'appearance_json.version')
  end

  local model = tostring(wrapperModel or rawAppearance.model or '')
  if not isAllowedModel(model) then
    return fail('invalid_model', model)
  end

  if rawAppearance.model ~= nil and tostring(rawAppearance.model) ~= model then
    return fail('model_mismatch', 'appearance_json.model')
  end

  local defaults = MZCreatorDefaults.get(model)
  local normalized = {
    version = MZCreatorSchema.version,
    model = model
  }

  local headBlend, headBlendErr = normalizeNumberGroup(
    rawAppearance.headBlend,
    defaults.headBlend,
    MZCreatorSchema.headBlend,
    'headBlend'
  )
  if not headBlend then return nil, headBlendErr end
  normalized.headBlend = headBlend

  local faceFeatures, faceFeaturesErr = normalizeNumberGroup(
    rawAppearance.faceFeatures,
    defaults.faceFeatures,
    MZCreatorSchema.faceFeatures,
    'faceFeatures'
  )
  if not faceFeatures then return nil, faceFeaturesErr end
  normalized.faceFeatures = faceFeatures

  local overlays, overlaysErr = normalizeHeadOverlays(rawAppearance.headOverlays, defaults.headOverlays)
  if not overlays then return nil, overlaysErr end
  normalized.headOverlays = overlays

  local hair, hairErr = normalizeNumberGroup(rawAppearance.hair, defaults.hair, MZCreatorSchema.hair, 'hair')
  if not hair then return nil, hairErr end
  normalized.hair = hair

  local eyeColor, eyeErr = normalizeNumber(rawAppearance.eyeColor or defaults.eyeColor, MZCreatorSchema.eyeColor, 'eyeColor')
  if not eyeColor then return nil, eyeErr end
  normalized.eyeColor = eyeColor

  local components, componentsErr = normalizeDrawableMap(
    rawAppearance.components,
    defaults.components,
    MZCreatorSchema.componentIds,
    MZCreatorSchema.componentValue,
    'components'
  )
  if not components then return nil, componentsErr end
  normalized.components = components

  local props, propsErr = normalizeDrawableMap(
    rawAppearance.props,
    defaults.props,
    MZCreatorSchema.propIds,
    MZCreatorSchema.propValue,
    'props'
  )
  if not props then return nil, propsErr end
  normalized.props = props

  local tattoos, tattoosErr = normalizeTattoos(rawAppearance.tattoos)
  if not tattoos then return nil, tattoosErr end
  normalized.tattoos = tattoos

  local normalizedSize = getPayloadSize(normalized)
  if normalizedSize > maxPayloadBytes then
    return fail('payload_too_large', 'appearance_json')
  end

  return normalized
end

function MZCreatorService.getAppearance(citizenid)
  citizenid = tostring(citizenid or '')
  if citizenid == '' then return nil end

  local row = MZCreatorRepository.getByCitizenId(citizenid)
  if not row then return nil end

  local appearance = decodeJson(row.appearance_json, nil)
  if type(appearance) ~= 'table' then
    return nil
  end

  return {
    citizenid = row.citizenid,
    model = row.model,
    appearance_json = appearance,
    created_at = row.created_at,
    updated_at = row.updated_at
  }
end

local function getSavedOrMetadataAppearance(source, player, modelFallback)
  local saved = player and MZCreatorService.getAppearance(player.citizenid) or nil
  if saved and type(saved.appearance_json) == 'table' then
    return cloneTable(saved.appearance_json)
  end

  local metadataAppearance = getCoreMetadataAppearance(source)
  if type(metadataAppearance) == 'table' then
    return cloneTable(metadataAppearance)
  end

  return MZCreatorDefaults.get(modelFallback or 'mp_m_freemode_01')
end

local function persistCurrentAppearance(source, player, appearance, markCharacterCreated)
  local normalized, validationErr = MZCreatorService.normalizeAppearance(appearance)
  if not normalized then
    return nil, validationErr
  end

  MZCreatorRepository.upsert(player.citizenid, normalized.model, normalized)
  syncCoreAppearanceMetadata(source, normalized, markCharacterCreated == true)

  return normalized
end

local function mergeClothingIntoAppearance(baseAppearance, clothingAppearance)
  local clothingModel = tostring(type(clothingAppearance) == 'table' and clothingAppearance.model or '')
  local baseModel = tostring(type(baseAppearance) == 'table' and baseAppearance.model or '')
  local model = baseModel ~= '' and baseModel or clothingModel

  if clothingModel ~= '' and clothingModel ~= model and MZCreatorSchema.allowedModels[clothingModel] == true then
    model = clothingModel
    baseAppearance = MZCreatorDefaults.get(model)
  else
    baseAppearance = cloneTable(baseAppearance or MZCreatorDefaults.get(model))
  end

  baseAppearance.model = model
  baseAppearance.version = MZCreatorSchema.version
  baseAppearance.components = type(baseAppearance.components) == 'table' and baseAppearance.components or {}
  baseAppearance.props = type(baseAppearance.props) == 'table' and baseAppearance.props or {}

  if type(clothingAppearance.components) == 'table' then
    for id, item in pairs(clothingAppearance.components) do
      if type(item) == 'table' then
        baseAppearance.components[tostring(id)] = {
          drawable = item.drawable,
          texture = item.texture
        }
      end
    end
  end

  if type(clothingAppearance.props) == 'table' then
    for id, item in pairs(clothingAppearance.props) do
      if type(item) == 'table' then
        baseAppearance.props[tostring(id)] = {
          drawable = item.drawable,
          texture = item.texture
        }
      end
    end
  end

  return baseAppearance
end

function MZCreatorService.hasCreatedCharacter(source)
  local player = getPlayer(source)
  if not player or not player.citizenid then
    return false
  end

  local metadataOk, metadataValue = pcall(function()
    return exports['mz_core']:GetMetadataValue(source, 'character_created')
  end)

  if metadataOk and metadataValue == true then
    return true
  end

  if MZCreatorService.getAppearance(player.citizenid) ~= nil then
    return true
  end

  return getCoreMetadataAppearance(source) ~= nil
end

function MZCreatorService.getState(source)
  local player = getPlayer(source)
  if not player or not player.citizenid then
    return {
      ok = false,
      error = 'player_not_loaded'
    }
  end

  local appearance = MZCreatorService.getAppearance(player.citizenid)
  local metadataAppearance = nil
  if not appearance then
    metadataAppearance = getCoreMetadataAppearance(source)
  end
  local characterCreated = false
  local metadataOk, metadataValue = pcall(function()
    return exports['mz_core']:GetMetadataValue(source, 'character_created')
  end)

  if metadataOk then
    characterCreated = metadataValue == true
  end

  if characterCreated ~= true and type(metadataAppearance) == 'table' then
    characterCreated = true
  end

  local resolvedAppearance = appearance and appearance.appearance_json or metadataAppearance
  local resolvedModel = appearance and appearance.model or (type(metadataAppearance) == 'table' and metadataAppearance.model or nil)

  return {
    ok = true,
    player = {
      citizenid = player.citizenid,
      license = player.license,
      charinfo = player.charinfo or {}
    },
    characterCreated = characterCreated,
    hasAppearance = type(resolvedAppearance) == 'table',
    appearance = resolvedAppearance,
    model = resolvedModel
  }
end

function MZCreatorService.saveAppearance(source, payload)
  local player = getPlayer(source)
  if not player or not player.citizenid then
    return {
      ok = false,
      error = 'player_not_loaded'
    }
  end

  local appearance, validationErr = persistCurrentAppearance(source, player, payload, false)
  if not appearance then
    return validationErr or {
      ok = false,
      error = 'invalid_appearance'
    }
  end

  return {
    ok = true,
    citizenid = player.citizenid,
    model = appearance.model,
    appearance = appearance
  }
end

function MZCreatorService.saveCharacter(source, payload)
  local maxPayloadBytes = tonumber(getCreatorConfig().maxPayloadBytes) or 65536
  if getPayloadSize(payload) > maxPayloadBytes then
    return {
      ok = false,
      error = 'payload_too_large',
      detail = 'saveCharacter'
    }
  end

  if type(payload) ~= 'table' then
    return {
      ok = false,
      error = 'invalid_payload'
    }
  end

  local safeOk, safeErr = inspectTable(payload, 1, 'saveCharacter')
  if not safeOk then
    return {
      ok = false,
      error = 'unsafe_payload',
      detail = safeErr
    }
  end

  local ok, err = rejectUnknownKeys(payload, {
    identity = true,
    appearance = true,
    spawn = true
  }, 'saveCharacter')
  if not ok then
    return {
      ok = false,
      error = 'unknown_field',
      detail = err
    }
  end

  if payload.spawn ~= nil then
    local spawnOk, spawnErr = rejectUnknownKeys(payload.spawn, {
      spawnId = true
    }, 'spawn')
    if not spawnOk then
      return {
        ok = false,
        error = 'unknown_field',
        detail = spawnErr
      }
    end
  end

  local identity, identityErr = MZCreatorService.normalizeIdentity(payload.identity)
  if not identity then
    return identityErr or {
      ok = false,
      error = 'invalid_identity'
    }
  end

  local appearance, appearanceErr = MZCreatorService.normalizeAppearance(payload.appearance)
  if not appearance then
    return appearanceErr or {
      ok = false,
      error = 'invalid_appearance'
    }
  end

  local player = getPlayer(source)
  if not player or not player.citizenid then
    return {
      ok = false,
      error = 'player_not_loaded'
    }
  end

  local charinfo = {
    firstname = identity.firstname,
    lastname = identity.lastname,
    birthdate = identity.birthdate,
    gender = identity.gender,
    nationality = identity.nationality,
    phone = identity.phone or ''
  }

  local charinfoOk, charinfoResult, charinfoErr = pcall(function()
    return exports['mz_core']:SetCharinfo(source, charinfo)
  end)

  if not charinfoOk or charinfoResult ~= true then
    return {
      ok = false,
      error = 'charinfo_save_failed',
      detail = charinfoErr
    }
  end

  local persistedAppearance, persistErr = persistCurrentAppearance(source, player, appearance, true)
  if not persistedAppearance then
    return {
      ok = false,
      error = 'appearance_save_failed',
      detail = persistErr and (persistErr.detail or persistErr.error) or nil
    }
  end

  appearance = persistedAppearance

  return {
    ok = true,
    citizenid = player.citizenid,
    identity = charinfo,
    model = appearance.model,
    appearance = appearance
  }
end

function MZCreatorService.applyAppearance(source)
  local player = getPlayer(source)
  if not player or not player.citizenid then
    return false, 'player_not_loaded'
  end

  local savedAppearance = MZCreatorService.getAppearance(player.citizenid)
  local appearance = savedAppearance and savedAppearance.appearance_json or getCoreMetadataAppearance(source)
  if type(appearance) ~= 'table' then
    return false, 'appearance_not_found'
  end

  TriggerClientEvent('mz_creator:client:applyAppearance', source, appearance)
  return true
end

function MZCreatorService.mergeClothingAppearance(source, clothingAppearance)
  local player = getPlayer(source)
  if not player or not player.citizenid then
    return {
      ok = false,
      error = 'player_not_loaded'
    }
  end

  if type(clothingAppearance) ~= 'table' then
    return {
      ok = false,
      error = 'invalid_clothing_appearance'
    }
  end

  local model = tostring(clothingAppearance.model or '')
  if MZCreatorSchema.allowedModels[model] ~= true then
    model = 'mp_m_freemode_01'
  end

  local baseAppearance = getSavedOrMetadataAppearance(source, player, model)
  local mergedAppearance = mergeClothingIntoAppearance(baseAppearance, clothingAppearance)
  local persistedAppearance, persistErr = persistCurrentAppearance(source, player, mergedAppearance, true)

  if not persistedAppearance then
    return {
      ok = false,
      error = 'appearance_save_failed',
      detail = persistErr and (persistErr.detail or persistErr.error) or nil
    }
  end

  return {
    ok = true,
    citizenid = player.citizenid,
    appearance = persistedAppearance
  }
end
