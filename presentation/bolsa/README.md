# Bolsa

A tela de itens: abas por categoria, lista do que o jogador tem, ficha do item
sob o cursor.

```bash
godot --headless --path . -s res://tools/test_bolsa.gd    # opções + catálogo + bolsa
godot --path .    # no mundo: B abre a bolsa, ESC abre a pausa
```

## Não é um inventário novo

`InventarioJogador` já era a tabela `id → quantidade` com sinais, já era
consumida pelo encontro e já estava testada. O comentário no topo daquele
arquivo previa este momento: *"quando houver loja, chave, cura e material, o
formato já é o mesmo"*.

O autoload `Bolsa` é o que faltava **em volta** dele:

```
Bolsa ──possui──▶ InventarioJogador    quantidades + sinais (inalterado)
      ──possui──▶ CatalogoItens        o que cada id significa
```

Quem já falava com o inventário continua falando com ele: a cena do mundo
entrega `Bolsa.inventario` ao `GerenciadorEncontro`, e o encontro **não sabe que
existe uma bolsa**. Quem precisa de categoria, descrição ou ícone fala com a
`Bolsa`.

## Duas fontes, um espaço de nomes

```
data/captura/dispositivos.json  ──TabelasCaptura──┐
data/captura/iscas.json         ──TabelasCaptura──┼──▶ ItemJogo ──▶ Bolsa
data/itens/catalogo.json        ──────────────────┘
```

Os itens de captura **não são redeclarados**: `ItemJogo.de_captura()` envelopa o
`DispositivoCaptura`/`IscaCaptura` que o encontro já usa. Dois arquivos
descrevendo o mesmo dispositivo divergiriam na primeira calibragem, e o bug
seria silencioso — a roda de captura usaria um número e a bolsa mostraria outro.

A consequência boa: `ItemJogo.detalhe()` **delega** ao objeto de mecânica. A
ficha de uma isca na bolsa e na roda de captura dizem a mesma coisa porque é
literalmente o mesmo método — e, com uma criatura em foco, as duas mudam juntas
de `atrai canino` para `preferida por canino (+45%)`.

## Marcadores em vez de subclasses

`item.tem_marcador("pesca")`. "Esta vara serve para pescar" é um marcador, não um
tipo: uma subclasse `ItemDePesca` obrigaria o catálogo a conhecer a pesca, e a
bolsa a conhecer as duas — para responder a uma pergunta de uma palavra.

Toda isca de captura ganha o marcador `pesca` automaticamente: a pescaria não
precisa de um segundo conjunto de iscas, porque o que ela consulta é o
`animal_base` preferido, que a `IscaCaptura` já declara.

Por isso `Bolsa.tem_marcador("pesca")` **não** responde "o jogador tem vara?" —
com as minhocas da carga inicial ele já é verdadeiro. Com a pesca pronta, a
pergunta é outra: o `GerenciadorPesca` olha o item **na mão**
(`ItemJogo.uso == "pescar"`, ver `equipamento/README.md`), e o HUD do mundo
procura na bolsa um equipamento com esse `uso` (`mundo.gd::_vara_na_bolsa`).

## Equipamento: `mao`, `uso` e o marcador `equipamento`

Três campos de item, todos opcionais, dizem o que acontece quando ele vai para
a mão do jogador:

```json
{"id": "vara_de_pesca", "marcadores": ["pesca", "equipamento"],
 "mao": {"forma": "vara", "comprimento": 18.0, "cor": "8a5a3c"},
 "uso": "pescar"}
```

| campo | em `ItemJogo` | o quê |
|---|---|---|
| marcador `equipamento` | `equipavel()` | o item pode ir para a mão e aparece na roda de itens (Q) |
| `mao` | `mao: Dictionary` | como desenhá-lo na mão: `forma` (`vara`·`lanterna`·`pa`·`icone`), `comprimento`, `cor`; `textura`/`cena` trazem a arte final |
| `uso` | `uso: String` | o que **F** faz com ele na mão. `"pescar"` liga a pesca; `""` só troca o sprite |

