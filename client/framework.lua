Framework = {
    name = 'standalone',
}

local qbCore
local esx

local function detect()
    local configured = Config.Framework
    if configured == 'auto' then
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
    return configured
end

CreateThread(function()
    Wait(250)
    Framework.name = detect()

    if Framework.name == 'qb' or Framework.name == 'qbx' then
        qbCore = exports['qb-core'] and exports['qb-core']:GetCoreObject() or nil
    elseif Framework.name == 'esx' then
        esx = exports['es_extended'] and exports['es_extended']:getSharedObject() or nil
    end
end)

function Framework.GetJob()
    if Framework.name == 'qbx' then
        local data = exports.qbx_core:GetPlayerData()
        if data and data.job then
            return data.job.name, (data.job.grade and (data.job.grade.level or data.job.grade)) or 0
        end
    elseif Framework.name == 'qb' and qbCore then
        local data = qbCore.Functions.GetPlayerData()
        if data and data.job then
            return data.job.name, (data.job.grade and data.job.grade.level) or 0
        end
    elseif Framework.name == 'esx' and esx then
        local data = esx.GetPlayerData and esx.GetPlayerData()
        if data and data.job then
            return data.job.name, data.job.grade or 0
        end
    end

    return nil, 0
end

function Framework.Notify(message, kind)
    kind = DJ.NotifyType(kind)
    if GetResourceState('ox_lib') == 'started' then
        exports.ox_lib:notify({
            title = Config.Notify.prefix,
            description = message,
            type = kind == 'inform' and 'info' or kind,
        })
        return
    end

    if (Framework.name == 'qb' or Framework.name == 'qbx') and qbCore then
        qbCore.Functions.Notify(message, kind == 'inform' and 'primary' or kind)
        return
    end

    if Framework.name == 'esx' and esx then
        esx.ShowNotification(message)
        return
    end

    BeginTextCommandThefeedPost('STRING')
    AddTextComponentSubstringPlayerName(message)
    EndTextCommandThefeedPostTicker(false, false)
end
