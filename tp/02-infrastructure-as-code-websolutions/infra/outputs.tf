output "web_url" {
  description = "Point d'entree HTTP de l'application"
  value       = "http://127.0.0.1:${var.web_port}"
}

output "network_name" {
  description = "Reseau Docker isole"
  value       = docker_network.websolutions_net.name
}

output "db_volume" {
  description = "Volume persistant PostgreSQL"
  value       = docker_volume.pgdata.name
}