# Charge Arena 3.2 — Gun feel / feedback de combate

Esta passagem mexe só na **apresentação** dos tiros: imagem, câmara, som, vibração e HUD.
Dano, cadência, velocidade dos projéteis, equilíbrio e ultimates ficam exatamente como estavam.
Há um teste que o confirma: `tests/test_gun_feel.gd` corre duas simulações idênticas, uma
com toda a apresentação ligada e outra sem nada, e exige que o estado final seja igual.

## 0. Mapa do fluxo (levantamento)

| Etapa | Onde | Natureza |
|---|---|---|
| **INPUT** | `game_hud._input` (toque no botão/joystick), `main._unhandled_input` (rato), `main._unhandled_key_input` (espaço). Cada toque soma 1 a `fire_tap` / `pending_clicks`. | local |
| **FIRE REQUEST** | `main.local_command()` no tick de física (60 Hz): os toques vão para a fila (`queue_shot`, até 10) e sai um por recarga (`take_queued_shot` + `rules.can_fire`). No PvP o convidado envia `submit_fire_tap` ao anfitrião. | determinístico (anfitrião) |
| **SPAWN** | `arena_rules.shoot()` → `spawn_ball()` + evento `shot`. | determinístico |
| **TRAVEL** | `arena_rules.step()` move as balas; a arena interpola a posição desenhada. | determinístico / visual |
| **COLLISION** | `arena_rules` (tijolo, obstáculo, parede, booster, piloto, baliza) → eventos `bounce`, `spent`, `boost`, `player_hit`, `brick_hit`, `brick`, `goal`, agora com a **normal** da colisão. | determinístico |
| **DAMAGE** | `arena_rules.damage_brick()` → `brick_hit` / `brick` (+ `defense_open` no último tijolo). | determinístico |
| **DESTRUCTION** | evento `brick` → `CombatFeel.brick_destroyed`. | apresentação |
| **GOAL** | fase `goal`/`finished` → `CombatFeel.goal_scored`. | apresentação |

Tudo o que é determinístico corre no anfitrião (ou no PvE local). O convidado só recebe
estado e eventos e **apresenta**. A apresentação nunca é lida pelas regras.

### Latência (medida no jogo)

O painel de afinação mostra o último tiro manual: **toque→tiro**, **tiro→imagem**,
**toque→imagem** e a **saída de áudio** do dispositivo.

- toque→tiro: no máximo 1 tick de física (0–16,7 ms a 60 Hz). Se a arma estiver a recarregar,
  o tiro sai quando a recarga acaba (a fila guarda-o).
- tiro→imagem: o tiro é desenhado no mesmo frame em que é criado (a física corre antes do desenho).
- som: arranca no mesmo frame; acrescenta-se o buffer de saída do telemóvel (`AudioServer.get_output_latency`).
- **PvP (antes)**: o convidado só via o seu próprio tiro depois da ida e volta à rede (RTT + até 50 ms do snapshot).
  **Agora**: o convidado conta o toque de imediato (arma, clarão, som e vibração) quando a sua arma
  está pronta. O anfitrião continua a decidir; quando o tiro dele chega, é reconhecido e não é contado duas vezes.
  Um toque recusado (piloto atordoado, fora de jogo) é esquecido ao fim de 0,7 s.

## 1. Sistemas alterados (antes → depois)

