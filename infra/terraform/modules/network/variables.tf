variable "name" {
  type = string
}

variable "region" {
  type = string
}

variable "cidr_block" {
  type    = string
  default = "10.20.0.0/16"
}

variable "az_count" {
  type    = number
  default = 2
  validation {
    condition     = var.az_count >= 2 && var.az_count <= 3
    error_message = "az_count must be 2 or 3."
  }
}

variable "single_nat_gateway" {
  type    = bool
  default = false
}

variable "flow_logs_bucket_arn" {
  type    = string
  default = null
}
