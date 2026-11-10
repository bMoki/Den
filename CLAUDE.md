# Thalamus (app Den)

A IDE do `ns`, um app macOS em SwiftUI. Leia antes de mexer:

- [docs/fluxo.md](docs/fluxo.md): o fluxo de trabalho, o Thalamus Dev isolado,
  a release e onde fica cada coisa.
- [docs/quality.md](docs/quality.md): os gates e como rodá-los.
- [CONTEXT.md](CONTEXT.md) e [docs/adr/](docs/adr/): a linguagem do domínio e
  as decisões.
- [docs/pendencias.md](docs/pendencias.md): o que ficou aberto.
- Tickets: `../.scratch/thalamus-ide/issues/`.

## Den real e Thalamus Dev

- O Den em `/Applications` é o que o usuário usa de verdade. Nunca o abra,
  feche ou troque, e nunca toque em `~/Library/Application Support/Den`, nas
  preferências `gabrielpassos.Den` nem no `ns` instalado (`~/.local/bin/ns`).
- Desenvolva e teste no Thalamus Dev, o build Debug. Ele usa o `ns` compilado
  do `../cli` e um workspace só de teste (`Scripts/dev-ns`). Depois de mudar
  o `cli`, rode `Scripts/dev-ns build`.
- O Den real só muda com `Scripts/release`, e só quando o usuário pedir.
- Não deixe o Thalamus Dev nem apps de teste abertos ao terminar.

## Trabalho

- Um ticket por vez, numa branch própria a partir de `main`. Nada vai direto
  para `main`: push da branch, pull request e merge com merge commit.
  Commit, push e merge só quando o usuário pedir.
- Ao terminar um ticket:
  1. Rode `/code-review` (Standards e Spec) e corrija os achados.
  2. Rode os testes unitários e o `Scripts/quality/check` (comandos em
     `docs/quality.md`).
  3. Em mudança de tela, faça a checagem visual com `Scripts/screenshot`.
  4. Faça a triagem do `docs/pendencias.md`.
  5. Marque o ticket como concluído.

  Depois disso, pare e espere a revisão do usuário antes do próximo.
- Commits em inglês, no formato Conventional Commits, sem `Co-Authored-By`
  nem qualquer outra atribuição, e sem código de ticket. Nunca commite
  `*.profraw`.
- O CI roda num runner self-hosted neste Mac. Se os checks ficarem na fila,
  veja se ele está online: `gh api repos/bMoki/Den/actions/runners`.
