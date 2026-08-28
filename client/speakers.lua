PortableSpeakers = {
    list = {},
    objects = {},
}

local lastPlaceAt = 0

function PortableSpeakers.Get(id)
    return PortableSpeakers.list[id]
end

function PortableSpeakers.Despawn(id)
    local handle = PortableSpeakers.objects[id]
    if handle and DoesEntityExist(handle) then
        DeleteObject(handle)
    end
    PortableSpeakers.objects[id] = nil
    Interact.Remove(id)
end

function PortableSpeakers.Spawn(speaker)
    PortableSpeakers.Despawn(speaker.id)
    local def = Config.SpeakerItems[speaker.item] or {}
    local hash = Props.LoadFirst(Props.Fallbacks(speaker.model or def.model, def.fallback))
    if not hash then
        print(('[lumina-dj] Could not load speaker model %s'):format(tostring(speaker.model or speaker.item)))
        PortableSpeakers.list[speaker.id] = speaker
        return
    end
    local obj = Props.CreateFrozen(hash, speaker.coords, speaker.heading)
    SetModelAsNoLongerNeeded(hash)
    if not obj then
        PortableSpeakers.list[speaker.id] = speaker
        return
    end
    PortableSpeakers.objects[speaker.id] = obj
    PortableSpeakers.list[speaker.id] = speaker

    Interact.RegisterPoint({
        id = speaker.id,
        coords = DJ.ToVector3(speaker.coords) + vector3(0.0, 0.0, 0.4),
        label = Config.SpeakerInteractLabel,
        icon = Config.SpeakerInteractIcon,
        onUse = function()
            Nui.expectOpenUntil = GetGameTimer() + 4000
            TriggerServerEvent('djbooth:openSpeaker', speaker.id)
        end,
    })
end

function PortableSpeakers.Clear()
    for id in pairs(PortableSpeakers.objects) do
        PortableSpeakers.Despawn(id)
    end
    PortableSpeakers.list = {}
end

local function applyGroupAudio(groupId, members, state)
    local points = {}
    for i = 1, #members do
        local speaker = members[i]
        points[#points + 1] = {
            coords = DJ.ToVector3(speaker.coords),
            volume = speaker.volume or Config.DefaultVolume,
            radius = speaker.radius or Config.DefaultRadius,
        }
        PortableSpeakers.list[speaker.id] = speaker
    end
    Audio.ApplyRig('spk_' .. groupId, points, state, 'djbooth:speakerEnded')
end

function PlacePortableSpeaker(itemName, slot)
    local now = GetGameTimer()
    if now - lastPlaceAt < 1000 then
        return
    end
    local def = Config.SpeakerItems[itemName]
    if not def then
        Framework.Notify('Unknown speaker item.', 'error')
        return
    end
    lastPlaceAt = now
    Placement.Start('portable', def.model, nil, {
        item = itemName,
        slot = DJ.SlotId(slot),
        fallback = def.fallback,
    })
end

local function resolveItemUse(a, b, c)
    if type(a) == 'string' and Config.SpeakerItems[a] then
        return a, DJ.SlotId(b) or DJ.SlotId(c)
    end
    if type(a) == 'table' then
        local name = a.name or a.item or a.itemName
        local slot = a.slot or a.slotId
        if type(b) == 'table' then
            name = name or b.name
            slot = b.slot or b.slotId or slot
        elseif b ~= nil then
            slot = b
        end
        return name, DJ.SlotId(slot)
    end
    return nil, nil
end

local function onUseSpeakerItem(a, b, c)
    local name, slot = resolveItemUse(a, b, c)
    if name then
        PlacePortableSpeaker(name, slot)
    end
end

RegisterNetEvent('djbooth:client:placeSpeaker', function(itemName, slot)
    onUseSpeakerItem(itemName, slot)
end)

