#!/bin/bash

# Script to complete setup of Vault and start Nomad
if [[ $(cat /home/ssdemo/IP_ADDRESS) == *"VAULT_SERVER_IP"* ]]; then
  echo "#### Initialize Vault" | tee -a /home/ssdemo/setup_vault.log

  until vault status -address=http://VAULT_SERVER_IP:8200; do
    systemctl restart consul
    sleep 30
    vault operator init -address=http://VAULT_SERVER_IP:8200 -recovery-shares=1 -recovery-threshold=1 >/home/ssdemo/VAULT_INIT
  done

  VAULT_TOKEN=$(cat /home/ssdemo/VAULT_INIT | grep 'Token:' | cut -d':' -f2 | awk '{print $1}')
  export VAULT_TOKEN=$VAULT_TOKEN
  echo "export VAULT_TOKEN=$VAULT_TOKEN" >>/home/ssdemo/.profile

  # Setup Vault policy/role after manually initializing & unsealing it
  echo "#### Setting up Vault policy and role" | tee -a /home/ssdemo/setup_vault.log
  curl https://nomadproject.io/data/vault/nomad-server-policy.hcl -O -s -L >/home/ssdemo/nomad-server-policy.hcl
  vault policy write -address=http://VAULT_SERVER_IP:8200 nomad-server /home/ssdemo/nomad-server-policy.hcl
  curl https://nomadproject.io/data/vault/nomad-cluster-role.json -O -s -L >/home/ssdemo/nomad-cluster-role.json
  vault write -address=http://VAULT_SERVER_IP:8200 /auth/token/roles/nomad-cluster @/home/ssdemo/nomad-cluster-role.json

  # Get token for Vault
  TOKEN_FOR_VAULT=$(vault token create -address=http://VAULT_SERVER_IP:8200 -policy nomad-server -period 72h -orphan -field token)
  sudo sed -i "s/TOKEN_FOR_VAULT/$TOKEN_FOR_VAULT/g" /etc/nomad.d/nomad.hcl
  echo "The generated Vault token is: $TOKEN_FOR_VAULT" | tee -a /home/ssdemo/setup_vault.log

  # Setup the Vault SSH secret backend
  echo "#### Setting up the Vault SSH secret backend" | tee -a /home/ssdemo/setup_vault.log
  vault secrets enable -address=http://VAULT_SERVER_IP:8200 ssh
  vault write -address=http://VAULT_SERVER_IP:8200 ssh/roles/otp_key_role key_type=otp default_user=root cidr_list=172.17.0.0/24

  # Test that we can generate a password
  echo "#### Testing that we can generate a password" | tee -a /home/ssdemo/setup_vault.log
  vault write -address=http://VAULT_SERVER_IP:8200 ssh/creds/otp_key_role ip=172.17.0.1
  # Write ssh_policy into Vault
  vault write -address=http://VAULT_SERVER_IP:8200 sys/policy/ssh_policy policy=@ssh_policy.hcl

else

  until vault status -address=http://VAULT_SERVER_IP:8200; do
    systemctl restart consul
    sleep 30
  done

  sudo -u ssdemo ssh-keyscan -H VAULT_SERVER_IP >>~/.ssh/known_hosts
  until sudo -u ssdemo ssh VAULT_SERVER_IP stat /home/ssdemo/DONE; do
    sleep 5
  done
  TOKEN_FOR_VAULT=$(sudo -u ssdemo ssh VAULT_SERVER_IP sudo cat /etc/nomad.d/nomad.hcl | grep 'token =' | cut -d'"' -f2)
  sudo sed -i "s/TOKEN_FOR_VAULT/$TOKEN_FOR_VAULT/g" /etc/nomad.d/nomad.hcl
fi
