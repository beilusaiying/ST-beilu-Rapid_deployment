#!/bin/bash

# ST-Manager Core Script
# Version: v1.0.0

# ==============================================================================
# 环境配置
# ==============================================================================
set -o pipefail
IFS=$'\n\t'

# ==============================================================================
# 路径与变量
# ==============================================================================
SCRIPT_NAME="st-manager"
DIR=$(cd "$(dirname "$0")" && pwd)
APP_DIR="$(dirname "$DIR")"
CONF_DIR="$DIR/conf"
MODULES_DIR="$DIR/modules"
SETTINGS_FILE="$CONF_DIR/settings.conf"

# 颜色定义
RED='\033[31m'
GREEN='\033[32m'
YELLOW='\033[33m'
BLUE='\033[36m'
RESET='\033[0m'

# ==============================================================================
# 工具函数
# ==============================================================================
log() { echo -e "${BLUE}[INFO] $1${RESET}"; }
success() { echo -e "${GREEN}[SUCCESS] $1${RESET}"; }
warn() { echo -e "${YELLOW}[WARN] $1${RESET}"; }
err() { echo -e "${RED}[ERROR] $1${RESET}" >&2; }

# 等待按键
pause() {
    read -rsp $'按任意键继续...\n' -n 1
}

# 加载配置
load_settings() {
    if [[ -f "$SETTINGS_FILE" ]]; then
        source "$SETTINGS_FILE"
    else
        # 默认配置
        mkdir -p "$CONF_DIR"
        echo "# ST-Manager 配置文件" > "$SETTINGS_FILE"
        echo "USE_PROXY=false" >> "$SETTINGS_FILE"
        echo "PROXY_URL=" >> "$SETTINGS_FILE"
    fi
}

# 加载模块
load_modules() {
    # SillyTavern
    if [[ -f "$MODULES_DIR/sillytavern/functions.sh" ]]; then
        source "$MODULES_DIR/sillytavern/functions.sh"
    fi
    
    # gcli2api
    if [[ -f "$MODULES_DIR/gcli2api/functions.sh" ]]; then
        source "$MODULES_DIR/gcli2api/functions.sh"
    fi
}

# 检查函数是否存在
check_func() {
    if ! declare -f "$1" > /dev/null; then
        err "功能模块未加载或函数 '$1' 不存在"
        pause
        return 1
    fi
    return 0
}

# ==============================================================================
# 主菜单
# ==============================================================================
main_menu() {
    while true; do
        clear
        echo -e "${BLUE}==============================================${RESET}"
        echo -e "${GREEN}           ST-Manager 管理工具              ${RESET}"
        echo -e "${BLUE}==============================================${RESET}"
        
        # 状态显示区
        echo -e "${YELLOW}[状态监控]${RESET}"
        
        # SillyTavern Status
        if declare -f st_status_text > /dev/null; then
            st_status_text
        else
            echo -e "SillyTavern: ${RED}模块未加载${RESET}"
        fi

        # gcli2api Status
        if declare -f gcli_status_text > /dev/null; then
            gcli_status_text
        else
            echo -e "gcli2api   : ${RED}模块未加载${RESET}"
        fi
        
        echo -e "${BLUE}----------------------------------------------${RESET}"
        
        echo -e "${BLUE}[SillyTavern 酒馆]${RESET}"
        echo -e "  ${GREEN}1)${RESET} 启动/重启"
        echo -e "  ${GREEN}2)${RESET} 停止"
        echo -e "  ${GREEN}3)${RESET} 更新 (智能/强制)"
        echo -e "  ${GREEN}4)${RESET} 切换分支 (Release/Staging)"
        echo -e "  ${GREEN}5)${RESET} 备份/恢复数据"
        
        echo -e "${BLUE}[gcli2api 谷歌API]${RESET}"
        echo -e "  ${GREEN}6)${RESET} 安装/更新"
        echo -e "  ${GREEN}7)${RESET} 启动"
        echo -e "  ${GREEN}8)${RESET} 停止"
        echo -e "  ${GREEN}9)${RESET} 查看日志"
        
        echo -e "${BLUE}[系统管理]${RESET}"
        
        # 检查自启动状态
        local autostart_status="${RED}关闭${RESET}"
        if grep -q "bash $DIR/core.sh" "$HOME/.bashrc"; then
            autostart_status="${GREEN}开启${RESET}"
        fi
        
        echo -e "  ${GREEN}10)${RESET} 开机自启设置 [$autostart_status]"
        echo -e "  ${GREEN}11)${RESET} 修复运行环境 (重装依赖)"
        echo -e "  ${GREEN}12)${RESET} 更新管理工具 (ST-Manager)"
        echo -e "  ${GREEN}0)${RESET} 退出"
        
        echo -e "${BLUE}==============================================${RESET}"
        read -rp "请选择操作 [0-12]: " choice
        
        case "$choice" in
            1) check_func st_start && st_start ;;
            2) check_func st_stop && st_stop ;;
            3) check_func st_update_menu && st_update_menu ;;
            4) check_func st_switch_branch && st_switch_branch ;;
            5) check_func st_backup_menu && st_backup_menu ;;
            6) check_func gcli_install && gcli_install ;;
            7) check_func gcli_start && gcli_start ;;
            8) check_func gcli_stop && gcli_stop ;;
            9) check_func gcli_logs && gcli_logs ;;
            10) toggle_autostart ;;
            11) fix_env ;;
            12) update_self ;;
            0) exit 0 ;;
            *) echo -e "${RED}无效选项${RESET}"; sleep 1 ;;
        esac
    done
}

# 切换自启动
toggle_autostart() {
    local bashrc="$HOME/.bashrc"
    local start_cmd="bash $DIR/core.sh"
    
    if grep -q "$start_cmd" "$bashrc"; then
        # 已开启，执行关闭
        sed -i "\|$start_cmd|d" "$bashrc"
        success "已关闭开机自启"
    else
        # 未开启，执行开启
        echo "$start_cmd" >> "$bashrc"
        success "已开启开机自启"
    fi
    pause
}

# 修复环境
fix_env() {
    echo -e "${YELLOW}正在重新安装系统依赖...${RESET}"
    if [[ "$PREFIX" == *"/com.termux"* ]]; then
        pkg update -y
        pkg install -y curl unzip git nodejs jq expect python openssl-tool
    else
        echo "非Termux环境，跳过pkg安装"
    fi
    echo -e "${GREEN}依赖修复完成${RESET}"
    pause
}

# 更新自身
update_self() {
    echo -e "${BLUE}正在检查 ST-Manager 更新...${RESET}"
    cd "$APP_DIR" || return
    
    if [[ ! -d ".git" ]]; then
        warn "当前不是 Git 仓库，无法自动更新"
        echo -e "请尝试重新安装或手动下载最新版"
        pause
        return
    fi

    echo -e "${BLUE}拉取最新代码...${RESET}"
    if git pull; then
        success "更新完成，正在重启脚本..."
        sleep 1
        exec bash "$0"
    else
        err "更新失败，请检查网络"
        pause
    fi
}

# ==============================================================================
# 启动流程
# ==============================================================================
load_settings
load_modules
main_menu