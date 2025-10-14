#!/bin/bash

# AutoTranscription 客户端服务卸载脚本
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
AutoTranscription 客户端服务卸载脚本 (跨平台支持)

检测到操作系统: $OS

用法: $SCRIPT_NAME [选项]

选项:
    full        完全卸载 (默认) - 删除服务、配置和日志
    service     仅卸载服务 - 保留配置和日志文件
    clean       清理残留文件
    status      查看卸载前状态
    -h, --help  显示此帮助信息

示例:
    $SCRIPT_NAME           # 完全卸载
    $SCRIPT_NAME full      # 完全卸载
    $SCRIPT_NAME service   # 仅卸载服务
    $SCRIPT_NAME clean     # 清理残留文件

平台支持:
  Linux: 使用 systemd 服务管理
  macOS: 使用 launchd 服务管理
  Windows: 使用 NSSM (Non-Sucking Service Manager)

EOF
}

# 检查权限
check_permissions() {
    if [[ $EUID -eq 0 ]]; then
        log_warning "检测到root权限，建议使用普通用户运行"
        read -p "是否继续? [y/N]: " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "取消操作"
            exit 0
        fi
    fi
}

# 显示当前状态
show_current_status() {
    log_info "当前服务状态 ($OS):"

    echo
    echo "=== 服务安装状态 ==="

    case "$OS" in
        "linux")
            if systemctl list-unit-files | grep -q "$SERVICE_NAME.service" 2>/dev/null; then
                echo "服务状态: 已安装"
                if systemctl is-active --quiet "$SERVICE_NAME" 2>/dev/null; then
                    echo "运行状态: 正在运行"
                else
                    echo "运行状态: 已停止"
                fi
                if systemctl is-enabled --quiet "$SERVICE_NAME" 2>/dev/null; then
                    echo "开机自启: 已启用"
                else
                    echo "开机自启: 已禁用"
                fi
            else
                echo "服务状态: 未安装"
            fi

            # 显示systemd日志
            if journalctl -u "$SERVICE_NAME" --quiet --no-pager -n 3 2>/dev/null; then
                echo
                echo "=== Systemd 日志 ==="
                journalctl -u "$SERVICE_NAME" --no-pager -n 5 2>/dev/null
            fi
            ;;

        "mac")
            local plist_file="$HOME/Library/LaunchAgents/com.autotranscription.client.plist"
            if [[ -f "$plist_file" ]]; then
                echo "服务状态: 已安装"
                if launchctl list | grep -q "com.autotranscription.client" 2>/dev/null; then
                    echo "运行状态: 已加载"
                else
                    echo "运行状态: 未加载"
                fi
                echo "服务文件: $plist_file"
            else
                echo "服务状态: 未安装"
            fi
            ;;

        "windows")
            if command -v nssm &> /dev/null; then
                if nssm list | grep -q "$SERVICE_NAME" 2>/dev/null; then
                    echo "服务状态: 已安装"
                    echo "服务名称: $SERVICE_NAME"
                    nssm status "$SERVICE_NAME" 2>/dev/null || echo "无法获取状态"
                else
                    echo "服务状态: 未安装"
                fi
            else
                echo "NSSM状态: 未安装"
                echo "服务状态: 无法检查"
            fi
            ;;
    esac

    echo
    echo "=== 相关文件 ==="

    case "$OS" in
        "linux")
            local service_file="/etc/systemd/system/$SERVICE_NAME.service"
            if [[ -f "$service_file" ]]; then
                echo "服务文件: ✓ $service_file"
            else
                echo "服务文件: ✗ 不存在"
            fi
            ;;

        "mac")
            local plist_file="$HOME/Library/LaunchAgents/com.autotranscription.client.plist"
            if [[ -f "$plist_file" ]]; then
                echo "服务文件: ✓ $plist_file"
            else
                echo "服务文件: ✗ 不存在"
            fi
            ;;

        "windows")
            echo "Windows服务: 通过NSSM管理"
            ;;
    esac

    local env_file="$PROJECT_DIR/.env"
    if [[ "$OS" != "windows" && -f "$env_file" ]]; then
        echo "环境文件: ✓ $env_file"
    elif [[ "$OS" == "windows" && -f "$env_file" ]]; then
        echo "环境文件: ✓ $env_file"
    else
        echo "环境文件: ✗ 不存在"
    fi

    local log_dir="$PROJECT_DIR/logs"
    if [[ -d "$log_dir" ]]; then
        local log_count=$(find "$log_dir" -name "*client*.log" 2>/dev/null | wc -l)
        echo "日志目录: ✓ $log_dir (包含 $log_count 个客户端日志文件)"
    else
        echo "日志目录: ✗ 不存在"
    fi

    echo
    echo "=== 项目日志 ==="
    if [[ -f "$PROJECT_DIR/logs/client_service.log" ]]; then
        echo "服务日志:"
        tail -10 "$PROJECT_DIR/logs/client_service.log" 2>/dev/null
    else
        echo "服务日志: 不存在"
    fi
}

