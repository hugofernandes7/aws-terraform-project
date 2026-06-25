#!/bin/bash
set -e

apt-get update -y
apt-get install -y wget unzip

apt install docker.io -y
systemctl enable docker
systemctl start docker

wget https://releases.hashicorp.com/nomad/1.7.7/nomad_1.7.7_linux_amd64.zip
unzip nomad_1.7.7_linux_amd64.zip
sudo mv nomad /usr/local/bin/

mkdir -p /etc/nomad.d

cat <<EOF > /etc/nomad.d/client.hcl
datacenter = "dc1"
data_dir   = "/opt/nomad"

client {
  enabled = true
  servers = ["${server_ip}:4647"]
}
EOF

sudo tee /etc/systemd/system/nomad.service > /dev/null <<EOF
[Unit]
Description=Nomad Client
After=network.target

[Service]
ExecStart=/usr/local/bin/nomad agent -config=/etc/nomad.d/
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable nomad
sudo systemctl start nomad

