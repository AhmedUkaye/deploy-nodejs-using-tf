########################################
# Provider
########################################
provider "aws" {
  region = "ap-south-1"
}

########################################
# VPC Module
########################################
module "vpc" {
  source               = "./modules/vpc"
  env                  = "dev"
  vpc_cidr             = "10.0.0.0/16"
  public_subnet_cidrs  = ["10.0.1.0/24","10.0.2.0/24"]
  private_subnet_cidrs = ["10.0.3.0/24","10.0.4.0/24"]
  azs                  = ["ap-south-1a","ap-south-1b"]
}

########################################
# Security Group for ECS Instances
########################################
resource "aws_security_group" "ecs_sg" {
  name        = "dev-ecs-sg"
  description = "Allow ECS traffic"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "dev-ecs-sg"
  }

  depends_on = [module.vpc]
}

########################################
# Security Group for ALB
########################################
resource "aws_security_group" "alb_sg" {
  name        = "dev-alb-sg"
  description = "Allow HTTP traffic"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "dev-alb-sg"
  }

  depends_on = [module.vpc]
}

########################################
# ALB Module
########################################
module "alb" {
  source         = "./modules/alb"
  env            = "dev"
  sg_id          = aws_security_group.alb_sg.id
  public_subnets = module.vpc.public_subnets
  vpc_id         = module.vpc.vpc_id
  container_port = 3000

  depends_on = [aws_security_group.alb_sg, module.vpc]
}

########################################
# ECS Module (EC2 Launch Type)
########################################
module "ecs" {
  source            = "./modules/ecs"
  env               = "dev"
  app_image         = "912394945263.dkr.ecr.ap-south-1.amazonaws.com/nodejs-mongo-webapp:latest"
  mongo_uri         = "mongodb://65.0.17.28:27017/testdb"
  ecs_sg_id         = aws_security_group.ecs_sg.id
  private_subnets   = module.vpc.private_subnets
  target_group_arn  = module.alb.target_group_arn

  depends_on = [
    module.vpc,
    aws_security_group.ecs_sg,
    module.alb
  ]
}

