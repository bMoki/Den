---
id: ADR-0004
status: accepted
date: 2026-11-09
decision_owner: "Breno Sonda"
related_modules: []
related_specs: [docs/specs/thalamus-escopo.md]
related_issues: []
supersedes: []
superseded_by: []
keywords: [console, terminal-livre, editor, abas, sessao, pagina-da-linha, sidebar]
---

# ADR-0004 — Console, Terminal livre e abas do editor pertencem à linha, não à Sessão

## Contexto

Até aqui, tudo o que o Thalamus mostra em volta da conversa pertencia à Sessão: o Console de cada Serviço, os Terminais livres e as abas abertas do editor. Duas Sessões da mesma Branch de workspace tinham, cada uma, o seu Console do backend (dois terminais anexados ao mesmo tmux), os seus Terminais livres e as suas abas. Trocar de Sessão escondia o terminal que estava rodando e as abas dos arquivos em revisão, embora fossem a mesma pasta.

Com a página da linha (T-1.22), a sidebar passou a ter linhas (Branch de workspace, Repo base, pasta de Outras pastas) com uma página própria, sem conversa. Nessa página não havia onde abrir um Console, porque o Console só existia dentro de uma Sessão.

## Decisão

Decidimos que o Console, o Terminal livre e as abas do editor pertencem à linha da sidebar, e não à Sessão, porque são da pasta e da branch, não da conversa, e porque assim a página da linha funciona sem uma Sessão aberta.

- O Console é da Branch de workspace, como o Serviço: aberto uma vez, aparece em todas as Sessões dela e na página; fechar fecha em todos os lugares (T-3.14).
- O Terminal livre é da linha e abre sempre na raiz dela (T-8.1).
- As abas do editor são da linha: as mesmas abas, na mesma ordem, em todas as Sessões dela (T-7.8).
- A página da linha tem tudo o que a Sessão tem, menos a conversa (T-1.27).
- Continuam da Sessão: a conversa, a fila, o histórico do composer, o título, o Estado de Sessão e as preferências do harness.

## Alternativas consideradas

- **Manter tudo por Sessão e a página delegar.** Abrir o Console pela página abriria a última Sessão da branch. Esconde o Console de quem não quer abrir uma conversa e mantém os Consoles duplicados entre Sessões.
- **Painel próprio na página, separado dos das Sessões.** Resolve a página, mas deixa o mesmo Console aberto em vários lugares sem relação entre si.
- **Só o Console passa para a branch.** Coerente com o Serviço, mas deixa abas e Terminais livres sumindo ao trocar de Sessão na mesma pasta.

## Consequências

- O painel de uma Sessão mostra terminais e abas que não foram abertos nela.
- Apagar uma Sessão não fecha abas nem pergunta por alterações não salvas; quem fecha abas e terminais de uma branch é a remoção dela, que também passa a bloquear por aba não salva (T-6.4).
- Uma Sessão aberta dentro de um Repo (`NS-1203/frontend`) abre Terminal livre na raiz da branch, não na pasta dela.

## Critérios de reversão

Se a convivência de várias Sessões na mesma linha virar o caso comum e o compartilhamento atrapalhar (abas ou terminais de um trabalho misturados com os de outro), voltar a separar por Sessão o que estiver atrapalhando, numa nova ADR.
