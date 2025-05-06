#!/bin/bash


##############################################################################################
######################### INSTALL AND START APACHE / NODE_JS SERVERS #########################

################### Variables ########################
REPO_URL="https://gitlab.com/devops7375008/DevOps_APP.git"
CLONE_DIR="/var/www/html/calculator"
BACKEND_DIR="/var/www/backend"
DB_ENDPOINT_FILE="$BACKEND_DIR/AWS_RDS_ENDPOINT"


# Install / Eenable HTTPD Service:
sudo dnf install -y httpd
sudo systemctl start httpd
sudo systemctl enable httpd

# Create directory for the application
sudo mkdir -p $CLONE_DIR

# Install git
sudo dnf install -y git
sudo git clone $REPO_URL $CLONE_DIR
sudo chown -R apache:apache $CLONE_DIR


# Install Node.js 18.x from NodeSource
curl -fsSL https://rpm.nodesource.com/setup_18.x | sudo bash -
sudo dnf install -y nodejs 

# Create directory for the backend and set up Node.js environment
sudo mkdir -p $BACKEND_DIR
sudo chown -R apache:apache $BACKEND_DIR
sudo npm init -y

# Move server.js and package.json to the backend directory
sudo mv $CLONE_DIR/src_backend/server.js $BACKEND_DIR/
sudo mv $CLONE_DIR/package.json $BACKEND_DIR/

# Navigate to backend directory and install NodeJS dependencies
cd $BACKEND_DIR
sudo npm install

# Create virtual host configuration
cat <<EOL | tee /etc/httpd/conf.d/calculator.conf
<VirtualHost *:80>
    DocumentRoot "$CLONE_DIR/public_frontend"
    <Directory "$CLONE_DIR/public_frontend">
        AllowOverride None
        Require all granted
    </Directory>
</VirtualHost>
EOL



# Add the RDS endpoint to a file for application use
echo "db_endpoint=${db_endpoint}" > $DB_ENDPOINT_FILE

# Extract just the hostname from the endpoint
DB_ENDPOINT=$(cat $DB_ENDPOINT_FILE | awk -F= '{print $2}' | sed 's/:3306//')

# Replace the placeholder in server.js
sudo sed -i "s|database-1.c9cyo2wmq0yg.us-east-1.rds.amazonaws.com|$DB_ENDPOINT|g" $BACKEND_DIR/server.js

# Restart httpd to apply the new configuration
sudo systemctl restart httpd

# Start Node.js 
nohup node $BACKEND_DIR/server.js > $BACKEND_DIR/server.log 2>&1 &



#####################################################################################
###################### AUTOMATIC (Hostname) DNS REGISTRATION ########################

# Fetch the unique EC2 instance ID from the AWS instance metadata service.
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)

# Fetch the private IPv4 address of the EC2 instance.
LOCAL_IP=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)

# Construct a hostname using the private IP:
HOSTNAME="web-server-${LOCAL_IP//./-}"

# Set the system hostname to the constructed value:
hostnamectl set-hostname $HOSTNAME


## Automatic DNS Registration for every EC2 inside the ASG: [Under Construction!] 
#aws route53 change-resource-record-sets --hosted-zone-id ${aws_route53_zone.private.zone_id} --change-batch '{
#      "Changes": [{
#        "Action": "UPSERT",
#        "ResourceRecordSet": {
#          "Name": "'$HOSTNAME'.internal.myapp.local",
#          "Type": "A",
#          "TTL": 60,
#          "ResourceRecords": [{ "Value": "'$LOCAL_IP'" }]
#        }
#      }]
#    }'
#  EOF
#  )
#}




#####################################################################################
############################### INSTALL NODE EXPORTER ###############################

# Node_exporter version: (1.9.0):
useradd -M -r -s /bin/false node_exporter
mkdir /var/lib/node_exporter
cd /var/lib/node_exporter
wget https://github.com/prometheus/node_exporter/releases/download/v1.9.0/node_exporter-1.9.0.linux-amd64.tar.gz
tar -xzf node_exporter-1.9.0.linux-amd64.tar.gz
cp node_exporter-1.9.0.linux-amd64/node_exporter /usr/local/bin
chown node_exporter:node_exporter /usr/local/bin/node_exporter


# SystemD Config: 
cat <<EOL | tee /etc/systemd/system/node_exporter.service
[Unit]
Description=Node Exporter
Documentation=https://prometheus.io/docs/guides/node-exporter/
Wants=network-online.target
After=network-online.target

[Service]
User=node_exporter
Group=node_exporter
Type=simple
Restart=on-failure
ExecStart=/usr/local/bin/node_exporter \
  --web.listen-address=:9100

[Install]
WantedBy=multi-user.target
EOL


# Reload all systemd services: 
chmod 664 /etc/systemd/system/node_exporter.service
sudo systemctl daemon-reload
sudo systemctl enable node_exporter.service
sudo systemctl start node_exporter.service
