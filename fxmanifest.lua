fx_version "cerulean"
game "gta5"
lua54 "yes"
version "1.0.0"
author "LuvvSumDev (Daviën K.)"
description "Garage System"

shared_scripts {
    "@es_extended/imports.lua",
    "@ox_lib/init.lua"
}

client_scripts {
    "src/client/*.lua"
}
  
server_scripts {
    "@oxmysql/lib/MySQL.lua",
    "shared/*.lua",
    "src/server/*.lua"
}

files {
    "locales/*.json"
}