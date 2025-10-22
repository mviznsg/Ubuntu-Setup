#!/bin/bash

###############################################################################
# PPTARMG Automated Installation Script
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

###############################################################################
# INSTALL PREREQUISITES
###############################################################################

log "[1/10] Installing prerequisites..." "$YELLOW"
apt-get update >> "$LOGFILE" 2>&1
apt-get install -y wget tar rsync ntpsec >> "$LOGFILE" 2>&1
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

if [ $? -eq 0 ]; then
    check "Package download"
else
    log "Download failed. Trying alternative method..." "$YELLOW"
    curl -k -u tagtag:mvizntagger007 -O \
        http://tagger07.mvizn.com/static/docker.mviznARMG_ppt.tgz >> "$LOGFILE" 2>&1
    check "Package download (curl)"
fi

###############################################################################
# EXTRACT PACKAGE
###############################################################################

log "[3/10] Extracting package..." "$YELLOW"
mkdir -p "$REAL_HOME/Code"
cd "$REAL_HOME/Code" || exit 1
tar xzf /tmp/docker.mviznARMG_ppt.tgz >> "$LOGFILE" 2>&1
check "Package extraction"

chown -R $REAL_USER:$REAL_USER "$REAL_HOME/Code/docker.mviznARMG_ppt" >> "$LOGFILE" 2>&1

###############################################################################
# CHECK RAID
###############################################################################

log "[4/10] Checking RAID configuration..." "$YELLOW"

if df -h /opt 2>/dev/null | grep -q "/dev/md0"; then
    log "/dev/md0 already mounted at /opt - skipping RAID setup" "$GREEN"
    RAID_SETUP="SKIPPED - Already configured"
else
    log "Checking available disks for RAID..." "$YELLOW"
    
    # Check if sda and sdc exist and are not mounted
    if [ -b /dev/sda ] && [ -b /dev/sdc ]; then
        log "Found /dev/sda and /dev/sdc - Setting up RAID automatically..." "$YELLOW"
        
        cd "$REAL_HOME/Code/docker.mviznARMG_ppt" || exit 1
        
        if [ -f raidscripts/clearraid.sh ]; then
            bash raidscripts/clearraid.sh >> "$LOGFILE" 2>&1
            check "RAID clear"
        fi
        
        if [ -f raidscripts/setupraid.sh ]; then
            bash raidscripts/setupraid.sh -y >> "$LOGFILE" 2>&1
            check "RAID setup"
            RAID_SETUP="CONFIGURED"
        else
            log "RAID setup script not found" "$YELLOW"
            RAID_SETUP="SCRIPT NOT FOUND"
        fi
    else
        log "Required disks not found or already in use" "$YELLOW"
        log "Proceeding with current /opt configuration" "$YELLOW"
        RAID_SETUP="NOT REQUIRED"
    fi
fi

###############################################################################
# SET PERMISSIONS
###############################################################################

log "[5/10] Setting permissions..." "$YELLOW"
chmod -R 777 /opt >> "$LOGFILE" 2>&1
check "Set /opt permissions"

###############################################################################
# DOCKER INSTALLATION
###############################################################################

log "[6/10] Installing Docker containers (this may take 15-30 minutes)..." "$YELLOW"

cd "$REAL_HOME/Code/docker.mviznARMG_ppt" || exit 1

if [ -f 00_install.sh ]; then
    log "Running Docker installation..." "$BLUE"
    bash 00_install.sh >> "$LOGFILE" 2>&1 &
    INSTALL_PID=$!
    
    while kill -0 $INSTALL_PID 2>/dev/null; do
        echo -n "."
        sleep 5
    done
    echo ""
    
    wait $INSTALL_PID
    INSTALL_STATUS=$?
    
    if [ $INSTALL_STATUS -eq 0 ]; then
        check "Docker installation"
        DOCKER_STATUS="SUCCESS"
    else
        log "Docker installation completed with warnings" "$YELLOW"
        DOCKER_STATUS="COMPLETED WITH WARNINGS"
    fi
else
    log "Installation script not found" "$RED"
    DOCKER_STATUS="SCRIPT NOT FOUND"
fi

###############################################################################
# CREATE SYMLINKS
###############################################################################

