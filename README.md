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
| **Mapa táctico** (abrir) | Tecla `M`, o click en el minimapa | Tap en el minimapa |
| **Cerrar el mapa táctico** | Tecla `M`, o botón `×` | Botón `×` |
| **Ir a un punto del mapa** | Click sobre el mapa, sin unidad seleccionada | Igual |
| **Dirigir la unidad desde el mapa** | Click sobre el mapa, con unidad propia seleccionada | Igual |
| **Atacar desde el mapa** | Click sobre el punto de un enemigo, con unidad propia seleccionada | Igual |
| **Menú de unidad ajena desde el mapa** | Click der. sobre su punto | Mantener pulsado sobre su punto |
| **Ir a donde pasó algo** | Click en la coordenada azul del registro de eventos | Igual |
| **Agrandar / encoger el minimapa** | Arrastrar su borde superior | Igual |

En el mapa táctico se manda igual que en el mundo: el mismo gesto significa lo mismo, y lo que
haya bajo el punto decide. **Pulsar no cierra el mapa** — el destino queda marcado en el propio
mapa, y el recuadro de la cámara enseña a dónde se fue la vista. Con una unidad seleccionada se
resalta su punto y se oculta ese recuadro, que si no sería un cuadro enorme persiguiéndola.

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
| Sitio del fogonazo del cañón | nodo `CannonFlash` de `av8b_harrier.tscn` → `position` |
| Velocidad del fogonazo y reparto arranque/ráfaga | `core/weapon/cannon_flash_frames.tres` (`start` = frames 0-5, `sustain` = 6-10) |
| Sitio y densidad del humo del cañón | nodo `CannonSmoke` de `av8b_harrier.tscn` → `position` / `spacing_px` |
| Largo del humo del cañón | `core/weapon/cannon_smoke_frames.tres` (hoy 0,67 s ≈ 45 px) |
| Letalidad del cañón | `core/weapon/gau12_cannon.tres` → `damage` (por bala) × `rounds_per_second` |
| Cuánto pierde el cañón con la distancia | mismo `.tres` → `long_range_accuracy` (0,25 = en el borde entra 1 de cada 4) |
| Cuánto cuesta soltar el gatillo | mismo `.tres` → `arc_hysteresis` (abre a 10°, no suelta hasta 20°) |
| Densidad y velocidad de las trazadoras | nodo `CannonTracers` → `tracers_per_second`; `core/weapon/tracer.tscn` → `speed` |
| Hasta dónde llega una trazadora | no se ajusta: se la da el arma (la distancia al blanco). `range_px` es sólo el respaldo sin blanco |
| Cuánto se dispersa la ráfaga (unas cortas, otras pasadas) | `core/weapon/tracer.tscn` → `reach_spread` (0,12 = ±12%) |
| Cómo se apaga la trazadora al llegar | mismo nodo → `burn_out_px` (en cuántos px se consume) |
| Reparto de la animación de la trazadora | `core/weapon/tracer_frames.tres` (`muzzle` = frames 0-6 saliendo, `streak` = el 7, el resto del vuelo) |
| Cuándo el avión se lanza a la pasada y deja de corregir | nodo `AttackRun` → `aim_tolerance_deg` (6° hoy) |
| Cuánto sigue recto pasado el blanco | mismo nodo → `strafe_overrun` |
| Separación mínima antes de rehacer una pasada | mismo nodo → `turn_around_margin`, en radios de giro del avión. Tiene que dar para girar **y salir apuntando** |
| Altura de la sombra del misil (diagonal) | nodo `Shadow` de `agm65_missile.tscn` → `altitude_drop_px` |
| Cuándo empieza a bajar la sombra | mismo nodo → `descent_px` |
| Vuelo de la bomba planeadora (caída, planeo, espoleta) | `core/weapon/gbu54_bomb.tscn` (nodo raíz) |
| Alcance real de la bomba | mismo nodo → `fall_time` (es su altura), junto con `max_range` del `.tres` |
| Vuelo de la bomba tonta (separación, freno, caída) | `core/weapon/mk82_bomb.tscn` (nodo raíz) |
| Cuánto se queda atrás la Mk-82 al soltarla | mismo nodo → `drag` y `terminal_speed`. Es lo que evita que el avión vuele hacia su propia explosión |
| Alcance real de la Mk-82 | no se ajusta: es lo que recorre mientras cae (`fall_time` × su velocidad). El `max_range` del `.tres` es **desde dónde soltarla** para que la ristra caiga centrada |
| Dispersión de la ristra | mismo nodo → `wander_deg` (a lo ancho) y `fall_spread` (a lo largo). **No** `salvo_spread`: una bomba tonta no apunta |
| Largo de la ristra de bombas | `core/weapon/mk82.tres` → `salvo_interval` (0,1 s ≈ 75 px a máxima). Cuántas caen: `salvo_size = 0` (todas) |
| Si el avión frena para apuntar con un arma | `<arma>.tres` → `slows_to_aim` (el cañón sí, la bomba no) |
| Velocidad de apertura del freno de la bomba | `core/weapon/mk82_bomb_frames.tres` (`carried` = cola cerrada, `drop` = abriéndose) |
| Velocidades del avión (mínima, máxima, aceleración) | nodo `PlaneController` de `av8b_harrier.tscn` |
| Radio de giro del avión | mismo nodo → `turn_radius`. **Es el parámetro maestro del vuelo**: manda sobre el viraje y sobre el tamaño mínimo del circuito de espera |
| Distancias de las pasadas de ataque | nodo `AttackRun` de `av8b_harrier.tscn` |
| A qué distancia del barco esperan los aviones | nodo `OrbitBehavior` de `av8b_harrier.tscn` → `radius` |
| A qué velocidad despega un avión | no se ajusta: es su `min_speed`, y la cubierta se la pregunta |
| Resistencia de cada unidad | `<unidad>_type.tres` → `max_health` |

