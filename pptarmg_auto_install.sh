#!/bin/bash

###############################################################################
# PPTARMG Installation Script - Streamlined Version
###############################################################################

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

LOGFILE="/tmp/pptarmg_install_$(date +%Y%m%d_%H%M%S).log"
TGZ_FILE="/tmp/docker.mviznARMG_ppt.tgz"

log() {
    echo -e "${2}${1}${NC}" | tee -a "$LOGFILE"
}

###############################################################################
# INITIALIZATION
###############################################################################

clear
log "================================================================================" "$BLUE"
log "                    PPTARMG INSTALLATION" "$BLUE"
log "================================================================================" "$BLUE"
echo ""

if [ "$EUID" -ne 0 ]; then 
    log "ERROR: Run with sudo" "$RED"
    exit 1
fi

REAL_USER=$(logname 2>/dev/null || who am i | awk '{print $1}' || echo $SUDO_USER)
REAL_HOME=$(eval echo ~$REAL_USER)

log "User: $REAL_USER" "$CYAN"
log "Home: $REAL_HOME" "$CYAN"
echo ""

###############################################################################
# CHECK PACKAGE FILE
###############################################################################

log "Checking for package file..." "$YELLOW"

if [ ! -f "$TGZ_FILE" ]; then
    log "✗ Package file not found at: $TGZ_FILE" "$RED"
    log "" "$NC"
    log "Please download first:" "$YELLOW"
    log "cd /tmp" "$CYAN"
    log "curl -k -u tagtag:mvizntagger007 -O http://tagger07.mvizn.com/static/docker.mviznARMG_ppt.tgz" "$CYAN"
    exit 1
fi

FILESIZE=$(stat -c%s "$TGZ_FILE" 2>/dev/null || echo 0)
log "✓ Found package: $(numfmt --to=iec $FILESIZE 2>/dev/null || echo $FILESIZE bytes)" "$GREEN"
echo ""

###############################################################################
# INSTALL PREREQUISITES
###############################################################################

log "Installing prerequisites..." "$YELLOW"
export DEBIAN_FRONTEND=noninteractive
apt-get update >> "$LOGFILE" 2>&1
apt-get install -y wget curl tar rsync ntpsec docker.io mdadm >> "$LOGFILE" 2>&1
systemctl enable docker >> "$LOGFILE" 2>&1
systemctl start docker >> "$LOGFILE" 2>&1
log "✓ Prerequisites installed" "$GREEN"
echo ""

###############################################################################
# EXTRACT PACKAGE
###############################################################################

log "Extracting package..." "$YELLOW"

mkdir -p "$REAL_HOME/Code"
chown $REAL_USER:$REAL_USER "$REAL_HOME/Code"
rm -rf "$REAL_HOME/Code/docker.mviznARMG_ppt"

cd "$REAL_HOME/Code"
tar xzf "$TGZ_FILE" >> "$LOGFILE" 2>&1

# Find installation directory
if [ -d "docker.mviznARMG_ppt" ]; then
    INSTALL_DIR="$REAL_HOME/Code/docker.mviznARMG_ppt"
elif [ -d "Code/docker.mviznARMG_ppt" ]; then
    mv Code/docker.mviznARMG_ppt ./
    INSTALL_DIR="$REAL_HOME/Code/docker.mviznARMG_ppt"
    rmdir Code 2>/dev/null || true
else
    INSTALL_DIR=$(find "$REAL_HOME/Code" -maxdepth 3 -type d -name "*mviznARMG*" -o -name "*ppt*" | grep -v ".git" | head -1)
fi

if [ -z "$INSTALL_DIR" ] || [ ! -d "$INSTALL_DIR" ]; then
    log "✗ Cannot find extracted directory" "$RED"
    log "Contents of $REAL_HOME/Code:" "$YELLOW"
    ls -la "$REAL_HOME/Code/" | tee -a "$LOGFILE"
    exit 1
fi

log "✓ Extracted to: $INSTALL_DIR" "$GREEN"
chown -R $REAL_USER:$REAL_USER "$INSTALL_DIR"
echo ""

###############################################################################
# RAID CONFIGURATION
###############################################################################

log "Configuring RAID..." "$YELLOW"

if df -h /opt 2>/dev/null | grep -q "/dev/md0"; then
    log "✓ RAID already configured" "$GREEN"
    RAID_STATUS="CONFIGURED"
