##############################################
# ECS Module - EC2 Launch Type
##############################################

# Fetch latest ECS-optimized Amazon Linux 2 AMI
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-ecs-hvm-*-x86_64-ebs"]
  }
}

# ECS Cluster
resource "aws_ecs_cluster" "this" {
  name = "${var.env}-ecs-cluster"
}

# IAM Role for ECS EC2 Instances
resource "aws_iam_role" "ecs_instance_role" {
  name = "${var.env}-ecs-instance-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_instance_role_attach" {
  role       = aws_iam_role.ecs_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"

  depends_on = [aws_iam_role.ecs_instance_role]
}

resource "aws_iam_instance_profile" "ecs_instance_profile" {
  name = "${var.env}-ecs-instance-profile"
  role = aws_iam_role.ecs_instance_role.name

  depends_on = [aws_iam_role_policy_attachment.ecs_instance_role_attach]
}

# Launch Template for ECS EC2 instances
resource "aws_launch_template" "ecs_lt" {
  name_prefix   = "${var.env}-ecs-lt-"
  image_id      = data.aws_ami.amazon_linux.id
  instance_type = "t3.micro"

  iam_instance_profile {
    name = aws_iam_instance_profile.ecs_instance_profile.name
  }

  user_data = base64encode(<<EOF
#!/bin/bash
echo ECS_CLUSTER=${aws_ecs_cluster.this.name} >> /etc/ecs/ecs.config
EOF
  )

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [var.ecs_sg_id]
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${var.env}-ecs-instance"
    }
  }

  depends_on = [aws_ecs_cluster.this, aws_iam_instance_profile.ecs_instance_profile]
}

# ECS EC2 Auto Scaling Group
resource "aws_autoscaling_group" "ecs_asg" {
  name                = "${var.env}-ecs-asg"
  desired_capacity    = 1
  max_size            = 2
  min_size            = 1
  vpc_zone_identifier = var.private_subnets

  launch_template {
    id      = aws_launch_template.ecs_lt.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "${var.env}-ecs-instance"
    propagate_at_launch = true
  }

  depends_on = [aws_launch_template.ecs_lt]
}

# ECS Task Definition
resource "aws_ecs_task_definition" "app" {
  family                  = "${var.env}-nodeapp-task"
  network_mode            = "bridge"
  requires_compatibilities = ["EC2"]
  cpu                     = "256"
  memory                  = "512"

  container_definitions = jsonencode([{
    name      = "nodejs-app"
    image     = var.app_image
    essential = true
    portMappings = [{
      containerPort = 3000
      hostPort      = 3000
    }]
    environment = [
      { name = "MONGO_URI", value = var.mongo_uri },
      { name = "NODE_ENV",  value = var.env }
    ]
  }])
}

# ECS Service
resource "aws_ecs_service" "app_service" {
  name            = "${var.env}-nodejs-service"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = 1
  launch_type     = "EC2"

  load_balancer {
    target_group_arn = var.target_group_arn
    container_name   = "nodejs-app"
    container_port   = 3000
  }

  depends_on = [
    aws_autoscaling_group.ecs_asg,
    aws_ecs_task_definition.app,
    var.target_group_arn
  ]
}

