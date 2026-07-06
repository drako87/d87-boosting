Bridge = {}

local function detectFramework()
    if Config.Framework ~= 'auto' then return Config.Framework end
    if GetResourceState('qbx_core') == 'started' then return 'qbx'
    elseif GetResourceState('qb-core') == 'started' then return 'qb'
    elseif GetResourceState('es_extended') == 'started' then return 'esx'
    end
    return 'qb'
end

Bridge.Framework = detectFramework()

local Core = nil
local function GetCore()
    if Core then return Core end
    if Bridge.Framework == 'qb' then
        Core = exports['qb-core']:GetCoreObject()
    elseif Bridge.Framework == 'esx' then
        Core = exports['es_extended']:getSharedObject()
    elseif Bridge.Framework == 'qbx' then
        Core = exports.qbx_core
    end
    return Core
end

if IsDuplicityVersion() then
    ---------------------------------------------------------------
    -- SERVER
    ---------------------------------------------------------------
    function Bridge.GetPlayer(src)
        if Bridge.Framework == 'esx' then
            return GetCore().GetPlayerFromId(src)
        elseif Bridge.Framework == 'qbx' then
            return exports.qbx_core:GetPlayer(src)
        else
            return GetCore().Functions.GetPlayer(src)
        end
    end

    function Bridge.AddItem(src, item, count)
        if not item then return end
        if Config.Inventory == 'ox_inventory' then
            exports.ox_inventory:AddItem(src, item, count)
            return
        end
        local Player = Bridge.GetPlayer(src)
        if not Player then return end
        if Bridge.Framework == 'esx' then
            Player.addInventoryItem(item, count)
        else
            Player.Functions.AddItem(item, count)
        end
    end

    function Bridge.RemoveItem(src, item, count)
        if not item then return end
        if Config.Inventory == 'ox_inventory' then
            exports.ox_inventory:RemoveItem(src, item, count)
            return
        end
        local Player = Bridge.GetPlayer(src)
        if not Player then return end
        if Bridge.Framework == 'esx' then
            Player.removeInventoryItem(item, count)
        else
            Player.Functions.RemoveItem(item, count)
        end
    end

    function Bridge.GetItemCount(src, item)
        if not item then return 0 end
        if Config.Inventory == 'ox_inventory' then
            return exports.ox_inventory:GetItemCount(src, item) or 0
        end
        local Player = Bridge.GetPlayer(src)
        if not Player then return 0 end
        if Bridge.Framework == 'esx' then
            local it = Player.getInventoryItem(item)
            return it and it.count or 0
        else
            local it = Player.Functions.GetItemByName(item)
            return it and it.amount or 0
        end
    end

    function Bridge.AddMoney(src, moneyType, amount)
        if amount <= 0 then return end
        if moneyType == 'black_money' then
            Bridge.AddItem(src, Config.BlackMoneyItem, amount)
            return
        end
        local Player = Bridge.GetPlayer(src)
        if not Player then return end
        if Bridge.Framework == 'esx' then
            Player.addMoney(amount)
        else
            Player.Functions.AddMoney('cash', amount)
        end
    end

    function Bridge.Notify(src, msg, type)
        TriggerClientEvent('carboosting:client:notify', src, msg, type)
    end

    function Bridge.RegisterUsableItem(item, cb)
        CreateThread(function()
            if Bridge.Framework == 'esx' then
                local ok = pcall(function()
                    GetCore().RegisterUsableItem(item, function(src) cb(src) end)
                end)
                if not ok then
                    exports['es_extended']:RegisterUsableItem(item, function(src) cb(src) end)
                end
            elseif Bridge.Framework == 'qbx' then
                exports.qbx_core:CreateUseableItem(item, function(src) cb(src) end)
            else
                GetCore().Functions.CreateUseableItem(item, function(src) cb(src) end)
            end
        end)
    end

    -- Registra el vehículo en la tabla de garaje real del framework para
    -- que el jugador pueda sacarlo/guardarlo como cualquier otro coche suyo.
    function Bridge.RegisterVehicle(src, model, plate)
        local ok = false

        if Bridge.Framework == 'esx' then
            local identifier = GetPlayerIdentifierByType(src, 'license') or GetPlayerIdentifierByType(src, 'license2')
            if not identifier then return false end

            local vehicleProps = { model = GetHashKey(model), plate = plate }
            ok = pcall(function()
                MySQL.insert.await('INSERT INTO owned_vehicles (owner, plate, vehicle, type, stored) VALUES (?, ?, ?, ?, 1)', {
                    identifier, plate, json.encode(vehicleProps), 'car',
                })
            end)
        else
            local Player = Bridge.GetPlayer(src)
            if not Player or not Player.PlayerData then return false end
            local citizenid = Player.PlayerData.citizenid
            local license = Player.PlayerData.license
            if not citizenid then return false end

            ok = pcall(function()
                MySQL.insert.await('INSERT INTO player_vehicles (license, citizenid, vehicle, hash, mods, plate, garage, fuel, engine, body, state, depotprice) VALUES (?, ?, ?, ?, ?, ?, ?, 100, 1000.0, 1000.0, 1, 0)', {
                    license, citizenid, model, tostring(GetHashKey(model)), '{}', plate, Config.DefaultGarage,
                })
            end)
        end

        return ok and true or false
    end
else
    ---------------------------------------------------------------
    -- CLIENT
    ---------------------------------------------------------------
    RegisterNetEvent('carboosting:client:notify', function(msg, type)
        Bridge.Notify(msg, type)
    end)

    function Bridge.Notify(msg, type)
        lib.notify({ description = msg, type = type or 'inform' })
    end
end
