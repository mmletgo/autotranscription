#!/bin/bash

# AutoTranscription 客户端服务安装脚本
# 跨平台支持: Linux (systemd), macOS (launchd), Windows (nssm)

set -e

# 检测操作系统
detect_os() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        OS="linux"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        OS="mac"
    elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]]; then
        OS="windows"
    else
        OS="unknown"
    fi
}

# 跨平台颜色输出
setup_colors() {
    if command -v tput &> /dev/null; then
        RED=$(tput setaf 1)
        GREEN=$(tput setaf 2)
        YELLOW=$(tput setaf 3)
        BLUE=$(tput setaf 4)
        NC=$(tput sgr0)
    else
        RED=''
        GREEN=''
        YELLOW=''
        BLUE=''
        NC=''
    fi
}

# 初始化
detect_os
setup_colors

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

# 配置变量
if [[ "$OS" == "windows" ]]; then
    # Windows路径处理
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
    SCRIPT_NAME="$(basename "$0")"
    SERVICE_NAME="AutoTranscriptionClient"
    SERVICE_USER="$USERNAME"
    CONDA_ENV_NAME="autotranscription"
    # Windows使用反斜杠
    PROJECT_DIR=$(echo "$PROJECT_DIR" | sed 's|/|\\|g')
else
    # Unix系统
    PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    SCRIPT_NAME="$(basename "$0")"
    SERVICE_NAME="autotranscription-client"
    SERVICE_USER="$(whoami)"
    CONDA_ENV_NAME="autotranscription"
fi

# 显示帮助信息
show_help() {
    cat << EOF
AutoTranscription 客户端服务安装脚本 (跨平台支持)

检测到操作系统: $OS

用法: $SCRIPT_NAME [选项]

选项:
    install     安装客户端服务 (默认)
    uninstall   卸载客户端服务
    status      查看服务状态
    enable      启用开机自启
    disable     禁用开机自启
    start       启动服务
    stop        停止服务
    restart     重启服务
    logs        查看服务日志
    -h, --help  显示此帮助信息

示例:
    $SCRIPT_NAME install     # 安装服务
    $SCRIPT_NAME enable      # 启用开机自启
    $SCRIPT_NAME status      # 查看服务状态

平台支持:
  Linux: 使用 systemd 服务管理
  macOS: 使用 launchd 服务管理
  Windows: 使用 NSSM (Non-Sucking Service Manager)

EOF
}

# 获取conda可执行文件路径
get_conda_exec() {
    if [[ "$OS" == "windows" ]]; then
        # Windows conda路径
        if [[ -f "$USERPROFILE/miniconda3/Scripts/conda.exe" ]]; then
            echo "$USERPROFILE/miniconda3/Scripts/conda.exe"
        elif [[ -f "$USERPROFILE/anaconda3/Scripts/conda.exe" ]]; then
            echo "$USERPROFILE/anaconda3/Scripts/conda.exe"
        else
            which conda.exe 2>/dev/null || echo "conda"
        fi
    else
        # Unix系统
        which conda 2>/dev/null || echo "conda"
    fi
}

# 检查环境
check_environment() {
    log_info "检查安装环境 (平台: $OS)..."

    # 检查conda
    local conda_exec=$(get_conda_exec)
    if ! command -v "$conda_exec" &> /dev/null; then
        log_error "未找到conda，请先运行: ./scripts/install_deps.sh"
        exit 1
    fi

    # 检查conda环境
    if ! $conda_exec env list | grep -q "^$CONDA_ENV_NAME "; then
        log_error "Conda环境 '$CONDA_ENV_NAME' 不存在，请先运行: ./scripts/install_deps.sh"
        exit 1
    fi

    # 检查项目目录
    if [[ ! -d "$PROJECT_DIR" ]]; then
        log_error "项目目录不存在: $PROJECT_DIR"
        exit 1
    fi

    # 检查客户端脚本
    local client_script="$PROJECT_DIR/scripts/start_client.sh"
    if [[ "$OS" == "windows" ]]; then
        client_script="$PROJECT_DIR\\scripts\\start_client.sh"
    fi

    if [[ ! -f "$PROJECT_DIR/scripts/start_client.sh" ]]; then
        log_error "客户端启动脚本不存在: $PROJECT_DIR/scripts/start_client.sh"
        exit 1
    fi

    log_success "环境检查通过"
}

