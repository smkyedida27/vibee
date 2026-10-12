terraform {
  required_version = ">= 1.6"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  # Partial config: bucket/region supplied via backend.hcl (see backend.hcl.example).
  backend "s3" {
    key            = "puzzlehub/staging/terraform.tfstate"
    dynamodb_table = "puzzlehub-terraform-lock"
    encrypt        = true
  }
}

provider "aws" {
  region = var.region
  default_tags {
    tags = {
      Project     = "puzzlehub"
      Environment = "staging"
      ManagedBy   = "terraform"
    }
  }
}

module "stack" {
  source = "../../modules/stack"

  environment              = "staging"
  region                   = var.region
  account_suffix           = var.account_suffix
  vpc_cidr                 = var.vpc_cidr
  single_nat_gateway       = var.single_nat_gateway
  certificate_arn          = var.certificate_arn
  task_cpu                 = var.task_cpu
  task_memory              = var.task_memory
  min_tasks                = var.min_tasks
  max_tasks                = var.max_tasks
  db_instance_class        = var.db_instance_class
  db_multi_az              = var.db_multi_az
  db_backup_retention_days = var.db_backup_retention_days
  deletion_protection      = var.deletion_protection
  log_retention_days       = var.log_retention_days
  firebase_project_id      = var.firebase_project_id
  play_package_name        = var.play_package_name
  alert_emails             = var.alert_emails
  monthly_budget_usd       = var.monthly_budget_usd
}

output "stack" {
  value = module.stack
}
