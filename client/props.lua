Props = {}

local VANILLA = {
    'prop_speaker_07',
    'prop_speaker_03',
    'prop_boombox_01',
    'prop_portable_hifi_01',
}

function Props.LoadHash(model)
    if not model then
        return nil
    end
    local hash = type(model) == 'number' and model or joaat(model)
    RequestModel(hash)
    local deadline = GetGameTimer() + 4000
    while not HasModelLoaded(hash) and GetGameTimer() < deadline do
        Wait(0)
    end
    if HasModelLoaded(hash) then
        return hash
    end
    return nil
end

function Props.LoadFirst(models)
    for i = 1, #models do
        local hash = Props.LoadHash(models[i])
        if hash then
            return hash, models[i]
        end
    end
    return nil
end

function Props.Fallbacks(primary, extra)
    local list = {}
    local seen = {}
    local function add(name)
        if not name or name == '' or seen[name] then
            return
        end
        seen[name] = true
        list[#list + 1] = name
    end
    add(primary)
    add(extra)
    add(Config.DefaultModel)
    add(Config.SpeakerModel)
    for i = 1, #VANILLA do
        add(VANILLA[i])
    end
    return list
end

function Props.CreateFrozen(hash, coords, heading, alpha)
    coords = DJ.ToVector3(coords)
    RequestCollisionAtCoord(coords.x, coords.y, coords.z)
    Wait(0)
    local obj = CreateObjectNoOffset(hash, coords.x, coords.y, coords.z, false, false, false)
    if not obj or obj == 0 or not DoesEntityExist(obj) then
        obj = CreateObject(hash, coords.x, coords.y, coords.z, false, false, false)
    end
    if not obj or obj == 0 or not DoesEntityExist(obj) then
        return nil
    end
    SetEntityHeading(obj, (heading or 0) + 0.0)
    FreezeEntityPosition(obj, true)
    SetEntityAsMissionEntity(obj, true, true)
    SetEntityLodDist(obj, 280)
    if alpha and alpha < 255 then
        SetEntityCollision(obj, false, false)
        SetEntityAlpha(obj, alpha, false)
    else
        SetEntityCollision(obj, true, true)
    end
    return obj
end
