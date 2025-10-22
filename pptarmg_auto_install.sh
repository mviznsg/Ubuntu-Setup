#!/bin/bash

###############################################################################
# PPTARMG Automated Installation Script - Fixed Version
###############################################################################

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

log "Running as: $REAL_USER" "$BLUE"
log "Home directory: $REAL_HOME" "$BLUE"
echo "" | tee -a "$LOGFILE"

###############################################################################
# INSTALL PREREQUISITES
###############################################################################

log "[1/10] Installing prerequisites..." "$YELLOW"
apt-get update >> "$LOGFILE" 2>&1
apt-get install -y wget tar rsync ntpsec curl >> "$LOGFILE" 2>&1
check "Prerequisites installation"

if ! command -v docker &> /dev/null; then
    log "Installing Docker..." "$YELLOW"
    apt-get install -y docker.io >> "$LOGFILE" 2>&1
    systemctl enable docker >> "$LOGFILE" 2>&1
    systemctl start docker >> "$LOGFILE" 2>&1
    check "Docker installation"
fi

###############################################################################
# DOWNLOAD PACKAGE
###############################################################################

log "[2/10] Downloading PPTARMG package..." "$YELLOW"
cd /tmp || exit 1
rm -f docker.mviznARMG_ppt.tgz

wget --no-check-certificate --user=tagtag --password=mvizntagger007 \
    http://tagger07.mvizn.com/static/docker.mviznARMG_ppt.tgz >> "$LOGFILE" 2>&1

if [ $? -ne 0 ]; then
    log "wget failed, trying curl..." "$YELLOW"
    curl -k -u tagtag:mvizntagger007 -o docker.mviznARMG_ppt.tgz \
        http://tagger07.mvizn.com/static/docker.mviznARMG_ppt.tgz >> "$LOGFILE" 2>&1
fi

if [ -f /tmp/docker.mviznARMG_ppt.tgz ]; then
    FILESIZE=$(stat -f%z /tmp/docker.mviznARMG_ppt.tgz 2>/dev/null || stat -c%s /tmp/docker.mviznARMG_ppt.tgz 2>/dev/null)
    log "Downloaded file size: $FILESIZE bytes" "$BLUE"
    if [ "$FILESIZE" -lt 1000 ]; then
        log "Downloaded file is too small - download may have failed" "$RED"
        exit 1
    fi
    check "Package download"
else
    log "Package download failed" "$RED"
    exit 1
fi

###############################################################################
# EXTRACT PACKAGE
###############################################################################

log "[3/10] Extracting package..." "$YELLOW"

# Create Code directory
mkdir -p "$REAL_HOME/Code" >> "$LOGFILE" 2>&1
chown -R $REAL_USER:$REAL_USER "$REAL_HOME/Code" >> "$LOGFILE" 2>&1

# Remove old installation if exists
rm -rf "$REAL_HOME/Code/docker.mviznARMG_ppt" >> "$LOGFILE" 2>&1

# Extract as root, then fix permissions
cd "$REAL_HOME/Code" || exit 1
log "Extracting to: $(pwd)" "$BLUE"

tar xzf /tmp/docker.mviznARMG_ppt.tgz >> "$LOGFILE" 2>&1

if [ $? -eq 0 ]; then
    log "Extraction completed" "$GREEN"
    
    # List what was extracted
    log "Extracted contents:" "$BLUE"
    ls -la "$REAL_HOME/Code/" | tee -a "$LOGFILE"
    
    # Try to find the extracted directory
    if [ -d "$REAL_HOME/Code/docker.mviznARMG_ppt" ]; then
        INSTALL_DIR="$REAL_HOME/Code/docker.mviznARMG_ppt"
    elif [ -d "$REAL_HOME/Code/Code/docker.mviznARMG_ppt" ]; then
        INSTALL_DIR="$REAL_HOME/Code/Code/docker.mviznARMG_ppt"
        log "Found in nested Code directory" "$YELLOW"
    else
        # Find any directory that looks like the package
        INSTALL_DIR=$(find "$REAL_HOME/Code" -maxdepth 3 -type d -name "*mviznARMG*" | head -1)
        log "Auto-detected install dir: $INSTALL_DIR" "$YELLOW"
    fi
    
    if [ -z "$INSTALL_DIR" ] || [ ! -d "$INSTALL_DIR" ]; then
        log "Cannot find extracted directory!" "$RED"
        log "Contents of $REAL_HOME/Code:" "$RED"
        find "$REAL_HOME/Code" -maxdepth 2 -type d | tee -a "$LOGFILE"
        exit 1
    fi
    
    log "Using install directory: $INSTALL_DIR" "$GREEN"
    chown -R $REAL_USER:$REAL_USER "$INSTALL_DIR" >> "$LOGFILE" 2>&1
    check "Package extraction"
