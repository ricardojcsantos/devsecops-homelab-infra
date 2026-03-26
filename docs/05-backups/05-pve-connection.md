# Ligar o Proxmox ao Servidor de Backups

> [!NOTE]
> **Objetivo:** Fazer a ligação entre o servidor principal (onde estão as Máquinas Virtuais) e o novo cofre de backups. Para ser seguro, eles vão comunicar através de uma impressão digital encriptada.

---

## 1. Obter a "Impressão Digital" do Cofre

O servidor principal precisa de uma prova de identidade (Fingerprint) para ter a certeza de que está a falar com o teu PBS.

* Aceder à interface web do teu Proxmox Backup Server (`https://10.10.1.253:8007`).
* No menu do lado esquerdo, clica em **Dashboard** (é a primeira opção).
* Olhar para a zona central superior do ecrã e clica no botão **Show Fingerprint** (Mostrar Impressão Digital).
* Vai aparecer uma janela com um código muito comprido. Clicar no botão **Copy** (Copiar).

---

## 2. Adicionar o Cofre ao Proxmox Principal

Agora vamos ao servidor onde correm as Máquinas Virtuais e o Docker para lhe dizer onde ele deve guardar as coisas.

* Acede à interface web do teu **Proxmox VE** (o principal).
* No menu do lado esquerdo, clica em **Datacenter**.
* Na coluna do meio, clica em **Storage** (Armazenamento).
* No topo, clica em **Add** (Adicionar) e escolhe **Proxmox Backup Server**.
* Preenche a janela exatamente com estes dados:

| Campo           | O que deves escrever                                        |
| :-------------- | :---------------------------------------------------------- |
| **ID**          | `pbs-local` (É o nome que vai aparecer na tua lista)        |
| **Server**      | `10.10.1.253` (O IP do teu Backup Server)                   |
| **Username**    | `root@pam` (A conta de sistema principal do PBS)            |
| **Password**    | *A tua password* (A que usas para entrar com o root no PBS) |
| **Datastore**   | `backup-pool` (O nome do cofre que formatámos)              |
| **Fingerprint** | *Colar aqui o código* (Aquele que copiaste no Passo 1)      |

* Clica no botão **Add**.

---

## 3. Confirmar a Ligação

Se tudo correr bem, o Proxmox principal já tem acesso direto ao disco de backups.

* Olhar para o menu do lado esquerdo do teu **Proxmox VE**.
* Na lista de discos, deve ter aparecido um novo chamado `pbs-local`.
* Clicar em cima dele e depois em **Summary**. 
* Se vires o gráfico com o espaço livre do disco, a ligação foi um sucesso!