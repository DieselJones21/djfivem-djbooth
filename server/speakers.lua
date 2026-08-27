local Speakers = {}
local Groups = {} -- groupId -> { speakerIds = {}, state = {} }
local OpenSpeaker = {} -- src -> speakerId

local function now()
    return os.time()
end

local function itemDef(name)
    return Config.SpeakerItems[name]
end

local function countSpeakers()
    local n = 0
    for _ in pairs(Speakers) do
        n = n + 1
    end
    return n
end

local function persist()
    Storage.SaveSpeakers(Speakers)
end

local function defaultState(speaker)
    return {
        playing = false,
        paused = false,
        current = nil,
        queue = {},
        volume = speaker and speaker.volume or Config.DefaultVolume,
        radius = speaker and speaker.radius or Config.DefaultRadius,
        loop = 'off',
        shuffle = false,
        elapsed = 0,
        duration = 0,
        startedAt = 0,
        pauseStarted = 0,
        playToken = 0,
        seekTo = nil,
    }
end

local function elapsedOf(state)
    if not state or not state.current then
        return 0
    end
    if state.paused then
        return state.elapsed or 0
    end
    if (state.startedAt or 0) <= 0 then
        return state.elapsed or 0
    end
    return (state.elapsed or 0) + math.max(0, now() - state.startedAt)
end

local function snapshotState(state)
    local copy = DJ.Copy(state)
    copy.elapsed = elapsedOf(state)
    copy.seekTo = nil
    return copy
end

