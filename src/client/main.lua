--==// [ VARIABLES ] \\==--

lib.locale()

ESX = exports["es_extended"]:getSharedObject()

LS = { Functions = {} }

Shared = lib.callback.await("ls-garagesystem:server:cb:getShared", false)

--==// [ THREADS ] \\==--

Citizen.CreateThread(function()
    while not Shared do Citizen.Wait(100) end

    while true do
        local isClose = false

        for k, v in pairs(Shared.Garages) do
            local interactionDist = #(GetEntityCoords(cache.ped) - v["interactionCoords"])

            if interactionDist <= 2.0 then
                isClose = true

                lib.showTextUI("[E] - ".. locale("garage_label", k))

                if IsControlJustPressed(0, 38) then
                    LS.Functions.OpenGarage(k)
                end
            end

            if IsPedInAnyVehicle(cache.ped, false) then
                local deleteDist = #(GetEntityCoords(cache.ped) - v["deleteCoords"])

                if deleteDist <= 3.0 then
                    isClose = true

                    lib.showTextUI("[E] - ".. locale("put_vehicle_away"))

                    if IsControlJustPressed(0, 38) then
                        LS.Functions.StoreVehicle(k)
                    end
                end
            end
        end

        if not isClose and lib.isTextUIOpen() then
            lib.hideTextUI()
        end

        Citizen.Wait(isClose and 0 or 750)
    end
end)

--==// [ FUNCTIONS ] \\==--

LS.Functions.OpenGarage = function(garageIndex)
    local vehicles = lib.callback.await("ls-garagesystem:server:cb:getAvailableVehicles", false)

    if not vehicles then
        return
    end

    local options = {}

    for i=1, #vehicles do
        options[#options + 1] = {
            title = GetLabelText(GetDisplayNameFromVehicleModel(vehicles[i]["props"]["model"])),
            description = locale("garage_vehicle_description", ESX.Math.Trim(vehicles[i]["plate"])),
            onSelect = function()
                LS.Functions.OpenGarageVehicle(garageIndex, vehicles, i)
            end
        }
    end

    lib.registerContext({
        id = "ls-garagesystem:menu:interaction",
        title = locale("garage_label", garageIndex),
        options = options
    })

    lib.showContext("ls-garagesystem:menu:interaction")
end

LS.Functions.OpenGarageVehicle = function(garageIndex, vehicles, vehicleIndex)
    if not garageIndex or not vehicles or not vehicleIndex then return end

    local options = {}

    options[#options + 1] = {
        title = locale("get_out_garage"),
        icon = "fas fa-arrow-up-from-bracket",
        disabled = vehicles[vehicleIndex]["stored"] == 0 and true or false,
        onSelect = function()
            LS.Functions.SpawnVehicle(garageIndex, vehicles[vehicleIndex])
        end
    }

    options[#options + 1] = {
        disabled = true
    }

    options[#options + 1] = {
        title = locale("gasoline_level"),
        progress = 100 - vehicles[vehicleIndex]["props"]["fuelLevel"],
        icon = "fas fa-gas-pump"
    }

    options[#options + 1] = {
        title = locale("damage_percentage"),
        progress = 100 - (vehicles[vehicleIndex]["props"]["engineHealth"] / 10),
        icon = "fas fa-car-burst"
    }

    lib.registerContext({
        id = "ls-garagesystem:client:openGarageVehicle",
        title = locale("vehicle_label", GetLabelText(GetDisplayNameFromVehicleModel(vehicles[vehicleIndex]["props"]["model"]))),
        options = options
    })

    lib.showContext("ls-garagesystem:client:openGarageVehicle")
end

LS.Functions.SpawnVehicle = function(garageIndex, vehicle)
    if not vehicle.stored then return end

    local locationIndex = math.random(1, #Shared.Garages[garageIndex]["spawnPoints"])

    if lib.progressCircle({
        duration = 7500,
        position = "bottom",
        label = locale("get_vehicle"),
        useWhileDead = false,
        canCancel = true,
        disable = {
            car = true,
            move = true,
            combat = true,
            sprint = true
        }
    }) then
        vehNetId = lib.callback.await("ls-garagesystem:server:cb:createVehicle", false, { 
            model = vehicle.props.model,
            type = LS.Functions.GetVehicleType(vehicle.props.model),
            coord = vec3(
                Shared.Garages[garageIndex]["spawnPoints"][locationIndex]["coords"]["x"],
                Shared.Garages[garageIndex]["spawnPoints"][locationIndex]["coords"]["y"],
                Shared.Garages[garageIndex]["spawnPoints"][locationIndex]["coords"]["z"]
            ),
            heading = Shared.Garages[garageIndex]["spawnPoints"][locationIndex]["coords"]["heading"],
            prop = vehicle.props
        })

        local canChange = lib.callback.await("ls-garagesystem:server:cb:changeVehicleData", false, {
            netId = vehNetId,
            changeState = true,
            newState = false,
            plate = vehicle.plate,
            currentState = vehicle.stored
        })
    end
end

LS.Functions.StoreVehicle = function(garageIndex)
    if not Shared.Garages[garageIndex]["deleteCoords"] then return end

    if #(GetEntityCoords(cache.ped) - Shared.Garages[garageIndex]["deleteCoords"]) > 2.5 then return end

    local vehicle, vehProps, netId = GetVehiclePedIsIn(cache.ped, false), ESX.Game.GetVehicleProperties(GetVehiclePedIsIn(cache.ped, false)), NetworkGetNetworkIdFromEntity(GetVehiclePedIsIn(cache.ped, false))
    local isAllowed = lib.callback.await("ls-garagesystem:server:cb:checkVehicleOwner", false, vehProps.plate)

    if not isAllowed or isAllowed.stored ~= 0 then return end

    if lib.progressCircle({
        duration = 4500,
        position = "bottom",
        label = locale("putting_vehicle_away"),
        useWhileDead = false,
        canCancel = true,
        disable = {
            car = true,
            move = true,
            combat = true,
            sprint = true,
            mouse = false
        }
    }) then 
        local canChange = lib.callback.await("ls-garagesystem:server:cb:changeVehicleData", false, {
            netId = netId,
            changeState = true,
            newState = true,
            plate = vehProps.plate,
            currentState = isAllowed.isStored
        })

        TaskLeaveVehicle(cache.ped, vehicle, 0)
        Wait(2000)
        NetworkFadeOutEntity(vehicle, false, true)
        Wait(400)
        SetVehicleHasBeenOwnedByPlayer(vehicle, false)
        SetEntityAsMissionEntity(vehicle, false, false)
        DeleteVehicle(vehicle)
    end
end

LS.Functions.GetVehicleType = function(model)
    if model == `submersible` or model == `submersible2` then
        return "submarine"
    end

    local class = GetVehicleClassFromName(model)
    local types = {
        [8] = "bike",
        [11] = "trailer",
        [13] = "bike",
        [14] = "boat",
        [15] = "heli",
        [16] = "plane",
        [21] = "train",
    }

    return types[class] or "automobile"
end

--==// [ EVENTS ] \\==--

RegisterNetEvent('ls-garagesystem:client:setVehicleProperties')
AddEventHandler('ls-garagesystem:client:setVehicleProperties', function(netId, data)
	local veh = NetworkGetEntityFromNetworkId(netId)

	SetEntityAsMissionEntity(veh, true)

	while not IsPedInAnyVehicle(cache.ped) do Wait(0) end

	ESX.Game.SetVehicleProperties(GetVehiclePedIsIn(cache.ped), data)
end)