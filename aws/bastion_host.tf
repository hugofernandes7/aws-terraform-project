resource "aws_instance" "bastion_host" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t3.micro"
  subnet_id                   = module.vpc.public_subnets[0]
  vpc_security_group_ids      = [aws_security_group.bastion_host_sg.id]
  associate_public_ip_address = true

  key_name = aws_key_pair.deployer.key_name

  tags = {
    Name      = "bastion_host"
    Terraform = "True"
  }
}

resource "aws_security_group" "bastion_host_sg" {
  description = "Security Group for Bastion_Host EC2 instance"
  vpc_id      = module.vpc.vpc_id

  tags = {
    Name      = "Bastion_Host"
    Terraform = "True"
  }
}

resource "aws_security_group_rule" "bastion_host_ssh_ingress" {
  type              = "ingress"
  description       = "Allow public ssh"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  ipv6_cidr_blocks  = []
  security_group_id = aws_security_group.bastion_host_sg.id
}

resource "aws_vpc_security_group_egress_rule" "bastion_host_egress" {
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
  security_group_id = aws_security_group.bastion_host_sg.id
}

