#!/bin/bash

set -e

cd /ops

CONFIGDIR=/ops/shared/config

CONSULVERSION=1.3.1
CONSULDOWNLOAD=https://releases.hashicorp.com/consul/${CONSULVERSION}/consul_${CONSULVERSION}_linux_amd64.zip
CONSULCONFIGDIR=/etc/consul.d
CONSULDIR=/opt/consul

VAULTVERSION=1.2.3
VAULTDOWNLOAD=https://releases.hashicorp.com/vault/${VAULTVERSION}/vault_${VAULTVERSION}_linux_amd64.zip
VAULTCONFIGDIR=/etc/vault.d
VAULTDIR=/opt/vault

NOMADVERSION=0.9.5
NOMADDOWNLOAD=https://releases.hashicorp.com/nomad/${NOMADVERSION}/nomad_${NOMADVERSION}_linux_amd64.zip
NOMADCONFIGDIR=/etc/nomad.d
NOMADDIR=/opt/nomad

# Dependencies
sudo apt-get install -y software-properties-common
sudo apt-get update
sudo apt-get install -y unzip redis-tools jq
sudo apt-get install -y unzip tree redis-tools jq
sudo apt-get install -y systemd-sysv
sudo update-initramfs -u

# Disable the firewall
sudo ufw disable

# Download Consul
curl -L $CONSULDOWNLOAD >consul.zip

## Install Consul
sudo unzip consul.zip -d /usr/local/bin
sudo chmod 0755 /usr/local/bin/consul
sudo chown root:root /usr/local/bin/consul

## Configure Consul
sudo mkdir -p $CONSULCONFIGDIR
sudo chmod 755 $CONSULCONFIGDIR
sudo mkdir -p $CONSULDIR
sudo chmod 755 $CONSULDIR

# Download Vault
curl -L $VAULTDOWNLOAD >vault.zip

## Install Vault
sudo unzip vault.zip -d /usr/local/bin
sudo chmod 0755 /usr/local/bin/vault
sudo chown root:root /usr/local/bin/vault

## Configure Vault
sudo mkdir -p $VAULTCONFIGDIR
sudo chmod 755 $VAULTCONFIGDIR
sudo mkdir -p $VAULTDIR
sudo chmod 755 $VAULTDIR

# Download Nomad
curl -L $NOMADDOWNLOAD >nomad.zip

## Install Nomad
sudo unzip nomad.zip -d /usr/local/bin
sudo chmod 0755 /usr/local/bin/nomad
sudo chown root:root /usr/local/bin/nomad

## Configure Nomad
sudo mkdir -p $NOMADCONFIGDIR
sudo chmod 755 $NOMADCONFIGDIR
sudo mkdir -p $NOMADDIR
sudo chmod 755 $NOMADDIR

# Docker
sudo apt install -y apt-transport-https ca-certificates curl software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
sudo apt-get update
sudo apt-get install -y docker-ce
#sudo usermod -a -G docker ubuntu
sudo sysctl -w vm.max_map_count=262144
echo "Final Line of Code"
