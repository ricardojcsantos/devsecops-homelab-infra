# Configuração Dynamic DNS (DDNS)

> [!NOTE]
> **Objetivo Estratégico**
> 
> Garantir que os serviços externos (VPNs) conseguem localizar o endereço IP Público da infraestrutura, mesmo que este seja alterado pelo Operador (ISP).
>
> **O Problema:** A maioria das ligações residenciais possuem IP Dinâmico.
> 
> **A Solução:** O cliente DDNS do pfSense deteta mudanças no IP da WAN e atualiza automaticamente um registo DNS (ex: `vpn.omeulab.com`).

---

## 1. Pré-requisitos

Antes de configurar no pfSense, é necessário ter conta num fornecedor de DNS suportado.

### Opções de Fornecedores

O pfSense suporta nativamente dezenas de serviços. Os mais comuns são:

1.  **Domínio Próprio (Recomendado):**
    * **Cloudflare:** Gratuito, rápido e profissional. Requer domínio próprio (`omeulab.pt`).

2.  **Subdomínio Gratuito:**
    * **No-IP:** Ideal para quem não quer comprar um domínio (`omeulab.ddns.org`).

---

## 2. Configuração no pfSense

O processo é idêntico para qualquer fornecedor, variando apenas nas credenciais exigidas (API Key ou Password).

**Caminho:** `Services > Dynamic DNS > Dynamic DNS Clients > Add`

### 2.1 Parâmetros Universais

| Parâmetro | Definição | Notas Técnicas |
| :--- | :--- | :--- |
| **Service Type** | `[O Teu Fornecedor]` | Escolher da lista (ex: Cloudflare, No-IP Free). |
| **Interface to monitor** | `WAN` | A interface cujo IP Público queremos monitorizar. |
| **Verbose logging** | **Checked** | Essencial para debug inicial (verificar se a atualização ocorre). |
| **Description** | `DDNS_WAN_Link` | Identificador descritivo. |

### 2.2 Credenciais e Hostnames

A forma de preencher varia conforme o serviço. Abaixo apresentam-se os cenários mais comuns.

#### Cenário A: Cloudflare (Domínio Próprio)
* **Hostname:** `@` (para a raiz) ou `vpn` (para subdomínio).
* **Domain name:** `exemplo.com`
* **Username:** Email da conta Cloudflare.
* **Password:** Global API Key.

> [!WARNING]
> **Segurança**
> 
> A Global API Key tem privilégios de administrador total. Guardar num gestor de passwords seguro.

* **Cloudflare Proxy:** **UNCHECKED (Desativado)**.

> [!CAUTION]
> **Aviso Crítico**
> 
> Para uso em VPNs (WireGuard, OpenVPN, IPsec), o Proxy (Nuvem Laranja) **TEM** de estar desligado.
>
> O DNS deve resolver para o IP real da casa, não para o IP da CDN da Cloudflare.

#### Cenário B: No-IP (Gratuito)
* **Hostname:** O nome completo (ex: `omeulab`).
* **Domain name:** O sufixo do serviço (ex: `ddns.net`).
* **Username:** O utilizador da conta.
* **Password:** A password da conta (ou Token).

---

## 3. Validação e Testes

Após clicar em **Save & Force Update**, deve validar se o sistema está funcional.

### 3.1 Validar no Dashboard

Adicionar o widget **Dynamic DNS Service Status** ao Dashboard principal.

* **Cached IP:** Deve ser igual ao IP da interface WAN (cor verde).
* **Status:** Deve indicar a data/hora da última atualização com sucesso.

### 3.2 Validar nos Logs

**Caminho:** `Status > System Logs > System > General`

* Procurar por `phpDynDNS`.
* Mensagem de sucesso: `Updated successfully` ou `IP address matches, no update needed`.

### 3.3 Teste de Resolução (Lookup)

Num computador fora da rede (ou via terminal), testar a resolução do nome:

```bash
# Windows
nslookup vpn.exemplo.com

# Linux / macOS
dig vpn.exemplo.com +short
```