# 停止并禁用服务
stop_and_disable_service() {
    log_info "停止并禁用服务..."

    case "$OS" in
        "linux")
            # 停止服务
            if systemctl is-active --quiet "$SERVICE_NAME" 2>/dev/null; then
                log_info "停止服务..."
                if sudo systemctl stop "$SERVICE_NAME"; then
                    log_success "服务已停止"
                else
                    log_warning "停止服务失败"
                fi
            else
                log_info "服务未运行"
            fi

            # 禁用服务
            if systemctl is-enabled --quiet "$SERVICE_NAME" 2>/dev/null; then
                log_info "禁用开机自启..."
                if sudo systemctl disable "$SERVICE_NAME"; then
                    log_success "开机自启已禁用"
                else
                    log_warning "禁用开机自启失败"
                fi
            else
                log_info "开机自启未启用"
            fi
            ;;

        "mac")
            # 停止launchd服务
            if launchctl list | grep -q "com.autotranscription.client" 2>/dev/null; then
                log_info "停止launchd服务..."
                if launchctl stop "com.autotranscription.client"; then
                    log_success "launchd服务已停止"
                else
                    log_warning "停止launchd服务失败"
                fi
            else
                log_info "launchd服务未运行"
            fi

            # 卸载plist
            local plist_file="$HOME/Library/LaunchAgents/com.autotranscription.client.plist"
            if [[ -f "$plist_file" ]]; then
                log_info "卸载launchd服务..."
                launchctl unload "$plist_file" 2>/dev/null || true
            fi
            ;;

        "windows")
            # 停止Windows服务
            if command -v nssm &> /dev/null && nssm list | grep -q "$SERVICE_NAME" 2>/dev/null; then
                log_info "停止Windows服务..."
                if nssm stop "$SERVICE_NAME"; then
                    log_success "Windows服务已停止"
                else
                    log_warning "停止Windows服务失败"
                fi
            else
                log_info "Windows服务未运行"
            fi

            # 禁用自动启动
            if command -v nssm &> /dev/null && nssm list | grep -q "$SERVICE_NAME" 2>/dev/null; then
                log_info "禁用自动启动..."
                if nssm set "$SERVICE_NAME" Start SERVICE_DEMAND_START; then
                    log_success "自动启动已禁用"
                else
                    log_warning "禁用自动启动失败"
                fi
            fi
            ;;
    esac
}

# 删除systemd服务
remove_linux_service() {
    log_info "删除systemd服务..."

    local service_file="/etc/systemd/system/$SERVICE_NAME.service"

    if [[ -f "$service_file" ]]; then
        log_info "删除服务文件: $service_file"
        if sudo rm -f "$service_file"; then
            log_success "服务文件已删除"
        else
            log_error "删除服务文件失败"
            return 1
        fi
    else
        log_info "服务文件不存在"
    fi

    # 重新加载systemd
    log_info "重新加载systemd..."
    if sudo systemctl daemon-reload; then
        log_success "systemd已重新加载"
    else
        log_warning "systemd重新加载失败"
    fi

    # 重置失败状态
    if sudo systemctl reset-failed "$SERVICE_NAME" 2>/dev/null; then
        log_success "已重置服务状态"
    fi

    log_success "systemd服务删除完成"
}

# 删除launchd服务
remove_mac_service() {
    log_info "删除launchd服务..."

    local plist_file="$HOME/Library/LaunchAgents/com.autotranscription.client.plist"

    if [[ -f "$plist_file" ]]; then
        log_info "删除launchd服务文件: $plist_file"
        if rm -f "$plist_file"; then
            log_success "launchd服务文件已删除"
        else
            log_error "删除launchd服务文件失败"
            return 1
        fi
    else
        log_info "launchd服务文件不存在"
    fi

    log_success "launchd服务删除完成"
}