| Sistema | Antes | Depois |
|---|---|---|
| Arquitetura | `main.play_events` chamava arena, som e vibração um a um | Evento central em `scripts/combat_feel.gd`: `weapon_fired`, `projectile_impact`, `brick_destroyed`, `goal_scored`. Imagem, câmara, som, vibração e HUD são ouvintes separados. |
| Recuo | seno de 60 ms + regresso de 150 ms, só a arma | Curva **snap→hold→return→settle**: 92 % do coice nos primeiros 30 % da subida, pico aos 65 ms, regresso de 150 ms com ligeira ultrapassagem, assentamento em 70 ms. A arma **e o piloto** (inclinação dos ombros e peso para trás) reagem; a posição de jogo não se mexe. |
| Clarão do cano | esfera a encolher em 55 ms | 3 frames com forma e direção: núcleo branco, cone ao longo do cano e leque de duas lâminas que roda aleatoriamente a cada tiro; cada frame mais pequeno e mais comprido. |
| Luz do disparo | luz real 70 ms (só Refinado no PC) | Poça de luz aditiva no chão (1 quad, com pool), 30–70 ms, em Equilibrado e Refinado, também no telemóvel. Luz real só no PC em Refinado. Desligada em Leve e com Efeitos reduzidos. |
| Som do tiro | 1 amostra da skin | Camadas: **TAP** (transiente do gatilho, só no próprio tiro) + corpo/energia/cauda da amostra da skin + **FSHH** (o projétil a sair). Variação de tom ±2,5 % para não cansar o ouvido. A metralhadora mantém a sua voz. |
| Projétil | núcleo + halo + rasto | Mesmo núcleo, halo e rasto, mais: rasto esticado nos primeiros 70 ms (velocidade percebida sem mudar a velocidade real), comprimento afinável, **brasa residual** onde acaba, e pool de projéteis (sem criar nós a cada tiro). |
| Impactos | mesmas lascas douradas em todo o lado | Linguagem de material e direção (normal + velocidade): tijolo **THOCK** (lascas para trás e confirmação discreta), metal **TANG** (faíscas finas ao longo do ricochete), escudo **BWOM** (ondulação dupla), parede seca (uma faísca e pó). O ricochete é o que se conta menos — não é recompensado como perícia. |
| Confirmação de acerto | tremor do tijolo | Tremor + casca pálida por cima do tijolo durante 3 frames. |
| Dano do tijolo | encolhe e apaga luzes de vida | Também ganha **fissuras**: finas ao primeiro acerto, rachado ao segundo. Desenhadas no mesmo lote (MultiMesh) do tijolo, sem custo de draw. |
| Destruição | lascas + som de quebra | **THOCK → CRACK**: pancada grave e, 28 ms depois, a quebra; pedaços que seguem a direção do tiro, luz no chão, pó; **micro-pausa** visual de 28 ms quando és tu a partir. |
| Último tijolo | anel + som | Sequência de abertura da baliza: CRACK → pausa de 50 ms → pulso na baliza → o escudo cede em rampa (não desliga de repente) → som grave de porta. |
| Golo | abanão forte + 5 explosões | O momento maior (≈1 s): pausa de 90 ms, efeitos em câmara lenta (35 %) durante 0,4 s, luz sobre a baliza, 3 ondas, chuva de faíscas, câmara empurrada para a baliza, mistura em ducking. Sem estroboscópio. |
| Câmara | um só abanão escalar | **Camadas**: cada momento acrescenta a sua camada com intensidade, duração, frequência, queda e direção (empurrão ao longo do evento + oscilação). Os poderes e ultimates mantêm o abanão de antes. |
| Vibração | durações soltas no código | Categorias **FIRE, DESTROY, LAST BRICK, POWER, ULTIMATE, GOAL** (tabela em `combat_feel.gd`). |
| Botão de tiro | 93→100 % ao tocar | **100 → 94 % sob o polegar → 103 % no instante em que o tiro sai → 100 %**; anel de recarga + pulso de "pronto". No modo joystick, a base do joystick faz o mesmo. |
| Poderes | clarão + som | Antecipação (o chão acende sob o piloto ao pedir) → ativação → efeito → dissipação (partículas que sobem e desaparecem). |
| Ultimates | — | **Não foram redesenhadas**: mesmos efeitos e sons; ganham só ducking de 180 ms na mistura. |
| Mistura | 3 prioridades | Hierarquia **ambiente < ricochete < tiro < impacto < destruição < poder < ultimate < golo** (níveis 0–7), roubo de vozes por nível e ducking por evento. |

## 2. Hierarquia (níveis 1–7)

| Nível | Momento | Som | Câmara | Vibração | Micro-pausa |
|---|---|---|---|---|---|
| 1 | ricochete | −23 dB | — | — | — |
| 2 | tiro | −17,5 dB (+TAP, FSHH) | 0,022 (push) | FIRE 9 ms | — |
| 3 | acerto no tijolo | −18 dB | 0,02 | — | — |
| 4 | tijolo destruído | −18 dB (THOCK+CRACK) | 0,075 | DESTROY 16 ms | 28 ms |
| 5 | poder | −18 dB | abanão original | POWER 22 ms | — |
| 6 | ultimate / último tijolo | −14 / −18 dB | original / 0,15 | ULTIMATE 42 ms / 30 ms | — / 50 ms |
| 7 | golo | −14 dB | 0,42 | GOAL 70 ms | 90 ms + câmara lenta |

Ducking: destruição baixa ricochetes 2 dB (80 ms); último tijolo baixa até ao nível 4 em 5 dB (250 ms);
ultimate baixa até ao nível 5 em 4,5 dB (180 ms); golo baixa tudo o resto 8 dB (1,1 s).

## 3. Parâmetros afináveis

Opções → **AFINAÇÃO DOS TIROS · DEBUG**. Aplicam-se na hora e guardam-se ao fechar (`user://combat_feel.cfg`).

