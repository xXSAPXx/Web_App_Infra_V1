#!/bin/bash


#####################################################################################
###################### AUTOMATIC (Hostname) DNS REGISTRATION ########################

# Generate a token lastng 6-hours for the EC2 metadata retrival process from AWS: 
TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")

# Fetch the private IPv4 address of the EC2 instance.
LOCAL_IP=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/local-ipv4)

# Construct a hostname using the private IP:
HOSTNAME="bastion-prometheus-host-$${LOCAL_IP//./-}.internal.xxsapxx.local"

# Set the system hostname to the constructed value:
sudo hostnamectl set-hostname $HOSTNAME



# Install AWS CLI: 
sudo dnf install -y awscli


##### NEEDS IAM ROLE --- (BECAUSE AWS CLI ASKS FOR CREDENTIALS): 

# Automatic DNS Registration for every EC2 inside the ASG: 
#sudo aws route53 change-resource-record-sets --hosted-zone-id "$PRIVATE_DNS_ZONE_ID" --change-batch "{
#  \"Comment\": \"Register DNS Record for EC2 instance in Route53 private_zone \",
#  \"Changes\": [{
#    \"Action\": \"UPSERT\",
#    \"ResourceRecordSet\": {
#      \"Name\": \"$HOSTNAME\",
#      \"Type\": \"A\",
#      \"TTL\": 120,
#      \"ResourceRecords\": [{ \"Value\": \"$LOCAL_IP\" }]
#    }
#  }]
#}"


#####################################################################################
############################### INSTALL PROMETHEUS ##################################

# Variables:
PROMETHEUS_SYSTEMD_UNIT_FILE="/etc/systemd/system/prometheus.service"
PROMETHEUS_BINARY_DIR="/usr/local/bin"
PROMETHEUS_CONF_DIR="/etc/prometheus"
PROMETHEUS_DIR="/var/lib/prometheus"
PROMETHEUS_VERSION="2.53.4"


# Install packages needed and upgrade the system:
sudo dnf install -y bash-completion
sudo dnf install -y vim
sudo dnf install -y wget
sudo dnf upgrade -y


# Configure directories / users and groups: 
sudo id -u prometheus &>/dev/null || sudo useradd -M -r -s /bin/false prometheus
sudo mkdir -p $PROMETHEUS_CONF_DIR $PROMETHEUS_DIR
cd $PROMETHEUS_DIR


# Install Prometheus LTS Version (2.53.4):
sudo wget https://github.com/prometheus/prometheus/releases/download/v$PROM_VERSION/prometheus-$PROM_VERSION.linux-amd64.tar.gz
sudo tar -xzf prometheus-$PROM_VERSION.linux-amd64.tar.gz


# Copy the binary files to default locations: 
sudo cp prometheus-2.53.4.linux-amd64/{prometheus,promtool} $PROMETHEUS_BINARY_DIR
sudo chown prometheus:prometheus $PROMETHEUS_BINARY_DIR/{prometheus,promtool}
sudo cp -r prometheus-2.53.4.linux-amd64/{consoles,console_libraries} $PROMETHEUS_CONF_DIR
sudo cp prometheus-2.53.4.linux-amd64/prometheus.yml $PROMETHEUS_CONF_DIR


# Change directory permissions: 
sudo chown -R prometheus:prometheus $PROMETHEUS_CONF_DIR
sudo chown -R prometheus:prometheus $PROMETHEUS_DIR


# Create Prometheus systemd service unit file: 
sudo cat <<EOL | sudo tee $PROMETHEUS_SYSTEMD_UNIT_FILE
[Unit]
Description=Prometheus Time Series Collection and Processing Server
Wants=network-online.target
After=network-online.target

[Service]
User=prometheus
Group=prometheus
Type=simple
ExecStart=$PROMETHEUS_BINARY_DIR/prometheus \
  --config.file $PROMETHEUS_CONF_DIR/prometheus.yml \
  --storage.tsdb.path $PROMETHEUS_DIR/ \
  --web.console.templates=$PROMETHEUS_CONF_DIR/consoles \
  --web.console.libraries=$PROMETHEUS_CONF_DIR/console_libraries
  
[Install]
WantedBy=multi-user.target
EOL


