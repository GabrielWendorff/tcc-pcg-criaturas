# Pôster A0 e peças de divulgação

| Arquivo | O que é |
|---|---|
| `poster.pdf` | o pôster, A0 retrato (841 × 1189 mm), texto e gráficos vetoriais |
| `poster_previa.png` | prévia pequena, para conferir sem abrir o PDF |
| `gerado/poster_150dpi.png` | o pôster em PNG, 4967 × 7021 px, para envio digital (fora do git) |
| `../../arte/divulgacao/` | banner e capa do itch.io, em 1x e 2x |
| `checklist-playbook.md` | o que o Playbook exige do pôster e da apresentação, com o estado de cada item |

## Regenerar

```bash
godot --headless --path . -s res://tools/poster/dados_poster.gd   # números → dados.json
godot --path . res://tools/divulgacao/renderizar.tscn               # mapa e criaturas (precisa de tela)
godot --path . res://tools/divulgacao/capturar_telas.tscn           # telas do jogo (precisa de tela)
python3 tools/divulgacao/compor.py                                  # banner e capa
python3 tools/poster/gerar_poster.py                                # pôster (precisa de segno e Chrome)
```

`gerar_poster.py` mede a altura das colunas no Chrome e avisa se o conteúdo passar do rodapé.

## O que preencher antes de imprimir

Em `tools/poster/config.json`:

- `email`: o e-mail institucional. Vazio, ele sai **marcado em amarelo**, como no template.
- `url_jogo`: a URL da página no itch.io. Vazio, o QR Code "Jogar no navegador" sai como um
  quadro amarelo a preencher.

O logo é o do template oficial (`logo_catolica_sc.jpeg`, 384 × 142 px). Para a impressão,
convém trocar por uma versão em alta resolução ou vetorial, com o mesmo nome.

## Decisões de desenho

- **Template oficial:** cabeçalho com logo, título, nome, e-mail e curso; faixas vermelhas
  (#C00000); Arial; seções Introdução, Desenvolvimento, Resultados, Conclusões e Referências.
- **Identidade do jogo:** título na fonte pixel do jogo, e o mapa como faixa de destaque, sob
  um véu escuro para o texto não brigar com ele. O fundo do resto do pôster fica branco, como
  pede o template.
- **Pouco texto:** todo número sai de `dados.json`, medido no gerador real. Nenhum texto abaixo
  de 20 pt.
