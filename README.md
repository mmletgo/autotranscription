# 语音转写系统 - 客户端/服务端架构

这是一个基于 Faster Whisper 的语音转写系统，采用客户端-服务端架构设计。服务端提供 AI 转写运算，客户端通过网络 API 调用服务。

## 🏗️ 项目结构

```
autotranscription/
├── server/                      # 服务端
│   ├── transcription_server.py  # 服务端主程序
│   └── requirements.txt         # 服务端依赖
├── client/                      # 客户端
│   ├── client.py                # 客户端主程序
│   └── requirements.txt         # 客户端依赖
├── config/                      # 配置文件
│   ├── server_config.json       # 服务端配置
│   └── client_config.json       # 客户端配置
├── assets/                      # 音效文件
│   ├── bo.wav
│   └── click.wav
└── README.md                    # 本文档
```

## ✨ 特性

### 服务端
- 🚀 REST API 接口，基于 Flask
- 🔒 支持局域网/互联网访问控制
- 🎯 使用 Faster Whisper 进行高效转写
- 💻 支持 CPU/GPU 推理
- 🌍 多语言支持（中文、英文、日语等）
- 📊 JSON 和二进制音频数据格式

### 客户端
- 🎤 录音功能（PyAudio）
- ⌨️ 快捷键触发（默认：Alt 键，可自定义）
- 📋 自动复制粘贴转写结果
- 🔄 实时流式输出（可选）
- 🇨🇳 中文繁简转换（可选）
- 🌐 网络 API 调用

## 📦 安装

### 服务端安装

```bash
cd server
pip install -r requirements.txt
```

**注意**: 如果使用 GPU 加速，需要安装对应的 CUDA 驱动和库。

### 客户端安装

```bash
cd client
pip install -r requirements.txt
```

**Linux 系统额外依赖**:
```bash
# Ubuntu/Debian
sudo apt-get install portaudio19-dev python3-pyaudio

# Fedora
sudo dnf install portaudio-devel
```

## ⚙️ 配置

### 服务端配置 (`config/server_config.json`)

```json
{
  "model_size": "base",           // 模型大小: tiny, base, small, medium, large
  "device": "cpu",                // 设备: cpu, cuda, auto
  "compute_type": "int8",         // 计算类型: int8, float16, float32
  "language": "zh",               // 语言: zh(中文), en(英文), 等
  "initial_prompt": "以下是普通话的句子。",  // 初始提示
  "host": "0.0.0.0",              // 监听地址: 0.0.0.0(局域网), 127.0.0.1(本地)
  "port": 5000,                   // 端口号
  "network_mode": "lan"           // 网络模式: lan(局域网), internet(互联网)
}
```

**网络模式说明**:
- `lan`: 局域网模式，限制 CORS，适合内网使用
- `internet`: 互联网模式，开放 CORS，适合公网访问（需配置防火墙）

### 客户端配置 (`config/client_config.json`)

```json
{
  "server_url": "http://localhost:5000",  // 服务端地址
  "max_time": 300,                        // 最大录音时长(秒)
  "language": "zh",                       // 语言
  "initial_prompt": "以下是普通话的句子。",
  "streaming": false,                     // 流式输出
  "zh_convert": "t2s",                    // 中文转换: none, t2s, s2t
  "key_combo": null                       // 快捷键(默认: <alt>)
}
```

## 🚀 使用方法

### 1. 启动服务端

```bash
cd server
python transcription_server.py
```

服务端启动后会显示:
```
==================================================
语音转写服务启动
地址: http://0.0.0.0:5000
模型: base
设备: cpu
网络模式: lan
局域网访问地址: http://<本机IP>:5000
==================================================
```

### 2. 启动客户端

**默认配置**:
```bash
cd client
python client.py
```

**指定服务器地址**:
```bash
# 连接到局域网服务器
python client.py -s http://192.168.1.100:5000

# 连接到远程服务器
python client.py -s http://example.com:5000
```

**自定义快捷键**:
```bash
# 使用组合键
python client.py -k "<ctrl>+<alt>+a"
python client.py -k "<win>+z"
python client.py -k "<cmd>+<alt>+r"

# 使用单个键（默认是 Alt）
python client.py -k "<alt>"
python client.py -k "<ctrl>"
```

