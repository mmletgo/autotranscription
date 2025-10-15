# AutoTranscription Speech-to-Text System

[中文文档](README.md) | English

High-concurrency client-server architecture speech-to-text system based on Faster Whisper, supporting GPU acceleration and production environment deployment.

## Features

- 🎯 **High Accuracy**: Based on OpenAI Whisper large-v3 model
- 🚀 **High Concurrency**: Supports 8-16 simultaneous transcription requests with 100-request queue
- 🔥 **GPU Acceleration**: Supports NVIDIA CUDA for significantly improved transcription speed
- 🏭 **Production Ready**: Includes process management, real-time monitoring, and health checks
- 📊 **Performance Monitoring**: Real-time queue status, success rate statistics, and load management
- 🔥 **Hotkey Support**: Global hotkey for quick recording activation
- 🌐 **Network Support**: Supports LAN and Internet access
- 📝 **Real-time Output**: Supports streaming transcription results
- 🇨🇳 **Chinese Optimization**: Optimized for Chinese speech recognition
- 🧠 **Smart Memory Management**: Automatic GPU memory cleanup and optimization

## Best Practices

### Recommended Deployment Architecture

AutoTranscription uses a client-server architecture. The following deployment methods are recommended for optimal performance and user experience:

#### 🖥️ Server Deployment (High-Performance Server)
```bash
# Recommended Configuration
- CPU: 8+ cores (Intel i7/AMD Ryzen 7 or higher)
- GPU: NVIDIA RTX 3060/4060 or higher (8GB+ VRAM)
- Memory: 32GB+
- Storage: 50GB+ available SSD space
- Network: Gigabit Ethernet

# Install Server
./scripts/manage.sh install-server
./scripts/manage.sh server start
```

**Server Advantages**:
- 🚀 **GPU Acceleration**: Utilizes high-performance GPU for speech transcription, 10-50x speed improvement
- 🔄 **High Concurrency**: Supports multiple simultaneous client connections, up to 16 concurrent transcriptions
- 💾 **Centralized Management**: Unified model file and configuration management
- 🌐 **Network Service**: Accessible to any device on the LAN

#### 💻 Client Deployment (LAN Devices)
```bash
# Supported Client Systems
- Windows 10/11 (Laptop/Desktop)
- macOS 10.15+ (iMac/MacBook/Mac Studio)
- Linux distributions (Ubuntu/CentOS/Arch, etc.)

# Install Client
./scripts/manage.sh install-client
./scripts/start_client.sh start
```

**Client Features**:
- ⚡ **Lightweight**: Only requires audio processing and hotkey listening dependencies
- 🎯 **Ready to Use**: One-click start, hotkey-triggered recording
- 🌍 **Cross-Platform**: Supports all major operating systems
- 📡 **Network Connection**: Automatically discovers and connects to LAN servers

#### 🏠 Home/Office Deployment Example

```
┌─────────────────┐      ┌─────────────────┐      ┌─────────────────┐
│   Laptop        │      │   Desktop       │      │   Server        │
│   (Windows)     │◄────►│   (macOS)       │◄────►│  (Linux + GPU)  │
│                 │      │                 │      │                 │
│  Client App     │      │  Client App     │      │  Server App     │
│  Hotkey Record  │      │  Hotkey Record  │      │  AI Transcriber │
│  Real-time      │      │  Real-time      │      │  High Concurrency│
└─────────────────┘      └─────────────────┘      └─────────────────┘
         ▲                        ▲                        ▲
         │                        │                        │
         └────────────────────────┴────────────────────────┘
                      LAN (WiFi/Ethernet)
```

#### 🏢 Enterprise Deployment

**Multi-Department Shared Solution**:
- One high-performance GPU server runs the service
- Employee computers in different departments install the client
- Supports dozens of simultaneous users for speech transcription
- Centralized management and maintenance reduces IT costs

**Remote Work Support**:
```bash
# Server Configuration (config/server_config.json)
{
    "network_mode": "internet",  // Enable Internet access
    "host": "0.0.0.0",          // Listen on all network interfaces
    "port": 5000                // Configurable firewall port
}

# Client Configuration (config/client_config.json)
{
    "server_url": "http://your-server-ip:5000"  // Point to server IP
}
```

