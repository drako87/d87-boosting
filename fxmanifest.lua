fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'd87-boosting'
author 'Drako87/Dracatt'
description 'Car Boosting multi-framework'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
    'bridge/init.lua'
}

client_scripts {
    'client/ui.lua',
    'client/npc.lua',
    'client/wallet.lua',
    'client/contracts.lua',
    'client/main.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/wallet.lua',
    'server/contracts.lua',
    'server/economy.lua',
    'server/main.lua'
}

ui_page 'ui/index.html'

files {
    'ui/index.html',
    'ui/style.css',
    'ui/app.js'
}

dependencies {
    'ox_lib',
    'oxmysql'
}
