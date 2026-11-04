---
id: ADR-0002
status: accepted
date: 2026-11-04
decision_owner: "Breno Sonda"
related_modules: []
related_specs: []
related_issues: []
supersedes: []
superseded_by: []
keywords: [adapter, nucleo, ns-rpc, servico, tmux, stdio, ndjson]
---

# ADR-0002 — O Thalamus é um adapter do núcleo do `ns` e fala com ele por `ns rpc`

## Contexto

O Thalamus é a IDE do `ns` (ADR-0001). Ele precisa iniciar e acompanhar Serviços, criar Branches de workspace e fazer pull, e tudo isso é lógica do `ns`.

A ADR-0002 do `ns` cli ("Núcleo e adapters", branch `nucleo`) reorganiza o `ns` em **núcleo** mais **adapters**:

- Cada operação é `run(input, ctx) => Result`, com `ctx.emit` para progresso e `ctx.ask` para perguntas no meio da operação.
- O núcleo devolve o **Plano de serviços** em vez de executá-lo.
- **Nenhum adapter é dono de um Serviço.** A identidade do Serviço é a porta. Cada Serviço roda numa sessão tmux destacada, com log em arquivo de caminho ditado pelo núcleo. Os adapters ficam proibidos de segurar processos por pipe ou handle.
- O núcleo é uma biblioteca TypeScript. Plugins de adapter são programas que a importam.

O Den herdado tinha um módulo `Run` que executa processos num PTY próprio. O Thalamus é escrito em Swift e não importa TypeScript.

## Decisão

Decidimos que o Thalamus é **um adapter do núcleo do `ns`**, no mesmo nível do terminal e do browser, e que fala com o núcleo por um **adapter stdio no próprio `ns` (`ns rpc`)**: um processo de longa duração que troca NDJSON (`op`/`input` de ida; `event`, `ask`, `result`/`error` de volta, e respostas a `ask`). Escolhemos isso em vez de um plugin Bun separado ou de shell-out por comando porque o protocolo stdio serve a qualquer cliente que não seja TypeScript, vive junto com o núcleo e suporta progresso e perguntas no meio da operação.

- O Thalamus **nunca é dono de um Serviço**. Fechar o Thalamus não derruba nenhum Serviço. Parar é sempre um ato explícito.
- O Thalamus acompanha Serviços pelos mecanismos do núcleo (arquivo de log, sessão tmux), inclusive os que subiram antes de ele abrir ou que foram iniciados pelo terminal.
- O módulo `Run` do Den não é usado para Serviços.

## Alternativas consideradas

- **Thalamus executa o Plano de serviços num PTY próprio** (reaproveitando o módulo `Run`). Violaria a regra de que nenhum adapter é dono de um Serviço: fechar o Thalamus mataria ou emudeceria os Serviços.
- **Plugin Bun separado** que importa o núcleo e expõe o protocolo. Segue a ADR do cli ao pé da letra, mas é mais um binário para instalar e versionar, e só serviria ao Thalamus.
- **Shell-out de `ns <comando> --json`** por operação. Não responde a `ask` nem transmite progresso; a ADR do cli já o descartou para o browser pelo mesmo motivo.

## Consequências

- Os itens do Thalamus que dependem do `ns` (criar Branch de workspace, iniciar e ver Serviços, pull) dependem de o núcleo migrar essas operações e de o `ns rpc` existir.
- O `ns rpc` precisa de uma decisão própria no repo do cli (pendente).
- O tmux passa a ser dependência do fluxo do Thalamus, herdada do núcleo.
- O Thalamus não ganha supervisão própria (restart automático, health check). Isso continua fora de qualquer adapter.

## Critérios de reversão

Se o núcleo do `ns` não for adiante, ou se a regra de que nenhum adapter é dono de um Serviço for revogada no cli, reavaliar a execução de Serviços pelo próprio Thalamus.
