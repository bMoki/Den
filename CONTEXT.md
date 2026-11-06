# Context — Thalamus

Glossário da linguagem do domínio. Apenas termos e seus significados — sem detalhes de implementação.

A linguagem do `ns` é herdada do glossário do cli ([`../cli/CONTEXT.md`](../cli/CONTEXT.md)) e não é redefinida aqui: **Branch de workspace**, **Repo**, **Snapshot**, **Restaurar**, **Branch principal (`@default`)**, **Serviço**, **Plano de serviços**, **Preparar**, **Iniciar**, **Núcleo**, **Adapter**. Este arquivo acrescenta apenas os termos próprios da IDE.

## Termos

### Thalamus
A IDE do `ns`: o ambiente de trabalho do desenvolvedor NeuroSteps construído sobre o `ns`. Não é um orquestrador genérico de harnesses — é a interface do `ns`.

### Sessão
Uma conversa com um agente de IA, ancorada numa pasta de trabalho. A Sessão pertence a uma Branch de workspace se a pasta estiver dentro dela, a um Repo base se estiver dentro dele, e é uma Sessão avulsa caso contrário — o pertencimento decorre da pasta, não de como a Sessão foi aberta. Ao criar uma Sessão a partir de uma Branch de workspace, a pasta padrão é a raiz dela, que enxerga todos os seus Repos. O transcript da Sessão pertence ao Thalamus, não à pasta.

A árvore de arquivos de uma Sessão começa na pasta da Sessão.

### Repo base
O checkout principal de um Repo, a partir do qual as Branches de workspace são criadas.

### Sessão avulsa
Uma Sessão cuja pasta não está dentro de nenhuma Branch de workspace nem de nenhum Repo base (por exemplo, `~/Documents`). Tem árvore de arquivos e Terminal livre, mas nada do `ns`: sem Serviços e sem Atualizar com a branch principal.

### Sessão arquivada
Uma Sessão cuja Branch de workspace foi removida. Continua legível, mas não aceita novas mensagens.
_Evitar:_ "sessão órfã", "sessão apagada".

### Processo
_Evitar_ como sinônimo de Serviço. Quando se fala de backend, frontend, manager ou report-server no ar para uma Branch de workspace, o termo é **Serviço** — e sua identidade é a porta, não o processo do sistema operacional.

### Console (de Serviço)
A vista interativa de um Serviço em execução: o mesmo terminal em que o Serviço roda, com entrada de teclado. Abrir ou fechar o Console não inicia nem para o Serviço.
_Evitar:_ "terminal do serviço", "log" (o log é só a saída gravada; o Console é interativo).

### Terminal livre
Um shell aberto na pasta de uma Sessão, sem relação com nenhum Serviço. Pertence ao Thalamus e se encerra com ele.

### Estado de Serviço
Em que situação um Serviço está, do ponto de vista de quem trabalha na Branch de workspace:
- **Parado** — não está no ar e não há tentativa em curso.
- **Iniciando** — foi iniciado, mas ainda não está atendendo na sua porta.
- **Rodando** — está atendendo na sua porta.
- **Falhou** — foi iniciado e terminou sem ser parado; a saída do erro continua disponível no Console.

O banco da Branch de workspace só tem Parado e Rodando, e não tem Console.

### Estado de Sessão
Em que situação uma Sessão está, ordenada por quanto ela precisa de quem trabalha nela:
1. **Aguardando decisão** — o agente parou à espera de uma permissão ou de uma resposta.
2. **Tokens esgotados** — o agente não consegue continuar até que se decida o que fazer.
3. **Resposta nova** — o agente terminou e a vez é de quem trabalha na Sessão, que ainda não viu a resposta.
4. **Pensando** — o agente está trabalhando; não precisa de ninguém.

Uma Sessão sem nenhum desses está ociosa. Quando mais de um vale ao mesmo tempo, prevalece o de cima.
_Evitar:_ "status da sessão" para o Estado de Serviço, e vice-versa.

### Repo opcional
Um Repo que uma Branch de workspace pode ou não ter, escolhido ao criá-la: **manager** (incluído por padrão), **report-server** e **parents**. Backend, frontend e docs estão sempre presentes.

### Nova Branch de workspace
Criar uma Branch de workspace e deixá-la preparada (Preparar), sem iniciar nenhum Serviço. Termina com uma Sessão aberta na raiz da Branch de workspace, sem mensagem inicial.

### Atualizar com a branch principal
Trazer a Branch principal (`@default`) de cada Repo para dentro da Branch de workspace. Um conflito não é resolvido pela operação: o Repo fica com o conflito em aberto para quem trabalha na Branch de workspace resolver.
_Evitar:_ "pull" sozinho — é ambíguo com sincronizar a própria branch a partir do remoto.
