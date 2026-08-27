local Booths = {}
local States = {}
local Library = { players = {} }
local Cooldown = {}
local OpenUi = {} -- src -> boothId

math.randomseed(GetGameTimer() % 2147483647)

local function now()
    return os.time()
end

local function countBooths()
    local n = 0
    for _ in pairs(Booths) do
        n = n + 1
    end
    return n
end

local function publicBooth(booth)
    local copy = DJ.Copy(booth)
    copy.state = States[booth.id]
    return copy
end

local function publicList()
    local list = {}
    for _, booth in pairs(Booths) do
        list[#list + 1] = publicBooth(booth)
    end
    table.sort(list, function(a, b)
        return tostring(a.name) < tostring(b.name)
    end)
    return list
end

local function defaultState()
    return {
        playing = false,
        paused = false,
        current = nil,
        queue = {},
        volume = Config.DefaultVolume,
        radius = Config.DefaultRadius,
        loop = 'off', -- off | track | queue
        shuffle = false,
        elapsed = 0,
        duration = 0,
        startedAt = 0,
        pauseStarted = 0,
        playToken = 0,
        seekTo = nil,
    }
end

local function elapsedOf(state)
    if not state or not state.current then
        return 0
    end
    if state.paused then
        return state.elapsed or 0
    end
    if (state.startedAt or 0) <= 0 then
        return state.elapsed or 0
    end
    return (state.elapsed or 0) + math.max(0, now() - state.startedAt)
end

local function snapshotState(state)
    local copy = DJ.Copy(state)
    copy.elapsed = elapsedOf(state)
    copy.seekTo = nil
    return copy
end

local function playerLibrary(src)
    local identifier = Permissions.GetIdentifier(src)
    Library.players[identifier] = Library.players[identifier] or {
        songs = {},
        playlists = {},
    }
    return Library.players[identifier], identifier
end

local function persistLibrary()
    Storage.SaveLibrary(Library)
end

local function persistBooths()
    Storage.SaveBooths(Booths)
end

local function broadcastAudio(boothId)
    local booth = Booths[boothId]
    if not booth then
        return
    end
    local state = snapshotState(States[boothId] or defaultState())
    TriggerClientEvent('djbooth:audioState', -1, boothId, state)

    for src, openId in pairs(OpenUi) do
        if openId == boothId then
            TriggerClientEvent('djbooth:audioState', src, boothId, state)
        end
    end
end

local function pushLibrary(src)
    local data = playerLibrary(src)
    TriggerClientEvent('djbooth:librarySync', src, {
        songs = data.songs,
        playlists = data.playlists,
    })
end

local function rateLimited(src)
    local last = Cooldown[src] or 0
    local t = GetGameTimer()
    if t - last < Config.PlayCooldownMs then
        return true
    end
    Cooldown[src] = t
    return false
end

local function parseJobs(raw)
    local jobs = {}
    if type(raw) == 'table' then
        for i = 1, #raw do
            local entry = raw[i]
            if type(entry) == 'string' and DJ.Trim(entry) ~= '' then
                jobs[#jobs + 1] = { name = DJ.Trim(entry), grade = 0 }
            elseif type(entry) == 'table' and entry.name and DJ.Trim(entry.name) ~= '' then
                jobs[#jobs + 1] = {
                    name = DJ.Trim(entry.name),
                    grade = tonumber(entry.grade) or 0,
                }
            end
        end
        return jobs
    end

    if type(raw) == 'string' then
        for token in string.gmatch(raw, '[^,]+') do
            local name, grade = token:match('^%s*([^:]+):?(%d*)%s*$')
            if name and DJ.Trim(name) ~= '' then
                jobs[#jobs + 1] = { name = DJ.Trim(name), grade = tonumber(grade) or 0 }
            end
        end
    end
    return jobs
end

local function sanitizeBoothInput(data, existing)
    local name = DJ.Trim(data and data.name or '')
    if name == '' then
        name = existing and existing.name or 'DJ Booth'
    end
    if #name > 42 then
        name = name:sub(1, 42)
    end

    local model = DJ.Trim(data and data.model or '')
    if model == '' then
        model = existing and existing.model or Config.DefaultModel
    end

    return {
        name = name,
        model = model,
        jobs = parseJobs(data and (data.jobs or data.jobText)),
        radius = DJ.Clamp(data and data.radius, Config.MinRadius, Config.MaxRadius),
        volume = DJ.Clamp(data and data.volume, 0.05, Config.MaxVolume),
        coords = DJ.Vec(data and data.coords) or (existing and existing.coords) or nil,
        heading = (data and tonumber(data.heading)) or (existing and existing.heading) or 0.0,
    }
end

local function playTrack(boothId, track, fromQueue)
    local state = States[boothId]
    if not state then
        return
    end
    state.playToken = (state.playToken or 0) + 1
    state.current = track
    state.playing = true
    state.paused = false
    state.elapsed = 0
    state.duration = tonumber(track.duration) or 0
    state.startedAt = now()
    state.pauseStarted = 0
    state.seekTo = 0
    if not fromQueue then
        -- keep queue
    end
    broadcastAudio(boothId)
end

local function advance(boothId, reason)
    local state = States[boothId]
    if not state then
        return
    end

    if state.loop == 'track' and state.current and reason == 'ended' then
        playTrack(boothId, state.current, true)
        return
    end

    if state.queue and #state.queue > 0 then
        local nextTrack
        if state.shuffle then
            local index = math.random(1, #state.queue)
            nextTrack = table.remove(state.queue, index)
        else
            nextTrack = table.remove(state.queue, 1)
        end
        if state.loop == 'queue' and state.current then
            state.queue[#state.queue + 1] = DJ.Copy(state.current)
        end
        playTrack(boothId, nextTrack, true)
        return
    end

    if state.loop == 'queue' and state.current then
        playTrack(boothId, state.current, true)
        return
    end

    state.playing = false
    state.paused = false
    state.current = nil
    state.elapsed = 0
    state.duration = 0
    state.startedAt = 0
    state.playToken = (state.playToken or 0) + 1
    broadcastAudio(boothId)
end

ResolveTrack = function(url, cb)
    url = DJ.Trim(url or '')
    if not DJ.IsValidMediaUrl(url) then
        cb(nil, Config.Locale.invalid_url)
        return
    end

    local playlistId = DJ.ExtractPlaylistId(url)
    local videoId = DJ.ExtractYouTubeId(url)
    if playlistId and Config.YouTubeApiKey ~= '' and (not videoId or url:find('list=', 1, true) and not url:find('watch', 1, true)) then
        local api = ('https://www.googleapis.com/youtube/v3/playlistItems?part=snippet&maxResults=%s&playlistId=%s&key=%s'):format(
            Config.YouTubePlaylistLimit,
            DJ.EncodeURI(playlistId),
            DJ.EncodeURI(Config.YouTubeApiKey)
        )
        PerformHttpRequest(api, function(status, body)
            if status ~= 200 or not body then
                if videoId then
                    ResolveTrack('https://www.youtube.com/watch?v=' .. videoId, cb)
                else
                    cb(nil, 'Could not expand that YouTube playlist.')
                end
                return
            end
            local decoded = json.decode(body)
            local tracks = {}
            if decoded and decoded.items then
                for i = 1, #decoded.items do
                    local snippet = decoded.items[i].snippet
                    local id = snippet and snippet.resourceId and snippet.resourceId.videoId
                    if id then
                        tracks[#tracks + 1] = {
                            id = DJ.Uuid(),
                            title = snippet.title or 'YouTube Track',
                            author = snippet.channelTitle or 'YouTube',
                            url = 'https://www.youtube.com/watch?v=' .. id,
                            thumbnail = DJ.ThumbnailFor(id) or ('https://i.ytimg.com/vi/%s/hqdefault.jpg'):format(id),
                            source = 'youtube',
                            duration = 0,
                        }
                    end
                end
            end
            if #tracks == 0 then
                cb(nil, 'That playlist had no playable videos.')
                return
            end
            cb(tracks)
        end, 'GET')
        return
    end

    local normalized, source, ytId = DJ.NormalizeMediaUrl(url)
    if source == 'youtube' and ytId then
        local oembed = 'https://www.youtube.com/oembed?format=json&url=' .. DJ.EncodeURI('https://www.youtube.com/watch?v=' .. ytId)
        PerformHttpRequest(oembed, function(status, body)
            local title, author = 'YouTube Track', 'YouTube'
            if status == 200 and body then
                local decoded = json.decode(body)
                if decoded then
                    title = decoded.title or title
                    author = decoded.author_name or author
                end
            end
            cb({
                {
                    id = DJ.Uuid(),
                    title = title,
                    author = author,
                    url = normalized,
                    thumbnail = DJ.ThumbnailFor(normalized),
                    source = 'youtube',
                    duration = 0,
                },
            })
        end, 'GET')
        return
    end

    local label = normalized:match('([^/]+)%.[%w]+$') or 'Audio Stream'
    label = label:gsub('%%20', ' ')
    cb({
        {
            id = DJ.Uuid(),
            title = label,
            author = 'Direct',
            url = normalized,
            thumbnail = nil,
            source = 'direct',
            duration = 0,
        },
    })
end

local function ensureBoothAccess(src, boothId)
    local booth = Booths[boothId]
    if not booth then
        Permissions.Notify(src, Config.Locale.booth_missing, 'error')
        return nil
    end
    if not Permissions.CanUseBooth(src, booth) then
        Permissions.Notify(src, Config.Locale.booth_open_denied, 'error')
        return nil
    end
    return booth
end

CreateThread(function()
    local saved = Storage.LoadBooths()
    for i = 1, #saved do
        local booth = saved[i]
        if booth.id then
            booth.jobs = booth.jobs or {}
            booth.speakers = booth.speakers or {}
            Booths[booth.id] = booth
            local state = defaultState()
            state.volume = booth.volume or Config.DefaultVolume
            state.radius = booth.radius or Config.DefaultRadius
            States[booth.id] = state
        end
    end
    Library = Storage.LoadLibrary()
    Library.players = Library.players or {}
    print(('[lumina-dj] Loaded %s booth(s).'):format(countBooths()))
end)

AddEventHandler('playerDropped', function()
    local src = source
    OpenUi[src] = nil
    Cooldown[src] = nil
end)

RegisterNetEvent('djbooth:playerReady', function()
    local src = source
    TriggerClientEvent('djbooth:setAdmin', src, Permissions.IsAdmin(src))
    TriggerClientEvent('djbooth:syncBooths', src, publicList())
    if SpeakerSync and SpeakerSync.List then
        TriggerClientEvent('djbooth:syncSpeakers', src, SpeakerSync.List())
    end
end)

RegisterNetEvent('djbooth:openBooth', function(boothId)
    local src = source
    local booth = ensureBoothAccess(src, boothId)
    if not booth then
        return
    end
    OpenUi[src] = boothId
    local lib = playerLibrary(src)
    TriggerClientEvent('djbooth:openBoothUi', src, {
        booth = publicBooth(booth),
        state = snapshotState(States[boothId]),
        songs = lib.songs,
        playlists = lib.playlists,
        isAdmin = Permissions.IsAdmin(src),
        playerName = GetPlayerName(src) or 'DJ',
    })
end)

RegisterNetEvent('djbooth:requestAdmin', function()
    local src = source
    if not Permissions.IsAdmin(src) then
        Permissions.Notify(src, Config.Locale.no_permission, 'error')
        return
    end
    TriggerClientEvent('djbooth:openAdminUi', src, {
        booths = publicList(),
        isAdmin = true,
    })
end)

RegisterNetEvent('djbooth:createBooth', function(data)
    local src = source
    if not Permissions.IsAdmin(src) then
        Permissions.Notify(src, Config.Locale.no_permission, 'error')
        return
    end
    if countBooths() >= Config.MaxBooths then
        Permissions.Notify(src, Config.Locale.too_many_booths, 'error')
        return
    end

    local fields = sanitizeBoothInput(data)
    if not fields.coords then
        Permissions.Notify(src, 'Stand where you want the booth and place it again.', 'error')
        return
    end

    local booth = {
        id = DJ.Uuid(),
        name = fields.name,
        model = fields.model,
        coords = fields.coords,
        heading = fields.heading,
        jobs = fields.jobs,
        radius = fields.radius,
        volume = fields.volume,
        speakers = {},
        createdBy = Permissions.GetIdentifier(src),
        createdAt = now(),
    }
    Booths[booth.id] = booth
    local state = defaultState()
    state.volume = booth.volume
    state.radius = booth.radius
    States[booth.id] = state
    persistBooths()
    TriggerClientEvent('djbooth:upsertBooth', -1, publicBooth(booth))
    Permissions.Notify(src, Config.Locale.booth_placed, 'success')
    TriggerClientEvent('djbooth:openAdminUi', src, { booths = publicList(), isAdmin = true })
end)

RegisterNetEvent('djbooth:updateBooth', function(data)
    local src = source
    if not Permissions.IsAdmin(src) then
        Permissions.Notify(src, Config.Locale.no_permission, 'error')
        return
    end
    local booth = Booths[data and data.id]
    if not booth then
        Permissions.Notify(src, Config.Locale.booth_missing, 'error')
        return
    end
    local fields = sanitizeBoothInput(data, booth)
    booth.name = fields.name
    booth.model = fields.model
    booth.jobs = fields.jobs
    booth.radius = fields.radius
    booth.volume = fields.volume
    if fields.coords then
        booth.coords = fields.coords
        booth.heading = fields.heading
    end
    local state = States[booth.id]
    if state then
        state.radius = booth.radius
        state.volume = booth.volume
    end
    persistBooths()
    TriggerClientEvent('djbooth:upsertBooth', -1, publicBooth(booth))
    broadcastAudio(booth.id)
    TriggerClientEvent('djbooth:openAdminUi', src, { booths = publicList(), isAdmin = true })
end)

RegisterNetEvent('djbooth:deleteBooth', function(boothId)
    local src = source
    if not Permissions.IsAdmin(src) then
        Permissions.Notify(src, Config.Locale.no_permission, 'error')
        return
    end
    if not Booths[boothId] then
        return
    end
    Booths[boothId] = nil
    States[boothId] = nil
    persistBooths()
    TriggerClientEvent('djbooth:removeBooth', -1, boothId)
    Permissions.Notify(src, Config.Locale.booth_deleted, 'success')
    TriggerClientEvent('djbooth:openAdminUi', src, { booths = publicList(), isAdmin = true })
end)

RegisterNetEvent('djbooth:addSpeaker', function(boothId, coords)
    local src = source
    if not Permissions.IsAdmin(src) then
        Permissions.Notify(src, Config.Locale.no_permission, 'error')
        return
    end
    local booth = Booths[boothId]
    if not booth then
        return
    end
    booth.speakers = booth.speakers or {}
    if #booth.speakers >= Config.MaxSpeakers then
        Permissions.Notify(src, Config.Locale.too_many_speakers, 'error')
        return
    end
    local packed = DJ.Vec(coords)
    if not packed then
        return
    end
    packed.model = Config.SpeakerModel
    packed.heading = 0.0
    booth.speakers[#booth.speakers + 1] = packed
    persistBooths()
    TriggerClientEvent('djbooth:upsertBooth', -1, publicBooth(booth))
    broadcastAudio(booth.id)
end)

RegisterNetEvent('djbooth:removeSpeaker', function(boothId, index)
    local src = source
    if not Permissions.IsAdmin(src) then
        return
    end
    local booth = Booths[boothId]
    if not booth or not booth.speakers then
        return
    end
    index = tonumber(index)
    if not index or not booth.speakers[index] then
        return
    end
    table.remove(booth.speakers, index)
    persistBooths()
    TriggerClientEvent('djbooth:upsertBooth', -1, publicBooth(booth))
    broadcastAudio(booth.id)
    TriggerClientEvent('djbooth:openAdminUi', src, { booths = publicList(), isAdmin = true })
end)

RegisterNetEvent('djbooth:playUrl', function(boothId, url, immediate)
    local src = source
    if rateLimited(src) then
        return
    end
    local booth = ensureBoothAccess(src, boothId)
    if not booth then
        return
    end
    local state = States[boothId]
    ResolveTrack(url, function(tracks, err)
        if err or not tracks then
            Permissions.Notify(src, err or Config.Locale.invalid_url, 'error')
            return
        end
        if immediate or not state.current then
            local first = table.remove(tracks, 1)
            for i = 1, #tracks do
                if #state.queue >= Config.MaxQueue then
                    break
                end
                state.queue[#state.queue + 1] = tracks[i]
            end
            playTrack(boothId, first, false)
        else
            for i = 1, #tracks do
                if #state.queue >= Config.MaxQueue then
                    Permissions.Notify(src, Config.Locale.queue_full, 'error')
                    break
                end
                state.queue[#state.queue + 1] = tracks[i]
            end
            broadcastAudio(boothId)
        end
    end)
end)

RegisterNetEvent('djbooth:control', function(boothId, action, value)
    local src = source
    local booth = ensureBoothAccess(src, boothId)
    if not booth then
        return
    end
    local state = States[boothId]
    if not state then
        return
    end

    if action == 'pause' then
        if not state.current then
            return
        end
        if not state.paused then
            state.elapsed = elapsedOf(state)
            state.paused = true
            state.playing = false
            state.pauseStarted = now()
            state.startedAt = 0
        end
    elseif action == 'resume' then
        if not state.current then
            return
        end
        state.paused = false
        state.playing = true
        state.startedAt = now()
    elseif action == 'stop' then
        state.current = nil
        state.playing = false
        state.paused = false
        state.elapsed = 0
        state.duration = 0
        state.startedAt = 0
        state.playToken = (state.playToken or 0) + 1
    elseif action == 'skip' then
        advance(boothId, 'skip')
        return
    elseif action == 'previous' then
        if state.current then
            playTrack(boothId, state.current, true)
        end
        return
    elseif action == 'seek' then
        if not state.current then
            return
        end
        local stamp = math.max(0, math.floor(tonumber(value) or 0))
        if state.duration and state.duration > 0 then
            stamp = math.min(stamp, math.max(0, state.duration - 1))
        end
        state.elapsed = stamp
        state.startedAt = state.paused and 0 or now()
        state.seekTo = stamp
        local snap = snapshotState(state)
        snap.seekTo = stamp
        TriggerClientEvent('djbooth:audioState', -1, boothId, snap)
        return
    elseif action == 'volume' then
        state.volume = DJ.Clamp(value, 0.0, Config.MaxVolume)
        booth.volume = state.volume
    elseif action == 'radius' then
        state.radius = DJ.Clamp(value, Config.MinRadius, Config.MaxRadius)
        booth.radius = state.radius
        persistBooths()
    elseif action == 'loop' then
        if value == 'track' or value == 'queue' or value == 'off' then
            state.loop = value
        end
    elseif action == 'shuffle' then
        state.shuffle = value and true or false
    end

    broadcastAudio(boothId)
end)

RegisterNetEvent('djbooth:queue', function(boothId, action, data)
    local src = source
    local booth = ensureBoothAccess(src, boothId)
    if not booth then
        return
    end
    local state = States[boothId]
    data = data or {}

    if action == 'clear' then
        state.queue = {}
    elseif action == 'remove' then
        local index = tonumber(data.index)
        if index and state.queue[index] then
            table.remove(state.queue, index)
        end
    elseif action == 'move' then
        local from = tonumber(data.from)
        local to = tonumber(data.to)
        if from and to and state.queue[from] then
            local track = table.remove(state.queue, from)
            to = DJ.Clamp(to, 1, #state.queue + 1)
            table.insert(state.queue, to, track)
        end
    elseif action == 'playIndex' then
        local index = tonumber(data.index)
        if index and state.queue[index] then
            local track = table.remove(state.queue, index)
            playTrack(boothId, track, true)
            return
        end
    elseif action == 'addTrack' then
        local track = data.track
        if type(track) == 'table' and DJ.IsValidMediaUrl(track.url) then
            if #state.queue >= Config.MaxQueue then
                Permissions.Notify(src, Config.Locale.queue_full, 'error')
                return
            end
            track.id = track.id or DJ.Uuid()
            state.queue[#state.queue + 1] = track
        end
    end

    broadcastAudio(boothId)
end)

RegisterNetEvent('djbooth:saveSong', function(data)
    local src = source
    local lib = playerLibrary(src)
    local url = data and data.url
    if not DJ.IsValidMediaUrl(url) then
        Permissions.Notify(src, Config.Locale.invalid_url, 'error')
        return
    end
    if #lib.songs >= Config.MaxSavedSongs then
        Permissions.Notify(src, 'Your library is full.', 'error')
        return
    end

    ResolveTrack(url, function(tracks, err)
        if err or not tracks or not tracks[1] then
            Permissions.Notify(src, err or Config.Locale.invalid_url, 'error')
            return
        end
        local track = tracks[1]
        if data.title and DJ.Trim(data.title) ~= '' then
            track.title = DJ.Trim(data.title)
        end
        for i = 1, #lib.songs do
            if lib.songs[i].url == track.url then
                Permissions.Notify(src, 'That track is already saved.', 'inform')
                pushLibrary(src)
                return
            end
        end
        lib.songs[#lib.songs + 1] = track
        persistLibrary()
        Permissions.Notify(src, Config.Locale.saved, 'success')
        pushLibrary(src)
    end)
end)

RegisterNetEvent('djbooth:deleteSong', function(songId)
    local src = source
    local lib = playerLibrary(src)
    for i = 1, #lib.songs do
        if lib.songs[i].id == songId then
            table.remove(lib.songs, i)
            persistLibrary()
            pushLibrary(src)
            return
        end
    end
end)

RegisterNetEvent('djbooth:playlist', function(boothId, data)
    local src = source
    data = data or {}
    local lib = playerLibrary(src)
    local action = data.action

    if action == 'create' then
        local name = DJ.Trim(data.name or '')
        if name == '' then
            name = 'Playlist'
        end
        if #lib.playlists >= Config.MaxPlaylists then
            Permissions.Notify(src, 'You cannot create more playlists.', 'error')
            return
        end
        lib.playlists[#lib.playlists + 1] = {
            id = DJ.Uuid(),
            name = name:sub(1, 32),
            tracks = {},
            createdAt = now(),
        }
        persistLibrary()
        Permissions.Notify(src, Config.Locale.playlist_created, 'success')
        pushLibrary(src)
        return
    end

    local playlist
    for i = 1, #lib.playlists do
        if lib.playlists[i].id == data.id then
            playlist = lib.playlists[i]
            break
        end
    end
    if not playlist and action ~= 'create' then
        return
    end

    if action == 'rename' then
        local name = DJ.Trim(data.name or '')
        if name ~= '' then
            playlist.name = name:sub(1, 32)
            persistLibrary()
            pushLibrary(src)
        end
    elseif action == 'delete' then
        for i = 1, #lib.playlists do
            if lib.playlists[i].id == playlist.id then
                table.remove(lib.playlists, i)
                break
            end
        end
        persistLibrary()
        pushLibrary(src)
    elseif action == 'add' then
        if #playlist.tracks >= Config.MaxPlaylistTracks then
            Permissions.Notify(src, Config.Locale.playlist_full, 'error')
            return
        end
        local track = data.track
        if type(track) ~= 'table' or not DJ.IsValidMediaUrl(track.url) then
            return
        end
        playlist.tracks[#playlist.tracks + 1] = {
            id = track.id or DJ.Uuid(),
            title = track.title or 'Track',
            author = track.author or '',
            url = track.url,
            thumbnail = track.thumbnail,
            source = track.source,
            duration = track.duration or 0,
        }
        persistLibrary()
        pushLibrary(src)
    elseif action == 'remove' then
        local index = tonumber(data.index)
        if index and playlist.tracks[index] then
            table.remove(playlist.tracks, index)
            persistLibrary()
            pushLibrary(src)
        end
    elseif action == 'queue' or action == 'play' then
        local booth = ensureBoothAccess(src, boothId)
        if not booth then
            return
        end
        local state = States[boothId]
        if action == 'play' and playlist.tracks[1] then
            local tracks = DJ.Copy(playlist.tracks)
            local first = table.remove(tracks, 1)
            state.queue = tracks
            playTrack(boothId, first, false)
        else
            for i = 1, #playlist.tracks do
                if #state.queue >= Config.MaxQueue then
                    break
                end
                state.queue[#state.queue + 1] = DJ.Copy(playlist.tracks[i])
            end
            if not state.current and state.queue[1] then
                advance(boothId, 'skip')
            else
                broadcastAudio(boothId)
            end
        end
    end
end)

RegisterNetEvent('djbooth:trackEnded', function(boothId, token)
    local state = States[boothId]
    if not state or not state.current then
        return
    end
    if token and state.playToken and token ~= state.playToken then
        return
    end
    if state.paused then
        return
    end
    local played = elapsedOf(state)
    if state.duration and state.duration > 5 and played < (state.duration - 4) then
        return
    end
    advance(boothId, 'ended')
end)

RegisterNetEvent('djbooth:reportDuration', function(boothId, duration)
    local src = source
    if OpenUi[src] ~= boothId then
        return
    end
    local state = States[boothId]
    duration = tonumber(duration) or 0
    if not state or duration <= 0 then
        return
    end
    if not state.duration or state.duration <= 0 or math.abs(state.duration - duration) > 2 then
        state.duration = duration
        if state.current then
            state.current.duration = duration
        end
    end
end)

exports('GetBooths', function()
    return publicList()
end)

exports('GetBoothState', function(boothId)
    return snapshotState(States[boothId] or defaultState())
end)
