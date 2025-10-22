window.addEventListener("load", initialize);

// Handle case where executeCommand might not be available
if (typeof window.executeCommand === 'function') {
    window.channel = window.executeCommand("get-channel");
} else {
    // Fallback for testing without the CEF backend
    window.channel = Promise.resolve("main");
    window.executeCommand = function(command, ...args) {
        console.log("Mock executeCommand:", command, ...args);
        return Promise.resolve(null);
    };
}

// Game data is now handled individually in each page's HTML file

function sleep(milliseconds) {
    return new Promise(resolve => {
        setTimeout(resolve, milliseconds);
    });
}

function makeSleep(milliseconds) {
    return () => sleep(milliseconds);
}

function waitForAllImages() {
    return new Promise(resolve => {
        function waitForAllImagesInternal() {
            const images = document.querySelectorAll('img');

            for (var i = 0; i < images.length; ++i) {
                if (!images[i].complete) {
                    window.requestAnimationFrame(waitForAllImagesInternal);
                    return;
                }
            }

            resolve();
        }

        waitForAllImagesInternal();
    });
}

function addStyleElement(css) {
    var head = document.head || document.getElementsByTagName('head')[0],
        style = document.createElement('style');

    head.appendChild(style);

    style.type = 'text/css';
    if (style.styleSheet) {
        // This is required for IE8 and below.
        style.styleSheet.cssText = css;
    } else {
        style.appendChild(document.createTextNode(css));
    }
}

function getOtherChannel(channel) {
    if (channel == "main") {
        return "dev";
    }
    return "main";
}

function adjustChannelElements() {
    window.channel.then(channel => {
        addStyleElement(`.channel-${getOtherChannel(channel)}{display: none;}`);
    });
}

// All game-specific functionality is now handled in individual page files

function initialize() {
    // Remove hidden class immediately to show the UI
    document.body.classList.remove('hidden');

    // Preload all game images first
    preloadGameImages().then(() => {
        console.log('All game images preloaded');
        // Load sidebar icons safely
        loadSidebarIcons();
    });

    initializeNavigation()
        .then(() => waitForAllImages())
        .then(makeSleep(300))
        .then(() => {
            // Try to call show command, but don't break if it fails
            try {
                window.executeCommand("show");
            } catch (error) {
                console.log("Show command not available:", error);
            }
        });

    document.querySelector("#minimize-button").onclick = () => {
        try {
            window.executeCommand("minimize");
        } catch (error) {
            console.log("Minimize command not available:", error);
        }
    };

    document.querySelector("#close-button").onclick = () => {
        try {
            window.executeCommand("close");
        } catch (error) {
            console.log("Close command not available:", error);
        }
    };

    adjustChannelElements();
}

window.showSettings = function() {
    document.querySelector("#settings").click();
}

function initializeNavigation() {
    // Handle home navigation
    const homeElement = document.querySelector("#home");
    homeElement.addEventListener("click", handleHomeClick);

    // Handle game navigation
    const gameElements = document.querySelectorAll(".game-item");
    gameElements.forEach(el => {
        el.addEventListener("click", handleGameClick);
    });

    // Handle settings navigation
    const settingsElement = document.querySelector("#settings");
    settingsElement.addEventListener("click", handleSettingsClick);

    // Initialize with home view
    return loadNavigationPage("home");
}

function removeActiveNavigation() {
    // Remove active from nav items
    const activeNavItem = document.querySelector(".nav-item.active");
    if (activeNavItem) {
        activeNavItem.classList.remove("active");
    }

    // Remove active from game items and game-specific classes
    const activeGameItem = document.querySelector(".game-item.active");
    if (activeGameItem) {
        activeGameItem.classList.remove("active");
        // Remove all game-specific active classes
        activeGameItem.classList.remove("iw4x-active", "iw6x-active", "s1x-active", "h1-mod-active", "iw7-mod-active", "hmw-mod-active");
    }
}

function handleHomeClick(e) {
    const el = this;
    if (el.classList.contains("active")) {
        return;
    }

    removeActiveNavigation();
    el.classList.add("active");
    loadNavigationPage("home");
}

function handleGameClick(e) {
    try {
        const el = this;
        const gameId = el.dataset.game;

        if (!gameId) {
            console.error("No game ID found in data-game attribute");
            return;
        }

        if (el.classList.contains("active")) {
            return;
        }

        removeActiveNavigation();
        el.classList.add("active");
        // Add game-specific active class for color matching
        el.classList.add(`${gameId}-active`);
        loadNavigationPage(gameId).catch(error => {
            console.error(`Failed to load game page ${gameId}:`, error);
            // Remove active class if loading failed
            el.classList.remove("active", `${gameId}-active`);
        });
    } catch (error) {
        console.error("Error in handleGameClick:", error);
    }
}

