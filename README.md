# O Cordel de Coisinha

Jogo 2D de aventura com visão de cima, feito em **Godot 4.7** (renderizador GL Compatibility), inspirado no folclore nordestino e na estética de xilogravura dos cordéis.

Coisinha é uma aprendiz de cordelista que enfrenta quatro lendas para recuperar os itens que faltam para imprimir seu cordel: o carimbo, a folha, a pena e a tinta.

## Como jogar

1. Abra a pasta do projeto no Godot 4.7 e aperte F5.
2. No Estúdio, entre nos cordéis espalhados pelo chão para iniciar cada fase.
3. Complete as 4 fases para ganhar os 4 itens.
4. Com todos os itens, use a Prensa para finalizar o cordel.

## Controles

- Mover: WASD ou setas
- Interagir: E
- Gritar: Espaço
- Aboio: Q ou F
- Pausar: Esc
- Silenciar: M

## As fases

1. **Chupa-Cabra**: encontre a corda e o candeeiro, ache os bodes escondidos e leve-os ao curral antes que o Chupa-Cabra os pegue.
2. **Fulozinha**: atravesse a fazenda, encontre o fumo e entregue à Fulô.
3. **Rasga-Mortalha**: resolva o enigma das 5 casas usando as pistas dos violeiros antes do tempo acabar.
4. **Botija**: na igreja escura, desenterre a botija enquanto foge da Fulô.

## Destaques técnicos

- Nenhum arquivo de arte ou áudio: os gráficos são desenhados por código (estilo xilogravura), os efeitos sonoros são sintetizados e a música é gerada proceduralmente.
- Arquitetura com autoloads (EventBus, GameManager, SoundManager, JuiceManager) e componentes reutilizáveis (Health, Interactable, Bush).

## Melhorias adicionadas

- Tecla M para silenciar e reativar o som
- Invulnerabilidade pós-dano reduzida de 5 s para 1,5 s, centralizada em uma constante
- Menu de pausa com Esc (continuar e voltar ao Estúdio)
- Controles de volume de música e efeitos
- HUD com os itens coletados durante as fases
