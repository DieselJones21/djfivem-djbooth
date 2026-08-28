Storage = {}

local resource = GetCurrentResourceName()

local function encodeList(list)
    if type(list) ~= 'table' or #list == 0 then
        return '[]'
    end
    return json.encode(list)
end

local function decode(raw, fallback)
    if not raw or raw == '' then
        return DJ.Copy(fallback)
    end
    local ok, decoded = pcall(json.decode, raw)
    if not ok or type(decoded) ~= 'table' then
        return DJ.Copy(fallback)
    end
    return decoded
end

local function readFile(fileName, fallback)
    return decode(LoadResourceFile(resource, fileName), fallback)
end

local function writeFile(fileName, encoded)
    local ok = SaveResourceFile(resource, fileName, encoded, -1)
    if ok == true then
        return true
    end
    ok = SaveResourceFile(resource, fileName, encoded, #encoded)
    if ok == true then
        return true
    end
    local path = GetResourcePath(resource)
    if path and path ~= '' then
        local ioOk, saved = pcall(function()
            local handle = io.open(path .. '/' .. fileName, 'w')
            if not handle then
                return false
            end
            handle:write(encoded)
            handle:close()
            return true
        end)
        if ioOk and saved then
            return true
        end
    end
    return false
end

local function readKvp(key, fallback)
    return decode(GetResourceKvpString(key), fallback)
end

local function writeKvp(key, encoded)
    SetResourceKvp(key, encoded)
end

local function persist(fileName, kvpKey, list, label)
    local encoded = encodeList(list)
    writeKvp(kvpKey, encoded)
    local saved = writeFile(fileName, encoded)
    if not saved then
        print(('[lumina-dj] %s folder is not writable; kept a KVP backup so data still survives restarts.'):format(label))
    end
    return true
end

local function loadMerged(fileName, kvpKey, fallback)
    local fromFile = readFile(fileName, fallback)
    local fileCount = 0
    if type(fromFile) == 'table' then
        if fromFile[1] ~= nil then
            fileCount = #fromFile
        else
            for _, entry in pairs(fromFile) do
                if type(entry) == 'table' then
                    fileCount = fileCount + 1
                end
            end
        end
    end
    if fileCount > 0 then
        return fromFile
    end
    return readKvp(kvpKey, fallback)
end

function Storage.LoadBooths()
    return loadMerged('data/booths.json', 'lumina_booths', {})
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
    persist('data/booths.json', 'lumina_booths', list, 'Booths')
    print(('[lumina-dj] Saved %s booth(s).'):format(#list))
end

function Storage.LoadLibrary()
    local data = loadMerged('data/library.json', 'lumina_library', { players = {} })
    data.players = data.players or {}
    return data
end

function Storage.SaveLibrary(library)
    local encoded = json.encode(library or { players = {} })
    writeKvp('lumina_library', encoded)
    if not writeFile('data/library.json', encoded) then
        print('[lumina-dj] Library folder is not writable; kept a KVP backup so data still survives restarts.')
    end
end

function Storage.LoadSpeakers()
    return loadMerged('data/speakers.json', 'lumina_speakers', {})
end

function Storage.SaveSpeakers(speakers)
    local list = {}
    for _, speaker in pairs(speakers) do
        local copy = DJ.Copy(speaker)
        copy.state = nil
        list[#list + 1] = copy
    end
    persist('data/speakers.json', 'lumina_speakers', list, 'Speakers')
    print(('[lumina-dj] Saved %s portable speaker(s).'):format(#list))
end
