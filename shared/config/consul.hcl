datacenter = "10m-ssd"
data_dir   = "/opt/consul"
bind_addr  = "IP_ADDRESS"
encrypt    = "CONSUL_ENCRYPT_KEY"
retry_join = ["provider=azure tag_name=consul tag_value=server tenand_id=TENANT_ID client_id=CLIENT_ID subscription_id=SUBSCRIPTION_ID secret_access_key='CLIENT_SECRET'"]
performance {
  raft_multiplier = 1
}
