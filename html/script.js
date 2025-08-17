console.log('[DUEL] Script JS chargé');

let selectedWeapon = null;
let selectedMap = null;
let availableArenas = [];

// Écouter les messages du client Lua
window.addEventListener('message', function(event) {
    const data = event.data;
    console.log('[DUEL] Message reçu:', data);
    
    switch(data.type) {
        case 'openMenu':
            openMenu();
            break;
        case 'closeMenu':
            closeMenu();
            break;
        case 'updateArenas':
            updateAvailableArenas(data.arenas);
            break;
    }
});

function openMenu() {
    console.log('[DUEL] Ouverture du menu');
    const app = document.getElementById('app');
    app.classList.remove('hidden');
}

function closeMenu() {
    console.log('[DUEL] Fermeture du menu');
    const app = document.getElementById('app');
    app.classList.add('hidden');
    
    // Reset des sélections
    selectedWeapon = null;
    selectedMap = null;
    updateJoinButton();
    
    // Reset de l'affichage
    const selectedWeaponSpan = document.getElementById('selectedWeapon');
    const selectedMapSpan = document.getElementById('selectedMap');
    if (selectedWeaponSpan) selectedWeaponSpan.textContent = 'Aucun';
    if (selectedMapSpan) selectedMapSpan.textContent = 'Aucune';
    
    // Retirer toutes les sélections visuelles
    document.querySelectorAll('.weapon-card.selected').forEach(card => {
        card.classList.remove('selected');
    });
    document.querySelectorAll('.map-card.selected').forEach(card => {
        card.classList.remove('selected');
    });
}

function updateJoinButton() {
    const createBtn = document.getElementById('createBtn');
    const joinBtn = document.getElementById('joinBtn');
    const selectedWeaponSpan = document.getElementById('selectedWeapon');
    const selectedMapSpan = document.getElementById('selectedMap');
    const playersCountSpan = document.getElementById('playersCount');
    
    // Mettre à jour l'affichage des sélections
    if (selectedWeaponSpan) {
        selectedWeaponSpan.textContent = selectedWeapon ? selectedWeapon.toUpperCase() : 'Aucun';
    }
    if (selectedMapSpan) {
        selectedMapSpan.textContent = selectedMap ? selectedMap.toUpperCase() : 'Aucune';
    }
    
    // Mettre à jour le compteur de joueurs
    if (playersCountSpan) {
        playersCountSpan.textContent = availableArenas.length + '/2';
    }
    
    // Activer le bouton créer si au moins une arme et une map sont sélectionnées
    if (selectedWeapon && selectedMap) {
        createBtn.disabled = false;
    } else {
        createBtn.disabled = true;
    }
    
    // Activer le bouton rejoindre s'il y a des arènes disponibles
    if (selectedWeapon && selectedMap) {
        joinBtn.disabled = availableArenas.length === 0;
    } else {
        joinBtn.disabled = true;
    }
}

// Event listeners
document.addEventListener('DOMContentLoaded', function() {
    console.log('[DUEL] DOM chargé');
    
    // Sélection des armes
    const weaponCards = document.querySelectorAll('.weapon-card');
    weaponCards.forEach(card => {
        card.addEventListener('click', function() {
            // Retirer la sélection précédente
            weaponCards.forEach(c => c.classList.remove('selected'));
            // Ajouter la sélection à la carte cliquée
            this.classList.add('selected');
            selectedWeapon = this.dataset.weapon;
            console.log('[DUEL] Arme sélectionnée:', selectedWeapon);
            updateJoinButton();
        });
    });
    
    // Sélection des maps
    const mapCards = document.querySelectorAll('.map-card');
    mapCards.forEach(card => {
        card.addEventListener('click', function() {
            // Retirer la sélection précédente
            mapCards.forEach(c => c.classList.remove('selected'));
            // Ajouter la sélection à la carte cliquée
            this.classList.add('selected');
            selectedMap = this.dataset.map;
            console.log('[DUEL] Map sélectionnée:', selectedMap);
            updateJoinButton();
        });
    });
    
    // Bouton créer l'arène
    const createBtn = document.getElementById('createBtn');
    if (createBtn) {
        createBtn.addEventListener('click', function() {
            console.log('[DUEL] Bouton créer cliqué');
            
            if (selectedWeapon && selectedMap) {
                console.log('[DUEL] Créer l\'arène avec:', selectedWeapon, selectedMap);
                
                const payload = {
                    weapon: selectedWeapon,
                    map: selectedMap
                };
                
                fetch(`https://duel_1v1/createArena`, {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json'
                    },
                    body: JSON.stringify(payload)
                }).then(response => {
                    console.log('[DUEL] Réponse créer arène - Status:', response.status);
                    return response.text();
                }).then(text => {
                    console.log('[DUEL] Réponse texte:', text);
                }).catch(err => {
                    console.log('[DUEL] Erreur créer arène:', err);
                });
            }
        });
    }
    
    // Bouton rejoindre une arène
    const joinBtn = document.getElementById('joinBtn');
    if (joinBtn) {
        joinBtn.addEventListener('click', function() {
            console.log('[DUEL] Bouton rejoindre cliqué');
            
            if (selectedWeapon && availableArenas.length > 0) {
                console.log('[DUEL] Rejoindre une arène avec:', selectedWeapon);
                
                const payload = {
                    weapon: selectedWeapon
                };
                
                fetch(`https://duel_1v1/joinArena`, {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json'
                    },
                    body: JSON.stringify(payload)
                }).then(response => {
                    console.log('[DUEL] Réponse rejoindre arène - Status:', response.status);
                    return response.text();
                }).then(text => {
                    console.log('[DUEL] Réponse texte:', text);
                }).catch(err => {
                    console.log('[DUEL] Erreur rejoindre arène:', err);
                });
            } else {
                console.log('[DUEL] Impossible de rejoindre - Sélections manquantes');
            }
        });
    }
    
    // Bouton fermer
    const closeBtn = document.getElementById('closeBtn');
    if (closeBtn) {
        closeBtn.addEventListener('click', function() {
            console.log('[DUEL] Bouton fermer cliqué');
            fetch(`https://duel_1v1/closeMenu`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({})
            }).then(response => {
                console.log('[DUEL] Menu fermé');
            }).catch(err => {
                console.log('[DUEL] Erreur fermeture:', err);
            });
        });
    }
});

// Fermer avec Échap
document.addEventListener('keydown', function(event) {
    if (event.key === 'Escape') {
        console.log('[DUEL] Échap pressé');
        fetch(`https://duel_1v1/closeMenu`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({})
        }).catch(err => console.log('[DUEL] Erreur:', err));
    }
});

function updateAvailableArenas(arenas) {
    console.log('[DUEL] Mise à jour des arènes disponibles:', arenas);
    availableArenas = arenas || [];
    updateJoinButton();
}