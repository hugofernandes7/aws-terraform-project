# AWS – Build and Scale the DevOps Way

Infraestrutura na AWS provisionada com **Terraform**, configurada com **Ansible** e com deployment automático de uma aplicação em containers através de **Nomad** e de uma pipeline **GitLab CI/CD**.

## Arquitetura

O projeto implementa o seguinte ambiente (diagrama do enunciado):

![Arquitetura](docs/architecture.png)

| Nº  | Componente do diagrama | Implementação neste projeto                          |
| --- | ---------------------- | ---------------------------------------------------- |
| 1   | GitLab Server          | GitLab (`gitlab.estig.ipb.pt`) + Container Registry no **Docker Hub** |
| 2   | GitLab Runner          | EC2 com runner registado (`aws/runner.tf`)           |
| 3   | Container Orchestrator | **Nomad Server** (`aws/nomad_server.tf`)             |
| 4   | Auto Scaling Group     | Clientes Nomad em ASG (`aws/asg.tf`)                 |
| 5   | Load Balancer          | Network Load Balancer (`aws/aws_lb.tf`) + No-IP DNS  |

O acesso SSH às instâncias privadas é feito através de um **Bastion Host** (`aws/bastion_host.tf`).

## Pré-requisitos

- [Terraform](https://www.terraform.io/) >= 1.x
- [AWS CLI](https://aws.amazon.com/cli/) configurado (`aws configure`)
- [Ansible](https://www.ansible.com/)
- Conta [No-IP](https://www.noip.com) (DNS dinâmico)

> **Nenhum segredo está no repositório.** Os valores sensíveis são fornecidos em `terraform.tfvars` (ignorado pelo Git).

## Passos

### 1. Configurar variáveis

```bash
cd aws
cp terraform.tfvars.example terraform.tfvars
# editar terraform.tfvars com os teus valores
```

Gerar o par de chaves SSH e colar a chave **pública** em `ssh_public_key`:

```bash
ssh-keygen -t ed25519 -f ~/.ssh/my-key-aws
```

### 2. Provisionar a infraestrutura (Terraform)

```bash
terraform init
terraform plan
terraform apply
```

### 3. Configurar o acesso SSH

Gera o `~/.ssh/config` a partir dos outputs do Terraform:

```bash
./connect.sh
```

Depois é possível ligar via Bastion: `ssh bastion`, `ssh nomad-server`, `ssh runner`.

### 4. Configurar os servidores (Ansible)

Instala e configura o Nomad, o Nginx e o TLS:

```bash
cd ../ansible
ansible-playbook -i inventory.ini playbooks/site.yml --ask-vault-pass
```

> `--ask-vault-pass` é necessário porque os certificados TLS estão protegidos com **Ansible Vault** (`group_vars/all/vault.yml`).

### 5. Fazer deploy da aplicação (GitLab CI/CD)

Define a variável `NOMAD_ADDR` no GitLab (endereço do Nomad Server) e faz push:

```bash
git push
```

A pipeline (`.gitlab-ci.yml`):
1. faz **build** das imagens Docker (webapp + nomad-runner);
2. **publica** no Docker Hub;
3. executa `nomad job run nomad-jobs/webapp.hcl` para fazer o deploy.

### 6. Atualizar o DNS dinâmico (No-IP)

Aponta o domínio No-IP para um IP saudável do Load Balancer:

```bash
cd ../aws
export NOIP_HOST="o_teu_host.myftp.org"
export NOIP_USER="o_teu_email"
export NOIP_PASS="a_tua_password"
./scripts/update-noip.sh
```

## Estrutura do projeto

```text
aws/            Infraestrutura Terraform (VPC, bastion, nomad, ASG, NLB, runner)
ansible/        Playbooks de configuração (Nomad, Nginx, TLS) + Vault
nomad-jobs/     Definição do job Nomad da aplicação (webapp.hcl)
nomad-runner/   Imagem Docker com Nomad CLI usada pela pipeline
app/            Dockerfile e configuração da aplicação web
docs/           Documentação e diagrama de arquitetura
```

## Notas

- As imagens Docker usam o namespace `maciel04` (públicas). Para replicar com a tua conta, substitui `maciel04` em `nomad-jobs/webapp.hcl` e `.gitlab-ci.yml`.
- O ambiente AWS Academy Sandbox tem um limite de **9 instâncias EC2** — tem isto em conta ao ajustar o ASG.
