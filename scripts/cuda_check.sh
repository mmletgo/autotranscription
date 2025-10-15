#!/bin/bash

# CUDA 和 cuDNN 诊断脚本
# 用于检查 CUDA 配置是否正确，并测试 GPU 转写功能

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
    echo -e "${GREEN}[✓]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[✗]${NC} $1"
}

# 获取项目目录
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

# 显示标题
echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}   CUDA & cuDNN 诊断工具${NC}"
echo -e "${BLUE}================================================${NC}"
echo

# 1. 检查 nvidia-smi
log_info "步骤 1: 检查 NVIDIA GPU 驱动"
if command -v nvidia-smi &> /dev/null; then
    nvidia-smi --query-gpu=name,driver_version,memory.total --format=csv,noheader,nounits | while read line; do
        log_success "GPU 找到: $line"
    done

    CUDA_VERSION=$(nvidia-smi | grep "CUDA Version" | awk '{print $9}')
    if [ -n "$CUDA_VERSION" ]; then
        log_success "驱动支持 CUDA: $CUDA_VERSION"
    fi
else
    log_error "nvidia-smi 未找到，请安装 NVIDIA 驱动"
    exit 1
fi
echo

# 2. 检查 Conda 环境
log_info "步骤 2: 检查 Conda 环境"
if command -v conda &> /dev/null; then
    CONDA_VERSION=$(conda --version 2>&1 | cut -d' ' -f2)
    log_success "Conda 已安装: $CONDA_VERSION"

    # 检查 autotranscription 环境
    if conda env list | grep -q "^autotranscription "; then
        log_success "autotranscription 环境存在"

        # 激活环境
        source "$(conda info --base)/etc/profile.d/conda.sh"
        conda activate autotranscription

        log_success "已激活 autotranscription 环境"
    else
        log_error "autotranscription 环境不存在"
        log_info "请运行: ./scripts/install_deps.sh"
        exit 1
    fi
else
    log_error "Conda 未安装"
    log_info "请运行: ./scripts/install_deps.sh"
    exit 1
fi
echo

# 3. 检查 PyTorch CUDA 支持
log_info "步骤 3: 检查 PyTorch CUDA 支持"
python3 << 'EOF'
import sys
try:
    import torch
    print(f"✓ PyTorch 版本: {torch.__version__}")
    print(f"✓ CUDA 可用: {torch.cuda.is_available()}")

    if torch.cuda.is_available():
        print(f"✓ CUDA 设备数量: {torch.cuda.device_count()}")
        print(f"✓ CUDA 当前设备: {torch.cuda.current_device()}")
        print(f"✓ CUDA 设备名称: {torch.cuda.get_device_name(0)}")
        print(f"✓ cuDNN 版本: {torch.backends.cudnn.version()}")
        print(f"✓ cuDNN 可用: {torch.backends.cudnn.enabled}")
    else:
        print("✗ CUDA 不可用")
        sys.exit(1)
except Exception as e:
    print(f"✗ PyTorch 检查失败: {e}")
    sys.exit(1)
EOF

if [ $? -ne 0 ]; then
    log_error "PyTorch CUDA 支持检查失败"
    exit 1
fi
echo

# 4. 检查 cuDNN 库路径
log_info "步骤 4: 检查 cuDNN 库路径"
CUDNN_LIB_PATH="$CONDA_PREFIX/lib/python3.10/site-packages/nvidia/cudnn/lib"

if [ -d "$CUDNN_LIB_PATH" ]; then
    log_success "cuDNN 库目录存在: $CUDNN_LIB_PATH"

    # 列出 cuDNN 库文件
    CUDNN_FILES=$(ls -1 "$CUDNN_LIB_PATH"/libcudnn*.so* 2>/dev/null | wc -l)
    if [ "$CUDNN_FILES" -gt 0 ]; then
        log_success "找到 $CUDNN_FILES 个 cuDNN 库文件"

        # 显示前几个库文件
        log_info "库文件列表:"
        ls -1 "$CUDNN_LIB_PATH"/libcudnn*.so* 2>/dev/null | head -5 | while read file; do
            echo "  - $(basename $file)"
        done
    else
        log_error "cuDNN 库目录存在但没有库文件"
        exit 1
    fi