function handleSettingsClick(e) {
    const el = this;
    if (el.classList.contains("active")) {
        return;
    }

    removeActiveNavigation();
    el.classList.add("active");
    loadNavigationPage("settings");
}

// setInnerHTML function removed - no longer needed with single page approach

function loadBackgroundImage(gameId) {
    const heroSection = document.querySelector(`.hero-section.${gameId}`);
    if (!heroSection || !gameId) return;

    const imagePath = GameUtils.getHeroImagePath(gameId);
    if (!imagePath) return;

    if (preloadedImages[imagePath]) {
        // Image is already preloaded, apply immediately
        heroSection.style.backgroundImage = `url('${imagePath}')`;
        heroSection.style.backgroundSize = 'cover';
        heroSection.style.backgroundPosition = 'center';
        heroSection.style.backgroundRepeat = 'no-repeat';
        console.log(`Background image loaded for ${gameId} (from cache)`);
    } else {
        // Fallback to loading on demand
        const img = new Image();
        img.onload = function() {
            heroSection.style.backgroundImage = `url('${imagePath}')`;
            heroSection.style.backgroundSize = 'cover';
            heroSection.style.backgroundPosition = 'center';
            heroSection.style.backgroundRepeat = 'no-repeat';
            console.log(`Background image loaded for ${gameId}`);
        };
        img.onerror = function() {
            console.log(`Background image failed to load for ${gameId}, using gradient fallback`);
            heroSection.style.backgroundImage = 'none';
        };
        img.src = imagePath;
    }
}

function loadHomeBackgroundImage() {
    const heroSection = document.querySelector('.hero-section.home');
    if (!heroSection) return;

    const imagePath = './img/cb-hero.png';

    if (preloadedImages[imagePath]) {
        // Image is already preloaded, apply immediately
        heroSection.style.backgroundImage = `url('${imagePath}')`;
        heroSection.style.backgroundSize = 'cover';
        heroSection.style.backgroundPosition = 'center';
        heroSection.style.backgroundRepeat = 'no-repeat';
        console.log('CB hero background image loaded (from cache)');
    } else {
        // Fallback to loading on demand
        const img = new Image();
        img.onload = function() {
            heroSection.style.backgroundImage = `url('${imagePath}')`;
            heroSection.style.backgroundSize = 'cover';
            heroSection.style.backgroundPosition = 'center';
            heroSection.style.backgroundRepeat = 'no-repeat';
            console.log('CB hero background image loaded');
        };
        img.onerror = function() {
            console.log('CB hero background image failed to load, using gradient fallback');
            heroSection.style.backgroundImage = 'none';
        };
        img.src = imagePath;
    }
}

// Cache for preloaded images
const preloadedImages = {};

function preloadGameImages() {
    const imageMap = GameUtils.getAllGameImages();

    return Promise.all(
        Object.entries(imageMap).map(([gameId, imagePaths]) => {
            return Promise.all(
                imagePaths.map(imagePath => {
                    return new Promise((resolve) => {
                        const img = new Image();
                        img.onload = function() {
                            preloadedImages[imagePath] = img;
                            console.log(`Preloaded image: ${imagePath}`);
                            resolve(true);
                        };
                        img.onerror = function() {
                            console.log(`Failed to preload image: ${imagePath}`);
                            resolve(false);
                        };
                        img.src = imagePath;
                    });
                })
            );
        })
    );
}

function loadSidebarIcons() {
    const gameIds = ['boiii', 'iw6x', 's1x', 'h1-mod', 'iw7-mod', 'hmw-mod'];

    gameIds.forEach(gameId => {
        const thumbnail = document.querySelector(`.${gameId}-thumb`);
        if (!thumbnail) return;

        const imagePath = GameUtils.getIconPath(gameId);
        if (preloadedImages[imagePath]) {
            // Image is already preloaded, apply immediately
            thumbnail.style.backgroundImage = `url('${imagePath}')`;
            console.log(`Sidebar icon loaded for ${gameId} (from cache)`);
        } else {
            // Fallback to loading on demand
            const img = new Image();
            img.onload = function() {
                thumbnail.style.backgroundImage = `url('${imagePath}')`;
                console.log(`Sidebar icon loaded for ${gameId}`);
            };
            img.onerror = function() {
                console.log(`Sidebar icon failed to load for ${gameId}, using gradient fallback`);
            };
            img.src = imagePath;
        }
    });
}

