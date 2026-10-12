# Composition of the whole Puzzle Hub backend environment. envs/<env> call this
# with environment-specific sizing.

locals {
  name = "puzzlehub-${var.environment}"
}

module "network" {
  source             = "../network"
  name               = local.name
  region             = var.region
  cidr_block         = var.vpc_cidr
  az_count           = 2
  single_nat_gateway = var.single_nat_gateway
}

module "ecr" {
  source = "../ecr"
  name   = local.name
}

module "secrets" {
  source                  = "../secrets"
  name                    = local.name
  recovery_window_in_days = var.environment == "prod" ? 30 : 7
}

module "assets" {
  source      = "../static_assets"
  name        = local.name
  bucket_name = "${local.name}-assets-${var.account_suffix}"
}

module "api" {
  source = "../ecs_service"

  name               = local.name
  environment        = var.environment
  region             = var.region
  vpc_id             = module.network.vpc_id
  vpc_cidr           = module.network.vpc_cidr
  public_subnet_ids  = module.network.public_subnet_ids
  private_subnet_ids = module.network.private_subnet_ids
  certificate_arn    = var.certificate_arn

  image     = "${module.ecr.repository_url}:${var.bootstrap_image_tag}"
  cpu       = var.task_cpu
  memory    = var.task_memory
  min_tasks = var.min_tasks
  max_tasks = var.max_tasks

  db_host       = module.db.endpoint
  db_port       = module.db.port
  db_name       = module.db.db_name
  db_secret_arn = module.db.master_user_secret_arn

  jwt_secret_arn                  = module.secrets.jwt_secret_arn
  play_service_account_secret_arn = module.secrets.play_service_account_secret_arn
  secret_arns                     = module.secrets.all_secret_arns

  assets_bucket_arn   = module.assets.bucket_arn
  firebase_project_id = var.firebase_project_id
  play_package_name   = var.play_package_name
  log_retention_days  = var.log_retention_days
  deletion_protection = var.deletion_protection
}

module "db" {
  source = "../rds"

  name                  = local.name
  vpc_id                = module.network.vpc_id
  private_subnet_ids    = module.network.private_subnet_ids
  app_security_group_id = module.api.app_security_group_id
  instance_class        = var.db_instance_class
  multi_az              = var.db_multi_az
  backup_retention_days = var.db_backup_retention_days
  deletion_protection   = var.deletion_protection
}

module "monitoring" {
  source = "../monitoring"

  name                    = local.name
  region                  = var.region
  alert_emails            = var.alert_emails
  alb_arn_suffix          = module.api.alb_arn_suffix
  target_group_arn_suffix = module.api.target_group_arn_suffix
  db_instance_id          = module.db.instance_id
  ecs_cluster_name        = module.api.cluster_name
  ecs_service_name        = module.api.service_name
  log_group_name          = module.api.log_group_name
}

module "budget" {
  source            = "../budget"
  name              = local.name
  project_tag       = "puzzlehub"
  monthly_limit_usd = var.monthly_budget_usd
  emails            = var.alert_emails
}
