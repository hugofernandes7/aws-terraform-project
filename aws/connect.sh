#!/bin/bash

bastion=$(terraform output -raw bastion_ip)
nomad_server=$(terraform output -raw nomad_server)
runner=$(terraform output -raw runner)
nomad_clients=$(terraform output -json asg_nomad_all_clients | jq -r '.[]')

cat > ~/.ssh/config << EOF
### The Bastion
Host bastion
 HostName ${bastion}
 User ubuntu
 IdentityFile ~/.ssh/my-key-aws

### Nomad Server
Host nomad-server
  HostName ${nomad_server}
  User ubuntu
  IdentityFile ~/.ssh/my-key-aws
  ProxyJump bastion

### Runner
Host runner
  HostName ${runner}
  User ubuntu
  IdentityFile ~/.ssh/my-key-aws
  ProxyJump bastion
EOF

i=1
for ip in $nomad_clients; do
cat >> ~/.ssh/config << EOF

### Nomad client $i
Host nomad-client-$i
  HostName $ip
  User ubuntu
  IdentityFile ~/.ssh/my-key-aws
  ProxyJump bastion
EOF

i=$((i+1))
done
