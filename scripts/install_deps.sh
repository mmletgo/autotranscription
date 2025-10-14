#!/bin/bash

# AutoTranscription 依赖安装脚本
# 支持系统: Ubuntu 20.04+, CentOS 7+, 其他Linux发行版
# GPU支持: NVIDIA CUDA (自动检测)

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# 检测操作系统
detect_os() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if command -v apt-get &> /dev/null; then
            OS="ubuntu"
            PKG_MANAGER="apt-get"
            PKG_UPDATE="sudo apt-get update"
            PKG_INSTALL="sudo apt-get install -y"
        elif command -v yum &> /dev/null; then
            OS="centos"
            PKG_MANAGER="yum"
            PKG_UPDATE="sudo yum update -y"
            PKG_INSTALL="sudo yum install -y"
        elif command -v dnf &> /dev/null; then
            OS="fedora"
            PKG_MANAGER="dnf"
            PKG_UPDATE="sudo dnf update -y"
            PKG_INSTALL="sudo dnf install -y"
        else
            log_error "不支持的Linux发行版"
            exit 1
        fi
    else
        log_error "不支持的操作系统: $OSTYPE"
        exit 1
    fi

    log_info "检测到操作系统: $OS"
}

# 检测Python环境
check_python() {
    log_info "检查Python环境..."

    if command -v python3 &> /dev/null; then
        PYTHON_VERSION=$(python3 --version | cut -d' ' -f2)
        PYTHON_MINOR_VERSION=$(echo $PYTHON_VERSION | cut -d'.' -f2)

        log_info "找到Python版本: $PYTHON_VERSION"

        if [[ $PYTHON_MINOR_VERSION -lt 8 ]]; then
            log_error "需要Python 3.8或更高版本，当前版本: $PYTHON_VERSION"
            exit 1
        fi

        PYTHON_CMD="python3"
    else
        log_error "未找到Python3，请先安装Python 3.8+"
        exit 1
    fi
}

# 检测CUDA环境
check_cuda() {
    log_info "检查CUDA环境..."

    if command -v nvidia-smi &> /dev/null; then
        GPU_AVAILABLE=true
        CUDA_VERSION=$(nvidia-smi | grep "CUDA Version" | awk '{print $9}' | cut -d'.' -f1,2)
        log_success "检测到NVIDIA GPU，驱动支持CUDA: $CUDA_VERSION"

        # 检查是否安装了CUDA toolkit
        if command -v nvcc &> /dev/null; then
            NVCC_VERSION=$(nvcc --version | grep "release" | awk '{print $6}' | cut -c2-)
            log_success "CUDA Toolkit已安装，版本: $NVCC_VERSION"
            CUDA_AVAILABLE=true
        else
            log_warning "未找到CUDA Toolkit，将自动安装"
            CUDA_AVAILABLE=false
            NEED_INSTALL_CUDA=true
        fi
    else
        log_warning "未检测到NVIDIA GPU，将使用CPU模式"
        GPU_AVAILABLE=false
        CUDA_AVAILABLE=false
        NEED_INSTALL_CUDA=false
    fi
}

# 检查磁盘空间
check_disk_space() {
    local required_gb=10
    local available_gb=$(df / | awk 'NR==2 {print int($4/1024/1024)}')

    if [[ $available_gb -lt $required_gb ]]; then
        log_warning "磁盘空间不足，需要至少 ${required_gb}GB，当前可用 ${available_gb}GB"
        log_info "CUDA Toolkit安装可能失败，建议清理磁盘空间"
        read -p "是否继续安装？[y/N]: " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "取消CUDA Toolkit安装"
            return 1
        fi
    else
        log_info "磁盘空间检查通过，可用 ${available_gb}GB"
    fi
}

# 安装CUDA Toolkit
install_cuda_toolkit() {
    if [[ "$NEED_INSTALL_CUDA" != true ]]; then
        return 0
    fi

    log_info "准备安装CUDA Toolkit..."
    log_warning "这是一个大型下载（约2-3GB），可能需要一些时间"

    # 检查磁盘空间
    if ! check_disk_space; then
        log_error "磁盘空间不足，无法安装CUDA Toolkit"
        return 1
    fi

    log_info "开始安装CUDA Toolkit..."

    case $OS in
        "ubuntu")
            install_cuda_ubuntu
            ;;
        "centos"|"fedora")
            install_cuda_rhel
            ;;
        *)
            log_error "不支持的CUDA安装操作系统: $OS"
            return 1
            ;;
    esac

    # 验证安装
    if command -v nvcc &> /dev/null; then
        NVCC_VERSION=$(nvcc --version | grep "release" | awk '{print $6}' | cut -c2-)
        log_success "CUDA Toolkit安装成功，版本: $NVCC_VERSION"
        CUDA_AVAILABLE=true
        NEED_INSTALL_CUDA=false
    else
        log_error "CUDA Toolkit安装失败"
        return 1
    fi
}

