MZCreatorAppearance = {}

local function numberOr(value, fallback)
  local numeric = tonumber(value)
  if numeric == nil then
    return fallback
  end
  return numeric
end

local function integerOr(value, fallback)
  return math.floor(numberOr(value, fallback))
end

local function isAllowedModel(model)
  local creatorConfig = Config.Creator or {}
  local allowed = creatorConfig.allowedModels or MZCreatorSchema.allowedModels
  return type(model) == 'string' and allowed[model] == true
end

local function loadModel(model)
  if type(model) == 'string' then
    model = joaat(model)
  end

  if not IsModelInCdimage(model) or not IsModelValid(model) then
    return nil
  end

  RequestModel(model)

  local attempts = 0
  while not HasModelLoaded(model) and attempts < 200 do
    Wait(25)
    attempts = attempts + 1
  end

  if not HasModelLoaded(model) then
    return nil
  end

  return model
end

local function ensureModel(modelName)
  if not isAllowedModel(modelName) then
    modelName = 'mp_m_freemode_01'
  end

  local model = loadModel(modelName)
  if not model then
    return PlayerPedId(), false
  end

  local modelChanged = GetEntityModel(PlayerPedId()) ~= model
  if modelChanged then
    SetPlayerModel(PlayerId(), model)
    SetModelAsNoLongerNeeded(model)
    Wait(150)
    SetPedDefaultComponentVariation(PlayerPedId())
    ClearAllPedProps(PlayerPedId())
  end

  return PlayerPedId(), modelChanged
end

local function applyHeadBlend(ped, headBlend)
  headBlend = headBlend or {}

  SetPedHeadBlendData(
    ped,
    integerOr(headBlend.shapeFirst, 0),
    integerOr(headBlend.shapeSecond, 21),
    integerOr(headBlend.shapeThird, 0),
    integerOr(headBlend.skinFirst, 0),
    integerOr(headBlend.skinSecond, 21),
    integerOr(headBlend.skinThird, 0),
    numberOr(headBlend.shapeMix, 0.5) + 0.0,
    numberOr(headBlend.skinMix, 0.5) + 0.0,
    numberOr(headBlend.thirdMix, 0.0) + 0.0,
    false
  )
end

local function applyFaceFeatures(ped, faceFeatures)
  faceFeatures = faceFeatures or {}

  for _, feature in ipairs(MZCreatorSchema.faceFeatureOrder or {}) do
    SetPedFaceFeature(ped, feature.index, numberOr(faceFeatures[feature.key], 0.0) + 0.0)
  end
end

local function applyHeadOverlays(ped, headOverlays)
  headOverlays = headOverlays or {}

  for _, overlayDef in ipairs(MZCreatorSchema.headOverlayOrder or {}) do
    local overlay = headOverlays[overlayDef.key] or {}
    local style = integerOr(overlay.style, 0)
    local opacity = numberOr(overlay.opacity, 0.0) + 0.0

    SetPedHeadOverlay(ped, overlayDef.index, style, opacity)

    if overlayDef.colorType then
      local color = integerOr(overlay.color, 0)
      local secondaryColor = integerOr(overlay.secondaryColor, color)
      SetPedHeadOverlayColor(ped, overlayDef.index, overlayDef.colorType, color, secondaryColor)
    end
  end
end

local function applyHair(ped, hair)
  hair = hair or {}

  SetPedComponentVariation(
    ped,
    2,
    integerOr(hair.style, 0),
    integerOr(hair.texture, 0),
    2
  )

  SetPedHairColor(ped, integerOr(hair.color, 0), integerOr(hair.highlight, 0))
end

local function applyComponents(ped, components)
  components = components or {}

  for id, _ in pairs(MZCreatorSchema.componentIds or {}) do
    local component = components[id]
    if component then
      SetPedComponentVariation(
        ped,
        tonumber(id),
        integerOr(component.drawable, 0),
        integerOr(component.texture, 0),
        2
      )
    end
  end
end

local function applyProps(ped, props)
  props = props or {}

  for id, _ in pairs(MZCreatorSchema.propIds or {}) do
    local prop = props[id]
    local propId = tonumber(id)
    if prop and propId then
      local drawable = integerOr(prop.drawable, -1)
      if drawable < 0 then
        ClearPedProp(ped, propId)
      else
        SetPedPropIndex(ped, propId, drawable, integerOr(prop.texture, 0), true)
      end
    end
  end
end

function MZCreatorAppearance.defaultForModel(model)
  return MZCreatorDefaults.get(model)
end

function MZCreatorAppearance.apply(appearance)
  if type(appearance) ~= 'table' then
    return false, 'invalid_appearance'
  end

  if type(appearance.appearance_json) == 'table' then
    appearance = appearance.appearance_json
  end

  local model = appearance.model
  if not isAllowedModel(model) then
    return false, 'invalid_model'
  end

  local ped, modelChanged = ensureModel(model)
  if not ped or ped == 0 then
    return false, 'invalid_ped'
  end

  applyHeadBlend(ped, appearance.headBlend)
  applyFaceFeatures(ped, appearance.faceFeatures)
  applyHeadOverlays(ped, appearance.headOverlays)
  applyHair(ped, appearance.hair)
  SetPedEyeColor(ped, integerOr(appearance.eyeColor, 0))
  applyComponents(ped, appearance.components)
  applyProps(ped, appearance.props)

  if modelChanged then
    TriggerEvent('mz_core:client:pedModelReady', { reason = 'creator_model_applied' })
  end
  TriggerEvent('mz_creator:client:appearanceApplied')

  return true
end
