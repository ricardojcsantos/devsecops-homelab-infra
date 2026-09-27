# Aprovisionamento do Ansible Controller

> [!NOTE]
> **Objetivo:** Preparar a Máquina Virtual dedicada à orquestração (Ansible). Esta máquina não irá correr nenhum serviço exposto. Atuará estritamente como o "cérebro" central que se liga às outras máquinas via SSH ou WinRM para aplicar configurações de forma automatizada.

---

## 1. Especificações de Hardware (VM)

Como o Ansible é *agentless* (não precisa de agentes instalados nas outras máquinas) e corre localmente, os seus requisitos de hardware são baixos. O planeamento respeita a topologia atual da infraestrutura base.

| Componente          | Configuração Recomendada                  | Motivação Técnica                                                                                            |
| :------------------ | :---------------------------------------- | :----------------------------------------------------------------------------------------------------------- |
| **Nome / ID / Tag** | `srv-ansible-core` / `103` / `infra-core` | Segue a lógica da infraestrutura principal (pfSense, Cloudflare, PBS).                                       |
| **VLAN (Rede)**     | `SERVER_PROD` (VLAN 40)                   | Mantém o Controller na mesma rede da VM de Produção (Docker), simplificando o routing e regras de firewall.  |
| **OS**              | Ubuntu Server 26.04 LTS                   | Instalação mínima, sem ambiente gráfico (Headless).                                                          |
| **Processador**     | 2 vCores (`Type: Host`)                   | Suficiente para orquestração paralela de múltiplas máquinas (*forks*).                                       |
| **Memória (RAM)**   | 2048 MB (2 GB)                            | Desmarcar o *Ballooning* para garantir estabilidade de execução durante a compilação de módulos.             |
| **Disco Principal** | 20 GB (VirtIO Block)                      | Espaço suficiente para SO, cache do *runner* GitHub e *scripts* locais (Ativar *SSD Emulation* e *Discard*). |
| **QEMU Agent**      | Ativado                                   | Essencial para a monitorização de IP via interface do Proxmox e paragens seguras (ACPI).                     |

---

## 2. Preparação do Sistema Operativo

Após instalar o Ubuntu e definires um IP estático (ex: `10.10.40.20`), acede à VM via SSH. Vamos atualizar o sistema e garantir as ferramentas base de administração.

```bash
# 1. Atualizar a lista de repositórios e os pacotes instalados
sudo apt update && sudo apt upgrade -y

# 2. Instalar ferramentas de comunicação, controlo de versões e o agente do Proxmox
sudo apt install -y curl wget git htop net-tools software-properties-common qemu-guest-agent

# 3. Ligar o agente do Proxmox e garantir que arranca automaticamente com o sistema
sudo systemctl enable --now qemu-guest-agent
```

---

## 3. Instalação do Motor Ansible

```bash
# 1. Instalar o pacote base do Ansible através do repositório oficial do Ubuntu
sudo apt install -y ansible

# 2. Validar a integridade da instalação
ansible --version
```

> [!TIP]
> **Validação:** Se o comando `ansible --version` devolver o caminho do executável, ficheiros de configuração e a versão atual, a instalação do motor foi concluída com sucesso.

---

## 4. Criação da Conta de Serviço (Padrão Enterprise)

Em ambientes corporativos e de alta segurança, a automação nunca é executada usando a conta `root` ou contas pessoais de administradores. É obrigatório criar uma Conta de Serviço (*Service Account*) dedicada. Isto garante separação de privilégios e rastreabilidade total nos logs (`auth.log`) dos servidores geridos.

```bash
# 1. Criar o utilizador de serviço (a flag --gecos "" ignora os prompts de Nome/Telefone)
sudo adduser --gecos "" ansible

# 2. Adicionar o utilizador ao grupo sudo (necessário para instalar o GitHub Runner futuramente)
sudo usermod -aG sudo ansible

# 3. Transição de identidade: Passar a usar o terminal como a conta de serviço 'ansible'
su - ansible
```

> [!IMPORTANT]
> **Ação Necessária:** A partir deste ponto, todos os comandos no laboratório relacionados com automação devem ser executados com o utilizador `ansible`. O teu terminal de controlo passou de `administrator@srv-ansible-core` para `ansible@srv-ansible-core`.

---

## 5. Estruturação do Diretório de Trabalho

Para manter a consistência com a orquestração e boas práticas de GitOps, criamos a árvore de diretórios onde o código Ansible (YAML) vai viver localmente. Aninhar a diretoria `group_vars` dentro do `inventory` é o padrão de arquitetura mais limpo para gerir variáveis por ambiente.

```bash
# 1. Criar a diretoria principal na home do utilizador ansible
mkdir -p ~/ansible

# 2. Criar as subpastas estruturais, aninhando as variáveis de grupo no inventário
mkdir -p ~/ansible/{playbooks,inventory/group_vars,roles}

# 3. Navegar para a nova diretoria raiz do projeto
cd ~/ansible
```

### O que faz cada pasta?

| Diretório               | Função na Automação                                                                                           |
| :---------------------- | :------------------------------------------------------------------------------------------------------------ |
| `playbooks/`            | Onde ficam os ficheiros YAML de alto nível que ditam as ações e orquestram a infraestrutura.                  |
| `inventory/`            | Onde listamos estritamente os IPs e definimos os agrupamentos lógicos das VMs (`inventory.ini`).              |
| `inventory/group_vars/` | Onde guardamos credenciais de ligação (via Vault) e variáveis específicas de cada grupo (ex: utilizador SSH). |
| `roles/`                | Onde armazenamos os módulos autónomos e partilháveis (ex: módulo isolado para instalar Docker ou hardening).  |

> [!WARNING]
> **Segurança Local:** Ao contrário do padrão de *hardening*, não apliques regras estritas de bloqueio na UFW (Firewall nativa do Ubuntu) nesta máquina de orquestração até termos o *pipeline* CI/CD validado. A VLAN 40 onde o Controller reside já se encontra devidamente protegida e segmentada pelo pfSense contra acessos externos.