// Game Installation Manager
window.GameInstallationManager = {
    async checkInstallation(gameId) {
        const config = GameUtils.getGameConfigByUIId(gameId);
        if (!config) return false;

        try {
            if (typeof window.executeCommand === 'function') {
                const isInstalled = await window.executeCommand('get-property', config.isInstalledProperty);
                return isInstalled && isInstalled.trim() === 'true';
            } else {
                // Mock for development
                console.log(`Mock: Checking installation for ${gameId}`);
                return false; // Default to not installed for testing
            }
        } catch (error) {
            console.error('Error checking installation:', error);
            return false;
        }
    },

    getInstallProperty(gameId) {
        const config = GameUtils.getGameConfigByUIId(gameId);
        return config ? config.installProperty : null;
    },

    getGameMapping(gameId) {
        return GameUtils.getGameMapping(gameId);
    },

    getGameDisplayName(gameId) {
        const config = GameUtils.getGameConfigByUIId(gameId);
        return config ? config.displayName : gameId;
    }
};

// Global Progress Manager
window.ProgressManager = {
    isActive: false,
    currentGame: null,
    cancelCallback: null,

    show: function(gameId, message = 'Processing...', onCancel = null) {
        const progressBar = document.getElementById('global-progress-bar');
        const progressInfo = document.getElementById('progress-info');
        const progressGameIcon = document.getElementById('progress-game-icon');
        const progressFill = document.getElementById('global-progress-fill');
        const progressPercent = document.getElementById('global-progress-percent');
        const cancelBtn = document.getElementById('progress-cancel-btn');
        const windowEl = document.querySelector('.window');

        if (!progressBar) {
            console.error('Global progress bar not found');
            return;
        }

        this.isActive = true;
        this.currentGame = gameId;
        this.cancelCallback = onCancel;

        // Apply game-specific theming
        progressBar.className = 'global-progress-bar';
        if (gameId) {
            progressBar.classList.add(gameId);
        }

        // Set game icon
        progressGameIcon.className = 'progress-game-icon';
        if (gameId) {
            progressGameIcon.classList.add(gameId);

            // Try to load the actual game image if it's preloaded
            const imagePath = GameUtils.getIconPath(gameId);
            if (imagePath && preloadedImages[imagePath]) {
                progressGameIcon.style.backgroundImage = `url('${imagePath}')`;
            }
        }

        // Set initial state
        progressInfo.textContent = message;
        progressFill.style.width = '0%';
        progressPercent.textContent = '0%';

        // Setup cancel button
        if (cancelBtn) {
            cancelBtn.onclick = () => this.cancel();
        }

        // Disable all game buttons
        this.disableButtons();

        // Show progress bar and adjust window padding
        progressBar.style.display = 'flex';
        windowEl.classList.add('progress-active');
    },

    update: function(progress, message = null) {
        const progressInfo = document.getElementById('progress-info');
        const progressFill = document.getElementById('global-progress-fill');
        const progressPercent = document.getElementById('global-progress-percent');

        if (message) {
            progressInfo.textContent = message;
        }

        progressFill.style.width = `${progress}%`;
        progressPercent.textContent = `${Math.floor(progress)}%`;
    },

    cancel: function() {
        if (this.cancelCallback) {
            this.cancelCallback();
        }
        this.hide();
    },

    hide: function() {
        const progressBar = document.getElementById('global-progress-bar');
        const windowEl = document.querySelector('.window');

        if (progressBar) {
            progressBar.style.display = 'none';
            progressBar.className = 'global-progress-bar'; // Reset theming
        }
        if (windowEl) {
            windowEl.classList.remove('progress-active');
        }

        // Re-enable all game buttons
        this.enableButtons();

        this.isActive = false;
        this.currentGame = null;
        this.cancelCallback = null;
    },

    disableButtons: function() {
        const buttons = document.querySelectorAll('.play-button, .verify-button');
        buttons.forEach(btn => {
            btn.disabled = true;
        });
        console.log(`Disabled ${buttons.length} buttons`);
    },

    enableButtons: function() {
        const buttons = document.querySelectorAll('.play-button, .verify-button');
        buttons.forEach(btn => {
            btn.disabled = false;
        });
        console.log(`Enabled ${buttons.length} buttons`);
    }
};

