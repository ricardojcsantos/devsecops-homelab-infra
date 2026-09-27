# Templates: Estruturas de Inventário e Variáveis Ansible

> [!NOTE]
> **Objetivo:** Este documento serve como base de conhecimento e consulta (*Cheat Sheet*). Contém as estruturas de mapeamento de servidores e a lista de variáveis nativas suportadas pelo Ansible para ambientes Linux (SSH) e Windows (WinRM).

---

## 1. Estruturas de Inventário (Ficheiros INI)

O Ansible permite mapear a infraestrutura de três formas distintas, dependendo da escala do projeto. 

> [!IMPORTANT]
> **Boas Práticas:** Embora o formato INI permita declarar variáveis diretamente com o sufixo `:vars` (como demonstrado abaixo para fins didáticos), a norma *Enterprise* dita que essas variáveis devem ser movidas para ficheiros YAML dentro da diretoria `group_vars/`.

### 1.1. Máquina a Máquina (Variáveis In-line)
* **Caso de Uso:** Testes rápidos locais ou scripts isolados para 1 ou 2 máquinas.
* **Características:** Rápido de escrever, mas difícil de ler e impossível de escalar.

```ini
srv-linux-lab ansible_host=10.10.40.10 ansible_user=ansible ansible_connection=ssh ansible_python_interpreter=/usr/bin/python3

srv-windows-lab ansible_host=10.10.50.10 ansible_user=ansible ansible_connection=winrm ansible_port=5986
```

### 1.2. Agrupamento Padrão
* **Caso de Uso:** Padrão base da indústria para a maioria das infraestruturas médias.
* **Características:** Permite agrupar servidores com funções semelhantes. As variáveis são herdadas por todas as máquinas que pertencem ao grupo.

```ini
[lab_linux]
srv-linux-lab ansible_host=10.10.50.20

[lab_windows]
srv-windows-lab ansible_host=10.10.50.10

[lab_linux:vars]
ansible_user=ansible
ansible_connection=ssh

[lab_windows:vars]
ansible_user=ansible
ansible_connection=winrm
```

### 1.3. Grupos de Grupos (Hierarquia com `:children`)
* **Caso de Uso:** Ambientes *Enterprise* com centenas de VMs espalhadas por Datacenters, Zonas ou tipos de Serviço.
* **Características:** Máxima flexibilidade. Permite executar comandos cruzados (ex: atualizar todo um Datacenter, independentemente do Sistema Operativo, visando o grupo `datacenter_proxmox`).

```ini
[linux_servers]
srv-linux-lab ansible_host=10.10.50.20

[windows_servers]
srv-windows-lab ansible_host=10.10.50.10

# O sufixo :children indica que este grupo contém outros grupos e não máquinas diretas
[datacenter_proxmox:children]
linux_servers
windows_servers

[datacenter_proxmox:vars]
ansible_user=ansible
```

---

## 2. Dicionário de Variáveis de Conexão (Formato YAML)

Lista das variáveis mais comuns e os seus valores esperados em contexto empresarial. Em infraestruturas organizadas, estes blocos são colocados nos ficheiros dentro de `inventory/group_vars/nome_do_grupo.yml`. 

*(Qualquer variável comentada com `#` é ignorada pelo motor do Ansible).*

### 2.1. Ambiente Linux (SSH)

```yaml
# ==========================================
# Variáveis de Grupo: LINUX
# ==========================================

# --- Conexão Base ---
ansible_connection: ssh                  # Força o uso de SSH (Omissão = ssh/smart)
ansible_port: 22                         # Define a porta SSH (Útil se alterada para segurança)
ansible_user: ansible                    # Utilizador remoto para o login principal

# --- Autenticação ---
ansible_ssh_private_key_file: ~/.ssh/id_ed25519  # Caminho para a chave privada

# --- Elevação de Privilégios (Sudo) ---
ansible_become: yes                      # Define se deve escalar privilégios nas tarefas
ansible_become_method: sudo              # Método de elevação (sudo, su)
ansible_become_user: root                # Utilizador final da elevação
# ansible_become_pass: "TUA_SENHA"       # Guardar apenas no Ansible Vault.

# --- Parâmetros Avançados ---
# ansible_ssh_common_args: '-o StrictHostKeyChecking=no'  # Ignora aviso de chave em laboratórios dinâmicos
ansible_python_interpreter: /usr/bin/python3              # Força o caminho do binário Python
```

### 2.2. Ambiente Windows (WinRM)

```yaml
# ==========================================
# Variáveis de Grupo: WINDOWS
# ==========================================

# --- Conexão Base ---
ansible_connection: winrm                # Obrigatório para máquinas Windows
ansible_port: 5986                       # 5986 (HTTPS Seguro) ou 5985 (HTTP Inseguro)
ansible_user: ansible                    # Utilizador local ou de domínio (ex: CORP\ansible)
# ansible_password: "TUA_SENHA"          # Guardar apenas no Ansible Vault.

# --- Autenticação e Criptografia WinRM ---
ansible_winrm_transport: basic           # Tipos suportados: basic, ntlm, kerberos, credssp, certificate
ansible_winrm_server_cert_validation: ignore  # "ignore" (Lab) ou "validate" (Enterprise com PKI)
ansible_winrm_scheme: https              # Força protocolo HTTPS

# --- Parâmetros Avançados (Timeouts) ---
# ansible_winrm_operation_timeout_sec: 60    # Tempo limite da operação (útil para updates pesados)
# ansible_winrm_read_timeout_sec: 70         # Timeout de leitura (deve ser superior ao operation_timeout)
```