# PfSense: Hardening, VLANs e Otimização

> [!ABSTRACT] Resumo
> * **Segurança:** Implementação de "Zero Trust" com bloqueios explícitos entre VLANs.
> * **Infraestrutura:** Segmentação lógica via VLANs e Switch Gerível (TP-Link TL-SG108E).
> * **Performance:** Otimização do Switch (QoS) e Segurança DNS.

## 1. Gestão de Identidade (RBAC)

**Objetivo:** Eliminar o uso da conta genérica `admin` para garantir rastreabilidade.

1. Navegar para **System > User Manager**.
2. Clicar em **Add**.
3. Preencher:
    * **Username:** (Ex: `rsantos.admin`)
    * **Password:** (Gerar aleatória > 20 caracteres)
    * **Group Membership:** Mover `admins` para a coluna **"Member Of"**.
4. Clicar em **Save**.
5. **Bloquear Default:**
    * Editar o utilizador `admin`.
    * Marcar **Disabled** ("This user cannot login").
    * Clicar em **Save**.

---

## 2. Segurança de Acesso (SSH & WebGUI)

**Objetivo:** Proteger interfaces de gestão contra acessos não autorizados.

1. Navegar para **System > Advanced > Admin Access**.
2. **Secção Secure Shell (SSH):**
    * **Secure Shell:** Enable.
    * **SSH Port:** Alterar para **`2222`**.
3. **Secção WebGUI:**
    * **Protocol:** HTTPS.
4. **Secção Console Options:**
    * **Password Protect:** Enable (Protege o acesso físico/console).

---

## 3. Resiliência e Backups (ACB)

**Objetivo:** Backups automáticos na cloud da Netgate e garantia de recuperação total (Disaster Recovery).

1. Navegar para **Services > Auto Config Backup > Settings**.
2. **Enable ACB:** Checked.
3. **Encryption Password:** Definir uma password forte.
4. **Device Key:** Identificar a chave alfanumérica mostrada no ecrã.
    * **AÇÃO CRÍTICA:** Copiar e guardar a **Device Key** e a **Encryption Password** no Cofre de Passwords.
    * *Motivo:* A "Device Key" é única por instalação. Se criares uma VM nova, ela terá uma chave diferente e não verá os teus backups antigos a menos que insiras a chave original manualmente.
5. **Frequency:** "On every config change".
6. Clicar em **Save**.

### 3.1 Validar e Restaurar
1. Clicar na aba **Restore** (no topo da página).
2. Verificar se a lista é preenchida com as alterações recentes.
3. **Para restaurar:** Clicar no ícone de "Revisão" ao lado da data desejada.

> [!TIP] Em caso de Desastre (Nova Instalação)
> Se tiveres de reinstalar o pfSense do zero (ex: falha de disco ou corrupção):
> 1. Instalar o novo pfSense.
> 2. Ir a **Services > Auto Config Backup**.
> 3. Substituir a nova **Device Key** pela **Antiga** (que guardaste no cofre).
> 4. Inserir a **Encryption Password**.
> 5. Clicar em **Save** e ir à aba **Restore**. Os teus backups antigos estarão disponíveis para download/restore.

---

## 4. Estabilização WAN (Fix Double NAT)

**Objetivo:** Garantir que o pfSense deteta falhas reais de Internet e não apenas a queda do cabo local.

1. Navegar para **System > Routing > Gateways**.
2. Editar o Gateway `WAN`.
3. **Monitor IP:** Alterar para `1.1.1.1`.
    * *Explicação Técnica:* Por defeito, o pfSense pinga o Router do ISP (`192.168.1.1`). Se o serviço do ISP cair mas o router ficar ligado, o pfSense acha que tem Internet. Ao pingar `1.1.1.1`, validamos a conectividade "fim-a-fim".
4. Clicar em **Save** e **Apply Changes**.

---

## 5. Segmentação de Rede (Definição VLANs)

**Objetivo:** Criar a estrutura lógica e as interfaces no pfSense.

### 5.1 Criar as Tags VLAN

1. Navegar para **Interfaces > Assignments > VLANs**.
2. Clicar em **Add** e criar as seguintes entradas (Lan Interface: `vtnet1`):

| VLAN Tag | Description   | Utilização Prevista             |
| :------: | :------------ | :------------------------------ |
|  **20**  | `TRUSTED`     | PCs, Portáteis                  |
|  **30**  | `IOT_MEDIA`   | TV Box, Smart Home              |
|  **40**  | `SERVER_PROD` | Docker (Vaultwarden, Nextcloud) |
|  **50**  | `LAB_TEST`    | Win Server, RHEL, Zabbix        |

### 5.2 Atribuir e Configurar Interfaces

