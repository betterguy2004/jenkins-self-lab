#!/bin/bash
set -e

echo "==> Update system"
sudo apt-get update -y

echo "==> Install required packages"
sudo apt-get install -y \
  ca-certificates \
  curl \
  gnupg \
  lsb-release \
  apt-transport-https

echo "==> Add Docker GPG key"
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
  | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

echo "==> Add Docker repository"
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" \
  | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

echo "==> Install Docker Engine"
sudo apt-get update -y
sudo apt-get install -y \
  docker-ce \
  docker-ce-cli \
  containerd.io \
  docker-buildx-plugin \
  docker-compose-plugin

echo "==> Enable & start Docker"
sudo systemctl enable docker
sudo systemctl start docker

echo "==> Add current user to docker group"
sudo usermod -aG docker $USER

echo "==> Fix docker.sock permission"
sudo chmod 660 /var/run/docker.sock

echo ""
echo "=================================================="
echo "Docker installed successfully."
echo "IMPORTANT: Logout and login again OR run:"
echo "  newgrp docker"
echo "=================================================="
