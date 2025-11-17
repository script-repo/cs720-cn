# CS720 Deployment Guide

## Quick Start

All configuration files are now in Git and ready to push to GitHub.

### Files Ready for GitHub:
- ✅ `docker-compose.yml` - Main configuration
- ✅ `nginx.conf` - Nginx proxy configuration
- ✅ `install-cs720.sh` - Installation script
- ✅ `README.md` - Project documentation
- ✅ `.gitignore` - Git ignore rules

## Push to GitHub

```bash
# 1. Create a new repo on GitHub, then:
git remote add origin https://github.com/YOUR_USERNAME/cs720-deployment.git
git branch -M main
git push -u origin main
```

## Save Docker Images

### Option 1: Push to GitHub Container Registry

```bash
# 1. Create a GitHub Personal Access Token with package permissions
# 2. Login to GHCR:
echo $GITHUB_TOKEN | docker login ghcr.io -u YOUR_USERNAME --password-stdin

# 3. Run the push script:
./push-images.sh YOUR_USERNAME
```

### Option 2: Save Locally (Backup)

```bash
# Save images to tar.gz files:
./save-images-local.sh

# This creates:
# - cs720-backend-fixed-v2.tar.gz (~95MB)
# - cs720-ai-service-fixed-v2.tar.gz (~80MB)

# Copy these to a safe location!
```

## What's Been Fixed

### Backend (cs720-backend:fixed-v2)
1. **NAI Health Check Fix**
   - Removed proxy availability requirement
   - Fixed URL replacement regex to avoid hostname corruption

2. **Empty Body Handling**
   - Custom JSON parser accepts empty POST bodies
   - Fixes UI ETL sync button

### AI Service (cs720-ai-service:fixed-v2)
1. **ES Module Imports**
   - Added .js extensions to all imports
   - Applied via startup script

## Restore on New Machine

```bash
# 1. Clone the repo
git clone https://github.com/YOUR_USERNAME/cs720-deployment.git
cd cs720-deployment

# 2. Load Docker images
# Either pull from GHCR:
docker pull ghcr.io/YOUR_USERNAME/cs720-backend:fixed-v2
docker pull ghcr.io/YOUR_USERNAME/cs720-ai-service:fixed-v2

# Or load from local files:
docker load < cs720-backend-fixed-v2.tar.gz
docker load < cs720-ai-service-fixed-v2.tar.gz

# 3. Start services
docker-compose up -d
```

## Current State

- **Data Imported**: 1,653 records from 3 clients
- **Services Running**: All healthy except Ollama (known healthcheck issue, but functional)
- **UI Working**: Frontend at http://10.38.38.107:3000
- **ETL Working**: Sync button functional from UI

## Data Location

- CSV Files: `/mnt/nfs/datadump/data` (mounted read-only)
- Database: `/app/.cs720/cs720.db` (in backend container)
- To backup database: `docker cp cs720-backend:/app/.cs720/cs720.db ./backup.db`
