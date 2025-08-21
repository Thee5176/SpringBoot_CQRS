variable "db_password" {
  description = "RDS root password for the database."
  type        = string
  sensitive   = true
}