# 删除Windows服务
remove_windows_service() {
    log_info "删除Windows服务..."

    if command -v nssm &> /dev/null; then
        # 检查服务是否存在
        if nssm list | grep -q "$SERVICE_NAME" 2>/dev/null; then
            log_info "删除Windows服务..."
            if nssm remove "$SERVICE_NAME" confirm 2>/dev/null; then
                log_success "Windows服务已删除"
            else
                log_error "删除Windows服务失败"
                return 1
            fi
        else
            log_info "Windows服务不存在"
        fi
    else
        log_error "未找到NSSM，无法删除Windows服务"
        return 1
    fi

    # 删除启动脚本
    local startup_script="$PROJECT_DIR\\scripts\\start_client_windows.bat"
    if [[ -f "$startup_script" ]]; then
        log_info "删除Windows启动脚本: $startup_script"
        if rm -f "$startup_script"; then
            log_success "Windows启动脚本已删除"
        else
            log_error "删除Windows启动脚本失败"
        fi
    else
        log_info "Windows启动脚本不存在"
    fi

    log_success "Windows服务删除完成"
}

# 删除服务文件
remove_service_files() {
    log_info "删除服务文件..."

    case "$OS" in
        "linux")
            remove_linux_service
            ;;
        "mac")
            remove_mac_service
            ;;
        "windows")
            remove_windows_service
            ;;
        *)
            log_error "不支持的操作系统: $OS"
            return 1
            ;;
    esac
}

# 删除环境文件
remove_env_file() {
    log_info "删除环境配置文件..."

    local env_file="$PROJECT_DIR/.env"

    if [[ -f "$env_file" ]]; then
        log_info "删除环境文件: $env_file"
        if rm -f "$env_file"; then
            log_success "环境文件已删除"
        else
            log_error "删除环境文件失败"
            return 1
        fi
    else
        log_info "环境文件不存在"
    fi
}

# 清理日志文件
cleanup_logs() {
    log_info "清理客户端日志文件..."

    local log_dir="$PROJECT_DIR/logs"
    local cleaned=false

    if [[ -d "$log_dir" ]]; then
        # 查找客户端相关日志文件
        while IFS= read -r -d '' log_file; do
            log_info "删除日志文件: $log_file"
            if rm -f "$log_file"; then
                cleaned=true
            else
                log_warning "删除日志文件失败: $log_file"
            fi
        done < <(find "$log_dir" -name "*client*.log" -print0 2>/dev/null)

        if [[ "$cleaned" == true ]]; then
            log_success "客户端日志文件清理完成"
        else
            log_info "没有找到客户端日志文件"
        fi
    else
        log_info "日志目录不存在"
    fi
}

# 清理systemd日志
cleanup_systemd_logs() {
    if [[ "$OS" != "linux" ]]; then
        return 0
    fi

    log_info "清理systemd日志..."

    if journalctl -u "$SERVICE_NAME" --quiet --no-pager -n 1 2>/dev/null; then
        log_info "发现systemd日志记录"
        read -p "是否删除systemd中的服务日志? [y/N]: " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            if sudo journalctl --vacuum-time=1s -u "$SERVICE_NAME" 2>/dev/null; then
                log_success "systemd日志已清理"
            else
                log_warning "清理systemd日志失败"
            fi
        else
            log_info "保留systemd日志"
        fi
    else
        log_info "没有找到systemd日志记录"
    fi
}

# 清理launchd日志
cleanup_launchd_logs() {
    if [[ "$OS" != "mac" ]]; then
        return 0
    fi

    log_info "清理launchd日志..."

    # macOS的日志通常在/var/log中，但我们主要关注项目日志
    log_info "项目日志将在cleanup_logs()中清理"
}

# 清理Windows日志
cleanup_windows_logs() {
    if [[ "$OS" != "windows" ]]; then
        return 0
    fi

    log_info "清理Windows事件日志..."

    # Windows事件日志通常不需要手动清理
    log_info "Windows事件日志由系统自动管理"
}

# 清理平台特定的日志
cleanup_platform_logs() {
    case "$OS" in
        "linux")
            cleanup_systemd_logs
            ;;
        "mac")
            cleanup_launchd_logs
            ;;
        "windows")
            cleanup_windows_logs
            ;;
    esac
}

