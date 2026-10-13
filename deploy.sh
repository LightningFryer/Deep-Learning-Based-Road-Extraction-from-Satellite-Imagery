#!/usr/bin/env bash
set -e

echo "=========================================================="
echo " Road Extraction App - EC2 Deployment Script"
echo "=========================================================="

# Ensure swap space exists (Crucial for AWS Free Tier t2.micro with 1GB RAM)
if [ ! -f /swapfile ] && [ $(free -m | awk '/^Mem:/{print $2}') -lt 2000 ]; then
    echo "[!] Low RAM detected (<2GB). Setting up 4GB swap space to avoid OOM..."
    sudo fallocate -l 4G /swapfile || sudo dd if=/dev/zero of=/swapfile bs=1M count=4096
    sudo chmod 600 /swapfile
    sudo mkswap /swapfile
    sudo swapon /swapfile
    echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
fi

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "[!] Docker not found. Installing Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    sudo usermod -aG docker "$USER"
    rm get-docker.sh
    echo "[*] Docker installed. Note: if permission denied occurs, run: sudo docker compose up -d"
fi

# Check Docker Compose plugin
if ! docker compose version &> /dev/null; then
    echo "[!] Docker Compose plugin not found. Installing..."
    sudo apt-get update && sudo apt-get install -y docker-compose-plugin
fi

echo "[*] Building and launching Road Extraction container..."
docker compose down || true
docker compose up -d --build

PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || curl -s ifconfig.me 2>/dev/null || echo "<your-ec2-ip>")

echo ""
echo "=========================================================="
echo "✅ App deployed successfully!"
echo "🌐 Gradio Web Interface: http://${PUBLIC_IP}:7860"
echo "📊 Check container status: docker compose ps"
echo "📜 View live logs:       docker compose logs -f"
echo "⏹️ Stop application:     docker compose down"
echo "=========================================================="
