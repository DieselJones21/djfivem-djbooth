-- Lumina DJ portable speakers
-- Paste these into ox_inventory/data/items.lua
-- Then copy png files from install/ox_inventory/web/images/ into ox_inventory/web/images/

['lumina_speaker_handheld'] = {
    label = 'Handheld Speaker',
    weight = 1500,
    stack = false,
    close = true,
    consume = 0,
    description = 'A portable boombox. Use it to place a speaker you can pick back up.',
    client = {
        image = 'lumina_speaker_handheld.png',
        export = 'djbooth.useHandheld',
    },
},

['lumina_speaker_big'] = {
    label = 'Big Speaker',
    weight = 8000,
    stack = false,
    close = true,
    consume = 0,
    description = 'A tall PA cabinet with serious throw. Place it, then E for the speaker menu.',
    client = {
        image = 'lumina_speaker_big.png',
        export = 'djbooth.useBigSpeaker',
    },
},

['lumina_speaker_tripod'] = {
    label = 'Tripod Speaker',
    weight = 4500,
    stack = false,
    close = true,
    consume = 0,
    description = 'A stand-mounted PA. Group it with nearby speakers for a synced stack.',
    client = {
        image = 'lumina_speaker_tripod.png',
        export = 'djbooth.useTripodSpeaker',
    },
},
