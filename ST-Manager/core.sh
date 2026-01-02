#!/bin/bash

# ==============================================================================
# Project: ST-Manager
# Description: Advanced SillyTavern Deployment Tool for Termux
# Version: v1.0
# Author: 贝露凛倾
# ==============================================================================

# Environment Setup
set -o pipefail

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
    read -rsp $'按任意键继续...\n' -n 1
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
    
    # Apply Proxy
    if [[ "$USE_PROXY" == "true" && -n "$PROXY_URL" ]]; then
        export http_proxy="$PROXY_URL"
        export https_proxy="$PROXY_URL"
        export ALL_PROXY="$PROXY_URL"
        log "已启用代理: $PROXY_URL"
    else
        unset http_proxy https_proxy ALL_PROXY
    fi
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
            if [[ "$line" =~ ^\[(.*)\] ]]; then
                current_group="${BASH_REMATCH[1]}"
                # Trim CR if present
                current_group="${current_group%$'\r'}"
                GROUP_TO_MODULE_MAP["$current_group"]="$module_name"
            
            # Menu Item: key=value
            elif [[ "$line" =~ ^([^=]+)=(.*)$ ]]; then
                local key="${BASH_REMATCH[1]}"
                local text="${BASH_REMATCH[2]}"
                
                # Trim whitespace/newlines from key and text
                key=$(echo "$key" | tr -d '[:space:]')
                text=$(echo "$text" | tr -d '\r')

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
    local sys_items=("fix_env:修复运行环境" "update_self:更新管理工具" "settings_menu:系统设置" "visit_github:访问 GitHub (求星星)" "visit_discord:加入 Discord 粉丝群")
    
    for item in "${sys_items[@]}"; do
        local key="${item%:*}"
        local text="${item#*:}"
        MENU_TEXTS["$key"]="$text"
        FUNCTION_MAP["$key"]="$key"
        MODULE_GROUPS["$sys_group,$key"]="$text"
    done
    MODULE_GROUP_ORDER["$sys_group"]="fix_env update_self settings_menu visit_github visit_discord"
}

# ==============================================================================
# System Functions
# ==============================================================================
fix_env() {
    echo -e "${YELLOW}正在重新安装依赖...${RESET}"
    if [[ "$PREFIX" == *"/com.termux"* ]]; then
        pkg update -y
        pkg install -y curl unzip git nodejs-lts jq expect python openssl-tool procps
        
        # Install PM2 if missing
        if ! command -v pm2 &>/dev/null; then
            echo -e "${YELLOW}正在安装 PM2 进程管理器...${RESET}"
            npm install -g pm2
        fi
    else
        warn "非 Termux 环境，跳过 pkg 安装。"
    fi
    success "依赖修复完成。"
    pause
}

update_self() {
    echo -e "${BLUE}正在检查更新...${RESET}"
    cd "$APP_DIR" || return
    
    # 配置 git 代理
    if [[ "$USE_PROXY" == "true" && -n "$PROXY_URL" ]]; then
        git config http.proxy "$PROXY_URL"
        git config https.proxy "$PROXY_URL"
    else
        git config --unset http.proxy
        git config --unset https.proxy
    fi

    # 尝试更新
    if git pull; then
        success "更新成功！正在重启..."
        exec bash "$0"
    else
        echo -e "${RED}更新失败！错误信息如上。${RESET}"
        echo -e "${YELLOW}常见原因:${RESET}"
        echo -e "1. 网络问题 (请检查代理设置)"
        echo -e "2. 本地文件冲突 (您修改了脚本文件)"
        
        read -rp "是否尝试强制重置更新? (这将覆盖本地修改) [y/N]: " force
        if [[ "$force" =~ ^[Yy]$ ]]; then
            echo -e "${BLUE}正在强制重置...${RESET}"
            git fetch --all
            git reset --hard origin/main
            success "重置成功！正在重启..."
            exec bash "$0"
        fi
        pause
    fi
}

settings_menu() {
    while true; do
        clear
        echo -e "${BLUE}=== 系统设置 ===${RESET}"
        echo -e "${YELLOW}注意: 如果您在中国大陆使用，更新功能通常需要配置代理。${RESET}"
        echo -e "请查看您的 VPN 软件设置，找到 'HTTP 代理端口'。"
        echo -e "常见的本地代理地址: http://127.0.0.1:7890 (Clash) 或 :10809 (v2rayN)"
        echo -e "${BLUE}----------------------------------------------${RESET}"
        echo -e "1) 切换代理开关 (当前: $USE_PROXY)"
        echo -e "2) 设置代理地址 (当前: $PROXY_URL)"
        echo -e "0) 返回"
        read -rp "请选择: " choice
        case "$choice" in
            1)
                if [[ "$USE_PROXY" == "true" ]]; then USE_PROXY="false"; else USE_PROXY="true"; fi
                save_settings
                ;;
            2)
                echo -e "${YELLOW}请输入完整的代理地址 (包含 http://)${RESET}"
                read -rp "例如 http://127.0.0.1:7890 : " url
                PROXY_URL="$url"
                save_settings
                ;;
            0) break ;;
        esac
    done
}

