TabletOpen = false

RegisterNetEvent('carboosting:client:openTablet', function()
    if TabletOpen then return end
    TabletOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'openTablet' })
    TriggerServerEvent('carboosting:server:requestContracts')
end)

local function closeTablet()
    if not TabletOpen then return end
    TabletOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'closeTablet' })
end

RegisterNUICallback('walletClose', function(_, cb)
    closeTablet()
    cb('ok')
end)

RegisterNUICallback('walletRegister', function(data, cb)
    local ok, message, balance = lib.callback.await('d87-boosting:wallet:register', false, data.username, data.password)
    cb({ ok = ok, message = message, balance = balance })
end)

RegisterNUICallback('walletLogin', function(data, cb)
    local ok, message, balance = lib.callback.await('d87-boosting:wallet:login', false, data.username, data.password)
    cb({ ok = ok, message = message, balance = balance })
end)

RegisterNUICallback('walletLogout', function(_, cb)
    lib.callback.await('d87-boosting:wallet:logout', false)
    cb('ok')
end)

RegisterNUICallback('walletGetBalance', function(_, cb)
    local ok, balance = lib.callback.await('d87-boosting:wallet:getBalance', false)
    cb({ ok = ok, balance = balance })
end)

RegisterNUICallback('walletSend', function(data, cb)
    local ok, message, balance = lib.callback.await('d87-boosting:wallet:send', false, data.username, data.amount)
    cb({ ok = ok, message = message, balance = balance })
end)

RegisterNUICallback('walletLeaderboard', function(_, cb)
    local rows = lib.callback.await('d87-boosting:wallet:leaderboard', false)
    cb({ rows = rows or {} })
end)
