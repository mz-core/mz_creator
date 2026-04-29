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
  defaultCameraMode = 'face',
  cameraModes = {
    face = { offset = vec3(0.0, 0.82, 0.62), point = vec3(0.0, 0.0, 0.60), fov = 38.0 },
    body = { offset = vec3(0.0, 2.55, 0.18), point = vec3(0.0, 0.0, 0.15), fov = 45.0 }
  }
}
