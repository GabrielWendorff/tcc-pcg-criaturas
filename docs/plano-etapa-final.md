# Plano da etapa final

Levantamento de 03/11/2026 (terça-feira) contra o
[The Portfolio Playbook](https://github.com/CatolicaSC-Portfolio/The-Portfolio-Playbook)
(revisão `ce005fe`), linha de **Jogos Digitais**. O quadro de execução é o
[Trello](https://trello.com/b/nPQmonFA/pac-vii-viii-pcg-rpg-2d), lista
"Etapa Final (até 30/11)". `docs/pendencias.md` continua sendo o registro técnico.

Faltam **27 dias** para a entrega de 30/11/2026 (segunda-feira), contados de 03/11.

**Estado em 04/11/2026:** a fatia de combate, vitória e derrota está pronta e foi testada
pelo autor, e as builds para a aula estão geradas (seção 4.1). O próximo marco é a aula de
06/11.

---

## 1. Gates: não viram nota, impedem de apresentar

| Gate | Prazo | Estado | Ação |
|---|---|---|---|
| 2 orientações evidenciadas | 30/09/2026 | **não realizadas: não houve aula até agora; prazo vencido** | pedir nova data por escrito na aula de 06/11/2026 |
| Playtest com ≥ 10 pessoas | 30/10/2026 | **não realizado; prazo vencido** | possivelmente na aula de 06/11/2026; levar build |
| Relatório do playtest | 30/10/2026 | **não realizado; prazo vencido** | pedir nova data por escrito na aula de 06/11/2026 |
| 5 orientações evidenciadas | 30/11/2026 | **nenhuma até agora** | agendar as 5 em 06/11/2026 |
| Jogo do início ao fim, com vitória e derrota | 30/11/2026 | **fatia atende** (1 guardiã); faltam 2 guardiões e o duelo final | seção 3 |
| Build pública (Itch.io, loja, WebGL, APK) | 30/11/2026 | só builds locais de Linux e Windows (seção 4.1) | CI + itch.io |
| GDD (mínimo: visão, loop, mecânicas, tecnologias) | 30/11/2026 | não existe | template de 19 seções |
| Wiki | 30/11/2026 | **primeira versão publicada em 04/11**; cresce com CI, GDD, playtest e gerador v2 | fechar em 24/11 |
| CI/CD com build automatizado | 30/11/2026 | não existe | GitHub Actions |
| Análise estática | 30/11/2026 | não existe | `gdlint` no CI |
| Monitoramento (log de erros ou telemetria) | 30/11/2026 | não existe | log de sessão e erros |
| Pôster A0 em PDF com QR Code | 30/11/2026 | não existe | template oficial |
| Prova de autoria | 30/11/2026 (2ª tentativa: 03/12/2026) | a preparar | ensaio das 25 perguntas |
| PAC VIII: release, peer review, aceite | 30/11/2026 | **a confirmar** | ver decisão D4 |
| Visitar outra noite do Demo Day e avaliar colegas | 10, 15 ou 16/12/2026 | futuro | requisito de aprovação |

"Sem condição de vitória/derrota" está em *O que não pode ter* da linha. Desde 03/11 o
jogo não incorre mais nisso. O maior risco técnico passou a ser o acúmulo entre 13/11 e
19/11 (seção 4).

## 2. Nota: o que falta para o 5 em cada critério

A nota é a média dos 6 critérios (Likert 1–5) × 2. **Tirar 10 exige 5 nos seis,
com os três professores.** O critério 5 é eliminatório.

| Critério | O que já sustenta | O que falta |
|---|---|---|
| 1. Relevância e complexidade | contribuição original (atributos correlacionados), RF08 medido contra baseline | jogo completo que mostre isso, com escopo declarado no GDD |
| 2. Documentação | READMEs por módulo, README raiz, Wiki, `mudancas-estruturais.md`, `pendencias.md` | GDD, Wiki completa, diagrama C4 |
| 3. Qualidade do código | regras puras em `regras/`, dados em JSON, testes de lógica | corrigir os testes da seção 2.1; PRs revisados; lint |
| 4. Infra e engenharia | Git | CI/CD, deploy automatizado, monitoramento, ambientes dev/produção |
| 5. Ética e autoria | arte gerada por scripts próprios | créditos e referências no GDD (seções 3 e 18), domínio do código |
| 6. Apresentação | — | pôster, demo estável, vídeo, QR Code, ensaio |

*Destaque* pede ainda polimento e **evidência de iteração a partir de playtests**;
playtest com público externo é diferencial.

### 2.1 Estado dos testes (Godot 4.7, 03/11/2026)

| Teste | Resultado |
|---|---|
| `test_dialogo`, `test_equipamento`, `test_gerador`, `test_mundo`, `test_pesca`, `test_tutorial` | passam |
| `test_pesca_integracao.tscn` (como cena) | passa (153 verificações) |
| `test_encontro` | corrigido em 03/11: roda como cena (`test_encontro.tscn`) e exige que cada etapa chegue ao fim |
| `test_batalha`, `test_arco.tscn` | novos em 03/11; passam |
| `test_interacao` | **aborta** pelo mesmo motivo (autoload sob `-s`) |
| `test_bolsa` | **não compila** (`detalhe()` sem argumento, linha 125) |
| `test_save` | **2 falhas**: `autoload registrado` (efeito do `-s`) e `sorteio de seed não se repete` |

Antes do CI, os testes que tocam autoloads precisam rodar como cena, e o
executor precisa falhar quando um teste aborta.

### 2.2 Requisitos funcionais

| RF | Estado |
|---|---|
| RF01 mundo por seed, RF02 bestiário, RF03 reprodutibilidade, RF05 exploração, RF08 métricas | entregues |
| RF04 atributos correlacionados | entregue no dado; **escamas, asas e nadadeiras não são desenhadas** (`pendencias.md`, itens 1 e 2), e são os exemplos centrais da tese |
| RF06 batalhas | **fatia entregue em 03/11** (`presentation/batalha/README.md`); faltam 2 guardiões e o duelo final |
| RF07 stats e visual | parcial: mesma lacuna de arte; sem tela de coleção |
| Camada 3 (ambientação pela seed) | **não implementada**: `procedural/ambiance/` só tem README; a vegetação atual é autoral |

## 3. Jogo com começo, meio e fim

Arco aprovado em 03/11/2026. **O ponto de interesse do jogo é o gerador de
criaturas e o seu algoritmo:** o resto existe para o jogador usar e enxergar o que
ele produz. Sessão-alvo de 15 a 20 minutos, reaproveitando o que existe.

- **Início:** nova partida com seed → vila → Anselmo dá o objetivo e a primeira
  criatura. Objetivo sempre visível no HUD.
- **Meio:** capturar e pescar para montar uma equipe de até 3; cada uma das 3
  regiões fora da vila tem um **guardião** (NPC autoral, ao ar livre) que dá um
  selo ao ser vencido.
- **Vitória:** com os 3 selos, o duelo final na vila → tela de encerramento com
  os dados da seed (capturas, coerência do bestiário).
- **Derrota:** equipe inteira sem HP → tela de derrota, com retorno ao último save.

**Vitrine do algoritmo (RF07, RF08):** bestiário dentro do jogo que mostra, para
cada criatura, Seed → primários → probabilidades condicionadas → derivados, e
marca se ela é coerente ou atípica. A tela final compara a coerência da seed com a
baseline independente. Junto da arte de escamas, asas e nadadeiras, tem prioridade
sobre Camada 3, áudio e polimento.

**Batalha (RF06):** por turnos, 1×1, com tabela de elementos em
`data/batalha/*.json`. Stats **derivados** da morfologia e do porte já sorteados,
sem tocar no `GeradorCriaturas`: é o mesmo caminho da pesca e da afinidade de
captura. RNG próprio (`world_seed` + deslocamento), regra pura em
`presentation/batalha/regras/` e `tools/test_batalha.gd`.

**No trade-off:** derivar custa quase nada em tempo real e não altera o bestiário
(coerência e métricas preservadas), enquanto uma busca ao estilo de Togelius et
al. (2011) pagaria desempenho sem ganho para este objetivo. A escala continua
limitada às ~100 criaturas por seed.

**Ajustes de 03/11 ao arco acima:** quem dá a primeira criatura é a **Mirela**, não o
Anselmo: ela está a 2 células do início, e o Anselmo a 40, depois do mato. É uma **escolha
de 1 entre 3** criaturas da seed. Os guardiões são NPCs existentes: Dulce, Anselmo e Otávio.
Sem XP nem níveis: a força vem de qual criatura se tem. O HP persiste, com cura gratuita
da Mirela e salvamento automático antes de cada guardião.

**Fora do escopo final, salvo sobra de prazo:** loja, interiores de casa, missões
paralelas, agenda de NPCs. Vão para a seção 16 do GDD como limitações.

**Sincronia com o artigo:** equipes de guardião lidas do bestiário da seed são
conteúdo autoral condicionado à saída do gerador, o caso previsto em
`mudancas-estruturais.md` (2026-09-16). A Camada 3 também. **Os dois exigem
registro lá e atualização da Seção 3.**

## 4. Cronograma

| Até | Entrega |
|---|---|
| ~~05/11~~ | ~~build para a aula: batalha, vitória e derrota~~ (pronta em 04/11; seção 4.1) |
| 06/11 | primeira aula: novas datas por escrito, orientações agendadas, possível playtest |
| 08/11 | testes corrigidos, CI com testes e `gdlint` |
| 10/11 | ajustes do combate a partir do que a aula mostrar; GDD v0.5 |
| 11/11 | build web no itch.io pelo CI, com log de erros |
| 13/11 | **gerador v2**, em três braços (independente, v1, v2); simulador de novo; vitrine do algoritmo |
| 15/11 | arte de asas e nadadeiras (escamas depois) |
| 16/11 | Anselmo, Otávio e duelo final (dono a definir): **jogo completo** |
| 18/11 | Camada 3 mínima; nota da Seção 3 do artigo |
| 19/11 | playtest da versão completa (≥ 10, com público externo), com o **teste cego** |
| 22/11 | melhorias do playtest, áudio, game feel |
| 24/11 | GDD v1.0, Wiki completa, peer review do PAC VIII |
| 26/11 | pôster, vídeo, QR Code; artigo final |
| 27/11 | ensaio da prova de autoria; congelar a release |
| 30/11 | **entrega** e prova de autoria |
| 10, 15, 16/12 | Poster + Demo Day |

**Risco:** gerador v2, vitrine, arte e guardiões vêm em sequência entre 13/11 e 16/11, e o
teste cego de 19/11 depende da v2 e da arte. Proposta, se atrasar: cortar primeiro a
Camada 3 de 18/11, depois as escamas.

### 4.1 Builds

| Build | Arquivo em `exports/` | F2, F3, F4 | Uso |
|---|---|---|---|
| entrega | `linux/rpg-pcg.x86_64`, `windows/rpg-pcg.exe` | não | aula e playtest |
| debug | `debug/linux/rpg-pcg-debug.x86_64`, `debug/windows/rpg-pcg-debug.exe` | sim | demonstração e diagnóstico |

```bash
godot --headless --path . --export-release "Linux" exports/linux/rpg-pcg.x86_64
godot --headless --path . --export-release "Windows" exports/windows/rpg-pcg.exe
godot --headless --path . --export-debug "Linux" exports/debug/linux/rpg-pcg-debug.x86_64
godot --headless --path . --export-debug "Windows" exports/debug/windows/rpg-pcg-debug.exe
```

As teclas seguem `OS.is_debug_build()`. A F5 (salvar) e o F de usar item valem nas duas.

`export_presets.cfg` e `exports/` estão fora do git, e o filtro que mantém as referências
locais (`autoral/_*`) fora da build está nesse arquivo. **O CI precisa dele:** versionar o
arquivo no passo de 08/11 e conferir o binário com `grep -a _ref_direcoes`.

## 5. Decisões

Tomadas em 03/11/2026:

- **Arco do jogo:** aprovado, com foco no gerador (seção 3).
- **Repositório público:** a Wiki em repositório privado exige plano pago. Aberto em 04/11.
- **Referência do protagonista:** sprite de Pokémon Emerald, usado para formato e
  proporção. A imagem fica fora do repositório e entra como referência no GDD.
- **Artigo:** será versionado neste repositório pelo autor.

- **Gerador v2, adiado para depois do combate:** novo modo, mantendo a v1 reproduzível.
  Entram: bestiário estratificado, dependência entre traços, `P(porte | animal, elemento)`
  e nota de coerência por criatura (surpresa). **Fora:** `P(matiz | elemento, paleta)` e
  vocabulário maior. Primários seguem independentes: fogo+peixe é um caso que o trabalho
  quer mostrar. Sem busca nem rejeição.
- **Critérios da v2, fixados antes de escrevê-la:** 64/64 pares em toda seed; informação
  mútua e unicidade sem queda (n=5000); geração abaixo de 2 s; RF03. O choque paleta×matiz
  (cerca de 6,6%) fica como dado informativo, porque a melhoria que o reduziria ficou fora.
- **Validação humana:** teste cego no playtest de 19/11, em que pessoas adivinham o
  elemento pelo sprite, comparando os três braços. Quebra a circularidade de medir a
  tabela com a própria tabela.
- **Critério de aceite do combate:** `tools/simular_batalha.gd`.

Tomadas em 04/11/2026:

- **Teclas de desenvolvimento** só no editor e na build de debug.

Pendente, sem data:

- Quem faz o duelo final.

Pendentes, para a aula de 06/11/2026:

- Novas datas de orientações, playtest e relatório, por escrito.
- PAC VIII: modalidade (Parceiro ou Comunidade), squad e NPs.
