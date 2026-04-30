Config = Config or {}

Config.Creator = {
  command = 'creator_test',
  maxPayloadBytes = 65536,
  maxTableDepth = 5,
  maxTattoos = 50,
  allowedModels = {
    mp_m_freemode_01 = true,
    mp_f_freemode_01 = true
  },
  applySavedAppearanceOnSpawn = true,
  applySavedAppearanceDelayMs = 800,
  defaultCameraMode = 'face',
  cameraStartRotation = 90.0,
  cameraModes = {
    face = { offset = vec3(0.0, 0.82, 0.62), point = vec3(0.0, 0.0, 0.60), fov = 38.0 },
    body = { offset = vec3(0.0, 2.55, 0.18), point = vec3(0.0, 0.0, 0.15), fov = 45.0 }
  },
  -- Local onde o criador de personagem será aberto
  spawnLocation = {
    coords = vec3(-797.70, 328.30, 219.44),
    heading = 350.61
  },
  -- Desabilitar rotação da câmera com A/D (câmera parada)
  allowCameraRotation = false
}



Config.AutoOpen = {
  enabled = true,
  delayMs = 1200,
  mode = 'first_login'
}
