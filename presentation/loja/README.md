# Lojas e gold

Três lojas, abertas pelo diálogo do vendedor (`{"servico": {"tipo": "loja", "loja": <id>}}`)
quando a conversa fecha:

| loja | vendedor | onde | vende |
|---|---|---|---|
| `vila` | Lauro | armazém da vila, na praça | dispositivos e poções |
| `padaria` | Bento | distrito da chaminé | iscas de comida e poção simples |
| `fazenda` | Dulce | sítio | iscas do campo |

- **Quem vende o quê** é autoral: `autoral/lojas/lojas.json`.
- **Quanto custa** é balanceamento: `data/economia/economia.json`, igual em toda loja.
- **Quem cobra e guarda** é a `Bolsa` (`Bolsa.comprar`, `Bolsa.gold`), que vai para o save.

## Gold

- Partida nova: **150 gold e nenhum consumível** na bolsa (só ferramentas).
- A Mirela entrega um **kit** com a primeira criatura: 5 esferas simples e 2 poções.
- Derrotar um **selvagem** paga `base + por_forca × força` da criatura: criatura mais
  forte que o gerador produziu vale mais. Capturar não paga.
- Vencer um **guardião** paga o `premio_gold` dele (`autoral/guardioes/guardioes.json`),
  só na primeira vitória.

```bash
godot --headless --path . -s res://tools/test_economia.gd   # dados coerentes entre si
godot --headless --path . res://tools/test_arco.tscn        # comprar, ganhar, salvar
```
