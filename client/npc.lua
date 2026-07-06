local activeGuards = {}
local guardsEngaged = false

function SpawnGuards(coords, count)
    local hash = GetHashKey(Config.GuardModel)
    RequestModel(hash)
    local timeout = GetGameTimer() + 3000
    while not HasModelLoaded(hash) and GetGameTimer() < timeout do
        Wait(0)
    end

    local weaponHash = GetHashKey(Config.GuardWeapon)

    for i = 1, count do
        local px = coords.x + math.random(-3, 3)
        local py = coords.y + math.random(-3, 3)
        local ped = CreatePed(4, hash, px, py, coords.z, 0.0, true, true)
        SetEntityAsMissionEntity(ped, true, true)
        GiveWeaponToPed(ped, weaponHash, 1, false, true)
        SetCurrentPedWeapon(ped, weaponHash, true)
        SetPedCombatAbility(ped, 2)
        SetPedCombatRange(ped, 2)
        SetPedCombatMovement(ped, 2)
        SetPedFleeAttributes(ped, 0, false)
        SetPedAccuracy(ped, 60)
        SetBlockingOfNonTemporaryEvents(ped, true)
        activeGuards[#activeGuards+1] = ped
    end

    SetModelAsNoLongerNeeded(hash)
    guardsEngaged = false
end

function TriggerGuardsAttack()
    if guardsEngaged then return end
    guardsEngaged = true
    local playerPed = PlayerPedId()
    for _, ped in ipairs(activeGuards) do
        if DoesEntityExist(ped) and not IsEntityDead(ped) then
            TaskCombatPed(ped, playerPed, 0, 16)
        end
    end
end

function AreGuardsAlive()
    for _, ped in ipairs(activeGuards) do
        if DoesEntityExist(ped) and not IsEntityDead(ped) then
            return true
        end
    end
    return false
end

function ClearGuards()
    for _, ped in ipairs(activeGuards) do
        if DoesEntityExist(ped) then
            DeleteEntity(ped)
        end
    end
    activeGuards = {}
    guardsEngaged = false
end
