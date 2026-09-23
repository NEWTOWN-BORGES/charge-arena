# Modo História 2.7

- Dez etapas de cinco batalhas e um boss: 50 adversários comuns + dez bosses, 60 combates.
- A chave paralela de 1 024 pilotos avança duas eliminatórias por vitória do protagonista. O vencedor continua a ser confirmado por partidas reais antes do confronto.
- Cinquenta pilotos procedurais distintos: dez combinações de capacete/crista e cinco famílias de equipamento, com proporções e cores próprias. Não são cinquenta modelos feitos à mão; o teste compara a geometria para confirmar que as combinações não se repetem.
- Cinquenta arenas de qualificatória com combinações de contorno, formação/afastamento dos blocos e movimento dos obstáculos. Reutilizam cinco famílias de contornos e cinco formações; os dez bosses mantêm as arenas temáticas. As posições dos blocos passam pelo mesmo cálculo de colisões e desenho.
- Ultimates comuns derivadas das habilidades equipadas: disparo +15% velocidade, cadência +25% duração, leque +2 projéteis, muralha/gelo/atração/perfuração +20% duração, soldadura com reparação adicional em um de cada quatro blocos. Preparação luminosa distinta; disparo e leque amplificados com cor própria. Ultimates dos bosses preservadas.
- Jornal alterna ação, chegada, treino, bastidores, entrevista, celebração e confronto. Cenários têm props, iluminação, enquadramento e cores variáveis; usam os modelos dos participantes da reportagem. As fotografias continuam a ser renderizadas uma única vez para evitar carga contínua no telemóvel.
- Árvore abre em AGORA: etapa, protagonista, próximo rival, último derrotado e estado da chave. RIVAIS e RESULTADOS ficam em vistas separadas. Etapas futuras não revelam bosses.
- Botão TAÇA do menu passou a MODO HISTÓRIA.

## Progresso antigo

O save versão 3 converte cada etapa antiga de onze combates numa etapa de seis. Cada par de qualificatórias antigas equivale a uma nova, arredondando a favor do jogador. Bosses já conquistados continuam conquistados, com a mesma semente/ordem dos setores. O ficheiro anterior é copiado para `.before-five-battles`; o histórico completo anterior também fica em `legacy_history`. Os resultados representativos mantêm o nome e marcador original, com `legacy_round`, e os próximos encontros seguem o novo formato.

## Validação

`test_story_refresh.gd`: 60 combates completos; cinquenta geometrias de piloto e cinquenta configurações de arena distintas; blocos dentro da arena; variedade de cenas; oito pontos de migração de saves (incluindo campanha completa); prémios e nova gravação/restauro; ativação e efeito das habilidades amplificadas.
Também passaram os testes da Taça, Percurso, árvore, jornal, torneio e ultimates. Capturas do menu, árvore, cinco arenas e três capas em Godot. Fluidez e gestos nos aparelhos físicos ainda precisam de teste.

APK normal e APK Teste: versão 2.7.0-historia, código 49.
