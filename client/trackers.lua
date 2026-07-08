--[[
    Sistema de rastreadores (compartido entre misiones y contratos)

    Uso manual del hak_kit: el jugador (conductor o pasajero) debe estar
    dentro del vehículo objetivo para poder intentar desactivar un
    rastreador. No hay activación automática.
]]

local hakKitBusy = false

-- Los vehículos recién creados a veces tardan un instante en registrarse
-- en la red; esto evita el warning "no such entity" al pedir su netId
-- justo después de spawnearlos.
function GetVehicleNetId(vehicle, maxAttempts)
    maxAttempts = maxAttempts or 20
    local netId = 0
    local attempts = 0
    while attempts < maxAttempts do
        if not DoesEntityExist(vehicle) then return 0 end
        netId = NetworkGetNetworkIdFromEntity(vehicle)
        if netId ~= 0 then return netId end
        Wait(50)
        attempts = attempts + 1
    end
    return 0
end

RegisterNetEvent('carboosting:client:useHakKit', function()
    local ped = PlayerPedId()
    if not IsPedInAnyVehicle(ped, false) then
        Bridge.Notify('No estás dentro de ningún vehículo.', 'error')
        return
    end

    local vehicle = GetVehiclePedIsIn(ped, false)
    local netId = NetworkGetNetworkIdFromEntity(vehicle)
    TriggerServerEvent('carboosting:server:attemptTrackerRemoval', netId)
end)

RegisterNetEvent('carboosting:client:startHakKitCheck', function(skillDifficulty, netId)
    if not skillDifficulty or #skillDifficulty == 0 then return end
    if hakKitBusy then return end

    hakKitBusy = true
    CreateThread(function()
        local ok, success = pcall(lib.skillCheck, skillDifficulty)
        hakKitBusy = false
        TriggerServerEvent('carboosting:server:hakKitResult', netId, ok and success or false)
    end)
end)

RegisterNetEvent('carboosting:client:trackerKitMissing', function()
    Bridge.Notify(('Necesitas un %s para desactivar el rastreador.'):format(Config.TrackerKitItem), 'error')
end)
