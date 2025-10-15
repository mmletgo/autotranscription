#!/bin/bash
# 客户端连接诊断脚本
# 在客户机上运行此脚本以诊断连接问题

SERVER_IP="192.168.6.142"
SERVER_PORT="5000"

echo "========================================"
echo "AutoTranscription 客户端连接诊断"
echo "========================================"
echo ""

# 1. 检查网络连通性
echo "[1/6] 检查网络连通性..."
if ping -c 3 $SERVER_IP > /dev/null 2>&1; then
    echo "✅ 网络连通正常"
else
    echo "❌ 无法 ping 通服务器 $SERVER_IP"
    echo "   请检查："
    echo "   - 客户机和服务器是否在同一网络"
    echo "   - 服务器防火墙是否允许 ICMP"
    exit 1
fi
echo ""

# 2. 检查端口连通性
echo "[2/6] 检查端口 $SERVER_PORT 连通性..."
if command -v nc > /dev/null 2>&1; then
    if nc -zv $SERVER_IP $SERVER_PORT 2>&1 | grep -q "succeeded\|Connected"; then
        echo "✅ 端口 $SERVER_PORT 可访问"
    else
        echo "❌ 无法连接到端口 $SERVER_PORT"
        echo "   请检查："
        echo "   - 服务端是否在运行"
        echo "   - 服务器防火墙是否允许端口 $SERVER_PORT"
        exit 1
    fi
elif command -v telnet > /dev/null 2>&1; then
    if timeout 3 telnet $SERVER_IP $SERVER_PORT 2>&1 | grep -q "Connected"; then
        echo "✅ 端口 $SERVER_PORT 可访问"
    else
        echo "❌ 无法连接到端口 $SERVER_PORT"
        exit 1
    fi
else
    echo "⚠️  未找到 nc 或 telnet 命令，跳过端口测试"
fi
echo ""

# 3. 检查代理设置
echo "[3/6] 检查代理设置..."
if [ -n "$http_proxy" ] || [ -n "$https_proxy" ] || [ -n "$HTTP_PROXY" ] || [ -n "$HTTPS_PROXY" ]; then
    echo "⚠️  检测到代理设置："
    [ -n "$http_proxy" ] && echo "   http_proxy=$http_proxy"
    [ -n "$https_proxy" ] && echo "   https_proxy=$https_proxy"
    [ -n "$HTTP_PROXY" ] && echo "   HTTP_PROXY=$HTTP_PROXY"
    [ -n "$HTTPS_PROXY" ] && echo "   HTTPS_PROXY=$HTTPS_PROXY"
    echo ""
    echo "   代理可能会干扰局域网连接，建议临时禁用："
    echo "   export no_proxy=\"$SERVER_IP,localhost,127.0.0.1\""
    echo "   或者："
    echo "   unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY"
else
    echo "✅ 未检测到代理设置"
fi
echo ""

# 4. 测试 HTTP 连接
echo "[4/6] 测试 HTTP API 连接..."
if command -v curl > /dev/null 2>&1; then
    # 临时禁用代理进行测试
    response=$(NO_PROXY="*" curl -s -w "\n%{http_code}" --connect-timeout 5 http://$SERVER_IP:$SERVER_PORT/api/health 2>&1)
    http_code=$(echo "$response" | tail -n 1)
    response_body=$(echo "$response" | head -n -1)

    if [ "$http_code" = "200" ]; then
        echo "✅ HTTP API 连接成功"
        echo "   响应: $response_body"
    else
        echo "❌ HTTP API 连接失败"
        echo "   HTTP 状态码: $http_code"
        echo "   响应: $response_body"
        exit 1
    fi
else
    echo "❌ 未找到 curl 命令，无法测试 HTTP 连接"
    exit 1
fi
echo ""

# 5. 检查本机网络配置
echo "[5/6] 检查本机网络配置..."
echo "本机 IP 地址："
ip addr show | grep "inet " | grep -v "127.0.0.1" | awk '{print "   " $2}'
echo ""
echo "本机路由表："
ip route show | head -5 | awk '{print "   " $0}'
echo ""

# 6. 测试转写功能
echo "[6/6] 测试转写 API (可选)..."
read -p "是否测试转写 API？这需要发送一个小的音频样本 (y/n): " test_transcribe

if [ "$test_transcribe" = "y" ] || [ "$test_transcribe" = "Y" ]; then
    # 创建一个空的音频数据进行测试（仅测试 API 是否响应）
    response=$(NO_PROXY="*" curl -s -w "\n%{http_code}" --connect-timeout 10 \
        -X POST \
        -H "Content-Type: application/json" \
        -d '{"audio": [], "sample_rate": 16000}' \
        http://$SERVER_IP:$SERVER_PORT/api/transcribe 2>&1)
    http_code=$(echo "$response" | tail -n 1)

    if [ "$http_code" = "200" ] || [ "$http_code" = "400" ]; then
        echo "✅ 转写 API 可访问 (状态码: $http_code)"
    else
        echo "⚠️  转写 API 响应异常 (状态码: $http_code)"
    fi
else
    echo "跳过转写 API 测试"
fi
echo ""

echo "========================================"
echo "诊断完成！"
echo "========================================"
echo ""
echo "如果所有检查都通过，请确认客户端配置："
echo "1. 检查 config/client_config.json 中的 server_url"
echo "2. 确保设置为: \"server_url\": \"http://$SERVER_IP:$SERVER_PORT\""
echo "3. 如果有代理，添加 no_proxy 环境变量"
echo ""
echo "启动客户端命令："
echo "   ./scripts/manage.sh client"
echo ""