# 完全卸载
full_uninstall() {
    log_info "开始完全卸载AutoTranscription客户端服务 ($OS)..."

    # 检查权限
    check_permissions

    # 显示当前状态
    show_current_status

    echo
    read -p "确认完全卸载? 这将删除所有相关文件 [y/N]: " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "取消卸载"
        exit 0
    fi

    # 停止并禁用服务
    stop_and_disable_service

    # 删除服务文件
    remove_service_files

    # 删除环境文件
    remove_env_file

    # 清理日志文件
    cleanup_logs

    # 清理平台特定日志
    cleanup_platform_logs

    log_success "=== 客户端服务完全卸载完成 ($OS) ==="
    echo
    echo "已删除的组件:"
    echo "  ✓ $OS平台服务配置"
    echo "  ✓ 环境变量文件"
    echo "  ✓ 客户端日志文件"
    echo "  ✓ 平台日志记录"
    echo
    echo "保留的组件:"
    echo "  ✓ 项目源代码"
    echo "  ✓ 配置文件 (config/)"
    echo "  ✓ conda环境"
    echo "  ✓ 服务端相关文件"
    echo
    echo "如需重新安装服务，请运行:"
    echo "  ./scripts/install_client_service.sh install"
}

# 仅卸载服务
service_uninstall() {
    log_info "卸载系统服务 (保留配置和日志)..."

    # 检查权限
    check_permissions

    # 停止并禁用服务
    stop_and_disable_service

    # 删除服务文件
    remove_service_files

    # 删除环境文件
    remove_env_file

    log_success "=== 系统服务卸载完成 ($OS) ==="
    echo
    echo "已删除:"
    echo "  ✓ $OS平台服务配置"
    echo "  ✓ 环境变量文件"
    echo
    echo "保留的文件:"
    echo "  ✓ 配置文件 (config/client_config.json)"
    echo "  ✓ 日志文件 (logs/)"
    echo "  ✓ 项目源代码"
    echo "  ✓ conda环境"
    echo
    echo "如需重新安装服务，请运行:"
    echo "  ./scripts/install_client_service.sh install"
}

# 清理残留文件
cleanup_residual_files() {
    log_info "清理残留文件..."

    local cleaned=false

    # 检查并删除可能残留的文件
    case "$OS" in
        "linux")
            local residual_files=(
                "/etc/systemd/system/$SERVICE_NAME.service"
                "/tmp/.X11-unix/*"
            )

            for file_pattern in "${residual_files[@]}"; do
                if [[ -f "$file_pattern" ]]; then
                    log_info "发现残留服务文件: $file_pattern"
                    if sudo rm -f "$file_pattern"; then
                        log_success "已删除残留服务文件"
                        cleaned=true
                    fi
                fi
            done
            ;;

        "mac")
            local plist_file="$HOME/Library/LaunchAgents/com.autotranscription.client.plist"
            if [[ -f "$plist_file" ]]; then
                log_info "发现残留服务文件: $plist_file"
                if rm -f "$plist_file"; then
                    log_success "已删除残留服务文件"
                    cleaned=true
                fi
            fi
            ;;

        "windows")
            # 检查Windows服务残留
            if command -v nssm &> /dev/null; then
                if nssm list | grep -q "$SERVICE_NAME" 2>/dev/null; then
                    log_info "发现残留Windows服务"
                    if nssm remove "$SERVICE_NAME" confirm 2>/dev/null; then
                        log_success "已删除残留Windows服务"
                        cleaned=true
                    fi
                fi
            fi

            # 检查启动脚本残留
            local startup_script="$PROJECT_DIR\\scripts\\start_client_windows.bat"
            if [[ -f "$startup_script" ]]; then
                log_info "发现残留启动脚本: $startup_script"
                if rm -f "$startup_script"; then
                    log_success "已删除残留启动脚本"
                    cleaned=true
                fi
            fi
            ;;
    esac

    # 清理临时文件
    local temp_files=$(find /tmp -name "*autotranscription*" -user "$SERVICE_USER" 2>/dev/null || true)
    if [[ -n "$temp_files" ]]; then
        log_info "发现临时文件，正在清理..."
        echo "$temp_files" | xargs rm -f 2>/dev/null || true
        log_success "临时文件已清理"
        cleaned=true
    fi

    # 平台特定的清理
    case "$OS" in
        "linux")
            sudo systemctl daemon-reload 2>/dev/null || true
            sudo systemctl reset-failed "$SERVICE_NAME" 2>/dev/null || true
            ;;
    esac

    if [[ "$cleaned" == true ]]; then
        log_success "残留文件清理完成 ($OS)"
    else
        log_info "没有发现残留文件 ($OS)"
    fi
}

# 主函数
main() {
    # 切换到项目目录
    cd "$PROJECT_DIR"

    case "${1:-full}" in
        "full")
            full_uninstall
            ;;
        "service")
            service_uninstall
            ;;
        "clean")
            cleanup_residual_files
            ;;
        "status")
            show_current_status
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
trap 'log_error "卸载过程中发生错误"; exit 1' ERR

# 运行主函数
main "$@"