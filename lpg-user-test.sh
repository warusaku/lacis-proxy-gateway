#!/bin/bash
# Test different user combinations for LPG

echo "=== Testing LPG SSH Access ==="
echo "Target: 192.168.234.2"
echo ""

# Common default usernames and passwords for Orange Pi/Armbian
users=("root" "orangepi" "pi" "admin" "lacissystem")
passwords=("1234" "orangepi" "orangepizero3" "admin" "lacis12345@")

echo "Testing common username/password combinations..."
echo "(Note: This is for troubleshooting only)"
echo ""

for user in "${users[@]}"; do
    echo "Testing user: $user"
    
    # Use timeout to avoid hanging
    timeout 5 ssh -o ConnectTimeout=3 -o PasswordAuthentication=yes -o PreferredAuthentications=password $user@192.168.234.2 "echo 'Success with user: $user'; exit" 2>&1 | grep -E "(Success|Permission denied|password:)"
    
    echo ""
done

echo "=== Alternative Approach ==="
echo ""
echo "If none of the above work, consider:"
echo "1. Physical access to the device (monitor + keyboard)"
echo "2. Re-flashing the SD card with a fresh image"
echo "3. Checking the Omada logs for the correct device"
echo ""
echo "The device at 192.168.234.2 might be:"
echo "- Already configured with unknown credentials"
echo "- A different device than expected"
echo "- Running a different OS than Armbian"