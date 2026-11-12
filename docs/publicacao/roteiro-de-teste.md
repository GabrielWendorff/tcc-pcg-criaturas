# Roteiro de teste da build publicada

Para a verificação da build pública e para a prova de autoria. O Playbook não fala em
"auditoria": o que ele verifica é a **build pública e jogável** (linha de Jogos Digitais) e a
**prova de autoria** (`docs/prova-de-autoria.md`).

## O que será verificado

| Fonte | Exigência | Onde se comprova |
|---|---|---|
| Linha de Jogos | jogável do início ao fim, com vitória e derrota | cenários 1 a 6 |
| Linha de Jogos | build pública e distribuída, sem depender do autor | página do itch.io, cenário 0 |
| Linha de Jogos | interface navegável, com feedback visual e sonoro | cenários 1, 3 e 7 |
| Núcleo comum | CI com build automatizado e análise estática | GitHub Actions: testes, gdlint, builds |
| Núcleo comum | monitoramento ou log de erros | `user://logs/sessao_*.jsonl` (cenário 8) |
| Avaliação | demonstração funcional em ambiente produtivo | itch.io, no navegador do avaliador |

## Cenários

Cada cenário começa em **partida nova** salvo indicação. Tempo total: cerca de 25 minutos.

| # | Cenário | Passos | Aceite |
|---|---|---|---|
| 0 | Acesso | abrir a URL do itch.io numa aba anônima, clicar em jogar | menu em até 30 s numa conexão comum, sem tela preta |
| 1 | Abertura | NOVO JOGO → slot → seed | ônibus sai do túnel, a Mirela vem até o jogador, a escolha de 3 criaturas abre; música toca |
| 2 | Pular abertura | partida nova, apertar P → "Pular" | a escolha da criatura abre do mesmo jeito |
| 3 | Primeira batalha | andar no mato alto até um encontro | dica da primeira batalha à esquerda; GOLPES tira vida com número de dano e som; a ficha mostra a linha SORTEIO |
| 4 | Captura | enfraquecer, CAPTURAR, escolher dispositivo | animação de lançamento e balanço; sucesso põe a criatura no bestiário com marca |
| 5 | Gerador visível | N → escolher criatura → E | aparecem seed, primários, a chance de cada derivado e a nota COERENTE ou ATÍPICA |
| 6 | Progressão e fim | vencer Dulce → Anselmo e Otávio → Mirela | cada vitória dá selo e gold; com 4 selos, tela de VITÓRIA com a coerência da seed contra o sorteio independente |
| 6b | Derrota | perder a equipe inteira | tela de DERROTA; "voltar ao último save" retoma o jogo sem fechar |
| 7 | Loja e exploração | comprar no Lauro; achar uma bolsa perdida | gold desconta; a bolsa paga uma vez e não volta depois de recarregar |
| 8 | Save | F5, fechar, CONTINUAR | volta na mesma posição, com equipe, bolsa e selos; na Web, depois de recarregar a aba |
| 9 | Reprodutibilidade | duas partidas com a mesma seed | mesmas criaturas no bestiário, na mesma ordem |
| 10 | Opções | ESC → opções → música e efeitos | o volume muda na hora; desligado fica em silêncio |

## Critérios de aceite da build

- Os cenários 0 a 8 passam no navegador (Chrome ou Firefox) e no Windows.
- Nenhum travamento nem tela preta. Queda de quadros só no carregamento.
- A suíte automatizada passa no commit publicado (CI verde).
- A página traz descrição, controles e capturas, e o QR Code do pôster abre a página.

## Riscos

| Risco | Impacto | Mitigação |
|---|---|---|
| Rede lenta no evento: a Web baixa 41 MB | demo demora a abrir | abrir a página antes; ter o `.exe` num pendrive |
| Navegador sem WebGL 2 | a Web não abre | Chrome ou Firefox atualizados; o `.exe` como reserva |
| Áudio bloqueado até o primeiro clique | a música não toca no menu | comportamento do navegador; toca após a primeira tecla |
| Windows avisa "editor desconhecido" | avaliador hesita | instrução na página: "Mais informações" → "Executar assim mesmo" |
| Save da Web some ao limpar dados do navegador | progresso perdido | avisar na página; a demo cabe em uma sessão |
| Duelo final difícil (27,7% para uma equipe mediana da IA) | quem joga pode desistir | itens, troca e vantagem de elemento ajudam; recalibrar depois do playtest |
| Seed com bestiário desfavorável | duelo mais difícil que o medido | os guardiões usam percentil de força; a dificuldade varia pouco entre seeds |
