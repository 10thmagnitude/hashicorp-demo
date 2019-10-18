#!/bin/bash

set -e

CONFIGDIR=/ops/shared/config

CONSULCONFIGDIR=/etc/consul.d
VAULTCONFIGDIR=/etc/vault.d
NOMADCONFIGDIR=/etc/nomad.d
HOME_DIR=ssdemo

# Wait for network
sleep 15

CONSUL_ENCRYPT_KEY=$(consul keygen)
DOCKER_BRIDGE_IP_ADDRESS=$(ifconfig docker0 2>/dev/null | awk '/inet/ {print $2}')
SERVER_COUNT=$1
IP_ADDRESS=$2

# Consul
id -u consul &>/dev/null || sudo useradd --system --home /etc/consul.d --shell /bin/false consul
sudo chown --recursive consul:consul /opt/consul
sudo cp $CONFIGDIR/consul.service /etc/systemd/system/consul.service
sudo mkdir --parents /etc/consul.d
sudo cp $CONFIGDIR/consul.hcl $CONSULCONFIGDIR
sudo sed -i "s/IP_ADDRESS/$IP_ADDRESS/g" $CONSULCONFIGDIR/consul.hcl
sudo sed -i "s/CONSUL_ENCRYPT_KEY/$CONSUL_ENCRYPT_KEY/g" $CONSULCONFIGDIR/consul.hcl
sudo chown --recursive consul:consul $CONSULCONFIGDIR
sudo chmod 640 $CONSULCONFIGDIR/consul.hcl
sudo cp $CONFIGDIR/consul_server.hcl $CONSULCONFIGDIR/server.hcl
sudo sed -i "s/SERVER_COUNT/$SERVER_COUNT/g" $CONSULCONFIGDIR/server.hcl

sudo systemctl enable consul
sudo systemctl start consul
sudo systemctl status consul
sleep 10
export CONSUL_HTTP_ADDR=$IP_ADDRESS:8500
export CONSUL_RPC_ADDR=$IP_ADDRESS:8400

# Vault
id -u vault &>/dev/null || sudo useradd --system --home /etc/vault.d --shell /bin/false vault
sudo cp $CONFIGDIR/vault.hcl $VAULTCONFIGDIR
sudo sed -i "s/IP_ADDRESS/$IP_ADDRESS/g" $VAULTCONFIGDIR/vault.hcl
sudo cp $CONFIGDIR/vault.service /etc/systemd/system/vault.service
sudo chown --recursive vault:vault /etc/vault.d
sudo chmod 640 /etc/vault.d/vault.hcl

sudo systemctl enable vault
sudo systemctl start vault
sudo systemctl status vault

# Nomad
sudo cp $CONFIGDIR/nomad.hcl $NOMADCONFIGDIR
sudo cp $CONFIGDIR/nomad_upstart.conf /etc/init/nomad.conf
sudo sed -i "s/IP_ADDRESS/$IP_ADDRESS/g" $NOMADCONFIGDIR/nomad.hcl
sudo sed -i "s/SERVER_COUNT/$SERVER_COUNT/g" $NOMADCONFIGDIR/nomad.hcl

#sudo service nomad start
#sleep 10
export NOMAD_ADDR=http://$IP_ADDRESS:4646

# Add hostname to /etc/hosts
echo "127.0.0.1 $(hostname)" | sudo tee --append /etc/hosts

# Add Docker bridge network IP to /etc/resolv.conf (at the top)
echo "nameserver $DOCKER_BRIDGE_IP_ADDRESS" | sudo tee /etc/resolv.conf.new
cat /etc/resolv.conf | sudo tee --append /etc/resolv.conf.new
sudo mv /etc/resolv.conf.new /etc/resolv.conf

# Add search service.consul at bottom of /etc/resolv.conf
echo "search service.consul" | sudo tee --append /etc/resolv.conf

# Set env vars for tool CLIs
echo "export CONSUL_RPC_ADDR=$IP_ADDRESS:8400" | sudo tee --append /home/$HOME_DIR/.bashrc
echo "export CONSUL_HTTP_ADDR=$IP_ADDRESS:8500" | sudo tee --append /home/$HOME_DIR/.bashrc
echo "export VAULT_ADDR=http://$IP_ADDRESS:8200" | sudo tee --append /home/$HOME_DIR/.bashrc
echo "export NOMAD_ADDR=http://$IP_ADDRESS:4646" | sudo tee --append /home/$HOME_DIR/.bashrc

# Move weave and scope to /usr/bin
# and daemon.json to /etc/docker
sudo mv /home/ssdemo/weave /usr/bin/weave
sudo mv /home/ssdemo/scope /usr/bin/scope
sudo echo {\"cluster-store\":\"consul://127.0.0.1:8500\"} >/home/ssdemo/daemon.json
sudo mkdir -p /etc/docker
sudo mv /home/ssdemo/daemon.json /etc/docker/daemon.json

# Start Docker, Weave Net, and Weave Scope
sudo service docker restart
/usr/bin/weave launch --dns-domain="service.consul." --ipalloc-init consensus=2
sleep 30
/usr/bin/scope launch -weave.hostname scope.service.consul

# Create Docker Networks
for network in sockshop; do
  if [ $(docker network ls | grep $network | wc -l) -eq 0 ]; then
    docker network create -d weave $network
  else
    echo docker network $network already created
  fi
done

# Copy Nomad jobs and scripts to desired locations
sudo cp /ops/shared/scripts/setup_vault.sh /home/ssdemo/setup_vault.sh
sudo cp /ops/shared/config/ssh_policy.hcl /home/ssdemo/ssh_policy.hcl
sudo cp /ops/shared/jobs/sockshop.nomad /home/ssdemo/sockshop.nomad
sudo chown -R $HOME_DIR:$HOME_DIR /home/$HOME_DIR/
sudo chmod 666 /home/ssdemo/*
sudo chmod +x /home/ssdemo/setup_vault.sh
