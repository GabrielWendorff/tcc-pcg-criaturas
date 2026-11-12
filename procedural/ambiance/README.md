# Camada 3: Ambientação pela seed

Distribui vegetação, rochas, sucata e um ponto de interesse por região sobre o mapa autoral.
Implementada em `gerador_ambientacao.gd`, com os números em `data/ambientacao.json`.

```bash
godot --headless --path . -s res://tools/test_ambientacao.gd
```

## Como funciona

```
seed + bestiário da seed + mapa autoral
  └─ por região: elemento dominante = o que o bestiário mais trouxe entre os
                 elementos_provaveis das zonas daquela região
       └─ por célula livre: sorteia se recebe algo (densidade × fator do elemento)
            └─ classe ~ pesos_da_região[classe] × viés_do_elemento[classe]
                 └─ prop da classe (flor, junco, toco, sucata, folhosa, conífera, rocha)
  └─ um achado por região: bolsa perdida em célula alcançável, que paga gold uma vez
```

É o condicionamento entre **criatura e lugar**: numa seed em que a vila recebe mais
criaturas de planta, a vila floresce; com mais elétricas, aparece sucata. Medido em
`test_ambientacao`: I(elemento dominante; classe) = 0,148 bit contra 0,003 bit do baseline
sem elemento, em 300 seeds.

## Garantias

- **RF03:** RNG próprio (`seed + 0xA3B1E`). Mesma seed, mesmo resultado, e o bestiário não muda.
- **Não estraga o mapa autoral:** só em grama livre, longe de caminhos, portas, spawn, NPCs e
  do trajeto da chegada de ônibus.
- **Não bloqueia passagem:** um obstáculo só entra com as 8 vizinhas livres. Um obstáculo
  isolado não separa duas áreas, então não há caminho a reconferir. O teste confere em 40
  seeds que NPCs, porta e zonas continuam alcançáveis.
- **Sem busca e sem rejeição:** cada célula consome três sorteios, sirva ou não. Custo de
  cerca de 40 ms para o mapa inteiro.

## No trade-off

Escala: cada seed muda o lugar, além das criaturas. Coerência: o lugar passa a refletir o
bestiário, medido contra o baseline. Desempenho: linear nas células, uma vez ao abrir o mundo.
Interiores continuam autorais.
