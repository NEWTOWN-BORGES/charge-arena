# Charge Arena — protótipo Godot para mobile

Projeto 3D em Godot 4.7.1, renderizador Compatibility. Direção visual indie sci-fi: arena flutuante, jade/coral, cerâmica clara e pequenos pilotos robóticos. A arena foi ampliada sem aumentar as colisões dos pilotos, tijolos ou projéteis, e a câmara aproxima o cenário para tornar os acabamentos e efeitos mais legíveis no telemóvel. Modelos, materiais, interface, sons e música são criados por código; o vídeo e screenshots originais continuam intactos na pasta acima.

## Jogar

1. Importar `project.godot` no Godot.
2. Carregar em **F5** para executar o projeto completo.
3. Escolher **CAMPANHA** (níveis) ou **JOGO RÁPIDO** (arena original contra a IA).

O menu foi pensado para o polegar: fica encostado ao fundo do ecrã, com a leitura em cima e os botões em baixo — dificuldade da IA, **SKINS** / **OPÇÕES**, **PvP** / **NÍVEIS** / **JOGO RÁPIDO** e, por último e maior, **JOGAR NÍVEL X**.

**Carrossel de níveis.** Por trás do menu aparece a arena do nível escolhido, com o boss e os seus tijolos, o nome e o desafio por cima e pontos de página por baixo. Deslizar o dedo para a esquerda ou direita sobre a arena muda de nível (no PC: arrastar com o rato ou setas ← / →). Um toque, um arrasto curto ou vertical e deslizes sobre os botões não mudam o nível. O nome muda de imediato e a arena é reconstruída quando o dedo pára (cerca de 0,1 s num PC). O menu abre no primeiro nível ainda não vencido e volta ao último nível jogado. O PvP (criar sala ou entrar por IP) abre num painel próprio. Na vertical, os painéis de níveis e PvP também ficam junto ao fundo.

No PC: **A / D ou setas esquerda / direita** para deslocar o personagem ao longo do arco e mudar a direção do disparo. **O rato não aponta:** manter o botão esquerdo pressionado apenas dispara. Escape regressa ao menu. No telemóvel, em orientação vertical: arrastar o polegar esquerdo lateralmente para mover e manter o botão **Disparar** do lado direito pressionado. Não é necessário arrastar esse botão. Largar ou arrastar para fora dele interrompe o disparo. Os dois controlos aceitam toque simultâneo. W/S e deslocamento vertical do controlo esquerdo não permitem sair do arco. Em **OPÇÕES**, a sensibilidade do movimento tem cinco níveis, de Muito lenta a Muito rápida.

## Orientação vertical

No telemóvel o jogo fica bloqueado na vertical. A interface mantém todos os elementos da versão horizontal, reorganizados em coluna: cabeçalho com **OPÇÕES** e **MENU**; placar e modo de jogo; cartão do adversário junto à baliza de cima; arena a toda a largura; cartão do jogador junto à baliza de baixo (no cliente PvP os cartões trocam, porque joga na baliza de cima); controlos para os polegares no fundo, com o contador de FPS e o aviso de paralisia entre eles. As dicas que antes ficavam sob os cartões laterais passam para o lado direito de cada cartão. Contagem, golos e vitória aparecem centrados na arena. No menu, a arena surge por cima do painel.

A escala do conteúdo acompanha a forma do ecrã: 720 unidades no lado curto, `content_scale_size` 720×1280 na vertical e 1280×720 na horizontal. No PC a janela continua horizontal e o layout é o mesmo de antes; redimensionar a janela para vertical mostra a versão de telemóvel. A câmara mede a extensão real do estádio (faróis laterais incluídos) e enquadra-o na faixa entre os cartões. Em telemóveis com recorte de câmara, cabeçalho e rodapé descem/sobem pela área segura do ecrã.

## Música

Sete faixas originais, todas sintetizadas localmente sem samples nem licenças de terceiros. O menu mantém sempre *Aurora Drift*; ao iniciar a partida, a música passa suavemente para o tema da skin equipada.

