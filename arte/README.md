# Arte — máscaras indexadas de pixel art

Assets consumidos pela engine. Autorais (escritos à mão, no princípio de Spelunky:
templates fixos + aleatoriedade controlada na composição), mas **combinados
proceduralmente** pela Camada 2 — por isso ficam aqui, e não em `autoral/`, que é
reservado a conteúdo de jogo fixo (NPCs, mapas, diálogos).

```
arte/
├── corpos/    32 máscaras 32×32 (8 animais × 4 portes) + corpos_ancoras.json
├── garras/     4 máscaras 16×16 (curtas, curvas, serrilhadas, adaga)
├── apendices/ asas e nadadeiras (dorsal e peitoral), 4 modelos cada, + apendices.json
│   └── escamas/  128 sobreposições: 4 modelos para cada um dos 32 corpos
├── mundo/     cenário isométrico: atlas_terreno.png + props/ + os dois JSON
├── itens/     16 ícones 20×20 de dispositivo e isca: itens.png + itens.json
├── ui/        molduras 9-slice, medidor, selo, balão, vinheta e a fonte pixel
└── shaders/   paleta_indexada.gdshader
```

## Três famílias de arte, e por que elas são diferentes

`corpos/`, `garras/` e `apendices/` são **máscaras indexadas**: a cor da criatura é um
atributo *derivado sorteado* (RF04) e só pode ser resolvida em tempo de
execução, pelo shader. Já `mundo/`, `itens/` e `ui/` saem **coloridos**: a vila é
conteúdo autoral fixo e um ícone de osso não tem matiz sorteado. Passá-los pelo
shader de paleta inventaria um grau de liberdade que o modelo não tem.

Uma convenção atravessa as três: **luz no alto à esquerda**, contorno escuro de
1px por fora e rampa de três tons. É o que faz criatura, cenário e interface
conviverem no mesmo quadro sem parecerem recortados de jogos diferentes.

## Onde cada traço encosta

Cada corpo declara pontos de encaixe medidos na própria silhueta
(`arte/corpos/corpos_ancoras.json`, por `tools/arte/corpos_tipos.py`), e cada peça
declara o pixel que encosta neles, o **pivô** (`arte/apendices/apendices.json`):

| traço | onde | como |
|---|---|---|
| garras | `pe_frente`, `pe_tras` | a ponta da garra no chão, sob cada pé |
| asas | `dorso` (ombro) | a raiz da asa no ombro; ela sobe e varre para trás |
| nadadeiras | `dorso_tras` e `flanco` | dorsal mais atrás no dorso; peitoral na lateral do tronco |
| escamas | o corpo inteiro | textura recortada pela silhueta, só no miolo, sem tocar o contorno |

Ordem de desenho, de trás para a frente: corpo, escamas, nadadeiras, garras, asas.
Cada traço só aparece se o gerador o sorteou, no modelo sorteado
(`CatalogoCorpos.quadros_de_tracos`). A ave e o peixe **não** têm asa nem
nadadeiras pintadas no corpo: antes tinham, e uma ave sem o traço `asas` aparecia
com asa. `tools/test_arte_criaturas.gd` confere encaixes, recorte e contagem de peças.

```bash
python3 tools/arte/gerar_corpos.py && python3 tools/arte/gerar_apendices.py
```

## Máscara indexada

Os PNGs **não carregam cor**. O canal R codifica um índice de paleta:

| valor R | índice | papel |
|---|---|---|
| 0 (α=0) | — | transparente |
| 64 | 1 | contorno |
| 128 | 2 | sombra |
| 191 | 3 | base |
| 255 | 4 | brilho |

`paleta_indexada.gdshader` faz `idx = round(R * 4)` e substitui pela rampa de 4
tons que `PaletaCriatura.rampa(matiz, paleta)` deriva dos atributos sorteados.

Consequência que sustenta a escala: o mesmo PNG serve às 8 famílias elementais e
às ~100 criaturas do bestiário. O custo de memória é **O(silhuetas)**, não
O(silhuetas × paletas) — é o que permite atacar escala e coerência ao mesmo tempo
sem pagar em desempenho.

**A rampa vem de (matiz, paleta), nunca de uma tabela fixa por elemento.** Uma cor
por elemento tornaria `I(elemento; cor)` trivialmente igual a `H(elemento)` e
inflaria a métrica de RF08 com um resultado que não vem do modelo probabilístico.

## Âncoras

`corpos/corpos_ancoras.json` acompanha as máscaras: sem ele, os PNGs não dizem
onde um apêndice encosta. Por sprite: `arquetipo`, `tem_patas` e os pontos
`pe_frente`, `pe_tras`, `cabeca`, `cauda` em pixels do quadro 32×32.

**Todo** corpo declara pontos de acoplagem de garra, inclusive os sem patas: no
peixe eles ficam na borda ventral. Não há veto anatômico na apresentação — se o
sorteio concedeu garras a um peixe (2% a 12% dos casos), elas aparecem. O lugar de
suprimir um apêndice improvável é a tabela condicional, que é calibrável e entra
nas métricas. `tem_patas` é metadado descritivo, não veto.

As garras são exportadas **já na orientação de uso** (coxim em cima, unhas para
baixo): o compositor só cola a máscara na âncora, sem flip.

## Regerar

Nunca editar os PNGs nem o JSON à mão — eles são saída:

