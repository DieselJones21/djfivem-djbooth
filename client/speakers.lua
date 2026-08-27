PortableSpeakers = {
    list = {},
    objects = {},
}

local function loadModel(model, fallback)
    local function try(name)
        if not name then
            return nil
        end
        local hash = type(name) == 'number' and name or joaat(name)
        if not IsModelInCdimage(hash) then
            return nil
        end
        RequestModel(hash)
        local timeout = GetGameTimer() + 4000
        while not HasModelLoaded(hash) and GetGameTimer() < timeout do
            Wait(10)
        end
        return HasModelLoaded(hash) and hash or nil
    end
    return try(model) or try(fallback)
end

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
    local hash = loadModel(speaker.model or def.model, def.fallback)
    if not hash then
        return
    end
    local coords = DJ.ToVector3(speaker.coords)
    local obj = CreateObject(hash, coords.x, coords.y, coords.z, false, false, false)
    SetEntityHeading(obj, (speaker.heading or 0) + 0.0)
    FreezeEntityPosition(obj, true)
    SetEntityCollision(obj, true, true)
    SetEntityAsMissionEntity(obj, true, true)
    SetModelAsNoLongerNeeded(hash)
    PortableSpeakers.objects[speaker.id] = obj
    PortableSpeakers.list[speaker.id] = speaker

    Interact.RegisterPoint({
        id = speaker.id,
        coords = coords + vector3(0.0, 0.0, 0.4),
        label = Config.SpeakerInteractLabel,
        icon = Config.SpeakerInteractIcon,
        onUse = function()
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
    local def = Config.SpeakerItems[itemName]
    if not def then
        Framework.Notify('Unknown speaker item.', 'error')
        return
    end
    Placement.Start('portable', def.model, nil, {
        item = itemName,
        slot = slot,
        fallback = def.fallback,
    })
end

RegisterNetEvent('djbooth:client:placeSpeaker', function(itemName, slot)
    PlacePortableSpeaker(itemName, slot)
end)

exports('useSpeaker', function(data, slot)
    local name = nil
    local slotId = nil
    if type(data) == 'string' then
        name = data
    elseif type(data) == 'table' then
        name = data.name or data.item or data.itemName
        slotId = data.slot
    end
    if type(slot) == 'table' then
        name = name or slot.name
        slotId = slot.slot or slotId
    elseif slot ~= nil then
        slotId = slot
    end
    PlacePortableSpeaker(name, slotId)
end)

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

exports('useHandheld', function(data, slot)
    PlacePortableSpeaker('lumina_speaker_handheld', slot and (slot.slot or slot))
end)
exports('useBigSpeaker', function(data, slot)
    PlacePortableSpeaker('lumina_speaker_big', slot and (slot.slot or slot))
end)
exports('useTripodSpeaker', function(data, slot)
    PlacePortableSpeaker('lumina_speaker_tripod', slot and (slot.slot or slot))
end)
