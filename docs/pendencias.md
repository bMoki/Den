# Pendências

Decisões em aberto que ainda não viraram ADR.

| Pendência | Impacto | Próximo passo | Status |
| --- | --- | --- | --- |
| ADR do `ns rpc` no repo do cli (adapter stdio, NDJSON `op`/`event`/`ask`/`result`) | Bloqueia a integração descrita na ADR-0002 | Escrever como ADR-0003 do cli, na branch `nucleo`, depois da ADR-0002 do cli | aberta |
| `runStatus` do núcleo distinguir Iniciando e Falhou (hoje devolve só booleano por Serviço, a partir de porta e container) | A barra de status do Thalamus precisa dos quatro Estados de Serviço | Mudar no cli, na branch `nucleo`; beneficia também `ns status` | aberta |
| Atalho "Abrir no app de banco" usa `ns db open`, que ainda não foi migrado para o núcleo | Sem ele, o atalho do banco no Thalamus não passa pelo `ns rpc` | Migrar `db open` para o núcleo quando chegar a vez | aberta |
| Criação com Repos opcionais no núcleo: `runNew` aceitar `repos` (manager, report-server, parents) e encadear Preparar, com falha parcial mantendo a Branch de workspace e permitindo repetir o Repo que falhou | Os checkboxes de "+ Branch" do Thalamus dependem disso | Mudar no cli, na branch `nucleo` (etapa 03); terminal ganha `ns new <branch> --with ...` | aberta |
| Migrar `pull` para o núcleo, devolvendo o resultado por Repo (`updated`, `up-to-date`, `skipped`, `failed`) e distinguindo conflito de outras falhas | O botão "Atualizar com a branch principal" do Thalamus depende disso | Migrar no cli, na branch `nucleo` | aberta |
| Iniciar, parar e reiniciar um Serviço isolado no núcleo (hoje `ns stop` só age sobre a branch inteira) | Botões por Serviço na barra de status do Thalamus | Migrar `start`/`stop` aceitando um Serviço específico, na branch `nucleo` | aberta |
| Migrar `rm` para o núcleo, informando os Repos com alterações não commitadas antes de remover, com opção de apagar o volume do banco | Ação "Remover branch" do Thalamus (sem `--force`; checkbox "Apagar também o banco") | Migrar no cli, na branch `nucleo` | aberta |
| Migrar `db snapshot`, `db snapshots` e `db restore` para o núcleo | Snapshot e Restaurar no menu do banco do Thalamus | Migrar no cli, na branch `nucleo` | aberta |
