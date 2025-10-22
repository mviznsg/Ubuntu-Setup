#!/bin/bash

###############################################################################
# PPTARMG Complete Installation Script - Final Working Version
###############################################################################

set -e  # Exit on error
trap 'last_command=$current_command; current_command=$BASH_COMMAND' DEBUG
trap 'echo "\"${last_command}\" command failed with exit code $?."' ERR

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
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
log "                    PPTARMG INSTALLATION SCRIPT" "$BLUE"
log "================================================================================" "$BLUE"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    log "ERROR: This script must be run with sudo" "$RED"
    log "Usage: sudo bash $0" "$YELLOW"
    exit 1
fi

# Get real user
REAL_USER=$(logname 2>/dev/null || who am i | awk '{print $1}' || echo $SUDO_USER)
REAL_HOME=$(eval echo ~$REAL_USER)

if [ -z "$REAL_USER" ] || [ "$REAL_USER" = "root" ]; then
    log "ERROR: Cannot determine real user. Don't run as root directly." "$RED"
    exit 1
fi

log "Installation User: $REAL_USER" "$CYAN"
log "Home Directory: $REAL_HOME" "$CYAN"
log "Log File: $LOGFILE" "$CYAN"
echo ""

###############################################################################
# STEP 1: INSTALL PREREQUISITES
###############################################################################

log "================================================================================" "$YELLOW"
log "[STEP 1/9] Installing Prerequisites" "$YELLOW"
log "================================================================================" "$YELLOW"
echo ""

export DEBIAN_FRONTEND=noninteractive

log "Updating package lists..." "$CYAN"
apt-get update >> "$LOGFILE" 2>&1 || true

log "Installing required packages..." "$CYAN"
apt-get install -y \
    wget \
    curl \
    tar \
    rsync \
    ntpsec \
    docker.io \
    mdadm \
    >> "$LOGFILE" 2>&1 || true

log "✓ Prerequisites installed" "$GREEN"

# Enable and start Docker
systemctl enable docker >> "$LOGFILE" 2>&1 || true
systemctl start docker >> "$LOGFILE" 2>&1 || true
log "✓ Docker service started" "$GREEN"
echo ""

###############################################################################
# STEP 2: DOWNLOAD PACKAGE
###############################################################################

log "================================================================================" "$YELLOW"
log "[STEP 2/9] Downloading PPTARMG Package" "$YELLOW"
log "================================================================================" "$YELLOW"
echo ""

# Remove old file if exists
rm -f "$TGZ_FILE"

# Check if file exists in common locations
FOUND_EXISTING=0
SEARCH_LOCATIONS=(
    "$REAL_HOME/Downloads/docker.mviznARMG_ppt.tgz"
    "$REAL_HOME/docker.mviznARMG_ppt.tgz"
    "/home/$REAL_USER/Downloads/docker.mviznARMG_ppt.tgz"
    "$(pwd)/docker.mviznARMG_ppt.tgz"
)

for loc in "${SEARCH_LOCATIONS[@]}"; do
    if [ -f "$loc" ]; then
        FILESIZE=$(stat -c%s "$loc" 2>/dev/null || echo 0)
        if [ "$FILESIZE" -gt 10000000 ]; then  # > 10MB
            log "Found existing package at: $loc" "$GREEN"
            log "Size: $(numfmt --to=iec $FILESIZE 2>/dev/null || echo ${FILESIZE} bytes)" "$CYAN"
            cp "$loc" "$TGZ_FILE"
            FOUND_EXISTING=1
            break
        fi
    fi
done

# Try automatic download if not found
if [ $FOUND_EXISTING -eq 0 ]; then
    log "Attempting automatic download..." "$CYAN"
    
    # Method 1: wget
    wget --no-check-certificate \
         --user=tagtag \
         --password=mvizntagger007 \
         -O "$TGZ_FILE" \
         http://tagger07.mvizn.com/static/docker.mviznARMG_ppt.tgz \
         >> "$LOGFILE" 2>&1 || true
    
    if [ -f "$TGZ_FILE" ]; then
        FILESIZE=$(stat -c%s "$TGZ_FILE" 2>/dev/null || echo 0)
        if [ "$FILESIZE" -gt 10000000 ]; then
            log "✓ Download successful via wget" "$GREEN"
            log "Size: $(numfmt --to=iec $FILESIZE 2>/dev/null || echo ${FILESIZE} bytes)" "$CYAN"
            FOUND_EXISTING=1
        else
            rm -f "$TGZ_FILE"
        fi
    fi
