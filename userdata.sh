#! /bin/bash

# Log file location
LOG_FILE="/var/log/user-data.log"

# Redirect all output (stdout & stderr) to the log file
exec > >(tee -a $LOG_FILE) 2>&1

# INSTALL GIT AND NGINX
dnf install git nginx -y

# INSTALL NODE.JS
curl -fsSL https://rpm.nodesource.com/setup_20.x | bash -
dnf install nodejs -y
npm -v
node -v

# INSTALL PM2
npm install -g pm2
pm2 --version

# INSTALL amazon-efs-utils for EFS mounting
dnf install -y amazon-efs-utils

# Create mount directory for EFS and mount it using your EFS ID
mkdir -p /mnt/efs/assets
sudo mount -t efs fs-0c8891c9eefc53d04:/ /mnt/efs/assets

# CLONE YOUR GITHUB REPOSITORY
mkdir -p /home/ec2-user/apps
cd /home/ec2-user/apps/
git clone https://github.com/tw0316/nobl-deed-storefront.git

# SWITCH TO THE PROJECT DIRECTORY AND INSTALL DEPENDENCIES
cd /home/ec2-user/apps/nobl-deed-storefront
npm install

# START THE APPLICATION USING PM2 (adjust the command if needed)
cd /home/ec2-user/apps/nobl-deed-storefront
pm2 start npm --name "nobl-deed-storefront" -- run start

# CONFIGURE NGINX AS A REVERSE PROXY
sudo tee /etc/nginx/nginx.conf > /dev/null <<'EOL'
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log;
pid /run/nginx.pid;
events {
    worker_connections 1024;
}
http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    sendfile on;
    keepalive_timeout 65;
    server {
        listen 80;
        server_name yourdomain.com;  # Replace with your actual domain or use _ as a wildcard
        location / {
            proxy_pass http://localhost:3000/;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection 'upgrade';
            proxy_set_header Host $host;
            proxy_cache_bypass $http_upgrade;
        }
    }
}
EOL

# Restart and enable NGINX
systemctl restart nginx
systemctl enable nginx