# 创建环境变量文件
create_env_file() {
    log_info "创建环境变量文件..."

    if [[ "$OS" == "windows" ]]; then
        local env_file="$PROJECT_DIR\\.env"
    else
        local env_file="$PROJECT_DIR/.env"
    fi

    cat > "$env_file" << EOF
# AutoTranscription 客户端环境变量
# 由 install_client_service.sh 自动生成

# 项目路径
PROJECT_DIR="$PROJECT_DIR"

# Conda环境
CONDA_ENV_NAME="$CONDA_ENV_NAME"

# 用户信息
SERVICE_USER="$SERVICE_USER"

# 日志路径
LOG_DIR="$PROJECT_DIR/logs"
CLIENT_LOG_FILE="\$LOG_DIR/client_service.log"

# 客户端配置
CLIENT_CONFIG_FILE="$PROJECT_DIR/config/client_config.json"

# 启动参数
CLIENT_ARGS="start"

# 其他设置
PYTHONUNBUFFERED=1
EOF

    log_success "环境变量文件创建完成: $env_file"
}

# Linux systemd 服务
create_linux_service() {
    log_info "创建Linux systemd服务文件..."

    local service_file="/etc/systemd/system/$SERVICE_NAME.service"

    # 需要sudo权限创建系统服务文件
    if [[ $EUID -ne 0 ]]; then
        log_info "需要sudo权限创建系统服务文件"
        if ! sudo -v; then
            log_error "获取sudo权限失败"
            exit 1
        fi
    fi

    local service_content="[Unit]
Description=AutoTranscription Client Service
Documentation=https://github.com/your-repo/autotranscription
After=network.target sound.target
Wants=network.target

[Service]
Type=simple
User=$SERVICE_USER
Group=$SERVICE_USER
WorkingDirectory=$PROJECT_DIR
EnvironmentFile=$PROJECT_DIR/.env
Environment=PYTHONUNBUFFERED=1
ExecStart=$PROJECT_DIR/scripts/start_client.sh \$CLIENT_ARGS
ExecReload=/bin/kill -HUP \$MAINPID
Restart=always
RestartSec=10
StandardOutput=append:\$CLIENT_LOG_FILE
StandardError=append:\$CLIENT_LOG_FILE

# 安全设置
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=$PROJECT_DIR/logs $PROJECT_DIR/config

[Install]
WantedBy=multi-user.target
"

    # 写入服务文件
    echo "$service_content" | sudo tee "$service_file" > /dev/null

    if [[ $? -eq 0 ]]; then
        log_success "systemd服务文件创建完成: $service_file"
        return 0
    else
        log_error "systemd服务文件创建失败"
        return 1
    fi
}

# macOS launchd 服务
create_mac_service() {
    log_info "创建macOS launchd服务文件..."

    local launchd_dir="$HOME/Library/LaunchAgents"
    local plist_file="$launchd_dir/com.autotranscription.client.plist"

    # 创建LaunchAgents目录
    mkdir -p "$launchd_dir"

    local plist_content="<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">
<plist version=\"1.0\">
<dict>
    <key>Label</key>
    <string>com.autotranscription.client</string>
    <key>ProgramArguments</key>
    <array>
        <string>$PROJECT_DIR/scripts/start_client.sh</string>
        <string>start</string>
    </array>
    <key>WorkingDirectory</key>
    <string>$PROJECT_DIR</string>
    <key>EnvironmentVariables</key>
    <dict>
        <key>PYTHONUNBUFFERED</key>
        <string>1</string>
        <key>PROJECT_DIR</key>
        <string>$PROJECT_DIR</string>
        <key>CONDA_ENV_NAME</key>
        <string>$CONDA_ENV_NAME</string>
    </dict>
    <key>RunAtLoad</key>
    <false/>
    <key>KeepAlive</key>
    <dict>
        <key>SuccessfulExit</key>
        <false/>
        <key>Crashed</key>
        <true/>
    </dict>
    <key>StandardOutPath</key>
    <string>$PROJECT_DIR/logs/client_service.log</string>
    <key>StandardErrorPath</key>
    <string>$PROJECT_DIR/logs/client_service_error.log</string>
    <key>RestartInterval</key>
    <integer>10</integer>
</dict>
</plist>"

    # 写入plist文件
    echo "$plist_content" > "$plist_file"

    if [[ $? -eq 0 ]]; then
        log_success "launchd服务文件创建完成: $plist_file"
        return 0
    else
        log_error "launchd服务文件创建失败"
        return 1
    fi
}