| Faixa | Onde | Estilo | Duração |
| --- | --- | --- | --- |
| `audio/music_menu.ogg` — *Aurora Drift* | Menu | Ambiente sci-fi, Ré dórico, 84 BPM: pads, arpejo, sinos FM | 45,7 s, 16 compassos |
| `audio/music_match.ogg` — *Charge Circuit* | Piloto Aurora | Synthwave, baixo pulsado, arpejo e lead | 64 s, 32 compassos |
| `audio/music_skin_1.ogg` | Faroleiro | Electro luminoso completo: bateria firme, baixo pulsado, sinos e ecos de farol | 64 s, 32 compassos |
| `audio/music_skin_2.ogg` | Astrónomo | Tema espacial completo: ritmo em meio-tempo, baixo orbital, pads e arpejos panorâmicos | 64 s, 32 compassos |
| `audio/music_skin_3.ogg` | Jardineiro | Tema orgânico completo: groove leve, baixo sincopado e percussão melódica de madeira | 64 s, 32 compassos |
| `audio/music_skin_4.ogg` | Mineiro | Tema industrial completo: bateria pesada, baixo áspero e impactos metálicos | 64 s, 32 compassos |
| `audio/music_skin_5.ogg` | Sentinela | Tema cinematográfico completo: ritmo grave em meio-tempo, baixo profundo e metais de eclipse | 64 s, 32 compassos |

Cada tema de skin é uma composição independente, com bateria, baixo, harmonia, melodia e arranjo próprios; nenhum contém a gravação de *Charge Circuit* por baixo. Todos começam com uma harmonia aberta compatível com o final do menu e repetem sem corte. `scripts/music_player.gd` faz a transição suave de 1,4 s entre menu e tema da skin, baixa 5 dB durante a contagem e 9 dB nos golos e no fim, e pausa quando a app vai para segundo plano. Em **OPÇÕES** há **Música de fundo** e **Volume**, guardados em `user://audio_settings.cfg`.

Para alterar a música, editar o script e regenerar (precisa de numpy, scipy e ffmpeg com libvorbis). Os ficheiros `.import` já têm o loop ativo:

```text
python tools/compose_music.py
python tools/compose_skin_music.py
```

As faixas foram verificadas objetivamente quanto à duração, repetição, independência do áudio e volume uniforme de −17,1 LUFS. O volume relativo entre música e efeitos deve ser afinado de ouvido num aparelho real; o ajuste está em `BASE_DB` e `DUCK_DB` no início de `music_player.gd`.

## Campanha

Dez níveis PvE. Cada um tem arena, desafio e boss próprios; vencer desbloqueia o seguinte e o progresso fica em `user://campaign.cfg`. **Nesta versão de testes todos os níveis estão abertos** (`UNLOCK_ALL_FOR_TESTS = true` em `scripts/campaign.gd`); as vitórias continuam a ser guardadas, e pôr a constante a `false` repõe o desbloqueio nível a nível. O ecrã de níveis mostra o boss, o desafio, o estado (concluído / bloqueado) e o progresso. No início de cada nível a contagem mostra o nome e o desafio; no fim aparecem **PRÓXIMO NÍVEL**, **REPETIR NÍVEL** / **TENTAR DE NOVO** e **NÍVEIS**.

