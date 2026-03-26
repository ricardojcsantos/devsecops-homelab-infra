# 06: Manual Simples de Backups e Restauro

> [!IMPORTANT]
> **Objetivo:** Garantir que temos cópias de segurança de tudo. Se houver algum problema ou uma peça avariar, consegues pôr tudo a funcionar de novo em poucos minutos, de forma simples.

---

## 1. O Router (pfSense)

A proteção do router opera num modelo híbrido de alta disponibilidade: guardamos a configuração lógica na *cloud* e a infraestrutura virtual (VM) no disco de backups local.

### Como são feitos os Backups

* **Na Nuvem (Automático):** Sempre que uma regra é alterada e clicas em `Apply Changes`, o pfSense encripta o ficheiro de definições e guarda-o nos servidores da Netgate em segurança.

* **No Disco de Backups (Madrugada):** Todos os dias às 04:00 da manhã, o Proxmox tira um snapshot à máquina inteira e guarda-a no cofre (`pbs-local`).

> [!TIP]
> **Onde estão as instruções de configuração?**
> * **Backup na Nuvem:** O passo-a-passo para ativar esta proteção e guardar a *Device Key* está no Ponto 3 do documento [`03-pfsense-hardening.md`](../03-network/03-pfsense-hardening.md).
>   
> * **Backup da VM Inteira:** A explicação exata de como configurar a rotina automática no Proxmox encontra-se no **Ponto 3 deste documento**.

### Como Restaurar se houver problemas

| O que aconteceu?                   | Como resolver passo-a-passo                                                                                                                                                        |
| :--------------------------------- | :--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Fiz asneira / Tive um problema** | Aceder a `Services` > `Auto Config Backup` > `Restore` e escolher a versão mais recente para voltar atrás no tempo.                                                                |
| **A máquina não arranca**          | No Proxmox, ir a `pbs-local` > `Backups` > Selecionar a VM > Clicar em **Restore**.                                                                                                |
| **Instalação do zero (Desastre)**  | 1. Instalar um pfSense novo. <br>2. Ir a `Services` > `Auto Config Backup`. <br>3. Inserir a *Device Key* original e a *Password*. O sistema descarrega todos os backups da nuvem. |

---

## 2. As Configurações do Servidor (Proxmox Host)

Se o disco físico do servidor avariar, perdes as configurações de rede e a lista de todas as Máquinas Virtuais. Vamos criar uma rotina para salvaguardar estas pastas automaticamente no disco de backups.

### Como criar o Backup Automático

**Passo 1: Criar o ficheiro do script**

Abrir a consola (Shell) do Proxmox e executa o comando:

```bash
nano /root/backup-proxmox.sh
```

**Passo 2: Inserir o código**

Colar o código abaixo. Altera apenas a password onde indicado (Para guardar pressionar `CTRL+X`, depois `Y` e `Enter`):

```bash
#!/bin/bash

# 1. Cria uma pasta temporária estrita para o backup
mkdir -p /tmp/pbs-host-backup

# 2. Comprime as pastas vitais (Registo de VMs, Rede e DNS) para dentro dessa nova pasta
tar -czvf /tmp/pbs-host-backup/pve-host-config.tar.gz /etc/pve /etc/network/interfaces /etc/hosts /etc/resolv.conf

# 3. Injeta a password do Proxmox Backup Server (PBS) temporariamente na sessão
export PBS_PASSWORD="tua-password-do-pbs"

# 4. Envia a PASTA inteira para o teu disco de backups (pbs-local)
proxmox-backup-client backup config-host.pxar:/tmp/pbs-host-backup --repository root@pam@10.10.1.253:backup-pool

# 5. Apaga a pasta temporária do Proxmox para manter o sistema limpo
rm -rf /tmp/pbs-host-backup
```

**Passo 3: Dar permissão de execução**

Dar autorização ao sistema para correr este ficheiro:

```bash
chmod +x /root/backup-proxmox.sh
```

**Passo 4: Primeira Execução Manual (Obrigatório)**

Antes de automatizares, tens de correr o script uma vez para o sistema registar a assinatura de segurança do teu PBS.

Executa no terminal:

```bash
/root/backup-proxmox.sh
```

