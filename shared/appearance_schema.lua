MZCreatorSchema = MZCreatorSchema or {}

MZCreatorSchema.version = 1

MZCreatorSchema.allowedModels = {
  mp_m_freemode_01 = true,
  mp_f_freemode_01 = true
}

MZCreatorSchema.headBlend = {
  shapeFirst = { min = 0, max = 45, integer = true },
  shapeSecond = { min = 0, max = 45, integer = true },
  shapeThird = { min = 0, max = 45, integer = true },
  skinFirst = { min = 0, max = 45, integer = true },
  skinSecond = { min = 0, max = 45, integer = true },
  skinThird = { min = 0, max = 45, integer = true },
  shapeMix = { min = 0.0, max = 1.0 },
  skinMix = { min = 0.0, max = 1.0 },
  thirdMix = { min = 0.0, max = 1.0 }
}

MZCreatorSchema.faceFeatureOrder = {
  { key = 'noseWidth', index = 0 },
  { key = 'nosePeakHeight', index = 1 },
  { key = 'nosePeakLength', index = 2 },
  { key = 'noseBoneHeight', index = 3 },
  { key = 'nosePeakLowering', index = 4 },
  { key = 'noseBoneTwist', index = 5 },
  { key = 'eyebrowHeight', index = 6 },
  { key = 'eyebrowDepth', index = 7 },
  { key = 'cheekboneHeight', index = 8 },
  { key = 'cheekboneWidth', index = 9 },
  { key = 'cheeksWidth', index = 10 },
  { key = 'eyesOpening', index = 11 },
  { key = 'lipsThickness', index = 12 },
  { key = 'jawBoneWidth', index = 13 },
  { key = 'jawBoneLength', index = 14 },
  { key = 'chinBoneHeight', index = 15 },
  { key = 'chinBoneLength', index = 16 },
  { key = 'chinBoneWidth', index = 17 },
  { key = 'chinHole', index = 18 },
  { key = 'neckThickness', index = 19 }
}

MZCreatorSchema.faceFeatures = {}
for _, feature in ipairs(MZCreatorSchema.faceFeatureOrder) do
  MZCreatorSchema.faceFeatures[feature.key] = { min = -1.0, max = 1.0 }
end

MZCreatorSchema.headOverlayOrder = {
  { key = 'blemishes', index = 0 },
  { key = 'facialHair', index = 1, colorType = 1 },
  { key = 'eyebrows', index = 2, colorType = 1 },
  { key = 'ageing', index = 3 },
  { key = 'makeup', index = 4, colorType = 1 },
  { key = 'blush', index = 5, colorType = 2 },
  { key = 'complexion', index = 6 },
  { key = 'sunDamage', index = 7 },
  { key = 'lipstick', index = 8, colorType = 2 },
  { key = 'molesFreckles', index = 9 },
  { key = 'chestHair', index = 10, colorType = 1 },
  { key = 'bodyBlemishes', index = 11 },
  { key = 'addBodyBlemishes', index = 12 }
}

MZCreatorSchema.headOverlays = {}
for _, overlay in ipairs(MZCreatorSchema.headOverlayOrder) do
  MZCreatorSchema.headOverlays[overlay.key] = {
    style = { min = 0, max = 255, integer = true },
    opacity = { min = 0.0, max = 1.0 },
    color = { min = 0, max = 63, integer = true, optional = true },
    secondaryColor = { min = 0, max = 63, integer = true, optional = true },
    colorType = overlay.colorType
  }
end

MZCreatorSchema.hair = {
  style = { min = 0, max = 255, integer = true },
  texture = { min = 0, max = 20, integer = true },
  color = { min = 0, max = 63, integer = true },
  highlight = { min = 0, max = 63, integer = true }
}

MZCreatorSchema.eyeColor = { min = 0, max = 31, integer = true }

MZCreatorSchema.componentIds = {
  ['1'] = true,
  ['3'] = true,
  ['4'] = true,
  ['5'] = true,
  ['6'] = true,
  ['7'] = true,
  ['8'] = true,
  ['9'] = true,
  ['10'] = true,
  ['11'] = true
}

MZCreatorSchema.propIds = {
  ['0'] = true,
  ['1'] = true,
  ['2'] = true,
  ['6'] = true,
  ['7'] = true
}

MZCreatorSchema.componentValue = {
  drawable = { min = 0, max = 1000, integer = true },
  texture = { min = 0, max = 100, integer = true }
}

MZCreatorSchema.propValue = {
  drawable = { min = -1, max = 1000, integer = true },
  texture = { min = 0, max = 100, integer = true }
}

function MZCreatorSchema.clone(value)
  if type(value) ~= 'table' then
    return value
  end

  local out = {}
  for k, v in pairs(value) do
    out[k] = MZCreatorSchema.clone(v)
  end
  return out
end
