variable "name" {
  type = string
}

variable "region" {
  type = string
}

variable "alert_emails" {
  type    = list(string)
  default = []
}

variable "alb_arn_suffix" {
  type = string
}

variable "target_group_arn_suffix" {
  type = string
}

variable "db_instance_id" {
  type = string
}

variable "ecs_cluster_name" {
  type = string
}

variable "ecs_service_name" {
  type = string
}

variable "log_group_name" {
  type = string
}

variable "error_rate_threshold_pct" {
  type    = number
  default = 2
}

variable "p95_latency_threshold_seconds" {
  type    = number
  default = 0.5
}

variable "db_max_connections_threshold" {
  type    = number
  default = 150
}

variable "db_free_storage_threshold_bytes" {
  type    = number
  default = 5368709120 # 5 GiB
}
