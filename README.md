<div align="center">

#  DevSecOps Home Lab
 
![Status](https://img.shields.io/badge/Status-Em_Andamento-yellow?style=for-the-badge)
![License](https://img.shields.io/badge/License-MIT-grey?style=for-the-badge)
 
![Proxmox](https://img.shields.io/badge/Proxmox-E57000?style=for-the-badge&logo=proxmox&logoColor=white)
![pfSense](https://img.shields.io/badge/pfSense-2C3E50?style=for-the-badge&logo=pfsense&logoColor=white)
![Docker](https://img.shields.io/badge/Docker-2496ED?style=for-the-badge&logo=docker&logoColor=white)
![GitHub Actions](https://img.shields.io/badge/GitHub_Actions-2088FF?style=for-the-badge&logo=githubactions&logoColor=white)
![Cloudflare](https://img.shields.io/badge/Cloudflare-F38020?style=for-the-badge&logo=cloudflare&logoColor=white)
![A aprender](https://img.shields.io/badge/A_aprender-Ansible_%26_Terraform-lightgrey?style=for-the-badge)
 
</div>

## Sobre o Projeto
 
Este repositório documenta a construção e gestão da minha infraestrutura de laboratório pessoal (**Home Lab**), montada num único Mini PC com Proxmox VE.
 
O objetivo é simular um ambiente empresarial real: segmentação de rede por VLANs, firewall dedicado, backup automatizado, e deployment de serviços via Docker com um pipeline de CI/CD próprio em GitHub Actions — tudo documentado passo-a-passo à medida que construo.
 
## Arquitetura de Rede
 
![Topologia de Rede](images/network-topology.png)
 
Router da operadora → Mini PC (Proxmox VE, 2 portas de rede) → VM pfSense a gerir o routing e o firewall → Switch L2 gerível → 4 VLANs segmentadas (Trusted, IoT/Media, Servers, Lab).
 
## Stack Tecnológica
 
* **Virtualização:** Proxmox VE
* **Rede & Segurança:** pfSense (firewall virtualizado, VLANs, 802.1Q)
* **Acesso Remoto:** Cloudflare Tunnel + Cloudflare WARP
* **Backup:** Proxmox Backup Server (datastore ZFS)
* **Serviços:** Docker & Docker Compose — Nginx Proxy Manager, Vaultwarden, Immich, Nextcloud
* **CI/CD:** GitHub Actions — deploy automático dos serviços a partir deste repositório
* **A aprender (roadmap):** Ansible, Terraform

## Como está organizado
 
| Pasta | O que contém? |
| :--- | :--- |
| **`docs/`** | Documentação passo-a-passo: hardware, instalação e hardening do Proxmox, rede/pfSense/VPNs, pipeline Docker/GitOps, estratégia de backups |
| **`images/`** | Diagramas de arquitetura |
| **`scripts/`** | Scripts de automação (Bash) — ex: hardening do Proxmox |
| **`templates/`** | Templates de deployment reais: workflow de CI/CD (`.github/workflows/deploy.yml`) e docker-compose de cada serviço (`apps/immich`, `apps/nextcloud`, `apps/npm`, `apps/vaultwarden`) |
 
## Princípios de Design
 
1. **Zero Trust Networking:** tráfego entre VLANs bloqueado por defeito, só o estritamente necessário é permitido.
2. **Infrastructure as Code (em progresso):** os serviços já são definidos e implantados via Docker Compose + CI/CD, não a cliques manuais. Ansible/Terraform são o próximo passo para levar isto ao nível da própria VM/rede.
3. **Segurança em Camadas:** hardening desde o sistema operativo (scripts em `scripts/`) até à camada de rede (pfSense, VLANs).

## Roadmap
 
- Automação de configuração com Ansible
- Provisionamento declarativo com Terraform
- Expandir monitorização (métricas + alertas)
---
*Mantido por **Ricardo Santos**.*
