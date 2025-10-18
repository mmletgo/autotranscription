# LLM Integration - Quick Start Guide

## What's New

你的服务端现在支持LLM集成功能！语音识别完成后，服务器会自动使用LLM来润色和纠错文本。

**核心特性**:
- ✅ 使用 OpenAI SDK 实现，支持任何 OpenAI API 兼容的 LLM 服务
- ✅ 开箱即用支持 ModelScope (推荐用于中文)、OpenAI、Ollama 等
- ✅ 完整的容错和重试机制，LLM 失败时自动回退到原始文本
- ✅ 指数退避重试策略，处理 API 限额和临时故障

## Quick Setup

### Step 1: Enable LLM in Configuration

编辑 `config/server_config.json`，修改 `llm` 部分的 `enabled` 为 `true`：

```json
{
  "llm": {
    "enabled": true,
    "api_url": "YOUR_API_URL",
    "api_key": "YOUR_API_KEY",
    "model": "YOUR_MODEL_NAME"
  }
}
```

### Step 2: Add Your LLM Service Details

根据你使用的LLM服务选择对应的配置：

#### ModelScope (推荐用于中文)

```json
{
  "llm": {
    "enabled": true,
    "api_url": "https://dashscope.aliyuncs.com/compatible-mode/v1",
    "api_key": "sk-xxxxxxxxx",
    "model": "qwen-turbo",
    "temperature": 0.3,
    "max_tokens": 2000
  }
}
```

获取API密钥：https://dashscope.console.aliyun.com

#### OpenAI

```json
{
  "llm": {
    "enabled": true,
    "api_url": "https://api.openai.com/v1",
    "api_key": "sk-xxxxxxxxx",
    "model": "gpt-3.5-turbo",
    "temperature": 0.3,
    "max_tokens": 2000
  }
}
```

#### 本地 Ollama

```json
{
  "llm": {
    "enabled": true,
    "api_url": "http://localhost:11434/v1",
    "api_key": "ollama",
    "model": "llama2",
    "timeout": 60
  }
}
```

### Step 3: Restart Server

```bash
./scripts/manage.sh server stop
./scripts/manage.sh server start
```

### Step 4: Check LLM Status

```bash
curl http://localhost:5000/api/llm/health
```

## Response Format

转写请求的响应现在包含以下新字段：

```json
{
  "success": true,
  "text": "Polished text by LLM",
  "original_text": "Original transcribed text",
  "llm_used": true,
  "llm_error": null,
  ...
}
```

- `text`: 最终文本（如果LLM成功则是润色后的，否则是原始文本）
- `original_text`: 原始识别文本
- `llm_used`: 是否成功使用LLM润色
- `llm_error`: 如果LLM处理失败，此字段包含错误信息

## How It Works

1. **语音识别**: 服务器用Whisper识别音频
2. **LLM润色**: 如果启用，将识别文本发送给LLM进行润色
3. **自动回退**: 如果LLM失败（API限额、网络问题等），直接返回原始文本
4. **响应返回**: 客户端收到最终文本（可能已润色或原始）

## Configuration Parameters

| 参数 | 说明 | 默认值 |
|------|------|--------|
| `enabled` | 启用/禁用LLM服务 | false |
| `api_url` | LLM API地址 | "" |
| `api_key` | API密钥 | "" |
| `model` | 模型名称 | "" |
| `timeout` | 请求超时时间（秒） | 30 |
| `max_retries` | 最大重试次数 | 2 |
| `temperature` | 采样温度（0-1） | 0.3 |
| `max_tokens` | 最大返回标记数 | 2000 |

## Testing

### Test 1: Check Server Health

```bash
curl http://localhost:5000/api/health
```

### Test 2: Check LLM Health

```bash
curl http://localhost:5000/api/llm/health
```

### Test 3: Test Transcription

```bash
# 使用client/client.py或任何HTTP客户端发送转写请求
curl -X POST http://localhost:5000/api/transcribe \
  -H "Content-Type: application/json" \
  -d '{
    "audio_data": [0.0, 0.1, 0.2, ...],
    "language": "zh"
  }'
```

## Troubleshooting

### LLM服务显示不健康

- 检查API URL和密钥是否正确
- 确保服务器可以访问API端点
- 检查防火墙/网络设置

### LLM处理缓慢

- 增加 `timeout` 值
- 尝试更快的模型
- 减少 `max_tokens` 值

### 高错误率

- 检查日志获取详细错误信息
- 验证API服务可用性
- 尝试增加 `max_retries`

## Important Notes

- 如果LLM失败，服务器会**自动使用原始文本**，确保转写服务的可靠性
- LLM处理会增加总响应时间（通常1-5秒）
- 某些付费LLM服务可能产生额外成本

## Disable LLM

要禁用LLM功能，只需将 `enabled` 设置为 `false`：

```json
{
  "llm": {
    "enabled": false
  }
}
```

## More Information

详细的LLM集成指南请参阅：`docs/LLM_INTEGRATION_GUIDE.md`

## File Changes Summary

新增文件：
- `server/llm_service.py` - LLM服务模块
- `docs/LLM_INTEGRATION_GUIDE.md` - 详细集成指南
- `docs/LLM_QUICK_START.md` - 快速开始指南
- `config/server_config.example.json` - 配置示例

修改文件：
- `config/server_config.json` - 添加LLM配置部分
- `server/transcription_server.py` - 集成LLM处理和健康检查端点
- `CLAUDE.md` - 更新项目文档
