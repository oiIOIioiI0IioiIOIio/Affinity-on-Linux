#!/bin/bash

###############################################################################
#
#  AFFINITY ON LINUX — UNIVERSAL INSTALLER
#  Version 1.0
#
#  Supports: Ubuntu, Debian, Linux Mint, Fedora, Nobara, Arch, Manjaro,
#            openSUSE, Pop!_OS, Zorin, elementary OS, and derivatives
#
#  Requirements: Wine 10.17+, winetricks, curl
#  Disk space:   ~10 GB free
#
#  Usage: bash affinity_install.sh [--help] [--repair] [--uninstall]
#
###############################################################################

set -o pipefail

# ─────────────────────────────────────────────────────────────────────────────
# COLORS AND FORMATTING
# ─────────────────────────────────────────────────────────────────────────────
C_RED='\033[0;31m'
C_GREEN='\033[0;32m'
C_YELLOW='\033[1;33m'
C_BLUE='\033[0;34m'
C_CYAN='\033[0;36m'
C_MAGENTA='\033[0;35m'
C_BOLD='\033[1m'
C_DIM='\033[2m'
C_NC='\033[0m'

# ─────────────────────────────────────────────────────────────────────────────
# GLOBALS
# ─────────────────────────────────────────────────────────────────────────────
WINEPREFIX="${WINEPREFIX:-$HOME/.affinity}"
TEMP_DIR="/tmp/affinity_install"
LOG_FILE="$HOME/affinity_install.log"
AFFINITY_INSTALLER=""
AFFINITY_INSTALL_DIR=""
DISTRO_ID=""
DISTRO_FAMILY=""   # debian | fedora | arch | suse
SCRIPT_MODE="install"   # install | repair | uninstall
TOTAL_ERRORS=0

# ─────────────────────────────────────────────────────────────────────────────
# PRINT HELPERS
# ─────────────────────────────────────────────────────────────────────────────
print_header() {
    clear
    echo -e "${C_BLUE}${C_BOLD}"
    echo    "  ╔══════════════════════════════════════════════════════════════╗"
    echo    "  ║           AFFINITY ON LINUX — UNIVERSAL INSTALLER           ║"
    echo    "  ║    Wine 10.17+  |  All major distros  |  Auto-repair        ║"
    echo    "  ╚══════════════════════════════════════════════════════════════╝"
    echo -e "${C_NC}"
    echo -e "  ${C_DIM}Log file: $LOG_FILE${C_NC}"
    echo ""
}

print_section() {
    echo ""
    echo -e "${C_MAGENTA}  ┌─────────────────────────────────────────────────────────────┐${C_NC}"
    echo -e "${C_MAGENTA}  │ ${C_CYAN}${C_BOLD} $1 ${C_NC}${C_MAGENTA}│${C_NC}"
    echo -e "${C_MAGENTA}  └─────────────────────────────────────────────────────────────┘${C_NC}"
    echo ""
}

ok()      { echo -e "  ${C_GREEN}[  OK  ]${C_NC}  $1";   log "OK:   $1"; }
fail()    { echo -e "  ${C_RED}[ FAIL ]${C_NC}  $1";   log "FAIL: $1"; TOTAL_ERRORS=$((TOTAL_ERRORS+1)); }
warn()    { echo -e "  ${C_YELLOW}[ WARN ]${C_NC}  $1";   log "WARN: $1"; }
info()    { echo -e "  ${C_BLUE}[ INFO ]${C_NC}  $1";   log "INFO: $1"; }
step()    { echo -e "  ${C_CYAN}[  >>  ]${C_NC}  $1";   log "STEP: $1"; }
detail()  { echo -e "  ${C_DIM}         $1${C_NC}";     log "    : $1"; }

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

ask() {
    # ask <question> — returns 0 for yes, 1 for no
    local prompt="$1"
    echo ""
    read -p "  ${C_YELLOW}[  ?  ]${C_NC}  $prompt (y/n) " -n 1 -r
    echo ""
    [[ $REPLY =~ ^[Yy]$ ]]
}

pause() {
    echo ""
    read -p "  ${C_DIM}Press Enter to continue...${C_NC}" -r
    echo ""
}

abort() {
    echo ""
    fail "$1"
    echo ""
    echo -e "  ${C_RED}${C_BOLD}Installation aborted.${C_NC}"
    echo -e "  ${C_DIM}See full log: $LOG_FILE${C_NC}"
    echo ""
    exit 1
}

# ─────────────────────────────────────────────────────────────────────────────
# ARGUMENT PARSING
# ─────────────────────────────────────────────────────────────────────────────
parse_args() {
    for arg in "$@"; do
        case "$arg" in
            --help|-h)
                echo ""
                echo -e "${C_BOLD}AFFINITY ON LINUX — UNIVERSAL INSTALLER${C_NC}"
                echo ""
                echo "  Usage: bash affinity_install.sh [OPTIONS]"
                echo ""
                echo "  Options:"
                echo "    (none)       Full installation"
                echo "    --repair     Re-run checks and fix missing components"
                echo "    --uninstall  Remove Affinity Wine prefix and desktop entry"
                echo "    --help       Show this help"
                echo ""
                echo "  Environment variables:"
                echo "    WINEPREFIX   Override Wine prefix location (default: ~/.affinity)"
                echo ""
                exit 0
                ;;
            --repair)   SCRIPT_MODE="repair"    ;;
            --uninstall) SCRIPT_MODE="uninstall" ;;
        esac
    done
}