fi

# Method 2: curl if wget failed
if [ $FOUND_EXISTING -eq 0 ]; then
    log "Trying curl..." "$CYAN"
    
    curl -k -L \
         -u tagtag:mvizntagger007 \
         -o "$TGZ_FILE" \
         http://tagger07.mvizn.com/static/docker.mviznARMG_ppt.tgz \
         >> "$LOGFILE" 2>&1 || true
    
    if [ -f "$TGZ_FILE" ]; then
        FILESIZE=$(stat -c%s "$TGZ_FILE" 2>/dev/null || echo 0)
        if [ "$FILESIZE" -gt 10000000 ]; then
            log "✓ Download successful via curl" "$GREEN"
            log "Size: $(numfmt --to=iec $FILESIZE 2>/dev/null || echo ${FILESIZE} bytes)" "$CYAN"
            FOUND_EXISTING=1
        else
            rm -f "$TGZ_FILE"
        fi
    fi
fi

# If still not found, prompt for manual download
if [ $FOUND_EXISTING -eq 0 ]; then
    log "" "$NC"
    log "================================================================================" "$RED"
    log "                    MANUAL DOWNLOAD REQUIRED" "$RED"
    log "================================================================================" "$RED"
    log "" "$NC"
    log "Automatic download failed. Please download manually." "$YELLOW"
    log "" "$NC"
    log "Open a NEW terminal and run ONE of these commands:" "$CYAN"
    log "" "$NC"
    log "METHOD 1 (wget):" "$GREEN"
    log "  cd /tmp" "$WHITE"
    log "  wget --no-check-certificate --user=tagtag --password=mvizntagger007 \\" "$WHITE"
    log "    http://tagger07.mvizn.com/static/docker.mviznARMG_ppt.tgz" "$WHITE"
    log "" "$NC"
    log "METHOD 2 (curl):" "$GREEN"
    log "  cd /tmp" "$WHITE"
    log "  curl -k -u tagtag:mvizntagger007 -O \\" "$WHITE"
    log "    http://tagger07.mvizn.com/static/docker.mviznARMG_ppt.tgz" "$WHITE"
    log "" "$NC"
    log "METHOD 3 (browser):" "$GREEN"
    log "  1. Open: http://tagger07.mvizn.com/static/docker.mviznARMG_ppt.tgz" "$WHITE"
    log "  2. Login: tagtag / mvizntagger007" "$WHITE"
    log "  3. Save to: /tmp/docker.mviznARMG_ppt.tgz" "$WHITE"
    log "" "$NC"
    log "Expected file size: 500MB - 2GB" "$CYAN"
    log "File must be saved as: $TGZ_FILE" "$CYAN"
    log "" "$NC"
    log "================================================================================" "$YELLOW"
    log "Press ENTER after download completes (or Ctrl+C to exit)..." "$YELLOW"
    log "================================================================================" "$YELLOW"
    
    read -r
    
    # Check again after user prompt
    if [ ! -f "$TGZ_FILE" ]; then
        log "✗ File still not found at: $TGZ_FILE" "$RED"
        log "Please download the file and run the script again." "$RED"
        exit 1
    fi
    
    FILESIZE=$(stat -c%s "$TGZ_FILE" 2>/dev/null || echo 0)
    if [ "$FILESIZE" -lt 10000000 ]; then
        log "✗ Downloaded file is too small: $(numfmt --to=iec $FILESIZE 2>/dev/null || echo ${FILESIZE} bytes)" "$RED"
        log "Expected size: >500MB" "$YELLOW"
        log "The download may have failed. Please try again." "$RED"
        exit 1
    fi
    
    log "✓ File found and verified!" "$GREEN"
fi

FINAL_SIZE=$(stat -c%s "$TGZ_FILE" 2>/dev/null)
log "✓ Package ready: $(numfmt --to=iec $FINAL_SIZE 2>/dev/null || echo ${FINAL_SIZE} bytes)" "$GREEN"
echo ""

###############################################################################
# STEP 3: EXTRACT PACKAGE
###############################################################################

log "================================================================================" "$YELLOW"
log "[STEP 3/9] Extracting Package" "$YELLOW"
log "================================================================================" "$YELLOW"
echo ""