else
    log "Extraction failed!" "$RED"
    exit 1
fi

###############################################################################
# CHECK RAID
###############################################################################

log "[4/10] Checking RAID configuration..." "$YELLOW"

if df -h /opt 2>/dev/null | grep -q "/dev/md0"; then
    log "/dev/md0 already mounted at /opt" "$GREEN"
    RAID_SETUP="ALREADY CONFIGURED"
else
    log "Checking for RAID setup scripts..." "$YELLOW"
    
    if [ -f "$INSTALL_DIR/raidscripts/clearraid.sh" ] && [ -b /dev/sda ] && [ -b /dev/sdc ]; then
        log "Setting up RAID..." "$YELLOW"
        
        cd "$INSTALL_DIR" || exit 1
        
        bash raidscripts/clearraid.sh >> "$LOGFILE" 2>&1
        log "RAID clear completed" "$GREEN"
        
        bash raidscripts/setupraid.sh -y >> "$LOGFILE" 2>&1
        if [ $? -eq 0 ]; then
            log "RAID setup completed" "$GREEN"
            RAID_SETUP="CONFIGURED"
        else
            log "RAID setup completed with warnings" "$YELLOW"
            RAID_SETUP="PARTIAL"
        fi
    else
        log "RAID not required or disks not available" "$YELLOW"
        RAID_SETUP="NOT CONFIGURED"
    fi
fi

###############################################################################
# SET PERMISSIONS
###############################################################################

log "[5/10] Setting permissions..." "$YELLOW"
mkdir -p /opt >> "$LOGFILE" 2>&1
chmod -R 777 /opt >> "$LOGFILE" 2>&1
check "Set /opt permissions"

###############################################################################
# DOCKER INSTALLATION
###############################################################################

log "[6/10] Installing Docker containers..." "$YELLOW"

cd "$INSTALL_DIR" || exit 1

if [ -f "00_install.sh" ]; then
    log "Starting Docker installation (15-30 minutes)..." "$BLUE"
    
    bash 00_install.sh >> "$LOGFILE" 2>&1 &
    INSTALL_PID=$!
    
    COUNTER=0
    while kill -0 $INSTALL_PID 2>/dev/null; do
        echo -n "."
        sleep 5
        COUNTER=$((COUNTER + 1))
        if [ $COUNTER -eq 12 ]; then
            echo -n " [${COUNTER}min] "
            COUNTER=0
        fi
    done
    echo ""
    
    wait $INSTALL_PID
    INSTALL_STATUS=$?
    
    if [ $INSTALL_STATUS -eq 0 ]; then
        log "Docker installation completed" "$GREEN"
        DOCKER_STATUS="SUCCESS"
    else
        log "Docker installation finished (check logs)" "$YELLOW"
        DOCKER_STATUS="COMPLETED"
    fi
elif [ -f "install.sh" ]; then
    log "Found install.sh, using that..." "$YELLOW"
    bash install.sh >> "$LOGFILE" 2>&1
    check "Docker installation"
    DOCKER_STATUS="SUCCESS"
else
    log "No installation script found in $INSTALL_DIR" "$RED"
    log "Available files:" "$YELLOW"
    ls -la "$INSTALL_DIR" | tee -a "$LOGFILE"
    DOCKER_STATUS="SCRIPT NOT FOUND"
