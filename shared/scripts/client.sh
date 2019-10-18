#!/bin/bash

set -e

CONFIGDIR=/ops/shared/config

CONSULCONFIGDIR=/etc/consul.d
NOMADCONFIGDIR=/etc/nomad.d
HOME_DIR=ssdemo

# Wait for network
sleep 15

IP_ADDRESS=$(curl http://instance-data/latest/meta-data/local-ipv4)
DOCKER_BRIDGE_IP_ADDRESS=($(ifconfig docker0 2>/dev/null | awk '/inet addr:/ {print $2}' | sed 's/addr://'))
REGION=$1
CLUSTER_TAG_VALUE=$2
SERVER_IP=$3

# Consul
# Consul
id -u consul &>/dev/null || sudo useradd --system --home /etc/consul.d --shell /bin/false consul
sudo chown --recursive consul:consul /opt/consul
sudo cp $CONFIGDIR/consul.service /etc/systemd/system/consul.service
sudo mkdir --parents /etc/consul.d
sudo cp $CONFIGDIR/consul.hcl $CONSULCONFIGDIR
sed -i "s/CONSUL_ENCRYPT_KEY/$CONSUL_ENCRYPT_KEY/g" $CONSULCONFIGDIR/consul.hcl
sudo chown --recursive consul:consul $CONSULCONFIGDIR
sudo chmod 640 $CONSULCONFIGDIR/consul.hcl

sudo systemctl enable consul
sudo systemctl start consul
sudo systemctl status consul
sleep 10

# Nomad
sudo cp $CONFIGDIR/nomad_client.hcl $NOMADCONFIGDIR/nomad.hcl
sudo cp $CONFIGDIR/nomad_upstart.conf /etc/init/nomad.conf
sudo sed -i "s/IP_ADDRESS/$IP_ADDRESS/g" $NOMADCONFIGDIR/nomad_client.hcl
sudo sed -i "s/SERVER_IP/$SERVER_IP/g" $NOMADCONFIGDIR/nomad_client.hcl

sudo service nomad start
sleep 10
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
echo "export VAULT_ADDR=http://$SERVER_IP:8200" | sudo tee --append /home/$HOME_DIR/.bashrc
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

# Connect Clients to Server
/usr/bin/weave connect $SERVER_IP
/usr/bin/weave expose
