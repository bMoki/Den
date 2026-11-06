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
| CLIs (`ns`, `claude`, `opencode`) | os que o shell de login acha | os que o shell de login acha | os falsos de `Scripts/fake-cli`; nos XCUITests não há `ns` |

Os testes unitários rodam dentro do Den Dev e também não tocam no real.

O Den e o Den Dev usam o `ns` que o shell de login acha (hoje
`~/.local/bin/ns`), a menos que a preferência `Den.nsPath` daquele app aponte
outro. Sem essa preferência, trocar o `ns` instalado afeta os dois.
O `claude` e o `opencode` também vêm do shell de login, com caminhos comuns
como `/opt/homebrew/bin` de reserva.
