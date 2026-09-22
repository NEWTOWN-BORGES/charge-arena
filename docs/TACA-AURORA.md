## Atualização 2.3.2 — música original dos bosses

Repostas as dez gravações de `5324840`, sem recomposição nem recodificação. Única alteração sonora: +1,25 dB de ganho na reprodução dos temas de bosses/skins. Menu e skin padrão inalterados. A pré-escuta do hangar mantém-se. O gerador da Taça já não substitui as músicas dos bosses.

## Atualização 2.3.1

O menu 3D com carrossel de mapas e adversários voltou a ser a entrada principal. O botão TAÇA abre Percurso/Árvore/Jornal; MENU 3D regressa às demonstrações. O hangar tem seleção horizontal sempre acessível, modelo maior, detalhes/ultimate com scroll e ações inferiores. Selecionar uma skin faz pré-escuta do seu tema, respeitando a opção de música desligada; sair restaura a faixa anterior com a transição normal. As qualificatórias usam agora os temas individuais dos adversários em vez da faixa genérica da Taça. Menu e skin padrão mantêm as gravações originais.

# Taça Aurora — demo 2.3

## O que esta versão entrega

Uma demo com dez qualificatórias contra Téo, Mavi, Bento, Suri, Orion, Nila, Dário, Íris, Zeno e Vésper, seguida da final contra o Faroleiro. As arenas aproveitam as geometrias já verificadas do jogo; a dificuldade da IA sobe ao longo do percurso. O grau Fácil/Normal/Difícil está nas Opções.

Em paralelo, uma chave regional de 1 024 participantes é simulada em dez eliminatórias. Os nomes são únicos; cada vencedor tem um resultado registado. O Faroleiro está colocado nessa chave e chega à final através dos mesmos pares de confrontos, com força narrativa superior. Lira começa como promessa; Vértice elimina-a e acaba por perder para o Faroleiro. Os resultados são determinísticos, não um serviço online.

O jogador encontra Percurso, Árvore e Jornal no novo menu. A árvore tem uma vista comprimida e a lista completa paginada, com resultados por eliminatória. Derrotas permitem tentar novamente sem avançar o resto da Taça. Vitórias são guardadas em `user://cup_v1.cfg`; no regresso, todos os confrontos e manchetes são reconstruídos. O último combate encerra a demo e entrega a skin do Faroleiro. A versão continua a disponibilizar as skins e poderes do build aberto para testar; a progressão da Taça é independente.

As antigas arenas, o treino e o PvP local continuam acessíveis. As cinco vidas, dano aliado desativado e pausa PvE foram mantidos.

## Direção visual e sonora

- Interface: fundo azul profundo, cerâmica escura, latão quente, texto claro e jade para estado/progresso. Botão principal inferior, navegação estável e áreas roláveis. Retrato 3D do próximo rival, renderizado uma única vez para poupar GPU.
- Arenas: tinta por setor, linhas finas no piso, medalhão e sinalética periférica; acabamento de cerâmica/metal revisto. Mantêm-se as colisões existentes.
- Pilotos: preservação das identidades, reforço dos acabamentos, distintivo de competição e costuras de ombro. Os pilotos intermédios recentes foram preservados.
- Efeitos: menos cubos soltos, estilhaços achatados e faíscas suaves; anel legível da explosão, marca residual e abalo curto; pulso de ativação com subida para poderes defensivos; selo no chão durante preparação de ultimate. Materiais de preparação quantizados para não criar uma entrada de cache por frame.
- Som: prioridade de cargas/ultimates/golos sobre tiros, controlo de transientes repetidos, novos acordes de pronto/golo e níveis relativos mais suaves.
- Música: menu original e tema padrão preservados. Dez novos arranjos melódicos de 32 compassos e um tema de Taça, com frase, resposta, ponte e reprise. Timbres de sino, flauta, madeira, órgão, vidro e cordas/metais, consoante a skin. Síntese original sem samples de terceiros; gerador em `tools/compose_cup_score.py`.
- Desempenho: nenhuma simulação da arena escondida atrás do menu da Taça; retrato estático; geometria periférica agrupada; efeitos respeitam o perfil de qualidade. Sem promessa de FPS medida num telemóvel real nesta revisão.

## Campanha completa — preparada narrativamente, não incluída na demo

A estrutura aprovada é qualificatórias e finais de setor, seguida da chave final. São **11 etapas de (10 combates + 1 boss) = 121 combates**. Não é uma única eliminatória com 121 rondas.