### Installation Mode Selection

Choose the appropriate installation mode based on different deployment scenarios:

#### 🖥️ **Full System Installation** (`./scripts/manage.sh install`)
- **Use Case**: Single machine deployment, development environment, small team use
- **Components**: Server + Client + All dependencies
- **Advantages**: One-click deployment, full functionality
- **Resource Requirements**: High (requires GPU and more memory)

#### 🚀 **Server Only Installation** (`./scripts/manage.sh install-server`)
- **Use Case**: GPU server, centralized deployment, multi-user sharing
- **Components**: AI transcription service + Web API + High concurrency processing
- **Advantages**: Focused on AI computing, high resource utilization
- **Resource Requirements**: GPU recommended, large memory

#### 💻 **Client Only Installation** (`./scripts/manage.sh install-client`)
- **Use Case**: User devices, lightweight deployment, connect to remote server
- **Components**: Recording program + Hotkey support + Network communication
- **Advantages**: Lightweight, low resource consumption
- **Resource Requirements**: Low, no GPU required

#### 🏢 **Enterprise Deployment Recommendations**
- **Server**: Use `install-server` mode on high-performance GPU server
- **Client**: Use `install-client` mode on employee computers
- **Network**: Configure firewall rules to ensure server accessibility
- **Management**: Use system service feature for auto-start on boot

### Deployment Advantages

#### 🎯 Performance Optimization
- **Centralized Computing**: All AI computation completed on high-performance server
- **Resource Sharing**: Multiple users share GPU resources, improving utilization
- **Cache Acceleration**: Model files loaded once, subsequent requests respond quickly

#### 💰 Cost Effectiveness
- **Hardware Savings**: Only one high-performance server needed, low client requirements
- **Simplified Maintenance**: Centralized updates and management, no complex environment on each device
- **Flexible Scaling**: New client devices can be added anytime

#### 🔒 Security and Control
- **LAN Deployment**: Data stays within internal network, ensuring information security
- **Access Control**: Configurable firewall rules to restrict access permissions
- **Audit Logging**: Complete transcription records and usage statistics

## Quick Start

### 1. System Requirements

- **Operating System**: Linux (Ubuntu 20.04+, CentOS 7+), macOS 10.15+, Windows 10+
- **Python**: 3.8 or higher (managed by Miniconda)
- **GPU**: NVIDIA GPU (optional, supports CPU mode)
- **CUDA**: 11.8+ (required for GPU mode, auto-installed)
- **Memory**: 16GB+ recommended (high concurrency mode requires more memory)
- **Network**: Stable network connection for model download and API calls

### 2. Flexible Installation Options

AutoTranscription now supports three installation modes. Choose the appropriate installation method based on your needs:

```bash
# Clone the project
git clone <repository-url>
cd autotranscription
```

#### Installation Options

**Full System Installation** (recommended for standalone deployment)
```bash
# Install complete system (Server + Client)
./scripts/manage.sh install
# Or
./scripts/install_deps.sh full
```

**Server Only Installation** (for GPU servers)
```bash
# Install AI transcription server only
./scripts/manage.sh install-server
# Or
./scripts/install_deps.sh server
```

**Client Only Installation** (for user devices)
```bash
# Install client program only
./scripts/manage.sh install-client
# Or
./scripts/install_deps.sh client
```

#### Direct Installation Script Usage

You can also use the `install_deps.sh` script directly:
```bash
# Full installation
./scripts/install_deps.sh full

# Client installation
./scripts/install_deps.sh client

# Server installation
./scripts/install_deps.sh server

# View help
./scripts/install_deps.sh --help
```

> **Note**: All installation modes will automatically detect and install Miniconda and CUDA Toolkit (required for server), no manual configuration needed.

### Manual Installation

If the automatic installation script encounters issues, or if you want to understand the installation process, please refer to the [Manual Installation Guide](docs/MANUAL_INSTALL.md) for detailed step-by-step installation instructions.

### 3. Start the System

