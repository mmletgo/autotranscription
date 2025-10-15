#!/bin/bash

# AutoTranscription 客户端启动脚本
# 支持功能: 连接管理、错误处理、日志记录

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 配置变量
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT_NAME="$(basename "$0")"
CONFIG_FILE="$PROJECT_DIR/config/client_config.json"
CONDA_ENV_NAME="autotranscription"
LOG_FILE="$PROJECT_DIR/logs/client.log"

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
    log_to_file "INFO: $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
    log_to_file "SUCCESS: $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
    log_to_file "WARNING: $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
    log_to_file "ERROR: $1"
}

log_to_file() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $1" >> "$LOG_FILE"
}

# 显示帮助信息
show_help() {
    cat << EOF
AutoTranscription 客户端管理脚本

用法: $SCRIPT_NAME [选项]

选项:
    start       启动客户端 (默认)
    check       检查服务连接
    config      显示配置信息
    -h, --help  显示此帮助信息

环境变量:
    SERVER_URL  服务端地址 (覆盖配置文件)
    HOTKEY      快捷键组合 (覆盖配置文件)

示例:
    $SCRIPT_NAME start                    # 启动客户端
    $SCRIPT_NAME check                   # 检查服务连接
    SERVER_URL=http://192.168.1.100:5000 $SCRIPT_NAME start  # 连接到远程服务器

EOF
}

# 检查环境
check_environment() {
    # 检查conda是否可用
    if ! command -v conda &> /dev/null; then
        log_error "Conda未安装或不在PATH中，请先运行: ./scripts/install_deps.sh"
        exit 1
    fi

    # 检查conda环境是否存在
    if ! conda env list | grep -q "^$CONDA_ENV_NAME "; then
        log_error "Conda环境 '$CONDA_ENV_NAME' 不存在，请先运行: ./scripts/install_deps.sh"
        exit 1
    fi

    # 检查配置文件
    if [[ ! -f "$CONFIG_FILE" ]]; then
        log_error "配置文件不存在: $CONFIG_FILE"
        exit 1
    fi

    # 创建日志目录
    mkdir -p "$(dirname "$LOG_FILE")"

    # 激活conda环境
    source "$(conda info --base)/etc/profile.d/conda.sh"
    conda activate "$CONDA_ENV_NAME"

    # 检查关键模块
    python3 -c "import pyaudio, pynput, requests, soundfile" 2>/dev/null || {
        log_error "Python依赖不完整，请重新运行: ./scripts/install_deps.sh"
        exit 1
    }

    log_info "已激活Conda环境: $CONDA_ENV_NAME"
}

# 加载配置
load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        SERVER_URL=${SERVER_URL:-$(python3 -c "import json; print(json.load(open('$CONFIG_FILE'))['server_url'])" 2>/dev/null || echo "http://localhost:5000")}
        HOTKEY=${HOTKEY:-$(python3 -c "import json; print(json.load(open('$CONFIG_FILE'))['key_combo'])" 2>/dev/null || echo "<alt>")}
        MAX_TIME=$(python3 -c "import json; print(json.load(open('$CONFIG_FILE'))['max_time'])" 2>/dev/null || echo 30)
        ZH_CONVERT=$(python3 -c "import json; print(json.load(open('$CONFIG_FILE'))['zh_convert'])" 2>/dev/null || echo "none")
        STREAMING=$(python3 -c "import json; print(json.load(open('$CONFIG_FILE'))['streaming'])" 2>/dev/null || echo "true")
    else
        # 默认配置
        SERVER_URL="http://localhost:5000"
        HOTKEY="<alt>"
        MAX_TIME=30
        ZH_CONVERT="none"
        STREAMING="true"
    fi

    log_info "配置: SERVER_URL=$SERVER_URL, HOTKEY=$HOTKEY, MAX_TIME=$MAX_TIME"
}

# 检查服务连接
check_connection() {
    log_info "检查服务端连接: $SERVER_URL"

    # 检查服务是否可达 (禁用代理以支持局域网连接)
    if curl -s -f --noproxy '*' "$SERVER_URL/api/health" > /dev/null 2>&1; then
        log_success "服务端连接正常"
        return 0
    else
        log_error "无法连接到服务端: $SERVER_URL"
        log_info "请确保服务端已启动: ./scripts/start_server.sh"
        return 1
    fi
}

# 启动客户端
start_client() {
    log_info "启动AutoTranscription客户端..."

    check_environment
    load_config

    # 检查服务端连接
    if ! check_connection; then
        log_error "服务端连接失败，无法启动客户端"
        exit 1
    fi

    log_info "启动客户端..."
    log_info "服务端地址: $SERVER_URL"
    log_info "快捷键: $HOTKEY"
    log_info "日志文件: $LOG_FILE"

    # 构建启动参数
    local client_args=""

    # 添加服务端地址参数
    client_args="$client_args -s $SERVER_URL"

    # 添加快捷键参数
    client_args="$client_args -k $HOTKEY"

    # 添加其他参数
    client_args="$client_args --max-time $MAX_TIME"
    client_args="$client_args --zh-convert $ZH_CONVERT"

    if [[ "$STREAMING" == "true" ]]; then
        client_args="$client_args --streaming"
    fi

    # 切换到客户端目录
    cd "$PROJECT_DIR/client"

    # 启动客户端
    log_info "执行: python3 -u client.py $client_args"

    # 使用tee命令同时输出到控制台和日志文件
    # -u 参数禁用输出缓冲，确保实时显示日志
    python3 -u client.py $client_args 2>&1 | tee -a "$LOG_FILE"
}

# 显示配置
show_config() {
    log_info "当前客户端配置:"
    echo "=========================="
    if [[ -f "$CONFIG_FILE" ]]; then
        cat "$CONFIG_FILE" | python3 -m json.tool
    else
        echo "配置文件不存在: $CONFIG_FILE"
    fi
    echo "=========================="
    echo "环境变量覆盖:"
    echo "SERVER_URL: ${SERVER_URL:-未设置}"
    echo "HOTKEY: ${HOTKEY:-未设置}"
    echo "=========================="
}

# 清理函数
cleanup() {
    if [[ "$1" == "EXIT" ]]; then
        log_info "客户端退出"
    fi
}

# 信号处理
trap cleanup EXIT
trap 'log_warning "收到中断信号，正在退出..."; exit 130' INT TERM

# 主函数
main() {
    # 切换到项目目录
    cd "$PROJECT_DIR"

    # 处理命令行参数
    case "${1:-start}" in
        "start")
            start_client
            ;;
        "check")
            check_environment
            load_config
            check_connection
            ;;
        "config")
            check_environment
            show_config
            ;;
        "-h"|"--help")
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