variable "env" {
  type        = string
  description = "Environment name (e.g. dev, qa, prod)"
}

variable "app_image" {
  type        = string
  description = "ECR image URI for the Node.js app"
}

variable "mongo_uri" {
  type        = string
  description = "MongoDB connection string"
}

variable "ecs_sg_id" {
  type        = string
  description = "Security group ID for ECS EC2 instances"
}

variable "private_subnets" {
  type        = list(string)
  description = "List of private subnet IDs"
}

variable "target_group_arn" {
  type        = string
  description = "Target group ARN from ALB"
}

