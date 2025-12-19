resource "yandex_compute_instance" "master" {
  name        = "master-node"
  platform_id = "standard-v3"
  zone        = var.zone

  resources {
    cores  = 2
    memory = 4
  }

  boot_disk {
    initialize_params {
        image_id = "fd89nl7rpq3plgh1dmtu"
        size = 20
    }
  }

  network_interface {
    index     = 1
    subnet_id = yandex_vpc_subnet.homelab-subnet.id
    nat = true
  }

  metadata = {
    ssh-keys = "vladislav:${file("~/.ssh/homelab.pub")}"
  }
}

resource "yandex_compute_instance" "worker" {
  name        = each.value
  platform_id = "standard-v3"
  zone        = var.zone
  for_each = toset(var.workers)

  resources {
    cores  = 2
    memory = 4
  }

  boot_disk {
    initialize_params {
        image_id = "fd89nl7rpq3plgh1dmtu"
        size = 20
    }
  }
  network_interface {
    index     = 1
    subnet_id = yandex_vpc_subnet.homelab-subnet.id
    nat     = true
  }

  metadata = {
    ssh-keys = "vladislav:${file("~/.ssh/homelab.pub")}"
  }
}

resource "yandex_vpc_network" "homelab-network" {
    name = "homelab-net"
}

resource "yandex_vpc_subnet" "homelab-subnet" {
  zone           = var.zone
  network_id     = yandex_vpc_network.homelab-network.id
  v4_cidr_blocks = ["10.5.0.0/24"]
}

output "master_ip" {
  value = yandex_compute_instance.master.network_interface.0.nat_ip_address
}
output "worker_ip" {
  value = { for w, inst in yandex_compute_instance.worker : w => inst.network_interface[0].nat_ip_address }
}

resource "local_file" "inventory" {
  content = <<EOF
all:
  vars:
    ansible_user: vladislav
    ansible_ssh_private_key_file: /home/vladislav/.ssh/homelab
    ansible_ssh_common_args: "-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
  children:
    masters:
      hosts:
        master-1:
          ansible_host: ${yandex_compute_instance.master.network_interface[0].nat_ip_address}

    workers:
      hosts:
${join("\n", [
  for k, inst in yandex_compute_instance.worker :
  "        ${k}:\n          ansible_host: ${inst.network_interface[0].nat_ip_address}"
])}
EOF
  filename = "/home/vladislav/ansible/inventory"
}
