# 🚀 AWS EC2 Deployment Guide: Road Extraction & Accessibility Detector

This guide provides step-by-step instructions for deploying the **Satellite Road Extraction Application** to an **AWS EC2** instance using **Docker** and **Gradio**.

---

## 📋 Table of Contents
1. [Prerequisites & Recommended EC2 Specs](#-prerequisites--recommended-ec2-specs)
2. [Option A: 1-Click Automated Deployment (EC2 User Data)](#-option-a-1-click-automated-deployment-via-user-data)
3. [Option B: Manual SSH Deployment](#-option-b-manual-ssh-deployment)
4. [Configuring AWS Security Group (Firewall Rules)](#-configuring-aws-security-group-firewall-rules)
5. [Useful Management Commands](#-useful-management-commands)
6. [Cost Optimization Tips](#-cost-optimization-tips)

---

## ⚙️ Prerequisites & Recommended EC2 Specs

### 1. Recommended EC2 Instance
* **AMI**: `Ubuntu Server 24.04 LTS` (or `22.04 LTS`), 64-bit (x86)
* **Instance Type**:
  * **Recommended (CPU)**: `t3.large` (2 vCPUs, 8 GiB RAM) — Smooth PyTorch CPU inference (~$0.083/hr).
  * **Budget (CPU)**: `t3.medium` (2 vCPUs, 4 GiB RAM) — Works well with batch size 1.
  * **GPU (Accelerated)**: `g4dn.xlarge` (4 vCPUs, 16 GiB RAM, NVIDIA T4 GPU) — Ultra-fast inference (~$0.526/hr).
* **Storage**: **25 GiB to 30 GiB gp3** SSD (needed for Docker layers and PyTorch wheels).

---

## ⚡ Option A: 1-Click Automated Deployment (via User Data)

AWS EC2 allows you to supply a bootstrap script ("User data") that automatically installs Docker, clones the repository, and launches the Gradio container on boot.

### Step 1: Open the AWS Console
1. Navigate to the **EC2 Dashboard** in the AWS Management Console.
2. Click **Launch Instance**.

### Step 2: Configure the Instance
1. **Name**: `road-segmentation-detector`
2. **Application and OS Images (AMI)**: Select **Ubuntu** (Ubuntu Server 24.04 LTS).
3. **Instance Type**: Select **`t3.large`** (or `t3.medium`).
4. **Key pair (login)**: Select an existing key pair or click **Create new key pair** (`.pem` format). Download and save this key safely.
5. **Network settings**:
   * Check **Allow SSH traffic from** -> Select **My IP** (recommended for security).
   * Check **Allow HTTP traffic from the internet** (Port 80).
   * Click **Edit** network settings and add an inbound rule for **Gradio Port 7860**:
     * **Type**: Custom TCP
     * **Port range**: `7860`
     * **Source type**: Anywhere (`0.0.0.0/0`)
6. **Configure Storage**: Change the volume size to **`25 GiB`** (General Purpose SSD `gp3`).

### Step 3: Add User Data Script
1. Scroll down and expand **Advanced details**.
2. Scroll to the bottom to find the **User data** text box.
3. Paste the contents of `ec2-user-data.sh`:

```bash
#!/bin/bash
set -e

exec > >(tee -a /var/log/road-detector-userdata.log | logger -t user-data -s 2>/dev/console) 2>&1

echo "=== Starting Road Segmentation Deployment ==="

export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get upgrade -y
apt-get install -y ca-certificates curl gnupg lsb-release git

# Install Docker
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null

apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

systemctl enable docker
systemctl start docker

if id "ubuntu" &>/dev/null; then
    usermod -aG docker ubuntu
fi

# Clone repo & run container
APP_DIR="/opt/road-segmentation-app"
REPO_URL="https://github.com/LightningFryer/Deep-Learning-Based-Road-Extraction-from-Satellite-Imagery.git"

if [ -d "$APP_DIR" ]; then
    cd "$APP_DIR" && git pull origin main || true
else
    git clone "$REPO_URL" "$APP_DIR"
    cd "$APP_DIR"
fi

docker compose down || true
docker compose up -d --build

echo "=== Deployment Finished! App accessible on port 7860 ==="
```

4. Click **Launch instance**.
5. Wait **3 to 5 minutes** for instance initialization and container build.
6. Copy the **Public IPv4 address** from the EC2 instance summary and open:
   ```text
   http://<YOUR_EC2_PUBLIC_IP>:7860
   ```

---

## 🛠️ Option B: Manual SSH Deployment

If you already launched an EC2 instance or prefer to connect via SSH directly:

### Step 1: Connect to your EC2 Instance
```bash
chmod 400 "path/to/your-key.pem"
ssh -i "path/to/your-key.pem" ubuntu@<YOUR_EC2_PUBLIC_IP>
```

### Step 2: Clone the Repository
```bash
git clone https://github.com/LightningFryer/Deep-Learning-Based-Road-Extraction-from-Satellite-Imagery.git
cd Deep-Learning-Based-Road-Extraction-from-Satellite-Imagery
```

### Step 3: Run the Deployment Script
```bash
chmod +x deploy.sh
./deploy.sh
```

Alternatively, run directly with Docker Compose:
```bash
docker compose up -d --build
```

### Step 4: Open the App
Visit in your web browser:
```text
http://<YOUR_EC2_PUBLIC_IP>:7860
```

---

## 🛡️ Configuring AWS Security Group (Firewall Rules)

Make sure your EC2 Security Group allows inbound traffic on port `7860`:

| Type | Protocol | Port Range | Source | Description |
| :--- | :--- | :--- | :--- | :--- |
| **SSH** | TCP | `22` | `My IP` | Secure terminal access |
| **Custom TCP** | TCP | `7860` | `0.0.0.0/0` | Gradio Web Interface |
| **HTTP** *(Optional)* | TCP | `80` | `0.0.0.0/0` | Web access (if using Nginx) |

---

## 📊 Useful Management Commands

Run these on your EC2 instance via SSH:

* **View live application logs:**
  ```bash
  docker compose logs -f
  ```
* **Check container health status:**
  ```bash
  docker compose ps
  ```
* **Restart the application:**
  ```bash
  docker compose restart
  ```
* **Update to latest code from GitHub:**
  ```bash
  git pull origin main
  docker compose up -d --build
  ```
* **Stop the application:**
  ```bash
  docker compose down
  ```
* **Check user-data boot logs (if Option A was used):**
  ```bash
  tail -f /var/log/road-detector-userdata.log
  ```

---

## 💰 Cost Optimization Tips

1. **Stop Instance When Not in Use**: Stop the instance from AWS Console when you are done testing. You only pay for EBS volume storage (~$2/month for 25GB) while stopped.
2. **Use Spot Instances**: For non-production demos, choose **Request Spot Instances** in AWS Console to save up to **70-80%** on EC2 hourly compute costs.
3. **Elastic IP**: If you plan to stop/start frequently and want to keep the same public IP address, allocate an **Elastic IP** and associate it with your EC2 instance.
