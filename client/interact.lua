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
    Interact.RegisterPoint({
        id = booth.id,
        coords = coords,
        label = Config.Interact.label,
        icon = Config.Interact.icon,
        groups = groupsFrom(booth),
        onUse = function()
            OpenBooth(booth.id)
        end,
        canInteract = function()
            return canOpen(Booths.Get(booth.id) or booth)
        end,
    })
end

function Interact.RegisterPoint(opts)
    local id = opts.id
    Interact.Remove(id)
    local coords = opts.coords
    local interactId = 'djbooth_' .. id
    local label = opts.label or Config.Interact.label
    local icon = opts.icon or Config.Interact.icon
    local onUse = opts.onUse
    local canInteract = opts.canInteract or function() return true end

    if GetResourceState(Config.Interact.resource) == 'started' then
        local payload = {
            coords = coords,
            distance = Config.Interact.distance,
            interactDst = Config.Interact.interactDst,
            id = interactId,
            options = {
                {
                    label = label,
                    action = function()
                        onUse()
                    end,
                    canInteract = canInteract,
                },
            },
        }
        if opts.groups then
            payload.groups = opts.groups
        end
        exports[Config.Interact.resource]:AddInteraction(payload)
        Interact.zones[id] = { kind = 'interact' }
        return
    end

    if GetResourceState('ox_target') == 'started' then
        local oxId = exports.ox_target:addSphereZone({
            coords = coords,
            radius = Config.Interact.interactDst,
            debug = false,
            options = {
                {
                    name = interactId,
                    icon = icon,
                    label = label,
                    groups = opts.groups,
                    onSelect = onUse,
                    canInteract = canInteract,
                },
            },
        })
        Interact.zones[id] = { kind = 'ox', ox = oxId }
        return
    end

    if GetResourceState('qb-target') == 'started' then
        exports['qb-target']:AddCircleZone(interactId, coords, Config.Interact.interactDst, {
            name = interactId,
            debugPoly = false,
            useZ = true,
        }, {
            options = {
                {
                    icon = icon,
                    label = label,
                    action = onUse,
                    canInteract = canInteract,
                },
            },
            distance = Config.Interact.interactDst,
        })
        Interact.zones[id] = { kind = 'qb' }
        return
    end

    Interact.native[id] = {
        coords = coords,
        label = label,
        onUse = onUse,
        canInteract = canInteract,
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
            if closest.canInteract and not closest.canInteract() then
                -- blocked
            elseif closest.onUse then
                closest.onUse()
            else
                OpenBooth(closestId)
            end
        end

        Wait(sleep)
    end
end)
