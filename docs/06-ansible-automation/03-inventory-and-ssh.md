# Gestão de Inventário, Acessos SSH e WinRM

> [!NOTE]
> **Objetivo:** Estabelecer a comunicação segura entre o *Ansible Controller* e as máquinas alvo. Vamos implementar a autenticação por chaves criptográficas (SSH) para o acesso ao Linux, e centralizar as configurações de ligação (incluindo o acesso ao WinRM do Windows previamente preparado) de forma segura num cofre encriptado (Ansible Vault).

---

## 1. Geração da Chave SSH (Controlador)

Vamos gerar a "identidade" única para o utilizador `ansible` na máquina controladora (`srv-ansible-core`).

> [!WARNING]
> **Regra Padrão:** Certifica-te de que estás a usar o terminal da máquina orquestradora (`srv-ansible-core`) com o utilizador de serviço (`ansible@srv-ansible-core:~/ansible$`).

Executa o seguinte comando para gerar uma chave moderna (ED25519) sem *passphrase* (exigência para futura automação via CI/CD):

```bash
ssh-keygen -t ed25519 -C "ansible-service-account" -f ~/.ssh/id_ed25519 -N ""
```

*Isto vai criar dois ficheiros na pasta `~/.ssh/`: a tua chave privada (`id_ed25519` - nunca partilhar) e a tua chave pública (`id_ed25519.pub` - a que vamos distribuir).*

---

## 2. Preparação dos Servidores Alvo

Para manter o padrão de excelência empresarial e a separação de privilégios, os servidores alvo têm de ter uma conta de serviço idêntica à do controlador para receber e executar os comandos.

### 2.1. Ambiente Linux (VM Lab)

**Na tua máquina alvo Linux (`srv-linux-lab`), acede com o teu utilizador normal e executa:**

```bash
# 1. Criar o utilizador de serviço
sudo adduser --gecos "" ansible

# 2. Dar permissões de administrador (sudo) para o Ansible poder alterar configurações
sudo usermod -aG sudo ansible
```
*(Define uma password forte quando for pedida. Vamos trancá-la no cofre no Passo 5 para a elevação de privilégios).*

### 2.2. Ambiente Windows (VM Lab)

Para preparares o servidor Windows para receber comandos do Ansible, é necessário criar o utilizador `ansible` localmente e ativar o protocolo WinRM. 

👉 **Consulta o guia de aprovisionamento:** `02-windows-lab-provisioning.md`

*(Garante que o script oficial do WinRM documentado nesse ficheiro foi executado com sucesso antes de avançares para o próximo passo).*

---

## 3. Distribuição da Chave (Confiança SSH para Linux)

Agora vamos dizer à máquina alvo Linux para confiar na chave que gerámos no Passo 1 (o Windows não usa SSH, pelo que este passo é exclusivo para Linux).

**Volta ao terminal do Controlador (`srv-ansible-core`) e executa:**

```bash
# Substitui o IP pelo IP real da tua VM Linux alvo (ex: 10.10.50.20)
ssh-copy-id ansible@10.10.50.20
```
*(Vai-te pedir a password que definiste no Passo 2.1. Será a única e última vez que a digitas em texto limpo para efeitos de login).*

**Teste de Sucesso:** Após copiares a chave, tenta entrar na máquina Linux. O login deve ser imediato, sem pedir password:

```bash
ssh ansible@10.10.50.20
# (Escreve 'exit' para fechar a sessão e voltares ao Controlador)
```

---

## 4. O Ficheiro de Inventário Central (`inventory.ini`)

O ficheiro de inventário deve ser mantido limpo, contendo estritamente os agrupamentos lógicos e os IPs (ou DNS). As variáveis de ligação vão viver em ficheiros separados por grupo.

No Controlador, abre o ficheiro de inventário:

```bash
nano ~/ansible/inventory/inventory.ini
```

Cola a seguinte estrutura e guarda:

```ini
# =======================================================
# Inventário Ansible - DevSecOps Homelab
# =======================================================

[lab_linux]
srv-linux-lab ansible_host=10.10.50.20

[lab_windows]
srv-windows-lab ansible_host=10.10.50.10
```

---

## 5. O Ansible Vault e Variáveis de Grupo (Segredos)

Para gerir a infraestrutura, o Ansible precisa de saber como se ligar a cada grupo e quais as passwords de elevação de privilégios. Vamos colocar tudo dentro da pasta `group_vars` e trancar esses ficheiros num cofre encriptado AES-256.

