# Mapa geral (tecla M)

```bash
godot --headless --path . -s res://tools/test_mundo.gd   # inclui a carta
```

Uma tela: `mapa_mundo.gd` → `MapaMundo`.

## A carta é rasterizada do próprio terreno

Um pixel por célula, na mesma projeção isométrica em que o jogador anda. **Não é
uma ilustração desenhada à parte**, e isso é decisão de arquitetura antes de ser
de arte:

- uma região nova aparece no mapa **sem ninguém desenhar nada** — basta ela
  existir no JSON do mundo. É o critério de "o sistema escala para novas áreas";
- o mapa não pode **mentir**. Ilustração envelhece em silêncio: muda-se o curso
  do rio no compilador do mapa e a carta continua mostrando o rio antigo. Aqui as
  duas coisas são o mesmo dado.

A projeção `(gx - gy, (gx + gy) / 2)` é a mesma relação 2:1 de `MundoIso`, em
miniatura. Uma carta desenhada na grade (retângulo) estaria girada 45° em relação
ao que se vê andando, e o jogador teria de fazer a conversão de cabeça.

Cada célula é pintada com **dois pixels de largura**: na projeção em miniatura,
células vizinhas caem em colunas alternadas, e um pixel só deixaria a carta
furada como um xadrez.

## Descoberta

Região não visitada aparece sob um véu de tinta envelhecida, com o nome
escondido (`?`) e a legenda em `???`. Quem decide é `EstadoMundo.visitou()` — a
**mesma** bandeira que o diálogo consulta com `{"visitou": "ribeira"}`.

A região do spawn é marcada na mão ao montar a cena: o jogador já nasce dentro
dela e `body_entered` nunca dispara, então sem isso a vila apareceria como `???`
até ele sair e voltar.

## Identidade visual

Moldura de pergaminho 9-slice, fonte bitmap e paleta do `TemaEncontro` — as
mesmas da interface de encontro e da caixa de diálogo. As cores dos terrenos
espelham `tools/arte/mundo_lib.py`, um tom acima do tom base para a carta não
sair abafada sob o véu.

O marcador do jogador pulsa: num mapa de 8.448 células, um ponto parado do
tamanho de um pixel se perde.

## Acrescentar uma região ao mapa

Nada a fazer aqui. Declare a região em `tools/mapas/regioes/<nome>.py`
(`m.regiao(...)`), regere o mundo, e ela aparece — no mapa, na legenda, no
gatilho de visita e na validação de alcançabilidade.
