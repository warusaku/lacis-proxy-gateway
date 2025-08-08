#!/bin/bash
# LPG Clean Installation - SD Card Writer
# Purpose: Safely write Orange Pi image to SD card

set -e

# Configuration
DISK_NUMBER="5"
DISK_DEVICE="/dev/disk${DISK_NUMBER}"
RDISK_DEVICE="/dev/rdisk${DISK_NUMBER}"
IMAGE_PATH="/Volumes/crucial_MX500/lacis_project/project/LPG/diskimage/Orangepizero3_1.0.2_ubuntu_jammy_server_linux6.1.31.img"
BACKUP_DIR="$HOME/LPG_Backups"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}======================================${NC}"
echo -e "${YELLOW}   LPG SD Card Image Writer${NC}"
echo -e "${YELLOW}======================================${NC}"
echo ""

# Check if running on macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo -e "${RED}Error: This script is for macOS only${NC}"
    exit 1
fi

# Check if image exists
if [ ! -f "$IMAGE_PATH" ]; then
    echo -e "${RED}Error: Image file not found at $IMAGE_PATH${NC}"
    exit 1
fi

# Show disk information
echo "Current disk information:"
diskutil list | grep -A 5 "disk${DISK_NUMBER}"
echo ""

# Confirm disk selection
echo -e "${YELLOW}⚠️  WARNING: This will ERASE all data on ${DISK_DEVICE}${NC}"
read -p "Are you sure disk${DISK_NUMBER} is the correct SD card? (yes/no): " confirmation

if [ "$confirmation" != "yes" ]; then
    echo "Operation cancelled"
    exit 1
fi

# Ask about backup
read -p "Do you want to backup the current SD card first? (yes/no): " backup_choice

if [ "$backup_choice" = "yes" ]; then
    echo -e "${GREEN}Creating backup...${NC}"
    mkdir -p "$BACKUP_DIR"
    BACKUP_FILE="$BACKUP_DIR/sdcard_backup_$(date +%Y%m%d_%H%M%S).img"
    echo "Backing up to: $BACKUP_FILE"
    sudo dd if="${RDISK_DEVICE}" of="$BACKUP_FILE" bs=4m status=progress
    echo -e "${GREEN}Backup completed: $BACKUP_FILE${NC}"
fi

# Unmount the disk
echo -e "${GREEN}Unmounting disk...${NC}"
diskutil unmountDisk "${DISK_DEVICE}"

# Write the image
echo -e "${GREEN}Writing Orange Pi image to SD card...${NC}"
echo "This will take approximately 10-15 minutes"
sudo dd if="${IMAGE_PATH}" of="${RDISK_DEVICE}" bs=4m status=progress

# Sync
echo -e "${GREEN}Syncing...${NC}"
sync

# Eject the disk
echo -e "${GREEN}Ejecting SD card...${NC}"
diskutil eject "${DISK_DEVICE}"

echo ""
echo -e "${GREEN}✅ SD card preparation completed!${NC}"
echo ""
echo "Next steps:"
echo "1. Insert the SD card into Orange Pi Zero 3"
echo "2. Connect power (5V/3A recommended)"
echo "3. Wait 2 minutes for boot"
echo "4. SSH to: ssh orangepi@192.168.234.2"
echo "   Default password: orangepi"
echo ""
echo -e "${YELLOW}Remember: Always use LPG_ADMIN_HOST=127.0.0.1${NC}"