#!/usr/bin/env bash
set -euo pipefail

U="${SUDO_USER:-$USER}"
HOME_DIR="$(eval echo "~$U")"
DOCS_DIR="$HOME_DIR/Documents"
REPORT="$DOCS_DIR/system_validation_$(date +%Y%m%d_%H%M%S).txt"
LSHW_HTML="$DOCS_DIR/lshw.html"
export DEBIAN_FRONTEND=noninteractive

mkdir -p "$DOCS_DIR"

apt-get update -y
apt-get upgrade -y

apt-get install -y \
  xdotool meld expect ntp ntpsec mdadm \
  openssh-server git vim screen python3-pip \
  mosquitto default-jre default-jdk ssh htop ffmpeg \
  unattended-upgrades jupyter-core ca-certificates curl gpg lshw \
  linux-headers-$(uname -r) build-essential ubuntu-drivers-common

if ! command -v snap >/dev/null 2>&1; then
  apt-get install -y snapd
fi
snap install sublime-text --classic || true

install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | tee /etc/apt/keyrings/docker.asc >/dev/null
chmod a+r /etc/apt/keyrings/docker.asc
CODENAME="$(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")"
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu ${CODENAME} stable" > /etc/apt/sources.list.d/docker.list
apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
getent group docker >/dev/null || groupadd docker
usermod -aG docker "$U" || true
systemctl enable --now docker

if ! command -v nvidia-smi >/dev/null 2>&1; then
  add-apt-repository ppa:graphics-drivers/ppa -y
  apt-get update -y
  ubuntu-drivers autoinstall -q || true
fi

install -m 0755 -d /usr/share/keyrings
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
curl -fsSL https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list \
 | sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' \
 | tee /etc/apt/sources.list.d/nvidia-container-toolkit.list >/dev/null
apt-get update -y
apt-get install -y nvidia-container-toolkit nvidia-container-runtime
/usr/bin/nvidia-ctk runtime configure --runtime=docker --set-as-default || true
/usr/bin/nvidia-ctk cdi generate --output=/etc/cdi/nvidia.yaml || true
systemctl restart docker

{
  echo "==== System Verification ($(date)) ===="
  echo "User: $U"
  echo "Host: $(hostname)"
  echo
  echo "== OS & Kernel =="
  lsb_release -a 2>/dev/null || true
  uname -r
  echo
  echo "== Core Tools =="
  xdotool --version || true
  git --version || true
  python3 --version || true
  java -version 2>&1 | head -n1 || true
  htop --version | head -n1 || true
  echo
  echo "== Docker =="
  docker --version
  docker compose version || true
  echo "-- hello-world --"
  docker run --rm hello-world 2>&1 | sed -n '1,20p' || true
  echo
  echo "== NVIDIA (host) =="
  if command -v nvidia-smi >/dev/null 2>&1; then
    nvidia-smi || true
  else
    echo "nvidia-smi not present (driver may require reboot)."
  fi
  echo
  echo "== NVIDIA (in container) =="
  docker run --rm --gpus all nvidia/cuda:12.4.1-base-ubuntu24.04 nvidia-smi || true
} | tee "$REPORT" >/dev/null

lshw -html > "$LSHW_HTML" || true
chown "$U:$U" "$REPORT" "$LSHW_HTML" || true
chmod 644 "$REPORT" "$LSHW_HTML" || true

echo
echo "Report: $REPORT"
echo "Hardware HTML: $LSHW_HTML"
echo "Note: If you were newly added to the 'docker' group or GPU drivers were installed, reboot is recommended."