# Windows NSSM 服务
create_windows_service() {
    log_info "创建Windows服务..."

    # 检查NSSM是否已安装
    if ! command -v nssm &> /dev/null; then
        log_error "未找到NSSM (Non-Sucking Service Manager)"
        log_info "请从 https://nssm.cc/download 下载并安装NSSM"
        log_info "或者运行: choco install nssm"
        return 1
    fi

    # 创建启动脚本
    local startup_script="$PROJECT_DIR\\scripts\\start_client_windows.bat"
    cat > "$startup_script" << EOF
@echo off
REM AutoTranscription Client Windows Startup Script

REM 获取conda路径
for %%i in ("%USERPROFILE%\\miniconda3\\Scripts\\conda.exe") do set CONDA_PATH=%%~dpi
if not exist "%CONDA_PATH%" (
    for %%i in ("%USERPROFILE%\\anaconda3\\Scripts\\conda.exe") do set CONDA_PATH=%%~dpi
)

if not exist "%CONDA_PATH%" (
    echo Conda not found
    exit /b 1
)

REM 激活conda环境
call "%CONDA_PATH%" activate autotranscription

REM 切换到项目目录
cd /d "$PROJECT_DIR"

REM 启动客户端
python scripts\\start_client.sh start
EOF

    # 使用NSSM创建服务
    nssm install "$SERVICE_NAME" "$startup_script"

    # 配置服务参数
    nssm set "$SERVICE_NAME" DisplayName "AutoTranscription Client Service"
    nssm set "$SERVICE_NAME" Description "AutoTranscription speech-to-text client service"
    nssm set "$SERVICE_NAME" Start SERVICE_AUTO_START
    nssm set "$SERVICE_NAME" AppStdout "$PROJECT_DIR\\logs\\client_service.log"
    nssm set "$SERVICE_NAME" AppStderr "$PROJECT_DIR\\logs\\client_service_error.log"
    nssm set "$SERVICE_NAME" AppRestartDelay 10000

    if [[ $? -eq 0 ]]; then
        log_success "Windows服务创建完成: $SERVICE_NAME"
        return 0
    else
        log_error "Windows服务创建失败"
        return 1
    fi
}

# 创建服务文件
create_service_file() {
    log_info "创建$OS平台服务文件..."

    case "$OS" in
        "linux")
            create_linux_service
            ;;
        "mac")
            create_mac_service
            ;;
        "windows")
            create_windows_service
            ;;
        *)
            log_error "不支持的操作系统: $OS"
            return 1
            ;;
    esac
}

# 安装服务
install_service() {
    log_info "安装AutoTranscription客户端服务..."

    # 检查环境
    check_environment

    # 检查服务是否已存在
    if service_exists; then
        log_warning "服务 '$SERVICE_NAME' 已存在，将先卸载..."
        uninstall_service
    fi

    # 创建环境变量文件
    create_env_file

    # 创建日志目录
    mkdir -p "$PROJECT_DIR/logs"

    # 创建服务文件
    if ! create_service_file; then
        log_error "服务文件创建失败"
        exit 1
    fi

    # 平台特定的安装后操作
    case "$OS" in
        "linux")
            log_info "重新加载systemd..."
            sudo systemctl daemon-reload
            ;;
        "mac")
            log_info "加载launchd服务..."
            launchctl load "$HOME/Library/LaunchAgents/com.autotranscription.client.plist" 2>/dev/null || true
            ;;
        "windows")
            log_info "Windows服务已创建"
            ;;
    esac

    log_success "客户端服务安装完成 ($OS)"
    show_platform_usage_info
}

# 检查服务是否存在
service_exists() {
    case "$OS" in
        "linux")
            systemctl list-unit-files | grep -q "$SERVICE_NAME.service" 2>/dev/null
            ;;
        "mac")
            [[ -f "$HOME/Library/LaunchAgents/com.autotranscription.client.plist" ]]
            ;;
        "windows")
            nssm list | grep -q "$SERVICE_NAME" 2>/dev/null
            ;;
        *)
            return 1
            ;;
    esac
}

