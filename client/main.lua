local boosting = false
local currentMission = nil
local currentInstance = nil
local targetCar = nil
local carLocation = nil
local dropOffLocation = nil
local spawnedCar = nil
local inTargetCar = false
local trackerActive = false
local dispatchSent = false
local dropOffEmailSent = false
local notificationShown = false
local cooldown = false

local searchZoneBlip = nil
local searchBlip = nil
local dropOffBlip = nil
local dropOffPed = nil
local vehiclePlate = nil
local vehicleColorLabel = nil
local engineWasOn = false

local function generatePlate()
    local chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
    local plate = ''
    for i = 1, 8 do
        local idx = math.random(1, #chars)
        plate = plate .. chars:sub(idx, idx)
    end
    return plate
end

---------------------------------------------------------------
-- Ped principal
---------------------------------------------------------------
CreateThread(function()
    local hash = GetHashKey(Config.PedModel)
    RequestModel(hash)
    while not HasModelLoaded(hash) do Wait(1) end

    local ped = CreatePed(4, hash, Config.PedLocation.x, Config.PedLocation.y, Config.PedLocation.z - 1.0, Config.PedLocation.w, false, true)
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)

    local function onInteract()
        if boosting then
            Bridge.Notify('Ya tienes un trabajo en curso.', 'error')
            return
        end
        if IsContractActive and IsContractActive() then
            Bridge.Notify('Termina tu contrato actual antes de aceptar otro trabajo.', 'error')
            return
        end
        if cooldown then
            Bridge.Notify('Debes esperar antes de aceptar otro trabajo.', 'error')
            return
        end
        OpenMissionMenu(function(missionId)
            TriggerServerEvent('carboosting:server:requestMission', missionId)
        end)
    end

    local function onCancel()
        TriggerEvent('carboosting:client:stopBoosting', true)
    end

    if Config.Target == 'qb' then
        exports['qb-target']:AddTargetEntity(ped, {
            options = {
                { type = 'client', action = onInteract, icon = 'fas fa-car', label = 'Ver trabajos', canInteract = function() return not boosting end },
                { type = 'client', action = onCancel, icon = 'fas fa-times', label = 'Cancelar trabajo', canInteract = function() return boosting end },
            },
            distance = 2.5,
        })
    else
        exports.ox_target:addLocalEntity(ped, {
            { onSelect = onInteract, icon = 'fas fa-car', label = 'Ver trabajos', distance = 2.5, canInteract = function() return not boosting end },
            { onSelect = onCancel, icon = 'fas fa-times', label = 'Cancelar trabajo', distance = 2.5, canInteract = function() return boosting end },
        })
    end

    local blip = AddBlipForCoord(Config.PedLocation.x, Config.PedLocation.y, Config.PedLocation.z)
    SetBlipSprite(blip, Config.PedBlip.sprite)
    SetBlipDisplay(blip, 4)
    SetBlipScale(blip, Config.PedBlip.scale)
    SetBlipColour(blip, Config.PedBlip.color)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(Config.PedBlip.label)
    EndTextCommandSetBlipName(blip)
end)

---------------------------------------------------------------
-- Utilidades
---------------------------------------------------------------
local function isVehicleNear(location, radius)
    local vehicle = GetClosestVehicle(location.x, location.y, location.z, radius, 0, 71)
    if vehicle ~= 0 then
        local c = GetEntityCoords(vehicle)
        return #(vector3(location.x, location.y, location.z) - c) < radius
    end
    return false
end

