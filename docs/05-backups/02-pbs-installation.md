# Instalação do Proxmox Backup Server (VM Dedicada)

> [!NOTE]
> **Ficha Técnica**
> * **Sistema:** Proxmox Backup Server (PBS)
> * **Hardware Alvo:** Proxmox VE (Guest VM)
> * **Tipo:** Servidor de Deduplicação e Disaster Recovery

> [!IMPORTANT]
> **Arquitetura: Enterprise vs. Home Lab**
> 
> Em ambiente corporativo padrão, o PBS deve ser **obrigatoriamente instalado num servidor físico dedicado e isolado**. Neste projeto, devido à existência de apenas um nó físico (Mini PC), o PBS é instanciado como uma Máquina Virtual (VM) com injeção direta de hardware para emular o isolamento estrito dos dados.

### 1. Pré-requisitos

* **Hardware:** Disco físico externo.
* **Software:** Imagem oficial do PBS no armazenamento do Proxmox VE.

### 2. Aprovisionamento da Máquina Virtual

A VM exige recursos adequados para indexação em memória e aceleração criptográfica nativa de hardware.

| Categoria         | Parâmetro              | Definição SysAdmin                             |
| :---------------- | :--------------------- | :--------------------------------------------- |
| **Geral**         | Nome / ID              | `srv-backups` / `102` (Pool de Infraestrutura) |
| **OS**            | Tipo / Qemu Agent      | Linux (2.6+ Kernel) / Ativado                  |
| **Armazenamento** | Tamanho / Controladora | `32 GB` / VirtIO SCSI single                   |
| **CPU**           | Cores / Tipo           | `2` Cores / `host` (Aceleração AES)            |
| **Memória**       | RAM / Ballooning       | `4096 MB` / Ativado                            |
| **Rede**          | Ponte                  | `vmbr1` (Rede de Gestão)                       |

### 3. Isolamento Físico de Hardware (Passthrough)

> [!WARNING]
> **Atenção Crítica:** O disco físico de backups nunca deve ser formatado ou montado no Proxmox Host. A sua exposição anula a proteção contra *Ransomware* em caso de comprometimento do hipervisor.

1. Ligar o disco externo ao servidor físico.
2. Na VM `srv-backups`, aceder a **Hardware > Add > USB Device**.
3. Selecionar **Use USB Vendor/Device ID** e escolher o dispositivo diretamente no *kernel* da VM (ativar suporte USB3).

### 4. Processo de Instalação (OS)

Arrancar a VM e selecionar "Install Proxmox Backup Server (Graphical)".

* **Target Harddisk:** Selecionar o disco virtual de `32 GB` (Ignorar o disco injetado).
* **Location and Time Zone:**
  * Country: Portugal
  * Time Zone: Europe/Lisbon
* **Credenciais:** Definir *password* de `root`.
* **Network Configuration (IP Estático na Management VLAN):**
  * **Hostname:** `srv-backups.lan`
  * **IP Address:** `10.10.1.253/24` 
  * **Gateway:** `10.10.1.1`
  * **DNS:** `10.10.1.1`

> [!TIP]
> **URL de Acesso ao Cofre (Dashboard)**
> `https://10.10.1.253:8007`