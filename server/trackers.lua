--[[
    Sistema de rastreadores (compartido entre misiones y contratos)

    Cada vehículo con rastreador(es) se registra aquí por su netId.
    Cualquier jugador dentro del vehículo puede usar el hak_kit para
    intentar desactivar UN rastreador a la vez (no es automático).
]]

Trackers = {}

local registry = {} -- [netId] = { ownerSrc, count, lastAttempt, skillDifficulty, onUpdate }

-- Registra un vehículo con rastreadores activos
function Trackers.Register(netId, ownerSrc, count, skillDifficulty, onUpdate)
    registry[netId] = {
        ownerSrc = ownerSrc,
        count = count,
        lastAttempt = 0,
        busy = false, -- true mientras un jugador tiene el minijuego abierto
        skillDifficulty = skillDifficulty or {},
        onUpdate = onUpdate,
    }
end

function Trackers.Unregister(netId)
    if netId then registry[netId] = nil end
end

function Trackers.GetCount(netId)
    local entry = netId and registry[netId]
    return entry and entry.count or 0
end

---------------------------------------------------------------
-- Intento de desactivación (cualquier jugador dentro del vehículo)
---------------------------------------------------------------
RegisterNetEvent('carboosting:server:attemptTrackerRemoval', function(netId)
    local src = source
    local entry = registry[netId]

    if not entry or entry.count <= 0 then
        Bridge.Notify(src, 'No hay ningún rastreador que desactivar aquí.', 'error')
        return
    end

    if entry.busy then
        Bridge.Notify(src, 'Ya hay una desactivación en curso en este vehículo.', 'error')
        return
    end

    local now = GetGameTimer()
    if now - entry.lastAttempt < Config.TrackerDeactivateCooldown then
        Bridge.Notify(src, 'Espera unos segundos antes de intentar desactivar otro rastreador.', 'error')
        return
    end

    local hasKit = Bridge.GetItemCount(src, Config.TrackerKitItem) > 0
    if not hasKit then
        TriggerClientEvent('carboosting:client:trackerKitMissing', src)
        return
    end

    entry.busy = true
    TriggerClientEvent('carboosting:client:startHakKitCheck', src, entry.skillDifficulty, netId)
end)

RegisterNetEvent('carboosting:server:hakKitResult', function(netId, success)
    local src = source
    local entry = registry[netId]
    if not entry then return end

    entry.busy = false
    entry.lastAttempt = GetGameTimer()

    if success then
        entry.count = math.max(0, entry.count - 1)
        Bridge.Notify(src, ('Rastreador desactivado. Quedan %d.'):format(entry.count), 'success')
        if entry.onUpdate then entry.onUpdate(entry.count) end
    else
        Bridge.Notify(src, 'Fallaste desactivando el rastreador. Vuelve a intentarlo.', 'error')
    end
end)

---------------------------------------------------------------
-- Item usable (no se consume): avisa al cliente para que compruebe
-- si está dentro de un vehículo con rastreadores activos.
---------------------------------------------------------------
Bridge.RegisterUsableItem(Config.TrackerKitItem, function(src)
    TriggerClientEvent('carboosting:client:useHakKit', src)
end)
