variable "name" {
  type = string
}

variable "environment" {
  type = string
}

variable "region" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "vpc_cidr" {
  type = string
}

variable "public_subnet_ids" {
  type = list(string)
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "certificate_arn" {
  description = "ACM certificate for the API hostname (same region as the ALB)"
  type        = string
}

variable "image" {
  description = "Initial container image; CI/CD deploys subsequent images"
  type        = string
}

variable "container_port" {
  type    = number
  default = 8080
}

variable "cpu" {
  type    = number
  default = 512
}

variable "memory" {
  type    = number
  default = 1024
}

variable "min_tasks" {
  type    = number
  default = 2
}

variable "max_tasks" {
  type    = number
  default = 10
}

variable "requests_per_task_target" {
  type    = number
  default = 1000
}

variable "db_host" {
  type = string
}

variable "db_port" {
  type    = number
  default = 5432
}

variable "db_name" {
  type = string
}

variable "db_secret_arn" {
  type = string
}

variable "jwt_secret_arn" {
  type = string
}

variable "play_service_account_secret_arn" {
  type = string
}

variable "secret_arns" {
  type = list(string)
}

variable "assets_bucket_arn" {
  type = string
}

variable "firebase_project_id" {
  type = string
}

variable "play_package_name" {
  type = string
}

variable "log_retention_days" {
  type    = number
  default = 30
}

variable "deletion_protection" {
  type    = bool
  default = true
}

variable "alb_access_logs_bucket" {
  type    = string
  default = null
}
