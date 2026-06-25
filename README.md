# Execução do Projeto

A infraestrutura e a aplicação podem ser disponibilizadas através das seguintes etapas.

---

## 0. Pré-requisitos e Configuração

Antes de provisionar, é necessário fornecer alguns valores próprios. **Nenhum segredo está incluído no repositório.**

### Ferramentas

- Terraform >= 1.x
- AWS CLI configurado (`aws configure`) com um profile válido
- Ansible (para a configuração dos servidores)
- Uma conta [No-IP](https://www.noip.com) (DNS dinâmico)

### Variáveis do Terraform

Copia o ficheiro de exemplo e preenche com os teus valores:

```bash
cd aws
cp terraform.tfvars.example terraform.tfvars
```

| Variável         | Descrição                                                        |
| ---------------- | ---------------------------------------------------------------- |
| `gitlab_token`   | Token de registo do runner GitLab                                |
| `gitlab_url`     | URL do servidor GitLab                                           |
| `ssh_public_key` | Chave SSH **pública** para acesso às instâncias EC2              |
| `noip_username`  | Email/utilizador da conta No-IP                                  |
| `noip_password`  | Password No-IP (sensível)                                        |
| `noip_hostname`  | Hostname dinâmico No-IP (ex.: `example.myftp.org`)               |
| `fqdn`           | FQDN público servido pela aplicação (normalmente igual ao No-IP) |

Gera o par de chaves SSH usado no acesso às instâncias:

```bash
ssh-keygen -t ed25519 -f ~/.ssh/my-key-aws
# cola o conteúdo de ~/.ssh/my-key-aws.pub na variável ssh_public_key
```

> `terraform.tfvars` e as chaves SSH (`my-key-aws*`) estão no `.gitignore` e nunca devem ser commitados.

### Imagens Docker

Os jobs Nomad e o pipeline usam o namespace Docker Hub `maciel04` (imagens públicas). Para replicar com a tua própria conta, substitui `maciel04` em `nomad-jobs/webapp.hcl` e `.gitlab-ci.yml` pelo teu namespace.

---

## 1. Provisionamento da Infraestrutura

Responsável pela criação dos recursos AWS.

### Comandos

```bash
cd aws

terraform init
terraform plan
terraform apply
```

### Resultado

| Comando           | Resultado                   |
| ----------------- | --------------------------- |
| `terraform init`  | Inicialização dos providers |
| `terraform plan`  | Validação das alterações    |
| `terraform apply` | Criação da infraestrutura   |

---

## 2. Configuração dos Acessos

Responsável pela geração automática da configuração SSH.

### Comandos

```bash
export NOIP_PASS="a_tua_password"
./update-noip.sh
```

### Resultado

| Comando            | Resultado                          |
| ------------------ | ---------------------------------- |
| `connect.sh`       | Geração automática do ficheiro SSH |
| `ssh bastion`      | Ligação ao Bastion Host            |
| `ssh nomad-server` | Ligação ao Nomad Server            |
| `ssh runner`       | Ligação ao GitLab Runner           |

---

## 3. Configuração dos Servidores

Responsável pela instalação e configuração automática dos serviços utilizados pela infraestrutura.

### Comandos

```bash
cd ansible

ansible-playbook -i inventory.ini playbooks/site.yml --ask-vault-pass
```

### Resultado

| Componente    | Resultado    |
| ------------- | ------------ |
| Nomad Server  | Configurado  |
| Nomad Clients | Configurados |
| Nginx         | Configurado  |
| TLS           | Configurado  |

### Justificação

O parâmetro `--ask-vault-pass` é necessário porque parte da configuração utiliza o **Ansible Vault** para armazenar informação sensível de forma segura.

No projeto, o Vault é utilizado para proteger os certificados TLS e outras variáveis confidenciais necessárias durante a configuração dos servidores.

Sem a palavra-passe do Vault, o Ansible não consegue desencriptar estas informações e o processo de configuração não pode ser concluído.

### Benefícios

 Benefício | Descrição |
|-----------|-----------|
| Segurança | Certificados protegidos através do Ansible Vault |
| Boas Práticas | Separação entre código e informação sensível |
| Controlo de Acesso | Apenas utilizadores autorizados podem aceder aos certificados |
| Automatização Segura | Configuração automática sem exposição de credenciais |

## 4. Deployment da Aplicação

Após a configuração da infraestrutura e dos servidores, a aplicação pode ser disponibilizada através da pipeline GitLab CI/CD.

### Pré-Requisitos

Antes de iniciar o deployment, é necessário atualizar a variável `NOMAD_ADDR` no GitLab com o endereço do Nomad Server.

Esta variável é utilizada pelo Nomad CLI durante a execução da pipeline para identificar o servidor com o qual deve comunicar ao executar o comando `nomad job run`.

### Configuração

| Variável       | Função                     |
| -------------- | -------------------------- |
| `NOMAD_ADDR`   | Endereço do Nomad Server   |
| `DOCKER_USER`  | Utilizador do Docker Hub   |
| `DOCKER_TOKEN` | Autenticação no Docker Hub |

### Fluxo

```text
Terraform Outputs
        │
        ▼

 Nomad Server IP
        │
        ▼

 GitLab Variable
 (NOMAD_ADDR)
        │
        ▼

 GitLab Pipeline
```

### Comandos

```bash
git add .
git commit -m "Nova versão"
git push
```

### Automatização

| Ação                        | Resultado                         |
| --------------------------- | --------------------------------- |
| Atualização de `NOMAD_ADDR` | Pipeline conhece o Nomad Server   |
| `git push`                  | Pipeline iniciada automaticamente |
| Build Docker                | Nova imagem criada                |
| Push Docker Hub             | Imagem publicada                  |
| `nomad job run`             | Deployment executado              |

### Justificação

O endereço do Nomad Server pode variar entre diferentes ambientes ou após alterações à infraestrutura. Por este motivo, o valor não é definido diretamente nos ficheiros da pipeline.

A utilização da variável `NOMAD_ADDR` permite desacoplar a configuração do ambiente da lógica da pipeline, tornando o processo mais flexível e reutilizável.

## Dynamic DNS

Após a conclusão da pipeline, a aplicação encontra-se em execução nos clientes Nomad e acessível através do Network Load Balancer.

### Fluxo

```text
GitLab Pipeline
        │
        ▼

 Nomad Deployment
        │
        ▼

 Nomad Clients
        │
        ▼

 Network Load Balancer
```

### Validação

Antes de associar o domínio à aplicação, é executado o script `update-noip.sh`.

Este script resolve os IPs associados ao DNS do Network Load Balancer, verifica quais conseguem comunicar corretamente com a aplicação e seleciona um endpoint funcional para atualização do serviço No-IP.

### Fluxo

```text
Load Balancer DNS
        │
        ▼

 Resolução dos IPs
        │
        ▼

 Teste de Conectividade
        │
        ▼

 Validação da Aplicação
        │
        ▼

 Atualização No-IP
```

### Automatização

| Ação                 | Resultado                                   |
| -------------------- | ------------------------------------------- |
| Deployment concluído | Aplicação disponível nos clientes           |
| Resolução DNS        | Obtenção dos IPs do Load Balancer           |
| Teste HTTP           | Verificação da disponibilidade da aplicação |
| Seleção do endpoint  | Escolha de um IP funcional                  |
| Atualização No-IP    | Domínio associado ao serviço                |

### Justificação

Os endereços IP associados ao Network Load Balancer podem variar ao longo do tempo. Por este motivo, não é recomendável associar manualmente um endereço ao domínio.

O script `update-noip.sh` resolve automaticamente os IPs do Load Balancer, testa cada endpoint e verifica quais conseguem encaminhar corretamente os pedidos para a aplicação. Apenas após esta validação é efetuada a atualização do registo DNS.

### Benefícios

| Benefício       | Descrição                                   |
| --------------- | ------------------------------------------- |
| Disponibilidade | Domínio aponta para um serviço funcional    |
| Automatização   | Atualização automática do DNS               |
| Fiabilidade     | Validação da aplicação antes da atualização |
| Continuidade    | Menor risco de indisponibilidade            |
|                 |                                             |


# Arquitetura Geral

```text
                                    Internet
                                        │
                                        ▼
                               +----------------+
                               |   No-IP DNS    |
                               +----------------+
                                        │
                                        ▼
                               +----------------+
                               | Network Load   |
                               |   Balancer     |
                               +----------------+
                                        │
                       ┌────────────────┴────────────────┐
                       │                                 │
                       ▼                                 ▼

             +------------------+             +------------------+
             | Nomad Client 1   |             | Nomad Client 2   |
             | Docker           |             | Docker           |
             | Nginx            |             | Nginx            |
             | Web Application  |             | Web Application  |
             +------------------+             +------------------+

                       Auto Scaling Group (ASG)
                                   │
                                   ▼

                         +------------------+
                         |   Nomad Server   |
                         | Cluster Manager  |
                         +------------------+

                                   │
                                   ▼

                         +------------------+
                         |  GitLab Runner   |
                         | CI/CD Execution  |
                         +------------------+

                                   │
                                   ▼

                         +------------------+
                         |   Bastion Host   |
                         | Secure Access    |
                         +------------------+
```

# Bastion Host

O Bastion Host constitui o único ponto de acesso SSH público da infraestrutura. Todas as restantes instâncias encontram-se protegidas em rede privada e são acedidas através deste servidor utilizando ProxyJump.

## Características

| Componente                   | Implementação           |
| ---------------------------- | ----------------------- |
| Acesso SSH público           | Bastion Host            |
| Acesso a instâncias privadas | ProxyJump               |
| Configuração SSH             | `~/.ssh/config`         |
| Automatização                | Script `aws/connect.sh` |
| Descoberta de IPs            | Terraform Outputs       |

---

# Configuração Automática com Ansible

A configuração dos servidores foi automatizada através do Ansible, permitindo garantir instalações consistentes e reproduzíveis em todas as instâncias do cluster.

## Estrutura

| Ficheiro                   | Função                               |
| -------------------------- | ------------------------------------ |
| `playbooks/site.yml`       | Playbook principal                   |
| `playbooks/nomad.yml`      | Instalação e configuração do Nomad   |
| `playbooks/tls.yml`        | Configuração HTTPS e Nginx           |
| `inventory.ini`            | Definição dos grupos de servidores   |
| `group_vars/all/vault.yml` | Armazenamento de variáveis sensíveis |

## Inventory

| Grupo             | Hosts                          |
| ----------------- | ------------------------------ |
| `nomad_instances` | Nomad Server                   |
| `nomad_clients`   | Nomad Client 1, Nomad Client 2 |

## Nomad

A instalação do Nomad foi realizada através da role da comunidade `brianshumate.nomad`, executada sobre os hosts definidos no grupo `nomad_instances`.

| Funcionalidade           | Implementação        |
| ------------------------ | -------------------- |
| Instalação do Nomad      | `brianshumate.nomad` |
| Gestão do serviço        | Systemd              |
| Inicialização automática | Ansible              |
| Configuração do servidor | Playbook `nomad.yml` |

## TLS e Nginx

O playbook `tls.yml` é responsável pela configuração HTTPS dos clientes Nomad.

| Funcionalidade      | Implementação      |
| ------------------- | ------------------ |
| Instalação do Nginx | Ansible            |
| Configuração HTTPS  | Certificados TLS   |
| Reverse Proxy       | Nginx → Aplicação  |
| Health Check        | Endpoint `/health` |
| Redirecionamento    | HTTP → HTTPS       |

## Fluxo de Execução

```text
site.yml
   │
   ├── nomad.yml
   │      └── Instalação do Nomad
   │
   └── tls.yml
          ├── Instalação Nginx
          ├── Configuração TLS
          └── Reverse Proxy HTTPS
```

---

# Nomad Jobs

Os deployments da aplicação são geridos através de ficheiros HCL (HashiCorp Configuration Language), permitindo definir de forma declarativa como os workloads devem ser executados no cluster Nomad.

## Estrutura

| Ficheiro                | Função                               |
| ----------------------- | ------------------------------------ |
| `nomad-jobs/webapp.hcl` | Definição do deployment da aplicação |

## Configuração do Job

| Componente         | Implementação  |
| ------------------ | -------------- |
| Orquestrador       | Nomad          |
| Driver             | Docker         |
| Imagem             | Docker Hub     |
| Rede               | Host Network   |
| Porta da aplicação | 8080           |
| Réplicas           | 2 Instâncias   |
| Atualizações       | Rolling Update |

## Funcionalidades

| Funcionalidade       | Descrição                           |
| -------------------- | ----------------------------------- |
| Deploy Declarativo   | Infraestrutura definida em HCL      |
| Alta Disponibilidade | Execução de múltiplas instâncias    |
| Rolling Updates      | Atualizações sem downtime           |
| Docker Integration   | Execução através de containers      |
| Health Monitoring    | Validação automática das instâncias |

## Fluxo de Deployment

```text
GitLab Pipeline
        │
        ▼
Docker Hub
        │
        ▼
webapp.hcl
        │
        ▼
Nomad Server
        │
        ▼
Nomad Clients
        │
        ▼
Application Running
```

## Automatização

| Ação               | Resultado                           |
| ------------------ | ----------------------------------- |
| Nova imagem Docker | Atualização da variável `IMAGE_TAG` |
| Execução do Job    | Distribuição automática             |
| Falha de instância | Reagendamento automático            |
| Nova versão        | Rolling Update                      |

---

# Nomad Runner

O diretório `nomad-runner` contém o Dockerfile responsável pela criação da imagem utilizada pelo GitLab Runner durante o processo de deployment.

Esta imagem inclui o **Nomad CLI**, permitindo que a pipeline comunique diretamente com o Nomad Server e execute operações de deployment no cluster.

## Estrutura

| Ficheiro                  | Função                                  |
| ------------------------- | --------------------------------------- |
| `nomad-runner/Dockerfile` | Construção da imagem de deployment      |
| `.gitlab-ci.yml`          | Utilização da imagem durante a pipeline |

## Componentes

| Componente           | Implementação         |
| -------------------- | --------------------- |
| Base Image           | Docker                |
| Ferramenta principal | Nomad CLI             |
| Integração           | GitLab CI/CD          |
| Comunicação          | Nomad Server          |
| Função               | Deployment Automation |

## Fluxo de Utilização

```text
GitLab Pipeline
        │
        ▼
 Nomad Runner Image
        │
        ▼
     Nomad CLI
        │
        ▼
    Nomad Server
        │
        ▼
   Nomad Clients
```

## Automatização

| Ação                 | Resultado                     |
| -------------------- | ----------------------------- |
| Build da imagem      | Ambiente consistente          |
| Execução da pipeline | Disponibilização do Nomad CLI |
| `nomad job run`      | Deployment automático         |
| Atualização do Job   | Rolling Update da aplicação   |

## Justificação

Embora fosse possível executar manualmente o comando `nomad job run` diretamente no Nomad Server através de SSH, optou-se por integrar este processo na pipeline GitLab CI/CD.

Esta abordagem elimina a necessidade de acesso manual ao servidor sempre que uma nova versão é disponibilizada, permitindo que o deployment seja executado automaticamente após cada alteração ao código.

| Abordagem                       | Limitação                                      |
| ------------------------------- | ---------------------------------------------- |
| Execução manual no Nomad Server | Necessidade de acesso SSH e intervenção humana |
| Execução através da pipeline    | Processo automático e reproduzível             |

## Benefícios

| Benefício         | Descrição                                      |
| ----------------- | ---------------------------------------------- |
| Automação         | Deploy executado após cada push                |
| Reprodutibilidade | Mesmo processo em todas as versões             |
| Segurança         | Menor necessidade de acesso direto ao servidor |
| Integração        | Ligação direta entre código e deployment       |
| Escalabilidade    | Processo preparado para múltiplos ambientes    |

---

# GitLab CI/CD

Foi implementada uma pipeline de CI/CD utilizando GitLab Runner para automatizar o processo de build, publicação e deployment da aplicação.

## Componentes

| Componente         | Implementação    |
| ------------------ | ---------------- |
| Repositório        | GitLab           |
| Pipeline           | `.gitlab-ci.yml` |
| Executor           | GitLab Runner    |
| Registo de imagens | Docker Hub       |
| Orquestração       | Nomad            |

## Fluxo Completo

```text
Developer Push
       │
       ▼

GitLab Repository
       │
       ▼

GitLab Pipeline
       │
       ├── Build Docker Image
       │
       ├── Push Docker Hub
       │
       └── Nomad Deployment
                │
                ▼

          Nomad Server
                │
                ▼

          Nomad Clients
                │
                ▼

        Application Updated
```

## Automatização

| Ação                    | Resultado                         |
| ----------------------- | --------------------------------- |
| Push para o repositório | Pipeline iniciada automaticamente |
| Build Docker            | Nova imagem gerada                |
| Push Docker Hub         | Imagem publicada                  |
| Deploy Nomad            | Atualização automática            |
| Rolling Update          | Atualização sem downtime          |

## Auto Scaling Group

O ficheiro `asg.tf` é responsável pela gestão dos clientes Nomad que executam a aplicação, permitindo ajustar automaticamente a capacidade do cluster de acordo com a procura.

### Estrutura

| Ficheiro                  | Função                               |
| ------------------------- | ------------------------------------ |
| `asg.tf`                  | Configuração do Auto Scaling Group   |
| `scripts/nomad_client.sh` | Configuração automática dos clientes |
| `scripts/user_data.tpl`   | Bootstrap das instâncias             |

### Funcionalidades

| Funcionalidade      | Descrição                             |
| ------------------- | ------------------------------------- |
| Auto Scaling        | Ajuste automático da capacidade       |
| Self-Healing        | Substituição automática de instâncias |
| Cluster Integration | Registo automático no Nomad           |
| Application Hosting | Execução dos workloads                |

### Fluxo

```text
Nomad Server
       │
       ▼

Auto Scaling Group
       │
 ┌─────┴─────┐
 ▼           ▼

Client 1   Client 2
```

### Automatização

| Ação                  | Resultado               |
| --------------------- | ----------------------- |
| Nova instância criada | Configuração automática |
| Falha de instância    | Reposição automática    |
| Registo no cluster    | Cliente disponível      |
| Deployment            | Aplicação distribuída   |

### Benefícios

| Benefício            | Descrição                          |
| -------------------- | ---------------------------------- |
| Alta Disponibilidade | Recuperação automática de falhas   |
| Escalabilidade       | Ajuste dinâmico da capacidade      |
| Resiliência          | Menor intervenção manual           |
| Integração           | Comunicação automática com o Nomad |

### Nomad Client Bootstrap

O script `nomad_client.sh` é responsável pela preparação automática das instâncias criadas pelo Auto Scaling Group, permitindo que estas se integrem no cluster Nomad sem intervenção manual.

### Estrutura

| Ficheiro                  | Função                                                                   |
| ------------------------- | ------------------------------------------------------------------------ |
| `scripts/nomad_client.sh` | Instalação do Nomad e integração automática de novos clientes no cluster |
| `scripts/user_data.tpl`   | Execução automática do bootstrap durante o arranque                      |

### Funcionalidades

| Funcionalidade      | Descrição                               |
| ------------------- | --------------------------------------- |
| Instalação do Nomad | Instala automaticamente o cliente Nomad |
| Configuração        | Geração da configuração necessária      |
| Cluster Integration | Ligação ao Nomad Server                 |
| Service Startup     | Inicialização automática do serviço     |
| Workload Ready      | Preparação para execução de workloads   |

### Fluxo

```text
Nova Instância
       │
       ▼

 user_data.tpl
       │
       ▼

nomad_client.sh
       │
       ├── Instala Nomad
       ├── Configura Cliente
       ├── Liga ao Cluster
       └── Inicia Serviço
               │
               ▼

      Cliente Disponível
```

### Automatização

| Ação                  | Resultado              |
| --------------------- | ---------------------- |
| Nova instância criada | Bootstrap executado    |
| Instalação do Nomad   | Cliente configurado    |
| Registo no cluster    | Cliente disponível     |
| Deployment            | Workloads distribuídos |

### Justificação

Os clientes Nomad pertencem ao Auto Scaling Group e podem ser criados ou removidos automaticamente pela AWS. Por este motivo, não é viável utilizar uma configuração exclusivamente baseada em Ansible, uma vez que novas instâncias podem surgir a qualquer momento.

A utilização de um processo de bootstrap garante que qualquer novo cliente fica automaticamente preparado para integrar o cluster e executar workloads.

### Benefícios

| Benefício       | Descrição                               |
| --------------- | --------------------------------------- |
| Escalabilidade  | Integração automática de novos clientes |
| Automação       | Sem intervenção manual                  |
| Resiliência     | Compatível com Auto Scaling             |
| Disponibilidade | Clientes prontos a receber workloads    |

## Network Load Balancer

O ficheiro `aws_lb.tf` é responsável pela distribuição do tráfego entre os clientes Nomad que executam a aplicação.

### Estrutura

| Ficheiro    | Função                        |
| ----------- | ----------------------------- |
| `aws_lb.tf` | Configuração do Load Balancer |

### Funcionalidades

| Funcionalidade       | Descrição                     |
| -------------------- | ----------------------------- |
| Traffic Distribution | Distribuição do tráfego       |
| Health Checks        | Monitorização dos clientes    |
| High Availability    | Continuidade do serviço       |
| Integration          | Ligação ao Auto Scaling Group |

### Fluxo

```text
Internet
    │
    ▼

Load Balancer
    │
 ┌──┴──┐
 ▼     ▼

Client1 Client2
```

### Automatização

| Ação                 | Resultado                 |
| -------------------- | ------------------------- |
| Novo cliente criado  | Registo automático        |
| Cliente indisponível | Remoção do balanceamento  |
| Pedido recebido      | Encaminhamento automático |

### Benefícios

| Benefício       | Descrição                          |
| --------------- | ---------------------------------- |
| Disponibilidade | Serviço sempre acessível           |
| Escalabilidade  | Integração com ASG                 |
| Resiliência     | Tolerância a falhas                |
| Transparência   | Distribuição automática do tráfego |


## Outputs

O ficheiro `outputs.tf` é responsável por disponibilizar informação da infraestrutura após a execução do Terraform, permitindo que outros componentes utilizem automaticamente os recursos criados.

### Estrutura

| Ficheiro     | Função                                     |
| ------------ | ------------------------------------------ |
| `outputs.tf` | Exportação de informação da infraestrutura |
| `connect.sh` | Consumo dos outputs para configuração SSH  |

### Funcionalidades

| Funcionalidade          | Descrição                                   |
| ----------------------- | ------------------------------------------- |
| Exportação de Endpoints | Disponibilização dos recursos criados       |
| Integração              | Comunicação entre Terraform e scripts       |
| Automatização           | Eliminação de configuração manual           |
| Reutilização            | Informação acessível por outros componentes |

### Fluxo

```text
Terraform Apply
        │
        ▼

    Outputs
        │
        ▼

  connect.sh
        │
        ▼

 ~/.ssh/config
```

### Automatização

| Ação                      | Resultado                      |
| ------------------------- | ------------------------------ |
| Criação da infraestrutura | Outputs atualizados            |
| Execução do `connect.sh`  | Leitura automática dos outputs |
| Alteração de IPs          | Configuração SSH atualizada    |
| Nova infraestrutura       | Sem configuração manual        |

### Benefícios

| Benefício                 | Descrição                              |
| ------------------------- | -------------------------------------- |
| Menos configuração manual | Elimina a necessidade de procurar IPs  |
| Integração                | Ligação entre Terraform e scripts      |
| Reprodutibilidade         | Mesmo processo em qualquer ambiente    |
| Manutenção                | Atualização automática da configuração |

### Justificação

Em vez de consultar manualmente a consola AWS para obter os endereços dos recursos criados, optou-se por utilizar os outputs do Terraform como fonte única de informação. Esta abordagem simplifica a gestão da infraestrutura e permite automatizar processos como a geração do ficheiro SSH utilizado pelo Bastion Host.


## Dynamic DNS

O script `update-noip.sh` é responsável por manter o domínio No-IP sincronizado com o endereço atualmente disponível do Load Balancer, permitindo o acesso à aplicação através de um domínio estável.

### Estrutura

| Ficheiro                 | Função                                  |
| ------------------------ | --------------------------------------- |
| `scripts/update-noip.sh` | Atualização automática do registo No-IP |

### Funcionalidades

| Funcionalidade  | Descrição                                   |
| --------------- | ------------------------------------------- |
| Resolução DNS   | Obtém os IPs associados ao Load Balancer    |
| Validação       | Testa a disponibilidade dos IPs encontrados |
| Seleção         | Escolhe um endpoint funcional               |
| Atualização DNS | Atualiza automaticamente o registo No-IP    |

### Fluxo

```text
Load Balancer DNS
        │
        ▼

 Resolução dos IPs
        │
        ▼

 Validação dos Endpoints
        │
        ▼

 Seleção do IP Válido
        │
        ▼

 Atualização No-IP
```

### Automatização

| Ação              | Resultado                                |
| ----------------- | ---------------------------------------- |
| Resolução do DNS  | Lista de IPs obtida                      |
| Teste dos IPs     | Identificação de endpoints ativos        |
| Seleção do IP     | Escolha automática de um endpoint válido |
| Atualização No-IP | Domínio atualizado                       |

### Justificação

Os Network Load Balancers podem estar associados a múltiplos endereços IP, que podem variar ao longo do tempo. Por este motivo, não é recomendável configurar manualmente um endereço estático no serviço No-IP.

O script implementado resolve automaticamente o DNS do Load Balancer, valida os IPs disponíveis através de pedidos HTTP e atualiza o registo No-IP utilizando apenas um endpoint funcional.

| Abordagem                         | Limitação                                   |
| --------------------------------- | ------------------------------------------- |
| Configuração manual do IP         | Necessidade de atualização manual           |
| Atualização automática via script | Sincronização contínua com a infraestrutura |

### Benefícios

| Benefício       | Descrição                        |
| --------------- | -------------------------------- |
| Automação       | Atualização automática do DNS    |
| Disponibilidade | Utilização de endpoints válidos  |
| Continuidade    | Domínio sempre operacional       |
| Manutenção      | Menor intervenção administrativa |

