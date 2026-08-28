Placement = {
    active = false,
}

local previewObject
local heading = 0.0
local heightOffset = 0.0
local currentModel
local pendingKind = 'booth' -- booth | speaker
local pendingBoothId
local scaleform

local function loadScaleform()
    local sf = RequestScaleformMovie('instructional_buttons')
    while not HasScaleformMovieLoaded(sf) do
        Wait(0)
    end
    return sf
end

local function showInstructions()
    if not scaleform then
        scaleform = loadScaleform()
    end

    BeginScaleformMovieMethod(scaleform, 'CLEAR_ALL')
    EndScaleformMovieMethod()

    BeginScaleformMovieMethod(scaleform, 'SET_CLEAR_SPACE')
    ScaleformMovieMethodAddParamInt(200)
    EndScaleformMovieMethod()

    local buttons = {
        { 38, 'Confirm' },
        { 73, 'Cancel' },
        { 15, 'Rotate' },
        { 172, 'Height' },
    }

    for index, button in ipairs(buttons) do
        BeginScaleformMovieMethod(scaleform, 'SET_DATA_SLOT')
        ScaleformMovieMethodAddParamInt(index - 1)
        ScaleformMovieMethodAddParamPlayerNameString(GetControlInstructionalButton(0, button[1], true))
        BeginTextCommandScaleformString('STRING')
        AddTextComponentSubstringPlayerName(button[2])
        EndTextCommandScaleformString()
        EndScaleformMovieMethod()
    end

    BeginScaleformMovieMethod(scaleform, 'DRAW_INSTRUCTIONAL_BUTTONS')
    EndScaleformMovieMethod()
end

local function rotationFromCam()
    local rot = GetGameplayCamRot(2)
    return vector3(
        -math.sin(math.rad(rot.z)) * math.abs(math.cos(math.rad(rot.x))),
        math.cos(math.rad(rot.z)) * math.abs(math.cos(math.rad(rot.x))),
        math.sin(math.rad(rot.x))
    )
end

local function raycastFromCamera(distance)
    local cam = GetGameplayCamCoord()
    local dir = rotationFromCam()
    local dest = cam + (dir * (distance or 12.0))
    local handle = StartExpensiveSynchronousShapeTestLosProbe(cam.x, cam.y, cam.z, dest.x, dest.y, dest.z, 1 + 16, PlayerPedId(), 7)
    local _, hit, endCoords = GetShapeTestResult(handle)
    if hit == 1 then
        return endCoords
    end
    return dest
end

local function requestModel(model)
    local hash, loadedName = Props.LoadFirst(Props.Fallbacks(model))
    if hash then
        currentModel = loadedName or model
    end
    return hash
end

local function deletePreview()
    if previewObject and DoesEntityExist(previewObject) then
        DeleteObject(previewObject)
    end
    previewObject = nil
end

local pendingItem
local pendingSlot

function Placement.Stop(silent)
    local kind = pendingKind
    Placement.active = false
    deletePreview()
    currentModel = nil
    pendingBoothId = nil
    pendingItem = nil
    pendingSlot = nil
    SetNuiFocus(false, false)
    if not silent and kind ~= 'portable' then
        Nui.OpenAdmin()
    end
end

function Placement.Start(kind, model, boothId, extra)
    if Placement.active then
        Placement.Stop(true)
    end

    pendingKind = kind or 'booth'
    pendingBoothId = boothId
    extra = extra or {}
    pendingItem = extra.item
    pendingSlot = extra.slot
    currentModel = model or (pendingKind == 'speaker' and Config.SpeakerModel or Config.DefaultModel)
    heading = GetEntityHeading(PlayerPedId())
    heightOffset = 0.0

    local hash = requestModel(currentModel)
    if not hash and extra.fallback then
        hash = requestModel(extra.fallback)
    end
    if not hash then
        Framework.Notify('That prop model is not available on this server.', 'error')
        if pendingKind ~= 'portable' then
            Nui.OpenAdmin()
        end
        return
    end

    Nui.Close(true)
    Wait(80)

    local coords = raycastFromCamera(8.0)
    previewObject = Props.CreateFrozen(hash, coords, heading, 175)
    if not previewObject then
        Framework.Notify('Could not spawn the placement preview.', 'error')
        if pendingKind ~= 'portable' then
            Nui.OpenAdmin()
        end
        return
    end
    SetModelAsNoLongerNeeded(hash)

    Placement.active = true
    showInstructions()
    Framework.Notify(Config.Locale.placement_help, 'inform')

    CreateThread(function()
        while Placement.active do
            Wait(0)
            DisableControlAction(0, 24, true)
            DisableControlAction(0, 25, true)
            DisableControlAction(0, 140, true)

            local hit = raycastFromCamera(10.0)
            if previewObject and DoesEntityExist(previewObject) then
                SetEntityCoordsNoOffset(previewObject, hit.x, hit.y, hit.z + heightOffset, false, false, false)
                SetEntityHeading(previewObject, heading)
            end

            if scaleform then
                DrawScaleformMovieFullscreen(scaleform, 255, 255, 255, 255, 0)
            end

            if IsControlJustPressed(0, Config.Placement.rotateFast) then
                heading = (heading + Config.Placement.rotateStep) % 360.0
            elseif IsControlJustPressed(0, Config.Placement.rotateSlow) then
                heading = (heading - Config.Placement.rotateStep) % 360.0
            end

            if IsControlPressed(0, Config.Placement.raise) then
                heightOffset = heightOffset + Config.Placement.heightStep
            elseif IsControlPressed(0, Config.Placement.lower) then
                heightOffset = heightOffset - Config.Placement.heightStep
            end

            if IsControlJustReleased(0, Config.Placement.confirm) then
                if not previewObject or not DoesEntityExist(previewObject) then
                    Framework.Notify('Placement preview was lost. Try again.', 'error')
                    Placement.Stop()
                else
                    local coords = GetEntityCoords(previewObject)
                    local hdg = GetEntityHeading(previewObject)
                    local kindNow = pendingKind
                    local boothIdNow = pendingBoothId
                    local modelNow = currentModel
                    local itemNow = pendingItem
                    local slotNow = pendingSlot
                    Placement.active = false
                    pendingKind = nil
                    deletePreview()

                    if kindNow == 'speaker' then
                        TriggerServerEvent('djbooth:addSpeaker', boothIdNow, DJ.Vec(coords))
                        Framework.Notify(Config.Locale.speaker_placed, 'success')
                        Wait(120)
                        Nui.OpenAdmin()
                    elseif kindNow == 'portable' then
                        TriggerServerEvent('djbooth:placePortableSpeaker', itemNow, DJ.Vec(coords), hdg, modelNow, slotNow)
                    else
                        Nui.OpenCreate({
                            coords = DJ.Vec(coords),
                            heading = hdg,
                            model = modelNow,
                        })
                    end
                end
            elseif IsControlJustReleased(0, Config.Placement.cancel) then
                Placement.Stop()
            end
        end
    end)
end

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then
        return
    end
    deletePreview()
end)
