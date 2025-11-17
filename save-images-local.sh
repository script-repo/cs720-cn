#!/bin/bash
# Script to save Docker images to tar files for backup

echo "Saving Docker images to tar files..."
docker save cs720-backend:fixed-v2 | gzip > cs720-backend-fixed-v2.tar.gz
docker save cs720-ai-service:fixed-v2 | gzip > cs720-ai-service-fixed-v2.tar.gz

echo ""
echo "Images saved:"
ls -lh cs720-*.tar.gz
echo ""
echo "To load these images on another machine:"
echo "  docker load < cs720-backend-fixed-v2.tar.gz"
echo "  docker load < cs720-ai-service-fixed-v2.tar.gz"
