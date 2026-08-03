# war-project

RTT (real-time tactics) 2D, inspirado visualmente en Raid on Bungeling Bay. Mecánicas propias.

## Stack
- **Motor:** Godot 4
- **Resolución:** 640×384 (5:3), escala entera, filtro Nearest
- **Paleta:** Resurrect64
- **Arte:** pixel art top-down
- **Plataformas objetivo:** PC, móvil, Nintendo Switch

## Cómo correr
1. Abrir el proyecto en Godot 4
2. F5 (o botón Play) para correr desde `main.tscn`
3. F6 para correr solo la escena actual

## Controles (build actual)

Un mismo gesto significa cosas distintas según lo que haya debajo — no hay modos ni
gestos separados por plataforma.

| Acción | PC | Táctil |
|--------|----|--------|
| Pan de cámara | Click izq + arrastre | Arrastre |
| Seleccionar unidad | Click izq sobre unidad | Tap sobre unidad |
| Deseleccionar | Escape / botón × | Botón × |
| Dar orden de movimiento | Click der, o click izq en espacio vacío con unidad seleccionada | Tap en espacio vacío con unidad seleccionada |
| **Atacar** | Click izq sobre un enemigo, con unidad propia seleccionada | Tap sobre un enemigo, con unidad propia seleccionada |
| **Menú de unidad ajena** (atacar / info) | Click der sobre la unidad | Mantener pulsado sobre la unidad |
| Elegir arma activa | Click en la barra inferior | Tap en la barra inferior |
| Centrar cámara en unidad | Click en card del panel superior | Tap en card del panel superior |

## Documentación
- `docs/GDD.md` — diseño del juego, mecánicas, unidades
- `docs/decisions.md` — bitácora de decisiones técnicas
- `docs/architecture.md` — índice de clases, señales y estado de implementación
- `CLAUDE.md` — instrucciones de trabajo para Claude Code


# PENDIENTES:
- [ ] Como atacar a los enemigo?
	- [X] Con unidad seleccionada y click al enemigo.
	- Por minimapa
	- Desde el deslpiegue de una unidad aerea o terrestre?
- [ ] Sistema de ataque de avión.
	- [ ] Cada misil y cada bomba tendrá su mecánica... allí el reto
	- [ ] Hacer distinción entre armas aereas y terrestres. no puedes atacar un tanque con un sidewinder
- [x] Las armas disponibles en el layout para armar un avión tienen que venir de una lista de "disponibles" al igual que los aviones. el jugador debe ir desbloqueando armas.
- No desplegar aviones si hay otro vuelo en pista. puede ir subiendo al elevador, eso es todo.
- [ ] Limitar a 2 el vuelo en escuadrón?, Las unidades desplegadas como escuadron deben navegar/desplazarce siguiendo al lider.
	- [X] Se completó el leadId al que despegue en el takeoffpoint mayor, y que al dar click sobre cualquier unidad del escuadron, se enfoque al lider.
	- Aún no vuelan en formación
		[ ] - Debes partir de el script core/unit/squad.gd 
		- debes modificar los parametros de vuelo por tu cuenta: en el script core/unit/lhd_wasp/flight_deck.gd,
		- debes modificar los parametros del harrier por tu cuenta: core/unit/av8b_harrier/av8b_harrier.gd
- [X] El refactor de vuelo hace un giro imposible al darle - Se desactivo brake on turns y mejoró, pero se comporta muy abierto.
- [X] Las unidades desplegadas como escuadron deben salir en el menú deu nidades como una sola y un multiplicador de la cantidad: x2, x3.. xN
- Minimapa y mapa tactico
	- A partir de aqui iniciar las opciones de ataque de unidades
