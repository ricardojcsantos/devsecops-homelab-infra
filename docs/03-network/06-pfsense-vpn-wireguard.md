# 05. Implementação VPN WireGuard

>[!NOTE]
> **Objetivo**
> 
> Implementar a VPN mais rápida e leve do mercado. Escolhe esta opção se queres **velocidade máxima** para ver filmes, transferir ficheiros grandes ou se usas muito o telemóvel em redes móveis (4G/5G).
>
> * **Pontos Fortes:** Conexão instantânea, gasta pouca bateria e aguenta trocas de rede (Wi-Fi <-> 4G) sem cair.
> 
> * **Segurança:** Configuramos uma porta "escondida" (`11200`) para evitar deteção por scanners na Internet.

---

## 1. Instalação e Preparação

Ao contrário do OpenVPN, o WireGuard no pfSense (CE) é um pacote adicional que corre no espaço do Kernel para performance máxima.

### 1.1 Instalar o Pacote

**Caminho:** `System > Package Manager > Available Packages`

1.  **Pesquisar:** `wireguard`
2.  **Ação:** Clicar em **Install** e aguardar a confirmação de sucesso.

### 1.2 Ativar o Serviço

**Caminho:** `VPN > WireGuard > Settings`

| Parâmetro | Valor | Motivação Técnica |
| :--- | :--- | :--- |
| **Enable WireGuard** | **Checked** | Inicializa a interface virtual `tun_wg`. |
| **Keep Configuration** | **Checked** | Garante persistência de dados em caso de reinstalação do pacote. |

---

## 2. Criação do Túnel (Servidor)

No WireGuard, o servidor é tecnicamente apenas um "Peer" que escuta uma porta fixa.

**Caminho:** `VPN > WireGuard > Tunnels > Add Tunnel`

| Parâmetro             | Valor Personalizado       | Motivação Técnica                                                                      |
| :-------------------- | :------------------------ | :------------------------------------------------------------------------------------- |
| **Description**       | `WireGuard_Remote_Access` | Identificação.                                                                         |
| **Listen Port**       | `11200`                   | **Ofuscação:** O padrão é 51820. Mudar para 11200 evita scanners de botnets genéricos. |
| **Interface Keys**    | **Generate**              | Gera o par de chaves (Privada/Pública) do Servidor.                                    |
| **Interface Address** | `192.168.112.1` / `24`    | **Gateway do Túnel:** Define o IP do pfSense dentro da VPN.                            |

> [!IMPORTANT]
> **Nota Técnica**
> 
> Clicar em **Save Tunnel**. A "Public Key" do servidor será necessária mais tarde.

---

## 3. Atribuição de Interface

Para aplicar regras de Firewall granulares e NAT, transformamos o túnel numa Interface lógica.

1.  **Ir a:** `Interfaces > Assignments`.
2.  **Available network ports:** Selecionar `tun_wg0` e clicar em **Add**.
3.  Clicar no nome da nova interface (ex: `OPT1`) para editar:
    * **Enable:** Checked.
    * **Description:** `VPN_WIREGUARD`.
    * **IPv4 Configuration:** `Static IPv4`.
    * **IPv4 Address:** `192.168.112.1` / `24` (Replicar o IP do túnel para garantir rotas no Kernel).
    * **Upstream Gateway:** *None* (Deixar vazio).
    * **Save & Apply.**

---

## 4. Regras de Firewall

É preciso abrir a porta na WAN e permitir o tráfego dentro do túnel.

### 4.1 Permitir Entrada (WAN)

**Caminho:** `Firewall > Rules > WAN > Add`

| Parâmetro                  | Valor                         | Notas                                      |
| :------------------------- | :---------------------------- | :----------------------------------------- |
| **Action**                 | `Pass`                        | Permitir tráfego.                          |
| **Protocol**               | `UDP`                         | O WireGuard é exclusivamente UDP.          |
| **Source**                 | `Any`                         |                                            |
| **Destination**            | `WAN Address`                 |                                            |
| **Destination Port Range** | `11200`                       | A porta personalizada definida no Passo 2. |
| **Description**            | `Allow WireGuard VPN Connect` |                                            |