`equipavel()` é um marcador e não um booleano novo pela mesma régua de cima: a
vara já era `equipamento` no catálogo. `mao` é declarativo como `efeito` — quem
interpreta é `ItemNaMao` (`presentation/equipamento/`), e item equipável sem
`mao` aparece como o próprio ícone, pequeno. Leitura defensiva: `"mao"` que não
é objeto vira `{}` e `"uso"` que não é texto vira `""`, em vez de derrubar o
catálogo inteiro.

Dois itens de exemplo entram com isso, um de cada na carga inicial:
**Lanterna** e **Pá de Jardim** (`ferramentas`, permanentes, `uso: ""`). Com a
vara na bolsa, `com_marcador("equipamento")` passa a ter três itens.

Ver `presentation/equipamento/README.md` para as poses, a ordem de desenho e a
roda.

## API

| pedido | aqui |
|---|---|
| `add_item` | `Bolsa.adicionar(id, n)` — devolve **quanto coube** |
| `remove_item` | `Bolsa.remover(id, n)` — falso se não houver, ou se for permanente |
| `has_item` | `Bolsa.tem(id, n)` |
| `get_quantity` | `Bolsa.quantidade(id)` |
| sinal | `Bolsa.item_mudou(id, quantidade)` |

Mais: `da_categoria`, `categorias_com_itens`, `com_marcador`, `tem_marcador`,
`reiniciar`.

Dois comportamentos que não são detalhe:

- **Não empilhável tem teto 1.** `adicionar("vara_de_pesca", 3)` devolve `1`. É o
  que impede o pescador de dar uma segunda vara ao jogador que volta para
  repetir o tutorial.
- **Permanente não se remove.** Perder a vara por um clique errado não é uma
  decisão que o jogo deva oferecer.

## Aba vazia não aparece

A bolsa lista o que o jogador **tem**, não o que existe no jogo: uma aba de
consumíveis permanentemente vazia seria ruído fixo. A consequência é que as abas
mudam de número ao longo da partida, e por isso a seleção é reancorada por **id**
de categoria, nunca por índice.

## Acrescentar um item

1. uma entrada em `data/itens/catalogo.json` (ou em `data/captura/*.json`, se for
   item de captura);
2. uma função de desenho em `tools/arte/gerar_itens.py` + o id **no fim** de
   `OUTROS`, e rodar `python3 tools/arte/gerar_itens.py`. No fim porque o índice
   na folha é a posição na lista: inserir no meio renumeraria os ícones
   seguintes;
3. se for equipamento: o marcador `equipamento`, e `mao`/`uso` (seção acima).

Item sem ícone **não dá erro na engine** — dá um buraco na bolsa. `tools/test_bolsa.gd`
confere o índice de ícones contra o catálogo inteiro e nomeia o que falta.

## Efeitos ainda não são consumidos

`{"tipo": "curar", "valor": 30}` é declarativo e está no dado desde já, mas
**nenhum sistema interpreta**: a batalha é a Etapa 5. Usar uma poção hoje
responde com uma recusa escrita, em vez de gastar o item em silêncio.

## Arquivos

| arquivo | papel |
|---|---|
| `tela_bolsa.gd` | `TelaBolsa` — abas, lista, ficha. Modal: lê a própria entrada |
| `../../sistemas/bolsa.gd` | autoload `Bolsa` |
| `../../sistemas/regras/item_jogo.gd` | `ItemJogo` — a ficha de um item |
| `../../sistemas/regras/catalogo_itens.gd` | `CatalogoItens` — as duas fontes num namespace |
| `../../data/itens/catalogo.json` | categorias + itens que não são de captura (com `mao`/`uso` dos equipáveis) |

Reaproveitados: `IconeCaptura` (recorta `arte/itens/itens.png` por id — genérico
apesar do nome), `TemaEncontro` (fonte, molduras, paleta).
