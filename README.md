# AutoTranscription 语音转文字系统

中文文档 | [English](README_EN.md)

## 核心价值

**加速 AI 对话效率 - 用语音代替打字**

本项目旨在解决一个实际痛点:**在与 AI 对话时,说话总是比打字快**。特别是在使用 Claude Code、ChatGPT、Cursor 等编程 AI 工具时,需要频繁地描述需求、解释问题、讨论方案。传统的打字输入不仅速度慢,而且容易打断思路。

通过热键快速录音 + AI 语音识别,您可以:
- **提升沟通效率**: 语音输入比打字快 3-5 倍
- **保持思维流畅**: 边想边说,不被打字速度限制
- **减少手部负担**: 长时间编程后,用语音代替打字可以缓解手部疲劳
- **专注核心问题**: 把时间用在思考和解决问题上,而不是打字上

---

基于 Faster Whisper 的高并发客户端-服务器架构语音转文字系统，支持 GPU 加速和生产环境部署。

## 特性

- 🎯 **高精度识别**: 基于 OpenAI Whisper large-v3 模型
- 🚀 **高并发处理**: 支持 8-16 个同时转写请求，100 个请求队列
- 🔥 **GPU 加速**: 支持 NVIDIA CUDA，显著提升转录速度
- 🏭 **生产就绪**: 包含进程管理、实时监控、健康检查
- 📊 **性能监控**: 实时队列状态、成功率统计、负载管理
- 🔥 **热键支持**: 全局快捷键快速启动录音
- 🌐 **网络支持**: 支持局域网和互联网访问
- 📝 **实时输出**: 支持流式转录结果
- 🇨🇳 **中文优化**: 针对中文语音识别优化
- 🧠 **智能内存管理**: 自动 GPU 内存清理和优化
- 🤖 **LLM 文本润色** ✨ **新功能**: 使用 OpenAI API 兼容的 LLM (ModelScope/OpenAI等) 自动润色和纠正识别文本，支持失败自动回退到原始文本

## 最佳实践

### 推荐部署架构

AutoTranscription 采用客户端-服务器架构，推荐以下部署方式以获得最佳性能和用户体验：

#### 🖥️ 服务端部署（高性能服务器）
```bash
# 推荐配置
- CPU: 8核+ (Intel i7/AMD Ryzen 7 或更高)
- GPU: NVIDIA RTX 3060/4060 或更高 (8GB+ 显存)
- 内存: 32GB+
- 存储: SSD 50GB+ 可用空间
- 网络: 千兆以太网

# 安装服务端
./scripts/manage.sh install-server
./scripts/manage.sh server start
```

**服务端优势**：
- 🚀 **GPU 加速**: 利用高性能 GPU 进行语音转写，速度提升 10-50 倍
- 🔄 **高并发处理**: 支持多个客户端同时连接，最多 16 个并发转写
- 💾 **集中管理**: 统一的模型文件和配置管理
- 🌐 **网络服务**: 可供局域网内任意设备访问

#### 💻 客户端部署（局域网设备）
```bash
# 支持的客户端系统
- Windows 10/11 (笔记本/台式机)
- macOS 10.15+ (iMac/MacBook/Mac Studio)
- Linux 发行版 (Ubuntu/CentOS/Arch 等)

# 安装客户端
./scripts/manage.sh install-client
./scripts/start_client.sh start
```

**客户端特点**：
- ⚡ **轻量级**: 只需安装音频处理和热键监听依赖
- 🎯 **即开即用**: 一键启动，热键触发录音
- 🌍 **跨平台**: 支持所有主流操作系统
- 📡 **网络连接**: 自动发现和连接局域网内的服务端

#### 🏠 家庭/办公室部署示例

```
┌─────────────────┐      ┌─────────────────┐      ┌─────────────────┐
│   笔记本电脑    │      │    台式机      │      │   服务器        │
│   (Windows)     │◄────►│   (macOS)       │◄────►│  (Linux + GPU) │
│                 │      │                 │      │                 │
│  客户端程序     │      │  客户端程序     │      │  服务端程序     │
│  热键录音       │      │  热键录音       │      │  AI 转写引擎    │
│  实时结果       │      │  实时结果       │      │  高并发处理     │
└─────────────────┘      └─────────────────┘      └─────────────────┘
         ▲                        ▲                        ▲
         │                        │                        │
         └────────────────────────┴────────────────────────┘
                          局域网 (WiFi/以太网)
```

#### 🏢 企业级部署

**多部门共享方案**：
- 一台高性能 GPU 服务器运行服务端
- 不同部门的员工电脑安装客户端
- 支持数十人同时使用语音转写服务
- 集中管理和维护，降低 IT 成本

**远程办公支持**：
```bash
# 服务端配置 (config/server_config.json)
{
    "network_mode": "internet",  // 启用互联网访问
    "host": "0.0.0.0",           // 监听所有网络接口
    "port": 5000                 // 可配置防火墙端口
}

# 客户端配置 (config/client_config.json)
{
    "server_url": "http://your-server-ip:5000"  // 指向服务器IP
}
```

### 安装模式选择

根据不同的部署场景，选择合适的安装模式：

#### 🖥️ **完整系统安装** (`./scripts/manage.sh install`)
- **适用场景**: 单机部署、开发环境、小团队使用
- **包含组件**: 服务端 + 客户端 + 所有依赖
- **优势**: 一键部署，功能完整
- **资源需求**: 较高 (需要GPU和更多内存)

#### 🚀 **仅服务端安装** (`./scripts/manage.sh install-server`)
- **适用场景**: GPU服务器、中央化部署、多用户共享
- **包含组件**: AI转写服务 + Web API + 高并发处理
- **优势**: 专注AI计算，资源利用率高
- **资源需求**: GPU推荐，大内存

