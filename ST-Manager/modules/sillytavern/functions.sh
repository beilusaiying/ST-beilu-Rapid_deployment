#!/bin/bash

ST_DIR="$HOME/SillyTavern"

# 获取版本
get_st_version() {
    if [[ -f "$ST_DIR/package.json" ]]; then
        jq -r .version "$ST_DIR/package.json"
    else
        echo "未安装"
    fi
}

# 检查运行状态
is_st_running() {
    if command -v pm2 &>/dev/null; then
        # Use --no-color to avoid escape codes interfering with grep
        if pm2 list --no-color | grep -q "SillyTavern.*online"; then
            return 0
        fi
    fi
    pgrep -f "node server.js" > /dev/null
}

# 状态显示文本
st_status_text() {
    local ver=$(get_st_version)
    local status
    if is_st_running; then
        status="${GREEN}运行中 (PM2/Process)${RESET}"
    else
        status="${RED}已停止${RESET}"
    fi
    echo -e "SillyTavern: ${GREEN}$ver${RESET} | $status"
}

# 安装
st_install() {
    echo -e "${BLUE}开始安装 SillyTavern (Release分支)...${RESET}"
    # 使用 --depth 1 减少下载体积
    git clone --depth 1 --branch release https://github.com/SillyTavern/SillyTavern "$ST_DIR"
    cd "$ST_DIR" || return
    echo -e "${BLUE}安装 npm 依赖...${RESET}"
    npm install
    success "安装完成"
    pause
}

# 启动
st_start() {
    if is_st_running; then
        warn "SillyTavern 已经在运行中"
        pause
        return
    fi
    
    if [[ ! -d "$ST_DIR" ]]; then
        warn "未检测到 SillyTavern，准备安装..."
        st_install
    fi

    # 检查 node_modules
    if [[ ! -d "$ST_DIR/node_modules" ]]; then
        warn "检测到依赖缺失，正在尝试修复..."
        cd "$ST_DIR" || return
        npm install
    fi

    echo -e "${GREEN}正在启动 SillyTavern...${RESET}"
    cd "$ST_DIR" || return
    
    if command -v pm2 &>/dev/null; then
        # 使用 PM2 启动
        if pm2 list | grep -q "SillyTavern"; then
            pm2 restart SillyTavern
        else
            pm2 start server.js --name SillyTavern --node-args="--max-old-space-size=4096"
        fi
    else
        # 降级方案
        nohup node --max-old-space-size=4096 server.js > st_output.log 2>&1 &
    fi
    
    # 等待几秒检查是否启动成功
    sleep 5
    if is_st_running; then
        success "SillyTavern 启动成功"
        
        # 尝试打开浏览器
        if command -v termux-open-url &>/dev/null; then
            termux-open-url "http://127.0.0.1:8000"
        elif command -v xdg-open &>/dev/null; then
            xdg-open "http://127.0.0.1:8000" &>/dev/null
        fi
    else
        err "启动失败，请查看日志"
        # 如果是依赖问题，提示用户
        if grep -q "MODULE_NOT_FOUND" st_output.log 2>/dev/null || pm2 logs SillyTavern --lines 20 --nostream 2>/dev/null | grep -q "MODULE_NOT_FOUND"; then
             err "检测到模块缺失错误。请尝试在菜单中选择 '常规更新' 或手动运行 'npm install'。"
        fi
        st_logs
    fi
    pause
}

# 查看日志
st_logs() {
    local log_file="$ST_DIR/st_output.log"
    
    if command -v pm2 &>/dev/null && pm2 list | grep -q "SillyTavern"; then
        local pm2_log_out="$HOME/.pm2/logs/SillyTavern-out.log"
        local pm2_log_err="$HOME/.pm2/logs/SillyTavern-error.log"
        
        if [[ -f "$pm2_log_err" ]]; then
            log_file="$pm2_log_err"
        elif [[ -f "$pm2_log_out" ]]; then
            log_file="$pm2_log_out"
        fi
    fi

    if [[ -f "$log_file" ]]; then
        while true; do
            clear
            echo -e "${BLUE}=== SillyTavern 日志 ($(basename "$log_file")) ===${RESET}"
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

# 停止
st_stop() {
    if command -v pm2 &>/dev/null && pm2 list | grep -q "SillyTavern"; then
        pm2 stop SillyTavern
        success "SillyTavern 已停止 (PM2)"
    elif is_st_running; then
        pkill -f "node server.js"
        success "SillyTavern 已停止 (Process)"
    else
        warn "SillyTavern 未运行"
    fi
    pause
}

# 更新菜单
st_update_menu() {
    while true; do
        clear
        echo -e "${BLUE}=== SillyTavern 更新管理 ===${RESET}"
        echo -e "  ${GREEN}1)${RESET} 常规更新 (git pull)"
        echo -e "  ${GREEN}2)${RESET} 强制修复更新 (重置到远程版本)"
        echo -e "  ${GREEN}0)${RESET} 返回"
        read -rp "选择: " opt
        case "$opt" in
            1) 
                cd "$ST_DIR" || return
                echo -e "${BLUE}执行 git pull...${RESET}"
                git pull
                echo -e "${BLUE}更新依赖...${RESET}"
                npm install
                success "更新完成"
                pause
                ;;
            2)
                echo -e "${RED}警告: 这将丢弃所有对核心文件的本地修改！(不影响数据)${RESET}"
                read -rp "确认执行? (y/n): " confirm
                if [[ "$confirm" == "y" ]]; then
                    cd "$ST_DIR" || return
                    echo -e "${BLUE}获取最新代码...${RESET}"
                    git fetch --all
                    # 获取当前分支名
                    local branch=$(git rev-parse --abbrev-ref HEAD)
                    echo -e "${BLUE}重置分支 $branch 到远程状态...${RESET}"
                    git reset --hard "origin/$branch"
                    echo -e "${BLUE}更新依赖...${RESET}"
                    npm install
                    success "强制更新完成"
                fi
                pause
                ;;
            0) break ;;
            *) ;;
        esac
    done
}

# 切换分支
st_switch_branch() {
    cd "$ST_DIR" || return
    echo -e "${BLUE}当前分支: $(git rev-parse --abbrev-ref HEAD)${RESET}"
    echo -e "  ${GREEN}1)${RESET} 切换到 Release (稳定版)"
    echo -e "  ${GREEN}2)${RESET} 切换到 Staging (测试版)"
    read -rp "选择: " opt
    case "$opt" in
        1) 
            git checkout release && git pull && npm install 
            success "已切换到 Release"
            ;;
        2) 
            git checkout staging && git pull && npm install 
            success "已切换到 Staging"
            ;;
    esac
    pause
}

# 备份
st_backup_menu() {
    local backup_file="$HOME/st_backup_$(date +%Y%m%d_%H%M%S).zip"
    echo -e "${BLUE}正在备份数据到 $backup_file ...${RESET}"
    if [[ -d "$ST_DIR" ]]; then
        cd "$ST_DIR" || return
        # 检查 zip 是否安装
        if ! command -v zip &>/dev/null; then
            pkg install zip -y
        fi
        
        if zip -r "$backup_file" public data config.yaml; then
            success "备份完成: $backup_file"
        else
            err "备份失败"
        fi
    else
        err "目录不存在"
    fi
    pause
}