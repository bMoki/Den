# Thalamus — escopo e comportamento esperado

**Data:** 2026-11-04
**Status:** decidido, aguardando plano de implementação

Decisões de produto: [ADR-0001](../adr/0001-thalamus-ide-do-ns.md), [ADR-0002](../adr/0002-thalamus-adapter-do-nucleo-ns.md), [ADR-0003](../adr/0003-dependencias-de-terceiros-terminal-e-editor.md).
Linguagem: [CONTEXT.md](../../CONTEXT.md). Dependências do `ns` ainda não resolvidas: [pendencias.md](../pendencias.md).

Escrito em linguagem de negócio. As regras são numeradas e estáveis: uma regra que muda ganha número novo, não é reescrita.

## 1. Organização

- **T-1.1** A sidebar agrupa as Sessões em três grupos: **Branches de workspace**, **Repos base** e **Outras pastas** (Sessões avulsas).
- **T-1.2** O grupo de uma Sessão decorre da pasta dela, não de como foi aberta. Uma Sessão aberta por "abrir pasta" dentro de `~/Developer/worktrees/<branch>/` aparece sob aquela Branch de workspace.
- **T-1.3** A lista de Branches de workspace vem do `ns`, não de um cadastro do Thalamus.
- **T-1.4** Cada Branch de workspace mostra na sua linha o Estado dos seus Serviços e a situação dos PRs dos seus Repos.
- **T-1.5** Quando uma Branch de workspace é removida (pelo Thalamus ou pelo terminal), suas Sessões viram Sessões arquivadas: continuam legíveis e não aceitam novas mensagens.

## 2. Nova Branch de workspace

- **T-2.1** A ação "+ Branch" pede o nome da branch e oferece os Repos opcionais como opções: manager (marcado), report-server e parents (desmarcados). Base padrão: a do `ns`.
- **T-2.2** O Thalamus não sugere nome de branch e não se liga ao Jira.
- **T-2.3** A criação cria a Branch de workspace e em seguida a prepara (banco no ar, aliases, dependências), mostrando o progresso. Nenhum Serviço é iniciado.
- **T-2.4** Perguntas que o `ns` fizer no meio da criação aparecem como diálogo no Thalamus.
- **T-2.5** Se um Repo opcional falhar depois de a Branch de workspace ter sido criada, ela é mantida, o erro é mostrado e o Thalamus oferece repetir a inclusão daquele Repo.
- **T-2.6** Ao terminar, abre uma Sessão do Claude Code na raiz da Branch de workspace, sem mensagem inicial.

## 3. Serviços

- **T-3.1** Cada Serviço mostra seu Estado: Parado, Iniciando, Rodando ou Falhou. O banco só mostra Parado ou Rodando.
- **T-3.2** A Branch de workspace tem as ações Iniciar e Parar, que agem sobre todos os seus Serviços.
- **T-3.3** Cada Serviço tem as ações Iniciar, Parar, Reiniciar e **Abrir console**.
- **T-3.4** O Console é o terminal interativo do Serviço: aceita teclado (por exemplo, `r` no `quarkus:dev`). Fechar o Console não para o Serviço.
- **T-3.5** O Thalamus nunca é dono de um Serviço. Fechar o Thalamus não para nenhum Serviço, e o Thalamus acompanha Serviços iniciados pelo terminal ou antes de ele abrir.
- **T-3.6** Num Serviço que Falhou, o Console mostra a saída do erro.
- **T-3.7** O banco não tem Console. Tem o atalho "Abrir no app de banco" (DataGrip ou o app configurado no `ns`).
- **T-3.8** Cada Serviço e o banco são marcados no Thalamus por um indicador. A cor do indicador é sempre o Estado; a forma identifica qual Serviço é. O mesmo indicador aparece em todo lugar onde o Serviço aparece: linha da Branch de workspace, painel de Serviços e abas de Console.
- **T-3.9** Os Ajustes têm a aba **Indicadores**, com uma seção Serviços (backend, frontend, manager, report-server) e uma seção Banco. As linhas são sempre as mesmas, existam ou não Branches de workspace com aquele Serviço. O banco tem linha própria, mas continua não sendo um Serviço.
- **T-3.10** A aba tem um Estilo geral: **Pontos** (um ponto por Serviço e um quadrado para o banco, sem distinguir qual é qual) ou **Ícones** (um ícone por Serviço). O padrão é Pontos. Voltar a Pontos guarda os ícones escolhidos para quando se voltar a Ícones.
- **T-3.11** Cada linha escolhe um ícone entre as sugestões daquele Serviço, todos os ícones e logos que o Thalamus traz, ou um nome de símbolo do sistema digitado à mão. Um nome que não existe não é aceito; um nome aceito que deixa de existir aparece como ponto. Não há importação de logos próprios.
- **T-3.12** Dois Serviços podem ter o mesmo ícone, sem aviso.
- **T-3.13** Os ícones padrão são os logos da tecnologia de cada Serviço: Quarkus no backend, Vite no frontend, Tailwind no manager, Bun no report-server; o banco tem um cilindro. "Restaurar padrões" volta o Estilo a Pontos e os ícones a esses.

