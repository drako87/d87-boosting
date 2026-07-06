Economy = {}

local function randomInRange(range)
    return math.random(range.min, range.max)
end

-- Genera los importes concretos de esta instancia de misión
-- (se calculan una sola vez para que la tarjeta que ve el jugador
-- coincida siempre con lo que realmente cobrará/pagará).
function Economy.RollInstance(mission)
    local instance = { rewardCrypto = 0, rewardBlackMoney = 0, keepCost = 0 }

    if mission.reward.crypto then
        instance.rewardCrypto = randomInRange(mission.reward.crypto)
    end
    if mission.reward.black_money then
        instance.rewardBlackMoney = randomInRange(mission.reward.black_money)
    end
    if mission.keepCost then
        instance.keepCost = randomInRange(mission.keepCost)
    end

    return instance
end

-- Calcula y paga la recompensa de una misión entregada
function Economy.PayoutMission(src, mission, trackerActive, instance)
    local multiplier = 1.0
    if mission.difficulty.trackerRequired and trackerActive then
        -- el jugador no desactivó el rastreador: penalización
        multiplier = mission.penaltyMultiplier
    end

    local paidParts = {}

    if instance.rewardCrypto and instance.rewardCrypto > 0 then
        local amount = math.floor(instance.rewardCrypto * multiplier)
        if amount > 0 then
            local credited = Wallet.AddBalance(src, amount)
            if credited then
                paidParts[#paidParts+1] = amount .. ' cripto (a tu cartera digital)'
            else
                paidParts[#paidParts+1] = 'cripto perdida (crea tu cartera digital con la tablet D87)'
            end
        end
    end

    if instance.rewardBlackMoney and instance.rewardBlackMoney > 0 then
        local amount = math.floor(instance.rewardBlackMoney * multiplier)
        if amount > 0 then
            Bridge.AddMoney(src, 'black_money', amount)
            paidParts[#paidParts+1] = '$' .. amount .. ' en dinero negro'
        end
    end

    local msg
    if multiplier < 1.0 then
        msg = ('Entregado con rastreador activo. Pago reducido: %s'):format(table.concat(paidParts, ' + '))
    else
        msg = ('Vehículo entregado. Has recibido: %s'):format(table.concat(paidParts, ' + '))
    end

    Bridge.Notify(src, msg, multiplier < 1.0 and 'warning' or 'success')
end
