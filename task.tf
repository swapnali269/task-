# Define provider (AWS in this case)
provider "aws" {
  region = "eu-north-1" # Change to your desired region
}

# Create a security group
resource "aws_security_group" "web_sg" {
  name        = "web_sg"
  description = "Security group for web servers"

  # Define ingress rule
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

# Create an application load balancer
resource "aws_lb" "web_alb" {
  name               = "web-alb"
  internal           = false
  load_balancer_type = "application"
  subnets            = ["subnet-0d48bc8236fe5ce0e", "subnet-0a6caeea4f7304c9d"] # Specify your subnet IDs
  security_groups    = [aws_security_group.web_sg.id]
  enable_deletion_protection = false

  tags = {
    Name = "web-alb"
  }
}

# Create a listener for ALB
resource "aws_lb_listener" "web_alb_listener" {
  load_balancer_arn = aws_lb.web_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "Hello, world"
      status_code  = "200"
    }
  }
}


# Create a target group
resource "aws_lb_target_group" "web_target_group" {
  name        = "web-target-group"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = "vpc-0fbb33dec5e870a74" # Specify your VPC ID
  target_type = "instance"
}

# Create a listener rule
resource "aws_lb_listener_rule" "web_alb_rule" {
  listener_arn = aws_lb_listener.web_alb_listener.arn

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web_target_group.arn
  }

  condition {
    path_pattern {
      values = ["/"]
    }
  }
}

# Create launch configuration
resource "aws_launch_configuration" "web_lc" {
  name          = "web_lc"
  image_id      = "ami-02d0a1cbe2c3e5ae4" # Specify your AMI ID
  instance_type = "t3.micro"      # Specify your instance type

  security_groups = [aws_security_group.web_sg.id]

  user_data = <<-EOF
              #!/bin/bash
              sudo -i
              yum update -y
              yum install httpd -y
              systemctl start httpd
              systemctl enable httpd
              echo "<h1>Hello World from $(hostname -f)</h1>" > /var/www/html/index.html
              yum install stress -y
              stress --cpu 200 --io 2 --vm 1 --vm-bytes 128M --timeout 1000s
              EOF

  lifecycle {
    create_before_destroy = true
  }
}

# Create auto scaling group
resource "aws_autoscaling_group" "web_asg" {
name                 = "web_asg"
  launch_configuration = aws_launch_configuration.web_lc.name
  min_size             = 2
  max_size             = 5
  desired_capacity     = 3
  vpc_zone_identifier  = ["subnet-0d48bc8236fe5ce0e", "subnet-0a6caeea4f7304c9d"] # Specify your subnet IDs

  health_check_type   = "ELB"
  target_group_arns   = ["arn:aws:elasticloadbalancing:eu-north-1:992382717347:targetgroup/web-target-group/fdbd0fac8b8a0f02"]

  tag {
    key                 = "Name"
    value               = "web-server"
    propagate_at_launch = true
  }
}


resource "aws_autoscaling_policy" "example" {
  name                   = "example-policy"
  policy_type            = "TargetTrackingScaling"

  adjustment_type        = "ChangeInCapacity"

  autoscaling_group_name = aws_autoscaling_group.web_asg.name

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }

    target_value = 30 # You want to scale out when the average CPU utilization is at 70%.
  }
}