#### 💻 **仅客户端安装** (`./scripts/manage.sh install-client`)
- **适用场景**: 用户设备、轻量级部署、连接远程服务端
- **包含组件**: 录音程序 + 热键支持 + 网络通信
- **优势**: 轻量化，资源占用少
- **资源需求**: 较低，无需GPU

#### 🏢 **企业级部署建议**
- **服务器**: 使用 `install-server` 模式部署在高性能GPU服务器
- **客户端**: 在员工电脑上使用 `install-client` 模式
- **网络**: 配置防火墙规则，确保服务端可访问
- **管理**: 使用系统服务功能实现开机自启

### 部署优势

#### 🎯 性能优化
- **集中计算**: 所有 AI 计算在高性能服务器上完成
- **资源共享**: 多用户共享 GPU 资源，提高利用率
- **缓存加速**: 模型文件只需加载一次，后续请求快速响应

#### 💰 成本效益
- **硬件节约**: 只需一台高性能服务器，客户端设备要求低
- **维护简化**: 集中更新和管理，无需在每台设备上维护复杂环境
- **扩展灵活**: 随时可以增加新的客户端设备

#### 🔒 安全可控
- **局域网部署**: 数据不出内网，保证信息安全
- **访问控制**: 可配置防火墙规则限制访问权限
- **日志审计**: 完整的转写记录和使用统计

## 🤖 LLM 文本润色功能

### 什么是 LLM 文本润色？

本项目现已支持使用 OpenAI API 兼容的 LLM 服务自动润色和纠正语音识别生成的文本！

✨ **特性**:
- 🔧 **自动纠正**: 修复识别错误、语法错误和标点符号
- 🎯 **多 LLM 支持**: ModelScope (推荐中文), OpenAI, Ollama, LM Studio 等
- 💾 **自动降级**: LLM 失败时自动使用原始文本，确保服务可靠性
- 🔄 **智能重试**: 指数退避重试策略，处理 API 限额和临时故障
- 🇨🇳 **中文优化**: 特别支持 ModelScope 的 Qwen 模型，适合中文处理

### 快速启用

1. **配置 LLM 服务** (编辑 `config/server_config.json`):
```json
{
  "llm": {
    "enabled": true,
    "api_url": "https://dashscope.aliyuncs.com/compatible-mode/v1",
    "api_key": "sk-your-api-key",
    "model": "qwen-turbo"
  }
}
```

2. **重启服务器**:
```bash
./scripts/manage.sh server restart
```

3. **验证状态**:
```bash
curl http://localhost:5000/api/llm/health
```

### 支持的 LLM 服务

| 服务 | 推荐用途 | 特点 |
|------|---------|------|
| **ModelScope** (推荐) | 中文处理 | 成本低，效果好，支持离线部署 |
| **OpenAI** | 通用 | 功能强大，支持 GPT-4 等高端模型 |
| **Ollama** | 本地部署 | 完全离线，无需 API key |
| **LM Studio** | 本地部署 | 界面友好，支持多种模型 |

### 详细文档

📚 **LLM 功能详细说明**:
- [LLM 快速开始](docs/LLM_QUICK_START.md) - 5 分钟快速配置

### 工作流程

```
音频输入
  ↓
Whisper 转写
  ↓
原始文本
  ↓
LLM 润色 (可选，支持失败回退)
  ↓
最终文本 (润色后或原始)
  ↓
返回给客户端
```

### API 响应示例

启用 LLM 后，转写 API 返回额外的信息：

```json
{
  "text": "润色后的文本（或原始文本如果 LLM 失败）",
  "original_text": "原始识别文本",
  "llm_used": true,
  "llm_error": null,
  "language": "zh",
  "duration": 5.2
}
```

## 快速开始

### 1. 系统要求

- **操作系统**: Linux (Ubuntu 20.04+, CentOS 7+), macOS 10.15+, Windows 10+
- **Python**: 3.8 或更高版本 (通过 Miniconda 管理)
- **GPU**: NVIDIA GPU (可选，支持 CPU 模式)
- **CUDA**: 11.8+ (GPU 模式需要，自动安装)
- **内存**: 建议 16GB+ (高并发模式需要更多内存)
- **网络**: 稳定的网络连接用于模型下载和 API 调用

### 2. 灵活安装选项

AutoTranscription 现在支持三种安装模式，根据您的需求选择合适的安装方式：

```bash
# 克隆项目
git clone <repository-url>
cd autotranscription
```

#### 安装选项

**完整系统安装** (推荐用于独立部署)
```bash
# 安装完整系统 (服务端 + 客户端)
./scripts/manage.sh install
# 或者
./scripts/install_deps.sh full
```

**仅服务端安装** (用于GPU服务器)
```bash
# 仅安装AI转写服务端
./scripts/manage.sh install-server
# 或者
./scripts/install_deps.sh server
```

**仅客户端安装** (用于用户设备)
```bash
# 仅安装客户端程序
./scripts/manage.sh install-client
# 或者
./scripts/install_deps.sh client
```

#### 直接使用安装脚本

您也可以直接使用 `install_deps.sh` 脚本：
```bash
# 完整安装
./scripts/install_deps.sh full

# 客户端安装
./scripts/install_deps.sh client

# 服务端安装
./scripts/install_deps.sh server

# 查看帮助
./scripts/install_deps.sh --help
```

> **注意**: 所有安装模式都会自动检测并安装 Miniconda 和 CUDA Toolkit（服务端需要），无需手动配置。

### Windows 环境安装指南

