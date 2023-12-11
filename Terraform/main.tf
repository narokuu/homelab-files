provider "vsphere" {
  user     = "your-username"
  password = "your-password"
  vsphere_server = "vcenter.example.com"
}

resource "vsphere_virtual_machine" "vm" {
  name             = "vmname"
  resource_pool_id = "resgroup-12345"
  datacenter_id    = "datacenter-12345"

  num_cpus = 2
  memory   = 2048

  network_interface {
    label = "Network Adapter 1"
    ipv4_address = "192.168.1.10"
    ipv4_prefix_length = 24
    ipv4_gateway = "192.168.1.1"
  }

  disk {
    label = "disk0"
    size  = 20
  }

  cdrom {
    datastore_id = "datastore-12345"
    path = "[datastore1] ISO/vmname.iso"
  }
}