RegisterNetEvent('djbooth:useSpeakerItem', onUseSpeakerItem)
AddEventHandler('djbooth:useSpeakerItem', onUseSpeakerItem)
AddEventHandler('ox_inventory:usedItem', function(name, slotId, metadata)
    local itemName = name
    if type(name) == 'table' then
        itemName = name.name or name.item or name.itemName
        slotId = slotId or name.slot or name.slotId
        if type(slotId) == 'table' then
            metadata = slotId
            slotId = name.slot
        end
    end
    if Config.SpeakerItems[itemName] then
        PlacePortableSpeaker(itemName, slotId or metadata)
    end
end)

exports('useSpeaker', function(data, slot)
    onUseSpeakerItem(data, slot)
end)

local function oxExport(itemName)
    return function(data, slot)
        if GetResourceState('ox_inventory') == 'started' and type(data) == 'table' then
            pcall(function()
                exports.ox_inventory:useItem(data, function() end)
            end)
        end
        local name = itemName
        if type(data) == 'table' then
            name = data.name or data.item or data.itemName or itemName
        elseif type(data) == 'string' and Config.SpeakerItems[data] then
            name = data
        end
        PlacePortableSpeaker(name, DJ.SlotId(slot) or DJ.SlotId(data))
    end
end

exports('useHandheld', oxExport('lumina_speaker_handheld'))
exports('useBigSpeaker', oxExport('lumina_speaker_big'))
exports('useTripodSpeaker', oxExport('lumina_speaker_tripod'))

RegisterNetEvent('djbooth:syncSpeakers', function(list)
    local keep = {}
    local byGroup = {}
    for i = 1, #(list or {}) do
        local speaker = list[i]
        keep[speaker.id] = true
        PortableSpeakers.Spawn(speaker)
        local gid = speaker.groupId or speaker.id
        byGroup[gid] = byGroup[gid] or { members = {}, state = speaker.state }
        byGroup[gid].members[#byGroup[gid].members + 1] = speaker
        if speaker.state then
            byGroup[gid].state = speaker.state
        end
    end
    for gid, pack in pairs(byGroup) do
        applyGroupAudio(gid, pack.members, pack.state)
    end
    for id in pairs(PortableSpeakers.objects) do
        if not keep[id] then
            local speaker = PortableSpeakers.list[id]
            PortableSpeakers.Despawn(id)
            if speaker then
                Audio.Stop('spk_' .. (speaker.groupId or id))
            end
        end
    end
end)

RegisterNetEvent('djbooth:upsertSpeaker', function(speaker)
    if not speaker or not speaker.id then
        return
    end
    PortableSpeakers.Spawn(speaker)
    if speaker.state and speaker.state.current then
        applyGroupAudio(speaker.groupId or speaker.id, { speaker }, speaker.state)
    end
end)

RegisterNetEvent('djbooth:removeSpeaker', function(speakerId)
    local speaker = PortableSpeakers.list[speakerId]
    PortableSpeakers.Despawn(speakerId)
    PortableSpeakers.list[speakerId] = nil
    if speaker then
        Audio.Stop('spk_' .. (speaker.groupId or speakerId))
    end
    if Nui.speakerId == speakerId then
        Nui.Close()
    end
end)

RegisterNetEvent('djbooth:speakerAudio', function(groupId, members, state)
    members = members or {}
    for i = 1, #members do
        local speaker = members[i]
        PortableSpeakers.list[speaker.id] = speaker
        if not PortableSpeakers.objects[speaker.id] then
            PortableSpeakers.Spawn(speaker)
        end
    end
    applyGroupAudio(groupId, members, state)
    if Nui.open and Nui.mode == 'speaker' then
        for i = 1, #members do
            if members[i].id == Nui.speakerId then
                Nui.Send('syncSpeaker', {
                    speaker = members[i],
                    state = state,
                })
                break
            end
        end
    end
end)

RegisterNetEvent('djbooth:openSpeakerUi', function(payload)
    Nui.OpenSpeaker(payload)
end)

RegisterNetEvent('djbooth:speakerUi', function(payload)
    if Nui.open and Nui.mode == 'speaker' then
        Nui.Send('syncSpeaker', payload)
    end
end)

RegisterNetEvent('djbooth:closeUi', function()
    Nui.Close()
end)
