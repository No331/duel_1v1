print("^2[DUEL] Client script chargé^7")

local isMenuOpen = false
local inDuel = false
local currentInstanceId = nil
local originalCoords = nil
local currentArena = nil

-- Point d'interaction
local interactionPoint = vector3(256.3, -776.82, 30.88)

-- Coordonnées des arènes avec zones limitées (50m de rayon)
local arenas = {
    aeroport = {
        center = vector3(-1037.0, -2737.0, 20.0),
        radius = 50.0,
        name = "AEROPORT"
    },
    ["dans l'eau"] = {
        center = vector3(-1308.0, 6636.0, 5.0),
        radius = 50.0,
        name = "DANS L'EAU"
    },
    foret = {
        center = vector3(-1617.0, 4445.0, 3.0),
        radius = 50.0,
        name = "FORET"
    },
    hippie = {
        center = vector3(2450.0, 3757.0, 41.0),
        radius = 50.0,
        name = "HIPPIE"
    }
}

-- Thread principal pour le marker
Citizen.CreateThread(function()
    print("^2[DUEL] Thread marker démarré^7")
    while true do
        local sleep = 1000
        local playerPed = PlayerPedId()
        local playerCoords = GetEntityCoords(playerPed)
        local distance = #(playerCoords - interactionPoint)
        
        if distance < 50.0 then
            sleep = 0
            -- Marker bleu
            DrawMarker(1, interactionPoint.x, interactionPoint.y, interactionPoint.z - 1.0, 
                      0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 
                      3.0, 3.0, 1.0, 
                      0, 150, 255, 200, 
                      false, true, 2, false, nil, nil, false)
            
            if distance < 3.0 then
                -- Texte d'aide
                SetTextComponentFormat("STRING")
                AddTextComponentString("Appuyez sur ~INPUT_CONTEXT~ pour ouvrir le menu de duel")
                DisplayHelpTextFromStringLabel(0, 0, 1, -1)
                
                -- Vérifier si E est pressé
                if IsControlJustPressed(1, 38) and not isMenuOpen then
                    print("^3[DUEL] Touche E pressée^7")
                    openDuelMenu()
                end
            end
        end
        
        Citizen.Wait(sleep)
    end
end)

-- Thread pour vérifier les limites de zone en duel
Citizen.CreateThread(function()
    while true do
        if inDuel and currentArena then
            local playerPed = PlayerPedId()
            local playerCoords = GetEntityCoords(playerPed)
            local arena = arenas[currentArena]
            
            if arena then
                local distance = #(playerCoords - arena.center)
                
                -- Dessiner le cercle de limite (pas trop voyant)
                DrawMarker(1, arena.center.x, arena.center.y, arena.center.z - 1.0,
                          0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                          arena.radius * 2, arena.radius * 2, 1.0,
                          255, 0, 0, 50,
                          false, true, 2, false, nil, nil, false)
                
                -- Si le joueur dépasse la limite
                if distance > arena.radius then
                    print("^1[DUEL] Joueur hors limite, téléportation au centre^7")
                    SetEntityCoords(playerPed, arena.center.x, arena.center.y, arena.center.z, false, false, false, true)
                    
                    -- Message d'avertissement
                    TriggerEvent('chat:addMessage', {
                        color = {255, 0, 0},
                        multiline = true,
                        args = {"[DUEL]", "Vous avez dépassé la zone de combat ! Retour au centre."}
                    })
                end
            end
        end
        
        Citizen.Wait(500) -- Vérifier toutes les 500ms
    end
end)

-- Fonction pour ouvrir le menu
function openDuelMenu()
    print("^3[DUEL] Ouverture du menu^7")
    -- Sauvegarder la position actuelle
    local playerPed = PlayerPedId()
    originalCoords = GetEntityCoords(playerPed)
    
    isMenuOpen = true
    SetNuiFocus(true, true)
    
    -- Demander la liste des arènes disponibles
    TriggerServerEvent('duel:getAvailableArenas')
    
    SendNUIMessage({
        type = "openMenu"
    })
end

-- Fonction pour fermer le menu
function closeDuelMenu()
    print("^3[DUEL] Fermeture du menu^7")
    isMenuOpen = false
    SetNuiFocus(false, false)
    
    SendNUIMessage({
        type = "closeMenu"
    })
end