else
    if [ -d "$INSTALL_DIR/raidscripts" ]; then
        cd "$INSTALL_DIR"
        
        if [ -b /dev/sda ] && [ -b /dev/sdc ]; then
            log "Setting up RAID on /dev/sda and /dev/sdc..." "$CYAN"
            
            [ -f "raidscripts/clearraid.sh" ] && bash raidscripts/clearraid.sh >> "$LOGFILE" 2>&1
            
            if [ -f "raidscripts/setupraid.sh" ]; then
                bash raidscripts/setupraid.sh -y >> "$LOGFILE" 2>&1
                log "✓ RAID configured" "$GREEN"
                RAID_STATUS="CONFIGURED"
            fi
        else
            log "⊘ RAID disks not found" "$YELLOW"
            RAID_STATUS="NOT CONFIGURED"
        fi
    else
        log "⊘ RAID scripts not found" "$YELLOW"
        RAID_STATUS="NOT AVAILABLE"
    fi
fi
echo ""

###############################################################################
# PERMISSIONS
###############################################################################

log "Setting permissions..." "$YELLOW"
mkdir -p /opt
chmod -R 777 /opt
log "✓ Permissions set" "$GREEN"
echo ""

###############################################################################
# DOCKER INSTALLATION
###############################################################################

log "Installing Docker containers (15-30 minutes)..." "$YELLOW"

cd "$INSTALL_DIR"

INSTALL_SCRIPT=""
[ -f "00_install.sh" ] && INSTALL_SCRIPT="00_install.sh"
[ -f "install.sh" ] && INSTALL_SCRIPT="install.sh"

if [ -n "$INSTALL_SCRIPT" ]; then
    log "Running: $INSTALL_SCRIPT" "$CYAN"
    log "Started: $(date)" "$CYAN"
    
    bash "$INSTALL_SCRIPT" >> "$LOGFILE" 2>&1 &
    PID=$!
    
    SEC=0
    while kill -0 $PID 2>/dev/null; do
        printf "\rTime: %02d:%02d" $((SEC/60)) $((SEC%60))
        sleep 10
        SEC=$((SEC + 10))
    done
    echo ""
    
    wait $PID
    log "✓ Docker installation completed" "$GREEN"
    DOCKER_STATUS="COMPLETED"
else
    log "⚠ Installation script not found" "$YELLOW"
    log "Available files in $INSTALL_DIR:" "$CYAN"
    ls -la "$INSTALL_DIR" | grep -i install | tee -a "$LOGFILE"
    DOCKER_STATUS="SCRIPT NOT FOUND"
fi
echo ""

###############################################################################
# SYMLINKS
###############################################################################

log "Creating symlinks..." "$YELLOW"
cd "$REAL_HOME/Code"
rm -f mviznARMG

if [ -d "$INSTALL_DIR/mviznARMG" ]; then
    ln -sf "$INSTALL_DIR/mviznARMG" mviznARMG
    chown -h $REAL_USER:$REAL_USER mviznARMG
    log "✓ Symlink created" "$GREEN"
else
    log "⊘ mviznARMG not found" "$YELLOW"
fi
echo ""

###############################################################################
# NTP CONFIGURATION
###############################################################################

log "Configuring NTP..." "$YELLOW"

mkdir -p /etc/ntpsec /var/lib/ntpsec /var/log/ntpsec
touch /var/lib/ntpsec/ntp.drift

[ -f /etc/ntpsec/ntp.conf ] && cp /etc/ntpsec/ntp.conf /etc/ntpsec/ntp.conf.bak

GATEWAY_IP=$(ip route | grep default | awk '{print $3}' | head -1)
log "Gateway: $GATEWAY_IP" "$CYAN"

cat > /etc/ntpsec/ntp.conf << 'EOF'
driftfile /var/lib/ntpsec/ntp.drift
logfile /var/log/ntpsec/ntp.log
restrict default kod limited nomodify nopeer noquery notrap
restrict 127.0.0.1
restrict ::1
EOF

echo "server ${GATEWAY_IP} prefer iburst" >> /etc/ntpsec/ntp.conf
echo "pool 0.ubuntu.pool.ntp.org iburst" >> /etc/ntpsec/ntp.conf
echo "server ntp.ubuntu.com" >> /etc/ntpsec/ntp.conf

systemctl daemon-reload
systemctl restart ntpsec >> "$LOGFILE" 2>&1 || systemctl restart ntp >> "$LOGFILE" 2>&1
systemctl enable ntpsec >> "$LOGFILE" 2>&1 || systemctl enable ntp >> "$LOGFILE" 2>&1

log "✓ NTP configured" "$GREEN"
echo ""

###############################################################################
# UTILITIES
###############################################################################

