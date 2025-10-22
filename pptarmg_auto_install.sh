#!/bin/bash

###############################################################################
# PPTARMG Installation Script - Manual Download Required
###############################################################################

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

LOGFILE="/tmp/pptarmg_install_$(date +%Y%m%d_%H%M%S).log"
REPORT_FILE="$HOME/Desktop/PPTARMG_Installation_Report_$(date +%Y%m%d_%H%M%S).txt"
TGZ_FILE="/tmp/docker.mviznARMG_ppt.tgz"

log() {
    echo -e "${2}${1}${NC}" | tee -a "$LOGFILE"
}

###############################################################################
# START
###############################################################################

clear
log "========================================" "$BLUE"
log "  PPTARMG INSTALLATION" "$BLUE"
log "========================================" "$BLUE"
echo ""

if [ "$EUID" -ne 0 ]; then 
    log "ERROR: Run with sudo" "$RED"
    exit 1
fi

REAL_USER=$(who am i | awk '{print $1}')
REAL_HOME=$(eval echo ~$REAL_USER)

###############################################################################
# STEP 1: MANUAL DOWNLOAD INSTRUCTIONS
###############################################################################

log "========================================" "$YELLOW"
log "  STEP 1: DOWNLOAD PACKAGE" "$YELLOW"
log "========================================" "$YELLOW"
echo ""

# Check if file already exists
if [ -f "$TGZ_FILE" ]; then
    FILESIZE=$(stat -c%s "$TGZ_FILE" 2>/dev/null)
    if [ "$FILESIZE" -gt 100000 ]; then
        log "✓ Package already downloaded ($FILESIZE bytes)" "$GREEN"
        SKIP_DOWNLOAD=1
    else
        log "✗ Existing file too small, needs re-download" "$RED"
        rm -f "$TGZ_FILE"
        SKIP_DOWNLOAD=0
    fi
else
    SKIP_DOWNLOAD=0
fi

if [ $SKIP_DOWNLOAD -eq 0 ]; then
    log "Download the package manually:" "$CYAN"
    echo ""
    log "METHOD 1 - Using wget (Recommended):" "$GREEN"
    log "  cd /tmp" "$MAGENTA"
    log "  wget --no-check-certificate --user=tagtag --password=mvizntagger007 \\" "$MAGENTA"
    log "    http://tagger07.mvizn.com/static/docker.mviznARMG_ppt.tgz" "$MAGENTA"
    echo ""
    log "METHOD 2 - Using Browser:" "$GREEN"
    log "  1. Open: http://tagger07.mvizn.com/static/docker.mviznARMG_ppt.tgz" "$MAGENTA"
    log "  2. Login - User: tagtag  Pass: mvizntagger007" "$MAGENTA"
    log "  3. Save to: /tmp/docker.mviznARMG_ppt.tgz" "$MAGENTA"
    echo ""
    log "Expected file size: 500MB - 2GB" "$YELLOW"
    log "Current location should be: $TGZ_FILE" "$YELLOW"
    echo ""
    log "========================================" "$CYAN"
    log "Press ENTER after download completes..." "$CYAN"
    log "Or press Ctrl+C to exit" "$CYAN"
    log "========================================" "$CYAN"
    read -r
    
    # Verify download
    if [ ! -f "$TGZ_FILE" ]; then
        log "✗ File not found at $TGZ_FILE" "$RED"
        log "Please download and try again" "$RED"
        exit 1
    fi
    
    FILESIZE=$(stat -c%s "$TGZ_FILE" 2>/dev/null)
    log "File size: $FILESIZE bytes" "$CYAN"
    
    if [ "$FILESIZE" -lt 100000 ]; then
        log "✗ File too small (should be >100MB)" "$RED"
        log "Download may have failed. Please try again." "$RED"
        exit 1
    fi
    
    log "✓ Package downloaded successfully!" "$GREEN"
fi

###############################################################################
# PREREQUISITES
###############################################################################

echo ""
log "========================================" "$YELLOW"
log "  STEP 2: INSTALLING PREREQUISITES" "$YELLOW"
log "========================================" "$YELLOW"

export DEBIAN_FRONTEND=noninteractive
apt-get update >> "$LOGFILE" 2>&1
apt-get install -y wget tar rsync ntpsec curl docker.io >> "$LOGFILE" 2>&1

