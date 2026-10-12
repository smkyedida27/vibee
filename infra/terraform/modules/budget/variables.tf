variable "name" {
  type = string
}

variable "project_tag" {
  type = string
}

variable "monthly_limit_usd" {
  type = number
}

variable "emails" {
  type = list(string)
}
