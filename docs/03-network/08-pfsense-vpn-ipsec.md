# Implementação VPN IPsec IKEv2

> [!NOTE]
> **Objetivo**
> 
> Escolher esta opção apenas se for preciso de ligar dispositivos onde **não se pode instalar software** (computadores da empresa bloqueados) ou se preferires usar os clientes integrados do iOS/Windows.
>
> * **Vantagem Principal:** Funciona sem Apps extra (Nativo).
> * **Performance:** Excelente velocidade (aceleração por hardware AES-NI).
> * **Segurança:** Autenticação forte (Certificado de Servidor + Utilizador/Password).

---

## 1. Infraestrutura de Chaves (PKI)

O IPsec IKEv2 é extremamente rigoroso com a validação de identidade. Vamos reutilizar a CA do OpenVPN, mas criar um certificado de servidor específico com parâmetros SAN (*Subject Alternative Names*).

### 1.1 Criar Certificado do Servidor

**Caminho:** `System > Certificates > Certificates > Add/Sign`

| Parâmetro                 | Valor Recomendado                             | Explicação                                                                          |
| :------------------------ | :-------------------------------------------- | :---------------------------------------------------------------------------------- |
| **Method**                | Create an internal certificate                | Cria um certificado novo localmente.                                                |
| **Descriptive name**      | `IPsec_Server_Cert`                           | Nome para identificar no pfSense.                                                   |
| **Certificate Authority** | `VPN_CA`                                      | **Importante:** Usa a mesma CA que foi usada no OpenVPN para manter a confiança.    |
| **Key length**            | `4096`                                        | Nível de encriptação da chave (Alta segurança).                                     |
| **Digest Algorithm**      | `SHA512`                                      |                                                                                     |
| **Lifetime (days)**       | `398`                                         | **Crítico:** Máximo de dias (aprox. 13 meses).                                      |
| **Common Name (CN)**      | `[O TEU DDNS]`                                | O endereço principal da VPN (ex: `vpn.oteudominio.com`).                            |
| **Alternative Names**     | **Type:** `FQDN or Hostname` → `[O TEU DDNS]` | **Obrigatório:** Repete o endereço aqui. Sem isto, o iOS/Windows rejeita a ligação. |
| **Certificate Type**      | **Server Certificate**                        | Indica que este certificado serve para identificar um Servidor.                     |


---

## 2. Configuração Mobile Clients

Definir o endereçamento IP virtual e o método de autenticação dos utilizadores.

**Caminho:** `VPN > IPsec > Mobile Clients`

### 2.1 Configuração Geral

| Parâmetro                | Valor                   | Explicação Simples                                                        |
| :----------------------- | :---------------------- | :------------------------------------------------------------------------ |
| **Enable IPsec Mobile**  | **Checked**             | Liga o serviço de acesso remoto.                                          |
| **User Authentication**  | `Local Database`        | Usa a lista de utilizadores criada no pfSense.                            |
| **Group Authentication** | `System`                | Permite verificar permissões de grupos.                                   |
| **Virtual Address Pool** | `Checked`               | Ativa a atribuição de IPs aos clientes.                                   |
| **Network Address**      | `192.168.115.0` / `24`  | **Rede VPN:** Uma rede exclusiva para estes clientes (não usar a da LAN). |
| **DNS Servers**          | `Checked` → `10.10.1.1` | Entrega o IP do pfSense como DNS para resolver nomes locais.              |

*Clicar em **Save** e depois **Apply Changes**.*

---

## 3. Configuração Fase 1 (IKEv2 - Control Plane)

Estabelece o canal seguro de controlo e negociação.

**Caminho:** `VPN > IPsec > Tunnels > Add P1`

### 3.1 General Information

