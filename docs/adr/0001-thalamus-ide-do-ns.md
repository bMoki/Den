---
id: ADR-0001
status: accepted
date: 2026-11-04
decision_owner: "Breno Sonda"
related_modules: []
related_specs: []
related_issues: []
supersedes: []
superseded_by: []
keywords: [fork, thalamus, ns-cli, produto, escopo]
---

# ADR-0001 — Thalamus: o fork do Den passa a ser a IDE do `ns`

## Contexto

O Den (upstream `Gabriel-Passoss/Den`) nasceu como orquestrador genérico de harnesses de IA, sob o princípio "orquestrador de harnesses, nunca um harness", independente de repositório ou empresa. Ele já tinha mecanismos próprios de worktree, de execução de processos e de Git.

O trabalho diário no NeuroSteps passa pelo `ns` cli, que já modela o ambiente de desenvolvimento: a Branch de workspace (worktrees de vários repos, banco próprio, serviços, aliases). Hoje o desenvolvedor alterna entre IDE, terminais, `ns` e o Den, e o Den não sabe nada do `ns`.

## Decisão

Decidimos transformar o fork `bMoki/Den` em **Thalamus**, a IDE do `ns`, em vez de manter o Den genérico com o `ns` como integração opcional, porque o objetivo passou a ser um ambiente único para o fluxo NeuroSteps, e o caráter genérico custaria abstrações que não queremos manter.

- O Thalamus é centrado no `ns`: a linguagem e os conceitos do `ns` são os do app.
- Funcionalidades do Den que não servem a esse fluxo podem ser descartadas.
- O upstream do Gabriel continua genérico e não é alterado por esta decisão.

## Alternativas consideradas

- **Mudar o próprio Den (upstream) para ser a IDE do `ns`**: quebraria o uso genérico do autor original.
- **Den genérico com um "modo `ns`"** ativado por detecção: duas personalidades no mesmo app, custo de manutenção alto, e cada feature precisaria funcionar nos dois modos.
- **`ns` como provedor opcional de worktree dentro do Den genérico**: mantém a abstração genérica, mas não entrega uma IDE centrada no `ns`.

## Consequências

- O princípio "orquestrador genérico" da fundação (`docs/superpowers/specs/2026-09-16-devspace-fundacao-design.md`) deixa de valer como norte de produto. O que for decidido sobre harnesses passa a servir ao fluxo do `ns`.
- Trazer melhorias de volta do upstream fica mais caro com o tempo. Melhorias genéricas do Thalamus (por exemplo, o explorador de arquivos) podem ser oferecidas ao upstream caso a caso.
- O glossário do Thalamus herda o do `ns` cli.
- O rename de target, bundle id e pastas para "Thalamus" é trabalho mecânico e pode vir depois.

## Critérios de reversão

Se o `ns` deixar de ser o centro do fluxo de desenvolvimento NeuroSteps, ou se mantivermos o fork sem divergência real do upstream, voltar a acompanhar o Den genérico.
