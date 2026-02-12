# Proxmox VE: Hardening & Post-Install

> [!NOTE]
> **Ficha Técnica**
> * **Objetivo:** Preparar o SO (Debian Trixie) para produção.
> * **Segurança:** Repositórios "No-Subscription", Microcode, SSH Key-Only e Fail2Ban.
> * **Método:** Híbrido (Script de Bootstrap + Hardening Manual).

---

## 1. Script de Preparação (Automated Hardening)

Este script segue uma abordagem de **"Least Intrusion"**. Valida a versão do SO, faz backups e apenas altera o estritamente necessário (Repositórios e Microcode).

> [!IMPORTANT]
> **Execução via SSH Obrigatória**
> 
> O comando reinicia o serviço `pveproxy` (Interface Web). Se for executado pela consola web, a ligação cai a meio. Usa um terminal (Putty/Terminal).

### Opção A: Execução Direta (Recomendado)

Se já tens acesso à internet no servidor, executa este comando para baixar e correr o script automaticamente do repositório:

```bash
bash <(curl -sL https://raw.githubusercontent.com/ricardojcsantos/devsecops-homelab-infra/main/scripts/proxmox-hardening.sh)
```


### Opção B: Método Manual (Criar Ficheiro)
### Código do Script:

Cria um ficheiro `hardening.sh`, cola o conteúdo abaixo e executa `bash hardening.sh`:

```bash
#!/bin/bash

echo "--------------------------------------------------"
echo "      A Iniciar Proxmox Hardening & Setup...      "
echo "--------------------------------------------------"

# --- 1. Verificação de Segurança ---
echo "A verificar a versão do sistema..."

if ! grep -q "trixie" /etc/os-release; then
    echo "Erro: Este script é exclusivo para Proxmox VE 9.x (Debian Trixie)."
    exit 1
fi

echo "Versão compatível detetada."

# --- 2. Configurar Repositórios (No-Subscription) ---
echo "A configurar repositórios (No-Subscription)..."

# Faz backup da pasta dos repositórios
cp -r /etc/apt/sources.list.d /etc/apt/sources.list.d.bak

# Remove repositórios Enterprise (Pagos)
rm -f /etc/apt/sources.list.d/pve-enterprise.sources
rm -f /etc/apt/sources.list.d/ceph.sources

# Adiciona repositório Gratuito do Proxmox (Trixie)
echo "deb http://download.proxmox.com/debian/pve trixie pve-no-subscription" > /etc/apt/sources.list.d/pve-no-subscription.list

# --- 3. Atualizar o Sistema ---
echo "A atualizar o sistema..."
apt update && apt dist-upgrade -y

# --- 4. Instalar Microcode (CPU Security) ---
echo "A verificar e instalar Microcode do CPU..."
if lscpu | grep -q "Intel"; then
    echo " -> Intel detetado. A instalar microcode..."
    apt install -y intel-microcode
elif lscpu | grep -q "AMD"; then
    echo " -> AMD detetado. A instalar microcode..."
    apt install -y amd64-microcode
fi

# --- 5. Remover Aviso "No Valid Subscription" ---
# Executado no fim para garantir persistência após updates
echo "A remover aviso de subscrição na UI..."
sed -Ezi.bak "s/(Ext.Msg.show\(\{\s+title: gettext\('No valid subscription'\),)/void\(\{ \/\/\1/g" /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js
systemctl restart pveproxy.service

# --- 6. Limpeza Final ---
echo "A limpar ficheiros temporários..."
apt autoremove -y && apt autoclean

echo "----------------------------------------------------------"
echo "            Instalação concluída com sucesso!             "
echo "    Por favor reiniciar o servidor com o comando: reboot   "
echo "----------------------------------------------------------"
```


---

## 2. Gestão de Identidade e Acesso (IAM)

> [!WARNING]
> **Regra de Ouro**
> 
> **Objetivo:** Eliminar o uso do utilizador `root` para operações diárias. Deve-se criar um utilizador nominal para garantir rastreabilidade (*Audit Trail*).

### 2.1. Criar Utilizador Admin (RBAC)

Vamos criar um grupo com permissões totais e adicionar um utilizador pessoal.

#### Opção A: Via Terminal (Recomendado)

Executa via SSH para criar a estrutura completa em segundos.

