-- Lumina DJ portable speakers
-- Paste these into ox_inventory/data/items.lua
-- Then copy png files from install/ox_inventory/web/images/ into ox_inventory/web/images/
--
-- client.event is required. Do NOT use client.export = 'djbooth.useHandheld'
-- unless this resource folder is literally named `djbooth`. The event name
-- works no matter what the folder is called. consume MUST stay 0 — the item
-- is removed when you confirm placement, not when you start aiming.

['lumina_speaker_handheld'] = {
    label = 'Handheld Speaker',
    weight = 1500,
    stack = false,
    close = true,
    consume = 0,
    description = 'A portable boombox. Use it to place a speaker you can pick back up.',
    client = {
        image = 'lumina_speaker_handheld.png',
        event = 'djbooth:useSpeakerItem',
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
        event = 'djbooth:useSpeakerItem',
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
        event = 'djbooth:useSpeakerItem',
    },
},