| Nível | Arena | Contorno | Tijolos | Desafio | Boss |
| --- | --- | --- | --- | --- | --- |
| 1 | Circuito Aurora | hexágono | bancos | dois deslizadores (a arena original) | Piloto Aurora |
| 2 | Baía do Farol | octógono | muralha | três pilares fixos no meio | Faroleiro |
| 3 | Estufa Suspensa | cintura estreita | arcos | dois vasos em órbita | Jardineiro |
| 4 | Observatório Lunar | hexágono | ilhas | três luas em órbita, sem aceleradores | Astrónomo |
| 5 | Mina Profunda | bojo largo | chevron | vagonetas verticais e barreira central | Mineiro |
| 6 | Santuário Eclipse | octógono | bancos | monólito central e duas luas | Sentinela |
| 7 | Farol da Tempestade | cintura estreita | ilhas | quatro defletores e deslizador rápido | Faroleiro |
| 8 | Jardim de Cristal | bojo largo | arcos | losango de pilares e dois deslizadores | Jardineiro |
| 9 | Veio Profundo | hexágono | muralha | barreira, duas órbitas e vagonetas, sem aceleradores | Mineiro |
| 10 | Coroa do Eclipse | octógono | chevron | monólito, três luas e defletores em V | Sentinela |

Com seis skins e dez níveis, quatro bosses repetem-se na segunda metade, com IA mais forte. O boss usa a skin e os tijolos do seu tema. A força do boss sobe de nível para nível (menos pausa entre disparos, mais velocidade, esquiva a partir do nível 3) e a dificuldade escolhida no menu desloca toda a curva: FÁCIL abranda cada boss, DIFÍCIL acelera-o.

**Mapas por dados.** `scripts/arena_rules.gd` guarda o mapa ativo (`map`): contorno, aceleradores, disposição dos tijolos, obstáculos (`fixed`, `slide` com eixo, `orbit`) e barreiras interiores (muros arredondados que gastam ricochete como uma parede). Balizas e arcos dos pilotos nunca mudam, por isso regras de golo, IA, guia de mira e rede são as mesmas. O mapa de omissão reproduz exatamente a arena original, usada no jogo rápido e no PvP. `scripts/campaign.gd` tem os dez níveis; a arena 3D é reconstruída só quando o mapa muda. Pilares fixos têm tampa dourada e obstáculos móveis tampa escura; deslizadores e órbitas mostram o percurso pintado no chão.

Todos os mapas são verificados em `tests/test_campaign.gd`: tijolos dentro das paredes e sem sobreposição, obstáculos que nunca tocam tijolos, arcos, balizas ou barreiras, e 12 s de jogo em cada mapa sem nenhuma bola a escapar. Capturas: `tests/capture_levels.gd` (as dez arenas) e `tests/capture_campaign_ui.gd` (menu, níveis, PvP, início e fim de nível).

## Skins

Destruir tijolos inimigos desbloqueia pilotos, um a cada 10 tijolos (valores de teste; a progressão prevista é 50, 100, …). Os tiros atravessam os tijolos aliados sem os danificar, por isso cada tijolo inimigo que cai conta para quem joga nesse aparelho (PvE, anfitrião ou cliente PvP). Ao atingir um limiar a meio da partida aparece **NOVA SKIN DESBLOQUEADA**. O progresso e a skin equipada ficam em `user://skins.cfg`.

Cada skin muda o piloto, a arma, as cores dos disparos **e os tijolos da sua equipa**.

| Tijolos | Skin | Arma | Tema dos tijolos | Cores |
| --- | --- | --- | --- | --- |
| 0 | **Piloto Aurora** | Manopla de energia | Baterias Aurora | cores da equipa |
| 10 | **Faroleiro** — cúpula com aro de latão, gema de farol, lanterna às costas | Lança-Farol | Farolins: torre creme, faixa da equipa, janela de luz, tampa de latão | luz e disparos azul-farol |
| 20 | **Astrónomo** — anéis orbitais a rodar, luneta, tubo de mapas | Sextante Estelar | Observatórios: bloco índigo, aro de latão, estrela em cada face | corpo índigo, disparos violeta |
| 30 | **Jardineiro** — cúpula de vidro com rebento, avental, vaso às costas | Semeador | Estufas: vaso de cerâmica vidrada com folhas | corpo musgo, disparos verde-folha |
| 40 | **Mineiro** — capacete de obra com lanterna, carga de cristais | Perfuradora de Cristal | Veios de cristal: pedra, cinta de aço, cristais rosa | corpo carvão, disparos magenta |
| 50 | **Sentinela** — capa de obsidiana, halo de eclipse dourado | Lança Eclipse | Monólitos Eclipse: obsidiana em plinto dourado, eclipse em cada face | corpo obsidiana, disparos pérola |