---------------------------------------------------------------
-- Inicio de misión (servidor confirma y envía los importes ya calculados)
---------------------------------------------------------------
RegisterNetEvent('carboosting:client:missionAccepted', function(missionId, instance)
    local mission = Config.Missions[missionId]
    if not mission or boosting then return end

    currentMission = mission
    currentInstance = instance
    targetCar = mission.cars[math.random(#mission.cars)]

    local spawn = Config.SpawnLocations[math.random(#Config.SpawnLocations)]
    carLocation = spawn

    searchZoneBlip = AddBlipForRadius(carLocation.x, carLocation.y, carLocation.z, Config.CarSearchRadius)
    SetBlipColour(searchZoneBlip, 1)
    SetBlipAlpha(searchZoneBlip, 128)

    if Config.Debug then
        searchBlip = AddBlipForCoord(carLocation.x, carLocation.y, carLocation.z)
        SetBlipSprite(searchBlip, 225)
        SetBlipColour(searchBlip, 1)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString('Vehículo objetivo (debug)')
        EndTextCommandSetBlipName(searchBlip)
    end

    local vehHash = GetHashKey(targetCar)
    RequestModel(vehHash)
    while not HasModelLoaded(vehHash) do Wait(1) end

    spawnedCar = CreateVehicle(vehHash, carLocation.x, carLocation.y, carLocation.z, 0.0, true, false)
    SetVehicleDoorsLocked(spawnedCar, 2)

    vehiclePlate = generatePlate()
    SetVehicleNumberPlateText(spawnedCar, vehiclePlate)

    local color = Config.VehicleColors[math.random(#Config.VehicleColors)]
    vehicleColorLabel = color.label
    SetVehicleColours(spawnedCar, color.id, color.id)

    local displayName = GetLabelText(GetDisplayNameFromVehicleModel(vehHash))
    local rewardText = BuildRewardText(mission, instance)
    ShowVehicleCard(displayName, vehiclePlate, vehicleColorLabel, rewardText)

    SetModelAsNoLongerNeeded(vehHash)

    local guardCount = math.random(mission.difficulty.npcGuards.min, mission.difficulty.npcGuards.max)
    if guardCount > 0 then
        SpawnGuards(carLocation, guardCount)
    end

    boosting = true
    trackerActive = mission.difficulty.trackerRequired
    dispatchSent = false
    dropOffEmailSent = false
    notificationShown = false

    Bridge.Notify(('Roba un %s. Cuidado, puede haber vigilantes armados.'):format(targetCar), 'inform')
end)

---------------------------------------------------------------
-- Cancelar
---------------------------------------------------------------
RegisterNetEvent('carboosting:client:stopBoosting', function(notify)
    if not boosting then return end
    TriggerServerEvent('carboosting:server:missionCancelled')
    boosting = false
    currentMission = nil
    currentInstance = nil
    targetCar = nil
    trackerActive = false
    if searchBlip then RemoveBlip(searchBlip) end
    if searchZoneBlip then RemoveBlip(searchZoneBlip) end
    if dropOffBlip then RemoveBlip(dropOffBlip) end
    if spawnedCar and DoesEntityExist(spawnedCar) then DeleteEntity(spawnedCar) end
    if dropOffPed and DoesEntityExist(dropOffPed) then DeleteEntity(dropOffPed) end
    ClearGuards()
    inTargetCar = false
    notificationShown = false
    engineWasOn = false
    HideVehicleCard()
    if notify then Bridge.Notify('Trabajo cancelado.', 'error') end
end)

---------------------------------------------------------------
-- Punto de entrega
---------------------------------------------------------------
local function setupDropOff()
    dropOffLocation = Config.DropOffLocations[math.random(#Config.DropOffLocations)]
    SetNewWaypoint(dropOffLocation.x, dropOffLocation.y)

    dropOffBlip = AddBlipForCoord(dropOffLocation.x, dropOffLocation.y, dropOffLocation.z)
    SetBlipSprite(dropOffBlip, 225)
    SetBlipColour(dropOffBlip, 1)
    SetBlipAsShortRange(dropOffBlip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString('Punto de Entrega')
    EndTextCommandSetBlipName(dropOffBlip)

    local hash = GetHashKey(Config.PedModel)
    RequestModel(hash)
    while not HasModelLoaded(hash) do Wait(1) end

    dropOffPed = CreatePed(4, hash, dropOffLocation.x, dropOffLocation.y, dropOffLocation.z - 1.0, dropOffLocation.w, false, true)
    FreezeEntityPosition(dropOffPed, true)
    SetEntityInvincible(dropOffPed, true)
    SetBlockingOfNonTemporaryEvents(dropOffPed, true)
    SetModelAsNoLongerNeeded(hash)

    local function canDeliver()
        return boosting and not inTargetCar and isVehicleNear(dropOffLocation, 10.0)
    end

    local function onDeliver()
        TriggerEvent('carboosting:client:completeOrder')
    end

    if Config.Target == 'qb' then
        exports['qb-target']:AddTargetEntity(dropOffPed, {
            options = { { type = 'client', action = onDeliver, icon = 'fas fa-check', label = 'Entregar vehículo', canInteract = canDeliver } },
            distance = 2.5,
        })
    else
        exports.ox_target:addLocalEntity(dropOffPed, {
            { onSelect = onDeliver, icon = 'fas fa-check', label = 'Entregar vehículo', distance = 2.5, canInteract = canDeliver },
        })
    end
end

---------------------------------------------------------------
-- Completar entrega
---------------------------------------------------------------
RegisterNetEvent('carboosting:client:completeOrder', function()
    if not (boosting and not inTargetCar and isVehicleNear(dropOffLocation, 10.0)) then
        Bridge.Notify('No hay ningún vehículo en la zona o sigues dentro.', 'error')
        return
    end

    TriggerServerEvent('carboosting:server:carDelivered', currentMission.id, trackerActive)

    boosting = false
    currentMission = nil
    currentInstance = nil
    targetCar = nil
    trackerActive = false
    if spawnedCar and DoesEntityExist(spawnedCar) then DeleteEntity(spawnedCar) end
    if dropOffBlip then RemoveBlip(dropOffBlip) end
    if dropOffPed and DoesEntityExist(dropOffPed) then DeleteEntity(dropOffPed) end
    ClearGuards()
    engineWasOn = false
    HideVehicleCard()

    cooldown = true
    Bridge.Notify(('Debes bajar el perfil durante %d segundos.'):format(Config.Cooldown), 'inform')
    SetTimeout(Config.Cooldown * 1000, function()
        cooldown = false
    end)
end)

---------------------------------------------------------------
-- Skill checks para quitar el rastreador
---------------------------------------------------------------
RegisterNetEvent('carboosting:client:startTrackerRemoval', function()
    if not currentMission then return end
    local diffs = currentMission.difficulty.skillDifficulty
    if not diffs or #diffs == 0 then return end

    CreateThread(function()
        local success = lib.skillCheck(diffs)
        if success then
            trackerActive = false
            TriggerServerEvent('carboosting:server:trackerRemoved')
            Bridge.Notify('¡Rastreador desactivado con éxito!', 'success')
        else
            Bridge.Notify('Fallaste desactivando el rastreador. Vuelve a intentarlo.', 'error')
        end
    end)
end)

RegisterNetEvent('carboosting:client:trackerKitMissing', function()
    Bridge.Notify(('Necesitas un %s para desactivar el rastreador.'):format(Config.TrackerKitItem), 'error')
end)

---------------------------------------------------------------
-- Bucle principal: detectar robo del vehículo, guardias, rastreador y entrega
---------------------------------------------------------------
CreateThread(function()
    while true do
        Wait(0)
        if boosting and targetCar then
            local playerPed = PlayerPedId()

            -- guardias atacan si el jugador se acerca al coche
            if carLocation and not inTargetCar and AreGuardsAlive() then
                local dist = #(GetEntityCoords(playerPed) - vector3(carLocation.x, carLocation.y, carLocation.z))
                if dist <= Config.GuardTriggerDistance then
                    TriggerGuardsAttack()
                end
            end

            if IsPedInAnyVehicle(playerPed, false) then
                local vehicle = GetVehiclePedIsIn(playerPed, false)
                local model = GetDisplayNameFromVehicleModel(GetEntityModel(vehicle)):lower()
                if model == targetCar:lower() and not inTargetCar then
                    inTargetCar = true

                    if not notificationShown then
                        Bridge.Notify(('Has robado el %s. Dirígete al punto de entrega.'):format(targetCar), 'success')
                        notificationShown = true
                    end

                    if not dispatchSent then
                        if GetResourceState('ps-dispatch') == 'started' then
                            exports['ps-dispatch']:CarBoosting(vehicle)
                        end
                        dispatchSent = true
                    end

                    if trackerActive then
                        TriggerServerEvent('carboosting:server:requestTrackerRemoval', currentMission.id)
                    end

                    if searchBlip then RemoveBlip(searchBlip) end
                    if searchZoneBlip then RemoveBlip(searchZoneBlip) end
                end

                -- Trazar ruta al punto de entrega al encender el motor
                if inTargetCar and not dropOffEmailSent then
                    local engineOn = GetIsVehicleEngineRunning(vehicle)
                    if engineOn and not engineWasOn then
                        setupDropOff()
                        Bridge.Notify('Ruta trazada al punto de entrega.', 'inform')
                        dropOffEmailSent = true
                    end
                    engineWasOn = engineOn
                end
            else
                if inTargetCar then
                    inTargetCar = false
                end
            end
        end
    end
end)

-- Aviso periódico a la policía si el rastreador sigue activo
CreateThread(function()
    while true do
        Wait(30000)
        if boosting and inTargetCar and trackerActive and GetResourceState('ps-dispatch') == 'started' then
            local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)
            exports['ps-dispatch']:CarBoosting(vehicle)
        end
    end
end)
