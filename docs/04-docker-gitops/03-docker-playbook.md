# Playbook Operacional: Docker & Compose (Cheat Sheet SysAdmin)

> [!NOTE]
> **Objetivo:** Referência rápida de comandos CLI, gestão de ciclo de vida de contentores e boas práticas de construção de imagens (Build/Hardening).

---

## Distinção Crítica: `Run` vs `Start`

* **`docker run` = APROVISIONAMENTO (Nascimento)**
  * Cria um contentor **novo** do zero a partir de uma imagem.
  * Executar 10 vezes = 10 contentores isolados diferentes.

* **`docker start` = EXECUÇÃO (Acordar)**
  * Pega num contentor existente (parado) e liga-o.
  * Mantém o estado, configurações, rede e ficheiros.

---

## 1. Docker CLI (Gestão Direta)

### 1.1. Obter e Criar

| Ação | Comando | Detalhes Técnicos |
| :--- | :--- | :--- |
| **Baixar Imagem** | `docker pull mysql:8.0` | Sincroniza a imagem do repositório remoto (Docker Hub) para o disco local. |
| **Ver Imagens** | `docker images` | Lista as imagens em cache no *Host*. |
| **Criar Contentor** | `docker run mysql:8.0` | Instancia um **novo** contentor e força o arranque. |

### 1.2. Gerir e Controlar

| Ação | Comando | Detalhes Técnicos |
| :--- | :--- | :--- |
| **Ver Ativos** | `docker ps` | Lista processos/contentores em execução (*Running*). |
| **Ver Tudo** | `docker ps -a` | Lista todo o inventário (Execução + Parados/Falhados). |
| **Controlo de Estado** | `docker stop [ID]` / `docker start [ID]` | Envia sinal SIGTERM (Stop) ou acorda o contentor. |
| **Sessão Shell (Entrar)** | `docker exec -it [ID] /bin/bash` | Abre um TTY interativo dentro do contentor. |
| **Auditoria** | `docker inspect [ID]` | Devolve o JSON integral de configuração (IP, Mounts, Redes). |

### 1.3. Redes Virtuais (Networking L2)

| Ação | Comando | Detalhes Técnicos |
| :--- | :--- | :--- |
| **Listar Redes** | `docker network ls` | Mostra as interfaces virtuais (Bridge, Host, Overlay). |
| **Criar Isolamento** | `docker network create [nome]` | Provisiona uma nova rede (VLAN interna) tipo Bridge. |
| **Anexar Interface** | `docker network connect [rede] [cnt]` | Injeta uma interface de rede num contentor existente. |

### 1.4. Monitorização (Logs)

| Ação | Comando | Detalhes Técnicos |
| :--- | :--- | :--- |
| **Dump Completo** | `docker logs [ID]` | Imprime o *stdout*/*stderr* integral. |
| **Tempo Real (Tail)** | `docker logs -f [ID]` | Escuta ativa de novos eventos (análogo ao `tail -f`). |

### 1.5. Manutenção e Saneamento

> [!WARNING]
> Comandos destrutivos. Usar com extrema cautela em produção.

| Ação                 | Comando                  | Detalhes Técnicos                                            |
| :------------------- | :----------------------- | :----------------------------------------------------------- |
| **Apagar Contentor** | `docker rm [ID]`         | Exige que o contentor esteja no estado `Exited` (Parado).    |
| **Apagar Imagem**    | `docker rmi [imagem]`    | Falha se existir algum contentor alocado a esta imagem base. |
| **Purga Global**     | `docker system prune -a` | Destrói contentores parados, redes órfãs e cache de build.   |

---

## 2. Docker Compose (Infraestrutura como Código - IaC)

O padrão da indústria para orquestração. Lê ficheiros `yaml`.

### 2.1. Ciclo de Vida do Compose

| Ação | Comando | Efeito na Infraestrutura |
| :--- | :--- | :--- |
| **Aprovisionar (Up)** | `docker compose -f ficheiro.yml up -d` | Lê o YAML, cria as redes/volumes e arranca em *background*. |
| **Auditar Logs** | `docker compose -f ficheiro.yml logs -f` | Agrega os logs de todos os serviços definidos no YAML. |
| **Destruir (Down)** | `docker compose -f ficheiro.yml down` | Destrói contentores e redes virtuais (Preserva volumes). |

### 2.2. Tradução CLI para Compose (Cheat Sheet)

| Parâmetro CLI (`docker run`) | Equivalente em YAML (`docker-compose.yml`) |
| :--- | :--- |
| `imagem` | `image: imagem` |
| `--name proxy` | `container_name: proxy` |
| `-p 80:80` | `ports: ["80:80"]` |
| `-v vol:/data` | `volumes: ["vol:/data"]` |
| `-e PASS=123` | `environment: ["PASS=123"]` |
| `--restart always` | `restart: always` |
| `--network rede` | `networks: - rede` |

---

## 3. Construção de Imagens (Dockerfile)

### 3.1. Workflow Completo de Build e Publish

1. **Login (Auth):** `docker login` *(Requer tokens para repos privados).*
2. **Construção:** `docker build -t my-app:1.0 .` *(O `.` indica o contexto atual do diretório).*
3. **Validação:** `docker run -d -p 3000:3000 my-app:1.0` *(Teste local).*
4. **Tagging (Aliasing):** `docker tag my-app:1.0 user/my-app:v1` *(Prepara o repositório de destino).*
5. **Upload (Push):** `docker push user/my-app:v1` *(Envia para o Registry).*

### 3.2. Hardening: O ficheiro `.dockerignore`

> [!IMPORTANT]
> A ausência deste ficheiro é a principal causa de fuga de dados (Data Leakage) em imagens Docker.

Criar o ficheiro `.dockerignore` na raiz bloqueia a injeção de lixo ou segredos locais na imagem final:

```plaintext
node_modules          # Obriga o container a compilar as suas próprias dependências
.git                  # Bloqueia a injeção do histórico do repositório
.env                  # CRÍTICO: Impede que chaves secretas locais fiquem expostas na imagem
Dockerfile            # Omitir a própria receita de construção
```