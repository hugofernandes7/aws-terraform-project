#!/bin/bash
set -e 

export DEBIAN_FRONTEND=noninterective

sudo apt-get update -y 
 
sudo apt install docker.io -y