```bash
# Start complete system
./scripts/manage.sh start

# Or start separately
./scripts/manage.sh server start  # Start server
./scripts/manage.sh client        # Start client
```

### 4. Using the Client

After starting the client, use the `Alt` hotkey to start recording, press again to stop recording and get transcription results.

## Detailed Usage

### Management Script (`./scripts/manage.sh`)

```bash
# System Installation
./scripts/manage.sh install         # Install complete system dependencies
./scripts/manage.sh install-client  # Install client dependencies only
./scripts/manage.sh install-server  # Install server dependencies only

# System Management
./scripts/manage.sh start           # Start complete system
./scripts/manage.sh stop            # Stop system
./scripts/manage.sh restart         # Restart system
./scripts/manage.sh status          # View system status

# Server Management
./scripts/manage.sh server start     # Start high-concurrency server
./scripts/manage.sh server stop      # Stop server
./scripts/manage.sh server restart   # Restart server
./scripts/manage.sh server status    # View server status
./scripts/manage.sh server logs      # View server logs
./scripts/manage.sh server health    # Health check
./scripts/manage.sh server monitor   # Real-time concurrency monitoring

# Client
./scripts/manage.sh client          # Start client

# Client Service Management (Cross-platform)
./scripts/manage.sh service install   # Install client as system service
./scripts/manage.sh service enable    # Enable auto-start on boot
./scripts/manage.sh service start     # Start client service
./scripts/manage.sh service stop      # Stop client service
./scripts/manage.sh service status    # View service status

# System Maintenance
./scripts/manage.sh clean           # Clean system (keep configuration)
./scripts/manage.sh reset           # Complete system reset (delete all data)
```

### Dependency Installation Script (`./scripts/install_deps.sh`)

```bash
# Use installation script directly (no need to go through manage.sh)
./scripts/install_deps.sh full       # Install complete system
./scripts/install_deps.sh client     # Install client only
./scripts/install_deps.sh server     # Install server only
./scripts/install_deps.sh --help     # View help information
```

### Server Script (`./scripts/start_server.sh`)

```bash
./scripts/start_server.sh start     # Start high-concurrency server
./scripts/start_server.sh stop      # Stop server
./scripts/start_server.sh restart   # Restart server
./scripts/start_server.sh status    # View status
./scripts/start_server.sh logs      # View logs
./scripts/start_server.sh health    # Health check
./scripts/start_server.sh monitor   # Real-time concurrency monitoring
./scripts/start_server.sh config    # Display configuration
```

### Client Script (`./scripts/start_client.sh`)

```bash
# Basic Usage
./scripts/start_client.sh start     # Start client
./scripts/start_client.sh check     # Test server connection
./scripts/start_client.sh config    # Display configuration

# Environment Variable Override
SERVER_URL=http://192.168.1.100:5000 ./scripts/start_client.sh start
HOTKEY="<ctrl>+<alt>+a" ./scripts/start_client.sh start
```

## Client System Service (Cross-platform Support)

AutoTranscription supports registering the client as a system service for auto-start on boot and background operation.

### Supported Platforms

- **Linux**: Uses systemd service management
- **macOS**: Uses launchd service management
- **Windows**: Uses NSSM (Non-Sucking Service Manager)

### Client Service Management

#### Install Service
```bash
# Install client service (auto-detects OS)
./scripts/install_client_service.sh install

# Enable auto-start on boot
./scripts/install_client_service.sh enable

# Start service
./scripts/install_client_service.sh start

# View service status
./scripts/install_client_service.sh status

# View service logs
./scripts/install_client_service.sh logs

# Stop service
./scripts/install_client_service.sh stop

# Restart service
./scripts/install_client_service.sh restart
```

#### Uninstall Service
```bash
# Complete uninstall (delete service, configuration and logs)
./scripts/uninstall_client_service.sh full

# Uninstall service only (keep configuration and logs)
./scripts/uninstall_client_service.sh service

# Clean residual files
./scripts/uninstall_client_service.sh clean

# View status before uninstall
./scripts/uninstall_client_service.sh status
```

#### Service Features

