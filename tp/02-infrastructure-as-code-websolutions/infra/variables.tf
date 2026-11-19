variable "app_version" {
  type        = string
  default     = "1.0.0"
  description = "Version de l'image de l'application Node.js"
}

variable "web_port" {
  type        = number
  default     = "8080"
  description = "Port local expose sur l'hote pour Nginx"
}

variable "db_name" {
  type        = string
  default     = "websolutions"
  description = "Nom de la base PostgreSQL"
}

variable "db_user" {
  type        = string
  default     = "ws_user"
  description = "Utilisateur PostgreSQL"
}

variable "db_password" {
  type        = string
  sensitive   = true
  description = "Mot de passe PostgreSQL (a passer via variable d'environnement TF_VAR_db_password)"
}
