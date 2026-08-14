# Arquitectura del código — war-project

Referencia de sesión. Actualizar cuando cambie algo relevante.

---

## Escena principal (`main.tscn`)

```
Node2D
├── TileMapLayer          — terreno (tile_set: terrain_tileset.tres, celdas de 32×32)
│                           hoy 64×45 celdas desde (0,−6) = 2048×1440 px de mundo.
│                           Es la única fuente del tamaño del mapa: de aquí sacan
│                           sus límites `PanCamera` y su imagen `MapTerrain`.
├── LHD_WASP              — instance lhd_wasp.tscn, position (1110, 519)
├── HUD                   — instance hud.tscn (CanvasLayer, fijo en pantalla)
├── PanCamera             — instance pan_camera.tscn (Camera2D)
└── SelectionManager      — instance selection_manager.tscn
                            exports: camera_path=../PanCamera, hud_path=../HUD
```

---

## Clases del núcleo

### `Unit` — `core/unit/unit.gd`
```
extends Area2D   class_name Unit
```
Base de toda unidad seleccionable. Tiene `CollisionShape2D` + `SelectionIndicator` como hijos en `unit.tscn`.

| Export | Tipo | Uso |
|--------|------|-----|
| `unit_type` | UnitType | Resource compartido por tipo |
| `unit_name` | String | Nombre propio de instancia (sin traducción) |
| `team` | Team.Side | Bando. En la **instancia**, no en el `UnitType`: el mismo modelo puede ser enemigo en una misión y aliado en otra. Por defecto `PLAYER` |
| `squad` | Squad | No exportado. `null` = unidad suelta. Asignado por quien despliega en grupo (ver `Squad` más abajo) |

| Método | Descripción |
|--------|-------------|
| `set_selected(bool)` | Marca/desmarca por selección. Ver "Indicador" abajo |
| `set_targeted(bool)` | Marca/desmarca por estar bajo ataque. Lo llama `SelectionManager`, no la unidad misma |
| `is_player_controlled()` | ¿Obedece órdenes del jugador? Sólo `PLAYER` — las aliadas las mueve la IA |
| `is_hostile_to(other)` | ¿Se disparan? Delega en `Team.are_hostile()` |
| `get_display_name()` | unit_name si existe, sino tr(unit_type.display_name) |
| `get_actions()` | PackedStringArray desde unit_type.actions |
| `set_weapon_loadout(loadout)` | Arma la unidad **con una copia** (ver abajo) y la dibuja si tiene `HardpointRack` |
| `get_weapons()` | `Array[WeaponType]`: cañón + un arma por tipo colgado, sin repetir |
| `get_default_weapon()` | La principal del loadout; el cañón sólo si va desarmada |
| `set_active_weapon(w)` | Con qué ataca. Emite `active_weapon_changed` |
| `get_ammo(w)` / `has_ammo(w)` | Lo que queda. **−1 = ilimitada** (el cañón no cuelga de estación) |
| `spend_ammo(w)` | Descuenta una y emite `ammo_changed`. `false` si no había |
| `get_domain()` | `UnitType.Domain` — en qué medio se mueve; decide qué armas pueden atacarla |
| `get_max_health()` / `is_alive()` | Resistencia |
| `take_damage(float, source)` | Encaja daño. Al llegar a 0 emite `died` y `queue_free()`. `source` es opcional: quien lo causó, si se sabe |
| `notify_tracked(threat)` | Le avisan de que la tienen enganchada. Lo llama **la amenaza** |
| `notify_fired_upon(threat)` | Le avisan de que le están disparando |

**Alarmas: quién apunta avisa a quién es apuntado.** Dos señales, `tracked_by(threat)` y
`fired_upon_by(threat)`. El agresor es el único que sabe a quién apunta, así que llama a la
víctima; la víctima decide qué hacer con la noticia — hoy el parte de eventos y los dos mapas,
mañana el audio.

La diferencia entre las dos importa: **`tracked_by` llega a tiempo**. Un antiaéreo detecta más
lejos de lo que alcanza y encima tarda en girar la torreta, así que entre que te engancha y que
te dispara hay margen. Medido con el Tunguska: 4,8 s.

**El filtro anti-repetición vive aquí** (`ALARM_SILENCE`, 8 s por amenaza y por tipo), no en
quien escucha: la alarma es una sola aunque la oigan varios, y si cada consumidor filtrara por
su cuenta acabarían diciendo cosas distintas. Sin él, un cañón de ráfagas —que abre fuego cada
segundo y medio— llenaría el parte con la misma línea. Medido: 2 avisos en vez de ~10.

**`killed_by`** guarda quién pegó el último, para el parte de bajas. El último y no el que más
puso: es lo que se dice en un parte, y lo único que se sabe sin llevar la cuenta de cada uno.
| `get_facing()` | **Virtual** — rumbo real en radianes. De ahí sale el armamento. Por defecto `global_rotation` |
| `get_velocity()` | **Virtual** — lo que se lleva el arma al soltarse. Por defecto cero |
| `get_time_to_impact()` | **Virtual** — segundos hasta que llegue lo que tenga disparado, −1 si nada |
| `receive_move_order(Vector2)` | **Virtual** — cancela `attack_target` (`super()`) y las subclases resuelven el cómo |
| `receive_attack_order(Unit)` | **Virtual** — llama `set_attack_target()`; las subclases resuelven cómo acercarse y disparar |
| `set_attack_target(Unit)` | Único sitio que toca `attack_target`. Ver nota sobre objetos liberados abajo |

| Señal | Cuándo |
|-------|--------|
| `active_weapon_changed(weapon)` | Cambió el arma seleccionada |
| `attack_target_changed(target)` | Cambió a quién ataca (`null` = a nadie) |
| `ammo_changed(weapon, remaining)` | Se gastó munición. Lo escucha `WeaponBar` |
| `died(unit)` | Antes de quitarla del mapa, mientras todavía existe |

Toda unidad se añade al grupo `Unit.GROUP` (`&"units"`) en `_ready()`: es donde mira una
explosión para saber a quién alcanza, en vez de recorrer el árbol entero.

**El loadout se clona al armar.** Lo que llega es el catálogo de `PlayerFleet`, compartido
por todas las unidades del mismo modelo; la munición es estado de *esa* salida. Clonar
aquí y no en quien llama es lo que hace que no se pueda olvidar — sin esto, gastar un
misil se lo quitaría a los demás aviones de la flota y no volvería nunca.

Estado de armamento: `weapon_loadout` (qué lleva) y `active_weapon` (con qué ataca). El
arma activa vive aquí y no en el HUD porque el panel se reconstruye en cada selección.
Sale puesta la principal del loadout — desde `_ready()` para unidades del mapa, y desde
`set_weapon_loadout()` al armarlas, porque el arma que hubiera puede no estar en el
armamento nuevo.

**Indicador visual (`_selection_indicator`):** se ve si `_selected` **o** `_targeted` es
verdadero — dos motivos distintos para el mismo dibujo. `_selected` lo pone
`SelectionManager` al elegir la unidad; `_targeted` lo pone también `SelectionManager`,
pero sobre la unidad que está siendo atacada por la unidad seleccionada. **Es una vista de
la selección, no un hecho propio de la unidad:** por eso vive como estado privado de
`Unit` pero lo escribe siempre `SelectionManager`, nunca la unidad misma. Se apaga y
enciende junto con el resto del HUD al deseleccionar/reseleccionar, aunque el ataque en
curso no se interrumpa.

**`attack_target` y objetos liberados:** un `Unit` liberado (`queue_free`) se compara
`== null` como verdadero. `set_attack_target()` normaliza antes de comparar — si el
objetivo anterior ya no es válido, el cambio se deja pasar aunque el nuevo valor también
sea `null` — porque si no, la muerte del objetivo nunca dispararía
`attack_target_changed` y el HUD se quedaría mostrando un ataque que ya terminó.
`SelectionManager._mark_target()` tiene la misma trampa resuelta igual.

| Señal | Cuándo |
|-------|--------|
| `active_weapon_changed(weapon)` | Cambió el arma seleccionada |
| `attack_target_changed(target)` | Cambió a quién ataca (orden nueva, movió, o el objetivo murió) |

Señales opcionales (no en la base, implementadas por subclases que las necesiten):
- `order_fulfilled` — la unidad llegó al destino

SelectionManager usa `has_signal()` antes de conectar — no acoplamiento directo.

---

### `Team` — `core/team/team.gd`
```
extends RefCounted   class_name Team
```
**Sólo identidad de bando**: quién es de quién y de qué color se pinta. No decide quién
manda a las unidades ni quién dispara a quién — eso lo consultan el HUD, la selección y
la IA, pero lo aplican ellos.

| Miembro | Descripción |
|---|---|
| `enum Side { PLAYER, ALLY, ENEMY, NEUTRAL }` | `ALLY` es del lado del jugador pero la mueve la IA. `NEUTRAL` no es de nadie: fauna, civiles, restos |
| `color(side) → Color` | Azul `#8fd3ff` / verde `#a8ca58` / rojo `#e83b3b` / blanco `#ffffff` (Resurrect64) |
| `are_hostile(a, b) → bool` | Hostiles si exactamente uno es `ENEMY`, **salvo que alguno sea `NEUTRAL`** |

**Los bandos nuevos se añaden al final del enum.** `Unit.team` es exportado, así que se
guarda como número en las escenas: colar uno en medio renumeraría los de abajo y cambiaría
de bando a todas las unidades ya colocadas.

**El neutral obligó a tocar `are_hostile()`.** La regla anterior —"hostil si uno de los dos
es enemigo"— habría hecho que un neutral fuese **enemigo del enemigo**, que es justo lo que
neutral no significa. La excepción va aquí y no en quien pregunta.

Las firmas usan `Team.Side` y no `Side` a secas: dentro del propio archivo GDScript
trata el enum local como un tipo distinto del que ven los demás, y las llamadas de fuera
no compilan.

El día que haya varias facciones enfrentadas entre sí, `are_hostile()` es el único sitio
que cambia.

---

### `Squad` — `core/unit/squad.gd`
```
extends RefCounted   class_name Squad
```
Agrupación en tiempo de ejecución (no se guarda en disco). `leader: Unit`, `members: Array[Unit]`. `add(unit, slot)` agrega y asigna líder a quien tenga el `slot` de cubierta más alto del grupo (`_leader_slot`, se recalcula en cada `add`) — el slot más alto despega primero (`FlightDeck._launch_next`), así el líder siempre despega primero. No implementa seguimiento/formación todavía — solo identidad de grupo. Ver `docs/decisions.md` (2026-08-01).

---

### `UnitType` — `core/unit/unit_type.gd`
```
extends Resource   class_name UnitType
```
Resource `.tres` compartido entre todas las instancias del mismo tipo (ej. `lhd_wasp_type.tres`).

| Export | Tipo |
|--------|------|
| `display_name` | String (clave de traducción) |
| `actions` | PackedStringArray (ej. `["Hangar"]`) |
| `cannon` | WeaponType — arma fija, va siempre y no ocupa estación. Vacío = sin cañón |
| `domain` | `Domain` (AIR / SURFACE) — en qué medio se mueve. Decide qué armas pueden atacarla |
| `max_health` | float — Harrier 60, T-14 100. Un AGM-65 pega 120 |
| `ecm_evasion` | 0–1 — lo que se libra de un misil guiado **sin gastar nada**. 0,20 en el Harrier |

**`ecm_evasion` va aquí y no en la instancia**, como `max_health`: es lo que trae el modelo de
fábrica, así que el menú de progresión lo subirá para todos los de ese modelo de una vez. Lo que
sí es de cada unidad es el bando, porque el mismo avión puede cambiarlo entre misiones.

El enum `Domain` se declara aquí y las firmas del propio archivo lo escriben
`UnitType.Domain` — ver el patrón "Enum de una clase con `class_name`".

---

### `SelectionIndicator` — `core/unit/selection_indicator.gd`
```
extends Node2D
```
Dibuja contorno de selección en `_draw()`. Exports `size: Vector2` y `color: Color` — el
color lo pone `Unit` en `_ready()` desde `Team.color(team)`, así que el contorno delata el
bando: azul propio, verde aliado, rojo enemigo. El valor exportado sólo se ve en el editor.

---

### `RangeRings` — `core/unit/range_rings.gd`
```
@tool  extends Node2D   class_name RangeRings
```
Dibuja los dos círculos de alcance de una unidad antiaérea. **Sólo dibuja**: no detecta, no
apunta y no dispara.

Son dos y no uno porque **ver y poder disparar no son lo mismo**. La corona entre ambos es la
franja en la que la unidad ya sabe que estás pero todavía no te llega, y ése es el margen de
reacción del jugador — por eso conviene que se vea.

| export | por defecto | qué es |
|---|---|---|
| `detection_radius` | 400 | hasta dónde ve; lo lee `TurretTracker` |
| `engagement_radius` | 250 | hasta dónde dispara |
| `visible_rings` | `true` | apagarlo quita los círculos sin perder los radios |
| `detection_color` / `engagement_color` | ámbar / rojo | — |
| `line_width` | 1 | píxeles de mundo |
| `segments` | 96 | tramos por círculo |

`@tool` a propósito: se ven en el editor sin ejecutar, así que ajustarlos es arrastrar un
número. Dos trampas ya pisadas y documentadas en el propio script:

- **Nada de `z_index` negativo.** El terreno es un `TileMapLayer` en 0; por debajo, el suelo
  los tapa. En 0 quedan sobre la hierba y bajo la unidad.
- **A zoom 1x sólo se ven 320 px desde el centro.** Un radio mayor existe pero cae fuera de
  cuadro; hay que alejar la cámara para verlo entero.

Es la fuente del alcance para quien la necesite: tenerlo también apuntado en el buscador daría
una unidad que engancha más lejos de lo que dibuja, y el jugador ajusta lo que ve.

**El círculo de dentro —la zona muerta— NO es un export.** Sale de `dead_zone_radius()`, que lee
el `min_range` del cañón de la unidad. Apuntarlo también aquí sería un tercer número diciendo lo
mismo, y el círculo acabaría mintiendo. Como ese valor no pasa por ningún setter de este nodo,
en el editor se comprueba cada frame si cambió para repintar; en juego eso no corre.

Sirve de ejemplo de la unificación que sigue pendiente para `engagement_radius`, que hoy **sí**
duplica el `max_range` del arma.

---

### `RadarDish` — `core/unit/radar_dish.gd`
```
extends Node2D   class_name RadarDish
```
Gira, y nada más. Un export: `scan_speed_deg` (120 = una vuelta cada 3 s).

**No busca ni sigue a nadie, y es deliberado.** Un radar de vigilancia barre todo el cielo; si
se parase a mirar un avión dejaría de vigilar el resto. Quien engancha es la puntería de la
torreta (`TurretTracker`). Es decoración honesta: gira porque el trasto de verdad gira.

Montado como hijo de la torreta, así que **gira sobre ella además de girar solo**, igual que
en el vehículo real.

---

### `TurretTracker` — `core/unit/turret_tracker.gd`
```
extends Node2D   class_name TurretTracker
```
Engancha la aeronave hostil más cercana dentro del alcance y la sigue con los cañones. **No
dispara**: apunta y avisa por señal de a quién.

| señal | cuándo |
|---|---|
| `target_acquired(unit)` | enganchó a alguien |
| `target_lost` | se fue de rango o dejó de existir |

| export | por defecto | qué es |
|---|---|---|
| `turn_speed_deg` | 60 | velocidad de giro |
| `sprite_offset_deg` | −90 | cañones dibujados hacia +Y |
| `target_group` | `unit_air` | dónde busca |
| `rescan_interval` | 0,1 s | cada cuánto rehace la búsqueda |
| `rings_path` | `../RangeRings` | de dónde saca el alcance |

Tres decisiones dentro:

- **Gira despacio a propósito.** Una torreta que se planta sobre el blanco en un frame se lee
  como un número asignado, no como una máquina; y el retardo es lo único que el jugador tiene a
  favor. Medido: el caso peor —avión apareciendo a la espalda, 180°— tarda **3,07 s** (teoría
  3,00 a 60°/s). Que llegue tarde con un avión rápido no es un fallo, es la mecánica.
- **Busca por distancia, no con un `Area2D`**, igual que `WeaponSystem` resuelve su alcance.
- **Ignora a los suyos** (`is_hostile_to`). Sin esto, en cuanto haya aviones en los dos bandos
  seguiría al aliado que pase más cerca.

Sin blanco **se queda donde quedó**: volver sola a una posición de reposo sería inventarse una
maniobra que nadie pidió.

`get_facing()` devuelve la línea de los cañones — es lo que la unidad debe reexportar para que
el armamento y los efectos sepan hacia dónde sale el fuego.

---

### `PanCamera` — `core/camera/pan_camera.gd`
```
extends Camera2D   class_name PanCamera
```
| Señal | Cuándo |
|-------|--------|
| `clicked(world_position: Vector2)` | Click/tap sin arrastre (umbral 6px) |
| `long_pressed(world_position: Vector2)` | Pulsación mantenida sin arrastrar (`long_press_time`, 0,5 s). Equivalente táctil del click derecho: en móvil no hay segundo botón |
| `zoom_changed(level, count)` | Cambió el nivel de acercamiento. Lo escucha quien dibuje los botones, para saber si queda cuerda |

| Variable | Descripción |
|----------|-------------|
| `follow_target: Node2D` | Si no es null, `_process` copia su `global_position` |

- Pan: click+arrastre izquierdo. Al empezar el arrastre, `follow_target = null`.
- Límites auto-calculados en `_ready()` desde todos los `TileMapLayer` de la escena.
- `SelectionManager` asigna `follow_target = _selected_unit` en `_select()`.
- **`long_pressed` se dispara sin soltar el botón**, como cualquier menú contextual
  táctil — el aviso llega con el dedo/botón aún apoyado. Al soltar después de que ya se
  disparó, no cuenta como `clicked`: si contara, el menú se abriría y una orden le
  llegaría encima en el mismo gesto.
- El reconocimiento del gesto no está aquí: lo lleva `LongPress` (ver abajo). La cámara sólo
  le va contando lo que pasa y traduce las respuestas a sus señales.

**Acercamiento.** `zoom_levels` (`PackedFloat32Array`, hoy `[0.5, 1.0, 2.0]`) y
`default_zoom_level` (1) son exports: añadir un nivel o cambiar con cuál arranca es tocar
el inspector. API: `zoom_level()`, `zoom_level_count()`, `set_zoom_level(n)`,
`step_zoom(±1)`.

---

### `LongPress` — `core/input/long_press.gd`
```
extends RefCounted   class_name LongPress
```
Reconoce "mantener pulsado sin arrastrar", el equivalente táctil del click derecho. Ajustes:
`hold_time` (0,5 s) y `move_threshold_px` (6).

| Método | Qué contesta |
|--------|--------------|
| `press(pos)` | empieza a contar |
| `moved(pos)` | `true` **la primera vez** que se pasa de umbral y deja de ser pulsación |
| `release()` | `true` si soltar cuenta como click limpio — ni se arrastró ni ya saltó la mantenida |
| `tick(delta)` | `true` **exactamente una vez**, al cumplirse el tiempo y sin soltar |
| `origin()` / `is_pressed()` / `is_dragging()` | estado |

**No conoce eventos ni nodos, y por eso lo usan los dos.** `PanCamera` trabaja en
coordenadas de pantalla dentro de `_unhandled_input`; `MapView` en locales dentro de
`_gui_input`. Se le cuenta lo que pasa y contesta qué significa, así que el mismo gesto se
reconoce igual en el mundo y en el mapa sin copiar el temporizador ni el umbral de arrastre.
Salió de dentro de `PanCamera`, donde estaba enredado con el estado del paneo.