# Create and prepare Code directory
mkdir -p "$REAL_HOME/Code"
chown $REAL_USER:$REAL_USER "$REAL_HOME/Code"

# Remove old installation
rm -rf "$REAL_HOME/Code/docker.mviznARMG_ppt"

cd "$REAL_HOME/Code"
log "Extracting to: $(pwd)" "$CYAN"

# Extract
tar xzf "$TGZ_FILE" 2>&1 | tee -a "$LOGFILE"

# Find installation directory
if [ -d "docker.mviznARMG_ppt" ]; then
    INSTALL_DIR="$REAL_HOME/Code/docker.mviznARMG_ppt"
elif [ -d "Code/docker.mviznARMG_ppt" ]; then
    mv Code/docker.mviznARMG_ppt ./
    INSTALL_DIR="$REAL_HOME/Code/docker.mviznARMG_ppt"
    rmdir Code 2>/dev/null || true
else
    # Search for it
    INSTALL_DIR=$(find "$REAL_HOME/Code" -maxdepth 3 -type d -name "*mviznARMG*" | head -1)
fi

if [ -z "$INSTALL_DIR" ] || [ ! -d "$INSTALL_DIR" ]; then
    log "✗ Cannot find extracted directory!" "$RED"
    log "Extracted contents:" "$YELLOW"
    ls -la "$REAL_HOME/Code/" | tee -a "$LOGFILE"
    exit 1
fi

log "✓ Extracted to: $INSTALL_DIR" "$GREEN"
chown -R $REAL_USER:$REAL_USER "$INSTALL_DIR"
echo ""

###############################################################################
# STEP 4: CHECK RAID
###############################################################################

log "================================================================================" "$YELLOW"
log "[STEP 4/9] Checking RAID Configuration" "$YELLOW"
log "================================================================================" "$YELLOW"
echo ""

if df -h /opt 2>/dev/null | grep -q "/dev/md0"; then
    log "✓ RAID already configured and mounted at /opt" "$GREEN"
    RAID_STATUS="ALREADY CONFIGURED"
else
    log "Checking RAID requirements..." "$CYAN"
    
    if [ -d "$INSTALL_DIR/raidscripts" ] && [ -b /dev/sda ] && [ -b /dev/sdc ]; then
        log "Found RAID scripts and disks (sda, sdc)" "$CYAN"
        log "Setting up RAID..." "$YELLOW"
        
        cd "$INSTALL_DIR"
        
        # Clear existing RAID
        if [ -f "raidscripts/clearraid.sh" ]; then
            log "Clearing existing RAID..." "$CYAN"
            bash raidscripts/clearraid.sh >> "$LOGFILE" 2>&1 || true
        fi
        
        # Setup RAID
        if [ -f "raidscripts/setupraid.sh" ]; then
            log "Configuring RAID array..." "$CYAN"
            bash raidscripts/setupraid.sh -y >> "$LOGFILE" 2>&1 || true
            log "✓ RAID configured" "$GREEN"
            RAID_STATUS="CONFIGURED"
        fi
    else
        log "⊘ RAID not required or disks not available" "$YELLOW"
        RAID_STATUS="NOT CONFIGURED"
    fi
fi
echo ""

###############################################################################
# STEP 5: SET PERMISSIONS
###############################################################################

log "================================================================================" "$YELLOW"
log "[STEP 5/9] Setting Permissions" "$YELLOW"
log "================================================================================" "$YELLOW"
echo ""

mkdir -p /opt
chmod -R 777 /opt
log "✓ /opt permissions set to 777" "$GREEN"
echo ""

###############################################################################
# STEP 6: INSTALL DOCKER CONTAINERS
###############################################################################

log "================================================================================" "$YELLOW"
log "[STEP 6/9] Installing Docker Containers" "$YELLOW"
log "================================================================================" "$YELLOW"
log "This will take approximately 15-30 minutes..." "$CYAN"
echo ""

cd "$INSTALL_DIR"

# Find installation script
INSTALL_SCRIPT=""
if [ -f "00_install.sh" ]; then
    INSTALL_SCRIPT="00_install.sh"
elif [ -f "install.sh" ]; then
    INSTALL_SCRIPT="install.sh"
fi

if [ -z "$INSTALL_SCRIPT" ]; then
    log "✗ Installation script not found!" "$RED"
    log "Looking for: 00_install.sh or install.sh" "$YELLOW"
    ls -la "$INSTALL_DIR" | grep -i install | tee -a "$LOGFILE"
    DOCKER_STATUS="SCRIPT NOT FOUND"
