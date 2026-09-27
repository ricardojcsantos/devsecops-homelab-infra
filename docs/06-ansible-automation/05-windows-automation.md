# Playbook: Automação e Hardening (Windows Server)

> [!NOTE]
> **Objetivo:** Demonstrar a capacidade multiplataforma do Ansible. Este laboratório aplica configurações de gestão e *hardening* num servidor Windows através do protocolo WinRM, utilizando módulos nativos para alinhar o sistema operativo com os standards de segurança empresarial (RGPD, CIS Benchmarks e prevenção de *ransomware*).

---

## 1. O Código YAML (`windows_hardening.yml`)

Cria o ficheiro do *Playbook* na diretoria que já estabelecemos:

```bash
nano ~/ansible/playbooks/windows_hardening.yml
```

Cola o seguinte código YAML. A indentação (espaços à esquerda) é rigorosa. Usa sempre espaços, nunca a tecla `TAB`.

```yaml
---
# ==============================================================================
# Playbook: Hardening Essencial Windows (Segurança Base e RGPD)
# ==============================================================================

- name: Aplicar politicas de seguranca e compliance em Windows
  hosts: lab_windows
  gather_facts: yes

  tasks:
    # --------------------------------------------------------------------------
    # PROTEÇÃO CONTRA RANSOMWARE E EXPLORAÇÃO REMOTA
    # --------------------------------------------------------------------------
    - name: 01 - Desativar protocolo obsoleto SMBv1
      ansible.windows.win_feature:
        name: FS-SMB1
        state: absent
      # Fundamento: O SMBv1 é o vetor principal de propagação de malware (ex: WannaCry).
      # Num ambiente moderno, nunca deve estar ativo.

    - name: 02 - Desativar o servico Print Spooler
      ansible.windows.win_service:
        name: Spooler
        state: stopped
        start_mode: disabled
      # Fundamento: Elimina vulnerabilidades críticas de elevação de privilégios 
      # (ex: PrintNightmare) em servidores que não precisam de imprimir.

    # --------------------------------------------------------------------------
    # PROTEÇÃO DE REDE
    # --------------------------------------------------------------------------
    - name: 03 - Ativar a Windows Firewall em todos os perfis
      ansible.windows.win_firewall:
        profiles:
          - Domain
          - Private
          - Public
        state: enabled
      # Fundamento: Garante que o tráfego não solicitado é bloqueado ao nível do SO,
      # atuando como segunda linha de defesa após o router/firewall de perímetro.

    # --------------------------------------------------------------------------
    # COMPLIANCE RGPD E AUDITORIA (CNCS / ISO 27001)
    # --------------------------------------------------------------------------
    - name: 04 - Ativar auditoria de acesso a ficheiros (Visibilidade Forense)
      community.windows.win_audit_policy_system:
        subcategory: File System
        audit_type: success, failure
      # Fundamento: Sem isto ativado, o Windows não regista quem acedeu, alterou 
      # ou apagou ficheiros. É impossível reportar uma violação de dados sem este log.

    - name: 05 - Garantir tamanho adequado para o log de seguranca (512MB)
      ansible.windows.win_eventlog:
        name: Security
        maximum_size: "512MB"
      # Fundamento: Como ativámos a auditoria no passo anterior, os logs vão crescer rápido.
      # Aumentar o limite evita que os eventos antigos sejam apagados antes do backup.

```
*(Guarda com `CTRL+O`, `Enter` e sai com `CTRL+X`).*

---

## 2. Anatomia do Playbook (Perspetiva de Arquitetura)

* **Multiplataforma Transparente:** Repara que a lógica das tarefas é exatamente igual à do Linux (Name -> Module -> Arguments), alterando apenas a coleção de módulos (`ansible.builtin` vs `ansible.windows` / `community.windows`).

* **Segurança Profunda (Defense in Depth):** As tarefas 01, 02 e 03 tapam vetores de ataque laterais. Mesmo que um atacante entre na VLAN de laboratório, não conseguirá usar exploits antigos nem saltar entre máquinas sem ser bloqueado pela *firewall* local.

* **Foco no Negócio (Tarefas 04 e 05):** A automação não serve só para instalar pacotes. Escalar automaticamente o tamanho do *Security Log* garante que os eventos antigos não são subscritos (apagados) antes do *Backup Server* os recolher, garantindo o cumprimento legal do RGPD em caso de incidente cibernético.

---

## 3. Execução e Validação

Como este ambiente requer a injeção da palavra-passe de ligação, temos de chamar a *flag* do cofre para desencriptar o ficheiro `lab_windows.yml` em memória.

Executa o comando no Controlador:

```bash
ansible-playbook -i ~/ansible/inventory/inventory.ini ~/ansible/playbooks/windows_hardening.yml --ask-vault-pass
```

> [!TIP]
> **Output Esperado:** Ao correr o código, o Ansible vai comunicar via WinRM (porta 5986) e executar os módulos traduzindo o YAML para PowerShell nativo. O protocolo vulnerável será removido, a Firewall ativada e a auditoria ligada. Se correres o Playbook uma segunda vez, tudo deverá aparecer a Verde (`changed=0`), provando que a idempotência no Ansible funciona de forma idêntica, independentemente do sistema operativo.