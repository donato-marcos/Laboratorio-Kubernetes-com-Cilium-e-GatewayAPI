vms = {

  # Servidor kubernetes control-plane
  "k8s-master01" = {
    os_type        = "linux"
    vcpus          = 2
    current_memory = 2560
    memory         = 3072
    firmware       = "efi"
    video_model    = "virtio"
    graphics       = "spice"
    running        = true
    disks = [
      {
        name     = "os"
        size_gb  = 25
        bootable = true

        backing_store = {
          image  = "ubuntu-24-cloud.x86_64.qcow2"
          format = "qcow2"
        }
      }
    ]
    networks = [
      {
        name         = "k8s-wan"
        ipv4_address = "192.168.200.10"
        ipv4_prefix  = 24
        ipv4_gateway = "192.168.200.1"
        dns_servers  = ["192.168.200.1"]
        wait_for_lease = false
      },
      {
        name           = "k8s-cluster"
        ipv4_address   = "172.16.200.10"
        ipv4_prefix    = 24
        wait_for_lease = false
      },
      {
        name           = "k8s-storage"
        ipv4_address   = "172.16.201.10"
        ipv4_prefix    = 24
        wait_for_lease = false
      }
    ]
  },

  # Servidor kubernetes worker
  "k8s-worker01" = {
    os_type        = "linux"
    vcpus          = 2
    current_memory = 2048
    memory         = 3072
    firmware       = "efi"
    video_model    = "virtio"
    graphics       = "spice"
    running        = true
    disks = [
      {
        name     = "os"
        size_gb  = 25
        bootable = true

        backing_store = {
          image  = "ubuntu-24-cloud.x86_64.qcow2"
          format = "qcow2"
        }
      }
    ]
    networks = [
      {
        name         = "k8s-wan"
        ipv4_address = "192.168.200.21"
        ipv4_prefix  = 24
        ipv4_gateway = "192.168.200.1"
        dns_servers  = ["192.168.200.1"]
        wait_for_lease = false
      },
      {
        name           = "k8s-cluster"
        ipv4_address   = "172.16.200.21"
        ipv4_prefix    = 24
        wait_for_lease = false
      },
      {
        name           = "k8s-storage"
        ipv4_address   = "172.16.201.21"
        ipv4_prefix    = 24
        wait_for_lease = false
      }
    ]
  },

  # Servidor kubernetes worker
  "k8s-worker02" = {
    os_type        = "linux"
    vcpus          = 2
    current_memory = 2048
    memory         = 3072
    firmware       = "efi"
    video_model    = "virtio"
    graphics       = "spice"
    running        = true
    disks = [
      {
        name     = "os"
        size_gb  = 25
        bootable = true

        backing_store = {
          image  = "ubuntu-24-cloud.x86_64.qcow2"
          format = "qcow2"
        }
      }
    ]
    networks = [
      {
        name         = "k8s-wan"
        ipv4_address = "192.168.200.22"
        ipv4_prefix  = 24
        ipv4_gateway = "192.168.200.1"
        dns_servers  = ["192.168.200.1"]
        wait_for_lease = false
      },
      {
        name           = "k8s-cluster"
        ipv4_address   = "172.16.200.22"
        ipv4_prefix    = 24
        wait_for_lease = false
      },
      {
        name           = "k8s-storage"
        ipv4_address   = "172.16.201.22"
        ipv4_prefix    = 24
        wait_for_lease = false
      }
    ]
  }
}