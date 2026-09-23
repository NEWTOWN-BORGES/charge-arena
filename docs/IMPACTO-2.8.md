# Charge Arena 2.8 — disparo e impacto

O disparo básico passa a ligar som, descarga e recuo ao mesmo evento que cria a bola. Há três variações por skin, com transiente seco, corpo grave, energia e uma cauda curta de arena. Os timbres anteriores das skins entram na composição; músicas e sons temáticos já existentes dos ultimates foram preservados.

## Jogar

- Disparo automático continua ligado por defeito.
- Em **Opções**, desligar **Disparo automático** mostra o botão **TIRO**. Tocar ou manter premido dispara quando a arma está pronta. No PC: rato ou Espaço. A cadência continua a ser a original.
- **Impacto da câmara**: desligado, suave ou completo.
- Vibração Android pode ser desligada; há volume próprio para efeitos sonoros.
- O último bloco produz um aviso breve de baliza aberta, sem parar o jogo.

## Implementação

- `arena_rules.gd`: acrescenta apenas metadados de impacto aos eventos existentes: superfície, direção, bloco e abertura da defesa. Não muda constantes, colisões ou dano.
- `indie_arena_view.gd`: recuo visual de 60 ms e recuperação de 150 ms; descarga curta; cauda ligada ao projétil; fragmentos direcionados; reação breve do bloco. Pool de até 80 pequenos fragmentos, dentro do orçamento de efeitos de cada perfil. Sem novas luzes dinâmicas no tiro básico.
- `main.gd`: 12 vozes reservadas aos tiros, 16 para os restantes efeitos. Os impactos não roubam vozes de disparo. Sons separados para acerto, destruição, metal, escudo e ricochete. O último bloco tem uma camada grave própria.
- Ultimates mantêm efeitos e sons individuais; recebem pequenos acentos temáticos. Sobrecarga, Rajada, Couraça e Sentinelas ganham uma voz adicional de ativação. A mistura baixa os efeitos secundários 4,5 dB nos últimos 180 ms de preparação e recupera suavemente depois da execução. Não baixa a música.
- Haptics limitados no tempo, com prioridade para eventos fortes. A vibração não repete em todos os fragmentos de uma explosão.
- O toque manual curto usa RPC fiável em PvP; movimento e disparo mantido conservam o transporte existente. O host continua a decidir se a arma pode disparar.
- `tools/compose_feedback.py`: gera os 46 WAVs de forma determinística, sem amostras de jogos externos; usa os timbres originais do próprio projeto.

## Verificação

- `test_feedback.gd`: eventos, recuo, imunidade dos blocos próprios, abertura da defesa e stress nos três perfis.
- `test_feedback_integration.gd`: toque curto, automático/manual, opções persistentes, vozes sobrepostas e redução temporária da mistura.
- `test_feedback_parity.gd`: 1.200 passos idênticos à simulação do commit anterior `6e08c74`.
- `test_feedback_network.gd`, host e cliente: um toque, um disparo, observado nos dois processos.
- `test_ultimates.gd` e `test_ultimate_sound.gd`: comportamento e identidades sonoras dos ultimates.
- Capturas em retrato/paisagem e opções; 46 ficheiros de áudio com pico máximo de −2,16 dBFS e início/fim em zero.

Os testes de áudio verificam os dados e a reprodução no motor. O computador de desenvolvimento está sem saída de áudio funcional; a avaliação auditiva, vibração real e desempenho no S23/A15 precisam do teste no aparelho. A GPU de desenvolvimento não serve como referência de desempenho Android. O PvP foi verificado em ligação local, sem simulação de perda de pacotes.

APKs Android: `2.8.0-impacto`, versionCode 51, assinaturas v2/v3 verificadas. A edição Teste instala em `org.chargearena.playtest`, separada da principal `org.chargearena.prototype`. Ambos incluem a permissão de vibração. Instalar a mesma versão nos dois aparelhos para PvP.