-- Fonction pour quitter le duel
function quitDuel()
    print("^3[DUEL] Quitter le duel^7")
    
    -- Réactiver toutes les permissions
    enablePlayerPermissions()
    
    -- Informer le serveur qu'on quitte l'arène
    TriggerServerEvent('duel:quitArena')
    
    inDuel = false
    currentInstanceId = nil
    currentArena = nil
    
    local playerPed = PlayerPedId()
    
    -- Retirer toutes les armes
    RemoveAllPedWeapons(playerPed, true)
    
    -- Retourner à la position originale
    if originalCoords then
        SetEntityCoords(playerPed, originalCoords.x, originalCoords.y, originalCoords.z, false, false, false, true)
    else
        -- Position par défaut si pas de coordonnées sauvegardées
        SetEntityCoords(playerPed, interactionPoint.x, interactionPoint.y, interactionPoint.z, false, false, false, true)
    end
    
    -- Message de confirmation
    TriggerEvent('chat:addMessage', {
        color = {0, 255, 0},
        multiline = true,
        args = {"[DUEL]", "Vous avez quitté l'arène et êtes retourné au point de départ."}
    })
end

-- Fonction pour désactiver les permissions du joueur
function disablePlayerPermissions()
    print("^1[DUEL] Désactivation des permissions^7")
    
    -- Désactiver les contrôles dangereux
    Citizen.CreateThread(function()
        while inDuel do
            -- Désactiver le menu de pause
            DisableControlAction(0, 200, true) -- ESC/Pause Menu
            
            -- Désactiver les menus de téléphone/interaction
            DisableControlAction(0, 288, true) -- F1 (Téléphone)
            DisableControlAction(0, 289, true) -- F2 
            DisableControlAction(0, 170, true) -- F3
            DisableControlAction(0, 167, true) -- F6
            DisableControlAction(0, 166, true) -- F5
            DisableControlAction(0, 199, true) -- P (Pause)
            
            -- Désactiver les menus de véhicule
            DisableControlAction(0, 75, true) -- Sortir du véhicule
            DisableControlAction(0, 23, true) -- Entrer dans véhicule
            
            -- Désactiver les interactions avec les objets
            DisableControlAction(0, 47, true) -- G (Détacher)
            DisableControlAction(0, 74, true) -- H (Klaxon)
            
            -- Désactiver le chat (optionnel)
            DisableControlAction(0, 245, true) -- T (Chat)
            
            -- Désactiver les emotes
            DisableControlAction(0, 244, true) -- M (Menu emotes)
            
            Citizen.Wait(0)
        end
    end)
end

-- Fonction pour réactiver les permissions du joueur
function enablePlayerPermissions()
    print("^2[DUEL] Réactivation des permissions^7")
    -- Les contrôles se réactivent automatiquement quand on arrête de les désactiver
    -- car on sort de la boucle while inDuel
end

-- Callbacks NUI
RegisterNUICallback('closeMenu', function(data, cb)
    print("^2[DUEL] Callback closeMenu reçu^7")
    closeDuelMenu()
    cb('ok')
end)

RegisterNUICallback('createArena', function(data, cb)
    print("^2[DUEL] ========== CALLBACK CREATEARENA ==========^7")
    print("^3[DUEL] Données reçues: weapon=" .. tostring(data.weapon) .. ", map=" .. tostring(data.map) .. "^7")
    
    if not data.weapon or not data.map then
        print("^1[DUEL] Données manquantes^7")
        cb('error')
        return
    end
    
    print("^2[DUEL] Fermeture du menu^7")
    closeDuelMenu()
    
    print("^2[DUEL] Envoi vers le serveur pour créer l'arène^7")
    TriggerServerEvent('duel:createArena', data.weapon, data.map)
    
    cb('ok')
end)

RegisterNUICallback('joinArena', function(data, cb)
    print("^2[DUEL] ========== CALLBACK JOINARENA ==========^7")
    print("^3[DUEL] Données reçues: weapon=" .. tostring(data.weapon) .. "^7")
    
    if not data.weapon then
        print("^1[DUEL] Arme manquante^7")
        cb('error')
        return
    end
    
    print("^2[DUEL] Fermeture du menu^7")
    closeDuelMenu()
    
    print("^2[DUEL] Envoi vers le serveur pour rejoindre une arène^7")
    TriggerServerEvent('duel:joinArena', data.weapon)
    
    cb('ok')
end)

-- Échapper pour fermer le menu
Citizen.CreateThread(function()
    while true do
        if isMenuOpen then
            if IsControlJustPressed(1, 322) then -- ESC
                print("^3[DUEL] ESC pressé^7")
                closeDuelMenu()
            end
        end
        Citizen.Wait(0)
    end
end)

