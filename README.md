# 🛡️ DevSecOps Home Lab

![Status](https://img.shields.io/badge/Status-Em_Andamento-yellow?style=for-the-badge)
![License](https://img.shields.io/badge/License-MIT-grey?style=for-the-badge)

![Proxmox](https://img.shields.io/badge/Proxmox-E57000?style=for-the-badge&logo=proxmox&logoColor=white)
![Debian](https://img.shields.io/badge/Debian-A81D33?style=for-the-badge&logo=debian&logoColor=white)
![Linux](https://img.shields.io/badge/Linux-FCC624?style=for-the-badge&logo=linux&logoColor=black)

![pfSense](https://img.shields.io/badge/pfSense-2C3E50?style=for-the-badge&logo=pfsense&logoColor=white)
![Cloudflare](https://img.shields.io/badge/Cloudflare-F38020?style=for-the-badge&logo=cloudflare&logoColor=white)

![Docker](https://img.shields.io/badge/Docker-2496ED?style=for-the-badge&logo=docker&logoColor=white)
![Vaultwarden](https://img.shields.io/badge/Vaultwarden-175DDC?style=for-the-badge&logo=bitwarden&logoColor=white)
![Nextcloud](https://img.shields.io/badge/Nextcloud-0082C9?style=for-the-badge&logo=nextcloud&logoColor=white)

![Bash](https://img.shields.io/badge/Bash-4EAA25?style=for-the-badge&logo=gnu-bash&logoColor=white)
![Git](https://img.shields.io/badge/Git-F05032?style=for-the-badge&logo=git&logoColor=white)
![GitHub](https://img.shields.io/badge/GitHub-181717?style=for-the-badge&logo=github&logoColor=white)


## 📖 Sobre o Projeto

Este repositório documenta a construção e gestão da minha infraestrutura de laboratório pessoal (**Home Lab**).

O objetivo principal é simular um ambiente empresarial real (**Enterprise-Grade**), saindo da configuração doméstica padrão para uma arquitetura baseada em **Segurança Ofensiva/Defensiva**, **Segmentação de Rede** e **Automação**.

Aqui centralizo toda a documentação desde instalações, configurações de rede, scripts de manutenção e código de infraestrutura (IaC).

## 🗺️ Arquitetura de Rede

Abaixo encontra-se o diagrama da topologia física e lógica implementada, destacando a separação entre o Hardware, a Camada de Virtualização e a Segmentação via VLANs.

![Topologia de Rede](images/network-topology.png)

---

## 🏗️ Stack Tecnológica

A infraestrutura é desenhada para ser resiliente e escalável, utilizando tecnologias padrão da indústria:

* **Virtualização:** Proxmox VE.
* **Segurança de Rede:** pfSense (Firewall Virtualizada, VLANs).
* **Hardware de Rede:** Switch L2 Gerível (Implementação de 802.1Q).
* **Serviços:** Docker & Docker Compose (Self-hosted apps).
* **Automação:** Bash Scripting (Bootstrap), Ansible e Terraform.

---

## 📂 Como está organizado?

A estrutura de pastas segue uma lógica de separação de responsabilidades:

| Pasta | O que contém? |
| :--- | :--- |
| **`docs/`** | **Manuais e Arquitetura.** Tudo o que é para leitura humana: diagramas, guias de instalação passo-a-passo e notas de hardware. |
| **`scripts/`** | **Automação.** Scripts prontos a correr (Bash/Python) para configurar servidores ou realizar manutenções rápidas. |
| **`network/`** | **Rede.** Backups sanitizados do pfSense e tabelas de regras de firewall. |
| **`infrastructure/`** | **Provisionamento (IaC).** Código (Terraform/Ansible) que cria as máquinas virtuais automaticamente e configura os serviços. |
| **`services/`** | **Aplicações.** Configurações dos serviços que correm no laboratório (ex: Vaultwarden, Monitorização). |

---

## 🔐 Princípios de Design

Este laboratório não é apenas "instalar e usar". Segue princípios estritos de engenharia:

1.  **Zero Trust Networking:** Todo o tráfego entre redes (VLANs) é bloqueado por defeito. Apenas o estritamente necessário é permitido.
2.  **Infrastructure as Code:** Evitar configurações manuais. O objetivo é definir a infraestrutura em código para ser reprodutível.
3.  **Segurança em Camadas:** Hardening aplicado desde a BIOS, passando pelo Sistema Operativo, até à Camada de Aplicação.

---
*Mantido por **Ricardo Santos**.*