function loadNavigationPage(page) {
    console.log(`Loading page: ${page}`);

    // Hide all page sections
    const allPages = document.querySelectorAll('.page-section');
    allPages.forEach(pageEl => {
        pageEl.style.display = 'none';
    });

    // Show the target page
    const targetPage = document.getElementById(`${page}-page`);
    if (!targetPage) {
        console.error(`Page not found: ${page}-page`);
        return Promise.reject(`Page not found: ${page}-page`);
    }

    targetPage.style.display = 'block';

    // Initialize page-specific functionality
    if (page === 'settings') {
        initializeSettingsPage();
    } else if (['boiii', 'iw6x', 's1x', 'h1-mod', 'iw7-mod', 'hmw-mod'].includes(page)) {
        initializeGamePage(page);
    }

    // Load background images
    if (['boiii', 'iw6x', 's1x', 'h1-mod', 'iw7-mod', 'hmw-mod'].includes(page)) {
        loadBackgroundImage(page);
    } else if (page === 'home') {
        loadHomeBackgroundImage();
    } else {
        // Clear background image for other pages - no need to clear since each page has its own hero section
    }

    // Handle progress manager state
    if (window.ProgressManager && window.ProgressManager.isActive) {
        setTimeout(() => {
            window.ProgressManager.disableButtons();
        }, 0);
    }

    return Promise.resolve();
}

// Game page initialization
let gamePopups = {};

function initializeGamePage(gameId) {
    console.log(`Initializing game page: ${gameId}`);

    // Initialize popups if not already done
    if (!gamePopups[gameId]) {
        gamePopups[gameId] = {
            gameModePopup: null,
            gameSettingsPopup: null,
            setupFlowPopup: null
        };
    }

    // Create buttons for the game
    createGameButtons(gameId);
}

async function createGameButtons(gameId) {
    const buttonGroup = document.getElementById(`${gameId}-button-group`);
    if (!buttonGroup) return;

    // Check installation status
    const isInstalled = await window.GameInstallationManager.checkInstallation(gameId);
    console.log(`${gameId} installation status:`, isInstalled);

    if (isInstalled) {
        // Show PLAY, VERIFY, and SETTINGS buttons
        buttonGroup.innerHTML = `
            <div class="left-buttons">
                <button class="play-button" id="${gameId}-play-button">
                    <div class="play-icon"></div>
                    PLAY
                </button>
                <button class="verify-button" id="${gameId}-verify-button">
                    VERIFY
                </button>
            </div>
            <div class="right-buttons">
                <button class="game-settings-btn" id="${gameId}-game-settings-btn" title="Game Settings">
                    <div class="settings-icon"></div>
                </button>
            </div>
        `;

        // Attach event listeners
        document.getElementById(`${gameId}-play-button`).onclick = () => launchGame(gameId);
        document.getElementById(`${gameId}-verify-button`).onclick = () => verifyGame(gameId);
        document.getElementById(`${gameId}-game-settings-btn`).onclick = () => showGameSettings(gameId);
    } else {
        // Show SETUP button only
        buttonGroup.innerHTML = `
            <div class="left-buttons">
                <button class="setup-button" id="${gameId}-setup-button">
                    SETUP
                </button>
            </div>
        `;

        // Attach event listener
        document.getElementById(`${gameId}-setup-button`).onclick = () => showSetupFlow(gameId);
    }

    // Handle progress manager state
    if (window.ProgressManager && window.ProgressManager.isActive) {
        const buttons = buttonGroup.querySelectorAll('button:not(.game-settings-btn)');
        buttons.forEach(btn => btn.disabled = true);
    }
}

