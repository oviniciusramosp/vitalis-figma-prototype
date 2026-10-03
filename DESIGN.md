# Vitalis Prototype — Design System

> Superfícies translúcidas, dados legíveis e movimento discreto.

Este documento descreve o sistema visual **implementado neste protótipo iOS independente**. A biblioteca começa com os fundamentos e componentes existentes; ela pode crescer junto com o app. Os valores de saúde, dispositivos e sincronização são demonstrativos e locais.

No app, abra **More → Design System** para consultar amostras vivas, trocar o tema, experimentar controles e reproduzir a animação do gauge. As amostras instanciam os mesmos componentes usados em Today. A estrutura deste documento segue uma referência de estilos organizada em tokens, componentes e regras de uso, com os valores próprios deste projeto.

## Identidade e temas

O fundo combina um gradiente suave, textura de grain estável e uma resposta sutil à inclinação do iPhone. Cards translúcidos organizam o conteúdo sem apagar essa textura. Os números são protagonistas; o movimento estabelece a ordem de leitura: gauge, valor, tendência e mensagem.

Existem três temas: **Gray**, **Dark** e **Light**. Gray é o padrão. A seleção em More ou no catálogo vale para todo o app e persiste no dispositivo. `PrototypeAppearance` guarda essa seleção; `PrototypeTheme` fornece os tokens e a aparência nativa correspondente.

Today, More e Design System usam `PrototypeBackground`. O fundo da página deve continuar compartilhado, incluindo textura, gradiente e comportamento de movimento.

## Tokens — cores

Valores hexadecimais abaixo são aproximações sRGB dos tons base. O resultado do fundo renderizado varia com o gradiente e a composição das superfícies; ele não corresponde a um preenchimento hex único.

| Token | Gray | Dark | Light | Papel |
|---|---|---|---|---|
| `PrototypeTheme.background` | `#575754` | `#1F1F1F` | `#DBDBD9` | Tom base e fallback do canvas |
| `PrototypeTheme.foreground` | `#FFFFFF` | `#FFFFFF` | `#1F1F1F` | Texto, números e ícones principais |
| `PrototypeTheme.muted` | Foreground 55% | Foreground 55% | Foreground 65% | Unidades, legendas e texto auxiliar |
| `PrototypeTheme.surface` | Preto 25% | Branco 5,5% | Branco 48% | Fundo dos widgets |
| `PrototypeTheme.listRow` | Branco 4,5% | Branco 4,5% | Branco 54% | Linhas agrupadas de More e amostras do catálogo |
| `PrototypeTheme.headerGray` | Cinza 40% | Cinza 14% | Cinza 86% | Camada cinza da topbar |
| `PrototypeTheme.panelTint` | Preto 14% | Preto 24% | Cinza 55% a 14% de opacidade | FormSheet sobre o blur |
| `PrototypeTheme.modalTint` | Preto 60% | Preto 60% | Branco 60% | Modal individual de dispositivo |
| `PrototypeTheme.accent` | `#FF8D28` | `#FF8D28` | `#FF8D28` | Média de exposição e destaque secundário |
| `PrototypeTheme.success` | `#34C759` | `#34C759` | `#34C759` | Start, Report Now, seleção e tendência de menor exposição |
| `Color.red` | Adaptativo | Adaptativo | Adaptativo | Exposição acima da média, atenção e remoção |
| `Color.blue` | Adaptativo | Adaptativo | Adaptativo | Ação Sync Now nos dispositivos |

Laranja e verde estão no asset catalog. Vermelho e azul são cores semânticas do sistema, sem um hex fixo neste contrato. A cor da tendência depende da métrica: Heart, HRV e Respiration usam uma indicação neutra. Comparar com a média pessoal não constitui uma avaliação clínica.

### Textura e parallax

`PrototypeBackground` renderiza `PrototypeMesh.metal` com MetalKit. A textura usa amplitude `0.024` e seed estável `4171`; ela acompanha a resolução da superfície. A malha e o grain são preparados e reutilizados pelo renderer.

`BackgroundMotion` controla o deslocamento sutil do fundo. O sensor funciona enquanto a página está visível e o app ativo. Reduce Motion desativa a resposta à inclinação. Preserve essa relação com o ciclo de vida ao reutilizar o fundo.

## Tokens — tipografia

**Fonte do conteúdo:** Inter, empacotada em `Resources/Inter.ttf`. Use `PrototypeFont.inter(_:weight:)`; ela resolve os nomes internos da fonte. Barras de navegação, tabs e controles nativos mantêm a tipografia do sistema quando não recebem uma fonte explícita.