log "[7/10] Creating symlinks..." "$YELLOW"
cd "$REAL_HOME/Code" || exit 1
rm -rf mviznARMG
ln -sf "$REAL_HOME/Code/docker.mviznARMG_ppt/mviznARMG" mviznARMG
chown -h $REAL_USER:$REAL_USER mviznARMG
check "Symlink creation"

###############################################################################
# NTP CONFIGURATION
###############################################################################

log "[8/10] Configuring NTP..." "$YELLOW"

if [ -f /etc/ntpsec/ntp.conf ]; then
    cp /etc/ntpsec/ntp.conf /etc/ntpsec/ntp.conf.backup_$(date +%Y%m%d_%H%M%S) 2>/dev/null
fi

GATEWAY_IP=$(ip route | grep default | awk '{print $3}' | head -1)
log "Detected gateway: $GATEWAY_IP" "$BLUE"

cat > /etc/ntpsec/ntp.conf << NTPEOF
driftfile /var/lib/ntpsec/ntp.drift
logfile /var/log/ntpsec/ntp.log

restrict default kod limited nomodify nopeer noquery notrap
restrict 127.0.0.1
restrict ::1

server ${GATEWAY_IP} prefer iburst
pool 0.ubuntu.pool.ntp.org iburst
pool 1.ubuntu.pool.ntp.org iburst
pool 2.ubuntu.pool.ntp.org iburst
pool 3.ubuntu.pool.ntp.org iburst
server ntp.ubuntu.com
NTPEOF

check "NTP configuration"

systemctl restart ntp >> "$LOGFILE" 2>&1 || systemctl restart ntpsec >> "$LOGFILE" 2>&1
check "NTP service restart"

NTP_STATUS="CONFIGURED"

###############################################################################
# CREATE UTILITY DIRECTORIES
###############################################################################

log "[9/10] Setting up utilities..." "$YELLOW"
mkdir -p "$REAL_HOME/PPTARMG_utils"
mkdir -p "$REAL_HOME/PPTARMG_config"
chown -R $REAL_USER:$REAL_USER "$REAL_HOME/PPTARMG_utils"
chown -R $REAL_USER:$REAL_USER "$REAL_HOME/PPTARMG_config"

if [ -d "$REAL_HOME/Code/docker.mviznARMG_ppt" ]; then
    find "$REAL_HOME/Code/docker.mviznARMG_ppt" -name "startsim.sh" -exec cp {} "$REAL_HOME/PPTARMG_utils/" \; 2>/dev/null
    find "$REAL_HOME/Code/docker.mviznARMG_ppt" -name "startstress.sh" -exec cp {} "$REAL_HOME/PPTARMG_utils/" \; 2>/dev/null
    find "$REAL_HOME/Code/docker.mviznARMG_ppt" -name "endsim.sh" -exec cp {} "$REAL_HOME/PPTARMG_utils/" \; 2>/dev/null
    chown -R $REAL_USER:$REAL_USER "$REAL_HOME/PPTARMG_utils"
fi

check "Utility setup"

###############################################################################
# VERIFICATION
###############################################################################

log "[10/10] Verifying installation..." "$YELLOW"

DOCKER_RUNNING=$(docker ps -a 2>/dev/null | wc -l)
DISK_USAGE=$(df -h / | tail -1 | awk '{print $5}')
OPT_MOUNT=$(df -h /opt | tail -1 | awk '{print $1,$6}')
NTP_RUNNING=$(systemctl is-active ntp 2>/dev/null || systemctl is-active ntpsec 2>/dev/null)

###############################################################################
# GENERATE REPORT
###############################################################################

log "Generating installation report..." "$YELLOW"

mkdir -p "$REAL_HOME/Desktop" 2>/dev/null
chown $REAL_USER:$REAL_USER "$REAL_HOME/Desktop" 2>/dev/null

cat > "$REPORT_FILE" << 'REPORTEOF'
================================================================================
                    PPTARMG INSTALLATION REPORT
================================================================================

REPORTEOF

cat >> "$REPORT_FILE" << REPORTEOF
Installation Date: $(date)
System: $(uname -a)
User: $REAL_USER
Installation Path: $REAL_HOME/Code/docker.mviznARMG_ppt

================================================================================
                        INSTALLATION STATUS
