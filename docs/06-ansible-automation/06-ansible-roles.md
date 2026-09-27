# Modularização com Ansible Roles (Web Server)

> [!NOTE]
> **Objetivo:** Abandonar os *Playbooks* monolíticos e adotar a arquitetura empresarial baseada em *Roles*. Vamos criar um módulo reutilizável para instalar e configurar um Servidor Web (Nginx) na máquina Linux, demonstrando o princípio DRY (*Don't Repeat Yourself*).

---

## 1. Criar a Estrutura da Role

O Ansible possui uma ferramenta nativa (`ansible-galaxy`) que gera automaticamente a árvore de diretorias (*scaffolding*) necessária para obedecer à norma estrutural das *Roles*.

No terminal do teu Controlador, acede à pasta do projeto e inicializa a *Role*:

```bash
cd ~/ansible
mkdir -p roles
ansible-galaxy init roles/webserver
```

*(Se executares `ls -l roles/webserver`, verás que o Ansible criou uma estrutura de pastas padronizada com `tasks`, `handlers`, `vars`, `files`, `templates`, etc).*

---

## 2. Configurar os Ficheiros da Role

Em vez de colocarmos todas as instruções num único ficheiro interminável, vamos dividir as responsabilidades pelas pastas correspondentes da nossa nova *Role*.

### A) O Ficheiro Estático (Files)
Cria um ficheiro HTML simples que o Ansible vai injetar no servidor web. Os ficheiros colocados nesta pasta não requerem caminhos absolutos nas tarefas.

```bash
nano ~/ansible/roles/webserver/files/index.html
```

Cola este conteúdo:
```html
<!DOCTYPE html>
<html>
<head>
    <title>Ansible Web Role</title>
</head>
<body>
    <h1>Servidor Web configurado via Ansible Role!</h1>
    <p>A arquitetura de modularizacao corporativa esta a funcionar.</p>
</body>
</html>
```
*(Guarda com `CTRL+O`, `Enter` e sai com `CTRL+X`).*

### B) As Tarefas Principais (Tasks)
Define o que a *Role* vai fazer. Edita o ficheiro principal de tarefas:

```bash
nano ~/ansible/roles/webserver/tasks/main.yml
```

Substitui o conteúdo existente por este (nota que numa *Role* já não declaramos `tasks:`, começamos diretamente na lista de ações):

```yaml
---
# tasks file for roles/webserver

- name: 01 - Instalar o servidor web Nginx
  ansible.builtin.apt:
    name: nginx
    state: present
    update_cache: yes

- name: 02 - Injetar a pagina web personalizada
  ansible.builtin.copy:
    src: index.html                    # Procura automaticamente na pasta 'files' da Role
    dest: /var/www/html/index.html
    owner: root
    group: root
    mode: '0644'
  notify: Reiniciar Nginx              # Aciona o Handler se o ficheiro for injetado/alterado

- name: 03 - Garantir que o Nginx esta ativo e arranca com o sistema
  ansible.builtin.service:
    name: nginx
    state: started
    enabled: yes

- name: 04 - Permitir trafego HTTP na Firewall (UFW)
  community.general.ufw:
    rule: allow
    port: '80'
    proto: tcp
```
*(Guarda e sai).*
### C) As Ações Reativas (Handlers)
Define a resposta à notificação da tarefa 02.

```bash
nano ~/ansible/roles/webserver/handlers/main.yml
```

Substitui o conteúdo por:

```yaml
---
# handlers file for roles/webserver

- name: Reiniciar Nginx
  ansible.builtin.service:
    name: nginx
    state: restarted
```
*(Guarda e sai).*

---

## 3. O Playbook Mestre (Master Playbook)

Com o módulo base pronto e isolado, o nosso *Playbook* de execução transforma-se apenas num orquestrador limpo e de alto nível, encarregue de mapear as *Roles* aos grupos de servidores.

Cria o ficheiro na tua pasta de *playbooks*:

```bash
nano ~/ansible/playbooks/deploy-web.yml
```

Cola este conteúdo:

```yaml
---
# ==============================================================================
# Playbook: Deploy da Frota de Servidores Web
# ==============================================================================

- name: Provisionamento Web
  hosts: lab_linux
  become: yes          # Requer root para instalar pacotes (a password esta no Vault)
  roles:
    - role: ../roles/webserver
```
*(Guarda e sai).*

---

## 4. Execução e Validação (Testes)

Como a elevação de privilégios via `NOPASSWD` está ativa no Linux, não precisas de invocar o *Vault (--ask-vault-pass )* :

Executa o *Playbook* mestre:

```bash
ansible-playbook -i ~/ansible/inventory/inventory.ini ~/ansible/playbooks/deploy-web.yml
```

> [!TIP]
> **Validação Final:** Após o Ansible terminar a execução com sucesso (verde/amarelo), abre o *browser* no teu computador físico e escreve o IP da máquina Linux do laboratório (ex: `http://10.10.50.20`).
> 
> Deves ver a página HTML renderizada. Isto comprova que o pacote foi instalado, o ficheiro transferido, a firewall aberta e o serviço ativado — tudo gerido por uma arquitetura modular baseada em *Roles*.