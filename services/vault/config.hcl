storage "raft" {
  path = "/vault/data"
  node_id = "vault-1"
}

listener "tcp" {
  address     = "[::]:8200"
  cluster_addr = "[::]:8201"
  tls_disable = "true"
}

telemetry {
  prometheus_retention_time = "30s"
}

ui = true
disable_mlock = true