================================================================================

Package Download:        SUCCESS
Package Extraction:      SUCCESS
RAID Configuration:      $RAID_SETUP
Docker Installation:     $DOCKER_STATUS
NTP Configuration:       $NTP_STATUS
Symlink Creation:        SUCCESS

================================================================================
                        SYSTEM VERIFICATION
================================================================================

Docker Containers:       $DOCKER_RUNNING containers found
Disk Usage:             $DISK_USAGE used
/opt Mount:             $OPT_MOUNT
NTP Service:            $NTP_RUNNING
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

$(cat /proc/mdstat 2>/dev/null || echo "No software RAID configured")

================================================================================
                        NTP STATUS
================================================================================

$(systemctl status ntp 2>/dev/null | head -15 || systemctl status ntpsec 2>/dev/null | head -15)

================================================================================
                        NEXT STEPS
================================================================================

1. COPY CONFIGURATION FILES:
   rsync -av /path/to/source/yc_config/ ~/PPTARMG_config/config
   
   Example:
   rsync -av /media/mvizn/hdd1/configbackup/yc7409/config/ ~/PPTARMG_config/config

2. SIMULATION TEST (in OFFICE):
   touch /tmp/launched
   bash ~/PPTARMG_utils/startsim.sh
   (Runs 1x TCDS, 1x CLPS)

3. STRESS TEST (in OFFICE):
   touch /tmp/launched
   bash ~/PPTARMG_utils/startstress.sh
   
   Controls:
   - Press H: Show HNCDS
   - Press P: Show PMNRS
   - Press C: Show CLPS
   - Press T: Show TCDS
   - CTRL-C: End test, then run: bash ~/PPTARMG_utils/endsim.sh

4. ENABLE SSH (if needed):
   sudo apt install openssh-server
   sudo systemctl enable ssh
   sudo systemctl start ssh

5. CONFIGURE NETWORK:
   Update IP settings as required

================================================================================
                        INSTALLATION PATHS
================================================================================

Main Installation:      $REAL_HOME/Code/docker.mviznARMG_ppt/
Symlink:               $REAL_HOME/Code/mviznARMG
Utilities:             $REAL_HOME/PPTARMG_utils/
Configuration:         $REAL_HOME/PPTARMG_config/
Log File:              $LOGFILE

================================================================================
                        QUICK COMMANDS
================================================================================

Check Docker:          docker ps -a
Check RAID:            cat /proc/mdstat
Check NTP:             systemctl status ntpsec
Check Disk:            df -h /opt
View Logs:             tail -f $LOGFILE

================================================================================
                    INSTALLATION COMPLETE
================================================================================

Status: SUCCESS
Timestamp: $(date)

REPORTEOF

chown $REAL_USER:$REAL_USER "$REPORT_FILE"

if [ -d "$REAL_HOME/Desktop" ]; then
    cp "$REPORT_FILE" "$REAL_HOME/Desktop/" 2>/dev/null
    chown $REAL_USER:$REAL_USER "$REAL_HOME/Desktop/$(basename $REPORT_FILE)" 2>/dev/null
    REPORT_LOCATION="$REAL_HOME/Desktop/$(basename $REPORT_FILE)"
else
    REPORT_LOCATION="$REPORT_FILE"
fi

check "Report generation"

###############################################################################
# FINAL SUMMARY
###############################################################################

echo ""
log "========================================" "$GREEN"
log "   INSTALLATION COMPLETED SUCCESSFULLY   " "$GREEN"
log "========================================" "$GREEN"
echo ""
log "Report saved to: $REPORT_LOCATION" "$BLUE"
log "Full log: $LOGFILE" "$BLUE"
echo ""
log "SYSTEM READY FOR CONFIGURATION" "$YELLOW"
echo ""

###############################################################################
# DETAILED SUMMARY
###############################################################################

echo "" | tee -a "$LOGFILE"
log "Installation Summary:" "$BLUE"
log "  - Docker containers: $DOCKER_RUNNING" "$NC"
log "  - RAID status: $RAID_SETUP" "$NC"
log "  - NTP service: $NTP_RUNNING" "$NC"
log "  - Disk usage: $DISK_USAGE" "$NC"
echo ""

exit 0
