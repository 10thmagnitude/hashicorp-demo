#cloud-config
users:
  - default
  - name: consul
    system: true
    homedir: /etc/consul.d
    shell: /bin/false
  - name: vault
    system: true
    homedir: /etc/vault.d
    shell: /bin/false
write_files:
  - path: /etc/consul.d/consul.hcl
    permissions: 0640
    content: |
      datacenter = "10m-ssd"
      data_dir   = "/opt/consul"
      bind_addr  = "IP_ADDRESS"
      encrypt    = "${consul_encrypt_key}"
      retry_join = ["provider=azure tag_name=consul tag_value=server tenand_id=${tenant_id} client_id=${client_id} subscription_id=${subscription_id} secret_access_key='${client_secret}'"]
      performance {
        raft_multiplier = ${server_count}
      }
  - path: /etc/consul.d/server.hcl
    permissions: 0640
    content: |
      server           = true
      bootstrap_expect = ${server_count}
      ui               = true
  - path: /etc/systemd/system/consul.service
    content: |
      [Unit]
      Description="HashiCorp Consul - A service mesh solution"
      Documentation=https://www.consul.io/
      Requires=network-online.target
      After=network-online.target
      ConditionFileNotEmpty=/etc/consul.d/consul.hcl

      [Service]
      User=consul
      Group=consul
      ExecStart=/usr/local/bin/consul agent -config-dir=/etc/consul.d/
      ExecReload=/usr/local/bin/consul reload
      KillMode=process
      Restart=on-failure
      LimitNOFILE=65536

      [Install]
      WantedBy=multi-user.target
  - path: /etc/vault.d/vault.hcl
    permissions: 0640
    content: |
      backend "consul" {
        path = "vault/"
        address = "IP_ADDRESS:8500"
        cluster_addr = "https://IP_ADDRESS:8201"
        redirect_addr = "http://IP_ADDRESS:8200"
      }

      listener "tcp" {
        address = "IP_ADDRESS:8200"
        cluster_address = "IP_ADDRESS:8201"
        tls_disable = 1
      }

      seal "azurekeyvault" {
        tenant_id = "${tenant_id}"
        client_id = "${client_id}"
        client_secret = "${client_secret}"
        vault_name = "${key_vault_name}"
        key_name = "${key_vault_key_name}"
      }
  - path: /etc/systemd/system/vault.service
    content: |
      [Unit]
      Description="HashiCorp Vault - A tool for managing secrets"
      Documentation=https://www.vaultproject.io/docs/
      Requires=network-online.target
      After=network-online.target
      ConditionFileNotEmpty=/etc/vault.d/vault.hcl
      StartLimitIntervalSec=60
      StartLimitBurst=3

      [Service]
      User=vault
      Group=vault
      ProtectSystem=full
      ProtectHome=read-only
      PrivateTmp=yes
      PrivateDevices=yes
      SecureBits=keep-caps
      AmbientCapabilities=CAP_IPC_LOCK
      Capabilities=CAP_IPC_LOCK+ep
      CapabilityBoundingSet=CAP_SYSLOG CAP_IPC_LOCK
      NoNewPrivileges=yes
      ExecStart=/usr/local/bin/vault server -config=/etc/vault.d/vault.hcl
      ExecReload=/bin/kill --signal HUP $MAINPID
      KillMode=process
      KillSignal=SIGINT
      Restart=on-failure
      RestartSec=5
      TimeoutStopSec=30
      StartLimitInterval=60
      StartLimitIntervalSec=60
      StartLimitBurst=3
      LimitNOFILE=65536
      LimitMEMLOCK=infinity

      [Install]
      WantedBy=multi-user.target
  - path: /etc/nomad.d/nomad.hcl
    permissions: 0640
    content: |
      data_dir = "/opt/nomad/data"
      bind_addr = "0.0.0.0"

      # Enable the server
      server {
        enabled = true
        bootstrap_expect = ${server_count}
      }

      name = "nomad@IP_ADDRESS"

      consul {
        address = "127.0.0.1:8500"
      }

      vault {
        enabled = true
        address = "http://IP_ADDRESS:8200"
        task_token_ttl = "1h"
        create_from_role = "nomad-cluster"
        token = "TOKEN_FOR_VAULT"
      }
  - path: /etc/systemd/system/vault.service
    content: |
      [Unit]
      Description=Nomad
      Documentation=https://nomadproject.io/docs/
      Wants=network-online.target
      After=network-online.target

      [Service]
      ExecReload=/bin/kill -HUP $MAINPID
      ExecStart=/usr/local/bin/nomad agent -config /etc/nomad.d
      KillMode=process
      KillSignal=SIGINT
      LimitNOFILE=65536
      LimitNPROC=infinity
      Restart=on-failure
      RestartSec=2
      StartLimitBurst=3
      StartLimitIntervalSec=10
      TasksMax=infinity

      [Install]
      WantedBy=multi-user.target
runcmd:
  - [chown, "--recursive", "consul:consul", "/opt/consul"]
  - [chown, "--recursive", "consul:consul", "/etc/consul.d"]
  - sed -i s/IP_ADDRESS/$(ifconfig eth0 | awk '/inet / {print $2}')/g /etc/consul.d/consul.hcl
  - [systemctl, enable, consul]
  - [systemctl, start, consul]
  - sed -i s/IP_ADDRESS/$(ifconfig eth0 | awk '/inet / {print $2}')/g /etc/vault.d/vault.hcl
  - [chown, "--recursive", "vault:vault", "/etc/vault.d"]
  - setcap cap_ipc_lock=+ep /usr/local/bin/vault
  - [systemctl, enable, vault]
  - [systemctl, start, vault]
  - sed -i s/IP_ADDRESS/$(ifconfig eth0 | awk '/inet / {print $2}')/g /etc/nomad.d/nomad.hcl
  - echo "127.0.0.1 $(hostname)" | sudo tee --append /etc/hosts
  - echo "nameserver $(ifconfig docker0 2>/dev/null | awk '/inet / {print $2}') | sudo tee /etc/resolv.conf.new
  - cat /etc/resolv.conf | sudo tee --append /etc/resolv.conf.new
  - mv /etc/resolv.conf.new /etc/resolv.conf
  - echo "search service.consul" | sudo tee --append /etc/resolv.conf
  - [mv, "/home/ssdemo/weave",  "/usr/bin/weave"]
  - [mv, "/home/ssdemo/scope",  "/usr/bin/scope"]
  - echo {\"cluster-store\":\"consul://127.0.0.1:8500\"} >/home/ssdemo/daemon.json
  - [mv, "/home/ssdemo/daemon.json", "/etc/docker/daemon.json"]
  - [systemctl, enable, docker]
  - [systemctl, start, docker]
  - /usr/bin/weave launch --dns-domain="service.consul." --ipalloc-init consensus=2
  - sleep 30
  - /usr/bin/scope launch -weave.hostname scope.service.consul
  - for network in sockshop; do if [ $(docker network ls | grep $network | wc -l) -eq 0 ]; then docker network create -d weave $network; else echo docker network $network already created; fi; done
  - [cp, "/ops/shared/config/ssh_policy.hcl", "/home/ssdemo/ssh_policy.hcl"]
  - [cp, "/ops/shared/jobs/sockshop.nomad", "/home/ssdemo/sockshop.nomad"]
  - [chown, "--recursive", "ssdemo:ssdemo", "/home/ssdemo/"]
  - [chmod, "666", "/home/ssdemo/*"]
