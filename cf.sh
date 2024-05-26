#!/bin/bash

# Define the domain you already have hosted on Cloudflare DNS
CLOUDFLARE_DNS_NAME="YOUR.DOMAIN.COM"
# Adapt your domain to GCP naming conventions
GCP_DNS_NAME="YOUR-DOMAIN-COM"
# Define the static external IP for your GCP VM
GCP_IP_ADDRESS="YOUR_STATIC_IP_ADDRESS"
# Define the service port you want forwarded on your VM this assumes you only have one
SERVICE_PORT="YOUR_SERVICE_PORT"

# Add cloudflare gpg key
sudo mkdir -p --mode=0755 /usr/share/keyrings
curl -fsSL https://pkg.cloudflare.com/cloudflare-main.gpg | sudo tee /usr/share/keyrings/cloudflare-main.gpg >/dev/null

# Add this repo to your apt repositories
echo 'deb [signed-by=/usr/share/keyrings/cloudflare-main.gpg] https://pkg.cloudflare.com/cloudflared jammy main' | sudo tee /etc/apt/sources.list.d/cloudflared.list

# install cloudflared
sudo apt-get update && sudo apt-get install cloudflared

sudo cloudflared tunnel login

sudo cloudflared tunnel create $GCP_DNS_NAME

sudo cloudflared tunnel route ip add $GCP_IP_ADDRESS/32 $GCP_DNS_NAME

sudo cloudflared tunnel route dns $GCP_DNS_NAME $CLOUDFLARE_DNS_NAME

tunnel_id=$(sudo cloudflared tunnel info $GCP_DNS_NAME | grep -oP 'Your tunnel \K([a-z0-9-]+)')

# Create config file
mkdir /etc/cloudflared

echo "tunnel: $GCP_DNS_NAME" > /etc/cloudflared/config.yml
echo "credentials-file: /root/.cloudflared/$tunnel_id.json" >> /etc/cloudflared/config.yml
echo "protocol: quic" >> /etc/cloudflared/config.yml
echo "logfile: /var/log/cloudflared.log" >> /etc/cloudflared/config.yml
echo "loglevel: debug" >> /etc/cloudflared/config.yml
echo "transport-loglevel: info" >> /etc/cloudflared/config.yml
echo "ingress:" >> /etc/cloudflared/config.yml
echo "  - hostname: $CLOUDFLARE_DNS_NAME" >> /etc/cloudflared/config.yml
echo "    service: http://localhost:$SERVICE_PORT" >> /etc/cloudflared/config.yml
echo "  - service: http_status:404" >> /etc/cloudflared/config.yml

cloudflared service install

systemctl start cloudflared
systemctl status cloudflared
