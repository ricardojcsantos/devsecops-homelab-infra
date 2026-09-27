# Aprovisionamento: Windows Server (Lab)

> [!NOTE]
> **Objetivo:** Criar uma máquina virtual Windows Server minimalista para testar a automação do Ansible via protocolo WinRM. Por ser uma máquina de testes com vetores de risco (ex: SMBv1 e Print Spooler abertos por defeito), será estritamente segregada na VLAN isolada de Laboratório.

---

## 1. Especificações de Hardware (Proxmox)

O Windows requer mais recursos base que o Linux (ausência de versão puramente *headless*). Esta é a configuração mínima viável para que o SO arranque, instale atualizações e responda à automação sem estrangular o nó hospedeiro (Mini PC).

| Componente          | Configuração Sugerida                 | Motivação Técnica                                                                                            |
| :------------------ | :------------------------------------ | :----------------------------------------------------------------------------------------------------------- |
| **Nome / ID / Tag** | `srv-windows-lab` / `500` / `lab`     | Separação lógica de IDs no Proxmox: `10x` (Core), `20x` (Produção), `50x` (Lab).                             |
| **VLAN (Rede)**     | `LAB_TEST` (VLAN 50)                  | Isolamento total. O pfSense gere esta rede impedindo que qualquer *malware* salte para a Produção.           |
| **IP Sugerido**     | `10.10.50.10`                         | IP estático definido na interface do Windows, essencial para garantir conetividade constante do Ansible.     |
| **OS**              | Windows Server 2022 (ou 2025) Eval    | Versão de avaliação oficial da Microsoft (180 dias gratuitos), ideal para ambientes de laboratório.          |
| **Processador**     | 2 vCores (`Type: Host`)               | Mínimo exigido para o sistema operativo não bloquear durante a execução de tarefas pesadas (*Windows Update*).|
| **Memória (RAM)**   | 4096 MB (4 GB)                        | Desmarcar o *Ballooning*. O Windows gere mal a variação dinâmica de RAM induzida pelo hipervisor.            |
| **Disco Principal** | 40 GB (VirtIO Block)                  | Espaço mínimo para a instalação do SO e ficheiros de paginação. (Ativar *Discard* e *SSD Emulation*).        |

---

## 2. Preparação Crítica (Drivers VirtIO)

O Windows não reconhece nativamente os discos de alta performance (VirtIO Block) nem as placas de rede virtuais paravirtualizadas do Proxmox.

> [!WARNING]
> **Antes de ligar a VM:** É obrigatório adicionar uma drive ótica extra (CD/DVD) na interface de hardware do Proxmox.

1. **ISO dos Drivers:** Montar nessa drive extra a imagem oficial do *VirtIO Drivers for Windows* (ficheiro `virtio-win.iso`).
2. **Instalação do SO:** Durante o setup do Windows, quando o instalador reportar que não encontra discos, clica em **Carregar Controlador** (*Load Driver*).
3. **Seleção do Driver:** Navega até ao CD do VirtIO e seleciona a pasta `amd64\w2k22` (ou a versão correspondente ao SO) dentro de `viostor` (para o disco) e `NetKVM` (para a placa de rede).
4. **Pós-Instalação:** Já dentro do Windows, abre novamente o CD e instala o **QEMU Guest Agent** para que o Proxmox consiga ler o IP e fazer *shutdowns* limpos.

---

## 3. Preparação para o Ansible (Padrão Enterprise)

Em ambiente empresarial, o Ansible comunica com máquinas Windows exclusivamente através do protocolo **WinRM** (Windows Remote Management) sobre HTTPS/HTTP, em vez do tradicional SSH.

Após a configuração de rede básica (definir IP fixo) do Windows, executa os seguintes passos:

### A. Criação da Conta de Automação
Tal como no Linux, é imperativo criar um utilizador local dedicado à orquestração para evitar o uso da conta de Administrador principal.

* **Username:** `ansible`
* **Password:** Define uma senha forte (esta password será guardada de forma encriptada no *Ansible Vault* e mapeada no `group_vars/lab_windows.yml`).
* **Permissões:** Adiciona o utilizador `ansible` ao grupo local de **Administradores**.

### B. Ativação do WinRM via PowerShell
O Ansible fornece um *script* oficial que prepara o ambiente Windows: ele configura a Firewall para permitir tráfego WinRM, gera um certificado auto-assinado e arranca o serviço remoto.

Abre o **PowerShell como Administrador** e executa o seguinte bloco de código:

```powershell
# Fazer o download do script oficial de preparação do Ansible
$url = "https://raw.githubusercontent.com/ansible/ansible-documentation/devel/examples/scripts/ConfigureRemotingForAnsible.ps1"
$file = "$env:temp\ConfigureRemotingForAnsible.ps1"

(New-Object -TypeName System.Net.WebClient).DownloadFile($url,$file)

# Executar o script contornando as políticas de restrição locais
powershell.exe -ExecutionPolicy ByPass -File $file
```

> [!TIP]
> **Validação:** Se o *script* terminar com a mensagem indicando que o WinRM está configurado e a ouvir nas portas 5985 (HTTP) e 5986 (HTTPS), o servidor Windows está pronto para receber comandos do teu Ansible Controller.