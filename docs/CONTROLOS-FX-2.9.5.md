# 2.9.5 — Controlos e efeitos

## Controlos restaurados

Opções abre no início, com uma escolha única: Automático, Botão separado, No próprio joystick. A escolha atualiza as preferências antigas sem migração destrutiva. Tamanho e posição do botão separado continuam configuráveis, com pré-visualização em tempo real (esquema do ecrã e vista ampliada do botão), seguidos da sensibilidade. No joystick, manter o dedo dispara e largar interrompe; tocar nos poderes não dispara.

## Picos de efeitos

A criação de CPUParticles3D não respeitava o limite geral em todos os chamadores. Sob uma rajada, continuava a alocar nós e recursos além do orçamento. As luzes temporárias também eram criadas/libertadas constantemente. Agora há 48 emissores e oito luzes reutilizáveis preparados durante a construção da arena, com limites simultâneos por perfil (16/32/48 emissores e 2/4/8 luzes). Não se altera a qualidade selecionada, resolução ou antialiasing.

Efeitos expirados voltam à reserva; remoção por índice reverso evita pesquisas/reorganizações repetidas. Tarefas visuais atrasadas executam até quatro por frame, em vez de todas após um frame lento. Isto só afeta a apresentação: poderes, dano, duração e física mantêm-se iguais.

Teste sintético de 300 pedidos de emissão/luz, headless no PC: versão anterior 356 nós novos e 12 099 µs; nova zero nós novos e 3 475 µs, 56 efeitos ativos. É uma medição pontual de criação no CPU, não FPS Android nem garantia de ausência de travamentos em todos os dispositivos.

## Verificação

- Testes dos três modos: toque, libertação, botão independente e persistência.
- Saturação e devolução dos recursos, execução completa da fila e preservação da qualidade.
- Regressões touch/feedback e paridade de 1 200 ticks com 2.9.4. O teste antigo usava física anterior às correções das paredes; a referência passa para 3bd4bb1.
- Execução gráfica de raio solar, meteoros, trovão, florescimento e pilhagem; captura das opções em retrato.
- APKs código 58, pacotes e ícones preservados: LABS Sentinela; Alfa Arconte. Sem ensaio físico em Android nesta sessão.
