Config = {}

-- Display name shown in the tablet UI
Config.AppName = 'Lumina'
Config.AppTagline = 'Live Booth OS'

--[[
    Framework
    'auto'   detect qbx_core, qb-core, or es_extended
    'qbx'    Qbox
    'qb'     QBCore
    'esx'    ESX
    'standalone'
]]
Config.Framework = 'auto'

-- ACE permission used by /djadmin and booth management
Config.AdminAce = 'djbooth.admin'

-- Extra identifiers (license:, discord:, fivem:) that always have admin
Config.AdminIdentifiers = {
    -- 'license:xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
}

-- QBCore / Qbox permission names treated as admin
Config.QBAdminPermissions = { 'god', 'admin' }

-- ESX groups treated as admin
Config.ESXAdminGroups = { 'admin', 'superadmin', 'god' }

-- Command to place / edit / delete booths
Config.AdminCommand = 'djadmin'

-- Optional alias that opens the nearest booth you can use
Config.OpenCommand = 'dj'

--[[
    Interaction
    Preferred: darktrovx/interact (E prompt)
    Fallbacks: ox_target, qb-target, then native 3D text + E
]]
Config.Interact = {
    resource = 'interact',
    label = 'Open DJ Booth',
    icon = 'fa-solid fa-headphones', -- ox_target / qb-target
    distance = 8.0,                  -- when the prompt becomes visible
    interactDst = 2.0,               -- when E can be pressed
    nativeDistance = 2.0,
}

-- Playback
Config.MaxVolume = 1.0
Config.DefaultVolume = 0.55
Config.MinRadius = 8.0
Config.MaxRadius = 120.0
Config.DefaultRadius = 40.0
Config.MaxQueue = 40
Config.MaxSavedSongs = 80
Config.MaxPlaylists = 24
Config.MaxPlaylistTracks = 40
Config.MaxBooths = 30
Config.MaxSpeakers = 4
Config.MaxUrlLength = 400
Config.PlayCooldownMs = 750

-- Empty job list = public booth anyone can use
Config.AllowPublicBooths = true

-- Destroy 3D audio when nobody is nearby for this many ms (saves NUI players)
Config.IdleDestroyMs = 0 -- 0 keeps audio loaded for seamless walk-up

-- Show floating now-playing text above the booth
Config.ShowNowPlayingText = true
Config.NowPlayingTextDistance = 18.0

-- Optional YouTube Data API v3 key — enables playlist URL expansion
-- https://console.cloud.google.com/apis/credentials
Config.YouTubeApiKey = ''
Config.YouTubePlaylistLimit = 40

Config.Models = {
    { model = 'sf_prop_sf_dj_desk_02a', label = 'Club DJ Desk' },
    { model = 'sf_prop_sf_dj_desk_01a', label = 'Low DJ Desk' },
    { model = 'ba_prop_battle_dj_stand', label = 'After Hours Stand' },
    { model = 'ba_prop_battle_dj_kit_speaker', label = 'Battle Speaker' },
    { model = 'prop_speaker_07', label = 'Tall Speaker' },
    { model = 'prop_speaker_03', label = 'Box Speaker' },
    { model = 'prop_boombox_01', label = 'Boombox' },
    { model = 'prop_portable_hifi_01', label = 'Portable Hi-Fi' },
    { model = 'prop_tapeplayer_01', label = 'Tape Player' },
}

Config.DefaultModel = 'prop_speaker_07'
Config.SpeakerModel = 'prop_speaker_03'

-- Placement controls (control indexes: https://docs.fivem.net/docs/game-references/controls/)
Config.Placement = {
    confirm = 38,      -- E
    cancel = 73,       -- X
    rotateSlow = 14,   -- mouse wheel down
    rotateFast = 15,   -- mouse wheel up
    raise = 172,       -- arrow up
    lower = 173,       -- arrow down
    rotateStep = 5.0,
    heightStep = 0.02,
}

Config.Notify = {
    prefix = 'Lumina',
}

Config.Locale = {
    no_permission = 'You do not have permission to do that.',
    no_xsound = 'xsound is not running. Start it before Lumina DJ.',
    booth_open_denied = 'You cannot use this booth.',
    booth_missing = 'That booth no longer exists.',
    invalid_url = 'Paste a YouTube link or a direct HTTPS audio URL.',
    queue_full = 'The queue is full.',
    saved = 'Saved to your library.',
    playlist_created = 'Playlist created.',
    playlist_full = 'This playlist is full.',
    booth_placed = 'DJ booth placed.',
    booth_deleted = 'DJ booth removed.',
    speaker_placed = 'Speaker added to the booth.',
    placement_help = 'E confirm  ·  X cancel  ·  scroll rotate  ·  arrows height',
    too_many_booths = 'Booth limit reached.',
    too_many_speakers = 'Speaker limit reached for this booth.',
    nothing_playing = 'Nothing is playing.',
    streamer_mode = 'Streamer mode is on — booth audio is muted for you.',
    nearest_none = 'No DJ booth nearby.',
}