# ─────────────────────────────────────────────────────────────────────────────
# UNINSTALL
# ─────────────────────────────────────────────────────────────────────────────
do_uninstall() {
    print_section "UNINSTALL AFFINITY"
    warn "This will delete the entire Wine prefix at: $WINEPREFIX"
    warn "All Affinity data, settings and files inside it will be lost."
    echo ""
    if ask "Are you sure you want to uninstall?"; then
        step "Killing Wine processes..."
        pkill -f wineserver 2>/dev/null || true
        pkill -f wine 2>/dev/null || true
        sleep 1

        step "Removing Wine prefix..."
        rm -rf "$WINEPREFIX"
        ok "Wine prefix removed"

        step "Removing desktop entry..."
        rm -f "$HOME/Desktop/Affinity.desktop"
        rm -f "$HOME/.local/share/applications/Affinity.desktop"
        ok "Desktop entries removed"

        step "Removing log file..."
        rm -f "$LOG_FILE"

        echo ""
        ok "Affinity has been uninstalled."
    else
        info "Uninstall cancelled."
    fi
    exit 0
}

# ─────────────────────────────────────────────────────────────────────────────
# DISTRO DETECTION
# ─────────────────────────────────────────────────────────────────────────────
detect_distro() {
    print_section "DETECTING YOUR SYSTEM"

    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO_ID="${ID,,}"
        DISTRO_NAME="${NAME}"
        DISTRO_VERSION="${VERSION_ID}"
        DISTRO_LIKE="${ID_LIKE,,}"
    else
        abort "Cannot detect Linux distribution. /etc/os-release not found."
    fi

    log "Distro ID: $DISTRO_ID | Name: $DISTRO_NAME | Like: $DISTRO_LIKE"

    # Determine family
    case "$DISTRO_ID" in
        ubuntu|debian|linuxmint|pop|zorin|elementary|kali|neon|parrot|raspbian)
            DISTRO_FAMILY="debian" ;;
        fedora|nobara|rhel|centos|rocky|alma)
            DISTRO_FAMILY="fedora" ;;
        arch|manjaro|endeavouros|garuda|artix|cachyos)
            DISTRO_FAMILY="arch" ;;
        opensuse*|suse*)
            DISTRO_FAMILY="suse" ;;
        *)
            # Try ID_LIKE as fallback
            if [[ "$DISTRO_LIKE" == *"debian"* ]] || [[ "$DISTRO_LIKE" == *"ubuntu"* ]]; then
                DISTRO_FAMILY="debian"
            elif [[ "$DISTRO_LIKE" == *"fedora"* ]] || [[ "$DISTRO_LIKE" == *"rhel"* ]]; then
                DISTRO_FAMILY="fedora"
            elif [[ "$DISTRO_LIKE" == *"arch"* ]]; then
                DISTRO_FAMILY="arch"
            elif [[ "$DISTRO_LIKE" == *"suse"* ]]; then
                DISTRO_FAMILY="suse"
            else
                DISTRO_FAMILY="unknown"
            fi
            ;;
    esac

    ok "Distribution: $DISTRO_NAME"
    ok "Family:       $DISTRO_FAMILY"
    ok "Version:      ${DISTRO_VERSION:-unknown}"
    ok "Architecture: $(uname -m)"
    ok "Kernel:       $(uname -r)"

    if [ "$DISTRO_FAMILY" = "unknown" ]; then
        warn "Unknown distro family. Will attempt Debian-style package manager."
        warn "You may need to install Wine 10.17+ manually if this fails."
        DISTRO_FAMILY="debian"
    fi

    if [ "$(uname -m)" != "x86_64" ]; then
        abort "This installer requires a 64-bit x86 system (x86_64). Found: $(uname -m)"
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
# CHECK INTERNET
# ─────────────────────────────────────────────────────────────────────────────
check_internet() {
    step "Checking internet connection..."
    if curl -s --max-time 5 https://dl.winehq.org > /dev/null 2>&1; then
        ok "Internet connection active"
    else
        warn "Cannot reach dl.winehq.org — may be a network issue"
        warn "Continuing, but downloads may fail"
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
# CHECK DISK SPACE
# ─────────────────────────────────────────────────────────────────────────────
check_disk_space() {
    step "Checking disk space..."
    local available
    available=$(df "$HOME" | awk 'NR==2 {print $4}')
    local required=$((10 * 1024 * 1024))   # 10 GB in KB

    local avail_human
    avail_human=$(df -h "$HOME" | awk 'NR==2 {print $4}')

    if [ "$available" -lt "$required" ]; then
        abort "Not enough disk space. Required: 10 GB, Available: $avail_human"
    else
        ok "Disk space: $avail_human available (10 GB required)"
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
# FIND AFFINITY INSTALLER
# ─────────────────────────────────────────────────────────────────────────────
find_installer() {
    print_section "FINDING YOUR AFFINITY INSTALLER"

    info "Searching standard download locations..."

    local candidates=(
        "$HOME/Downloads/affinity.exe"
        "$HOME/Downloads/Affinity.exe"
        "$HOME/Downloads/Affinity x64.exe"
        "$HOME/Downloads/Affinity_x64.exe"
        "$HOME/Téléchargements/affinity.exe"
        "$HOME/Téléchargements/Affinity.exe"
        "$HOME/Téléchargements/Affinity x64.exe"
        "$HOME/Telechargements/affinity.exe"
        "$HOME/Telechargements/Affinity.exe"
        "$HOME/Telechargements/Affinity x64.exe"
        "$HOME/Desktop/affinity.exe"
        "$HOME/Desktop/Affinity.exe"
    )

    for c in "${candidates[@]}"; do
        if [ -f "$c" ]; then
            AFFINITY_INSTALLER="$c"
            break
        fi
    done

    if [ -n "$AFFINITY_INSTALLER" ]; then
        ok "Found: $AFFINITY_INSTALLER"
        local size
        size=$(du -h "$AFFINITY_INSTALLER" | cut -f1)
        detail "File size: $size"
    else
        warn "Affinity installer not found in standard locations."
        echo ""
        info "Download it first from: https://affinity.serif.com/v2/"
        info "or from:                https://affinity.studio/download"
        echo ""
        echo -e "  ${C_YELLOW}Enter the full path to your Affinity installer:${C_NC}"
        echo -e "  ${C_DIM}Example: /home/yourname/Downloads/affinity.exe${C_NC}"
        echo ""
        read -r -p "  Path: " AFFINITY_INSTALLER

        if [ ! -f "$AFFINITY_INSTALLER" ]; then
            abort "File not found: $AFFINITY_INSTALLER"
        fi
        ok "Using: $AFFINITY_INSTALLER"
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
# INSTALL WINE 10.17+ — per distro family
# ─────────────────────────────────────────────────────────────────────────────
check_wine_version() {
    local ver
    ver=$(wine --version 2>/dev/null | grep -oP '\d+\.\d+' | head -1)
    local major minor
    major=$(echo "$ver" | cut -d. -f1)
    minor=$(echo "$ver" | cut -d. -f2)

    [ -z "$major" ] && return 1   # not installed

    if [ "$major" -gt 10 ]; then return 0
    elif [ "$major" -eq 10 ] && [ "$minor" -ge 17 ]; then return 0
    else return 1
    fi
}

install_wine_debian() {
    step "Adding 32-bit architecture support..."
    sudo dpkg --add-architecture i386
    ok "i386 enabled"

    step "Adding WineHQ GPG key..."
    sudo mkdir -pm755 /etc/apt/keyrings
    sudo wget -q -O /etc/apt/keyrings/winehq.asc \
        https://dl.winehq.org/wine-builds/winehq.key
    ok "GPG key added"

    # Resolve codename — Linux Mint uses Ubuntu bases
    local codename
    codename=$(lsb_release -cs 2>/dev/null || echo "")

    case "$codename" in
        # Linux Mint 22.x → Ubuntu 24.04 noble
        wilma|virginia|victoria|vera) codename="noble" ;;
        # Linux Mint 21.x → Ubuntu 22.04 jammy
        una|uma|ulyssa|ulyana)        codename="jammy" ;;
        # Linux Mint 20.x → Ubuntu 20.04 focal
        elsie|faye|feline|ulyana)     codename="focal" ;;
        # Linux Mint LMDE / Debian bases
        bookworm|bullseye|buster)     : ;;  # already correct
        "")
            # Fallback: read from os-release
            if [ -n "$UBUNTU_CODENAME" ]; then
                codename="$UBUNTU_CODENAME"
            else
                codename="$(grep VERSION_CODENAME /etc/os-release | cut -d= -f2)"
            fi
            ;;
    esac

    detail "Using WineHQ repo for: $codename"

    step "Adding WineHQ repository..."
    sudo sh -c "echo \"deb [signed-by=/etc/apt/keyrings/winehq.asc] https://dl.winehq.org/wine-builds/ubuntu $codename main\" \
        > /etc/apt/sources.list.d/winehq.list"
    ok "Repository added"

    step "Updating package lists..."
    sudo apt-get update -qq
    ok "Package lists updated"

    step "Installing winehq-devel (Wine 10.17+)..."
    detail "This download is large (~200 MB) and may take a few minutes."
    sudo apt-get install --install-recommends winehq-devel -y
    ok "Wine installed: $(wine --version)"
}

