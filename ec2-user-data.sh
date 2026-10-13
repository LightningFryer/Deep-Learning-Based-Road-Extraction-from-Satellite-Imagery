#!/bin/bash
set -e

# Redirect output to both console and logfile
exec > >(tee -a /var/log/road-detector-userdata.log | logger -t user-data -s 2>/dev/console) 2>&1

echo "=========================================================="
echo " Starting Road Segmentation Deployment via EC2 User Data"
echo " Date: $(date)"
echo "=========================================================="

# 1. Update system packages
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get upgrade -y
apt-get install -y ca-certificates curl gnupg lsb-release git

# 2. Install official Docker Engine & Docker Compose plugin
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null

apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Enable and start Docker service
systemctl enable docker
systemctl start docker

# Add default ubuntu user to docker group (so sudo is not needed for docker commands)
if id "ubuntu" &>/dev/null; then
    usermod -aG docker ubuntu
fi

# 3. Clone or pull application repository
APP_DIR="/opt/road-segmentation-app"
REPO_URL="https://github.com/LightningFryer/Deep-Learning-Based-Road-Extraction-from-Satellite-Imagery.git"

if [ -d "$APP_DIR" ]; then
    echo "[*] Directory $APP_DIR exists. Pulling latest changes..."
    cd "$APP_DIR"
    git pull origin main || true
else
    echo "[*] Cloning repository $REPO_URL to $APP_DIR..."
    git clone "$REPO_URL" "$APP_DIR"
    cd "$APP_DIR"
fi

# 4. Build and start the container
echo "[*] Building and starting the Docker container..."
docker compose down || true
docker compose up -d --build

echo "=========================================================="
echo " Deployment Finished Successfully!"
echo " Gradio App running on port 7860"
echo " Access URL: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 || curl -s ifconfig.me):7860"
echo "=========================================================="
