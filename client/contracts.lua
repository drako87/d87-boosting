local contracts = {}       -- contratos pendientes/en curso mostrados en la tablet
local contractActive = false
local activeContract = nil
local contractCar = nil
local contractPlate = nil
local contractColorLabel = nil
local contractInTargetCar = false
local contractEngineWasOn = false
local contractDropOffSet = false
local contractKeepLocation = nil
local contractKeepInProgress = false
local contractBlip = nil
local contractSearchBlip = nil
local contractTextUIShown = false
local contractTrackerActive = false
local contractTrackerRequestSent = false

function IsContractActive()
    return contractActive
end

local function generatePlate()
    local chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
    local plate = ''
    for i = 1, 8 do
        local idx = math.random(1, #chars)
        plate = plate .. chars:sub(idx, idx)
    end
    return plate
end

local function sendContractsToUI()
    local list = {}
    for _, c in pairs(contracts) do
        list[#list+1] = c
    end
    SendNUIMessage({ action = 'contractsUpdate', contracts = list })
end

---------------------------------------------------------------
-- Eventos del servidor
---------------------------------------------------------------
RegisterNetEvent('carboosting:client:contractUpdate', function(contract)
    local isNew = contracts[contract.id] == nil
    contracts[contract.id] = contract
    sendContractsToUI()
    if isNew and contract.status == 'pending' then
        Bridge.Notify('Nuevo contrato disponible en tu tablet.', 'inform')
    end
end)

RegisterNetEvent('carboosting:client:contractRemoved', function(id)
    contracts[id] = nil
    sendContractsToUI()

    if activeContract and activeContract.id == id and contractActive then
        cleanupContract()
    end
end)

RegisterNetEvent('carboosting:client:contractsList', function(list)
    contracts = {}
    for _, c in ipairs(list) do
        contracts[c.id] = c
    end
    sendContractsToUI()
end)

---------------------------------------------------------------
-- Callbacks NUI
---------------------------------------------------------------
RegisterNUICallback('contractAccept', function(data, cb)
    WantsToKeepVehicle = data.keep and true or false
    TriggerServerEvent('carboosting:server:acceptContract', tonumber(data.id))
    cb('ok')
end)

RegisterNUICallback('contractDelete', function(data, cb)
    TriggerServerEvent('carboosting:server:deleteContract', tonumber(data.id))
    cb('ok')
end)

RegisterNUICallback('contractTransfer', function(data, cb)
    TriggerServerEvent('carboosting:server:transferContract', tonumber(data.id), data.target)
    cb('ok')
end)

---------------------------------------------------------------
-- Contrato aceptado: spawnear vehículo en el punto de recogida
---------------------------------------------------------------
RegisterNetEvent('carboosting:client:contractAccepted', function(contract)
    if contractActive then return end

    activeContract = contract
    contractActive = true
    contractInTargetCar = false
    contractEngineWasOn = false
    contractDropOffSet = false
    contractKeepLocation = nil
    contractTrackerActive = contract.trackerRequired or false
    contractTrackerRequestSent = false

    local pickup = contract.pickup
    contractSearchBlip = AddBlipForCoord(pickup.x, pickup.y, pickup.z)
    SetBlipSprite(contractSearchBlip, 225)
    SetBlipColour(contractSearchBlip, 5)
    SetBlipAsShortRange(contractSearchBlip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(('Contrato: %s'):format(contract.tierLabel))
    EndTextCommandSetBlipName(contractSearchBlip)
    SetNewWaypoint(pickup.x, pickup.y)

    local hash = GetHashKey(contract.car)
    RequestModel(hash)
    while not HasModelLoaded(hash) do Wait(1) end

    contractCar = CreateVehicle(hash, pickup.x, pickup.y, pickup.z, 0.0, true, false)
    SetVehicleDoorsLocked(contractCar, 2)
    contractPlate = generatePlate()
    SetVehicleNumberPlateText(contractCar, contractPlate)

    local color = Config.VehicleColors[math.random(#Config.VehicleColors)]
    contractColorLabel = color.label
    SetVehicleColours(contractCar, color.id, color.id)

    local displayName = GetLabelText(GetDisplayNameFromVehicleModel(hash))
    local cardValue, cardLabel
    if WantsToKeepVehicle then
        cardValue = contract.keepCost .. ' cripto'
        cardLabel = 'Precio de compra'
    else
        cardValue = contract.reward .. ' cripto'
        cardLabel = 'Ganancia (entrega)'
    end
    ShowVehicleCard(displayName, contractPlate, contractColorLabel, cardValue, cardLabel)

    SetModelAsNoLongerNeeded(hash)

    if contract.guardCount and contract.guardCount > 0 then
        SpawnGuards(pickup, contract.guardCount, contract.guardWeapons)
    end

    Bridge.Notify(('Contrato aceptado: roba un %s y llévalo al punto de entrega.'):format(contract.car), 'inform')
end)

local function hideContractTextUI()
    if contractTextUIShown then
        lib.hideTextUI()
        contractTextUIShown = false
    end
end

function cleanupContract()
    contractActive = false
    activeContract = nil
    contractInTargetCar = false
    contractEngineWasOn = false
    contractDropOffSet = false
    contractKeepLocation = nil
    contractCar = nil
    contractTrackerActive = false
    contractTrackerRequestSent = false
    WantsToKeepVehicle = false
    if contractSearchBlip then RemoveBlip(contractSearchBlip) contractSearchBlip = nil end
    if contractBlip then RemoveBlip(contractBlip) contractBlip = nil end
    ClearGuards()
    hideContractTextUI()
    HideVehicleCard()
end

---------------------------------------------------------------
-- Rastreador del contrato (solo si el contrato lo incluye)
---------------------------------------------------------------
RegisterNetEvent('carboosting:client:startContractTrackerRemoval', function(skillDifficulty)
    if not skillDifficulty or #skillDifficulty == 0 then return end

    CreateThread(function()
        local success = lib.skillCheck(skillDifficulty)
        if success then
            contractTrackerActive = false
            TriggerServerEvent('carboosting:server:contractTrackerRemoved')
            Bridge.Notify('¡Rastreador desactivado con éxito!', 'success')
        else
            contractTrackerRequestSent = false
            Bridge.Notify('Fallaste desactivando el rastreador. Vuelve a intentarlo.', 'error')
        end
    end)
end)

---------------------------------------------------------------
-- Quedarse con el vehículo del contrato: confirmación + barra de progreso
---------------------------------------------------------------
local function tryKeepContractVehicle()
    local cost = activeContract and activeContract.keepCost or 0
    local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)

    local alert = lib.alertDialog({
        header = '¿Quedarte con el vehículo?',
        content = ('Esto te costará %d cripto de tu cartera digital.'):format(cost),
        centered = true,
        cancel = true,
        labels = { confirm = 'Sí', cancel = 'No' },
    })

    if alert == 'confirm' then
        local success = lib.progressBar({
            duration = Config.KeepDuration,
            label = 'Adquiriendo el vehículo...',
            useWhileDead = false,
            canCancel = true,
            disable = { move = true, car = true, combat = true },
        })

        if success and contractActive and activeContract and DoesEntityExist(vehicle) then
            TriggerServerEvent('carboosting:server:keepContractVehicle', activeContract.id, contractPlate, activeContract.car)
        else
            Bridge.Notify('Cancelaste la adquisición del vehículo.', 'error')
        end
    else
        local ped = PlayerPedId()
        if DoesEntityExist(vehicle) then
            TaskLeaveVehicle(ped, vehicle, 0)
        end
        Wait(1500)
        TriggerServerEvent('carboosting:server:cancelContract')
        if contractCar and DoesEntityExist(contractCar) then DeleteEntity(contractCar) end
        cleanupContract()
    end

    contractKeepInProgress = false
end

RegisterNetEvent('carboosting:client:keepContractFailed', function()
    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)
    if DoesEntityExist(vehicle) then
        TaskLeaveVehicle(ped, vehicle, 0)
    end
    Wait(1500)
    if contractCar and DoesEntityExist(contractCar) then DeleteEntity(contractCar) end
    cleanupContract()
end)

---------------------------------------------------------------
-- Bucle: guardias, robar, encender motor, entregar o quedarse el vehículo
---------------------------------------------------------------
CreateThread(function()
    while true do
        Wait(0)
        if contractActive and activeContract and contractCar and DoesEntityExist(contractCar) then
            local playerPed = PlayerPedId()

            if not contractInTargetCar and AreGuardsAlive() then
                local pickup = activeContract.pickup
                local dist = #(GetEntityCoords(playerPed) - vector3(pickup.x, pickup.y, pickup.z))
                if dist <= Config.GuardTriggerDistance then
                    TriggerGuardsAttack()
                end
            end

            if IsPedInAnyVehicle(playerPed, false) then
                local vehicle = GetVehiclePedIsIn(playerPed, false)
                if vehicle == contractCar and not contractInTargetCar then
                    contractInTargetCar = true
                    if contractSearchBlip then RemoveBlip(contractSearchBlip) contractSearchBlip = nil end
                    if GetResourceState('ps-dispatch') == 'started' then
                        exports['ps-dispatch']:CarBoosting(vehicle)
                    end

                    if contractTrackerActive and not contractTrackerRequestSent then
                        contractTrackerRequestSent = true
                        TriggerServerEvent('carboosting:server:requestContractTrackerRemoval', activeContract.id)
                    end
                end

                if contractInTargetCar and not contractDropOffSet then
                    local engineOn = GetIsVehicleEngineRunning(vehicle)
                    if engineOn and not contractEngineWasOn then
                        if WantsToKeepVehicle then
                            contractKeepLocation = Config.KeepLocations[math.random(#Config.KeepLocations)]
                            contractBlip = AddBlipForCoord(contractKeepLocation.x, contractKeepLocation.y, contractKeepLocation.z)
                            SetBlipSprite(contractBlip, 225)
                            SetBlipColour(contractBlip, 5)
                            SetBlipAsShortRange(contractBlip, true)
                            BeginTextCommandSetBlipName('STRING')
                            AddTextComponentString('Comprador de Vehículos')
                            EndTextCommandSetBlipName(contractBlip)
                            SetNewWaypoint(contractKeepLocation.x, contractKeepLocation.y)
                            Bridge.Notify('Ruta trazada. Llega sin bajarte y pulsa E para quedarte el vehículo.', 'inform')
                        else
                            local dropoff = activeContract.dropoff
                            contractBlip = AddBlipForCoord(dropoff.x, dropoff.y, dropoff.z)
                            SetBlipSprite(contractBlip, 225)
                            SetBlipColour(contractBlip, 2)
                            SetBlipAsShortRange(contractBlip, true)
                            BeginTextCommandSetBlipName('STRING')
                            AddTextComponentString('Entrega del Contrato')
                            EndTextCommandSetBlipName(contractBlip)
                            SetNewWaypoint(dropoff.x, dropoff.y)
                            Bridge.Notify('Ruta trazada. Llega sin bajarte y pulsa E para entregar.', 'inform')
                        end
                        contractDropOffSet = true
                    end
                    contractEngineWasOn = engineOn
                end

                if contractInTargetCar and contractDropOffSet and not contractKeepInProgress then
                    local target = WantsToKeepVehicle and contractKeepLocation or activeContract.dropoff
                    if target then
                        local dist = #(GetEntityCoords(playerPed) - vector3(target.x, target.y, target.z))

                        DrawMarker(1, target.x, target.y, target.z - 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 2.0, 2.0, 1.0, 255, 194, 44, 140, false, false, 2, false, nil, nil, false)

                        if dist <= Config.ContractInteractDistance then
                            if not contractTextUIShown then
                                lib.showTextUI(WantsToKeepVehicle and '[E] Quedarme con el vehículo' or '[E] Entregar vehículo', { position = 'right-center' })
                                contractTextUIShown = true
                            end
                            if IsControlJustPressed(0, 51) then
                                if WantsToKeepVehicle then
                                    contractKeepInProgress = true
                                    hideContractTextUI()
                                    CreateThread(tryKeepContractVehicle)
                                else
                                    TriggerServerEvent('carboosting:server:completeContract', activeContract, contractTrackerActive)
                                    if DoesEntityExist(contractCar) then DeleteEntity(contractCar) end
                                    cleanupContract()
                                end
                            end
                        else
                            hideContractTextUI()
                        end
                    end
                end
            else
                if contractInTargetCar then
                    contractInTargetCar = false
                end
                hideContractTextUI()
            end
        end
    end
end)