-- Event reçu quand une instance est créée
RegisterNetEvent('duel:instanceCreated')
AddEventHandler('duel:instanceCreated', function(instanceId, weapon, map)
    print("^2[DUEL] Instance " .. tostring(instanceId) .. " créée pour arène '" .. tostring(map) .. "'^7")
    
    -- Marquer comme en duel
    inDuel = true
    currentInstanceId = instanceId
    currentArena = map
    
    -- Désactiver toutes les permissions dangereuses
    disablePlayerPermissions()
    
    -- Téléporter le joueur vers l'arène
    local playerPed = PlayerPedId()
    local arena = arenas[map]
    
    if arena then
        SetEntityCoords(playerPed, arena.center.x, arena.center.y, arena.center.z, false, false, false, true)
        
        print("^2[DUEL] Téléportation vers " .. arena.name .. " (" .. arena.center.x .. ", " .. arena.center.y .. ", " .. arena.center.z .. ")^7")
        
        -- Donner l'arme sélectionnée
        local weapons = {
            pistol = "WEAPON_PISTOL",
            combat_pistol = "WEAPON_COMBATPISTOL",
            heavy_pistol = "WEAPON_HEAVYPISTOL",
            vintage_pistol = "WEAPON_VINTAGEPISTOL"
        }
        
        -- Retirer toutes les armes d'abord
        RemoveAllPedWeapons(playerPed, true)
        
        -- Donner la nouvelle arme
        local weaponHash = GetHashKey(weapons[weapon] or weapons.pistol)
        GiveWeaponToPed(playerPed, weaponHash, 250, false, true)
        
        -- Message de confirmation
        TriggerEvent('chat:addMessage', {
            color = {0, 255, 0},
            multiline = true,
            args = {"[DUEL]", "Vous êtes dans l'arène " .. arena.name .. " ! En attente d'un adversaire..."}
        })
    else
        print("^1[DUEL] Arène '" .. tostring(map) .. "' non trouvée dans la liste des arènes^7")
        print("^1[DUEL] Arènes disponibles: aeroport, dans l'eau, foret, hippie^7")
    end
end)

-- Event reçu quand une instance est supprimée
RegisterNetEvent('duel:instanceDeleted')
AddEventHandler('duel:instanceDeleted', function()
    print("^1[DUEL] Instance supprimée^7")
    
    -- Réactiver toutes les permissions
    enablePlayerPermissions()
    
    local playerPed = PlayerPedId()
    
    -- Retirer toutes les armes
    RemoveAllPedWeapons(playerPed, true)
    
    -- Retourner à la position originale
    if originalCoords then
        SetEntityCoords(playerPed, originalCoords.x, originalCoords.y, originalCoords.z, false, false, false, true)
    else
        -- Position par défaut si pas de coordonnées sauvegardées
        SetEntityCoords(playerPed, interactionPoint.x, interactionPoint.y, interactionPoint.z, false, false, false, true)
    end
    
    -- Message de confirmation
    TriggerEvent('chat:addMessage', {
        color = {255, 165, 0},
        multiline = true,
        args = {"[DUEL]", "Vous avez quitté votre instance privée et êtes retourné au point de départ."}
    })
end)
-- Event reçu pour mettre à jour la liste des arènes disponibles
RegisterNetEvent('duel:updateAvailableArenas')
AddEventHandler('duel:updateAvailableArenas', function(arenas)
    print("^3[DUEL] Mise à jour des arènes disponibles: " .. #arenas .. " arène(s)^7")
    
    SendNUIMessage({
        type = "updateArenas",
        arenas = arenas
    })
end)

-- Event reçu quand un adversaire rejoint
RegisterNetEvent('duel:opponentJoined')
AddEventHandler('duel:opponentJoined', function(opponentName)
    print("^2[DUEL] Adversaire rejoint: " .. tostring(opponentName) .. "^7")
    
    TriggerEvent('chat:addMessage', {
        color = {0, 255, 0},
        multiline = true,
        args = {"[DUEL]", opponentName .. " a rejoint l'arène ! Le duel commence dans 3 secondes..."}
    })
    
    -- Compte à rebours
    Citizen.SetTimeout(1000, function()
        TriggerEvent('chat:addMessage', {
            color = {255, 165, 0},
            args = {"[DUEL]", "2..."}
        })
    end)
    
    Citizen.SetTimeout(2000, function()
        TriggerEvent('chat:addMessage', {
            color = {255, 165, 0},
            args = {"[DUEL]", "1..."}
        })
    end)
    
    Citizen.SetTimeout(3000, function()
        TriggerEvent('chat:addMessage', {
            color = {255, 0, 0},
            args = {"[DUEL]", "COMBAT !"}
        })
    end)
end)