install_wine_fedora() {
    step "Removing old Wine packages if present..."
    sudo dnf remove -y wine\* 2>/dev/null || true

    step "Adding WineHQ repository for Fedora..."
    local fedora_ver
    fedora_ver=$(rpm -E %fedora 2>/dev/null || echo "41")

    sudo rm -f /etc/yum.repos.d/winehq.repo
    sudo tee /etc/yum.repos.d/winehq.repo > /dev/null <<EOF
[winehq-devel]
name=WineHQ packages for Fedora $fedora_ver
baseurl=https://dl.winehq.org/wine-builds/fedora/$fedora_ver/
enabled=1
gpgcheck=0
EOF
    ok "WineHQ repository added"

    step "Installing winehq-devel..."
    sudo dnf install -y winehq-devel
    ok "Wine installed: $(wine --version)"
}

install_wine_arch() {
    step "Installing Wine from official Arch repos..."
    if command -v yay &>/dev/null; then
        yay -S --needed --noconfirm wine winetricks
    elif command -v paru &>/dev/null; then
        paru -S --needed --noconfirm wine winetricks
    else
        sudo pacman -S --needed --noconfirm wine winetricks
    fi
    ok "Wine installed: $(wine --version)"
}

install_wine_suse() {
    step "Adding WineHQ repository for openSUSE..."
    local ver
    ver=$(grep "^VERSION=" /etc/os-release | cut -d'"' -f2 | cut -d. -f1)
    sudo zypper ar -f "https://download.opensuse.org/repositories/Emulators:/Wine/openSUSE_Tumbleweed/" "WineHQ" 2>/dev/null || true
    sudo zypper --gpg-auto-import-keys refresh

    step "Installing Wine..."
    sudo zypper install -y wine
    ok "Wine installed: $(wine --version)"
}

