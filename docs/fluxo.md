# Fluxo de trabalho

O Thalamus real, instalado em `/Applications/Thalamus.app`, é o que se usa no
dia a dia. O desenvolvimento acontece no Thalamus Dev, um app à parte que
nunca toca nos dados do real. O real só muda quando você roda
`Scripts/release`.

## Do ticket ao Thalamus real

1. **Uma branch por ticket**, a partir de `main` atualizado:

   ```sh
   git switch main && git pull --ff-only
   git switch -c feat/<assunto>
   ```

2. **Testar no Thalamus Dev.** Rodar pelo Xcode, ou pelos testes, abre o
   Thalamus Dev (ícone com a faixa laranja "DEV"). Ele pode ficar aberto ao
   lado do Thalamus real. Para os testes e o gate, use os comandos de
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
   `gh api repos/bMoki/Thalamus/actions/runners`.
   O runner e o registro dele estão em [O runner do CI](#o-runner-do-ci).

4. **Merge em `main`** pelo pull request, com merge commit, que mantém os
   commits da branch como foram feitos, e atualize o `main` local:

   ```sh
   gh pr merge --merge
   git switch main && git pull --ff-only
   ```

5. **Atualizar o Thalamus real**, quando quiser:

   ```sh
   Scripts/release
   ```

   Ele recusa rodar fora de `main` ou com alterações não commitadas, roda os
   testes unitários e o gate, gera a build de Release assinada, pede para o
   Thalamus aberto sair (o aviso de arquivos não salvos continua valendo;
   cancelar ali para tudo sem trocar nada), faz backup do app e dos dados,
   instala e reabre. O painel Sobre mostra a versão como `1.0 (274)`, com o
   número de commits, e o commit embaixo.

   A primeira release do Thalamus também aposenta o Den: se o Den estiver
   aberto, pede para ele sair do mesmo jeito, guarda o `Den.app` no backup e
   o tira de `/Applications`, para os dois apps não trabalharem nos mesmos
   projetos. Os dados do Den (`~/Library/Application Support/Den` e as
   preferências `gabrielpassos.Den`) ficam onde estão; o Thalamus copia o que
   precisa deles na primeira abertura (veja abaixo).

## Voltar uma release

```sh
Scripts/release --rollback
```

Põe de volta os apps que a última release substituiu. Rodar de novo volta
mais uma release. Logo depois da primeira release do Thalamus, o rollback
devolve o `Den.app` a `/Applications` e tira o Thalamus. Só os apps são
trocados: os dados que cada release encontrou ficam no `data.zip` do backup
dela, para restaurar à mão se uma release mudar o formato deles.

Os backups ficam em `~/Library/Application Support/Thalamus Releases/<data>`,
os cinco mais novos que ainda têm um app para voltar (os mais antigos saem,
inclusive os já usados por um rollback). Por isso o caminho de volta ao Den
dura cinco releases. Os apps ficam zipados ali para o macOS não achar uma
segunda cópia. Os backups de quando o app era o Den continuam em
`~/Library/Application Support/Den Releases`; o rollback não os usa, e para
voltar a um deles é preciso descompactar o `Den.app.zip` à mão.

Para ensaiar a troca sem tocar nos apps reais, aponte
`THALAMUS_RELEASE_ROOT` para uma pasta descartável. Ela faz o papel de
`/Applications` e de `Application Support`, e o script pula o git, os testes
e a build (instala o app de Release que já está em `build/Release`) e não
fecha, abre nem registra nenhum app real:

```sh
THALAMUS_RELEASE_ROOT=$(mktemp -d) Scripts/release
```

## O runner do CI

Os workflows pedem `runs-on: [self-hosted, macOS]`, e o único runner é este
Mac:

| O quê | Hoje |
|---|---|
| Pasta | `~/actions-runner-thalamus` |
| Nome | `MacBook-Pro-de-Breno-thalamus` |
| Labels | `self-hosted`, `macOS`, `ARM64` (as padrão) |
| Serviço | LaunchAgent `actions.runner.bMoki-Thalamus.MacBook-Pro-de-Breno-thalamus` |
| Logs | `~/actions-runner-thalamus/_diag` e `~/Library/Logs/actions.runner.bMoki-Thalamus.*` |

Renomear o repositório não derruba o runner: o registro fica ligado ao ID do
repositório, não ao nome dele. Depois de um renome, aponte o `origin` para o
nome novo e confira o runner:

```sh
git remote set-url origin git@github.com:bMoki/Thalamus.git
gh api repos/bMoki/Thalamus/actions/runners --jq '.runners[] | {name, status}'
```

Para registrá-lo de novo (se ele ficar offline, ou para trocar a pasta ou o
nome), espere o runner ficar livre (`busy: false`), porque parar o serviço
derruba o job em andamento. Os tokens vêm do `gh` de quem administra o
repositório e valem uma hora. O registro antigo sai pela API, e não pelo
`config.sh remove`: o `.runner` guarda a URL que o repositório tinha quando o
runner foi registrado, e depois de um renome a remoção por ela dá 404.

```sh
cd ~/actions-runner-thalamus
./svc.sh stop && ./svc.sh uninstall
id=$(gh api repos/bMoki/Thalamus/actions/runners --jq '.runners[] | select(.name=="MacBook-Pro-de-Breno-thalamus") | .id')
gh api -X DELETE "repos/bMoki/Thalamus/actions/runners/$id"
./config.sh remove --local
./config.sh --unattended --url https://github.com/bMoki/Thalamus \
  --token "$(gh api -X POST repos/bMoki/Thalamus/actions/runners/registration-token --jq .token)" \
  --name MacBook-Pro-de-Breno-thalamus --work _work --replace
./svc.sh install && ./svc.sh start
```

Para trocar a pasta, mova-a entre o `remove --local` e o novo `config.sh`.
O nome do serviço sai do repositório e do `--name`; se eles mudarem, atualize
a tabela acima.

## Onde fica cada coisa

| O quê | Thalamus (real, Release) | Thalamus Dev (Debug) | Testes de interface |
|---|---|---|---|
| Como abre | `/Applications/Thalamus.app`, instalado pelo `Scripts/release` | build Debug do Xcode | XCUITest e `Scripts/screenshot` |
| Bundle id | `dev.brenosonda.Thalamus` | `dev.brenosonda.Thalamus.dev` | `dev.brenosonda.Thalamus.dev` |
| Ícone | `AppIcon` | `AppIconDev`, com a faixa "DEV" | `AppIconDev` |
| Sessões, anexos, PRs | `~/Library/Application Support/Thalamus` | `~/Library/Application Support/Thalamus Dev` | uma pasta descartável em `/private/tmp` (`ThalamusUITests-…`, `ThalamusScreenshot-…`) |
| Preferências | `dev.brenosonda.Thalamus` | `Thalamus.Dev` | `Thalamus.UITests`, zeradas a cada pasta nova |
| CLIs (`ns`, `claude`, `opencode`) | os que o shell de login acha | o `ns` do `cli` em desenvolvimento (veja abaixo); os outros, os que o shell de login acha | os falsos de `Scripts/fake-cli`; nos XCUITests não há `ns` |

Os testes unitários rodam dentro do Thalamus Dev e também não tocam no real.

Na primeira abertura, quando a pasta de dados dele ainda não existe, o
Thalamus copia a do Den (`~/Library/Application Support/Den`) e as
preferências `Den.*` do domínio `gabrielpassos.Den`, trocando o prefixo para
`Thalamus.`. As sessões copiadas passam a apontar para os anexos copiados. O
Thalamus Dev faz o mesmo a partir do Den Dev (`Den Dev` e `Den.Dev`), nunca do
Den real. Nada do Den é apagado nem alterado, uma preferência `Thalamus.*`
que já exista não é trocada, e a cópia não roda de novo depois que a pasta
existe. Quando o app abre como host dos testes unitários, não migra nada.

O Thalamus usa o `ns` que o shell de login acha (hoje `~/.local/bin/ns`), a
menos que a preferência `Thalamus.nsPath` dele aponte outro. O `claude` e o
`opencode` vêm do shell de login nos dois apps, com caminhos comuns como
`/opt/homebrew/bin` de reserva.

## O Thalamus Dev isolado, com o ns em desenvolvimento

O `ns` e o Thalamus evoluem juntos. O Thalamus Dev usa o `ns` compilado do
repositório `cli`, num workspace só de teste. Assim, criar, arquivar ou remover
uma Sessão nele não mexe nas branches e worktrees reais, e o Thalamus
real segue com o `ns` instalado em `~/.local/bin/ns`.

```sh
Scripts/dev-ns setup   # uma vez: compila o cli, monta o workspace e aponta o Thalamus Dev
Scripts/dev-ns build   # a cada mudança no cli; depois reabra o Thalamus Dev
Scripts/dev-ns off     # volta o Thalamus Dev para o ns instalado e o workspace real
```

O `setup` pode rodar de novo: ele reescreve a configuração de teste a partir
da real e só cria os clones e os templates que faltam. Ele monta:

| O quê | Thalamus Dev | Thalamus real |
|---|---|---|
| `ns` | `cli/dist/ns` (preferência `Thalamus.nsPath`) | `~/.local/bin/ns` |
| Configuração do `ns` | `~/.config/ns-dev` (preferência `Thalamus.nsConfigDir`) | `~/.config/ns` |
| Repositórios e worktrees | `~/Developer/ns-dev`, com clones locais dos reais | `~/Developer` |
| Estado do `ns` | `~/.local/state/ns-dev` | `~/.local/state/ns` |
| Nome do produto (containers, volumes, snapshots, URLs locais) | `nsdev` | o do `env.json` real |
| Portas dos serviços principais | as do real mais 100 | as do `~/.config/ns/env.json` |
| Templates | uma cópia em `~/Developer/ns-dev/nsdev-workspace` | os do workspace real |

Os clones buscam do GitHub, mas não conseguem dar push: o endereço de push
deles é inválido de propósito. Os apps das branches de teste sobem com `nsdev` nas URLs
locais e nas variáveis de produto dos templates. Os hooks do IntelliJ ficam desligados, e o
`setup` apaga as branches que o Thalamus Dev lembrava do workspace real.

O Thalamus Dev exporta a pasta de configuração como `NS_CONFIG_DIR` ao abrir, então
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

O Thalamus real só recebe o `ns` novo com `bun run install-global` no `cli`,
que faz para o `ns` o que o `Scripts/release` faz para o Thalamus.
