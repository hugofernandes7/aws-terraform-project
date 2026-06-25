data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-20260430"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

data "cloudinit_config" "foobar" {
  gzip          = false
  base64_encode = false

  part {
    filename     = "container.sh"
    content_type = "text/x-shellscript"

    content = file("${path.module}/scripts/container.sh")
  }

  part {
    filename     = "launch_runner.sh"
    content_type = "text/x-shellscript"

    content = templatefile("${path.module}/scripts/launch_runner.sh",
      {
        gitlab_token = var.gitlab_token
        gitlab_url   = var.gitlab_url
    })
  }
}

data "aws_instances" "asg_instances" {
  filter {
    name   = "tag:aws:autoscaling:groupName"
    values = [aws_autoscaling_group.asg_nomad_client.name]
  }
}
