#!/bin/bash

echo "=== Checking LPG Admin Service on Remote Server ==="
echo "Server: 192.168.234.2"
echo ""

# Check if we can SSH to the server
echo "Testing SSH connection..."
ssh -o ConnectTimeout=5 orangepi@192.168.234.2 "echo 'SSH connection successful'" 2>/dev/null

if [ $? -eq 0 ]; then
    echo "Connected to server. Checking service status..."
    
    # Check service status
    ssh orangepi@192.168.234.2 "
        echo '=== Service Status ==='
        sudo systemctl status lpg-admin --no-pager | head -20
        
        echo -e '\n=== Process Information ==='
        ps aux | grep lpg_admin | grep -v grep
        
        echo -e '\n=== Template File Check ==='
        ls -la /home/orangepi/lpg/src/templates/settings_unified.html 2>/dev/null
        
        echo -e '\n=== Checking for margin-bottom in template ==='
        grep 'margin-bottom.*30px' /home/orangepi/lpg/src/templates/settings_unified.html 2>/dev/null
        
        echo -e '\n=== Python Cache Check ==='
        find /home/orangepi/lpg -name '*.pyc' -o -name '__pycache__' | head -10
        
        echo -e '\n=== Last restart time ==='
        sudo systemctl show lpg-admin --property=ActiveEnterTimestamp
    "
else
    echo "Cannot connect to server via SSH"
    echo "Testing with curl instead..."
    
    # Test with curl
    curl -k -s -o /dev/null -w "HTTPS Status: %{http_code}\n" https://192.168.234.2:8443/
    curl -s -o /dev/null -w "HTTP Status: %{http_code}\n" http://192.168.234.2:8443/
fi