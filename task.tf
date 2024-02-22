provider "aws" {
  region = "eu-north-1"
}


# Retrieve default VPC ID
data "aws_vpc" "default" {
  default = true
}

# Create security group
resource "aws_security_group" "example" {
  name        = "example-security-group"
  description = "Example security group for default VPC"
  vpc_id      = data.aws_vpc.default.id
  
  # Define ingress and egress rules as needed
  # Example:
  # ingress {
  #   from_port   = 80
  #   to_port     = 80
  #   protocol    = "tcp"
  #   cidr_blocks = ["0.0.0.0/0"]
  # }
  # egress {
  #   from_port   = 0
  #   to_port     = 0
  #   protocol    = "-1"
  #   cidr_blocks = ["0.0.0.0/0"]
  # }
}


# Define the index.html content
data "template_file" "index_html" {
  template = file("./index.html")
}

# Define Launch Template
resource "aws_launch_template" "example" {
  name_prefix   = "example-launch-template"
  image_id      = "ami-02d0a1cbe2c3e5ae4" # specify your AMI
  instance_type = "t3.micro"
  security_group_id = aws_security_group.example.id

  block_device_mappings {
    device_name           = "/dev/sda1"
    ebs {
      volume_size = 20
    }
  }

  # User data for copying index.html
  user_data = <<-EOF
              #!/bin/bash
              echo '${data.template_file.index_html.rendered}' > /var/www/html/index.html
              EOF
}

# Define Auto Scaling Group
resource "aws_autoscaling_group" "example" {
  name                 = "example-autoscaling-group"
  launch_configuration = aws_launch_configuration.example.name
  min_size             = 2
  max_size             = 5
  desired_capacity     = 3
  vpc_zone_identifier  = ["subnet-0a6caeea4f7304c9d","subnet-0d48bc8236fe5ce0e"] # specify your subnets
}

# Define Auto Scaling Policies
resource "aws_autoscaling_policy" "scale_out" {
  name                   = "scale-out-policy"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300 # 5 minutes cooldown
  autoscaling_group_name = aws_autoscaling_group.example.name

  # Specify conditions for scaling out
}

resource "aws_autoscaling_policy" "scale_in" {
  name                   = "scale-in-policy"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300 # 5 minutes cooldown
  autoscaling_group_name = aws_autoscaling_group.example.name

  # Specify conditions for scaling in
}

# Define Load Balancer
resource "aws_lb" "example" {
  name               = "example-load-balancer"
  internal           = false
  load_balancer_type = "application"
  security_groups    = ["my-sg"] # specify your security group
  subnets            = ["subnet-0a6caeea4f7304c9d","subnet-0d48bc8236fe5ce0e"] # specify your subnets
}

# Define Target Group
resource "aws_lb_target_group" "example" {
  name     = "example-target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.default.id  # specify your VPC ID
}

# Associate Auto Scaling Group with Load Balancer
resource "aws_autoscaling_attachment" "example" {
  autoscaling_group_name = aws_autoscaling_group.example.name
  alb_target_group_arn   = aws_lb_target_group.example.arn
}

output "load_balancer_dns_name" {
  value = aws_lb.example.dns_name
}