install_wine() {
    print_section "WINE 10.17+ — INSTALLATION"

    if check_wine_version; then
        ok "Wine $(wine --version) is already 10.17 or newer. Skipping upgrade."
        return 0
    fi

    local current
    current=$(wine --version 2>/dev/null || echo "not installed")
    warn "Current Wine: $current"
    warn "Affinity requires Wine 10.17+. Installing now..."
    echo ""
    info "This is the most important step. The installer crash you saw was"
    info "caused by an outdated Wine version missing WinRT API support."
    echo ""

    case "$DISTRO_FAMILY" in
        debian) install_wine_debian ;;
        fedora) install_wine_fedora ;;
        arch)   install_wine_arch   ;;
        suse)   install_wine_suse   ;;
        *)      abort "Unsupported distro family: $DISTRO_FAMILY. Install Wine 10.17+ manually." ;;
    esac

    if check_wine_version; then
        ok "Wine version verified: $(wine --version)"
    else
        abort "Wine installation seems to have failed. Got: $(wine --version). Expected 10.17+."
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
# INSTALL WINETRICKS
# ─────────────────────────────────────────────────────────────────────────────
install_winetricks() {
    print_section "WINETRICKS"

    if command -v winetricks &>/dev/null; then
        ok "winetricks already installed"
        detail "Version: $(winetricks --version 2>/dev/null | head -1)"
        return 0
    fi

    step "Installing winetricks..."

    case "$DISTRO_FAMILY" in
        debian)
            sudo apt-get install -y winetricks 2>/dev/null || true
            ;;
        fedora)
            sudo dnf install -y winetricks 2>/dev/null || true
            ;;
        arch)
            sudo pacman -S --needed --noconfirm winetricks 2>/dev/null || true
            ;;
        suse)
            sudo zypper install -y winetricks 2>/dev/null || true
            ;;
    esac

    # If package manager install failed or version is too old, install from source
    if ! command -v winetricks &>/dev/null; then
        step "Package install failed — installing winetricks from upstream..."
        sudo curl -sL -o /usr/local/bin/winetricks \
            https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks
        sudo chmod +x /usr/local/bin/winetricks
    fi

    if command -v winetricks &>/dev/null; then
        ok "winetricks ready: $(winetricks --version 2>/dev/null | head -1)"
    else
        abort "Could not install winetricks. Please install it manually and re-run."
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
# CREATE WINE PREFIX
# ─────────────────────────────────────────────────────────────────────────────
create_prefix() {
    print_section "WINE PREFIX"

    info "A Wine prefix is an isolated Windows environment for Affinity."
    info "Location: $WINEPREFIX"
    echo ""

    if [ -d "$WINEPREFIX" ] && [ -f "$WINEPREFIX/system.reg" ]; then
        warn "An existing Wine prefix was found."
        if ask "Remove and recreate it? (Recommended for a clean install)"; then
            step "Killing any running Wine processes..."
            pkill -f wineserver 2>/dev/null || true
            pkill -f wine 2>/dev/null || true
            sleep 2
            step "Removing old prefix..."
            rm -rf "$WINEPREFIX"
            ok "Old prefix removed"
        else
            info "Keeping existing prefix."
            return 0
        fi
    fi

    export WINEPREFIX
    export WINEARCH=win64

    step "Initializing Wine prefix (Windows 10, 64-bit)..."
    WINEPREFIX="$WINEPREFIX" WINEARCH=win64 wineboot --init > /dev/null 2>&1
    ok "Wine prefix created at: $WINEPREFIX"
}