O sistema vai perguntar: `Are you sure you want to continue connecting? (y/n)`. **Escreve `y` e carrega no Enter (vai pedir duas vezes).** Isto guarda a "impressão digital" para que, de madrugada, o script não encrave à espera de intervenção humana.

**Passo 5: Agendar para a madrugada (Cron)**

Diz ao sistema para correr isto de forma invisível todos os dias às 04:00 da manhã. Escreve `crontab -e` e adiciona este bloco no final do documento:

```bash
# Executa o script todos os dias às 04:00 AM.
# A instrução ">/dev/null 2>&1" redireciona o output para o vazio, evitando logs desnecessários.
0 4 * * * /root/backup-proxmox.sh >/dev/null 2>&1
```

---

### Como Restaurar se o disco físico avariar

Se o servidor "morrer" e tiveres de colocar um disco físico novo, segue estes passos rigorosamente para extrair o backup através do Proxmox Backup Server (PBS):

1. **Instalação Limpa:** Instalar o Proxmox VE de fresco no novo disco.

2. **Extração Direta (Via PBS):** Acede à interface web do teu PBS (Porta 8007). Ir a `Datastore: backup-pool` > Separador `Content` > expande a secção `host/pve-node` e descarrega o ficheiro de backup (`.tar.gz`) para o teu PC.

3. **Reconstrução Segura:** Extrai as pastas no teu computador e usa-as apenas como um "mapa" para voltares a configurar os mesmos IPs (`interfaces`) e para recuperares os ficheiros das tuas VMs (`/etc/pve/qemu-server`).

> [!WARNING]
> **Atenção (O Paradoxo da VM):** Se o teu PBS for uma Máquina Virtual dentro do próprio Proxmox que avariou, não terás acesso à interface web dele para recuperar este ficheiro inicial. Neste cenário de falha total, é mandatório que extraias periodicamente o ficheiro `.tar.gz` e o guardes num armazenamento externo (PC local ou NAS) *antes* do desastre ocorrer.

> [!CAUTION]
> **Nunca** copies estas pastas diretamente por cima do Proxmox novo à pressa, pois podes corromper a nova instalação. Copia apenas o conteúdo estritamente necessário.

---

## 3. As Máquinas Virtuais (O Sistema Todo)

É aqui que guardamos as VMs inteiras. Se o Sistema Operativo encravar ou houver corrupção, recuperas a máquina tal como ela estava na madrugada anterior, sem perder dados e em poucos minutos.

### Como agendar o Backup

**Passo 1: Criar a Tarefa**

No Proxmox VE, vai a `Datacenter` > `Backup` e clica no botão `Add`.

**Passo 2: Preencher as Definições**

Preenche os campos exatamente com estes parâmetros para otimização:

* **Storage:** `pbs-local` (O disco de backups).
* **Schedule:** `04:00` (Executa de madrugada, quando o tráfego e uso de CPU são mínimos).
* **Selection Mode:** `Include selected VMs` (Escolhe estritamente as máquinas de produção).
* **Mode:** `Snapshot` (Garante a cópia "a quente" usando o QEMU Guest Agent, sem desligar as máquinas).

**Passo 3: Configurar a Retenção (Manter apenas 3 dias)**

Para garantir que o disco não enche, configuramos o sistema para manter estritamente os últimos 3 backups (apagando o mais antigo de forma autónoma).

* Na mesma janela de configuração, clica no separador **Retention**.
* **Keep Last:** Preenche com o valor `3`.
* **Restantes campos (Keep Daily, Weekly, etc.):** Deixa totalmente em branco para não criar retenções residuais indesejadas.

---

### Como Restaurar (Disaster Recovery)

**Passo 1: Isolamento (Desligar a Máquina Avariada)**

Efetuar sempre o `Shutdown` (ou `Stop` forçado) da máquina com problemas antes de iniciar o restauro. 
Se não o fizeres, a rede vai bloquear com conflitos de IP quando a máquina antiga e a restaurada tentarem comunicar ao mesmo tempo.

**Passo 2: Injetar o Backup**

1. No menu lateral do Proxmox, vai ao teu cofre de backups: `pbs-local` > `Backups`.
2. Selecionar o *snapshot* da VM afetada com a data pretendida e clica em **Restore**.
3. Escolher o disco de destino em **Target Storage** (ex: `local-lvm`) e mantém o **VM ID** original (ex: `200`). 
4. Clicar no botão de restauro e aguarda que a máquina seja reconstruída.

