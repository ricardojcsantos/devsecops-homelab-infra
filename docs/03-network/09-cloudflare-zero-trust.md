# Implementação Cloudflare Zero Trust (WARP)

> [!NOTE]
> **Objetivo Estratégico**
> 
> Implementar a solução de acesso mais moderna e segura do mercado.
>
> * **Zero Portas:** A rede não precisa de abrir portas no router. O túnel funciona de "dentro para fora".
> * **Identidade:** O acesso é concedido com base em **quem tu és** (login da organização), e não apenas porque tens a chave da VPN.
> * **Performance:** Utiliza a rede global da Cloudflare para acelerar a ligação, muitas vezes mais rápida que uma VPN tradicional.

---

## 0. Setup Inicial (Conta e Zero Trust)

Antes de começar a configuração, é necessário criar a organização na Cloudflare.

1.  **Criação de Conta Global:**
    * Aceder a [dash.cloudflare.com/sign-up](https://dash.cloudflare.com/sign-up).
    * Criar uma conta.
    * Validar o email recebido no email (Passo obrigatório).

2.  **Ativação do Zero Trust:**
    * No menu lateral esquerdo do Dashboard principal, clicar em **Zero Trust**.
    * Irá iniciar um *wizard* de configuração independente.

3.  **Definição da Equipa (Team Name):**
    * Escolher um nome único para a organização (ex: `<nome-da-tua-org>`).
    * **Importante:** Este nome define o URL de autenticação (`<nome>.cloudflareaccess.com`) e será solicitado obrigatoriamente no login do Agente WARP.

4.  **Seleção de Plano:**
    * Selecionar o plano **Zero Trust Free**.
    * Permite até 50 utilizadores gratuitos e inclui todas as funcionalidades necessárias (Gateway, Access, Tunnels).
    * *Nota: Pode ser necessário associar um método de pagamento (Cartão/PayPal) apenas para validação de identidade, mesmo sem cobrança.*

---

## 1. Arquitetura da Solução

* **Gateway:** Servidor pfSense (existente).
* **Connector:** VM Ubuntu Server dedicada a correr o daemon `cloudflared`.
* **Clientes:** Dispositivos com agente Cloudflare WARP.
* **Control Plane:** Dashboard Cloudflare Zero Trust (políticas, rotas e logs).


---

## 2. Especificações da VM

Como este serviço atua apenas como *tunnel gateway*, não requer muitos recursos de computação.

### 2.1 Requisitos de Hardware

* **OS:** Ubuntu Server 22.04 LTS ou 24.04 LTS (Instalação Minimal).
* **vCPU:** 1 Core.
* **RAM:** 512MB ou 1GB (Recomendado).
* **Disk:** 8GB ou 10GB (Suficiente para OS + Logs).
* **Network:** IP Fixo atribuído (Manual ou DHCP Reservation).

### 2.2 Configuração de Rede (Netplan)

Editar o ficheiro de configuração para fixar o IP (ex: `/etc/netplan/50-cloud-init.yaml`):

```yaml
network:
  version: 2
  ethernets:
    enp6s18: # Confirmar se o nome é este com o comando: ip a
      addresses:
        - 10.10.40.253/24
      nameservers:
        addresses:
          - 10.10.40.1  # Primário (pfSense)
          - 1.1.1.1     # Secundário (Backup Cloudflare)
      routes:
        - to: default
          via: 10.10.40.1
```

Aplicar alterações:

```bash
sudo netplan apply
```

---

## 3. Instalação e Autenticação

### 3.1 Instalar o cloudflared

Descarregar e instalar o pacote `.deb` (verificar arquitetura AMD64 vs ARM64):

```bash
curl -L https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb -o cloudflared.deb 
sudo dpkg -i cloudflared.deb
```

### 3.2 Autenticar

Este comando vai gerar um URL. Abrir esse URL no browser para autorizar o túnel na sua conta Cloudflare.

```bash
cloudflared tunnel login
```


> [!NOTE]
> **Certificado**
> 
> O certificado será guardado automaticamente em `~/.cloudflared/cert.pem`.

### 3.3 Organizar Certificados (Boas Práticas)

Mover o certificado para a diretoria do sistema para maior segurança:

```bash
# Cria a diretoria de configuração do sistema (se ainda não existir)
sudo mkdir -p /etc/cloudflared

# Move o certificado gerado na home do utilizador para a diretoria do sistema
sudo mv ~/.cloudflared/cert.pem /etc/cloudflared/

# Define o utilizador e grupo 'root' como proprietários do ficheiro (segurança)
sudo chown root:root /etc/cloudflared/cert.pem

# Restringe as permissões: apenas o root pode ler e escrever (rw-------)
sudo chmod 600 /etc/cloudflared/cert.pem
```

---

## 4. Criação e Configuração do Túnel

### 4.1 Criar o Túnel

Substituir `home-gateway` pelo nome que deseja dar ao túnel.

```bash
# Cria um novo túnel chamado 'home-gateway' e gera o ficheiro de credenciais (JSON) associado
cloudflared tunnel create home-gateway
```

> [!IMPORTANT]
> **Guardar o UUID**
> 
> O comando acima irá devolver um **UUID**. Anote-o.
> Será criado automaticamente um ficheiro JSON em `/etc/cloudflared/<UUID>.json`.

Ajustar permissões do ficheiro JSON gerado:

```bash
# Define o utilizador e grupo 'root' como proprietários do ficheiro de credenciais
sudo chown root:root /etc/cloudflared/*.json

# Restringe as permissões: apenas o root pode ler e escrever (segurança crítica)
sudo chmod 600 /etc/cloudflared/*.json
```

### 4.2 Criar Ficheiro de Configuração (config.yml)

Criar o ficheiro `/etc/cloudflared/config.yml`.

**Nota:** Usar o UUID no campo `tunnel`.

```bash
sudo nano /etc/cloudflared/config.yml
```

Cole o seguinte conteúdo, substituindo `<UUID_DO_TUNEL>` pelo ID real:

``` yml
# Identificador único do túnel (UUID gerado no passo anterior)
tunnel: <UUID_DO_TUNEL>

# Caminho absoluto para o ficheiro de credenciais do túnel
credentials-file: /etc/cloudflared/<UUID_DO_TUNEL>.json

# Ativa o encaminhamento de tráfego de rede (permite o modo VPN/WARP)
warp-routing:
  enabled: true

# Regras de entrada (Ingress Rules)
ingress:
  # Como este túnel serve apenas para WARP (rede privada),
  # definimos um serviço padrão que responde 404 a pedidos HTTP diretos
  - service: http_status:404
```

---

## 5. Rotas e Serviço 

### 5.1 Adicionar Rotas IP (Essencial)

Como estamos a usar configuração local, temos de dizer ao Cloudflare que este túnel é responsável por estas subnets.

```bash
# Rede de Gestão (LAN - pfSense, Switches, APs)
cloudflared tunnel route ip add 10.10.1.0/24 home-gateway

# Rede de Confiança (PCs, Impressoras)
cloudflared tunnel route ip add 10.10.20.0/24 home-gateway

# Rede de Servidores (Onde estão as outras VMs)
cloudflared tunnel route ip add 10.10.40.0/24 home-gateway

# Rede de Testes (VMs Lab)
cloudflared tunnel route ip add 10.10.50.0/24 home-gateway
```

> [!TIP]
> **Porquê adicionar a rede 10.10.40.0/24?**
> 
> Pode parecer redundante adicionar a rede onde o próprio túnel reside, mas é **obrigatório**.
>
> * **O motivo:** O Cliente WARP (no teu portátil/telemóvel) não "adivinha" a topologia da tua rede.
> * **A lógica:** Sem este comando, quando tentares aceder a outra VM na rede `40` (ex: Home Assistant), o WARP enviará o pedido para a Internet pública (onde o IP privado `10.x.x.x` não existe). Ao adicionar a rota, forçamos esse tráfego a entrar no túnel.

> [!NOTE]
> **Verificação**
> 
> Pode-se verificar as rotas ativas com: `cloudflared tunnel route ip show`

### 5.2 Instalar Serviço

Para garantir que o túnel arranca automaticamente com a VM, apontando para o ficheiro de configuração correto.

```bash
#Instalar o serviço (ele vai ler automaticamente o /etc/cloudflared/config.yml)
sudo cloudflared service install
```

Ativar e verificar o serviço:

```bash
# Recarrega o gestor de serviços para reconhecer a nova unidade criada
sudo systemctl daemon-reload

# Ativa o serviço para iniciar automaticamente no arranque do sistema
sudo systemctl enable cloudflared

# Reinicia o serviço para garantir que carrega a configuração mais recente
sudo systemctl restart cloudflared

# Verifica o estado do serviço (deve aparecer como "active (running)")
sudo systemctl status cloudflared
```

---

## 6. Configuração de Routing (Linux)

Para que a VM funcione como um Router e encaminhe o tráfego do túnel para a rede interna, é obrigatório ativar o *IP Forwarding*.

### 6.1 Ativar IP Forwarding 

Este passo altera o Kernel do Linux para permitir a passagem de pacotes entre interfaces.

```bash
# 1. Ativar imediatamente na sessão atual
sudo sysctl -w net.ipv4.ip_forward=1

# 2. Tornar a configuração permanente (sobrevive ao reboot)
echo "net.ipv4.ip_forward = 1" | sudo tee -a /etc/sysctl.conf
```

---

## 7. Ajustes de Firewall (pfSense)

> [!NOTE]
> **Execução Condicional**
> 
> Este passo é **obrigatório apenas se** existirem regras de Hardening que bloqueiem o acesso à gestão (`This Firewall`) a partir de outras VLANs.
> Se a política da firewall for permissiva ("Any/Any"), este passo pode ser ignorado.

### 7.1 Criar Regra de Exceção

Se o acesso ao WebGUI (`10.10.40.1` ou `10.10.1.1`) falhar via túnel, é preciso adicionar uma regra explícita no **TOPO** da lista de regras da interface.

| Parâmetro       | Definição                                               |
| :-------------- | :------------------------------------------------------ |
| **Interface**   | `SERVER_PROD` (VLAN 40)                                 |
| **Posição**     | **TOPO** (Obrigatório ficar acima da regra de bloqueio) |
| **Action**      | `Pass`                                                  |
| **Protocol**    | `TCP`                                                   |
| **Source**      | `Address or Alias` → `10.10.40.253` (IP da VM do Túnel) |
| **Destination** | `This Firewall (self)`                                  |
| **Dest. Port**  | `HTTPS (443)`                                           |

> [!IMPORTANT]
> **Ordem das Regras**
> 
> O pfSense processa regras de cima para baixo (**First Match Wins**).
> Se esta regra de permissão ficar **abaixo** da regra "Bloquear Gestão/Router", o tráfego continuará a ser bloqueado.


---

## 8. Configuração Dashboard (Zero Trust)

Aceder ao [Cloudflare One Dashboard](https://one.dash.cloudflare.com/).

### 8.1 Rotas Privadas (Confirmação)

Ir a **Network > Routes**.
* Confirmar se as rotas adicionadas no passo 5.1 aparecem corretamente.

### 8.2 Criação de Perfil Dedicado (Device Profile)

Para evitar alterar o perfil *Default* (que afeta todos os utilizadores), cria-se um perfil específico para Administradores com regras de encaminhamento (Split Tunnel) do tipo **Include**.

1.  Navegar para **Team & Resources > Devices > Device profiles**.
2.  Clicar em **Create new profile**.
3.  Configurar os parâmetros conforme a tabela abaixo:

| Secção | Campo | Valor / Ação |
| :--- | :--- | :--- |
| **Profile Name** | Name | `Admin - Home Lab` (ou descritivo similar) |
| **Rules** | Expression | `User Email` + `matches` + `[O Teu Email]` |
| **Service Mode** | Mode | **Traffic and DNS mode** (Essencial para VPN L3) |
| **Settings** | Lock WARP switch | **OFF** (Permite desligar o cliente para despiste de erros) |
| **Split Tunnels** | Mode | **Include IPs and domains** |

4.  **Configurar Redes (Split Tunnels):**
    * Na secção "Split Tunnels", clicar em **Manage**.
    * Adicionar **apenas** as subnets da infraestrutura interna. O tráfego não listado sairá pela internet local (Direct Breakout).

    * `10.10.1.0/24` (Gestão / LAN)
    * `10.10.20.0/24` (Trusted)
    * `10.10.40.0/24` (Server VLAN)
    * `10.10.50.0/24` (Lab)

5.  Clicar em **Create profile** para finalizar.

> [!NOTE]
> **Aplicação**
> 
> As alterações propagam-se automaticamente. Se o cliente WARP já estiver ligado, desligue e volte a ligar para forçar a atualização das rotas.

### 8.3 Otimização de Protocolo (QUIC)

Para garantir a máxima performance do túnel (menor latência), recomenda-se que o protocolo UDP esteja ativo.

1.  **No Dashboard Cloudflare:**
    * Aceder a **Traffic policies > Traffic settings**.
    * Na secção **Proxy and Inspection settings**, localize a opção "Select protocols to proxy".
    * Certificar de que a opção **UDP (Recommended)** está selecionada.
        * *Nota: O TCP costuma estar ativo e bloqueado por defeito.*

2.  **No pfSense (Verificação):**
    * O túnel conecta-se às portas de saída **UDP 7844**.
    * **Ação:** Como existe uma regra de saída "IPv4 *" (Allow All) na VLAN do servidor (`SERVER_PROD`), o tráfego já está autorizado. **Nenhuma configuração adicional é necessária.**
	    * *Nota:* Apenas em firewalls restritivas (Whitelisting) seria necessário abrir explicitamente a porta `UDP/7844` para a internet.

---

## 9. Políticas de Segurança (Gateway)

Como o tráfego e as consultas DNS dos dispositivos passam pelo Cloudflare Gateway, é possível aplicar regras de filtragem centralizadas para proteger a rede contra ameaças.

### 9.1 Configuração de Filtros DNS

**Caminho:** Aceder a **Traffic policies > Firewall policies** e selecione a aba **DNS**.

Recomenda-se uma abordagem de "Bloqueio de Ameaças" baseada em categorias de segurança da Cloudflare.

| Ordem | Nome da Regra            | Condição (Selector)                                                             | Ação      |
| :---- | :----------------------- | :------------------------------------------------------------------------------ | :-------- |
| **1** | **Whitelist (Opcional)** | `Domain` is in `[exemplo-seguro.com]`                                           | **Allow** |
| **2** | **Bloquear Ameaças**     | `Security Categories` in `[Malware, Phishing, Command & Control, Cryptomining]` | **Block** |
| **3** | **Bloquear Tracking**    | `Privacy Categories` in `[Direct Marketing, Spyware]`                           | **Block** |

> [!TIP]
> **Ordem de Processamento**
> 
> As regras são processadas de cima para baixo. Coloque sempre as regras de permissão (**Allow**) no topo (ex: para desbloquear um falso positivo) e as regras de bloqueio (**Block**) logo a seguir.


---

## 10. Cliente WARP (Utilização)

A configuração de rotas e segurança é empurrada automaticamente pelo perfil. No lado do cliente, o processo é puramente de autenticação.

1.  **Instalar:** Baixar e instalar o agente **Cloudflare WARP** (PC ou Telemóvel).
2.  **Registar:**
    * Ir a **Preferences > Account > Login with Cloudflare Zero Trust**.
    * Inserir o nome da organização: `<nome-da-tua-org>`.
3.  **Autenticar:** Seguir os passos no browser.
4.  **Ligar:** Ativar o interruptor na aplicação.

> [!TIP]
> **Validação Rápida**
> 
> Se o ícone estiver "Laranja" (WARP) ou "Azul com escudo" (Zero Trust), o túnel está ativo.
> Para confirmar o acesso, bata tentar abrir por exemplo `https://10.10.1.254:8006` (Proxmox).

---
## 11. Troubleshooting & Diagnóstico

> [!WARNING]
> **A Ilusão do Ping (ICMP)**
> 
> Em redes Zero Trust (WARP), o tráfego ICMP tem prioridade baixa ou é bloqueado, enquanto o tráfego aplicacional (TCP/UDP) passa.
> **Regra de Ouro:** Nunca confiar apenas no Ping. Testar sempre a abertura da porta do serviço.

### 11.1 Validar Conexão Real (TCP)

Se o serviço não abre mas o túnel parece ativo, utilizar estas ferramentas para validar se o tráfego chega ao destino.

Testar se a porta 8006 (Proxmox) está acessível através do túnel:
```bash
#Linux (Netcat)
nc -vz 10.10.1.254 8006


#Windows (PowerShell):
Test-NetConnection 10.10.1.254 -Port 8006
```

### 11.2 Tabela de Erros Comuns

| Sintoma                                     | Causa Provável                             | Solução                                                                                                |
| :------------------------------------------ | :----------------------------------------- | :----------------------------------------------------------------------------------------------------- |
| **Túnel "Connected" mas sem acesso a nada** | Falta de encaminhamento no Linux.          | Verificar se `net.ipv4.ip_forward = 1` na VM `cf-tunnel'.                                              |
| **Aceder ao Proxmox mas não ao pfSense**    | Bloqueio de Auto-Proteção da Firewall.     | Criar regra na interface VLAN permitindo acesso a `This Firewall` (Porta 443).                         |
| **Lentidão / Falhas em RDP e SSH**          | Fallback para TCP (performance degradada). | Confirmar se o protocolo **UDP** está ativo nas *Traffic Policies* da Cloudflare.                      |
| **DNS resolve o nome, mas não conecta**     | Split Tunnel mal configurado.              | Confirmar se as subnets estão no perfil em modo **Include**.                                           |
| **Erro de Certificado / SSL**               | Inspeção TLS ativa.                        | Instalar o certificado CA da Cloudflare nos dispositivos ou adicionar o domínio à exceção de inspeção. |
