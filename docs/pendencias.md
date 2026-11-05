# Pendências

Decisões em aberto que ainda não viraram ADR.

| Pendência | Impacto | Próximo passo | Status |
| --- | --- | --- | --- |
| Atalho "Abrir no app de banco" usa `ns db open`, que ainda não foi migrado para o núcleo | Sem ele, o atalho do banco no Thalamus não passa pelo `ns rpc` | Migrar `db open` para o núcleo quando chegar a vez | aberta |
| Criação com Repos opcionais no núcleo: `runNew` aceitar `repos` (manager, report-server, parents) e encadear Preparar, com falha parcial mantendo a Branch de workspace e permitindo repetir o Repo que falhou | Os checkboxes de "+ Branch" do Thalamus dependem disso | Feito: `ns rpc` serve `new` (com `repos`) e `addRepo`, que repete só o Repo que faltou; terminal ganha `ns new <branch> --with ...` | fechada |
| Migrar `pull` para o núcleo, devolvendo o resultado por Repo (`updated`, `up-to-date`, `skipped`, `failed`) e distinguindo conflito de outras falhas | O botão "Atualizar com a branch principal" do Thalamus depende disso | Migrar no cli, na branch `nucleo` | aberta |
| Iniciar, parar e reiniciar um Serviço isolado no núcleo (hoje `ns stop` só age sobre a branch inteira) | Botões por Serviço na barra de status do Thalamus | Feito: `ns start <branch> [serviço]` e `ns stop <branch> [serviço]`, servidos pelo `ns rpc` com `service`; Reiniciar é parar e iniciar, no Thalamus | fechada |
| Migrar `rm` para o núcleo, informando os Repos com alterações não commitadas antes de remover, com opção de apagar o volume do banco | Ação "Remover branch" do Thalamus (sem `--force`; checkbox "Apagar também o banco") | Migrar no cli, na branch `nucleo` | aberta |
| Migrar `db snapshot`, `db snapshots` e `db restore` para o núcleo | Snapshot e Restaurar no menu do banco do Thalamus | Migrar no cli, na branch `nucleo` | aberta |
