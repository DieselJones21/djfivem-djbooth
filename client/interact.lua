Interact = {
    zones = {},
    native = {},
}

local function isAdmin()
    return LocalPlayer and LocalPlayer.state and LocalPlayer.state.djboothAdmin == true
end

local function canOpen(booth)
    if not booth then
        return false
    end
    if not booth.jobs or #booth.jobs == 0 then
        return Config.AllowPublicBooths
    end

    local job, grade = Framework.GetJob()
    if not job then
        return isAdmin()
    end

    for i = 1, #booth.jobs do
        local entry = booth.jobs[i]
        local name = type(entry) == 'table' and entry.name or entry
        local minGrade = type(entry) == 'table' and (entry.grade or 0) or 0
        if name == job and grade >= minGrade then
            return true
        end
    end

    return isAdmin()
end

local function groupsFrom(booth)
    if not booth.jobs or #booth.jobs == 0 then
        return nil
    end
    local groups = {}
    local any = false
    for i = 1, #booth.jobs do
        local entry = booth.jobs[i]
        local name = type(entry) == 'table' and entry.name or entry
        local grade = type(entry) == 'table' and (entry.grade or 0) or 0
        if name and name ~= '' then
            groups[name] = grade
            any = true
        end
    end
    return any and groups or nil
end

function Interact.Remove(boothId)
    local id = 'djbooth_' .. boothId
    local cached = Interact.zones[boothId]
    Interact.zones[boothId] = nil
    Interact.native[boothId] = nil

    if GetResourceState(Config.Interact.resource) == 'started' then
        pcall(function()
            exports[Config.Interact.resource]:RemoveInteraction(id)
        end)
    end

    if GetResourceState('ox_target') == 'started' and cached and cached.ox then
        pcall(function()
            exports.ox_target:removeZone(cached.ox)
        end)
    end

    if GetResourceState('qb-target') == 'started' then
        pcall(function()
            exports['qb-target']:RemoveZone(id)
        end)
    end
end

function Interact.RemoveAll()
    for boothId in pairs(Interact.zones) do
        Interact.Remove(boothId)
    end
    for boothId in pairs(Interact.native) do
        Interact.Remove(boothId)
    end
end

function Interact.Register(booth)
    Interact.Remove(booth.id)

    local coords = DJ.ToVector3(booth.coords) + vector3(0.0, 0.0, 0.45)
    local id = 'djbooth_' .. booth.id
    local groups = groupsFrom(booth)

    if GetResourceState(Config.Interact.resource) == 'started' then
        local payload = {
            coords = coords,
            distance = Config.Interact.distance,
            interactDst = Config.Interact.interactDst,
            id = id,
            options = {
                {
                    label = Config.Interact.label,
                    action = function()
                        OpenBooth(booth.id)
                    end,
                    canInteract = function()
                        return canOpen(Booths.Get(booth.id) or booth)
                    end,
                },
            },
        }
        if groups then
            payload.groups = groups
        end
        exports[Config.Interact.resource]:AddInteraction(payload)
        Interact.zones[booth.id] = { kind = 'interact' }
        return
    end

    if GetResourceState('ox_target') == 'started' then
        local oxId = exports.ox_target:addSphereZone({
            coords = coords,
            radius = Config.Interact.interactDst,
            debug = false,
            options = {
                {
                    name = id,
                    icon = Config.Interact.icon,
                    label = Config.Interact.label,
                    groups = groups,
                    onSelect = function()
                        OpenBooth(booth.id)
                    end,
                    canInteract = function()
                        return canOpen(Booths.Get(booth.id) or booth)
                    end,
                },
            },
        })
        Interact.zones[booth.id] = { kind = 'ox', ox = oxId }
        return
    end

    if GetResourceState('qb-target') == 'started' then
        exports['qb-target']:AddCircleZone(id, coords, Config.Interact.interactDst, {
            name = id,
            debugPoly = false,
            useZ = true,
        }, {
            options = {
                {
                    icon = Config.Interact.icon,
                    label = Config.Interact.label,
                    action = function()
                        OpenBooth(booth.id)
                    end,
                    canInteract = function()
                        return canOpen(Booths.Get(booth.id) or booth)
                    end,
                },
            },
            distance = Config.Interact.interactDst,
        })
        Interact.zones[booth.id] = { kind = 'qb' }
        return
    end

    Interact.native[booth.id] = {
        coords = coords,
        label = Config.Interact.label,
    }
end

local function drawText3d(coords, text)
    local onScreen, x, y = World3dToScreen2d(coords.x, coords.y, coords.z)
    if not onScreen then
        return
    end
    SetTextScale(0.32, 0.32)
    SetTextFont(4)
    SetTextProportional(true)
    SetTextColour(20, 24, 32, 230)
    SetTextCentre(true)
    SetTextOutline()
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(x, y)
end

CreateThread(function()
    while true do
        local sleep = 750
        local ped = PlayerPedId()
        local pos = GetEntityCoords(ped)
        local closest, closestDist, closestId

        for boothId, zone in pairs(Interact.native) do
            local dist = #(pos - zone.coords)
            if dist < 12.0 then
                sleep = 0
                if dist < Config.Interact.nativeDistance + 1.5 then
                    drawText3d(zone.coords, ('[E]  %s'):format(zone.label))
                end
                if not closestDist or dist < closestDist then
                    closest = zone
                    closestDist = dist
                    closestId = boothId
                end
            end
        end

        if closest and closestDist <= Config.Interact.nativeDistance and IsControlJustReleased(0, 38) then
            OpenBooth(closestId)
        end

        Wait(sleep)
    end
end)