**启用流式输出**:
```bash
python client.py --streaming
```

### 3. 录音转写

1. 按下快捷键（**默认：Alt 键**）开始录音
2. 听到"哔"声后开始说话
3. 再次按下快捷键停止录音
4. 等待转写完成，结果会自动粘贴到当前光标位置

**快捷键说明**:
- 默认使用 **Alt** 键（左 Alt 或右 Alt 均可）
- 可通过 `-k` 参数自定义为其他键或组合键
- 示例：`python client.py -k "<ctrl>+<alt>+a"`

## 🔧 命令行参数

### 服务端
服务端参数通过配置文件设置，不支持命令行参数。

### 客户端

```bash
python client.py [选项]

选项:
  -s, --server-url URL        服务端API地址 (默认: http://localhost:5000)
  -k, --key-combo KEYS        快捷键，如: <alt>, <ctrl>+<alt>+a (默认: <alt>)
  -t, --max-time SECONDS      最大录音时长（秒），默认: 300
  -l, --language CODE         语言代码，如: zh, en, ja
  --initial-prompt TEXT       初始提示文本
  --streaming                 启用流式输出模式
  --zh-convert MODE           中文转换: t2s(繁转简), s2t(简转繁), none(禁用)
```

## 🌐 API 文档

### 健康检查
```http
GET /api/health
```

**响应**:
```json
{
  "status": "healthy",
  "model": "base",
  "device": "cpu",
  "timestamp": "2025-10-14T12:00:00"
}
```

### 获取配置
```http
GET /api/config
```

**响应**:
```json
{
  "model_size": "base",
  "device": "cpu",
  "compute_type": "int8",
  "language": "zh",
  "network_mode": "lan"
}
```

### 转写音频（JSON格式）
```http
POST /api/transcribe
Content-Type: application/json

{
  "audio_data": [0.1, 0.2, ...],
  "sample_rate": 16000,
  "language": "zh",
  "initial_prompt": "以下是普通话的句子。",
  "streaming": false
}
```

**响应**:
```json
{
  "success": true,
  "language": "zh",
  "language_probability": 0.95,
  "text": "这是转写的完整文本",
  "segments": [
    {
      "start": 0.0,
      "end": 2.5,
      "text": "这是转写的完整文本"
    }
  ]
}
```

### 转写音频（二进制格式）
```http
POST /api/transcribe_binary
Content-Type: application/octet-stream
X-Sample-Rate: 16000
X-Language: zh
X-Initial-Prompt: 以下是普通话的句子。

[二进制音频数据]
```

## 🔐 安全建议

### 局域网部署
1. 使用 `network_mode: "lan"` 配置
2. 设置 `host: "0.0.0.0"` 允许局域网访问
3. 配置防火墙规则，只允许内网 IP 访问

### 互联网部署
1. 使用 `network_mode: "internet"` 配置
2. 配置 HTTPS（建议使用 Nginx 反向代理）
3. 添加身份验证机制（如 JWT Token）
4. 限制请求频率和大小
5. 使用专业的 WSGI 服务器（如 Gunicorn）

**生产环境部署示例**:
```bash
# 安装 Gunicorn
pip install gunicorn

# 启动服务（4个工作进程）
gunicorn -w 4 -b 0.0.0.0:5000 transcription_server:app
```

## 🐛 故障排查

### 客户端无法连接服务器
1. 检查服务端是否启动
2. 确认服务器地址和端口正确
3. 检查防火墙设置
4. 测试网络连通性: `ping <服务器IP>`

### 录音没有声音
1. 检查麦克风权限
2. 确认麦克风设备正常
3. 检查系统音频设置

### 转写结果不准确
1. 尝试使用更大的模型 (`small`, `medium`, `large`)
2. 提供合适的 `initial_prompt`
3. 指定正确的语言代码
4. 确保录音环境安静

### GPU 加速不工作
1. 检查 CUDA 驱动安装
2. 确认 PyTorch/CTranslate2 支持 GPU
3. 设置 `device: "cuda"` 或 `"auto"`

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

## 📄 许可证

[根据原项目许可证]

## 🙏 致谢

- [Faster Whisper](https://github.com/guillaumekln/faster-whisper)
- [OpenAI Whisper](https://github.com/openai/whisper)
- Flask 和相关开源项目