1. Navegar para **Interfaces > Assignments**.
2. No dropdown *Available network ports*, selecionar a VLAN (ex: `VLAN 20 on vtnet1`) e clicar em **Add**.
3. Clicar no nome da nova interface (ex: `OPT1`) para editar.
4. Preencher os campos conforme a tabela abaixo:
    * **Enable:** Marcar a checkbox `Enable Interface`.
    * **Description:** Inserir o **Nome Final** (ex: `TRUSTED`).
    * **IPv4 Configuration Type:** Selecionar `Static IPv4`.
    * **IPv4 Address:** Inserir o IP (ex: `10.10.20.1`) e **alterar a máscara para `/24`**.
    * **IPv4 Upstream gateway:** Manter em **`None`** (⚠️ Crítico: Não adicionar gateway!).

| Nome Final (Description) | IPv4 Address | Subnet |
| :--- | :--- | :---: |
| **`TRUSTED`** | `10.10.20.1` | `/24` |
| **`IOT_MEDIA`** | `10.10.30.1` | `/24` |
| **`SERVER_PROD`** | `10.10.40.1` | `/24` |
| **`LAB_TEST`** | `10.10.50.1` | `/24` |

5. Clicar em **Save** e depois **Apply Changes**.
6. Repetir o processo para todas as interfaces da tabela.

### 5.3 Configurar DHCP
1. Navegar para **Services > DHCP Server**.
2. Para cada interface (`TRUSTED`, `IOT_MEDIA`, etc.):
    * **Enable:** `Checked`.
    * **Range:** Definir pool (ex: `.100` a `.200`).
    * **Save**.

---

## 6. Firewall: Matriz de Acesso (Zero Trust)

**Objetivo:** Bloquear tudo por defeito, permitir apenas o necessário.

> [!DANGER] Regra de Ouro (DNS)
> Em VLANs bloqueadas de aceder à Firewall (IoT, Server, Lab), a **Regra nº 1** tem de ser **Permitir DNS (Porta 53)** para o destino "This Firewall". Sem isto, não há navegação.

### 6.1 TRUSTED (VLAN 20)
*Perfil: Power User.*

|  #  | Ação | Proto | Origem  |    Destino    | Porta | Descrição                           |
| :-: | :--: | :---: | :-----: | :-----------: | :---: | :---------------------------------- |
|  1  |  🛑  |  Any  | TRUSTED | IOT_MEDIA net |   *   | Bloquear acesso a IoT (Segurança)   |
|  2  |  ✅   |  Any  | TRUSTED |      Any      |   *   | Permitir Internet e restantes VLANs |

### 6.2 IOT_MEDIA (VLAN 30)
*Perfil: Isolamento Total.*

|  #  | Ação |  Proto  |  Origem   |     Destino     | Porta | Descrição           |
| :-: | :--: | :-----: | :-------: | :-------------: | :---: | :------------------ |
|  1  |  ✅   | TCP/UDP | IOT_MEDIA |  This Firewall  |  53   | **Permitir DNS**    |
|  2  |  🛑  |   Any   | IOT_MEDIA |  This Firewall  |   *   | Bloquear Router     |
|  3  |  🛑  |   Any   | IOT_MEDIA |   TRUSTED net   |   *   | Bloquear PC/Dados   |
|  4  |  🛑  |   Any   | IOT_MEDIA | SERVER_PROD net |   *   | Bloquear Servidores |
|  5  |  🛑  |   Any   | IOT_MEDIA |  LAB_TEST net   |   *   | Bloquear Lab        |
|  6  |  ✅   |   Any   | IOT_MEDIA |       Any       |   *   | Internet Apenas     |

### 6.3 SERVER_PROD (VLAN 40)
*Perfil: Servidor Seguro.*

|  #  | Ação |  Proto  | Origem |    Destino    | Porta | Descrição              |
| :-: | :--: | :-----: | :----: | :-----------: | :---: | :--------------------- |
|  1  |  ✅   | TCP/UDP | SERVER | This Firewall |  53   | **Permitir DNS**       |
|  2  |  🛑  |   Any   | SERVER | This Firewall |   *   | Bloquear Router        |
|  3  |  🛑  |   Any   | SERVER | IOT_MEDIA net |   *   | Bloquear IoT           |
|  4  |  ✅   |   Any   | SERVER |      Any      |   *   | Internet + VLANs 20/50 |

### 6.4 LAB_TEST (VLAN 50)
*Perfil: Sandbox.*

|  #  | Ação |  Proto  | Origem |    Destino    | Porta | Descrição              |
| :-: | :--: | :-----: | :----: | :-----------: | :---: | :--------------------- |
|  1  |  ✅   | TCP/UDP |  LAB   | This Firewall |  53   | **Permitir DNS**       |
|  2  |  🛑  |   Any   |  LAB   | This Firewall |   *   | Bloquear Router        |
|  3  |  🛑  |   Any   |  LAB   | IOT_MEDIA net |   *   | Bloquear IoT           |
|  4  |  ✅   |   Any   |  LAB   |      Any      |   *   | Internet + VLANs 20/40 |

