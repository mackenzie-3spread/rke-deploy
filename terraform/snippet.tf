data "local_file" "ssh_public_key" {
  filename = "./id_rsa.pub"
}

variable "vm_password" {}


resource "proxmox_virtual_environment_file" "user_data_cloud_config" {
  for_each = var.nodes

  content_type = "snippets"
  datastore_id = "local"
  node_name    = "pve2"

  source_raw {
    data = <<-EOF
    #cloud-config
    hostname: ${each.value.name}
    users:
      - name: dusty 
        groups: sudo
        shell: /bin/bash
        ssh_authorized_keys:
          - ${trimspace(data.local_file.ssh_public_key.content)}
        sudo: ALL=(ALL) NOPASSWD:ALL
    chpasswd:
      expire: false
      list: |
        dusty:${var.vm_password}
    runcmd:
      - apt update
      - apt install -y qemu-guest-agent net-tools
      - systemctl enable qemu-guest-agent
      - systemctl start qemu-guest-agent
    EOF

    file_name = "${each.value.name}-cloud-config.yaml"
  }
}

