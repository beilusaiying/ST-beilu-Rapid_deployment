#!/bin/bash

# 项目名称: ST-Manager (SillyTavern & gcli2api Manager)
# 描述: 专为 Termux 设计的轻量级管理工具
# 版本: v1.0.0

# 初始化设置
set -euo pipefail
IFS=$'\n\t'

# 全局变量
SCRIPT_NAME="st-manager"
# 获取脚本当前所在目录
DIR=$(cd "$(dirname "$0")" && pwd)
MANAGER_DIR="$DIR/manager"

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
    
    # Termux 基础依赖
    local deps=(curl unzip git nodejs jq expect python openssl-tool)
    local missing=()

    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &>/dev/null; then
            missing+=("$dep")
        fi
    done

    if [ "${#missing[@]}" -gt 0 ]; then
        warn "发现缺失依赖: ${missing[*]}"
        log "正在自动安装依赖..."
        
        if [[ "$PREFIX" == *"/com.termux"* ]]; then
            pkg update -y
            pkg install -y "${missing[@]}" || err "依赖安装失败，请检查网络或更换源"
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

# 设置权限
setup_permissions() {
    log "设置执行权限..."
    chmod +x "$MANAGER_DIR/core.sh"
    find "$MANAGER_DIR/modules" -name "*.sh" -exec chmod +x {} \;
}

# 主函数
main() {
    clear
    echo -e "${BLUE}==============================================${RESET}"
    echo -e "${GREEN}          ST-Manager 安装/初始化程序          ${RESET}"
    echo -e "${BLUE}==============================================${RESET}"
    
    check_deps
    setup_permissions
    
    echo -e "${BLUE}==============================================${RESET}"
    success "安装完成！"
    echo -e "请运行以下命令启动管理工具："
    echo -e "${YELLOW}bash $MANAGER_DIR/core.sh${RESET}"
    echo -e "${BLUE}==============================================${RESET}"
    
    # 询问是否立即启动
    read -rp "是否立即启动? (y/n): " start_now
    if [[ "$start_now" == "y" || "$start_now" == "Y" ]]; then
        exec bash "$MANAGER_DIR/core.sh"
    fi
}

main