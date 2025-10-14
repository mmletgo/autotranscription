# 手动安装教程

本教程适用于需要手动安装 AutoTranscription 系统的用户，提供了详细的分步安装指南。

## 目录

- [系统要求](#系统要求)
- [安装步骤概览](#安装步骤概览)
- [详细安装步骤](#详细安装步骤)
  - [1. 安装 Miniconda](#1-安装-miniconda)
  - [2. 安装 CUDA Toolkit (GPU 模式)](#2-安装-cuda-toolkit-gpu-模式)
  - [3. 克隆项目](#3-克隆项目)
  - [4. 创建 Python 环境](#4-创建-python-环境)
  - [5. 安装服务端依赖](#5-安装服务端依赖)
  - [6. 安装客户端依赖](#6-安装客户端依赖)
  - [7. 配置系统](#7-配置系统)
  - [8. 验证安装](#8-验证安装)
- [手动启动](#手动启动)
- [故障排除](#故障排除)

## 系统要求

### 基础要求
- **操作系统**: Linux (Ubuntu 20.04+, CentOS 7+), macOS 10.15+, Windows 10+
- **内存**: 建议 16GB+ (高并发模式需要更多内存)
- **存储**: 至少 10GB 可用空间 (用于模型文件和日志)
- **网络**: 稳定的网络连接用于模型下载

### GPU 要求 (可选)
- **显卡**: NVIDIA GPU (支持 CUDA 的显卡)
- **显存**: 建议 8GB+ (large-v3 模型需要较多显存)
- **驱动**: NVIDIA 驱动版本 470.57.02 或更高

## 安装步骤概览

1. 安装 Miniconda (Python 环境管理)
2. 安装 CUDA Toolkit (仅 GPU 模式需要)
3. 克隆项目代码
4. 创建 Python 虚拟环境
5. 安装服务端依赖
6. 安装客户端依赖
7. 配置系统参数
8. 验证安装结果

## 详细安装步骤

### 1. 安装 Miniconda

Miniconda 是轻量级的 Anaconda 发行版，用于管理 Python 环境和依赖包。

#### Linux 系统
```bash
# 下载 Miniconda 安装脚本
wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh

# 运行安装脚本
bash Miniconda3-latest-Linux-x86_64.sh

# 按照提示操作：
# - 同意许可协议 (yes)
# - 确认安装位置 (默认 ~/miniconda3)
# - 初始化 conda (yes)

# 重新加载 shell 配置
source ~/.bashrc
```

#### macOS 系统
```bash
# 下载 Miniconda 安装脚本 (Intel 芯片)
wget https://repo.anaconda.com/miniconda/Miniconda3-latest-MacOSX-x86_64.sh

# 或者 Apple Silicon (M1/M2)
wget https://repo.anaconda.com/miniconda/Miniconda3-latest-MacOSX-arm64.sh

# 运行安装脚本
bash Miniconda3-latest-MacOSX-*.sh

# 按照提示操作并重新加载 shell
source ~/.zshrc  # 或 ~/.bashrc
```

#### Windows 系统
1. 访问 [Miniconda 官网](https://docs.conda.io/en/latest/miniconda.html)
2. 下载 Windows 版本的安装程序
3. 运行安装程序，按照向导完成安装
4. 确保 "Add Miniconda to PATH" 选项被勾选

#### 验证 Miniconda 安装
```bash
conda --version
# 应该显示类似: conda 23.x.x
```

### 2. 安装 CUDA Toolkit (GPU 模式)

如果您有 NVIDIA GPU 并希望使用 GPU 加速，需要安装 CUDA Toolkit。

#### 检查 NVIDIA 驱动
```bash
nvidia-smi
# 如果显示驱动信息，可以继续；如果报错，请先安装 NVIDIA 驱动
```

#### Linux 系统 (Ubuntu/Debian)
```bash
# 方法 1: 使用 conda-forge 安装 (推荐)
conda install -c conda-forge cudatoolkit=11.8

# 方法 2: 使用 NVIDIA 官方仓库
wget https://developer.download.nvidia.com/compute/cuda/11.8.0/local_installers/cuda_11.8.0_520.61.05_linux.run
sudo sh cuda_11.8.0_520.61.05_linux.run

# 按照提示操作，取消安装驱动选项 (如果已安装驱动)
```

#### CentOS/RHEL 系统
```bash
# 使用 conda-forge
conda install -c conda-forge cudatoolkit=11.8

# 或使用官方方法 (需要配置 NVIDIA 仓库)
# 详情参考: https://docs.nvidia.com/cuda/cuda-installation-guide-linux/index.html
```

#### Windows 系统
1. 访问 [CUDA Toolkit 官网](https://developer.nvidia.com/cuda-downloads)
2. 选择 Windows 版本和架构
3. 下载并运行安装程序
4. 按照向导完成安装

#### 验证 CUDA 安装
```bash
nvcc --version
# 应该显示 CUDA 版本信息

# Linux 检查 CUDA 库
ls /usr/local/cuda/lib64/libcudart.so
```

### 3. 克隆项目

```bash
# 克隆项目 (替换为实际的仓库地址)
git clone <repository-url>
cd autotranscription

# 或者下载并解压项目文件
# wget <project-url>.zip
# unzip autotranscription.zip
# cd autotranscription
```

### 4. 创建 Python 环境

```bash
# 创建专用 conda 环境
conda create -n autotranscription python=3.9 -y

# 激活环境
conda activate autotranscription

# 验证 Python 版本
python --version
# 应该显示: Python 3.9.x
```

### 5. 安装服务端依赖

```bash
# 进入服务端目录
cd server

# 使用 conda 安装主要依赖
conda install -c conda-forge flask numpy requests gunicorn -y

# 安装 PyTorch (根据您的 CUDA 版本选择)
# CUDA 11.8
conda install pytorch torchvision torchaudio pytorch-cuda=11.8 -c pytorch -c nvidia -y

# 或者 CPU 版本
# conda install pytorch torchvision torchaudio cpuonly -c pytorch -y

# 使用 pip 安装 conda 中没有的包
pip install faster-whisper flask-cors

# 验证安装
python -c "import torch; print(f'PyTorch: {torch.__version__}')"
python -c "import faster_whisper; print('Faster-Whisper installed successfully')"
```

### 6. 安装客户端依赖

```bash
# 返回项目根目录
cd ..

# 进入客户端目录
cd client

# 使用 conda 安装主要依赖
conda install -c conda-forge requests numpy soundfile sounddevice -y

# 使用 pip 安装 conda 中没有的包
pip install pynput transitions pyperclip opencc-python-reimplemented

# macOS 特殊处理 (如果需要 PyAudio)
if [[ "$(uname)" == "Darwin" ]]; then
    # 安装 PortAudio (PyAudio 的依赖)
    if command -v brew &> /dev/null; then
        brew install portaudio
    else
        echo "请先安装 Homebrew: https://brew.sh/"
    fi

    # 安装 PyAudio
    pip install pyaudio
else
    # Linux 系统
    sudo apt-get update
    sudo apt-get install -y portaudio19-dev python3-pyaudio
    # 或者使用 pip
    pip install pyaudio
fi

# Windows 用户通常可以直接安装 PyAudio
pip install pyaudio

# 验证安装
python -c "import pynput; print('pynput installed successfully')"
python -c "import sounddevice; print('sounddevice installed successfully')"
```

### 7. 配置系统

#### 创建必要目录
```bash
# 返回项目根目录
cd ..

# 创建日志目录
mkdir -p logs

# 设置权限
chmod 755 scripts/*.sh
```

#### 检查配置文件
```bash
# 检查服务端配置
cat config/server_config.json

# 检查客户端配置
cat config/client_config.json
```

#### 配置说明

**服务端配置** (`config/server_config.json`):
```json
{
    "model_size": "large-v3",
    "device": "cuda",        // 改为 "cpu" 如果没有 GPU
    "compute_type": "float16",
    "network_mode": "lan",
    "host": "0.0.0.0",
    "port": 5000,
    "workers": 8,
    "max_concurrent_transcriptions": 8,  // 根据 GPU 内存调整
    "queue_size": 100,
    "timeout": 600,
    "log_level": "INFO"
}
```

**客户端配置** (`config/client_config.json`):
```json
{
    "server_url": "http://localhost:5000",
    "max_time": 30,
    "zh_convert": "none",
    "streaming": true,
    "key_combo": "<alt>",
    "sample_rate": 16000,
    "channels": 1
}
```

### 8. 验证安装

#### 验证服务端
```bash
# 激活环境 (如果未激活)
conda activate autotranscription

# 测试服务端启动
cd server
python transcription_server.py --test

# 或者使用启动脚本
cd ..
./scripts/start_server.sh test
```

#### 验证客户端
```bash
# 测试客户端连接
./scripts/start_client.sh check

# 应该显示服务端连接成功的消息
```

## 手动启动

### 启动服务端

```bash
# 激活环境
conda activate autotranscription

# 方式 1: 直接运行 (前台)
cd server
python transcription_server.py

# 方式 2: 使用 Gunicorn (生产环境)
cd server
gunicorn --bind 0.0.0.0:5000 --workers 4 --timeout 600 transcription_server:app

# 方式 3: 使用启动脚本
./scripts/start_server.sh start
```

### 启动客户端

```bash
# 方式 1: 直接运行 (前台)
cd client
python client.py

# 方式 2: 使用启动脚本
./scripts/start_client.sh start

# 方式 3: 自定义参数
SERVER_URL=http://192.168.1.100:5000 ./scripts/start_client.sh start
```

## 故障排除

### 常见问题

1. **Conda 命令未找到**
   ```bash
   # 检查 conda 是否在 PATH 中
   which conda

   # 如果未找到，手动添加到 PATH
   echo 'export PATH="$HOME/miniconda3/bin:$PATH"' >> ~/.bashrc
   source ~/.bashrc
   ```

2. **CUDA 不可用**
   ```bash
   # 检查 CUDA 安装
   python -c "import torch; print(f'CUDA available: {torch.cuda.is_available()}')"

   # 如果不可用，检查驱动和 CUDA 版本兼容性
   nvidia-smi
   nvcc --version
   ```

3. **PyAudio 安装失败**
   ```bash
   # Linux 系统
   sudo apt-get install -y python3-dev portaudio19-dev
   pip install pyaudio

   # macOS 系统
   brew install portaudio
   pip install pyaudio

   # Windows 系统
   pip install pipwin
   pipwin install pyaudio
   ```

4. **模型下载失败**
   ```bash
   # 检查网络连接
   curl -I https://huggingface.co

   # 设置代理 (如果需要)
   export HF_ENDPOINT=https://hf-mirror.com
   ```

5. **权限问题**
   ```bash
   # 修复脚本权限
   chmod +x scripts/*.sh

   # 修复日志目录权限
   sudo chown -R $USER:$USER logs/
   ```

6. **热键监听失败**
   ```bash
   # Linux 系统可能需要辅助功能权限
   # 检查系统设置 -> 安全性与隐私 -> 辅助功能

   # macOS 系统可能需要屏幕录制权限
   # 系统偏好设置 -> 安全性与隐私 -> 隐私 -> 屏幕录制
   ```

### 日志查看

```bash
# 查看服务端日志
tail -f logs/transcription_server.log

# 查看客户端日志
tail -f logs/client.log

# 查看错误日志
tail -f logs/transcription_server_error.log
```

### 性能测试

```bash
# 测试 API 连接
curl http://localhost:5000/api/health

# 查看服务状态
curl http://localhost:5000/api/status

# 压力测试 (可选)
# 使用 Apache Bench 或其他工具测试并发性能
```

### 获取帮助

如果遇到无法解决的问题：

1. 查看项目 Issues 页面
2. 搜索相关错误信息
3. 提交新的 Issue，包含：
   - 操作系统和版本
   - Python 和 Conda 版本
   - 详细的错误信息
   - 执行的命令和输出

## 下一步

安装完成后，您可以：

1. 阅读 [主 README](../README.md) 了解系统功能
2. 配置客户端系统服务实现开机自启
3. 根据需要调整配置文件
4. 开始使用语音转文字功能