---

## 4. As Apps Docker (Bases de Dados e Passwords)

Os dados pesados (fotos do Immich, ficheiros do Nextcloud) residem no disco `/data` e são protegidos automaticamente pelo *snapshot* do Proxmox (Ponto 3). No entanto, as bases de dados ativas na RAM (SQL/SQLite) corrompem facilmente se copiadas "a quente".

Esta rotina garante o *dump* (exportação limpa) dos metadados e o empacotamento das configurações críticas (*Vaultwarden* e *NPM*) antes do backup principal, sem duplicar os Gigabytes de media.

### Como criar o Backup "A Limpo" (Script Híbrido)

**Passo 1: Instalar Dependências**

O *Vaultwarden* e o *NPM* utilizam SQLite. Instala a ferramenta nativa no Linux para garantir a exportação transacional segura. 
Executa na VM Docker:

```bash
apt update && apt install sqlite3 -y
```

**Passo 2: Criar o Script Unificado**

Gera o ficheiro que vai orquestrar a rotina:

```bash
nano backup-db.sh
```

**Passo 3: Inserir o Código**

Cola o código abaixo. O *script* exporta os catálogos (SQL) e empacota o essencial, ignorando deliberadamente as pastas pesadas de media. Altera a *password* onde indicado (Guarda com `CTRL+X`, `Y` e `Enter`):

```bash
#!/bin/bash

# Define as diretorias da infraestrutura
DATA_DIR="/data"
DUMPS_DIR="/data/dumps"
EXPORT_DIR="/root/docker-export"

# Cria as pastas de destino
mkdir -p $DUMPS_DIR
mkdir -p $EXPORT_DIR

# 1. Dumps SQL (Mapeamento corrigido para os teus contentores reais)
docker exec immich-postgres pg_dumpall -c -U postgres > $DUMPS_DIR/immich_db.sql
docker exec nextcloud-db mysqldump --all-databases -u root -p"tua-password-do-mariadb" > $DUMPS_DIR/nextcloud_db.sql

# 2. Dumps SQLite (Vaultwarden e NPM - Cópias atómicas a quente)
sqlite3 $DATA_DIR/vaultwarden/db.sqlite3 ".backup '$DUMPS_DIR/vaultwarden_db.sqlite3'"
sqlite3 $DATA_DIR/npm/database.sqlite ".backup '$DUMPS_DIR/npm_db.sqlite'"

# 3. Criar o Cofre Portátil de Emergência
# NOTA: Empacota os Dumps e as pastas leves. Exclui ficheiros pesados de media.
tar -czvf $EXPORT_DIR/docker-core-$(date +%F).tar.gz $DUMPS_DIR $DATA_DIR/vaultwarden $DATA_DIR/npm

# 4. Limpeza Autónoma (FIFO: Mantém estritamente os 3 backups mais recentes)
ls -t $EXPORT_DIR/docker-core-*.tar.gz | tail -n +4 | xargs -r rm -f
```

**Passo 4: Permissões e Agendamento (Cron)**

Dá autorização de execução ao binário:

```bash
chmod +x backup-db.sh
```

Abre o agendador (`crontab -e`) e define a execução para as **03:30** da manhã (exatamente 30 minutos antes do Proxmox fazer a cópia pesada da máquina inteira para a Pen Drive):

```bash
30 3 * * * /home/administrator/backup-db.sh >/dev/null 2>&1
```

---

### Como Extrair o Cofre de Emergência (Download)

Para garantires que tens os dados na mão antes de um desastre total, extrai o ficheiro periodicamente para o teu PC local (Cold Storage).

1. Acede à interface do **Proxmox VE** (Porta 8006).
2. No menu lateral, clica no disco da Pen: `pbs-local` > **Backups**.
3. Selecionar o backup mais recente da tua VM Docker e clica no botão **File Restore** (no menu superior).
4. Na janela que abre, expande a árvore de pastas: `drive-scsi0.img.fidx` > `root` > `docker-export`.
5. Selecionar o ficheiro `docker-core-YYYY-MM-DD.tar.gz` e clica em **Download**.

---

### Como Restaurar Tudo numa Máquina Nova

