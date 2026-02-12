# Guia de Acesso Remoto: Qual VPN Escolher?

> [!NOTE]
> **Objetivo Estratégico**
> 
> Este guia serve para ajudar a escolher a melhor VPN para cada situação. Temos 4 formas de entrar na rede, cada uma com um propósito específico.
>
> **O Arsenal Disponível:**
> 
> 1.  ☁️ **Cloudflare Tunnel:** Acesso moderno sem abrir portas (Zero Trust).
> 2.  🛡️ **OpenVPN:** O clássico compatível com tudo.
> 3.  🚀 **WireGuard:** Velocidade máxima.
> 4.  📱 **IPsec IKEv2:** Integração nativa (sem instalar nada).

---

##  A minha Recomendação 

> [!TIP]
> **1.ª Escolha: Cloudflare Tunnel (Zero Trust)**
> 
> **Porquê?** É a solução mais segura para uso pessoal.
> 
> * **Invisível:** Não precisas de abrir nenhuma porta no router. A tua casa fica "invisível" para scanners na Internet.
> * **Funciona Sempre:** Mesmo que a operadora mude o teu IP ou te coloque atrás de CGNAT.
> * **Cliente Seguro:** Requer apenas a instalação da app **Cloudflare WARP** (ligada à tua organização).
> * [Ver Guia de Implementação](./09-cloudflare-zero-trust.md)


> [!TIP]
> **2.ª Escolha: OpenVPN**
> 
> **Porquê?** É a alternativa universal que funciona em qualquer rede.
> 
> * **Simplicidade:** É muito fácil de configurar no pfSense e nos clientes.
> * **Compatibilidade:** Se a Cloudflare falhar ou estiveres numa rede que bloqueia tudo, o OpenVPN passa quase sempre.
> * [Ver Guia de Implementação](./07-pfsense-vpn-openvpn.md)

---

## 1. Comparativo entre VPNs

Análise rápida para perceber as diferenças:

| Método | Velocidade | Portas no Router (Abrir) | Dificuldade | Ideal Para... |
| :--- | :--- | :---: | :--- | :--- |
| **Cloudflare** | Média | ❌ **Nenhuma** (Seguro) | Fácil | Acesso diário, Web Apps, CGNAT. |
| **OpenVPN** | Média | ✅ Sim (UDP ou TCP) | Muito Fácil | Hotéis, Aeroportos e Redes Públicas. |
| **WireGuard** | **Extrema** | ✅ Sim (UDP) | Média | Transferir ficheiros grandes, Streaming 4K. |
| **IPsec** | Alta | ✅ Sim (UDP) | Difícil | Dispositivos de trabalho (sem permissão de install). |

---

## 2. Qual devo usar? (Cenários Reais)

Escolher a VPN consoante a situação onde te encontras:

### Cenário A: "A minha operadora não me dá IP Público (CGNAT)"
* **Usa:** ☁️ **Cloudflare Tunnel**.
* **Motivo:** É a única solução que funciona de "dentro para fora". Ignora completamente as restrições da operadora.

### Cenário B: "Estou num Hotel/Aeroporto e o Wi-Fi bloqueia VPNs"
* **Usa:** 🛡️ **OpenVPN** (em modo TCP).
* **Motivo:** O OpenVPN consegue disfarçar-se de tráfego normal de internet (HTTPS). As firewalls dos hotéis deixam passar porque pensam que estás apenas a visitar um site seguro.

### Cenário C: "Quero ver filmes com qualidade máxima"
* **Usa:** 🚀 **WireGuard**.
* **Motivo:** É a VPN mais leve e rápida. Conecta-se instantaneamente, não gasta bateria no telemóvel e aguenta streaming pesado sem falhas.

### Cenário D: "Não posso instalar Apps no computador da empresa"
* **Usa:** 📱 **IPsec IKEv2**.
* **Motivo:** O Windows, Mac, iPhone e Android já trazem este sistema instalado de origem. Basta colocar o endereço, user e password nas definições de rede do dispositivo.

---

## 3. Resumo de Requisitos Técnicos

O que é preciso para ativar cada uma:

* **Cloudflare Tunnel:**
    * Requer: Domínio próprio (ex: `meunome.com`) + Conta Cloudflare.
    * Portas: **Zero.**

* **OpenVPN:**
    * Requer: DDNS Ativo.
    * Portas: Uma porta **UDP** dedicada (ex: 51850) ou **443 (TCP)** para compatibilidade.

* **WireGuard:**
    * Requer: DDNS Ativo.
    * Portas: Uma porta **UDP** dedicada (ex: 51820).

* **IPsec:**
    * Requer: DDNS Ativo.
    * Portas: Portas **UDP 500** e **UDP 4500**.

---

## 4. Guias de Instalação (Passo a Passo)

Clicar nos links abaixo para seguir o tutorial de implementação de cada VPN:

* 🌐 **Pré-Requisito Global:** [05 - Configuração Dynamic DNS](./05-pfsense-dynamic-ddns-configuration.md)
* 🚀 **WireGuard:** [06 - Implementação WireGuard](./06-pfsense-vpn-wireguard.md)
* 🛡️ **OpenVPN:** [07 - Implementação OpenVPN](./07-pfsense-vpn-openvpn.md)
* 📱 **IPsec:** [08 - Implementação IPsec (Mobile)](./08-pfsense-vpn-ipsec.md)
* ☁️ **Cloudflare:** [09 - Implementação Zero Trust](./09-cloudflare-zero-trust.md)