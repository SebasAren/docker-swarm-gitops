api_addr = "http://127.0.0.1:8200"
cluster_addr = "http://127.0.0.1:8201"

storage "raft" {
  path = "/vault/data"
  node_id = "vault-1"
}

listener "tcp" {
  address     = "[::]:8200"
  tls_disable = "true"
}

telemetry {
  prometheus_retention_time = "30s"
}

ui = true
disable_mlock = true