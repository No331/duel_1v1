console.log('[DUEL] Script JS chargé');

let selectedWeapon = null;
let selectedMap = null;

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
    const joinBtn = document.getElementById('joinBtn');
    const selectedWeaponSpan = document.getElementById('selectedWeapon');
    const selectedMapSpan = document.getElementById('selectedMap');
    
    // Mettre à jour l'affichage des sélections
    if (selectedWeaponSpan) {
        selectedWeaponSpan.textContent = selectedWeapon ? selectedWeapon.toUpperCase() : 'Aucun';
    }
    if (selectedMapSpan) {
        selectedMapSpan.textContent = selectedMap ? selectedMap.toUpperCase() : 'Aucune';
    }
    
    // Activer le bouton si au moins une arme et une map sont sélectionnées
    if (selectedWeapon && selectedMap) {
        joinBtn.disabled = false;
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
    
    // Bouton rejoindre l'arène
    const joinBtn = document.getElementById('joinBtn');
    if (joinBtn) {
        joinBtn.addEventListener('click', function() {
            if (selectedWeapon && selectedMap) {
                console.log('[DUEL] Rejoindre l\'arène avec:', selectedWeapon, selectedMap);
                fetch(`https://duel_1v1/joinArena`, {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json'
                    },
                    body: JSON.stringify({
                        weapon: selectedWeapon,
                        map: selectedMap
                    })
                }).then(response => {
                    console.log('[DUEL] Réponse rejoindre arène:', response);
                }).catch(err => {
                    console.log('[DUEL] Erreur rejoindre arène:', err);
                });
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