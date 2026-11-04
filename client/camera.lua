MZCreatorCamera = {
  active = false,
  cam = nil,
  mode = nil,
  orbitalRotation = 0.0
}

local function nativeBool(value)
  return value == true or value == 1
end

local function getModeConfig(mode)
  local creatorConfig = Config.Creator or {}
  local modes = creatorConfig.cameraModes or {}
  return modes[mode] or modes[creatorConfig.defaultCameraMode or 'face'] or {
    offset = vec3(0.0, 2.5, 0.2),
    point = vec3(0.0, 0.0, 0.2),
    fov = 45.0
  }
end

local function lockCurrentPed()
  if not MZCreatorCamera.active then
    return
  end

  local ped = PlayerPedId()
  if not ped or ped == 0 then
    return
  end

  FreezeEntityPosition(ped, true)
  SetEntityVisible(ped, true, false)
  SetPlayerInvincible(PlayerId(), true)
  SetEntityInvincible(ped, true)
  SetEntityCollision(ped, true, true)
  SetPedCanRagdoll(ped, false)
end

local function pointCameraAtPed()
  if not MZCreatorCamera.active or not MZCreatorCamera.cam then
    return
  end

  local ped = PlayerPedId()
  if not ped or ped == 0 then
    return
  end

  local creatorConfig = Config.Creator or {}
  local cfg = getModeConfig(MZCreatorCamera.mode)
  local pedCoords = GetEntityCoords(ped)
  local pointCoords = pedCoords + vec3(cfg.point.x, cfg.point.y, cfg.point.z)
  local camCoords

  -- Com a rotação desativada, a câmera deve respeitar exatamente o offset do config.
  -- Antes ela começava em 0 graus no cálculo orbital, por isso ficava de lado.
  if creatorConfig.allowCameraRotation == false then
    camCoords = pedCoords + vec3(cfg.offset.x, cfg.offset.y, cfg.offset.z)
  else
    local angle = math.rad(MZCreatorCamera.orbitalRotation)
    local distance = math.sqrt(cfg.offset.x ^ 2 + cfg.offset.y ^ 2)
    local orbitalX = math.cos(angle) * distance
    local orbitalY = math.sin(angle) * distance
    local orbitalZ = cfg.offset.z
    camCoords = pedCoords + vec3(orbitalX, orbitalY, orbitalZ)
  end

  SetCamCoord(MZCreatorCamera.cam, camCoords.x, camCoords.y, camCoords.z)
  PointCamAtCoord(MZCreatorCamera.cam, pointCoords.x, pointCoords.y, pointCoords.z)
  SetCamFov(MZCreatorCamera.cam, cfg.fov or 45.0)
end

function MZCreatorCamera.open(mode)
  local ped = PlayerPedId()
  local creatorConfig = Config.Creator or {}
  MZCreatorCamera.mode = mode or creatorConfig.defaultCameraMode or 'face'
  MZCreatorCamera.active = true

  -- 90 graus coloca a câmera no eixo Y positivo, que é o mesmo sentido dos offsets
  -- padrão do config: vec3(0.0, 0.82, 0.62).
  MZCreatorCamera.orbitalRotation = tonumber(creatorConfig.cameraStartRotation or 90.0) or 90.0

  lockCurrentPed()

  if MZCreatorCamera.cam and nativeBool(DoesCamExist(MZCreatorCamera.cam)) then
    DestroyCam(MZCreatorCamera.cam, false)
  end

  MZCreatorCamera.cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', false)
  if not MZCreatorCamera.cam or MZCreatorCamera.cam == 0
    or not nativeBool(DoesCamExist(MZCreatorCamera.cam)) then
    MZCreatorCamera.cam = nil
    MZCreatorCamera.active = false
    return false
  end

  pointCameraAtPed()
  SetCamActive(MZCreatorCamera.cam, true)
  RenderScriptCams(true, true, 300, true, true)
  return nativeBool(IsCamActive(MZCreatorCamera.cam))
end

function MZCreatorCamera.close()
  local ped = PlayerPedId()

  if MZCreatorCamera.cam and nativeBool(DoesCamExist(MZCreatorCamera.cam)) then
    SetCamActive(MZCreatorCamera.cam, false)
    RenderScriptCams(false, true, 300, true, true)
    DestroyCam(MZCreatorCamera.cam, false)
  else
    RenderScriptCams(false, true, 300, true, true)
  end

  MZCreatorCamera.cam = nil
  MZCreatorCamera.active = false
  MZCreatorCamera.mode = nil

  FreezeEntityPosition(ped, false)
  SetPlayerInvincible(PlayerId(), false)
  SetEntityInvincible(ped, false)
  SetEntityCollision(ped, true, true)
  SetPedCanRagdoll(ped, true)
end

function MZCreatorCamera.setMode(mode)
  MZCreatorCamera.mode = mode or 'face'
  pointCameraAtPed()
end

function MZCreatorCamera.rotate(amount)
  local creatorConfig = Config.Creator or {}
  -- Verifica se rotação de câmera está habilitada
  if creatorConfig.allowCameraRotation ~= false then
    MZCreatorCamera.orbitalRotation = MZCreatorCamera.orbitalRotation + (tonumber(amount) or 0.0)
    pointCameraAtPed()
  end
end

function MZCreatorCamera.update()
  lockCurrentPed()
  pointCameraAtPed()
end