| Parâmetro | Omissão | Intervalo |
|---|---|---|
| `fire_recoil_strength` | 1.0 | 0–2 |
| `fire_recoil_duration` (pico) | 65 ms | 30–120 ms |
| `fire_return_duration` | 150 ms | 80–300 ms |
| `camera_fire_strength` | 1.0 | 0–3 |
| `camera_destroy_strength` | 1.0 | 0–3 |
| `camera_goal_strength` | 1.0 | 0–2 |
| `haptic_fire_strength` | 0.14 | 0–0.5 |
| `trail_length` | 1.0 | 0.3–2 |
| `impact_particle_amount` | 1.0 | 0–2 |
| `destruction_particle_amount` | 1.0 | 0–2 |
| `audio_pitch_variation` | ±2,5 % | 0–8 % |
| `muzzle_flash_duration` | 50 ms | 20–100 ms |
| `light_flash_duration` | 50 ms | 0–80 ms |
| `hitstop_destroy` | 28 ms | 0–60 ms |
| `hitstop_last_brick` | 50 ms | 0–100 ms |
| `hitstop_goal` | 90 ms | 0–200 ms |

O botão **CAMPO DE TESTE** abre uma partida com o rival parado, para disparar, acertar, partir e marcar enquanto se afina.
Se alguma micro-pausa parecer má, basta pô-la a 0.

## 4. Qualidade gráfica

- **Leve**: recuo, clarão, faíscas, fissuras, THOCK→CRACK e câmara ficam; sem luz no chão, sem luzes reais, menos partículas. FIRE → IMPACT → DESTROY continua legível.
- **Equilibrado**: tudo, com luz no chão (sem luzes reais).
- **Refinado**: tudo; no PC também a luz real de 50 ms no cano.

## 5. Acessibilidade

- **Impacto da câmara**: Desligado / Suave / Completo (já existia; agora governa todas as camadas).
- **Vibração**: ligada/desligada (já existia; agora por categorias).
- **Efeitos de combate**: Completos / Reduzidos (novo) — metade das partículas, sem luz de disparo, sem micro-pausas nem câmara lenta.
- Sem estroboscópio: nenhum clarão ocupa o ecrã inteiro nem pisca repetidamente.

## 6. Desempenho

- Luz no chão: pool de 16 quads (aditivos, sem escrita de profundidade); nada de luzes reais no telemóvel.
- Projéteis reutilizados (pool por equipa) em vez de criar e libertar nós a cada tiro.
- Faíscas e pedaços usam o pool de 80 lascas que já existia; tudo respeita `effect_limit`.
- Fissuras dentro do MultiMesh dos tijolos: zero draws extra por tijolo.
- O material aditivo é pré-compilado no aquecimento de shaders (`warm_shaders`), para não haver soluço no primeiro tiro.
- Camadas de câmara: no máximo 8 em simultâneo.

## 7. Assets

Nenhum ficheiro novo: o TAP, o FSHH, o THOCK e o som da porta da baliza são sintetizados no arranque
(menos de 1 ms). Se no futuro houver gravações próprias, substituem `tones["shot_tap"]`, `shot_air`,
`thud` e `goal_open` em `main.build_audio()`. Nada foi copiado de Destiny, Marathon ou outro jogo.

## 8. Regressões possíveis e onde afinar

- **Micro-pausas** podem parecer "engasgos" num telemóvel lento → `hitstop_*` a 0.
- **Câmara** demasiado viva → `camera_*_strength` ou Impacto da câmara "Suave".
- **FSHH** cansativo em rajadas longas → baixar o ganho em `main.fire_audio()` (−12 dB) ou `audio_pitch_variation`.
- **Previsão no PvP**: se o anfitrião recusar um toque, o convidado já viu o clarão. É raro (só com o piloto atordoado) e é o compromisso habitual.
- As fissuras só se veem na tampa dos tijolos; em temas de tijolo com tampa mais alta ficam escondidas (sem erro).

## 9. Testes

- `tests/test_gun_feel.gd` — curva de recuo (pico 50–80 ms, regresso 120–180 ms), hierarquia, categorias de vibração,
  parâmetros (limites e gravação), evento central (um anúncio por tiro, local ou não), botão 100→94→103→100,
  anel de recarga, **simulação idêntica com e sem apresentação**, micro-pausa só visual, câmara por camadas
  (e Desligado), Leve/Reduzidos sem luz, fissuras no lote, ducking do golo e previsão do convidado.
- `tests/capture_gun_feel.gd` — capturas do tiro, da destruição e das fissuras.
- Atualizados: `test_feedback.gd` (nova curva), `test_feedback_integration.gd` (camadas de som).