```bash
python3 tools/arte/gerar_corpos.py        # 32 máscaras + corpos_ancoras.json
python3 tools/arte/gerar_garras.py        #  4 máscaras
python3 tools/arte/gerar_itens.py         # itens.png + itens.json (16 ícones)
python3 tools/arte/gerar_ui.py            # molduras, medidor, selo, balão, vinheta
python3 tools/arte/gerar_fonte.py         # fonte_pixel{,_2x,_3x}.png + .fnt
python3 tools/arte/gerar_mundo_tiles.py   # atlas_terreno.png + .json
python3 tools/arte/gerar_mundo_props.py   # props/*.png + props.json
python3 tools/mapas/gerar_mundo.py        # o mapa (depende de props.json)
python3 tools/mapas/preview_mundo.py      # confere o mundo fora da engine
python3 tools/validate_tables.py          # confere cobertura animal × porte
```

A ordem importa: o compilador do mapa lê `props.json` para saber a pegada de
cada prop, e a prévia lê os dois. Depois de mexer em qualquer PNG, rode
`godot --headless --path . --import` — o Godot **não** reimporta ao rodar o
jogo, e a textura antiga continua sendo usada em silêncio.

## Cenário isométrico (`mundo/`)

Losango canônico **32×16** (2:1). O chão é um atlas de 16 colunas × 10 linhas
(`grama`, `caminho`, `terra`, `areia`, `agua`, `rocha`, `grama_alta` e, com a
expansão do mundo, `calcada`, `lavoura` e `ponte`);
`atlas_terreno.json` diz em que linha mora cada terreno e é lido tanto pelo
`MundoIso` em GDScript quanto pela prévia em Python — os dois precisam
concordar pixel a pixel, ou a prévia deixa de valer como conferência do jogo.

Terrenos que formam manchas (caminho, lago, praia, grama alta) têm **16
versões**, uma por subconjunto das 4 arestas do losango — `NO=1, NE=2, SE=4,
SO=8`, o bit aceso significando "deste lado o terreno acaba". Quem calcula a
máscara é o carregador, a partir da grade do mapa. Assim o formato do lago vive
no *dado*, e não na arte: um lago diferente não pede um PNG novo.

`props.json` acompanha `props/`: para cada prop, a **âncora** (o pixel que cai
sobre o centro da pegada), a pegada em células e o **polígono de colisão** —
que é a projeção da área no chão, e não a caixa do quadro: colidir com o quadro
faria o jogador esbarrar no ar acima do telhado.

Folhas de contato para conferência visual ficam em `tools/arte/_preview/`
(marcada com `.gdignore`, fora do import da engine).

## Interface (`ui/`, `itens/`)

Arte da tela de encontro (`presentation/encontro/`). Existe pelo mesmo motivo do
resto: **não há asset comprado nem baixado neste projeto** — tudo sai de um script
em `tools/arte/`, versionado, determinístico e regerável.

### Ícones de item

16 ícones de 20×20 numa folha única (`itens.png`), indexados por
`itens.json` com os **mesmos ids** de `data/captura/*.json`. Item declarado sem
ícone é erro de dado, apanhado por `tools/test_encontro.gd` — não um buraco
descoberto na tela.

Silhueta primeiro: em 20×20 o jogador precisa reconhecer o item sem ler o nome.
Nada de detalhe interno com menos de 2px.

> As duas esferas de captura têm **coleira e argola**, costura diagonal e uma
> lente fora do centro. Isso é decisão de design, não enfeite: um globo partido ao
> meio por uma faixa horizontal com um botão no centro é a forma registrada de
> outra franquia. O perfil daqui lê como aparelho de captura sendo original — e,
> de quebra, ganha uma silhueta que não é um círculo puro, o que a distingue da
> Redoma na roda.

### Molduras 9-slice

`StyleBoxTexture` divide a textura em 9 pedaços: os 4 cantos ficam intactos, as
bordas esticam num eixo e só o miolo estica nos dois. Por isso toda moldura é
*contorno, chanfro, linha interna, miolo de cor chapada* — detalhe no miolo vira
borrão esticado. As tachas dos cantos existem porque canto é o que o 9-slice
**não** deforma.

Chanfro claro em cima/à esquerda e escuro embaixo/à direita: é o que dá volume
sem sombra projetada. Sombra difusa lê como interface web; chanfro de 1px lê como
objeto.

### Fonte

Bitmap 5×7 em caixa 5×11, gerada glifo a glifo por `tools/arte/gerar_fonte.py` a
partir de `tools/arte/fonte_glifos.py`, exportada em **BMFont** (`.fnt`), que o
Godot 4 importa nativamente.

Três folhas — 1×, 2× e 3× — e não uma escalada em tempo de execução: uma fonte de
bitmap pedida acima do tamanho nativo é reamostrada, e o filtro come a borda do
pixel. Ampliar por vizinho mais próximo na geração mantém cada pixel um quadrado.

Os 27 glifos acentuados são **compostos** (base + acento), não redesenhados: uma
correção no `a` corrige `á à â ã` de uma vez. `tools/test_encontro.gd` confere que
a fonte cobre todo o texto que a interface escreve — glifo ausente não dá erro,
sai como caixa vazia.

### Vinheta

Escurecimento radial em **trama xadrez de 4 níveis**, 192×108 (exatamente 1/6 de
1152×648, então sobe por replicação inteira de pixel). Um degradê liso no meio de
uma tela de pixel art denuncia a interface como estranha ao jogo.
