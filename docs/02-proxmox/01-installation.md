# Instalação do Proxmox VE (Bare Metal)

> [!NOTE]
> **Ficha Técnica**
> * **Versão:** Proxmox VE 9.1
> * **Hardware Alvo:** Mini PC Ryzen 4500U
> * **Tipo:** Bare Metal Hypervisor

O Proxmox VE é a plataforma de virtualização open-source escolhida para este Home Lab. Baseada em Debian, permite a gestão unificada de Máquinas Virtuais (KVM) e Contentores (LXC).

---

## 1. Pré-requisitos

* **Hardware:** Pen USB (Min. 4GB) e Target Host (Mini PC).
* **Software:** [BalenaEtcher](https://www.balena.io/etcher/) ou [Ventoy](https://www.ventoy.net/).
* **ISO:** Imagem oficial do Proxmox VE.

## 2. Preparação da Pen de Instalação

1.  **Download:** Obter a ISO em [Proxmox Downloads](https://www.proxmox.com/en/downloads).
2.  **Flash:**
    * Inserir a Pen USB.
    * Abrir o **BalenaEtcher**.
    * Selecionar a ISO e o Target Drive correto.
    * Executar o *Flash*.

---

## 3. Configuração de BIOS/UEFI (Hardening)

Antes da instalação, o hardware deve ser preparado para virtualização.

**Aceder à BIOS:** Pressionar `DEL`, `F2` ou `ESC` durante o boot.

### Configurações Críticas

| Categoria          | Definição         | Motivo                                      |
| :----------------- | :---------------- | :------------------------------------------ |
| **Virtualization** | **Enabled**       | Necessário para KVM e Passthrough.          |
| **Secure Boot**    | **Disabled**      | Evita bloqueios de drivers do kernel Linux. |
| **Boot Order**     | **1º USB Device** | Para arrancar o instalador.                 |
| **Power Loss**     | **Always On**     | Recuperação automática após falha de luz.   |

> [!TIP]
> Não esquecer de guardar as alterações com `F10` (Save & Exit).

---

## 4. Processo de Instalação

Arrancar pela Pen USB e selecionar **"Install Proxmox VE (Graphical)"**.

### Passos do Assistente:

1.  **End User License Agreement (EULA)**
    * Clicar em **"I Agree"**.

2.  **Target Harddisk (Disco de Destino)**
    * Selecionar o disco NVMe/SSD na lista.

> [!WARNING]
> **Atenção Crítica**
> Confirmar que é o disco correto. Todos os dados serão apagados irreversivelmente ao prosseguir.

3.  **Location and Time Zone**
    * **Country:** `Portugal`
    * **Time Zone:** `Europe/Lisbon`
    * **Keyboard:** `Portuguese`

4.  **Administration Password**
    * **Password:** Definir password forte para `root`.
    * **Email:** Inserir email real para alertas.

5.  **Network Configuration (IP Estático)**
    * **Interface:** Selecionar a porta ligada ao Router (`ETH0`).
    * **Hostname:** `pve-node.lan`
    * **IP Address:** `192.168.1.200/24`
    * **Gateway:** `192.168.1.1`
    * **DNS:** `1.1.1.1`

---

## 5. Conclusão

Após a instalação, o sistema irá reiniciar. Acede à interface web noutro computador.

> [!TIP]
> **URL de Acesso**
>
> `https://192.168.1.200:8006`