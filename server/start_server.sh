#!/bin/bash
# Server startup script

cd "$(dirname "$0")"

echo "================================"
echo "  Transcription Server Startup"
echo "================================"
echo ""

# Check dependencies
if ! python3 -c "import flask" 2>/dev/null; then
    echo "❌ Flask not installed"
    echo "Installing dependencies..."
    pip3 install -r requirements.txt
fi

echo "✅ Dependency check completed"
echo ""

# Start service
python3 transcription_server.py