**Visualizador.** O botão **SKINS** abre um painel com o piloto em 3D num pedestal, junto de dois tijolos do tema em exposição (o segundo com uma vida perdida, mais pequeno e com uma luz apagada). Arrastar roda o pedestal, que volta a girar sozinho após 1,5 s; o piloto dispara de vez em quando para mostrar a cor do raio. Ao lado ficam nome, arma, tema dos tijolos, descrição, amostras de cor (corpo, luz, disparo), progresso e uma grelha de miniaturas para pré-visualizar qualquer skin — também as bloqueadas. **EQUIPAR** só fica ativo quando a skin está desbloqueada; caso contrário mostra quantos tijolos faltam.

**Legibilidade.** A aura e o rasto dos disparos usam a cor da skin, mas o brilho no chão por baixo de cada tiro, o anel aos pés do piloto, os braços e as três luzes de vida de cada tijolo mantêm a cor da equipa. Disparos acelerados continuam dourados com qualquer skin. No PvP cada jogador envia a skin ao ligar-se e o rival vê piloto, disparos e tijolos. A skin muda só o aspeto: colisões e regras são iguais.

**Desempenho.** Todos os temas usam o mesmo tamanho de tijolo. Trocar de skin reconstrói os 40 tijolos dessa equipa e reagrupa as peças; com duas equipas de temas diferentes os 80 tijolos continuam em 7–11 grupos de desenho.

**Acrescentar uma skin:** nova entrada em `CATALOG` (`scripts/skins.gd`: `weapon`, `bricks`, `unlock`, `body`, `light`, `shot`; cores vazias usam a cor da equipa), um ramo em `build_player` e outro em `make_brick` (`indie_arena_view.gd`; o piloto precisa dos nós `LegL`, `LegR`, `Gun/Flash`, o tijolo das luzes `HP0`–`HP2`) e um avatar em `portrait` (`game_hud.gd`). Capturas de controlo: `tests/capture_skins.gd` (pilotos e tijolos) e `tests/capture_skins_ui.gd` (visualizador e disparos).

## Gráficos e som

Abrir **GRÁFICOS E SOM** no menu, ou **OPÇÕES** durante a partida. Escolher o limite de **60, 90 ou 120 FPS**, a qualidade, VSync e o contador de **FPS reais**. As preferências são guardadas em `user://video_settings.cfg`. O padrão móvel é Leve / 60 FPS / VSync ligado. Instalações anteriores são migradas uma vez para este perfil, evitando que uma preferência antiga pesada continue ativa após a atualização. Escape fecha primeiro este painel. O PvE pausa enquanto as opções estão abertas; no PvP a partida continua, com o movimento e disparo locais libertados.

| Qualidade | Suavização dos contornos | Máximo de efeitos visuais |
| --- | --- | --- |
| Leve | Sem MSAA, iluminação plana, resolução 3D 68% | 20 |
| Equilibrado | MSAA 2×, resolução 3D 84% | 48 |
| Refinado | MSAA 4×, resolução 3D 100% | 96 |

No telemóvel, um controlador acompanha o desempenho durante a partida. Em **Refinado** e **Equilibrado**, conserva exatamente a resolução e os efeitos escolhidos e reduz apenas o alvo de 120 para 90 e depois 60 FPS quando necessário. Só o perfil **Leve**, destinado a aparelhos mais fracos, pode reduzir gradualmente a resolução 3D e recorrer a 45/30 FPS. A interface permanece à resolução nativa. A simulação continua a 60 passos por segundo; o desenho interpola personagens, obstáculos e projéteis entre esses passos. No cliente PvP, a interpolação usa as duas últimas atualizações recebidas (intervalo nominal de 50 ms).