```bash
# 1. Criar grupo 'Administrators'
pveum group add Administrators -comment "System Administrators"

# 2. Atribuir permissões de Administrador ao grupo em todo o cluster (/)
pveum acl modify / -group Administrators -role Administrator

# 3. Criar o utilizador (Substituir 'ricardo' pelo respetivo nome)
# Nota: O realm 'pve' é a base de dados local do Proxmox.
pveum user add ricardo@pve -group Administrators -password

# (Será pedida a password duas vezes)
```

#### Opção B: Via Interface Web

Fazer via GUI (*Datacenter View*).

1.  **Criar Grupo:**
    * Navegar para: **Datacenter** > **Permissions** > **Groups** > **Create**.
    * **Name:** `Administrators`

2.  **Atribuir Permissões:**
    * Navegar para: **Permissions** > **Add** > **Group Permission**.
    * **Path:** `/`
    * **Group:** `Administrators`
    * **Role:** `Administrator`

3.  **Criar Utilizador:**
    * Navegar para: **Users** > **Add**.
    * **User:** `ricardo`
    * **Realm:** `Proxmox VE authentication server`
    * **Group:** `Administrators`


---

## 3. Autenticação Multifator (MFA/2FA)

> [!IMPORTANT]
> **Requisito de Segurança**
> 
> Em ambientes profissionais, **nenhuma** conta administrativa deve estar exposta sem MFA.
> * **Método:** Exclusivo via Interface Web (o QR Code precisa de ser gerado visualmente).

### Passos de Configuração

1.  **Aceder com o novo utilizador:**
    * Fazer **Logout** do `root`.
    * Entrar com o novo utilizador (ex: `ricardo@pve`).

2.  **Navegar até à definição:**
    * Ir a: **Datacenter** > **Permissions** > **Two Factor Authentication**.

3.  **Adicionar Token:**
    * Clicar em **Add** > **TOTP**.

4.  **Preencher Dados:**
    * **User:** `ricardo@pve`
    * **Description:** `MFA Admin`
    * **Secret:** *(Deixar gerar automático)*

5.  **Sincronizar:**
    * Usar a App (Google Auth, Authy, Microsoft Auth) para ler o **QR Code** no ecrã.
    * Inserir o código de 6 dígitos no campo "Verify Code" e clicar em **Add**.

> [!TIP]
> **Validação**
> 
> Faz **Logout** e volta a tentar entrar. O sistema deve agora pedir o token de 6 dígitos após a password.


---

## 4. SSH Hardening (Chaves e Bloqueio)

> [!CAUTION]
> **Segurança Crítica**
> 
> O objetivo é substituir a autenticação por password por **Chaves Criptográficas (SSH Keys)**. Isto anula completamente ataques de *Brute-Force* baseados em dicionário.

### 4.1. Configurar Chaves (No teu PC)

Antes de trancar a porta, é preciso garantir que tens a chave para entrar.
Executa isto no terminal do **teu computador pessoal** (não no Proxmox).

```bash
# 1. Gerar par de chaves (se ainda não tiveres, dá Enter em tudo)
ssh-keygen -t ed25519 -C "admin-proxmox"

# 2. Enviar a chave pública para o Proxmox (Substitui IP e User)

# Mac / Linux:
ssh-copy-id -i ~/.ssh/id_ed25519.pub ricardo@192.168.1.200

# Windows (PowerShell):
type $env:USERPROFILE\.ssh\id_ed25519.pub | ssh ricardo@192.168.1.200 "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys"
```

### 4.2. Bloquear Passwords e Root (No Proxmox)

Agora vamos configurar o servidor para recusar qualquer login que não use chaves. Isto elimina a possibilidade de ataques de força bruta.

> [!CAUTION]
> **Perigo de Lockout**
> 
> 1. Testa o acesso SSH com a chave numa **nova janela** antes de fazeres isto.
> 2. Se não conseguires entrar, **não feches** a janela atual onde estás logado!

**Passo 1: Criar ficheiro de configuração**
Usamos o editor `nano` para criar uma configuração dedicada.

```bash
nano /etc/ssh/sshd_config.d/99-hardening.conf
```

**Passo 2: Colar a configuração de segurança** Copia o bloco abaixo e cola dentro do editor:

```bash
# Porta SSH (Standard 22)
Port 22

# Desativar login direto de root
# Obriga a entrar como 'ricardo' e depois usar 'su' ou 'sudo'
PermitRootLogin prohibit-password

# Desativar autenticação por password (apenas chaves)
PasswordAuthentication no
ChallengeResponseAuthentication no
PubkeyAuthentication yes

# Whitelist (Apenas estes utilizadores podem ligar via SSH)
AllowUsers root ricardo
```