# 在Ubuntu上安装CUDA Toolkit
install_cuda_ubuntu() {
    log_info "在Ubuntu上安装CUDA Toolkit..."

    # 检测Ubuntu版本
    local ubuntu_version=$(lsb_release -rs 2>/dev/null || echo "22.04")
    log_info "检测到Ubuntu版本: $ubuntu_version"

    # 根据Ubuntu版本选择仓库
    local cuda_repo_version="ubuntu2204"
    case $ubuntu_version in
        "20.04"|"20.10"|"21.04"|"21.10")
            cuda_repo_version="ubuntu2004"
            ;;
        "22.04"|"22.10"|"23.04"|"23.10")
            cuda_repo_version="ubuntu2204"
            ;;
        "24.04"|"24.10")
            cuda_repo_version="ubuntu2404"
            ;;
        *)
            log_warning "未知的Ubuntu版本: $ubuntu_version，使用ubuntu2204仓库"
            cuda_repo_version="ubuntu2204"
            ;;
    esac

    # 添加NVIDIA CUDA仓库
    log_info "添加NVIDIA CUDA仓库 ($cuda_repo_version)..."
    if ! wget https://developer.download.nvidia.com/compute/cuda/repos/$cuda_repo_version/x86_64/cuda-keyring_1.1-1_all.deb; then
        log_error "无法下载CUDA仓库密钥包"
        return 1
    fi

    if ! $PKG_INSTALL ./cuda-keyring_1.1-1_all.deb; then
        log_error "无法安装CUDA仓库密钥包"
        rm -f cuda-keyring_1.1-1_all.deb
        return 1
    fi

    $PKG_UPDATE

    # 选择合适的CUDA版本
    case $CUDA_VERSION in
        "13.0"|"12.4"|"12.3"|"12.2"|"12.1")
            CUDA_PACKAGE_VERSION="12-4"
            ;;
        "12.0"|"11.8"|"11.7"|"11.6"|"11.5")
            CUDA_PACKAGE_VERSION="12-1"
            ;;
        *)
            CUDA_PACKAGE_VERSION="12-1"
            log_warning "未知的CUDA版本: $CUDA_VERSION，安装CUDA 12.1"
            ;;
    esac

    # 安装CUDA Toolkit
    log_info "安装CUDA Toolkit $CUDA_PACKAGE_VERSION..."
    $PKG_INSTALL cuda-toolkit-$CUDA_PACKAGE_VERSION

    # 清理下载的包
    rm -f cuda-keyring_1.1-1_all.deb

    # 设置环境变量
    echo 'export PATH=/usr/local/cuda/bin:$PATH' >> ~/.bashrc
    echo 'export LD_LIBRARY_PATH=/usr/local/cuda/lib64:$LD_LIBRARY_PATH' >> ~/.bashrc

    # 立即生效环境变量
    export PATH=/usr/local/cuda/bin:$PATH
    export LD_LIBRARY_PATH=/usr/local/cuda/lib64:$LD_LIBRARY_PATH
}

# 在RHEL/CentOS/Fedora上安装CUDA Toolkit
install_cuda_rhel() {
    log_info "在RHEL/CentOS/Fedora上安装CUDA Toolkit..."

    # 选择合适的CUDA版本
    case $CUDA_VERSION in
        "13.0"|"12.4"|"12.3"|"12.2"|"12.1")
            CUDA_REPO_VERSION="12.4.0-1"
            ;;
        "12.0"|"11.8"|"11.7"|"11.6"|"11.5")
            CUDA_REPO_VERSION="12.1.0-1"
            ;;
        *)
            CUDA_REPO_VERSION="12.1.0-1"
            log_warning "未知的CUDA版本: $CUDA_VERSION，安装CUDA 12.1"
            ;;
    esac

    if [[ "$OS" == "fedora" ]]; then
        # Fedora
        CUDA_REPO_RPM="cuda-repo-fedora$x86_64-$CUDA_REPO_VERSION.x86_64.rpm"
        wget https://developer.download.nvidia.com/compute/cuda/repos/fedora$x86_64/x86_64/$CUDA_REPO_RPM
        $PKG_INSTALL $CUDA_REPO_RPM
        $PKG_UPDATE
    else
        # CentOS/RHEL
        CUDA_REPO_RPM="cuda-repo-rhel$(rpm -E %rhel)-$CUDA_REPO_VERSION.x86_64.rpm"
        wget https://developer.download.nvidia.com/compute/cuda/repos/rhel$(rpm -E %rhel)/x86_64/$CUDA_REPO_RPM
        $PKG_INSTALL $CUDA_REPO_RPM
        $PKG_UPDATE
    fi

    # 安装CUDA Toolkit
    $PKG_INSTALL cuda-toolkit

    # 清理下载的包
    rm -f $CUDA_REPO_RPM

    # 设置环境变量
    echo 'export PATH=/usr/local/cuda/bin:$PATH' >> ~/.bashrc
    echo 'export LD_LIBRARY_PATH=/usr/local/cuda/lib64:$LD_LIBRARY_PATH' >> ~/.bashrc

    # 立即生效环境变量
    export PATH=/usr/local/cuda/bin:$PATH
    export LD_LIBRARY_PATH=/usr/local/cuda/lib64:$LD_LIBRARY_PATH
}

