fx_version 'cerulean'
game 'gta5'

author 'MovinBags420'
description 'QBCore Bank Truck Heist'
version '1.0.0'

files {
    'sounds/drill.ogg'
}

client_scripts {
    'config.lua',
    'client.lua',
    '@PolyZone/client.lua',  
    --'@BolyZone/client.lua',-- Only if you use PolyZone directly
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'config.lua',
    'server.lua'
}

shared_script '@qb-core/shared/locale.lua'

dependencies {
    'qb-target',
    'xsound',
    'PolyZone',                -- Only if you use PolyZone
    'ox_lib'                   -- Only if you use ox_lib
    --'BoxZone'             -- Uncomment if you use BoxZone instead of PolyZone
}