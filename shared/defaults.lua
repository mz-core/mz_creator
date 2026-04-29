MZCreatorDefaults = MZCreatorDefaults or {}

local function baseAppearance(model)
  local isFemale = model == 'mp_f_freemode_01'

  return {
    version = MZCreatorSchema.version,
    model = model,
    headBlend = {
      shapeFirst = isFemale and 21 or 0,
      shapeSecond = isFemale and 0 or 21,
      shapeThird = 0,
      skinFirst = isFemale and 21 or 0,
      skinSecond = isFemale and 0 or 21,
      skinThird = 0,
      shapeMix = 0.5,
      skinMix = 0.5,
      thirdMix = 0.0
    },
    faceFeatures = {
      noseWidth = 0.0,
      nosePeakHeight = 0.0,
      nosePeakLength = 0.0,
      noseBoneHeight = 0.0,
      nosePeakLowering = 0.0,
      noseBoneTwist = 0.0,
      eyebrowHeight = 0.0,
      eyebrowDepth = 0.0,
      cheekboneHeight = 0.0,
      cheekboneWidth = 0.0,
      cheeksWidth = 0.0,
      eyesOpening = 0.0,
      lipsThickness = 0.0,
      jawBoneWidth = 0.0,
      jawBoneLength = 0.0,
      chinBoneHeight = 0.0,
      chinBoneLength = 0.0,
      chinBoneWidth = 0.0,
      chinHole = 0.0,
      neckThickness = 0.0
    },
    headOverlays = {
      blemishes = { style = 0, opacity = 0.0 },
      facialHair = { style = 0, opacity = 0.0, color = 0, secondaryColor = 0 },
      eyebrows = { style = 0, opacity = 1.0, color = 0, secondaryColor = 0 },
      ageing = { style = 0, opacity = 0.0 },
      makeup = { style = 0, opacity = 0.0, color = 0, secondaryColor = 0 },
      blush = { style = 0, opacity = 0.0, color = 0 },
      complexion = { style = 0, opacity = 0.0 },
      sunDamage = { style = 0, opacity = 0.0 },
      lipstick = { style = 0, opacity = 0.0, color = 0 },
      molesFreckles = { style = 0, opacity = 0.0 },
      chestHair = { style = 0, opacity = 0.0, color = 0 },
      bodyBlemishes = { style = 0, opacity = 0.0 },
      addBodyBlemishes = { style = 0, opacity = 0.0 }
    },
    hair = {
      style = 0,
      texture = 0,
      color = 0,
      highlight = 0
    },
    eyeColor = 0,
    components = {
      ['3'] = { drawable = 15, texture = 0 },
      ['4'] = { drawable = isFemale and 15 or 21, texture = 0 },
      ['6'] = { drawable = isFemale and 35 or 34, texture = 0 },
      ['8'] = { drawable = 15, texture = 0 },
      ['11'] = { drawable = 15, texture = 0 }
    },
    props = {
      ['0'] = { drawable = -1, texture = 0 },
      ['1'] = { drawable = -1, texture = 0 },
      ['2'] = { drawable = -1, texture = 0 },
      ['6'] = { drawable = -1, texture = 0 },
      ['7'] = { drawable = -1, texture = 0 }
    },
    tattoos = {}
  }
end

MZCreatorDefaults.byModel = {
  mp_m_freemode_01 = baseAppearance('mp_m_freemode_01'),
  mp_f_freemode_01 = baseAppearance('mp_f_freemode_01')
}

function MZCreatorDefaults.get(model)
  local resolved = MZCreatorDefaults.byModel[model] and model or 'mp_m_freemode_01'
  return MZCreatorSchema.clone(MZCreatorDefaults.byModel[resolved])
end
