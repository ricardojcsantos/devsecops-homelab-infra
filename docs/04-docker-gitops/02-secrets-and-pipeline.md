# Guia: Cofre de Segredos e Pipeline de Deploy (GitOps)

> [!NOTE]
> **Objetivo:** Estabelecer a gestão segura de credenciais via GitHub Secrets e implementar o ficheiro de orquestração automatizada (`deploy.yml`) que instrui o servidor a levantar os contentores.

---

## 1. Guardar Passwords em Segurança (GitHub Secrets)

> [!WARNING]
> **Regra de Ouro:** Nunca escrever passwords diretamente nos ficheiros `.yml`. Se o código for parar à internet ou for copiado, as contas ficam expostas. As passwords são enviadas pelo GitHub apenas no momento exato em que o servidor arranca as apps.

Para que a automação funcione sem erros, é preciso criar as chaves no GitHub (Ir a `Settings` > `Secrets and variables` > `Actions` > `New repository secret`):

| Nome exato a colocar no GitHub | Onde vai ser injetado no Servidor | Para que serve? |
| :--- | :--- | :--- |
| `IMMICH_DB_PASS` | `apps/immich/.env` | Password da base de dados do Immich |
| `DB_ROOT_PASS` | `apps/nextcloud/.env` | Password de Administrador do Nextcloud |
| `DB_PASS` | `apps/nextcloud/.env` | Password do Utilizador do Nextcloud |

---

## 2. O Motor de Automação (`deploy.yml`)

Para evitar arranques acidentais, o código-fonte original está guardado neste caminho:

* **Ficheiro de Origem:** `templates/.github/workflows/deploy.yml`

**Como Criar e Ativar via GitHub Web:**
1. No repositório, clicar no separador **Actions** > **New workflow** > **set up a workflow yourself**.
2. No nome do ficheiro, escrever: `deploy.yml`.
3. **Ação Exigida:** Abrir o ficheiro de origem indicado acima, **copiar a totalidade do código** lá contido e **colar** na janela do novo *workflow*.
4. Clicar em **Commit changes**. O GitHub vai detetar o ficheiro e a automação fica imediatamente ativa.


---

## 3. Ficheiros das Apps (Docker Compose)

Cada aplicação tem o seu próprio ficheiro `.yml` separado. Isto mantém tudo organizado e fácil de atualizar.

* **Onde estão guardados:** `templates/apps/`

| Pasta da App                  | Ficheiro a usar   | O que faz a App?                                                     |
| :---------------------------- | :---------------- | :------------------------------------------------------------------- |
| `templates/apps/npm/`         | `npm.yml`         | **Nginx Proxy Manager:** Trata dos domínios e cadeados verdes (SSL). |
| `templates/apps/vaultwarden/` | `vaultwarden.yml` | **Vaultwarden:** O cofre pessoal de passwords.                       |
| `templates/apps/immich/`      | `immich.yml`      | **Immich:** A galeria de fotos privada.                              |
| `templates/apps/nextcloud/`   | `nextcloud.yml`   | **Nextcloud:** A nuvem de ficheiros.                                 |

> [!TIP]
> **Acesso Seguro via Nginx Proxy Manager (Padrão Recomendado):** Se mantiveres a arquitetura *Zero Trust* e utilizares o NPM para gerir os domínios e certificados SSL, a configuração de roteamento (Split-DNS e Cloudflare) está detalhada no módulo de redes.
> * **Consultar Documentação:** `docs/03-network/10-npm-domain-ssl.md`

> [!IMPORTANT]
> **Acesso direto sem Nginx Proxy Manager:** Por razões de segurança, estes ficheiros vêm configurados para comunicar exclusivamente através do Nginx Proxy Manager (as portas externas estão desativadas). Se **não** fores usar o proxy e quiseres aceder às apps através do IP do teu servidor (ex: `192.168.1.10:8080`), tens de abrir cada ficheiro `.yml`, procurar a secção `ports:` e apagar o símbolo `#` para a ativar.

**Como Ativar as Apps no Servidor:**
* Mover a pasta inteira `apps/` (que está dentro de `templates/`) para a pasta principal (raiz) do teu projeto. 
* A automação está programada para procurar as aplicações estritamente aí.

---

## 4. Como a Automação Funciona na Prática

Quando envias código novo para o teu GitHub, o sistema lê o ficheiro `deploy.yml` e faz isto de forma automática:

| O que está no código             | O que faz na realidade                                                                                                                   |
| :------------------------------- | :--------------------------------------------------------------------------------------------------------------------------------------- |
| **`paths: - 'apps/**'`**         | Só avisa o servidor se mexeres nos ficheiros das apps. Atualizar texto (como o `README.md`) não faz a máquina trabalhar à toa.           |
| **`runs-on: self-hosted`**       | Obriga o GitHub a fazer o trabalho no próprio servidor (Proxmox), e não nos servidores públicos da Microsoft.                            |
| **`actions/checkout@v4`**        | Descarrega a versão mais recente do código para dentro da máquina virtual.                                                               |
| **Comandos `echo` (`>` e `>>`)** | Cria o ficheiro invisível (`.env`) com as passwords diretamente no disco do servidor. Assim, as passwords nunca ficam no código público. |
| **`--remove-orphans`**           | Faz a limpeza: Apaga automaticamente contentores antigos que já tenhas retirado do código.                                               |
| **`docker image prune -af`**     | Poupa espaço no teu disco: Apaga restos de atualizações antigas do Docker que já não estão a ser usadas.                                 |
