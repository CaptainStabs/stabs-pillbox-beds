local QBCore = exports['qb-core']:GetCoreObject()
-- Config
local bedModelNames = {
    { modelName = "gabz_pillbox_diagnostics_bed_03", offset = vector3(0.0, 0.0, 1.0) },
    { modelName = "gabz_pillbox_diagnostics_bed_02", offset = vector3(0.0, 0.2, 1.0) },
    { modelName = "gabz_pillbox_diagnostics_bed_01", offset = vector3(0.0, 0.0, 1.0) },
    { modelName = "v_med_bed1", offset = vector3(0.0, 0.0, 1.0) }
}

local bedInteractKey = 38  -- The key code for the 'E' key (default is 38)
local getHealedKey = 23 -- The key code for the 'F' key
local standingOffset = vector3(1.3, 0.0, 0.0)  -- Offset to move the player when standing up

local isLyingDown = false

-- Function to load animation dictionary
local function LoadAnimDict(d)
    while not HasAnimDictLoaded(d) do
        RequestAnimDict(d)
        Citizen.Wait(5)
    end
end

-- Preload animation dictionaries
LoadAnimDict("anim@gangops@morgue@table@")

-- Function to check if the player is near a bed
local function IsPlayerNearBed()
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    
    for i, bedData in ipairs(bedModelNames) do
        local bedObject = GetClosestObjectOfType(playerCoords, 3.0, GetHashKey(bedData.modelName), false, false, false)
        
        if bedObject ~= 0 then
            local bedCoords = GetEntityCoords(bedObject)
            local distance = GetDistanceBetweenCoords(playerCoords, bedCoords, true)
            
            if distance <= 2.0 then
                return true, bedObject, bedData
            end
        end
    end
    
    return false, nil, nil
end

-- Function to perform the lying down animation
local function LyingDownAnimation(bedObject, bedData)
    local playerPed = PlayerPedId()
    local bedOffset = GetOffsetFromEntityInWorldCoords(bedObject, bedData.offset.x, bedData.offset.y, bedData.offset.z)
    local bedHeading = GetEntityHeading(bedObject)

    SetEntityCoordsNoOffset(playerPed, bedOffset, 0, 0, 1)
    SetEntityHeading(playerPed, bedHeading + 180.0) -- Rotate player's heading by 180 degrees

    TaskPlayAnim(playerPed, "anim@gangops@morgue@table@", "ko_front", 3.0, 3.0, -1, 1, 0, false, false, false)
end

-- Function to perform the standing up animation
local function StandUpAnimation()
    local playerPed = PlayerPedId()
    DoScreenFadeOut(2000)
    Wait(1500)
    local playerOffset = GetOffsetFromEntityInWorldCoords(playerPed, standingOffset.x, standingOffset.y, standingOffset.z)
    SetEntityCoordsNoOffset(playerPed, playerOffset, 0, 0, 1)
    Wait(1500)
    DoScreenFadeIn(2000)
    ClearPedTasks(playerPed)
end


local function menu()
    exports['qb-menu']:openMenu({
        {
            header = 'Bed Menu',
            icon = 'fas fa-code',
            isMenuHeader = true, -- Set to true to make a nonclickable title
        },
        {
            header = 'Let local doctor treat you',
            txt = 'Get healed',
            params = {
                event = 'beds:localHeal',
                args = {
                    isRevive = true
                }
            }
        },
    })
end.

-- Modified from qb-ambulancejob
RegisterNetEvent('beds:localHeal', function(isRevive)
    gettingHealed = true
    CreateThread(function ()
        Wait(5)
        if isRevive then
            QBCore.Functions.Notify('You are being helped...', 'success')
            Wait(Config.AIHealTimer * 1000)
            TriggerEvent("hospital:client:Revive")
            gettingHealed = false
        else
            canLeaveBed = true
        end
    end)
end)

-- Main thread
Citizen.CreateThread(function()
    local targetCoords = vector3(316.48, -576.39, 43.28)
    gettingHealed = false
    while true do
        Citizen.Wait(0)
        
        local playerPed = PlayerPedId()
        local playerCoords = GetEntityCoords(playerPed)

        -- Check if the player is near a bed
        local isNearBed, bedObject, bedData = IsPlayerNearBed()
        
        local distanceToTarget = GetDistanceBetweenCoords(playerCoords, targetCoords, true)
            if distanceToTarget <= 100.0 then
                -- Set wait time to 0 when player is within 100 units of the target coordinates
                Citizen.Wait(0)
            else
                -- Calculate a scaled wait time based on the player's distance from the target coordinates
                local scaledWaitTime = math.floor(distanceToTarget * 2)  -- Adjust the division factor (10.0) as needed
                if scaledWaitTime > 0 then
                    Citizen.Wait(scaledWaitTime)
                else
                    Citizen.Wait(0)
                end
            end

        if isNearBed then            
            -- Display prompt to lie down
            if not isLyingDown then
                SetTextComponentFormat("STRING")
                AddTextComponentString("Press ~INPUT_PICKUP~ to lie down")
                DisplayHelpTextFromStringLabel(0, 0, 1, -1)
            end
            
            -- Check if the player pressed the interact key
            if IsControlJustPressed(0, bedInteractKey) then
                if not isLyingDown then
                    if bedData.modelName == 'v_med_bed1' then
                        QBCore.Functions.TriggerCallback('beds:doctorCount', function(doctorCount)
                            local AIHealWait = Config.AIHealWait * 1000
                            if doctorCount < Config.MinimalDoctors then
                                QBCore.Functions.Notify('Please wait while we ping a local doctor...', 'success', AIHealWait)
                                Citizen.Wait(AIHealWait)
                                QBCore.Functions.Notify('The doctor will see you now.', 'success')
                                gettingHealed = true
                                TriggerEvent('beds:localHeal', true)
                                gettingHealed = false
                            
                            else -- If there are medics online
                                -- Add logic here to trigger a dispatch call for a player checking in
                                local data = exports['cd_dispatch']:GetPlayerInfo()
                                TriggerServerEvent('cd_dispatch:AddNotification', {
                                    job_table = {'ambulance', }, 
                                    coords = data.coords,
                                    title = 'An injured person has checked in...',
                                    message = '', 
                                    flash = 0,
                                    unique_id = data.unique_id,
                                    sound = 1,
                                    blip = {
                                        sprite = 682, 
                                        scale = 1.2, 
                                        colour = 3,
                                        flashes = false, 
                                        text = 'Checked-In',
                                        time = 5,
                                        radius = 0,
                                    }
                                })

                                QBCore.Functions.Notify('Please wait while we ping a doctor...', 'success', AIHealWait)
                                Citizen.Wait(AIHealWait)
                                menu()

                            end
                        end)
                    end
                    LyingDownAnimation(bedObject, bedData)
                    isLyingDown = true
                elseif isLyingDown and gettingHealed then
                    StandUpAnimation()
                    isLyingDown = false
                end
            elseif IsControlJustPressed(0, 73) then
                StandUpAnimation()
                isLyingDown = false
            end
        end
    end
end)