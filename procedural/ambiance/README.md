# Camada 3 — Gerador Procedural de Ambientação

Distribuição secundária, também alimentada pela seed:
vegetação, construções menores e pontos de interesse.

Segue as mesmas regras da camada de criaturas: seed explícita e determinismo
(RF03). Depende das camadas 1 e 2 apenas como contexto de posicionamento.

**Ainda não implementada.** O ponto de entrada já existe: a primeira área
jogável (`presentation/exploracao/`) expõe

```gdscript
MundoIso.adicionar_prop(categoria, {"prop": "arvore_01", "celula": [12, 20]})
```

que instancia sprite, colisão e ordenação por profundidade a partir de
`arte/mundo/props.json`. Esta camada vai chamá-lo com posições sorteadas pela
seed, sobre um mapa autoral que deixou vazios de propósito — um cenário saturado
de props escritos à mão não teria onde recebê-la.

As áreas de grama alta da vila (`pontos_encontro` no mapa) trazem
`elementos_provaveis`, que é onde o condicionamento por região vai se apoiar:
uma margem de lago puxa `agua`/`gelo`, um pedregal puxa `terra`/`eletrico`.
Isso estende RF04 — atributos correlacionados — do interior da criatura para a
relação entre criatura e lugar.