Não há uma escala global de line height imposta. SwiftUI usa as métricas da fonte, com frames específicos nos componentes de dados. O catálogo representa os papéis mais comuns; tamanhos menores dos widgets são parte da composição compacta.

| Papel | Tamanho | Peso | Tracking | Referência |
|---|---:|---|---:|---|
| Título do catálogo | 28 pt | Medium | −0,7 pt | Introdução do Design System |
| Título de seção do catálogo | 22 pt | Medium | Padrão | `PrototypeCatalogSection` |
| Perfil | 20 pt | Semibold | Padrão | More |
| Texto / ação secundária | 15 pt | Regular / Medium | Padrão | Corpo e Report Now |
| Texto auxiliar | 12–14 pt | Regular | Padrão | Metadados e explicações |
| Título do widget | 9 / 11 / 15 pt | Regular | Padrão | Small / Medium / Large |
| Valor do widget | 31 / 34 pt | Medium | −1,1 pt | Compacto / Large |
| Label do gauge | 14 pt | Medium | +2,1 pt | TODAY’S BLAST |
| Valor central | 72 pt | Regular | −2,88 pt | `BlastGaugeView` |
| Unidade do gauge | 14 pt | Regular | Padrão | PSI |
| Dia do gráfico de exposição | 8 pt | Regular | Padrão | Legenda sobre a coluna |

Use `.contentTransition(.numericText(value:))` para números animados. Formate exposição com uma casa decimal e unidade PSI. A comparação usa a mesma precisão visível para evitar uma seta que contradiga o número arredondado. Duração de sono aparece como `6h30`; as outras métricas preservam suas unidades.

## Tokens — espaço e formas

Todos os tamanhos de layout são expressos em **pontos**, não pixels CSS. `PrototypeStyle` reúne os primeiros tokens de espaço e superfície reutilizados na UI.

| Token / uso | Valor |
|---|---:|
| `PrototypeStyle.spacing` | 4, 8, 12, 16, 20, 24, 32, 48 pt |
| `PrototypeStyle.gridGap` | 12 pt |
| `PrototypeStyle.cardPadding(for:)` | 16 pt Large; 12 pt Medium e Small |
| `PrototypeStyle.cardRadius` | 16 pt |
| `PrototypeStyle.cardBorderWidth` | 0,5 pt |
| `PrototypeStyle.cardBorderOpacity` | Foreground 24% |
| Divider das ações | `1 / displayScale` pt: um pixel físico |
| Cantos das barras de Blast Exposure | 3 pt |
| Cantos das barras das demais métricas | 2,5 pt |
| Linha de média | Capsule, 2 pt de altura |
| Modal de dispositivo | Raio de 30 pt |
| Cantos superiores do FormSheet | Raio de 38 pt |
| Botões Start e Report Now | Capsule nativa |

Widgets não recebem uma sombra pesada. A separação vem do tom da superfície e da borda fina. Blur e tint definem a profundidade dos painéis; não acrescente sombras como padrão a cada elemento.

### Grid de widgets

O grid lógico tem seis colunas, com espaçamento de 12 pt. Para uma largura útil `W`:

| Formato | Colunas | Largura | Altura | Dados visíveis |
|---|---:|---|---:|---|
| Large | 6 | `W` | 134 pt | Gráfico de 14 dias |
| Medium | 3 | `(W − 12) / 2` | 110 pt | Gráfico de 7 dias |
| Small | 2 | `(W − 24) / 3` | 110 pt | Número e tendência, sem gráfico |

Health Overview é uma variação: em Large mostra um carrossel horizontal de métricas circulares. Nos formatos compactos ele usa o resumo de Blast. `PrototypeWidgetSize`, `PrototypeWidgetGrid` e `PrototypeWidgetLayout` determinam tamanhos, empacotamento e persistência; não calcule larguras independentes para cada novo widget.

## Superfícies e hierarquia

| Camada | Construção | Uso |
|---|---|---|
| Canvas | `PrototypeBackground` | Today, More e Design System |
| Conteúdo | Texto e cards com `PrototypeTheme.surface` | Dados e widgets |
| Topbar | Blur com máscara em degradê + sobreposição cinza | Título e baterias fixos em Today |
| FormSheet | Blur + `panelTint`, discretamente mais escuro | Ações rápidas, abaixo das tabs |
| Tabs | TabView nativa | Navegação principal persistente |
| Modal de dispositivo | Fundo desfocado + card com `modalTint` | Sync e informações individuais |
| Navegação do catálogo | NavigationStack nativa, barra sem preenchimento próprio | More → Design System |

