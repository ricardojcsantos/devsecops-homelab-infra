# Guia: Preparar o Servidor Docker + Automação GitHub

> [!NOTE]
> **O que é isto:** Passo-a-passo para criar uma máquina virtual segura no Proxmox, instalar o Docker e ligá-la ao GitHub. Assim, sempre que o código alterar no GitHub, o servidor atualiza as apps automaticamente.

---

## 1. Apps que vão correr neste Servidor

* **Nginx Proxy Manager (NPM):** Gere os domínios e trata dos certificados de segurança.
* **Vaultwarden:** O gestor de passwords.
* **Immich:** A galeria de fotos privada (tipo Google Photos).
* **Nextcloud:** A nuvem de ficheiros.
* **GitHub Actions Runner:** O agente que "ouve" o GitHub e aplica as alterações no servidor.

---

## 2. Como configurar a Máquina Virtual (Proxmox)

| Componente                 | Valor a colocar             | Porquê?                                                                   |
| :------------------------- | :-------------------------- | :------------------------------------------------------------------------ |
| **Sistema Operativo** | Ubuntu Server 24.04 LTS     | Versão base, sem lixo gráfico instalado.                                  |
| **Processador (CPU)** | 4 vCores (**Type: Host**)   | Obrigatório para o Immich funcionar bem.                                  |
| **Memória (RAM)** | 8192 MB (8 GB)              | Desligar o *Ballooning* para não bloquear as bases de dados.              |
| **Disco Principal (OS)** | 50 GB                       | Ativar as opções `SSD Emulation` e `Discard` (Ajuda na saúde do disco).   |
| **Disco Secundário** | 250 GB+                     | Disco apenas para guardar as fotos e ficheiros das apps.                  |
| **Rede** | VirtIO (Bridge)             | Definir um IP fixo na VM (ex: 10.10.40.10).                               |
| **QEMU Agent** | Ativado                     | Permite ao Proxmox saber o IP da máquina e desligá-la corretamente.       |

---

## 3. Preparar o Linux (Comandos via SSH)

Abrir o terminal da vm e corre estes blocos de código em ordem.

### 3.1. Atualizar o Sistema e Instalar Ferramentas Úteis

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y curl wget git htop net-tools qemu-guest-agent
sudo systemctl enable --now qemu-guest-agent
```

### 3.2. Preparar os Discos (Espaço e Dados)

Vamos usar todo o espaço do disco principal e formatar o disco secundário para guardar as apps.

**A. Esticar o disco principal para usar os 50GB:**

```bash
sudo lvextend -l +100%FREE /dev/ubuntu-vg/ubuntu-lv
sudo resize2fs /dev/ubuntu-vg/ubuntu-lv
```

**B. Formatar o disco secundário e montá-lo na pasta `/data`:**

> [!WARNING]
> Confirma sempre se o disco é o 'sdb' usando o comando `lsblk` antes de formatares.

```bash
# Formata o disco (confirma se é o 'sdb' usando o comando 'lsblk')
sudo mkfs.ext4 /dev/sdb

# Cria a pasta onde vão ficar os ficheiros
sudo mkdir /data

# Liga o disco a essa pasta
sudo mount /dev/sdb /data
```

**C. Fazer o disco ligar automaticamente quando a máquina reinicia:**

1. Descobrir o ID do teu disco: `sudo blkid /dev/sdb` (Copiar o código UUID).
2. Abrir o ficheiro de configuração: `sudo nano /etc/fstab`.
3. Cola esta linha no fim (troca pelo UUID do disco): `UUID=UUID_AQUI  /data  ext4  defaults  0  2`
4. Testar se ficou bem feito: `sudo mount -a` 

> [!TIP]
> Se o comando `sudo mount -a` não retornar nenhum erro no terminal, a configuração do fstab está perfeita.

### 3.3. Ligar a Firewall (Segurança)

Bloqueia tudo o que vem de fora, permitindo apenas acesso remoto por SSH.

```bash
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh
sudo ufw --force enable
```

### 3.4. Instalar o Docker Oficial

```bash
# 1. Instala ferramentas de download seguro
sudo apt update
sudo apt install ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# 2. Adiciona o repositório do Docker ao Ubuntu
sudo tee /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
Components: stable
Signed-By: /etc/apt/keyrings/docker.asc
EOF

# 3. Instala o Docker
sudo apt-get update
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y

# 4. Dá permissão ao teu utilizador para usar o Docker sem escrever 'sudo'
sudo usermod -aG docker $USER
sudo systemctl enable --now docker.service
sudo systemctl enable --now containerd.service
```

### 3.5. Criar as Pastas para as Apps

Vamos criar uma pasta no disco de 250GB para cada serviço.

```bash
sudo mkdir -p /data/{npm,vaultwarden,immich,nextcloud}
sudo chown -R $USER:docker /data
sudo chmod -R 775 /data
```

---

## 4. Testar se o Docker Ficou Bem Instalado

| O que estamos a testar | Comando a executar             | Resposta que deves ver            |
| :--------------------- | :----------------------------- | :-------------------------------- |
| **Versão instalada** | `docker --version`             | `Docker version 25.0.x...`        |
| **Plugin do Compose** | `docker compose version`       | `Docker Compose version v2.x`     |
| **Se está a correr** | `systemctl is-active docker`   | `active`                          |
| **Teste Real** | `docker run --rm hello-world`  | `Hello from Docker!`              |

---

## 5. Ligar o Servidor ao GitHub

Vamos instalar o programa que lê as instruções no GitHub e levanta as apps no servidor.

### 5.1. Descarregar o Agente

Ir ao repositório do GitHub: *Settings > Actions > Runners > New self-hosted runner*. 

```bash
# Create a folder
mkdir actions-runner && cd actions-runner

# Download the latest runner package
curl -o actions-runner-linux-x64-2.331.0.tar.gz -L https://github.com/actions/runner/releases/download/v2.331.0/actions-runner-linux-x64-2.331.0.tar.gz

# Extract the installer
tar xzf ./actions-runner-linux-x64-2.331.0.tar.gz
```

### 5.2. Ligar ao Repositório

Substituir pelo comando exato que o GitHub te mostra no ecrã (com o teu token):

```bash
./config.sh --url https://github.com/ricardojcsantos/REPOSITORIO --token TOKEN_AQUI
```

> [!IMPORTANT]
> Clica 'Enter' em todas as perguntas que o assistente fizer para aceitar os nomes padrão.

### 5.3. Meter o Agente a Correr em Fundo

Para que não seja preciso manter o terminal aberto, vamos instalar o agente como um serviço do sistema.

```bash
# Instala o serviço
sudo ./svc.sh install

# Arranca o serviço
sudo ./svc.sh start

# Verifica se está tudo OK (Tem de dizer 'active')
sudo ./svc.sh status
```

> [!SUCCESS]
> **Tudo Pronto:** O servidor está ligado ao GitHub. Quando meteres os ficheiros `.yml` no teu repositório, este agente vai ler os ficheiros e arrancar os contentores automaticamente.