# ─────────────────────────────────────────────────────────────────────────────
# INSTALL RUNTIME DEPENDENCIES
# ─────────────────────────────────────────────────────────────────────────────
run_winetricks_verb() {
    local verb="$1"
    local timeout_min="${2:-15}"
    local timeout_sec=$((timeout_min * 60))

    echo ""
    step "Installing: ${C_BOLD}$verb${C_NC}  (timeout: ${timeout_min} min)"
    detail "Output is shown live below:"
    echo -e "  ${C_DIM}────────────────────────────────────────────────────────${C_NC}"

    local exit_code=0
    timeout "$timeout_sec" sh -c \
        "WINEPREFIX='$WINEPREFIX' WINEARCH=win64 winetricks --unattended --force '$verb'" \
        || exit_code=$?

    echo -e "  ${C_DIM}────────────────────────────────────────────────────────${C_NC}"

    if [ $exit_code -eq 0 ]; then
        ok "$verb installed successfully"
    elif [ $exit_code -eq 124 ]; then
        warn "$verb timed out after ${timeout_min} minutes — skipping"
        warn "This is non-critical for most components. Continuing..."
    else
        warn "$verb returned error code $exit_code — skipping"
        warn "This may not affect Affinity. Continuing..."
    fi
}

install_runtime() {
    print_section "RUNTIME DEPENDENCIES"

    info "Installing Windows runtime components Affinity depends on."
    echo ""
    info "Components to install:"
    detail "remove_mono  — remove Wine's built-in Mono (conflicts with .NET)"
    detail "vcrun2022    — Visual C++ 2022 redistributable"
    detail "dotnet48     — Microsoft .NET Framework 4.8"
    detail "corefonts    — Microsoft core fonts"
    detail "win11        — Set Windows version to 11"
    echo ""
    warn "dotnet48 is large and may take 10-20 minutes. This is normal."
    warn "You will see Wine debug output — this is expected, not errors."
    echo ""
    pause

    run_winetricks_verb "remove_mono"  5
    run_winetricks_verb "vcrun2022"    10
    run_winetricks_verb "dotnet48"     30
    run_winetricks_verb "corefonts"    5
    run_winetricks_verb "win11"        5

    echo ""
    ok "Runtime dependency installation complete."
}