function launchGame(gameId) {
    console.log(`Play button clicked for ${gameId}`);

    const gameMapping = GameUtils.getGameMapping(gameId);
    const gameConfig = GameUtils.getGameConfig(gameMapping);

    if (!gameConfig) {
        console.error(`No configuration found for game: ${gameId}`);
        return;
    }

    // Check if game has multiple modes
    if (gameConfig.hasMultipleModes) {
        // Show mode selection popup for games with multiple modes
        if (!gamePopups[gameId].gameModePopup) {
            gamePopups[gameId].gameModePopup = new GameModePopup();
        }
        gamePopups[gameId].gameModePopup.show(gameMapping, gameConfig);
    } else {
        // Launch directly for single-mode games
        const installProperty = gameConfig.installProperty;
        window.executeCommand('get-property', installProperty).then(folder => {
            if (!folder) {
                const gameName = gameConfig.displayName;
                if (typeof window.showMessageBox === 'function') {
                    window.showMessageBox(`⚙ ${gameName} not configured`,
                        `You have not configured your <b>${gameName} installation</b> path.<br><br>Please do so in the settings!`, ["Ok"]).then(index => {
                        if (typeof window.showSettings === 'function') {
                            window.showSettings();
                        }
                    });
                } else {
                    alert(`${gameName} installation path not configured. Please configure it in settings.`);
                }
            } else {
                // Use launch-game command for all games
                window.executeCommand('launch-game', { game: gameMapping }).then(() => {
                    console.log(`Launching ${gameId} directly`);
                }).catch(error => {
                    console.error(`Failed to launch ${gameId}:`, error);
                });
            }
        }).catch(error => {
            console.error(`Failed to get ${gameId} install property:`, error);
        });
    }
}

function showGameSettings(gameId) {
    console.log(`Game settings button clicked for ${gameId}`);

    if (!gamePopups[gameId].gameSettingsPopup) {
        gamePopups[gameId].gameSettingsPopup = new GameSettingsPopup();
    }

    const gameMapping = GameUtils.getGameMapping(gameId);
    const gameConfig = GameUtils.getGameConfig(gameMapping);
    gamePopups[gameId].gameSettingsPopup.show(gameMapping, gameConfig);
}

function verifyGame(gameId) {
    console.log(`Verify button clicked for ${gameId}`);

    const gameMapping = GameUtils.getGameMapping(gameId);
    const gameDisplayName = window.GameInstallationManager.getGameDisplayName(gameId);

    let pollInterval;

    const cancelVerification = () => {
        if (pollInterval) {
            clearInterval(pollInterval);
            console.log('Verification cancelled');
        }
        // Call backend to cancel the update
        window.executeCommand('cancel-update').then(() => {
            console.log('Cancel command sent to backend');
        }).catch(error => {
            console.error('Failed to send cancel command:', error);
        });
    };

    // Show progress bar
    window.ProgressManager.show(gameId, `Verifying ${gameDisplayName}...`, cancelVerification);

    // Start verification command
    window.executeCommand('verify-game', { game: gameMapping }).catch(error => {
        console.error('Failed to start verification:', error);
        window.ProgressManager.hide();
    });

    setTimeout(() => {
        // Poll for progress updates
        pollInterval = setInterval(async () => {
            try {
                const result = await window.executeCommand('get-update-progress');

                if (!result) {
                    console.log('No progress data received');
                    return;
                }

                if (!result.active) {
                    console.log('Update no longer active');
                    // Verification complete
                    clearInterval(pollInterval);
                    window.ProgressManager.update(100, 'Verification complete!');

                    // Trigger UI update in case verification installed missing files
                    window.dispatchEvent(new CustomEvent('gameInstallationUpdated', {
                        detail: { game: gameMapping }
                    }));

                    setTimeout(() => {
                        window.ProgressManager.hide();
                    }, 1000);
                    return;
                }

                // Update progress
                console.log(`Updating progress: ${result.message}, ${result.progress}`);
                window.ProgressManager.update(result.progress, result.message);
            } catch (error) {
                console.error('Error polling progress:', error);
                clearInterval(pollInterval);
                window.ProgressManager.hide();
            }
        }, 100); // Poll every 100ms
    }, 500); // This is the initial 500ms delay
}

function showSetupFlow(gameId) {
    console.log(`Setup button clicked for ${gameId}`);

    if (!gamePopups[gameId].setupFlowPopup) {
        gamePopups[gameId].setupFlowPopup = new SetupFlowPopup();
    }

    const gameDisplayName = window.GameInstallationManager.getGameDisplayName(gameId);
    const gameMapping = window.GameInstallationManager.getGameMapping(gameId);
    gamePopups[gameId].setupFlowPopup.show(gameMapping, gameDisplayName);
}


// Settings page functionality
let settingsPopup;


