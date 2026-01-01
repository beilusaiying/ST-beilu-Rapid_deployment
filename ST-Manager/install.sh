#!/bin/bash

# Project: ST-Manager
# Description: SillyTavern Deployment Tool for Termux
# Repo: https://github.com/beilusaiying/ST-beilu-Rapid_deployment

set -euo pipefail
IFS=$'\n\t'

# Config
REPO_URL="https://github.com/beilusaiying/ST-beilu-Rapid_deployment"
INSTALL_DIR="$HOME/ST-Manager"
TEMP_DIR="$(mktemp -d)"

# Colors
RED='\033[31m'
GREEN='\033[32m'
YELLOW='\033[33m'
BLUE='\033[36m'
RESET='\033[0m'

log() { echo -e "${BLUE}[INFO] $1${RESET}"; }
success() { echo -e "${GREEN}[SUCCESS] $1${RESET}"; }
warn() { echo -e "${YELLOW}[WARN] $1${RESET}"; }
err() { echo -e "${RED}[ERROR] $1${RESET}" >&2; exit 1; }

cleanup() {
    rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

check_deps() {
    log "Checking dependencies..."
    local deps=(curl unzip git jq expect python openssl-tool)
    local missing=()
    
    # Check for nodejs (lts or current)
    if ! command -v node &>/dev/null; then missing+=("nodejs"); fi
    
    for dep in "${deps[@]}"; do
        local cmd="$dep"
        [[ "$dep" == "openssl-tool" ]] && cmd="openssl"
        if ! command -v "$cmd" &>/dev/null; then missing+=("$dep"); fi
    done

    if [ "${#missing[@]}" -gt 0 ]; then
        log "Installing missing dependencies: ${missing[*]}"
        if [[ "$PREFIX" == *"/com.termux"* ]]; then
            pkg update -y
            pkg install -y "${missing[@]}" || err "Failed to install dependencies"
        else
            if command -v apt &>/dev/null; then
                sudo apt update -y
                sudo apt install -y "${missing[@]}"
            else
                warn "Not in Termux and apt not found. Please install dependencies manually."
            fi
        fi
    fi
}

install_project() {
    log "Downloading resources..."
    
    # Clone to temp dir
    git clone --depth 1 "$REPO_URL" "$TEMP_DIR/repo" || err "Git clone failed"
    
    # Check if source exists
    local source_dir="$TEMP_DIR/repo/ST-Manager"
    if [[ ! -d "$source_dir" ]]; then
        err "Invalid repository structure: ST-Manager folder not found"
    fi
    
    # Backup user config if exists
    if [[ -f "$INSTALL_DIR/conf/settings.conf" ]]; then
        log "Backing up settings..."
        cp "$INSTALL_DIR/conf/settings.conf" "$TEMP_DIR/settings.conf.bak"
    fi
    
    # Clean install
    if [[ -d "$INSTALL_DIR" ]]; then
        log "Removing old version..."
        rm -rf "$INSTALL_DIR"
    fi
    
    log "Installing files..."
    mkdir -p "$INSTALL_DIR"
    cp -rf "$source_dir/"* "$INSTALL_DIR/"
    
    # Restore config
    if [[ -f "$TEMP_DIR/settings.conf.bak" ]]; then
        log "Restoring settings..."
        mkdir -p "$INSTALL_DIR/conf"
        cp "$TEMP_DIR/settings.conf.bak" "$INSTALL_DIR/conf/settings.conf"
    fi
    
    # Permissions
    chmod +x "$INSTALL_DIR/core.sh"
    find "$INSTALL_DIR/modules" -name "*.sh" -exec chmod +x {} \;
}

setup_autostart() {
    read -rp "Enable autostart on Termux launch? (y/n): " choice
    if [[ "$choice" == "y" || "$choice" == "Y" ]]; then
        local bashrc="$HOME/.bashrc"
        local cmd="bash $INSTALL_DIR/core.sh"
        if ! grep -q "$cmd" "$bashrc"; then
            echo "$cmd" >> "$bashrc"
            success "Autostart enabled"
        fi
    fi
}

main() {
    clear
    echo -e "${BLUE}=== ST-Manager Installer ===${RESET}"
    check_deps
    install_project
    
    echo -e "${BLUE}============================${RESET}"
    success "Installation Complete!"
    echo -e "Run: ${YELLOW}bash $INSTALL_DIR/core.sh${RESET}"
    
    setup_autostart
    
    read -rp "Start now? (y/n): " start
    if [[ "$start" == "y" || "$start" == "Y" ]]; then
        exec bash "$INSTALL_DIR/core.sh"
    fi
}

main