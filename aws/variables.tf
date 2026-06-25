variable "profile" {
  type    = string
  default = "etux-tst"
}

variable "region" {
  type    = string
  default = "eu-west-1"
}

variable "gitlab_token" {
  description = "Used to initialize the gitlab provider"
  type        = string
  sensitive   = true
}

variable "gitlab_url" {
  description = "Your gitlab server's fully qualified domain name"
  type        = string
  default     = "https://gitlab.estig.ipb.pt"
}

variable "client_instance_type" {
  description = "Tipo de instância EC2 para os nós cliente do Nomad (ASG)"
  type        = string
  default     = "t3.micro"
}

variable "client_min_size" {
  description = "Número mínimo de nós cliente no Auto Scaling Group"
  type        = number
  default     = 2
}

variable "client_desired_capacity" {
  description = "Número desejado de nós cliente no Auto Scaling Group"
  type        = number
  default     = 2
}

variable "client_max_size" {
  description = "Número máximo de nós cliente no Auto Scaling Group "
  type        = number
  default     = 4
}

variable "noip_username" {
  description = "No-IP account username/email (set in terraform.tfvars)"
  type        = string
}

variable "noip_password" {
  description = "No-IP account password (set in terraform.tfvars or via TF_VAR_noip_password)"
  type        = string
  sensitive   = true
}

variable "noip_hostname" {
  description = "No-IP dynamic DNS hostname, e.g. example.myftp.org"
  type        = string
}

variable "ssh_public_key" {
  description = "Public SSH key used for the EC2 deployer key pair"
  type        = string
}

variable "fqdn" {
  description = "Public FQDN served by the webapp (usually the No-IP hostname)"
  type        = string
  default     = "example.myftp.org"
}