Windows 用户有两种安装方式,推荐使用 WSL 方式以获得最佳体验:

#### 方式一:使用 WSL (推荐)

WSL 允许您在 Windows 上运行完整的 Linux 环境,可以直接使用项目的 bash 脚本。

**1. 安装 WSL**
```powershell
# 在 PowerShell (管理员) 中运行
wsl --install -d Ubuntu-22.04
```

**2. 重启计算机并配置 Ubuntu**
- 设置用户名和密码
- 更新系统: `sudo apt update && sudo apt upgrade`

**3. 在 WSL 中安装项目**
```bash
# 克隆项目
git clone <repository-url>
cd autotranscription

# 安装系统依赖 (仅首次需要)
sudo apt install -y build-essential portaudio19-dev

# 选择安装模式
./scripts/manage.sh install         # 完整安装
# 或
./scripts/manage.sh install-client  # 仅客户端
# 或
./scripts/manage.sh install-server  # 仅服务端
```

**4. GPU 支持 (可选)**

如果您的 Windows 有 NVIDIA GPU 并希望使用 GPU 加速:
```bash
# 确保 Windows 上安装了最新的 NVIDIA 驱动
# WSL2 会自动访问 Windows 的 GPU

# 检查 GPU 可用性
nvidia-smi
```

**5. 启动服务**
```bash
# 启动完整系统
./scripts/manage.sh start

# 或分别启动
./scripts/manage.sh server start  # 启动服务端
./scripts/manage.sh client        # 启动客户端
```

**注意事项**:
- WSL 客户端的热键监听在 Linux 环境中工作,不能直接监听 Windows 全局热键
- 如需在 Windows 应用中使用,建议服务端运行在 WSL,客户端使用原生 Windows 安装
- WSL2 性能优于 WSL1,建议使用 WSL2

#### 方式二:原生 Windows 安装

如果不想使用 WSL,可以直接在 Windows 上安装:

**1. 安装 Miniconda**
- 下载: https://docs.conda.io/en/latest/miniconda.html
- 选择 Windows 64-bit 安装包
- 安装时勾选 "Add Miniconda3 to PATH"

**2. 安装 Git (如果尚未安装)**
- 下载: https://git-scm.com/download/win
- 使用默认设置安装

**3. 克隆项目**
```cmd
git clone <repository-url>
cd autotranscription
```

**4. 创建 Conda 环境**
```cmd
# 打开 Anaconda Prompt 或 PowerShell
conda create -n autotranscription python=3.10 -y
conda activate autotranscription
```

**5. 安装依赖**

**仅客户端安装** (推荐用于普通用户):
```cmd
# 安装客户端依赖
pip install -r client/requirements.txt

# 安装 PyAudio (Windows 需要特殊处理)
pip install pipwin
pipwin install pyaudio
```

**完整安装或仅服务端** (需要 GPU):
```cmd
# 安装 CUDA Toolkit (GPU 模式)
# 从 NVIDIA 官网下载并安装 CUDA 11.8+: https://developer.nvidia.com/cuda-downloads

# 安装服务端依赖
pip install -r server/requirements.txt

# 安装客户端依赖 (如果需要)
pip install -r client/requirements.txt
pip install pipwin
pipwin install pyaudio
```

**6. 配置文件**

复制配置文件模板 (如果不存在):
```cmd
# PowerShell
if (!(Test-Path "config\server_config.json")) {
    Copy-Item "config\server_config.example.json" "config\server_config.json"
}
if (!(Test-Path "config\client_config.json")) {
    Copy-Item "config\client_config.example.json" "config\client_config.json"
}
```

或手动复制 `config/*.example.json` 文件,去掉 `.example` 后缀。

**7. 启动服务**

**启动服务端**:
```cmd
conda activate autotranscription
python server/transcription_server.py
```

**启动客户端** (新开一个终端):
```cmd
conda activate autotranscription
python client/client.py
```

**8. Windows 防火墙配置**

首次运行时,Windows 防火墙可能会询问是否允许网络访问,请选择"允许访问"。

如需手动配置:
```powershell
# PowerShell (管理员)
New-NetFirewallRule -DisplayName "AutoTranscription Server" -Direction Inbound -Protocol TCP -LocalPort 5000 -Action Allow
```

#### 使用 Windows 管理脚本 (推荐)

为了简化 Windows 环境的管理,我们提供了完整的批处理脚本,类似于 Linux/macOS 的 bash 脚本:

**主管理脚本** (`scripts\windows\manage.bat`):
```cmd
REM 系统安装
scripts\windows\manage.bat install         # 安装完整系统依赖
scripts\windows\manage.bat install-client  # 仅安装客户端依赖
scripts\windows\manage.bat install-server  # 仅安装服务端依赖

REM 系统管理
scripts\windows\manage.bat start           # 启动完整系统
scripts\windows\manage.bat stop            # 停止系统
scripts\windows\manage.bat restart         # 重启系统
scripts\windows\manage.bat status          # 查看系统状态

REM 服务端管理
scripts\windows\manage.bat server start    # 启动服务端
scripts\windows\manage.bat server stop     # 停止服务端
scripts\windows\manage.bat server status   # 查看服务端状态
scripts\windows\manage.bat server logs     # 查看服务端日志
scripts\windows\manage.bat server health   # 健康检查

REM 客户端管理
scripts\windows\manage.bat client          # 启动客户端

REM 系统维护
scripts\windows\manage.bat clean           # 清理系统 (保留配置)
scripts\windows\manage.bat reset           # 完全重置系统
```

