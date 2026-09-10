Booths = {
    list = {},
    objects = {},
    speakerKeys = {},
}

function Booths.Get(id)
    return Booths.list[id]
end

function Booths.ClearProps()
    for id, handle in pairs(Booths.objects) do
        if DoesEntityExist(handle) then
            DeleteObject(handle)
        end
        Booths.objects[id] = nil
    end
    Booths.speakerKeys = {}
end

local function despawnSpeakerKeys(boothId)
    local keys = Booths.speakerKeys[boothId]
    if not keys then
        return
    end
    for i = 1, #keys do
        local handle = Booths.objects[keys[i]]
        if handle and DoesEntityExist(handle) then
            DeleteObject(handle)
        end
        Booths.objects[keys[i]] = nil
    end
    Booths.speakerKeys[boothId] = nil
end

function Booths.Spawn(booth)
    local existing = Booths.objects[booth.id]
    if existing and DoesEntityExist(existing) then
        DeleteObject(existing)
    end
    despawnSpeakerKeys(booth.id)

    local hash, modelName = Props.LoadFirst(Props.Fallbacks(booth.model or Config.DefaultModel))
    if not hash then
        print(('[djbooth] Could not load booth model %s'):format(tostring(booth.model)))
        return
    end
    booth.model = modelName or booth.model

    local coords = DJ.ToVector3(booth.coords)
    local obj = Props.CreateFrozen(hash, coords, booth.heading)
    SetModelAsNoLongerNeeded(hash)
    if not obj then
        return
    end
    Booths.objects[booth.id] = obj

    local keys = {}
    if booth.speakers then
        for i = 1, #booth.speakers do
            local key = booth.id .. '_spk_' .. i
            local speakerHash = Props.LoadFirst(Props.Fallbacks(booth.speakers[i].model or Config.SpeakerModel))
            if speakerHash then
                local speaker = Props.CreateFrozen(speakerHash, booth.speakers[i], booth.speakers[i].heading)
                if speaker then
                    Booths.objects[key] = speaker
                    keys[#keys + 1] = key
                end
                SetModelAsNoLongerNeeded(speakerHash)
            end
        end
    end
    Booths.speakerKeys[booth.id] = keys
end

function Booths.Despawn(id)
    local handle = Booths.objects[id]
    if handle and DoesEntityExist(handle) then
        DeleteObject(handle)
    end
    Booths.objects[id] = nil
    despawnSpeakerKeys(id)
end

function Booths.SyncAll(list)
    local keep = {}
    local incoming = {}
    for i = 1, #(list or {}) do
        local booth = list[i]
        incoming[booth.id] = booth
        keep[booth.id] = true
    end

    for id in pairs(Booths.list) do
        if not keep[id] then
            Booths.list[id] = nil
            Booths.Despawn(id)
            Interact.Remove(id)
            Audio.Stop(id)
        end
    end

    for id, booth in pairs(incoming) do
        Booths.list[id] = booth
        Booths.Spawn(booth)
        Interact.Register(booth)
        if booth.state then
            Audio.Apply(booth, booth.state)
        end
    end
end

function OpenBooth(boothId)
    if not boothId then
        return
    end
    local now = GetGameTimer()
    if Nui.open and Nui.mode == 'booth' and Nui.boothId == boothId then
        return
    end
    if (Nui.lastOpenAt or 0) + 400 > now then
        return
    end
    Nui.lastOpenAt = now
    -- Do not Nui.Close() first: that SendNUIMessage('close') can arrive after
    -- openBooth and hide the tablet we just opened.
    Nui.expectOpenUntil = now + 4000
    TriggerServerEvent('djbooth:openBooth', boothId)
end

RegisterNetEvent('djbooth:syncBooths', function(list)
    Booths.SyncAll(list or {})
end)

RegisterNetEvent('djbooth:upsertBooth', function(booth)
    if not booth or not booth.id then
        return
    end
    Booths.list[booth.id] = booth
    Booths.Spawn(booth)
    Interact.Register(booth)
    if booth.state then
        Audio.Apply(booth, booth.state)
    end
end)

RegisterNetEvent('djbooth:removeBooth', function(boothId)
    Booths.list[boothId] = nil
    Booths.Despawn(boothId)
    Interact.Remove(boothId)
    Audio.Stop(boothId)
    if Nui.boothId == boothId then
        Nui.Close()
    end
end)

RegisterNetEvent('djbooth:audioState', function(boothId, state)
    local booth = Booths.Get(boothId)
    if not booth then
        return
    end
    booth.state = state
    Audio.Apply(booth, state)
    if Nui.open and Nui.boothId == boothId then
        Nui.Send('syncState', {
            booth = booth,
            state = state,
        })
    end
end)

RegisterNetEvent('djbooth:audioTick', function(boothId, tick)
    tick = tick or {}
    local booth = Booths.Get(boothId)
    if booth and booth.state then
        booth.state.elapsed = tick.elapsed or booth.state.elapsed
        booth.state.duration = tick.duration or booth.state.duration
        if tick.paused ~= nil then
            booth.state.paused = tick.paused and true or false
        end
    end
    Audio.Tick(boothId, tick)
    if Nui.open and Nui.boothId == boothId then
        Nui.Send('progress', { elapsed = tick.elapsed or 0, duration = tick.duration or 0 })
    end
end)

RegisterNetEvent('djbooth:openBoothUi', function(payload)
    Nui.OpenBooth(payload)
end)

RegisterNetEvent('djbooth:openAdminUi', function(payload)
    Nui.OpenAdmin(payload)
end)

RegisterNetEvent('djbooth:librarySync', function(payload)
    if Nui.open then
        Nui.Send('syncLibrary', payload)
    end
end)

RegisterNetEvent('djbooth:notify', function(message, kind)
    Framework.Notify(message, kind)
end)

RegisterNetEvent('djbooth:setAdmin', function(isAdmin)
    pcall(function()
        LocalPlayer.state:set('djboothAdmin', isAdmin and true or false, false)
    end)
end)

local function hideUiIfIdle()
    if Nui and Nui.ForceHide then
        Nui.ForceHide()
    end
end

AddEventHandler('onClientResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then
        return
    end
    hideUiIfIdle()
end)

AddEventHandler('playerSpawned', hideUiIfIdle)
RegisterNetEvent('QBCore:Client:OnPlayerLoaded', hideUiIfIdle)
RegisterNetEvent('esx:playerLoaded', hideUiIfIdle)

CreateThread(function()
    while GetResourceState('xsound') ~= 'started' do
        Wait(200)
    end
    TriggerServerEvent('djbooth:playerReady')
    Wait(2500)
    TriggerServerEvent('djbooth:playerReady')
end)

CreateThread(function()
    while true do
        local sleep = 800
        if Config.ShowNowPlayingText then
            local ped = PlayerPedId()
            local pos = GetEntityCoords(ped)
            local maxDist = Config.NowPlayingTextDistance
            for _, booth in pairs(Booths.list) do
                local state = booth.state
                if state and state.current and not state.paused then
                    local coords = DJ.ToVector3(booth.coords)
                    local dist = #(pos - coords)
                    if dist < maxDist then
                        local onScreen, x, y = World3dToScreen2d(coords.x, coords.y, coords.z + 1.15)
                        if onScreen then
                            sleep = 0
                            SetTextScale(0.28, 0.28)
                            SetTextFont(4)
                            SetTextCentre(true)
                            SetTextColour(240, 213, 108, 230)
                            SetTextOutline()
                            BeginTextCommandDisplayText('STRING')
                            AddTextComponentSubstringPlayerName(('♪  %s'):format(state.current.title or 'Now Playing'))
                            EndTextCommandDisplayText(x, y)
                        elseif sleep > 150 then
                            sleep = 150
                        end
                    end
                end
            end
        end
        Wait(sleep)
    end
end)

CreateThread(function()
    while true do
        Wait(1000)
        if Nui.open and Nui.boothId then
            local elapsed, duration = Audio.Timestamp(Nui.boothId)
            if duration and duration > 0 then
                Nui.Send('progress', { elapsed = elapsed, duration = duration })
                TriggerServerEvent('djbooth:reportDuration', Nui.boothId, duration)
            end
        elseif Nui.open and Nui.speakerId then
            local speaker = PortableSpeakers.Get(Nui.speakerId)
            local gid = speaker and (speaker.groupId or speaker.id)
            if gid then
                local elapsed, duration = Audio.Timestamp('spk_' .. gid)
                if duration and duration > 0 then
                    Nui.Send('progress', { elapsed = elapsed, duration = duration })
                end
            end
        end
    end
end)

RegisterCommand(Config.AdminCommand, function()
    Nui.OpenAdmin()
end, false)

RegisterCommand(Config.OpenCommand, function()
    local pos = GetEntityCoords(PlayerPedId())
    local nearest, nearestDist
    for id, booth in pairs(Booths.list) do
        local dist = #(pos - DJ.ToVector3(booth.coords))
        if dist < (nearestDist or Config.Interact.distance) then
            nearest = id
            nearestDist = dist
        end
    end
    if nearest then
        OpenBooth(nearest)
    else
        Framework.Notify(Config.Locale.nearest_none, 'error')
    end
end, false)

TriggerEvent('chat:addSuggestion', '/' .. Config.AdminCommand, 'Open Rebel Roleplay DJ booth admin (place / edit booths)')
TriggerEvent('chat:addSuggestion', '/' .. Config.OpenCommand, 'Open the nearest DJ booth you can use')

exports('OpenBooth', OpenBooth)
exports('GetBooths', function()
    local list = {}
    for _, booth in pairs(Booths.list) do
        list[#list + 1] = booth
    end
    return list
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then
        return
    end
    SetNuiFocus(false, false)
    Interact.RemoveAll()
    Audio.StopAll()
    Booths.ClearProps()
    if PortableSpeakers then
        PortableSpeakers.Clear()
    end
end)
