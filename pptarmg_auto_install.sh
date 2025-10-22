#!/bin/bash

###############################################################################
# PPTARMG Automated Installation Script - Robust Version
###############################################################################

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

LOGFILE="/tmp/pptarmg_install_$(date +%Y%m%d_%H%M%S).log"
REPORT_FILE="$HOME/Desktop/PPTARMG_Installation_Report_$(date +%Y%m%d_%H%M%S).txt"

log() {
    echo -e "${2}${1}${NC}" | tee -a "$LOGFILE"
}

check() {
    if [ $? -eq 0 ]; then
        log "✓ $1 - SUCCESS" "$GREEN"
        return 0
    else
        log "✗ $1 - FAILED" "$RED"
        return 1
    fi
}

###############################################################################
# START
###############################################################################

clear
log "========================================" "$BLUE"
log "PPTARMG AUTOMATED INSTALLATION" "$BLUE"
log "========================================" "$BLUE"
echo "" | tee -a "$LOGFILE"

if [ "$EUID" -ne 0 ]; then 
    log "ERROR: Must run with sudo" "$RED"
    exit 1
fi

REAL_USER=$(who am i | awk '{print $1}')
REAL_HOME=$(eval echo ~$REAL_USER)

log "User: $REAL_USER" "$CYAN"
log "Home: $REAL_HOME" "$CYAN"
echo "" | tee -a "$LOGFILE"

###############################################################################
# INSTALL PREREQUISITES
###############################################################################

log "[1/10] Installing prerequisites..." "$YELLOW"
export DEBIAN_FRONTEND=noninteractive
apt-get update >> "$LOGFILE" 2>&1
apt-get install -y wget tar rsync ntpsec curl >> "$LOGFILE" 2>&1
check "Prerequisites"

if ! command -v docker &> /dev/null; then
    log "Installing Docker..." "$YELLOW"
    apt-get install -y docker.io >> "$LOGFILE" 2>&1
    systemctl enable docker >> "$LOGFILE" 2>&1
    systemctl start docker >> "$LOGFILE" 2>&1
    check "Docker"
fi

###############################################################################
# DOWNLOAD PACKAGE - WITH MULTIPLE METHODS
###############################################################################

log "[2/10] Downloading PPTARMG package..." "$YELLOW"

DOWNLOAD_SUCCESS=0
TGZ_FILE="/tmp/docker.mviznARMG_ppt.tgz"

# Clean up old file
rm -f "$TGZ_FILE"

# Method 1: wget with authentication
log "Trying method 1: wget..." "$CYAN"
wget --no-check-certificate --user=tagtag --password=mvizntagger007 \
    -O "$TGZ_FILE" \
    http://tagger07.mvizn.com/static/docker.mviznARMG_ppt.tgz >> "$LOGFILE" 2>&1

if [ -f "$TGZ_FILE" ]; then
    FILESIZE=$(stat -c%s "$TGZ_FILE" 2>/dev/null)
    log "Downloaded: $FILESIZE bytes" "$CYAN"
    
    if [ "$FILESIZE" -gt 10000 ]; then
        DOWNLOAD_SUCCESS=1
        log "Download successful!" "$GREEN"
    else
        log "File too small, trying another method..." "$YELLOW"
        rm -f "$TGZ_FILE"
    fi
fi

# Method 2: curl with authentication
if [ $DOWNLOAD_SUCCESS -eq 0 ]; then
    log "Trying method 2: curl..." "$CYAN"
    curl -k -u tagtag:mvizntagger007 \
        -o "$TGZ_FILE" \
        http://tagger07.mvizn.com/static/docker.mviznARMG_ppt.tgz >> "$LOGFILE" 2>&1
    
    if [ -f "$TGZ_FILE" ]; then
        FILESIZE=$(stat -c%s "$TGZ_FILE" 2>/dev/null)
        log "Downloaded: $FILESIZE bytes" "$CYAN"
        
        if [ "$FILESIZE" -gt 10000 ]; then
            DOWNLOAD_SUCCESS=1
            log "Download successful!" "$GREEN"
        else
            rm -f "$TGZ_FILE"
        fi
    fi
fi

# Method 3: Check if file already exists in current directory
if [ $DOWNLOAD_SUCCESS -eq 0 ]; then
    log "Checking for existing package file..." "$CYAN"
    
    # Check common locations
    POSSIBLE_LOCATIONS=(
        "./docker.mviznARMG_ppt.tgz"
        "$REAL_HOME/Downloads/docker.mviznARMG_ppt.tgz"
        "$REAL_HOME/docker.mviznARMG_ppt.tgz"
        "/home/$REAL_USER/docker.mviznARMG_ppt.tgz"
    )
    
    for loc in "${POSSIBLE_LOCATIONS[@]}"; do
        if [ -f "$loc" ]; then
            FILESIZE=$(stat -c%s "$loc" 2>/dev/null)
            if [ "$FILESIZE" -gt 10000 ]; then
                log "Found existing file: $loc ($FILESIZE bytes)" "$GREEN"
                cp "$loc" "$TGZ_FILE"
                DOWNLOAD_SUCCESS=1
                break
            fi
        fi
    done
