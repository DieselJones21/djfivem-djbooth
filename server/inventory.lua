Inventory = {}

local function oxReady()
    return GetResourceState('ox_inventory') == 'started'
end

function Inventory.Remove(src, item, count, slot)
    count = count or 1
    if oxReady() then
        return exports.ox_inventory:RemoveItem(src, item, count, nil, slot) and true or false
    end

    if GetResourceState('qb-core') == 'started' then
        local player = exports['qb-core']:GetCoreObject().Functions.GetPlayer(src)
        if player then
            return player.Functions.RemoveItem(item, count, slot) and true or false
        end
    end

    if GetResourceState('es_extended') == 'started' then
        local ESX = exports['es_extended']:getSharedObject()
        local xPlayer = ESX.GetPlayerFromId(src)
        if xPlayer then
            xPlayer.removeInventoryItem(item, count)
            return true
        end
    end

    return Permissions.IsAdmin(src)
end

function Inventory.Add(src, item, count)
    count = count or 1
    if oxReady() then
        local added = exports.ox_inventory:AddItem(src, item, count)
        return added and true or false
    end

    if GetResourceState('qb-core') == 'started' then
        local player = exports['qb-core']:GetCoreObject().Functions.GetPlayer(src)
        if player then
            player.Functions.AddItem(item, count)
            return true
        end
    end

    if GetResourceState('es_extended') == 'started' then
        local ESX = exports['es_extended']:getSharedObject()
        local xPlayer = ESX.GetPlayerFromId(src)
        if xPlayer then
            xPlayer.addInventoryItem(item, count)
            return true
        end
    end

    return true
end

function Inventory.Has(src, item, count)
    count = count or 1
    if oxReady() then
        local total = exports.ox_inventory:GetItemCount(src, item) or 0
        return total >= count
    end
    return true
end
