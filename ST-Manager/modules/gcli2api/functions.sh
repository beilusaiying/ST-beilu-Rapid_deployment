#!/usr/bin/env bash

GCLI_DIR="$HOME/gcli2api"

# 获取版本
get_gcli_version() {
    if [[ -d "$GCLI_DIR/.git" ]]; then
        cd "$GCLI_DIR" && git rev-parse --short HEAD
    else
        echo "未安装"
    fi
}

# 检查运行状态
is_gcli_running() {
    # 检查是否有 python 运行 run.py 或 main.py
    pgrep -f "python.*(run|main)\.py" > /dev/null
}

# 状态显示
gcli_status_text() {
    local ver=$(get_gcli_version)
    local status
    if is_gcli_running; then
        status="${GREEN}运行中${RESET}"
    else
        status="${RED}已停止${RESET}"
    fi
    echo -e "gcli2api   : ${GREEN}$ver${RESET} | $status"
}

# 安装
gcli_install() {
    echo -e "${BLUE}开始安装/更新 gcli2api...${RESET}"
    
    local install_script="$HOME/gcli2api-install.sh"
    local target_url="https://raw.githubusercontent.com/su-kaka/gcli2api/master/termux-install.sh"
    
    echo -e "${YELLOW}正在下载官方安装脚本...${RESET}"
    if curl -fL "$target_url" -o "$install_script"; then
        chmod +x "$install_script"
        echo -e "${BLUE}执行安装脚本...${RESET}"
        bash "$install_script"
        rm -f "$install_script"
        success "安装/更新完成"
    else
        err "下载安装脚本失败，请检查网络"
    fi
    pause
}

# 启动
gcli_start() {
    if is_gcli_running; then
        warn "gcli2api 已经在运行中"
        pause
        return
    fi

    if [[ ! -d "$GCLI_DIR" ]]; then
        warn "未检测到 gcli2api，请先安装"
        pause
        return
    fi

    echo -e "${GREEN}正在启动 gcli2api...${RESET}"
    cd "$GCLI_DIR" || return
    
    if [[ -f "termux-start.sh" ]]; then
        chmod +x termux-start.sh
        # 后台运行
        nohup bash termux-start.sh > gcli.log 2>&1 &
    else
        err "未找到启动脚本 termux-start.sh"
        pause
        return
    fi
    
    sleep 5
    if is_gcli_running; then
        success "启动成功！日志已输出到 $GCLI_DIR/gcli.log"
        echo -e "${BLUE}========================================${RESET}"
        echo -e "API 地址: ${GREEN}http://127.0.0.1:7861/v1${RESET}"
        echo -e "默认密码: ${GREEN}pwd${RESET}"
        echo -e "${BLUE}========================================${RESET}"
        echo -e "请在 SillyTavern 中配置此 API 地址和密码"
    else
        err "启动失败，请查看日志"
        cat gcli.log
    fi
    pause
}

# 停止
gcli_stop() {
    if is_gcli_running; then
        pkill -f "python.*(run|main)\.py"
        success "gcli2api 已停止"
    else
        warn "gcli2api 未运行"
    fi
    pause
}

# 查看日志
gcli_logs() {
    if [[ -f "$GCLI_DIR/gcli.log" ]]; then
        while true; do
            clear
            echo -e "${BLUE}=== gcli2api 日志 (最后 30 行) ===${RESET}"
            tail -n 30 "$GCLI_DIR/gcli.log"
            echo -e "\n${BLUE}========================================${RESET}"
            echo -e "按 ${GREEN}Enter${RESET} 刷新日志，按 ${RED}0${RESET} 退出"
            read -rsn1 key
            if [[ "$key" == "0" ]]; then break; fi
        done
    else
        warn "暂无日志文件"
        pause
    fi
}