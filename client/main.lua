Booths = {
    list = {},
    objects = {},
}

local function modelHash(model)
    return type(model) == 'number' and model or joaat(model)
end

local function loadModel(model)
    local hash = modelHash(model)
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
end

function Booths.Spawn(booth)
    local existing = Booths.objects[booth.id]
    if existing and DoesEntityExist(existing) then
        DeleteObject(existing)
    end

    for key, handle in pairs(Booths.objects) do
        if type(key) == 'string' and key:find(booth.id .. '_spk_', 1, true) then
            if DoesEntityExist(handle) then
                DeleteObject(handle)
            end
            Booths.objects[key] = nil
        end
    end

    local hash = loadModel(booth.model or Config.DefaultModel)
    if not hash then
        hash = loadModel(Config.DefaultModel)
    end
    if not hash then
        return
    end

    local coords = DJ.ToVector3(booth.coords)
    local obj = CreateObject(hash, coords.x, coords.y, coords.z, false, false, false)
    SetEntityHeading(obj, (booth.heading or 0) + 0.0)
    FreezeEntityPosition(obj, true)
    SetEntityCollision(obj, true, true)
    SetEntityAsMissionEntity(obj, true, true)
    SetModelAsNoLongerNeeded(hash)
    Booths.objects[booth.id] = obj

    if booth.speakers then
        for i = 1, #booth.speakers do
            local key = booth.id .. '_spk_' .. i
            local old = Booths.objects[key]
            if old and DoesEntityExist(old) then
                DeleteObject(old)
            end
            local speakerHash = loadModel(booth.speakers[i].model or Config.SpeakerModel)
            if speakerHash then
                local sc = DJ.ToVector3(booth.speakers[i])
                local speaker = CreateObject(speakerHash, sc.x, sc.y, sc.z, false, false, false)
                SetEntityHeading(speaker, (booth.speakers[i].heading or 0) + 0.0)
                FreezeEntityPosition(speaker, true)
                SetEntityCollision(speaker, true, true)
                Booths.objects[key] = speaker
                SetModelAsNoLongerNeeded(speakerHash)
            end
        end
    end
end

function Booths.Despawn(id)
    local handle = Booths.objects[id]
    if handle and DoesEntityExist(handle) then
        DeleteObject(handle)
    end
    Booths.objects[id] = nil

    for key, obj in pairs(Booths.objects) do
        if type(key) == 'string' and key:find(id .. '_spk_', 1, true) then
            if DoesEntityExist(obj) then
                DeleteObject(obj)
            end
            Booths.objects[key] = nil
        end
    end
end

function Booths.SyncAll(list)
    local keep = {}
    Booths.list = {}
    for i = 1, #list do
        local booth = list[i]
        Booths.list[booth.id] = booth
        keep[booth.id] = true
        Booths.Spawn(booth)
        Interact.Register(booth)
        if booth.state then
            Audio.Apply(booth, booth.state)
        end
    end

    for id in pairs(Booths.objects) do
        local boothId = tostring(id):match('^(.-)_spk_') or id
        if not keep[boothId] then
            Booths.Despawn(id)
            Interact.Remove(boothId)
            Audio.Stop(boothId)
        end
    end
end

function OpenBooth(boothId)
    if Nui.open then
        return
    end
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

CreateThread(function()
    while GetResourceState('xsound') ~= 'started' do
        Wait(200)
    end
    TriggerServerEvent('djbooth:playerReady')
end)

CreateThread(function()
    while true do
        local sleep = 800
        if Config.ShowNowPlayingText then
            local ped = PlayerPedId()
            local pos = GetEntityCoords(ped)
            for id, booth in pairs(Booths.list) do
                local state = booth.state
                if state and state.current and not state.paused then
                    local coords = DJ.ToVector3(booth.coords)
                    local dist = #(pos - coords)
                    if dist < Config.NowPlayingTextDistance then
                        sleep = 0
                        local onScreen, x, y = World3dToScreen2d(coords.x, coords.y, coords.z + 1.15)
                        if onScreen then
                            SetTextScale(0.28, 0.28)
                            SetTextFont(4)
                            SetTextCentre(true)
                            SetTextColour(18, 22, 30, 230)
                            SetTextOutline()
                            BeginTextCommandDisplayText('STRING')
                            AddTextComponentSubstringPlayerName(('♪  %s'):format(state.current.title or 'Now Playing'))
                            EndTextCommandDisplayText(x, y)
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
end)