if [ $? -eq 0 ]; then
    log "✓ Prerequisites installed" "$GREEN"
else
    log "✗ Some prerequisites failed (check log)" "$YELLOW"
fi

systemctl enable docker >> "$LOGFILE" 2>&1
systemctl start docker >> "$LOGFILE" 2>&1

###############################################################################
# EXTRACT
###############################################################################

echo ""
log "========================================" "$YELLOW"
log "  STEP 3: EXTRACTING PACKAGE" "$YELLOW"
log "========================================" "$YELLOW"

mkdir -p "$REAL_HOME/Code" >> "$LOGFILE" 2>&1
chown -R $REAL_USER:$REAL_USER "$REAL_HOME/Code" >> "$LOGFILE" 2>&1

rm -rf "$REAL_HOME/Code/docker.mviznARMG_ppt" >> "$LOGFILE" 2>&1

cd "$REAL_HOME/Code" || exit 1
log "Extracting to: $(pwd)" "$CYAN"

tar xzf "$TGZ_FILE" >> "$LOGFILE" 2>&1

if [ $? -eq 0 ]; then
    log "✓ Extraction completed" "$GREEN"
    
    # Find installation directory
    if [ -d "$REAL_HOME/Code/docker.mviznARMG_ppt" ]; then
        INSTALL_DIR="$REAL_HOME/Code/docker.mviznARMG_ppt"
    elif [ -d "$REAL_HOME/Code/Code/docker.mviznARMG_ppt" ]; then
        INSTALL_DIR="$REAL_HOME/Code/Code/docker.mviznARMG_ppt"
    else
        INSTALL_DIR=$(find "$REAL_HOME/Code" -maxdepth 3 -type d -name "*mviznARMG*" | head -1)
    fi
    
    if [ -z "$INSTALL_DIR" ]; then
        log "✗ Cannot find extracted directory" "$RED"
        exit 1
    fi
    
    log "Install directory: $INSTALL_DIR" "$CYAN"
    chown -R $REAL_USER:$REAL_USER "$INSTALL_DIR" >> "$LOGFILE" 2>&1
else
    log "✗ Extraction failed" "$RED"
    exit 1
fi

###############################################################################
# RAID
###############################################################################

echo ""
log "========================================" "$YELLOW"
log "  STEP 4: RAID CONFIGURATION" "$YELLOW"
log "========================================" "$YELLOW"

if df -h /opt 2>/dev/null | grep -q "/dev/md0"; then
    log "✓ RAID already configured" "$GREEN"
    RAID_SETUP="ALREADY CONFIGURED"
else
    if [ -d "$INSTALL_DIR/raidscripts" ] && [ -b /dev/sda ] && [ -b /dev/sdc ]; then
        log "Setting up RAID..." "$CYAN"
        
        cd "$INSTALL_DIR" || exit 1
        
        [ -f "raidscripts/clearraid.sh" ] && bash raidscripts/clearraid.sh >> "$LOGFILE" 2>&1
        
        if [ -f "raidscripts/setupraid.sh" ]; then
            bash raidscripts/setupraid.sh -y >> "$LOGFILE" 2>&1
            log "✓ RAID setup completed" "$GREEN"
            RAID_SETUP="CONFIGURED"
        fi
    else
        log "⊘ RAID not required" "$YELLOW"
        RAID_SETUP="NOT CONFIGURED"
    fi
fi

###############################################################################
# PERMISSIONS
###############################################################################

echo ""
log "========================================" "$YELLOW"
log "  STEP 5: SETTING PERMISSIONS" "$YELLOW"
log "========================================" "$YELLOW"

mkdir -p /opt >> "$LOGFILE" 2>&1
chmod -R 777 /opt >> "$LOGFILE" 2>&1
log "✓ Permissions set" "$GREEN"

###############################################################################
# DOCKER INSTALLATION
###############################################################################

echo ""
log "========================================" "$YELLOW"
log "  STEP 6: DOCKER INSTALLATION" "$YELLOW"
log "========================================" "$YELLOW"
log "This will take 15-30 minutes..." "$CYAN"
echo ""

cd "$INSTALL_DIR" || exit 1

