# Provider
provider "aws" {
    region = var.aws_region
}





# Define variables
variable "aws_region" {
  default = "eu-north-1"
}

variable "vpc_id" {
  default = "vpc-0fbb33dec5e870a74"
}

variable "subnets" {
  default = ["subnet-0d48bc8236fe5ce0e"]
}


# Create a security group
resource "aws_security_group" "web_sg" {
  name        = "web_sg"
  description = "Security group for web servers"

  # Define ingress rules
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow inbound SSH access for administration
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Define egress rules
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Launch Configuration
resource "aws_launch_configuration" "example" {
  name          = "example-lc"
  image_id      = "ami-02d0a1cbe2c3e5ae4" # Your AMI ID
  instance_type = "t3.micro"
  security_groups = [aws_security_group.web_sg.name]

  user_data = <<-EOF
              #!/bin/bash
              sudo -i
              yum update -y
              yum install httpd -y
              systemctl start httpd
              systemctl enable httpd
              echo "<h1>Hello World from $(hostname -f)</h1>" > /var/www/html/index.html
              EOF

  lifecycle {
    create_before_destroy = true
  }
}

# Autoscaling Group
resource "aws_autoscaling_group" "example" {
  name                      = "example-asg"
  max_size                  = 4
  min_size                  = 1
  desired_capacity          = 2
  vpc_zone_identifier       = var.subnets
  launch_configuration      = aws_launch_configuration.example.name

  target_group_arns = [aws_lb_target_group.example.arn]
}

# ALB
resource "aws_lb" "example" {
  name               = "example-alb"
  internal           = false
  load_balancer_type = "application"
  subnets            = var.subnets
}

# Target Group
resource "aws_lb_target_group" "example" {
  name     = "example-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id
}

# Listener
resource "aws_lb_listener" "example" {
  load_balancer_arn = aws_lb.example.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.example.arn
  }
}