# 卸载服务
uninstall_service() {
    log_info "卸载AutoTranscription客户端服务..."

    case "$OS" in
        "linux")
            # 停止服务
            if systemctl is-active --quiet "$SERVICE_NAME" 2>/dev/null; then
                log_info "停止服务..."
                sudo systemctl stop "$SERVICE_NAME" || log_warning "停止服务失败"
            fi

            # 禁用服务
            if systemctl is-enabled --quiet "$SERVICE_NAME" 2>/dev/null; then
                log_info "禁用服务..."
                sudo systemctl disable "$SERVICE_NAME" || log_warning "禁用服务失败"
            fi

            # 删除服务文件
            local service_file="/etc/systemd/system/$SERVICE_NAME.service"
            if [[ -f "$service_file" ]]; then
                log_info "删除服务文件..."
                sudo rm -f "$service_file"
            fi

            # 重新加载systemd
            sudo systemctl daemon-reload
            sudo systemctl reset-failed "$SERVICE_NAME" 2>/dev/null || true
            ;;

        "mac")
            # 卸载launchd服务
            launchctl unload "$HOME/Library/LaunchAgents/com.autotranscription.client.plist" 2>/dev/null || true

            # 删除plist文件
            if [[ -f "$HOME/Library/LaunchAgents/com.autotranscription.client.plist" ]]; then
                log_info "删除launchd服务文件..."
                rm -f "$HOME/Library/LaunchAgents/com.autotranscription.client.plist"
            fi
            ;;

        "windows")
            # 停止并删除服务
            nssm stop "$SERVICE_NAME" 2>/dev/null || true
            nssm remove "$SERVICE_NAME" confirm 2>/dev/null || true

            # 删除启动脚本
            local startup_script="$PROJECT_DIR\\scripts\\start_client_windows.bat"
            if [[ -f "$startup_script" ]]; then
                log_info "删除Windows启动脚本..."
                rm -f "$startup_script"
            fi
            ;;
    esac

    # 删除环境变量文件
    local env_file="$PROJECT_DIR/.env"
    if [[ -f "$env_file" ]]; then
        log_info "删除环境变量文件..."
        rm -f "$env_file"
    fi

    log_success "客户端服务卸载完成 ($OS)"
}

# 查看服务状态
show_status() {
    log_info "查看服务状态..."

    if ! service_exists; then
        log_warning "服务 '$SERVICE_NAME' 未安装"
        return 1
    fi

    case "$OS" in
        "linux")
            echo "服务状态:"
            systemctl status "$SERVICE_NAME" --no-pager

            echo
            echo "开机自启状态:"
            if systemctl is-enabled --quiet "$SERVICE_NAME"; then
                echo "✓ 已启用开机自启"
            else
                echo "✗ 未启用开机自启"
            fi
            ;;
        "mac")
            echo "服务状态:"
            if launchctl list | grep -q "com.autotranscription.client"; then
                echo "✓ 服务已加载"
            else
                echo "✗ 服务未加载"
            fi
            ;;
        "windows")
            echo "服务状态:"
            nssm status "$SERVICE_NAME"
            ;;
    esac

    echo
    echo "最近日志:"
    if [[ -f "$PROJECT_DIR/logs/client_service.log" ]]; then
        tail -20 "$PROJECT_DIR/logs/client_service.log"
    else
        echo "日志文件不存在"
    fi
}

# 启用开机自启
enable_service() {
    log_info "启用开机自启..."

    if ! service_exists; then
        log_error "服务 '$SERVICE_NAME' 未安装，请先运行: $SCRIPT_NAME install"
        exit 1
    fi

    case "$OS" in
        "linux")
            sudo systemctl enable "$SERVICE_NAME"
            ;;
        "mac")
            # launchd服务默认是RunAtLoad=false，需要修改plist
            local plist_file="$HOME/Library/LaunchAgents/com.autotranscription.client.plist"
            if [[ -f "$plist_file" ]]; then
                sed -i '' 's/<key>RunAtLoad<\/key><false\/>/<key>RunAtLoad<\/key><true\/>/g' "$plist_file"
                launchctl unload "$plist_file" 2>/dev/null || true
                launchctl load "$plist_file"
            fi
            ;;
        "windows")
            nssm set "$SERVICE_NAME" Start SERVICE_AUTO_START
            ;;
    esac

    if [[ $? -eq 0 ]]; then
        log_success "开机自启已启用 ($OS)"
    else
        log_error "启用开机自启失败"
        exit 1
    fi
}

