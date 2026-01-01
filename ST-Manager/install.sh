#!/usr/bin/env bash

# 项目名称: ST-Manager (SillyTavern & gcli2api Manager)
# 描述: 专为 Termux 设计的轻量级管理工具
# 版本: v1.0.0

# 初始化设置
set -euo pipefail
IFS=$'\n\t'

# 全局变量
SCRIPT_NAME="st-manager"
REPO_URL="https://github.com/beilusaiying/ST-beilu-Rapid_deployment"
APP_DIR="$HOME/ST-Manager"
MANAGER_DIR="$APP_DIR/manager"

# 颜色定义
RED='\033[31m'
GREEN='\033[32m'
YELLOW='\033[33m'
BLUE='\033[36m'
RESET='\033[0m'

# 错误处理
err() {
    echo -e "${RED}错误: $1${RESET}" >&2
    exit "${2:-1}"
}

log() {
    echo -e "${BLUE}[INFO] $1${RESET}"
}

success() {
    echo -e "${GREEN}[SUCCESS] $1${RESET}"
}

warn() {
    echo -e "${YELLOW}[WARN] $1${RESET}"
}

# 检查并安装依赖
check_deps() {
    log "检查系统依赖..."
    
    # Termux 基础依赖 (使用 nodejs-lts 替代 nodejs 以提高稳定性)
    local deps=(curl unzip git jq expect python openssl-tool build-essential)
    local missing=()

    # 特殊检查 node
    if ! command -v node &>/dev/null; then
        missing+=("nodejs-lts")
    fi

    for dep in "${deps[@]}"; do
        # 处理包名与命令名不一致的情况
        local cmd="$dep"
        [[ "$dep" == "openssl-tool" ]] && cmd="openssl"
        [[ "$dep" == "build-essential" ]] && cmd="gcc" # 简单检查 gcc 是否存在

        if ! command -v "$cmd" &>/dev/null; then
            missing+=("$dep")
        fi
    done

    if [ "${#missing[@]}" -gt 0 ]; then
        warn "发现缺失依赖: ${missing[*]}"
        log "正在自动安装依赖..."
        
        if [[ "$PREFIX" == *"/com.termux"* ]]; then
            log "正在更新软件源并升级系统..."
            
            # 1. 尝试修复潜在的损坏状态
            dpkg --configure -a || true
            
            # 2. 移除可能导致 ABI 冲突的 bleeding-edge nodejs
            if pkg list-installed 2>/dev/null | grep -q "^nodejs/"; then
                warn "检测到非 LTS 版本 Node.js，正在移除以避免库兼容性问题..."
                pkg uninstall -y nodejs || dpkg --remove --force-all nodejs
            fi

            # 3. 全面升级系统 (解决 CANNOT LINK EXECUTABLE 问题)
            pkg update -y
            pkg upgrade -y
            
            log "正在安装依赖: ${missing[*]}"
            if ! pkg install -y "${missing[@]}"; then
                warn "依赖安装遇到问题，尝试自动修复..."
                
                # 再次尝试修复
                if dpkg --configure -a; then
                    log "dpkg 修复成功，重试安装..."
                    pkg install -y "${missing[@]}" || err "依赖安装再次失败。请尝试手动运行: dpkg --configure -a"
                else
                    err "无法自动修复 dpkg 错误。请尝试手动运行: dpkg --configure -a"
                fi
            fi
        else
            # 非 Termux 环境尝试使用 apt (仅供测试)
            if command -v apt &>/dev/null; then
                sudo apt update -y
                sudo apt install -y "${missing[@]}" || err "依赖安装失败"
            else
                err "非 Termux 环境且未找到 apt，请手动安装依赖: ${missing[*]}"
            fi
        fi
        success "依赖安装完成"
    else
        success "所有依赖已就绪"
    fi
}

# 安装或更新项目
install_project() {
    log "正在安装/更新 ST-Manager..."
    
    if [[ -d "$APP_DIR" ]]; then
        if [[ -d "$APP_DIR/.git" ]]; then
            log "检测到已安装，正在更新..."
            cd "$APP_DIR" || exit 1
            git pull || warn "更新失败，请检查网络"
        else
            warn "目录 $APP_DIR 已存在但不是 Git 仓库，正在强制重新安装..."
            rm -rf "$APP_DIR"
            git clone "$REPO_URL" "$APP_DIR" || err "克隆失败，请检查网络"
        fi
    else
        log "正在克隆仓库..."
        git clone "$REPO_URL" "$APP_DIR" || err "克隆失败，请检查网络"
    fi

    # 统一修正目录结构 (防止 ST-Manager/ST-Manager 嵌套)
    # 无论是新克隆还是更新，都检查是否存在嵌套
    if [[ -d "$APP_DIR/ST-Manager" ]]; then
        log "检测到嵌套目录，正在修正结构..."
        # 使用 cp -rf 强制覆盖/合并，避免 mv 在目标目录存在时产生嵌套 (如 manager/manager)
        cp -rf "$APP_DIR/ST-Manager/"* "$APP_DIR/"
        rm -rf "$APP_DIR/ST-Manager"
    fi
    
    # 最终检查核心文件是否存在
    if [[ ! -f "$MANAGER_DIR/core.sh" ]]; then
        err "核心文件缺失 ($MANAGER_DIR/core.sh)，安装可能失败。请尝试运行: rm -rf ~/ST-Manager 然后重试。"
    fi
}

# 设置权限
setup_permissions() {
    log "设置执行权限..."
    if [[ -f "$MANAGER_DIR/core.sh" ]]; then
        chmod +x "$MANAGER_DIR/core.sh"
        find "$MANAGER_DIR/modules" -name "*.sh" -exec chmod +x {} \;
    else
        err "核心文件丢失，安装可能失败"
    fi
}

# 主函数
main() {
    clear
    echo -e "${BLUE}==============================================${RESET}"
    echo -e "${GREEN}          ST-Manager 安装/初始化程序          ${RESET}"
    echo -e "${BLUE}==============================================${RESET}"
    
    check_deps
    install_project
    setup_permissions
    
    echo -e "${BLUE}==============================================${RESET}"
    success "安装完成！"
    echo -e "请运行以下命令启动管理工具："
    echo -e "${YELLOW}bash $MANAGER_DIR/core.sh${RESET}"
    echo -e "${BLUE}==============================================${RESET}"
    
    # 询问是否开启自启动
    read -rp "是否设置开机(打开Termux)自启动? (y/n): " enable_autostart
    if [[ "$enable_autostart" == "y" || "$enable_autostart" == "Y" ]]; then
        if ! grep -q "bash $MANAGER_DIR/core.sh" "$HOME/.bashrc"; then
            echo "bash $MANAGER_DIR/core.sh" >> "$HOME/.bashrc"
            success "已开启自启动"
        else
            warn "自启动已存在，跳过"
        fi
    fi

    # 询问是否立即启动
    read -rp "是否立即启动? (y/n): " start_now
    if [[ "$start_now" == "y" || "$start_now" == "Y" ]]; then
        exec bash "$MANAGER_DIR/core.sh"
    fi
}

main