## Ajuda de jogabilidade

Em **OPÇÕES** também se escolhe a dificuldade da IA — Fácil, Normal ou Difícil —, ativa-se o guia de mira e regula-se a sensibilidade do joystick entre cinco níveis. O guia desenha a trajetória prevista, incluindo ricochetes, e marca o tijolo, jogador ou baliza que será atingido. A mira e a IA usam a mesma simulação de trajetória. A curva suave continua a permitir pequenos ajustes; a sensibilidade muda a velocidade resultante sem alterar o arco.

Os sons das seis armas usam canais simultâneos: disparos, ricochetes e impactos podem sobrepor-se sem cortar a cauda do som anterior. O acelerador tem um sinal ascendente próprio, diferente do clique de ricochete, e também é detetado no cliente PvP.

Referências técnicas: [antialiasing do Godot](https://docs.godotengine.org/en/4.6/tutorials/3d/3d_antialiasing.html) e [limite de FPS e taxa da simulação](https://docs.godotengine.org/en/stable/classes/class_engine.html#class-engine-property-max-fps). Esta versão Compatibility usa MSAA; não depende de TAA ou de efeitos exclusivos do Forward+.

## Regras desta versão

- Mapa hexagonal baseado em `Drawing3-Layout1.pdf`, com uma baliza em cada ponta e quatro grupos de tijolos nas paredes inclinadas.
- Cada personagem desloca-se exclusivamente no seu arco, à frente da respetiva baliza. A orientação é determinada pela posição no arco: dispara sempre em frente. Jogador, IA e cliente PvP obedecem à mesma regra.
- Cada piloto tem uma barra de **5 vidas**. Cada bola inimiga retira uma vida; ao chegar a zero, o piloto fica paralisado durante **0,5 segundo** e recupera as cinco vidas ao voltar. Os próprios projéteis nunca atingem o atirador, mesmo depois de ricochetes.
- Dois obstáculos circulares atravessam a região central na horizontal, em pistas separadas e sentidos opostos. Cada contacto reflete a bola e acrescenta **+1 ricochete disponível**, sem gastar os que já tinha. Mesmo uma bola sem ricochetes disponíveis pode receber outro ao atingir um obstáculo. A colisão considera o movimento do obstáculo durante o frame para evitar atravessamentos.
- A bola começa com **1 ricochete disponível**. Paredes, escudos e aceleradores gastam um por contacto; sem nenhum disponível, a bola desaparece ao tocá-los. Os extras dos obstáculos acumulam, mas a bola continua limitada a 4 segundos de existência. Desaparece também ao acertar num tijolo ou personagem.
- Os arcos dourados nas paredes laterais são aceleradores: refletem a bola, reproduzem um som de carga próprio, aumentam a velocidade para **1,65×** e o dano para **2**. Cada contacto gasta um ricochete disponível; velocidade e dano não se multiplicam com boosts sucessivos.
- Os próprios tijolos são imunes e transparentes aos disparos da sua equipa: a bola atravessa-os e pode continuar até uma parede, obstáculo ou alvo inimigo. Esta regra aplica-se igualmente ao jogador, à IA e ao PvP.
- Cada tijolo tem **3 vidas**. Um disparo normal tira 1 vida e um acelerado tira 2. O tamanho e a colisão diminuem de 100% para 76% e depois 52%; com zero vidas, o tijolo desaparece. As três marcas no topo mostram as vidas restantes.
- Existem 20 tijolos em cada grupo (filas de 6, 5, 4, 3 e 2), totalizando 40 por jogador. Destruir os dois grupos adversários desbloqueia a baliza. Enquanto há tijolos, um escudo de energia protege a entrada.
- A baliza aberta fica verde; acertar dentro dela marca um golo.
- Após um golo, os tijolos e posições são repostos, preservando o placar. Vence o primeiro a 3 golos.
- O atirador fica protegido do próprio projétil durante toda a trajetória.
- A IA procura posições no arco que permitam atingir os tijolos adversários, favorecendo destruir os mais frágeis e aproveitar o dano dos boosts. Prevê colisões e movimento dos obstáculos, verifica novamente a trajetória antes de disparar e procura marcar quando a baliza abre. Evita tiros sem objetivo e desvia-se de ameaças próximas; a previsão não conhece decisões futuras do adversário. A pesquisa é repartida por vários frames.

**Valores ajustáveis:** 5 vidas por piloto, paralisia de 0,5 s, velocidade do boost 1,65×, 20 tijolos por grupo, todos os tijolos necessários para desbloquear a baliza e limite de 3 golos. O PDF não inclui cotas; as dimensões e o comprimento dos arcos foram adaptados para manter o mapa legível no ecrã. Constantes principais em `scripts/arena_rules.gd`: `PLAYER_LIVES`, `TRACK_RADIUS`, `TRACK_LIMIT`, `FACING_FACTOR`, `OBSTACLE_RADIUS`, `OBSTACLE_TRAVEL`, `OBSTACLE_FREQUENCY`, `BRICK_ROWS`, `BRICK_LIVES`, `BOOST_SPEED`, `BOOST_DAMAGE`, `STUN_SECONDS` e `WIN_SCORE`.

## PvP por ligação direta

Nos dois dispositivos, executar a mesma versão. Um escolhe **Criar partida** e passa o IP apresentado ao outro. O segundo introduz esse IP e escolhe **Entrar**. O anfitrião controla a simulação; o cliente envia apenas movimento e disparo. As regras e o placar são sincronizados. Ao sair um jogador, a partida termina com uma mensagem.

A porta utilizada é UDP **27940**. Na mesma rede Wi-Fi, o router precisa de permitir comunicação entre os dispositivos e a firewall do anfitrião precisa de permitir o Godot. Pela internet é necessário um anfitrião acessível; este projeto **ainda não inclui servidor público, matchmaking, relay, contas ou salas por código**. Não foram alteradas regras de firewall nem configurações do router.

## Android

Preset **Android** com `arm64-v8a` (aparelhos reais) e `x86_64` (emulador), orientação vertical e permissão de internet. A saída é `builds/charge-arena.apk`.

O ambiente já está preparado: templates de exportação 4.7.1, caminhos do SDK e do JDK nas definições do editor, e keystore de depuração em `%APPDATA%/Godot/keystores/debug.keystore`.

Gerar o APK:

```text
godot --headless --path . --export-debug "Android" builds/charge-arena.apk
```

Instalar e correr num telemóvel ligado por USB, com **Depuração USB** ativa nas Opções de programador:

```text
adb devices
adb install -r builds/charge-arena.apk
adb logcat -s godot
```

O APK foi gerado, instalado e lançado no emulador: o motor arranca, cria contexto OpenGL ES 3.0 e entra no ciclo principal sem erros de script. **Falta a validação num aparelho real**: desempenho, áudio, multitouch, recortes do ecrã e comportamento ao suspender a aplicação.

Notas sobre o emulador: com `-gpu host` o jogo desenha na janela do emulador, mas `adb exec-out screencap` devolve preto porque não captura a SurfaceView; com `-gpu swiftshader_indirect` a captura funciona mas os shaders não compilam (`GL_MAX_FRAGMENT_UNIFORM_VECTORS` insuficiente). Para prova visual, usar um aparelho real.

iOS requer a sua própria configuração e ferramentas de exportação, e um Mac.

## Testes

Teste determinístico de regras:

```text
godot --headless --path . --script res://tests/test_rules.gd
godot --headless --path . --script res://tests/test_touch.gd
godot --headless --path . --script res://tests/test_map_view.gd
godot --headless --path . --script res://tests/test_forward_obstacles.gd
godot --headless --path . --script res://tests/test_tactical_ai.gd
godot --headless --path . --script res://tests/test_video.gd
godot --headless --path . --script res://tests/test_mobile_input.gd
godot --headless --path . --script res://tests/test_portrait.gd
godot --headless --path . --script res://tests/test_music.gd
godot --headless --path . --script res://tests/test_skins.gd
godot --headless --path . --script res://tests/test_gameplay_aids.gd
godot --headless --path . --script res://tests/test_campaign.gd
```

Validação gráfica das instâncias e captura com medição dos perfis (precisa de GPU; omitir `--headless`):

```text
godot --path . --audio-driver Dummy --script res://tests/test_video.gd
godot --path . --audio-driver Dummy --script res://tests/test_polish_visual.gd
godot --path . --audio-driver Dummy --script res://tests/test_portrait_visual.gd
```

Teste de rede em dois processos: iniciar o anfitrião, depois o cliente (antes de 12 s):

```text
godot --headless --path . --script res://tests/test_network.gd -- --host
godot --headless --path . --script res://tests/test_network.gd -- --client
```

## Ficheiros

- `scripts/arena_rules.gd`: movimento, tiros, colisões contínuas, paralisia, tijolos, golos e IA.
- `scripts/indie_arena_view.gd`: arena com bordas chanfradas, personagens articulados, animações e efeitos 3D procedurais.
- `shaders/`: chão pintado, sombras suaves, balizas de energia e fundo atmosférico.
- `scripts/game_hud.gd`: menus, placar, controlos de toque e layouts horizontal/vertical.
- `scripts/main.gd`: execução, efeitos sonoros, escala do ecrã, enquadramento da câmara e ligação ENet.
- `scripts/music_player.gd`: música de fundo, transições, atenuação e preferências de som.
- `scripts/skins.gd`: catálogo de skins, contagem de tijolos destruídos e progresso guardado.
- `scripts/game_settings.gd`: dificuldade, guia de mira e sensibilidade do joystick.
- `scripts/campaign.gd`: os dez níveis (mapa, desafio, boss, força da IA) e o progresso guardado.
- `scripts/video_settings.gd`: limites de FPS, qualidade, VSync e preferências locais.
- `audio/`: música do menu, seis temas de partida e efeitos de armas.
- `tools/compose_music.py` e `tools/compose_skin_music.py`: composição e mistura da música (excluídos do APK).
- `tests/`: testes de regras e comunicação entre anfitrião e cliente.

Poderes especiais e personagens finais do vídeo ainda não fazem parte deste protótipo. O objetivo é validar o ciclo de movimentar-se para apontar, disparar, paralisar, abrir a baliza e marcar.

## Visual indie — mapa hexagonal / revisão 06

- Plataforma hexagonal com bordas chanfradas, grelhas, faróis flutuantes e detalhes em latão.
- Chão com linhas pintadas, arcos das balizas, textura subtil e sombreamento consistente, sem o artefacto quadriculado da primeira versão.
- Pilotos Nova e Ember com capacete arredondado, viseira, olhos, mochila, movimento das pernas e recuo da arma.
- Quatro grupos de tijolos em forma de baterias que encolhem, balizas curvas com energia animada, arcos de movimento visíveis e dois aceleradores laterais dourados. Disparos acelerados ganham uma aura maior e um rasto dourado.
- Dois obstáculos circulares de cerâmica com anéis luminosos, deslocamento horizontal e pistas discretas desenhadas no chão. O controlo direito é agora um botão de disparo, em vez de um joystick para apontar.
- Fragmentos na destruição, faíscas no ricochete, estrelas de paralisia e efeitos de golo.
- Interface com retratos que reagem à paralisia, contagem de defesas e controlos de toque na mesma paleta.
- Cerâmica com brilho suave, latão com acabamento metálico, iluminação quente/fria equilibrada, capacetes mais redondos e sombras de contacto sob os tijolos.
- Arcos e aceleradores são superfícies contínuas, sem junções entre pequenos blocos. As linhas do chão usam suavização pela dimensão do píxel; a textura e as linhas animadas dos escudos foram ajustadas para reduzir cintilação.
- Renderizador Compatibility, materiais e geometria reutilizados. A arquitetura opaca foi agrupada em 19 conjuntos e as 560 peças dos tijolos em 7 MultiMeshes. Tijolos só atualizam as transformações quando perdem vidas ou são repostos. Partículas pequenas usam menos geometria; o HUD atualiza a 30 Hz e reutiliza estilos.
- Sem MSAA/MSAA 2×/MSAA 4× e limites de efeitos configuráveis. Movimento visual interpolado sem alterar a velocidade da partida. Refinado preserva os gráficos completos durante o ajuste automático de FPS.

O protocolo de rede desta revisão sincroniza as posições em arco, orientação fixa, obstáculos móveis, projéteis acelerados e vidas dos 80 tijolos. O estado usa vetores numéricos compactos sem executar compressão DEFLATE na thread principal a cada atualização, reduzindo picos de CPU durante o PvP. O cliente envia apenas movimento e disparo; não pode enviar uma direção de mira. As posições dos tijolos são reconstruídas de forma determinística; apenas as vidas são enviadas, mantendo os pacotes pequenos. Usar esta mesma versão nos dois dispositivos. O ficheiro `scripts/arena_view.gd` contém apenas o visual antigo, mantido como referência; o projeto executa `indie_arena_view.gd`.

## Verificação realizada

- 40 verificações das regras passaram, incluindo movimento em arco, os dois aceleradores, dano 1/2, colisão com tijolos rodados e encolhidos, balizas e reposição de rondas.
- 19 verificações de orientação fixa, colisão com obstáculos móveis, imunidade ao próprio disparo e entrada do rato passaram.
- 20 verificações de IA por objetivos, proteção dos tijolos aliados, ricochetes adicionais, previsão sem alterar o estado e desvio de ameaças. A simulação de 90 segundos mede os disparos, acertos nos tijolos e golos; também é testada uma baliza já aberta.
- 7 verificações de eventos de toque passaram, incluindo mover e disparar simultaneamente e disparar imediatamente ao tocar no botão.
- 7 verificações dos modelos passaram, incluindo encolhimento, marcas de vidas, aura do boost, escudo aberto e reposição dos tijolos.
- 22 verificações de vídeo passaram com renderização gráfica: nove combinações de qualidade/FPS, persistência, valores inválidos, controlos, pausa PvE, interpolação e encolhimento/destruição/reposição dos MultiMeshes. Em modo headless executam-se 19; as três leituras de transformações na GPU exigem o renderizador gráfico, pois o renderizador dummy devolve matrizes identidade.
- Duas instâncias em localhost ligaram-se por ENet e confirmaram disparos, projéteis acelerados, ricochetes adicionais, movimento em arco, orientação fixa, obstáculos móveis, vidas e tamanhos dos tijolos nos dois lados. Isto não equivale a testar dois telemóveis ou uma ligação pela internet.
- Menu, painel de vídeo e partida foram renderizados e revistos. Capturas atuais em `preview-menu-r06.png`, `preview-settings-r06.png`, `preview-gameplay-r06.png` (1280 × 720) e `preview-mobile-r06.png` (1200 × 554).
- Ensaio local na NVIDIA GeForce 210, a 1200 × 554, VSync desligado, três segundos por perfil após aquecimento: Leve/limite 60 = **25,9 FPS**, Equilibrado/limite 90 = **19,7 FPS**, Refinado/limite 120 = **12,8 FPS**; cerca de 389–394 chamadas de desenho por frame para a cena completa e interface. É uma medição curta neste PC, não um benchmark de telemóvel. Não foram atingidos nem validados 60/90/120 FPS reais neste hardware. Log em `polish-visual.log`.
- O dispositivo de áudio do ambiente de teste estava indisponível; a verificação visual utilizou o driver Dummy. Sons sintetizados incluídos, mas a reprodução audível ainda precisa de verificação.