## Dónde se ajusta el mapa

| Qué | Dónde |
|-----|-------|
| Tamaño de las zonas de coordenadas (A1…H6) | nodo `TacticalMap/Map` de `hud.tscn` → `zone_cells` (hoy 8) |
| Tecla que abre el mapa táctico | nodo `TacticalMap` → `shortcut_key` (`KEY_NONE` la desactiva) |
| Cuánto hay que aguantar para que cuente como pulsación mantenida | `core/input/long_press.gd` → `hold_time` (0,5 s) |
| Qué terreno es cada tile (agua / tierra / arena) | `assets/art/tiles/terrain_tileset.tres` → capa de datos `tipo`, en el editor del TileSet |
| Color de cada tipo de terreno en el mapa | `ui/hud/minimap/map_terrain.gd` → `COLORS` |
| Tamaño del punto de las unidades | nodo `MapView` de cada mapa → `marker_px` (2 en el minimapa, 4 en el táctico) |
| Color de cada bando | `core/team/team.gd` → `_COLORS` |
| Zona de dibujo del mapa táctico (para que no la pisen los paneles) | nodo `TacticalMap/Map` → `offset_top` / `offset_right` |
| Sitio del rótulo y del botón de cerrar | nodos `TacticalMap/Hint` y `TacticalMap/CloseButton` → `offset` |
| Cuánto puede crecer el minimapa | `ui/hud/minimap/minimap.gd` → `MAX_HEIGHT` |
| Cuántas líneas guarda el registro de eventos | `ui/hud/event_log/event_log.gd` → `MAX_LINES` |
| Código de brevedad de cada arma (`Rifle!`, `Fox Two!`…) | `core/weapon/<arma>.tres` → `brevity_code` |

Las unidades se marcan con un punto del color de su bando: **azul** el jugador, **rojo** los
enemigos, **verde** los aliados y **blanco** los neutrales.

El tamaño del mapa **no se configura en ningún sitio**: sale del `TileMapLayer`, así que un
mapa de otra misión funciona sin tocar nada. La escala del minimapa y del mapa táctico se
calcula sola — el mayor número entero de píxeles por celda que quepa.

**El mapa no dibuja la cuadrícula de 32 px del terreno**, solo la de zonas de coordenadas: una
línea por celda serían casi 2900 cuadritos y se lee como rayado, no como cuadrícula. Y
`zone_cells` es lo que se *pide*, no lo que sale: si el mapa crece, las zonas se agrupan de dos
en dos hasta que la coordenada vuelve a leerse. Por eso no hay que retocarlo por misión.

**El registro de eventos** cuenta órdenes, ataques, disparos y bajas, con el arma y su código
de brevedad OTAN (`LHD Wasp: AGM-65 (Rifle!)`). La coordenada azul del final de cada línea es
pulsable: lleva la cámara a donde pasó. Se mide por su contenido y crece hacia arriba, y
vacío no se dibuja.

**La columna de la izquierda se acomoda sola.** El minimapa se recorta a su dibujo —por eso ya
no tiene marco negro— y al arrastrar su borde superior salta entre escalas enteras (1x, 2x…),
nunca a medias. El registro se aparta hacia arriba cuando el minimapa crece.

El mapa táctico **no se dibuja encima del HUD**: su área esquiva la barra superior y la columna
de paneles de la derecha, así que el hangar, las acciones, el zoom y la lista de desplegadas
siguen a mano con el mapa abierto. Lo único que se esconde es la barra de armas. Si mueves
paneles del HUD, ajusta los dos `offset` de la tabla o volverán a solaparse.

## Documentación
- `docs/GDD.md` — diseño del juego, mecánicas, unidades
- `docs/decisions.md` — bitácora de decisiones técnicas
- `docs/architecture.md` — índice de clases, señales y estado de implementación
- `CLAUDE.md` — instrucciones de trabajo para Claude Code


# PENDIENTES:
- [ ] Los sprites se ven pixelados cuando se mueven. se ponen borrosos a medida que giran y maniobran.
- [X] Relentizar vuelo y mejorar agilidad del avión. Los giros deben verse mas naturales.
	- Mantener frenado durante el ataque.
	- Velocidad normal de vuelo.
	- Aceleración al ir hacia un target o durante combate aereo.
- Bugs y mejoras lanzamiento de AGM-65
	- El avión sale de la pantalla intentando atacar, eso no debería ocurrir, debe maniobrar dentro del juego...
		- Siempre falla el misil al tratar de re tomar el ataque? parece que si.
	- Sigue intentando atacar aún cuando se quedó sin arma. supongo que es por que no tenemos mas logicas de armas aún.
	- El avión vira demasiado brusco y enseguida al lanzar el misil. es un giro cerrado de carrito a control remoto cuando debe ser un giro controlado... que pasó con el derrape y las variables cool y excentricas del control del jet, no aplican acá?
- [X] Estela de humo del misil !! Falta alargar la fase opaca: empieza a desvanecerse al primer tercio, hacen falta 3–4 frames opacos más y algún paso de alfa extra antes del final
- [X] Sombra del misil !! Redibujarla ovalada y de 3 px de ancho: ahora mide lo mismo que el cuerpo del misil y en los últimos frames se funden
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
- [X] Minimapa y mapa tactico — terreno, rejilla de 32x32 y coordenadas por zonas (A1…P12). Falta:
	- [X] Unidades en el mapa (puntos por bando)
	- [X] Coordenadas pulsables en el log de eventos (`label_at` / `zone_center` ya existen)
	- [X] Distinguir en el mapa la unidad seleccionada, y quizá aire de superficie
