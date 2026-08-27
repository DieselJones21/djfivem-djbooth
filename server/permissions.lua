Permissions = {}

local qbCore
local esx
local frameworkName

local function detectFramework()
    if Config.Framework ~= 'auto' then
        return Config.Framework
    end
    if GetResourceState('qbx_core') == 'started' then
        return 'qbx'
    end
    if GetResourceState('qb-core') == 'started' then
        return 'qb'
    end
    if GetResourceState('es_extended') == 'started' then
        return 'esx'
    end
    return 'standalone'
end

CreateThread(function()
    Wait(200)
    frameworkName = detectFramework()
    if frameworkName == 'qb' or frameworkName == 'qbx' then
        qbCore = exports['qb-core'] and exports['qb-core']:GetCoreObject() or nil
    elseif frameworkName == 'esx' then
        esx = exports['es_extended'] and exports['es_extended']:getSharedObject() or nil
    end
end)

function Permissions.GetIdentifier(src)
    local license = GetPlayerIdentifierByType(src, 'license2') or GetPlayerIdentifierByType(src, 'license')
    return license or ('src:%s'):format(src)
end

function Permissions.IsAdmin(src)
    if src == 0 then
        return true
    end
    if IsPlayerAceAllowed(src, Config.AdminAce) or IsPlayerAceAllowed(src, 'command.' .. Config.AdminCommand) then
        return true
    end

    local identifier = Permissions.GetIdentifier(src)
    for i = 1, #Config.AdminIdentifiers do
        if Config.AdminIdentifiers[i] == identifier then
            return true
        end
        for _, idType in ipairs({ 'license', 'license2', 'discord', 'fivem', 'steam' }) do
            local value = GetPlayerIdentifierByType(src, idType)
            if value and value == Config.AdminIdentifiers[i] then
                return true
            end
        end
    end

    if frameworkName == 'qbx' then
        if qbCore then
            local player = qbCore.Functions.GetPlayer(src)
            if player then
                local perms = player.PlayerData.permission or player.PlayerData.group
                for i = 1, #Config.QBAdminPermissions do
                    if perms == Config.QBAdminPermissions[i] then
                        return true
                    end
                    if qbCore.Functions.HasPermission and qbCore.Functions.HasPermission(src, Config.QBAdminPermissions[i]) then
                        return true
                    end
                end
            end
        end
        if GetResourceState('qbx_core') == 'started' then
            for i = 1, #Config.QBAdminPermissions do
                local ok, allowed = pcall(function()
                    return exports.qbx_core:HasPermission(src, Config.QBAdminPermissions[i])
                end)
                if ok and allowed then
                    return true
                end
            end
        end
    elseif frameworkName == 'qb' and qbCore then
        for i = 1, #Config.QBAdminPermissions do
            if qbCore.Functions.HasPermission(src, Config.QBAdminPermissions[i]) then
                return true
            end
        end
    elseif frameworkName == 'esx' and esx then
        local player = esx.GetPlayerFromId(src)
        if player then
            local group = player.getGroup and player.getGroup() or player.group
            for i = 1, #Config.ESXAdminGroups do
                if group == Config.ESXAdminGroups[i] then
                    return true
                end
            end
        end
    end

    return false
end

function Permissions.GetJob(src)
    if frameworkName == 'qbx' then
        local ok, player = pcall(function()
            return exports.qbx_core:GetPlayer(src)
        end)
        if ok and player and player.PlayerData and player.PlayerData.job then
            local job = player.PlayerData.job
            return job.name, (job.grade and (job.grade.level or job.grade)) or 0, job.label
        end
    end

    if (frameworkName == 'qb' or frameworkName == 'qbx') and qbCore then
        local player = qbCore.Functions.GetPlayer(src)
        if player and player.PlayerData and player.PlayerData.job then
            local job = player.PlayerData.job
            return job.name, (job.grade and job.grade.level) or 0, job.label
        end
    end

    if frameworkName == 'esx' and esx then
        local player = esx.GetPlayerFromId(src)
        if player and player.job then
            return player.job.name, player.job.grade or 0, player.job.label
        end
    end

    return nil, 0, nil
end

function Permissions.CanUseBooth(src, booth)
    if Permissions.IsAdmin(src) then
        return true
    end
    if not booth then
        return false
    end
    if not booth.jobs or #booth.jobs == 0 then
        return Config.AllowPublicBooths
    end

    local job, grade = Permissions.GetJob(src)
    if not job then
        return false
    end

    for i = 1, #booth.jobs do
        local entry = booth.jobs[i]
        local name = type(entry) == 'table' and entry.name or entry
        local minGrade = type(entry) == 'table' and (entry.grade or 0) or 0
        if name == job and grade >= minGrade then
            return true
        end
    end

    return false
end

function Permissions.Notify(src, message, kind)
    TriggerClientEvent('djbooth:notify', src, message, kind or 'inform')
end