### 5.1. Definir o Nano como Editor Padrão

Por defeito, o Ansible Vault tenta abrir o Vim. Para garantir que abre sempre o Nano:

```bash
# Adiciona a instrução ao perfil e recarrega-o
echo "export EDITOR=nano" >> ~/.bashrc
source ~/.bashrc
```

### 5.2. Cofres de Grupo (Linux e Windows)

*Nota de Arquitetura: O nome do ficheiro tem de ser exatamente igual ao nome do **grupo** definido no `inventory.ini` (ex: `lab_linux.yml`).*

**Para o Grupo Linux (Lab):**
```bash
ansible-vault create ~/ansible/inventory/group_vars/lab_linux.yml
```
*(Define uma password-mestra para o teu cofre).* Lá dentro, cola as variáveis SSH:
```yaml
# Configuracoes de ligacao SSH
ansible_user: ansible
ansible_ssh_private_key_file: ~/.ssh/id_ed25519
ansible_python_interpreter: /usr/bin/python3

# Password de sudo para as maquinas Linux deste grupo
ansible_become_pass: "TUA_PASSWORD_DE_SUDO_AQUI"
```

**Para o Grupo Windows (Lab):**
```bash
ansible-vault create ~/ansible/inventory/group_vars/lab_windows.yml
```
*(Usa a mesma password-mestra).* Lá dentro, cola as variáveis WinRM:
```yaml
# Configuracoes de ligacao WinRM
ansible_user: ansible
ansible_connection: winrm
ansible_winrm_server_cert_validation: ignore
ansible_port: 5986
ansible_winrm_transport: basic

# Password de login para as maquinas Windows deste grupo
ansible_password: "TUA_PASSWORD_DO_WINDOWS_AQUI"
```

### 5.3. Comandos Essenciais do Vault (Cheat Sheet)

No dia a dia, não voltarás a usar o comando `create`. Quando precisares de operar sobre os cofres, usa estas instruções:

* **Editar um cofre (Edit):** Abre o ficheiro, desencripta em memória e volta a encriptar ao fechar.
  ```bash
  ansible-vault edit ~/ansible/inventory/group_vars/lab_linux.yml
  ```

* **Consultar sem alterar (View):** Imprime o conteúdo no terminal de forma segura, anulando o risco de edição acidental.
  ```bash
  ansible-vault view ~/ansible/inventory/group_vars/lab_windows.yml
  ```

* **Alterar a password-mestra (Rekey):** Pede a password antiga e permite rodar para uma nova credencial.
  ```bash
  ansible-vault rekey ~/ansible/inventory/group_vars/lab_linux.yml
  ```

* **Encriptar um ficheiro existente:** Transforma um YAML em texto limpo num cofre encriptado.
  ```bash
  ansible-vault encrypt ficheiro_limpo.yml
  ```

* **Desencriptar (remover cofre):** Remove a proteção de forma permanente, devolvendo o ficheiro a texto limpo.
  ```bash
  ansible-vault decrypt ficheiro_encriptado.yml
  ```

---
## 6. Validação (O Teste de Fogo)

Com a infraestrutura mapeada e os segredos trancados, vamos testar a conetividade. Na linha de comandos, os testes rápidos (*ad-hoc*) exigem a utilização do módulo específico para cada sistema operativo.

Executa no Controlador (garante que estás dentro da pasta raiz `~/ansible`):

**1. Testar ambiente Linux (Módulo Python):**
```bash
# Alvo: lab_linux | -i: indica o inventario | -m ping: testa a ligacao SSH | --ask-vault-pass: pede a password do cofre
ansible lab_linux -i inventory/inventory.ini -m ping --ask-vault-pass
```

**2. Testar ambiente Windows (Módulo PowerShell):**
```bash
# Alvo: lab_windows | -i: indica o inventario | -m win_ping: testa a ligacao WinRM | --ask-vault-pass: pede a password do cofre
ansible lab_windows -i inventory/inventory.ini -m win_ping --ask-vault-pass
```

> [!TIP]
> **Output Esperado:** Ambos os comandos deverão devolver a mensagem `"ping": "pong"` a verde. Isto confirma que o Ansible consegue autenticar-se via SSH (Linux) e via WinRM (Windows), lendo corretamente a arquitetura de variáveis guardadas nos cofres de grupo.