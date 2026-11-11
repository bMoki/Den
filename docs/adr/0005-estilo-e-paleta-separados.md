---
id: ADR-0005
status: accepted
date: 2026-11-11
decision_owner: "Breno Sonda"
related_modules: []
related_specs: [docs/specs/thalamus-escopo.md]
related_issues: []
supersedes: []
superseded_by: []
keywords: [tema, estilo, paleta, tty, cores, aparencia, icone, marca]
---

# ADR-0005 — A aparência se escolhe em duas partes: Estilo e Paleta

## Contexto

Até aqui o Thalamus tinha uma aparência só, escura, com as cores fixas em `Theme.swift` e as fontes, os cantos e os espaçamentos espalhados pelas telas. A marca já tem quatro paletas de ícone em `docs/marca` (Índigo, Brasa, Menta, Violeta), e a pendência do ícone pedia que ele acompanhasse o tema do app.

A primeira ideia foi um Tema que definisse tudo. A paleta Brasa foi desenhada assim, só com cores. Depois veio o TTY, que muda a forma inteira (tudo em caracteres, caixas de linha, Estados como glifo e palavra), e com ele a vontade de usar o TTY com outras cores. Se cada Tema definisse tudo, cada combinação de forma e cor precisaria ser um Tema próprio, desenhado à parte.

## Decisão

Decidimos separar a aparência em duas preferências independentes, o **Estilo** e a **Paleta**, combináveis livremente, em vez de um Tema único que define tudo. O motivo: assim qualquer Estilo serve com qualquer Paleta, uma Paleta é desenhada uma vez e funciona em todo Estilo, e um Estilo nunca precisa escolher cores.

- O **Estilo** define a tipografia, as formas (cantos, bordas, sombras, caixas), os glifos e ornamentos, a densidade e o desenho do ícone do Dock. Não define nenhuma cor. Os Estilos são o Padrão e o TTY.
- A **Paleta** define todas as cores: superfícies, textos, acento, as que sinalizam algo (Estado de Sessão, Estado de Serviço, diff, alertas), o código no editor, as cores do Terminal e as cores do ícone. Dentro dela, os quatro Estados de Sessão se distinguem entre si; um deles pode ser a cor do acento. As Paletas têm os nomes das paletas da marca: Índigo, a padrão, e Brasa.
- O **Tema** é o par dos dois, como "TTY com Brasa". O padrão é Padrão com Índigo, que é a aparência de hoje.
- Nem o Estilo nem a Paleta mudam o que aparece: as áreas, as ações, os atalhos e as informações são os mesmos em todo Tema.
- O ícone do Dock acompanha o Tema: o desenho vem do Estilo e as cores da Paleta (`docs/marca/README.md`).
- O diálogo de confirmação, a dica ao passar o mouse, a moldura dos popovers e a janela de Ajustes deixam de ser do macOS e passam a ser componentes do Thalamus, desenhados pelo Estilo, nos dois Estilos: o Padrão os desenha como hoje, e não tem caminho nativo à parte. O seletor de arquivo e a barra de menus continuam do macOS em todo Estilo.
- As cores que sinalizam algo são da Paleta, não do Estilo: a Índigo tem um conjunto só, o de hoje, tanto no Padrão quanto no TTY.

## Alternativas consideradas

- **Tema único que define tudo.** Mais simples de começar e cada Tema fica afinado como um todo. Mas cada nova combinação de forma e cor vira um Tema inteiro, e as cores de sinal são redesenhadas em cada um.
- **Só Paletas, sem Estilo.** Resolve a troca de cores, mas não comporta o TTY, que muda tipografia, formas e glifos.
- **Componentes nativos no Padrão e próprios só no TTY.** Deixa o Padrão idêntico ao de hoje, mas cada diálogo, dica e popover teria duas implementações, e o Padrão viraria uma exceção ("o nativo") em vez de um Estilo como os outros.
- **Estilo com cores próprias, que a Paleta só sobrescreve em parte.** Deixa o TTY ter as suas cores de terminal, mas não fica claro quem manda em cada cor, e uma Paleta deixa de funcionar igual em todo Estilo.

## Consequências

- As telas pedem a forma ao Estilo e a cor à Paleta, separadamente, em vez de usar fontes, cantos e espaçamentos fixos. Hoje só as cores estão centralizadas, então isso é uma reescrita ampla das telas.
- Toda Paleta precisa ser conferida em todo Estilo: cada Paleta nova multiplica o que se confere visualmente.
- Uma Paleta não pode contar com uma forma específica para se distinguir. Por exemplo, os Estados de Sessão se distinguem pela cor mesmo no Padrão, onde aparecem só como um ponto.
- O ícone do Dock é montado a partir de duas fontes, e o TTY ainda precisa de um desenho para 16 e 32 px.
- No Padrão, o diálogo, a dica e a janela de Ajustes deixam de ser exatamente os do macOS (a animação do alerta, o atraso da dica, a aparência dos Ajustes de outros apps). Em troca, todo componente segue o Estilo por um caminho só.
- No TTY, o seletor de arquivo continua sendo o do Finder, porque refazê-lo perderia iCloud, favoritos e as permissões de pasta que o macOS concede por ele.

## Critérios de reversão

Se as combinações de Estilo e Paleta forem poucas e cada uma precisar de ajustes próprios a ponto de a separação só atrapalhar, voltar a um Tema que define tudo, numa nova ADR.
