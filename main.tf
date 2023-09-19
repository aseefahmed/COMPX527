# Define the provider and region
provider "aws" {
  region = "us-east-1" # Change to your desired AWS region
}

# Create a VPC
resource "aws_vpc" "example" {
  cidr_block = "10.0.0.0/16" # Change this to your desired VPC CIDR block
}

# Create an Internet Gateway (IGW)
resource "aws_internet_gateway" "example" {
  vpc_id = aws_vpc.example.id
}

# Create two private subnets in the VPC
resource "aws_subnet" "private_subnet1" {
  vpc_id                  = aws_vpc.example.id
  cidr_block              = "10.0.1.0/24" # Change this to your desired subnet CIDR block
  availability_zone       = "us-east-1a" # Change to your desired availability zone
  map_public_ip_on_launch = false
}

resource "aws_subnet" "private_subnet2" {
  vpc_id                  = aws_vpc.example.id
  cidr_block              = "10.0.2.0/24" # Change this to your desired subnet CIDR block
  availability_zone       = "us-east-1b" # Change to your desired availability zone
  map_public_ip_on_launch = false
}

# Create a security group that allows all traffic
resource "aws_security_group" "allow_all" {
  name        = "allow-all"
  description = "Allow all inbound and outbound traffic"
  vpc_id      = aws_vpc.example.id

  ingress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Create an ECS task definition with Nginx image
resource "aws_ecs_task_definition" "nginx_task" {
  family                   = "nginx-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  memory    = 512
  cpu       = 10
  execution_role_arn = aws_iam_role.ecs_execution_role.arn

  container_definitions = jsonencode([
    {
      name  = "nginx-container"
      image = "nginx:latest"
      portMappings = [
        {
          containerPort = 80
          hostPort      = 80
        },
      ]
    },
  ])
}

# Create an IAM role for ECS task execution
resource "aws_iam_role" "ecs_execution_role" {
  name = "ecs_execution_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

# Create an ECS cluster
resource "aws_ecs_cluster" "example" {
  name = "example-cluster"
}

# Create an ECS service with 3 replicas
resource "aws_ecs_service" "nginx_service" {
  name            = "nginx-service"
  cluster         = aws_ecs_cluster.example.id
  task_definition = aws_ecs_task_definition.nginx_task.arn
  launch_type     = "FARGATE"
  desired_count   = 3
  network_configuration {
    subnets = [aws_subnet.private_subnet1.id, aws_subnet.private_subnet2.id]
    security_groups = [aws_security_group.allow_all.id]
  }
}

# Create an Application Load Balancer (ALB)
resource "aws_lb" "example" {
  name               = "example-alb"
  internal           = false
  load_balancer_type = "application"
  subnets            = [aws_subnet.private_subnet1.id, aws_subnet.private_subnet2.id]
}

# Create a target group for the ECS service
resource "aws_lb_target_group" "nginx_target_group" {
  name     = "nginx-target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.example.id
}

# Attach the ECS service to the target group
resource "aws_lb_target_group_attachment" "ecs_attachment" {
  target_group_arn = aws_lb_target_group.nginx_target_group.arn
  target_id        = aws_ecs_service.nginx_service.id
}

# Create a listener for the ALB
resource "aws_lb_listener" "example" {
  load_balancer_arn = aws_lb.example.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "Fixed response content"
      status_code  = "200"
    }
  }
}
