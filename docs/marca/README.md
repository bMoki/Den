# Marca do Thalamus

O ícone escolhido é o **B2**: as duas metades do tálamo, ovais e inclinadas,
ligadas no centro por um ponto, a massa intermédia. A paleta padrão é a
**Índigo**, a mesma do acento do app (`#8B93FF`).

A exploração completa (os conceitos de A a G, as personalidades e as
alternativas de B2 → T) está no canvas
[Thalamus Logo](https://claude.ai/artifact/UtosvvNJTf2ekDsz7DoM1Q).

## Arquivos

Os SVGs são a fonte do desenho. A geometria e as paletas abaixo descrevem o
que eles têm; ao mudar o desenho, mude os SVGs e depois este texto.

| Arquivo | Uso |
| --- | --- |
| `icone/app-indigo.svg` | Ícone do app, paleta padrão |
| `icone/app-indigo-16.svg` | O mesmo ícone ajustado à grade de 16 px, só para esse tamanho |
| `icone/app-brasa.svg` | Ícone do app, paleta Brasa |
| `icone/app-menta.svg` | Ícone do app, paleta Menta (clara) |
| `icone/app-violeta.svg` | Ícone do app, paleta Violeta |
| `icone/simbolo-fundo-claro.svg` | Símbolo de uma cor (`#15171C`) para fundo claro |
| `icone/simbolo-fundo-escuro.svg` | Símbolo de uma cor (`#F3F4F6`) para fundo escuro |
| `icone/simbolo-template.svg` | Símbolo preto, para imagem *template* do macOS (barra de menu), que o sistema pinta |

Os ícones do app ocupam uma tela de 1024 × 1024, com o corpo de 824 × 824 a
100 px da borda e cantos de raio 185, a grade de ícones do macOS. Os símbolos
têm fundo transparente; o anel em volta do ponto central é um recorte de
verdade, então funcionam sobre qualquer fundo.

## Paletas

| Paleta | Fundo | Metades | Ponto central |
| --- | --- | --- | --- |
| Índigo (padrão) | `#171A33` | `#8B93FF` | `#E6E9F0` |
| Brasa | `#1C1B20` | `#FF7A45` | `#FFD3B0` |
| Menta | `#E3F1EC` | `#0F6E5F` | `#13A38C` |
| Violeta | `#5B4CF5` | `#FFFFFF` | `#FFD84A` |

O anel em volta do ponto central sempre usa a cor do fundo.

## Geometria

Numa caixa de 100 × 100 (o corpo do ícone):

- Metade esquerda: elipse de centro (36, 50), raios 13 × 22, girada −14°.
- Metade direita: elipse de centro (64, 50), raios 13 × 22, girada 14°.
- Ponto central: círculo de centro (50, 53), raio 7, com contorno de 3 na cor
  do fundo.

A 16 px, um pixel vale quase 8 unidades da caixa, e o ponto central se
mistura com as metades. O `app-indigo-16.svg` encaixa o desenho nessa grade:
o ponto fica no centro (50, 50) e ocupa 2 × 2 pixels, com um anel de quase um
pixel, e as metades ficam mais finas e afastadas (centros em 28,64 e 71,36,
raios 10,5 × 23,3, giradas 12°).

## Ícone do app no Xcode

Os PNGs do `AppIcon` (Release) e do `AppIconDev` (Thalamus Dev, o build
Debug) saem dos SVGs Índigo pelo script (a tabela "Onde fica cada coisa" de
[fluxo.md](../fluxo.md) diz qual app usa qual):

```sh
Scripts/app-icon
```

O script desenha cada tamanho que o catálogo pede (16 a 1024 px) direto do
SVG, em sRGB, e grava por cima dos PNGs de `Thalamus/Assets.xcassets`. O de 16 px
sai do `app-indigo-16.svg`; os outros, do `app-indigo.svg`. No `AppIconDev`,
ele acrescenta embaixo a faixa laranja "DEV" (`#FF8C1A`), com um quarto da
altura do corpo, abaixo do desenho. Rode de novo sempre que um dos dois SVGs
mudar.

## Temas

O ícone ainda não acompanha o tema do app; isso fica para a task de temas
(veja a pendência em [pendencias.md](../pendencias.md)). A ideia é cada tema
escolher uma paleta acima e trocar o ícone do Dock em tempo de execução, com
`NSApplication.shared.applicationIconImage`. O ícone do Finder continua sendo
o do `AppIcon`, a Índigo.