### 4.2 Regras de Firewall (Segmentação e Segurança)

A ordem das regras é crítica: o pfSense processa de cima para baixo. **Primeiro bloqueamos** o que é perigoso (IoT) e **depois permitimos** o resto.

#### A. Regra 1: Bloquear Acesso à IoT (Topo da Lista)

Esta regra impede que dispositivos ligados via VPN acedam a dispositivos inseguros (Câmaras, Smart Home, Sensores).

**Caminho:** `Firewall > Rules > VPN_WIREGUARD > Add` (Usar a seta ↑ para garantir que fica no topo)

| Parâmetro          | Valor a Preencher  | Notas Técnicas                                  |
| :----------------- | :----------------- | :---------------------------------------------- |
| **Action**         | `Block`            | Bloqueia o tráfego silenciosamente.             |
| **Interface**      | `VPN_WIREGUARD`    | A interface criada no passo 3.                  |
| **Address Family** | `IPv4`             |                                                 |
| **Protocol**       | `Any`              | Abrange TCP, UDP e ICMP.                        |
| **Source**         | `Any`              | Qualquer dispositivo vindo da VPN.              |
| **Destination**    | `IOT_MEDIA net`    | (Ou selecionar a rede/Alias da VLAN IoT).       |
| **Description**    | `Block VPN to IoT` | **Segurança:** Isolar dispositivos vulneráveis. |

#### B. Regra 2: Permitir Restante Tráfego (LAN / Internet)

Esta regra permite o acesso aos servidores, computadores de gestão e navegação segura na Internet (Full Tunnel).

**Caminho:** `Firewall > Rules > VPN_WIREGUARD > Add` (Usar a seta ↓ para colocar abaixo da regra de bloqueio)

| Parâmetro          | Valor a Preencher          | Notas Técnicas                                |
| :----------------- | :------------------------- | :-------------------------------------------- |
| **Action**         | `Pass`                     | Permitir tráfego.                             |
| **Interface**      | `VPN_WIREGUARD`            |                                               |
| **Address Family** | `IPv4`                     |                                               |
| **Protocol**       | `Any`                      |                                               |
| **Source**         | `Any`                      |                                               |
| **Destination**    | `Any`                      | Permite acesso à LAN e saída para a Internet. |
| **Description**    | `Allow VPN Traffic (Safe)` | Apenas passa o que não foi bloqueado acima.   |

---

## 5. Configuração de Peers 

Para máxima compatibilidade e segurança, geramos as chaves manualmente via linha de comandos para garantir que funcionam em qualquer cliente (Windows/Mobile).

### 5.1 Gerar o Par de Chaves do Cliente

1.  No pfSense, navegar até **`Diagnostics > Command Prompt`**.
2.  Na caixa **Execute Shell Command**, colar e executar:

```bash
priv=$(wg genkey); pub=$(echo "$priv" | wg pubkey); echo "Private Key (Copiar para Cliente): $priv"; echo "Public Key (Copiar para Peer do pfSense): $pub"
```

3.  O resultado mostrará duas linhas de chaves.
    * **Linha 1 (Private Key):** Copiar para um Bloco de Notas (será usada no ficheiro do cliente).
    * **Linha 2 (Public Key):** Copiar para usar no passo 5.2.

### 5.2 Registar o Peer no pfSense

**Caminho:** `VPN > WireGuard > Peers > Add Peer`

| Parâmetro            | Valor                  | Motivação Técnica                                                      |
| :------------------- | :--------------------- | :--------------------------------------------------------------------- |
| **Enable**           | **Checked**            |                                                                        |
| **Tunnel**           | `tun_wg0`              | Associação ao túnel criado.                                            |
| **Description**      | `iPhone_Ricardo`       | Identificação do dispositivo.                                          |
| **Dynamic Endpoint** | **Checked**            | Permite que o IP público do cliente mude.                              |
| **Keepalive**        | `25`                   | **Anti-NAT:** Força tráfego a cada 25s para manter a porta UDP aberta. |
| **Public Key**       | **[COLAR AQUI]**       | Cola a **Public Key** (Linha 2) gerada no passo 5.1.                   |
| **Pre-shared Key**   | **Generate**           | Gera uma chave extra aqui. **Copia-a** para o Bloco de Notas também.   |
| **Allowed IPs**      | `192.168.112.2` / `32` | **ACL Estrita:** Este Peer *só* pode usar este IP.                     |

