# Sentinela LAB — 2.9

APK: `builds/charge-arena-2.9.0-sentinela-lab.apk`.

Esta edição instala como **Sentinela LAB**, com o avatar original do Sentinela no ícone. O pacote `org.chargearena.sentinellab` tem armazenamento Android separado de `org.chargearena.prototype` e `org.chargearena.playtest`. Não é necessário desinstalar nenhum deles; o LAB não lê nem altera os seus saves.

O preset **Android Laboratorio** ativa a feature `open_test`, que abre todas as skins, poderes e arenas. O Sentinela é a skin inicial numa instalação nova. A história continua a progredir normalmente: não são inventadas vitórias ou bosses derrotados. As habilidades conservam as suas cargas e recargas de combate.

## Controlos

Em **Opções**, desligar **Disparo automático** e escolher **Tiro manual**:

- **No joystick**: manter o dedo para disparar e arrastar para apontar; soltar interrompe o disparo.
- **Botão separado**: ajustar tamanho entre 70% e 150%, posição horizontal e vertical. As escolhas ficam guardadas neste aparelho.

## Vibração

Além dos impulsos ao disparar, destruir, ativar poderes e marcar golo:

- Laser: vibração suave sustentada por pulsos sobrepostos durante o feixe.
- Coroa Solar: vibração sustentada mais forte.
- Singularidade, Sobrecarga e disparo rápido: pulsações distintas.
- Meteoros, trovões e rajadas: impulsos nos eventos de execução/impacto.

Pausar, perder o foco ou desligar a vibração interrompe o motor. Efeitos do adversário não ativam os padrões sustentados do jogador. O comportamento depende do motor e das opções de vibração do Android.

## Validação

`test_open_lab.gd` verifica os desbloqueios, a separação dos pacotes e a ausência de vitórias artificiais. `test_feedback_integration.gd` cobre disparo no joystick, soltar, mover/apontar simultaneamente, posição/tamanho persistentes e seleção/fim dos padrões hápticos. O APK contém `open_test` e o ícone foi extraído e inspecionado. A intensidade física da vibração precisa de teste no dispositivo.