visit_github() {
    local url="https://github.com/beilusaiying/ST-beilu-Rapid_deployment"
    echo -e "${BLUE}正在打开 GitHub 仓库...${RESET}"
    echo -e "请给我们点个 Star ⭐️！"
    if command -v termux-open-url &>/dev/null; then
        termux-open-url "$url"
    elif command -v xdg-open &>/dev/null; then
        xdg-open "$url" &>/dev/null
    else
        echo -e "请手动访问: $url"
    fi
    pause
}

visit_discord() {
    local url="https://discord.gg/agHeDq9bqU"
    echo -e "${BLUE}正在打开 Discord 粉丝群...${RESET}"
    if command -v termux-open-url &>/dev/null; then
        termux-open-url "$url"
    elif command -v xdg-open &>/dev/null; then
        xdg-open "$url" &>/dev/null
    else
        echo -e "请手动访问: $url"
    fi
    pause
}

# ==============================================================================
# Main Menu
# ==============================================================================
show_banner() {
    clear
    echo -e "${BLUE}==============================================${RESET}"
    echo -e "${GREEN}             与你之歌 v1.0             ${RESET}"
    echo -e "${BLUE}==============================================${RESET}"
    echo -e "${YELLOW}作者: 贝露凛倾${RESET}"
    echo -e "${BLUE}----------------------------------------------${RESET}"
    echo -e "本人做此预设的目的为ai模型微调的学术交流，仅供学习，无其他目的。"
    echo -e "且为免费开源项目，禁止商用。二改需授权。"
    echo -e "此脚本禁止用于商业传播，仅限ai模型研究者交流。"
    echo -e "禁止利用该脚本进行违反当地法律的事情。"
    echo -e "${BLUE}==============================================${RESET}"
}

show_group_menu() {
    local group_name="$1"
    while true; do
        clear
        echo -e "${BLUE}=== $group_name ===${RESET}"
        
        # Status Check (Context aware)
        local module_name="${GROUP_TO_MODULE_MAP[$group_name]}"
        if [[ "$module_name" == "sillytavern" ]]; then
            if declare -f st_status_text > /dev/null; then st_status_text; fi
        elif [[ "$module_name" == "gcli2api" ]]; then
            if declare -f gcli_status_text > /dev/null; then gcli_status_text; fi
        fi
        echo -e "${BLUE}----------------------------------------------${RESET}"

        local i=1
        declare -A active_options
        
        if [[ -n "${MODULE_GROUP_ORDER[$group_name]}" ]]; then
            for key in ${MODULE_GROUP_ORDER[$group_name]}; do
                echo -e "  ${GREEN}$i)${RESET} ${MENU_TEXTS[$key]}"
                active_options[$i]="$key"
                ((i++))
            done
        fi
        
        echo -e "\n${RED}0)${RESET} 返回上一级"
        echo -e "${BLUE}==============================================${RESET}"
        
        read -rp "请选择 [0-$((i-1))]: " choice
        
        if [[ "$choice" == "0" ]]; then
            break
        elif [[ -n "${active_options[$choice]}" ]]; then
            local func="${FUNCTION_MAP[${active_options[$choice]}]}"
            if declare -f "$func" > /dev/null; then
                "$func"
            else
                err "未找到功能 '$func'!"
                pause
            fi
        else
            err "无效选项"
            sleep 1
        fi
    done
}

main_menu() {
    while true; do
        show_banner
        
        # Global Status Summary
        echo -e "${YELLOW}[状态监控]${RESET}"
        if declare -f st_status_text > /dev/null; then st_status_text; fi
        if declare -f gcli_status_text > /dev/null; then gcli_status_text; fi
        echo -e "${BLUE}----------------------------------------------${RESET}"

        local i=1
        declare -A group_map

        for group in "${MAIN_GROUP_ORDER[@]}"; do
            echo -e "  ${GREEN}$i)${RESET} $group"
            group_map[$i]="$group"
            ((i++))
        done

        echo -e "\n${RED}0)${RESET} 退出"
        echo -e "${BLUE}==============================================${RESET}"
        
        read -rp "请选择 [0-$((i-1))]: " choice
        
        if [[ "$choice" == "0" ]]; then
            exit 0
        elif [[ -n "${group_map[$choice]}" ]]; then
            show_group_menu "${group_map[$choice]}"
        else
            err "无效选项"
            sleep 1
        fi
    done
}

# ==============================================================================
# Startup
# ==============================================================================
load_settings
load_modules
main_menu