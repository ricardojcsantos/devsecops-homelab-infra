# O Primeiro Playbook (Hardening Linux)

> [!NOTE]
> **Objetivo:** Criar um *Playbook* idempotente que automatize a segurança base da VM Linux (Lab). Vamos atualizar o sistema, configurar a firewall (UFW) e trancar o serviço SSH para não aceitar passwords (apenas a chave criptográfica que configurámos na Fase 3).

### 1. O Padrão DevSecOps (Bypass de PAM)

Sistemas operativos modernos (como o Ubuntu 26.04) utilizam módulos PAM estritos que bloqueiam a injeção de passwords de *sudo* via automação (resultando num `Timeout (12s)`). Em ambientes empresariais, a conta de serviço `ansible` nunca utiliza password para elevação de privilégios. A segurança é delegada à criptografia assimétrica (Chave SSH).

**Pré-Requisito Obrigatório (Configuração no Alvo):**
Antes de executar qualquer automação que exija privilégios, o servidor alvo tem de autorizar o utilizador de serviço a executar comandos sem barreira interativa.

Acesso ao servidor alvo (ex: `10.10.50.20`):
```bash
# 1. Entra na máquina alvo
ssh ansible@10.10.50.20

# 2. Configura a elevação de privilégios sem password para o utilizador ansible
echo "ansible ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/ansible

# 3. Sai do servidor alvo
exit
```
## 2. Estrutura de Diretórios

Para manter a organização, os *playbooks* devem ficar numa pasta própria. No teu Controlador, cria a diretoria e o ficheiro:

```bash
mkdir -p ~/ansible/playbooks
nano ~/ansible/playbooks/linux-hardening.yml
```

## 2. O Código YAML

Cola o seguinte código. No Ansible, a indentação (espaços à esquerda) é rigorosa. Usa sempre espaços, nunca a tecla TAB.

```yaml
- name: Aplicar politicas de seguranca no ambiente Linux
  hosts: lab_linux           # O grupo alvo definido no inventory.ini
  become: yes                # Exige elevacao de privilegios (sudo)
  gather_facts: yes          # Recolhe informacoes do sistema (IPs, SO, RAM) antes de comecar

  tasks:
    - name: 01 - Garantir que o sistema operativo esta atualizado
      ansible.builtin.apt:
        update_cache: yes      # Equivalente a 'apt update'
        upgrade: dist          # Equivalente a 'apt upgrade' (instala as novidades do SO)
        cache_valid_time: 3600 # So atualiza os repositorios se o ultimo update foi ha mais de 1 hora

    - name: 02 - Configurar Fuso Horario (Timezone) para Portugal
      community.general.timezone:
        name: Europe/Lisbon    # Vital para analise forense e correlacao de logs

    - name: 03 - Instalar a firewall UFW (Uncomplicated Firewall)
      ansible.builtin.apt:
        name: ufw
        state: present         # Garante que esta instalada (Idempotencia)

    - name: 04 - Configurar UFW para permitir ligacoes SSH (Porta 22)
      community.general.ufw:
        rule: allow
        port: '22'
        proto: tcp
      # ALERTA: Se não abrirmos a porta 22 antes de ligar a firewall na tarefa seguinte, perdemos o acesso!

    - name: 05 - Ativar a firewall UFW e definir politica padrao (Negar Tudo)
      community.general.ufw:
        state: enabled
        default: deny          # Bloqueia qualquer trafego de entrada nao especificado

    - name: 06 - Desativar autenticacao por password no SSH (Forcar chaves)
      ansible.builtin.lineinfile:
        path: /etc/ssh/sshd_config
        regexp: '^#?PasswordAuthentication' # Procura a diretiva, esteja ela comentada ou nao
        line: 'PasswordAuthentication no'   # Substitui pela configuracao segura
      notify: Reiniciar servico SSH         # Se fizer alteracoes, aciona o 'handler' no final

  # HANDLERS: Tarefas reativas. So correm se forem chamadas por um "notify" de uma tarefa que mudou de estado.
  handlers:
    - name: Reiniciar servico SSH
      ansible.builtin.service:
        name: ssh
        state: restarted
```
*(Guarda com `CTRL+O`, `Enter` e sai com `CTRL+X`).*

### 3. Execução Limpa do Playbook

Como implementámos a elevação via `NOPASSWD`, já não precisamos de fornecer a flag `--ask-vault-pass` para este servidor. A execução torna-se 100% autónoma, pronta a ser integrada num *pipeline* de CI/CD.

Dispara o comando no terminal:
```bash
ansible-playbook -i ~/ansible/inventory/inventory.ini ~/ansible/playbooks/linux-hardening.yml
```

### O que observar no output:
1. **Verde (OK):** O sistema verificou o estado e já estava em conformidade (ex: a firewall já estava instalada).
2. **Amarelo (CHANGED):** O sistema fez uma alteração (ex: ativou a firewall ou alterou o ficheiro do SSH).
3. **Vermelho (FAILED):** Houve um erro crítico.
4. **Resumo Final (PLAY RECAP):** Mostra o total de tarefas com sucesso, alteradas ou falhadas. Se correres o mesmo playbook duas vezes seguidas, a segunda vez deverá dar 0 tarefas alteradas (tudo a verde), provando a **idempotência**.