CREATE TABLE IF NOT EXISTS `d87_wallets` (
  `identifier` VARCHAR(60) NOT NULL,
  `username` VARCHAR(32) NOT NULL,
  `password_hash` VARCHAR(20) NOT NULL,
  `salt` VARCHAR(16) NOT NULL,
  `balance` INT NOT NULL DEFAULT 0,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`identifier`),
  UNIQUE KEY `username` (`username`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Registro interno (log) de vehículos adquiridos. El vehículo real se
-- guarda además en la tabla de garaje de tu framework (player_vehicles
-- en QB/QBX, owned_vehicles en ESX) mediante Bridge.RegisterVehicle.
CREATE TABLE IF NOT EXISTS `d87_owned_vehicles` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `identifier` VARCHAR(60) NOT NULL,
  `model` VARCHAR(60) NOT NULL,
  `plate` VARCHAR(12) NOT NULL,
  `acquired_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `d87_contract_stats` (
  `identifier` VARCHAR(60) NOT NULL,
  `completed` INT NOT NULL DEFAULT 0,
  PRIMARY KEY (`identifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

