local QBCore = exports['qb-core']:GetCoreObject()

QBCore.Functions.CreateCallback('beds:doctorCount', function(source, cb)
    -- Get the 'GetDoctorCount' function from the 'qb-ambulancejob' resource
    local doctorCount = exports['qb-ambulancejob']:GetDoctorCount()

    cb(doctorCount)
end)