INSTALL_SCRIPT=""
[ -f "00_install.sh" ] && INSTALL_SCRIPT="00_install.sh"
[ -f "install.sh" ] && INSTALL_SCRIPT="install.sh"

if [ -n "$INSTALL_SCRIPT" ]; then
    log "Running: $INSTALL_SCRIPT" "$CYAN"
    
    bash "$INSTALL_SCRIPT" >> "$LOGFILE" 2>&1 &
    PID=$!
    
    COUNT=0
    while kill -0 $PID 2>/dev/null; do
        printf "."
        sleep 5
        COUNT=$((COUNT + 1))
        if [ $((COUNT % 12)) -eq 0 ]; then
            printf " [%d min] " $((COUNT / 12))
        fi
    done
    echo ""
    
    wait $PID
    log "✓ Docker installation completed" "$GREEN"
    DOCKER_STATUS="COMPLETED"
else
    log "✗ Installation script not found" "$RED"
    DOCKER_STATUS="NOT FOUND"
fi

###############################################################################
# SYMLINKS
###############################################################################

echo ""
log "========================================" "$YELLOW"
log "  STEP 7: CREATING SYMLINKS" "$YELLOW"
log "========================================" "$YELLOW"

cd "$REAL_HOME/Code" || exit 1
rm -f mviznARMG

if [ -d "$INSTALL_DIR/mviznARMG" ]; then
    ln -sf "$INSTALL_DIR/mviznARMG" mviznARMG
    chown -h $REAL_USER:$REAL_USER mviznARMG
    log "✓ Symlink created" "$GREEN"
else
    log "⊘ mviznARMG directory not found" "$YELLOW"
fi

###############################################################################
# NTP
###############################################################################

echo ""
log "========================================" "$YELLOW"
log "  STEP 8: NTP CONFIGURATION" "$YELLOW"
log "========================================" "$YELLOW"

mkdir -p /etc/ntpsec 2>/dev/null
[ -f /etc/ntpsec/ntp.conf ] && cp /etc/ntpsec/ntp.conf /etc/ntpsec/ntp.conf.bak 2>/dev/null

GATEWAY_IP=$(ip route | grep default | awk '{print $3}' | head -1)
log "Gateway: $GATEWAY_IP" "$CYAN"

cat > /etc/ntpsec/ntp.conf << 'NTPEOF'
driftfile /var/lib/ntpsec/ntp.drift
logfile /var/log/ntpsec/ntp.log
restrict default kod limited nomodify nopeer noquery notrap
restrict 127.0.0.1
restrict ::1
NTPEOF

echo "server ${GATEWAY_IP} prefer iburst" >> /etc/ntpsec/ntp.conf
echo "pool 0.ubuntu.pool.ntp.org iburst" >> /etc/ntpsec/ntp.conf
echo "server ntp.ubuntu.com" >> /etc/ntpsec/ntp.conf

systemctl restart ntpsec >> "$LOGFILE" 2>&1 || systemctl restart ntp >> "$LOGFILE" 2>&1
systemctl enable ntpsec >> "$LOGFILE" 2>&1 || systemctl enable ntp >> "$LOGFILE" 2>&1

log "✓ NTP configured" "$GREEN"

###############################################################################
# UTILITIES
###############################################################################

echo ""
log "========================================" "$YELLOW"
log "  STEP 9: SETTING UP UTILITIES" "$YELLOW"
log "========================================" "$YELLOW"

mkdir -p "$REAL_HOME/PPTARMG_utils"
mkdir -p "$REAL_HOME/PPTARMG_config"

find "$INSTALL_DIR" -name "startsim.sh" -exec cp {} "$REAL_HOME/PPTARMG_utils/" \; 2>/dev/null
find "$INSTALL_DIR" -name "startstress.sh" -exec cp {} "$REAL_HOME/PPTARMG_utils/" \; 2>/dev/null
find "$INSTALL_DIR" -name "endsim.sh" -exec cp {} "$REAL_HOME/PPTARMG_utils/" \; 2>/dev/null

chown -R $REAL_USER:$REAL_USER "$REAL_HOME/PPTARMG_utils"
chown -R $REAL_USER:$REAL_USER "$REAL_HOME/PPTARMG_config"

