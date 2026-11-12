# O que o Playbook pede do pôster e da apresentação

Fontes: `demoday/guia_poster.md`, `demoday/Avaliacao_Poster_DemoDay.md`, `calendario.md` e a
linha de Jogos Digitais do [Playbook](https://github.com/CatolicaSC-Portfolio/The-Portfolio-Playbook).

## Pôster

| Exigência | Estado |
|---|---|
| A0 (841 × 1189 mm), retrato, PDF digital | ✅ `poster.pdf` |
| Cabeçalho, rodapé e cores do template oficial | ✅ |
| Logo da Católica SC | ✅ do template; trocar por alta resolução para imprimir |
| Título | ✅ "TCC: Coerência Semântica" |
| Nome e e-mail do integrante | ⚠️ falta o e-mail institucional (`config.json`) |
| QR Code para a solução em produção | ⚠️ falta a URL do itch.io (`config.json`); o do repositório já está |
| Contexto e problema | ✅ Introdução |
| Solução proposta | ✅ faixa do mapa, "O que é coerência semântica", "Como as tabelas funcionam" |
| Arquitetura (diagrama) | ✅ 4 camadas e a seed |
| Referências | ✅ Hendrikx 2013, Togelius 2011, Shaker 2016, jogos analisados |
| Fonte de no mínimo 20 pt, Arial ou equivalente | ✅ |
| Mais imagem e diagrama que texto; autoexplicativo | ✅ |
| QR Code testado | ⚠️ testar no celular depois de preencher a URL |
| Impressão conferida em tamanho real | ⚠️ conferir um trecho impresso em A4 a 100% |

## Apresentação (critério 6 e nota da comunidade)

| O que avaliam | Como cobrir |
|---|---|
| Clareza e narrativa: problema, solução, resultados | roteiro de 3 minutos abaixo |
| Demonstração funcional em ambiente produtivo | a página do itch.io aberta; o `.exe` como reserva |
| Domínio técnico nas respostas | `docs/prova-de-autoria.md` e `docs/mudancas-estruturais.md` |
| Pôster autoexplicativo, QR funcional, identidade coerente | este pôster |
| Comunidade: originalidade e clareza (10%) | a comparação condicionado × independente, com as criaturas lado a lado |

## Habilitação (antes do evento)

| Item | Prazo | Estado |
|---|---|---|
| 5 orientações evidenciadas | 30/11/2026 | depende do autor |
| Prova de autoria aprovada | 30/11/2026 (2ª tentativa: 03/12) | preparação em `docs/prova-de-autoria.md` |
| Build pública | 30/11/2026 | pronta para enviar (`docs/publicacao/`) |
| Playtest com 10 pessoas e relatório | conforme o calendário | pendente |
| Visitar outra noite do evento e avaliar colegas | 10, 15 ou 16/12/2026 | requisito de aprovação |

## Roteiro de 3 minutos

1. **Problema (30 s).** Jogos geram mundos enormes, mas sem coerência: a cor e o corpo de uma
   criatura não têm relação com o que ela é. A academia resolve com busca, que é lenta.
2. **Ideia (40 s).** Apontar as criaturas da faixa: cada atributo sai de uma tabela de
   probabilidade condicionada ao elemento e ao animal. Mostrar a tabela de nadadeiras: peixe de
   água, 0,98; peixe de fogo, 0,77.
3. **Prova (40 s).** Os pares condicionado × independente e o gráfico de informação mútua: de
   32 a 156 vezes mais informação, 64 pares em toda seed, 100 criaturas em cerca de 2 ms.
4. **Jogo (50 s).** Abrir a build: uma batalha com a linha SORTEIO, o bestiário com E.
   O corpo decide a luta.
5. **Fechamento (20 s).** O que falta: a validação humana, com o teste cego no playtest.