**Client Service Features**:
- **Auto-start on Boot**: Automatically runs client after system startup
- **Auto Restart**: Automatically restarts if service exits abnormally
- **Log Management**: Unified log output and management
- **Security Settings**: Limited permissions to protect system security
- **Environment Isolation**: Runs using conda environment
- **Cross-platform Support**: Unified commands for Linux, macOS, Windows

**Platform-Specific Notes**:

| Platform | Service Manager | Service File Location | Startup Method |
|----------|----------------|----------------------|----------------|
| Linux | systemd | `/etc/systemd/system/autotranscription-client.service` | `systemctl` |
| macOS | launchd | `~/Library/LaunchAgents/com.autotranscription.client.plist` | `launchctl` |
| Windows | NSSM | Windows Service Registry | `nssm` |

#### Troubleshooting

**Common Issues**:

1. **Service Start Failure**
   ```bash
   # Check service status
   ./scripts/install_client_service.sh status

   # Linux view detailed logs
   sudo journalctl -u autotranscription-client -n 50
   ```

2. **Permission Issues**
   ```bash
   # Ensure scripts have execute permission
   chmod +x scripts/install_client_service.sh
   chmod +x scripts/uninstall_client_service.sh
   chmod +x scripts/start_client.sh
   ```

3. **Environment Issues**
   ```bash
   # Check conda environment
   conda env list

   # Check client configuration
   ./scripts/start_client.sh check
   ```

4. **Hotkey Conflicts**
   - Check hotkey settings in client configuration file
   - Ensure no other programs are using the same hotkey

**Manual Debugging**:
```bash
# Activate conda environment
conda activate autotranscription

# Manually run client
./scripts/start_client.sh start

# View real-time logs
tail -f logs/client.log
```

**Log Locations**:
- **Service Logs**: `logs/client_service.log`
- **Linux System Logs**: `sudo journalctl -u autotranscription-client`
- **Client Logs**: `logs/client.log`

## Configuration Files

### Server Configuration (`config/server_config.json`)

```json
{
    "model_size": "large-v3",              // Model size: tiny/base/small/medium/large-v3
    "device": "cuda",                     // Device: cpu/cuda/auto
    "compute_type": "float16",            // Compute precision: int8/float16/float32
    "network_mode": "lan",                // Network mode: lan/internet
    "host": "0.0.0.0",                   // Listen address
    "port": 5000,                        // Listen port
    "workers": 8,                        // Gunicorn worker processes
    "max_concurrent_transcriptions": 16,  // Max concurrent transcriptions
    "queue_size": 100,                   // Request queue size
    "timeout": 600,                      // Request timeout (seconds)
    "log_level": "INFO"                  // Log level
}
```

**High Concurrency Configuration Notes**:
- `max_concurrent_transcriptions`: Maximum number of simultaneous transcription requests
- `queue_size`: Request queue capacity, returns 503 error when full
- `workers`: Gunicorn worker process count, recommended CPU cores × 2

### Client Configuration (`config/client_config.json`)

```json
{
    "server_url": "http://localhost:5000",  // Server address
    "max_time": 30,                         // Max recording duration (seconds)
    "zh_convert": "none",                   // Chinese conversion: none/t2s/s2t
    "streaming": true,                      // Streaming output
    "key_combo": "<alt>",                   // Hotkey combination
    "sample_rate": 16000,                   // Sample rate
    "channels": 1,                          // Number of channels
    "audio_device": null,                   // Audio output device ID (null=default)
    "enable_beep": false                    // Enable beep sounds
}
```

### Audio Device Configuration

The client supports playing beep sounds when recording starts/stops. Due to varying audio device configurations across different systems, manual configuration of the audio output device may be required.

#### Testing and Configuring Audio Devices

If you want to enable the beep sound feature, follow these steps:

1. **Run the audio device test script**
   ```bash
   ./scripts/test_audio.sh
   ```

2. **Test Process**
   - The script will list all available audio output devices
   - It will play test sounds to each device sequentially
   - When you hear the sound, enter `y` to confirm
   - Enter `n` to skip the current device
   - Enter `r` to replay the test sound for the current device