**Clicar em Save Peer.**

---

## 6. Configuração nos Clientes (Windows e Mobile)

É preciso criar um ficheiro de configuração universal (`.conf`) que pode ser importado em qualquer dispositivo.

### 6.1 Criar o Ficheiro de Configuração

No computador, criar um ficheiro de texto chamado `vpn_wireguard.conf` e cola o seguinte conteúdo.

> [!WARNING]
> **Ação Necessária**
> 
> Substitui os valores entre `< >` pelos dados reais que guardaste nos passos anteriores.

```ini
[Interface]
# A Chave Privada que geraste no terminal (Passo 5.1 - Linha 1)
PrivateKey = <A_TUA_PRIVATE_KEY_DO_PASSO_5.1>
Address = 192.168.112.2/24
DNS = 192.168.112.1

[Peer]
# A Chave Pública do SERVIDOR (Ver em VPN > WireGuard > Tunnels)
PublicKey = <A_PUBLIC_KEY_DO_TUNNEL_PFSENSE>
# A Chave PSK gerada no botão "Generate" dentro do Peer settings
PresharedKey = <A_TUA_PRE_SHARED_KEY>
AllowedIPs = 0.0.0.0/0
# O teu IP Público ou Domínio DDNS + Porta
Endpoint = <SEU_DDNS_OU_IP_PUBLICO>:11200
PersistentKeepalive = 25
```


> [!IMPORTANT]
> **⚠️ Regra de Ouro: Um Peer = Um Procedimento**
> 
> **Não podes reutilizar este ficheiro noutro telemóvel ou PC.** O WireGuard exige **chaves únicas** e **IPs únicos** para cada dispositivo.
>
> **Para adicionar um segundo dispositivo (ex: Portátil):**
> 
> 1. Repetir o passo **5.1** (Gerar um **novo** par de chaves).
> 2. Repetir o passo **5.2** (Registar no pfSense), mas alterar o IP para o seguinte livre (ex: `192.168.112.3`).
> 3. Criar um novo ficheiro `.conf` com as novas chaves e o novo IP.

### 6.2 Opção A: Windows

1.  **Instalar:** Fazer download e instalar o cliente oficial **WireGuard para Windows**.
2.  **Importar:** Clicar no botão **"Import tunnel(s) from file"**.
3.  **Selecionar:** Escolher o ficheiro `vpn_wireguard.conf`.
4.  **Ligar:** Clicar no botão **Activate**.

### 6.3 Opção B: Linux (Gnome/NetworkManager)

O importador gráfico do Gnome por vezes falha com ficheiros `.conf`. O método infalível é via terminal:

1.  Abrir o terminal na pasta do ficheiro.
2.  Executar o comando:

```bash
   sudo nmcli connection import type wireguard file vpn_wireguard.conf
```

3.  A VPN aparecerá automaticamente nas Definições de Rede.

### 6.4 Opção C: iPhone/Android

1.  **Transferir:** Enviar o ficheiro `vpn_wireguard.conf` para o telemóvel (via Email, iCloud Drive ou AirDrop).
2.  **Abrir:** No telemóvel, tocar no ficheiro e escolher a opção **"Abrir com WireGuard"**.
3.  **Importar:** A App aceita a configuração automaticamente.
4.  **Ligar:** Tocar no interruptor para conectar.

---

## 7. Verificação e Testes

Para garantir que o serviço está operacional:

1.  **Status do Servidor (pfSense):**
    * Ir a `Status > WireGuard`.
    * Verificar se a coluna **Handshake** mostra um valor recente (ex: "2 minutes ago"). *Se estiver vazio, a ligação falhou.*

2.  **Teste de Conectividade:**
    * Com a VPN ligada, tentar aceder ao pfSense: `https://10.10.1.1`.
    * Verificar o IP público (ex: site `whatismyip.com`).
        * *Resultado Esperado:* Deve mostrar o **IP de Casa**.