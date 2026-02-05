# Hardware Inventory & Network Map

> **Data de Atualização:** 2026-02-04
> **Estado:** Operacional

Documentação técnica do inventário físico e configurações de rede (Switching).

## 1. Compute Node (Hypervisor)

O servidor central que aloja o Proxmox VE e o pfSense.

| Componente | Especificação | Detalhes / Notas |
| :--- | :--- | :--- |
| **Equipamento** | Mini PC (AMD Ryzen) | Formato NUC/SFF |
| **CPU** | AMD Ryzen 5 4500U | 6 Cores / 6 Threads @ 2.3GHz |
| **RAM** | 24GB DDR4 3200MHz | *Expansível até 64GB* |
| **Disco Sistema** | 512GB NVMe M.2 | Proxmox OS + VMs |
| **NIC 1** | Realtek 1GbE | **WAN** (Passthrough pfSense) |
| **NIC 2** | Realtek 1GbE | **LAN** (VLAN Trunk) |

## 2. Network Infrastructure (Switching)

### Matriz de VLANs (TP-Link TL-SG108E)
Configuração 802.1Q VLAN. A Porta 1 serve como **Trunk** (Uplink) para o Router/Firewall.

| VLAN ID | Descrição | Port 1 (Uplink) | Ports 2-5 (Trusted) | Ports 6-7 (IoT) | Port 8 (Mgmt) |
| :---: | :--- | :---: | :---: | :---: | :---: |
| **1** | *Default* | *(Ignorar)* | *(Ignorar)* | *(Ignorar)* | *(Ignorar)* |
| **20** | **Trusted LAN** | **Tagged** | **Untagged** | Not Member | Not Member |
| **30** | **IoT / Guest** | **Tagged** | Not Member | **Untagged** | Not Member |
| **40** | **Labs** | **Tagged** | Not Member | Not Member | Not Member |
| **50** | **NoT / Cams** | **Tagged** | Not Member | Not Member | Not Member |

### Configuração de PVID (Port VLAN ID)
Para garantir que o tráfego entra na VLAN correta:

* **Port 1:** PVID 1 (Trunk)
* **Ports 2-5:** PVID 20
* **Ports 6-7:** PVID 30
* **Port 8:** PVID 1 (ou VLAN de Gestão dedicada)

---
*Nota: A VLAN 40 e 50 estão criadas no Uplink (Port 1) mas ainda não têm portas físicas atribuídas (podem ser usadas por VMs ou Wi-Fi com VLAN Tagging).*