3. **Automatic Configuration**
   - After finding a working device, the script will automatically display configuration instructions
   - You can directly edit `config/client_config.json` to apply the configuration

4. **Manual Configuration Example**
   ```json
   {
       "audio_device": 5,      // Set to the working device ID
       "enable_beep": true     // Enable beep sounds
   }
   ```

5. **Disable Beep Sounds**

   If you don't need the beep sound feature, you can disable it in the configuration:
   ```json
   {
       "enable_beep": false    // Disable beep sounds (default)
   }
   ```

#### Command Line Options

You can also specify the audio device via command line parameters:

```bash
# List all audio output devices
python3 client/client.py --list-audio-devices

# Start with specified audio device
python3 client/client.py --audio-device 5

# Enable beep sounds
python3 client/client.py --enable-beep
```

#### Audio Device Troubleshooting

**Issue: Cannot hear beep sounds**
- Run `./scripts/test_audio.sh` to find the correct audio device
- Check system volume settings
- Ensure audio output device is not muted
- Try different device IDs

**Issue: Test script cannot recognize input**
- Ensure you run the script in an interactive terminal
- Wait for the prompt to appear before entering
- Use the direct Python script: `python3 scripts/test_audio_devices.py`

**Issue: Audio device list is empty**
- Check if system audio drivers are working properly
- Confirm that an audio output device (speakers/headphones) is connected
- Check system audio settings

## API Interface

The server provides a RESTful API:

### Health Check
```http
GET /api/health
```

### Get Configuration
```http
GET /api/config
```

### Get Detailed Status
```http
GET /api/status
```

Returns real-time performance metrics:
- Queue size and usage rate
- Active transcription count
- Success/failure request statistics
- Model information

### Speech Transcription (JSON Format)
```http
POST /api/transcribe
Content-Type: application/json

{
    "audio_data": [audio data array],
    "sample_rate": 16000,
    "language": "zh",
    "initial_prompt": "以下是普通话句子。",
    "streaming": false
}
```

### Speech Transcription (Binary Format)
```http
POST /api/transcribe_binary
Content-Type: application/octet-stream
X-Sample-Rate: 16000
X-Language: zh
X-Initial-Prompt: 以下是普通话句子。

[binary audio data]
```

## Production Environment Deployment

### 1. System Service Configuration

Create systemd service file:

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

Enable and start service:

```bash
sudo systemctl daemon-reload
sudo systemctl enable autotranscription
sudo systemctl start autotranscription
sudo systemctl status autotranscription
```

### 2. Reverse Proxy Configuration (Nginx)

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

### 3. Firewall Configuration

```bash
# Ubuntu/Debian
sudo ufw allow 5000/tcp

# CentOS/RHEL
sudo firewall-cmd --permanent --add-port=5000/tcp
sudo firewall-cmd --reload
```

## Troubleshooting

### Common Issues

1. **Model Download Failure**
   ```bash
   # Check network connection
   curl -I https://huggingface.co

   # Reinstall dependencies
   ./scripts/manage.sh clean
   ./scripts/manage.sh install
   ```

2. **GPU Unavailable**
   ```bash
   # Check NVIDIA driver
   nvidia-smi

   # Check CUDA installation
   nvcc --version

   # Force CPU mode
   # Edit config/server_config.json, set "device": "cpu"
   ```

3. **Port Already in Use**
   ```bash
   # Check port usage
   sudo netstat -tlnp | grep :5000

   # Change port
   # Edit config/server_config.json, modify "port" value
   ```

4. **Permission Issues**
   ```bash
   # Ensure scripts have execute permission
   chmod +x scripts/*.sh

   # Check log directory permissions
   sudo chown -R $USER:$USER logs/
   ```

5. **Installation Mode Selection Issues**
   ```bash
   # If unsure which mode to choose, use full installation
   ./scripts/manage.sh install

   # View detailed descriptions of each installation mode
   ./scripts/install_deps.sh --help
   ```

6. **Client Connection to Server Failed**
   ```bash
   # Check server status
   ./scripts/manage.sh server status

   # Check network connection
   curl http://server-ip:5000/api/health

   # Modify client configuration
   nano config/client_config.json
   # Update server_url to correct server address
   ```

