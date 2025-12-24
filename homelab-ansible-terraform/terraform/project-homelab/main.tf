resource "yandex_compute_instance" "master" {
  name        = "master-node"
  platform_id = "standard-v3"
  zone        = var.zone
  labels = {
    project = "test"
  }

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
  labels = {
    project = "test"
  }

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
  labels = {
    project = "test"
  }
}

resource "yandex_vpc_subnet" "homelab-subnet" {
  zone           = var.zone
  network_id     = yandex_vpc_network.homelab-network.id
  v4_cidr_blocks = ["10.5.0.0/24"]
  labels = {
    project = "test"
  }
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

resource "yandex_lb_target_group" "tg-cluster" {
  name  = "tg-cluster"
  region_id = var.region
  labels = {
    project = "test"
  }

  target {
    subnet_id = yandex_vpc_subnet.homelab-subnet.id
    address = yandex_compute_instance.master.network_interface[0].ip_address
  }
}

resource "yandex_lb_network_load_balancer" "lb-cluster" {
  name = "lb-cluster"
  labels = {
    project = "test"
  }

  listener {
    name = "list-lb-cluster"
    port = 80
    target_port = 30080
    external_address_spec {
      ip_version = "ipv4"
    }
  }

  attached_target_group {
    target_group_id = yandex_lb_target_group.tg-cluster.id

    healthcheck {
      name = "tcp"
      tcp_options {
        port = 30080
      }
    }
  }
}

resource "yandex_vpc_security_group" "sg" {
  name        = "SG for ingressnginx"
  description = "asf"
  network_id  = yandex_vpc_network.homelab-network.id
  labels = {
    project = "test"
  }

  ingress {
    protocol       = "TCP"
    description    = "Allow LB only"
    v4_cidr_blocks = flatten([
      for l in yandex_lb_network_load_balancer.lb-cluster.listener : [
        for e in l.external_address_spec : "${e.address}/32"
      ]
    ])
    port           = 30080
  }

  ingress {
    protocol       = "TCP"
    port           = 80
    description    = "Allow all to LB"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "yandex_dns_zone" "main-zone" {
  name        = "main-zone-test"
  description = "desc"

  labels = {
    project = "test"
  }

  zone             = "solodium.test."
  public           = true

  deletion_protection = false
}

resource "yandex_dns_recordset" "main-zone-record" {
  zone_id = yandex_dns_zone.main-zone.id
  name    = each.value
  for_each = toset(var.dns_zone)
  type    = "A"
  ttl     = 300
  data = flatten([
    for l in yandex_lb_network_load_balancer.lb-cluster.listener : [
      for e in l.external_address_spec : e.address
    ]
  ])
}