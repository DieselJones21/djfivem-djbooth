fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'djbooth'
author 'Lumina'
description 'Premium DJ booth system with YouTube playback, playlists, and in-game placement'
version '1.0.0'

shared_scripts {
    'config.lua',
    'shared/utils.lua',
}

client_scripts {
    'client/framework.lua',
    'client/audio.lua',
    'client/interact.lua',
    'client/placement.lua',
    'client/nui.lua',
    'client/main.lua',
}

server_scripts {
    'server/permissions.lua',
    'server/storage.lua',
    'server/main.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/css/style.css',
    'html/js/app.js',
}

dependencies {
    'xsound',
}

provide 'djbooth'
