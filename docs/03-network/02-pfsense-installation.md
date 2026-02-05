# Instalação e Configuração do pfSense

> [!ABSTRACT] Objetivo
> Instalar o Sistema Operativo, definir os IPs das interfaces, executar o "Switchover" físico e realizar a configuração inicial via Web.

## 1. Instalação do OS (Console)

1.  No Proxmox, clicar em **Start** na VM `100` e abrir a **Console**.
2.  Aceitar os termos (Enter).
3.  Escolher **Install pfSense** > **Auto (ZFS)** > **Select Disk** > **Yes**.
4.  Aguardar a instalação e selecionar **Reboot**.

## 2. Mapeamento de Interfaces (Primeiro Boot)

O sistema irá perguntar quais as interfaces físicas correspondem à WAN e LAN.

* **Should VLANs be set up now?** `n`
* **Enter the WAN interface name:** `vtnet0`
    * *Nota:* Corresponde à `net0` (vmbr0).
* **Enter the LAN interface name:** `vtnet1`
    * *Nota:* Corresponde à `net1` (vmbr1).
* **Do you want to proceed?** `y`

## 3. Definição de IPs (Menu Principal)

No menu de texto (*Opção 2 - Set interface(s) IP address*):

### 3.1 Configurar WAN (vtnet0)
* **Configure IPv4 via DHCP?** `n`
* **IPv4 Address:** `192.168.1.253`
* **Subnet Bit Count:** `24`
* **IPv4 Upstream Gateway:** `192.168.1.1`
* **Configure IPv6 via DHCP?** `n`
* **IPv6 Address:** (Enter para vazio)
* **Enable DHCP Server on WAN?** `n`
* **Revert to HTTP as the webConfigurator protocol?** `n` (Mantém HTTPS seguro).

### 3.2 Configurar LAN (vtnet1)
* **IPv4 Address:** `10.10.1.1`
* **Subnet Bit Count:** `24`
* **IPv4 Upstream Gateway:** (Enter para vazio - **Importante!**)
* **IPv6 Address:** (Enter para vazio)
* **Enable DHCP Server on LAN?** `y`
* **Start of the IPv4 range:** `10.10.1.100`
* **End of the IPv4 range:** `10.10.1.200`
* **Revert to HTTP as the webConfigurator protocol?** `n` (Mantém HTTPS seguro).

---

## 4. O Switchover (Troca de Cabos)

> [!DANGER] Atenção
> Este passo altera a topologia física da rede.

1.  Manter o cabo da **WAN (`nic0`)** ligado ao Router da Operadora.
2.  Ligar o cabo da **LAN (`nic1`)** do pfSense à **Porta 1** do Switch Pessoal (Uplink).
3.  Ligar o cabo do **PC Pessoal** à **Porta 2** do Switch Pessoal.
4.  No PC Pessoal: Desligar e ligar o cabo de rede (ou desativar/ativar a placa de rede) para renovar o IP.
    * *Sucesso:* O PC deve receber um IP na gama `10.10.1.x` (atribuído pelo pfSense através do Switch).
5.  Testar ligação (Terminal): `ping 10.10.1.1`.

## 5. Configuração Inicial (Web Wizard)

Aceder via browser a `https://10.10.1.1`.
**Credenciais padrão:** User `admin` / Password `pfsense`.

Executar o *Setup Wizard* com os seguintes parâmetros:

| Etapa | Parâmetro | Valor Recomendado | Notas Técnicas |
| :--- | :--- | :--- | :--- |
| **1. Welcome** | Next | - | - |
| **2. General** | Hostname | `pfsense` | - |
| | Domain | `lan` | Ou domínio interno à escolha. |
| | Primary DNS | **`9.9.9.9`** | Quad9 (Segurança/Blocklist). |
| | Secondary DNS | **`1.1.1.1`** | Cloudflare (Performance). |
| | Override DNS | **Uncheck** (Desmarcar) | Evita usar DNS do ISP na WAN. |
| **3. Time** | Timezone | `Europe/Lisbon` | Crítico para logs. |
| **4. WAN** | Type | `Static` | Já configurado na consola. |
| | Block RFC1918 | **Uncheck** (Desmarcar) | **Obrigatório** (WAN é privada: 192.168.x.x). |
| | Block Bogon | **Enable** | Bloqueia redes não alocadas. |
| **5. LAN** | LAN IP Address | `10.10.1.1` | Confirmar valor. |
| | Subnet Mask | `/24` | - |
| **6. Password** | Admin Password | `[PASSWORD_FORTE]` | **Ação Crítica:** Alterar a default. |
| **7. Reload** | Reload | - | Aplica as configurações. |
| **8. Finish** | Finish | - | Redireciona para o Dashboard. |

> [!TIP] Pós-Instalação
> Após o *Finish*, aceitar o "Copyright Notice". O sistema está operacional.

---

## 6. Correção de Performance (VirtIO Offloading)

> [!CRITICAL] Passo Obrigatório para VirtIO
> Como estamos a usar placas de rede virtuais (`vtnet`), o "Hardware Checksum Offloading" causa corrupção de pacotes e lentidão extrema. Tem de ser desativado para o CPU processar os pacotes.

1.  No pfSense, navegar para: **System** > **Advanced** > **Networking**.
2.  Secção **Network Interfaces**:
    * **Hardware Checksum Offloading:** ✅ Marcar **"Disable hardware checksum offload"**.
    * **Hardware TCP Segmentation Offloading:** ✅ Marcar **"Disable hardware TCP segmentation offload"**.
    * **Hardware Large Receive Offloading:** ✅ Marcar **"Disable hardware large receive offload"**.
3.  Clicar em **Save** (fundo da página).
4.  **Reiniciar o pfSense** (Diagnostics > Reboot) para aplicar.

---

## 7. Limpeza e Definição de Gateway (Proxmox Host)

Remover o acesso antigo da WAN e definir o pfSense como o Gateway oficial do Proxmox.

1.  Aceder ao Proxmox via nova rede LAN: `https://10.10.1.254:8006`.
2.  Navegar para **System > Network**.
3.  **Limpar a WAN (`vmbr0`):**
    * Editar a interface `vmbr0`.
    * **Apagar** os campos IPv4/CIDR e Gateway (Deixar vazios).
    * Clicar em **OK**.
4.  **Configurar a LAN (`vmbr1`):**
    * Editar a interface `vmbr1`.
    * Confirmar IPv4/CIDR: `10.10.1.254/24`.
    * **Gateway:** Preencher com `10.10.1.1` (IP do pfSense).
    * Clicar em **OK**.
5.  Clicar em **Apply Configuration** (No topo da janela).

> [!SUCCESS] Estado Final da Infraestrutura
> * **`vmbr0` (WAN):** Passagem direta para o pfSense (Sem IP no Host).
> * **`vmbr1` (LAN):** Rede de Gestão com Internet (`10.10.1.254` -> GW `10.10.1.1`).
> * **pfSense:** Router e Gateway central (`10.10.1.1`).