| Etapa | Boss |
| --- | --- |
| 1 | Faroleiro |
| 2 | Mineiro |
| 3 | Alquimista |
| 4 | Relojoeiro |
| 5 | Jardineiro |
| 6 | Corsário |
| 7 | Caça-Trovões |
| 8 | Astrónomo |
| 9 | Sentinela |
| 10 | Arconte Solar |
| 11 | Nadir — novo rival final, ainda por produzir |

**Aurel** é o tricampeão da imprensa, separado dos dez bosses já existentes. **Nadir** é o estreante que acumula resultados longe das câmaras. Na versão completa, Nadir elimina Aurel na outra semifinal; o jogador descobre que a história paralela era a caminhada de outro protagonista. A demo introduz ambos sem antecipar a reviravolta. As notícias de outros setores são eventos editoriais escritos; a simulação detalhada de todos os setores e os 110 combates restantes ainda não estão implementados.

## Verificação

Teste dedicado `tests/test_cup.gd`: identidades únicas, chave e resultados, curva de dificuldade, limite da demo, reviravolta baseada num confronto, persistência, início real de partida, pausa e resultado de derrota/vitória. `tests/capture_cup.gd` captura menu, árvore, jornal, arena e efeito em retrato e paisagem. Regressões existentes verificam combate, poderes, toque, música e PvP com dois processos.

Os testes headless validam estado e disparo dos sons, não a qualidade ouvida. As capturas foram feitas no PC; o equilíbrio musical final e a fluidez precisam de audição e teste no S23/A15.

## Jornal Aurora em Campo — 2.4.0
- Publicação editorial com capa ilustrada, reportagem secundária, telex discreto e boletim oficial.
- Doze edições (abertura + onze vitórias), selecionáveis no arquivo. As derrotas não criam edições.
- Artigos abrem com fotografia, título, contexto, resultado, protagonistas e etapa.
- `cup_news.gd` separa os registos editoriais da interface; resultados do Farol vêm das fixtures e o resultado do protagonista vem do histórico guardado.
- `news_scene.gd` reutiliza as skins 3D em cenários de imprensa, arena, treino e bastidores. Templates suportam futuras reportagens sem publicar spoilers da campanha completa.
- Fotografias geradas apenas ao entrar na área visível; um render de cada vez. O cenário é libertado após a captura e só permanece a textura da página atual.
- Aurel domina a imprensa; Nadir aparece em notas pequenas. Lira é eliminada por Vértice na jornada 7; Faroleiro ganha a chave na 10; a capa da final celebra o protagonista na 11.
- A demo continua limitada aos dez combates + Faroleiro. Não inclui a campanha completa, nem um quiosque explorável/mascote.
- Músicas originais dos bosses e pré-escuta da galeria preservadas.
- Validação: test_journal, test_cup, test_menu_gallery e test_music; capturas de capa, entrevista, artigo e orientação horizontal. Desempenho nos aparelhos físicos requer teste no APK.

## Árvore narrativa — 2.5.0
- Três níveis: visão da Taça, setor do Farol e confrontos paginados (oito por página).
- Protagonista com a skin equipada, avatar maior, contorno e caminho verde; histórico de adversários vencidos integrado no ramo até à final do setor.
- Onze personagens de referência, com avatares dos modelos existentes; os 1 024 inscritos permanecem agrupados.
- Perfis e percursos derivados das partidas já concluídas. Lira cai perante Vértice; este pode depois aparecer eliminado por Faroleiro; o campeão do setor só fica confirmado quando vence a chave.
- Setores distantes distinguem vitórias publicadas de um histórico completo. Não são inventados resultados detalhados nem revelado o final futuro de Aurel/Nadir.
- Arrasto por rato/toque, zoom com roda/pinça/botões, LOCALIZAR-ME, VISÃO GERAL, seleção e acompanhamento de rival.
- VER NA ÁRVORE nos artigos abre diretamente o perfil do personagem.
- Dados públicos (`cup_tree_data.gd`), canvas (`cup_tree_canvas.gd`) e navegação (`cup_tree.gd`) separados. Os avatares são renderizados uma vez por visita e os cenários temporários libertados.
- Testes: estados e eliminação real, progressão, foco no protagonista, zoom, arrasto, páginas, percurso de rival, ligação do jornal, regressão do menu/galeria e jornal. Capturas em vertical e horizontal. Pinça e desempenho final em aparelhos físicos ainda requerem teste.
