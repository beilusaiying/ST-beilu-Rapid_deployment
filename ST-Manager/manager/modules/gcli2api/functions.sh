#!/bin/bash

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
    echo -e "${BLUE}开始安装 gcli2api...${RESET}"
    
    # 检查 Python 环境
    if ! command -v python &>/dev/null; then
        echo -e "${YELLOW}未检测到 Python，正在安装...${RESET}"
        pkg install python -y
    fi

    if [[ -d "$GCLI_DIR" ]]; then
        echo -e "${YELLOW}检测到旧版本，正在更新...${RESET}"
        cd "$GCLI_DIR" || return
        git pull
    else
        echo -e "${BLUE}克隆仓库...${RESET}"
        git clone https://github.com/su-kaka/gcli2api "$GCLI_DIR"
    fi

    cd "$GCLI_DIR" || return
    echo -e "${BLUE}安装 Python 依赖...${RESET}"
    pip install -r requirements.txt
    
    success "安装完成"
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
    
    # 后台运行并记录日志
    nohup python run.py > gcli.log 2>&1 &
    
    sleep 2
    if is_gcli_running; then
        success "启动成功！日志已输出到 $GCLI_DIR/gcli.log"
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
        echo -e "${BLUE}正在显示最后 20 行日志 (按 Ctrl+C 退出):${RESET}"
        tail -f -n 20 "$GCLI_DIR/gcli.log"
    else
        warn "暂无日志文件"
        pause
    fi
}