**依赖安装脚本** (`scripts\windows\install_deps.bat`):
```cmd
REM 直接使用安装脚本
scripts\windows\install_deps.bat full      # 安装完整系统
scripts\windows\install_deps.bat client    # 仅安装客户端
scripts\windows\install_deps.bat server    # 仅安装服务端
scripts\windows\install_deps.bat --help    # 查看帮助信息
```

**服务端脚本** (`scripts\windows\start_server.bat`):
```cmd
scripts\windows\start_server.bat start     # 启动服务端
scripts\windows\start_server.bat stop      # 停止服务端
scripts\windows\start_server.bat restart   # 重启服务端
scripts\windows\start_server.bat status    # 查看状态
scripts\windows\start_server.bat logs      # 查看日志
scripts\windows\start_server.bat health    # 健康检查
scripts\windows\start_server.bat config    # 显示配置
```

**客户端脚本** (`scripts\windows\start_client.bat`):
```cmd
REM 基本使用
scripts\windows\start_client.bat start     # 启动客户端
scripts\windows\start_client.bat check     # 检查服务连接
scripts\windows\start_client.bat config    # 显示配置

REM 环境变量覆盖
set SERVER_URL=http://192.168.1.100:5000
scripts\windows\start_client.bat start
```

**音频设备测试脚本** (`scripts\windows\test_audio.bat`):
```cmd
REM 测试音频设备
scripts\windows\test_audio.bat             # 测试音频输出设备
```

该脚本用于测试和配置Windows环境下的音频输出设备:
- 自动检测并激活Conda环境
- 列出所有可用的音频输出设备
- 依次测试每个设备的播放效果
- 帮助找到能正常播放提示音的设备ID
- 提供配置建议和说明

**诊断和服务管理脚本**:
```cmd
REM CUDA环境诊断
scripts\windows\cuda_check.bat             # 诊断CUDA和GPU配置

REM 客户端连接诊断
scripts\windows\diagnose_client_connection.bat          # 诊断客户端与服务端的连接问题
scripts\windows\diagnose_client_connection.bat <server_ip> <port>  # 指定服务器IP和端口

REM 客户端服务管理 (使用NSSM)
scripts\windows\install_client_service.bat install      # 安装客户端为Windows服务
scripts\windows\install_client_service.bat uninstall    # 卸载客户端服务
scripts\windows\install_client_service.bat status       # 查看服务状态
scripts\windows\install_client_service.bat enable       # 启用开机自启
scripts\windows\install_client_service.bat disable      # 禁用开机自启
scripts\windows\install_client_service.bat start        # 启动服务
scripts\windows\install_client_service.bat stop         # 停止服务
scripts\windows\install_client_service.bat restart      # 重启服务

REM 客户端服务卸载 (高级选项)
scripts\windows\uninstall_client_service.bat full       # 完全卸载(删除服务、配置和日志)
scripts\windows\uninstall_client_service.bat service    # 仅卸载服务(保留配置和日志)
scripts\windows\uninstall_client_service.bat clean      # 清理残留文件
scripts\windows\uninstall_client_service.bat status     # 查看卸载前状态
```

**诊断脚本说明**:
- `cuda_check.bat`: 检查NVIDIA驱动、CUDA、PyTorch和Whisper GPU功能
- `diagnose_client_connection.bat`: 测试网络连通性、端口可达性、HTTP API连接

**服务管理说明**:
- Windows服务管理使用NSSM (Non-Sucking Service Manager)
- 需要管理员权限
- 安装NSSM: 从 https://nssm.cc/download 下载或使用 `choco install nssm`
- 服务日志位置: `logs\client_service.log`

**使用示例**:

1. **一键安装完整系统**:
```cmd
REM 在项目根目录打开 CMD 或 PowerShell
scripts\windows\manage.bat install
```

2. **启动系统**:
```cmd
scripts\windows\manage.bat start
```

3. **查看系统状态**:
```cmd
scripts\windows\manage.bat status
```

4. **仅安装和使用客户端**:
```cmd
REM 安装客户端依赖
scripts\windows\manage.bat install-client

REM 配置服务端地址 (编辑 config\client_config.json)
REM "server_url": "http://192.168.1.100:5000"

REM 启动客户端
scripts\windows\manage.bat client
```

**脚本特点**:
- ✅ 自动检测和配置 Conda 环境
- ✅ 自动检测 CUDA 和 GPU
- ✅ 智能依赖安装 (使用 pipwin 处理 PyAudio)
- ✅ 完整的进程管理 (启动/停止/重启/状态)
- ✅ 日志管理和查看
- ✅ 健康检查和诊断
- ✅ 与 Linux/macOS 脚本功能一致

#### Windows 客户端服务 (开机自启)

Windows 客户端可以使用 NSSM 注册为系统服务:

**1. 下载 NSSM**
- 下载: https://nssm.cc/download
- 解压到 `C:\Tools\nssm` 或任意目录
- 将路径添加到系统 PATH

**2. 安装服务**
```cmd
# 打开 CMD (管理员)
cd C:\path\to\autotranscription

# 注册服务
nssm install AutoTranscription-Client "%USERPROFILE%\miniconda3\envs\autotranscription\python.exe" "client\client.py"

# 设置工作目录
nssm set AutoTranscription-Client AppDirectory "C:\path\to\autotranscription"

# 启动服务
nssm start AutoTranscription-Client
```

**3. 管理服务**
```cmd
# 查看状态
nssm status AutoTranscription-Client

# 停止服务
nssm stop AutoTranscription-Client

# 重启服务
nssm restart AutoTranscription-Client

# 卸载服务
nssm remove AutoTranscription-Client confirm
```

#### Windows 常见问题

**1. 麦克风无法录音**

