# Guia: Exposição Privada, SSL e Split-DNS (Zero Trust)

> [!NOTE]
> **Objetivo:** Garantir acesso seguro às aplicações via Nginx Proxy Manager (NPM) com certificados SSL válidos, mantendo a infraestrutura 100% invisível na internet (*Zero Port Forwarding*). O acesso externo é feito estritamente via VPN (Cloudflare Zero Trust) e o acesso interno via Split-DNS.

---

## 1. Topologia de Segurança (Hardening Perimetral)

* **Isolamento Total:** NENHUMA porta aberta no Router/Firewall.
* **Invisibilidade:** Superfície de ataque externa nula (Servidor invisível a *scanners* públicos como Shodan).
* **Segregação de Roteamento:** Resolução de nomes (DNS) separada entre tráfego LAN (pfSense) e tráfego WAN (Cloudflare WARP).

---

## 2. Configuração DNS e API (Cloudflare)

A emissão de certificados SSL sem a porta 80 aberta exige a utilização do método **DNS-01 Challenge**. O NPM necessita de comunicar com a API da Cloudflare para provar a propriedade do domínio criptograficamente.

### 2.1. Criação de Registos A (Zona DNS)

| Tipo  | Nome (Subdomínio) | Alvo (IP)  | Estado do Proxy      | Função Arquitetural                                          |
| :---- | :---------------- | :--------- | :------------------- | :----------------------------------------------------------- |
| **A** | `npm`             | `ip-da-vm` | Desligado (DNS Only) | Aponta para o IP local. Acessível apenas com VPN/WARP ativa. |
| **A** | `immich`          | `ip-da-vm` | Desligado (DNS Only) | Roteamento cego para a infraestrutura local.                 |
| **A** | `nextcloud`       | `ip-da-vm` | Desligado (DNS Only) | Roteamento cego para a infraestrutura local.                 |
| **A** | `vault`           | `ip-da-vm` | Desligado (DNS Only) | Roteamento cego para a infraestrutura local.                 |

### 2.2. Geração de Token de API (Cloudflare)

* **1.** Aceder a **My Profile** > **API Tokens** > **Create Token**.
* **2.** Selecionar o template **Edit zone DNS**.
* **3.** Em **Zone Resources:** Definir como `Include` -> `Specific Zone` -> `[teudominio.com]`.
* **4.** Guardar o Token gerado (será injetado diretamente no cofre do NPM no passo seguinte).

---

## 3. Emissão SSL via DNS Challenge (NPM)

No painel de administração do Nginx Proxy Manager (`http://ip-da-vm:81`), gera o certificado sem expor o servidor à internet:

**Ação:** Aceder a **SSL Certificates** > **Add SSL Certificate** > **Let's Encrypt** e preencher a matriz:

| Parâmetro | Valor / Ação | Justificação Técnica |
| :--- | :--- | :--- |
| **Domain Names** | `*.teudominio.com`, `teudominio.com` | Emissão de certificado *Wildcard*. Cobre todos os subdomínios (presentes e futuros) numa única validação. |
| **Use a DNS Challenge** | Ativar | Contorna a exigência da porta 80 aberta no Router da operadora. |
| **DNS Provider** | `Cloudflare` | Define o *endpoint* da API para validação autoritativa. |
| **Credentials File Content** | `dns_cloudflare_api_token=O_TEU_TOKEN` | Injeção do token gerado no passo 2.2. |
| **Propagation Seconds** | `120` | Margem de segurança de replicação DNS nos servidores globais antes do gatilho de validação. |

---

## 4. Roteamento Interno (Split-DNS no pfSense)

Para aceder localmente sem a latência de roteamento da VPN e mantendo o tráfego estritamente local, o pfSense interceta e resolve os pedidos DNS na LAN.

> [!IMPORTANT]
> **Regra Restrita:** É obrigatório criar um registo manual isolado para **cada** aplicação que exista na infraestrutura.

**Ação:** No pfSense, aceder a **Services** > **DNS Resolver** > **Host Overrides** > **Add**.

| Host (Aplicação) | Domain (Base)    | IP Address (Alvo) | Função no Split-DNS                  |
| :--------------- | :--------------- | :---------------- | :----------------------------------- |
| `npm`            | `teudominio.com` | `ip-da-vm`        | Devolve o IP local do Proxy à LAN.   |
| `immich`         | `teudominio.com` | `ip-da-vm`        | Devolve o IP local da Galeria à LAN. |
| `nextcloud`      | `teudominio.com` | `ip-da-vm`        | Devolve o IP local da Nuvem à LAN.   |
| `vault`          | `teudominio.com` | `ip-da-vm`        | Devolve o IP local do Cofre à LAN.   |

---

## 5. Mapeamento de Proxies (NPM)

Com os certificados gerados e a resolução DNS operacional, efetua o roteamento final para os contentores.

> [!IMPORTANT]
> **Roteamento Granular (Regra Restrita):** A criação do *Proxy Host* é estritamente individual. Este procedimento tem de ser repetido integralmente para **cada** aplicação da infraestrutura (Nextcloud, Vaultwarden, etc.), ajustando o FQDN, o Host de destino e a porta interna correspondente.

**Ação:** No NPM, aceder a **Hosts** > **Proxy Hosts** > **Add Proxy Host** e preencher a matriz (Exemplo para o Immich):

| Separador | Parâmetro | Valor a Configurar | Justificação (*Hardening*) |
| :--- | :--- | :--- | :--- |
| **Details** | **Domain Names** | `immich.teudominio.com` | FQDN de acesso. |
| **Details** | **Scheme / Forward Host** | `http` / `immich-server` | Roteamento fechado via rede interna do Docker (DNS nativo). |
| **Details** | **Forward Port** | `2283` | Porta de escuta interna da aplicação no YAML. |
| **Details** | **Block Common Exploits** | Ativar | Ativa mitigação L7 básica (Injeções SQL, XSS). |
| **SSL** | **SSL Certificate** | Selecionar o *Wildcard* | Aplicação do certificado gerado no Passo 3. |
| **SSL** | **Force SSL / HTTP/2 / HSTS** | Ativar Todos | Bloqueio absoluto de *downgrade* para tráfego em texto limpo (HTTP). |

---

## 6. Verificação de Fluxo Lógico (*Troubleshooting*)

| Vetor de Acesso | Fluxo de Resolução (Como a rede processa o pedido) |
| :--- | :--- |
| **Acesso Interno (LAN)** | Cliente pede `immich.teudominio.com` ➔ pfSense interceta via *Split-DNS* e devolve `10.10.40.10` ➔ NPM recebe o pedido e encaminha para o contentor isolado. |
| **Acesso Externo (WAN)** | Cliente liga VPN (Cloudflare WARP) ➔ Pede `immich.teudominio.com` ➔ DNS Cloudflare devolve `10.10.40.10` ➔ Túnel roteia o IP privado para a infraestrutura ➔ NPM processa o pedido. |
