MZCreatorCamera = {
  active = false,
  cam = nil,
  mode = nil
}

local function getModeConfig(mode)
  local creatorConfig = Config.Creator or {}
  local modes = creatorConfig.cameraModes or {}
  return modes[mode] or modes[creatorConfig.defaultCameraMode or 'face'] or {
    offset = vec3(0.0, 2.5, 0.2),
    point = vec3(0.0, 0.0, 0.2),
    fov = 45.0
  }
end

local function pointCameraAtPed()
  if not MZCreatorCamera.active or not MZCreatorCamera.cam then
    return
  end

  local ped = PlayerPedId()
  if not ped or ped == 0 then
    return
  end

  local cfg = getModeConfig(MZCreatorCamera.mode)
  local camCoords = GetOffsetFromEntityInWorldCoords(ped, cfg.offset.x, cfg.offset.y, cfg.offset.z)
  local pointCoords = GetOffsetFromEntityInWorldCoords(ped, cfg.point.x, cfg.point.y, cfg.point.z)

  SetCamCoord(MZCreatorCamera.cam, camCoords.x, camCoords.y, camCoords.z)
  PointCamAtCoord(MZCreatorCamera.cam, pointCoords.x, pointCoords.y, pointCoords.z)
  SetCamFov(MZCreatorCamera.cam, cfg.fov or 45.0)
end

function MZCreatorCamera.open(mode)
  local ped = PlayerPedId()
  MZCreatorCamera.mode = mode or (Config.Creator and Config.Creator.defaultCameraMode) or 'face'
  MZCreatorCamera.active = true

  FreezeEntityPosition(ped, true)
  SetPlayerInvincible(PlayerId(), true)
  SetEntityCollision(ped, true, true)

  if MZCreatorCamera.cam and DoesCamExist(MZCreatorCamera.cam) then
    DestroyCam(MZCreatorCamera.cam, false)
  end

  MZCreatorCamera.cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
  SetCamActive(MZCreatorCamera.cam, true)
  RenderScriptCams(true, true, 300, true, true)
  pointCameraAtPed()
end

function MZCreatorCamera.close()
  local ped = PlayerPedId()

  if MZCreatorCamera.cam and DoesCamExist(MZCreatorCamera.cam) then
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
  SetEntityCollision(ped, true, true)
end

function MZCreatorCamera.setMode(mode)
  MZCreatorCamera.mode = mode or 'face'
  pointCameraAtPed()
end

function MZCreatorCamera.rotate(amount)
  local ped = PlayerPedId()
  local nextHeading = GetEntityHeading(ped) + (tonumber(amount) or 0.0)
  SetEntityHeading(ped, nextHeading)
  pointCameraAtPed()
end

function MZCreatorCamera.update()
  pointCameraAtPed()
end
