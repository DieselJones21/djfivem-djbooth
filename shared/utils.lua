DJ = DJ or {}

function DJ.Trim(value)
    if type(value) ~= 'string' then
        return ''
    end
    return (value:gsub('^%s+', ''):gsub('%s+$', ''))
end

function DJ.Copy(value)
    if type(value) ~= 'table' then
        return value
    end

    local clone = {}
    for key, entry in pairs(value) do
        clone[key] = DJ.Copy(entry)
    end
    return clone
end

function DJ.Uuid()
    local template = 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'
    return string.gsub(template, '[xy]', function(char)
        local number = (char == 'x') and math.random(0, 15) or math.random(8, 11)
        return string.format('%x', number)
    end)
end

function DJ.Vec(coords)
    if not coords then
        return nil
    end

    if type(coords) == 'vector3' then
        return { x = coords.x + 0.0, y = coords.y + 0.0, z = coords.z + 0.0 }
    end

    return {
        x = (coords.x or coords[1] or 0) + 0.0,
        y = (coords.y or coords[2] or 0) + 0.0,
        z = (coords.z or coords[3] or 0) + 0.0,
    }
end

function DJ.ToVector3(coords)
    local packed = DJ.Vec(coords)
    if not packed then
        return vector3(0.0, 0.0, 0.0)
    end
    return vector3(packed.x, packed.y, packed.z)
end

function DJ.FormatTime(seconds)
    seconds = math.floor(tonumber(seconds) or 0)
    if seconds < 0 then
        seconds = 0
    end
    local minutes = math.floor(seconds / 60)
    local remain = seconds % 60
    return string.format('%d:%02d', minutes, remain)
end

function DJ.ExtractYouTubeId(url)
    url = DJ.Trim(url or '')
    if url == '' then
        return nil
    end

    local patterns = {
        'youtu%.be/([%w%-_]+)',
        'youtube%.com/watch%?.*v=([%w%-_]+)',
        'youtube%.com/embed/([%w%-_]+)',
        'youtube%.com/shorts/([%w%-_]+)',
        'youtube%.com/live/([%w%-_]+)',
        'music%.youtube%.com/watch%?.*v=([%w%-_]+)',
        'm%.youtube%.com/watch%?.*v=([%w%-_]+)',
    }

    for i = 1, #patterns do
        local id = url:match(patterns[i])
        if id and #id >= 11 then
            return id:sub(1, 11)
        end
    end

    return nil
end

function DJ.ExtractPlaylistId(url)
    url = DJ.Trim(url or '')
    return url:match('[?&]list=([%w%-_]+)')
end

function DJ.NormalizeMediaUrl(url)
    url = DJ.Trim(url or '')
    local youtubeId = DJ.ExtractYouTubeId(url)
    if youtubeId then
        return ('https://www.youtube.com/watch?v=%s'):format(youtubeId), 'youtube', youtubeId
    end
    return url, 'direct', nil
end

local function hostIsPrivate(host)
    host = host:lower()
    if host == 'localhost' or host == '127.0.0.1' or host == '::1' or host == '0.0.0.0' then
        return true
    end
    if host:match('^10%.') or host:match('^192%.168%.') or host:match('^169%.254%.') then
        return true
    end
    local a, b = host:match('^172%.(%d+)%.(%d+)%.')
    if a then
        local second = tonumber(a)
        if second and second >= 16 and second <= 31 then
            return true
        end
    end
    return false
end

function DJ.IsValidMediaUrl(url)
    url = DJ.Trim(url or '')
    if url == '' or #url > (Config.MaxUrlLength or 400) then
        return false
    end

    local lower = url:lower()
    if lower:find('javascript:', 1, true) or lower:find('nui://', 1, true) or lower:find('file:', 1, true) then
        return false
    end

    if DJ.ExtractYouTubeId(url) or DJ.ExtractPlaylistId(url) then
        return true
    end

    local host = url:match('^https://([^/%?]+)')
    if not host or hostIsPrivate(host) then
        return false
    end

    return true
end

function DJ.ThumbnailFor(url)
    if type(url) == 'string' and #url == 11 and url:match('^[%w%-_]+$') then
        return ('https://i.ytimg.com/vi/%s/hqdefault.jpg'):format(url)
    end
    local id = DJ.ExtractYouTubeId(url)
    if id then
        return ('https://i.ytimg.com/vi/%s/hqdefault.jpg'):format(id)
    end
    return nil
end

function DJ.EncodeURI(str)
    str = tostring(str or '')
    return (str:gsub('([^%w%-_%.~])', function(char)
        return string.format('%%%02X', string.byte(char))
    end))
end

function DJ.Clamp(value, min, max)
    value = tonumber(value) or min
    if value < min then
        return min
    end
    if value > max then
        return max
    end
    return value
end

function DJ.NotifyType(kind)
    if kind == 'error' or kind == 'success' or kind == 'inform' or kind == 'warning' then
        return kind
    end
    return 'inform'
end