# 安装系统依赖
install_system_deps() {
    log_info "安装系统依赖（不包括Python包）..."

    $PKG_UPDATE

    case $OS in
        "ubuntu")
            $PKG_INSTALL \
                build-essential \
                curl \
                wget \
                git \
                gnupg2 \
                ca-certificates \
                software-properties-common
            ;;
        "centos"|"fedora")
            $PKG_INSTALL \
                gcc \
                gcc-c++ \
                make \
                curl \
                wget \
                git \
                gnupg2 \
                ca-certificates
            ;;
    esac

    log_success "系统依赖安装完成"
}

# 检查并安装Miniconda
install_miniconda() {
    log_info "检查Miniconda安装..."

    # 检查是否已安装conda
    if command -v conda &> /dev/null; then
        CONDA_VERSION=$(conda --version 2>/dev/null | cut -d' ' -f2)
        log_success "Conda已安装，版本: $CONDA_VERSION"

        # 检查是否已安装mamba
        if command -v mamba &> /dev/null; then
            MAMBA_VERSION=$(mamba --version 2>/dev/null | cut -d' ' -f2)
            log_success "Mamba已安装，版本: $MAMBA_VERSION"
            USE_MAMBA=true
        else
            log_info "Mamba未安装，将在conda环境创建后安装"
            USE_MAMBA=false
        fi
        return 0
    fi

    log_info "未找到Conda，开始安装Miniconda..."

    # 检测系统架构
    local arch=$(uname -m)
    local conda_arch="x86_64"
    if [[ "$arch" == "aarch64" ]]; then
        conda_arch="aarch64"
    elif [[ "$arch" == "arm64" ]]; then
        conda_arch="arm64"
    fi

    # 下载Miniconda安装脚本
    local miniconda_url="https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-${conda_arch}.sh"
    local installer_path="/tmp/miniconda.sh"

    log_info "下载Miniconda安装程序..."
    if ! wget -O "$installer_path" "$miniconda_url"; then
        log_error "无法下载Miniconda安装程序"
        return 1
    fi

    # 安装Miniconda
    log_info "安装Miniconda到用户目录..."
    chmod +x "$installer_path"
    bash "$installer_path" -b -p "$HOME/miniconda3"

    # 清理安装文件
    rm -f "$installer_path"

    # 初始化conda
    log_info "初始化Conda..."
    "$HOME/miniconda3/bin/conda" init bash

    # 添加到PATH
    echo 'export PATH="$HOME/miniconda3/bin:$PATH"' >> ~/.bashrc

    # 立即生效
    export PATH="$HOME/miniconda3/bin:$PATH"

    # 验证安装
    if command -v conda &> /dev/null; then
        log_success "Miniconda安装成功"
        USE_MAMBA=false
        return 0
    else
        log_error "Miniconda安装失败"
        return 1
    fi
}

# 创建Conda环境
create_conda_env() {
    log_info "创建Conda虚拟环境..."

    # 确保conda可用
    if ! command -v conda &> /dev/null; then
        log_error "Conda不可用，请先安装Miniconda"
        return 1
    fi

    local env_name="autotranscription"

    # 检查环境是否已存在
    if conda env list | grep -q "^$env_name "; then
        log_warning "Conda环境 '$env_name' 已存在，删除旧环境..."
        conda env remove -n "$env_name" -y
    fi

    # 创建新的conda环境
    log_info "创建Conda环境: $env_name"

    # 根据CUDA可用性选择Python版本和基础包
    if [[ "$CUDA_AVAILABLE" == true ]]; then
        log_info "使用GPU优化的配置创建环境"
        conda create -n "$env_name" python=3.10 -y
    else
        log_info "使用CPU配置创建环境"
        conda create -n "$env_name" python=3.10 -y
    fi

    # 激活环境
    log_info "激活Conda环境..."
    source "$(conda info --base)/etc/profile.d/conda.sh"
    conda activate "$env_name"
    # 安装Mamba
    install_mamba
    # # 升级conda和pip
    # conda update -n base -c defaults conda -y
    # pip install --upgrade pip setuptools wheel

    log_success "Conda环境创建完成"
}

# 安装Mamba (如果可用)
install_mamba() {
    log_info "检查并安装Mamba以加速conda包管理..."

    # 激活conda环境
    source "$(conda info --base)/etc/profile.d/conda.sh"
    conda activate autotranscription

    # 检查mamba是否已在环境中可用
    if command -v mamba &> /dev/null; then
        MAMBA_VERSION=$(mamba --version 2>/dev/null | cut -d' ' -f2)
        log_success "Mamba已在环境中可用，版本: $MAMBA_VERSION"
        USE_MAMBA=true
        return 0
    fi

    log_info "在conda环境中安装Mamba..."
    # 安装mamba到base环境
    conda install -n base -c conda-forge mamba -y

    # 重新初始化以确保mamba可用
    conda init bash

    # 再次检查mamba是否可用
    if command -v mamba &> /dev/null; then
        MAMBA_VERSION=$(mamba --version 2>/dev/null | cut -d' ' -f2)
        log_success "Mamba安装成功，版本: $MAMBA_VERSION"
        USE_MAMBA=true
        log_info "Mamba将显著加速包解析和安装过程"
    else
        log_warning "Mamba安装失败，将使用conda进行包管理"
        USE_MAMBA=false
    fi
}

