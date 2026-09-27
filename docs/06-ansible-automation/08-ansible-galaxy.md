# Ansible Galaxy e Roles da Comunidade

> [!NOTE]
> **Objetivo:** Neste laboratório final, vamos utilizar o Ansible Galaxy (o repositório oficial da comunidade) para descarregar uma *Role* externa e usá-la para instalar o Docker no nosso servidor Linux. Vamos usar código criado pelo *geerlingguy* (Jeff Geerling), um dos maiores contribuidores de Ansible do mundo, cujas *Roles* são consideradas *standard* na indústria.

---

## 1. Declarar as Dependências (`requirements.yml`)

Em projetos empresariais e *pipelines* CI/CD, nunca descarregas *Roles* à mão. Crias um ficheiro de manifesto que dita exatamente de que módulos externos o teu projeto precisa (à semelhança do `package.json` no Node.js ou `requirements.txt` no Python).

No terminal do Controlador, cria o ficheiro de requisitos na raiz do projeto:

```bash
nano ~/ansible/requirements.yml
```

Cola o seguinte conteúdo:

```yaml
roles:
  - name: geerlingguy.docker
    version: "7.4.0" 
    # Fixar a versao garante a imutabilidade do ambiente: 
    # o teu codigo nao quebra se o autor lancar um update incompativel amanha.
```
*(Guarda com `CTRL+O`, `Enter` e sai com `CTRL+X`).*

---

## 2. Instalar a Role Localmente

Agora dizemos ao motor do Ansible para ler o ficheiro de manifesto e descarregar as dependências da internet para a nossa máquina de controlo.

Executa no terminal:

```bash
ansible-galaxy install -r ~/ansible/requirements.yml -p ~/ansible/roles/
```

> [!TIP]
> **O que acontece:** O Ansible vai ao portal Galaxy, faz o download do código da *Role* do Docker e extrai-o de forma estruturada para a tua pasta `~/ansible/roles/geerlingguy.docker`.

---

## 3. Criar o Playbook Mestre

Temos a *Role* complexa no nosso disco. Só precisamos de um *Playbook* de alto nível muito limpo para a invocar, injetar as nossas preferências e aplicar ao laboratório Linux.

Cria o ficheiro do *Playbook*:

```bash
nano ~/ansible/playbooks/deploy-docker.yml
```

Cola o seguinte código:

```yaml
---
# ==============================================================================
# Playbook: Instalacao do Docker (via Ansible Galaxy)
# ==============================================================================

- name: Configurar ambiente de contentores
  hosts: lab_linux
  become: yes          # Requer privilegios elevados para instalar o motor Docker

  # Injetar variaveis dita o comportamento da Role da comunidade
  vars:
    docker_users:
      - ansible        # Adiciona o nosso utilizador de servico ao grupo 'docker'

  roles:
    - role: ../roles/geerlingguy.docker
```
*(Guarda e sai).*

---

## 4. Execução e Validação

Dispara o teu *Playbook*:

```bash
ansible-playbook -i ~/ansible/inventory/inventory.ini ~/ansible/playbooks/deploy-docker.yml
```

> [!WARNING]
> **Privilégios e Segurança:** Como configurámos o utilizador `ansible` com a flag `NOPASSWD` no sudo do nosso laboratório, o comando acima corre sem pedir credenciais. No entanto, num ambiente de Produção rigoroso (onde o `NOPASSWD` é proibido por motivos de segurança), deves sempre trancar a password no cofre e acrescentar a flag `--ask-vault-pass` ao comando de execução.

Vais reparar que, em vez de 4 ou 5 tarefas, o terminal vai processar dezenas de passos automaticamente (adicionar chaves GPG, configurar repositórios apt oficiais, instalar o *daemon*, arrancar o serviço). Tu escreveste ~15 linhas de código; a comunidade escreveu as outras 500 por ti, garantindo o tratamento de *edge-cases*.

### Validação do Sucesso:

Quando o *Playbook* terminar sem erros, entra na tua máquina Linux alvo via SSH:

```bash
ssh ansible@10.10.50.20
```

E pede ao sistema para listar os contentores a correr:

```bash
docker ps
```

> [!IMPORTANT]
> Se o terminal devolver o cabeçalho das colunas do Docker (`CONTAINER ID   IMAGE   COMMAND...`) **sem dar erro de permissão recusada**, o teu ambiente está perfeito! 
> Isto comprova duas coisas: o motor Docker foi instalado com sucesso, e a variável que injetaste (`docker_users`) funcionou, permitindo à conta `ansible` interagir com o *socket* do Docker sem precisar de usar `sudo`.