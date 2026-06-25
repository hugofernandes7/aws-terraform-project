output "bastion_ip" {
  value = aws_instance.bastion_host.public_ip
}

output "nomad_server" {
  value = aws_instance.nomad_server.private_ip
}

output "runner" {
  value = aws_instance.runner.private_ip
}

output "asg_nomad_client" {
  value = data.aws_instances.asg_instances.private_ips[0]
}

output "server_private_ip" {
  value = aws_instance.nomad_server.private_ip
}

output "asg_nomad_all_clients" {
  value = data.aws_instances.asg_instances.private_ips
}

output "alb_dns" {
  value = aws_lb.lb.dns_name
}