# 安装完整系统依赖
install_python_deps() {
    log_info "安装完整系统依赖（使用pip + conda系统包）..."

    # 激活conda环境
    source "$(conda info --base)/etc/profile.d/conda.sh"
    conda activate autotranscription

    # 升级pip到最新版本
    log_info "升级pip..."
    pip install --upgrade pip setuptools wheel

    # 首先安装系统级依赖（通过conda）
    log_info "安装系统级依赖..."
    conda install -y \
        ffmpeg \
        libsndfile \
        portaudio \
        pkg-config \
        curl \
        wget \
        git || {
        log_warning "部分系统依赖安装失败，继续..."
    }

    # 安装基础科学计算包（优先conda，失败则pip）
    log_info "安装基础科学计算包..."
    conda install -y numpy scipy requests || {
        log_warning "conda安装部分包失败，使用pip..."
        pip install numpy scipy requests
    }

    # 安装Web服务依赖
    log_info "安装Web服务依赖..."
    pip install flask gunicorn gevent flask-cors

    # 根据CUDA可用性安装PyTorch
    if [[ "$CUDA_AVAILABLE" == true ]]; then
        log_info "安装CUDA版本的PyTorch..."
        pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121 || {
            log_warning "PyTorch CUDA版本安装失败，尝试CPU版本..."
            pip install torch torchvision torchaudio
        }
    else
        log_info "安装CPU版本的PyTorch..."
        pip install torch torchvision torchaudio
    fi

    # 安装核心应用包（使用pip确保兼容性）
    log_info "安装核心应用包..."

    # 服务端依赖
    pip install faster-whisper psutil

    # 客户端依赖
    pip install soundfile pyaudio pynput transitions pyperclip sounddevice

    # 中文处理
    pip install opencc-python-reimplemented

    # 可选GUI包（如果conda失败则跳过）
    log_info "尝试安装可选GUI包..."
    conda install -y pyqt pyside2 tk || {
        log_warning "GUI包安装失败，跳过（不影响核心功能）"
    }

    # 清理conda缓存
    log_info "清理conda缓存..."
    conda clean -a -y

    log_success "完整系统依赖安装完成"
    log_info "安装策略: conda系统包 + pip Python包 = 最佳兼容性"
}

# 仅安装客户端依赖
install_client_deps() {
    log_info "安装客户端依赖（轻量化安装）..."

    # 激活conda环境
    source "$(conda info --base)/etc/profile.d/conda.sh"
    conda activate autotranscription

    # 升级pip到最新版本
    log_info "升级pip..."
    pip install --upgrade pip setuptools wheel

    # 安装系统级依赖（通过conda）
    log_info "安装音频处理系统依赖..."
    conda install -y \
        ffmpeg \
        libsndfile \
        portaudio \
        pkg-config \
        curl \
        wget \
        git || {
        log_warning "部分系统依赖安装失败，继续..."
    }

    # 安装基础科学计算包
    log_info "安装基础依赖..."
    conda install -y numpy scipy requests || {
        log_warning "conda安装部分包失败，使用pip..."
        pip install numpy scipy requests
    }

    # 安装客户端核心依赖
    log_info "安装客户端核心依赖..."
    pip install soundfile pyaudio pynput transitions pyperclip sounddevice
    pip install opencc-python-reimplemented

    # 可选GUI包
    log_info "尝试安装可选GUI包..."
    conda install -y pyqt pyside2 tk || {
        log_warning "GUI包安装失败，跳过（不影响核心功能）"
    }

    # 清理conda缓存
    log_info "清理conda缓存..."
    conda clean -a -y

    log_success "客户端依赖安装完成"
    log_info "安装策略: 仅安装客户端运行所需依赖"
}

# 仅安装服务端依赖
install_server_deps() {
    log_info "安装服务端依赖（AI转写服务）..."

    # 激活conda环境
    source "$(conda info --base)/etc/profile.d/conda.sh"
    conda activate autotranscription

    # 升级pip到最新版本
    log_info "升级pip..."
    pip install --upgrade pip setuptools wheel

    # 根据CUDA可用性安装PyTorch
    if [[ "$CUDA_AVAILABLE" == true ]]; then
        log_info "安装CUDA版本的PyTorch..."
        pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121 || {
            log_warning "PyTorch CUDA版本安装失败，尝试CPU版本..."
            pip install torch torchvision torchaudio
        }
    else
        log_info "安装CPU版本的PyTorch..."
        pip install torch torchvision torchaudio
    fi

    # 安装Web服务依赖
    log_info "安装Web服务依赖..."
    pip install flask gunicorn gevent flask-cors

    # 安装服务端核心依赖
    log_info "安装服务端核心依赖..."
    pip install faster-whisper psutil

    # 清理conda缓存
    log_info "清理conda缓存..."
    conda clean -a -y

    log_success "服务端依赖安装完成"
    log_info "安装策略: 仅安装服务端运行所需依赖"
}

