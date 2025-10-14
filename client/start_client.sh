#!/bin/bash
# Client startup script

cd "$(dirname "$0")"

echo "================================"
echo "  Transcription Client Startup"
echo "================================"
echo ""

# Check dependencies
if ! python3 -c "import requests" 2>/dev/null; then
    echo "❌ Dependencies not installed"
    echo "Installing dependencies..."
    pip3 install -r requirements.txt
fi

echo "✅ Dependency check completed"
echo ""

# Check server connection
echo "Checking server configuration..."
SERVER_URL=$(python3 -c "import json; print(json.load(open('../config/client_config.json'))['server_url'])" 2>/dev/null || echo "http://localhost:5000")
echo "Server URL: $SERVER_URL"
echo ""

# Start client
if [ $# -eq 0 ]; then
    python3 client.py
else
    python3 client.py "$@"
fi
