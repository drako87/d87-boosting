Config = {}

-- Framework / compatibilidad
Config.Framework = 'auto'   -- 'auto' | 'qb' | 'esx' | 'qbx'
Config.Target    = 'ox'     -- 'ox'  | 'qb'
Config.Inventory = 'default' -- 'default' | 'ox_inventory'

-- Items usados como moneda / herramienta
Config.BlackMoneyItem = 'black_money'
Config.TrackerKitItem = 'hak_kit'

Config.Debug = false

-- Ped
Config.PedModel = 'a_m_m_bevhills_02'
Config.PedLocation = vector4(1129.99, -989.16, 45.97, 96.08)
Config.PedBlip = { sprite = 280, color = 1, scale = 0.8, label = 'Trabajos de Vehículos' }

Config.CarSearchRadius = 100.0
Config.Cooldown = 600 -- segundos de enfriamiento tras entregar

-- NPCs que defienden el vehículo
Config.GuardModel  = 'g_m_y_lost_01'
Config.GuardWeapon = 'WEAPON_BAT'
Config.GuardTriggerDistance = 12.0 -- distancia al vehículo para que ataquen

-- ============================================================
-- UBICACIONES (edítalas aquí, cada lista tiene un uso distinto)
-- ============================================================

-- Dónde APARECEN los vehículos robados (recogida), tanto en misiones
-- del NPC como en el punto de recogida de los contratos.
Config.SpawnLocations = {
    vector3(-2480.9, -212.0, 17.4),   vector3(-2723.4, 13.2, 15.1),
    vector3(-3169.6, 976.2, 15.0),    vector3(-3139.8, 1078.7, 20.2),
    vector3(-1656.9, -246.2, 54.5),   vector3(-1586.7, -647.6, 29.4),
    vector3(-1036.1, -491.1, 36.2),   vector3(-1029.2, -475.5, 36.4),
    vector3(75.2, 164.9, 104.7),      vector3(-534.6, -756.7, 31.6),
    vector3(487.2, -30.8, 88.9),      vector3(-772.2, -1281.8, 4.6),
    vector3(-663.8, -1207.0, 10.2),   vector3(719.1, -767.8, 24.9),
    vector3(-971.0, -2410.4, 13.3),   vector3(-1067.5, -2571.4, 13.2),
    vector3(-619.2, -2207.3, 5.6),    vector3(1192.1, -1336.9, 35.1),
    vector3(-432.8, -2166.1, 9.9),    vector3(-451.8, -2269.3, 7.2),
    vector3(939.3, -2197.5, 30.5),    vector3(-556.1, -1794.7, 22.0),
    vector3(591.7, -2628.2, 5.6),     vector3(1654.5, -2535.8, 74.5),
    vector3(1642.6, -2413.3, 93.1),   vector3(1371.3, -2549.5, 47.6),
    vector3(383.8, -1652.9, 37.3),    vector3(27.2, -1030.9, 29.4),
    vector3(229.3, -365.9, 43.8),     vector3(-85.8, -51.7, 61.1),
    vector3(-4.6, -670.3, 31.9),      vector3(-111.9, 92.0, 71.1),
    vector3(-314.3, -698.2, 32.5),    vector3(-366.9, 115.5, 65.6),
    vector3(-592.1, 138.2, 60.1),     vector3(-1613.9, 18.8, 61.8),
    vector3(-1709.8, 55.1, 65.7),     vector3(-521.9, -266.8, 34.9),
    vector3(-451.1, -333.5, 34.0),    vector3(322.4, -1900.5, 25.8),
}

-- Dónde se ENTREGA el vehículo (misiones del NPC y contratos cuando
-- el jugador elige entregarlo en vez de quedárselo).
-- Deben ser calles/solares abiertos, nunca la entrada de un local o taller.
Config.DropOffLocations = {
    vector4(56.82, 160.78, 104.73, 250.3),  -- aparcamiento en azotea (abierto)
    vector4(-320.9, -1471.9, 29.9, 60.0),   -- calle abierta, Pillbox
    vector4(-1035.9, -523.9, 33.9, 130.0),  -- calle abierta, Morningwood
}

-- Dónde se QUEDA/VENDE el vehículo cuando el jugador marca la opción
-- de "quedarme con el vehículo" en vez de entregarlo.
-- Igual que arriba: calles/solares abiertos, nunca dentro de un local.
Config.KeepLocations = {
    vector4(215.1, -800.9, 30.9, 250.0),  -- calle abierta, Alta
    vector4(-46.7, -1750.9, 29.4, 30.0),  -- solar abierto, Strawberry
    vector4(908.5, -1749.7, 30.4, 210.0), -- calle abierta, Elysian Island
}
Config.KeepDuration = 20000 -- ms que dura la barra de "adquiriendo vehículo"