# 创建完整配置文件
create_config() {
    log_info "创建完整配置文件..."
    create_server_config
    create_client_config
}

# 仅创建服务端配置文件
create_server_config() {
    log_info "创建服务端配置文件..."

    # 确保config目录存在
    mkdir -p config

    # 创建服务器配置文件
    if [[ ! -f "config/server_config.json" ]]; then
        # 根据GPU可用性设置设备
        if [[ "$CUDA_AVAILABLE" == true ]]; then
            DEVICE="cuda"
            COMPUTE_TYPE="float16"
        else
            DEVICE="cpu"
            COMPUTE_TYPE="int8"
        fi

        cat > config/server_config.json << EOF
{
    "model_size": "large-v3",
    "device": "$DEVICE",
    "compute_type": "$COMPUTE_TYPE",
    "language": "zh",
    "initial_prompt": "以下是普通话的句子。",
    "network_mode": "lan",
    "host": "0.0.0.0",
    "port": 5000,
    "workers": 8,
    "max_concurrent_transcriptions": 16,
    "queue_size": 100,
    "timeout": 600,
    "log_level": "INFO"
}
EOF
        log_success "服务端配置文件创建完成"
    else
        log_info "服务端配置文件已存在，跳过创建"
    fi
}

# 仅创建客户端配置文件
create_client_config() {
    log_info "创建客户端配置文件..."

    # 确保config目录存在
    mkdir -p config

    # 创建客户端配置文件
    if [[ ! -f "config/client_config.json" ]]; then
        cat > config/client_config.json << EOF
{
    "server_url": "http://localhost:5000",
    "max_time": 30,
    "zh_convert": "none",
    "streaming": true,
    "key_combo": "<alt>",
    "sample_rate": 16000,
    "channels": 1
}
EOF
        log_success "客户端配置文件创建完成"
    else
        log_info "客户端配置文件已存在，跳过创建"
    fi
}

# 原始的创建配置文件函数（保持向后兼容）
create_config_original() {

    # 确保config目录存在
    mkdir -p config

    # 创建服务器配置文件
    if [[ ! -f "config/server_config.json" ]]; then
        log_info "创建服务器配置文件..."

        # 根据GPU可用性设置设备
        if [[ "$CUDA_AVAILABLE" == true ]]; then
            DEVICE="cuda"
            COMPUTE_TYPE="float16"
        else
            DEVICE="cpu"
            COMPUTE_TYPE="int8"
        fi

        cat > config/server_config.json << EOF
{
    "model_size": "large-v3",
    "device": "$DEVICE",
    "compute_type": "$COMPUTE_TYPE",
    "language": "zh",
    "initial_prompt": "以下是普通话的句子。",
    "network_mode": "lan",
    "host": "0.0.0.0",
    "port": 5000,
    "workers": 8,
    "max_concurrent_transcriptions": 16,
    "queue_size": 100,
    "timeout": 600,
    "log_level": "INFO",
    "_comments": {
        "model_size": "Model size: tiny, base, small, medium, large-v1, large-v2, large-v3",
        "device": "Device: cpu, cuda, auto",
        "compute_type": "Compute type: int8, float16, float32",
        "language": "Language: zh(Chinese), en(English), ja(Japanese), etc",
        "host": "Listen address: 0.0.0.0(LAN), 127.0.0.1(local only)",
        "port": "Port number",
        "network_mode": "Network mode: lan(LAN), internet(Internet)",
        "workers": "Gunicorn worker processes (recommended: 2-8 for GPU)",
        "max_concurrent_transcriptions": "Maximum concurrent transcription requests",
        "queue_size": "Request queue size for load balancing",
        "timeout": "Request timeout in seconds",
        "log_level": "Logging level: DEBUG, INFO, WARNING, ERROR"
    }
}
EOF
        log_success "服务器配置文件创建完成"
    fi

    # 创建客户端配置文件
    if [[ ! -f "config/client_config.json" ]]; then
        log_info "创建客户端配置文件..."
        cat > config/client_config.json << EOF
{
    "server_url": "http://localhost:5000",
    "max_time": 30,
    "zh_convert": "none",
    "streaming": true,
    "key_combo": "<alt>",
    "sample_rate": 16000,
    "channels": 1
}
EOF
        log_success "客户端配置文件创建完成"
    fi
}

# 创建日志目录
create_log_dir() {
    log_info "创建日志目录..."
    mkdir -p logs
    log_success "日志目录创建完成"
}

