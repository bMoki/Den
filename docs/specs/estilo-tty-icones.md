# Ícones do Estilo TTY

No Estilo TTY, cada ícone do Thalamus é desenhado com um ícone do
[Nerd Fonts](https://www.nerdfonts.com) (versão 3.4.0), que ocupa uma célula
de caractere como uma letra. A fonte do TTY, **JetBrains Mono Nerd Font Mono**,
embarcada no Thalamus, traz o texto e esses ícones no mesmo arquivo. Esta tabela
é a correspondência aprovada: todo ícone usado no Thalamus tem uma linha aqui,
e um ícone novo só entra com a sua.

O nome é o de `glyphnames.json` do Nerd Fonts, e o prefixo diz de que conjunto
ele vem: `cod-` Codicons, `oct-` Octicons, `md-` Material Design Icons, `fa-`
Font Awesome, `dev-` e `seti-` Devicons. O código é o ponto Unicode na fonte.
No Estilo Padrão, os ícones continuam os da coluna "Hoje".

Fora desta tabela ficam os caracteres que já são texto no TTY: `›`, `×`, `+`,
`[x]`, o spinner em braille e as caixas de linha.

## Navegação e painéis

| Hoje | Onde | Nerd Fonts | Código |
| --- | --- | --- | --- |
| `chevron.right` | Abrir grupo da sidebar, ir para a próxima etapa | `cod-chevron_right` | `U+EAB6` |
| `chevron.left` | Voltar | `cod-chevron_left` | `U+EAB5` |
| `chevron.down` | Grupo aberto, passos de ferramenta expandidos | `cod-chevron_down` | `U+EAB4` |
| `chevron.up.chevron.down` | Indica um seletor (Indicadores) | `fa-sort` | `U+F0DC` |
| `sidebar.left` | Mostrar ou esconder a sidebar | `cod-layout_sidebar_left` | `U+EBF3` |
| `sidebar.right` | Mostrar ou esconder o inspector | `cod-layout_sidebar_right` | `U+EBF4` |
| `rectangle.bottomthird.inset.filled` | Mostrar ou esconder o painel de terminais | `cod-layout_panel` | `U+EBF2` |
| `arrow.down` | Ir para o fim da conversa | `cod-arrow_down` | `U+EA9A` |
| `arrow.up` | Enviar mensagem | `cod-arrow_up` | `U+EAA1` |
| `arrow.right` | Enviar, no campo do composer | `cod-arrow_right` | `U+EA9C` |
| `arrow.turn.down.right` | Resposta encadeada no transcript | `md-subdirectory_arrow_right` | `U+F060D` |
| `arrow.up.right` | Abrir no navegador (checks do PR) | `cod-link_external` | `U+EB14` |
| `arrow.up.forward.app` | Abrir no app de banco | `md-open_in_app` | `U+F03CB` |
| `arrow.up.arrow.down` | Ordem da sidebar | `md-swap_vertical` | `U+F04E2` |
| `magnifyingglass` | Busca | `cod-search` | `U+EA6D` |
| `escape` | Esc para parar o agente | `md-keyboard_esc` | `U+F12B7` |

## Ações

| Hoje | Onde | Nerd Fonts | Código |
| --- | --- | --- | --- |
| `plus` | Nova Sessão, adicionar | `cod-add` | `U+EA60` |
| `xmark` | Fechar, remover | `cod-close` | `U+EA76` |
| `xmark.circle.fill` | Limpar a busca | `md-close_circle` | `U+F0159` |
| `square.and.pencil` | Nova Sessão (cabeçalho da sidebar) | `cod-new_file` | `U+EA7F` |
| `arrow.clockwise` | Reiniciar Serviço, atualizar | `cod-refresh` | `U+EB37` |
| `arrow.down.to.line` | Atualizar com a branch principal | `md-arrow_collapse_down` | `U+F0792` |
| `play.fill` | Iniciar | `cod-play` | `U+EB2C` |
| `stop.fill` | Parar, interromper o agente | `cod-debug_stop` | `U+EAD7` |
| `terminal` | Abrir Console, Terminal livre | `cod-terminal` | `U+EA85` |
| `trash` | Mover para a lixeira | `cod-trash` | `U+EA81` |
| `doc.on.doc` | Copiar bloco de código | `cod-copy` | `U+EBCC` |
| `doc.badge.plus` | Novo arquivo | `cod-new_file` | `U+EA7F` |
| `folder.badge.plus` | Nova pasta | `cod-new_folder` | `U+EA80` |
| `arrow.right.doc.on.clipboard` | Mover para… | `md-file_move` | `U+F0AB9` |
| `at` | Mencionar na Sessão | `cod-mention` | `U+EB1F` |
| `paperclip` | Anexar arquivo | `md-paperclip` | `U+F03E2` |
| `eye` | Mostrar PR dispensado, Visualizar | `cod-eye` | `U+EA70` |
| `eye.slash` | Dispensar PR | `cod-eye_closed` | `U+EAE7` |
| `archivebox` | Sessões arquivadas | `cod-archive` | `U+EA98` |

## Git e GitHub

| Hoje | Onde | Nerd Fonts | Código |
| --- | --- | --- | --- |
| `arrow.triangle.branch` | Branch de workspace | `oct-git_branch` | `U+F418` |
| `arrow.triangle.pull` | PR aberto, aba GitHub dos Ajustes | `oct-git_pull_request` | `U+F407` |
| `arrow.triangle.merge` | PR mergeado | `oct-git_merge` | `U+F419` |
| `arrow.uturn.backward` | Mudanças pedidas no review | `oct-file_diff` | `U+F4D2` |
| `plus.forwardslash.minus` | Aba Alterações do inspector | `cod-diff` | `U+EAE1` |
| `checkmark.circle` | Nada a commitar | `oct-check_circle` | `U+F49E` |
| `folder.badge.questionmark` | Pasta sem git | `md-folder_question` | `U+F19CA` |

## Arquivos

| Hoje | Onde | Nerd Fonts | Código |
| --- | --- | --- | --- |
| `doc` | Arquivo na árvore e nas abas | `cod-file` | `U+EA7B` |
| `photo` | Imagem na árvore e nas abas | `cod-file_media` | `U+EAEA` |
| `folder` | Pasta de Outras pastas, sem Sessões | `cod-folder` | `U+EA83` |
| `folder.fill` | Pasta de Outras pastas, com Sessões | `md-folder` | `U+F024B` |
| `doc.fill` | Arquivo anexado numa mensagem | `md-file` | `U+F0214` |
| `doc.plaintext` | Anexo no composer | `md-file_document_outline` | `U+F09EE` |
| `list.bullet` | Aba de lista no editor | `cod-list_unordered` | `U+EB17` |
| `bubble.left` | Aba da Sessão no editor | `cod-comment` | `U+EA6B` |

## Agente e conversa

| Hoje | Onde | Nerd Fonts | Código |
| --- | --- | --- | --- |
| `brain` | Pensamento do agente | `md-brain` | `U+F09D1` |
| `wrench.and.screwdriver` | Ferramenta sem tipo | `cod-tools` | `U+EB6D` |
| `doc.text` | Ferramenta Read; também um Indicador do report-server | `md-file_eye_outline` | `U+F0DCB` |
| `pencil` | Ferramenta Edit, Renomear | `cod-edit` | `U+EA73` |
| `plus.square` | Ferramenta Write | `cod-diff_added` | `U+EADC` |
| `globe` | Ferramenta Fetch; também um Indicador do frontend | `cod-globe` | `U+EB01` |
| `text.quote` | Resumo da compactação | `cod-quote` | `U+EB33` |
| `arrow.down.right.and.arrow.up.left` | Comando /compact | `cod-fold` | `U+EAF5` |
| `clock` | Mensagem na fila | `md-clock_outline` | `U+F0150` |
| `info.circle` | Aviso informativo no transcript | `cod-info` | `U+EA74` |
| `sparkles` | Skills | `cod-sparkle` | `U+EC10` |
| `powerplug` | Servidor MCP | `cod-plug` | `U+EB2D` |
| `bolt.horizontal` | Prompt de MCP | `oct-zap` | `U+26A1` |
| `gauge.with.dots.needle.50percent` | Esforço | `cod-dashboard` | `U+EACD` |
| `circle.fill` | Ponto do harness | `cod-circle_filled` | `U+EA71` |
| `bubble.left.and.bubble.right` | Lista de Sessões vazia | `cod-comment_discussion` | `U+EAC7` |

## Pergunta do agente

| Hoje | Onde | Nerd Fonts | Código |
| --- | --- | --- | --- |
| `circle` | Opção de escolha única, não marcada; tarefa pendente | `md-checkbox_blank_circle_outline` | `U+F0130` |
| `largecircle.fill.circle` | Opção de escolha única, marcada | `md-radiobox_marked` | `U+F043E` |
| `square` | Opção de várias escolhas, não marcada | `md-checkbox_blank_outline` | `U+F0131` |
| `checkmark.square.fill` | Opção de várias escolhas, marcada | `md-checkbox_marked` | `U+F0132` |
| `checkmark.circle.fill` | Tarefa feita | `cod-pass_filled` | `U+EBB3` |
| `checkmark` | Confirmado, copiado | `cod-check` | `U+EAB2` |

## Modos de permissão

| Hoje | Onde | Nerd Fonts | Código |
| --- | --- | --- | --- |
| `shield` | Modo manual | `cod-shield` | `U+EB53` |
| `list.bullet.clipboard` | Modo plano | `oct-tasklist` | `U+F4A0` |
| `pencil.line` | Modo aceitar edições | `md-pencil_plus` | `U+F0DEB` |
| `forward.fill` | Modo automático | `md-fast_forward` | `U+F0211` |
| `exclamationmark.shield` | Modo sem permissões | `md-shield_alert` | `U+F0ECC` |
| `hammer` | Agente build (OpenCode) | `md-hammer` | `U+F08EA` |

## Avisos

| Hoje | Onde | Nerd Fonts | Código |
| --- | --- | --- | --- |
| `exclamationmark.triangle` | Aviso | `cod-warning` | `U+EA6C` |
| `exclamationmark.triangle.fill` | Aviso forte, no composer | `md-alert` | `U+F0026` |
| `questionmark.square.dashed` | Serviço sem Indicador | `cod-question` | `U+EB32` |

## Serviços e banco

| Hoje | Onde | Nerd Fonts | Código |
| --- | --- | --- | --- |
| `server.rack` | Aba Serviços do inspector; Indicador do backend | `cod-server` | `U+EB50` |
| `cylinder` | Indicador do banco | `cod-database` | `U+EACE` |
| `cylinder.split.1x2` | Seção do banco nos Serviços | `md-database_outline` | `U+F1632` |

## Indicadores do backend

| Hoje | Onde | Nerd Fonts | Código |
| --- | --- | --- | --- |
| `curlybraces` | Opção de Indicador | `cod-json` | `U+EB0F` |
| `cpu` | Opção de Indicador | `oct-cpu` | `U+F4BC` |
| `cup.and.saucer` | Opção de Indicador | `md-coffee` | `U+F0176` |
| `gearshape.2` | Opção de Indicador | `cod-settings_gear` | `U+EB51` |

## Indicadores do frontend

| Hoje | Onde | Nerd Fonts | Código |
| --- | --- | --- | --- |
| `macwindow` | Opção de Indicador | `cod-window` | `U+EB7F` |
| `desktopcomputer` | Opção de Indicador | `md-monitor` | `U+F0379` |
| `rectangle.3.group` | Opção de Indicador | `cod-layout` | `U+EBEB` |
| `cursorarrow` | Opção de Indicador | `md-cursor_default` | `U+F01C0` |

## Indicadores do manager

| Hoje | Onde | Nerd Fonts | Código |
| --- | --- | --- | --- |
| `slider.horizontal.3` | Opção de Indicador | `cod-settings` | `U+EB52` |
| `checkmark.shield` | Opção de Indicador | `md-shield_check` | `U+F0565` |
| `key` | Opção de Indicador | `cod-key` | `U+EB11` |
| `building.2` | Opção de Indicador | `md-office_building` | `U+F0991` |
| `person.badge.key` | Opção de Indicador | `md-account_key` | `U+F000B` |

## Indicadores do report-server

| Hoje | Onde | Nerd Fonts | Código |
| --- | --- | --- | --- |
| `chart.bar` | Opção de Indicador | `cod-graph` | `U+EB03` |
| `chart.bar.doc.horizontal` | Opção de Indicador | `md-file_chart` | `U+F0215` |
| `printer` | Opção de Indicador | `md-printer` | `U+F042A` |
| `scroll` | Opção de Indicador | `md-script_text` | `U+F0BC2` |

## Abas dos Ajustes

| Hoje | Onde | Nerd Fonts | Código |
| --- | --- | --- | --- |
| `circle.grid.2x2` | Aba Indicadores | `md-dots_grid` | `U+F15FC` |
| `bubble.left.and.text.bubble.right` | Aba Sessões | `cod-comment_discussion` | `U+EAC7` |

## Tipos de arquivo

| Hoje | Onde | Nerd Fonts | Código |
| --- | --- | --- | --- |
| `filetype-java` | Arquivo .java na árvore e nas abas | `dev-java` | `U+E738` |
| `filetype-js` | Arquivo .js | `seti-javascript` | `U+E60C` |
| `filetype-react` | Arquivo .jsx e .tsx | `seti-react` | `U+E625` |
| `filetype-swift` | Arquivo .swift | `seti-swift` | `U+E699` |
| `filetype-ts` | Arquivo .ts | `seti-typescript` | `U+E628` |

## Logos das tecnologias

| Hoje | Onde | Nerd Fonts | Código |
| --- | --- | --- | --- |
| `logo-bun` | Dependências; Indicador padrão do report-server | `dev-bun` | `U+E76F` |
| `logo-chakra` | Dependências | `md-alpha_c_circle` | `U+F0BF2` |
| `logo-expo` | Dependências | `md-chevron_up` | `U+F0143` |
| `logo-java` | Dependências | `dev-java` | `U+E738` |
| `logo-quarkus` | Dependências; Indicador padrão do backend | `dev-quarkus` | `U+E87E` |
| `logo-react` | Dependências | `dev-react` | `U+E7BA` |
| `logo-tailwind` | Dependências; Indicador padrão do manager | `dev-tailwindcss` | `U+E8BA` |
| `logo-typescript` | Dependências | `dev-typescript` | `U+E8CA` |
| `logo-vite` | Dependências; Indicador padrão do frontend | `dev-vitejs` | `U+E8D7` |

## Harnesses e git

| Hoje | Onde | Nerd Fonts | Código |
| --- | --- | --- | --- |
| `HarnessClaudeCode` | Harness Claude Code | `md-asterisk` | `U+F06C4` |
| `HarnessOpenCode` | Harness OpenCode | `md-unfold_more_horizontal` | `U+F054F` |
| `GitChanges` | Aba de mudanças do git | `oct-git_commit` | `U+F417` |

## Sem logo no Nerd Fonts

Expo, Claude Code e OpenCode não têm logo no Nerd Fonts. Ficaram com um ícone que
lembra a marca sem copiá-la: a seta para cima do Expo, o asterisco do Claude Code
e os sinais de código do OpenCode. Chakra ficou com a letra C num círculo.

## Licenças

O Nerd Fonts é MIT, mas cada conjunto dentro dele mantém a sua licença:
Codicons (CC BY 4.0), Octicons (MIT), Material Design Icons (Apache 2.0),
Font Awesome (ícones CC BY 4.0, fonte OFL 1.1) e Devicons (MIT). O JetBrains Mono é OFL 1.1. Ao embarcar a
fonte, o Thalamus precisa de um arquivo de créditos com elas.