## 4. Banco: Snapshot e Restaurar

- **T-4.1** O menu do banco oferece **Tirar snapshot** (pede um nome), **Restaurar** e a lista de Snapshots da branch, com opção de remover.
- **T-4.2** Restaurar lista os Snapshots agrupados por branch de origem: primeiro a branch atual, depois `master`, depois as demais. É possível restaurar a partir de outra branch.
- **T-4.3** A confirmação de Restaurar mostra a referência completa (`origem:nome`) e a branch alvo.
- **T-4.4** Se houver Serviços Rodando, a confirmação avisa, mas o Thalamus não os para nem os reinicia.

## 5. Atualizar com a branch principal

- **T-5.1** Cada Branch de workspace tem a ação **Atualizar com a branch principal**, que traz a Branch principal de cada Repo para dentro dela. Só roda quando acionada.
- **T-5.2** O resultado é mostrado por Repo: atualizado, já em dia, ignorado ou falhou.
- **T-5.3** Em conflito, o Thalamus só informa qual Repo ficou em conflito. A resolução é feita pelo desenvolvedor, normalmente pedindo na Sessão em que já está.
- **T-5.4** Sincronizar a própria branch a partir do remoto está fora de escopo.

## 6. Remover branch

- **T-6.1** A ação **Remover branch** pede confirmação e lista os Repos com alterações não commitadas.
- **T-6.2** Se houver alterações não commitadas, a remoção é bloqueada; o Thalamus não força.
- **T-6.3** A confirmação tem a opção "Apagar também o banco", desmarcada por padrão.

## 7. Arquivos

- **T-7.1** A árvore de arquivos mostra a pasta da Sessão selecionada, e só ela. Trocar de Sessão troca a árvore.
- **T-7.2** Cada arquivo mostra sua situação no git (modificado, novo). Arquivos ignorados pelo git aparecem esmaecidos ou ocultos.
- **T-7.3** A árvore permite criar, renomear, mover e excluir (para a lixeira), revelar no Finder, copiar caminho e mencionar o arquivo na Sessão.
- **T-7.4** Arquivos abrem num editor com realce de sintaxe, busca e salvar. Markdown e imagens têm visualização própria; há diff do arquivo contra o git.
- **T-7.5** Quando o arquivo muda no disco (por exemplo, editado pelo agente):
  - sem alterações não salvas, o editor recarrega sozinho;
  - com alterações não salvas, o editor avisa e oferece Recarregar, Comparar ou Manter a minha.
- **T-7.6** O Thalamus nunca bloqueia o agente de escrever num arquivo aberto no editor.
- **T-7.7** Autocomplete, ir para a definição e erros inline (LSP) estão fora de escopo agora e previstos para o futuro.

## 8. Terminal livre

- **T-8.1** Qualquer Sessão, inclusive avulsa, pode abrir Terminais livres na sua pasta.
- **T-8.2** Terminais livres se encerram quando o Thalamus fecha.

## 9. Sessão avulsa

- **T-9.1** Uma Sessão avulsa tem árvore de arquivos, editor e Terminal livre, e nada do `ns`: sem Serviços, sem Atualizar com a branch principal, sem banco.

## 10. Harnesses

- **T-10.1** Claude Code e OpenCode continuam suportados, assim como a troca de harness dentro da Sessão.
- **T-10.2** O Thalamus não acrescenta contexto próprio às Sessões; não há modo "raw".

## 11. O que sai do Den

| Sai | Substituído por |
| --- | --- |
| Folders livres da sidebar | Grupos de T-1.1 |
| Criação de worktree do Den (planejador, criador, sugestão de nome de branch, escolha de repos, envio do pedido como primeira mensagem) | Nova Branch de workspace pelo `ns` (seção 2) |
| Run configurations e execução de processos em PTY próprio | Serviços do `ns` (seção 3) |
| Registro de worktree e PRs por Sessão | PRs acompanhados por Branch de workspace e Repo (T-1.4) |

Ficam: chat e composer, permissões, slash, menções, painel de contexto, alterações do git, acompanhamento de PRs (agora por Branch de workspace), Claude Code, OpenCode e handoff.

## 12. Fora de escopo

- Integração com o Jira.
- Modo "raw" ou controle do contexto carregado pelo harness.
- Sincronizar a própria branch a partir do remoto.
- LSP no editor (futuro).
