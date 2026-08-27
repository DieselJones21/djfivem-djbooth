Storage = {}

local resource = GetCurrentResourceName()

local function readJson(fileName, fallback)
    local raw = LoadResourceFile(resource, fileName)
    if not raw or raw == '' then
        return DJ.Copy(fallback)
    end
    local ok, decoded = pcall(json.decode, raw)
    if not ok or type(decoded) ~= 'table' then
        return DJ.Copy(fallback)
    end
    return decoded
end

local function writeJson(fileName, data)
    SaveResourceFile(resource, fileName, json.encode(data), -1)
end

function Storage.LoadBooths()
    return readJson('data/booths.json', {})
end

function Storage.SaveBooths(booths)
    local list = {}
    for _, booth in pairs(booths) do
        local copy = DJ.Copy(booth)
        copy.state = nil
        list[#list + 1] = copy
    end
    table.sort(list, function(a, b)
        return tostring(a.name) < tostring(b.name)
    end)
    writeJson('data/booths.json', list)
end

function Storage.LoadLibrary()
    return readJson('data/library.json', { players = {} })
end

function Storage.SaveLibrary(library)
    writeJson('data/library.json', library)
end

function Storage.LoadSpeakers()
    return readJson('data/speakers.json', {})
end

function Storage.SaveSpeakers(speakers)
    local list = {}
    for _, speaker in pairs(speakers) do
        local copy = DJ.Copy(speaker)
        copy.state = nil
        list[#list + 1] = copy
    end
    writeJson('data/speakers.json', list)
end