如果在Windows上遇到麦克风无法录音的问题(录音能量为0,转写返回空结果),请参考详细的排查指南:

📖 **[Windows麦克风问题排查指南](docs/troubleshooting_microphone_windows.md)**

该指南涵盖:
- Windows隐私设置检查
- 系统级麦克风测试
- Realtek音频管理器配置
- 音频设备诊断工具使用
- 驱动程序问题排查

**2. PyAudio 安装失败**

PyAudio 是客户端录音的核心组件,Windows 安装可能会遇到问题。我们提供了多种解决方案:

```cmd
# 方法1: 使用专用安装脚本 (推荐)
conda activate autotranscription
scripts\windows\install_pyaudio.bat

# 方法2: 使用 conda-forge (最可靠)
conda activate autotranscription
conda install -c conda-forge pyaudio

# 方法3: 手动下载预编译 wheel 文件
# 访问 https://github.com/intxcc/pyaudio_portaudio/releases
# 下载对应 Python 版本的 .whl 文件
pip install PyAudio-0.2.14-cp310-cp310-win_amd64.whl
```

**详细信息**: 请参阅 [PyAudio Windows 安装指南](docs/pyaudio_installation_windows.md)

**2. CUDA 不可用**
```cmd
# 检查 CUDA 安装
nvcc --version

# 检查 GPU
nvidia-smi

# 如果没有 GPU,编辑 config/server_config.json:
# "device": "cpu"
```

**3. 热键不工作**
- 确保以管理员权限运行客户端
- 检查是否有其他程序占用了相同的热键
- 尝试更改 `config/client_config.json` 中的 `key_combo`

**4. Windows 快捷键需要双击**
- 在 Windows 系统上,由于 `pynput` 库的热键监听机制,快捷键需要 **连按两次** 才能触发操作
- 这是已知的行为特性,不是故障
- **操作方式**:
  - 连按两次快捷键 → 开始录音
  - 连按两次快捷键 → 停止录音
- 如果希望改善体验,可以尝试使用组合键(如 `<ctrl>+<alt>+a`)代替单键

**5. 模块导入错误**
```cmd
# 确保激活了正确的 conda 环境
conda activate autotranscription

# 重新安装依赖
pip install -r client/requirements.txt --force-reinstall
```

**6. 编码问题**
- 确保所有配置文件使用 UTF-8 编码
- PowerShell 中可以设置: `[Console]::OutputEncoding = [System.Text.Encoding]::UTF8`

#### Windows 性能建议

- **客户端**: 可以在任何 Windows 设备上运行,资源占用低
- **服务端**: 建议部署在有 NVIDIA GPU 的 Windows 工作站或服务器上
- **混合部署**: 服务端在 WSL 或 Linux 服务器,客户端使用原生 Windows
- **网络**: 确保服务端和客户端在同一局域网,或配置正确的网络路由

### 手动安装

如果自动安装脚本遇到问题，或者您希望了解安装过程，请参考 [手动安装教程](docs/MANUAL_INSTALL.md) 获取详细的分步安装指南。

### 3. 启动系统

```bash
# 启动完整系统
./scripts/manage.sh start

# 或者分别启动
./scripts/manage.sh server start  # 启动服务端
./scripts/manage.sh client        # 启动客户端
```

### 4. 使用客户端

启动客户端后，使用快捷键 `Alt` 开始录音，再次按下停止录音并获取转录结果。

## 详细使用

### 管理脚本 (`./scripts/manage.sh`)

```bash
# 系统安装
./scripts/manage.sh install         # 安装完整系统依赖
./scripts/manage.sh install-client  # 仅安装客户端依赖
./scripts/manage.sh install-server  # 仅安装服务端依赖

# 系统管理
./scripts/manage.sh start           # 启动完整系统
./scripts/manage.sh stop            # 停止系统
./scripts/manage.sh restart         # 重启系统
./scripts/manage.sh status          # 查看系统状态

# 服务端管理
./scripts/manage.sh server start     # 启动高并发服务端
./scripts/manage.sh server stop      # 停止服务端
./scripts/manage.sh server restart   # 重启服务端
./scripts/manage.sh server status    # 查看服务端状态
./scripts/manage.sh server logs      # 查看服务端日志
./scripts/manage.sh server health    # 健康检查
./scripts/manage.sh server monitor   # 实时并发监控

# 客户端
./scripts/manage.sh client          # 启动客户端

# 客户端服务管理 (跨平台)
./scripts/manage.sh service install   # 安装客户端为系统服务
./scripts/manage.sh service enable    # 启用开机自启
./scripts/manage.sh service start     # 启动客户端服务
./scripts/manage.sh service stop      # 停止客户端服务
./scripts/manage.sh service status    # 查看服务状态

# 系统维护
./scripts/manage.sh clean           # 清理系统 (保留配置)
./scripts/manage.sh reset           # 完全重置系统 (删除所有数据)
```

### 依赖安装脚本 (`./scripts/install_deps.sh`)

```bash
# 直接使用安装脚本 (无需通过manage.sh)
./scripts/install_deps.sh full       # 安装完整系统
./scripts/install_deps.sh client     # 仅安装客户端
./scripts/install_deps.sh server     # 仅安装服务端
./scripts/install_deps.sh --help     # 查看帮助信息
```

### 服务端脚本 (`./scripts/start_server.sh`)

```bash
./scripts/start_server.sh start     # 启动高并发服务端
./scripts/start_server.sh stop      # 停止服务端
./scripts/start_server.sh restart   # 重启服务端
./scripts/start_server.sh status    # 查看状态
./scripts/start_server.sh logs      # 查看日志
./scripts/start_server.sh health    # 健康检查
./scripts/start_server.sh monitor   # 实时并发监控
./scripts/start_server.sh config    # 显示配置
```

