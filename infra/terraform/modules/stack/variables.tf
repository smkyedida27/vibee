variable "environment" {
  type = string
  validation {
    condition     = contains(["staging", "prod"], var.environment)
    error_message = "environment must be staging or prod."
  }
}

variable "region" {
  type = string
}

variable "account_suffix" {
  description = "Short unique suffix (e.g. AWS account id) to make bucket names globally unique"
  type        = string
}

variable "vpc_cidr" {
  type = string
}

variable "single_nat_gateway" {
  type = bool
}

variable "certificate_arn" {
  type = string
}

variable "bootstrap_image_tag" {
  type    = string
  default = "bootstrap"
}

variable "task_cpu" {
  type = number
}

variable "task_memory" {
  type = number
}

variable "min_tasks" {
  type = number
}

variable "max_tasks" {
  type = number
}

variable "db_instance_class" {
  type = string
}

variable "db_multi_az" {
  type = bool
}

variable "db_backup_retention_days" {
  type = number
}

variable "deletion_protection" {
  type = bool
}

variable "log_retention_days" {
  type = number
}

variable "firebase_project_id" {
  type = string
}

variable "play_package_name" {
  type    = string
  default = "com.puzzlehub.app"
}

variable "alert_emails" {
  type = list(string)
}

variable "monthly_budget_usd" {
  type = number
}
