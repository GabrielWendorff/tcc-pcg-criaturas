# Camada 4 — Apresentação

Integra as saídas das camadas 1–3 e as expõe ao jogador.

- `menu/` — **menu principal, slots de save e a escolha da seed (RF01)**. É a
  cena principal do projeto desde a Etapa 1; o mundo deixou de ser a primeira
  tela e passou a receber a seed de fora, por `Save.partida` — ver
  `menu/README.md`.
- `bolsa/` — **itens do jogador**: abas por categoria, lista e ficha. Aberta por
  **B** no mundo ou pelo menu de pausa — ver `bolsa/README.md`.
- `exploracao/` — navegação pelo mundo (RF05). **Primeira área jogável**: vila
  isométrica com jogador, câmera, colisão, lago, casas e as zonas preparadas
  para os futuros encontros. Era a cena principal até a Etapa 1; hoje é aberta
  pelo menu, que lhe entrega a seed — ver `exploracao/README.md`.
- `encontro/` — encontro e captura de criaturas: detecção na exploração, roteiro
  de aviso/transição, menu de ação, roda radial de itens e o cálculo centralizado
  de captura. É onde o bestiário gerado pela seed vira decisão de jogo — ver
  `encontro/README.md`.
- `pesca/` — **a segunda forma de encontrar uma criatura**: na beira d'água, com a
  vara na mão, arco de força, recolhimento com o mouse e a silhueta que segue a
  isca. Altura, velocidade e folgas de cada criatura são **derivadas** da
  morfologia que o gerador já sorteou (RF04 virando mecânica); para na fisgada
  (`peixe_fisgado`), sem batalha — ver `pesca/README.md`.
- `equipamento/` — **o item na mão** (`SlotDaMao`, filho do jogador, ordem de
  desenho por direção) e a **roda de itens** do **Q**, montada com o que a bolsa
  tem marcado como equipamento — ver `equipamento/README.md`.
- `tutorial/` — **tutorial como sequência de passos em dado**: a lição de pesca
  do Anselmo (`autoral/tutoriais/pesca.json`), dicas no topo da tela e pulo com
  confirmação — ver `tutorial/README.md`.
- `dialogo/` — NPCs, árvores de diálogo, condições e efeitos; é por ele que o
  tutorial fala — ver `dialogo/README.md`.
- `batalha/` — sistema de combate e exibição de stats/visual (RF06, RF07). Ainda
  vazio: o golpe que enfraquece a criatura dentro do encontro é um mínimo
  provisório, não um sistema de batalha.
- `creature_sprite_renderer.gd` — desenha a criatura com a pixel art de `arte/`:
  máscara do corpo `(animal_base, porte)` + apêndices nas âncoras daquele corpo,
  coloridos por um único `ShaderMaterial` com a rampa de `PaletaCriatura`.
- `creature_renderer.gd` — renderizador vetorial anterior, mantido como referência
  (nenhuma tela ativa o usa).

Esta camada **consome** dados; não gera conteúdo procedural por conta própria.

O estado que sobrevive a fechar o jogo não mora aqui: vive em `sistemas/`, fora
de qualquer cena. Cada tela declara ao autoload `Save` como colher e repor o que
é seu, e nenhuma delas conhece o formato do arquivo.