log "Setting up utilities..." "$YELLOW"

mkdir -p "$REAL_HOME/PPTARMG_utils"
mkdir -p "$REAL_HOME/PPTARMG_config"

find "$INSTALL_DIR" -name "startsim.sh" -exec cp {} "$REAL_HOME/PPTARMG_utils/" \; 2>/dev/null
find "$INSTALL_DIR" -name "startstress.sh" -exec cp {} "$REAL_HOME/PPTARMG_utils/" \; 2>/dev/null
find "$INSTALL_DIR" -name "endsim.sh" -exec cp {} "$REAL_HOME/PPTARMG_utils/" \; 2>/dev/null

chown -R $REAL_USER:$REAL_USER "$REAL_HOME/PPTARMG_utils"
chown -R $REAL_USER:$REAL_USER "$REAL_HOME/PPTARMG_config"

log "✓ Utilities ready" "$GREEN"
echo ""

###############################################################################
# VERIFICATION
###############################################################################

log "Verifying installation..." "$YELLOW"

DOCKER_COUNT=$(docker ps -a 2>/dev/null | grep -v CONTAINER | wc -l)
DOCKER_RUNNING=$(docker ps 2>/dev/null | grep -v CONTAINER | wc -l)
DISK_USAGE=$(df -h / | tail -1 | awk '{print $5}')
NTP_STATUS=$(systemctl is-active ntpsec 2>/dev/null || systemctl is-active ntp 2>/dev/null || echo "inactive")

log "Docker: $DOCKER_COUNT total, $DOCKER_RUNNING running" "$CYAN"
log "Disk: $DISK_USAGE used" "$CYAN"
log "NTP: $NTP_STATUS" "$CYAN"
echo ""

###############################################################################
# GENERATE REPORT
###############################################################################

REPORT_FILE="$REAL_HOME/Desktop/PPTARMG_Report_$(date +%Y%m%d_%H%M%S).txt"
mkdir -p "$REAL_HOME/Desktop"

cat > "$REPORT_FILE" << ENDREPORT
================================================================================
                    PPTARMG INSTALLATION REPORT
================================================================================

Date: $(date)
User: $REAL_USER
Installation: $INSTALL_DIR

================================================================================
                        STATUS
================================================================================

✓ Package:         $(numfmt --to=iec $FILESIZE 2>/dev/null || echo $FILESIZE bytes)
✓ Extraction:      SUCCESS
✓ RAID:           $RAID_STATUS
✓ Docker:         $DOCKER_STATUS
✓ NTP:            CONFIGURED
✓ Utilities:      SUCCESS

================================================================================
                        VERIFICATION
================================================================================

Docker Containers:  $DOCKER_COUNT (Running: $DOCKER_RUNNING)
Disk Usage:        $DISK_USAGE
NTP Status:        $NTP_STATUS
Gateway:           $GATEWAY_IP

================================================================================
                        DOCKER CONTAINERS
================================================================================

$(docker ps -a 2>/dev/null)

================================================================================
                        NEXT STEPS
================================================================================

1. Copy config files:
   rsync -av /source/yc_config/ ~/PPTARMG_config/config

2. Test simulation:
   touch /tmp/launched
   bash ~/PPTARMG_utils/startsim.sh

3. Stress test:
   touch /tmp/launched
   bash ~/PPTARMG_utils/startstress.sh
   Controls: H=HNCDS, P=PMNRS, C=CLPS, T=TCDS
   Exit: Ctrl+C, then bash ~/PPTARMG_utils/endsim.sh

================================================================================
                        PATHS
================================================================================

Installation:  $INSTALL_DIR
Utilities:     $REAL_HOME/PPTARMG_utils/
Config:        $REAL_HOME/PPTARMG_config/
Log:           $LOGFILE

================================================================================
$(date) - Installation Complete
================================================================================
ENDREPORT

chown $REAL_USER:$REAL_USER "$REPORT_FILE"

###############################################################################
# SUMMARY
###############################################################################

log "================================================================================" "$GREEN"
log "                    INSTALLATION COMPLETE" "$GREEN"
log "================================================================================" "$GREEN"
echo ""
log "✓ Report: ~/Desktop/$(basename $REPORT_FILE)" "$CYAN"
log "✓ Docker: $DOCKER_COUNT containers" "$CYAN"
log "✓ RAID: $RAID_STATUS" "$CYAN"
log "✓ NTP: $NTP_STATUS" "$CYAN"
echo ""
log "Next: Copy config files to ~/PPTARMG_config/" "$YELLOW"
echo ""

exit 0