fi

# If all methods failed, provide manual instructions
if [ $DOWNLOAD_SUCCESS -eq 0 ]; then
    log "" "$NC"
    log "========================================" "$RED"
    log "AUTOMATIC DOWNLOAD FAILED" "$RED"
    log "========================================" "$RED"
    log "" "$NC"
    log "Please download manually:" "$YELLOW"
    log "1. Open browser and go to:" "$CYAN"
    log "   http://tagger07.mvizn.com/static/docker.mviznARMG_ppt.tgz" "$NC"
    log "" "$NC"
    log "2. Login with:" "$CYAN"
    log "   Username: tagtag" "$NC"
    log "   Password: mvizntagger007" "$NC"
    log "" "$NC"
    log "3. Save file to: /tmp/docker.mviznARMG_ppt.tgz" "$CYAN"
    log "" "$NC"
    log "4. Then run this script again" "$YELLOW"
    log "" "$NC"
    
    # Wait for manual download
    log "Waiting for manual download..." "$YELLOW"
    log "Press ENTER after you've downloaded the file, or Ctrl+C to exit" "$CYAN"
    read -r
    
    if [ -f "$TGZ_FILE" ]; then
        FILESIZE=$(stat -c%s "$TGZ_FILE" 2>/dev/null)
        if [ "$FILESIZE" -gt 10000 ]; then
            DOWNLOAD_SUCCESS=1
            log "File found! Continuing..." "$GREEN"
        fi
    fi
    
    if [ $DOWNLOAD_SUCCESS -eq 0 ]; then
        log "File not found. Exiting." "$RED"
        exit 1
    fi
fi

check "Package download"

###############################################################################
# EXTRACT PACKAGE
###############################################################################

log "[3/10] Extracting package..." "$YELLOW"

mkdir -p "$REAL_HOME/Code" >> "$LOGFILE" 2>&1
chown -R $REAL_USER:$REAL_USER "$REAL_HOME/Code" >> "$LOGFILE" 2>&1

rm -rf "$REAL_HOME/Code/docker.mviznARMG_ppt" >> "$LOGFILE" 2>&1

cd "$REAL_HOME/Code" || exit 1
log "Extracting to: $(pwd)" "$CYAN"

tar xzf "$TGZ_FILE" >> "$LOGFILE" 2>&1

if [ $? -eq 0 ]; then
    log "Extraction completed" "$GREEN"
    
    # Find the extracted directory
    if [ -d "$REAL_HOME/Code/docker.mviznARMG_ppt" ]; then
        INSTALL_DIR="$REAL_HOME/Code/docker.mviznARMG_ppt"
    else
        # Try to find it
        INSTALL_DIR=$(find "$REAL_HOME/Code" -maxdepth 2 -type d -name "*mviznARMG*" -o -name "*docker*" | grep -v "\.git" | head -1)
    fi
    
    if [ -z "$INSTALL_DIR" ] || [ ! -d "$INSTALL_DIR" ]; then
        log "Extracted directory not found!" "$RED"
        log "Contents:" "$YELLOW"
        ls -la "$REAL_HOME/Code/" | tee -a "$LOGFILE"
        exit 1
    fi
    
    log "Install directory: $INSTALL_DIR" "$GREEN"
    chown -R $REAL_USER:$REAL_USER "$INSTALL_DIR" >> "$LOGFILE" 2>&1
    check "Extraction"
else
    log "Extraction failed!" "$RED"
    exit 1
fi

###############################################################################
# CHECK RAID
###############################################################################

log "[4/10] Checking RAID..." "$YELLOW"

if df -h /opt 2>/dev/null | grep -q "/dev/md0"; then
    log "RAID already configured" "$GREEN"
    RAID_SETUP="ALREADY CONFIGURED"
else
    if [ -d "$INSTALL_DIR/raidscripts" ]; then
        log "RAID scripts found" "$CYAN"
        
        if [ -b /dev/sda ] && [ -b /dev/sdc ]; then
            log "Disks found: /dev/sda, /dev/sdc" "$CYAN"
            
            cd "$INSTALL_DIR" || exit 1
            
            if [ -f "raidscripts/clearraid.sh" ]; then
                log "Clearing RAID..." "$YELLOW"
                bash raidscripts/clearraid.sh >> "$LOGFILE" 2>&1
            fi
            
            if [ -f "raidscripts/setupraid.sh" ]; then
                log "Setting up RAID..." "$YELLOW"
                bash raidscripts/setupraid.sh -y >> "$LOGFILE" 2>&1
                RAID_SETUP="CONFIGURED"
            fi
        else
            log "Required disks not available" "$YELLOW"
            RAID_SETUP="NOT CONFIGURED"
        fi
    else
        log "RAID scripts not found" "$YELLOW"
        RAID_SETUP="SCRIPTS NOT FOUND"
    fi
fi

###############################################################################
# PERMISSIONS
###############################################################################

