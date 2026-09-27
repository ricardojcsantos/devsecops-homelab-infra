# Variáveis e Ficheiros Dinâmicos (Templates Jinja2)

> [!NOTE]
> **Objetivo:** Num ambiente de infraestrutura real, os ficheiros de configuração (ex: `nginx.conf`, `php.ini`) não podem ser estáticos. Um servidor de Base de Dados com 32GB de RAM precisa de um ficheiro de configuração diferente de um servidor com 4GB. O motor *Jinja2* do Ansible permite resolver este desafio, injetando variáveis, *Facts* de sistema e lógica condicional diretamente nos ficheiros no momento da execução.

---

## 1. Definir Variáveis Locais da Role (Defaults)

Primeiro, vamos definir variáveis genéricas para a nossa *Role*. Numa arquitetura limpa, variáveis que representam valores "por omissão" (passíveis de serem alterados no futuro pelo *Playbook* mestre) devem viver na diretoria `defaults`.

Edita o ficheiro predefinido da *Role*:

```bash
nano ~/ansible/roles/webserver/defaults/main.yml
```

Substitui o conteúdo por:

```yaml
# defaults file for roles/webserver

ambiente_deploy: "Laboratório DevSecOps"
responsavel_ti: "Administrador de Sistemas"
```
*(Guarda com `CTRL+O`, `Enter` e sai com `CTRL+X`).*

---

## 2. Criar o Template Jinja2 (`.j2`)

Os *Templates* ficam guardados na pasta `templates` da *Role*. O motor de execução vai injetar nesta página as variáveis que definiste acima, cruzando-as com os **Ansible Facts** (informações que o Ansible recolhe automaticamente da máquina, como IP, *Hostname*, RAM e CPU no início de cada execução - `gather_facts: yes`).

Cria o ficheiro do *Template*:

```bash
nano ~/ansible/roles/webserver/templates/index.html.j2
```

Cola o seguinte código (repara na sintaxe `{{ variavel }}` de interpolação):

```html
<!DOCTYPE html>
<html>
<head>
    <title>Painel de Servidor - {{ ansible_hostname }}</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; background-color: #f4f4f9; }
        .card { background: white; padding: 20px; border-radius: 8px; box-shadow: 0 4px 8px rgba(0,0,0,0.1); max-width: 600px; }
        h1 { color: #333; }
        li { margin-bottom: 10px; }
    </style>
</head>
<body>
    <div class="card">
        <h1>Identidade do Servidor: {{ ansible_hostname }}</h1>
        <p>Esta pagina foi gerada dinamicamente via <strong>Ansible Jinja2</strong>.</p>
        
        <h3>Dados Técnicos Injetados (Facts):</h3>
        <ul>
            <li><strong>IP Principal (IPv4):</strong> {{ ansible_default_ipv4.address }}</li>
            <li><strong>Sistema Operativo:</strong> {{ ansible_distribution }} {{ ansible_distribution_version }}</li>
            <li><strong>Arquitetura:</strong> {{ ansible_architecture }}</li>
        </ul>

        <h3>Variáveis de Ambiente (Defaults):</h3>
        <ul>
            <li><strong>Ambiente:</strong> {{ ambiente_deploy }}</li>
            <li><strong>Responsável:</strong> {{ responsavel_ti }}</li>
        </ul>
    </div>
</body>
</html>
```
*(Guarda e sai).*

---

## 3. Substituir `copy` por `template` na Task

Agora temos de instruir o Ansible a parar de usar o módulo estático `copy` (que transfere ficheiros "cegos") e passar a usar o módulo `template` (que processa e compila as variáveis antes de entregar o ficheiro à máquina alvo).

Edita a lista de tarefas da tua *Role*:

```bash
nano ~/ansible/roles/webserver/tasks/main.yml
```

Altera **APENAS** a tarefa 02, substituindo `ansible.builtin.copy` por `ansible.builtin.template` e mudando o nome do ficheiro origem de `index.html` para `index.html.j2`. 

O bloco 02 deve ficar estritamente assim:

```yaml
- name: 02 - Injetar a pagina web dinamica (Template Jinja2)
  ansible.builtin.template:
    src: index.html.j2                 # Procura automaticamente na pasta 'templates'
    dest: /var/www/html/index.html
    owner: root
    group: root
    mode: '0644'
  notify: Reiniciar Nginx
```
*(Guarda e sai).*

---

## 4. Execução e Validação (Scaling Test)

Como apenas afinámos o comportamento interno da *Role*, a orquestração de alto nível mantém-se. Voltamos a executar o *Playbook* mestre do laboratório anterior.
Como a elevação de privilégios via `NOPASSWD` está ativa no Linux, não precisas de invocar o *Vault (--ask-vault-pass )* :

No terminal do teu *Controller*, dispara:

```bash
ansible-playbook -i ~/ansible/inventory/inventory.ini ~/ansible/playbooks/deploy-web.yml
```

> [!TIP]
> **Validação Final:** Faz um *refresh* (F5) à página no teu *browser* (`http://10.10.50.20`).
> 
> A página estática básica desapareceu, dando lugar a um painel que leu o sistema operativo da máquina alvo (ex: Ubuntu), descobriu o IP sozinho e injetou as variáveis de ambiente que definiste. 
> 
> **A verdadeira magia:** Se correres este exato *Playbook* contra um inventário de 50 servidores diferentes simultaneamente, cada máquina irá processar o *Template* localmente e servir a sua própria página, com o seu próprio IP e *Hostname* reais!