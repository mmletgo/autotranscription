#!/bin/bash

# AutoTranscription 综合管理脚本
# 提供一键安装、启动、停止等管理功能

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 配置变量
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT_NAME="$(basename "$0")"

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${CYAN}[STEP]${NC} $1"
}

# 显示横幅
show_banner() {
    echo -e "${CYAN}"
    cat << "EOF"
 _____                         _
|  __ \                       | |
| |  | | ___   _ __ ___   __ _| |_ ___  _ __
| |  | |/ _ \ | '_ ` _ \ / _` | __/ _ \| '__|
| |__| | (_) || | | | | | (_| | || (_) | |
|_____/ \___/ |_| |_| |_|\__,_|\__\___/|_|
              TRANSCRIPTION SYSTEM
EOF
    echo -e "${NC}"
}

# 显示帮助信息
show_help() {
    cat << EOF
AutoTranscription 管理脚本

用法: $SCRIPT_NAME <命令> [选项]

命令:
    install         安装完整系统依赖
    install-client  仅安装客户端依赖
    install-server  仅安装服务端依赖
    start           启动服务端和客户端
    stop            停止服务端和客户端
    restart         重启服务端和客户端
    server          管理服务端 (start|stop|restart|status|logs|health|monitor)
    client          启动客户端
    service         客户端服务管理 (install|uninstall|enable|disable|start|stop|restart|status|logs)
    status          显示系统状态
    clean           清理系统 (保留配置)
    reset           完全重置系统 (删除所有数据)
    -h, --help      显示此帮助信息

示例:
    $SCRIPT_NAME install             # 安装完整系统
    $SCRIPT_NAME install-client      # 仅安装客户端依赖
    $SCRIPT_NAME install-server      # 仅安装服务端依赖
    $SCRIPT_NAME start               # 启动完整系统
    $SCRIPT_NAME server start        # 仅启动服务端
    $SCRIPT_NAME server status       # 查看服务端状态
    $SCRIPT_NAME client              # 启动客户端
    $SCRIPT_NAME status              # 查看系统状态
    $SCRIPT_NAME clean               # 清理系统

EOF
}

# 显示系统状态
show_status() {
    show_banner
    echo -e "${BLUE}系统状态检查${NC}"
    echo "================================"

    # 检查Conda安装状态
    if command -v conda &> /dev/null; then
        echo -e "✓ ${GREEN}Conda: 已安装${NC}"
        conda_version=$(conda --version 2>/dev/null | cut -d' ' -f2)
        echo -e "  - 版本: $conda_version"

        # 检查AutoTranscription环境
        if conda env list | grep -q "^autotranscription "; then
            echo -e "✓ ${GREEN}Conda环境: 已创建${NC}"
        else
            echo -e "✗ ${RED}Conda环境: 未创建${NC}"
        fi
    else
        echo -e "✗ ${RED}Conda: 未安装${NC}"
    fi

    if [[ -f "$PROJECT_DIR/config/server_config.json" ]]; then
        echo -e "✓ ${GREEN}服务端配置: 已创建${NC}"
    else
        echo -e "✗ ${RED}服务端配置: 未创建${NC}"
    fi

    if [[ -f "$PROJECT_DIR/config/client_config.json" ]]; then
        echo -e "✓ ${GREEN}客户端配置: 已创建${NC}"
    else
        echo -e "✗ ${RED}客户端配置: 未创建${NC}"
    fi

    # 检查服务端状态
    SERVER_PID_FILE="$PROJECT_DIR/logs/transcription_server.pid"
    if [[ -f "$SERVER_PID_FILE" ]]; then
        SERVER_PID=$(cat "$SERVER_PID_FILE" 2>/dev/null)
        if [[ -n "$SERVER_PID" ]] && kill -0 "$SERVER_PID" 2>/dev/null; then
            echo -e "✓ ${GREEN}服务端: 运行中${NC}"
            echo -e "  - PID: $SERVER_PID"

            # 尝试获取服务端详细信息
            if curl -s "http://localhost:5000/api/health" >/dev/null 2>&1; then
                echo -e "  - 状态: $(curl -s "http://localhost:5000/api/health" 2>/dev/null | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('status', 'unknown'))" 2>/dev/null || echo "未知")"

                # 获取模型信息
                MODEL=$(curl -s "http://localhost:5000/api/health" 2>/dev/null | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('model', 'unknown'))" 2>/dev/null || echo "未知")
                DEVICE=$(curl -s "http://localhost:5000/api/health" 2>/dev/null | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('device', 'unknown'))" 2>/dev/null || echo "未知")
                echo -e "  - 模型: $MODEL"
                echo -e "  - 设备: $DEVICE"

                # 获取并发信息
                ACTIVE=$(curl -s "http://localhost:5000/api/health" 2>/dev/null | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('active_transcriptions', 0))" 2>/dev/null || echo "0")
                MAX_CONCURRENT=$(curl -s "http://localhost:5000/api/health" 2>/dev/null | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('max_concurrent', 0))" 2>/dev/null || echo "0")
                QUEUE_SIZE=$(curl -s "http://localhost:5000/api/health" 2>/dev/null | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('queue_size', 0))" 2>/dev/null || echo "0")
                echo -e "  - 活跃转写: $ACTIVE/$MAX_CONCURRENT"
                echo -e "  - 队列大小: $QUEUE_SIZE"

                # 获取工作进程数
                WORKERS=$(curl -s "http://localhost:5000/api/health" 2>/dev/null | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('worker_count', 0))" 2>/dev/null || echo "0")
                echo -e "  - 工作进程: $WORKERS"
            fi
        else
            echo -e "✗ ${RED}服务端: 未运行${NC}"
            # 清理无效的PID文件
            rm -f "$SERVER_PID_FILE" 2>/dev/null || true
        fi
    else
        # 备用检查：查找gunicorn进程
        if pgrep -f "gunicorn.*transcription_server" >/dev/null 2>&1; then
            echo -e "✓ ${GREEN}服务端: 运行中${NC}"
        else
            echo -e "✗ ${RED}服务端: 未运行${NC}"
        fi
    fi

    # 检查客户端进程状态
    if pgrep -f "client.py" >/dev/null 2>&1; then
        CLIENT_PID=$(pgrep -f "client.py" | head -1)
        echo -e "✓ ${GREEN}客户端进程: 运行中${NC}"
        echo -e "  - PID: $CLIENT_PID"

        # 尝试获取快捷键信息
        CLIENT_CMD=$(ps -p $CLIENT_PID -o args= 2>/dev/null)
        if echo "$CLIENT_CMD" | grep -q "\-k"; then
            HOTKEY=$(echo "$CLIENT_CMD" | grep -o '\-k[[:space:]]\+[^[:space:]]\+' | head -1 | sed 's/-k[[:space:]]*//')
            echo -e "  - 快捷键: $HOTKEY"
        fi
    else
        echo -e "✗ ${RED}客户端进程: 未运行${NC}"
    fi

    # 检查客户端服务状态（systemd服务）
    if systemctl list-unit-files | grep -q "autotranscription-client.service" 2>/dev/null; then
        if systemctl is-active --quiet "autotranscription-client" 2>/dev/null; then
            echo -e "✓ ${GREEN}客户端服务: 运行中${NC}"
            if systemctl is-enabled --quiet "autotranscription-client" 2>/dev/null; then
                echo -e "  - 开机自启: 已启用"
            else
                echo -e "  - 开机自启: 已禁用"
            fi
        else
            echo -e "✗ ${YELLOW}客户端服务: 已安装但未运行${NC}"
        fi
    else
        echo -e "✗ ${RED}客户端服务: 未安装${NC}"
    fi

    # 检查GPU支持
    if command -v nvidia-smi &> /dev/null; then
        GPU_NAME=$(nvidia-smi --query-gpu=name --format=csv,noheader,nounits | head -1)
        echo -e "✓ ${GREEN}GPU: $GPU_NAME${NC}"
    else
        echo -e "✗ ${RED}GPU: 未检测到${NC}"
    fi

    echo "================================"
}

# 安装完整系统
install_system() {
    show_banner
    log_step "开始安装AutoTranscription完整系统..."

    # 运行安装脚本
    "$PROJECT_DIR/scripts/install_deps.sh" full

    log_success "完整系统安装完成！"
    echo
    log_info "接下来可以运行:"
    echo "  $SCRIPT_NAME start     # 启动系统"
    echo "  $SCRIPT_NAME server    # 管理服务端"
    echo "  $SCRIPT_NAME client    # 启动客户端"
    echo
    log_info "激活环境: conda activate autotranscription"
}

# 仅安装客户端依赖
install_client_only() {
    show_banner
    log_step "开始安装客户端依赖..."

    # 运行安装脚本
    "$PROJECT_DIR/scripts/install_deps.sh" client

    log_success "客户端依赖安装完成！"
    echo
    log_info "接下来可以运行:"
    echo "  $SCRIPT_NAME client           # 启动客户端"
    echo "  $SCRIPT_NAME service install  # 安装客户端服务"
    echo
    log_info "激活环境: conda activate autotranscription"
    echo
    log_info "连接服务端:"
    echo "  1. 确保服务端已启动"
    echo "  2. 修改 config/client_config.json 中的 server_url"
    echo "  3. 运行 $SCRIPT_NAME client"
}

# 仅安装服务端依赖
install_server_only() {
    show_banner
    log_step "开始安装服务端依赖..."

    # 运行安装脚本
    "$PROJECT_DIR/scripts/install_deps.sh" server

    log_success "服务端依赖安装完成！"
    echo
    log_info "接下来可以运行:"
    echo "  $SCRIPT_NAME server start     # 启动服务端"
    echo "  $SCRIPT_NAME server status    # 查看服务端状态"
    echo
    log_info "激活环境: conda activate autotranscription"
}

# 启动系统
start_system() {
    show_banner
    log_step "启动AutoTranscription系统..."

    # 检查安装状态
    if ! command -v conda &> /dev/null; then
        log_error "Conda未安装，请先运行: $SCRIPT_NAME install"
        exit 1
    fi

    if ! conda env list | grep -q "^autotranscription "; then
        log_error "Conda环境未创建，请先运行: $SCRIPT_NAME install"
        exit 1
    fi

    # 启动服务端
    log_info "启动服务端..."
    "$PROJECT_DIR/scripts/start_server.sh" start

    # 等待服务端完全启动
    sleep 3

    # 启动客户端（后台运行）
    log_info "启动客户端..."
    nohup "$PROJECT_DIR/scripts/start_client.sh" start > /dev/null 2>&1 &

    # 等待客户端启动
    sleep 2

    echo
    log_success "系统启动完成！"
    echo
    log_info "服务端地址: http://localhost:5000"
    log_info "快捷键: 查看 config/client_config.json 中的 key_combo"
    log_info "查看状态: $SCRIPT_NAME status"
    echo
    log_info "客户端管理:"
    echo "  $SCRIPT_NAME client           # 重新启动客户端"
    echo "  $SCRIPT_NAME stop            # 停止整个系统"
    echo
    log_info "Conda环境: conda activate autotranscription"
}

# 停止系统
stop_system() {
    show_banner
    log_step "停止AutoTranscription系统..."

    # 停止客户端进程
    log_info "停止客户端..."
    pkill -f "client.py" || true

    # 停止服务端
    log_info "停止服务端..."
    "$PROJECT_DIR/scripts/start_server.sh" stop

    log_success "系统已停止"
}

# 重启系统
restart_system() {
    show_banner
    log_step "重启AutoTranscription系统..."

    stop_system
    sleep 2
    start_system
}

# 启动客户端
start_client() {
    # 检查安装状态
    if ! command -v conda &> /dev/null; then
        log_error "Conda未安装，请先运行: $SCRIPT_NAME install"
        exit 1
    fi

    if ! conda env list | grep -q "^autotranscription "; then
        log_error "Conda环境未创建，请先运行: $SCRIPT_NAME install"
        exit 1
    fi

    # 检查服务端状态
    if ! "$PROJECT_DIR/scripts/start_server.sh" health >/dev/null 2>&1; then
        log_warning "服务端未运行，客户端可能无法正常工作"
        log_info "请先运行: $SCRIPT_NAME server start"
        echo
    fi

    # 启动客户端
    "$PROJECT_DIR/scripts/start_client.sh" start
}

# 清理系统
clean_system() {
    show_banner
    log_step "清理AutoTranscription系统..."

    # 停止服务
    "$PROJECT_DIR/scripts/start_server.sh" stop >/dev/null 2>&1 || true

    # 清理日志
    if [[ -d "$PROJECT_DIR/logs" ]]; then
        rm -rf "$PROJECT_DIR/logs"
        log_info "已清理日志文件"
    fi

    # 清理缓存
    if [[ -d "$PROJECT_DIR/__pycache__" ]]; then
        find "$PROJECT_DIR" -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true
        log_info "已清理Python缓存"
    fi

    log_success "系统清理完成"
}

# 重置系统
reset_system() {
    show_banner
    log_warning "这将删除所有数据和配置，确定要继续吗？"
    read -p "输入 'RESET' 确认重置: " -r
    echo

    if [[ $REPLY != "RESET" ]]; then
        log_info "取消重置"
        exit 0
    fi

    log_step "重置AutoTranscription系统..."

    # 停止服务
    "$PROJECT_DIR/scripts/start_server.sh" stop >/dev/null 2>&1 || true

    # 删除Conda环境
    if command -v conda &> /dev/null && conda env list | grep -q "^autotranscription "; then
        conda env remove -n autotranscription -y
        log_info "已删除Conda环境"
    fi

    # 清理所有文件
    clean_system

    log_success "系统重置完成"
    log_info "请运行 '$SCRIPT_NAME install' 重新安装"
}

# 主函数
main() {
    # 处理命令行参数
    case "${1:-help}" in
        "install")
            install_system
            ;;
        "install-client")
            install_client_only
            ;;
        "install-server")
            install_server_only
            ;;
        "start")
            start_system
            ;;
        "stop")
            stop_system
            ;;
        "restart")
            restart_system
            ;;
        "server")
            if [[ -z "$2" ]]; then
                log_error "请指定服务端命令: start|stop|restart|status|logs|health|monitor"
                exit 1
            fi
            "$PROJECT_DIR/scripts/start_server.sh" "$2"
            ;;
        "client")
            start_client
            ;;
        "service")
            if [[ -z "$2" ]]; then
                log_error "请指定服务命令: install|uninstall|enable|disable|start|stop|restart|status|logs"
                exit 1
            fi
            "$PROJECT_DIR/scripts/install_client_service.sh" "$2"
            ;;
        "status")
            show_status
            ;;
        "clean")
            clean_system
            ;;
        "reset")
            reset_system
            ;;
        "-h"|"--help"|"help")
            show_banner
            show_help
            ;;
        *)
            log_error "未知命令: $1"
            echo
            show_help
            exit 1
            ;;
    esac
}

# 运行主函数
main "$@"