**Potencias de dos, no una escala continua.** Con filtro Nearest, 0,5 descarta exactamente
uno de cada dos píxeles del mundo; un 0,75 descartaría un patrón irregular que hierve en
cuanto la cámara se mueve. Misma regla que la escala de ventana ("entera siempre, nunca
1.5x"), aplicada dentro del juego. Por eso **el cambio es instantáneo y no interpolado**:
una transición suave pasaría medio segundo por zooms fraccionarios.

`step_zoom()` **no da la vuelta** en los extremos — un botón de acercar que alejase del
todo sería una trampa. Y alejarse se corta en 0,5x (1280×768 de mundo visible sobre un
mapa de 2048×1440) a propósito: ver el teatro entero es trabajo del mapa táctico.

**Cerca del borde del mapa la cámara topa con sus límites y la unidad seguida deja de
estar centrada.** No es un fallo: el zoom no puede enseñar más allá del mapa. Medido a los
tres niveles, nada se sale de pantalla.

El arrastre divide por `zoom` (`position -= delta_pantalla / zoom`), así que el mapa sigue
al dedo exactamente a cualquier nivel.

---

### `SelectionManager` — `core/selection/selection_manager.gd`
```
extends Node2D
```
NodePaths exportados: `camera_path`, `hud_path` → resueltos con `get_node()` en `_ready()`.
Coordina selección, órdenes de movimiento y de ataque, el marcador de destino y el menú
contextual. Es el único lugar donde se decide qué significa cada gesto de entrada.

**Flujo de input — el mismo gesto en PC y táctil, sin ramas por plataforma:**
```
click izquierdo / tap → PanCamera.clicked → _on_camera_clicked(pos)
       └─ _handle_click(pos, _find_unit_at(pos))
mapa táctico          → HUD.map_clicked   → _on_map_clicked(pos, unit)
       └─ suelta la cámara; sin nada propio que dirigir → _look_at(pos)
       └─ si no → _handle_click(pos, unit)

_handle_click(pos, unit)
  └─ unidad bajo el punto:
       └─ puedo atacarla (propia seleccionada + hostil) → _issue_attack_order(unit)
       └─ es la ya seleccionada → _select(null)
       └─ si no → _select(unit)
  └─ sin unidad + hay propia seleccionada → _issue_move_order(pos)

click derecho / mantenida → PanCamera.long_pressed      → _on_context_requested(pos)
mapa táctico              → HUD.map_context_requested   → _on_map_context_requested(pos, unit)

_handle_context(pos, unit)
  └─ unidad ajena bajo el punto → _hud.open_target_menu(unit, can_attack)
  └─ si no, y hay propia seleccionada → _issue_move_order(pos)

HUD.attack_requested (del menú) → _issue_attack_order(target)
ESC → cierra el menú + _select(null)
HUD.deselect_requested → _select(null)
HUD.zoom_change_requested(step) → PanCamera.step_zoom(step)
PanCamera.zoom_changed(level, count) → HUD.set_zoom_state(...)
```

**El significado del gesto está separado de quién lo trae.** `_handle_click` y
`_handle_context` reciben ya resuelto qué hay debajo; el mundo lo averigua con
`_find_unit_at()` (física) y el mapa con `MapView.unit_at()` (contra los puntos dibujados).
Cambiar qué significa un click cambia en los dos sitios a la vez, que es justo lo que se
quiere: **el mapa no es otro modo de juego, es la misma partida vista de lejos.**

**Tocar el mapa suelta la cámara** (`_release_camera()`). Sin eso, ordenar desde el mapa deja
la vista pegada a la unidad y el recuadro de cámara se va de paseo con ella mientras lo miras.
Si el click acaba seleccionando a alguien, `_select()` la vuelve a enganchar — eso sí se
quiere. La única excepción del mapa respecto al mundo es que, sin nada propio que dirigir,
pulsar terreno lleva la mirada allí (`_look_at`) en vez de no hacer nada: es para lo que se
abre el mapa.

**Corredor del zoom.** El HUD no conoce la cámara y no debe empezar a conocerla, así que
`SelectionManager` cablea los dos sentidos. Después de conectar **pide el estado inicial a
mano**: la cámara fija su nivel en su propio `_ready()`, antes de que haya nadie
escuchando, y conectarse a una señal no sirve de nada cuando ya sonó.

**`_can_attack(target)`:** propia seleccionada, controlada por el jugador, y hostil al
objetivo. Se comprueba dos veces por diseño — al ofrecer la opción en el menú y otra vez
al ejecutarla — porque la selección puede cambiar entre una cosa y la otra.

**`_find_unit_at(pos)`:** Query `PhysicsPointQueryParameters2D` con `collide_with_areas=true, collide_with_bodies=false`. Devuelve la primer `Unit` bajo el cursor o null — si esa unidad tiene `squad != null`, devuelve `unit.squad.leader` en su lugar (click en cualquier integrante de un escuadrón selecciona al líder, no al que se clickeó).

**`_select(unit)`:**
1. Llama `set_selected(false/true)` en la unidad anterior/nueva
2. Desconecta/conecta `attack_target_changed` de la unidad para seguir su recuadro de objetivo (`_mark_target`)
3. Actualiza HUD: `show_selected_unit` / `clear_selected_unit`
4. Asigna `_camera.follow_target`

**`_mark_target(target)`:** enciende/apaga `set_targeted()` en la unidad marcada como
objetivo de la selección actual. Ver la nota de `Unit` sobre objetos liberados — tiene la
misma trampa resuelta con la misma regla.

**`_issue_move_order(target)`:** portero único de "el enemigo no recibe órdenes"
(`is_player_controlled()`) — cubre tanto el click derecho como el izquierdo en vacío, así
que basta un solo `if`. Reasigna `_order_unit`, llama `receive_move_order`, planta el
`_move_marker` y conecta `order_fulfilled` con `CONNECT_ONE_SHOT` si la unidad la tiene.

**`_issue_attack_order(target)`:** vuelve a comprobar `_can_attack` (ver arriba), llama
`receive_attack_order` y **retira el marcador de destino** (`_clear_move_order()`):
atacar cancela la orden de movimiento, así que su marcador ya no señala nada y dejarlo
puesto hace creer que el avión sigue yendo a ese punto.

**`_on_order_fulfilled`:** limpia `_order_unit`. Al **cumplirse** la orden el marcador
**no se oculta** — se queda donde se pidió el punto, como referencia de vuelo. Sólo
desaparece si otra orden lo sustituye.

---

### `MoveMarker` — `core/selection/move_marker.gd`
```
extends Node2D
```
Creado dinámicamente por SelectionManager en `_ready()`, añadido a `current_scene` de
forma diferida (`.call_deferred()` — en `_ready()` la escena todavía se está montando y
Godot rechaza el `add_child` directo). Dibuja: círculo (radio 8) + cruz, color accent con
85% alpha. Persiste tras cumplirse la orden — no se oculta solo.
**IMPORTANTE:** llama `queue_redraw()` en `NOTIFICATION_VISIBILITY_CHANGED` — sin esto `_draw()` no se ejecuta al hacer `show()`.

---

### `TargetMenu` — `ui/hud/target_menu/target_menu.gd`
```
extends PanelContainer
```
Menú contextual sobre una unidad ajena: Atacar (si se puede) / Información / Cerrar. Se
abre con click derecho en PC o **pulsación mantenida** en táctil — el click/tap izquierdo
queda libre para atacar directamente, que es la acción frecuente.

| Método / Señal | Descripción |
|---|---|
| `open(target, screen_position, can_attack)` | Reconstruye las opciones. `can_attack` lo decide quien llama — el menú no sabe si hay selección propia ni hostilidad |
| `close()` | |
| `current_target()` | |
| `attack_requested(target)` | El jugador tocó "Atacar" |
| `info_requested(target)` | El jugador tocó "Información" — hoy `HUD` lo traduce en seleccionar la unidad |

Se coloca junto a la unidad con un offset, siempre dentro de pantalla (`clampf` contra
`get_viewport_rect().size` menos su propio tamaño) — pegado a un borde se saldría y
dejaría opciones inalcanzables. Como el tamaño no es fiable hasta que el contenedor se
recoloca, `open()` espera un `process_frame` antes de posicionarse.

---

### `LHD Wasp` — `core/unit/lhd_wasp/`

**`lhd_wasp.gd`:**
```gdscript
extends Unit
@onready var flight_deck: Node = $FlightDeck
```
`unit_name` = "LHD Wasp" — esta string es la key que usa `HangarWindow` en `PlayerFleet.get_loadout()`.

**Árbol de `lhd_wasp.tscn`:**
```
Area2D (Unit)
├── CollisionShape2D
├── SelectionIndicator
├── Sprite2D
├── FlightDeck (Node2D)
│   ├── Elevator1, Elevator2       (Marker2D)
│   ├── TakeoffPoint1..4           (Marker2D)
│   └── LaunchPoint                (Marker2D)
```

---

### `FlightDeck` — `core/unit/lhd_wasp/flight_deck.gd`
```
extends Node2D
```
Gestiona el ciclo de cubierta: Elevador → Taxi → Despegue → entrega de control.
**No vuela aviones.** Al terminar la carrera de proa suelta el avión y no vuelve a tocarlo.

**Exports clave:**
- `taxi_speed`, `elevator_cycle_time`, `launch_delay`
- `post_bow_distance`, `climb_duration`

**La cubierta no tiene velocidad de despegue propia.** Se la pregunta al avión
(`Unit.get_takeoff_speed()`, que el Harrier resuelve como su `min_speed`) y con ella
calcula la carrera. Tenerla costó un bug: `takeoff_speed` valía 120 contra un avión
que vuela a 90 como mucho, así que el piloto lo recortaba en silencio al recoger el
control y el avión "frenaba" al soltar amarras — y encima la animación de la pista
estaba cronometrada con una velocidad que el avión nunca llegaba a volar.

**La carrera de pista es una aceleración constante de verdad.** `EASE_IN` +
`TRANS_QUAD` desde parado recorre `runway_dist` en `2 × runway_dist / launch_speed`
y llega a proa exactamente a `launch_speed`: el factor 2 es la media de una rampa
lineal, no un número a ojo.

**Estado interno:**
- `_occupied[4]`, `_units[4]` — slots de cubierta
- `_taxi_queues[2]` — cola por elevador

**API pública:**
- `request_deploy(scene: PackedScene, squad: Squad = null) → bool` — inicia ciclo de despliegue; si se pasa `squad`, el avión se suma a ese `Squad` al spawnear (ver `Squad` más arriba)
- `has_free_slot() → bool`

**`_hand_over_control(unit)`:** Si la unidad tiene `start_flight()`, se la llama pasándole el barco como centro de órbita. El piloto arranca a su `min_speed`, que es justo la velocidad a la que la cubierta lo soltó: el relevo no se nota. A partir de ahí el avión se pilota solo.

**Lo que no despega por pista** (`get_takeoff_speed()` a 0) se salta la carrera de proa pero
**también recibe el control**, sólo que posado en su punto. Su plaza no se da por libre ahí:
`_free_slot_when_airborne()` la mantiene ocupada hasta que el aparato avise con `took_off`, o el
siguiente taxiaría hasta el mismo sitio y se le montaría encima. La conexión se hace **al crearlo**,
no al soltarlo, porque la orden de salir puede llegar mientras todavía lo están colocando.

---

### Vuelo — `core/unit/flight/`

Dos responsabilidades separadas, ambas `Node` colgando de la escena del avión.
Se sustituyeron al steering que antes vivía repartido entre `flight_deck.gd` y
`av8b_harrier.gd` (ver `decisions.md`, 2026-08-01 (3)).

#### `PlaneController` — `plane_controller.gd`
Decide **cómo** vuela: velocidad, viraje, inercia. No sabe a dónde va.
Mueve al nodo padre desde `_physics_process`. Arranca inactivo.

| Señal | Cuándo |
|-------|--------|
| `target_reached` | Entró en `arrive_radius`, o rebasó el destino dentro de su radio de giro |
| `committed(side)` | Se comprometió a virar por un lado (−1 izq, +1 der) |

| Grupo | Exports |
|-------|---------|
| Velocidad | `min_speed` (70), `max_speed` (150), `acceleration` (90), `brake_in_turns` |
| Giro | `turn_radius` (130), `fine_gain`, `turn_inertia` (2), `velocity_align` |
| Compromiso | `release_deg` (22), `reengage_deg` (45), `dead_circle_hysteresis` (1.12) |
| Navegación | `arrive_radius` (40), `flyby_capture`, `sprite_offset_deg` (−90) |
| Alabeo | `bank_sprite_path` (opcional, `AnimatedSprite2D` de 5 frames) |

**API:** `enable()`, `disable()`, `set_target(pos)`, `update_target(pos)`, `clear_target()`, `set_cruising(bool)`, `current_turn_rate()`, `min_turn_radius()`.

**El viraje se parametriza por RADIO, no por grados/segundo.** `turn_radius` es el ancho
del círculo que traza el avión virando a tope, y `current_turn_rate()` sale de dividir:
`speed / turn_radius`. Antes era al revés — `base_turn_deg` mandaba y el radio se
deducía — y eso hacía que **volar más lento cerrase el viraje**, justo lo contrario de
lo real. Con `min_speed` 75 y `max_speed` 90 el radio efectivo era de 41 px: el sprite
mide 32, así que el avión pivotaba sobre sí mismo como un coche teledirigido. Ahora un
avión al ralentí traza el mismo círculo, sólo que tardando más en recorrerlo, y subir
`max_speed` **no** abre el viraje. Mismo criterio que en `GuidedMissile` y `GlideBomb`,
que ya llevaban `min_turn_radius`.

**Dos regímenes de velocidad y un interruptor, no un techo numérico.** `cruising` (bool)
elige entre `min_speed` y `max_speed`; `acceleration` hace la transición y es lo único
que separa un cambio creíble de un tirón (medido: rampa completa con 1 % de desvío
sobre el teórico, o sea que nadie salta la velocidad a mano). El piloto sólo obedece:
quién lo pone es de quien manda al avión.

**Lo normal es ir despacio.** `cruising` arranca en `false` y `enable()` lo devuelve ahí:
`min_speed` es el estado de reposo — despegue, circuito de espera, alineación de tiro —
y `max_speed` la excepción, sólo mientras hay una orden que cumplir. Al revés (crucero
por defecto, frenar bajo petición) el avión despegaba acelerando a tope para frenar
inmediatamente al entrar en el circuito.

Esto sustituyó a `speed_limit`, un techo en px/s que cada comportamiento fijaba a mano.
Acabó como tenía que acabar: `AttackRunBehavior.attack_speed` valía 90, exactamente la
`max_speed` del Harrier, así que "frenar para atacar" no frenaba nada y nadie se enteró.
Un número absoluto en otro script duplica el rango de velocidades del avión y se
desincroniza en cuanto se toca. El interruptor no puede.

`set_target` replantea el viraje desde cero; `update_target` corrige el punto
sin soltar el compromiso en curso — para objetivos que se mueven.

**Compromiso de viraje:** una vez elegido el lado no se replantea hasta bajar de
`release_deg`. Es lo que evita el amague. Tiene dos salvaguardas:
- **Círculo muerto:** si el destino cae dentro del círculo de giro, virar hacia él
  sólo daría vueltas a su alrededor para siempre. Se nivela y se sale recto hasta
  que la geometría permita enfilarlo. Invertir el viraje en su lugar produce
  oscilación — se probó y se descartó.
- **`flyby_capture`:** da por alcanzado un destino ya rebasado si está dentro del
  radio de giro. Sin esto el avión, que no puede frenar, da un bucle completo.

**Orientación:** `sprite_offset_deg` traduce rumbo → rotación del sprite.
El arte del Harrier apunta a **+Y local** (abajo), de ahí el −90.

#### `HelicopterController` — `helicopter_controller.gd`
```
extends Node   class_name HelicopterController
```
El piloto del helicóptero. Mismo papel que `PlaneController` —decide **cómo** se mueve, no a
dónde va— y **cero código compartido con él**, a propósito: aquél está construido sobre el radio
de giro y aquí no hay radio de giro que valga.

**Dentro hay un mando, no una trayectoria.** `_stick` (adelante/atrás y costados, en ejes del
propio aparato) y `_pedal` (el giro), que son las dos manos con las que se lleva un helicóptero
en cualquier juego. La velocidad sale de la física de esos ejes.

**Los ejes no valen lo mismo**, y eso es medio carácter: `forward_speed` 85, `strafe_speed` 38,
`back_speed` 28. Recular es incómodo, que es lo que empuja a girar en vez de irse de espaldas
medio mapa.

**El rumbo va aparte de la traslación.** `_wanted_heading` se ata al destino sólo si está a más
de `face_range`; más cerca se entra de lado sin girar (medido: punto a 49 px por detrás, **0
grados** de giro). Es la separación que permitirá, cuando haya armamento, apuntar al blanco
mientras el aparato se desplaza de costado.

**Llega exacto.** Cada eje pide la velocidad que le deja pararse en lo que falta (`v² = 2·a·d`) y
el mando es analógico, así que se planta en el punto en vez de pasarse y volver: 40 de 40 órdenes
al azar terminan a menos de **1,5 px**. Hubo una versión con un piloto torpe —frenada mal
calculada, mando a golpes, morro desviado— y se quitó entera; ver `decisions.md`, 2026-08-13.

**Estados** (`state_changed`, y el controlador **no toca ningún sprite** — de aquí colgarán las
animaciones de hélice, vuelo y despegue):

| estado | qué es |
|---|---|
| `GROUNDED` | posado en cubierta; ni se mueve ni obedece hasta que se le ordene salir |
| `LIFTING` | subiendo en vertical, `lift_time`. Hoy sólo una espera: no hay nada que dibujar |
| `FLYING` | de camino a un punto |
| `HOVER` | llegó, y ahí se queda con el morro donde iba |

| señal | cuándo |
|---|---|
| `target_reached` | llegó al punto |
| `state_changed(state)` | cambió de fase |
| `took_off` | dejó la cubierta — lo escucha el barco para dar la plaza por libre |

| export | por defecto | qué es |
|---|---|---|
| `forward_speed` / `strafe_speed` / `back_speed` | 85 / 38 / 28 | tope de cada eje, px/s |
| `acceleration` / `deceleration` | 60 / 55 | px/s². La segunda decide además cuándo empieza a frenar |
| `yaw_speed_deg` | 100 | giro sobre sí mismo a fondo. En grados y no en radio: pivota parado |
| `yaw_ramp_time` | 0,45 s | lo que tarda la cola en coger y soltar el giro |
| `yaw_deadzone_deg` | 1,5 | por debajo no se pelea con el último grado |
| `stick_delay` | 0,25 s | pedal antes de cíclico. Lo único que se hace esperar |
| `face_range` | 70 px | por debajo no gira para encarar: entra de lado |
| `axis_deadzone` | 1,5 px | desvío por eje que ya no se corrige |
| `arrive_radius` / `settle_speed` | 3 px / 12 px/s | llegar es estar cerca **y** lento, no cruzar el punto de paso |
| `lift_time` | 1,6 s | el despegue vertical |
| `sprite_offset_deg` | −90 | el arte apunta a +Y, como todo en el proyecto |

**API:** `enable()` / `disable()`, `set_target()` / `clear_target()`, `get_state()`,
`is_airborne()`.

`enable()` recoge el aparato **posado** y, si ya le habían ordenado un punto mientras el barco lo
colocaba, sale a cumplirlo en vez de olvidarlo. `set_target()` estando en `GROUNDED` es también
la orden de despegar.

#### `Countermeasures` — `countermeasures.gd`
```
extends Node   class_name Countermeasures
```
Chaff y bengalas: lleva la cuenta y **las suelta solo** cuando le viene un misil. Se engancha al
`missile_inbound` de su propia unidad y va soltando con un respiro entre soltada y soltada hasta
que el misil se pierde o impacta. No pide permiso a nadie.

| señal | cuándo |
|---|---|
| `spent(kind, left)` | se gastó una carga |
| `dispensing_started(threat)` | empieza a soltar — el parte canta `DEFENDING` |
| `dispensing_stopped` | el misil terminó, o no quedan cargas |

| export | por defecto | qué es |
|---|---|---|
| `chaff` / `flares` | 30 / 30 | cargas de cada tipo |
| `decoy_scene` | `decoy.tscn` | qué suelta |
| `interval` | 0,25 s | entre soltada y soltada |
| `per_release` | 1 | cuántos salen de golpe. 2 con apertura = la V clásica |
| `spread_deg` | 60 | apertura del abanico, hacia la cola |
| `behind_px` | 6 | a qué distancia del avión aparecen |
| `inherit_velocity` | 0,35 | cuánto se llevan de la velocidad del avión |

**Va aparte del armamento a propósito:** una contramedida no es un arma — no se elige, no apunta
y no hace daño. Meterla en el `WeaponLoadout` la habría metido en la rotación de armas activas,
y el avión podría acabar "atacando con bengalas".

**El tipo lo decide el arma que te tiran** (`kind_against()`), no una preferencia: contra radar
chaff, contra calor bengalas. Soltar el que no es no engaña a nadie. Hoy sólo hay misiles de
radar, así que las bengalas no se gastan nunca.

`dispensing_started` se emite **diferido**: cuelga del mismo aviso que el registro de eventos y
se conecta antes que él, así que emitirlo en el acto cantaba `DEFENDING` antes que `SAM LAUNCH`.

---

#### `Decoy` — `decoy.gd`
```
extends Node2D   class_name Decoy
```
Una nube de chaff o una bengala en el aire. Vive en el mundo, no colgada del avión. Grupo
`decoys`, para que los buscadores lo encuentren sin conocer a quien lo soltó.

Exports: `kind`, `lifetime` (2,6 s), `fade_fraction`, `drag`, y `peak_strength` / `bloom_time`,
que describen cuánto "brilla" y cuánto tarda en abrirse.

> ⚠ **`strength()` ya no decide nada.** Se escribió cuando el engaño se resolvía simulando, y
> ese modelo se descartó (ver `decisions.md`). Hoy quien decide es la tirada del lanzamiento;
> esto queda como dato descriptivo por si vuelve a hacer falta.

Se dibuja con `_draw()` porque todavía no hay arte. Cuando lo haya, conviene que el dibujo viva
en la escena y el script sólo mueva, como `Casing` y `Tracer`.

---

#### `OrbitBehavior` — `orbit_behavior.gd`
Decide **a dónde** va cuando no hay órdenes: vueltas alrededor de un centro.

| Señal | Cuándo |
|-------|--------|
| `center_reached` | Llegó al punto que ordenó el jugador; a partir de ahí orbita ahí |

| Export | Default |
|--------|---------|
| `radius` | 330 px — a qué distancia del barco esperan |
| `clockwise` | false |
| `pilot_path` | `../PlaneController` |

**API:** `orbit_around(node)` (centro móvil, el barco), `orbit_at(pos)` (orden del
jugador: va al punto y luego orbita ahí), `has_pending_order()`, `stop()`.

`has_pending_order()` = está yendo a un punto que ordenó el jugador. Lo consulta
`Av8bHarrier.start_flight()` para no pisar una orden dada mientras el avión estaba en
cubierta — evita duplicar el punto ordenado en otra variable sólo para poder preguntarlo.

**No hay ninguna figura impuesta.** Cada frame se le señala al piloto el punto del
círculo que corresponde a **dónde está el avión ahora** respecto al barco, corrido un
poco hacia adelante en el sentido de giro. Por dentro o por fuera, ese punto le queda
hacia el círculo y entra; ya encima, le queda por delante y lo recorre. Converge desde
cualquier sitio y con cualquier radio de giro, porque no le impone una curva: le dice
dónde tiene que estar y la vuelta sale de su propio viraje.

**Sigue al barco gratis:** el centro se relee de `_center_node.global_position` cada
frame, así que el circuito navega con el LHD sin código de seguimiento.

**El adelanto sale del viraje del avión** (`1.5 × min_turn_radius() / radio`), no de un
número fijo. Hay que dejarle sitio para llegar girando, y ese sitio crece con lo abierto
que vire.

**El circuito tiene suelo: `max(radius, 2.5 × min_turn_radius())`.** Es la lección cara
de esta sección. Un círculo más apretado que eso es **imposible de rodear**: cada punto
cae dentro del propio giro del avión, el piloto endereza en vez de virar (círculo
muerto), se abre, y acaba encerrado dando vueltas donde no debe — pegado a la proa, en
el corredor de despegue. Con el suelo puesto, tocar `turn_radius` ya no rompe el
circuito.

**Reposo, no crucero:** `orbit_around()` pone `set_cruising(false)` — esperar se hace a
`min_speed`. `orbit_at()` sí mete gas, porque ir a un punto ordenado es una orden; lo
suelta al llegar.

Waypoints discretos no funcionan aquí: un avión que no puede frenar nunca "llega"
a un punto que tiene al costado — se queda orbitándolo.

Medido en headless (1.00 = clavado en el círculo): 0.93 con el avión de radio 130, 1.02
con radio 50, 1.01 con el barco navegando a 25 px/s.

**Dos límites conocidos:**
- Con `turn_radius` 130 el suelo da un circuito de 660 px de diámetro, **más ancho que
  la pantalla** (640). Es consecuencia directa del radio de giro: un avión que vira así
  no puede rodear nada más pequeño. Para meterlo en pantalla hay que bajar `turn_radius`.
- Si el barco navega a más de ~1/3 de la `max_speed` del avión, el avión no mantiene el
  circuito y queda rezagado (a 45 px/s contra 90 de máxima, se rompe).

**Lo que había antes y por qué se fue:** una elipse (`semi_x`/`semi_y`) con una fase
propia (`_phase`) que avanzaba sola y se enganchaba parcialmente a la posición del avión
(`sync_rate`, `center_deadzone`, `lead_deg`). Funcionaba mientras el avión virase mucho
más cerrado que el óvalo — con el radio efectivo de 41 px lo hacía. Al pasar el viraje a
130 px se rompió: el punto se le escapaba y el avión cortaba por dentro, quedando
atrapado en un círculo de su propio radio. Se midió que **ningún parámetro lo
arreglaba** — `lead_deg`, `sync_rate`, `fine_gain`, `turn_inertia` y el tamaño del óvalo
(probado hasta 500×600) no movían la aguja; sólo `turn_radius`. Era un fallo de diseño,
no de ajuste.

#### `AttackRunBehavior` — `attack_run_behavior.gd`
Decide **a dónde** va cuando ataca a alguien. Sustituyó a `ChaseBehavior` (perseguir sin
más): un avión armado no se pega al blanco, hace pasadas. **Hermano de `OrbitBehavior`**,
no una rama dentro de él — los dos le dan puntos móviles al mismo `PlaneController`, y
por eso nunca deben procesar a la vez; quien recibe la orden (`Av8bHarrier`) es quien
para uno al arrancar el otro.

**Quien manda aquí es el arma**, pero este nodo **no sabe de armas**: recibe la
envolvente ya resuelta. Ciclo de dos fases:

| Fase | Qué hace | Cuándo cambia |
|------|----------|---------------|
| `INGRESS` **sin enfilar** | Encara el blanco corrigiendo el punto cada frame | Al enfilar (pasa a comprometido), o al llegar a `min_range × break_off_margin` |
| `INGRESS` **comprometido** | Vuela **recto**: el destino ya no se toca | Al llegar a `min_range × break_off_margin`, o al disparar (`break_off()`) |
| `EGRESS` | Se aleja recto hacia un punto de fuga fijado al romper | Al alcanzar la distancia de reencare |

| Señal | Cuándo |
|-------|--------|
| `target_lost` | El objetivo dejó de ser válido (murió). Se apaga a sí mismo **antes** de emitirla, para que quien escuche pueda darle otra orden al avión sin que este nodo se la pise en el frame siguiente |
| `attack_run_started` | Enfiló y se lanza: empieza la pasada recta. **Única ventana en la que tiene sentido tirar** |
| `attack_run_ended` | Se acabó la pasada (rompió, perdió el blanco o le quitaron la orden). Lo que venga después es maniobra, no ataque |

| Export | Default | Uso |
|--------|---------|-----|
| `break_off_margin` | 1.2 | Corta la pasada ese % antes del alcance mínimo |
| `reengage_fraction` | 0.85 | Fracción del alcance máximo a la que vuelve a encarar |
| `separation_gain` | 1.15 | Separación mínima al romper, relativa a **dónde** rompió |
| `egress_overshoot` | 1.3 | Cuánto más allá del reencare apunta el punto de fuga |
| `turn_around_margin` | 4.5 | Separación mínima antes de reencarar, **en radios de giro del avión** |
| `aim_tolerance_deg` | 6.0 | Desvío máximo del morro para dar la pasada por enfilada |
| `strafe_overrun` | 600.0 | Cuánto más allá del blanco vuela la pasada comprometida |
| `pilot_path` | `../PlaneController` | |

**La pasada se compromete y deja de corregir.** Mientras encara, el nodo va llamando a
`update_target(blanco)` cada frame. En cuanto el morro entra en `aim_tolerance_deg` **y**
ya está dentro del alcance, `_commit()` cambia el destino por un punto a
`distancia + strafe_overrun` en la línea actual avión→blanco, y **no se vuelve a tocar**.
El avión atraviesa el objetivo y sigue, que es lo que hace un avión ametrallando.

Corregir frame a frame hasta el final era lo que hacía que el avión culebrease encima del
blanco: cada corrección movía el morro, el blanco entraba y salía del cono de tiro, y la
"pasada" salía a tirones. Medido antes y después, con el morro tomado como desvío al
blanco durante la ráfaga:

| | pasada 1 | pasada 2 | pasada 3 |
|---|---|---|---|
| corrigiendo | 54 daño | 18 | 10 |
| comprometido | 37.7 (morro ±0.0°) | 34.5 (−2.7°/+0.9°) | 27.8 (−0.9°/+2.8°) |

Menos daño de golpe en la primera, pero las tres pasadas abren fuego en el borde del
alcance (~418 px) y el morro se mueve **menos de 3°** en toda la ráfaga. El tanque muere
en 3 pasadas en vez de estancarse.

**El punto de la pasada va lejos, no sobre el blanco.** Puesto encima, el avión intentaría
llegar exactamente ahí y acabaría dando vueltas sobre el objetivo — el mismo problema del
circuito de espera, y por el mismo motivo (`arrive_radius` y el radio de giro).

**El reencare tiene suelo, y es la misma lección que el circuito de espera.**
`_reengage_distance()` sale del alcance del arma, pero nunca baja de
`turn_around_margin × min_turn_radius()`: hay que separarse lo bastante **para poder
darse la vuelta**. Sin ese suelo un arma de corto alcance deja al avión atrapado — el
cañón rompe a 180 px y reencaraba a 297, o sea 117 px para invertir el rumbo con un radio
de giro de 130. Llegaba torcido a cada pasada: medido, la primera quitaba 54 y las
siguientes de 1 a 4. Con el suelo puesto: 54, 39, 6 y muerto.

Con un arma de largo alcance el suelo no se nota (el Maverick reencara a 850 y el suelo
son 585), así que sólo actúa donde hace falta. Una distancia fija que no sabe nada del
viraje del avión se rompe en cuanto el viraje cambia.

**Subió de 3.0 a 4.5 al llegar la pasada comprometida**, y por una razón que sólo se ve
midiendo: el avión se estaba **alineando dentro del alcance del arma**. Reencaraba a
390 px, llegaba de la vuelta todavía torcido y no enfilaba hasta ~300 px — con la ruptura
en 264, le quedaban **36 px de ventana de fuego**. Con 585 px de separación llega enfilado
de sobra y abre fuego en el borde de la envolvente, que es donde toca. La separación no
sólo tiene que dar para girar: tiene que dar para girar **y salir apuntando**.

**API:** `engage(target, min_range, max_range)`, `set_envelope(min, max)`, `break_off()`, `stop()`.

`engage()` y cada reencare usan `set_target()` del piloto (destino nuevo, replantea el
viraje desde cero); mientras encara se corrige con `update_target()` sin soltar el
compromiso, igual que `OrbitBehavior` con su punto. `_commit()` también usa
`update_target()`: el rumbo ya es prácticamente el de la pasada, y replantear el viraje
desde cero justo al enfilar sería pegar un tirón en el peor momento posible.

**El gas es una consecuencia de la fase, no un ajuste.** `_set_throttle()` suelta gas en
un único caso — INGRESS y ya dentro del alcance del arma —, que es cuando hay que
alinearse para tirar y cada segundo en parámetros es otra ocasión de disparar. Fuera de
ahí mete gas: llegar cuanto antes a la envolvente, y romper cuanto antes tras soltar el
arma. No existe ninguna velocidad "de ataque" configurable: la lenta es la `min_speed`
del propio avión (ver `PlaneController`, por qué se fue `attack_speed`).

**…y hay armas que no piden frenar.** `set_envelope()` recibe también `slows_to_aim`, por
el mismo canal que las distancias y por la misma razón: es una propiedad del arma traducida
a vuelo, y este nodo sigue sin saber de armas. Una bomba tonta viene alineándose desde lejos
y no tiene nada que afinar al final — frenar encima de un blanco para soltarla es la peor
forma posible de hacerlo, y es el ataque en el que más se expone el avión.

**`separation_gain` existe por un bug real:** romper justo en el borde del alcance máximo
no servía de nada, porque la condición de reencarar ya estaba cumplida en el mismo frame
y el avión seguía metiéndose. La separación tiene que ser relativa a dónde se rompió, no
sólo al alcance del arma.

**`max_range` a 0** (unidad sin arma) = se comporta como el viejo perseguir: va derecho,
que es lo único sensato sin envolvente que respetar.

---

#### `DogfightBehavior` — `dogfight_behavior.gd`
```
extends Node   class_name DogfightBehavior
```
Decide **a dónde** va el avión cuando pelea contra otro avión. Cuarto hermano de
`OrbitBehavior` y `AttackRunBehavior`: los tres le dan puntos al mismo piloto y nunca corren a
la vez. El Harrier elige entre pasadas y duelo **según el dominio del blanco**.

**Existe aparte porque mezclarlo con las pasadas fue un bug real:** contra tierra el avión
suelta el arma y **rompe** —correcto, un tanque no te persigue—, y eso dejaba al Harrier
alejándose cada vez que soltaba un AMRAAM. Aquí no se rompe nunca: se dispara y se sigue
maniobrando.

**Lo que manda es el ángulo, no la distancia.** No vuela hacia el enemigo: vuela hacia el punto
que lo pone **detrás** de él. Como ese punto se mueve con el blanco, perseguirlo produce solo
las persecuciones circulares de un dogfight, sin programar ninguna maniobra. Y decide quién gana
sin reglas extra: el que vira más cerrado cierra por dentro, así que **el radio de giro decide
también el combate aéreo**.

**A dónde ir lo dice el arma**, no una regla fija:

| arma activa | destino |
|---|---|
| entra por donde sea (radar) | el punto de intercepción — se vuela derecho y se dispara mientras se cierra |
| necesita la tobera (calor, cañón) | la cola del enemigo |

| export | por defecto | qué es |
|---|---|---|
| `saddle_distance` | 120 | a qué distancia por detrás se pone la posición de tiro |
| `lead_time` | 0,6 s | cuánto se adelanta al movimiento del enemigo |
| `overshoot_guard` | 70 | por debajo de esto deja de cerrar, para no pasársele |

Gas siempre a tope: en un duelo la energía es media posición, y frenar para apuntar —lo que se
hace contra tierra— aquí es regalar el ángulo.

---

### Armamento — `core/weapon/`

Tres niveles, separados a propósito: qué es un arma, qué se monta en una salida, y
cómo se dibuja.

**`WeaponType`** (`weapon_type.gd`, `extends Resource`) — definición compartida de un
arma. Existe un `.tres` por tipo (`aim9_sidewinder`, `aim120_amraam`, `agm65_maverick`,
`mk82`, `gbu54`) y los loadouts lo referencian en vez de copiarlo, así el nombre y el
icono no se desincronizan entre misiones.

| Grupo | Export | Uso |
|-------|--------|-----|
| — | `display_name` | String |
| — | `short_name` | Para los botones de `WeaponBar`, donde caben ~6 caracteres |
| — | `brevity_code` | Código OTAN que se canta al soltarla, para el `EventLog` |
| — | `icon` | Texture2D (`AtlasTexture` sobre `Jet_bombs_missiles.png`) |
| Objetivos | `targets` | Flags Aire / Superficie. Contra qué sirve |
| Alcance | `min_range`, `max_range` | Envolvente de tiro. Debajo del mínimo el arma aún no se estabilizó; encima del máximo se queda sin combustible |
| Alcance | `firing_arc_deg` | Cuánto puede estar el blanco fuera del morro para poder tirar |
| Alcance | `air_min_range` / `air_max_range` | Envolvente **sólo contra lo que vuela**. −1 = usa la de siempre |
| Alcance | `max_aspect_deg` | Desde qué parte del blanco hay que atacarlo, medido **desde su cola**. 180 = por donde sea |

**`air_min_range` / `air_max_range` no son un capricho: el cañón necesita las dos.** Contra un
tanque quieto se ametralla de 220 a 420 px; contra un avión, de 40 a 150. El mínimo, porque a
quemarropa en un duelo es lo único que queda. El máximo, porque con 420 **llegaba más lejos que
el AIM-9** y el avión se ponía a los tiros a 400 px en vez de tirar el misil.

Antes esto se resolvía con un solo número de compromiso, y ataba las dos cosas: cambiarlo para
el aire movía el alcance, **la distancia a la que rompe la pasada en tierra y hasta la
puntería**, sin que nadie tocara nada de tierra. Ver `decisions.md`.

**`max_aspect_deg` es lo que da forma al combate aéreo.** El AIM-9 pide 60° porque busca la
tobera; el AMRAAM entra por donde sea. Así el arma decide la geometría del vuelo: si puede
disparar de frente se vuela derecho, y sólo se va a buscar la cola cuando el arma lo exige.
**Sólo cuenta contra blancos aéreos** — un tanque no tiene cola táctica, y exigirlo dejaría al
cañón sin disparar contra tierra salvo llegando justo por detrás.

Métodos: `in_range_against(distance, domain)`, `min_range_against(domain)`,
`max_range_against(domain)`, `needs_rear_aspect()` y `aspect_to(shooter, target)` (estático).
| Daño | `damage`, `blast_radius` | 0 de radio = sólo daña lo que toca |
| Lanzamiento | `projectile_scene` | Qué se instancia al disparar |
| Lanzamiento | `salvo_size` | 1 = de una en una; **0 = todo lo que quede** |
| Lanzamiento | `salvo_spread` | Radio de dispersión del punto de apuntado de cada arma de la andanada |
| Lanzamiento | `salvo_interval` | Segundos entre una arma y la siguiente **dentro** de la andanada. 0 = todas a la vez |
| Lanzamiento | `reload_time` | Segundos entre andanadas |
| Lanzamiento | `slows_to_aim` | Si el avión frena para alinearse con esta arma |

**`salvo_spread` sólo aplica a armas que apuntan.** Dispersa el *punto de apuntado*, y una
bomba tonta no tiene punto de apuntado: cae donde la deja la inercia. Su dispersión está en
la escena de la bomba, porque lo que varía es **cómo se desprende cada una**, no a dónde
apunta. Por eso la Mk-82 lo lleva a 0 y no está roto.

**`slows_to_aim` es del arma, no del avión**, por lo mismo que `fire_mode`: qué exige el
arma de quien la lleva. El cañón sí (hay que apuntar y la pasada es larga); una bomba tonta
no (viene alineándose desde lejos y lo que necesita es cruzar rápido y salir de ahí).

**El código de brevedad va en el arma, no en una tabla del registro.** Es parte de lo que el
arma *es*: un arma nueva lo trae puesto y nadie tiene que acordarse de añadirla a una lista
aparte. Puestos hoy: AGM-65 `Rifle`, AIM-9 `Fox Two`, AIM-120 `Fox Three`, GAU-12 `Guns`,
Mk-82 y GBU-54 `Pickle`. Vacío = el parte sólo dice el nombre.

`get_short_name()` cae al nombre largo si el corto está vacío.
`can_engage_domain(domain)` e `in_range(distance)` responden las dos preguntas que hace
`WeaponSystem` antes de disparar. El cañón (`gau12_cannon.tres`) es un `WeaponType` más,
sin icono ni `projectile_scene`: no cuelga de ninguna estación y no instancia nada al
disparar — es `SUSTAINED` y reparte el daño por geometría.

**Las cifras de combate están aquí y las de vuelo en la escena del proyectil.** Así la
misma escena de misil sirve para dos armas con pegada distinta, y la cifra que se
enseñaría en el hangar es exactamente la que se aplica. Valores del AGM-65: superficie,
300–1000 px, arco 25°, daño 120, radio 20, de uno en uno, recarga 1,5 s. Del GAU-12: todos
los dominios, 220–420 px, arco 10°, daño 0,62 por bala × 60 balas/s, munición ilimitada.

**`WeaponMount`** (`weapon_mount.gd`, `extends RefCounted`) — un tipo de arma sobre un
grupo de estaciones simétricas. `weapon: WeaponType`, `stations: PackedStringArray`
(ids como `"L2"`, `"R2"` — no nombres de marker), `per_station: int`, `remaining: int`.
`total()` suma todas las estaciones del grupo; `spend()` descuenta una; `clone()` da una
copia cargada al completo.

`per_station` es **dato de munición, no de dibujo**: una estación con 3 Mk-82 lleva 3
aunque en pantalla quepa una sola. `remaining` es estado de **una salida concreta**, no
del catálogo — por eso los loadouts se clonan antes de colgarlos de un avión.

**`WeaponLoadout`** (`weapon_loadout.gd`, `extends RefCounted`) — el armamento completo
de una salida: `display_name` + `mounts: Array[WeaponMount]` + `default_weapon`. Única
fuente de verdad — el HUD saca de aquí el resumen y el `HardpointRack` los sprites, así
que no hay dos cifras que puedan discrepar.

**El mismo objeto hace de dos cosas según quién lo tenga:** en `PlayerFleet` es un
CATÁLOGO —qué configuraciones existen— y en un avión es su carga real con la munición
que le queda. Son incompatibles, así que `Unit.set_weapon_loadout()` guarda un `clone()`.
`ammo_of(w)`, `spend(w)` y `stations_of(w)` completan la API de munición.

`get_default_weapon()` → con qué arma sale seleccionado el avión. `default_weapon` es
**opcional** (tercer parámetro del `_init`): vacío = la primera montada. Existe para que
la principal no dependa del orden de declaración, que también manda el orden de los
botones y el de la lista del hangar. Si apunta a un arma que no está montada, cae a la
primera. Ninguno de los tres presets del Harrier lo rellena: en los tres la principal ya
es la primera.

**`HardpointRack`** (`hardpoint_rack.gd`, `extends Node2D`) — lo único que sabe dibujar
armas. No conoce misiones ni unidades: recibe un `WeaponLoadout` y lo representa
colgando `Sprite2D` de los `Marker2D` hijos.

| Método | Descripción |
|--------|-------------|
| `apply_loadout(loadout)` | Limpia y vuelve a colgar todo. `null` = desarmado |
| `clear_weapons()` | Borra los sprites colgados |
| `release(weapon)` | Descuelga una y devuelve el `Marker2D` del que salió, o `null` |

`release()` **alterna alas** y se vacía de fuera hacia dentro: como se descarga un avión
de verdad, y para que no quede visiblemente descompensado a mitad de ataque. Cada sprite
lleva su `WeaponType` en un `set_meta`, que es lo único que queda del arma una vez
montada. Si ya no hay sprite que descolgar —la estación llevaba más de las que caben
dibujadas— devuelve igualmente un marker de esa estación: **descolgar el sprite y
descontar munición son cosas distintas**, y el avión sigue teniendo con qué tirar aunque
el ala se vea vacía.

El nombre del marker empieza por el id de su estación — `L2a`, `L2b`, `L2c` son la
estación `L2`. **Mover, añadir o borrar markers en la escena cambia lo que se dibuja
sin tocar código.** Dentro de cada estación las armas se reparten desde el centro (con
un arma y tres markers cuelga del de en medio, no del borde del pylon), y los markers
se ordenan por distancia al eje del avión, no por orden en el árbol: eso es lo que hace
que la posición N signifique lo mismo en las dos alas y las cargas simétricas salgan
simétricas. Si una estación lleva más armas que markers se dibujan sólo las que caben.

**Presets por modelo:** `core/unit/av8b_harrier/av8b_harrier_loadouts.gd`
(`build(available_weapons) → Array[WeaponLoadout]`) define CAS/Antitanque, Bombardeo y
Caza/Interceptor. Viven junto al avión porque las estaciones son propias del modelo.

**Filtrado por armamento disponible:** `build()` devuelve sólo las configuraciones
armables con la lista que recibe — `WeaponLoadout.can_arm_with()` es todo o nada: si
falta un arma, esa misión no se ofrece. La lista vive en `PlayerFleet._available_weapons`,
hardcodeada por ahora igual que el inventario de aeronaves. **Las misiones no armables
no aparecen**: sin avisos ni botones deshabilitados, porque no hay sistema de
compra/desbloqueo que explique la ausencia.

**Recorrido del dato:** `HangarWindow` (el jugador elige misión) → `FlightDeck.request_deploy(scene, squad, loadout)`
→ `Unit.set_weapon_loadout()`, que guarda el loadout **y** busca un `HardpointRack`
entre sus hijos para aplicarlo. Las unidades sin rack lo guardan igual: llevar
armamento y saber dibujarlo son cosas distintas.

**Capas de dibujado** — ver `docs/decisions.md` (2026-08-03). Dentro de una unidad:
`Hardpoints` en z 0, `Sprite2D` en 1, `SelectionIndicator` en 2 (definido en
`unit.tscn`, lo heredan todas). Entre unidades, en el nodo raíz: naval 0, aire 10.
`z_as_relative` está activo, así que los z de dentro se suman al de la raíz — por eso
las armas del Harrier (10) se ven sobre la cubierta del Wasp (1) mientras rueda.

**Límite conocido del pixel art:** las armas miden 10–14 px de largo y la cuerda del
ala donde cuelgan mide 10 px, así que sobresalen de la silueta. Medido, no supuesto.
Ver `docs/decisions.md` (2026-08-02) para las opciones de arte.

#### `Projectile` — `projectile.gd`
```
extends Node2D   class_name Projectile
```
Lo que sale del arma, sea lo que sea. Aquí está sólo lo que **todos** comparten: de
dónde salieron, a qué apuntan y qué pasa al explotar. Cómo vuelan lo pone cada subclase.

| Miembro | Descripción |
|---------|-------------|
| `launch(shooter, muzzle, at, weapon, aim_offset)` | **Virtual.** Las subclases llaman `super()` y arrancan su vuelo |
| `detonate()` | Reparte daño, emite `detonated(where)` y se libera |
| `time_to_impact()` | Segundos al ritmo actual, −1 si no se puede saber |
| `guides()` | **Virtual, `false` por defecto** — ¿persigue al blanco, o cae donde caiga? |

**Cuidado al añadir un proyectil nuevo:** `guides()` devuelve `false` salvo que se sobrescriba
—lo normal es caer, guiar es la excepción—, y de él depende que haya cuenta atrás de impacto.
Un proyectil que persiga y no lo declare saldrá sin contador y no habrá pista de por qué. Lo
declaran `GuidedMissile` y `GlideBomb`; `BallisticBomb` no, y es correcto: una bomba tonta no
promete impacto y poner un número sobre el blanco fingiría una puntería que no tiene.
| `get_speed()` | **Virtual** — px/s. Cada tipo sabe la suya |
| `direct_hit_radius` | Export. Por debajo, daño completo |

`muzzle` es la estación del ala, no el centro del avión. `aim_offset` desvía el punto de
impacto: es lo que convierte una andanada en un área batida. `_aim_point` guarda el
último sitio donde se vio al blanco — si muere a mitad de vuelo el proyectil no se
entera y sigue hasta ahí.

**El daño en área no distingue bandos** —una explosión no lo hace—, salvo a quien
disparó: sale hacia adelante y nunca debería alcanzarse, pero si la geometría se tuerce,
un avión suicidándose con su propia arma se lee como un bug y no como fuego amigo. Cae
linealmente de `damage` en el centro a 0 en `blast_radius`.

#### `GuidedMissile` — `guided_missile.gd` (`extends Projectile`)
Misil contra un blanco ya designado — el `attack_target` de la unidad. Dispara y olvida.
Escena: `agm65_missile.tscn` (`z_index` 9: por debajo del avión, que va en 10, y por
encima del suelo y los tanques).

Cuatro fases, y el orden importa para que se lea como un misil y no como una bala
teledirigida: **separación** (cae del ala sin motor, con la inercia del avión) →
**ignición** → **crucero guiado** (proporcional) → **sin combustible** (recto, frenando).

| Grupo | Exports |
|-------|---------|
| Separación | `separation_time` (0.25), `launch_speed` (40), `separation_drag` |
| Vuelo | `cruise_speed` (300), `acceleration`, `boost_time`, `min_turn_radius` (90), `nav_gain` (3.5), `fuel_time` (2.5), `coast_drag`, `max_lifetime` |
| Estabilización | `wobble_amount_deg`, `wobble_hz`, `wobble_decay` |
| Espoleta | `proximity_radius` (12) |
| Buscador | `seeker_cone_deg` (30) |
| Arte | `sprite_offset_deg` (−90) |

**No decide si lo engaña un señuelo: obedece.** `set_decoyed(bool)` se lo dice quien lo lanza,
antes de volar. Si le tocó fallar, busca la bengala más centrada que tenga delante y se va con
ella; si no, ignora los señuelos y va derecho. `seeker_cone_deg` sólo evita que se vaya a uno
que tiene detrás.

Se intentó al revés —que el misil decidiera simulando la geometría de los señuelos— y no
funcionó: cuatro modelos distintos y todos daban el mismo resultado siempre. Ver `decisions.md`.

**El giro se limita por RADIO, no por grados por segundo.** Es la diferencia entre un
misil y un misil invencible: cuanto más rápido va, más ancho vira, así que existe una
geometría en la que no llega. En grados/s pasaría lo contrario — a más velocidad, giros
más cerrados — y no habría forma de escapársele.

**Espoleta por máximo acercamiento:** detona cuando la distancia deja de bajar y empieza
a subir, estando dentro de `proximity_radius`. Así existen los roces en vez de matar
siempre que llegue cerca.

| Señal | Para qué |
|-------|----------|
| `motor_ignited` | Sprite de fuego, estela de humo |
| `fuel_spent` | Apagar la estela |
| `detonated(where)` | Explosión (heredada de `Projectile`) |

Los enganches con arte son el escape (`MissileExhaust`), la estela (`SmokeTrail`) y
la sombra (`MissileShadow`), abajo. Siguen sin arte la **explosión y la caída**.

| Método | Para qué |
|--------|----------|
| `get_speed()` | velocidad real, contando la inercia heredada del avión |
| `get_distance_to_aim()` | lo que le falta para llegar. Lo lee `MissileShadow` como altura |

#### `MissileExhaust` — `missile_exhaust.gd`
```
extends AnimatedSprite2D   class_name MissileExhaust
```
El fuego del propulsor. Cuelga de la cola del misil como hijo y **el misil no sabe que
existe**: se engancha solo a las señales del padre en `_ready()` por duck-typing
(`has_signal`), así que cualquier proyectil que emita `motor_ignited` / `fuel_spent` puede
llevar escape sin heredar de nada.

| Fase del misil | Animación | Cicla |
|----------------|-----------|-------|
| `motor_ignited` | `ignite` (frames 0–9) | no |
| al terminar de prender | `burn` (frames 10–14) | sí |
| `fuel_spent` | `shutdown` (frames 15–19) | no, y se oculta al acabar |

**Tres animaciones y no una porque el motor tiene tres momentos**, y la tira los tiene
dibujados: prende, arde estable, se apaga. Ciclar los 20 frames enteros haría que la llama
desapareciera y volviera a nacer cada 0,8 s; reproducirlos una sola vez dejaría 2,5 s de
vuelo con motor y sin llama. Los nombres son `@export` (`ignite_anim`, `burn_anim`,
`shutdown_anim`): re-cortar la tira es tocar el `.tres` y los tres campos, sin código.

**El corte lo puso el autor del arte, no la medición.** El primer reparto salió de contar
píxeles opacos por frame (0–7 / 8–16 / 17–19) y estaba mal: la métrica no distingue una
llama que crece de una que arde. Al mirarla, el bucle sostenido es 10–14 y sólo son cinco
frames. **Ojo con la numeración al hablar de esto:** aquí los frames se cuentan por su
posición en el PNG (0–19), pero el panel de `SpriteFrames` de Godot renumera dentro de cada
animación — su `burn` frame 0 es el 10 de la tira.

**`core/weapon/missile_exhaust_frames.tres`** es el `SpriteFrames`: 20 `AtlasTexture` de
16×16 sobre `assets/art/sprites/Animations/Missile_fire_animation_16x16.png`, a 24 fps.
La tira es una rejilla uniforme, así que **no hace falta el JSON de frames** del editor de
pixel art — ese sólo se gana el sueldo con atlas empaquetados de recortes irregulares, y
sería un archivo más que mantener sincronizado.

**Colocación (`position`, hoy `(0, -13)`):** medido, no supuesto. El Maverick apunta a +Y,
su último píxel de cola está en la fila 2 del recorte y el primer píxel de la llama en la
fila 15; con sprites centrados de 16×16 eso da −13 exactos, y la llama crece hacia −Y, o
sea hacia atrás. **Es el único número que hay que rehacer si cambia el arte del misil.**

**Medio píxel que no se puede cuadrar, y no es un fallo:** el cuerpo del misil tiene ancho
**par** (columnas 7–8, eje en x=0) y la llama ancho **impar** (núcleo en la columna 8, eje
en x=+0,5). Ningún desplazamiento entero centra una cosa en la otra; ±0,5 px es el mínimo
posible. Se dejó a la derecha porque así el primer píxel de la llama cae exactamente sobre
un píxel de la cola. Cuadrarlo de verdad es cosa del arte —hacer par el núcleo de la llama
o impar el cuerpo del misil—, no de la posición.

`z_index = -1` dentro del misil: la llama se dibuja por detrás del fuselaje, misma
convención que `Hardpoints` bajo el `Sprite2D` de una unidad.

#### `EffectEmitter` — `effect_emitter.gd`
```
extends Node2D   class_name EffectEmitter
```
Base de los efectos que van **soltando cosas por el mundo** mientras algo dura: el humo de
un motor, el humo de boca de un cañón, las trazadoras de una ráfaga.

Lo común está aquí: engancharse por nombre de señal a quien los enciende, averiguar cuál
es "el mundo", parir allí y encenderse/apagarse. **Lo único que hereda cada subclase es
*cuándo toca soltar la siguiente*** — es la única diferencia real entre ellas.

| Exportado | Qué hace |
|-----------|----------|
| `spawn_scene` | qué se suelta |
| `source_path` | quién lo enciende (por defecto `..`) |
| `start_signal` / `stop_signal` | qué señales de esa fuente |

**`source_path` existe porque quien manda no siempre es de quien cuelgas.** Los efectos del
cañón cuelgan del avión pero los enciende su `WeaponSystem`. Alternativa descartada: que el
avión reemitiera las señales — un salto de más para nada.

La fuente se guarda en `_source` además de engancharse, porque **algún efecto necesita algo
más que el encendido**: `TracerStream` le pregunta a qué distancia está tirando para que
sus trazos no se pasen del blanco. Se pregunta con `has_method()`, nunca dando por hecho
que la fuente sea un `WeaponSystem`.

**`_emit_heading()`, y el bug que lo trajo.** El rumbo de quien emite **no** es la rotación
de su nodo: el arte del avión apunta a +Y, así que su rotación lleva −90 de desfase. Usarla
mandaba las trazadoras perpendiculares al morro. Ahora se pregunta `get_facing()`, que es
lo que ya hacía el armamento por este mismo motivo. Si de quien cuelga no es una `Unit` —el
humo de un misil cuelga del misil— vale la rotación, que es lo que había.

**`_shooter()` sube por el árbol, no mira sólo al padre.** Al montar el Tunguska se vio que
las dos suposiciones de este nodo valían para un avión y no para un vehículo con torreta,
donde los efectos cuelgan de la torreta y hay un nivel de más:

| se preguntaba | daba en un avión | daba con torreta |
|---|---|---|
| `get_parent() as Unit` (rumbo) | la `Unit` ✓ | `null` → rotación del nodo ✗ |
| `get_parent().get_parent()` (el mundo) | el mundo ✓ | la propia `Unit` ✗ |

El segundo era el peligroso: las trazadoras habrían nacido colgadas de la unidad y **habrían
girado con la torreta** en vez de quedarse donde se soltaron. Un rastro que sigue a quien lo
suelta no es un rastro. Ahora los dos suben hasta encontrar la `Unit`, y el mundo es el padre
de ésta. El avión no nota el cambio: su padre ya era la `Unit`.

**Que la señal no exista no es un error:** así se puede colocar y probar un efecto antes de
que exista quien lo dispare.

**`_due(delta, per_second)` — la cuenta de quien siembra por cadencia.** `TracerStream` y
`CasingEjector` llevaban la misma, y sólo cambiaba qué sale. Devuelve **cuántos** tocan en este
frame, no un sí/no: con cadencias por encima de los fps hay que soltar más de uno en el mismo
frame, y el resto se arrastra al siguiente en vez de perderse, así que **la cadencia real no
queda limitada por los fotogramas**. El `_begin()` de la base pone el reloj a cero para que el
primero salga ya —esperar el intervalo dejaría un hueco entre el fogonazo y lo primero que sale
por la boca—; quien siembra por distancia (`SmokeTrail`) lo sobrescribe.

#### `SmokeTrail` — `smoke_trail.gd` (`extends EffectEmitter`)
```
extends EffectEmitter   class_name SmokeTrail
```
El rastro de humo, **de cualquier cosa que eche humo**. No dibuja nada: va soltando
`SmokePuff` sueltas por el mundo mientras esté encendido.

**Siembra por distancia recorrida** (`spacing_px`), que es lo suyo frente a los demás
emisores: así la densidad no depende de los fps ni de la velocidad. Un misil a 300 px/s y
un avión a 90 dejan la misma cola de espesa; sólo cambia lo deprisa que la van dejando.

Se llamaba `MissileSmokeTrail` y era del misil. Al llegar el cañón resultó que la mecánica
era la misma —algo empieza, algo termina, y mientras tanto sale humo— y lo único distinto
era el dibujo, la densidad y quién lo enciende. Las tres son datos ahora, así que un humo
nuevo no cuesta código: son dos ficheros `.tres`/`.tscn` y un nodo.

| Exportado | Misil | Cañón | Qué hace |
|-----------|-------|-------|----------|
| `spawn_scene` | `smoke_puff.tscn` | `cannon_smoke_puff.tscn` | qué se suelta |
| `spacing_px` | `4.0` | `5.0` | cada cuántos píxeles **recorridos** sale una |
| `source_path` | `..` (el misil) | `../WeaponSystem` | quién lo enciende |
| `start_signal` | `motor_ignited` | `firing_started` | qué lo enciende |
| `stop_signal` | `fuel_spent` | `firing_stopped` | qué lo apaga |

**Cada bocanada se queda donde nació, con el rumbo congelado de quien la escupió en ese
instante.** De ahí que el rastro se doble solo en las curvas: no hay una cola que deformar,
hay un reguero de piezas que ya salieron apuntando a donde se iba entonces. Vale igual para
un misil virando que para un avión metido en un giro con el cañón abierto — medido, 9° de
abanico en el rastro del Harrier virando.

**Cuelgan del mundo, no de quien las echa** — se añaden a `get_parent().get_parent()`, el
mismo nodo donde `WeaponSystem` suelta los proyectiles. Hijas del misil viajarían con él,
que es lo contrario de una estela; y así la cola **sobrevive al impacto** y termina de
deshacerse sola después de que el misil desaparezca.

**Se siembra por distancia, no por tiempo**, y a lo largo del tramo recorrido, no en el
punto actual: a velocidad de crucero el misil avanza 5 px por frame, así que una bocanada
por frame dejaría la cola a trozos. Se interpolan posición (`lerp`) y rumbo (`lerp_angle`)
dentro del segmento. El portero es `set_physics_process()`, no una bandera aparte.

**El enganche por nombre de señal es opcional.** Si el padre no emite esa señal, no se
conecta nada y el nodo se enciende llamando a `start()` / `stop()`. Así se puede probar un
efecto antes de que exista quien lo dispare — que es justo el estado del cañón hoy.

#### `MuzzleFlash` — `muzzle_flash.gd`
```
extends AnimatedSprite2D   class_name MuzzleFlash
```
El fogonazo de un arma automática. Cuelga de la boca del cañón y sólo sabe encenderse
mientras se dispara: no conoce armas, ni munición, ni a quién se le tira. Mismo enganche
por señal que `SmokeTrail`, así que quien dispare no tiene que conocerlo.

**Dos animaciones sobre la misma tira, porque un cañón tiene dos momentos:**

| Animación | Fotogramas | Cicla | Qué es |
|-----------|-----------|-------|--------|
| `start` | 0–5 | no | el arranque: la llama crece de una chispa a la primera llamarada |
| `sustain` | 6–10 | sí | la ráfaga: alterna llamaradas grandes y pequeñas |

**El sostenido cicla y el arranque no**, y ahí está todo el efecto. Un cañón de rotación
suelta cientos de proyectiles por minuto: el fogonazo mantenido no puede ser un destello
por bala —a esa cadencia sería un parpadeo ilegible— sino una llama que titila. Pero
arrancar se ve una sola vez, y volver a enseñar ese crecimiento en mitad de la ráfaga
delataría el bucle.

Cortar el fuego lo apaga en seco **incluso a mitad del arranque**: el arma dejó de
disparar, y una llama creciendo sería mentira. Y abrir fuego dos veces seguidas no
reinicia nada — seguir disparando es seguir disparando.

**Arranca invisible en juego pero se sigue viendo en el editor** (`visible = false` en
`_ready()`, no en la escena), que es lo que permite colocarlo a mano sobre el arte sin
tener que dispararlo para saber dónde cae. Misma treta que `MissileExhaust`.

Un fogonazo es un sprite y no puede heredar de `EffectEmitter`, pero se engancha igual:
usa su `hook_up()`, que es estática justo por eso — un solo sitio donde se decide cómo se
engancha un efecto.

#### `TracerStream` — `tracer_stream.gd` (`extends EffectEmitter`)
```
extends EffectEmitter   class_name TracerStream
```
Las trazadoras de una ráfaga. **Siembra por cadencia y no por distancia**, que es lo único
que lo separa de `SmokeTrail`: un cañón dispara a su ritmo aunque el avión frene, y si se
parase en seco el humo dejaría de salir pero la ráfaga no.

`tracers_per_second` (12) **no es la cadencia del cañón** (60): es cada cuántas balas se ve
una, que es lo que es una trazadora. El `while` del reparto suelta más de una en el mismo
frame si hace falta, así que la cadencia no queda limitada por los fps.

**Le pregunta al arma hasta dónde tiene que llegar** (`_reach()` → `get_firing_distance()`
del `_source`), y se lo pasa a cada trazo en `launch()`. El alcance del cañón ya está
escrito en el `WeaponType`; repetirlo aquí sería el mismo número en dos sitios, que es como
se acaba teniendo dos verdades distintas. Se pregunta con `has_method()` y no se da por
hecho: esto se cuelga de lo que sea que dispare, y no todo lo que dispara es un
`WeaponSystem`.

#### `Tracer` — `tracer.gd`
```
extends AnimatedSprite2D   class_name Tracer
```
Un trazo. **No es una bala: no hace daño y no comprueba nada.** El daño lo reparte el arma.

**Tres tiempos, todos de la misma tira de 8 dibujos** (`Tracer_16x64.png`), que es como
está pensado el arte: los frames 0–6 son una bala corta que se va alargando, y el 7 es la
trazadora entera.

| Tiempo | Animación | Frames | Cuánto dura |
|--------|-----------|--------|-------------|
| Sale del arma | `muzzle` (60 fps, sin bucle) | 0→6 | los primeros ~105 px |
| Vuela | `streak` (en bucle) | sólo el 7 | el grueso del camino |
| Se consume | `muzzle` a mano, **al revés** | 6→0 | los últimos `burn_out_px` |

| Exportado | Hoy | Nota |
|-----------|-----|------|
| `speed` | 900 | muy por encima del avión, o se quedaría pegado al morro |
| `range_px` | 420 | **sólo el respaldo**: lo normal es que el arma le pase la distancia real al blanco |
| `reach_spread` | 0.12 | ±% del recorrido de cada trazo. Sin esto la ráfaga entera parece una regla |
| `burn_out_px` | 90 | en cuántos px se consume al final |
| `sprite_offset_deg` | −90 | el trazo está dibujado apuntando a +Y |

**El trazo muere donde está el blanco, no donde se le acaba el alcance.** `launch(heading,
reach)` recibe la distancia al objetivo en el momento del disparo. Volando 420 px fijos, un
tiro abierto a 273 px seguía **150 px más allá del tanque**: balas prometiendo impactos
imposibles muy por detrás de lo que se está ametrallando. Medido con el alcance real y la
dispersión puestos: se pasan **22 px de media, 44 la peor**, y aproximadamente la mitad se
queda corta — que es lo que tiene que pasar.

**El consumo final se maneja por distancia, no reproduciendo la animación al revés.** Lo
que manda es lo que queda de recorrido, no un reloj: así el trazo se acaba al ritmo al que
llega, aunque vaya más rápido o más lento.

**`launch()` va aparte de `_ready()`**, y no es un capricho: el nodo entra en el árbol antes
de que se le coloque, así que en `_ready()` todavía no sabe hacia dónde mira — leerlo ahí
mandaba todos los trazos hacia +X y de lado. Es lo mismo que hace `Projectile.launch()`:
nacer y salir disparado son dos momentos distintos.

**La tira estuvo mal montada al principio**, y merece la pena por lo poco evidente que era:
los 8 frames iban como una animación seguida a 20 fps. Eso son 0,35 s de "formándose", que
a 900 px/s son **315 px de los 360** — la bala se pasaba el 87% del viaje saliendo del arma
y el trazo de verdad sólo aparecía los últimos 45 px, justo antes de borrarse. Con los dos
tiempos separados es al revés: 105 px formándose y 315 de trazo. Una tira de dibujos no
siempre es una animación; a veces son dos estados y hay que preguntarle al que la dibujó.

#### `CasingEjector` — `casing_ejector.gd` (`extends EffectEmitter`)
```
extends EffectEmitter   class_name CasingEjector
```
Va escupiendo casquillos mientras dure el fuego. Hermano de `TracerStream`: los dos siembran
por cadencia y esa cuenta la lleva la base (`_due()`). Lo suyo es que **lo que sale no va hacia
adelante**.

| export | por defecto | qué es |
|---|---|---|
| `casings_per_second` | 8–10 | cada cuántos disparos se ve caer uno, no la cadencia del arma |
| `eject_angle_deg` | 90 | por qué lado salen (ver abajo) |
| `angle_spread_deg` | 25 | cuánto se abre el chorro |
| `inherit_velocity` | 0,5 | qué fracción de la velocidad del vehículo se llevan |

**El lado es del arma, no del cartucho.** Vivía en `Casing` y no servía: un cañón gemelo usa el
mismo cartucho en los dos tubos y escupe a lados opuestos. `Casing.launch()` recibe la dirección
ya resuelta.

> ⚠ **`−90` es la izquierda de quien va dentro; `+90`, su derecha.** No es la izquierda del
> dibujo. El arte apunta a +Y —al sur—, y quien mira al sur tiene el este a su izquierda: el
> lado +X, que en la imagen se ve a la **derecha**. Mirar el sprite quieto en el editor para
> elegir el signo lleva justo al error contrario.

**`inherit_velocity` ni 0 ni 1.** A 1 volarían pegados al avión; a 0 quedarían clavados en el
aire como si el avión no llevara inercia. A la mitad salen acompañando y **se van quedando
atrás** — medido, hasta 68 px por detrás del morro. La velocidad se le pregunta a la unidad
(`get_velocity()`) y no se deduce del movimiento del nodo: **la torreta gira, y girar no es
desplazarse**.

---

#### `Casing` — `casing.gd`
```
extends Sprite2D   class_name Casing
```
Un casquillo: sale de lado, da vueltas, frena rápido y se apaga en el suelo con un fundido.
**No es munición y no hace nada** — la bala ya salió por el otro extremo.

| export | por defecto |
|---|---|
| `eject_speed` / `speed_spread` | 70 px/s / ±35% |
| `drag` | 6 (frenada exponencial) |
| `spin_deg` | 720, sentido al azar |
| `lifetime` / `fade_fraction` | 0,9 s / último 35% |

Deja de girar a la vez que deja de moverse: un casquillo quieto dando vueltas en el sitio se
lee como un error. Y **cuelga del mundo**, así que se queda donde cayó aunque el que disparó se
vaya o muera.

Las escenas van por **calibre y no por unidad** —`casing_30mm.tscn`, `casing_25mm.tscn`—, las
dos recortadas del mismo PNG de 5×6: regiones `(1,1)` 1×4 y `(3,2)` 1×3.

---

#### `SmokePuff` — `smoke_puff.gd`
```
extends AnimatedSprite2D   class_name SmokePuff
```
Una bocanada suelta: se reproduce una vez y `queue_free()` en `animation_finished`. No sabe
nada de quien la escupió. Nace **visible** —al revés que `MissileExhaust`, que arranca
oculto porque vive colgado del misil desde antes de encender— y con `z_index = 8`, bajo el
misil (9) y bajo el avión (10).

**Un solo script, dos humos.** El dibujo y la duración son de la escena, no de la clase, así
que el humo del cañón reutiliza este código tal cual:

| Escena | Fotogramas | Vida | Rastro a su velocidad |
|--------|-----------|------|----------------------|
| `smoke_puff.tscn` | 23 (`missile_smoke_frames.tres`) | 1,47 s | ~440 px a 300 px/s |
| `cannon_smoke_puff.tscn` | 10 (`cannon_smoke_frames.tres`) | 0,67 s | ~45 px a ~95 px/s |

El del cañón es corto a propósito: es humo de boca de arma, no una estela que marque una
trayectoria. Sus 5 primeros fotogramas son la bocanada formándose (duración plana) y los 5
últimos la disipación, alargándose de 1,2 a 2,2 — misma forma que el del misil pero
comprimida.

| Exportado | Hoy | Qué hace |
|-----------|-----|----------|
| `puff_anim` | `&"puff"` | animación a reproducir |
| `start_jitter_frames` | `1` | cuántos frames enteros puede saltarse al nacer |

**Contra la repetición: `flip_h` al azar y desfase al nacer.** Todas son el mismo dibujo
cada 4 px exactos, y eso se lee como un sello repetido. El espejo duplica los dibujos
gratis y mueve el píxel de nacimiento de la columna 7 a la 8 — las dos son cola del misil,
así que sigue anclada. El desfase tiene dos partes y la segunda es la que trabaja: el frame
entero cambia el dibujo, y el **sub-frame** (siempre, `randf()`) descoloca *cuándo* cada una
salta al siguiente. Sin él escalonarían todas a la vez: a velocidad de crucero cada frame
dura tres bocanadas, y se veían bandas de tres iguales avanzando en bloque.

**`core/weapon/missile_smoke_frames.tres`**: 23 `AtlasTexture` de 16×16 sobre
`Missile_smoke_animation_16x16.png` (tira de 368×16), a 24 fps y `loop = false`. Dos fases:
**0–8 la bocanada formándose** (de 1 a 6 columnas de ancho, opaca) y **9–22 disipándose**
(se abre hasta las 16 columnas del tile y baja el alfa 100 → 70 → 55 → 39 → 22 → 11 %).

**Las duraciones no son planas, pero casi** — 1,0 en los 9 primeros y una rampa suave de
1,5 a 2,6 en los 14 últimos — y ahí está el largo de la cola: 35,2 unidades / 24 fps =
1,467 s, que a 300 px/s son **~440 px de estela y ~110 bocanadas vivas**. Se alarga por
frame en vez de bajando `speed`: eso habría alargado igual, pero devolviendo a 12 fps el
nacimiento, que es donde el dibujo cambia mucho entre frames y un salto se vería. La rampa
se concentra al final a propósito: **cada unidad de duración son 12,5 px de estela enseñando
el mismo dibujo**, así que estirar sale caro en bandas, y sólo es barato donde el alfa ya
está al 22 % y al 11 %.

> **Reserva conocida: la estela empieza a desvanecerse pronto.** Los frames opacos (0–17) se
> llevan 301 px y el fade (18–22) los 139 restantes, o sea que se disuelve desde el primer
> tercio y se lee menos como rastro. **Es de reparto de dibujos, no de reproducción**:
> alargar la fase opaca sólo con duraciones devolvería las bandas (fue la causa de la cola
> plana de la primera versión, ver `docs/decisions.md`). El arreglo bueno son 3–4 pasos
> opacos más y algún paso de alfa extra. Límite duro a tener presente: con 2,5 s de
> combustible el misil vuela ~700 px, así que una cola mucho más larga cubriría el recorrido
> entero y dejaría de verse disolver en vuelo.

#### `MissileShadow` — `missile_shadow.gd`
```
extends AnimatedSprite2D   class_name MissileShadow
```
La sombra del misil en el suelo. Hija suya, así que viaja y rota con él. **No reproduce la
animación**: el frame se asigna a mano cada `_physics_process` a partir de lo que le falta
al misil para llegar al blanco, o sea que los 7 frames no son una animación sino una
**escala de altura**.

| Exportado | Por defecto | Qué hace |
|-----------|-------------|----------|
| `descent_px` | `120.0` | distancia al blanco a la que empieza a picar (~0,4 s a velocidad de crucero) |
| `ground_px` | `12.0` | distancia a la que se considera que tocó el suelo |
| `altitude_drop_px` | `5.0` | cuánto se separa la sombra hacia abajo estando alto |

**Por distancia y no por tiempo, por el mismo motivo que todo lo demás aquí.** El misil
lleva espoleta de proximidad: **no sabe cuándo va a explotar**, así que «reproduce esto los
últimos 0,3 s» no se puede programar. La distancia sí la sabe siempre, y atándolo a ella la
sombra se junta con el misil justo en el impacto venga a la velocidad que venga.

**`ground_px` no es cero, y no es un detalle.** El misil detona por proximidad a 12 px sin
llegar a tocar nada. Contando hasta cero, el último frame —la sombra pegada al misil, que es
el remate del efecto— no se vería nunca.

**La diagonal la pone el nodo, no el dibujo.** El arte trae pintado el alejamiento
horizontal (la barra viaja de la columna 14 a la 8 según baja) pero le falta la componente
vertical: con el sol al noroeste, a más altura la sombra debe irse abajo *y* a la derecha.
No cabía en el tile —el cuerpo del misil llega a la fila 13 y sólo quedan dos libres—, así
que se añade como `position.y` del nodo, que no está atado a los 16 px. **Se encoge con la
misma cuenta que el dibujo**: fija, al impactar la sombra quedaría 5 px por debajo del misil
en vez de justo debajo.

**`core/weapon/missile_shadow_frames.tres`**: 7 `AtlasTexture` de 16×16 sobre
`Missile_shadow_animation_16x16.png` (112×16), animación `descend`, `loop = false`. Barra de
2 px de ancho a alfa 39 % plano, que **crece al bajar** (7 px de alto arriba, 10 abajo) —
convención de sombra falsa, cuanto más alto más pequeña. Las duraciones dan igual: nadie
reproduce esta animación.

> Pendiente de arte: redibujarla **ovalada y de 3 px de ancho** en vez de barra de 2. Hoy
> mide exactamente lo mismo que el cuerpo del misil, así que en los dos últimos frames se
> funden y parece que el misil engordó, no que la sombra llegó.

#### `GlideBomb` — `glide_bomb.gd` (`extends Projectile`)
```
extends Projectile   class_name GlideBomb
```
La GBU-54 y las que vengan detrás. **Hermana de `GuidedMissile`, no hija suya**: una bomba
no tiene fases de motor que heredar. Se suelta y cae, sin fuego y sin estela — la escena
`gbu54_bomb.tscn` reutiliza sólo `MissileShadow`.

**Lo que la hace un arma de largo alcance es ALTURA, no empuje.** `fall_time` (5,5 s) es su
altura, y de ahí sale el alcance: lo que recorra picando durante ese rato es hasta dónde
llega. No sale con velocidad propia — hereda la del avión (`shooter.get_velocity()`) — y
va **ganando** velocidad al picar hacia `terminal_speed` (280), lo contrario del misil,
que arranca fuerte y se apaga.

| Exportado | Por defecto | Qué hace |
|-----------|-------------|----------|
| `separation_time` / `separation_drag` | 0.35 / 0.9 | cae del pilón sin guiar, frenando |
| `terminal_speed` / `dive_acceleration` | 280 / 90 | velocidad que alcanza picando y cuánto gana por segundo |
| `min_turn_radius` | 220 | muy por encima de los 90 del misil: unas aletas corrigen deriva, no viran |
| `nav_gain` | 3.0 | ganancia del guiado proporcional |
| `fall_time` | 5.5 | segundos hasta tocar suelo — **su altura** |
| `proximity_radius` | 10 | espoleta de máximo acercamiento |

**Dos finales y sólo dos:** llegó al blanco, o se le acabó la caída y aterriza donde esté.
Los dos salen del mismo `if` en `_physics_process`, no de dentro del planeo: dos caminos a
`detonate()` en el mismo frame repartirían el daño dos veces.

El segundo final es lo que da sentido al `max_range` del arma. No es una regla ni un muro:
es hasta dónde llega picando. Medido soltándola desde parado (el peor caso, sin heredar
velocidad), el límite físico son **1018 px**; con `max_range` en 900 quedan ~118 px de
margen y a 1100 cae **82 px corta** — fuera de los 45 de radio de explosión, o sea un fallo
limpio y visible. El fallo sale de la simulación, no de un dado.

**`get_distance_to_aim()` devuelve la menor de dos cuentas** — lo que le falta para llegar
y lo que le queda de caída — porque manda la que se agote antes. Así la sombra se junta con
la bomba en el impacto tanto si acierta como si se queda corta, que es lo que hace legible
el fallo: se ve tocar tierra lejos del blanco.

A diferencia del misil **guía hasta el final**: unas aletas no gastan combustible. Lo que
se le acaba es el sitio para maniobrar, no el mando.

Verificado en headless con el ciclo completo del Harrier (blanco a 1400 px): suelta a
**898 px**, nunca se acerca a menos de **782** (el `min_range` es 350, así que el avión no
sobrevuela nada), gasta **una sola** por pasada (`salvo_size = 1`) y mata.

#### `BallisticBomb` — `ballistic_bomb.gd` (`extends Projectile`)
```
extends Projectile   class_name BallisticBomb
```
Bomba tonta retardada — la Mk-82. **No guía, no corrige y no sabe dónde está el blanco.**

**Hermana de `GlideBomb`, no subclase suya.** Comparten "no tiene motor, se desprende y
cae", pero la planeadora **manda sobre su rumbo** y ésta no manda sobre nada. Unirlas con un
`if` obligaría a arrastrar guiado, espoleta de proximidad y punto de apuntado por un camino
que no los usa jamás.

Dos tiempos:

| Tiempo | Qué pasa | Cuánto dura |
|--------|----------|-------------|
| Separación | Cae del pilón con el freno cerrado, casi sin frenar. Es lo que la aleja del avión | `separation_time` (0,25 s) |
| Retardada | El freno de cola abre y frena de golpe. Deja de seguir al avión | hasta tocar suelo |

| Exportado | Hoy | Nota |
|-----------|-----|------|
| `separation_time` | 0.25 | cuándo abre el freno |
| `separation_drag` | 0.35 | frenado antes de abrirlo: bajo, no hay nada desplegado |
| `drag` | 1.6 | frenado con el freno abierto. **Decide cuánto se queda atrás** |
| `terminal_speed` | 45 | a lo que acaba cayendo |
| `fall_time` | 3.0 | su altura, igual que en la planeadora |
| `wander_deg` | 3.0 | cuánto puede salir torcida |
| `fall_spread` | 0.09 | cuánto puede variar su caída |
| `sprite_offset_deg` | −90 | el arte apunta a +Y, como todo lo demás |

**Su alcance no se configura: sale de la geometría.** No hay ningún parámetro que diga
"llega a X px" — llega hasta donde la lleve su velocidad mientras dure `fall_time`.
Soltarla pronto la deja corta y soltarla tarde la pasa de largo. Eso es lo que hace tonta a
una bomba tonta, y por eso el `max_range` del arma significa **"desde dónde hay que
soltarla"**, no un muro.

**Ignora el `aim_offset` a propósito.** Le llega porque `Projectile.launch()` lo pasa
siempre, pero es el desvío de un punto de apuntado y esto no apunta. Ignorarlo es la forma
de decir en el código que una bomba tonta no tiene puntería que dispersar. Lo que sí varía
es cómo se desprende cada una: `wander_deg` la reparte **a lo ancho** y `fall_spread` **a lo
largo**.

**El frenado es exponencial, no a plazos fijos.** Una retardada pierde de golpe casi toda la
velocidad que traía y luego baja despacio hasta la suya; restando una cantidad fija por
segundo se quedaría quieta de repente, que se lee como otra cosa.

**Sólo tiene un final:** se le acaba la altura y estalla donde esté. No hay espoleta de
proximidad ni impacto directo — no sabe dónde está el blanco, así que no puede acertarle a
propósito.

**El freno cumple su función, medido:** cuando cada bomba estalla, el avión ya está a
**135–216 px** de ella. No vuela hacia su propia explosión.

**Lleva la sombra del misil sin que nadie tocara la sombra.** `MissileShadow` pide
`get_distance_to_aim()` a su padre por duck-typing, así que bastó con que la bomba lo
implemente. En la planeadora eso significa "lo que falta para llegar al blanco"; aquí no hay
blanco, así que es **lo que falta para quedarse sin altura** — que para una sombra es lo
mismo, porque lo que mide es caída, no puntería.

No es velocidad × tiempo restante: la bomba viene frenando todo el rato y eso daría de más,
con la sombra tocando suelo antes que la bomba. Es la integral del frenado exponencial.
Medido en una caída real (`descent_px` 150, `ground_px` 3):

| Le queda | Frame |
|---|---|
| 253,7 px | 0 |
| 137,5 px | 1 |
| 87,9 px | 3 |
| 39,6 px | 5 |
| 14,9 px | 6 (pegada a la bomba) |

Los 7 frames se reparten parejo y el último cae justo al tocar suelo. Es la sombra del
misil por ahora: **la Mk-82 tendrá la suya cuando exista el arte**.

**El arte** (`mk82_bomb_frames.tres`, 6 frames de 16×16) va en dos estados, igual que el
fogonazo y la trazadora: `carried` (frame 0, cola cerrada) y `drop` (0→5, el freno
abriéndose), que se dispara al separarse y se queda en el último frame — un freno no se
vuelve a cerrar. El `sprite_offset_deg` estuvo en +90 y **la bomba volaba de culo, con el
freno desplegándose por delante**: el arte de este proyecto apunta a +Y y la convención es
−90 en todas partes (avión, misil, planeadora, trazadora). Salirse de ella nunca sale bien.

#### `WeaponSystem` — `weapon_system.gd`
```
extends Node   class_name WeaponSystem
```
Decide **cuándo** se dispara. Tercer hermano de `OrbitBehavior` y `AttackRunBehavior`:
ellos llevan el avión hasta el blanco, éste comprueba si desde aquí se puede tirar. No
decide a quién se ataca (eso es la orden, y vive en `Unit`) ni cómo vuela lo que dispara.

| Miembro | Descripción |
|---------|-------------|
| `can_fire_at(target)` | Arma válida contra ese dominio, munición, distancia y ángulo |
| `time_to_impact()` | La primera de sus armas en llegar, −1 si no tiene nada volando |
| `set_active(bool)` | Encender/apagar. Arranca encendido. Apagar suelta el gatillo |
| `set_cleared_to_fire(bool)` | Permiso de tiro sin apagar el armamento. Arranca en `true`. Quitarlo suelta el gatillo |
| `get_firing_distance()` | A qué distancia se está tirando, 0 si no hay blanco. Lo usan los efectos que necesitan saber dónde **acaba** el tiro |
| `fired(weapon)` | Señal. La escucha el vuelo para romper el ataque |
| `firing_started` / `firing_stopped` | Señales. Las escuchan los efectos del cañón |
| `rack_path` | Export, `../Hardpoints` |

**Apuntar y poder tirar son cosas distintas.** `set_cleared_to_fire()` es lo que las
separa. Un `WeaponSystem` suelto dispara siempre que las condiciones se den — un tanque no
le pide permiso a nadie —, pero el avión sólo tiene permiso **dentro de la pasada**
(`AttackRunBehavior.attack_run_started` / `attack_run_ended`).

Sin eso, en cuanto rompía y se iba virando el morro le barría el paisaje y cruzaba el
blanco de refilón una y otra vez; cada cruce cumplía las condiciones y salía una ráfaga.
Visto desde fuera, el avión parecía **bailar alrededor del objetivo disparando a todos
lados** en vez de ametrallarlo. El permiso es de todo el armamento, no sólo del cañón: un
misil tampoco debe salir a mitad de un viraje.

**No dispara mientras tenga algo suyo en el aire.** De ahí sale solo el "si no muere,
lanza el otro": se lanza, se espera a que explote, y si el blanco sigue vivo sale el
siguiente. Nadie escribió "reevaluar tras el impacto".

**Una andanada escalonada es UN disparo que dura, no N disparos sueltos.** Con
`salvo_interval > 0` la andanada pasa a ser un estado en curso (`_stick_*`) que se atiende
al principio del proceso y se termina siempre. Dos motivos, los dos reales:

- La regla de arriba la mataría: la bomba nº1 en el aire bloquearía a las cinco siguientes.
- Cortarla a medias por perder el permiso de tiro o porque el blanco muera dejaría media
  carga colgada del ala sin que nadie pueda soltarla.

Sólo `set_active(false)` la aborta — ahí el avión aterrizó o murió, y no hay pasada que
acabar.

**`fired` se emite con la ÚLTIMA del stick**, y de eso depende toda la pasada de bombardeo:
el vuelo rompe al oírlo, así que anunciarlo con la primera pondría al avión a virar con
cinco bombas todavía colgadas, y saldrían abanicadas hacia donde ya no está el blanco.

**La longitud de la ristra no se configura**: sale del intervalo por la velocidad a la que
vaya el avión. Medido con la Mk-82 (0,1 s a 115 px/s): **75 px** de línea batida, las
primeras cortas, las del medio encima del blanco y las últimas largas.

**Dos formas de disparar, según `WeaponType.fire_mode`:**

| | `LAUNCHER` | `SUSTAINED` |
|---|---|---|
| Qué hace | instancia un proyectil por disparo | mantiene un chorro |
| Quién hace el daño | el proyectil al llegar | el arma, mientras dure |
| Cadencia | andanadas con `reload_time` | continua |
| Emite `fired` | sí | **no** |

**Un arma sostenida nunca emite `fired`, y ahí está toda la diferencia de vuelo.** `fired`
significa "ya hay algo en camino, deja de acercarte", y el avión rompe al oírlo. Con el
cañón no hay nada que esperar: sigue metiéndose y rompe cuando la distancia le obliga.
Eso convierte una pasada de misil en una de ametrallamiento **sin tocar
`AttackRunBehavior`**.

**El daño se cuenta en proyectiles, no en "daño por segundo".** Así `damage` sigue
significando lo de siempre —lo que hace UNA bala— y no hay que sobrecargar el campo.
Cuántas entran lo dice `_hit_fraction()`, y son dos cosas que en el fondo son la misma:
cuánto se ha abierto el cono de balas para cuando llega.

- **Distancia:** de cerca la dispersión no ha tenido sitio para abrirse y entra casi todo;
  en el borde del alcance entra `long_range_accuracy`.
- **Puntería:** centrado en el morro entra todo; rozando el borde del cono, sólo el rabo
  de la ráfaga. Fuera del cono, cero — se ve el fogonazo y no acierta nada, que es lo que
  pasa de verdad cuando se aguanta el gatillo sin apuntar.

Así el fallo sale de la geometría y no de un dado, y **la pasada importa**: entrar cerca y
encarado mata, hostigar desde lejos hace cosquillas.

**Histéresis en el gatillo**, igual que el compromiso de viraje del piloto: se abre fuego
con `firing_arc_deg` y no se suelta hasta `× arc_hysteresis`. Sin eso el blanco entra y
sale del cono mientras el avión corrige y la ráfaga sale a tirones. Medido: **una sola
apertura por pasada**.

**Ninguna bala existe como objeto.** El cañón tira 60 proyectiles/s; sesenta nodos por
segundo no se sostienen, y ese era el problema que llevaba tiempo anotado en pendientes.
Lo que se ve son las trazadoras — 12/s, una de cada cinco, que es lo que es una trazadora
de verdad — y no hacen daño ni comprueban nada.

**Contramedidas: se tira una vez, al lanzar.** `_roll_decoy_defeat()` decide de una si el misil
va a fallar, y el vuelo posterior sólo lo representa. Suma dos capas y resta una:

```
prob = UnitType.ecm_evasion  +  WeaponType.decoy_bonus (si gasta carga)
                             −  decoy_defeat_step × misiles ya lanzados a ese blanco
```

Medido, con el Harrier (ECM 0,20) contra el 9M311 (+0,55, escalón 0,15):

```
             misil 1   2     3     4     5
con chaff      75%   58%   44%   29%   12%
sin chaff      20%    5%    0%    0%    0%
```

**Una carga por misil, no por bengala:** lo que se gasta es la respuesta a una amenaza; cuántas
salgan por el tubo es cosa del patrón. Así cambiar el patrón visual no altera la autonomía.

**La solución de tiro se guarda por blanco** (`_solutions`) y se olvida de dos maneras: sola,
pasado `fire_solution_memory` (25 s) sin seguirlo, y de golpe con `forget_solution()` cuando el
avión vuelva a base — método listo, **todavía sin llamar**, porque la recuperación no existe. Se
descartó olvidar al salir del círculo de detección: sería un botón de reiniciar.

**Ráfagas: `burst_seconds` y `burst_pause`, con 0 = sin ráfagas.** Un cañón de avión debe
tirar seguido porque **la pasada ya es la ráfaga**; una batería antiaérea no tiene pasada que
le marque el ritmo, y si no cortara se quedaría escupiendo fuego desde que te ve hasta que
sales. Con `burst_seconds = 0` el arma tira mientras haya ocasión —comportamiento de siempre,
el del Harrier, sin tocar nada—; por encima de 0 corta sola y espera.

El silencio se hace **soltando el gatillo** (`_release_trigger()`), no con una bandera aparte:
los efectos apagan el fogonazo por la señal de siempre y ninguno se entera de que existen las
ráfagas. Medido en el Tunguska: 0,80 s de fuego / 0,70 s de pausa, exactos.

**No comprueba hostilidad**: el portero de a-quién-se-ataca es `SelectionManager` /
`Unit.receive_attack_order`. Ver "Un solo portero por regla".

---

#### `WeaponSelector` — `weapon_selector.gd`
```
extends Node   class_name WeaponSelector
```
Elige con qué arma se ataca según a qué distancia está el blanco. Cuelga de la unidad y lo usan
el Harrier y el Tunguska — salió del script del Tunguska en cuanto hizo falta lo mismo en el
avión.

**Quién manda, que costó tres correcciones:**

| situación | manda |
|---|---|
| duelo aéreo sin que el jugador toque nada | el automático, cambiando de banda según se cierra |
| ataque a tierra | **el jugador**: se pone un arma que sirva al empezar y no se vuelve a tocar |
| el jugador elige en la barra | él, hasta que el arma se agote o cambie a otro blanco |
| elige el arma **antes** de dar la orden | él: la elección **espera** al blanco que venga |

Los dos últimos son bugs que se vieron jugando, no razonando:

- Elegir arma y **después** pulsar al enemigo es el orden normal, y la primera versión daba la
  elección por caducada justo al atacar, pisándole el arma al jugador.
- Al desactivar el automático en tierra, **el arma se quedaba pegada de lo anterior**: salías de
  un duelo con el cañón puesto, mandabas el avión contra un tanque y se iba a ametrallar con
  distancia de sobra para bombardear. De ahí la distinción entre *no cambiarla durante* y *poner
  una que sirva al empezar*.

**Cómo elige** (`best_for`), con el alcance y el aspecto que aplican a ese blanco:

- **El cañón es siempre el último recurso.** Mientras un misil llegue, se tira el misil. Y de
  ahí sale gratis lo que se quería: a quemarropa ningún misil llega, así que el cañón entra solo
  sin ninguna regla que diga "usa el cañón cuando estés encima".
- **Contra aire**, entre misiles gana el de **menor** alcance: las envolventes están hechas para
  no solaparse apenas, así que ése es el de la banda de ahora.
- **Contra tierra**, el de **mayor** alcance: se tira desde fuera de lo que defienda el blanco.

---

### `T-14 Armata` — `core/unit/t14_armata/`

Tanque enemigo. **Sin script**: instancia de `unit.tscn` con `unit_type` y `team = ENEMY`,
en el grupo `unit_ground`. `Unit` ya le da contorno, nombre y selección, y
`receive_move_order()` virtual vacío significa que no se mueve. Tendrá script cuando
tenga IA.

Sirve de patrón para cualquier unidad estática: **una unidad no necesita script propio
hasta que tenga comportamiento**.

---

### `2S6 Tunguska` — `core/unit/2s6_tunguska/`

Batería antiaérea enemiga. Primera unidad hostil **con** comportamiento, y el contraejemplo del
T-14: aquí sí hace falta script, pero sólo veinte líneas.

**Arte:** un PNG de 50×50 con tres piezas, recortadas con `AtlasTexture` sin trocear el archivo.

| nodo | región | jerarquía |
|---|---|---|
| `Sprite2D` (casco) | `(1,1)` 24×35 | raíz |
| `Turret` | `(26,25)` 24×24 | hijo de la unidad — lleva `TurretTracker` |
| `Radar` | `(29,1)` 20×11 | hijo de `Turret` — lleva `RadarDish` |

Escena completa: casco + `Turret` (con el `Radar` dentro) + `RangeRings` + `WeaponSystem` + seis
emisores de efectos colgados de la torreta.

**`tunguska_2s6.gd`** ata los dos cabos que ningún componente puede atar solo:

```
extends Unit
```
1. **Lo que el radar engancha es a quien se dispara.** `TurretTracker` sabe a quién sigue y
   `WeaponSystem` sabe cuándo puede tirar, pero ninguno conoce al otro:
   `turret.target_acquired → set_attack_target`.
2. **`get_facing()` devuelve la línea de los cañones**, no la del casco. Sin esto el armamento
   creería apuntar al frente del vehículo y no dispararía nunca — o dispararía de lado.

No recibe órdenes: es del otro bando y se defiende sola.

**Arma:** `2a38m_cannon.tres` — `SUSTAINED`, alcance 250, arco 8°, 50 disparos/s, ráfagas de
0,8 s con 0,7 s de pausa, sólo contra objetivos `Aire`.

**Efectos:** hoy usa prestados los del Harrier (`cannon_flash_frames`, `tracer.tscn`,
`cannon_smoke_puff`) hasta que tenga los suyos. Son **dos juegos, uno por cañón**, en
`x = ∓7, y = +12` — la boca de cada tubo, medida sobre el sprite. Todos escuchan
`firing_started`/`firing_stopped`, así que los dos tubos abren y cierran sincronizados.

Más los **casquillos de 30 mm**: `CasingsL` / `CasingsR` en `(∓9, −7)`, la culata de cada
cañón, escupiendo **cada uno hacia afuera** (`+90` el izquierdo, `−90` el derecho). Aquí el
criterio es "hacia afuera" y no izquierda/derecha del vehículo, así que no depende de la
convención que confunde en el Harrier. `inherit_velocity` da igual: el vehículo no se mueve.

> Cambiar el arte después no toca código: `MuzzleFlash` recibe un `SpriteFrames` y
> `TracerStream` un `PackedScene`, los dos apuntados desde la escena. Lo único heredado es la
> estructura de animación (`start`/`sustain` en el fogonazo, `muzzle`/`streak` en la trazadora).

---

### `AH-1W SuperCobra` — `core/unit/ah1w_supercobra/`

Helicóptero de ataque del jugador. Sale del hangar, hace el mismo recorrido de cubierta que el
Harrier —elevador, taxi, colocación— y **se queda posado en su punto** hasta que se le ordene ir
a algún sitio.

Arte en dos piezas del mismo PNG de 48×54: cuerpo `(4,2)` 23×48 y palas `(38,5)` 6×47, colocadas
a mano sobre el mástil.

**`ah1w_supercobra.gd`** (`extends Unit`) es mucho más corto que el del Harrier, y no por estar a
medias: **un helicóptero no necesita comportamientos**. El avión los tiene porque no puede parar,
así que hay que inventarle qué hacer cuando no hay nada que hacer —orbitar— y cómo acercarse a un
blanco sin frenar —la pasada—. Aquí ir y esperar son lo mismo: se le manda un punto, va, y se
queda. Sin patrón de espera a propósito.

Lo que resuelve: `get_facing()` y `get_velocity()` desde el piloto, `get_move_destination()` para
la etiqueta del HUD, `start_flight()` —que recoge el control **con el aparato en cubierta**, al
revés que el avión— y `receive_move_order()`. Reemite `took_off` del piloto para que el barco
libere la plaza, y `order_fulfilled` al llegar, que es lo que `SelectionManager` espera de
cualquier unidad que cumpla una orden.

**Cómo sabe la cubierta que no debe lanzarlo por pista:** se lo pregunta al aparato.
`get_takeoff_speed()` devuelve 0 en todo lo que no despega en carrera, y `FlightDeck._launch_next()`
se lo salta. Sin listas de modelos: el día que haya otro helicóptero funciona solo.

**`ah1w_supercobra_loadouts.gd`** — tres misiones **sin armamento**: CAS, Escolta armada y
Ataque antiblindaje. Al no pedir ninguna arma, `can_arm_with` las deja pasar siempre y el hangar
las ofrece las tres. 4 unidades en el inventario del LHD.

> Pendiente: **el armamento**, y con él el gesto que le falta al vuelo — morro clavado en el
> blanco mientras se desplaza de costado. El controlador ya lleva el rumbo separado de la
> traslación, así que es apuntar `_wanted_heading` al objetivo y dejar que el destino mande sólo
> en el movimiento.

---

#### `Rotor` — `rotor.gd`
```
extends Sprite2D   class_name Rotor
```
Las palas: arrancan **cuando el aparato ya está colocado** y suben a régimen en `spin_up_time`
(4 s) hasta `max_speed_deg` (1400°/s ≈ 4 vueltas por segundo).

Sabe cuándo arrancar **mirando si el aparato se mueve**, no porque nadie se lo diga: mientras la
cubierta lo lleva de un sitio a otro está rodando, y en cuanto se queda quieto `settle_time`
(0,5 s) es que llegó. Así el barco no conoce qué saca ni el helicóptero avisa a nadie, y cambiar
el recorrido de cubierta no rompe esto.

**Una vez arrancado no se para**, aunque el aparato se mueva: lo contrario sería un rotor que se
apaga justo al despegar.

Es **provisional** hasta que haya animación de hélice — girar unas palas rectas se lee bien de
lejos, pero no es el disco borroso de un rotor a régimen.

---

### `Su-33 Flanker-D` — `core/unit/su33_flanker/`

Avión enemigo. **Sin IA, y a propósito**: vuela en círculo sobre donde lo pongas y ya está. Es
un blanco aéreo de verdad —se mueve, hay que anticiparlo, los misiles tienen que
interceptarlo— sin decidir todavía nada del comportamiento enemigo, que es cosa de cuando haya
misiones.

No hizo falta inventar nada para eso: **reusa `PlaneController` + `OrbitBehavior` tal cual**,
que es el circuito de espera del Harrier. Cuando llegue el momento de darle comportamiento, esto
será su estado "sin órdenes" y no habrá que deshacer nada.

70 de vida, ECM 0,25 (más que el Harrier), radio de giro 150, 90–140 px/s. Su arte apunta a **+Y
igual que el Harrier**, así que usa el `sprite_offset_deg` por defecto.

El del mapa lleva **`invulnerable = true`**: es el blanco de pruebas.

---

### `AV-8B Harrier II` — `core/unit/av8b_harrier/`

**`av8b_harrier.gd`:** sólo identidad y ruteo de órdenes. No pilota. Arbitra cuál de los
dos comportamientos de vuelo manda — `orbit` y `attack` nunca procesan a la vez — y
**traduce el arma activa a la envolvente de tiro** que el vuelo debe respetar: el
comportamiento no sabe de armas y el arma no sabe de vuelo.
```
extends Unit
```
| Señal | Cuándo |
|-------|--------|
| `order_fulfilled` | Llegó al punto ordenado (reenvía `OrbitBehavior.center_reached`) |

**Escena:** `Sprite2D`, `CollisionShape2D`, `SelectionIndicator`, `PlaneController`,
`OrbitBehavior`, `AttackRun` (`AttackRunBehavior`), `WeaponSystem`, `Hardpoints`
(`HardpointRack` con 10 `Marker2D`: `L1`, `L2a`, `L2c`, `L3a`, `L3c` y sus simétricos
`R`), `CannonFlash` (`MuzzleFlash`), `CannonSmoke` (`SmokeTrail`), `CannonTracers`
(`TracerStream`) y `CannonCasings` (`CasingEjector`, 25 mm). `z_index = 10` en el raíz.

**Los efectos del cañón se colocan a ojo en el editor** y no dependen de nada del
código: `CannonFlash` y `CannonTracers` en la boca del arma, `CannonSmoke` bajo el ala,
`CannonCasings` junto a la cabina. Todos escuchan `firing_started` / `firing_stopped` en
**`../WeaponSystem`**, que es quien sabe si se dan las condiciones de tiro. Ninguno conoce
a los otros: sumar un efecto más no obliga a tocar nada — los casquillos se añadieron así,
sin tocar una línea de los otros tres.

`CannonCasings` lleva **`eject_angle_deg = −90`**: la izquierda del piloto. Ver la advertencia
en `CasingEjector` — no es la izquierda de la imagen.

**API:**
- `start_flight(orbit_center)` — la cubierta le cede el control y enciende el armamento. **Sólo entra al circuito de espera si no tiene órdenes**: si hay `attack_target` sale a por él, y si `orbit.has_pending_order()` no toca nada (el destino ya está puesto en el piloto). El circuito es lo que hace un avión sin órdenes, y el jugador pudo darle una mientras estaba en cubierta
- `receive_move_order(target)` — para `attack`, delega en `orbit.orbit_at(target)`
- `receive_attack_order(target)` — para `orbit`, delega en `attack.engage(target, min, max)`
- `get_facing()` / `get_velocity()` — el rumbo **real** del piloto, no la rotación del nodo: el arte apunta a +Y y el armamento heredaría el desfase, saliendo disparado de lado
- `get_time_to_impact()` — delega en `weapons`

**Armamento apagado en cubierta:** un avión que ya tiene la orden no dispara desde el
barco. Lo enciende `start_flight()`.

**Disparar rompe el ataque:** `weapons.fired` → `attack.break_off()`. Y
`active_weapon_changed` → `attack.set_envelope(...)`, porque cambiar de arma en pleno
ataque cambia a qué distancia hay que volar.

**Sólo se tira dentro de la pasada:** `attack.attack_run_started` / `attack_run_ended` →
`weapons.set_cleared_to_fire(true/false)`. Y `receive_attack_order()` lo pone en `false` de
entrada: **primero se enfila, el permiso llega con la pasada**. Al revés, el avión abriría
fuego mientras todavía busca la línea de ataque. Aquí es donde se cierra el reparto: el
comportamiento sabe *cuándo hay pasada*, el `WeaponSystem` sabe *si desde aquí se acierta*,
y el Harrier es el único que conoce a los dos.

**`_on_target_lost()`** (conectado a `attack.target_lost`): el objetivo murió en pleno
vuelo. El avión no puede pararse en seco, así que orbita **donde llegó**
(`orbit.orbit_at(global_position)`), no donde estaba el enemigo — seguir volando hasta un
punto vacío se vería como que no se enteró. No hace falta guardar esa posición aparte:
el comportamiento avisa *antes* de dejar de procesar, así que `global_position` en ese
instante ya es "aquí estoy ahora".

**Sin munición sigue haciendo pasadas** sobre el blanco, sin disparar. Pendiente decidir
qué debería hacer.

---

## HUD — `ui/hud/`

### `HUD` — `hud.gd`
```
extends CanvasLayer   class_name HUD
```
| Señal | Cuándo |
|-------|--------|
| `deselect_requested` | Botón × presionado |
| `unit_focus_requested(unit: Unit)` | Click en un cuadrito de `DeployedPanel`, o "Información" en `TargetMenu` |
| `attack_requested(target: Unit)` | El jugador tocó "Atacar" en `TargetMenu` |
| `zoom_change_requested(step: int)` | Pidió acercar (+1) o alejar (−1). Reenvía lo de `ZoomControls`; el HUD no conoce la cámara |
| `map_clicked(world_position: Vector2, unit: Unit)` | Pulsó el mapa táctico, con la unidad que hubiera bajo el punto o `null`. Mismo trato: reenvía |
| `map_context_requested(world_position: Vector2, unit: Unit)` | Ídem con el botón derecho |
| `look_requested(world_position: Vector2)` | Pulsó una coordenada del `EventLog`: llevar la mirada allí |

API:
- `show_selected_unit(unit: Unit)` — muestra panel + acciones (si controla) + barra de armas + botón ×; se suscribe a `attack_target_changed` de la unidad; le pasa la selección al `TacticalMap` para su rótulo y su recuadro
- `clear_selected_unit()` — oculta todo, incluido el aviso de ataque; se desuscribe
- `open_target_menu(target, can_attack)` / `close_target_menu()` — delegan en `TargetMenu`
- `show_order_marker(world_position)` / `clear_order_marker()` — el destino de la orden en curso, para que se vea en los dos mapas. Se lo dice `SelectionManager`: el HUD no conoce el mundo
- `report_move_order(unit, where)` — una orden dada, para el `EventLog`. Igual que el marcador: lo cuenta quien la da, porque nadie más se entera de que ha habido una
- `set_zoom_state(level, count)` — hasta dónde puede seguir acercándose o alejándose. Se lo dice `SelectionManager`, que sí tiene la cámara delante

**`_refresh_weapon_bar()` junta las tres condiciones que esconden la barra de armas:** que no
haya selección, que la unidad no sea del jugador, o que el mapa táctico esté abierto. Las tres
acaban en `show_weapons(null)`, así que caben en una llamada, y por eso `TacticalMap.opened` y
`closed` van conectadas ahí. **La barra es lo único del HUD que se esconde con el mapa
abierto** — cae justo encima del terreno y ahí no se dispara nada; el hangar, las acciones, el
zoom y la lista de desplegadas siguen a mano.

**El menú contextual se coloca sobre el punto del mapa cuando el mapa está abierto**, en vez
de sobre la unidad (`get_global_transform_with_canvas()`). Es la misma unidad mirada desde
otro sitio: la de verdad puede estar a media misión de la cámara, y el menú saldría pegado a
un borde de la pantalla.

`_on_attack_target_changed(target)` mantiene el `AttackLabel` ("Atacando: <nombre>") en
sincronía con la unidad seleccionada — enganchado a su señal y no refrescado a mano,
porque el objetivo puede cambiar sin que la selección cambie (el enemigo murió).
`_on_ammo_changed(...)` hace lo propio con la barra de armas.

**`ImpactTimer` — cuenta atrás de impacto.** `Label` rojo (`font_size` 7) que se coloca
sobre el objetivo, 10 px a la derecha y 14 arriba, con `get_global_transform_with_canvas()`.
Se refresca en `_process` preguntando `Unit.get_time_to_impact()`.

**Vive con la selección**, igual que el recuadro del objetivo: es lo que está disparando
la unidad que miras, no un adorno del mapa. Se va al deseleccionar y vuelve al
reseleccionar. Sin nada en el aire (entre disparo y disparo) no muestra nada. Es una
estimación honesta —distancia entre velocidad actual—, no un cronómetro: si el arma aún
acelera o el blanco maniobra, la cifra se corrige sola.

Ruteo de acciones en `_on_action_pressed(name)`:
```gdscript
match action_name.to_lower():
    "hangar": _hangar_window.open(_current_unit)
```
Agregar casos aquí al implementar nuevas acciones.

**Árbol de `hud.tscn`:**
```
CanvasLayer (HUD)          — process_mode = Always: la interfaz sigue viva en pausa
├── UnitTag          (Node2D)         — etiqueta de la unidad seleccionada, sigue su posición
├── EventLog         (PanelContainer) — columna izquierda, se mide y se coloca solo
├── Minimap          (PanelContainer) — esquina inferior izquierda, estirable
├── TacticalMap      (Control)        — pantalla completa, visible=false
├── HangarWindow     (PanelContainer)
├── ActionsPanel     (PanelContainer) — offset_left=544, offset_top=313
├── SelectionPanel   (PanelContainer) — offset_left=544, offset_top=349
├── DeployedPanel    (PanelContainer) — panel superior, unidades desplegadas
├── WeaponBar        (HBoxContainer)  — offset (160,344)-(480,376), barra de armas
├── AttackLabel      (Label)          — offset (160,332)-(480,343), "Atacando: X"
├── ZoomControls     (VBoxContainer)  — offset (622,30)-(636,60), botones + / −
├── PauseButton      (Button)         — offset (622,66)-(636,80), alterna la pausa
├── TargetMenu       (PanelContainer) — menú contextual, se posiciona en runtime
└── DeselButton      (Button)         — offset (526,351), visible=false, flat, text="×"
```

**El mapa táctico va pronto en la lista a propósito.** En un `CanvasLayer` el orden de los
hijos decide quién dibuja encima, y el mapa está donde está para que el resto del HUD le pase
por delante y siga siendo pulsable con el mapa abierto. Lo que evita el solape no es el orden
sino la **colocación**: el área de dibujo del mapa empieza en `y=26` (bajo `DeployedPanel`) y
acaba en `x=486` (antes de la columna de la derecha), así que ningún panel cruza el terreno y
la escala no baja por ello. Probarlo moviendo el mapa al final es tentador y sale mal:
entonces tapa el hangar y la lista de desplegadas.

---

### `UnitTag` — `ui/hud/unit_tag/unit_tag.gd`
```
extends Node2D   class_name UnitTag
```
La etiqueta que sale al seleccionar una unidad: una línea que se despliega (10 frames a
24 fps) y el nombre entrando detrás. No conoce ningún tipo de unidad — recibe una `Unit` y
muestra `get_display_name()`, así que sirve igual para un avión, un barco o un tanque.

**API:** `show_for(unit)` / `clear()`. Lo llama el HUD desde `show_selected_unit()` y
`clear_selected_unit()`; nadie más lo toca.

**Vive en el HUD, no colgada de la unidad, y ahí está todo el asunto.** Se construyó primero
al revés — dos nodos dentro de `av8b_harrier.tscn` con `top_level = true` — y esa versión
falló tres veces seguidas, cada una por un motivo distinto:

| Síntoma | Causa |
|---|---|
| Aparecía un frame lejísimos y desaparecía | `top_level` no hereda posición: se dibujaba en el sitio del frame anterior antes de que el reposicionado la corrigiera |
| Temblaba sin parar al volar | Se reposicionaba en `_physics_process`, pero el piloto mueve el avión en el `_physics_process` de un nodo **hijo** — el padre corre antes, así que leía la posición de un tick atrás, cada tick |
| **El texto vibraba con el zoom, y a 0,5x era ilegible** | Las dos de arriba se podían parchear. Ésta no: la cámara escala todo lo que vive en el mundo |

La tercera es la que obligó a rehacerlo. **Una etiqueta que sigue a una unidad no es parte
del mundo: es HUD que se mueve.** Debe medir siempre lo mismo y sólo cambiar de sitio. Eso
se consigue dejándola en el `CanvasLayer` y preguntándole a la unidad dónde cae en pantalla:

```gdscript
var on_screen: Vector2 = _unit.get_global_transform_with_canvas().origin
```

Es exactamente lo que ya hacía `_impact_timer` en `hud.gd` — el patrón estaba escrito al
lado y no se miró. Medido a tres zooms:

| Zoom | Escala de la línea | Tamaño de fuente |
|---|---|---|
| 0,5x | (1,1) | 16 |
| 1,0x | (1,1) | 16 |
| 2,0x | (1,1) | 16 |

**La colocación se hace arrastrando los nodos, no escribiendo números.** `_ready()` guarda
dónde quedaron `Line` y `Name` en la escena y usa eso como separación respecto a la unidad.
Hubo antes dos `@export` de offset y eran inservibles: se ajustaban contra el vacío, sin
nada con lo que comparar. Por eso la escena lleva además un `EditorGuide` — el sprite del
Harrier al 50%, que se apaga en `_ready()`. Misma treta que `MuzzleFlash`: **si algo se
coloca a ojo, en el editor tiene que verse contra qué**.

Dos detalles del arte que costaron una pasada: la línea va con `centered = false` (centrada,
su mitad izquierda se metía dentro del avión) y con `frame = 9` fijo en la escena, para que
en el editor se vea desplegada y no en el primer frame, que está casi vacío.

**La entrada del nombre** (`name_delay` 0,28 s, `name_fade_time` 0,25 s, `name_rise_px` 4)
va un instante detrás de la línea, como si la trajera ella. El deslizamiento se lleva en una
variable propia (`_rise`) y no animando la posición: la posición se reescribe entera cada
frame siguiendo a la unidad, así que un tween sobre ella se pisaría solo.

**El estado**, debajo del nombre y con su misma entrada: `Status: En espera`,
`Status: Moviéndose a H6`, `Status: Atacando a Su-33 Flanker-D`. Son **dos nodos**: el rótulo
`Status` con su texto fijo —es un letrero, se edita en la escena— y `Status/Value` colgando de
él, que es lo que cambia. Al colgar del rótulo, mover el "Status:" se lleva el valor detrás.

**El texto se compone aquí, no en la unidad.** Ella expone hechos —`attack_target`, y
`get_move_destination()`, que devuelve un punto— y el HUD los pone en palabras; así el mismo
dato le sirve al parte de eventos, que los cuenta distinto. La coordenada sale del `MapView` del
mapa táctico (`map_path`), la misma que usa el parte.

Dos reglas de comportamiento: **atacar manda sobre moverse**, y "moviéndose" sólo cuenta
*mientras se acerca* — una vez llegado orbita ahí, y eso ya es esperar.

---

### `BrevityCalls` — `ui/hud/brevity_calls/brevity_calls.gd`
```
@tool  extends Node2D   class_name BrevityCalls
```
Las llamadas de radio al disparar: `Fox Three!`, `Rifle!`, `Pickle!`. Sale sobre **cualquier
avión propio**, esté seleccionado o no — ahí está la diferencia con `UnitTag`, que acompaña a
uno solo: lo interesante es enterarte de lo que hacen los que no estás mirando.

Vive en el HUD y en píxeles de pantalla, por lo mismo que la etiqueta. Se engancha solo a las
unidades por el grupo, como el parte de eventos.

**El código sale del arma** (`brevity_code`): un arma nueva trae su llamada puesta. Lo que es
presentación se queda aquí — el cañón se canta `guns, guns, guns` porque en radio se repite tres
veces, pero el `.tres` sigue diciendo `Guns` y en el parte sale corto.

| export | por defecto |
|---|---|
| `hold_time` / `fade_time` | 1,8 s + 1,0 s |
| `offset` | `(30, −28)` — debajo del nombre |
| `font_size`, `color` | 16, ámbar |
| `gun_call_repeats` / `repeated_code` | 3, `"Guns"` |
| `same_call_window` | 2,8 s |

**Contra el spam, dos cortes distintos**, porque venía por dos caminos: `same_call_window`
agrupa repeticiones **del mismo arma** —una ristra de seis Mk-82 canta un solo `Pickle!`— y
además **un avión canta de uno en uno**: al llegar una llamada nueva, la anterior de ese avión
se manda a desvanecer. Sin lo segundo, soltar un misil y abrir con el cañón sacaba dos carteles
en la misma esquina.

Cada llamada es un `BrevityCall` (`brevity_call.gd`) suyo, no un `Label` reutilizado: pueden
coincidir varias. **Sobrevive a la unidad** — si derriban al avión justo después de disparar, su
última llamada se queda un momento donde estaba en vez de desaparecer con él.

---

### `SelectionPanel` — `ui/hud/selection_panel/selection_panel.gd`
```
extends PanelContainer
```
Solo un `Label` con autowrap. `show_unit(name)` / `clear()`.
**No meter botones dentro** — el panel es muy pequeño (~93×31px) y rompe el layout.

---

### `ActionsPanel` — `ui/hud/actions_panel/actions_panel.gd`
```
extends PanelContainer
signal action_pressed(action_name: String)
```
`show_actions(PackedStringArray)` — crea un `Button` por acción dinámicamente.
`clear()` — oculta el panel.

---

### `HangarWindow` — `ui/hud/hangar_window/hangar_window.gd`
```
extends PanelContainer
```
Ventana arrastrable. Patrón de drag: `TitleBar.gui_input` con `mouse_filter=STOP`.
- `open(ship: Node2D)` — recibe la unidad seleccionada (LHD Wasp)
- Lee loadout desde `PlayerFleet.get_loadout(ship.unit_name)`
- Selector de cantidad: 1–4, máximo disponible no desplegado
- Misiones: SEAD / CAP / CAS (botones, sin lógica aún)
- DESPLEGAR: `PlayerFleet.try_deploy` → `flight_deck.request_deploy(scene)`

---

### `DeployedPanel` — `ui/hud/deployed_panel/deployed_panel.gd`
```
extends PanelContainer
signal unit_selected(unit: Unit)
```
Panel superior con las unidades desplegadas, agrupadas por categoría (grupos de Godot `unit_maritime`/`unit_air`/`unit_ground` — sin referencia directa, se descubre igual que el minimapa está pensado que haga). Se refresca (`_refresh()`) cuando se agrega/quita un `Unit` de la escena (`get_tree().node_added`/`node_removed`, con flag `_dirty` para no recalcular más de una vez por frame).

Un cuadrito (`Button`, 30×14px) por unidad suelta o por **escuadrón**: si `unit.squad != null`, todos sus miembros colapsan en un solo cuadrito (con el nombre del líder), y si tiene más de 1 miembro se agrega un badge `xN` en la esquina inferior derecha (`Label` hijo del botón, `mouse_filter = IGNORE` para no tapar el click). Al presionar, emite `unit_selected(unit)` — la unidad individual, o `squad.leader` si es un escuadrón. `HUD` conecta esto a `unit_focus_requested`.

**Una baja no desaparece del panel: se apaga y se va al final de su fila.** Que un cuadrito se
esfume sin más deja al jugador dudando de si perdió algo o si nunca lo tuvo; verlo ahí, apagado,
es el recuento de la operación. El botón va `disabled` y sin `pressed` — no hay a dónde llevar
la cámara, lo que representaba ya no está en el mapa.

Se engancha a `Unit.died` (con repaso inicial diferido, como el parte de eventos) y guarda **el
nombre, no la unidad**: para cuando se dibuja, la unidad ya no existe y el panel es lo único que
queda de ella. Pendiente: **las bajas se acumulan sin tope**, así que en una operación larga la
fila se llenará de cuadritos apagados.

---

### `WeaponBar` — `ui/hud/weapon_bar/weapon_bar.gd`
```
extends HBoxContainer
```
Fila de botones cuadrados (34×34, `font_size` 7) abajo al centro (`x` 160–480, `y` 344–376
— hueco libre entre el minimapa y los paneles de la derecha). Uno por arma de la unidad
seleccionada, para elegir con cuál ataca.

**Sin `clip_text`:** un nombre que no cabe ensancha el botón en vez de perder letras en
silencio. El tamaño salió de medir con `Font.get_string_size()` — el nombre más ancho
("AGM-65") ocupa 27 px sobre 30 útiles.

| Método / Señal | Descripción |
|---|---|
| `show_weapons(unit)` | Reconstruye los botones. Se oculta sola si la unidad no tiene armas |
| `set_active(weapon)` | Repinta sin reconstruir |
| `refresh_ammo()` | Repinta al gastarse munición |
| `clear()` | Vacía y oculta |
| `weapon_selected(weapon)` | El jugador pulsó un arma |

Tres estados, para distinguir de un vistazo "no elegida" de "no disponible": activo a
alpha 1.0, no seleccionado a `_DIM_ALPHA` (0.45) y **agotado** a `_EMPTY_ALPHA` (0.22)
con `disabled = true` — elegir un arma que ya no está armaría un ataque que nunca sale.

Cada botón lleva la munición restante en un `Label` hijo anclado abajo a la derecha
(`font_size` 6, `MOUSE_FILTER_IGNORE` para no comerse los clicks). Va por dentro y no en
el texto porque el nombre ya ocupa el ancho entero. El cañón no muestra número: su
munición es −1, ilimitada.

Se entera por `Unit.ammo_changed` en vez de preguntar cada frame por algo que cambia de
tarde en tarde. **No guarda estado de selección**: la fuente de verdad es
`Unit.active_weapon`, porque la barra se reconstruye en cada selección. `HUD` hace de
intermediario — recibe `weapon_selected` y llama a `Unit.set_active_weapon()`.

---

### `CountermeasureBar` — `ui/hud/countermeasure_bar/countermeasure_bar.gd`
```
@tool  extends HBoxContainer   class_name CountermeasureBar
```
Chaff y bengalas de la unidad seleccionada, con lo que le queda de cada una.

**Barra aparte de la de armas, y no un par de botones dentro de ella.** Una contramedida no se
elige ni apunta, así que no debe leerse como una opción más de la rotación de armas. Se probó
metida en `WeaponBar` y se sacó.

Es `@tool` y **todo lo que se ve está exportado** — `button_size`, `font_size`, los textos, y la
posición como cualquier `Control`. Ésa era la pega de la primera versión: los botones se
construían por código y no se podían acomodar en el editor. En el editor enseña cargas de
muestra, porque si no la barra sería un rectángulo vacío imposible de colocar.

Los botones **no se pueden pulsar**, a propósito: el avión se defiende solo y el jugador no
pilota. Están porque saber que quedan tres cargas cambia si mandás ese avión o no, y el día que
haya pilotaje manual el botón ya está en su sitio. Se apagan al agotarse, como un arma sin
munición, y se enganchan a `Countermeasures.spent` para bajar solos.

---

### `ZoomControls` — `ui/hud/zoom_controls/zoom_controls.gd`
```
extends VBoxContainer
signal zoom_change_requested(step: int)
```
Dos botones cuadrados de 14×14 (`+` y `−`, `font_size` 8) apilados en el borde derecho,
debajo de `DeployedPanel` — hueco libre entre ese panel y `ActionsPanel` (y=313). Estilo
por `StyleBoxFlat` en código, misma paleta que `WeaponBar`.

**No sabe qué zoom hay puesto.** Emite `+1` / `−1` y recibe `set_state(level, count)`, con
lo que apaga el botón que ya no lleva a ninguna parte (`disabled` + alpha 0,3). Es el mismo
criterio de `WeaponBar` con las armas agotadas: se distingue de un vistazo "puedes" de "no
puedes", y la fuente de verdad sigue estando en un solo sitio, la cámara.

Para moverlos basta cambiar los `offset` del nodo en `hud.tscn`.

---

### `PauseButton` — `ui/hud/pause_button/pause_button.gd`
```
extends Button
signal pause_toggled(paused: bool)
```
Alterna `get_tree().paused`. Botón de 14×14 debajo de `ZoomControls`, misma columna.
`shortcut_key` es `@export` (por defecto `KEY_SPACE`; `KEY_NONE` lo desactiva) y se atiende
en `_unhandled_key_input`, igual que el ESC de `SelectionManager` — sin inventar un recurso
`Shortcut` para una sola tecla.

**Enseña la acción disponible, no el estado:** corriendo `||`, pausado `>`. Y pausado se
pinta en color de acento, porque con todo congelado no queda nada en pantalla que delate
en qué estado está.

**Sin cableado con nadie.** `paused` es estado del árbol, no de otro nodo: no hay a quién
pedírselo ni a quién avisar, así que no pasa por `HUD` → `SelectionManager` como el zoom.
`pause_toggled` existe para un aviso o un velo futuros; hoy no la escucha nadie.

**Qué sigue vivo en pausa se declara con `process_mode = Always` en cada escena** —
`hud.tscn`, `pan_camera.tscn`, `selection_manager.tscn` — y no con una lista dentro del
botón: se ve en el inspector de cada nodo y una escena nueva decide por sí misma. Se puede
panear, cambiar el zoom y **seleccionar** con la partida congelada; esto último hace una
consulta al servidor de física, que no se está simulando, y se comprobó que responde.

El hangar también responde en pausa: la orden se acepta pero el ciclo de cubierta no
arranca hasta reanudar, porque `FlightDeck` sí es pausable.

---

### `EventLog` — `ui/hud/event_log/event_log.gd`
```
extends PanelContainer   class_name EventLog
```
El parte de lo que va pasando, con la coordenada del mapa. Emite
`look_requested(world_position)` al pulsar una coordenada. `map_path` (exportado) apunta al
`MapView` de donde salen esas coordenadas.

| Evento | De dónde | Ejemplo |
|--------|----------|---------|
| Orden de movimiento | `SelectionManager` → `HUD.report_move_order()` | `AV-8B > F4` |
| Empieza a atacar | `Unit.attack_target_changed` | `AV-8B ataca T-14 (RIFLE) B2` |
| Baja enemiga | `Unit.died` | `Splash! T-14 B2` |
| **Baja propia** | `Unit.died` | `Perdido: AV-8B D1` + `   por 2S6` |
| **Te enganchan** | `Unit.tracked_by` | `AV-8B: MUD SPIKE D1` |
| **Te disparan** | `Unit.fired_upon_by` | `AV-8B: AAA, bajo fuego D1` |
| **Misil en el aire** | `Unit.missile_inbound` | `AV-8B: SAM LAUNCH D1` |
| **Se defiende** | `Countermeasures.dispensing_started` | `AV-8B: DEFENDING` |

**El disparo no tiene parte propio.** Lo tuvo: cada arma que salía escribía su línea, agrupando
las ristras para que una andanada de seis Mk-82 no fueran seis renglones. Aun así sobraba —
`ataca` ya dice que el compromiso empezó y `Splash!` que terminó, así que la línea del arma era
una tercera entrada del mismo suceso, y con varias unidades a la vez tapaba lo único urgente,
que son las alarmas. El código de brevedad se mudó a la línea de ataque, preguntándole a
`WeaponSelector.best_for()` qué elegiría para ese blanco. La munición se ve en el `WeaponBar`,
que es donde toca. Con esto se fue también todo el agrupador de andanadas.

**Aviso pendiente:** `attack_target_changed` sólo emite cuando el blanco **cambia**. Varias
pasadas sobre el mismo objetivo dan una sola línea y después silencio. Mientras existió la
línea del arma eso no se notaba. Si al jugarlo queda demasiado callado, la salida no es volver
al disparo por disparo sino reenganchar tras un rato sin atacar.

**Caer no se cuenta igual según de quién sea.** `Splash!` es lo que se canta al abatir algo, no
lo que se dice al perder a uno de los tuyos; de ahí las dos líneas distintas.

**Las alarmas van con la coordenada de la amenaza, no la del avión**: lo que el jugador necesita
saber es de dónde viene el fuego, para decidir por dónde sale. Y sólo se reportan las de
unidades propias — que a un enemigo lo enganche otro enemigo no es noticia suya. Morir sí se
cuenta de todos: saber que algo cayó importa venga de donde venga.

**Se engancha él solo a cada unidad por el grupo**, igual que el mapa saca sus puntos: nadie
tiene que avisarle de quién nace o muere. El repaso inicial va **diferido**, y no es un
detalle menor: en `_ready()` sólo existen las unidades que van antes que el HUD en la escena
—las de después aún no están en el grupo— y `node_added` tampoco las coge, porque ya estaban
en el árbol cuando el registro se conectó. Sin diferirlo, media flota no se registraba. Las
órdenes sí llegan de fuera: no las emite nadie, las da el jugador.

**Las coordenadas se leen del mapa táctico, no del minimapa.** En el minimapa las zonas se
agrupan hasta caber en 87 px, así que el mapa entero sale como dos o tres coordenadas y el
parte diría `A1` de todo. Se piden con `MapView.zone_label_at()`, que usa el tamaño de zona
que se está dibujando de verdad.

**Cada línea es una instancia de `event_entry.tscn`**, no nodos fabricados en código. Ver
[`EventEntry`](#evententry--uihudevent_logevent_entrygd) — es la diferencia entre poder ajustar
el parte mirándolo y tener que arrancar el juego para ver qué pasó.

**El registro no tiene caja ni fondo.** El panel llegó a tener marco dibujado, barra de título
y fondo navy; se quitó entero (`StyleBoxEmpty`) porque ocupaba 144×160 px de una pantalla de
640×384 — casi la cuarta parte del ancho y el 40% del alto — para mostrar seis renglones. Sin
marco que descontar, el ancho útil de texto pasó de 123 a 191 px, y el registro sólo ocupa lo
que ocupa su texto. El PNG del panel sigue en `assets/art/UI/event_log_panel.png`: es un
nine-patch y está pensado para reusarse en las ventanas de acción (hangar, mapa táctico).

**Sin fondo, el texto necesita contorno.** Va sobre el terreno —selva verde, agua, arena
clara—, así que un color plano se pierde contra la mitad de los fondos. `outline_size = 2` en
negro es lo que lo hace legible venga lo que venga debajo.

**El panel mide lo que midan sus líneas y crece hacia arriba**, con el borde de abajo quieto,
como una consola. Vacío no se dibuja. `set_bottom(y)` lo mueve el HUD cuando el minimapa
cambia de tamaño: comparten columna y el minimapa manda, porque es el que el jugador estira.

El alto se recalcula con `lines.minimum_size_changed`, no sólo al añadir una entrada: cuando
llega, el texto todavía no sabe de qué ancho dispone y pide más alto del que va a necesitar.
Sin volver a medir después, el panel se quedaba con esa primera cuenta — 299 px medidos donde
hacían falta 104.

### `EventEntry` — `ui/hud/event_log/event_entry.gd`
```
extends Control   class_name EventEntry
```
La plantilla de una línea: el filete separador, el ícono y el texto. **Es una escena, no nodos
creados en código.** La primera versión fabricaba cada fila a mano (`HBoxContainer.new()`,
`TextureRect.new()`…) y el resultado era invisible en el editor: no había forma de ajustar
fuente, color o separaciones sin arrancar el juego y adivinar. Ahora se abre
`event_entry.tscn`, se ve con contenido de muestra y se toca ahí.

**Los tres nodos van a posición libre, fuera de contenedores.** No es descuido: en Godot un
contenedor decide dónde van sus hijos y el editor bloquea el arrastre. Se eligió poder mover
el ícono y el texto con el ratón, y el precio es que el alto no se calcula solo — de eso se
encarga `_fit()`, y es la razón de que el script exista. La entrada mide lo que llegue más
abajo (texto o ícono) más `padding_bottom`.

| Ajuste | Dónde | Qué hace |
|--------|-------|----------|
| Fuente, tamaño, color, contorno | nodo `Text` | lo visual del texto |
| Posición del ícono | nodo `Icon` | se arrastra |
| Largo del filete | nodo `Rule`, `offset_right` | 112 px hoy |
| `padding_bottom` | raíz, exportado | aire bajo el texto (4) |
| `fade_after` / `fade_time` / `faded_alpha` | raíz, exportado | 6 s / 1,5 s / 0,35 |

**Las entradas se transparentan, no desaparecen.** A los 6 s bajan a `alpha 0.35` y se quedan
ahí: siguen leyéndose y su coordenada sigue siendo pulsable. El registro no pierde historia,
sólo deja de robar la vista. Si una línea se reescribe, vuelve a plena vista — una línea que
cambia mientras se apaga no se lee.

**El texto va en `MOUSE_FILTER_PASS`.** En `IGNORE` las coordenadas dejaban de ser pulsables;
en `STOP` el registro robaría al mapa todos los clicks de su superficie, que ahora es
transparente. `PASS` atiende la coordenada y deja pasar el resto.

**Antes de meter un signo tipográfico en el parte hay que comprobar que la fuente lo tenga.**
El separador de las órdenes era `→` y descuadraba la línea entera: M5X7 no tiene ese glifo, así
que Godot lo sacaba de una fuente del sistema cuyo alto de línea es de 23 px en vez de 13. La
fila se estiraba y el ícono se quedaba arriba. Ninguna de las dos fuentes del proyecto tiene
`→ ← ↑ ↓ — – … • ‹ ›`; sí tienen acentos, `ñ`, `¿`, `¡` y `×`.

**Los nombres se acortan al primer espacio** (`_short()`): en el parte cabe `2S6`, no `2S6
Tunguska`, y el jugador lo reconoce igual porque el nombre completo está en el panel de
selección. Se abrevian nombres propios, nunca el verbo — `Harrier B4` no dice nada.

### Mapa — `ui/hud/minimap/`

Cuatro archivos y **un solo dibujo**: el minimapa de la esquina y el mapa táctico a
pantalla completa son el mismo `MapView` con distintos ajustes, sobre la misma imagen a
distinta escala.

#### `MapTerrain` — `map_terrain.gd`
```
extends RefCounted   class_name MapTerrain
```
El terreno reducido a una `ImageTexture` de **un píxel por celda**, más las cuentas de
coordenadas. No es un nodo: es el dato que dibujan los dos mapas.

| Miembro | Descripción |
|---------|-------------|
| `build(layer, cells_per_pixel)` | estático. Construye la imagen leyendo el `TileMapLayer` |
| `texture` / `cells` / `origin_cell` / `tile_px` / `world_rect` | la imagen y las medidas del mapa |
| `cells_per_px` | cuántas celdas resume cada píxel. 1 salvo mapas enormes |
| `zone_count(n)` / `zone_at(world, n)` / `zone_center(zone, n)` / `label_at(world, n)` | coordenadas |
| `column_label(i)` | estático. `A`…`Z`, `AA`, `AB`… |

**El tamaño sale del `TileMapLayer`, nunca de una constante.** El mapa cambia por misión;
apuntarlo en algún sitio sería tener dos verdades y que una envejezca. Misma fuente de la
que `PanCamera` saca sus límites.

**El tipo de terreno sale del dato, no del dibujo.** El TileSet lleva una capa de datos
personalizada `tipo` (`agua`, `tierra`, `arena`), marcada **una vez por tile en el atlas**
—no por celda pintada—, y `COLORS` dice de qué color se pinta cada uno. Un tipo que esté en
el mapa pero no en `COLORS` sale en rojo (`UNKNOWN_COLOR`): mejor que cante a que
desaparezca. Se descartó deducir el terreno del color dominante del tile: pinta bien pero
no *sabe* nada, y dos tiles parecidos pueden ser cosas distintas.

**Un píxel que resume varias celdas se decide por mayoría, no por promedio.** Promediar
colores inventa uno que no está en Resurrect64.

**El origen no es (0,0)** — hoy el mapa arranca en la fila −6. Las coordenadas cuentan
desde `origin_cell`; contarlas desde el cero del mundo desplazaría todas las etiquetas sin
que se notara.

#### `MapView` — `map_view.gd`
```
extends Control   class_name MapView
```
Dibuja terreno, rejilla, coordenadas, el recuadro de lo que se ve en pantalla, las unidades,
el destino de la orden en curso, el recuadro de la unidad seleccionada y **las ondas de los
contactos** (ver `ThreatPulses`).

| Señal | Cuándo |
|-------|--------|
| `map_clicked(world_position: Vector2, unit: Unit)` | Click izquierdo dentro del terreno |
| `map_context_requested(world_position: Vector2, unit: Unit)` | Ídem con el derecho |

API además de los exportados: `set_order_marker(world)` / `clear_order_marker()`,
`set_selected_unit(unit)`, `unit_at(local_position)`, `world_to_local()` / `local_to_world()`.

| Exportado | Minimapa | Táctico | Qué hace |
|-----------|----------|---------|----------|
| `show_grid` | `true` | `true` | rejilla de zonas de coordenadas (**no** de celdas de terreno) |
| `show_labels` | `false` | `true` | letras arriba y abajo, números a los lados |
| `grid_texture` | — | — | celda dibujada, repetida una por zona. Sin ella se trazan líneas |
| `grid_color` | `#2d3a4a80` | igual | color de las líneas, **translúcido**: es una guía, no debe competir con el terreno |
| `grid_dash` / `grid_gap` | `4` / `3` | igual | punteado, **en píxeles de pantalla** |
| `grid_border` | `false` | `true` | recuadro alrededor del mapa. Sobra cuando el panel ya trae marco dibujado |
| `zone_cells` | — | `8` | celdas por lado de zona **que se piden**. **El número a mover si las coordenadas salen gruesas o finas** |
| `show_viewport_rect` | `true` | `true` | recuadro de lo que se está mirando |
| `show_units` | `true` | `true` | un punto por unidad, del color de su bando |
| `marker_px` | `2` | `4` | lado del punto **en píxeles de pantalla** |
| `show_alerts` | `true` | `true` | ondas donde nos enganchan o nos disparan |
| `alert_radius_px` | `12` | `28` | hasta dónde se abre la onda, **en píxeles de pantalla** |
| `alert_rings` | `3` | `3` | cuántas ondas por contacto |

**La escala no se configura, se calcula:** el mayor número entero de píxeles por celda que
quepa en el control. Si no cabe ni uno, se resume el mapa dentro de la propia imagen y se
dibuja a 1. **Nunca hay escala fraccionaria**, que con Nearest es lo que hace hervir los
píxeles al mover la cámara — el mismo motivo por el que `PanCamera` sólo usa potencias de
dos. Con el mapa de 64×45: minimapa 1 px/celda (imagen de 64×45 en un panel de 87), táctico
8 px/celda (512×360). Se recalcula en `resized`, así que redimensionar el panel basta.

**La rejilla se traza, no se pega.** Se probó a repetir una celda dibujada de 8×8 px, una por
zona (`grid_texture`, que sigue soportado). Salió mal por una razón que vale para cualquier
adorno del mapa: **la textura escala con el terreno**, así que una línea de 1 px del dibujo se
ve de 4 px cuando el minimapa está a 4x. Trazada, la línea mide 1 px de pantalla siempre —
igual que los puntos de las unidades y por el mismo motivo: la rejilla es un icono encima del
mapa, no terreno. El punteado (`grid_dash` / `grid_gap`) tampoco escala.

Va **translúcida** (`alpha 0.5`) y sin recuadro exterior en el minimapa, porque el marco ya lo
pone el panel dibujado.

**Sólo hay una rejilla: la de zonas.** Hubo una segunda, fina, con una línea por celda de
terreno — 64×45 = casi 2900 cuadritos de 7 px. Se quitó: no era información sino el tamaño
del tile, un detalle de implementación, y a esa densidad no se lee como cuadrícula sino como
rayado. Sirve de referencia el sistema de las cartas náuticas (Silent Hunter, Sea Power,
Command): **una sola rejilla, pocas divisiones, letra+número**, y subdividir sólo con zoom.

**`zone_cells` es una petición, no una orden.** `_zone_side()` la duplica tantas veces como
haga falta hasta que una zona mida al menos 24 px en pantalla. Con el mapa de 64×45 a 7 px
por celda, 8 celdas dan zonas de 56 px → **8×6 zonas, A1…H6**. En un mapa del doble de
grande las zonas pasarían solas a 16 celdas y seguiría leyéndose igual, sin retocar el
exportado por misión. `zone_label_at(world)` devuelve la coordenada con el tamaño que se está
dibujando **de verdad** — el registro de eventos debe preguntar por ahí, o el texto y el
dibujo podrían no coincidir.

**Las coordenadas van fuera del mapa**, repetidas en los dos bordes para no tener que seguir
una fila con el dedo hasta el otro extremo. Dentro no caben —a 8 px por celda una zona de
4 celdas mide 32 px— y taparían el terreno.

**El recuadro de pantalla sale de la transformación del lienzo, no de la cámara.** Es una
propiedad de lo que hay en pantalla, no de un nodo concreto, así que el mapa lo dibuja sin
conocer a nadie.

**Las unidades salen del grupo `Unit.GROUP`, preguntando al dibujar.** No hay lista propia
ni suscripción a `died`: el mapa no se entera de quién nace ni quién muere y no hay nada que
mantener sincronizado. El color lo da `Team.color(unit.team)`, así que un bando nuevo se
pinta solo.

**El punto tiene tamaño fijo en píxeles de pantalla, no a escala del mapa** — es un icono,
no terreno: a 1 px por celda un punto a escala sería invisible y en el mapa grande una
mancha. Lleva **un filo oscuro de 1 px**, que no es adorno: el azul del jugador (`#8fd3ff`)
y el del agua (`#4d9be6`) se parecen demasiado y un punto de 2 px sin borde desaparece. Una
unidad fuera del mapa **no se pinta pegada al borde**: se metería encima de las coordenadas
y mentiría sobre dónde está.

Con `show_units` el mapa **se redibuja cada frame**; sin ellas basta con mirar si cambió la
transformación del lienzo. Son un puñado de rectángulos, y un mapa oculto no se dibuja.

**El click izquierdo se cuenta al soltar, no al pulsar.** Hasta que el dedo no se levanta no
se sabe si era un click o el principio de una pulsación mantenida — que aquí significa lo
mismo que en el mundo: abrir el menú de la unidad. Lo reconoce `LongPress`, el mismo detector
que usa `PanCamera`. De regalo, arrastrar sobre el mapa ya no dispara una orden. El botón
derecho no espera a nada: en PC no hay ambigüedad.

**`unit_at()` busca contra los puntos dibujados, no contra el mundo.** A la escala del mapa un
píxel son decenas de píxeles de mundo, así que una consulta de física en el punto pulsado no
acertaría a una unidad nunca: lo que el jugador apunta es el punto que ve. Gana el más
cercano, con 3 px de margen alrededor porque un cuadrito de 4 px no se acierta ni con ratón.
Igual que en el mundo, pulsar a un miembro de escuadrón devuelve al líder.

**El recuadro de cámara y el de la unidad seleccionada son excluyentes.** Con una unidad
seleccionada la cámara la sigue, así que el recuadro de pantalla se convertía en un cuadro
enorme persiguiendo por todo el mapa al mismo punto que ya está resaltado. Habiendo selección
se dibuja **su** recuadro (accent, separado 3 px del punto para no comerse el color del bando)
y se calla el de cámara; sin selección vuelve el de cámara. **Sólo aplica al mapa táctico** —
al minimapa no se le pasa la selección, y ahí el recuadro de cámara se queda siempre.

**El destino de la orden se dibuja en los dos mapas**, con la misma cruz dentro de un círculo
que planta `MoveMarker` en el mundo y al mismo tamaño en ambos: es un icono. Con el mapa
abierto el marcador del mundo no se ve, y sin esto no habría forma de saber a dónde se mandó
la unidad.

#### `ThreatPulses` — `threat_pulses.gd`
```
extends RefCounted   class_name ThreatPulses
```
Lleva la cuenta de los contactos que hay que señalar en un mapa: quién nos enganchó, **desde
dónde** y hace cuánto. Se engancha solo a las unidades por el grupo, como el parte de eventos.

**Sólo lleva la cuenta; no dibuja.** El dibujo es de cada mapa, que sabe su escala — el mismo
contacto sale con un anillo de 12 px en el minimapa y de 28 en el grande.

| | |
|---|---|
| `Kind.TRACKED` | ámbar — te siguen, aún no disparan |
| `Kind.FIRED_UPON` | rojo — te están disparando |
| `LIFETIME` | 5 s. Del mismo orden que `Unit.ALARM_SILENCE`: más largo y los pulsos se solaparían consigo mismos |

`active()` devuelve los vigentes y **de paso tira los caducados**, así que no hace falta
limpiarlos por otro lado mientras alguien pregunte al dibujar.

Se guarda **la posición de la amenaza, no la del avión**, y se guarda la posición y no la
unidad: el contacto es un sitio y un momento, y sigue valiendo aunque quien disparó se mueva o
deje de existir.

**Cada mapa tiene su instancia.** Parece desperdicio y es justo lo que da el comportamiento
buscado: el mapa grande está oculto casi siempre pero **sigue apuntando lo que pasa**, así que
al abrirlo porque algo sonó se ven los contactos vivos en vez de nada. Verificado con el HUD
real: 1 pulso registrado con `visible: false`.

---

#### `Minimap` — `minimap.gd`
```
extends PanelContainer   class_name Minimap
```
El mapa pequeño. Emite `expand_requested`. **No es un mando de navegación**: a 1 px por
celda no cabe una coordenada ni tendría sentido apuntar a un sitio concreto, así que el
minimapa entero —terreno y marco— es un botón que abre el grande. Reenvía a su `MapView` el
destino de la orden (`set_order_marker` / `clear_order_marker`) y nada más: no sabe qué unidad
está seleccionada, y por eso conserva su recuadro de cámara.

**El panel se ajusta al dibujo, no al revés.** La escala del mapa es entera, así que en un
panel de tamaño cualquiera siempre sobra borde muerto — se veía como un marco negro alrededor
del terreno. Aquí se mira lo que ocupa el dibujo (`MapView.drawn_size()`, avisado por
`refitted`) y el panel se recorta a esa medida, con el **borde de abajo fijo**: vive en la
esquina y sólo tiene sentido crecer hacia arriba.

**Se estira arrastrando el borde de arriba** (`GRIP_PX`, 10 px — el grosor del marco dibujado;
más allá empieza el mapa y agarrar ahí sería robarle el click. Las dos rayitas que avisan de
que se puede estirar están dibujadas en el PNG, no las pinta el código). **Estirar elige
escala, no píxeles**: el alto pedido se traduce
a la escala entera que quepa y el panel se pone del tamaño exacto del dibujo a esa escala, así
que salta de 1x a 2x a 3x sin franjas negras por el camino (`MAX_HEIGHT` limita el tope).
Estirar sólo a lo alto no bastaba: el ancho también manda sobre la escala, así que crecen los
dos. El alto pedido se guarda aparte del real (`_wanted_height`) porque si se leyera del panel
—que salta por escalones— el arrastre se quedaría atascado en vez de seguir al ratón.

En `_resize_to()` **la posición se asigna antes que el tamaño**: cambiar el tamaño avisa a
quien escuche `resized`, y el HUD usa ese aviso para recolocar el `EventLog` justo encima. Al
revés, leería el sitio viejo y quedaría un hueco descuadrado.

Su `MapView` tiene `mouse_filter = IGNORE`: todo el input lo atiende el panel, que es quien
distingue el agarre del resto.

**El marco es un nine-patch sobre `assets/art/UI/minimap_panel.png`** (84×87), con cortes en
**15 izq / 17 arriba / 21 der / 5 abajo**. Esos números no son estéticos: son dónde acaban los
detalles dibujados. Un nine-patch sólo conserva 1:1 **las cuatro esquinas**; los bordes se
estiran en un eje y el centro en los dos. La sombra azul de arriba a la izquierda ocupa hasta
x14/y16 y las marcas de agarre de arriba a la derecha empiezan en x63, así que los cortes
tienen que dejarlas dentro de la esquina o se deforman al estirar el panel. Se llegó ahí
después de dos intentos con márgenes demasiado pequeños.

**Cómo comprobarlo, que es lo que faltó las dos veces:** recorrer las cuatro franjas de borde
y exigir que **cada fila del borde superior e inferior sea de un solo color a lo ancho, y cada
columna del izquierdo y el derecho de un solo color a lo alto**. Si alguna varía, ahí hay
dibujo en zona estirable. Con los cortes actuales todas son uniformes, y por eso no hace falta
`axis_stretch = TILE`: estirar un color plano da lo mismo que repetirlo.

**Regla para futuros paneles:** lo figurativo —remaches, una brújula, marcas— va pegado a una
esquina, o sale del PNG y se cuelga como nodo propio encima. En mitad de un borde no hay
margen que lo salve. Los cortes se ponen siempre desde Godot: el PNG no los lleva dentro, así
que el arte no necesita cambios, sólo hay que medirlo.

#### `TacticalMap` — `tactical_map.gd`
```
extends Control   class_name TacticalMap
```
El mapa a pantalla completa. Emite `clicked(world, unit)`, `context_requested(world, unit)`,
`opened` y `closed`. Se abre pulsando el minimapa o con `shortcut_key` (`M`, `KEY_NONE` la
desactiva), y **se cierra con esa tecla o con el botón `×`** — el atajo no existe en móvil, y
sin el botón no habría salida.

**El mapa no decide qué significa un click.** Depende de qué haya seleccionado, y de eso sabe
`SelectionManager`; aquí sólo se cuenta el gesto, igual que se hace con la cámara. `_selected`
existe únicamente para el rótulo y para pasarle la selección al `MapView`.

**Pulsar no cierra el mapa.** Se dirige a la unidad, se ataca o se mira sin salir de él: el
destino queda marcado en el propio mapa y el recuadro de cámara enseña a dónde se fue la
vista. Cerrar es cosa de la tecla o del botón.

API: `open()` / `close()` / `toggle()`, `set_selected_unit(unit)`, `set_order_marker(world)` /
`clear_order_marker()`, y `marker_position(unit)` — dónde cae el punto de una unidad en la
pantalla, que es lo que el HUD usa para colocar el menú contextual.

Tapa la pantalla y **se come los clicks a propósito**: con el mapa abierto, una pulsación no
puede colarse hasta el mundo y dar una orden de movimiento sin querer. Funciona en pausa sin
hacer nada, porque cuelga del HUD y el HUD ya es `process_mode = Always`.

**Árbol de `tactical_map.tscn`:**
```
Control (TacticalMap)      — 640×384, mouse_filter = STOP
├── Backdrop     (ColorRect) — pantalla completa, opaca
├── Map          (MapView)   — (0,26)-(486,384): esquiva la barra superior y la columna derecha
├── Hint         (Label)     — (492,126), autowrap: qué hará el siguiente click
└── CloseButton  (Button)    — (620,86), bajo el de pausa
```

**El terreno se reconstruye al abrir**, no al arrancar: el mapa cambia por misión y así no
hay que acordarse de avisar a nadie al cargar otro.

---

## Autoloads

### `PlayerFleet` — `core/fleet/player_fleet.gd`
```
extends Node   (Autoload)
```
Lo que el jugador posee: aeronaves y armamento. **Hardcodeado** — reemplazar con
sistema de puerto cuando exista.

```gdscript
_available_weapons = [ aim9, aim120, agm65, mk82, gbu54 ]   # armas del jugador

_loadouts = {
    "LHD Wasp": [
        { "display_name": "AV-8B Harrier II",
          "scene": preload("res://core/unit/av8b_harrier/av8b_harrier.tscn"),
          "total": 6, "deployed": 0,
          "weapon_loadouts": _HarrierLoadouts.build(_available_weapons) }
    ]
}
```

`_available_weapons` se declara **antes** que `_loadouts`: los inicializadores de miembro
corren en orden de declaración y `_loadouts` lee esa lista. Quitar un arma de ahí hace
desaparecer del hangar las misiones que la necesitan.

El armamento vive aquí y no en un autoload aparte a propósito: es "lo que el jugador
tiene", igual que las aeronaves, y como todo esto lo reemplaza la pantalla de puerto,
partirlo en dos duplicaría esa migración.

API: `get_loadout(ship_name)`, `try_deploy(entry) → bool`, `recall(entry)`.

---

## Patrones establecidos

### Rotación con sprite Y-forward
El sprite mira hacia el eje Y local (arriba en el editor = adelante en el mundo).
```gdscript
# Ángulo de heading desde la transformada
var fwd: Vector2 = global_transform.y
var heading: float = atan2(fwd.y, fwd.x)

# Aplicar rotación desde vector de movimiento
global_rotation = atan2(-move_dir.x, move_dir.y)
```

### Steering con tasa máxima de giro
```gdscript
var diff: float = wrapf(desired_heading - _heading, -PI, PI)
_heading += clampf(diff, -turn_rate * delta, turn_rate * delta)
var move_dir: Vector2 = Vector2(cos(_heading), sin(_heading))
```

### Duck-typing para señales/métodos opcionales
```gdscript
if unit.has_signal("order_fulfilled"):
    unit.order_fulfilled.connect(callback, CONNECT_ONE_SHOT)
if unit.has_method("receive_move_order"):
    unit.receive_move_order(target)
```

### Señales de un disparo
```gdscript
source.signal_name.connect(callback, CONNECT_ONE_SHOT)
```

### NodePath exportado para referencias entre nodos
Exportar `NodePath` y resolver con `get_node()` en `_ready()` — no wiring automático.
```gdscript
@export var camera_path: NodePath
var _camera: PanCamera
func _ready() -> void:
    _camera = get_node(camera_path) as PanCamera
```

### Ventana arrastrable (patrón)
`PanelContainer` → `VBoxContainer` → `TitleBar (HBoxContainer, mouse_filter=STOP)` + `Content`.
Drag en `TitleBar.gui_input`. Ver `HangarWindow` como referencia.

### _draw() con visibilidad
Si usas `_draw()` en un nodo que puede ocultarse/mostrarse, llamar `queue_redraw()` en `NOTIFICATION_VISIBILITY_CHANGED`.

### Lo que sigue a una unidad pero se lee, va en el HUD
Nombres flotantes, barras de vida, cuentas atrás: **no cuelgan de la unidad**. Viven en el
`CanvasLayer` y cada frame preguntan dónde cae la unidad en pantalla
(`get_global_transform_with_canvas().origin`). Colgarlos de la unidad los mete en el mundo,
y entonces el zoom los escala: a 0,5x el texto se vuelve ilegible mientras el resto del HUD
se queda quieto, que es justo lo contrario de lo que espera el jugador. Ver `UnitTag` y
`HUD._impact_timer`.

Corolario: la separación se mide en **píxeles de pantalla**, no de mundo. Se ve igual con
cualquier zoom, sin cuentas.

### Un `Control` no es un nodo de mundo
`snap_controls_to_pixels` (activo por defecto) redondea la posición de todo `Control` al
píxel — pensado para HUD fijo. Un `Label` colocado en el mundo y visto con zoom vibra por
eso: el redondeo cae en el espacio equivocado y el zoom lo magnifica. O se dibuja con
`_draw()` (como `SelectionIndicator`), o se pone en el HUD, que es donde un `Control` está
en su sitio.

### Si algo se coloca a ojo, poner contra qué mirarlo
Un `@export` de offset que se ajusta sin referencia visual se ajusta contra el vacío. La
escena debe traer una guía —el sprite de la unidad, el arma, lo que sea— visible en el
editor y apagada en `_ready()`. Y mejor todavía: que la colocación se lea de **dónde quedó
el nodo** en vez de un número aparte, para que arrastrar con el ratón sea el ajuste. Ver
`UnitTag.EditorGuide` y `MuzzleFlash`.

### Un solo portero por regla
Cuando una regla tenga varias vías de entrada, ponerla en el punto por donde pasan todas,
no en cada una. Ejemplo: "el enemigo no recibe órdenes" vive dentro de
`SelectionManager._issue_move_order()`, que cubre el click derecho y el izquierdo en vacío.
Repetirla en cada llamador es donde aparecen las incoherencias.

### Enum de una clase con `class_name`
Declarar las firmas con el nombre cualificado (`Team.Side`, no `Side`) aunque estés dentro
del propio archivo. GDScript trata el enum local como un tipo distinto del que ven los
demás scripts y las llamadas de fuera fallan a compilar.

### Una unidad no necesita script hasta que tenga comportamiento
`Unit` ya da identidad, selección, contorno y armamento. Un enemigo estático o un decorado
seleccionable son escena + `UnitType`, nada más. Ver `T-14 Armata`.

### Objetos liberados y comparación `== null`
En Godot, un objeto liberado (`queue_free()`) se compara `== null` como verdadero. Un
patrón como `if valor_actual == nuevo_valor: return` (guarda de "no hubo cambio") es
peligroso si `valor_actual` puede haber muerto: tras la liberación, comparar contra otro
`null` da `true` y la guarda se traga un cambio real — por ejemplo, que un ataque terminó
porque el objetivo murió. Regla: la comparación de "sin cambios" sólo es de fiar si el
valor **anterior** sigue siendo `is_instance_valid()`; si no, tratarlo como si ya fuera
`null` y dejar pasar la actualización. Ver `Unit.set_attack_target()` y
`SelectionManager._mark_target()`.

**La otra cara del mismo fallo: *usar* la referencia, no compararla.** Una lista de
objetos vivos que se limpia en un proceso (física) y se lee en otro (`_process`) tiene un
hueco en el que la referencia sigue en la lista y ya no vale nada; leerla o convertirla
revienta. Regla: `is_instance_valid()` antes de tocar cualquier elemento de una lista que
no se limpia en el mismo sitio donde se lee. Ver `WeaponSystem.time_to_impact()`.

### Comportamientos hermanos que comparten un actuador
Cuando dos comportamientos distintos (p. ej. `OrbitBehavior` y `AttackRunBehavior`) mueven
al mismo actuador (`PlaneController`) dándole puntos, que no se sepan el uno al otro: cada
uno sólo llama `set_target`/`update_target` sobre el piloto. Quien los posee (`Av8bHarrier`)
es el árbitro — para uno explícitamente antes de arrancar el otro, porque si los dos
procesan a la vez se pisan el objetivo cada frame.

El actuador tampoco decide el régimen: `set_cruising()` lo pone quien manda al avión, no
el piloto. El piloto sabe volar; **cuándo** hay que ir despacio es de quien da la orden.

### Lo que se le pide a un actuador es la intención, no el número
Corolario del anterior, y la regla que más veces se ha roto en este proyecto. Un
comportamiento dice "despacio", no "a 90 px/s"; la cubierta pregunta a qué velocidad
despega el avión en vez de tener la suya. Un número absoluto en otro script duplica algo
que no le pertenece y se desincroniza en cuanto se toca el original — y en silencio,
porque nada falla: sencillamente deja de significar lo que significaba.

Tres casos reales, los tres del mismo día:
- `AttackRunBehavior.attack_speed` = 90, igual que la `max_speed` del Harrier: frenar
  para atacar no frenaba nada.
- `FlightDeck.takeoff_speed` = 120 contra una `max_speed` de 90: el piloto lo recortaba
  sin avisar y la animación de pista iba a una velocidad imposible.
- El óvalo de `OrbitBehavior` con medidas fijas que no sabían nada del radio de giro del
  avión: al cambiarlo, el circuito se rompió entero.

El contraejemplo está en el mismo archivo: `break_off_margin`, `separation_gain` y
`egress_overshoot` son **multiplicadores** sobre valores que llegan de fuera (el alcance
del arma, la distancia actual). No duplican nada, así que no pueden desincronizarse.
Cuando haga falta un número que depende de otro sistema, que sea relativo o preguntado.

Excepción que no lo es: `sprite_offset_deg` se repite en `PlaneController`,
`GuidedMissile` y `GlideBomb` con el mismo −90, pero es un dato **de cada dibujo** — tres
sprites distintos que podrían estar orientados de tres maneras. Está bien donde está.

### Catálogo y estado no pueden ser el mismo objeto
`WeaponLoadout` describe una configuración (catálogo, compartido) y también la carga real
de un avión con su munición (estado, de esa salida). Son incompatibles: descontar sobre el
catálogo se lo quita a todas las unidades del modelo, para siempre. Quien recibe el objeto
se queda con un `clone()`, y **clonar en el receptor y no en quien llama** es lo que hace
que no se pueda olvidar. Aplica a cualquier resource compartido que gane estado mutable.

### El dato manda sobre el comportamiento
El arma declara su envolvente (`min_range`, `max_range`, `firing_arc_deg`) y el vuelo se
organiza alrededor de ella; el comportamiento no conoce armas y el arma no conoce vuelo.
Quien los junta es la unidad, que traduce una a otra y rehace las distancias si el dato
cambia a mitad de acción. Lo mismo con `salvo_size` / `salvo_spread`: "de uno en uno" o
"toda la carga con dispersión" es un número en un `.tres`, no una rama de código.

Mismo criterio con el terreno: **qué es un tile lo marca el artista en el TileSet, no lo
adivina el código mirando el dibujo**. La capa de datos `tipo` se rellena una vez por tile
en el atlas —no por celda pintada, que son miles— y todo lo que necesite saber de terreno
la lee. Deducirlo del color dominante del tile llegó a plantearse y se descartó: pinta bien
pero no *sabe* nada, y dos tiles parecidos pueden ser cosas distintas. El color se usó sólo
como borrador para no marcar 101 tiles a mano la primera vez.

### La escala de una vista se calcula, no se configura
Todo lo que enseñe el mundo a otro tamaño —el minimapa, el mapa táctico— saca su escala del
sitio que tiene y del tamaño real del mapa, cogiendo **el mayor entero que quepa**. Nunca un
número escrito a mano: el mapa cambia por misión y el panel no, así que cualquier constante
se queda vieja o produce una escala fraccionaria. Y una escala fraccionaria con filtro
Nearest descarta píxeles en un patrón irregular que hierve al mover la cámara — mismo motivo
por el que `PanCamera` sólo admite potencias de dos. Cuando ni el entero más pequeño cabe,
se reduce **el dato** (varias celdas por píxel de imagen) en vez de encoger el dibujo. Ver
`MapView` y `MapTerrain`.

La misma idea vale para lo que se dibuja encima: `zone_cells` dice el tamaño de zona que se
**quiere**, y la vista lo agrupa hasta que la coordenada se lee. Un exportado que fija un
resultado visual se queda viejo en cuanto cambia el mapa o el panel; uno que expresa una
intención sigue valiendo. **Exportar la intención, calcular el resultado.**

### Limitar la maniobra por radio, no por velocidad angular
Un móvil con tope de grados por segundo gira **más cerrado** cuanto más rápido va, que es
al revés que la física y produce proyectiles imposibles de esquivar. Con tope de radio de
giro, la velocidad angular disponible sale de dividir velocidad entre radio: más rápido,
más abierto, y existe una geometría en la que no llega. Ver `GuidedMissile.min_turn_radius`.

### El fallo sale de la simulación, no de un dado
Nada de tirar una probabilidad al final para decidir si un arma acierta: es invisible para
el jugador, que no puede leer en pantalla por qué falló. Los mecanismos son físicos —
combustible finito, alcance mínimo, espoleta por máximo acercamiento (detonar cuando la
distancia deja de bajar, no cuando baja de un umbral) — y las contramedidas futuras
encajan como blancos falsos reales y degradación del guiado, no como un porcentaje.

### Lo que sobrevive a la pausa lo declara cada escena
`process_mode = Always` va en el nodo raíz de quien tenga que seguir funcionando con
`get_tree().paused` — hoy `hud.tscn`, `pan_camera.tscn` y `selection_manager.tscn`. **No**
una lista de excepciones dentro de quien pausa: así se ve en el inspector del propio nodo y
una escena nueva decide por sí misma, sin que nadie tenga que acordarse de darla de alta.
Regla de diseño detrás: una pausa que además congela la cámara sólo sirve para irse; la
que deja mirar, medir y seleccionar es la que sirve para jugar y para depurar.

### El efecto escucha; la simulación no sabe que hay efecto
Fuego, humo o explosión van en un nodo hijo que se conecta solo a las señales del padre en
su `_ready()`, por duck-typing (`has_signal`). El padre no guarda referencia ni sabe si el
efecto está puesto. Así el script que decide *cuándo* pasa algo no crece cada vez que se
añade arte, y el efecto sirve para cualquier otro nodo que emita las mismas señales.
Ver `MissileExhaust` y `SmokeTrail`, los dos sobre `GuidedMissile.motor_ignited` /
`fuel_spent`, ninguno conocido por él.

Cuando el efecto no depende de *que pase algo* sino de *cuánto vale algo* —una altura, una
carga, un nivel de daño— la señal no sirve, y el reflejo de guardar una referencia al padre
tampoco hace falta: se le pide un **getter público** por duck-typing (`has_method`) y se lee
cada frame. Sigue sin haber acoplamiento en la dirección que importa, la simulación no
publica un campo nuevo por cada efecto, y si el getter no está el efecto se apaga solo en
vez de reventar. Ver `MissileShadow` sobre `get_distance_to_aim()`.

### Los efectos se atan a lo que el juego sabe, no a un cronómetro
Recurrente en todo lo del misil: **si el momento exacto no está decidido de antemano, no se
puede programar por tiempo**. La espoleta es de proximidad, así que el misil no sabe cuándo
va a explotar y «esto pasa los últimos 0,3 s» es imposible de escribir. Lo que sí sabe es a
qué distancia está, y atando el efecto a esa magnitud sale gratis que caiga justo donde
tiene que caer, a cualquier velocidad y desde cualquier ángulo. Mismo razonamiento que
sembrar la estela por distancia recorrida y no con temporizador. Ver `MissileShadow` y
`SmokeTrail`.

### Sombras: dirección de sol fija en el sprite, no en el mundo
Convención del proyecto, **asumida a sabiendas de que es incorrecta**. El arte se dibuja
mirando al sur con el sol al noroeste, o sea la sombra abajo a la derecha, y **la sombra va
pintada o colgada en el espacio del sprite**: al rotar el objeto, rota con él. Consecuencia:
el sol acaba siguiendo a cada objeto, y dos unidades con rumbos distintos se contradicen
—se ve en el LHD, girado en la escena—.

Lo correcto sería separar las dos propiedades: **la forma** es la silueta del objeto y rota
con él, pero **el desplazamiento** lo decide el sol y es fijo en el mundo (`posición +
dirección_del_sol × altura`). No hace falta iluminación del motor para eso; es un vector
constante. Se descartó porque exige que todo el arte de sombras se dibuje centrado, sin el
desplazamiento incorporado, y ya hay assets hechos al revés. **Si algún día se cambia, se
cambia para todo a la vez** — media flota con cada criterio se ve peor que toda con el
criterio malo.

Lo que sí se hace por código es el reparto: en `MissileShadow` la separación horizontal está
pintada en los frames y la vertical la pone el nodo, porque un tile de 16 px no tiene sitio
para una diagonal de verdad. Y a 16 px el presupuesto de separación es de **2–5 px**: más y
la sombra se despega tanto que se lee como otro objeto.

### Un rastro de piezas sueltas, no una cola que se deforma
Para una estela —humo, espuma, polvo— sale más barato ir soltando piezas que se quedan
donde nacieron, con el rumbo congelado de ese instante, que mantener una geometría que haya
que doblar detrás de quien la arrastra. La curva sale sola porque cada pieza ya salió
apuntando a donde se iba entonces. Dos condiciones para que funcione: **cuelgan del mundo,
no de quien las suelta** (si no, viajan con él, que es justo lo contrario), y **se siembran
por distancia recorrida, no por tiempo** — con temporizador el espaciado queda atado a la
velocidad y a los fps, y sale rala al acelerar y apelmazada al frenar. Ver
`SmokeTrail` / `SmokePuff`.

### Un dibujo repetido en fila no es un efecto, es un sello
Cuando un efecto siembra copias del mismo sprite a intervalos regulares, el ojo lee el
patrón antes que el efecto. Se rompe gratis y sin tocar arte: espejar al azar (`flip_h`,
que en pixel art no cuesta nada y no rompe el encaje) y desfasar la reproducción al nacer.
Del desfase, **la parte que trabaja es la de menos de un frame**: no cambia el dibujo, pero
descoloca en qué momento cada copia salta al siguiente, que es lo que se veía escalonar en
bloque. Aviso por experiencia: **un desfase fijo no arregla los tramos de frames largos** —
si un frame dura cinco veces más, un desfase de una unidad sólo despeina el borde de la
racha. Ahí el problema es de arte, no de reproducción.

En un efecto que se siembra por distancia hay además una **regla de cambio**: la duración de
un frame se convierte en longitud de rastro enseñando ese mismo dibujo (en el humo, 1 unidad
= 12,5 px). Sirve para decidir dónde estirar sin pensar en segundos: donde el dibujo es
visible sale caro en bandas, y sólo es barato en los frames que ya casi no se ven.

### Colocar arte sobre arte: medir los píxeles, no ajustar a ojo
El desplazamiento de un efecto respecto a lo que decora sale de las filas/columnas opacas
reales de las dos texturas, no de mover el nodo hasta que quede bien. Con sprites
centrados de N×N, el píxel de la fila `r` ocupa local `[r − N/2, r − N/2 + 1]`, y de ahí
sale el offset exacto. **Anchos par e impar no se pueden centrar con offsets enteros**: el
desvío mínimo es medio píxel y uno fraccionario rompe el encaje. Cuando pase, se deja
escrito de qué lado quedó y por qué — es un arreglo de arte, no de posición.

### Los lados se razonan desde dentro del vehículo, no desde la imagen
Para cualquier cosa que salga **de lado** —casquillos hoy, eyecciones o escapes laterales
mañana— el sistema de referencia es el del vehículo, no el del dibujo en el editor.

El arte apunta a **+Y**, o sea al sur, y **quien mira al sur tiene el este a su izquierda**. El
este es +X, que en la imagen se ve a la **derecha**. Así que "la izquierda del piloto" y "la
izquierda del sprite" son lados contrarios, y mirar el sprite quieto para elegir el signo lleva
justo al error opuesto. Es la misma familia que el `−90` del rumbo y que el `get_facing()` de
una torreta: el marco del dibujo no es el marco del vehículo.

Cuando el criterio es **"hacia afuera"** —los dos cañones de un gemelo— la trampa desaparece,
porque no depende de izquierda ni derecha.

### Medir el efecto, no el punto de partida
Un test que comprueba **dónde nace** una cosa no prueba **hacia dónde va**. Con los dos
eyectores del Tunguska escupiendo al mismo lado, la primera medición seguía informando de
casquillos "a izquierda y derecha": nacían en sitios distintos, y eso era todo lo que estaba
mirando. El bug sobrevivió a su propia prueba.

Lo que hay que medir es el desplazamiento respecto al origen, o el estado después de que la
cosa haya tenido tiempo de ocurrir. Mismo error que el de esperar un número fijo de pasos en
vez de esperar al hecho.

### El contexto desambigua el gesto, no un modo aparte
Antes de añadir un modo o un gesto secundario para una acción nueva, comprobar si el
contexto ya alcanza para distinguirla. Ejemplo: atacar no necesitó doble-tap ni un botón de
"modo ataque" — con una unidad propia seleccionada, tocar a un hostil sólo puede
significar "atacar", así que el mismo click/tap que selecciona ya sirve. Se reserva un
gesto secundario (aquí, pulsación mantenida / click derecho) sólo para la acción que de
verdad compite por el mismo gesto primario (inspeccionar vs. atacar).

El corolario apareció con el mapa táctico: **una vista nueva no inventa gestos nuevos.**
Pulsar el mapa significa lo mismo que pulsar el mundo —dirigir, atacar, seleccionar,
inspeccionar— y lo resuelven las mismas funciones. Lo único que cambia es cómo se averigua
qué hay debajo. Si una vista necesitara su propio vocabulario de clicks, el problema
normalmente es la vista, no el vocabulario.

---

## Paleta de colores (Resurrect64 en uso)

| Uso | Hex | Color GDScript |
|-----|-----|----------------|
| Fondo paneles | `#313638` | `Color(0.192, 0.212, 0.220)` |
| Texto/borde | `#ab947a` | `Color(0.671, 0.580, 0.478)` |
| Accent/selección | `#8fd3ff` | `Color(0.561, 0.827, 1.0)` |
| Bando aliado (IA) | `#a8ca58` | `Color(0.659, 0.792, 0.345)` |
| Bando enemigo | `#e83b3b` | `Color(0.910, 0.231, 0.231)` |
| Bando neutral | `#ffffff` | `Color(1.0, 1.0, 1.0)` |
| Agua (mapa) | `#4d9be6` | dominante del tile, en `MapTerrain.COLORS` |
| Tierra (mapa) | `#91db69` | ídem |
| Arena (mapa) | `#fbff86` | ídem |
| Terreno sin color asignado | `#ff0044` | `MapTerrain.UNKNOWN_COLOR`, a propósito chillón |

Los colores de bando viven en `Team._COLORS`; el del jugador es el mismo accent del HUD.
Los del mapa en `MapTerrain.COLORS`, y salen del propio pixel art de los tiles.

---

## Estado de implementación

### Implementado y funcional
- [x] Cámara con pan + follow a unidad seleccionada
- [x] Selección de unidades por click (física query manual)
- [x] Órdenes de movimiento (click izq. vacío / click der.)
- [x] Marcador de destino (se queda donde se ordenó, como referencia para ajustar el vuelo)
- [x] Deselección: Escape + botón × en HUD
- [x] AV-8B Harrier: vuelo al punto → órbita CCW
- [x] LHD Wasp: despliegue completo (elevador → taxi → despegue → circuito de espera)
- [x] HangarWindow: selector cantidad + misión + DESPLEGAR
- [x] HUD base: event log, minimapa, selection panel, actions panel
- [x] Vuelo separado en `PlaneController` (cómo vuela) + `OrbitBehavior` (a dónde va); la cubierta cede el control con `start_flight()` y no vuelve a tocar al avión
- [x] Escuadrones agrupan en un solo cuadrito con badge `xN` en `DeployedPanel`, click enfoca al líder
- [x] Armamento por misión: se elige loadout en el hangar y el avión sale con las armas colgadas de los `Marker2D` de las alas (`HardpointRack`)
- [x] Capas de dibujado por `z_index`: la capa la lleva el raíz de la unidad, las piezas de dentro usan 0/1/2
- [x] Las configuraciones de armamento del hangar salen de `PlayerFleet._available_weapons`; las no armables no se ofrecen
- [x] `WeaponBar`: elegir arma activa al seleccionar un avión (cañón siempre presente)
- [x] Arma por defecto según el loadout — un avión armado no sale seleccionando el cañón
- [x] Bandos (`Team`): jugador/aliado/enemigo, color en el contorno, enemigo seleccionable pero no controlable ni listado en la UI del jugador
- [x] **2S6 Tunguska**: primera unidad enemiga con comportamiento — radar girando, torreta que engancha y sigue al avión más cercano, y cañón gemelo con ráfagas cortas. Construida con tres componentes genéricos (`RangeRings`, `RadarDish`, `TurretTracker`) y veinte líneas de pegamento
- [x] Círculos de alcance visibles y ajustables en el editor (`RangeRings`, `@tool`): detección y tiro por separado
- [x] Ráfagas por arma (`burst_seconds` / `burst_pause`), con 0 = fuego continuo para no tocar el cañón del avión
- [x] Casquillos al disparar (`Casing` / `CasingEjector`), por calibre y no por unidad: 30 mm en el Tunguska (uno por cañón, hacia afuera) y 25 mm en el Harrier (izquierda del piloto, arrastrando con el avión)
- [x] Zona muerta del cañón antiaéreo: no puede batir lo que le pasa por encima. El círculo interior se dibuja solo, sacado del `min_range` del arma
- [x] Alarmas de amenaza (`Unit.tracked_by` / `fired_upon_by`), con filtro anti-repetición: aviso de enganche **antes** del primer disparo, y parte de "bajo fuego"
- [x] Ondas de contacto en el minimapa y el mapa táctico (`ThreatPulses`), con el grande registrando aunque esté cerrado
- [x] Parte de bajas: `Splash!` para lo enemigo, `UNIT LOST — … derribado por …` para lo propio (`take_damage` propaga el autor)
- [x] Las unidades perdidas se quedan apagadas al final de su fila en el panel superior, en vez de desaparecer
- [x] **Misil del Tunguska** (9M311, 250–380 px) y elección de arma por distancia: misil de lejos, cañón cuando se te mete dentro. Las dos envolventes se tocan sin solaparse, así que la distancia elige sola
- [x] Cuatro anillos de alcance dibujados: detección, misil, cañón y zona muerta — los dos últimos derivados del arma, no exportados aparte
- [x] **Contramedidas**: chaff y bengalas contadas, soltadas solas al aviso de misil, con el tipo elegido según la guía del arma
- [x] Probabilidad de librarse en dos capas (ECM del modelo + señuelo) y una resta: la batería afina la puntería con cada misil que insiste
- [x] **Combate aéreo**: `DogfightBehavior` (se pelea por el ángulo, no se rompe tras disparar) y el Harrier elige maniobra según el dominio del blanco
- [x] Su-33 enemigo volando en círculo, sin IA, reusando el circuito de espera
- [x] AIM-120 (350–900) y AIM-9 (130–360, exige 60° desde la cola) definidos, y cañón con envolvente aparte contra aire (40–150)
- [x] `WeaponSelector`: cadena automática por bandas en aire, elección del jugador respetada, y arma sensata al empezar un ataque a tierra
- [x] `Unit.invulnerable` para tener blancos de pruebas que no se desintegran al primer impacto
- [x] **Llamadas de radio** al disparar (`BrevityCalls`): `Fox Three!`, `Pickle!`, sobre cualquier avión propio, con el código sacado del arma
- [x] Estado de la unidad en su etiqueta: en espera, moviéndose a, atacando a
- [x] **AH-1W SuperCobra**: en el hangar con sus tres misiones, sale a cubierta y se coloca en su punto. Rotor girando (provisional) que arranca al quedarse quieto
- [x] El contador de impacto sólo sale donde significa algo: arma guiada contra tierra
- [x] Primer enemigo en el mapa: T-14 Armata (estático, sin IA)
- [x] Atacar: click/tap sobre un enemigo con unidad propia seleccionada, o "Atacar" en `TargetMenu`; al morir el objetivo, el Harrier orbita donde llegó
- [x] Menú contextual (`TargetMenu`) sobre unidad ajena: click derecho en PC, pulsación mantenida en táctil (`PanCamera.long_pressed`)
- [x] Indicador visual del objetivo bajo ataque (recuadro rojo, reutiliza `SelectionIndicator`) y aviso "Atacando: X" en el HUD — ambos ligados a la selección, no al enemigo
- [x] **Disparo real (AGM-65):** el arma sale de la estación del ala alternando lados, vuela por fases, guía hasta el blanco y detona. Munición consumible por avión
- [x] Salud y daño con área (`Unit.take_damage`, señal `died`); un Maverick mata un T-14 de un impacto
- [x] Dominios aire/superficie: un arma sólo se dispara contra lo que declara poder atacar
- [x] **Pasadas de ataque (`AttackRunBehavior`):** el avión frena al entrar en alcance, dispara, rompe y se aleja sin meterse por debajo del alcance mínimo — el arma manda sobre el vuelo
- [x] Cuenta atrás de impacto sobre el objetivo, ligada a la selección
- [x] Botones de arma con munición restante, deshabilitados al agotarse
- [x] Fuego del propulsor del misil (`MissileExhaust`), enganchado a `motor_ignited` / `fuel_spent`
- [x] Estela de humo del misil (`SmokeTrail` / `SmokePuff`): bocanadas sueltas sembradas por distancia, con fase de disipación por alfa
- [x] Sombra del misil (`MissileShadow`): frame por distancia al blanco, se junta con él en el impacto
- [x] Tres niveles de zoom (0,5x / 1x / 2x) con botones `+` / `−` en el HUD
- [x] Pausa y play (botón + barra espaciadora); cámara, HUD y selección siguen vivos en pausa
- [x] Minimapa y mapa táctico (`MapTerrain` / `MapView` / `Minimap` / `TacticalMap`): terreno, rejilla de celdas, coordenadas por zonas y un punto por unidad del color de su bando
- [x] Marco del minimapa dibujado, como nine-patch con los cortes medidos para que sus detalles no se deformen al estirar la ventana
- [x] Rejilla punteada y translúcida sobre el minimapa, trazada a 1 px de pantalla en vez de pegada como textura
- [x] Bando `NEUTRAL` (blanco), con el que no se mete nadie
- [x] Capa de datos `tipo` en `terrain_tileset.tres` (agua / tierra / arena), 101 tiles marcados
- [x] **Mandar desde el mapa táctico:** dirigir, atacar y abrir el menú contextual pulsando el mapa, con los mismos gestos que en el mundo (incluida la pulsación mantenida en táctil) y sin cerrarlo. Destino marcado en los dos mapas, unidad seleccionada resaltada y rotulada, y botón `×` para cerrarlo sin teclado
- [x] Rejilla de coordenadas por zonas que **se agrupan solas** para seguir legibles pase lo que pase con el tamaño del mapa (`A1…H6` hoy)
- [x] `LongPress`: el mismo detector de pulsación mantenida en la cámara y en el mapa
- [x] **Registro de eventos vivo:** órdenes, ataques con código de brevedad OTAN, alarmas y bajas, con la coordenada del mapa **pulsable** para llevar la mirada allí
- [x] El registro es texto flotante sin caja, con contorno para leerse sobre el terreno, y sus líneas se transparentan a los 6 s sin dejar de ser pulsables
- [x] Cada línea del registro es una escena editable (`event_entry.tscn`), no nodos fabricados en código
- [x] Fuentes a su tamaño nativo (16) y con antialiasing/hinting/subpixel apagados: m6x11plus para títulos, M5X7 para cuerpo
- [x] Columna izquierda que se mide sola: el minimapa se recorta a su dibujo y se estira por escalas enteras, y el registro crece hacia arriba apartándose de él
- [x] **Bomba planeadora (`GlideBomb` / GBU-54):** el alcance sale de la altura (`fall_time`), no de un motor; cae corta de verdad si se suelta demasiado lejos
- [x] **Viraje del avión por radio** (`turn_radius`) en vez de grados/segundo: volar más lento ya no cierra el giro, y hay entrada en viraje
- [x] **Circuito de espera que rodea al barco y navega con él**, con suelo automático ligado al radio de giro para que no se pueda pedir un círculo imposible de volar
- [x] **Dos regímenes de velocidad con un interruptor** (`cruising`): mínima en despegue, espera y alineación de tiro; máxima sólo con una orden en curso. Sin velocidades de avión repartidas por otros scripts
- [x] **Cañón (GAU-12) completo:** fuego sostenido (`WeaponType.FireMode.SUSTAINED`) con el daño saliendo de la geometría —distancia y puntería—, **sin un nodo por bala**; histéresis en el gatillo; fogonazo de dos tiempos, humo de boca y trazadoras, los tres enganchados al `WeaponSystem` y sin conocerse entre ellos
- [x] **Suelo de separación en las pasadas** (`turn_around_margin`): el avión se aleja lo bastante para darse la vuelta **y salir apuntando**, en vez de orbitar el blanco picoteando o gastarse la envolvente alineándose
- [x] **Pasada de ametrallamiento recta:** el avión se compromete al enfilar y deja de corregir hasta que rompe, atravesando el blanco. Medido, el morro se mueve **menos de 3°** durante toda la ráfaga
- [x] **Sólo se dispara dentro de la pasada** (`set_cleared_to_fire`): al romper hay alto el fuego, así que el morro puede barrer el blanco mientras vira sin que salga un tiro
- [x] **Trazadoras que se acaban en el blanco:** el trazo recibe del arma la distancia real de tiro, lleva dispersión propia y se consume con los frames cortos al revés en vez de seguir de largo
- [x] **Bomba tonta (`BallisticBomb` / Mk-82):** se desprende con la velocidad del avión, abre el freno de cola y cae donde la deja la inercia — sin guiado, sin punto de apuntado y sin saber dónde está el blanco
- [x] **Ristra escalonada** (`salvo_interval`): las 6 bombas salen una detrás de otra y baten una línea de 75 px sobre el blanco. El avión rompe con la última, no con la primera
- [x] **Velocidad de pasada según el arma** (`slows_to_aim`): el cañón frena para apuntar, el bombardeo cruza a máxima y sale de ahí
- [x] **Etiqueta de unidad seleccionada (`UnitTag`):** línea desplegable y nombre, en el HUD, siguiendo a la unidad en pantalla — mide igual a cualquier zoom. Sirve para cualquier unidad, no sólo el Harrier
- [x] Sombra de la Mk-82 al caer, reusando `MissileShadow` por duck-typing (`get_distance_to_aim`) sin tocar su código
- [x] **Vuelo del helicóptero (`HelicopterController`):** mando de ejes propios —adelante 85, costado 38, espaldas 28— con el rumbo separado de la traslación. Llega a menos de **1,5 px** del punto en 40 de 40 órdenes al azar y se planta ahí (0,1 px en 3 s de hover)
- [x] **Despegue vertical:** la primera orden de movimiento saca al helicóptero de cubierta y libera su plaza (`took_off`). La orden vale aunque llegue mientras el barco todavía lo está colocando

### Pendiente
- [ ] **Sombra propia para la Mk-82.** Hoy usa la del misil, que no le corresponde: es otra silueta y otra forma de caer
- [ ] **Elegir la fuente del juego.** `assets/fonts/ui_theme.tres` está vacío a propósito (cae en la del motor) mientras se prueban candidatas. `UnitTag` usa m5x7 a 16 px, que es la que convence por ahora. Ojo con la cobertura: la Boxel se descartó porque no trae **ninguna** tilde ni Ñ ni `¿ ¡` — sin eso no hay español, y menos localización
- [ ] Alabeo e inclinación del avión al virar y al cambiar de régimen: el enganche existe (`bank_sprite_path`, `AnimatedSprite2D` de 5 frames), falta el arte
- [ ] Marcas de impacto en el terreno y barras de vida. Con eso se afinan las ráfagas del cañón para que varíen y no dejen siempre el mismo patrón
- [ ] **Definir el daño en serio.** Los números de hoy son de trabajo: un Harrier destruye un T-14 en tres pasadas de cañón, y **dos Mk-82 bastan** para lo mismo. Demasiado fácil para lo que debería costar. Va junto con las barras de vida, y hay que decidirlo por unidad y por arma, no ajustando el `damage` de cada una hasta que "quede bien"
- [ ] **Revisar en el editor la Mk-82:** el vuelo, la ristra y el frenado están medidos, pero la animación del freno abriéndose sólo se ha comprobado por fotogramas
- [ ] **Revisar en el editor** los efectos del cañón: verificados por medición (fotogramas, encadenado, siembra, rumbo de los trazos, dónde muere cada trazo, curvatura del rastro y las tres pasadas hasta matar), pero la lectura visual final no
- [ ] Efectos: explosión y caída. Los enganches existen (`detonated`), falta el arte. Fuego, humo y sombra ya están — `MissileExhaust`, `SmokeTrail` y `MissileShadow` sirven de patrón
- [ ] Redibujar la sombra del misil ovalada y de 3 px de ancho: hoy mide lo mismo que el cuerpo y se funden en los últimos frames (ver `MissileShadow`)
- [ ] Sombras del resto de unidades. Antes de dibujarlas, releer el patrón de sombras: la convención actual es incorrecta a propósito y cambiarla obliga a rehacer el arte de todas a la vez
- [ ] Alargar la fase opaca del humo (3–4 frames más antes de que baje el alfa, y algún paso de alfa extra): hoy la estela se disuelve desde el primer tercio (ver `SmokePuff`)
- [ ] **Efectos propios del Tunguska**: fogonazo, trazadoras y humo son los del Harrier prestados. Cambiarlos es reasignar dos recursos por emisor, sin tocar código
- [ ] **Probabilidad de impacto contra aeronaves.** El cañón AA usa hoy el mismo `_hit_fraction` por geometría que el del avión, que no modela lo que cuesta acertarle a un blanco aéreo rápido. Va junto con el daño en serio: hoy baja un Harrier de 100 a 47 en dos ráfagas
- [ ] **Que se note que la batería te está afinando la puntería.** Es la mecánica más importante del bloque y hoy es **invisible**: quien pierda un avión al cuarto misil lo leerá como mala suerte. Sin números en pantalla — la idea es un indicador en el avión que muestre desde dónde lo siguen y se intensifique, pulsando y sonando más fuerte
- [ ] **Arte de los señuelos.** Hoy `Decoy` se dibuja con `_draw()`. El patrón (varios trozos de chaff, bengalas en V) ya es configurable: `per_release` y `spread_deg`
- [ ] **Misiles de calor**, para que las bengalas sirvan de algo. El tipo ya se distingue (`WeaponType.seeker`); faltaría darle a cada tipo su propio `decoy_bonus`, hoy común
- [ ] **Llamar a `forget_solution()` al recuperar un avión.** El método está; falta el aterrizaje
- [ ] `Decoy.strength()` y `bloom_time` quedaron sin uso al descartar el modelo simulado — decidir si se quitan o se aprovechan
- [ ] Menú de progresión: subir `ecm_evasion` por modelo. Ahí **sí** van números en pantalla, porque se gastan recursos y hay que saber qué se compra
- [ ] **Audio de las alertas.** Es la única señal que funciona sin estar mirando la pantalla; hoy las tres avisos visuales compiten por la misma atención. El enganche ya está: las señales `tracked_by` / `fired_upon_by` con su filtro
- [ ] **Evasión automática: descartada, no pendiente.** Se construyó y se eliminó el mismo día — creaba dos bucles y dejaba al avión dando vueltas junto a la batería. Sacar un avión de una zona batida es del jugador. Ver `decisions.md` antes de volver a intentarlo
- [ ] **Vigilar el avión sin órdenes dentro del alcance.** `_on_target_lost()` lo pone a orbitar *donde está*, que tras un ataque es encima de la defensa. No es esquivar: es elegir dónde orbitar
- [ ] Ruido en el parte: se reportan también los ataques de unidades enemigas (`2S6 Tunguska ataca AV-8B Harrier II`), que ahora duplica al `MUD SPIKE`
- [ ] Las bajas del panel superior se acumulan sin tope; hará falta un límite o limpiarlas entre misiones
- [ ] Duplicación pendiente de decidir: `RangeRings.engagement_radius` (250) y `max_range` del arma (250) dicen lo mismo en dos sitios. Mover el círculo no cambia el arma
- [ ] Contramedidas (bengalas, chaff, ECM) como blancos falsos y degradación del guiado
- [ ] Qué hace el avión cuando se queda sin munición y el blanco sigue vivo (hoy sigue haciendo pasadas)
- [ ] Cadena de repliegue de arma: usar la siguiente cuando se acaba una, cañón como último recurso
- [ ] **Proyectil propio de los misiles aire-aire.** El AIM-120 y el AIM-9 usan prestado el del Maverick, igual que el 9M311: vuelan y guían, pero sale un AGM-65 con sombra de altitud
- [ ] **Comportamiento del Su-33.** Hoy sólo orbita: no responde, no dispara, no huye. Va con las misiones
- [ ] **El gesto de combate del helicóptero:** morro clavado en el blanco mientras se desplaza de costado, y giro sobre su eje para apuntar. Es lo que el vuelo de hoy todavía no enseña, y no por falta de máquina: el rumbo ya va aparte de la traslación, falta que haya un blanco al que apuntar `_wanted_heading`. Va con el armamento
- [ ] **Armamento del AH-1W.** Las tres misiones existen vacías para poder sacarlo a cubierta
- [ ] **El helicóptero no reacciona a lo que hace.** No se inclina al acelerar, ni alabea al desplazarse de lado, ni cae de cola al frenar: es un dibujo rígido deslizándose, y eso es lo que hace que el vuelo se sienta soso por bien medido que esté. No hace falta redibujarlo en ángulos — dos o tres frames de inclinación, o un píxel de separación contra la sombra, ya cambian la lectura
- [ ] **Snap de píxel en 2D.** Sin comprobar. A 20–40 px/s —un helicóptero colocándose— el sprite avanza un píxel cada dos o tres frames de forma irregular, y eso se ve como tirones. Los aviones no lo acusan porque van al triple. `rendering/2d/snap/*` no está tocado en `project.godot`
- [ ] **Animación de despegue vertical.** Hoy `lift_time` (1,6 s) es sólo una espera con el aparato quieto. El hueco está: `HelicopterController` anuncia `LIFTING` por `state_changed`
- [ ] **Animación de hélice.** Hoy `Rotor` gira unas palas rectas; a régimen debería verse el disco borroso
- [ ] Revisar el sobrevuelo del ataque a tierra: rompe donde debe (263 px) pero completa el viraje pasando a 114. Es el radio de giro, no un fallo — decidir si molesta
- [ ] Vuelo en formación (aviones del mismo escuadrón) — hoy la orden sólo llega al líder
- [ ] Animación del elevador (placeholder `elevator_cycle_time` ya existe)
- [ ] Misiones funcionales: SEAD/CAP/CAS tienen UI, sin comportamiento de IA
- [ ] Bloqueo por misión activa (no desplegar mientras escuadrón en vuelo)
- [ ] Sistema de vuelo completo: objetivos, ataque, regreso al portaaviones
- [ ] Aterrizaje/recuperación de aviones
- [ ] Pantalla de puerto (reemplazar `PlayerFleet` hardcodeado)
- [ ] El minimapa como aviso de que pasa algo fuera de pantalla (parpadeo al recibir fuego, o similar). Los puntos ya están; falta que llamen la atención
- [ ] Distinguir en el mapa aire de superficie (`UnitType.Domain`) — la unidad seleccionada ya se resalta
- [ ] Menú contextual también en el minimapa, o dejarlo como botón: hoy sus puntos de 2 px no se pueden apuntar
- [ ] Nombres propios de zona por misión ("Bahía Norte") encima de la rejilla, si el registro de eventos gana con ello. El sistema de zonas serviría de rejilla de fondo sin tirar nada — modelo Foxhole / EVE frente a modelo carta náutica
- [ ] Registrar el despliegue de aviones en el `EventLog` (ocurre dentro de `FlightDeck`)
- [ ] Mecánicas de ataque/combate
- [ ] Unidades enemigas
- [ ] IA de unidades enemigas y aliadas (`Team.Side.ALLY` existe pero nadie la mueve)
