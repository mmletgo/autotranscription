#!/bin/bash

# AutoTranscription 生产级别服务端启动脚本
# 支持功能: 后台运行、进程管理、日志管理、健康检查、自动重启

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
PID_FILE="$PROJECT_DIR/logs/transcription_server.pid"
LOG_FILE="$PROJECT_DIR/logs/transcription_server.log"
ERROR_LOG_FILE="$PROJECT_DIR/logs/transcription_server_error.log"
CONFIG_FILE="$PROJECT_DIR/config/server_config.json"
CONDA_ENV_NAME="autotranscription"

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
AutoTranscription 服务端管理脚本

用法: $SCRIPT_NAME [选项]

选项:
    start       启动服务 (默认)
    stop        停止服务
    restart     重启服务
    status      查看服务状态
    logs        查看日志
    health      健康检查
    monitor     监控并发状态
    config      显示配置信息
    -h, --help  显示此帮助信息

特性:
    - 高并发转写支持 (最多8-16个并发)
    - 智能队列管理 (最多100个请求排队)
    - GPU内存优化管理
    - 实时性能监控
    - 负载均衡和超时控制

示例:
    $SCRIPT_NAME start      # 启动服务
    $SCRIPT_NAME monitor    # 监控并发状态
    $SCRIPT_NAME health     # 健康检查

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
    python3 -c "import flask, faster_whisper, gunicorn" 2>/dev/null || {
        log_error "Python依赖不完整，请重新运行: ./scripts/install_deps.sh"
        exit 1
    }

    log_info "已激活Conda环境: $CONDA_ENV_NAME"
}

# 加载配置
load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        HOST=$(python3 -c "import json; print(json.load(open('$CONFIG_FILE'))['host'])" 2>/dev/null || echo "0.0.0.0")
        PORT=$(python3 -c "import json; print(json.load(open('$CONFIG_FILE'))['port'])" 2>/dev/null || echo 5000)
        WORKERS=$(python3 -c "import json; print(json.load(open('$CONFIG_FILE'))['workers'])" 2>/dev/null || echo 4)
        TIMEOUT=$(python3 -c "import json; print(json.load(open('$CONFIG_FILE'))['timeout'])" 2>/dev/null || echo 600)
        LOG_LEVEL=$(python3 -c "import json; print(json.load(open('$CONFIG_FILE'))['log_level'])" 2>/dev/null || echo "INFO")
        MAX_CONCURRENT=$(python3 -c "import json; print(json.load(open('$CONFIG_FILE')).get('max_concurrent_transcriptions', 8))" 2>/dev/null || echo 8)
    else
        # 默认配置
        HOST="0.0.0.0"
        PORT=5000
        WORKERS=4
        TIMEOUT=600
        LOG_LEVEL="INFO"
        MAX_CONCURRENT=8
    fi

    log_info "配置: HOST=$HOST, PORT=$PORT, WORKERS=$WORKERS, TIMEOUT=$TIMEOUT, LOG_LEVEL=$LOG_LEVEL, MAX_CONCURRENT=$MAX_CONCURRENT"
}

# 检查服务状态
check_status() {
    if [[ -f "$PID_FILE" ]]; then
        PID=$(cat "$PID_FILE")
        if ps -p "$PID" > /dev/null 2>&1; then
            log_info "服务正在运行 (PID: $PID)"
            return 0
        else
            log_warning "PID文件存在但进程不存在，清理PID文件"
            rm -f "$PID_FILE"
            return 1
        fi
    else
        log_info "服务未运行"
        return 1
    fi
}

# 健康检查
health_check() {
    local max_attempts=30
    local attempt=1

    while [[ $attempt -le $max_attempts ]]; do
        if curl -s -f "http://localhost:$PORT/api/health" > /dev/null 2>&1; then
            log_success "健康检查通过"
            return 0
        fi

        log_info "健康检查失败，重试 ($attempt/$max_attempts)..."
        sleep 2
        ((attempt++))
    done

    log_error "健康检查失败，服务可能未正常启动"
    return 1
}

