# Implementação VPN OpenVPN (SSL/TLS)

> [!NOTE]
> **Objetivo**
> 
> Implementar a VPN  mais robusta e compatibilidade universal.
>
> * **Cenário Ideal:** Essencial para quando viajas (Hotéis, Aeroportos) e precisas de garantir que consegues entrar em casa, mesmo que a rede onde estás seja instável ou tente bloquear conexões mais simples.
> 
> * **Segurança:** Configuramos autenticação de nível alto (Certificados + User/Password) para blindar a entrada.

---

## 1. Infraestrutura de Chaves Públicas

A segurança do OpenVPN depende da cadeia de confiança. Vamos criar a Autoridade (CA), o Certificado do Servidor e o Utilizador.

### 1.1 Criar a Autoridade Certificadora (CA)

**Caminho:** `System > Certificates > Authorities > Add`

| Parâmetro | Valor | Motivação Técnica |
| :--- | :--- | :--- |
| **Descriptive name** | `VPN_CA` | Identificação da Autoridade Certificadora. |
| **Method** | Create an internal Certificate Authority | O pfSense gere a própria CA. |
| **Key length** | `4096` | Segurança robusta para a chave raiz. |
| **Digest Algorithm** | `SHA512` | Algoritmo de hash resistente a colisões. |
| **Lifetime (days)** | **3650** | *(Ajustado para 10 Anos)*. **Crítico:** A CA deve durar muito mais que os certificados individuais. |

### 1.2 Criar Certificado do Servidor

**Caminho:** `System > Certificates > Certificates > Add/Sign`

| Parâmetro | Valor | Motivação Técnica |
| :--- | :--- | :--- |
| **Method** | Create an internal certificate | |
| **Descriptive name** | `VPN_Remote_Server` | Identificação do servidor. |
| **Certificate Authority** | `VPN_CA` | Assinado pela CA criada acima. |
| **Key Length** | `4096` | |
| **Digest Algorithm** | `SHA512` | |
| **Lifetime (days)** | `398` | **Compatibilidade:** Máximo aceite por dispositivos Apple/Android modernos. |
| **Common Name** | `vpn-remote-server` | Identidade do servidor na rede. |
| **Certificate Type** | **Server Certificate** | Define o uso correto da chave (EKU). |

### 1.3 Criar Utilizador e Certificado

**Caminho:** `System > User Manager > Add`

1.  **Criar Utilizador:** `ricardo` com password forte.
2.  **Adicionar Certificado:** Editar o utilizador > Secção *User Certificates* > Botão **Add**.

| Parâmetro | Valor | Motivação Técnica |
| :--- | :--- | :--- |
| **Method** | Create an internal certificate | |
| **Descriptive name** | `vpn-user-ricardo` | Identifica o dispositivo do utilizador. |
| **Certificate Authority** | `VPN_CA` | Assinado pela mesma CA. |
| **Key Length** | `4096` | |
| **Lifetime (days)** | `398` | |
| **Common Name:** | `vpn-user-ricardo` | |
| **Certificate Type** | **User Certificate** | Restringe o uso apenas para autenticação de cliente. |

---

## 2. Configuração do Servidor OpenVPN

**Caminho:** `VPN > OpenVPN > Servers > Add`

### 2.1 General & Mode

| Parâmetro | Valor | Motivação Técnica |
| :--- | :--- | :--- |
| **Description** | `VPN_Remote_SSL_TLS` | Nome descritivo. |
| **Server Mode** | `Remote Access (SSL/TLS + User Auth)` | **2FA:** Exige certificado e password. |
| **Backend for auth** | `Local Database` | Usa a base de dados local. |
| **Device Mode** | `tun` | Modo de encaminhamento (Layer 3), ideal para LANs. |

### 2.2 Endpoint (Rede Externa)

| Parâmetro | Valor | Motivação Técnica |
| :--- | :--- | :--- |
| **Protocol** | `UDP` | Melhor performance e recuperação de pacotes. |
| **Interface** | `WAN` | Interface de entrada. |
| **Local Port** | `11300` | **Security by Obscurity:** Evita a porta padrão 1194 para reduzir ataques de bots. |

### 2.3 Cryptographic Settings (Hardening)

| Parâmetro | Valor | Motivação Técnica |
| :--- | :--- | :--- |
| **Use TLS Key** | **Ativado** | Protege o canal de controlo (HMAC). |
| **Auto generate TLS Key** | **Ativado** | Gera a chave estática automaticamente. |
| **Peer Certificate Authority** | `VPN_CA` | Valida clientes contra a nossa CA. |
| **Server Certificate** | `VPN_Remote_Server_Cert` | Identidade do servidor. |
| **DH Parameter Length** | `4096` | Troca de chaves inicial segura (Diffie-Hellman). |
| **Data Encryption Algo.** | `AES-256-GCM` | **Gold Standard:** Rápido e seguro (AEAD). |
| **Fallback Algorithm** | `AES-256-GCM` | Impede downgrade para cifras fracas. |
| **Auth Digest Algorithm** | `SHA512` | Integridade do canal de controlo. |
| **Certificate Depth** | `One` | Aceita apenas certificados emitidos diretamente pela CA. |
| **Strict User-CN Matching** | **Ativar** | Impede que o utilizador X use o certificado do utilizador Y. |
| **Client Cert Key Usage** | **Ativado** | Valida se o certificado é realmente de "Cliente". |

