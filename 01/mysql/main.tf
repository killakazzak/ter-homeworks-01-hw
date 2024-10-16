terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
    random = {
      source = "hashicorp/random"
    }
  }
  required_version = ">= 0.130"
}

provider "yandex" {
  service_account_key_file = "/root/yandex-cloud/key.json"
  cloud_id                 = "b1gp6qjp3sreksmq9ju1"
  folder_id                = "b1g3hhpc4sj7fmtmdccu"
  zone                     = "ru-central1-a"
}

resource "random_password" "mysql_root_password" {
  length  = 16
  special = true
}

resource "random_password" "mysql_user_password" {
  length  = 16
  special = true
}

resource "yandex_compute_instance" "vm" {
  count = 1

  name = "vm-${count.index + 1}"
  zone = "ru-central1-a"

  resources {
    core_fraction = 5
    cores  = 2
    memory = 1
  }
  
  scheduling_policy {
    preemptible = true
  }

  boot_disk {
    initialize_params {
      image_id = "fd8tvc3529h2cpjvpkr5" # ID образа, например, Ubuntu
    }
  }

  network_interface {
    subnet_id = "e9bang8tpj4mbo92gvr6"
    nat       = true
  }

  metadata = {
    "ssh-keys" = file("./ssh-keys.txt")
    "user-data" = <<-EOF
      #!/bin/bash
      apt-get update
      apt-get install -y docker.io
      systemctl start docker
      systemctl enable docker
      docker run -d \
        --name mysql \
        -e "MYSQL_ROOT_PASSWORD=${random_password.mysql_root_password.result}" \
        -e "MYSQL_DATABASE=wordpress" \
        -e "MYSQL_USER=wordpress" \
        -e "MYSQL_PASSWORD=${random_password.mysql_user_password.result}" \
        -p 127.0.0.1:3306:3306 \
        mysql:8
    EOF
  }
}

output "instance_ips" {
  value = [for instance in yandex_compute_instance.vm : instance.network_interface[0].nat_ip_address]
}