More mantém a mesma textura da Home por trás das linhas agrupadas. A página Design System herda essa linguagem; amostras não devem introduzir um quarto tema.

## Componentes

### Superfície de widget

`.prototypeWidgetSurface()` aplica cor do texto, preenchimento translúcido, raio e borda. `BlastExposureCard` e `MetricWidgetCard` compartilham esse modifier. O padding continua separado e depende do tamanho do widget.

### Ação principal — Start

`.prototypePrimaryAction()` usa botão nativo `.borderedProminent`, capsule, tamanho de controle pequeno e tint verde. Start inclui o ícone de play. O callback e o rótulo acessível pertencem à tela que usa o botão.

### Ação secundária — Report Now

`.prototypeSecondaryAction()` usa `.bordered`, capsule, tint e texto verdes, Inter 15 Medium e altura mínima visual de 30 pt. O fundo nativo diferencia a ação do texto comum. O catálogo permite experimentar o estilo com feedback local.

### Ação destrutiva — Remove Widget

Use `Button(role: .destructive)` com texto e ícone vermelhos. No menu de widgets, mantenha a remoção junto das opções de tamanho e adição. A amostra do catálogo exibe feedback sem modificar o grid de Today.

### Blast Exposure

`BlastExposureCard` reúne título, média, linha laranja com pontas arredondadas e histórico. Large usa **14-day avg**; Medium usa **7-day avg**. A linha parte do lado esquerdo da área interna do card, atravessa a região da média e do gráfico e representa seu valor na escala das colunas.

A seleção por toque, arraste ou hover ilumina a coluna correspondente. A coluna de hoje recebe a cor da tendência; a letra sobre uma coluna vermelha é clara para manter contraste. Small mostra apenas o valor de hoje e a comparação com a média de 14 dias.

### Métricas e Health Overview

`PrototypeAuxiliaryWidgetCard` escolhe entre Cognition, Sleep, Activity, Heart, HRV, Respiration, Blast Exposure e Health Overview. Formatos gráficos usam a mesma série local da métrica; o período muda conforme o tamanho. `HealthSummaryWidgetCard` organiza o carrossel Large e o resumo compacto.

### Gauge central

`BlastGaugeView` é a leitura principal de Today. A seta compara hoje com a média dos últimos 14 dias, incluindo hoje. No cenário inicial, **7,2 PSI** fica acima da média arredondada de **5,4 PSI**; o widget Medium calcula sua própria média de sete dias, **6,2 PSI**.

O gauge central não tem ícone de alerta. Alertas de sincronização ficam nos dispositivos. A mensagem sobre exposição é um bloco separado com ícone à esquerda e entrada depois da animação principal.

### FormSheet e baterias

`PrototypeActionsSheet` tem duas posições de repouso. O scroll dispara a mudança de posição com histerese; o painel não acompanha continuamente cada pixel do scroll. O handler permite arraste manual e ajuste acessível. Dividers de um pixel físico separam as ações.

Os dois indicadores de bateria entram em cascata. O alerta de dispositivo surge depois do gauge de bateria e tem borda da cor do fundo. Cada device abre seu próprio modal, com último sync e ação de sincronização simulada.

### Edição do grid

O botão pequeno **Edit Widgets**, ao final da lista, ativa a edição. Cards entram em wiggle e podem ser arrastados para reorganizar, inclusive para a área acima de TODAY’S BLAST. IDs estáveis preservam a identidade do card durante o arraste. A ordem e os tamanhos persistem localmente.

### Catálogo vivo

`PrototypeDesignSystemView` apresenta cores, tipografia, espaço, formas, controles, widgets e movimento. Ele reutiliza `BlastExposureCard`, `PrototypeAuxiliaryWidgetCard`, `HealthSummaryWidgetCard` e `BlastGaugeView`. Não é uma imagem estática do dashboard: alterações nesses componentes atualizam suas amostras.

## Movimento e feedback

| Interação | Comportamento atual |
|---|---|
| Gauge central | Sweep suave de 1,3 s; morph numérico com ticks hápticos limitados |
| Tendência do gauge | Reveal de 0,24 s após o valor final, com fade e deslocamento |
| Blast Exposure | Barras em cascata, atraso de 0,045 s por coluna; spring com bounce discreto |
| Demais gráficos | Ease-out de 0,65 s, com atraso por coluna |
| Valores compactos | Numeric morph com ease-out de 0,7 s |
| FormSheet | Spring de 0,48 s, bounce 0,09 |
| Mensagem de exposição | Slide para baixo vindo da região do gauge, blur reduzindo a zero |
| Catálogo | Replay do gauge real; amostras dos widgets animam ao aparecer |

