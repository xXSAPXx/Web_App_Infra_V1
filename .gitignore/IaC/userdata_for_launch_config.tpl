#!/bin/bash

# Update and install httpd
sudo yum update -y
sudo yum install -y httpd

# Start and enable httpd
sudo systemctl start httpd
sudo systemctl enable httpd

# Create directory for the application
sudo mkdir -p /var/www/html/calculator

# Install git
sudo yum install -y git



### Variables ###
REPO_URL="https://github.com/xXSAPXx/Calculator_APP.git"
CLONE_DIR="/var/www/html/calculator"
BACKEND_DIR="/var/www/backend"
HTML_FILE="$CLONE_DIR/public/index.html"
DB_ENDPOINT_FILE="$BACKEND_DIR/AWS_RDS_ENDPOINT"




# Fetch application files from GitHub
sudo git clone $REPO_URL $CLONE_DIR

# Change ownership of the files to the apache user
sudo chown -R apache:apache $CLONE_DIR

# Get the current public IP address
CURRENT_IP=$(curl -s ifconfig.me)

# Replace the old IP address with the new one in the HTML file
sudo sed -i "s|http://34.201.114.206:3000|http://$CURRENT_IP:3000|g" "$HTML_FILE"

# Verify that the replacement was successful
grep "http://$CURRENT_IP:3000" "$HTML_FILE"



# Install Node.js 18.x from NodeSource
curl -fsSL https://rpm.nodesource.com/setup_18.x | sudo bash -
sudo yum install -y nodejs 

# Create directory for the backend and set up Node.js environment
sudo mkdir -p $BACKEND_DIR
sudo chown -R apache:apache $BACKEND_DIR
sudo npm init -y

# Move server.js and package.json to the backend directory
sudo mv $CLONE_DIR/src/server.js $BACKEND_DIR/
sudo mv $CLONE_DIR/package.json $BACKEND_DIR/

# Navigate to backend directory and install NodeJS dependencies
cd $BACKEND_DIR
sudo npm install

# Create virtual host configuration
cat <<EOL | sudo tee /etc/httpd/conf.d/calculator.conf
<VirtualHost *:80>
    DocumentRoot "$CLONE_DIR/public"
    <Directory "$CLONE_DIR/public">
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