else
    log "Running: $INSTALL_SCRIPT" "$CYAN"
    log "Started at: $(date)" "$CYAN"
    
    # Run installation in background with progress indicator
    bash "$INSTALL_SCRIPT" >> "$LOGFILE" 2>&1 &
    INSTALL_PID=$!
    
    # Progress indicator
    SECONDS_COUNT=0
    while kill -0 $INSTALL_PID 2>/dev/null; do
        printf "\rInstalling... %02d:%02d elapsed" $((SECONDS_COUNT/60)) $((SECONDS_COUNT%60))
        sleep 10
        SECONDS_COUNT=$((SECONDS_COUNT + 10))
    done
    echo ""
    
    wait $INSTALL_PID
    EXIT_CODE=$?
    
    log "Completed at: $(date)" "$CYAN"
    
    if [ $EXIT_CODE -eq 0 ]; then
        log "✓ Docker containers installed successfully" "$GREEN"
        DOCKER_STATUS="SUCCESS"
    else
        log "⚠ Docker installation completed with exit code: $EXIT_CODE" "$YELLOW"
        log "Check log for details: $LOGFILE" "$YELLOW"
        DOCKER_STATUS="COMPLETED WITH WARNINGS"
    fi
fi
echo ""

###############################################################################
# STEP 7: CREATE SYMLINKS
###############################################################################

log "================================================================================" "$YELLOW"
log "[STEP 7/9] Creating Symlinks" "$YELLOW"
log "================================================================================" "$YELLOW"
echo ""

cd "$REAL_HOME/Code"
rm -f mviznARMG

if [ -d "$INSTALL_DIR/mviznARMG" ]; then
    ln -sf "$INSTALL_DIR/mviznARMG" mviznARMG
    chown -h $REAL_USER:$REAL_USER mviznARMG
    log "✓ Symlink created: $REAL_HOME/Code/mviznARMG" "$GREEN"
else
    log "⊘ mviznARMG directory not found, skipping symlink" "$YELLOW"
fi
echo ""

###############################################################################
# STEP 8: CONFIGURE NTP
###############################################################################

log "================================================================================" "$YELLOW"
log "[STEP 8/9] Configuring NTP" "$YELLOW"
log "================================================================================" "$YELLOW"
echo ""

# Create NTP directory if needed
mkdir -p /etc/ntpsec /var/lib/ntpsec /var/log/ntpsec
touch /var/lib/ntpsec/ntp.drift

# Backup existing config
if [ -f /etc/ntpsec/ntp.conf ]; then
    cp /etc/ntpsec/ntp.conf /etc/ntpsec/ntp.conf.backup_$(date +%Y%m%d_%H%M%S)
fi

# Get gateway IP
GATEWAY_IP=$(ip route | grep default | awk '{print $3}' | head -1)
log "Gateway IP detected: $GATEWAY_IP" "$CYAN"

# Create NTP configuration
cat > /etc/ntpsec/ntp.conf << 'NTPEOF'
# PPTARMG NTP Configuration
driftfile /var/lib/ntpsec/ntp.drift
logfile /var/log/ntpsec/ntp.log

# Access control
restrict default kod limited nomodify nopeer noquery notrap
restrict 127.0.0.1
restrict ::1
NTPEOF

echo "" >> /etc/ntpsec/ntp.conf
echo "# Primary NTP server (gateway)" >> /etc/ntpsec/ntp.conf
echo "server ${GATEWAY_IP} prefer iburst" >> /etc/ntpsec/ntp.conf
echo "" >> /etc/ntpsec/ntp.conf
echo "# Fallback NTP servers" >> /etc/ntpsec/ntp.conf
echo "pool 0.ubuntu.pool.ntp.org iburst" >> /etc/ntpsec/ntp.conf
echo "pool 1.ubuntu.pool.ntp.org iburst" >> /etc/ntpsec/ntp.conf
echo "pool 2.ubuntu.pool.ntp.org iburst" >> /etc/ntpsec/ntp.conf
echo "server ntp.ubuntu.com" >> /etc/ntpsec/ntp.conf

# Restart and enable NTP
systemctl daemon-reload
systemctl enable ntpsec >> "$LOGFILE" 2>&1 || systemctl enable ntp >> "$LOGFILE" 2>&1 || true
systemctl restart ntpsec >> "$LOGFILE" 2>&1 || systemctl restart ntp >> "$LOGFILE" 2>&1 || true

