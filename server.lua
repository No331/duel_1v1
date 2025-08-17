print("^2[DUEL] Server script chargé^7")

-- Système d'instances
local instances = {}
local nextInstanceId = 1

-- Fonction pour créer une nouvelle instance
function createInstance(playerId, arenaType)
    local instanceId = nextInstanceId
    nextInstanceId = nextInstanceId + 1
    
    instances[instanceId] = {
        id = instanceId,
        owner = playerId,
        arena = arenaType,
        players = {playerId},
        created = os.time()
    }
    
    print("^3[DUEL] Instance " .. instanceId .. " créée pour le joueur " .. playerId .. " (arène: " .. arenaType .. ")^7")
    return instanceId
end

-- Fonction pour supprimer une instance
function deleteInstance(instanceId)
    if instances[instanceId] then
        print("^1[DUEL] Instance " .. instanceId .. " supprimée^7")
        instances[instanceId] = nil
    end
end

-- Fonction pour obtenir l'instance d'un joueur
function getPlayerInstance(playerId)
    for instanceId, instance in pairs(instances) do
        for _, pid in ipairs(instance.players) do
            if pid == playerId then
                return instanceId, instance
            end
        end
    end
    return nil, nil
end

-- Event pour rejoindre une arène (créer une instance)
RegisterServerEvent('duel:joinArena')
AddEventHandler('duel:joinArena', function(weapon, map)
    local source = source
    local playerName = GetPlayerName(source)
    
    print("^2[DUEL] " .. playerName .. " (ID: " .. source .. ") rejoint l'arène " .. map .. " avec " .. weapon .. "^7")
    
    -- Vérifier si le joueur est déjà dans une instance
    local currentInstanceId, currentInstance = getPlayerInstance(source)
    if currentInstanceId then
        print("^1[DUEL] Joueur " .. source .. " déjà dans l'instance " .. currentInstanceId .. "^7")
        return
    end
    
    -- Créer une nouvelle instance privée
    local instanceId = createInstance(source, map)
    
    -- Confirmer au client
    TriggerClientEvent('duel:instanceCreated', source, instanceId, weapon, map)
end)

-- Event pour quitter une arène (supprimer l'instance)
RegisterServerEvent('duel:quitArena')
AddEventHandler('duel:quitArena', function()
    local source = source
    local playerName = GetPlayerName(source)
    
    print("^3[DUEL] " .. playerName .. " (ID: " .. source .. ") quitte son arène^7")
    
    -- Trouver et supprimer l'instance du joueur
    local instanceId, instance = getPlayerInstance(source)
    if instanceId then
        deleteInstance(instanceId)
        TriggerClientEvent('duel:instanceDeleted', source)
    end
end)

-- Nettoyer les instances quand un joueur se déconnecte
AddEventHandler('playerDropped', function(reason)
    local source = source
    local playerName = GetPlayerName(source)
    
    print("^1[DUEL] " .. playerName .. " s'est déconnecté, nettoyage de son instance^7")
    
    local instanceId, instance = getPlayerInstance(source)
    if instanceId then
        deleteInstance(instanceId)
    end
end)

-- Commande admin pour voir les instances actives
RegisterCommand('duel_instances', function(source, args, rawCommand)
    if source == 0 then -- Console serveur seulement
        print("^2[DUEL] Instances actives:^7")
        local count = 0
        for instanceId, instance in pairs(instances) do
            count = count + 1
            local playerName = GetPlayerName(instance.owner)
            print("^3  Instance " .. instanceId .. ": " .. playerName .. " (" .. instance.owner .. ") - Arène: " .. instance.arena .. "^7")
        end
        if count == 0 then
            print("^1  Aucune instance active^7")
        end
    end
end, true)

-- Nettoyage automatique des instances anciennes (toutes les 5 minutes)
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(300000) -- 5 minutes
        
        local currentTime = os.time()
        local toDelete = {}
        
        for instanceId, instance in pairs(instances) do
            -- Supprimer les instances de plus de 30 minutes
            if currentTime - instance.created > 1800 then
                table.insert(toDelete, instanceId)
            end
        end
        
        for _, instanceId in ipairs(toDelete) do
            print("^1[DUEL] Instance " .. instanceId .. " supprimée (trop ancienne)^7")
            deleteInstance(instanceId)
        end
    end
end)