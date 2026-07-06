# D87-Boosting

Script de robo/entrega de vehículos (car boosting) multi-framework para FiveM.

**Autores:** Drako87 / Dracatt

## Dependencias
- ox_lib
- oxmysql
- Framework: qb-core / es_extended / qbx_core (autodetección)
- Target: ox_target o qb-target (Config.Target)
- Opcional: ps-dispatch (si está iniciado, se usa automáticamente)

## Base de datos
Ejecuta el archivo `database.sql` en tu base de datos (tablas de carteras, vehículos adquiridos y estadísticas de contratos).

## Items necesarios
- `boosting_tablet` (abre la tablet, item usable, no se consume)
- `black_money` (pago en dinero negro)
- `hak_kit` (kit para desactivar rastreadores — no se consume al usarse)

## Tablet D87
Usa el item `boosting_tablet` desde tu inventario para abrir la tablet (ya no existe comando `/cartera`). Desde ella se accede a:
- **Cuenta**: crear cartera digital / iniciar sesión / ver saldo / cerrar sesión.
- **Enviar**: transferir cripto a otro usuario registrado por su nombre de usuario.
- **Ranking**: top de carteras con más cripto acumulada entre todos los jugadores.
- **Contratos**: contratos de robo aleatorios (ver abajo).

La sesión de la cartera dura mientras estés conectado; al reconectar debes volver a iniciar sesión.

## Sistema de Contratos
Cada jugador recibe contratos aleatorios de robo con el tiempo (intervalo configurable). Cada contrato incluye: vehículo, punto de recogida aleatorio, punto de entrega aleatorio y ganancia en cripto. Los contratos no caducan solos: se guardan hasta `Config.ContractMaxStored` (10 por defecto) y, al llenarse, se eliminan automáticamente los `Config.ContractPurgeCount` (3) más antiguos para hacer hueco a los nuevos.

Al aceptar un contrato, este pasa a estado "En curso" y permanece en tu lista (sin poder traspasarse ni eliminarse) hasta que lo entregues.

Desde la pestaña **Contratos** de la tablet puedes:
- **Aceptar**: spawnea el vehículo en el punto de recogida y traza la ruta de entrega al encender el motor. Se entrega pulsando **E** sin bajarte del vehículo, cerca del punto de entrega.
- **Traspasar**: escribe el ID de servidor de otro jugador para enviarle el contrato (si tiene hueco libre).
- **Eliminar**: descarta el contrato sin penalización.

### Progresión por tiers
Cuantos más contratos completes, mejor tier desbloqueas (más variedad de coches de gama alta, mejores ganancias, más vigilantes armados y mayor coste/valor por quedarte el vehículo). Los tiers se configuran en `Config.ContractTiers`. El sistema evita repetir los últimos vehículos recibidos (`Config.ContractRecentMemory`) para dar variedad.

### Vigilantes y quedarte con el vehículo
Cada contrato puede tener vigilantes armados con bate custodiando el punto de recogida (`guardCount` según el tier). La opción de quedarte el vehículo (en vez de entregarlo) se marca como casilla dentro del propio contrato en la tablet, antes de pulsar "Aceptar". Si la marcas, al robar el coche y encender el motor se traza ruta a un punto de compra; llega sin bajarte y pulsa **E** para confirmar (Sí/No). Con "Sí", tras 20 segundos de barra de progreso el vehículo pasa a ser tuyo y se descuenta el coste (`keepCost` del tier) de tu cartera digital.

Los vehículos adquiridos se guardan automáticamente en la tabla de garaje real de tu framework (`player_vehicles` en QB/QBX, `owned_vehicles` en ESX) mediante `Bridge.RegisterVehicle`, así que aparecen directamente en el garaje del jugador (`Config.DefaultGarage`). También se guarda un registro interno en `d87_owned_vehicles` a modo de histórico. Si usas un script de garaje con tablas distintas a las de por defecto, ajusta `Bridge.RegisterVehicle` en `bridge/init.lua`.

Las misiones del NPC solo permiten entregar el vehículo (no tienen opción de quedárselo).

### Añadir items en ox_inventory
Agrega esto en `ox_inventory/data/items.lua`:

```lua
['boosting_tablet'] = {
    label = 'Tablet D87',
    weight = 200,
    stack = false,
    close = true,
    description = 'Accede a tu cartera digital y a los contratos de robo activos.'
},

['black_money'] = {
    label = 'Dinero Negro',
    weight = 0,
    stack = true,
    close = true,
    description = 'Dinero sucio que necesita ser blanqueado.'
},

['hak_kit'] = {
    label = 'Kit de Hackeo',
    weight = 500,
    stack = true,
    close = true,
    description = 'Herramienta para desactivar rastreadores de vehículos.'
},
```

## Instalación
> Revisa `Config.SpawnLocations`, `Config.DropOffLocations` y `Config.KeepLocations` en el mapa antes de publicar el servidor: deben ser calles o solares abiertos, no puertas de locales/talleres (p. ej. Benny's), para evitar que un punto quede bloqueado dentro de un interior.

1. Coloca la carpeta `d87-boosting` en `resources/`.
2. Ejecuta `database.sql` en tu base de datos.
3. Añade los items de arriba a tu inventario/framework si no existen. Dale la tablet a los jugadores (comando de admin, tienda, starter kit, etc.).
4. Ajusta `config.lua`: en la sección "UBICACIONES" están separadas y comentadas `Config.SpawnLocations` (recogida), `Config.DropOffLocations` (entrega) y `Config.KeepLocations` (quedarte el vehículo) para editarlas fácilmente. Ajusta también `Config.DefaultGarage` al nombre de garaje que uses.
5. Añade `ensure d87-boosting` en tu `server.cfg` (después de `oxmysql` y `ox_lib`).

## Misiones del NPC
1. **Trabajo Cripto** – fácil, sin rastreador, 1 vigilante. Pago en cripto.
2. **Trabajo Dinero Negro** – medio, rastreador + hak_kit requerido, 2 vigilantes. Pago en dinero negro.
3. **Trabajo Alto Riesgo** – difícil, rastreador + hak_kit requerido, 3 vigilantes. Pago cripto + dinero negro.

Si el rastreador no se desactiva, la entrega se paga con penalización (`penaltyMultiplier` en config).

## Licencia
GPL-3.0. Ver archivo LICENSE.
