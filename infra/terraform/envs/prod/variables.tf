variable "region" {
  type    = string
  default = "us-east-1"
}

variable "account_suffix" {
  type = string
}

variable "vpc_cidr" {
  type    = string
  default = "10.40.0.0/16"
}

variable "single_nat_gateway" {
  type    = bool
  default = false
}

variable "certificate_arn" {
  type = string
}

variable "task_cpu" {
  type    = number
  default = 1024
}

variable "task_memory" {
  type    = number
  default = 2048
}

variable "min_tasks" {
  type    = number
  default = 2
}

variable "max_tasks" {
  type    = number
  default = 12
}

variable "db_instance_class" {
  type    = string
  default = "db.m7g.large"
}

variable "db_multi_az" {
  type    = bool
  default = true
}

variable "db_backup_retention_days" {
  type    = number
  default = 14
}

variable "deletion_protection" {
  type    = bool
  default = true
}

variable "log_retention_days" {
  type    = number
  default = 90
}

variable "firebase_project_id" {
  type = string
}

variable "play_package_name" {
  type    = string
  default = "com.quintile.app"
}

variable "alert_emails" {
  type = list(string)
}

variable "monthly_budget_usd" {
  type    = number
  default = 1200
}