# Reload all systemd services: 
sudo chmod 664 $PROMETHEUS_SYSTEMD_UNIT_FILE
sudo systemctl daemon-reload
sudo systemctl enable prometheus.service
sudo systemctl start prometheus.service


# Configure Prometheus settings: [AUTO DISCOVERY SERVICE + SEND METRICS TO GRAFANA CLOUD]
# IAM ROLE NEEDED FOR THE AUTO DISCOVERY SERVICE: 
sudo cat <<EOL | sudo tee $PROMETHEUS_CONF_DIR/prometheus.yml
# My global config:
global:
  scrape_interval: 60s
remote_write:
  - url: https://prometheus-prod-24-prod-eu-west-2.grafana.net/api/prom/push
    basic_auth:
      username: 1968384
      password: glc_eyJvIjoiMTMwNTgzNiIsIm4iOiJzdGFjay0xMTI1NjY3LWFsbG95LWF3c19wcm9tZXRoZXVzIiwiayI6IjFSNmVrMERzVEEyTDB3OTNodjlLbDQ2cyIsIm0iOnsiciI6InByb2QtZXUtd2VzdC0yIn19

# Alertmanager configuration
alerting:
  alertmanagers:
    - static_configs:
        - targets:
          # - alertmanager:9093

# Load rules once and periodically evaluate them according to the global 'evaluation_interval'.
rule_files:
  # - "first_rules.yml"
  # - "second_rules.yml"

# A scrape configuration containing exactly one endpoint to scrape:
# Here it's Prometheus itself.
scrape_configs:

  # Prometheus self-scraping
  - job_name: "prometheus"
    static_configs:
      - targets: ["localhost:9090"]

  # EC2 dynamic discovery
  - job_name: "ec2-instances"
    ec2_sd_configs:
      - region: us-east-1
    relabel_configs:
      - source_labels: [__meta_ec2_private_ip]
        target_label: __address__
        replacement: '${1}:9100'
EOL



#####################################################################################
############################### INSTALL NODE EXPORTER ###############################

NODE_EXPORTER_UNIT_FILE="/etc/systemd/system/node_exporter.service"
NODE_EXPORTER_DIR="/var/lib/node_exporter"
NODE_EXPORTER_BINARY_DIR="/usr/local/bin"
NODE_EXPORTER_USER="node_exporter"
NODE_EXPORTER_VERSION="1.9.0"


# Configure everthing and download the mentioned node_exporter version: 
if ! id "$NODE_EXPORTER_USER" &>/dev/null; then
  sudo useradd -M -r -s /bin/false $NODE_EXPORTER_USER
fi

sudo mkdir -p $NODE_EXPORTER_DIR
cd $NODE_EXPORTER_DIR
sudo dnf install -y wget
sudo wget https://github.com/prometheus/node_exporter/releases/download/v$NODE_EXPORTER_VERSION/node_exporter-$NODE_EXPORTER_VERSION.linux-amd64.tar.gz
sudo tar -xzf node_exporter-$NODE_EXPORTER_VERSION.linux-amd64.tar.gz
sudo cp node_exporter-$NODE_EXPORTER_VERSION.linux-amd64/node_exporter $NODE_EXPORTER_BINARY_DIR
sudo chown "$NODE_EXPORTER_USER":"$NODE_EXPORTER_USER" $NODE_EXPORTER_BINARY_DIR/node_exporter


# SystemD Config: 
sudo cat <<EOL | sudo tee $NODE_EXPORTER_UNIT_FILE
[Unit]
Description=Node_Exporter
Documentation=https://prometheus.io/docs/guides/node-exporter/
Wants=network-online.target
After=network-online.target

[Service]
User=$NODE_EXPORTER_USER
Group=$NODE_EXPORTER_USER
Type=simple
Restart=on-failure
ExecStart=$NODE_EXPORTER_BINARY_DIR/node_exporter \
  --web.listen-address=:9100

[Install]
WantedBy=multi-user.target
EOL


# Reload all systemd services: 
sudo chmod 664 $NODE_EXPORTER_UNIT_FILE
sudo systemctl daemon-reload
sudo systemctl enable node_exporter.service
sudo systemctl start node_exporter.service