fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'mz_creator'
author 'Mazus'
description 'Manual appearance creator for mz_core'
version '0.1.0'

ui_page 'web/index.html'

shared_scripts {
  '@ox_lib/init.lua',
  'config.lua',
  'shared/appearance_schema.lua',
  'shared/defaults.lua'
}

server_scripts {
  '@oxmysql/lib/MySQL.lua',
  'server/prepare.lua',
  'server/repository.lua',
  'server/service.lua',
  'server/events.lua',
  'server/exports.lua'
}

client_scripts {
  'client/appearance.lua',
  'client/camera.lua',
  'client/flow.lua',
  'client/main.lua'
}

files {
  'web/index.html',
  'web/style.css',
  'web/app.js',
  'web/assets/*'
}

dependencies {
  'oxmysql',
  'ox_lib',
  'mz_core'
}
