networks = [
  {
    name      = "k8s-wan"
    mode      = "nat"
    autostart = true

    ipv4_address      = "192.168.200.1"
    ipv4_prefix       = 24
    ipv4_dhcp_enabled = true
    ipv4_dhcp_start   = "192.168.200.64"
    ipv4_dhcp_end     = "192.168.200.128"
  },
  {
    name      = "k8s-cluster"
    mode      = "isolated"
    autostart = true

    ipv4_address      = "172.16.200.1"
    ipv4_prefix       = 24
    ipv4_dhcp_enabled = false
  },
  {
    name      = "k8s-storage"
    mode      = "isolated"
    autostart = true

    ipv4_address      = "172.16.201.1"
    ipv4_prefix       = 24
    ipv4_dhcp_enabled = false
  }
]
