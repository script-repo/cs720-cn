# CS720 Deployment Configuration

This repository contains the deployment configuration for the CS720 platform with custom fixes applied.

## Fixed Container Images

- **cs720-backend:fixed-v2** - Backend with NAI health check fix and empty JSON body handling
- **cs720-ai-service:fixed-v2** - AI service with ES module import fixes

## What's Fixed

### Backend Fixes
1. NAI health check no longer requires proxy to be available
2. Proxy URL replacement uses proper regex to avoid hostname corruption  
3. Custom JSON parser accepts empty request bodies from frontend

### AI Service Fixes
1. ES module imports now include .js extensions
2. Fixed via startup script that patches imports on container start

## Files

- `docker-compose.yml` - Main orchestration file with all services
- `nginx.conf` - Nginx configuration for frontend proxy routing
- `install-cs720.sh` - Installation script for Rocky Linux

## Data

- CSV files mounted from `/mnt/nfs/datadump/data`
- Database at `/app/.cs720/cs720.db` in backend container
- ETL endpoint: `POST /api/sync/etl/trigger`

## Services

- Frontend: http://localhost:3000
- Backend API: http://localhost:3001
- AI Service: http://localhost:3003
- Proxy: http://localhost:3002
- Ollama: http://localhost:11434
