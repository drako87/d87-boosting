local playerState = {} -- [src] = { onMission, cooldown, missionId, missionInstance }

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

    state.onMission = true
    state.missionId = missionId
    state.missionInstance = instance

    TriggerClientEvent('carboosting:client:missionAccepted', src, missionId, instance)
end)

---------------------------------------------------------------
-- Cancelar misión
---------------------------------------------------------------
RegisterNetEvent('carboosting:server:missionCancelled', function()
    local state = getState(source)
    state.onMission = false
    state.missionId = nil
    state.missionInstance = nil
end)

---------------------------------------------------------------
-- Solicitud de retirar rastreador (valida hak_kit)
---------------------------------------------------------------
RegisterNetEvent('carboosting:server:requestTrackerRemoval', function(missionId)
    local src = source
    local mission = Config.Missions[missionId]
    if not mission or not mission.difficulty.trackerRequired then return end

    local hasKit = Bridge.GetItemCount(src, Config.TrackerKitItem) > 0
    if not hasKit then
        TriggerClientEvent('carboosting:client:trackerKitMissing', src)
        return
    end

    TriggerClientEvent('carboosting:client:startTrackerRemoval', src)
end)

RegisterNetEvent('carboosting:server:trackerRemoved', function()
    -- Confirmación informativa; el estado real lo controla el cliente y se valida en la entrega
end)

---------------------------------------------------------------
-- Entrega del vehículo
---------------------------------------------------------------
RegisterNetEvent('carboosting:server:carDelivered', function(missionId, trackerActive)
    local src = source
    local state = getState(src)
    if not state.onMission or state.missionId ~= missionId or not state.missionInstance then return end

    local mission = Config.Missions[missionId]
    if not mission then return end

    Economy.PayoutMission(src, mission, trackerActive, state.missionInstance)

    state.onMission = false
    state.missionId = nil
    state.missionInstance = nil
    state.cooldown = true

    SetTimeout(Config.Cooldown * 1000, function()
        state.cooldown = false
    end)
end)
