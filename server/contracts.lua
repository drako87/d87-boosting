Contracts = {}

local playerData = {} -- [identifier] = { contracts = {}, recentCars = {}, nextContractAt = 0 }
local contractCounter = 0
ActiveContractPlayers = {} -- [src] = true mientras el jugador tiene un contrato en curso

local function getData(identifier)
    if not playerData[identifier] then
        playerData[identifier] = { contracts = {}, recentCars = {}, nextContractAt = 0 }
    end
    return playerData[identifier]
end

local function countContracts(data)
    local n = 0
    for _ in pairs(data.contracts) do n = n + 1 end
    return n
end

local function getCompletedCount(identifier)
    return MySQL.scalar.await('SELECT completed FROM d87_contract_stats WHERE identifier = ?', { identifier }) or 0
end

local function pickTier(identifier)
    local completed = getCompletedCount(identifier)
    local tier = Config.ContractTiers[1]
    for _, t in ipairs(Config.ContractTiers) do
        if completed >= t.minCompleted then tier = t end
    end
    return tier
end

local function pickCar(pool, recent)
    local candidates = {}
    for _, car in ipairs(pool) do
        local isRecent = false
        for _, r in ipairs(recent) do
            if r == car then isRecent = true break end
        end
        if not isRecent then candidates[#candidates+1] = car end
    end
    if #candidates == 0 then candidates = pool end
    return candidates[math.random(#candidates)]
end

-- Elimina los contratos pendientes más viejos para hacer hueco (nunca borra los que están en curso)
local function purgeOldest(data, amount)
    local pending = {}
    for id, c in pairs(data.contracts) do
        if c.status == 'pending' then
            pending[#pending+1] = c
        end
    end
    table.sort(pending, function(a, b) return a.createdAt < b.createdAt end)

    for i = 1, math.min(amount, #pending) do
        data.contracts[pending[i].id] = nil
        Contracts.PendingRemoved(pending[i])
    end
end

-- Se sobreescribe más abajo con acceso a TriggerClientEvent (necesita el src del jugador)
function Contracts.PendingRemoved(_) end

local function generateContract(identifier, data)
    local tier = pickTier(identifier)
    local car = pickCar(tier.cars, data.recentCars)

    table.insert(data.recentCars, car)
    if #data.recentCars > Config.ContractRecentMemory then
        table.remove(data.recentCars, 1)
    end

    local pickup = Config.SpawnLocations[math.random(#Config.SpawnLocations)]
    local dropoff = Config.DropOffLocations[math.random(#Config.DropOffLocations)]
    local reward = math.random(tier.reward.min, tier.reward.max)
    local keepCost = math.random(tier.keepCost.min, tier.keepCost.max)
    local guardCount = math.random(tier.guardCount.min, tier.guardCount.max)

    local hasTracker = (tier.trackerChance or 0) > 0 and math.random(100) <= tier.trackerChance
    local trackerCount = hasTracker and math.random(1, Config.TrackerMaxCount) or 0

    contractCounter = contractCounter + 1

    return {
        id = contractCounter,
        car = car,
        pickup = { x = pickup.x, y = pickup.y, z = pickup.z },
        dropoff = { x = dropoff.x, y = dropoff.y, z = dropoff.z },
        reward = reward,
        keepCost = keepCost,
        guardCount = guardCount,
        guardWeapons = tier.guardWeapons,
        trackerRequired = hasTracker,
        trackerCount = trackerCount,
        vehicleNetId = nil,
        skillDifficulty = tier.skillDifficulty,
        tierLevel = tier.level,
        tierLabel = tier.label,
        tierColor = tier.color,
        status = 'pending',
        createdAt = os.time(),
    }
end

function Contracts.Tick(src)
    local identifier = Wallet.GetIdentifier(src)
    if not identifier then return end

    local data = getData(identifier)
    local now = os.time()

    if now >= data.nextContractAt then
        if countContracts(data) >= Config.ContractMaxStored then
            purgeOldest(data, Config.ContractPurgeCount)
        end

        if countContracts(data) < Config.ContractMaxStored then
            local contract = generateContract(identifier, data)
            data.contracts[contract.id] = contract
            data.nextContractAt = now + math.random(Config.ContractIntervalMin, Config.ContractIntervalMax)
            TriggerClientEvent('carboosting:client:contractUpdate', src, contract)
        end
    end
end

-- Ahora que TriggerClientEvent está disponible, conectamos el aviso de purgado.
-- Guardamos el src actual del jugador cuya lista se está purgando mediante un contexto simple.
local purgingSrcContext = nil
Contracts.PendingRemoved = function(contract)
    if purgingSrcContext then
        TriggerClientEvent('carboosting:client:contractRemoved', purgingSrcContext, contract.id)
    end
end

local function tickWithContext(src)
    purgingSrcContext = src
    Contracts.Tick(src)
    purgingSrcContext = nil
end

CreateThread(function()
    while true do
        Wait(Config.ContractCheckInterval * 1000)
        for _, playerId in ipairs(GetPlayers()) do
            tickWithContext(tonumber(playerId))
        end
    end
end)

---------------------------------------------------------------
-- Eventos del jugador
---------------------------------------------------------------
RegisterNetEvent('carboosting:server:acceptContract', function(id)
    local src = source
    local identifier = Wallet.GetIdentifier(src)
    if not identifier then return end

    local data = getData(identifier)
    local contract = data.contracts[id]
    if not contract or contract.status ~= 'pending' then
        Bridge.Notify(src, 'Ese contrato ya no está disponible.', 'error')
        return
    end

    if (IsBusyState and IsBusyState(src)) or ActiveContractPlayers[src] then
        Bridge.Notify(src, 'Termina tu trabajo actual antes de aceptar un contrato.', 'error')
        return
    end

    contract.status = 'in_progress'
    ActiveContractPlayers[src] = true
    TriggerClientEvent('carboosting:client:contractUpdate', src, contract)
    TriggerClientEvent('carboosting:client:contractAccepted', src, contract)
end)

RegisterNetEvent('carboosting:server:deleteContract', function(id)
    local src = source
    local identifier = Wallet.GetIdentifier(src)
    if not identifier then return end

    local data = getData(identifier)
    local contract = data.contracts[id]
    if contract and contract.status == 'pending' then
        data.contracts[id] = nil
        TriggerClientEvent('carboosting:client:contractRemoved', src, id)
    end
end)

RegisterNetEvent('carboosting:server:transferContract', function(id, targetServerId)
    local src = source
    local identifier = Wallet.GetIdentifier(src)
    if not identifier then return end

    local data = getData(identifier)
    local contract = data.contracts[id]
    if not contract or contract.status ~= 'pending' then
        Bridge.Notify(src, 'Ese contrato ya no está disponible.', 'error')
        return
    end

    local targetSrc = tonumber(targetServerId)
    if not targetSrc or not GetPlayerName(targetSrc) then
        Bridge.Notify(src, 'Jugador no encontrado.', 'error')
        return
    end
    if targetSrc == src then
        Bridge.Notify(src, 'No puedes traspasarte el contrato a ti mismo.', 'error')
        return
    end

    local targetIdentifier = Wallet.GetIdentifier(targetSrc)
    if not targetIdentifier then
        Bridge.Notify(src, 'No se pudo identificar al jugador destino.', 'error')
        return
    end

    local targetData = getData(targetIdentifier)
    if countContracts(targetData) >= Config.ContractMaxStored then
        Bridge.Notify(src, 'Ese jugador tiene su lista de contratos llena.', 'error')
        return
    end

    data.contracts[id] = nil
    targetData.contracts[id] = contract

    TriggerClientEvent('carboosting:client:contractRemoved', src, id)
    TriggerClientEvent('carboosting:client:contractUpdate', targetSrc, contract)
    Bridge.Notify(src, 'Contrato traspasado correctamente.', 'success')
    Bridge.Notify(targetSrc, 'Has recibido un contrato de otro jugador.', 'inform')
end)

RegisterNetEvent('carboosting:server:completeContract', function(contractData)
    local src = source
    local identifier = Wallet.GetIdentifier(src)
    if not identifier then return end

    ActiveContractPlayers[src] = nil

    local id = contractData and contractData.id
    local storedContract = id and getData(identifier).contracts[id]

    local trackerActive = false
    if storedContract then
        trackerActive = storedContract.vehicleNetId and Trackers.GetCount(storedContract.vehicleNetId) > 0 or false
        if storedContract.vehicleNetId then
            Trackers.Unregister(storedContract.vehicleNetId)
        end
    end

    if id then
        getData(identifier).contracts[id] = nil
        TriggerClientEvent('carboosting:client:contractRemoved', src, id)
    end

    local reward = tonumber(contractData and contractData.reward)
    if not reward or reward <= 0 then return end

    local multiplier = trackerActive and Config.ContractTrackerPenalty or 1.0
    local amount = math.floor(reward * multiplier)

    local credited = Wallet.AddBalance(src, amount)
    if credited then
        if multiplier < 1.0 then
            Bridge.Notify(src, ('Entregado con rastreador(es) activo(s). Pago reducido: %d cripto.'):format(amount), 'warning')
        else
            Bridge.Notify(src, ('Contrato completado. Has recibido %d cripto.'):format(amount), 'success')
        end
    else
        Bridge.Notify(src, 'Contrato completado, pero necesitas una cartera digital para cobrar en cripto.', 'error')
    end

    MySQL.insert('INSERT INTO d87_contract_stats (identifier, completed) VALUES (?, 1) ON DUPLICATE KEY UPDATE completed = completed + 1', {
        identifier,
    })
end)

RegisterNetEvent('carboosting:server:cancelContract', function()
    local src = source
    ActiveContractPlayers[src] = nil

    local identifier = Wallet.GetIdentifier(src)
    if not identifier then return end

    local data = getData(identifier)
    for _, c in pairs(data.contracts) do
        if c.status == 'in_progress' and c.vehicleNetId then
            Trackers.Unregister(c.vehicleNetId)
            c.vehicleNetId = nil
        end
    end
end)

RegisterNetEvent('carboosting:server:keepContractVehicle', function(id, plate, model)
    local src = source
    local identifier = Wallet.GetIdentifier(src)
    if not identifier then return end

    local data = getData(identifier)
    local contract = data.contracts[id]
    if not contract or contract.status ~= 'in_progress' then return end

    local cost = contract.keepCost or 0
    local paid = Wallet.TryDeduct(src, cost)
    if not paid then
        Bridge.Notify(src, 'No se pudo cobrar el pago. Revisa tu cartera digital y saldo.', 'error')
        TriggerClientEvent('carboosting:client:keepContractFailed', src)
        return
    end

    if contract.vehicleNetId then
        Trackers.Unregister(contract.vehicleNetId)
    end

    MySQL.insert('INSERT INTO d87_owned_vehicles (identifier, model, plate) VALUES (?, ?, ?)', {
        identifier, model, plate,
    })

    local registered = Bridge.RegisterVehicle(src, model, plate)
    if not registered then
        Bridge.Notify(src, 'Aviso: no se pudo registrar el vehículo en tu garaje automáticamente. Contacta con un admin.', 'warning')
    end

    ActiveContractPlayers[src] = nil
    data.contracts[id] = nil
    TriggerClientEvent('carboosting:client:contractRemoved', src, id)
    Bridge.Notify(src, ('¡El vehículo ahora es tuyo! Se descontaron %d cripto de tu cartera.'):format(cost), 'success')

    MySQL.insert('INSERT INTO d87_contract_stats (identifier, completed) VALUES (?, 1) ON DUPLICATE KEY UPDATE completed = completed + 1', {
        identifier,
    })
end)

RegisterNetEvent('carboosting:server:requestContracts', function()
    local src = source
    local identifier = Wallet.GetIdentifier(src)
    if not identifier then return end

    local data = getData(identifier)
    local list = {}
    for _, contract in pairs(data.contracts) do
        list[#list+1] = contract
    end
    TriggerClientEvent('carboosting:client:contractsList', src, list)
end)

---------------------------------------------------------------
-- Registro del vehículo del contrato (sistema de rastreadores)
---------------------------------------------------------------
RegisterNetEvent('carboosting:server:registerContractVehicle', function(id, netId)
    local src = source
    local identifier = Wallet.GetIdentifier(src)
    if not identifier then return end

    local data = getData(identifier)
    local contract = data.contracts[id]
    if not contract or contract.status ~= 'in_progress' then return end

    contract.vehicleNetId = netId

    if contract.trackerCount and contract.trackerCount > 0 then
        Trackers.Register(netId, src, contract.trackerCount, contract.skillDifficulty, function(newCount)
            contract.trackerCount = newCount
            TriggerClientEvent('carboosting:client:contractTrackerUpdate', src, newCount)
        end)
    end
end)
