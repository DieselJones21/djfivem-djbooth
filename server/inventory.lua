Inventory = {}

local function oxReady()
    return GetResourceState('ox_inventory') == 'started'
end

local function asSlot(slot)
    return DJ.SlotId(slot)
end

-- ox_inventory may return true, a remaining count (including 0), or an item table.
local function removedOk(result)
    if result == true then
        return true
    end
    if type(result) == 'number' then
        return true
    end
    if type(result) == 'table' then
        return true
    end
    return false
end

function Inventory.Remove(src, item, count, slot)
    count = count or 1
    slot = asSlot(slot)

    if oxReady() then
        local ok, result = pcall(function()
            return exports.ox_inventory:RemoveItem(src, item, count, nil, slot)
        end)
        if ok and removedOk(result) then
            return true
        end
        if slot then
            ok, result = pcall(function()
                return exports.ox_inventory:RemoveItem(src, item, count)
            end)
            if ok and removedOk(result) then
                return true
            end
        end
        return false
    end

    if GetResourceState('qb-core') == 'started' then
        local ok, player = pcall(function()
            return exports['qb-core']:GetCoreObject().Functions.GetPlayer(src)
        end)
        if ok and player then
            local removed = player.Functions.RemoveItem(item, count, slot)
            if removed or removedOk(removed) then
                return true
            end
        end
    end

    if GetResourceState('qbx_core') == 'started' then
        local ok, player = pcall(function()
            return exports.qbx_core:GetPlayer(src)
        end)
        if ok and player and player.Functions and player.Functions.RemoveItem then
            local removed = player.Functions.RemoveItem(item, count, slot)
            if removed or removedOk(removed) then
                return true
            end
        end
    end

    if GetResourceState('es_extended') == 'started' then
        local ok, ESX = pcall(function()
            return exports['es_extended']:getSharedObject()
        end)
        if ok and ESX then
            local xPlayer = ESX.GetPlayerFromId(src)
            if xPlayer then
                xPlayer.removeInventoryItem(item, count)
                return true
            end
        end
    end

    return Permissions.IsAdmin(src)
end

function Inventory.Add(src, item, count)
    count = count or 1
    if oxReady() then
        local ok, added = pcall(function()
            return exports.ox_inventory:AddItem(src, item, count)
        end)
        return ok and added and true or false
    end

    if GetResourceState('qb-core') == 'started' then
        local ok, player = pcall(function()
            return exports['qb-core']:GetCoreObject().Functions.GetPlayer(src)
        end)
        if ok and player then
            player.Functions.AddItem(item, count)
            return true
        end
    end

    if GetResourceState('qbx_core') == 'started' then
        local ok, player = pcall(function()
            return exports.qbx_core:GetPlayer(src)
        end)
        if ok and player and player.Functions and player.Functions.AddItem then
            player.Functions.AddItem(item, count)
            return true
        end
    end

    if GetResourceState('es_extended') == 'started' then
        local ok, ESX = pcall(function()
            return exports['es_extended']:getSharedObject()
        end)
        if ok and ESX then
            local xPlayer = ESX.GetPlayerFromId(src)
            if xPlayer then
                xPlayer.addInventoryItem(item, count)
                return true
            end
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