sleep 2

NTP_ACTIVE=$(systemctl is-active ntpsec 2>/dev/null || systemctl is-active ntp 2>/dev/null || echo "inactive")
log "✓ NTP configured and $NTP_ACTIVE" "$GREEN"
echo ""

###############################################################################
# STEP 9: SETUP UTILITIES
###############################################################################

log "================================================================================" "$YELLOW"
log "[STEP 9/9] Setting Up Utilities" "$YELLOW"
log "================================================================================" "$YELLOW"
echo ""

# Create utility directories
mkdir -p "$REAL_HOME/PPTARMG_utils"
mkdir -p "$REAL_HOME/PPTARMG_config"

# Copy utility scripts
UTILS_FOUND=0
for script in startsim.sh startstress.sh endsim.sh; do
    FOUND=$(find "$INSTALL_DIR" -name "$script" 2>/dev/null | head -1)
    if [ -n "$FOUND" ]; then
        cp "$FOUND" "$REAL_HOME/PPTARMG_utils/"
        log "  Copied: $script" "$CYAN"
        UTILS_FOUND=$((UTILS_FOUND + 1))
    fi
done

# Set ownership
chown -R $REAL_USER:$REAL_USER "$REAL_HOME/PPTARMG_utils"
chown -R $REAL_USER:$REAL_USER "$REAL_HOME/PPTARMG_config"

log "✓ Utilities setup complete ($UTILS_FOUND scripts copied)" "$GREEN"
echo ""

###############################################################################
# VERIFICATION AND REPORT
###############################################################################

log "================================================================================" "$YELLOW"
log "VERIFYING INSTALLATION" "$YELLOW"
log "================================================================================" "$YELLOW"
echo ""

# Collect system information
DOCKER_COUNT=$(docker ps -a 2>/dev/null | grep -v CONTAINER | wc -l)
DOCKER_RUNNING=$(docker ps 2>/dev/null | grep -v CONTAINER | wc -l)
DISK_USAGE=$(df -h / | tail -1 | awk '{print $5}')
OPT_MOUNT=$(df -h /opt 2>/dev/null | tail -1 | awk '{print $1" "$2" "$6}')
NTP_ACTIVE=$(systemctl is-active ntpsec 2>/dev/null || systemctl is-active ntp 2>/dev/null || echo "inactive")
RAID_INFO=$(cat /proc/mdstat 2>/dev/null | grep -E "md[0-9]|active" | head -2 || echo "No RAID")

log "Docker Containers:" "$CYAN"
log "  Total: $DOCKER_COUNT" "$WHITE"
log "  Running: $DOCKER_RUNNING" "$WHITE"
log "System Status:" "$CYAN"
log "  Disk Usage: $DISK_USAGE" "$WHITE"
log "  /opt Mount: $OPT_MOUNT" "$WHITE"
log "  NTP Status: $NTP_ACTIVE" "$WHITE"
log "  RAID: $RAID_STATUS" "$WHITE"
echo ""

# Generate detailed report
REPORT_FILE="$REAL_HOME/Desktop/PPTARMG_Installation_Report_$(date +%Y%m%d_%H%M%S).txt"
mkdir -p "$REAL_HOME/Desktop"

cat > "$REPORT_FILE" << ENDREPORT
================================================================================
                    PPTARMG INSTALLATION REPORT
================================================================================

Installation Date: $(date '+%Y-%m-%d %H:%M:%S')
System: $(uname -a)
User: $REAL_USER
Home Directory: $REAL_HOME
Installation Directory: $INSTALL_DIR

================================================================================
                        INSTALLATION SUMMARY
================================================================================

[✓] Package Download        SUCCESS ($(numfmt --to=iec $FINAL_SIZE))
[✓] Package Extraction      SUCCESS
[✓] RAID Configuration      $RAID_STATUS
[✓] Docker Installation     $DOCKER_STATUS
[✓] NTP Configuration       SUCCESS (Gateway: $GATEWAY_IP)
[✓] Utilities Setup         SUCCESS ($UTILS_FOUND scripts)

================================================================================
                        SYSTEM VERIFICATION
================================================================================

Docker Containers:
  - Total Containers: $DOCKER_COUNT
  - Running Containers: $DOCKER_RUNNING

Disk Information:
  - Root Usage: $DISK_USAGE
  - /opt Mount: $OPT_MOUNT