# 验证安装
verify_installation() {
    local install_mode="${1:-full}"

    log_info "验证安装..."

    # 激活conda环境
    source "$(conda info --base)/etc/profile.d/conda.sh" 2>/dev/null || source "$HOME/miniconda3/etc/profile.d/conda.sh" 2>/dev/null || source "$HOME/anaconda3/etc/profile.d/conda.sh" 2>/dev/null
    conda activate autotranscription

    # 显示环境信息
    log_info "Python版本: $(python --version)"
    log_info "Conda环境: $CONDA_DEFAULT_ENV"

    # 检查CUDA支持（仅在完整或服务端模式下）
    if [[ "$install_mode" == "full" ]] || [[ "$install_mode" == "server" ]]; then
        if [[ "$CUDA_AVAILABLE" == true ]]; then
            python3 -c "
import torch
print(f'PyTorch版本: {torch.__version__}')
print(f'CUDA可用: {torch.cuda.is_available()}')
if torch.cuda.is_available():
    print(f'CUDA设备数量: {torch.cuda.device_count()}')
    print(f'CUDA当前设备: {torch.cuda.current_device()}')
    print(f'CUDA设备名称: {torch.cuda.get_device_name()}')
"
        fi
    fi

    # 显示conda环境信息
    log_info "Conda环境包列表:"
    conda list | head -20

    # 根据安装模式选择要验证的模块
    case "$install_mode" in
        "full")
            modules_list=("flask" "flask_cors" "faster_whisper" "numpy" "gunicorn" "gevent" "torch" "soundfile" "psutil" "pyaudio" "pynput" "transitions" "pyperclip" "sounddevice")
            ;;
        "client")
            modules_list=("numpy" "soundfile" "pyaudio" "pynput" "transitions" "pyperclip" "sounddevice" "requests")
            ;;
        "server")
            modules_list=("flask" "flask_cors" "faster_whisper" "numpy" "gunicorn" "gevent" "torch" "psutil")
            ;;
    esac

    # 检查关键模块是否可以导入
    # 将bash数组转换为Python列表字符串
    python_modules=$(printf "'%s'," "${modules_list[@]}" | sed 's/,$//')

    python3 -c "
import sys
try:
    from importlib.metadata import distributions
except ImportError:
    # 兼容旧版本Python
    from pkg_resources import distributions

modules = [${python_modules}]

failed = []
success = []
conda_packages = []
pip_packages = []

print('检查模块导入情况...')
for module in modules:
    try:
        __import__(module)
        success.append(module)

        # 检查包的安装来源
        try:
            dist_found = False
            for dist in distributions():
                if dist.name.replace('-', '_').lower() == module.lower():
                    dist_found = True
                    # 检查是否为conda安装
                    if hasattr(dist, '_provider') and 'conda' in str(dist._provider).lower():
                        conda_packages.append(module)
                    else:
                        pip_packages.append(module)
                    break
            if not dist_found:
                pip_packages.append(module)
        except:
            pip_packages.append(module)

        print(f'✓ {module}')
    except ImportError as e:
        print(f'✗ {module}: {e}')
        failed.append(module)

print(f'\\n=== 安装总结 (${install_mode}模式) ===')
print(f'成功导入: {len(success)}/{len(modules)} 个模块')
print(f'Conda安装: {len(conda_packages)} 个')
print(f'Pip安装: {len(pip_packages)} 个')

if conda_packages:
    print(f'\\nConda安装的包: {conda_packages}')
if pip_packages:
    print(f'\\nPip安装的包: {pip_packages}')

if failed:
    print(f'\\n导入失败的模块: {failed}')
    sys.exit(1)
else:
    print('\\n🎉 所有模块导入成功!')
"

    if [[ $? -eq 0 ]]; then
        log_success "安装验证成功!"

        # 测试特定功能（仅在完整或服务端模式下测试faster-whisper）
        if [[ "$install_mode" == "full" ]] || [[ "$install_mode" == "server" ]]; then
            # 测试faster-whisper
            log_info "测试faster-whisper功能..."
            python3 -c "
try:
    from faster_whisper import WhisperModel
    print('✓ faster-whisper导入成功')

    # 检查模型是否可用
    import os
    cache_dir = os.path.expanduser('~/.cache/huggingface')
    if os.path.exists(cache_dir):
        print(f'✓ Hugging Face缓存目录: {cache_dir}')
    else:
        print('⚠ Hugging Face缓存目录不存在，首次运行时将自动创建')

except Exception as e:
    print(f'✗ faster-whisper测试失败: {e}')
    exit(1)
"
            if [[ $? -eq 0 ]]; then
                log_success "faster-whisper功能验证通过!"
            else
                log_error "faster-whisper功能验证失败!"
                exit 1
            fi
        fi

        # 测试特定功能（仅在完整或客户端模式下测试音频模块）
        if [[ "$install_mode" == "full" ]] || [[ "$install_mode" == "client" ]]; then
            # 测试音频模块
            log_info "测试音频处理模块..."
            python3 -c "
try:
    import soundfile as sf
    import sounddevice as sd
    print('✓ 音频处理模块导入成功')

    # 测试基本功能
    print('✓ soundfile版本:', sf.__version__)
    print('✓ sounddevice版本:', sd.__version__)