async function resetAllSettings() {
    const result = await window.showMessageBox(
        "⚠️ Reset Settings",
        "Are you sure you want to reset all game settings to defaults? This will clear all game installation paths and settings.",
        ["Cancel", "Reset"]
    );

    if (result === 1) {
        if (typeof executeCommand === 'function') {
            try {
                await executeCommand('set-property', GameUtils.getResetProperties());

                await executeCommand('reset-settings');

                window.dispatchEvent(new CustomEvent('gameInstallationUpdated', {
                    detail: { game: 'all' }
                }));

                window.showMessageBox("✓ Settings Reset", "All game settings have been reset to defaults!", ["OK"]);
                await initializeSettingsPage();
            } catch (error) {
                console.error('Failed to reset settings:', error);
                window.showMessageBox("✗ Reset Failed", "Failed to reset settings. Please try again.", ["OK"]);
            }
        }
    }
}

function showSettingsGameSettings(gameId) {
    console.log('Settings game settings button clicked for:', gameId);

    if (!settingsPopup) {
        settingsPopup = new GameSettingsPopup();
    }

    const gameMapping = GameUtils.getGameMapping(gameId);
    const gameConfig = GameUtils.getGameConfig(gameMapping);
    if (gameConfig) {
        settingsPopup.show(gameMapping, gameConfig);
    }
}

async function checkGameInstallation(gameId) {
    const config = GameUtils.getGameConfigByUIId(gameId);
    if (!config) return false;

    try {
        if (typeof window.executeCommand === 'function') {
            const isInstalled = await window.executeCommand('get-property', config.isInstalledProperty);
            return isInstalled && isInstalled.trim() === 'true';
        } else {
            console.log(`Mock: Checking installation for ${gameId}`);
            return Math.random() > 0.5;
        }
    } catch (error) {
        console.error(`Error checking installation for ${gameId}:`, error);
        return false;
    }
}

async function populateGamesList() {
    const gamesList = document.getElementById('games-list');
    if (!gamesList) return;

    console.log('Populating games list...');
    gamesList.innerHTML = '';

    let installedGamesCount = 0;

    const gameIds = ['boiii', 'iw6x', 's1x', 'h1-mod', 'iw7-mod', 'hmw-mod'];

    for (const gameId of gameIds) {
        console.log(`Checking installation for ${gameId}...`);
        const isInstalled = await checkGameInstallation(gameId);
        console.log(`${gameId} installation status:`, isInstalled);

        if (isInstalled) {
            installedGamesCount++;
            const config = GameUtils.getGameConfigByUIId(gameId);
            if (!config) continue;

            const gameItem = document.createElement('div');
            gameItem.className = 'game-settings-item';
            gameItem.setAttribute('data-game', gameId);

            gameItem.innerHTML = `
                <div class="game-settings-info">
                    <div class="game-settings-name">${config.displayName} - ${config.codeName}</div>
                </div>
                <button class="game-settings-btn" data-game="${gameId}" title="Game Settings">
                    <div class="settings-icon"></div>
                </button>
            `;

            gamesList.appendChild(gameItem);

            const settingsButton = gameItem.querySelector('.game-settings-btn');
            settingsButton.addEventListener('click', function() {
                const gameKey = this.getAttribute('data-game');
                showSettingsGameSettings(gameKey);
            });
        }
    }

    // Update description and reset button visibility based on installed games
    const descriptionEl = document.querySelector('.settings-description');
    const resetButton = document.querySelector('.reset-button');

    if (installedGamesCount === 0) {
        if (descriptionEl) {
            descriptionEl.textContent = 'No games installed. To install games, click on a game in the sidebar and then click the SETUP button.';
        }
        if (resetButton) {
            resetButton.style.display = 'none';
        }
    } else {
        if (descriptionEl) {
            descriptionEl.textContent = 'You can manage settings for installed games here.';
        }
        if (resetButton) {
            resetButton.style.display = 'block';
        }
    }

    console.log('Games list populated');
}

async function initializeSettingsPage() {
    console.log('=== Initializing settings page ===');
    await populateGamesList();
    console.log('Settings page initialized');
}

// Listen for installation updates globally
window.addEventListener('gameInstallationUpdated', (event) => {
    console.log('Installation updated globally');
    const targetGame = event.detail.game;

    // Refresh settings page if it's visible
    const settingsPage = document.getElementById('settings-page');
    if (settingsPage && settingsPage.style.display !== 'none') {
        initializeSettingsPage();
    }

    // Refresh game pages if needed
    const gamePages = document.querySelectorAll('.game-page');
    gamePages.forEach(page => {
        if (page.style.display !== 'none') {
            const gameId = page.id.replace('-page', '');
            if (targetGame === 'all' || targetGame === window.GameInstallationManager.getGameMapping(gameId)) {
                createGameButtons(gameId);
            }
        }
    });
});