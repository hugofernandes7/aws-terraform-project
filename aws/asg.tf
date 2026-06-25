# Defines the configuration for EC2 instances that will be launched by the ASG
resource "aws_launch_template" "nomad_client_template" {
  name_prefix   = "nomad_client_template"
  image_id      = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"
  key_name      = aws_key_pair.deployer.key_name

  user_data = base64encode(templatefile("${path.module}/scripts/nomad_client.sh", {
    server_ip     = aws_instance.nomad_server.private_ip
    noip_username = var.noip_username
    noip_password = var.noip_password
    noip_hostname = var.noip_hostname
    nlb_dns_name  = aws_lb.lb.dns_name
  }))

  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [aws_security_group.nomad_client.id]
  }

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "nomad-client"
    }
  }

}

resource "aws_security_group" "nomad_client" {
  name   = "nomad-client-sg"
  vpc_id = module.vpc.vpc_id

  ingress {
    from_port   = 20000
    to_port     = 32000
    protocol    = "tcp"
    cidr_blocks = [module.vpc.vpc_cidr_block]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "nomad-client-sg"
  }
}

# Creates the ASG that maintains the desired number of instances
resource "aws_autoscaling_group" "asg_nomad_client" {
  name                = "asg_nomad_client"
  desired_capacity    = var.client_desired_capacity
  max_size            = var.client_max_size
  min_size            = var.client_min_size
  vpc_zone_identifier = module.vpc.private_subnets



  launch_template {
    id      = aws_launch_template.nomad_client_template.id
    version = "$Latest"
  }
}

resource "aws_autoscaling_policy" "nomad_client_cpu" {
  name                   = "nomad-client-cpu-target"
  autoscaling_group_name = aws_autoscaling_group.asg_nomad_client.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 50.0
  }
}

# Attaches the ASG to the LB_TG to automatically register de EC2 created
resource "aws_autoscaling_traffic_source_attachment" "asg_http" {
  autoscaling_group_name = aws_autoscaling_group.asg_nomad_client.id

  traffic_source {
    identifier = aws_lb_target_group.http.arn
    type       = "elbv2"
  }
}

resource "aws_autoscaling_traffic_source_attachment" "asg_https" {
  autoscaling_group_name = aws_autoscaling_group.asg_nomad_client.id

  traffic_source {
    identifier = aws_lb_target_group.https.arn
    type       = "elbv2"
  }
}