### 客户端脚本 (`./scripts/start_client.sh`)

```bash
# 基本使用
./scripts/start_client.sh start     # 启动客户端
./scripts/start_client.sh check     # 检查服务连接
./scripts/start_client.sh config    # 显示配置

# 环境变量覆盖
SERVER_URL=http://192.168.1.100:5000 ./scripts/start_client.sh start
HOTKEY="<ctrl>+<alt>+a" ./scripts/start_client.sh start
```

## 客户端系统服务 (跨平台支持)

AutoTranscription 支持将客户端注册为系统服务，实现开机自启和后台运行。

### 支持的平台

- **Linux**: 使用 systemd 服务管理
- **macOS**: 使用 launchd 服务管理
- **Windows**: 使用 NSSM (Non-Sucking Service Manager)

### 客户端服务管理

#### 安装服务
```bash
# 安装客户端服务 (自动检测操作系统)
./scripts/install_client_service.sh install

# 启用开机自启
./scripts/install_client_service.sh enable

# 启动服务
./scripts/install_client_service.sh start

# 查看服务状态
./scripts/install_client_service.sh status

# 查看服务日志
./scripts/install_client_service.sh logs

# 停止服务
./scripts/install_client_service.sh stop

# 重启服务
./scripts/install_client_service.sh restart
```

#### 卸载服务
```bash
# 完全卸载 (删除服务、配置和日志)
./scripts/uninstall_client_service.sh full

# 仅卸载服务 (保留配置和日志)
./scripts/uninstall_client_service.sh service

# 清理残留文件
./scripts/uninstall_client_service.sh clean

# 查看卸载前状态
./scripts/uninstall_client_service.sh status
```

#### 服务特性

**客户端服务特性**:
- **开机自启**: 系统启动后自动运行客户端
- **自动重启**: 服务异常退出时自动重启
- **日志管理**: 统一的日志输出和管理
- **安全设置**: 限制权限，保护系统安全
- **环境隔离**: 使用 conda 环境运行
- **跨平台支持**: Linux、macOS、Windows 统一命令

**平台特定说明**:

| 平台 | 服务管理器 | 服务文件位置 | 启动方式 |
|------|------------|--------------|----------|
| Linux | systemd | `/etc/systemd/system/autotranscription-client.service` | `systemctl` |
| macOS | launchd | `~/Library/LaunchAgents/com.autotranscription.client.plist` | `launchctl` |
| Windows | NSSM | Windows 服务注册表 | `nssm` |

#### 故障排除

**常见问题**:

1. **服务启动失败**
   ```bash
   # 检查服务状态
   ./scripts/install_client_service.sh status

   # Linux 查看详细日志
   sudo journalctl -u autotranscription-client -n 50
   ```

2. **权限问题**
   ```bash
   # 确保脚本有执行权限
   chmod +x scripts/install_client_service.sh
   chmod +x scripts/uninstall_client_service.sh
   chmod +x scripts/start_client.sh
   ```

3. **环境问题**
   ```bash
   # 检查 conda 环境
   conda env list

   # 检查客户端配置
   ./scripts/start_client.sh check
   ```

4. **热键冲突**
   - 检查客户端配置文件中的热键设置
   - 确保没有其他程序占用相同热键

**手动调试**:
```bash
# 激活 conda 环境
conda activate autotranscription

# 手动运行客户端
./scripts/start_client.sh start

# 查看实时日志
tail -f logs/client.log
```

**日志位置**:
- **服务日志**: `logs/client_service.log`
- **Linux 系统日志**: `sudo journalctl -u autotranscription-client`
- **客户端日志**: `logs/client.log`

## 配置文件

### 服务端配置 (`config/server_config.json`)

```json
{
    "model_size": "large-v3",              // 模型大小: tiny/base/small/medium/large-v3
    "device": "cuda",                     // 设备: cpu/cuda/auto
    "compute_type": "float16",            // 计算精度: int8/float16/float32
    "network_mode": "lan",                // 网络模式: lan/internet
    "host": "0.0.0.0",                   // 监听地址
    "port": 5000,                        // 监听端口
    "workers": 8,                        // Gunicorn 工作进程数
    "max_concurrent_transcriptions": 16,  // 最大并发转写数
    "queue_size": 100,                   // 请求队列大小
    "timeout": 600,                      // 请求超时时间(秒)
    "log_level": "INFO"                  // 日志级别
}
```

**高并发配置说明**:
- `max_concurrent_transcriptions`: 同时处理的最大转写请求数
- `queue_size`: 请求队列容量，满载时返回 503 错误
- `workers`: Gunicorn 工作进程数，**推荐根据 GPU 显存配置**：
  - **6GB 显存**: 建议 2-4 个 workers (如 RTX 3060 6GB)
  - **8GB 显存**: 建议 4-6 个 workers (如 RTX 3060Ti, RTX 3070, RTX 4060)
  - **10-12GB 显存**: 建议 6-8 个 workers (如 RTX 3080, RTX 3080Ti, RTX 4070)
  - **16GB+ 显存**: 建议 8-12 个 workers (如 RTX 4080, RTX 4090, A100)
  - **24GB+ 显存**: 建议 12-16 个 workers (如 RTX 4090, A5000, A6000)

  > **注意**: 每个 worker 在 GPU 模式下会消耗约 1.5-2GB 显存 (large-v3 模型)。建议留出 2-3GB 显存余量以保证系统稳定性。同时也要考虑 CPU 核心数，workers 数量不应超过 CPU 核心数 × 2。

