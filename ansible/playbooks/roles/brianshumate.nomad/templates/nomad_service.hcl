[Unit]
Description=Nomad Server
After=network.target

[Service]
ExecStart=/usr/local/bin/nomad agent -config=/etc/nomad.d/
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target

