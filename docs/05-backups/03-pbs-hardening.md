# Hardening e Configuração (PBS)

> [!NOTE]
> **Ficha Técnica**
> * **Onde Aplicar:** `srv-backups` (Proxmox Backup Server / Debian Trixie).
> * **Objetivo:** Aplicar regras de segurança numa Máquina Virtual isolada.
> * **Nota de Hardware:** Não vamos instalar atualizações de processador (Microcode) nesta VM, porque o servidor Proxmox principal já trata disso.

---

## 1. Repositórios (Grátis) e Atualizações

Vamos trocar a versão paga do sistema pela versão gratuita para podermos receber atualizações de segurança.

* No menu do lado esquerdo, aceder a **Administration** e clicar em **Repositories**.
* Selecionar a linha com `enterprise.proxmox.com` e clicar no botão **Disable** (no topo).
* Clicar no botão **Add**, escolher **No-Subscription** e clicar em **Add**.

**Execução no Terminal (Root):**
```bash
# Atualizar todo o sistema
apt update && apt full-upgrade -y
```

---

## 2. Utilizadores e Acessos (IAM)

> [!WARNING]
> **Regra de Ouro:**
> Não se deve usar o utilizador `root` no dia a dia. Cria uma conta com o teu nome para saberes sempre quem alterou o quê.

### 2.1. Criar Utilizador Administrador

No PBS damos permissões diretamente à pessoa (não precisamos de criar grupos primeiro).

#### Opção A: Via Terminal (Recomendado)

Corre isto no terminal para criares a conta num segundo.

```bash
# 1. Criar a tua conta (Muda 'ricardo' para o teu nome)
proxmox-backup-manager user add ricardo@pbs --password

# 2. Dar permissões de Administrador em todo o servidor (Caminho: /)
proxmox-backup-manager acl update / Admin --auth-id ricardo@pbs
```

#### Opção B: Via Painel Web

Acede à interface web (`https://ip-da-vm:8007`).

* **1. Criar Utilizador:**
  * Vai a: `Configuration` > `Access Control` > `User Management` > `Add`.
  * **User:** `ricardo`
  * **Realm:** `Proxmox Backup authentication server`
  * **Password:** Escolher uma forte.

* **2. Dar Permissões:**
  * Vai a: `Configuration` > `Access Control` > `Permissions` > `Add` > `User Permission`.
  * **Path:** `/`
  * **User:** `ricardo@pbs`
  * **Role:** `Admin`

> [!IMPORTANT]
> **Autenticação Dupla (MFA/2FA)**
> 
> A verificação em dois passos tem de ser ativada na Interface Web:
> * **Onde ir:** Configuration > Access Control > Two Factor Authentication > Add > TOTP.

---

## 3. Segurança do SSH (Apenas Chaves)

> [!CAUTION]
> **Bloquear Passwords**
> O objetivo é proibir o login com password. Vamos usar apenas "Chaves de Segurança" (ficheiros no teu PC) para impedir que robôs adivinhem a tua senha.

### 3.1. Configurar Chaves (No teu PC)

Garante que tens a chave antes de trancares a porta do servidor. Corre isto no teu PC:

```bash
# 1. Criar a chave (dá Enter a tudo)
ssh-keygen -t ed25519 -C "admin-pbs"

# 2. Enviar a chave para o servidor
# Mac / Linux:
ssh-copy-id -i ~/.ssh/id_ed25519.pub root@10.10.1.253

# Windows (PowerShell):
type $env:USERPROFILE\.ssh\id_ed25519.pub | ssh root@10.10.1.253 "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys"
```

### 3.2. Bloquear Root e Passwords (No PBS)

> [!CAUTION]
> **Atenção:** Testa se consegues entrar noutra janela do terminal antes de fazeres isto, para não ficares trancado fora!

**Passo 1: Criar ficheiro de segurança**
```bash
nano /etc/ssh/sshd_config.d/99-hardening.conf
```

