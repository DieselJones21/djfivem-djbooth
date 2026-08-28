fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'djbooth'
author 'Lumina'
description 'Premium DJ booth system with YouTube playback, playlists, and in-game placement'
version '1.1.0'

shared_scripts {
    'config.lua',
    'shared/utils.lua',
}

client_scripts {
    'client/framework.lua',
    'client/props.lua',
    'client/audio.lua',
    'client/interact.lua',
    'client/placement.lua',
    'client/nui.lua',
    'client/speakers.lua',
    'client/main.lua',
}

server_scripts {
    'server/permissions.lua',
    'server/storage.lua',
    'server/inventory.lua',
    'server/main.lua',
    'server/speakers.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/css/style.css',
    'html/js/app.js',
    'html/images/items/*.png',
}

dependencies {
    'xsound',
}

provide 'djbooth'
