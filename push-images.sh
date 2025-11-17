#!/bin/bash
# Script to push fixed images to GHCR
# Usage: ./push-images.sh YOUR_GITHUB_USERNAME

if [ -z "$1" ]; then
    echo "Usage: ./push-images.sh YOUR_GITHUB_USERNAME"
    exit 1
fi

USERNAME=$1

echo "Tagging images for GHCR..."
docker tag cs720-backend:fixed-v2 ghcr.io/$USERNAME/cs720-backend:fixed-v2
docker tag cs720-backend:fixed-v2 ghcr.io/$USERNAME/cs720-backend:latest
docker tag cs720-ai-service:fixed-v2 ghcr.io/$USERNAME/cs720-ai-service:fixed-v2
docker tag cs720-ai-service:fixed-v2 ghcr.io/$USERNAME/cs720-ai-service:latest

echo ""
echo "To push to GHCR, first login:"
echo "  echo \$GITHUB_TOKEN | docker login ghcr.io -u $USERNAME --password-stdin"
echo ""
echo "Then push the images:"
echo "  docker push ghcr.io/$USERNAME/cs720-backend:fixed-v2"
echo "  docker push ghcr.io/$USERNAME/cs720-backend:latest"
echo "  docker push ghcr.io/$USERNAME/cs720-ai-service:fixed-v2"
echo "  docker push ghcr.io/$USERNAME/cs720-ai-service:latest"
