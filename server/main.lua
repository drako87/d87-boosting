local playerState = {} -- [src] = { onMission, cooldown, missionId, missionInstance, trackerCount, vehicleNetId }

local function getState(src)
    if not playerState[src] then
        playerState[src] = { onMission = false, cooldown = false }
    end
    return playerState[src]
end

function IsBusyState(src)
    return getState(src).onMission
end

Bridge.RegisterUsableItem(Config.TabletItem, function(src)
    TriggerClientEvent('carboosting:client:openTablet', src)
end)

AddEventHandler('playerDropped', function()
    local state = playerState[source]
    if state and state.vehicleNetId then
        Trackers.Unregister(state.vehicleNetId)
    end
    playerState[source] = nil
end)

---------------------------------------------------------------
-- Solicitar misión
---------------------------------------------------------------
RegisterNetEvent('carboosting:server:requestMission', function(missionId)
    local src = source
    local mission = Config.Missions[missionId]
    if not mission then return end

    local state = getState(src)
    if state.onMission then
        Bridge.Notify(src, 'Ya tienes un trabajo en curso.', 'error')
        return
    end
    if ActiveContractPlayers and ActiveContractPlayers[src] then
        Bridge.Notify(src, 'Termina tu contrato actual antes de aceptar otro trabajo.', 'error')
        return
    end
    if state.cooldown then
        Bridge.Notify(src, 'Debes esperar antes de aceptar otro trabajo.', 'error')
        return
    end

    local instance = Economy.RollInstance(mission)
    local trackerCount = 0
    if mission.difficulty.trackerRequired then
        trackerCount = math.random(1, Config.TrackerMaxCount)
    end

    state.onMission = true
    state.missionId = missionId
    state.missionInstance = instance
    state.trackerCount = trackerCount
    state.vehicleNetId = nil

    TriggerClientEvent('carboosting:client:missionAccepted', src, missionId, instance, trackerCount)
end)

---------------------------------------------------------------
-- Registro del vehículo robado (para el sistema de rastreadores)
---------------------------------------------------------------
RegisterNetEvent('carboosting:server:registerMissionVehicle', function(netId)
    local src = source
    local state = getState(src)
    if not state.onMission or not state.missionId then return end

    local mission = Config.Missions[state.missionId]
    if not mission then return end

    state.vehicleNetId = netId

    if state.trackerCount and state.trackerCount > 0 then
        Trackers.Register(netId, src, state.trackerCount, mission.difficulty.skillDifficulty, function(newCount)
            state.trackerCount = newCount
            TriggerClientEvent('carboosting:client:missionTrackerUpdate', src, newCount)
        end)
    end
end)

---------------------------------------------------------------
-- Cancelar misión
---------------------------------------------------------------
RegisterNetEvent('carboosting:server:missionCancelled', function()
    local state = getState(source)
    if state.vehicleNetId then
        Trackers.Unregister(state.vehicleNetId)
    end
    state.onMission = false
    state.missionId = nil
    state.missionInstance = nil
    state.trackerCount = nil
    state.vehicleNetId = nil
end)

---------------------------------------------------------------
-- Entrega del vehículo
---------------------------------------------------------------
RegisterNetEvent('carboosting:server:carDelivered', function(missionId)
    local src = source
    local state = getState(src)
    if not state.onMission or state.missionId ~= missionId or not state.missionInstance then return end

    local mission = Config.Missions[missionId]
    if not mission then return end

    local trackerActive = state.vehicleNetId and Trackers.GetCount(state.vehicleNetId) > 0

    Economy.PayoutMission(src, mission, trackerActive, state.missionInstance)

    if state.vehicleNetId then
        Trackers.Unregister(state.vehicleNetId)
    end

    state.onMission = false
    state.missionId = nil
    state.missionInstance = nil
    state.trackerCount = nil
    state.vehicleNetId = nil
    state.cooldown = true

    SetTimeout(Config.Cooldown * 1000, function()
        state.cooldown = false
    end)
end)
