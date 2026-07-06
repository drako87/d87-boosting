Wallet = {}

local sessions = {} -- [src] = identifier (logueado en esta sesión)

local function getIdentifier(src)
    return GetPlayerIdentifierByType(src, 'license') or GetPlayerIdentifierByType(src, 'license2')
end

local function getSourceFromIdentifier(identifier)
    for _, playerId in ipairs(GetPlayers()) do
        local src = tonumber(playerId)
        if getIdentifier(src) == identifier then
            return src
        end
    end
    return nil
end

-- Hash simple (FNV-1a 64 bits) + salt. Suficiente para este sistema de RP,
-- no sustituye un almacenamiento de credenciales de nivel producción.
local function fnv1a(str)
    local hash = 0xcbf29ce484222325
    for i = 1, #str do
        hash = hash ~ str:byte(i)
        hash = (hash * 0x100000001b3) & 0xFFFFFFFFFFFFFFFF
    end
    return string.format('%016x', hash)
end

local function hashPassword(password, salt)
    return fnv1a(salt .. password .. salt)
end

local function generateSalt()
    local chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789'
    local salt = {}
    for i = 1, 12 do
        local idx = math.random(1, #chars)
        salt[i] = chars:sub(idx, idx)
    end
    return table.concat(salt)
end

AddEventHandler('playerDropped', function()
    sessions[source] = nil
end)

---------------------------------------------------------------
-- Crédito de saldo (usado por el sistema de recompensas)
---------------------------------------------------------------
function Wallet.AddBalance(src, amount)
    local identifier = getIdentifier(src)
    if not identifier then return false end

    local exists = MySQL.scalar.await('SELECT identifier FROM d87_wallets WHERE identifier = ?', { identifier })
    if not exists then return false end

    MySQL.update.await('UPDATE d87_wallets SET balance = balance + ? WHERE identifier = ?', { amount, identifier })
    return true
end

function Wallet.GetIdentifier(src)
    return getIdentifier(src)
end

function Wallet.TryDeduct(src, amount)
    local identifier = getIdentifier(src)
    if not identifier then return false end

    local balance = MySQL.scalar.await('SELECT balance FROM d87_wallets WHERE identifier = ?', { identifier })
    if not balance or balance < amount then return false end

    MySQL.update.await('UPDATE d87_wallets SET balance = balance - ? WHERE identifier = ?', { amount, identifier })
    return true
end

---------------------------------------------------------------
-- Callbacks (ox_lib)
---------------------------------------------------------------
lib.callback.register('d87-boosting:wallet:register', function(source, username, password)
    local src = source
    local identifier = getIdentifier(src)
    if not identifier then return false, 'No se pudo identificar tu cuenta.' end

    username = tostring(username or ''):gsub('%s+', '')
    if #username < 3 or #username > 20 then
        return false, 'El usuario debe tener entre 3 y 20 caracteres.'
    end
    if not password or #password < 4 then
        return false, 'La contraseña debe tener al menos 4 caracteres.'
    end

    local existingId = MySQL.scalar.await('SELECT identifier FROM d87_wallets WHERE identifier = ?', { identifier })
    if existingId then
        return false, 'Ya tienes una cartera digital creada.'
    end

    local existingUser = MySQL.scalar.await('SELECT username FROM d87_wallets WHERE username = ?', { username })
    if existingUser then
        return false, 'Ese nombre de usuario ya está en uso.'
    end

    local salt = generateSalt()
    local hash = hashPassword(password, salt)

    MySQL.insert.await('INSERT INTO d87_wallets (identifier, username, password_hash, salt, balance) VALUES (?, ?, ?, ?, 0)', {
        identifier, username, hash, salt,
    })

    sessions[src] = identifier
    return true, 'Cartera creada correctamente. Sesión iniciada.', 0
end)

lib.callback.register('d87-boosting:wallet:login', function(source, username, password)
    local src = source
    local row = MySQL.single.await('SELECT identifier, password_hash, salt, balance FROM d87_wallets WHERE username = ?', { username })
    if not row then
        return false, 'Usuario no encontrado.'
    end

    if hashPassword(password or '', row.salt) ~= row.password_hash then
        return false, 'Contraseña incorrecta.'
    end

    sessions[src] = row.identifier
    return true, 'Sesión iniciada.', row.balance
end)

lib.callback.register('d87-boosting:wallet:logout', function(source)
    sessions[source] = nil
    return true
end)

lib.callback.register('d87-boosting:wallet:getBalance', function(source)
    local identifier = sessions[source]
    if not identifier then return false, 'No has iniciado sesión.' end

    local balance = MySQL.scalar.await('SELECT balance FROM d87_wallets WHERE identifier = ?', { identifier }) or 0
    return true, balance
end)

lib.callback.register('d87-boosting:wallet:send', function(source, targetUsername, amount)
    local src = source
    local identifier = sessions[src]
    if not identifier then return false, 'No has iniciado sesión.' end

    amount = tonumber(amount)
    if not amount or amount <= 0 or amount ~= math.floor(amount) then
        return false, 'Cantidad inválida.'
    end

    local senderBalance = MySQL.scalar.await('SELECT balance FROM d87_wallets WHERE identifier = ?', { identifier }) or 0
    if senderBalance < amount then
        return false, 'Saldo insuficiente.'
    end

    local target = MySQL.single.await('SELECT identifier, username FROM d87_wallets WHERE username = ?', { targetUsername })
    if not target then
        return false, 'El destinatario no existe.'
    end
    if target.identifier == identifier then
        return false, 'No puedes enviarte cripto a ti mismo.'
    end

    MySQL.update.await('UPDATE d87_wallets SET balance = balance - ? WHERE identifier = ?', { amount, identifier })
    MySQL.update.await('UPDATE d87_wallets SET balance = balance + ? WHERE identifier = ?', { amount, target.identifier })

    local targetSrc = getSourceFromIdentifier(target.identifier)
    if targetSrc then
        Bridge.Notify(targetSrc, ('Has recibido %d cripto de otro usuario.'):format(amount), 'success')
    end

    local newBalance = senderBalance - amount
    return true, ('Has enviado %d cripto a %s.'):format(amount, target.username), newBalance
end)

lib.callback.register('d87-boosting:wallet:leaderboard', function(source)
    local rows = MySQL.query.await(
        'SELECT username, balance FROM d87_wallets ORDER BY balance DESC LIMIT ?',
        { Config.WalletLeaderboardSize }
    ) or {}
    return rows
end)
