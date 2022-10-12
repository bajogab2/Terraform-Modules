# configure aws provider
provider "aws" {
  region    = var.region
  profile   = "terraform-user"
}

# create vpc
module "vpc" {
  source                       = "../modules/vpc"
  region                       = var.region
  project_name                 = var.project_name
  vpc_cidr                     = var.vpc_cidr
  public_subnet_az1_cidr       = var.public_subnet_az1_cidr
  public_subnet_az2_cidr       = var.public_subnet_az2_cidr
  private_app_subnet_az1_cidr  = var.private_app_subnet_az1_cidr
  private_app_subnet_az2_cidr  = var.private_app_subnet_az2_cidr
  private_data_subnet_az1_cidr = var.private_data_subnet_az1_cidr
  private_data_subnet_az2_cidr = var.private_data_subnet_az2_cidr
}

# create nat gateways
module "nat_gateway" {
  source = "../modules/Nat Gateway"
  public_subnet_az1_id        = module.vpc.public_subnet_az1_id
  internet_gateway            = module.vpc.internet_gateway
  public_subnet_az2_id        = module.vpc.public_subnet_az2_id
  vpc_id                      = module.vpc.vpc_id
  private_app_subnet_az1_id   = module.vpc.private_app_subnet_az1_id
  private_data_subnet_az1_id  = module.vpc.private_data_subnet_az1_id
  private_app_subnet_az2_id   = module.vpc.private_app_subnet_az2_id
  private_data_subnet_az2_id  = module.vpc.private_data_subnet_az2_id
}

module "security_group" {
  source = "../modules/SG"
  vpc_id = module.vpc.vpc_id
}

module "ecs_task_execution_role" {
  source        = "../modules/ecs-tasks-execution-role"
  project_name  = module.vpc.project_name
}

module "acm" {
  source            = "../modules/ACM"
  domain_name       = var.domain_name
  alternative_name  = var.alternative_name
}

module "application_load_balancer" {
  source                  = "../modules/ALB"
  project_name            = module.vpc.project_name
  alb_security_group_id   = module.security_group.alb_security_group_id
  public_subnet_az1_id    = module.vpc.public_subnet_az1_id
  public_subnet_az2_id    = module.vpc.public_subnet_az2_id
  vpc_id                  = module.vpc.vpc_id
  certificate_arn         = module.acm.certificate_arn

}

module "ecs" {
  source                       = "../modules/ECS"
  project_name                 = module.vpc.project_name
  ecs_tasks_execution_role_arn = module.ecs_task_execution_role.ecs_tasks_execution_role_arn
  container_image              = var.container_image
  region                       = module.vpc.region
  private_app_subnet_az1_id    = module.vpc.private_app_subnet_az1_id
  private_app_subnet_az2_id    = module.vpc.private_app_subnet_az2_id
  ecs_security_group_id        = module.security_group.ecs_security_group_id
  alb_target_group_arn         = module.application_load_balancer.alb_target_group_arn
}

module "asg" {
  source             = "../modules/ASG"
  ecs_cluster_name   = module.ecs.ecs_cluster_name
  ecs_service_name   = module.ecs.ecs_service_name
}

module "route-53" {
  source                              = "../modules/route-53"
  domain_name                         = module.acm.domain_name
  record_name                         = var.record_name
  application_load_balancer_dns_name  = module.application_load_balancer.application_load_balancer_dns_name
  application_load_balancer_zone_id   = module.application_load_balancer.application_load_balancer_zone_id
}

output "website_url" {
  value = join ("", ["https://", var.record_name, ".", var.domain_name])
}