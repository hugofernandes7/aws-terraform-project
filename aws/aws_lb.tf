# Create an Application Load Balancer with network interfaces in each public subnet
resource "aws_lb" "lb" {
  name               = "lb-tf"
  internal           = false
  load_balancer_type = "network"
  subnets            = module.vpc.public_subnets

  enable_deletion_protection = false

  tags = {
    Environment = "production"
  }
}

# Listens a specific port and then forwards incoming traffic to the target_group
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.lb.arn
  port              = "443"
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.https.arn
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.lb.arn
  port              = 80
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.http.arn
  }
}

# destination of the traffic is on this vpc
resource "aws_lb_target_group" "http" {
  name     = "lb-http-tg"
  port     = 8080
  protocol = "TCP"
  vpc_id   = module.vpc.vpc_id

  health_check {
    protocol = "TCP"
    port     = "8080"
  }
}

resource "aws_lb_target_group" "https" {
  name     = "lb-https-tg"
  port     = 443
  protocol = "TCP"

  vpc_id = module.vpc.vpc_id

  health_check {
    protocol = "TCP"
    port     = "443"
  }
}