| Parâmetro                | Valor                       | Explicação Simples                                                       |
| ------------------------ | --------------------------- | ------------------------------------------------------------------------ |
| **Description**          | `IPsec_Remote_Access_IKEv2` | Nome para identificares esta VPN na lista.                               |
| **Key Exchange Version** | `IKEv2`                     | Protocolo moderno (mais rápido e recupera melhor a ligação se falhar).   |
| **Internet Protocol**    | `IPv4`                      | Tipo de endereçamento padrão da internet.                                |
| **Interface**            | `WAN`                       | A porta onde a internet chega ao router (onde o servidor vai "escutar"). |

### 3.2 Phase 1 Proposal (Authentication)


| Parâmetro           | Valor                                          | Explicação Simples                                                                                          |
| ------------------- | ---------------------------------------------- | ----------------------------------------------------------------------------------------------------------- |
| **Auth Method**     | `EAP-MSCHAPv2`                                 | O método padrão de "Utilizador e Password" que o Windows e Apple usam nativamente.                          |
| **My Identifier**   | `Fully qualified domain name` → `[O TEU DDNS]` | A "Identidade" oficial do servidor. **Tem** de ser igual ao endereço no Certificado para o cliente confiar. |
| **Peer Identifier** | `Any`                                          | Aceita ligações vindas de qualquer lugar.                                                                   |
| **My Certificate**  | `IPsec_Server_Cert`                            | O ficheiro de segurança que criámos no Passo 1 para provar quem somos.                                      |

### 3.3 Phase 1 Proposal (Algorithms)


|Parâmetro|Valor|Explicação Simples|
|---|---|---|
|**Encryption Algorithm**|`AES 256-GCM`|Encriptação forte para proteger o canal de negociação inicial.|
|**Key length**|`128 bits`|Nível de complexidade da chave (128 bits é o padrão rápido e seguro para GCM).|
|**Hash Algorithm**|`SHA256`|Garante que os dados de controlo não foram alterados no caminho.|
|**DH Group**|`14 (2048 bit)`|Define a matemática da troca de chaves. O Grupo 14 é o padrão mais compatível.|
|**Lifetime**|`28800` (8h)|O túnel de controlo reinicia a segurança a cada 8 horas.|

*Clicar em **Save** e **Apply**.*

---

## 4. Configuração Fase 2 (ESP - Data Plane)

Define como os dados do utilizador são encriptados.

**Caminho:** Dentro da Fase 1, clicar em **Show Phase 2 Entries** > **Add P2**.

### 4.1 General Information


|Parâmetro|Valor|Explicação Simples|
|---|---|---|
|**Description**|`IPsec_Phase2_Data`|Nome interno para identificar esta configuração.|
|**Mode**|`Tunnel IPv4`|O modo padrão para VPNs de acesso remoto.|
|**Local Network**|`Network` → `0.0.0.0/0`|Diz ao cliente para "enviar tudo pela VPN". Evita problemas de rotas e DNS no Windows.|

### 4.2 Phase 2 Proposal (Algorithms)


| Parâmetro                 | Valor                        | Explicação Simples                                                                                                   |
| ------------------------- | ---------------------------- | -------------------------------------------------------------------------------------------------------------------- |
| **Protocol**              | `ESP`                        | O protocolo que transporta os dados encriptados.                                                                     |
| **Encryption Algorithms** | `AES 128 GCM` (**128 bits**) | **Rápido e Eficiente:** O GCM faz a encriptação e verificação ao mesmo tempo. 128 bits poupa bateria nos telemóveis. |
| **PFS Key Group**         | `Off`                        | **Importante:** Mantém desligado. O iOS e Windows tendem a perder a ligação se tentarem renegociar isto.             |
| **Lifetime**              | `3600` (1h)                  | As chaves de encriptação dos dados mudam a cada hora para maior segurança.                                           |

---

## 5. Regras de Firewall

O IPsec utiliza múltiplas portas (UDP 500/4500) e um protocolo (ESP).

### 5.1 Interface IPsec (Tráfego Interno)

**Caminho:** `Firewall > Rules > IPsec`

