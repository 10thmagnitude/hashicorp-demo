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
      retry_join = [${consul_servers}]
      performance {
        raft_multiplier = ${server_count}
      }
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
  - path: /etc/nomad.d/nomad.hcl
    permissions: 0640
    content: |
      data_dir = "/opt/nomad/data"
      bind_addr = "0.0.0.0"
      name = "nomad@IP_ADDRESS"

      # Enable the client
      client {
        enabled = true
        options = {
          driver.raw_exec.enable = "1"
          docker.cleanup.image = false
        }
      }

      consul {
        address = "127.0.0.1:8500"
      }

      vault {
        enabled = true
        address = "http://${vault_server_ip}:8200"
      }
  - path: /etc/systemd/system/nomad.service
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
      TasksMax=infinity

      [Install]
      WantedBy=multi-user.target
  - path: /home/ssdemo/.profile
    owner: ssdemo:ssdemo
    content: |
      export VAULT_ADDR=http://${vault_server_ip}:8200
      export NOMAD_ADDR=http://IP_ADDRESS:4646
runcmd:
  - ifconfig eth0 | awk '/inet / {print $2}' > /home/ssdemo/IP_ADDRESS
  - az keyvault secret show --vault-name ${key_vault_name} -n ${private_key_name} | jq -r '.value' > /home/ssdemo/.ssh/id_rsa
  - az keyvault secret show --vault-name ${key_vault_name} -n ${public_key_name} | jq -r '.value' > /home/ssdemo/.ssh/id_rsa.pub
  - [chown, "--recursive", "ssdemo:ssdemo", "/home/ssdemo/.ssh/"]
  - [chmod, "600", "/home/ssdemo/.ssh/id_rsa"]
  - [chown, "--recursive", "consul:consul", "/opt/consul"]
  - [chown, "--recursive", "consul:consul", "/etc/consul.d"]
  - sed -i s/IP_ADDRESS/$(ifconfig eth0 | awk '/inet / {print $2}')/g /etc/consul.d/consul.hcl
  - [systemctl, enable, consul]
  - [systemctl, start, consul]
  - sed -i s/IP_ADDRESS/$(ifconfig eth0 | awk '/inet / {print $2}')/g /etc/nomad.d/nomad.hcl
  - [systemctl, enable, nomad]
  - [systemctl, start, nomad]
  - echo "127.0.0.1 $(hostname)" | sudo tee --append /etc/hosts
  - echo "nameserver $(ifconfig docker0 2>/dev/null | awk '/inet / {print $2}')" | sudo tee /etc/resolv.conf.new
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
  - /usr/bin/weave connect $(ifconfig eth0 | awk '/inet / {print $2}')
  - /usr/bin/weave expose
  - [chown, "--recursive", "ssdemo:ssdemo", "/home/ssdemo/"]
  - sed -i s/IP_ADDRESS/$(ifconfig eth0 | awk '/inet / {print $2}')/g /home/ssdemo/.profile
  - [chmod, "go-w", "/home/ssdemo/"]
  - touch /home/ssdemo/DONE
  - [chmod, "ssdemo:ssdemo", "/home/ssdemo/DONE"]