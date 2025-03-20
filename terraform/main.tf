terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
    }
  }
  required_version = ">= 1.0"
}

variable "proxmox_endpoint" {}
variable "proxmox_api_token" {}
variable "private_key_file_location" {}

provider "proxmox" {
  endpoint  = var.proxmox_endpoint
  api_token = var.proxmox_api_endpoint
  insecure  = true

  ssh {
    agent       = true
    username    = "root"
    private_key = file(var.private_key_file_location)
  }
}

variable "nodes" {
  description = "Map of Kubernetes nodes to create: one controller and several workers."
  type = map(object({
    role      : string
    name      : string
    # Add any other custom configuration here if needed.
  }))
  default = {
    "controller" = {
      role      = "controller"
      name      = "k8s-controller"
    }
    "worker1" = {
      role      = "worker"
      name      = "k8s-worker-1"
    }
    "worker2" = {
      role      = "worker"
      name      = "k8s-worker-2"
    }
    "worker3" = {
      role      = "worker"
      name      = "k8s-worker-3"
    }
    "manager" = {
      role      = "manager"
      name      = "k8s-manager"
    }
  }
}

resource "proxmox_virtual_environment_vm" "tiny_test_vm" {

  for_each = var.nodes

  name      = each.value.name
  node_name = "pve2"

  tags = ["k8s", each.value.role]

  agent {
    enabled = true
  }

  # Clone from existing VM template
  clone {
    vm_id = 9000
    full  = true
  }

  cpu {
    cores = 2
  }

  memory {
    dedicated = 4096
  }

  initialization {
    ip_config {
      ipv4 {
        address = "dhcp"
      }
    }
    user_data_file_id = proxmox_virtual_environment_file.user_data_cloud_config[each.key].id
  }

  # Minimal network config
  network_device {
    bridge = "vmbr0"
    model  = "virtio"
  }
}

resource "null_resource" "wait_for_ips" {
  depends_on = [proxmox_virtual_environment_vm.tiny_test_vm]

  provisioner "local-exec" {
    command = <<EOT
    for i in {1..20}; do
      IP=$(terraform output instance_ips | grep controller | awk -F '=' '{print $2}' | tr -d ' ')
      [[ "$IP" != "0.0.0.0" && "$IP" != "" ]] && exit 0
      sleep 5
    done
    exit 1
    EOT
  }
}

output "instance_ips" {
  value = {
    controller = proxmox_virtual_environment_vm.tiny_test_vm["controller"].ipv4_addresses[1]
    worker1    = proxmox_virtual_environment_vm.tiny_test_vm["worker1"].ipv4_addresses[1]
    worker2    = proxmox_virtual_environment_vm.tiny_test_vm["worker2"].ipv4_addresses[1]
    worker3    = proxmox_virtual_environment_vm.tiny_test_vm["worker3"].ipv4_addresses[1]
    manager    = proxmox_virtual_environment_vm.tiny_test_vm["manager"].ipv4_addresses[1]
  }
}



resource "local_file" "ansible_inventory" {
  filename = "../ansible/inventory.ini"
  content = templatefile("inventory.tpl", {
    controller = proxmox_virtual_environment_vm.tiny_test_vm["controller"].ipv4_addresses[1][0]
    worker1    = proxmox_virtual_environment_vm.tiny_test_vm["worker1"].ipv4_addresses[1][0]
    worker2    = proxmox_virtual_environment_vm.tiny_test_vm["worker2"].ipv4_addresses[1][0]
    worker3    = proxmox_virtual_environment_vm.tiny_test_vm["worker3"].ipv4_addresses[1][0]
    manager    = proxmox_virtual_environment_vm.tiny_test_vm["manager"].ipv4_addresses[1][0]
  })
}