log "✓ Utilities setup completed" "$GREEN"

###############################################################################
# VERIFICATION
###############################################################################

echo ""
log "========================================" "$YELLOW"
log "  STEP 10: VERIFICATION" "$YELLOW"
log "========================================" "$YELLOW"

DOCKER_COUNT=$(docker ps -a 2>/dev/null | grep -v CONTAINER | wc -l)
DISK_USAGE=$(df -h / | tail -1 | awk '{print $5}')
OPT_MOUNT=$(df -h /opt 2>/dev/null | tail -1 | awk '{print $1}')
NTP_ACTIVE=$(systemctl is-active ntpsec 2>/dev/null || systemctl is-active ntp 2>/dev/null || echo "inactive")

log "Docker containers: $DOCKER_COUNT" "$CYAN"
log "Disk usage: $DISK_USAGE" "$CYAN"
log "NTP status: $NTP_ACTIVE" "$CYAN"

###############################################################################
# REPORT
###############################################################################

mkdir -p "$REAL_HOME/Desktop" 2>/dev/null

cat > "$REPORT_FILE" << ENDREPORT
================================================================================
                    PPTARMG INSTALLATION REPORT
================================================================================

Date: $(date)
User: $REAL_USER
Installation: $INSTALL_DIR

================================================================================
                        INSTALLATION STATUS
================================================================================

✓ Package Download:      SUCCESS ($FILESIZE bytes)
✓ Package Extraction:    SUCCESS
✓ RAID Configuration:    $RAID_SETUP
✓ Docker Installation:   $DOCKER_STATUS
✓ NTP Configuration:     SUCCESS
✓ Utilities Setup:       SUCCESS

================================================================================
                        SYSTEM VERIFICATION
================================================================================

Docker Containers:       $DOCKER_COUNT
Root Disk Usage:         $DISK_USAGE
/opt Mount:             $OPT_MOUNT
NTP Service:            $NTP_ACTIVE
Gateway IP:             $GATEWAY_IP

================================================================================
                        DOCKER CONTAINERS
================================================================================

$(docker ps -a 2>/dev/null)

================================================================================
                        DISK USAGE
================================================================================

$(df -h 2>/dev/null)

================================================================================
                        RAID STATUS
================================================================================

$(cat /proc/mdstat 2>/dev/null || echo "No RAID configured")

================================================================================
                        NEXT STEPS
================================================================================

1. COPY CONFIGURATION FILES:
   rsync -av /source/path/yc_config/ ~/PPTARMG_config/config
   
   Example:
   rsync -av /media/mvizn/hdd1/configbackup/yc7409/config/ ~/PPTARMG_config/config

2. RUN SIMULATION (in Office):
   touch /tmp/launched
   bash ~/PPTARMG_utils/startsim.sh

3. RUN STRESS TEST (in Office):
   touch /tmp/launched
   bash ~/PPTARMG_utils/startstress.sh
   
   Controls: H=HNCDS, P=PMNRS, C=CLPS, T=TCDS
   Exit: Ctrl+C then bash ~/PPTARMG_utils/endsim.sh

4. ENABLE SSH (if needed):
   sudo systemctl enable ssh
   sudo systemctl start ssh

================================================================================
                        INSTALLATION COMPLETE
================================================================================

Report saved: ~/Desktop/$(basename $REPORT_FILE)
Log file: $LOGFILE

$(date)
================================================================================
ENDREPORT

chown $REAL_USER:$REAL_USER "$REPORT_FILE" 2>/dev/null
cp "$REPORT_FILE" "$REAL_HOME/Desktop/" 2>/dev/null

###############################################################################
# COMPLETE
###############################################################################

echo ""
log "========================================" "$GREEN"
log "     INSTALLATION COMPLETE" "$GREEN"
log "========================================" "$GREEN"
echo ""
log "✓ Report: ~/Desktop/$(basename $REPORT_FILE)" "$CYAN"
log "✓ Docker: $DOCKER_COUNT containers installed" "$CYAN"
log "✓ RAID: $RAID_SETUP" "$CYAN"
log "✓ NTP: $NTP_ACTIVE" "$CYAN"
echo ""
log "Next: Copy config files to ~/PPTARMG_config/" "$YELLOW"
echo ""

exit 0
