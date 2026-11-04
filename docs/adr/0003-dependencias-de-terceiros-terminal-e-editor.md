---
id: ADR-0003
status: accepted
date: 2026-11-04
decision_owner: "Breno Sonda"
related_modules: []
related_specs: [docs/specs/thalamus-escopo.md]
related_issues: []
supersedes: []
superseded_by: []
keywords: [dependencias, spm, swiftterm, codeeditsourceeditor, terminal, editor, lsp]
---

# ADR-0003 — Dependências de terceiros para terminal e editor

## Contexto

O Den herdado não tem nenhuma dependência de terceiros: só SwiftUI, AppKit e os pacotes internos do HarnessKit. O repositório tem gates de qualidade (periphery, swiftlint, jscpd, mutation, coverage floor).

O Thalamus precisa de duas capacidades que o Den não tem:

- Um **terminal interativo de verdade** para o Console de Serviço (anexado à sessão tmux do Serviço) e para o Terminal livre, com entrada de teclado, cores e o console interativo do `quarkus:dev` e do vite.
- Um **editor de código** com realce, busca e salvar agora, que possa crescer até LSP (autocomplete, ir para a definição, erros inline) no futuro.

## Decisão

Decidimos adotar **SwiftTerm** para o terminal e **CodeEditSourceEditor** (tree-sitter) para o editor, via SPM e com versão fixada, em vez de construir os dois do zero ou embutir componentes web, porque um emulador de terminal completo e um editor que cresça até LSP são projetos do tamanho do app inteiro.

- As dependências ficam fora dos gates de qualidade, que continuam valendo para o código do Thalamus.
- Novas dependências de terceiros continuam exigindo decisão própria; esta ADR não abre a porta para qualquer biblioteca.

## Alternativas consideradas

- **Emulador de terminal próprio** sobre o PTY e o `ANSIParser` do Den. O Den só interpreta cor de log; um VT100/xterm completo (cursor, telas alternativas, mouse) é um projeto inteiro.
- **STTextView** como editor. Mais enxuto, mas todo o caminho até LSP ficaria por nossa conta.
- **WebView com Monaco e xterm.js.** Componentes maduros, mas trazem JavaScript e WebKit para dentro de um app nativo, com outra cadeia de build e outro modelo de foco e teclado.

## Consequências

- O app passa a depender da manutenção de dois projetos externos; atualizações exigem revisão.
- O caminho até LSP (escopo futuro) segue o do CodeEdit, em vez de ser desenhado do zero.
- O tamanho do binário e o tempo de build aumentam.

## Critérios de reversão

Se uma das dependências for abandonada ou bloquear a evolução (por exemplo, o caminho para LSP não se concretizar), substituir a dependência afetada por outra ou por implementação própria, numa nova ADR.
