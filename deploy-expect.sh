#!/usr/bin/expect -f
# LPG Deployment via Expect
# This script automates SSH deployment

set timeout 300
set host "192.168.234.2"
set user "lacissystem"
set password "lacis12345@"

# Stage 1: Copy deployment package
puts "=== Stage 1: Copying deployment package ==="
spawn scp lpg-deploy-v2.tar.gz $user@$host:/home/lacissystem/
expect {
    "continue connecting" {
        send "yes\r"
        expect "password:"
        send "$password\r"
    }
    "password:" {
        send "$password\r"
    }
}
expect eof

# Stage 2: Extract and setup
puts "\n=== Stage 2: Extracting and running setup ==="
spawn ssh $user@$host
expect "password:"
send "$password\r"
expect "$ "

# Extract package
send "cd /home/lacissystem\r"
expect "$ "
send "tar -xzf lpg-deploy-v2.tar.gz\r"
expect "$ "

# Make scripts executable
send "chmod +x scripts/*.sh\r"
expect "$ "

# Run setup with sudo
send "sudo ./scripts/setup-lpg.sh\r"
expect {
    "password for lacissystem:" {
        send "$password\r"
    }
}

# Wait for setup to complete
set timeout 600
expect {
    "Completed at:" {
        puts "\nSetup completed successfully!"
    }
    timeout {
        puts "\nSetup timed out - check manually"
    }
}

# Check status
send "sudo systemctl status caddy --no-pager\r"
expect "$ "

send "sudo systemctl status vsftpd --no-pager\r"
expect "$ "

send "exit\r"
expect eof

puts "\n=== Deployment Complete ==="
puts "Access points:"
puts "- Admin UI: https://192.168.234.2:8443"
puts "- Main URL: https://akb001yebraxfqsm9y.dyndns-web.com/lacisstack/"