**Passo 2: Colar regras**
Copiar e colar isto:
```bash
# Porta normal do SSH
Port 22

# Desliga login direto com password
PermitRootLogin prohibit-password

# Obriga a usar as chaves de segurança
PasswordAuthentication no
ChallengeResponseAuthentication no
PubkeyAuthentication yes

# Só o root pode aceder por SSH (usando a chave)
AllowUsers root
```

**Passo 3: Gravar e Sair**
* Clica `Ctrl+O` e `Enter` (para gravar).
* Clica `Ctrl+X` (para sair).

**Passo 4: Aplicar regras**
```bash
systemctl restart sshd
```

---

## 4. Proteção de Rede (Fail2Ban e Kernel)

> [!NOTE]
> **Objetivo:**
> Bloquear IPs que tentem adivinhar a password repetidamente e proteger o servidor contra ataques de rede. Feito apenas no terminal.

### 4.1. Instalar Fail2Ban (Bloqueio Automático)

**Passo 1: Instalar**
```bash
apt update && apt install -y fail2ban
```

**Passo 2: Criar a regra de bloqueio**
```bash
nano /etc/fail2ban/jail.local
```

**Passo 3: Colar a configuração**
Bloqueia um IP durante 1 hora se falhar 3 vezes num espaço de 10 minutos:
```ini
[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 3600
findtime = 600
```

**Passo 4: Gravar e Ligar**
* Grava (`Ctrl+O`, `Enter`) e sai (`Ctrl+X`).
* Liga a proteção:
```bash
systemctl enable fail2ban --now
```

### 4.2. Afinar o Sistema (Kernel)

**Passo 1: Criar ficheiro de regras**
```bash
nano /etc/sysctl.d/99-pbs-security.conf
```

**Passo 2: Colar regras de defesa**
```bash
# Ignorar pedidos de ping em massa (evita sobrecargas)
net.ipv4.icmp_echo_ignore_broadcasts = 1

# Bloquear IPs falsificados
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1

# Rejeitar redirecionamentos perigosos de rede
net.ipv4.conf.all.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0

# Registar ligações impossíveis para rever mais tarde
net.ipv4.conf.all.log_martians = 1
```

**Passo 3: Gravar e Sair** (`Ctrl+O`, `Enter` -> `Ctrl+X`).

**Passo 4: Ativar**
```bash
sysctl --system
```

---

## 5. Escalabilidade para Grande Empresa

> [!IMPORTANT]
> O que fizemos acima é excelente para um homelab. Mas numa grande empresa auditada, teríamos de juntar obrigatoriamente estes pontos:

### Equipamento e Proteção Física

* **Servidor Próprio:** Ter um computador físico só para os backups (não usar uma Máquina Virtual).
* **Discos de Topo:** Usar vários discos em conjunto (RAID). Se um queimar, os dados não se perdem.
* **Sala Trancada:** Guardar o servidor numa sala segura com câmaras e entrada por impressão digital.

### Gestão de Dados e Segurança

* **Regra 3-2-1:** Enviar obrigatoriamente uma cópia dos backups para a Nuvem ou para outro edifício.
* **Anti-Ransomware:** Usar discos especiais onde não se consegue apagar dados, ou usar discos que ficam desligados da corrente física.
* **Encriptação:** Trancar os ficheiros com uma senha forte na origem. Assim, se roubarem o servidor, não conseguem ler nada.

### Acessos e Redes Isoladas

* **Logins Centrais:** Ligar o servidor às contas gerais da empresa (ex: sistema da Microsoft) em vez de criar utilizadores à mão.
* **Rede Fechada:** Proibir o acesso de toda a gente. Só os computadores dos informáticos é que conseguem sequer ver a página web do servidor.
* **Vigilância Permanente:** Enviar os registos do que acontece no servidor para uma equipa de segurança monitorizar dia e noite (SOC).

### Regras Operacionais

* **Licença Paga:** Pagar a licença oficial (*Enterprise*) para poder ligar à linha de emergência em caso de avaria grave.
* **Vigiar o Desgaste:** Ter programas a monitorizar os discos para avisar antes de eles morrerem de velhice.
* **Testar Restauros:** Apagar máquinas de propósito a cada 3 meses para garantir que o sistema de recuperação funciona mesmo na prática.