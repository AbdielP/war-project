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
| **Acercar / alejar** (0,5x / 1x / 2x) | Botones `+` y `−` del borde derecho | Igual |
| **Pausa / play** | Barra espaciadora, o el botón bajo los de zoom | Botón bajo los de zoom |

Los niveles de zoom se cambian en el nodo `PanCamera` → `zoom_levels` (y con cuál arranca,
`default_zoom_level`). Conviene que sean potencias de dos: con filtro Nearest, cualquier
factor intermedio descarta píxeles en un patrón irregular que hierve al mover la cámara.
Los botones se mueven cambiando los `offset` de `ZoomControls` y `PauseButton` en `hud.tscn`.

**En pausa se puede seguir mirando:** la cámara, el HUD y la selección siguen vivos, así que
puedes panear, cambiar el zoom y seleccionar unidades con la partida congelada. Lo decide
el `process_mode = Always` de cada escena, no una lista en el código. La tecla del atajo se
cambia en el nodo `PauseButton` → `shortcut_key` (`KEY_NONE` lo desactiva).

## Dónde se ajusta el combate

Todo por inspector, sin tocar código. Está separado a propósito: lo que el arma **hace**
va en su recurso, y **cómo vuela** lo que dispara va en la escena del proyectil.

| Qué | Dónde |
|-----|-------|
| Alcance, arco de tiro, daño, radio de explosión, andanada, recarga | `core/weapon/<arma>.tres` |
| Velocidad, radio de giro, combustible, espoleta del misil | `core/weapon/agm65_missile.tscn` (nodo raíz) |
| Posición del fuego del propulsor | nodo `Exhaust` de `agm65_missile.tscn` → `position` |
| Velocidad y corte de frames del fuego | `core/weapon/missile_exhaust_frames.tres` |
| Densidad de la estela de humo | nodo `SmokeTrail` de `agm65_missile.tscn` → `spacing_px` |
| Largo de la estela (duración por frame) | `core/weapon/missile_smoke_frames.tres` |
| Velocidad de crucero y viraje del avión | nodo `PlaneController` de `av8b_harrier.tscn` |
| Velocidad de ataque y distancias de las pasadas | nodo `AttackRun` de `av8b_harrier.tscn` |
| Circuito de espera (tamaño del óvalo) | nodo `OrbitBehavior` de `av8b_harrier.tscn` |
| Resistencia de cada unidad | `<unidad>_type.tres` → `max_health` |

## Documentación
- `docs/GDD.md` — diseño del juego, mecánicas, unidades
- `docs/decisions.md` — bitácora de decisiones técnicas
- `docs/architecture.md` — índice de clases, señales y estado de implementación
- `CLAUDE.md` — instrucciones de trabajo para Claude Code


# PENDIENTES:
- [ ] Los sprites se ven pixelados cuando se mueven. se ponen borrosos a medida que giran y maniobran.
- [ ] Relentizar vuelo y mejorar agilidad del avión. Los giros deben verse mas naturales.
	- Mantener frenado durante el ataque.
	- Velocidad normal de vuelo.
	- Aceleración al ir hacia un target o durante combate aereo.
- Bugs y mejoras lanzamiento de AGM-65
	- El avión sale de la pantalla intentando atacar, eso no debería ocurrir, debe maniobrar dentro del juego...
		- Siempre falla el misil al tratar de re tomar el ataque? parece que si.
	- Sigue intentando atacar aún cuando se quedó sin arma. supongo que es por que no tenemos mas logicas de armas aún.
	- El avión vira demasiado brusco y enseguida al lanzar el misil. es un giro cerrado de carrito a control remoto cuando debe ser un giro controlado... que pasó con el derrape y las variables cool y excentricas del control del jet, no aplican acá?
- [X] Estela de humo del misil !! Falta alargar la fase opaca: empieza a desvanecerse al primer tercio, hacen falta 3–4 frames opacos más y algún paso de alfa extra antes del final
- [ ] El contador de impacto debería ser visible siempre sobre la unidad? de ese modo puedo saber si está siendo atacado mientras uso otra unidad.
- [X] Pausar y play
- [X] Diferentes zooms !! El zoom al CV es muy grande
- [ ] Como atacar a los enemigo?
	- [X] Con unidad seleccionada y click al enemigo.
	- Por minimapa
	- Desde el deslpiegue de una unidad aerea o terrestre?
- [ ] Sistema de ataque de avión.
	- [ ] Cada misil y cada bomba tendrá su mecánica... allí el reto
	- [X] Hacer distinción entre armas aereas y terrestres. no puedes atacar un tanque con un sidewinder
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