# 禁用开机自启
disable_service() {
    log_info "禁用开机自启..."

    if ! service_exists; then
        log_error "服务 '$SERVICE_NAME' 未安装"
        exit 1
    fi

    case "$OS" in
        "linux")
            sudo systemctl disable "$SERVICE_NAME"
            ;;
        "mac")
            # launchd服务设置RunAtLoad=false
            local plist_file="$HOME/Library/LaunchAgents/com.autotranscription.client.plist"
            if [[ -f "$plist_file" ]]; then
                sed -i '' 's/<key>RunAtLoad<\/key><true\/>/<key>RunAtLoad<\/key><false\/>/g' "$plist_file"
                launchctl unload "$plist_file" 2>/dev/null || true
                launchctl load "$plist_file"
            fi
            ;;
        "windows")
            nssm set "$SERVICE_NAME" Start SERVICE_DEMAND_START
            ;;
    esac

    if [[ $? -eq 0 ]]; then
        log_success "开机自启已禁用 ($OS)"
    else
        log_error "禁用开机自启失败"
        exit 1
    fi
}

# 启动服务
start_service() {
    log_info "启动客户端服务..."

    if ! service_exists; then
        log_error "服务 '$SERVICE_NAME' 未安装，请先运行: $SCRIPT_NAME install"
        exit 1
    fi

    case "$OS" in
        "linux")
            sudo systemctl start "$SERVICE_NAME"
            ;;
        "mac")
            launchctl start "com.autotranscription.client"
            ;;
        "windows")
            nssm start "$SERVICE_NAME"
            ;;
    esac

    if [[ $? -eq 0 ]]; then
        log_success "客户端服务启动成功 ($OS)"
    else
        log_error "客户端服务启动失败"
        exit 1
    fi
}

# 停止服务
stop_service() {
    log_info "停止客户端服务..."

    if ! service_exists; then
        log_error "服务 '$SERVICE_NAME' 未安装"
        exit 1
    fi

    case "$OS" in
        "linux")
            sudo systemctl stop "$SERVICE_NAME"
            ;;
        "mac")
            launchctl stop "com.autotranscription.client"
            ;;
        "windows")
            nssm stop "$SERVICE_NAME"
            ;;
    esac

    if [[ $? -eq 0 ]]; then
        log_success "客户端服务停止成功 ($OS)"
    else
        log_error "客户端服务停止失败"
        exit 1
    fi
}

# 重启服务
restart_service() {
    log_info "重启客户端服务..."

    if ! service_exists; then
        log_error "服务 '$SERVICE_NAME' 未安装，请先运行: $SCRIPT_NAME install"
        exit 1
    fi

    case "$OS" in
        "linux")
            sudo systemctl restart "$SERVICE_NAME"
            ;;
        "mac")
            launchctl stop "com.autotranscription.client"
            sleep 2
            launchctl start "com.autotranscription.client"
            ;;
        "windows")
            nssm restart "$SERVICE_NAME"
            ;;
    esac

    if [[ $? -eq 0 ]]; then
        log_success "客户端服务重启成功 ($OS)"
    else
        log_error "客户端服务重启失败"
        exit 1
    fi
}

# 查看服务日志
show_logs() {
    log_info "查看客户端服务日志..."

    case "$OS" in
        "linux")
            if command -v journalctl &> /dev/null; then
                echo "=== Systemd 日志 ==="
                sudo journalctl -u "$SERVICE_NAME" -f --no-pager
            else
                echo "查看项目日志文件:"
                tail -f "$PROJECT_DIR/logs/client_service.log"
            fi
            ;;
        "mac")
            echo "查看项目日志文件:"
            tail -f "$PROJECT_DIR/logs/client_service.log"
            ;;
        "windows")
            echo "查看项目日志文件:"
            if [[ -f "$PROJECT_DIR/logs/client_service.log" ]]; then
                type "$PROJECT_DIR/logs/client_service.log"
            else
                echo "日志文件不存在"
            fi
            ;;
    esac
}