# 监控并发状态
monitor_status() {
    if ! check_status; then
        log_error "服务未运行，无法监控"
        return 1
    fi

    log_info "开始监控并发状态 (按 Ctrl+C 退出)"

    while true; do
        clear
        echo "AutoTranscription 服务监控"
        echo "=========================="
        echo "时间: $(date '+%Y-%m-%d %H:%M:%S')"
        echo

        # 获取状态信息
        if status_output=$(curl -s "http://localhost:$PORT/api/status" 2>/dev/null); then
            echo "📊 队列状态:"
            echo "$status_output" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    q = data['queue']
    print(f\"  - 队列大小: {q['size']}/{q['max_size']}\")
    print(f\"  - 活跃转写: {q['active_transcriptions']}\")
    print(f\"  - 最大并发: {q['max_concurrent']}\")

    # 计算使用率
    queue_usage = (q['size'] / q['max_size']) * 100
    concurrent_usage = (q['active_transcriptions'] / q['max_concurrent']) * 100

    print(f\"  - 队列使用率: {queue_usage:.1f}%\")
    print(f\"  - 并发使用率: {concurrent_usage:.1f}%\")

    perf = data['performance']
    total = perf.get('total_requests', 0)
    success = perf.get('successful_requests', 0)
    failed = perf.get('failed_requests', 0)

    print(f\"\\n📈 性能统计:\")
    print(f\"  - 总请求数: {total}\")
    print(f\"  - 成功请求: {success}\")
    print(f\"  - 失败请求: {failed}\")
    if total > 0:
        success_rate = (success / total) * 100
        print(f\"  - 成功率: {success_rate:.1f}%\")

    print(f\"\\n🖥️  模型信息:\")
    model = data['model']
    print(f\"  - 模型: {model['size']}\")
    print(f\"  - 设备: {model['device']}\")
    print(f\"  - 计算类型: {model['compute_type']}\")

except Exception as e:
    print(f\"解析状态信息失败: {e}\")
"
        else
            echo "❌ 无法获取状态信息"
        fi

        echo
        echo "Ctrl+C 退出监控"
        sleep 3
    done
}

# 启动服务
start_service() {
    log_info "启动AutoTranscription服务 (支持高并发转写)..."

    if check_status; then
        log_warning "服务已在运行"
        return 0
    fi

    check_environment
    load_config

    log_info "启动高并发Gunicorn服务器..."

    # 创建启动脚本，确保在conda环境中运行
    cat > /tmp/start_server.sh << EOF
#!/bin/bash
# 确保conda环境正确激活
CONDA_BASE="/home/rongheng/anaconda3"
if [ -f "\$CONDA_BASE/etc/profile.d/conda.sh" ]; then
    . "\$CONDA_BASE/etc/profile.d/conda.sh"
    conda activate "$CONDA_ENV_NAME" || {
        echo "Failed to activate conda environment, trying direct activation..."
        . "\$CONDA_BASE/bin/activate" "$CONDA_ENV_NAME" || exit 1
    }
else
    echo "Conda not found at \$CONDA_BASE"
    exit 1
fi

cd "$PROJECT_DIR/server"

# 导出Python路径以确保模块可用
export PYTHONPATH="$PROJECT_DIR/server:$PYTHONPATH"

exec gunicorn \\
    --bind "$HOST:$PORT" \\
    --workers "$WORKERS" \\
    --worker-class gevent \\
    --timeout "$TIMEOUT" \\
    --max-requests 1000 \\
    --max-requests-jitter 100 \\
    --access-logfile "$LOG_FILE" \\
    --error-logfile "$ERROR_LOG_FILE" \\
    --log-level "$LOG_LEVEL" \\
    --pid "$PID_FILE" \\
    --daemon \\
    "transcription_server:app"
EOF

    chmod +x /tmp/start_server.sh

    # 使用gunicorn启动服务，后台运行
    nohup /tmp/start_server.sh >> "$LOG_FILE" 2>&1

    # 清理临时脚本
    rm -f /tmp/start_server.sh

    # 等待服务启动
    sleep 3

    if check_status; then
        log_success "高并发服务启动成功"
        log_info "PID: $(cat "$PID_FILE")"
        log_info "访问地址: http://localhost:$PORT"
        log_info "健康检查: http://localhost:$PORT/api/health"
        log_info "状态监控: http://localhost:$PORT/api/status"
        log_info "最大并发数: $MAX_CONCURRENT"

        # 健康检查
        if health_check; then
            log_success "服务健康检查通过"
        else
            log_warning "服务启动但健康检查失败，请查看日志"
        fi
    else
        log_error "服务启动失败，请查看日志: $LOG_FILE"
        exit 1
    fi
}

# 停止服务
stop_service() {
    log_info "停止AutoTranscription服务..."

    if ! check_status; then
        log_warning "服务未运行"
        return 0
    fi

    PID=$(cat "$PID_FILE")
    log_info "正在停止服务 (PID: $PID)..."

    # 发送TERM信号
    kill -TERM "$PID" 2>/dev/null || true

    # 等待进程结束
    local count=0
    while ps -p "$PID" > /dev/null 2>&1 && [[ $count -lt 10 ]]; do
        sleep 1
        ((count++))
    done

    # 如果进程仍在运行，强制杀死
    if ps -p "$PID" > /dev/null 2>&1; then
        log_warning "进程未响应TERM信号，强制终止"
        kill -KILL "$PID" 2>/dev/null || true
        sleep 1
    fi

    # 清理PID文件
    rm -f "$PID_FILE"

    log_success "服务已停止"
}

# 重启服务
restart_service() {
    log_info "重启AutoTranscription服务..."
    stop_service
    sleep 2
    start_service
}

# 显示日志
show_logs() {
    if [[ -f "$LOG_FILE" ]]; then
        tail -f "$LOG_FILE"
    else
        log_error "日志文件不存在: $LOG_FILE"
    fi
}

# 显示配置
show_config() {
    log_info "当前配置:"
    echo "=========================="
    if [[ -f "$CONFIG_FILE" ]]; then
        cat "$CONFIG_FILE" | python3 -m json.tool
    else
        echo "配置文件不存在: $CONFIG_FILE"
    fi
    echo "=========================="
}

# 显示状态信息
show_status() {
    echo "AutoTranscription 服务状态"
    echo "=========================="

    if check_status; then
        PID=$(cat "$PID_FILE")
        echo "状态: 运行中"
        echo "PID: $PID"

        # 显示进程信息
        if command -v ps &> /dev/null; then
            echo "进程信息:"
            ps -p "$PID" -o pid,ppid,cmd,etime,pcpu,pmem 2>/dev/null || echo "无法获取进程信息"
        fi

        # 显示端口信息
        if command -v netstat &> /dev/null; then
            echo "监听端口:"
            netstat -tlnp 2>/dev/null | grep ":$PORT " || echo "无法获取端口信息"
        fi

        # 健康检查
        if curl -s -f "http://localhost:$PORT/api/health" > /dev/null 2>&1; then
            echo "健康检查: 通过"
        else
            echo "健康检查: 失败"
        fi
    else
        echo "状态: 未运行"
    fi

    echo "=========================="
    echo "日志文件: $LOG_FILE"
    echo "错误日志: $ERROR_LOG_FILE"
    echo "配置文件: $CONFIG_FILE"
    echo "PID文件: $PID_FILE"
}

# 清理函数
cleanup() {
    # 在脚本退出时进行清理
    if [[ "$1" == "EXIT" ]]; then
        # 正常退出，不需要特殊处理
        true
    fi
}

# 信号处理
trap cleanup EXIT
trap 'log_warning "收到中断信号，正在停止服务..."; stop_service; exit 130' INT TERM

# 主函数
main() {
    # 切换到项目目录
    cd "$PROJECT_DIR"

    # 处理命令行参数
    case "${1:-start}" in
        "start")
            start_service
            ;;
        "stop")
            stop_service
            ;;
        "restart")
            restart_service
            ;;
        "status")
            show_status
            ;;
        "logs")
            show_logs
            ;;
        "health")
            if check_status; then
                if curl -s -f "http://localhost:$PORT/api/health"; then
                    log_success "健康检查通过"
                    exit 0
                else
                    log_error "健康检查失败"
                    exit 1
                fi
            else
                log_error "服务未运行"
                exit 1
            fi
            ;;
        "monitor")
            monitor_status
            ;;
        "config")
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