> [!IMPORTANT]
> **Ordem das Regras**
> 
> Tal como no OpenVPN, bloquear IoT primeiro.

**Regra 1: Bloquear IoT (Topo)**
* **Action:** Block
* **Source:** Any
* **Destination:** `IoT_VLAN Subnets`
* **Description:** Bloquear IPsec à IoT

**Regra 2: Permitir Acesso (Fundo)**
* **Action:** Pass
* **Source:** Any
* **Destination:** Any (Ou restringir a `Server_VLAN` + `Mgmt_VLAN`)
* **Description:** Permitir tráfego IPsec Geral

### 5.2 Interface WAN (Entrada da Ligação)

**Caminho:** `Firewall > Rules > WAN`

Necessário abrir portas para negociação (ISAKMP) e travessia de NAT (NAT-T).

| Ação | Protocolo | Destino | Porta | Descrição |
| :--- | :--- | :--- | :--- | :--- |
| **Pass** | **UDP** | WAN Address | `500` | **ISAKMP:** Negociação de chaves (IKE). |
| **Pass** | **UDP** | WAN Address | `4500` | **NAT-T:** Encapsulamento se cliente estiver atrás de NAT (4G/WiFi). |
| **Pass** | **ESP** | WAN Address | `*` | **ESP:** Protocolo 50 (Transporte de dados diretos). |

---

## 6. Gestão de Utilizadores (Auth Workaround)

> [!IMPORTANT]
> **Correção de Bug de Sincronização**
> 
> Em algumas instalações do pfSense, os utilizadores criados no *User Manager* não são exportados corretamente para o ficheiro de configuração do IPsec (`swanctl.conf`). Para garantir o acesso, a credencial deve ser criada diretamente na tabela de chaves.

### 6.1 Criar Credencial EAP Manualmente

**Caminho:** `VPN > IPsec > Pre-Shared Keys > Add`

1.  **Identifier:** Define o username (ex: `ricardo`).
2.  **Secret Type:** Seleciona obrigatoriamente **`EAP`**.
3.  **Pre-Shared Key:** Define a password de acesso.
4.  **Identifier Type:** Seleciona **`any`** (para evitar erros de correspondência de ID).
5.  **Save** e **Apply Changes**.
---

## 7. Configuração no Cliente (Exemplo: iOS)

O iOS possui a implementação mais robusta e estrita do protocolo IKEv2. Se funcionar aqui, a infraestrutura está validada.

### Passo A: Importar Certificado

O dispositivo TEM de confiar na CA do pfSense.

1.  **Exportar:** No pfSense (`System > Cert Manager > CAs`), exportar apenas o Certificado (`.crt`) da `VPN_CA`.
2.  **Transferir:** Enviar para o iPhone via AirDrop, iCloud Drive ou Email.
3.  **Instalar Perfil:**
    * Tocar no ficheiro `.crt`. Ir a `Definições > Perfil Descarregado` e clicar em **Instalar**.
4.  **Ativar Confiança (Crítico):**
    * Ir a `Definições > Geral > Informações > Definições de confiança de certificados`.
    * Ativar o interruptor para a `VPN_CA`.

### Passo B: Configurar a VPN

1.  Ir a `Definições > VPN e Gestão de Dispositivos > VPN > Adicionar Configuração`.
2.  Preencher os parâmetros:
    * **Tipo:** `IKEv2`
    * **Descrição:** `VPN Casa`
    * **Servidor:** `[O TEU DDNS]` (Ex: `vpn.oteudominio.com`)
    * **ID Remoto:** `[O TEU DDNS]` (Tem de ser igual ao Servidor).
    * **ID Local:** *(Deixar vazio)*
    * **Autenticação:** `Nome de utilizador`
    * **Nome de utilizador:** `ricardo`
    * **Palavra-passe:** *(A password definida no Passo 461)*
    * **Proxy:** `Desligado`
3.  Clicar em **OK** e ligar o interruptor.