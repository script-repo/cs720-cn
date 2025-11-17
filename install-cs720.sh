#!/usr/bin/env bash
set -euo pipefail

echo "=== cs720 environment bootstrap for Rocky Linux ==="

#----------------------------------------
# 0. Sanity checks
#----------------------------------------
if [[ $EUID -ne 0 ]]; then
  echo "Please run this script as root (e.g. sudo bash $0)" >&2
  exit 1
fi

if [[ -r /etc/os-release ]]; then
  . /etc/os-release
  if [[ "${ID:-}" != "rocky" ]]; then
    echo "WARNING: This script is intended for Rocky Linux. Detected: ${ID:-unknown}" >&2
  fi
fi

#----------------------------------------
# 1. System update & basic tools
#----------------------------------------
echo ">>> Updating system and installing base tools..."
dnf -y update

# dnf-plugins-core: needed for config-manager
# curl: used for health checks and convenience
dnf -y install dnf-plugins-core curl

#----------------------------------------
# 2. Add Docker CE repo & install Docker
#----------------------------------------
echo ">>> Configuring Docker CE repository..."
if ! dnf repolist | grep -qi docker-ce; then
  dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
fi

echo ">>> Installing Docker Engine and Docker Compose plugin..."
dnf -y install \
  docker-ce \
  docker-ce-cli \
  containerd.io \
  docker-buildx-plugin \
  docker-compose-plugin

#----------------------------------------
# 3. Enable & start Docker service
#----------------------------------------
echo ">>> Enabling and starting Docker service..."
systemctl enable docker
systemctl start docker

#----------------------------------------
# 4. docker-compose compatibility shim
#    (so both `docker compose` and `docker-compose` work)
#----------------------------------------
if ! command -v docker-compose >/dev/null 2>&1; then
  echo ">>> Creating docker-compose wrapper (calls 'docker compose')..."
  cat >/usr/local/bin/docker-compose <<'EOF'
#!/usr/bin/env bash
exec docker compose "$@"
EOF
  chmod +x /usr/local/bin/docker-compose
fi

#----------------------------------------
# 5. Add invoking user to docker group (if applicable)
#----------------------------------------
# This allows running `docker` without sudo after next login.
if ! getent group docker >/dev/null 2>&1; then
  groupadd docker
fi

DEFAULT_USER="${SUDO_USER:-}"
if [[ -n "${DEFAULT_USER}" ]]; then
  echo ">>> Adding user '${DEFAULT_USER}' to 'docker' group..."
  usermod -aG docker "${DEFAULT_USER}"
  ADDED_USER_MSG="User '${DEFAULT_USER}' has been added to the 'docker' group. Log out and back in for this to take effect."
else
  ADDED_USER_MSG="No non-root user detected via SUDO_USER; skipped adding to docker group."
fi

#----------------------------------------
# 6. Quick Docker sanity test
#----------------------------------------
echo ">>> Running Docker hello-world test (can be ignored if it fails behind proxy)..."
if ! docker run --rm hello-world >/dev/null 2>&1; then
  echo "NOTE: 'docker run hello-world' failed. This is often caused by network/proxy issues."
else
  echo "Docker hello-world test succeeded."
fi

#----------------------------------------
# 7. Pull application images (public GHCR)
#----------------------------------------
echo ">>> Pulling cs720 container images from GHCR..."
docker pull ghcr.io/script-repo/cs720-frontend:latest
docker pull ghcr.io/script-repo/cs720-backend:latest
docker pull ghcr.io/script-repo/cs720-proxy:latest
docker pull ghcr.io/script-repo/cs720-ai-service:latest

echo
echo "=== cs720 environment bootstrap complete ==="
echo "${ADDED_USER_MSG}"
echo
echo "Next steps:"
echo "  1) Place your docker-compose.yml in some directory on this VM."
echo "  2) From that directory, run:"
echo "       docker-compose up -d"
echo "     (or: docker compose up -d)"
echo "  3) Verify health endpoints from the VM:"
echo "       curl http://localhost:3000          # Frontend"
echo "       curl http://localhost:3001/health   # Backend"
echo "       curl http://localhost:3002/health   # Proxy"
echo "       curl http://localhost:3003/health   # AI Service"
echo
