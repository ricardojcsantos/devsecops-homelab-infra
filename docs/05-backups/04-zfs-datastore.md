# Criação do Cofre ZFS (Datastore)

> [!NOTE]
> **Objetivo:** Preparar o armazenamento físico. Vamos formatar o disco num formato inteligente chamado ZFS, que comprime os ficheiros automaticamente para poupar espaço e verifica se eles não estão estragados.

---

## 1. Limpeza do Disco Físico 

Antes de formatar, é obrigatório apagar qualquer tabela de partições antiga que o disco possa ter.

* No menu lateral esquerdo, aceder a **Administration** > **Storage / Disks**.
* Na lista central, localizar o disco destinado aos backups (em laboratório vou usar: um disco NVME).
* Selecionar o disco e clicar no botão **Wipe Disk** no topo.
* Confirmar a operação (Aviso: Esta ação destrói todos os dados do disco).

---

## 2. Injeção da Pool ZFS e Datastore

O PBS automatiza a criação do Datastore quando formatamos o disco em ZFS através da interface web.

* Aceder a **Administration** > **Storage / Disks** > **ZFS**.
* Clicar no botão **Create: ZFS**.
* Preencher os parâmetros exatos de engenharia:
  * **Name:** `backup-pool` (Nome lógico do cofre).
  * **RAID Level:** `Single` (Nota: Em ambientes de produção *Enterprise*, usar obrigatoriamente `Mirror` ou `RAIDZ2`).
  * **Compression:** `on` (Ativa compressão nativa LZ4 para reduzir operações de escrita).
  * **ashift:** `12` (Força o alinhamento de blocos a 4K, standard para discos modernos).
  * **Device:** Selecionar o disco que acabou de ser limpo.
* Clicar em **Create**.

---

## 3. Validação de Sistema

Após a conclusão da formatação, o sistema monta o repositório imediatamente.

* Olhar para o menu principal do lado esquerdo.
* Debaixo da secção **Datastores**, confirmar que apareceu um novo cofre com o nome `backup-pool`.
* Clicar em `backup-pool` e depois em **Summary** para verificar o espaço total disponível e garantir que não existem erros de I/O. 