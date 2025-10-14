# AutoTranscription 语音转文字系统

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

## 快速开始

### 1. 系统要求

- **操作系统**: Ubuntu 20.04+, CentOS 7+, 其他 Linux 发行版
- **Python**: 3.8 或更高版本
- **GPU**: NVIDIA GPU (可选，支持 CPU 模式)
- **CUDA**: 11.8+ (GPU 模式需要，自动安装)
- **内存**: 建议 16GB+ (高并发模式需要更多内存)
- **网络**: 稳定的网络连接用于模型下载和 API 调用

### 2. 一键安装

```bash
# 克隆项目
git clone <repository-url>
cd autotranscription

# 一键安��� (自动安装 Miniconda + CUDA + 所有依赖)
./scripts/manage.sh install
```

> **注意**: 安装脚本会自动检测并安装 Miniconda 和 CUDA Toolkit，无需手动配置。

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
# 系统管理
./scripts/manage.sh install       # 安装依赖
./scripts/manage.sh start         # 启动系统
./scripts/manage.sh stop          # 停止系统
./scripts/manage.sh restart       # 重启系统
./scripts/manage.sh status        # 查看状态

# 服务端管理
./scripts/manage.sh server start     # 启动高并发服务端
./scripts/manage.sh server stop      # 停止服务端
./scripts/manage.sh server status    # 查看服务端状态
./scripts/manage.sh server logs      # 查看服务端日志
./scripts/manage.sh server health    # 健康检查
./scripts/manage.sh server monitor   # 实时并发监控

# 客户端
./scripts/manage.sh client          # 启动客户端

# 系统维护
./scripts/manage.sh clean           # 清理系统
./scripts/manage.sh reset           # 完全重置
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
- `workers`: Gunicorn 工作进程数，建议 CPU 核心数 × 2

### 客户端配置 (`config/client_config.json`)

```json
{
    "server_url": "http://localhost:5000",  // 服务端地址
    "max_time": 30,                         // 最大录音时长(秒)
    "zh_convert": "none",                   // 中文转换: none/t2s/s2t
    "streaming": true,                      // 流式输出
    "key_combo": "<alt>",                   // 快捷键组合
    "sample_rate": 16000,                   // 采样率
    "channels": 1                           // 声道数
}
```

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
│   ├── verify_cleanup.sh  # 环境验证工具
│   └── cuda_check.sh      # CUDA 环境诊断
├── logs/                  # 日志目录
├── systemd/               # 系统服务配置
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

1. **环境验证**
   ```bash
   ./scripts/verify_cleanup.sh     # 验证环境完整性
   ./scripts/cuda_check.sh         # 检查 CUDA 环境
   ```

2. **开发调试**
   ```bash
   # 开发模式启动服务端 (前台运行)
   cd server && python transcription_server.py

   # 查看详细日志
   ./scripts/manage.sh server logs

   # 测试 API 连接
   ./scripts/start_client.sh check
   ```

3. **添加新功能**
   1. 修改相应的配置文件
   2. 更新服务端/客户端代码
   3. 使用 `./scripts/manage.sh restart` 重启服务测试
   4. 通过监控功能验证性能影响

## 许可证

本项目基于 MIT 许可证开源。

## 支持

如有问题或建议，请提交 Issue 或 Pull Request。