### Log File Locations

- Server logs: `logs/transcription_server.log`
- Error logs: `logs/transcription_server_error.log`
- Client logs: `logs/client.log`

### Performance Optimization and Monitoring

1. **Real-time Monitoring**
   ```bash
   # Real-time concurrency monitoring dashboard
   ./scripts/manage.sh server monitor

   # Check system status
   curl http://localhost:5000/api/status

   # Health check
   curl http://localhost:5000/api/health
   ```

2. **GPU Optimization**
   - Use `compute_type: "float16"` for improved speed
   - Ensure sufficient GPU VRAM (8GB+ recommended)
   - System automatically cleans GPU memory

3. **Concurrency Optimization**
   - Adjust `max_concurrent_transcriptions` based on GPU memory (8-16)
   - Adjust `workers` parameter (recommended CPU cores × 2)
   - Increase `queue_size` to handle burst requests

4. **Network Optimization**
   - Use binary API (`/api/transcribe_binary`) to reduce transmission overhead
   - Configure appropriate timeout (default 600 seconds)

### Performance Metrics

**Expected Performance**:
- **Concurrency**: 8-16 simultaneous transcription requests
- **Queue Capacity**: 100 queued requests
- **Throughput**: 800-2000 transcriptions/hour (depends on audio length)
- **Response Time**: 10-60 seconds (depends on audio length and model)

**Monitoring Metrics**:
- Queue usage rate (recommended < 80%)
- Concurrency usage rate (recommended < 90%)
- Success rate (should be > 95%)
- Average response time

## Development Notes

### Project Structure

```
autotranscription/
├── client/                 # Client code
│   ├── client.py          # Main client program (state machine + hotkey support)
│   └── requirements.txt   # Client dependencies
├── server/                # Server code
│   ├── transcription_server.py  # High-concurrency transcription server
│   └── requirements.txt   # Server dependencies
├── config/                # Configuration files
│   ├── server_config.json # Server configuration (includes concurrency settings)
│   └── client_config.json # Client configuration
├── scripts/               # Management scripts
│   ├── install_deps.sh    # Auto-install (Miniconda + CUDA)
│   ├── start_server.sh    # Server management (includes monitoring)
│   ├── start_client.sh    # Client startup script
│   ├── manage.sh          # Comprehensive management script
│   ├── install_client_service.sh  # Cross-platform client service installation
│   ├── uninstall_client_service.sh # Cross-platform client service uninstallation
│   └── cuda_check.sh      # CUDA environment diagnostic
├── logs/                  # Log directory
└── CLAUDE.md              # Claude Code development guide
```

### Architecture Highlights

**High-Concurrency Server**:
- ThreadPoolExecutor manages concurrent transcriptions (8-16 simultaneous)
- Request queue system (100 capacity)
- Automatic GPU memory management
- Real-time performance monitoring API

**Client**:
- State machine architecture (READY → RECORDING → TRANSCRIBING → REPLAYING)
- Global hotkey support (pynput)
- Automatic retry and error handling
- Chinese text conversion support

### Development and Debugging
1. **Development Debugging**
   ```bash
   # Start server in development mode (foreground)
   cd server && python transcription_server.py

   # View detailed logs
   ./scripts/manage.sh server logs

   # Test API connection
   ./scripts/start_client.sh check
   ```

2. **Adding New Features**
   1. Modify corresponding configuration files
   2. Update server/client code
   3. Use `./scripts/manage.sh restart` to restart service for testing
   4. Verify performance impact through monitoring features

## Acknowledgments

The design of this project was inspired by the [faster-whisper-dictation](https://github.com/doctorguile/faster-whisper-dictation) project. Thanks to this project for providing excellent implementation references in the field of speech-to-text.

## License

This project is open source under the [MIT License](LICENSE).

Copyright (c) 2025 AutoTranscription Contributors

You are free to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of this software. For details, please refer to the [LICENSE](LICENSE) file.

## Support

If you have any questions or suggestions, please submit an Issue or Pull Request.