-- Garaje del framework donde se guarda el vehículo adquirido
-- (nombre de garaje por defecto usado por qb-garage / ESX garage).
Config.DefaultGarage = 'pillboxgarage'

Config.VehicleColors = {
    { label = 'Negro',       id = 0   },
    { label = 'Blanco',      id = 111 },
    { label = 'Gris Plata',  id = 3   },
    { label = 'Rojo',        id = 27  },
    { label = 'Azul Oscuro', id = 64  },
    { label = 'Verde',       id = 53  },
    { label = 'Amarillo',    id = 88  },
    { label = 'Naranja',     id = 38  },
}

Config.TabletItem = 'boosting_tablet'
Config.WalletLeaderboardSize = 10

-- Sistema de contratos aleatorios
Config.ContractMaxStored = 10     -- máximo de contratos guardados por jugador
Config.ContractPurgeCount = 3     -- cuántos se eliminan (los más viejos) al llenarse
Config.ContractCheckInterval = 60 -- segundos entre revisiones del servidor
Config.ContractIntervalMin = 180  -- segundos min para que llegue un contrato nuevo
Config.ContractIntervalMax = 420  -- segundos max
Config.ContractRecentMemory = 6   -- nº de coches recientes a evitar repetir por jugador
Config.ContractInteractDistance = 8.0

Config.ContractTiers = {
    { level = 1, label = 'Novato',     minCompleted = 0,
      cars = {'blista', 'panto', 'dilettante', 'issi2', 'asea'},
      reward = { min = 10, max = 20 },
      keepCost = { min = 30, max = 50 },
      guardCount = { min = 0, max = 1 } },
    { level = 2, label = 'Intermedio', minCompleted = 5,
      cars = {'dominator', 'gauntlet', 'f620', 'sultan', 'tampa'},
      reward = { min = 25, max = 45 },
      keepCost = { min = 70, max = 100 },
      guardCount = { min = 1, max = 2 } },
    { level = 3, label = 'Experto',    minCompleted = 15,
      cars = {'adder', 'zentorno', 't20', 'osiris', 'vacca'},
      reward = { min = 60, max = 100 },
      keepCost = { min = 140, max = 200 },
      guardCount = { min = 2, max = 3 } },
    { level = 4, label = 'Élite',      minCompleted = 30,
      cars = {'turismor', 'entityxf', 'reaper', 'tempesta', 'vagner'},
      reward = { min = 120, max = 180 },
      keepCost = { min = 250, max = 350 },
      guardCount = { min = 3, max = 3 } },
}

-- Misiones: cada una define pago, vehículos, dificultad (guardias/tracker) y requisitos
Config.Missions = {
    [1] = {
        id = 1,
        label = 'Trabajo Cripto',
        icon = 'bitcoin-sign',
        paymentType = 'crypto',
        cars = {'panto', 'blista', 'dilettante'},
        reward = { crypto = { min = 15, max = 25 } },
        penaltyMultiplier = 0.5,
        requirements = {},
        difficulty = {
            npcGuards = { min = 1, max = 1 },
            trackerRequired = false,
            skillDifficulty = {},
        },
        description = 'Robo sencillo sin rastreador. Roba el vehículo indicado y entrégalo en el punto marcado. Pago 100%% en criptomonedas.',
    },
    [2] = {
        id = 2,
        label = 'Trabajo Dinero Negro',
        icon = 'money-bill-wave',
        paymentType = 'black_money',
        cars = {'dominator', 'gauntlet', 'f620'},
        reward = { black_money = { min = 1500, max = 2500 } },
        penaltyMultiplier = 0.4,
        requirements = {'hak_kit'},
        difficulty = {
            npcGuards = { min = 2, max = 2 },
            trackerRequired = true,
            skillDifficulty = {'easy', 'medium'},
        },
        description = 'El vehículo tiene rastreador y 2 vigilantes armados con bates lo custodian. Necesitas un kit de hackeo (hak_kit) para desactivar el rastreador. Pago en dinero negro.',
    },
    [3] = {
        id = 3,
        label = 'Trabajo Alto Riesgo',
        icon = 'skull',
        paymentType = 'mixed',
        cars = {'adder', 'zentorno', 't20'},
        reward = {
            crypto = { min = 15, max = 20 },
            black_money = { min = 2000, max = 3000 },
        },
        penaltyMultiplier = 0.35,
        requirements = {'hak_kit'},
        difficulty = {
            npcGuards = { min = 3, max = 3 },
            trackerRequired = true,
            skillDifficulty = {'easy', 'medium', 'hard'},
        },
        description = 'Vehículo de alta gama muy vigilado (3 guardias) y con rastreador. Necesitas un kit de hackeo (hak_kit). Pago combinado: criptomonedas + dinero negro.',
    },
}