### 客户端配置 (`config/client_config.json`)

```json
{
    "server_url": "http://localhost:5000",  // 服务端地址
    "max_time": 30,                         // 最大录音时长(秒)
    "zh_convert": "none",                   // 中文转换: none/t2s/s2t
    "streaming": true,                      // 流式输出
    "key_combo": "<alt>",                   // 快捷键组合
    "sample_rate": 16000,                   // 采样率
    "channels": 1,                          // 声道数
    "audio_device": null,                   // 音频输出设备ID (null=默认)
    "enable_beep": false                    // 启用提示音
}
```

### 音频设备配置

客户端支持在录音开始/结束时播放提示音。由于不同系统的音频设备配置各异，可能需要手动配置音频输出设备。

#### 测试和配置音频设备

为了确保快捷键按下时能正常播放提示音，您需要先确定正确的音频设备配置：

1. **运行音频设备测试脚本**
   ```bash
   ./scripts/test_audio.sh
   ```

   该脚本会帮助您：
   - 列出所有可用的音频输出设备
   - 依次测试每个设备的播放效果
   - 找到能正常播放提示音的设备ID
   - 提供配置建议和说明

2. **测试流程**
   - 脚本会列出所有可用的音频输出设备
   - 依次播放测试音到每个设备
   - 当您听到声音时，输入 `y` 确认
   - 输入 `n` 跳过当前设备
   - 输入 `r` 重新播放当前设备的测试音

3. **自动配置**
   - 找到工作的设备后，脚本会自动显示配置方法
   - 您可以直接编辑 `config/client_config.json` 应用配置

4. **手动配置示例**
   ```json
   {
       "audio_device": 5,      // 设置为工作的设备ID
       "enable_beep": true     // 启用提示音
   }
   ```

5. **禁用提示音**

   如果不需要提示音功能，可以在配置中禁用：
   ```json
   {
       "enable_beep": false    // 禁用提示音（默认）
   }
   ```

#### 命令行选项

也可以通过命令行参数指定音频设备：

```bash
# 列出所有音频输出设备
python3 client/client.py --list-audio-devices

# 使用指定的音频设备启动
python3 client/client.py --audio-device 5

# 启用提示音
python3 client/client.py --enable-beep
```

#### 音频设备故障排除

**问题：听不到提示音**
- 运行 `./scripts/test_audio.sh` 找到正确的音频设备
- 检查系统音量设置
- 确认音频输出设备没有被静音
- 尝试不同的设备ID

**问题：测试脚本无法识别输入**
- 确保在交互式终端中运行脚本
- 等待提示符出现后再输入
- 使用直接的 Python 脚本：`python3 scripts/test_audio_devices.py`

**问题：音频设备列表为空**
- 检查系统音频驱动是否正常
- 确认已连接音频输出设备（扬声器/耳机）
- 查看系统音频设置

## API 接口

服务端提供 RESTful API：

### 健康检查
```http
GET /api/health
```

### 获取配置
```http
GET /api/config
```

### 获取详细状态
```http
GET /api/status
```

返回实时性能指标：
- 队列大小和使用率
- 活跃转写数量
- 成功/失败请求统计
- 模型信息

### 语音转录 (JSON格式)
```http
POST /api/transcribe
Content-Type: application/json

{
    "audio_data": [音频数据数组],
    "sample_rate": 16000,
    "language": "zh",
    "initial_prompt": "以下是普通话句子。",
    "streaming": false
}
```

### 语音转录 (二进制格式)
```http
POST /api/transcribe_binary
Content-Type: application/octet-stream
X-Sample-Rate: 16000
X-Language: zh
X-Initial-Prompt: 以下是普通话句子。

[二进制音频数据]
```

## 生产环境部署

### 1. 系统服务配置

创建 systemd 服务文件：

```bash
sudo nano /etc/systemd/system/autotranscription.service
```

```ini
[Unit]
Description=AutoTranscription Service
After=network.target

[Service]
Type=forking
User=your-username
WorkingDirectory=/path/to/autotranscription
ExecStart=/path/to/autotranscription/scripts/start_server.sh start
ExecStop=/path/to/autotranscription/scripts/start_server.sh stop
ExecReload=/path/to/autotranscription/scripts/start_server.sh restart
PIDFile=/path/to/autotranscription/logs/transcription_server.pid
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

启用和启动服务：

```bash
sudo systemctl daemon-reload
sudo systemctl enable autotranscription
sudo systemctl start autotranscription
sudo systemctl status autotranscription
```

### 2. 反向代理配置 (Nginx)

```nginx
server {
    listen 80;
    server_name your-domain.com;

    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout 300s;
        proxy_connect_timeout 75s;
    }
}
```

### 3. 防火墙配置

```bash
# Ubuntu/Debian
sudo ufw allow 5000/tcp

