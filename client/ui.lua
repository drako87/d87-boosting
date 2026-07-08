function ShowVehicleCard(name, plate, colorLabel, rewardText, rewardLabel)
    SendNUIMessage({
        action = 'showCard',
        vehicle = name,
        plate = plate,
        color = colorLabel,
        reward = rewardText,
        rewardLabel = rewardLabel or 'Ganancia (entrega)',
    })
end

function HideVehicleCard()
    SendNUIMessage({ action = 'hideCard' })
end

-- Muestra/actualiza el nº de rastreadores en la tarjeta; se oculta solo al llegar a 0
function UpdateTrackerCount(count)
    SendNUIMessage({ action = 'updateTrackers', count = count })
end

function BuildRewardText(mission, instance)
    if mission.paymentType == 'crypto' then
        return instance.rewardCrypto .. ' cripto'
    elseif mission.paymentType == 'black_money' then
        return '$' .. instance.rewardBlackMoney .. ' (dinero negro)'
    else
        return instance.rewardCrypto .. ' cripto + $' .. instance.rewardBlackMoney .. ' (dinero negro)'
    end
end

local function paymentLabel(mission)
    if mission.paymentType == 'crypto' then
        return ('Cripto: %d-%d'):format(mission.reward.crypto.min, mission.reward.crypto.max)
    elseif mission.paymentType == 'black_money' then
        return ('Dinero negro: $%d-$%d'):format(mission.reward.black_money.min, mission.reward.black_money.max)
    else
        return ('Cripto: %d-%d + Dinero negro: $%d-$%d'):format(
            mission.reward.crypto.min, mission.reward.crypto.max,
            mission.reward.black_money.min, mission.reward.black_money.max)
    end
end

local function buildDescription(mission)
    local lines = {}
    lines[#lines+1] = mission.description
    lines[#lines+1] = ('Vigilantes armados: %d'):format(mission.difficulty.npcGuards.max)
    lines[#lines+1] = ('Rastreador: %s'):format(mission.difficulty.trackerRequired and 'Sí' or 'No')
    if #mission.requirements > 0 then
        lines[#lines+1] = ('Requiere: %s'):format(table.concat(mission.requirements, ', '))
    end
    lines[#lines+1] = ('Pago: %s'):format(paymentLabel(mission))
    return table.concat(lines, '\n')
end

function OpenMissionMenu(onSelect)
    local options = {}
    for id, mission in pairs(Config.Missions) do
        options[#options+1] = {
            title = mission.label,
            description = buildDescription(mission),
            icon = mission.icon or 'car',
            onSelect = function()
                onSelect(id)
            end,
        }
    end
    table.sort(options, function(a, b) return a.title < b.title end)

    lib.registerContext({
        id = 'carboosting_menu',
        title = 'Trabajos de Vehículos',
        options = options,
    })
    lib.showContext('carboosting_menu')
end
