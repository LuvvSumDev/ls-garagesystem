--==// [ VARIABLES ] \\==--

lib.locale()

ESX = exports["es_extended"]:getSharedObject()

LS = { Functions = {} }

--==// [ CALLBACKS ] \\==--

lib.callback.register("ls-garagesystem:server:cb:getShared", function(source)
    return Shared
end)

lib.callback.register("ls-garagesystem:server:cb:getOwnedVehicles", function(source)
    local xPlayer = ESX.GetPlayerFromId(source)

    if not xPlayer then return nil, false end

    local vehicleData, isFound = LS.Functions.CheckOwnedVehicles(xPlayer.identifier)

    return vehicleData, isFound
end)

lib.callback.register("ls-garagesystem:server:cb:getAvailableVehicles", function(source, vehicleType)
    local vehicles, formattedVehicles = LS.Functions.GetVehicles(source), {}

    for plate, data in pairs(vehicles) do
        formattedVehicles[#formattedVehicles + 1] = {
            plate = plate,
            props = data.props,
            type = data.type,
            stored = data.stored,
            label = data.label and data.label or nil
        }
    end

    return formattedVehicles
end)

lib.callback.register("ls-garagesystem:server:cb:changeVehicleData", function(source, vehData)
    if not vehData or not vehData.netId then return end

    local entityObject = NetworkGetEntityFromNetworkId(vehData.netId)

    local repeatTimer = 0
    local doesEntityExist = nil

    repeat
        doesEntityExist = DoesEntityExist(entityObject)
        repeatTimer += 1
    until doesEntityExist or repeatTimer >= 5

    if not doesEntityExist then 
        print("[^4" .. GetCurrentResourceName() .. "^7] Player tried to change vehicle data of vehicle which isn't active on the server. (^4".. source .."^7)")

        return
    end

    if vehData.changeState then 
        if vehData.newState == vehData.currentState then 
            print("[^4" .. GetCurrentResourceName() .. "^7] Player tried to change vehicle data of vehicle which the provided data isn't correct. (^4".. source .."^7)")

            return
        end

        local affectedRows = MySQL.update.await("UPDATE `owned_vehicles` SET `stored` = ? WHERE `owner` = ? AND `plate` = ?", { vehData.newState, ESX.GetPlayerFromId(source).identifier, vehData.plate })
    end
end)

lib.callback.register("ls-garagesystem:server:cb:checkVehicleOwner", function(source, plate)
    local xPlayer = ESX.GetPlayerFromId(source)
    local isOwned = MySQL.single.await("SELECT * FROM `owned_vehicles` WHERE `owner` = ? AND `plate` = ?", { xPlayer.identifier, plate })

    if not isOwned or type(isOwned) ~= "table" then
        return false
    end

    return isOwned
end)

local ServerVehicle = CreateVehicleServerSetter
lib.callback.register("ls-garagesystem:server:cb:createVehicle", function(source, data)
    local routing = GetPlayerRoutingBucket(source)
    local randomRoute = math.random(100, 999)

    SetPlayerRoutingBucket(source, randomRoute)

    local vehicle = ServerVehicle and ServerVehicle(data.model, data.type, data.coord, data.heading) or CreateVehicle(data.model, data.coord.x, data.coord.y, data.coord.z, data.heading, true, true)

    while not ServerVehicle and not DoesEntityExist(vehicle) do Citizen.Wait(0) end

    SetEntityRoutingBucket(vehicle, randomRoute)

    while NetworkGetEntityOwner(vehicle) == -1 do Citizen.Wait(0) end

    if data.prop and data.prop.plate then
        SetVehicleNumberPlateText(vehicle, data.prop.plate)
    end
    
    SetPedIntoVehicle(GetPlayerPed(source), vehicle, -1)

    while NetworkGetEntityOwner(vehicle) ~= source do 
        SetPedIntoVehicle(GetPlayerPed(source), vehicle, -1)

        Citizen.Wait(10)
    end

    local netId = NetworkGetNetworkIdFromEntity(vehicle)

    TriggerClientEvent("ls-garagesystem:client:setVehicleProperties", NetworkGetEntityOwner(vehicle), netId, data.prop)

    Citizen.SetTimeout(1000, function()
        SetPlayerRoutingBucket(source, routing)
        SetEntityRoutingBucket(vehicle, routing)
        SetPedIntoVehicle(GetPlayerPed(source), vehicle, -1)
    end)

    return netId
end)

--==// [ FUNCTIONS ] \\==--

LS.Functions.GetVehicles = function(source)
    local xPlayer = ESX.GetPlayerFromId(source)
    local response = MySQL.query.await("SELECT * FROM `owned_vehicles` WHERE `owner` = ?", { xPlayer.identifier })

    if not response or type(response) ~= "table" or #response == 0 then
        return false
    end

    local vehicles = {}

    for _, row in ipairs(response) do
        if row.plate and row.vehicle and row.type then
            vehicles[row.plate] = {
                props = json.decode(row.vehicle),
                type = row.type,
                stored = row.stored or false,
                isSeized = row.isSeized or false,
                label = row.label or nil
            }
        end
    end

    return vehicles
end

LS.Functions.ShowNotify = function(messageType, description, duration)
    local src = source
    local messageType = messageType ~= nil and messageType or "error"
    local description = description ~= nil and description or ""
    local duration = type(duration) == "number" and duration or 5000

    TriggerClientEvent("ox_lib:notify", src, { type = messageType, title = "LuvvSum Garages", description = description, duration = duration })
end