Nui = {
    open = false,
    mode = nil,
    boothId = nil,
    speakerId = nil,
    expectOpenUntil = 0,
}

function Nui.Send(action, payload)
    SendNUIMessage({
        action = action,
        payload = payload or {},
    })
end

function Nui.Close(keepAdmin)
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    Nui.open = false
    if not keepAdmin then
        Nui.mode = nil
        Nui.boothId = nil
        Nui.speakerId = nil
    end
    Nui.Send('close')
end

function Nui.ForceHide()
    if Nui.open then
        return
    end
    if (Nui.expectOpenUntil or 0) > GetGameTimer() then
        return
    end
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    Nui.Send('close')
end

function Nui.Focus()
    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(false)
    Nui.open = true
end

function Nui.OpenBooth(payload)
    payload = payload or {}
    Nui.expectOpenUntil = 0
    Nui.mode = 'booth'
    Nui.boothId = payload.booth and payload.booth.id or nil
    Nui.Focus()
    payload.appName = Config.AppName
    payload.appTagline = Config.AppTagline
    payload.locale = Config.Locale
    payload.limits = {
        maxVolume = Config.MaxVolume,
        minRadius = Config.MinRadius,
        maxRadius = Config.MaxRadius,
    }
    Nui.Send('openBooth', payload)
end

function Nui.OpenAdmin(payload)
    Nui.mode = 'admin'
    Nui.boothId = nil
    if payload then
        Nui.expectOpenUntil = 0
        Nui.Focus()
        payload.appName = Config.AppName
        payload.models = Config.Models
        payload.defaultModel = Config.DefaultModel
        payload.speakerModel = Config.SpeakerModel
        Nui.Send('openAdmin', payload)
        return
    end
    Nui.expectOpenUntil = GetGameTimer() + 4000
    TriggerServerEvent('djbooth:requestAdmin')
end

function Nui.OpenSpeaker(payload)
    payload = payload or {}
    Nui.expectOpenUntil = 0
    Nui.mode = 'speaker'
    Nui.speakerId = payload.speaker and payload.speaker.id or nil
    Nui.boothId = nil
    Nui.Focus()
    payload.appName = Config.AppName
    payload.appTagline = 'Speaker'
    payload.limits = {
        maxVolume = Config.MaxVolume,
        minRadius = (payload.speaker and payload.speaker.minRadius) or 4.0,
        maxRadius = (payload.speaker and payload.speaker.maxRadius) or Config.MaxRadius,
    }
    Nui.Send('openSpeaker', payload)
end

function Nui.OpenCreate(draft)
    Nui.expectOpenUntil = 0
    Nui.mode = 'create'
    Nui.Focus()
    Nui.Send('openCreate', {
        appName = Config.AppName,
        draft = draft,
        models = Config.Models,
    })
end

RegisterNUICallback('close', function(_, cb)
    Nui.Close()
    cb({ ok = true })
end)

RegisterNUICallback('notify', function(data, cb)
    if data and data.message then
        Framework.Notify(data.message, data.type or 'inform')
    end
    cb({ ok = true })
end)

RegisterNUICallback('playUrl', function(data, cb)
    if Nui.mode == 'speaker' then
        TriggerServerEvent('djbooth:speakerPlay', Nui.speakerId, data and data.url, data and data.immediate)
    else
        TriggerServerEvent('djbooth:playUrl', Nui.boothId, data and data.url, data and data.immediate)
    end
    cb({ ok = true })
end)

RegisterNUICallback('control', function(data, cb)
    if Nui.mode == 'speaker' then
        TriggerServerEvent('djbooth:speakerControl', Nui.speakerId, data and data.action, data and data.value)
    else
        TriggerServerEvent('djbooth:control', Nui.boothId, data and data.action, data and data.value)
    end
    cb({ ok = true })
end)

RegisterNUICallback('speakerGroup', function(data, cb)
    TriggerServerEvent('djbooth:speakerGroup', Nui.speakerId, data and data.action, data and data.targetId)
    cb({ ok = true })
end)

RegisterNUICallback('speakerPickup', function(_, cb)
    TriggerServerEvent('djbooth:pickupSpeaker', Nui.speakerId)
    cb({ ok = true })
end)

RegisterNUICallback('queue', function(data, cb)
    if Nui.mode == 'speaker' then
        TriggerServerEvent('djbooth:speakerQueue', Nui.speakerId, data and data.action, data)
    else
        TriggerServerEvent('djbooth:queue', Nui.boothId, data and data.action, data)
    end
    cb({ ok = true })
end)

RegisterNUICallback('saveSong', function(data, cb)
    TriggerServerEvent('djbooth:saveSong', data)
    cb({ ok = true })
end)

RegisterNUICallback('deleteSong', function(data, cb)
    TriggerServerEvent('djbooth:deleteSong', data and data.id)
    cb({ ok = true })
end)

RegisterNUICallback('playlist', function(data, cb)
    TriggerServerEvent('djbooth:playlist', Nui.boothId, data)
    cb({ ok = true })
end)

RegisterNUICallback('startPlacement', function(data, cb)
    cb({ ok = true })
    Placement.Start('booth', data and data.model or Config.DefaultModel)
end)

RegisterNUICallback('startSpeakerPlacement', function(data, cb)
    cb({ ok = true })
    Placement.Start('speaker', data and data.model or Config.SpeakerModel, data and data.boothId)
end)

RegisterNUICallback('createBooth', function(data, cb)
    TriggerServerEvent('djbooth:createBooth', data)
    cb({ ok = true })
end)

RegisterNUICallback('updateBooth', function(data, cb)
    TriggerServerEvent('djbooth:updateBooth', data)
    cb({ ok = true })
end)

RegisterNUICallback('deleteBooth', function(data, cb)
    TriggerServerEvent('djbooth:deleteBooth', data and data.id)
    cb({ ok = true })
end)

RegisterNUICallback('removeSpeaker', function(data, cb)
    TriggerServerEvent('djbooth:removeSpeaker', data and data.boothId, data and data.index)
    cb({ ok = true })
end)

RegisterNUICallback('teleportBooth', function(data, cb)
    cb({ ok = true })
    if not data or not data.coords then
        return
    end
    local ped = PlayerPedId()
    local c = data.coords
    SetEntityCoords(ped, c.x + 0.8, c.y + 0.8, c.z + 0.2, false, false, false, false)
end)

RegisterNUICallback('refreshAdmin', function(_, cb)
    TriggerServerEvent('djbooth:requestAdmin')
    cb({ ok = true })
end)

RegisterCommand('lumina_close', function()
    if Nui.open then
        Nui.Close()
    end
end, false)

CreateThread(function()
    -- ui_page is always drawn; hide it on join so it cannot stick.
    Wait(0)
    Nui.ForceHide()
    Wait(500)
    Nui.ForceHide()
end)

CreateThread(function()
    while true do
        if Nui.open then
            DisableControlAction(0, 200, true) -- pause menu
            Wait(0)
        else
            Wait(200)
        end
    end
end)