# ─────────────────────────────────────────────────────────────────────────────
# INSTALL AFFINITY
# ─────────────────────────────────────────────────────────────────────────────
install_affinity() {
    print_section "INSTALLING AFFINITY"

    info "Installer: $AFFINITY_INSTALLER"
    echo ""
    warn "The Affinity setup window will open in a moment."
    warn "Follow the on-screen prompts normally."
    warn "Do NOT close this terminal during installation."
    echo ""
    pause

    step "Launching Affinity installer via Wine..."
    WINEPREFIX="$WINEPREFIX" WINEARCH=win64 wine "$AFFINITY_INSTALLER"

    echo ""
    ok "Affinity installer has closed."

    # Locate the installed directory
    AFFINITY_INSTALL_DIR=$(find "$WINEPREFIX/drive_c/Program Files" \
        -maxdepth 3 -type d -name "Affinity" 2>/dev/null | head -1)

    if [ -z "$AFFINITY_INSTALL_DIR" ]; then
        warn "Could not auto-detect Affinity install directory."
        warn "Searching more broadly..."
        AFFINITY_INSTALL_DIR=$(find "$WINEPREFIX/drive_c" \
            -maxdepth 6 -type f -name "Affinity.exe" 2>/dev/null \
            | head -1 | xargs dirname 2>/dev/null)
    fi

    if [ -n "$AFFINITY_INSTALL_DIR" ] && [ -d "$AFFINITY_INSTALL_DIR" ]; then
        ok "Affinity installed at: $AFFINITY_INSTALL_DIR"
    else
        abort "Affinity installation directory not found. Did the installer complete?"
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
# DOWNLOAD WINRT HELPER FILES
# ─────────────────────────────────────────────────────────────────────────────
download_helpers() {
    print_section "WINRT HELPER FILES"

    info "Affinity uses Windows Runtime (WinRT) APIs."
    info "Two extra files are needed to provide this support under Wine:"
    detail "Windows.winmd  — WinRT API metadata (from Microsoft)"
    detail "wintypes.dll   — WinRT shim DLL (by ElementalWarrior)"
    echo ""

    mkdir -p "$TEMP_DIR"
    cd "$TEMP_DIR" || abort "Cannot access $TEMP_DIR"

    # Windows.winmd
    step "Downloading Windows.winmd..."
    if curl -L --progress-bar -o Windows.winmd \
        "https://github.com/microsoft/windows-rs/raw/master/crates/libs/bindgen/default/Windows.winmd"; then
        ok "Windows.winmd downloaded ($(du -h Windows.winmd | cut -f1))"
    else
        abort "Failed to download Windows.winmd. Check your internet connection."
    fi

    # wintypes.dll
    step "Downloading wintypes.dll..."
    if curl -L --progress-bar -o wintypes.dll \
        "https://github.com/ElementalWarrior/wine-wintypes.dll-for-affinity/raw/refs/heads/master/wintypes_shim.dll.so"; then
        # Handle the .so extension that the file may be saved with
        [ -f "$TEMP_DIR/wintypes.dll.so" ] && \
            mv "$TEMP_DIR/wintypes.dll.so" "$TEMP_DIR/wintypes.dll" 2>/dev/null || true
        ok "wintypes.dll downloaded ($(du -h wintypes.dll | cut -f1))"
    else
        abort "Failed to download wintypes.dll. Check your internet connection."
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
# PLACE HELPER FILES
# ─────────────────────────────────────────────────────────────────────────────
place_helpers() {
    print_section "CONFIGURING WINE PREFIX"

    step "Creating winmetadata directory..."
    mkdir -p "$WINEPREFIX/drive_c/windows/system32/winmetadata"
    ok "Directory: system32/winmetadata/"

    step "Copying Windows.winmd..."
    cp "$TEMP_DIR/Windows.winmd" \
        "$WINEPREFIX/drive_c/windows/system32/winmetadata/Windows.winmd"
    ok "Windows.winmd placed"

    step "Copying wintypes.dll to Affinity directory..."
    cp "$TEMP_DIR/wintypes.dll" "$AFFINITY_INSTALL_DIR/wintypes.dll"
    ok "wintypes.dll placed"
}

# ─────────────────────────────────────────────────────────────────────────────
# CONFIGURE DLL OVERRIDE
# ─────────────────────────────────────────────────────────────────────────────
configure_dll_override() {
    print_section "DLL OVERRIDE — wintypes"

    info "Wine must be told to use the native wintypes.dll we just placed."
    info "Applying override via registry..."
    echo ""

    # Apply via wine reg (no GUI needed)
    WINEPREFIX="$WINEPREFIX" wine reg add \
        "HKCU\\Software\\Wine\\DllOverrides" \
        /v wintypes /t REG_SZ /d native /f > /dev/null 2>&1

    # Verify it was written
    if grep -qi "wintypes" "$WINEPREFIX/user.reg" 2>/dev/null; then
        ok "wintypes DLL override applied automatically"
    else
        warn "Automatic registry write may have failed."
        warn "Opening winecfg so you can apply it manually."
        echo ""
        echo -e "  ${C_CYAN}  In the window that opens:${C_NC}"
        echo -e "  ${C_CYAN}  1. Click the 'Libraries' tab${C_NC}"
        echo -e "  ${C_CYAN}  2. Type 'wintypes' in the field, click Add${C_NC}"
        echo -e "  ${C_CYAN}  3. Select it in the list, click Edit${C_NC}"
        echo -e "  ${C_CYAN}  4. Select 'Native (Windows)' -> OK${C_NC}"
        echo -e "  ${C_CYAN}  5. Apply -> OK${C_NC}"
        echo ""
        pause
        WINEPREFIX="$WINEPREFIX" winecfg
        ok "winecfg closed"
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
# OPTIONAL: AFFINITY PLUGIN LOADER
# ─────────────────────────────────────────────────────────────────────────────
install_plugin_loader() {
    print_section "OPTIONAL — AFFINITY PLUGIN LOADER"

    info "AffinityPluginLoader (by Noah C3) is a community patch that:"
    detail "Fixes preferences and settings not saving on Linux"
    detail "Improves runtime stability under Wine"
    detail "Bypasses the Canva sign-in dialog on startup"
    echo ""
    info "Source: https://github.com/noahc3/AffinityPluginLoader"
    echo ""

    if ask "Install AffinityPluginLoader + WineFix? (Recommended)"; then
        step "Downloading AffinityPluginLoader + WineFix bundle..."
        if curl -L --progress-bar \
            -o "$TEMP_DIR/affinitypluginloader-plus-winefix.tar.xz" \
            "https://github.com/noahc3/AffinityPluginLoader/releases/latest/download/affinitypluginloader-plus-winefix.tar.xz"; then
            ok "Bundle downloaded"
        else
            warn "Download failed. Skipping AffinityPluginLoader."
            return
        fi

        step "Extracting into Affinity directory..."
        cd "$AFFINITY_INSTALL_DIR" || return
        if tar -xf "$TEMP_DIR/affinitypluginloader-plus-winefix.tar.xz" -C .; then
            ok "Files extracted"
        else
            warn "Extraction failed. Skipping AffinityPluginLoader."
            return
        fi

        step "Replacing launcher with hooked version..."
        if [ -f "AffinityHook.exe" ]; then
            mv "Affinity.exe" "Affinity.real.exe"
            mv "AffinityHook.exe" "Affinity.exe"
            ok "Launcher replaced — AffinityPluginLoader is now active"
            detail "Affinity.exe now automatically loads the plugin loader"
        else
            warn "AffinityHook.exe not found in archive. Skipping launcher swap."
        fi
    else
        info "Skipped. Install later from: https://github.com/noahc3/AffinityPluginLoader"
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
# CREATE DESKTOP LAUNCHER
# ─────────────────────────────────────────────────────────────────────────────
create_launcher() {
    print_section "DESKTOP LAUNCHER"

    local exe_path="$AFFINITY_INSTALL_DIR/Affinity.exe"
    local launcher_path="$HOME/.local/share/applications/Affinity.desktop"
    local desktop_path="$HOME/Desktop/Affinity.desktop"

    # Build the launcher script path
    local launch_script="$HOME/.local/bin/affinity_launch.sh"
    mkdir -p "$HOME/.local/bin"

    # Write the health-check launcher script
    cat > "$launch_script" << LAUNCHSCRIPT
#!/bin/bash
# Affinity launcher with health checks
# Auto-generated by affinity_install.sh

WINEPREFIX="$WINEPREFIX"
AFFINITY_EXE="$exe_path"
WINMD="\$WINEPREFIX/drive_c/windows/system32/winmetadata/Windows.winmd"
AFFINITY_DIR="\$(dirname \"\$AFFINITY_EXE\")"

# Repair Windows.winmd if missing
if [ ! -f "\$WINMD" ]; then
    notify-send "Affinity" "Re-downloading Windows.winmd..." 2>/dev/null || true
    mkdir -p "\$(dirname \"\$WINMD\")"
    curl -sL -o "\$WINMD" \\
        "https://github.com/microsoft/windows-rs/raw/master/crates/libs/bindgen/default/Windows.winmd"
fi

# Repair wintypes.dll if missing
if [ ! -f "\$AFFINITY_DIR/wintypes.dll" ]; then
    notify-send "Affinity" "Re-downloading wintypes.dll..." 2>/dev/null || true
    curl -sL -o /tmp/wintypes.dll \\
        "https://github.com/ElementalWarrior/wine-wintypes.dll-for-affinity/raw/refs/heads/master/wintypes_shim.dll.so"
    [ -f /tmp/wintypes.dll.so ] && mv /tmp/wintypes.dll.so /tmp/wintypes.dll 2>/dev/null || true
    cp /tmp/wintypes.dll "\$AFFINITY_DIR/wintypes.dll" 2>/dev/null || true
fi

# Ensure DLL override
WINEPREFIX="\$WINEPREFIX" wine reg add \\
    "HKCU\\\\Software\\\\Wine\\\\DllOverrides" \\
    /v wintypes /t REG_SZ /d native /f > /dev/null 2>&1

# Launch
WINEPREFIX="\$WINEPREFIX" wine "\$AFFINITY_EXE"
LAUNCHSCRIPT

    chmod +x "$launch_script"
    ok "Health-check launcher created: $launch_script"

    # .desktop entry
    cat > "$launcher_path" << DESKTOP
[Desktop Entry]
Name=Affinity
GenericName=Design Application
Comment=Affinity suite running under Wine
Exec=$launch_script
Icon=wine
Terminal=false
Type=Application
Categories=Graphics;2DGraphics;Photography;
StartupNotify=true
DESKTOP

    chmod +x "$launcher_path"
    ok "Application menu entry created"

    # Desktop shortcut
    if [ -d "$HOME/Desktop" ]; then
        cp "$launcher_path" "$desktop_path"
        chmod +x "$desktop_path"
        ok "Desktop shortcut created: $desktop_path"

        # Try to mark as trusted on GNOME/Ubuntu
        gio set "$desktop_path" metadata::trusted true 2>/dev/null || true
    fi

    # Refresh desktop database
    update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true
}

# ─────────────────────────────────────────────────────────────────────────────
# FINAL VERIFICATION
# ─────────────────────────────────────────────────────────────────────────────
verify_installation() {
    print_section "VERIFICATION"

    local check_errors=0

    check_file() {
        local path="$1"
        local label="$2"
        if [ -f "$path" ]; then
            ok "$label"
        else
            fail "$label"
            detail "Expected at: $path"
            check_errors=$((check_errors+1))
        fi
    }

    check_file "$AFFINITY_INSTALL_DIR/Affinity.exe" \
        "Affinity.exe present"

    check_file "$WINEPREFIX/drive_c/windows/system32/winmetadata/Windows.winmd" \
        "Windows.winmd in winmetadata"

    check_file "$AFFINITY_INSTALL_DIR/wintypes.dll" \
        "wintypes.dll in Affinity directory"

    check_file "$WINEPREFIX/system.reg" \
        "Wine prefix registry intact"

    if check_wine_version; then
        ok "Wine version: $(wine --version)"
    else
        fail "Wine version $(wine --version) is below 10.17"
        check_errors=$((check_errors+1))
    fi

    if grep -qi "wintypes" "$WINEPREFIX/user.reg" 2>/dev/null; then
        ok "wintypes DLL override configured in registry"
    else
        warn "wintypes DLL override not found in registry — may cause issues"
    fi

    echo ""
    if [ $check_errors -eq 0 ]; then
        ok "All checks passed. Installation looks healthy."
    else
        warn "$check_errors check(s) failed."
        warn "Run with --repair to attempt automatic fixes."
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
# REPAIR MODE
# ─────────────────────────────────────────────────────────────────────────────
do_repair() {
    print_section "REPAIR MODE"

    info "Checking and repairing installation components..."
    echo ""

    # Find Affinity exe
    AFFINITY_INSTALL_DIR=$(find "$WINEPREFIX/drive_c" \
        -maxdepth 6 -type f -name "Affinity.exe" 2>/dev/null \
        | head -1 | xargs dirname 2>/dev/null)

    if [ -z "$AFFINITY_INSTALL_DIR" ]; then
        abort "Cannot find Affinity.exe in $WINEPREFIX. Run a full install first."
    fi
    ok "Affinity found at: $AFFINITY_INSTALL_DIR"

    # Repair Wine version
    if ! check_wine_version; then
        warn "Wine is outdated — upgrading..."
        install_wine
    else
        ok "Wine version OK: $(wine --version)"
    fi

    # Repair Windows.winmd
    local winmd="$WINEPREFIX/drive_c/windows/system32/winmetadata/Windows.winmd"
    if [ ! -f "$winmd" ]; then
        warn "Windows.winmd missing — re-downloading..."
        mkdir -p "$(dirname "$winmd")"
        curl -L --progress-bar -o "$winmd" \
            "https://github.com/microsoft/windows-rs/raw/master/crates/libs/bindgen/default/Windows.winmd"
        ok "Windows.winmd restored"
    else
        ok "Windows.winmd present"
    fi

    # Repair wintypes.dll
    if [ ! -f "$AFFINITY_INSTALL_DIR/wintypes.dll" ]; then
        warn "wintypes.dll missing — re-downloading..."
        curl -L --progress-bar -o /tmp/wintypes.dll \
            "https://github.com/ElementalWarrior/wine-wintypes.dll-for-affinity/raw/refs/heads/master/wintypes_shim.dll.so"
        [ -f /tmp/wintypes.dll.so ] && mv /tmp/wintypes.dll.so /tmp/wintypes.dll 2>/dev/null || true
        cp /tmp/wintypes.dll "$AFFINITY_INSTALL_DIR/wintypes.dll"
        ok "wintypes.dll restored"
    else
        ok "wintypes.dll present"
    fi

    # Repair DLL override
    WINEPREFIX="$WINEPREFIX" wine reg add \
        "HKCU\\Software\\Wine\\DllOverrides" \
        /v wintypes /t REG_SZ /d native /f > /dev/null 2>&1
    ok "DLL override re-applied"

    echo ""
    ok "Repair complete. Try launching Affinity now."
    echo ""
    if ask "Launch Affinity now?"; then
        WINEPREFIX="$WINEPREFIX" wine "$AFFINITY_INSTALL_DIR/Affinity.exe" &
    fi
    exit 0
}

# ─────────────────────────────────────────────────────────────────────────────
# LAUNCH PROMPT
# ─────────────────────────────────────────────────────────────────────────────
launch_affinity() {
    print_section "INSTALLATION COMPLETE"

    echo ""
    echo -e "${C_GREEN}${C_BOLD}  ╔══════════════════════════════════════════════════════════════╗${C_NC}"
    echo -e "${C_GREEN}${C_BOLD}  ║           AFFINITY SUCCESSFULLY INSTALLED                   ║${C_NC}"
    echo -e "${C_GREEN}${C_BOLD}  ╚══════════════════════════════════════════════════════════════╝${C_NC}"
    echo ""
    echo -e "  ${C_CYAN}Wine version:${C_NC}  $(wine --version)"
    echo -e "  ${C_CYAN}Wine prefix:${C_NC}   $WINEPREFIX"
    echo -e "  ${C_CYAN}Affinity:${C_NC}      $AFFINITY_INSTALL_DIR"
    echo -e "  ${C_CYAN}Launcher:${C_NC}      $HOME/.local/bin/affinity_launch.sh"
    echo -e "  ${C_CYAN}Log file:${C_NC}      $LOG_FILE"
    echo ""
    info "To launch Affinity from the terminal at any time:"
    echo ""
    echo -e "  ${C_CYAN}bash ~/.local/bin/affinity_launch.sh${C_NC}"
    echo ""
    info "Or find it in your application menu under Graphics."
    echo ""

    if ask "Launch Affinity right now?"; then
        step "Launching Affinity..."
        WINEPREFIX="$WINEPREFIX" wine "$AFFINITY_INSTALL_DIR/Affinity.exe" &
        sleep 1
        ok "Affinity launched. Check your taskbar."
    fi

    echo ""
    echo -e "  ${C_DIM}Installation log saved to: $LOG_FILE${C_NC}"
    echo ""
}

# ─────────────────────────────────────────────────────────────────────────────
# CLEANUP
# ─────────────────────────────────────────────────────────────────────────────
cleanup() {
    if [ -d "$TEMP_DIR" ]; then
        step "Cleaning up temporary files..."
        rm -rf "$TEMP_DIR"
        ok "Temporary files removed"
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
# MAIN
# ─────────────────────────────────────────────────────────────────────────────
main() {
    parse_args "$@"

    # Init log
    mkdir -p "$(dirname "$LOG_FILE")"
    echo "" >> "$LOG_FILE"
    log "=== Affinity installer started ==="
    log "Mode: $SCRIPT_MODE"
    log "Arguments: $*"

    print_header

    case "$SCRIPT_MODE" in
        uninstall)
            detect_distro
            do_uninstall
            ;;
        repair)
            detect_distro
            do_repair
            ;;
        install)
            detect_distro
            check_internet
            check_disk_space
            find_installer
            install_wine
            install_winetricks
            create_prefix
            install_runtime
            install_affinity
            download_helpers
            place_helpers
            configure_dll_override
            install_plugin_loader
            create_launcher
            verify_installation
            cleanup
            launch_affinity
            ;;
    esac

    log "=== Affinity installer finished. Errors: $TOTAL_ERRORS ==="
}

main "$@"