Se o servidor avariar por completo e precisares de montar tudo num computador novo do zero, usa o ficheiro `.tar.gz` que descarregaste para repor tudo a funcionar em poucos minutos.

| Passo                             | O que tens de fazer                                                                                               | Comando ou Ação a executar                                                                                    |
| :-------------------------------- | :---------------------------------------------------------------------------------------------------------------- | :------------------------------------------------------------------------------------------------------------ |
| **1. Enviar o Backup**            | Passar o ficheiro de segurança para a pasta `/root/` do servidor novo.                                            | Usa um programa como o **WinSCP** para arrastar o ficheiro para lá.                                           |
| **2. Descompactar**               | Extrair as tuas passwords e bases de dados. Este comando coloca tudo automaticamente nas pastas certas.           | `tar -xzvf /root/docker-core-*.tar.gz -C /`                                                                   |
| **3. Repor as Fotos e Ficheiros** | Copia as pastas pesadas que estavam protegidas no disco de Backups.                                               | Coloca as tuas fotos e documentos dentro de `/data/immich` e `/data/nextcloud`.                               |
| **4. Ligar os Serviços**          | Arranca com o Docker. O teu cofre de Passwords (Vaultwarden) e gestor de acessos (NPM) ficam logo prontos a usar. | Navega até à pasta onde está o teu `docker-compose.yml` e escreve:<br>`docker compose up -d`                  |
| **5. Reconhecer o Nextcloud**     | Injeta a base de dados antiga para o Nextcloud voltar a "ver" os ficheiros que copiaste no passo 3.               | `cat /data/dumps/nextcloud_db.sql \| docker exec -i nextcloud-db mariadb -u root -p"tua-password-do-mariadb"` |
| **6. Reconhecer o Immich**        | Injeta a base de dados antiga para o Immich voltar a "ver" as fotos e os álbuns.                                  | `cat /data/dumps/immich_db.sql \| docker exec -i immich-postgres psql -U postgres`                            |

---

## 5. Limpeza Física Obrigatória (Não deixar o Disco encher)

O Proxmox VE apaga o registo das VMs mais antigas (via regra de Retenção do Ponto 3), mas isso apenas destrói o índice lógico (*Pruning*). Os Gigabytes reais só são eliminados fisicamente do Disco quando o PBS executa a operação pesada de remoção de blocos órfãos (*Garbage Collection*).

Como as VMs estão limitadas a 3 dias, tens de configurar o PBS para fazer o mesmo aos backups do Host (Ponto 2) e limpar o disco físico de forma autónoma.

### Fase A: Limitar os Backups do Host (Prune Job)

Instruir o PBS a manter estritamente os últimos 3 dias de configurações do Proxmox Host.

1. Acede à interface web do **Proxmox Backup Server** (Porta `8007`).
2. Vai a `Datastore: backup-pool` > `Prune & GC Jobs`.
3. Clica no botão **Add** (na secção superior de *Prune Jobs*).
4. Preenche os parâmetros estritamente como abaixo:

| Parâmetro de Retenção | Valor a Inserir | Motivo de Engenharia |
| :--- | :--- | :--- |
| **Keep Last** | `3` | Garante a regra FIFO, mantendo apenas as 3 cópias mais recentes. |
| **Schedule** | `daily` | Força a validação e limpeza lógica a ocorrer diariamente. |
| *(Restantes Campos)* | *(Deixar Vazio)* | Preencher retenções mensais/semanais anula a regra principal e esgota o disco. |

### Fase B: Libertar o Espaço Físico (Garbage Collection)

Agendar quando é que vai ao sistema de ficheiros destruir os blocos obsoletos e devolver o espaço real disponível.

1. No mesmo separador (`Prune & GC Jobs`), localiza a tarefa base chamada **Garbage Collection**.
2. Seleciona a tarefa e clica em **Edit**.
3. Configura o agendamento:

| Parâmetro de Tarefa | Valor a Inserir | Motivo de Engenharia                                                                                                         |
| :------------------ | :-------------- | :--------------------------------------------------------------------------------------------------------------------------- |
| **Schedule**        | `Sat 06:00`     | Executa ao Sábado de manhã. Evita colisões de I/O (escrita no disco) com a janela de backups de produção das VMs (04:00 AM). |