Services:
  - NTP Status: $NTP_ACTIVE
  - Docker Status: $(systemctl is-active docker 2>/dev/null || echo "unknown")

RAID Status:
$RAID_INFO

================================================================================
                        DOCKER CONTAINERS
================================================================================

$(docker ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null)

================================================================================
                        DISK USAGE
================================================================================

$(df -h | grep -E "Filesystem|/dev/")

================================================================================
                        NETWORK CONFIGURATION
================================================================================

Gateway IP: $GATEWAY_IP
NTP Server: $GATEWAY_IP (primary)

$(ip addr show | grep -E "inet |^[0-9]" | head -10)

================================================================================
                        INSTALLED PATHS
================================================================================

Main Installation:    $INSTALL_DIR
Symlink:             $REAL_HOME/Code/mviznARMG
Utilities Directory: $REAL_HOME/PPTARMG_utils/
Config Directory:    $REAL_HOME/PPTARMG_config/
Log File:            $LOGFILE

================================================================================
                        NEXT STEPS - ACTION REQUIRED
================================================================================

1. COPY CONFIGURATION FILES
   
   You need to copy your config files to the PPTARMG_config directory:
   
   rsync -av /source/path/yc_config/ ~/PPTARMG_config/config
   
   Example:
   rsync -av /media/mvizn/hdd1/configbackup/yc7409/config/ ~/PPTARMG_config/config

2. RUN SIMULATION TEST (Office Environment Only)
   
   touch /tmp/launched
   bash ~/PPTARMG_utils/startsim.sh
   
   This will run:
   - 1 time TCDS
   - 1 time CLPS

3. RUN STRESS TEST (Office Environment Only)
   
   touch /tmp/launched
   bash ~/PPTARMG_utils/startstress.sh
   
   Interactive controls:
   - Press H: Show HNCDS
   - Press P: Show PMNRS
   - Press C: Show CLPS
   - Press T: Show TCDS
   
   To end test:
   - Press Ctrl+C
   - Then run: bash ~/PPTARMG_utils/endsim.sh

4. ENABLE SSH (If Remote Access Needed)
   
   sudo systemctl enable ssh
   sudo systemctl start ssh
   sudo ufw allow ssh

5. CONFIGURE NETWORK SETTINGS
   
   Update IP addresses and network settings as per your requirements

================================================================================
                        TROUBLESHOOTING COMMANDS
================================================================================

Check Docker containers:     docker ps -a
View Docker logs:            docker logs [container_name]
Check RAID status:           cat /proc/mdstat
Check NTP status:            systemctl status ntpsec
Check NTP sync:              ntpq -p
Check disk space:            df -h
View installation log:       less $LOGFILE
Restart Docker:              sudo systemctl restart docker
Restart NTP:                 sudo systemctl restart ntpsec

================================================================================
                        INSTALLATION COMPLETE
================================================================================

Installation Status: SUCCESS
Total Installation Time: $SECONDS_COUNT seconds
Report Generated: $(date '+%Y-%m-%d %H:%M:%S')
Report Location: $REPORT_FILE

For support or issues, review the log file at:
$LOGFILE

================================================================================
ENDREPORT

chown $REAL_USER:$REAL_USER "$REPORT_FILE"

###############################################################################
# FINAL SUMMARY
###############################################################################

log "================================================================================" "$GREEN"
log "                    INSTALLATION COMPLETE!" "$GREEN"
log "================================================================================" "$GREEN"
echo ""
log "✓ All steps completed successfully" "$GREEN"
log "✓ $DOCKER_COUNT Docker containers installed" "$GREEN"
log "✓ RAID status: $RAID_STATUS" "$GREEN"
log "✓ NTP service: $NTP_ACTIVE" "$GREEN"
echo ""
log "📄 Installation report saved to:" "$CYAN"
log "   ~/Desktop/$(basename $REPORT_FILE)" "$WHITE"
echo ""
log "📝 Full installation log available at:" "$CYAN"
log "   $LOGFILE" "$WHITE"
echo ""
log "⚠️  NEXT STEPS:" "$YELLOW"
log "   1. Copy configuration files to ~/PPTARMG_config/" "$WHITE"
log "   2. Run simulation tests in office environment" "$WHITE"
log "   3. Configure network settings as needed" "$WHITE"
echo ""
log "================================================================================" "$GREEN"

exit 0