except Exception as e:
    print(f'✗ 音频处理模块测试失败: {e}')
    exit(1)
"
            if [[ $? -eq 0 ]]; then
                log_success "音频处理模块验证通过!"
            else
                log_warning "音频处理模块验证失败，可能影响录音功能"
            fi
        fi

    else
        log_error "安装验证失败!"
        exit 1
    fi
}

# 显示安装后信息
show_post_install_info() {
    local install_mode="$1"

    case "$install_mode" in
        "full")
            log_success "=== AutoTranscription 完整系统安装完成 (基于Conda) ==="
            echo
            echo "接下来的步骤:"
            echo "1. 激活Conda环境: conda activate autotranscription"
            echo "2. 启动高并发服务端: ./scripts/manage.sh server start"
            echo "3. 启动客户端: ./scripts/manage.sh client"
            echo "4. 实时监控: ./scripts/manage.sh server monitor"
            echo
            echo "环境信息:"
            echo "- Conda环境: autotranscription (完全隔离)"
            echo "- Python版本: $(conda run -n autotranscription python --version 2>/dev/null || echo '未知')"
            echo "- 包管理器: conda (系统库) + pip (Python包)"
            if [[ "$CUDA_AVAILABLE" == true ]]; then
                echo "- GPU加速: 已启用 (CUDA $CUDA_VERSION)"
                echo "- PyTorch: CUDA版本 (pip安装)"
            else
                echo "- GPU加速: 未启用 (CPU模式)"
                echo "- PyTorch: CPU版本 (pip安装)"
            fi
            echo
            echo "高并发配置:"
            echo "- 最大并发转写: 16个同时请求"
            echo "- 请求队列容量: 100个"
            echo "- Gunicorn工作进程: 8个"
            echo
            echo "配置文件位置:"
            echo "- 服务器配置: config/server_config.json (含高并发设置)"
            echo "- 客户端配置: config/client_config.json"
            echo
            echo "日志目录: logs/"
            echo
            echo "Conda环境管理:"
            echo "- 激活环境: conda activate autotranscription"
            echo "- 退出环境: conda deactivate"
            echo "- 查看环境: conda env list"
            echo "- 查看包列表: conda list -n autotranscription"
            echo "- 更新包: conda update -n autotranscription <package_name>"
            echo "- 删除环境: conda env remove -n autotranscription -y"
            echo
            echo "依赖来源:"
            echo "- 系统库: conda (ffmpeg, libsndfile, portaudio等)"
            echo "- Python包: pip (所有核心功能包)"
            echo "- 安装策略: 混合安装确保最佳兼容性"
            echo
            echo "常用管理命令:"
            echo "- 系统状态: ./scripts/manage.sh status"
            echo "- 服务健康检查: ./scripts/manage.sh server health"
            echo "- 查看服务端状态: ./scripts/manage.sh server status"
            echo
            echo "如需重新安装，请运行:"
            echo "conda env remove -n autotranscription -y"
            echo "./scripts/manage.sh install"
            echo
            echo "🚀 高并发语音转写系统已准备就绪!"
            ;;

        "client")
            log_success "=== AutoTranscription 客户端安装完成 (基于Conda) ==="
            echo
            echo "接下来的步骤:"
            echo "1. 激活Conda环境: conda activate autotranscription"
            echo "2. 启动客户端: ./scripts/manage.sh client"
            echo "3. 检查服务连接: ./scripts/start_client.sh check"
            echo
            echo "环境信息:"
            echo "- Conda环境: autotranscription (客户端)"
            echo "- Python版本: $(conda run -n autotranscription python --version 2>/dev/null || echo '未知')"
            echo "- 包管理器: conda (系统库) + pip (Python包)"
            echo
            echo "配置文件位置:"
            echo "- 客户端配置: config/client_config.json"
            echo
            echo "日志目录: logs/"
            echo
            echo "连接服务端:"
            echo "1. 确保服务端已启动"
            echo "2. 修改 config/client_config.json 中的 server_url"
            echo "3. 运行 ./scripts/manage.sh client"
            echo
            echo "客户端服务管理:"
            echo "- 安装为系统服务: ./scripts/manage.sh service install"
            echo "- 启用开机自启: ./scripts/manage.sh service enable"
            echo "- 查看服务状态: ./scripts/manage.sh service status"
            echo
            echo "Conda环境管理:"
            echo "- 激活环境: conda activate autotranscription"
            echo "- 退出环境: conda deactivate"
            echo "- 查看环境: conda env list"
            echo "- 删除环境: conda env remove -n autotranscription -y"
            echo
            echo "依赖来源:"
            echo "- 系统库: conda (ffmpeg, libsndfile, portaudio等)"
            echo "- Python包: pip (客户端核心功能包)"
            echo "- 安装策略: 轻量化客户端安装"
            echo
            echo "🎤 客户端已准备就绪，可以连接到服务端!"
            ;;

        "server")
            log_success "=== AutoTranscription 服务端安装完成 (基于Conda) ==="
            echo
            echo "接下来的步骤:"
            echo "1. 激活Conda环境: conda activate autotranscription"
            echo "2. 启动服务端: ./scripts/manage.sh server start"
            echo "3. 健康检查: ./scripts/manage.sh server health"
            echo "4. 实时监控: ./scripts/manage.sh server monitor"
            echo
            echo "环境信息:"
            echo "- Conda环境: autotranscription (服务端)"
            echo "- Python版本: $(conda run -n autotranscription python --version 2>/dev/null || echo '未知')"
            echo "- 包管理器: conda (系统库) + pip (Python包)"
            if [[ "$CUDA_AVAILABLE" == true ]]; then
                echo "- GPU加速: 已启用 (CUDA $CUDA_VERSION)"
                echo "- PyTorch: CUDA版本 (pip安装)"
            else
                echo "- GPU加速: 未启用 (CPU模式)"
                echo "- PyTorch: CPU版本 (pip安装)"
            fi
            echo
            echo "高并发配置:"
            echo "- 最大并发转写: 16个同时请求"
            echo "- 请求队列容量: 100个"
            echo "- Gunicorn工作进程: 8个"
            echo
            echo "配置文件位置:"
            echo "- 服务器配置: config/server_config.json (含高并发设置)"
            echo
            echo "日志目录: logs/"
            echo
            echo "API接口:"
            echo "- 健康检查: GET http://localhost:5000/api/health"
            echo "- 系统状态: GET http://localhost:5000/api/status"
            echo "- 语音转录: POST http://localhost:5000/api/transcribe"
            echo
            echo "常用管理命令:"
            echo "- 服务端状态: ./scripts/manage.sh server status"
            echo "- 服务端日志: ./scripts/manage.sh server logs"
            echo "- 健康检查: ./scripts/manage.sh server health"
            echo "- 实时监控: ./scripts/manage.sh server monitor"
            echo
            echo "Conda环境管理:"
            echo "- 激活环境: conda activate autotranscription"
            echo "- 退出环境: conda deactivate"
            echo "- 查看环境: conda env list"
            echo "- 删除环境: conda env remove -n autotranscription -y"
            echo
            echo "依赖来源:"
            echo "- 系统库: conda (ffmpeg, libsndfile等)"
            echo "- Python包: pip (服务端核心功能包)"
            echo "- 安装策略: 高并发服务端安装"
            echo
            echo "🚀 高并发AI转写服务已准备就绪!"
            ;;
    esac

    echo
    echo "通用命令:"
    echo "- 查看系统状态: ./scripts/manage.sh status"
    echo "- 查看帮助: ./scripts/manage.sh --help"
    echo "- 完全重置: ./scripts/manage.sh reset"
    echo
    echo "🎉 安装完成!"
}