### 2.4 Tunnel Settings (Rede Interna)

| Parâmetro | Valor | Motivação Técnica |
| :--- | :--- | :--- |
| **IPv4 Tunnel Network** | `192.168.113.0/24` | Rede virtual exclusiva para a VPN. |
| **Redirect IPv4 Gateway** | **Desativado** | **Split Tunnel:** Apenas tráfego da LAN passa na VPN. Internet normal sai direta. |
| **IPv4 Local Network(s)** | `10.10.1.0/24, 10.10.20.0/24, 10.10.40.0/24, 10.10.50.0/24` | Define a LAN acessível aos clientes. |
| **Allow Compression** | `Refuse any non-stub compression` | **Segurança:** Evita vulnerabilidades (ataques VORACLE). |
| **Inter-client commun.** | **Desativado** | Não permite clientes VPN falarem entre si. |
| **Duplicate Connection** | **Desativado** | Evita sessões fantasma ou partilhadas. |

### 2.5 Client Settings & Advanced

* **Dynamic IP:** Ativado (Permite reconexão em 4G/5G).
* **Topology:** `subnet` (Um IP por cliente).
* **Gateway creation:** IPv4 only.
* **Verbosity level:** 3 (Detalhe ideal para logs).

---

## 3. Regras de Firewall

### 3.1 Interface OpenVPN (Tráfego do Túnel)

**Caminho:** `Firewall > Rules > OpenVPN`

> [!IMPORTANT]
> **Ordem das Regras**
> 
> O pfSense processa regras de cima para baixo. Para isolar a rede IoT, a regra de bloqueio deve ficar **acima** da regra de permissão geral.

**Regra 1: Bloquear IoT (Deve ficar no Topo)**

* **Action:** Block
* **Interface:** OpenVPN
* **Address Family:** IPv4
* **Protocol:** Any
* **Source:** Any
* **Destination:** `IoT_VLAN subnets`
* **Description:** Bloquear acesso VPN à IoT

**Regra 2: Permitir Restante (Deve ficar em baixo)**

* **Action:** Pass
* **Interface:** OpenVPN
* **Address Family:** IPv4
* **Protocol:** Any
* **Source:** Any
* **Destination:** Any
* **Description:** Permitir tráfego VPN Geral

### 3.2 Interface WAN

**Caminho:** `Firewall > Rules > WAN > Add`

* **Action:** Pass
* **Interface:** WAN
* **Protocol:** UDP
* **Destination:** WAN Address
* **Destination Port Range:** `11300` (From/To)
* **Description:** Permitir acesso remoto OpenVPN UDP 11300

---

## 4. Exportação do Cliente

**Pré-requisito:** Instalar pacote `openvpn-client-export` em **System > Package Manager**.

**Caminho:** `VPN > OpenVPN > Client Export`

### 4.1 Configuração de Exportação

| Parâmetro                 | Valor              | Motivação Técnica                                                                       |
| :------------------------ | :----------------- | :-------------------------------------------------------------------------------------- |
| **Host Name Resolution**  | `other`            | Permite definir manualmente o endereço de destino.                                      |
| **Host Name**             | `[O TEU DDNS]`     | **Recomendado:** Usar o domínio configurado em `05-pfsense-dynamic-ddns-configuration`. |
| **Verify Server CN**      | `Automatic`        | Validação do certificado do servidor.                                                   |
| **Block Outside DNS**     | **Ativado**        | Previne DNS Leaks (essencial para Windows 10/11).                                       |
| **Legacy Client**         | **Desativado**     | Não suportamos clientes obsoletos.                                                      |
| **Silent Installer**      | **Ativado**        | Instalação automática no Windows.                                                       |
| **Password Protect Cert** | **Ativado**        | Protege o ficheiro exportado com senha extra (2FA).                                     |
| **PKCS#12 Encryption**    | `AES-256 + SHA256` | Cifragem forte do ficheiro de configuração.                                             |

### 4.2 Download (Secção OpenVPN Clients)

Localizar o utilizador `ricardo` e escolher:
* **Inline Configuration (.ovpn):** Para Android / iOS / Linux / macOS (Tunnelblick).
* **Windows Installer (.msi):** Para Windows (inclui o software oficial + perfil).