**Passo 3: Gravar e Sair**
1.  Pressiona `Ctrl+O` e depois `Enter` (para gravar as alterações).
2.  Pressiona `Ctrl+X` (para fechar o editor).

**Passo 4: Aplicar alterações**
Reinicia o serviço SSH para que a nova política de segurança entre em vigor imediatamente.

```bash
systemctl restart sshd
```


---

## 5. Proteção Ativa e Rede (Fail2Ban & Kernel)

> [!NOTE]
> **Objetivo Técnico**
> 
> Banir IPs atacantes automaticamente (IPS) e blindar o Kernel contra ataques de rede comuns (*Spoofing*, *Flooding* e *Man-in-the-Middle*).
> * **Método:** Exclusivo via Terminal (estas configurações de baixo nível não existem na GUI).

### 5.1. Instalar Fail2Ban (Intrusion Prevention)

O Fail2Ban monitoriza os logs do sistema e bloqueia temporariamente IPs que falhem a autenticação repetidamente.

**Passo 1: Instalar o serviço**
```bash
apt update && apt install -y fail2ban
```

**Passo 2: Criar a regra para SSH**
Vamos criar uma "prisão" (*jail*) específica para o serviço SSH.

```bash
nano /etc/fail2ban/jail.local
```

**Passo 3: Colar a configuração**
Copia e cola o seguinte bloco (configurado para ser rigoroso):

```bash
[sshd]
enabled = true              # Ativa a proteção para SSH
port = ssh                  # Monitoriza a porta standard SSH
filter = sshd               # Usa o filtro padrão de logs do SSH
logpath = /var/log/auth.log # Onde o Proxmox guarda os logs de acesso
maxretry = 3                # Número de tentativas falhadas permitidas
bantime = 3600              # Tempo de castigo (em segundos) -> 1 Hora
findtime = 600              # Janela de tempo para contar as falhas -> 10 Minutos
```

**Passo 4: Gravar e Ativar**
1.  Grava (`Ctrl+O`, `Enter`) e sai (`Ctrl+X`).
2.  Ativa o serviço para arrancar com o sistema:

```bash
systemctl enable fail2ban --now
```

### 5.2. Kernel Tuning (Sysctl Hardening)

Vamos ajustar parâmetros do Kernel Linux para ignorar tráfego malicioso e evitar ataques de negação de serviço (DoS).

**Passo 1: Criar ficheiro de parâmetros**
```bash
nano /etc/sysctl.d/99-pve-security.conf
```

**Passo 2: Colar as regras de blindagem**
Copia o bloco anano /etc/sysctl.d/99-pve-security.confbaixo e cola dentro do editor:

```ini
# --- Proteção de Rede (Network Hardening) ---

# Ignorar Pings de Broadcast
# Evita ataques "Smurf" onde o servidor responderia a toda a rede
net.ipv4.icmp_echo_ignore_broadcasts = 1

# Proteção contra IP Spoofing
# Valida se o pacote vem da interface correta (RFC 3704)
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1

# Desativar Redirecionamentos ICMP
# Evita ataques Man-in-the-Middle; o servidor não deve aceitar rotas de estranhos
net.ipv4.conf.all.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0

# Log de pacotes "Martians"
# Regista IPs impossíveis (ex: IP privado a vir da WAN) para auditoria
net.ipv4.conf.all.log_martians = 1
```
 *(Gravar com `Ctrl+O`, `Enter` e Sair com `Ctrl+X`)*

**Passo 3: Aplicar imediatamente**
Carrega as novas regras sem precisar de reiniciar o servidor.

```bash
sysctl --system
```


---

## Checklist de Conclusão (Hardening)

| Componente         |   Estado    | Verificação                                |
| :----------------- | :---------: | :----------------------------------------- |
| **Sistema Base**   |  🔒 Seguro  | Repos No-Sub, Trixie, Microcode OK.        |
| **Acesso Web**     |  🔒 Seguro  | User dedicado + MFA ativo. Root protegido. |
| **Acesso SSH**     | 🔒 Blindado | Apenas Chaves (Keys). Password Auth OFF.   |
| **Proteção Ativa** |  🛡️ Ativa  | Fail2Ban a correr. Kernel Tuned.           |