# 显示平台特定的使用说明
show_platform_usage_info() {
    echo
    echo "=== $OS 平台使用说明 ==="
    echo

    case "$OS" in
        "linux")
            echo "服务管理命令:"
            echo "  启用开机自启: $SCRIPT_NAME enable"
            echo "  禁用开机自启: $SCRIPT_NAME disable"
            echo "  启动服务:     $SCRIPT_NAME start"
            echo "  停止服务:     $SCRIPT_NAME stop"
            echo "  重启服务:     $SCRIPT_NAME restart"
            echo "  查看状态:     $SCRIPT_NAME status"
            echo "  查看日志:     $SCRIPT_NAME logs"
            echo
            echo "Systemd命令:"
            echo "  启用开机自启: sudo systemctl enable $SERVICE_NAME"
            echo "  查看服务状态: sudo systemctl status $SERVICE_NAME"
            echo "  查看日志:     sudo journalctl -u $SERVICE_NAME -f"
            ;;
        "mac")
            echo "服务管理命令:"
            echo "  启用开机自启: $SCRIPT_NAME enable"
            echo "  禁用开机自启: $SCRIPT_NAME disable"
            echo "  启动服务:     $SCRIPT_NAME start"
            echo "  停止服务:     $SCRIPT_NAME stop"
            echo "  重启服务:     $SCRIPT_NAME restart"
            echo "  查看状态:     $SCRIPT_NAME status"
            echo "  查看日志:     $SCRIPT_NAME logs"
            echo
            echo "Launchd命令:"
            echo "  查看服务状态: launchctl list | grep autotranscription"
            echo "  手动启动服务: launchctl start com.autotranscription.client"
            echo "  手动停止服务: launchctl stop com.autotranscription.client"
            ;;
        "windows")
            echo "服务管理命令:"
            echo "  启用开机自启: $SCRIPT_NAME enable"
            echo "  禁用开机自启: $SCRIPT_NAME disable"
            echo "  启动服务:     $SCRIPT_NAME start"
            echo "  停止服务:     $SCRIPT_NAME stop"
            echo "  重启服务:     $SCRIPT_NAME restart"
            echo "  查看状态:     $SCRIPT_NAME status"
            echo "  查看日志:     $SCRIPT_NAME logs"
            echo
            echo "NSSM命令:"
            echo "  查看服务状态: nssm status $SERVICE_NAME"
            echo "  手动启动服务: nssm start $SERVICE_NAME"
            echo "  手动停止服务: nssm stop $SERVICE_NAME"
            echo
            echo "Windows服务管理:"
            echo "  服务管理器: services.msc"
            echo "  查看服务: 在服务管理器中查找 '$SERVICE_NAME'"
            ;;
    esac

    echo
    echo "日志文件位置:"
    echo "  服务日志: $PROJECT_DIR/logs/client_service.log"
    echo "  项目日志: $PROJECT_DIR/logs/client.log"
    echo
    echo "注意事项:"
    echo "  1. 首次使用前请确保服务端已启动"
    echo "  2. 客户端会使用全局热键进行录音"
    echo "  3. 配置文件: $PROJECT_DIR/config/client_config.json"
}

# 显示使用说明
show_usage_info() {
    if [[ "$1" == "install" ]]; then
        log_success "=== 客户端服务安装完成 ($OS) ==="
        show_platform_usage_info
    fi
}

# 主函数
main() {
    # 切换到项目目录
    cd "$PROJECT_DIR"

    case "${1:-install}" in
        "install")
            install_service
            show_usage_info "install"
            ;;
        "uninstall")
            uninstall_service
            ;;
        "status")
            show_status
            ;;
        "enable")
            enable_service
            ;;
        "disable")
            disable_service
            ;;
        "start")
            start_service
            ;;
        "stop")
            stop_service
            ;;
        "restart")
            restart_service
            ;;
        "logs")
            show_logs
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

# 错误处理
trap 'log_error "操作过程中发生错误"; exit 1' ERR

# 运行主函数
main "$@"