---
## 7. Configuração Switch (TL-SG108E)

**Objetivo:** Fixar IP de gestão, isolar as redes e distribuir VLANs para as portas físicas.

> [!NOTE] Topologia Física (Atualizada)
> * **Porta 1:** Uplink (Liga ao Proxmox/pfSense). Híbrida (Gestão + VLANs).
> * **Portas 2-5:** PCs e Portáteis (VLAN 20).
> * **Portas 6-7:** TV Box, Smart Home(VLAN 30).
> * **Porta 8:** **Gestão Dedicada/Emergência** (Rede 10.10.1.x).

### 7.1 Definir IP Estático (Gestão)
1. Aceder à WebGUI do Switch (IP obtido via DHCP).
2. Ir a **System > IP Setting**:
    * **DHCP Setting:** `Disable`
    * **IP Address:** `10.10.1.2`
    * **Gateway:** `10.10.1.1`
3. Clicar em **Apply** (A sessão cai. Aceder novamente em `http://10.10.1.2`).

### 7.2 Definir VLANs (802.1Q)
1. Ir a **VLAN > 802.1Q VLAN**.
2. **Enable** 802.1Q VLAN Configuration.
3. Ignorar a linha da VLAN 1 (Default).
4. Criar/Editar as restantes VLANs conforme a tabela:

| VLAN ID | Port 1 (Uplink) | Ports 2-5 (Trusted) | Ports 6-7 (IoT) | Port 8 (Mgmt) |
| :---: | :---: | :---: | :---: | :---: |
| **1** | **(Ignorar)** | (Ignorar) | (Ignorar) | (Ignorar) |
| **20** | **Tagged** | **Untagged** | Not Member | Not Member |
| **30** | **Tagged** | Not Member | **Untagged** | Not Member |
| **40** | **Tagged** | Not Member | Not Member | Not Member |
| **50** | **Tagged** | Not Member | Not Member | Not Member |

*Nota: As VLANs 40 e 50 são criadas e marcadas na Porta 1 para manter a consistência do Trunk, mesmo que não tenham portas físicas atribuídas.*

### 7.3 Configurar PVID (Port VLAN ID)
**PASSO CRÍTICO:** É aqui que o isolamento acontece realmente, anulando a configuração da VLAN 1.

1. Ir a **VLAN > 802.1Q VLAN PVID Setting**.
2. Configurar rigorosamente:

| Portas | PVID | Resultado |
| :--- | :--: | :--- |
| **Porta 1** | `1` | Gestão nativa. |
| **Portas 2-5** | `20` | Força entrada na rede **Trusted**. |
| **Portas 6-7** | `30` | Força entrada na rede **IoT**. |
| **Porta 8** | `1` | Acesso de emergência. |

---
## 8. Notificações (SMTP)

1. Navegar para **System > Advanced > Notifications**.
2. Configurar servidor SMTP (ex: Gmail) e testar envio.

---

## 9. Otimização de Switch (QoS & Flow Control)

**Objetivo:** Garantir prioridade aos pacotes críticos e evitar congestionamento.

1. Aceder a `http://10.10.1.2`.
2. **System > Flow Control:** Verificar se está tudo **OFF**.
3. **QoS > QoS Basic:**
    * **Mode:** `Port Based`.
    * **Priority:**
        * Porta 1 (Router): `Highest`
        * Portas 2-5 (PCs): `Highest`
        * Portas 6-7 (TV): `Lowest`
    * **Apply**.

---

## 10. DNS Seguro (Privacidade & Segurança)
**Objetivo:** Proteger contra spoofing e garantir privacidade DNS (evitando o ISP).

1. Navegar para **System > General Setup**.
2. **DNS Servers:**
    * `1.1.1.1` (Cloudflare - Performance)
    * `9.9.9.9` (Quad9 - Segurança/Blocklist Malware)
3. **DNS Server Override:** `Uncheck` (Forçar o uso dos DNS acima, ignorando o ISP).
4. Navegar para **Services > DNS Resolver**.
5. **Enable DNSSEC:** `Checked` (Valida autenticidade das respostas DNS).
6. **Save**.

> [!SUCCESS] Estado Final
> 
> * **Segurança:** Acessos administrativos bloqueados e contas de serviço criadas.
> * **Infraestrutura:** VLANs configuradas e distribuídas pelo switch físico.
> * **Isolamento:** Regras de Firewall ativas separando IoT, Servidores e Dados Pessoais.
> * **Switch:** QoS ativo para priorizar Gaming e Router.