# CentOS/RHEL
sudo firewall-cmd --permanent --add-port=5000/tcp
sudo firewall-cmd --reload
```

## 故障排除

### 常见问题

1. **模型下载失败**
   ```bash
   # 检查网络连接
   curl -I https://huggingface.co

   # 重新安装依赖
   ./scripts/manage.sh clean
   ./scripts/manage.sh install
   ```

2. **GPU 不可用**
   ```bash
   # 检查 NVIDIA 驱动
   nvidia-smi

   # 检查 CUDA 安装
   nvcc --version

   # 强制使用 CPU 模式
   # 编辑 config/server_config.json，设置 "device": "cpu"
   ```

3. **端口被占用**
   ```bash
   # 查看端口占用
   sudo netstat -tlnp | grep :5000

   # 更改端口
   # 编辑 config/server_config.json，修改 "port" 值
   ```

4. **权限问题**
   ```bash
   # 确保脚本有执行权限
   chmod +x scripts/*.sh

   # 检查日志目录权限
   sudo chown -R $USER:$USER logs/
   ```

5. **安装模式选择问题**
   ```bash
   # 如果不确定选择哪种模式，使用完整安装
   ./scripts/manage.sh install

   # 查看各安装模式的详细说明
   ./scripts/install_deps.sh --help
   ```

6. **客户端连接服务端失败**
   ```bash
   # 运行连接诊断脚本
   ./scripts/diagnose_client_connection.sh

   # 检查服务端状态
   ./scripts/manage.sh server status

   # 检查网络连接
   curl http://server-ip:5000/api/health

   # 修改客户端配置
   nano config/client_config.json
   # 更新 server_url 为正确的服务端地址
   ```

### 诊断工具

为了帮助用户快速排查和解决连接问题，系统提供了专门的诊断脚本：

#### 连接诊断脚本 (`./scripts/diagnose_client_connection.sh`)

该脚本用于诊断客户端与服务端之间的连接问题，包括网络连通性、端口可达性、代理设置和API连接测试。

**使用方法**：
```bash
./scripts/diagnose_client_connection.sh
```

**诊断内容**：
- 网络连通性检查
- 端口可达性测试
- 代理设置检测
- 服务端API连接验证
- 配置文件验证
- 常见问题排查建议

**适用场景**：
- 无法连接到服务端
- 转录请求失败
- 网络配置问题排查
- 局域网/互联网连接配置验证

### 日志文件位置

- 服务端日志: `logs/transcription_server.log`
- 错误日志: `logs/transcription_server_error.log`
- 客户端日志: `logs/client.log`

### 性能优化和监控

1. **实时监控**
   ```bash
   # 实时并发监控仪表板
   ./scripts/manage.sh server monitor

   # 检查系统状态
   curl http://localhost:5000/api/status

   # 健康检查
   curl http://localhost:5000/api/health
   ```

2. **GPU 优化**
   - 使用 `compute_type: "float16"` 提升速度
   - 确保有足够的 GPU 显存 (建议 8GB+)
   - 系统会自动清理 GPU 内存

3. **并发优化**
   - 调整 `max_concurrent_transcriptions` 基于 GPU 内存 (8-16)
   - 调整 `workers` 参数 (建议 CPU 核心数 × 2)
   - 增加 `queue_size` 处理突发请求

4. **网络优化**
   - 使用二进制 API (`/api/transcribe_binary`) 减少传输开销
   - 配置合适的超时时间 (默认 600 秒)

### 性能指标

**预期性能**:
- **并发能力**: 8-16 个同时转写请求
- **队列容量**: 100 个请求排队
- **吞吐量**: 800-2000 转写/小时 (取决于音频长度)
- **响应时间**: 10-60 秒 (取决于音频长度和模型)

**监控指标**:
- 队列使用率 (建议 < 80%)
- 并发使用率 (建议 < 90%)
- 成功率 (应该 > 95%)
- 平均响应时间

## 开发说明

### 项目结构

```
autotranscription/
├── client/                 # 客户端代码
│   ├── client.py          # 主客户端程序 (状态机 + 热键支持)
│   └── requirements.txt   # 客户端依赖
├── server/                # 服务端代码
│   ├── transcription_server.py  # 高并发转写服务器
│   └── requirements.txt   # 服务端依赖
├── config/                # 配置文件
│   ├── server_config.json # 服务端配置 (含并发设置)
│   └── client_config.json # 客户端配置
├── scripts/               # 管理脚本
│   ├── install_deps.sh    # 自动安装 (Miniconda + CUDA)
│   ├── start_server.sh    # 服务端管理 (含监控)
│   ├── start_client.sh    # 客户端启动脚本
│   ├── manage.sh          # 综合管理脚本
│   ├── install_client_service.sh  # 跨平台客户端服务安装
│   ├── uninstall_client_service.sh # 跨平台客户端服务卸载
│   └── cuda_check.sh      # CUDA 环境诊断
├── logs/                  # 日志目录
└── CLAUDE.md              # Claude Code 开发指南
```

### 架构特点

**高并发服务端**:
- ThreadPoolExecutor 管理并发转写 (8-16 个同时)
- 请求队列系统 (100 个容量)
- 自动 GPU 内存管理
- 实时性能监控 API

**客户端**:
- 状态机架构 (READY → RECORDING → TRANSCRIBING → REPLAYING)
- 全局热键支持 (pynput)
- 自动重试和错误处理
- 中文文本转换支持

### 开发和调试
1. **开发调试**
   ```bash
   # 开发模式启动服务端 (前台运行)
   cd server && python transcription_server.py

   # 查看详细日志
   ./scripts/manage.sh server logs

   # 测试 API 连接
   ./scripts/start_client.sh check
   ```

2. **添加新功能**
   1. 修改相应的配置文件
   2. 更新服务端/客户端代码
   3. 使用 `./scripts/manage.sh restart` 重启服务测试
   4. 通过监控功能验证性能影响

## 致谢

本项目的设计思路受到 [faster-whisper-dictation](https://github.com/doctorguile/faster-whisper-dictation) 项目的启发，感谢该项目为语音转文字领域提供的优秀实现参考。

## 许可证

本项目基于 [MIT 许可证](LICENSE) 开源。

Copyright (c) 2025 AutoTranscription Contributors

您可以自由地使用、复制、修改、合并、发布、分发、再许可和/或销售本软件的副本。详细信息请参阅 [LICENSE](LICENSE) 文件。

## 支持

如有问题或建议，请提交 Issue 或 Pull Request。