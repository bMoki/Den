# Pendências

Decisões em aberto que ainda não viraram ADR.

| Pendência | Impacto | Próximo passo | Status |
| --- | --- | --- | --- |
| Atalho "Abrir no app de banco" usa `ns db open`, que ainda não foi migrado para o núcleo | Sem ele, o atalho do banco no Thalamus não passa pelo `ns rpc` | Feito: `ns rpc` serve `dbOpen` (abre o app configurado no `ns`; sem app configurado, erro `pre-condicao` com o comando que resolve) | fechada |
| Criação com Repos opcionais no núcleo: `runNew` aceitar `repos` (manager, report-server, parents) e encadear Preparar, com falha parcial mantendo a Branch de workspace e permitindo repetir o Repo que falhou | Os checkboxes de "+ Branch" do Thalamus dependem disso | Feito: `ns rpc` serve `new` (com `repos`) e `addRepo`, que repete só o Repo que faltou; terminal ganha `ns new <branch> --with ...` | fechada |
| Migrar `pull` para o núcleo, devolvendo o resultado por Repo (`updated`, `up-to-date`, `skipped`, `failed`) e distinguindo conflito de outras falhas | O botão "Atualizar com a branch principal" do Thalamus depende disso | Feito: `ns rpc` serve `pull` com o estado de cada Repo, e conflito é um estado próprio (`conflict`, com os arquivos) | fechada |
| Iniciar, parar e reiniciar um Serviço isolado no núcleo (hoje `ns stop` só age sobre a branch inteira) | Botões por Serviço na barra de status do Thalamus | Feito: `ns start <branch> [serviço]` e `ns stop <branch> [serviço]`, servidos pelo `ns rpc` com `service`; Reiniciar é parar e iniciar, no Thalamus | fechada |
| Migrar `rm` para o núcleo, informando os Repos com alterações não commitadas antes de remover, com opção de apagar o volume do banco | Ação "Remover branch" do Thalamus (sem `--force`; checkbox "Apagar também o banco") | Feito: `ns rpc` serve `rmPreview` (Repos com alterações não commitadas, volume do banco) e `rm` (`purge`, sem `force`) | fechada |
| Migrar `db snapshot`, `db snapshots` e `db restore` para o núcleo | Snapshot e Restaurar no menu do banco do Thalamus | Migrar no cli, na branch `nucleo` | aberta |
| Sessão arquivada quando o app abre sem `ns` (ou com um `ns` sem `worktreesDir`): até o `ns` responder, ela aparece em "Outras pastas" e aceita mensagens | Viola a T-1.5 nessa janela | Decidir se o Thalamus guarda a pasta das worktrees ou as branches removidas entre execuções, ou se a janela é aceitável | aberta |
| Acabamento da Sessão arquivada: chip riscado da branch removida no cabeçalho (protótipo) e Terminal livre, que ainda abre na pasta que não existe | Sessão arquivada parece ativa no cabeçalho; o Terminal livre abre num shell sem pasta | Esconder ou desabilitar o Terminal livre e mostrar o chip da branch removida | aberta |
