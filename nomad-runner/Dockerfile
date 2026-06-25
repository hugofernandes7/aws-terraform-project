FROM ubuntu:22.04
RUN apt-get update -y \
    && apt-get install -y wget unzip \
    && wget -q https://releases.hashicorp.com/nomad/1.7.7/nomad_1.7.7_linux_amd64.zip -O /tmp/nomad.zip \
    && unzip /tmp/nomad.zip -d /tmp/ \
    && mv /tmp/nomad /usr/local/bin/nomad \
    && chmod +x /usr/local/bin/nomad \
    && rm /tmp/nomad.zip \
    && nomad version

