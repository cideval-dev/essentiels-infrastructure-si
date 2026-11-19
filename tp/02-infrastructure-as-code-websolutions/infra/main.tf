resource "docker_network" "websolutions_net" {
  name = "websolutions-net"
}

resource "docker_volume" "pgdata" {
  name = "websolutions-pgdata"
}

resource "docker_image" "postgres" {
  name         = "postgres:17-alpine"
  keep_locally = true
}

resource "docker_image" "nginx" {
  name         = "nginx:1.28-alpine"
  keep_locally = true
}

resource "docker_container" "db" {
  name  = "websolutions-db"
  image = docker_image.postgres.image_id

  env = [
    "POSTGRES_DB=${var.db_name}",
    "POSTGRES_USER=${var.db_user}",
    "POSTGRES_PASSWORD=${var.db_password}",
  ]

  volumes {
    volume_name    = docker_volume.pgdata.name
    container_path = "/var/lib/postgresql/data"
  }

  networks_advanced {
    name = docker_network.websolutions_net.name
  }
}

resource "docker_container" "api" {
  name       = "websolutions-api"
  image      = "websolutions-api:${var.app_version}"
  depends_on = [docker_container.db]

  env = [
    "PORT=3000",
    "APP_VERSION=${var.app_version}",
    "DB_HOST=websolutions-db",
    "DB_NAME=${var.db_name}",
    "DB_USER=${var.db_user}",
  ]

  networks_advanced {
    name = docker_network.websolutions_net.name
  }
}

resource "docker_container" "web" {
  name       = "websolutions-web"
  image      = docker_image.nginx.image_id
  depends_on = [docker_container.api]

  ports {
    internal = 80
    external = var.web_port
    ip       = "127.0.0.1"
  }

  networks_advanced {
    name = docker_network.websolutions_net.name
  }
}