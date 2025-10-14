#!/bin/bash
# Docker run script for transcription server

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}================================"
echo "  Transcription Server Docker Runner"
echo -e "================================${NC}"
echo ""

# Default values
IMAGE_NAME="transcription-server"
TAG=${1:-"latest"}
CONTAINER_NAME="transcription-server"
HOST_PORT=${2:-5000}
CONFIG_PATH=${3:-"./config"}

# Help function
show_help() {
    echo -e "${BLUE}Usage:${NC}"
    echo "  $0 [TAG] [HOST_PORT] [CONFIG_PATH]"
    echo ""
    echo -e "${BLUE}Arguments:${NC}"
    echo "  TAG         Docker image tag (default: latest)"
    echo "  HOST_PORT   Host port to map (default: 5000)"
    echo "  CONFIG_PATH Path to config directory (default: ./config)"
    echo ""
    echo -e "${BLUE}Options:${NC}"
    echo "  -h, --help  Show this help message"
    echo "  --cpu       Force CPU mode (disable GPU)"
    echo "  --compose   Use docker-compose instead of docker run"
    echo ""
    echo -e "${BLUE}Examples:${NC}"
    echo "  $0                    # Run with defaults"
    echo "  $0 v1.0.0 8080        # Use tag v1.0.0 and port 8080"
    echo "  $0 latest 5000 ./config  # Use custom config path"
    echo "  $0 --cpu              # Force CPU mode"
    echo "  $0 --compose          # Use docker-compose"
}

# Parse arguments
USE_GPU=true
USE_COMPOSE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        --cpu)
            USE_GPU=false
            shift
            ;;
        --compose)
            USE_COMPOSE=true
            shift
            ;;
        *)
            # Positional arguments
            if [[ -z "$TAG_SET" ]]; then
                TAG="$1"
                TAG_SET=true
            elif [[ -z "$PORT_SET" ]]; then
                HOST_PORT="$1"
                PORT_SET=true
            elif [[ -z "$CONFIG_SET" ]]; then
                CONFIG_PATH="$1"
                CONFIG_SET=true
            else
                echo -e "${RED}❌ Unknown argument: $1${NC}"
                show_help
                exit 1
            fi
            shift
            ;;
    esac
done

# Check if Docker is running
if ! docker info &> /dev/null; then
    echo -e "${RED}❌ Docker is not running. Please start Docker first.${NC}"
    exit 1
fi

# Check if config directory exists
if [ ! -d "$CONFIG_PATH" ]; then
    echo -e "${RED}❌ Config directory not found: $CONFIG_PATH${NC}"
    exit 1
fi

# Check if server config exists
if [ ! -f "$CONFIG_PATH/server_config.json" ]; then
    echo -e "${RED}❌ Server config not found: $CONFIG_PATH/server_config.json${NC}"
    exit 1
fi

echo -e "${YELLOW}Configuration:${NC}"
echo "  Image: $IMAGE_NAME:$TAG"
echo "  Container: $CONTAINER_NAME"
echo "  Host port: $HOST_PORT"
echo "  Config path: $CONFIG_PATH"
echo "  GPU support: $([ "$USE_GPU" = true ] && echo "Yes" || echo "No (CPU only)")"
echo "  Use compose: $([ "$USE_COMPOSE" = true ] && echo "Yes" || echo "No")"
echo ""

# Stop and remove existing container if it exists
if docker ps -a --format 'table {{.Names}}' | grep -q "^$CONTAINER_NAME$"; then
    echo -e "${YELLOW}Stopping existing container...${NC}"
    docker stop "$CONTAINER_NAME" 2>/dev/null || true
    docker rm "$CONTAINER_NAME" 2>/dev/null || true
fi

if [ "$USE_COMPOSE" = true ]; then
    echo -e "${YELLOW}Starting with docker-compose...${NC}"

    # Stop existing services
    docker-compose down 2>/dev/null || true

    # Start services
    docker-compose up -d

    echo ""
    echo -e "${GREEN}✅ Container started with docker-compose!${NC}"
    echo -e "${YELLOW}Server URL: http://localhost:5000${NC}"
    echo -e "${YELLOW}Health check: http://localhost:5000/api/health${NC}"

else
    # Build docker run command
    DOCKER_CMD=("docker" "run" "-d" "--name" "$CONTAINER_NAME")

    # Add GPU support if available and requested
    if [ "$USE_GPU" = true ] && (command -v nvidia-docker &> /dev/null || docker info 2>/dev/null | grep -q "nvidia"); then
        DOCKER_CMD+=("--gpus" "all")
        echo -e "${GREEN}✅ GPU support enabled${NC}"
    else
        echo -e "${YELLOW}⚠️  Running in CPU mode${NC}"
    fi

    # Add port mapping and volumes
    DOCKER_CMD+=("-p" "$HOST_PORT:5000")
    DOCKER_CMD+=("-v" "$(realpath "$CONFIG_PATH"):/app/config:ro")

    # Add restart policy
    DOCKER_CMD+=("--restart" "unless-stopped")

    # Add image name
    DOCKER_CMD+=("$IMAGE_NAME:$TAG")

    echo -e "${YELLOW}Starting container...${NC}"

    # Run the container
    "${DOCKER_CMD[@]}"

    echo ""
    echo -e "${GREEN}✅ Container started successfully!${NC}"
    echo -e "${YELLOW}Container name: $CONTAINER_NAME${NC}"
    echo -e "${YELLOW}Server URL: http://localhost:$HOST_PORT${NC}"
    echo -e "${YELLOW}Health check: http://localhost:$HOST_PORT/api/health${NC}"
fi

echo ""
echo -e "${BLUE}Useful commands:${NC}"
echo "  View logs: docker logs $CONTAINER_NAME"
echo "  Stop container: docker stop $CONTAINER_NAME"
echo "  Restart container: docker restart $CONTAINER_NAME"
echo "  Shell access: docker exec -it $CONTAINER_NAME bash"
if [ "$USE_COMPOSE" = true ]; then
    echo "  View compose logs: docker-compose logs -f"
    echo "  Stop compose: docker-compose down"
fi

echo ""
echo -e "${YELLOW}Waiting for server to be ready...${NC}"
sleep 5

# Check if server is responding
if curl -f "http://localhost:$HOST_PORT/api/health" &>/dev/null; then
    echo -e "${GREEN}✅ Server is ready and responding!${NC}"
else
    echo -e "${YELLOW}⚠️  Server might still be starting up. Check logs for details.${NC}"
fi