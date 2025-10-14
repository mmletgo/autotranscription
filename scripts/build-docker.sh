#!/bin/bash
# Docker build script for transcription server

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}================================"
echo "  Transcription Server Docker Builder"
echo -e "================================${NC}"
echo ""

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo -e "${RED}❌ Docker is not installed. Please install Docker first.${NC}"
    exit 1
fi

# Check if Docker Compose is installed
if ! command -v docker-compose &> /dev/null; then
    echo -e "${RED}❌ Docker Compose is not installed. Please install Docker Compose first.${NC}"
    exit 1
fi

# Check if NVIDIA Docker runtime is available (for GPU support)
if command -v nvidia-docker &> /dev/null || docker info 2>/dev/null | grep -q "nvidia"; then
    echo -e "${GREEN}✅ NVIDIA Docker runtime detected - GPU support available${NC}"
    GPU_SUPPORT="--gpu"
else
    echo -e "${YELLOW}⚠️  NVIDIA Docker runtime not detected - will use CPU only${NC}"
    GPU_SUPPORT="--cpu"
fi

echo ""

# Build arguments
IMAGE_NAME="transcription-server"
TAG=${1:-"latest"}
BUILD_CONTEXT=${2:-"./server"}

echo -e "${YELLOW}Building Docker image:${NC}"
echo "  Image name: $IMAGE_NAME"
echo "  Tag: $TAG"
echo "  Build context: $BUILD_CONTEXT"
echo ""

# Build the Docker image
echo -e "${YELLOW}Starting Docker build...${NC}"
docker build -t "$IMAGE_NAME:$TAG" "$BUILD_CONTEXT"

echo ""
echo -e "${GREEN}✅ Docker image built successfully!${NC}"
echo ""
echo -e "${YELLOW}To run the container:${NC}"
echo "  # CPU only:"
echo "  docker run -p 5000:5000 -v \$(pwd)/config:/app/config:ro $IMAGE_NAME:$TAG"
echo ""
if [ "$GPU_SUPPORT" = "--gpu" ]; then
    echo "  # With GPU support:"
    echo "  docker run --gpus all -p 5000:5000 -v \$(pwd)/config:/app/config:ro $IMAGE_NAME:$TAG"
    echo ""
    echo "  # Or using docker-compose:"
    echo "  docker-compose up -d"
fi

echo ""
echo -e "${YELLOW}To push to registry (optional):${NC}"
echo "  docker tag $IMAGE_NAME:$TAG your-registry/$IMAGE_NAME:$TAG"
echo "  docker push your-registry/$IMAGE_NAME:$TAG"