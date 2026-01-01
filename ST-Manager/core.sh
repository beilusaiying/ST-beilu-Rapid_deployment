#!/bin/bash

# ==============================================================================
# Project: ST-Manager
# Description: Advanced SillyTavern Deployment Tool for Termux
# Version: v2.0.0
# ==============================================================================

# Environment Setup
set -o pipefail
IFS=$'\n\t'

# ==============================================================================
# Paths & Variables
# ==============================================================================
SCRIPT_NAME="st-manager"
DIR=$(cd "$(dirname "$0")" && pwd)
APP_DIR="$DIR"
CONF_DIR="$DIR/conf"
MODULES_DIR="$DIR/modules"
SETTINGS_FILE="$CONF_DIR/settings.conf"

# Colors
RED='\033[31m'
GREEN='\033[32m'
YELLOW='\033[33m'
BLUE='\033[36m'
RESET='\033[0m'

# Core Arrays for Dynamic Menu
declare -A MENU_TEXTS
declare -A FUNCTION_MAP
declare -A MODULE_GROUPS
declare -A MODULE_GROUP_ORDER
declare -A GROUP_TO_MODULE_MAP

# Menu Order Definition
readonly MAIN_GROUP_ORDER=("SillyTavern 管理" "gcli2api 管理" "系统管理")
MENU_ORDER=()
RELOAD_MENU=false

# ==============================================================================
# Utility Functions
# ==============================================================================
log() { echo -e "${BLUE}[INFO] $1${RESET}"; }
success() { echo -e "${GREEN}[SUCCESS] $1${RESET}"; }
warn() { echo -e "${YELLOW}[WARN] $1${RESET}"; }
err() { echo -e "${RED}[ERROR] $1${RESET}" >&2; }

pause() {
    read -rsp $'Press any key to continue...\n' -n 1
}

# ==============================================================================
# Settings Management
# ==============================================================================
load_settings() {
    if [[ ! -f "$SETTINGS_FILE" ]]; then
        mkdir -p "$CONF_DIR"
        echo "# ST-Manager Configuration" > "$SETTINGS_FILE"
        echo "USE_PROXY=false" >> "$SETTINGS_FILE"
        echo "PROXY_URL=" >> "$SETTINGS_FILE"
        echo "DEBUG_MODE=false" >> "$SETTINGS_FILE"
    fi
    source "$SETTINGS_FILE"
}

save_settings() {
    {
        echo "USE_PROXY=\"$USE_PROXY\""
        echo "PROXY_URL=\"$PROXY_URL\""
        echo "DEBUG_MODE=\"$DEBUG_MODE\""
    } > "$SETTINGS_FILE"
}

# ==============================================================================
# Module System (The Core Logic)
# ==============================================================================
validate_menu_conf() {
    local menu_file="$1"
    if [[ ! -f "$menu_file" ]]; then return 1; fi
    return 0
}