O estado intermediário do gauge fica no próprio componente para evitar atualizar todo o dashboard a cada tick. O fundo usa recursos Metal compartilhados e atualizações sob demanda. O app solicita a cadência máxima disponível; FPS, haptics e resposta ao sensor ainda precisam de avaliação no iPhone físico.

Reduce Motion apresenta os valores diretamente, remove a sequência de entrada e desativa parallax. Preserve essa alternativa ao adicionar animações. Tarefas e haptics devem parar quando a view sai da tela ou o app perde atividade.

## Acessibilidade e dados

- Tendências devem incluir direção e período no valor acessível; cor sozinha não explica o estado.
- Gráficos expõem tamanho, número de dias, valores e indicação de dados simulados.
- Elementos decorativos, textura e overlays sem interação ficam fora da árvore acessível.
- Preserve o alto contraste da letra sobre a coluna de hoje; confira Gray, Dark e Light.
- Use os rótulos acessíveis dos controles, especialmente quando houver apenas um ícone.
- O catálogo e os estilos existentes são um ponto de partida. Validar todos os tamanhos de Dynamic Type, contraste e alvos de toque continua sendo parte da evolução do sistema.

Não invente escalas clínicas, não trate uma série demonstrativa como medida real e não mostre uma média independente do histórico que alimenta o gráfico.

## Imagens e ícones

Use os assets já empacotados para a marca, métricas e dispositivos e SF Symbols para controles e navegação. Ícones de métricas usam rendering template quando devem acompanhar `foreground`. Mantenha proporções com `scaledToFit`; não distorça imagens de devices.

Não adicione novas imagens apenas para representar cores, textura ou componentes que já são renderizados nativamente. Evite incluir credenciais, identificadores pessoais ou documentos internos na distribuição do protótipo.

## Regras de uso

**Faça:** use tokens semânticos, o fundo compartilhado e componentes existentes; mantenha números coerentes; faça a tendência aparecer na ordem correta; experimente as mudanças nos três temas; atualize este documento e o catálogo quando uma regra visual mudar.

**Evite:** duplicar cores em telas novas; substituir o fundo texturizado por um cinza plano; adicionar sombras pesadas a todos os cards; criar gráficos em Small; repetir alertas sobre o gauge central; mover o FormSheet continuamente com o scroll; refazer a biblioteca como amostras desconectadas do código real.

## Quick start — SwiftUI

```swift
// Fundo compartilhado para uma nova página.
ScrollView {
    // Conteúdo
}
.background { PrototypeBackground() }
.foregroundStyle(PrototypeTheme.foreground)

// Superfície e padding dos widgets existentes.
Text("Sample value")
    .font(PrototypeFont.inter(34, weight: .medium))
    .padding(PrototypeStyle.cardPadding(for: .large))
    .prototypeWidgetSurface()

// Ações com os mesmos estilos de Today e do catálogo.
Button("Start", systemImage: "play.fill", action: start)
    .prototypePrimaryAction()
Button("Report Now", action: report)
    .prototypeSecondaryAction()

// Reutilize o widget e deixe o tamanho definir o período.
PrototypeAuxiliaryWidgetCard(kind: .sleep, size: .medium)
```

### Arquivos de referência

| Arquivo | Responsabilidade |
|---|---|
| `Sources/PrototypeTheme.swift` | Temas, cores e helper da fonte |
| `Sources/PrototypeDesignSystem.swift` | Tokens iniciais de espaço e superfície, estilos de ação e catálogo |
| `Sources/PrototypeBackground.swift` / `PrototypeMesh.metal` | Renderer, textura e gradiente |
| `Sources/BackgroundMotion.swift` | Movimento do fundo |
| `Sources/PrototypeWidgets.swift` / `PrototypeWidgetLayout.swift` | Tipos, tamanhos, galeria e organização |
| `Sources/BlastExposureCard.swift` / `PrototypeMetricCards.swift` | Cards, gráficos e resumos |
| `Sources/BlastGaugeView.swift` / `BlastHaptics.swift` | Gauge, morph e haptics |
| `Sources/PrototypeActionsSheet.swift` | Painel e ações compartilhadas |
| `Sources/TodayView.swift` / `DemoFlows.swift` | Composição de Today, More e fluxos demonstrativos |
| `UITests/DesignSystemTests.swift` | Navegação, temas, controles, formatos e replay do catálogo |

Esta é a versão inicial do sistema. Novos componentes devem entrar primeiro como implementações reutilizáveis, acompanhados de uma amostra no catálogo e do contrato correspondente neste documento.