local function groupOf(speaker)
    local gid = speaker.groupId or speaker.id
    Groups[gid] = Groups[gid] or { speakerIds = {}, state = defaultState(speaker) }
    local group = Groups[gid]
    local found = false
    for i = 1, #group.speakerIds do
        if group.speakerIds[i] == speaker.id then
            found = true
            break
        end
    end
    if not found then
        group.speakerIds[#group.speakerIds + 1] = speaker.id
    end
    speaker.groupId = gid
    return group, gid
end

local function membersOf(groupId)
    local group = Groups[groupId]
    local list = {}
    if not group then
        return list
    end
    for i = 1, #group.speakerIds do
        local speaker = Speakers[group.speakerIds[i]]
        if speaker then
            list[#list + 1] = speaker
        end
    end
    return list
end

local function publicSpeaker(speaker)
    local copy = DJ.Copy(speaker)
    local group = Groups[speaker.groupId or speaker.id]
    copy.state = group and snapshotState(group.state) or defaultState(speaker)
    copy.groupSize = #(membersOf(speaker.groupId or speaker.id))
    local def = itemDef(speaker.item)
    copy.label = def and def.label or 'Speaker'
    copy.maxRadius = def and def.maxRadius or Config.MaxRadius
    copy.minRadius = def and def.minRadius or 4.0
    return copy
end

local function broadcastGroup(groupId)
    local group = Groups[groupId]
    if not group then
        return
    end
    local members = membersOf(groupId)
    local payload = {}
    for i = 1, #members do
        payload[#payload + 1] = publicSpeaker(members[i])
    end
    TriggerClientEvent('djbooth:speakerAudio', -1, groupId, payload, snapshotState(group.state))

    for src, speakerId in pairs(OpenSpeaker) do
        local open = Speakers[speakerId]
        if open and open.groupId == groupId then
            TriggerClientEvent('djbooth:speakerUi', src, {
                speaker = publicSpeaker(open),
                nearby = nearbyFor(src, open),
                canPickup = canPickup(src, open),
                canPermanent = canControl(src, open),
            })
        end
    end
end

function canControl(src, speaker)
    if not speaker then
        return false
    end
    if Permissions.IsAdmin(src) then
        return true
    end
    if speaker.owner == Permissions.GetIdentifier(src) then
        return true
    end
    if speaker.permanent and Config.PermanentSpeakersPublic then
        return true
    end
    return false
end

function canPickup(src, speaker)
    if not speaker or speaker.permanent then
        return false
    end
    return Permissions.IsAdmin(src) or speaker.owner == Permissions.GetIdentifier(src)
end

function nearbyFor(src, speaker)
    local origin = DJ.ToVector3(speaker.coords)
    local list = {}
    for id, other in pairs(Speakers) do
        if id ~= speaker.id then
            local dist = #(origin - DJ.ToVector3(other.coords))
            if dist <= Config.SpeakerGroupDistance then
                list[#list + 1] = {
                    id = other.id,
                    label = (itemDef(other.item) and itemDef(other.item).label) or 'Speaker',
                    distance = math.floor(dist + 0.5),
                    grouped = other.groupId == speaker.groupId,
                    permanent = other.permanent and true or false,
                }
            end
        end
    end
    table.sort(list, function(a, b)
        return a.distance < b.distance
    end)
    return list
end

local function ensureAccess(src, speakerId)
    local speaker = Speakers[speakerId]
    if not speaker then
        Permissions.Notify(src, Config.Locale.booth_missing, 'error')
        return nil
    end
    if not canControl(src, speaker) then
        Permissions.Notify(src, Config.Locale.speaker_denied, 'error')
        return nil
    end
    return speaker
end

local function playOnGroup(groupId, track)
    local group = Groups[groupId]
    if not group then
        return
    end
    local state = group.state
    state.playToken = (state.playToken or 0) + 1
    state.current = track
    state.playing = true
    state.paused = false
    state.elapsed = 0
    state.duration = tonumber(track and track.duration) or 0
    state.startedAt = now()
    state.seekTo = 0
    broadcastGroup(groupId)
end

local function stopGroup(groupId)
    local group = Groups[groupId]
    if not group then
        return
    end
    local state = group.state
    state.current = nil
    state.playing = false
    state.paused = false
    state.elapsed = 0
    state.duration = 0
    state.startedAt = 0
    state.playToken = (state.playToken or 0) + 1
    broadcastGroup(groupId)
end

local function advanceGroup(groupId, reason)
    local group = Groups[groupId]
    if not group then
        return
    end
    local state = group.state
    state.queue = state.queue or {}

    if state.loop == 'track' and state.current and reason == 'ended' then
        playOnGroup(groupId, state.current)
        return
    end

    if #state.queue > 0 then
        local nextTrack
        if state.shuffle then
            local index = math.random(1, #state.queue)
            nextTrack = table.remove(state.queue, index)
        else
            nextTrack = table.remove(state.queue, 1)
        end
        if state.loop == 'queue' and state.current then
            state.queue[#state.queue + 1] = DJ.Copy(state.current)
        end
        playOnGroup(groupId, nextTrack)
        return
    end

    if state.loop == 'queue' and state.current then
        playOnGroup(groupId, state.current)
        return
    end

    stopGroup(groupId)
end

CreateThread(function()
    Wait(250)
    local saved = Storage.LoadSpeakers()
    for i = 1, #saved do
        local speaker = saved[i]
        if speaker.id then
            Speakers[speaker.id] = speaker
            speaker.groupId = speaker.groupId or speaker.id
            groupOf(speaker)
        end
    end
    print(('[lumina-dj] Loaded %s portable speaker(s).'):format(countSpeakers()))
end)

RegisterNetEvent('djbooth:placePortableSpeaker', function(item, coords, heading, model, slot)
    local src = source
    local def = itemDef(item)
    if not def then
        return
    end
    if countSpeakers() >= Config.MaxPortableSpeakers then
        Permissions.Notify(src, Config.Locale.too_many_speakers, 'error')
        return
    end
    local packed = DJ.Vec(coords)
    if not packed then
        return
    end
    if not Inventory.Remove(src, item, 1, slot) and not Permissions.IsAdmin(src) then
        Permissions.Notify(src, 'You do not have that speaker.', 'error')
        return
    end

    local speaker = {
        id = DJ.Uuid(),
        item = item,
        model = model or def.model,
        coords = packed,
        heading = tonumber(heading) or 0.0,
        volume = def.defaultVolume,
        radius = def.defaultRadius,
        permanent = false,
        owner = Permissions.GetIdentifier(src),
        createdAt = now(),
    }
    speaker.groupId = speaker.id
    Speakers[speaker.id] = speaker
    groupOf(speaker)
    persist()
    TriggerClientEvent('djbooth:upsertSpeaker', -1, publicSpeaker(speaker))
    Permissions.Notify(src, Config.Locale.portable_placed, 'success')
end)

RegisterNetEvent('djbooth:openSpeaker', function(speakerId)
    local src = source
    local speaker = ensureAccess(src, speakerId)
    if not speaker then
        return
    end
    OpenSpeaker[src] = speakerId
    TriggerClientEvent('djbooth:openSpeakerUi', src, {
        speaker = publicSpeaker(speaker),
        nearby = nearbyFor(src, speaker),
        canPickup = canPickup(src, speaker),
        canPermanent = Permissions.IsAdmin(src) or speaker.owner == Permissions.GetIdentifier(src),
        isAdmin = Permissions.IsAdmin(src),
        playerName = GetPlayerName(src) or 'DJ',
    })
end)

RegisterNetEvent('djbooth:speakerPlay', function(speakerId, url, immediate)
    local src = source
    local speaker = ensureAccess(src, speakerId)
    if not speaker then
        return
    end
    local group = groupOf(speaker)
    ResolveTrack(url, function(tracks, err)
        if err or not tracks then
            Permissions.Notify(src, err or Config.Locale.invalid_url, 'error')
            return
        end
        local first = table.remove(tracks, 1)
        group.state.queue = group.state.queue or {}
        if immediate or not group.state.current then
            for i = 1, #tracks do
                if #group.state.queue >= Config.MaxQueue then
                    break
                end
                group.state.queue[#group.state.queue + 1] = tracks[i]
            end
            playOnGroup(speaker.groupId, first)
        else
            group.state.queue[#group.state.queue + 1] = first
            for i = 1, #tracks do
                if #group.state.queue >= Config.MaxQueue then
                    Permissions.Notify(src, Config.Locale.queue_full, 'error')
                    break
                end
                group.state.queue[#group.state.queue + 1] = tracks[i]
            end
            broadcastGroup(speaker.groupId)
        end
    end)
end)

RegisterNetEvent('djbooth:speakerControl', function(speakerId, action, value)
    local src = source
    local speaker = ensureAccess(src, speakerId)
    if not speaker then
        return
    end
    local group, gid = groupOf(speaker)
    local state = group.state
    local def = itemDef(speaker.item)

    if action == 'pause' then
        if not state.current then return end
        if not state.paused then
            state.elapsed = elapsedOf(state)
            state.paused = true
            state.playing = false
            state.startedAt = 0
        end
    elseif action == 'resume' then
        if not state.current then return end
        state.paused = false
        state.playing = true
        state.startedAt = now()
    elseif action == 'stop' then
        stopGroup(gid)
        return
    elseif action == 'skip' then
        advanceGroup(gid, 'skip')
        return
    elseif action == 'previous' then
        if state.current then
            playOnGroup(gid, state.current)
        end
        return
    elseif action == 'seek' then
        if not state.current then
            return
        end
        local stamp = math.max(0, math.floor(tonumber(value) or 0))
        if state.duration and state.duration > 0 then
            stamp = math.min(stamp, math.max(0, state.duration - 1))
        end
        state.elapsed = stamp
        state.startedAt = state.paused and 0 or now()
        state.seekTo = stamp
        local payload = {}
        local members = membersOf(gid)
        for i = 1, #members do
            payload[#payload + 1] = publicSpeaker(members[i])
        end
        local snap = snapshotState(state)
        snap.seekTo = stamp
        TriggerClientEvent('djbooth:speakerAudio', -1, gid, payload, snap)
        return
    elseif action == 'volume' then
        speaker.volume = DJ.Clamp(value, 0.0, Config.MaxVolume)
        persist()
    elseif action == 'radius' then
        local minR = def and def.minRadius or 4.0
        local maxR = def and def.maxRadius or Config.MaxRadius
        speaker.radius = DJ.Clamp(value, minR, maxR)
        persist()
    elseif action == 'loop' then
        if value == 'track' or value == 'queue' or value == 'off' then
            state.loop = value
        end
    elseif action == 'shuffle' then
        state.shuffle = value and true or false
    elseif action == 'permanent' then
        if not (Permissions.IsAdmin(src) or speaker.owner == Permissions.GetIdentifier(src)) then
            return
        end
        speaker.permanent = value and true or false
        persist()
        Permissions.Notify(src, speaker.permanent and Config.Locale.speaker_permanent or Config.Locale.speaker_unpermanent, 'success')
    end

    broadcastGroup(gid)
end)

RegisterNetEvent('djbooth:speakerGroup', function(speakerId, action, targetId)
    local src = source
    local speaker = ensureAccess(src, speakerId)
    if not speaker then
        return
    end

    if action == 'leave' then
        local old = speaker.groupId
        if old == speaker.id then
            return
        end
        local group = Groups[old]
        if group then
            for i = #group.speakerIds, 1, -1 do
                if group.speakerIds[i] == speaker.id then
                    table.remove(group.speakerIds, i)
                end
            end
        end
        speaker.groupId = speaker.id
        local fresh = groupOf(speaker)
        if group and group.state and group.state.current then
            fresh.state = DJ.Copy(group.state)
        end
        persist()
        Permissions.Notify(src, Config.Locale.speaker_ungrouped, 'success')
        if old then
            broadcastGroup(old)
        end
        broadcastGroup(speaker.groupId)
        return
    end

    if action == 'join' then
        local other = Speakers[targetId]
        if not other then
            return
        end
        local dist = #(DJ.ToVector3(speaker.coords) - DJ.ToVector3(other.coords))
        if dist > Config.SpeakerGroupDistance then
            Permissions.Notify(src, Config.Locale.no_nearby_speakers, 'error')
            return
        end
        if not canControl(src, other) then
            Permissions.Notify(src, Config.Locale.speaker_denied, 'error')
            return
        end
        local targetGroup = groupOf(other)
        if #membersOf(other.groupId) >= Config.MaxSpeakerGroup then
            Permissions.Notify(src, Config.Locale.group_full, 'error')
            return
        end
        local old = speaker.groupId
        if old and Groups[old] then
            for i = #Groups[old].speakerIds, 1, -1 do
                if Groups[old].speakerIds[i] == speaker.id then
                    table.remove(Groups[old].speakerIds, i)
                end
            end
        end
        speaker.groupId = other.groupId
        groupOf(speaker)
        persist()
        Permissions.Notify(src, Config.Locale.speaker_grouped, 'success')
        if old and old ~= speaker.groupId then
            broadcastGroup(old)
        end
        broadcastGroup(speaker.groupId)
        targetGroup = targetGroup
    end
end)

RegisterNetEvent('djbooth:pickupSpeaker', function(speakerId)
    local src = source
    local speaker = Speakers[speakerId]
    if not speaker or not canPickup(src, speaker) then
        Permissions.Notify(src, Config.Locale.speaker_denied, 'error')
        return
    end
    if not Inventory.Add(src, speaker.item, 1) then
        Permissions.Notify(src, 'Your inventory is full.', 'error')
        return
    end
    local gid = speaker.groupId
    Speakers[speakerId] = nil
    if Groups[gid] then
        for i = #Groups[gid].speakerIds, 1, -1 do
            if Groups[gid].speakerIds[i] == speakerId then
                table.remove(Groups[gid].speakerIds, i)
            end
        end
    end
    persist()
    TriggerClientEvent('djbooth:removeSpeaker', -1, speakerId)
    if gid then
        broadcastGroup(gid)
    end
    OpenSpeaker[src] = nil
    Permissions.Notify(src, Config.Locale.portable_picked, 'success')
    TriggerClientEvent('djbooth:closeUi', src)
end)

RegisterNetEvent('djbooth:speakerEnded', function(rigId, token)
    local groupId = tostring(rigId or ''):gsub('^spk_', '')
    local group = Groups[groupId]
    if not group or not group.state or not group.state.current then
        return
    end
    if token and group.state.playToken and token ~= group.state.playToken then
        return
    end
    if group.state.paused then
        return
    end
    advanceGroup(groupId, 'ended')
end)

AddEventHandler('playerDropped', function()
    OpenSpeaker[source] = nil
end)

SpeakerSync = {}

function SpeakerSync.List()
    local list = {}
    for _, speaker in pairs(Speakers) do
        list[#list + 1] = publicSpeaker(speaker)
    end
    return list
end

CreateThread(function()
    Wait(800)
    if GetResourceState('qb-core') == 'started' then
        local ok, QBCore = pcall(function()
            return exports['qb-core']:GetCoreObject()
        end)
        if ok and QBCore then
            for name in pairs(Config.SpeakerItems) do
                QBCore.Functions.CreateUseableItem(name, function(source, item)
                    TriggerClientEvent('djbooth:client:placeSpeaker', source, name, item and item.slot)
                end)
            end
        end
    end
    if GetResourceState('es_extended') == 'started' then
        local ok, ESX = pcall(function()
            return exports['es_extended']:getSharedObject()
        end)
        if ok and ESX and ESX.RegisterUsableItem then
            for name in pairs(Config.SpeakerItems) do
                ESX.RegisterUsableItem(name, function(source)
                    TriggerClientEvent('djbooth:client:placeSpeaker', source, name)
                end)
            end
        end
    end
end)

RegisterCommand('givespeaker', function(src, args)
    if src == 0 then
        return
    end
    if not Permissions.IsAdmin(src) then
        Permissions.Notify(src, Config.Locale.no_permission, 'error')
        return
    end
    local map = {
        handheld = 'lumina_speaker_handheld',
        big = 'lumina_speaker_big',
        tripod = 'lumina_speaker_tripod',
    }
    local kind = args[1] or 'handheld'
    local item = map[kind] or (Config.SpeakerItems[kind] and kind)
    if not item then
        Permissions.Notify(src, 'Use handheld, big, or tripod.', 'error')
        return
    end
    local target = tonumber(args[2]) or src
    Inventory.Add(target, item, 1)
    Permissions.Notify(src, ('Gave %s.'):format(item), 'success')
end, false)

RegisterCommand('placespeaker', function(src, args)
    if src == 0 or not Permissions.IsAdmin(src) then
        return
    end
    local map = {
        handheld = 'lumina_speaker_handheld',
        big = 'lumina_speaker_big',
        tripod = 'lumina_speaker_tripod',
    }
    TriggerClientEvent('djbooth:client:placeSpeaker', src, map[args[1] or 'handheld'] or 'lumina_speaker_handheld')
end, false)