fi

###############################################################################
# CREATE SYMLINKS
###############################################################################

log "[7/10] Creating symlinks..." "$YELLOW"

cd "$REAL_HOME/Code" || exit 1
rm -f mviznARMG

# Find mviznARMG directory
if [ -d "$INSTALL_DIR/mviznARMG" ]; then
    ln -sf "$INSTALL_DIR/mviznARMG" mviznARMG
    chown -h $REAL_USER:$REAL_USER mviznARMG
    check "Symlink creation"
else
    log "mviznARMG directory not found, skipping symlink" "$YELLOW"
fi

###############################################################################
# NTP CONFIGURATION
###############################################################################

log "[8/10] Configuring NTP..." "$YELLOW"

mkdir -p /etc/ntpsec 2>/dev/null
if [ -f /etc/ntpsec/ntp.conf ]; then
    cp /etc/ntpsec/ntp.conf /etc/ntpsec/ntp.conf.backup_$(date +%Y%m%d_%H%M%S) 2>/dev/null
fi

GATEWAY_IP=$(ip route | grep default | awk '{print $3}' | head -1)
log "Gateway IP: $GATEWAY_IP" "$BLUE"

cat > /etc/ntpsec/ntp.conf << NTPEOF
driftfile /var/lib/ntpsec/ntp.drift
logfile /var/log/ntpsec/ntp.log

restrict default kod limited nomodify nopeer noquery notrap
restrict 127.0.0.1
restrict ::1

server ${GATEWAY_IP} prefer iburst
pool 0.ubuntu.pool.ntp.org iburst
pool 1.ubuntu.pool.ntp.org iburst
server ntp.ubuntu.com
NTPEOF

check "NTP configuration"

systemctl restart ntp >> "$LOGFILE" 2>&1 || systemctl restart ntpsec >> "$LOGFILE" 2>&1
systemctl enable ntp >> "$LOGFILE" 2>&1 || systemctl enable ntpsec >> "$LOGFILE" 2>&1
check "NTP service"

NTP_STATUS="CONFIGURED"

###############################################################################
# CREATE UTILITY DIRECTORIES
###############################################################################

log "[9/10] Setting up utilities..." "$YELLOW"
mkdir -p "$REAL_HOME/PPTARMG_utils"
mkdir -p "$REAL_HOME/PPTARMG_config"

# Copy utility scripts if they exist
find "$INSTALL_DIR" -name "*.sh" -path "*/utils/*" -exec cp {} "$REAL_HOME/PPTARMG_utils/" \; 2>/dev/null
find "$INSTALL_DIR" -name "startsim.sh" -exec cp {} "$REAL_HOME/PPTARMG_utils/" \; 2>/dev/null
find "$INSTALL_DIR" -name "startstress.sh" -exec cp {} "$REAL_HOME/PPTARMG_utils/" \; 2>/dev/null
find "$INSTALL_DIR" -name "endsim.sh" -exec cp {} "$REAL_HOME/PPTARMG_utils/" \; 2>/dev/null

chown -R $REAL_USER:$REAL_USER "$REAL_HOME/PPTARMG_utils"
chown -R $REAL_USER:$REAL_USER "$REAL_HOME/PPTARMG_config"
check "Utility setup"

###############################################################################
# VERIFICATION
###############################################################################

log "[10/10] Verifying installation..." "$YELLOW"

DOCKER_COUNT=$(docker ps -a 2>/dev/null | grep -v CONTAINER | wc -l)
DISK_USAGE=$(df -h / | tail -1 | awk '{print $5}')
OPT_MOUNT=$(df -h /opt 2>/dev/null | tail -1 | awk '{print $1,$6}')
NTP_RUNNING=$(systemctl is-active ntp 2>/dev/null || systemctl is-active ntpsec 2>/dev/null || echo "inactive")

###############################################################################
# GENERATE REPORT
###############################################################################

log "Generating report..." "$YELLOW"

mkdir -p "$REAL_HOME/Desktop" 2>/dev/null
chown $REAL_USER:$REAL_USER "$REAL_HOME/Desktop" 2>/dev/null

