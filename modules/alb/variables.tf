variable "env" {
  type        = string
  description = "Environment name"
}

variable "sg_id" {
  type        = string
  description = "Security group ID for ALB"
}

variable "public_subnets" {
  type        = list(string)
  description = "Public subnet IDs"
}

variable "vpc_id" {
  type        = string
  description = "VPC ID"
}

variable "container_port" {
  type        = number
  description = "Port on which ECS container is running"
  default     = 3000
}

