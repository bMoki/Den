# Fluxo de trabalho

O Den real, instalado em `/Applications`, é o que se usa no dia a dia. O
desenvolvimento acontece no Den Dev, um app à parte que nunca toca nos dados
do real. O real só muda quando você roda `Scripts/release`.

## Do ticket ao Den real

1. **Uma branch por ticket**, a partir de `main` atualizado:

   ```sh
   git switch main && git pull --ff-only
   git switch -c feat/<assunto>
   ```

2. **Testar no Den Dev.** Rodar pelo Xcode, ou pelos testes, abre o Den Dev
   (ícone com a faixa laranja "DEV"). Ele pode ficar aberto ao lado do Den
   real. Para os testes e o gate, use os comandos de
   [quality.md](quality.md), ou rode `Scripts/screenshot` para ver uma tela
   sem abrir nada à mão.

3. **Commit e push da branch.** Nada vai direto para `main`: a branch sobe
   e vira pull request (o GitHub não protege `main`, a regra é nossa):

   ```sh
   git push -u origin feat/<assunto>
   gh pr create --fill
   ```

   O CI roda neste Mac, que é o único runner do repositório. Se os checks
   ficarem na fila, confira se ele está online com
   `gh api repos/bMoki/Den/actions/runners`.

4. **Merge em `main`** pelo pull request, com merge commit, que mantém os
   commits da branch como foram feitos, e atualize o `main` local:

   ```sh
   gh pr merge --merge
   git switch main && git pull --ff-only
   ```

5. **Atualizar o Den real**, quando quiser:

   ```sh
   Scripts/release
   ```

   Ele recusa rodar fora de `main` ou com alterações não commitadas, roda os
   testes unitários e o gate, gera a build de Release assinada, pede para o
   Den aberto sair (o aviso de arquivos não salvos continua valendo; cancelar
   ali para tudo sem trocar nada), faz backup do app e dos dados, instala e
   reabre. O painel Sobre mostra a versão como `1.0 (274)`, com o número de
   commits, e o commit embaixo.

## Voltar uma release

```sh
Scripts/release --rollback
```

Troca o Den instalado pelo app que a última release substituiu. Rodar de novo
volta mais uma release. Só o app é trocado: os dados que cada release
encontrou ficam no `data.zip` do backup dela, para restaurar à mão se uma
release mudar o formato deles.

Os backups ficam em `~/Library/Application Support/Den Releases/<data>`, os
cinco mais novos. O app fica zipado ali para o macOS não achar um segundo Den.

## Onde fica cada coisa

| O quê | Den (real) | Den Dev | Testes de interface |
|---|---|---|---|
| Como abre | `/Applications/Den.app` | build Debug do Xcode | XCUITest e `Scripts/screenshot` |
| Bundle id | `gabrielpassos.Den` | `gabrielpassos.Den.dev` | `gabrielpassos.Den.dev` |
| Sessões, anexos, PRs | `~/Library/Application Support/Den` | `~/Library/Application Support/Den Dev` | uma pasta descartável em `/private/tmp` (`DenUITests-…`, `DenScreenshot-…`) |
| Preferências | `gabrielpassos.Den` | `Den.Dev` | `Den.UITests`, zeradas a cada pasta nova |
| CLIs (`ns`, `claude`, `opencode`) | os que o shell de login acha | o `ns` do `cli` em desenvolvimento (veja abaixo); os outros, os que o shell de login acha | os falsos de `Scripts/fake-cli`; nos XCUITests não há `ns` |

Os testes unitários rodam dentro do Den Dev e também não tocam no real.

O Den usa o `ns` que o shell de login acha (hoje `~/.local/bin/ns`), a menos
que a preferência `Den.nsPath` dele aponte outro. O `claude` e o `opencode`
vêm do shell de login nos dois apps, com caminhos comuns como
`/opt/homebrew/bin` de reserva.

## O Den Dev isolado, com o ns em desenvolvimento

O `ns` e o Den evoluem juntos. O Den Dev usa o `ns` compilado do repositório
`cli`, num workspace só de teste. Assim, criar, arquivar ou remover uma Sessão
nele não mexe nas branches e worktrees reais, e o Den real segue com o `ns`
instalado em `~/.local/bin/ns`.

```sh
Scripts/dev-ns setup   # uma vez: compila o cli, monta o workspace e aponta o Den Dev
Scripts/dev-ns build   # a cada mudança no cli; depois reabra o Den Dev
Scripts/dev-ns off     # volta o Den Dev para o ns instalado e o workspace real
```

O `setup` pode rodar de novo: ele reescreve a configuração de teste a partir
da real e só cria os clones e os templates que faltam. Ele monta:

| O quê | Den Dev | Den real |
|---|---|---|
| `ns` | `cli/dist/ns` (preferência `Den.nsPath`) | `~/.local/bin/ns` |
| Configuração do `ns` | `~/.config/ns-dev` (preferência `Den.nsConfigDir`) | `~/.config/ns` |
| Repositórios e worktrees | `~/Developer/ns-dev`, com clones locais dos reais | `~/Developer` |
| Estado do `ns` | `~/.local/state/ns-dev` | `~/.local/state/ns` |
| Nome do produto (containers, volumes, snapshots, URLs locais) | `nsdev` | o do `env.json` real |
| Portas dos serviços principais | as do real mais 100 | as do `~/.config/ns/env.json` |
| Templates | uma cópia em `~/Developer/ns-dev/nsdev-workspace` | os do workspace real |

Os clones buscam do GitHub, mas não conseguem dar push: o endereço de push
deles é inválido de propósito. Os apps das branches de teste sobem com `nsdev` nas URLs
locais e nas variáveis de produto dos templates. Os hooks do IntelliJ ficam desligados, e o
`setup` apaga as branches que o Den Dev lembrava do workspace real.

O Den Dev exporta a pasta de configuração como `NS_CONFIG_DIR` ao abrir, então
os terminais do painel e os agentes também usam o workspace de teste. Nos
terminais, porém, `ns` continua sendo o do `PATH`, porque o shell de login
monta o `PATH` de novo; chame `cli/dist/ns` pelo caminho para usar o de
desenvolvimento.

Ficam compartilhados com o real:
- o volume de seed de onde saem os bancos novos (só lido);
- o tmux e o nome do projeto do Docker Compose (`ns-<branch>`). Use nomes de
  branch que não existam no workspace real;
- as portas de debug do backend e de management, que o `ns` não desloca. Uma
  branch de teste pode pegar a porta de uma branch real parada.

Variáveis `NS_*` exportadas no seu shell valem mais que o `env.json`. Não
exporte `NS_BASE_DIR`, `NS_STATE_DIR` nem os `NS_*_REPO`, ou o workspace de
teste volta a apontar para o real.

O Den real só recebe o `ns` novo com `bun run install-global` no `cli`, que faz
para o `ns` o que o `Scripts/release` faz para o Den.