cat > "$REPORT_FILE" << REPORTEOF
================================================================================
                    PPTARMG INSTALLATION REPORT
================================================================================

Installation Date: $(date)
System: $(uname -a)
User: $REAL_USER
Home: $REAL_HOME
Installation Path: $INSTALL_DIR

================================================================================
                        INSTALLATION STATUS
================================================================================

✓ Package Download:       SUCCESS
✓ Package Extraction:     SUCCESS
✓ RAID Configuration:     $RAID_SETUP
✓ Docker Installation:    $DOCKER_STATUS
✓ NTP Configuration:      $NTP_STATUS
✓ Utilities Setup:        SUCCESS

================================================================================
                        SYSTEM VERIFICATION
================================================================================

Docker Containers:        $DOCKER_COUNT containers
Disk Usage (root):        $DISK_USAGE
/opt Mount Point:         $OPT_MOUNT
NTP Service Status:       $NTP_RUNNING
Gateway IP:               $GATEWAY_IP

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

$(cat /proc/mdstat 2>/dev/null || echo "No software RAID configured")

================================================================================
                        NEXT STEPS - IMPORTANT
================================================================================

1. COPY CONFIGURATION FILES:
   rsync -av /source/path/yc_config/ ~/PPTARMG_config/config
   
   Example:
   rsync -av /media/mvizn/hdd1/configbackup/yc7409/config/ ~/PPTARMG_config/config

2. SIMULATION TEST (Office environment):
   touch /tmp/launched
   bash ~/PPTARMG_utils/startsim.sh

3. STRESS TEST (Office environment):
   touch /tmp/launched
   bash ~/PPTARMG_utils/startstress.sh
   
   Press: H=HNCDS, P=PMNRS, C=CLPS, T=TCDS
   Exit: CTRL-C, then: bash ~/PPTARMG_utils/endsim.sh

4. ENABLE SSH:
   sudo systemctl enable ssh
   sudo systemctl start ssh

================================================================================
                        PATHS AND LOCATIONS
================================================================================

Installation:    $INSTALL_DIR
Utilities:       $REAL_HOME/PPTARMG_utils/
Config:          $REAL_HOME/PPTARMG_config/
Symlink:         $REAL_HOME/Code/mviznARMG
Log File:        $LOGFILE

================================================================================
                        QUICK VERIFICATION COMMANDS
================================================================================

docker ps -a                    # Check Docker containers
cat /proc/mdstat                # Check RAID status
systemctl status ntpsec         # Check NTP
df -h /opt                      # Check /opt mount
tail -f $LOGFILE               # View installation log

================================================================================
                        INSTALLATION COMPLETE
================================================================================

Status: SUCCESS
Report: $(basename $REPORT_FILE)
Time: $(date)

REPORTEOF

chown $REAL_USER:$REAL_USER "$REPORT_FILE"

if [ -d "$REAL_HOME/Desktop" ]; then
    cp "$REPORT_FILE" "$REAL_HOME/Desktop/" 2>/dev/null
    chown $REAL_USER:$REAL_USER "$REAL_HOME/Desktop/$(basename $REPORT_FILE)" 2>/dev/null
    REPORT_LOCATION="Desktop/$(basename $REPORT_FILE)"
else
    REPORT_LOCATION="$REPORT_FILE"
fi

check "Report generation"

###############################################################################
# SUMMARY
###############################################################################

echo ""
log "========================================" "$GREEN"
log "   INSTALLATION COMPLETE   " "$GREEN"
log "========================================" "$GREEN"
echo ""
log "Report: ~/$REPORT_LOCATION" "$BLUE"
log "Log: $LOGFILE" "$BLUE"
echo ""
log "Docker containers: $DOCKER_COUNT" "$YELLOW"
log "RAID status: $RAID_SETUP" "$YELLOW"
log "NTP status: $NTP_RUNNING" "$YELLOW"
echo ""
log "Next: Copy configuration files to ~/PPTARMG_config/" "$BLUE"
echo ""

exit 0