load_modules() {
    # Reset arrays
    MENU_TEXTS=()
    FUNCTION_MAP=()
    MODULE_GROUPS=()
    MODULE_GROUP_ORDER=()

    local module_dir
    for module_dir in "$MODULES_DIR"/*/; do
        [[ -d "$module_dir" ]] || continue
        
        local module_name=$(basename "$module_dir")
        local funcs_file="${module_dir}functions.sh"
        local menu_file="${module_dir}menu.conf"

        if [[ ! -f "$funcs_file" || ! -f "$menu_file" ]]; then
            continue
        fi

        # Load functions
        source "$funcs_file"

        # Parse menu.conf
        local current_group=""
        while IFS= read -r line || [[ -n "$line" ]]; do
            # Skip comments and empty lines
            [[ "$line" =~ ^[[:space:]]*# || -z "$line" ]] && continue
            
            # Group Header: [GroupName]
            if [[ "$line" =~ ^\[(.*)\]$ ]]; then
                current_group="${BASH_REMATCH[1]}"
                GROUP_TO_MODULE_MAP["$current_group"]="$module_name"
            
            # Menu Item: key=value
            elif [[ "$line" =~ ^([^=]+)=(.*)$ ]]; then
                local key="${BASH_REMATCH[1]}"
                local text="${BASH_REMATCH[2]}"
                
                MENU_TEXTS["$key"]="$text"
                FUNCTION_MAP["$key"]="$key"
                MODULE_GROUPS["$current_group,$key"]="$text"
                
                # Append to order list for this group
                if [[ -z "${MODULE_GROUP_ORDER[$current_group]}" ]]; then
                    MODULE_GROUP_ORDER["$current_group"]="$key"
                else
                    MODULE_GROUP_ORDER["$current_group"]="${MODULE_GROUP_ORDER[$current_group]} $key"
                fi
            fi
        done < "$menu_file"
    done

    # Add System Management Items
    local sys_group="系统管理"
    local sys_items=("fix_env:修复运行环境" "update_self:更新管理工具" "settings_menu:系统设置")
    
    for item in "${sys_items[@]}"; do
        local key="${item%:*}"
        local text="${item#*:}"
        MENU_TEXTS["$key"]="$text"
        FUNCTION_MAP["$key"]="$key"
        MODULE_GROUPS["$sys_group,$key"]="$text"
    done
    MODULE_GROUP_ORDER["$sys_group"]="fix_env update_self settings_menu"
}

build_menu_order() {
    MENU_ORDER=()
    for group in "${MAIN_GROUP_ORDER[@]}"; do
        if [[ -n "${MODULE_GROUP_ORDER[$group]}" ]]; then
            for key in ${MODULE_GROUP_ORDER[$group]}; do
                MENU_ORDER+=("$key")
            done
        fi
    done
}

# ==============================================================================
# System Functions
# ==============================================================================
fix_env() {
    echo -e "${YELLOW}Reinstalling dependencies...${RESET}"
    if [[ "$PREFIX" == *"/com.termux"* ]]; then
        pkg update -y
        pkg install -y curl unzip git nodejs-lts jq expect python openssl-tool
    else
        warn "Not Termux, skipping pkg install."
    fi
    success "Dependencies fixed."
    pause
}

update_self() {
    echo -e "${BLUE}Checking for updates...${RESET}"
    cd "$APP_DIR" || return
    if git pull; then
        success "Updated successfully. Restarting..."
        exec bash "$0"
    else
        err "Update failed."
        pause
    fi
}

settings_menu() {
    while true; do
        clear
        echo -e "${BLUE}=== System Settings ===${RESET}"
        echo -e "1) Toggle Proxy (Current: $USE_PROXY)"
        echo -e "2) Set Proxy URL (Current: $PROXY_URL)"
        echo -e "0) Back"
        read -rp "Choice: " choice
        case "$choice" in
            1) 
                if [[ "$USE_PROXY" == "true" ]]; then USE_PROXY="false"; else USE_PROXY="true"; fi
                save_settings
                ;;
            2)
                read -rp "Enter Proxy URL (e.g., http://127.0.0.1:7890): " url
                PROXY_URL="$url"
                save_settings
                ;;
            0) break ;;
        esac
    done
}

# ==============================================================================
# Main Menu
# ==============================================================================
main_menu() {
    while true; do
        clear
        echo -e "${BLUE}==============================================${RESET}"
        echo -e "${GREEN}           ST-Manager v2.0 (Dynamic)          ${RESET}"
        echo -e "${BLUE}==============================================${RESET}"

        # Status Check
        echo -e "${YELLOW}[Status Monitor]${RESET}"
        if declare -f st_status_text > /dev/null; then st_status_text; fi
        if declare -f gcli_status_text > /dev/null; then gcli_status_text; fi
        
        local i=1
        declare -A active_options

        for group in "${MAIN_GROUP_ORDER[@]}"; do
            # Check if group has items
            if [[ -n "${MODULE_GROUP_ORDER[$group]}" ]]; then
                echo -e "\n${BLUE}[$group]${RESET}"
                for key in ${MODULE_GROUP_ORDER[$group]}; do
                    echo -e "  ${GREEN}$i)${RESET} ${MENU_TEXTS[$key]}"
                    active_options[$i]="$key"
                    ((i++))
                done
            fi
        done

        echo -e "\n${RED}0)${RESET} Exit"
        echo -e "${BLUE}==============================================${RESET}"
        
        read -rp "Select option [0-$((i-1))]: " choice
        
        if [[ "$choice" == "0" ]]; then
            exit 0
        elif [[ -n "${active_options[$choice]}" ]]; then
            local func="${FUNCTION_MAP[${active_options[$choice]}]}"
            if declare -f "$func" > /dev/null; then
                "$func"
            else
                err "Function '$func' not found!"
                pause
            fi
        else
            err "Invalid option"
            sleep 1
        fi
    done
}

# ==============================================================================
# Startup
# ==============================================================================
load_settings
load_modules
build_menu_order
main_menu