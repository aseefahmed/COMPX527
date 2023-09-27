# Define the provider and region
provider "aws" {
  region = "us-east-1" # Change to your desired AWS region
}

resource "random_pet" "unique_pet" {
}

# Create a VPC
resource "aws_vpc" "vpc" {
  cidr_block = "10.0.0.0/16" # Change this to your desired VPC CIDR block
}

# Create an Internet Gateway (IGW)
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id
}

resource "aws_route_table" "rt" {
  vpc_id = aws_vpc.vpc.id
}

resource "aws_route" "awsrt" {
  route_table_id         = aws_route_table.rt.id
  destination_cidr_block = "0.0.0.0/0" 
  gateway_id             = aws_internet_gateway.igw.id
}

# Create two private subnets in the VPC
resource "aws_subnet" "subnet1" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = false
}

resource "aws_subnet" "subnet2" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = "10.0.2.0/24" 
  availability_zone       = "us-east-1b" 
  map_public_ip_on_launch = false
}


resource "aws_route_table_association" "rtb1" {
  subnet_id      = aws_subnet.subnet1.id
  route_table_id = aws_route_table.rt.id
}
resource "aws_route_table_association" "rtb2" {
  subnet_id      = aws_subnet.subnet2.id
  route_table_id = aws_route_table.rt.id
}

# Create a security group that allows all traffic
resource "aws_security_group" "allow_all" {
  name        = "allow-all-${random_pet.unique_pet.id}"
  description = "Allow all inbound and outbound traffic"
  vpc_id      = aws_vpc.vpc.id

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
  family                   = "nginx-task-${random_pet.unique_pet.id}"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 1024
  memory                   = 2048
  execution_role_arn = aws_iam_role.ecs_execution_role.arn

  container_definitions = jsonencode([
    {
      name  = "nginx-container-${random_pet.unique_pet.id}"
      image = "aseefahmed/waikato_health_app:latest"
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
  name = "ecs_execution_role_new-${random_pet.unique_pet.id}"
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
resource "aws_ecs_cluster" "ecsclstr" {
  name = "cluster-new"
}

# Create an ECS service with 3 replicas
resource "aws_ecs_service" "nginx_service" {
  name            = "nginx-service-new-${random_pet.unique_pet.id}"
  cluster         = aws_ecs_cluster.ecsclstr.id
  task_definition = aws_ecs_task_definition.nginx_task.arn
  launch_type     = "FARGATE"
  desired_count   = 3
  network_configuration {
    subnets = [aws_subnet.subnet1.id, aws_subnet.subnet2.id]
    security_groups = [aws_security_group.allow_all.id]
    assign_public_ip = true
  }

}

# Create an Application Load Balancer (ALB)
resource "aws_lb" "alb" {
  # unique name to alb
  name               = "alb-${random_pet.unique_pet.id}"
  internal           = false
  load_balancer_type = "application"
  subnets            = [aws_subnet.subnet1.id, aws_subnet.subnet2.id]
}

resource "aws_lb_listener" "web" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.nginx_target_group.arn
  }
  
}


# Create a target group for the ECS service
resource "aws_lb_target_group" "nginx_target_group" {
  name     = "tg-${random_pet.unique_pet.id}"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.vpc.id
}

# output "result" {
#     value = aws_ecs_service.nginx_service
# }
# # Attach the ECS service to the target group
# resource "aws_lb_target_group_attachment" "ecs_attachment" {
#   target_group_arn = aws_lb_target_group.nginx_target_group.arn
#   target_id        = aws_ecs_service.nginx_service.name
# }

output "target_group_arn" {
    value = aws_lb_target_group.nginx_target_group.arn
    description = "Target Group ARN"
}
output "nginx_service" {
    value = aws_ecs_service.nginx_service
    description = "ECS Service ID"
}

# # Create a listener for the ALB
# resource "aws_lb_listener" "example" {
#   load_balancer_arn = aws_lb.alb.arn
#   port              = 80
#   protocol          = "HTTP"

#   default_action {
#     type             = "fixed-response"
#     fixed_response {
#       content_type = "text/plain"
#       message_body = "Fixed response content"
#       status_code  = "200"
#     }
#   }
# }
