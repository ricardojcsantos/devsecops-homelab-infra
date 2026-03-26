# Estratégia de Backups e Recuperação de Desastres

> [!NOTE]
> **Objetivo:** Garantir que conseguimos recuperar a infraestrutura toda do zero de forma rápida. Usamos backups automáticos e à prova de erros, guardados de forma centralizada no Proxmox Backup Server (PBS).

---

## 1. O Problema das Cópias Estragadas

Copiar os ficheiros do Docker (como o Nextcloud ou o Immich) enquanto eles estão a trabalhar estraga as bases de dados. Se a cópia for feita no milissegundo em que uma foto está a ser gravada, o backup fica corrompido.

Para resolver isto, o nosso sistema faz primeiro uma "cópia limpa" (chamada *Dump*) das bases de dados, guardando-as de forma segura antes da cópia principal da máquina.

---

## 2. O Que Guardamos (E como poupamos espaço)

O PBS é inteligente: não guarda a mesma coisa duas vezes. Se um ficheiro de 10GB só tiver uma alteração de 1MB hoje, o backup só vai ocupar esse 1MB extra no disco.

| O que estamos a guardar              | Como extraímos os dados             | Onde guardamos            | Frequência               |
| :----------------------------------- | :---------------------------------- | :------------------------ | :----------------------- |
| **pfSense (Router)**                 | Envio Automático para a Nuvem       | Nuvem da Netgate          | Sempre que há alterações |
| **Proxmox Host (O Servidor)**        | Script que "zipa" as redes e VMs    | Cofre PBS (Disco Backups) | Diário                   |
| **Passwords e Domínios**             | Cópias seguras a quente (SQLite)    | Cofre PBS (Disco Backups) | Diário                   |
| **Bases de Dados (Fotos/Ficheiros)** | Exportação limpa das tabelas (SQL)  | Cofre PBS (Disco Backups) | Diário                   |
| **Máquinas Virtuais Inteiras**       | "Fotografia" exata ao disco inteiro | Cofre PBS (Disco Backups) | Diário                   |

---

## 3. O Passo-a-Passo de Madrugada

Tudo acontece sozinho durante a noite, para não deixar o servidor lento durante o dia:

* **03:30 (Preparação):** O sistema extrai as cópias limpas das bases de dados e das passwords, e guarda-as numa pasta segura dentro da própria máquina.

* **04:00 (O Backup Principal):** O Proxmox tira uma "fotografia" ao disco inteiro da máquina virtual (que já inclui a preparação feita às 03:30) e envia tudo para o disco de backups. O próprio servidor Proxmox também envia as suas configurações de rede nesta hora.

* **Sábado às 06:00 (Limpeza):** O sistema faz a manutenção do disco de backups, eliminando definitivamente o lixo digital para recuperar espaço físico.

---

## 4. Regra de Limpeza (Para o disco não encher)

Como o espaço no disco é limitado, não podemos guardar backups de meses inteiros. Implementámos uma regra estrita de segurança:

* **Manter apenas 3 dias:** O sistema guarda sempre, e apenas, as 3 cópias mais recentes. 
* **Limpeza Automática:** Assim que um backup atinge o 4º dia de idade, ele é apagado automaticamente para dar espaço ao novo.