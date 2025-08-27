variable "aws_access_key" {
  description = "AWS access key"
  type        = string
  sensitive   = true
}

variable "aws_secret_key" {
  description = "AWS secret key"
  type        = string
  sensitive   = true
}
variable "db_username" {
  description = "RDS root username for the database"
  type        = string
  default     = "db_master"
}

variable "db_password" {
  description = "RDS root password for the database."
  type        = string
  sensitive   = true
}

variable "db_schema" {
  description = "RDS database name to be created."
  type        = string
  default     = "record"
}