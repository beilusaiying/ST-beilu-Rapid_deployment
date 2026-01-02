#!/usr/bin/env bash

GCLI_DIR="$HOME/gcli2api"

# 获取版本
get_gcli_version() {
    if [[ -d "$GCLI_DIR/.git" ]]; then
        cd "$GCLI_DIR" && git rev-parse --short HEAD
    elif [[ -f "$GCLI_DIR/web.py" ]]; then
        echo "已安装"
    else
        echo "未安装"
    fi
}

# 检查运行状态
is_gcli_running() {
    # 优先检查 pm2
    if command -v pm2 &>/dev/null; then
        # Use --no-color to avoid escape codes interfering with grep
        if pm2 list --no-color | grep -q "web.*online"; then
            return 0
        fi
    fi
    # 备用检查
    if command -v pgrep &>/dev/null; then
        pgrep -f "python.*web\.py" > /dev/null
    else
        ps -ef 2>/dev/null | grep "web.py" | grep -v grep > /dev/null
    fi
}

# 状态显示
gcli_status_text() {
    local ver=$(get_gcli_version)
    local status
    if is_gcli_running; then
        status="${GREEN}运行中 (PM2/Process)${RESET}"
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
    
    # 优先使用 PM2 启动 (兼容官方安装脚本)
    if command -v pm2 &>/dev/null; then
        # 检查是否已经注册在 pm2 中
        if pm2 list | grep -q "web"; then
            pm2 restart web
        else
            # 尝试使用 uv 环境启动
            if [[ -f ".venv/bin/python" && -f "web.py" ]]; then
                pm2 start .venv/bin/python --name web -- web.py
            else
                # 尝试直接启动
                pm2 start web.py --name web --interpreter python3
            fi
        fi
    else
        # 降级方案：直接后台运行
        if [[ -f ".venv/bin/python" ]]; then
            nohup .venv/bin/python web.py > gcli.log 2>&1 &
        else
            nohup python web.py > gcli.log 2>&1 &
        fi
    fi
    
    sleep 5
    if is_gcli_running; then
        success "启动成功！"
        echo -e "${BLUE}========================================${RESET}"
        echo -e "API 地址: ${GREEN}http://127.0.0.1:7861/v1${RESET}"
        echo -e "默认密码: ${GREEN}pwd${RESET}"
        echo -e "${BLUE}========================================${RESET}"
        echo -e "请在 SillyTavern 中配置此 API 地址和密码"
    else
        err "启动失败，请查看日志"
        gcli_logs
    fi
    pause
}

# 停止
gcli_stop() {
    if command -v pm2 &>/dev/null && pm2 list | grep -q "web"; then
        pm2 stop web
        success "gcli2api 已停止 (PM2)"
    elif is_gcli_running; then
        pkill -f "python.*web\.py"
        success "gcli2api 已停止 (Process)"
    else
        warn "gcli2api 未运行"
    fi
    pause
}

# 查看日志
gcli_logs() {
    local log_file="$GCLI_DIR/gcli.log"
    
    # 如果是 PM2 管理，尝试获取 PM2 日志路径
    if command -v pm2 &>/dev/null && pm2 list | grep -q "web"; then
        # 通常在 ~/.pm2/logs/web-out.log 和 web-error.log
        # 这里简单处理，优先看 error log 因为通常包含有用信息，或者 out log
        local pm2_log_out="$HOME/.pm2/logs/web-out.log"
        local pm2_log_err="$HOME/.pm2/logs/web-error.log"
        
        if [[ -f "$pm2_log_err" ]]; then
            log_file="$pm2_log_err"
        elif [[ -f "$pm2_log_out" ]]; then
            log_file="$pm2_log_out"
        fi
    fi

    if [[ -f "$log_file" ]]; then
        while true; do
            clear
            echo -e "${BLUE}=== gcli2api 日志 ($(basename "$log_file")) ===${RESET}"
            tail -n 30 "$log_file"
            echo -e "\n${BLUE}========================================${RESET}"
            echo -e "按 ${GREEN}Enter${RESET} 刷新日志，按 ${RED}0${RESET} 退出"
            read -rsn1 key
            if [[ "$key" == "0" ]]; then break; fi
        done
    else
        warn "暂无日志文件: $log_file"
        pause
    fi
}