log "[5/10] Setting permissions..." "$YELLOW"
mkdir -p /opt >> "$LOGFILE" 2>&1
chmod -R 777 /opt >> "$LOGFILE" 2>&1
check "Permissions"

###############################################################################
# DOCKER INSTALLATION
###############################################################################

log "[6/10] Installing Docker containers..." "$YELLOW"

cd "$INSTALL_DIR" || exit 1

INSTALL_SCRIPT=""
if [ -f "00_install.sh" ]; then
    INSTALL_SCRIPT="00_install.sh"
elif [ -f "install.sh" ]; then
    INSTALL_SCRIPT="install.sh"
fi

if [ -n "$INSTALL_SCRIPT" ]; then
    log "Running: $INSTALL_SCRIPT" "$CYAN"
    log "This will take 15-30 minutes..." "$YELLOW"
    
    bash "$INSTALL_SCRIPT" >> "$LOGFILE" 2>&1 &
    PID=$!
    
    COUNT=0
    while kill -0 $PID 2>/dev/null; do
        echo -n "."
        sleep 5
        COUNT=$((COUNT + 1))
        if [ $((COUNT % 12)) -eq 0 ]; then
            echo -n " [${COUNT}min] "
        fi
    done
    echo ""
    
    wait $PID
    DOCKER_STATUS="COMPLETED"
    check "Docker installation"
else
    log "Installation script not found!" "$RED"
    DOCKER_STATUS="SCRIPT NOT FOUND"
fi

###############################################################################
# SYMLINKS
###############################################################################

log "[7/10] Creating symlinks..." "$YELLOW"

cd "$REAL_HOME/Code" || exit 1
rm -f mviznARMG

if [ -d "$INSTALL_DIR/mviznARMG" ]; then
    ln -sf "$INSTALL_DIR/mviznARMG" mviznARMG
    chown -h $REAL_USER:$REAL_USER mviznARMG
    check "Symlink"
else
    log "mviznARMG directory not found" "$YELLOW"
fi

###############################################################################
# NTP CONFIGURATION
###############################################################################

log "[8/10] Configuring NTP..." "$YELLOW"

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
check "NTP"

NTP_STATUS="CONFIGURED"

###############################################################################
# UTILITIES
###############################################################################

log "[9/10] Setting up utilities..." "$YELLOW"

mkdir -p "$REAL_HOME/PPTARMG_utils"
mkdir -p "$REAL_HOME/PPTARMG_config"

find "$INSTALL_DIR" -name "startsim.sh" -exec cp {} "$REAL_HOME/PPTARMG_utils/" \; 2>/dev/null
find "$INSTALL_DIR" -name "startstress.sh" -exec cp {} "$REAL_HOME/PPTARMG_utils/" \; 2>/dev/null
find "$INSTALL_DIR" -name "endsim.sh" -exec cp {} "$REAL_HOME/PPTARMG_utils/" \; 2>/dev/null

chown -R $REAL_USER:$REAL_USER "$REAL_HOME/PPTARMG_utils"
chown -R $REAL_USER:$REAL_USER "$REAL_HOME/PPTARMG_config"
check "Utilities"

###############################################################################
# VERIFICATION
###############################################################################

log "[10/10] Verification..." "$YELLOW"

DOCKER_COUNT=$(docker ps -a 2>/dev/null | grep -v CONTAINER | wc -l)
DISK_USAGE=$(df -h / | tail -1 | awk '{print $5}')
OPT_MOUNT=$(df -h /opt 2>/dev/null | tail -1 | awk '{print $1}')
NTP_STATUS_CHK=$(systemctl is-active ntpsec 2>/dev/null || systemctl is-active ntp 2>/dev/null || echo "inactive")

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
Home: $REAL_HOME
Install: $INSTALL_DIR

================================================================================
                        STATUS
================================================================================

✓ Download:         SUCCESS ($FILESIZE bytes)
✓ Extraction:       SUCCESS
✓ RAID:            $RAID_SETUP
✓ Docker:          $DOCKER_STATUS
✓ NTP:             $NTP_STATUS
✓ Utilities:       SUCCESS

================================================================================
                        VERIFICATION
================================================================================

Docker Containers:  $DOCKER_COUNT
Disk Usage:        $DISK_USAGE
/opt Mount:        $OPT_MOUNT
NTP Service:       $NTP_STATUS_CHK
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

================================================================================
$(date) - Installation Complete
================================================================================
ENDREPORT

chown $REAL_USER:$REAL_USER "$REPORT_FILE" 2>/dev/null
cp "$REPORT_FILE" "$REAL_HOME/Desktop/" 2>/dev/null

log "" "$NC"
log "========================================" "$GREEN"
log "        INSTALLATION COMPLETE" "$GREEN"
log "========================================" "$GREEN"
log "" "$NC"
log "Report: ~/Desktop/$(basename $REPORT_FILE)" "$CYAN"
log "Docker: $DOCKER_COUNT containers" "$CYAN"
log "RAID: $RAID_SETUP" "$CYAN"
log "" "$NC"

exit 0
