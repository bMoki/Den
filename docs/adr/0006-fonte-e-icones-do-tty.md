---
id: ADR-0006
status: accepted
date: 2026-11-11
decision_owner: "Breno Sonda"
related_modules: []
related_specs: [docs/specs/estilo-tty-icones.md]
related_issues: []
supersedes: []
superseded_by: []
keywords: [tty, estilo, fonte, jetbrains-mono, nerd-fonts, icones, dependencias]
---

# ADR-0006 — O TTY usa uma fonte embarcada, JetBrains Mono Nerd Font Mono, para texto e ícones

## Contexto

O Estilo TTY (ADR-0005) desenha tudo em caracteres: texto monoespaçado, caixas de linha, setas, blocos, o spinner em braille e os ícones da interface no lugar dos SF Symbols. Para isso funcionar, todo caractere precisa ocupar exatamente uma célula da grade.

As fontes do sistema não bastam. O SF Mono, que o editor e o Terminal usam hoje, não tem as caixas de linha (`╭╮╰╯├┤═║`), os blocos (`░▒▓`), setas e marcas como `✓ ▾ ▸ ■ ▶ ↻ ↵` nem o braille. O Menlo tem quase tudo, menos o braille. Quando falta um caractere, o macOS o desenha com outra fonte, que pode ter outra largura e quebra o alinhamento.

Para os ícones, desenhar cada um em ASCII ficou pobre, e a escolha foi o Nerd Fonts, a coleção de ícones em fonte monoespaçada que os TUIs usam (opencode, lazygit, starship). A correspondência dos 120 ícones do Thalamus está em `docs/specs/estilo-tty-icones.md`.

## Decisão

Decidimos que o Estilo TTY usa uma fonte embarcada no Thalamus, a **JetBrains Mono Nerd Font Mono** (normal, negrito e itálico), para o texto e os ícones, em vez das fontes do sistema ou de uma fonte que quem usa escolhe. O motivo: um arquivo só garante que texto, caixas, braille e ícones têm a mesma largura de célula; o SF Mono não tem as caixas e o Menlo não tem o braille; e os ícones do Nerd Fonts são os que os TUIs já usam.

- O texto, os ícones e o desenho do ícone do Dock no TTY usam essa fonte.
- Os Terminais livres e os Consoles no TTY também, para que os ícones que as ferramentas imprimem apareçam.
- Cada ícone da interface tem uma linha na tabela de `docs/specs/estilo-tty-icones.md`; um ícone novo só entra com a sua.
- O Estilo Padrão continua com as fontes do sistema e os SF Symbols.

## Alternativas consideradas

- **Menlo e Symbols Nerd Font Mono.** Nada a embarcar para o texto, mas são duas fontes na mesma grade, sem garantia de que as larguras batem, e o spinner precisaria de outros caracteres, porque o Menlo não tem braille.
- **Só ASCII, sem fonte de ícones.** Nada a embarcar, mas os ícones ficam pobres e muitos não têm equivalente legível.
- **Fonte escolhida por quem usa.** Flexível, mas uma fonte sem caixas de linha ou sem os ícones quebra o TTY, e o Thalamus teria de avisar ou completar o que falta.

## Consequências

- O app cresce cerca de 2 MB por peso da fonte.
- O Thalamus precisa de um arquivo de créditos com as licenças: JetBrains Mono (OFL 1.1), Nerd Fonts (MIT), Codicons (CC BY 4.0), Octicons (MIT), Material Design Icons (Apache 2.0), Font Awesome (ícones CC BY 4.0, fonte OFL 1.1) e Devicons (MIT).
- Atualizar o Nerd Fonts pode renomear ou mover ícones; a tabela fixa a versão (3.4.0) e precisa ser conferida a cada atualização.
- Expo, Claude Code e OpenCode não têm logo no Nerd Fonts e usam um ícone parecido, não a marca.

## Critérios de reversão

Se o macOS passar a trazer uma fonte monoespaçada com caixas, braille e um conjunto de ícones equivalente, ou se o tamanho e as licenças da fonte embarcada pesarem mais do que a garantia de alinhamento, voltar às fontes do sistema numa nova ADR.