# 显示帮助信息
show_help() {
    cat << EOF
AutoTranscription 依赖安装脚本

用法: $SCRIPT_NAME [模式]

模式:
    full            安装完整系统依赖 (默认)
    client          仅安装客户端依赖
    server          仅安装服务端依赖
    -h, --help      显示此帮助信息

示例:
    $SCRIPT_NAME                # 安装完整系统
    $SCRIPT_NAME full           # 安装完整系统
    $SCRIPT_NAME client         # 仅安装客户端
    $SCRIPT_NAME server         # 仅安装服务端

EOF
}

# 主函数
main() {
    # 解析命令行参数
    local install_mode="${1:-full}"

    case "$install_mode" in
        "full")
            log_info "开始安装AutoTranscription完整系统依赖..."
            ;;
        "client")
            log_info "开始安装客户端依赖..."
            ;;
        "server")
            log_info "开始安装服务端依赖..."
            ;;
        "-h"|"--help"|"help")
            show_help
            exit 0
            ;;
        *)
            log_error "未知安装模式: $install_mode"
            echo
            show_help
            exit 1
            ;;
    esac

    # 检测系统环境（完整安装需要）
    if [[ "$install_mode" == "full" ]] || [[ "$install_mode" == "server" ]]; then
        detect_os
        check_python
        check_cuda
        install_system_deps

        # 如果需要安装CUDA Toolkit，在conda环境创建前安装
        if [[ "$NEED_INSTALL_CUDA" == true ]]; then
            install_cuda_toolkit
        fi
    else
        # 客户端安装只需要基本检测
        detect_os
        check_python
    fi

    # 安装/配置Miniconda
    install_miniconda

    # 根据安装模式创建环境和安装依赖
    case "$install_mode" in
        "full")
            create_conda_env
            install_python_deps
            create_config
            ;;
        "client")
            create_conda_env
            install_client_deps
            create_client_config
            ;;
        "server")
            create_conda_env
            install_server_deps
            create_server_config
            ;;
    esac

    create_log_dir
    verify_installation "$install_mode"
    show_post_install_info "$install_mode"

    log_success "安装完成!"
}

# 错误处理
trap 'log_error "安装过程中发生错误，请检查日志"; exit 1' ERR

# 运行主函数
main "$@"