else
    log_error "cuDNN 库目录不存在: $CUDNN_LIB_PATH"
    log_info "请运行: ./scripts/install_deps.sh"
    exit 1
fi
echo

# 5. 测试 cuDNN 库加载
log_info "步骤 5: 测试 cuDNN 库加载"
export LD_LIBRARY_PATH="$CUDNN_LIB_PATH:$LD_LIBRARY_PATH"

python3 << 'EOF'
import sys
import os

# 显示 LD_LIBRARY_PATH
ld_path = os.environ.get('LD_LIBRARY_PATH', '')
if 'cudnn' in ld_path:
    print(f"✓ LD_LIBRARY_PATH 包含 cuDNN 路径")
else:
    print(f"✗ LD_LIBRARY_PATH 未设置 cuDNN 路径")

try:
    import torch

    # 尝试使用 CUDA
    if torch.cuda.is_available():
        # 创建一个简单的 tensor 并移动到 GPU
        x = torch.randn(100, 100).cuda()
        y = torch.randn(100, 100).cuda()
        z = torch.matmul(x, y)

        print(f"✓ CUDA tensor 操作成功")
        print(f"✓ cuDNN 库加载正常")

        # 清理
        del x, y, z
        torch.cuda.empty_cache()
    else:
        print("✗ CUDA 不可用")
        sys.exit(1)

except Exception as e:
    print(f"✗ cuDNN 库加载测试失败: {e}")
    import traceback
    traceback.print_exc()
    sys.exit(1)
EOF

if [ $? -ne 0 ]; then
    log_error "cuDNN 库加载测试失败"
    log_warning "这通常是由于 LD_LIBRARY_PATH 未正确设置导致的"
    log_info "解决方法: 启动脚本已自动配置库路径"
    exit 1
fi
echo

# 6. 测试 Whisper GPU 转写
log_info "步骤 6: 测试 Whisper GPU 转写功能"
log_warning "这将下载并加载 Whisper base 模型（约 150MB），可能需要一些时间..."

python3 << 'EOF'
import sys
import numpy as np

try:
    from faster_whisper import WhisperModel
    import torch

    print("✓ faster-whisper 导入成功")

    # 加载模型
    print("正在加载 Whisper base 模型...")
    model = WhisperModel('base', device='cuda', compute_type='float16')
    print("✓ Whisper 模型加载成功 (base + GPU + float16)")

    # 测试转写
    print("正在测试 GPU 转写...")
    test_audio = np.zeros(16000, dtype=np.float32)
    segments, info = model.transcribe(test_audio, language='zh')
    segment_list = list(segments)

    print(f"✓ GPU 转写测试成功")
    print(f"  - 检测语言: {info.language}")
    print(f"  - 语言概率: {info.language_probability:.2f}")
    print(f"  - 片段数量: {len(segment_list)}")

    # 清理
    del model
    torch.cuda.empty_cache()

    print("\n✓ 所有测试通过，GPU 转写功能正常！")

except Exception as e:
    print(f"\n✗ Whisper GPU 转写测试失败: {e}")
    import traceback
    traceback.print_exc()
    sys.exit(1)
EOF

if [ $? -eq 0 ]; then
    echo
    echo -e "${GREEN}================================================${NC}"
    echo -e "${GREEN}   ✓ CUDA 和 cuDNN 配置完全正常${NC}"
    echo -e "${GREEN}================================================${NC}"
    echo
    log_success "系统已准备就绪，可以启动服务端"
    echo
    echo "接下来的步骤:"
    echo "1. 启动服务端: ./scripts/manage.sh server start"
    echo "2. 检查健康状态: ./scripts/manage.sh server health"
    echo "3. 实时监控: ./scripts/manage.sh server monitor"
    echo
else
    echo
    echo -e "${RED}================================================${NC}"
    echo -e "${RED}   ✗ CUDA 配置存在问题${NC}"
    echo -e "${RED}================================================${NC}"
    echo
    log_error "请检查上述错误信息并修复问题"
    echo
    echo "常见解决方法:"
    echo "1. 重新安装依赖: ./scripts/install_deps.sh"
    echo "2. 检查 NVIDIA 驱动: nvidia-smi"
    echo "3. 检查错误日志: logs/transcription_server_error.log"
    echo
    exit 1
fi
