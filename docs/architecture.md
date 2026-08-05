# Arquitectura del código — war-project

Referencia de sesión. Actualizar cuando cambie algo relevante.

---

## Escena principal (`main.tscn`)

```
Node2D
├── TileMapLayer          — terreno (tile_set: terrain_tileset.tres)
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
| `take_damage(float)` | Encaja daño. Al llegar a 0 emite `died` y `queue_free()` |
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
| `enum Side { PLAYER, ALLY, ENEMY }` | `ALLY` es del lado del jugador pero la mueve la IA |
| `color(side) → Color` | Azul `#8fd3ff` / verde `#a8ca58` / rojo `#e83b3b` (Resurrect64) |
| `are_hostile(a, b) → bool` | Hoy: hostiles si exactamente uno es `ENEMY` |

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

**Acercamiento.** `zoom_levels` (`PackedFloat32Array`, hoy `[0.5, 1.0, 2.0]`) y
`default_zoom_level` (1) son exports: añadir un nivel o cambiar con cuál arranca es tocar
el inspector. API: `zoom_level()`, `zoom_level_count()`, `set_zoom_level(n)`,
`step_zoom(±1)`.

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
  └─ unidad bajo cursor:
       └─ puedo atacarla (propia seleccionada + hostil) → _issue_attack_order(unit)
       └─ es la ya seleccionada → _select(null)
       └─ si no → _select(unit)
  └─ sin unidad + hay propia seleccionada → _issue_move_order(pos)

click derecho / pulsación mantenida → PanCamera.long_pressed → _on_context_requested(pos)
  └─ unidad ajena bajo cursor → _hud.open_target_menu(unit, can_attack)
  └─ si no, y hay propia seleccionada → _issue_move_order(pos)

HUD.attack_requested (del menú) → _issue_attack_order(target)
ESC → cierra el menú + _select(null)
HUD.deselect_requested → _select(null)
HUD.zoom_change_requested(step) → PanCamera.step_zoom(step)
PanCamera.zoom_changed(level, count) → HUD.set_zoom_state(...)
```

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
- `taxi_speed`, `elevator_cycle_time`, `launch_delay`, `takeoff_speed`
- `post_bow_distance`, `climb_duration`

**Estado interno:**
- `_occupied[4]`, `_units[4]` — slots de cubierta
- `_taxi_queues[2]` — cola por elevador

**API pública:**
- `request_deploy(scene: PackedScene, squad: Squad = null) → bool` — inicia ciclo de despliegue; si se pasa `squad`, el avión se suma a ese `Squad` al spawnear (ver `Squad` más arriba)
- `has_free_slot() → bool`

**`_hand_over_control(unit)`:** Si la unidad tiene `start_flight()`, se la llama pasándole el barco como centro de órbita y `takeoff_speed` como velocidad inicial. A partir de ahí el avión se pilota solo.

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
| Giro | `base_turn_deg` (150), `fine_gain`, `turn_inertia`, `velocity_align` |
| Compromiso | `release_deg` (22), `reengage_deg` (45), `dead_circle_hysteresis` (1.12) |
| Navegación | `arrive_radius` (40), `flyby_capture`, `sprite_offset_deg` (−90) |
| Alabeo | `bank_sprite_path` (opcional, `AnimatedSprite2D` de 5 frames) |

**API:** `enable(initial_speed)`, `disable()`, `set_target(pos)`, `update_target(pos)`, `clear_target()`, `set_speed_limit(v)`, `clear_speed_limit()`, `current_turn_rate()`, `min_turn_radius()`.

**`speed_limit`** es un techo temporal (0 = sin límite) que nunca baja de `min_speed` —
un avión no puede pararse. El piloto sólo obedece: quién y cuándo lo pone es de quien
manda al avión (hoy `AttackRunBehavior`, que frena al entrar en alcance). Se limpia solo
en `enable()` y `disable()`.

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

#### `OrbitBehavior` — `orbit_behavior.gd`
Decide **a dónde** va cuando no hay órdenes: vueltas alrededor de un centro.

| Señal | Cuándo |
|-------|--------|
| `center_reached` | Llegó al punto que ordenó el jugador; a partir de ahí orbita ahí |

| Export | Default |
|--------|---------|
| `semi_x` / `semi_y` | 200 / 280 px |
| `lead_deg` | 35° — cuánto por delante se pone el punto de referencia |
| `clockwise` | false |
| `center_deadzone` | 0.25 — dentro de esa fracción del óvalo manda el rumbo, no la posición |
| `sync_rate` | 2.5 — con qué rapidez la fase se engancha a dónde está el avión |
| `pilot_path` | `../PlaneController` |

**API:** `orbit_around(node)` (centro móvil, el barco), `orbit_at(pos)` (orden del
jugador: va al punto y luego orbita ahí), `has_pending_order()`, `stop()`.

`has_pending_order()` = está yendo a un punto que ordenó el jugador. Lo consulta
`Av8bHarrier.start_flight()` para no pisar una orden dada mientras el avión estaba en
cubierta — evita duplicar el punto ordenado en otra variable sólo para poder preguntarlo.

**El óvalo no es un riel.** Se mantiene una fase propia (`_phase`) que avanza sola
cada frame al ritmo al que vuela el avión, y el punto de esa fase sobre la elipse es
lo que persigue el piloto. La curva que se ve la produce él con su inercia y su radio
de giro reales.

**La fase avanza sola, no se deduce de la posición.** Deducirla con
`atan2(rel.y/semi_y, rel.x/semi_x)` parece natural pero es indeterminada en el centro
del óvalo: al pasar por ahí saltaba 180° en un frame y el punto objetivo se movía
450 px de golpe — el avión amagaba a un lado y viraba al otro. Ocurría justo al
terminar una orden del jugador, que es cuando el avión queda en el centro exacto.
La posición sólo se usa para enganchar la fase (`sync_rate`) y sólo más allá de
`center_deadzone`; dentro, manda el rumbo del avión.

Waypoints discretos tampoco funcionan aquí: un avión que no puede frenar nunca "llega"
a un punto que tiene al costado — se queda orbitándolo.

Medido en headless: el avión ciñe el óvalo con error < 9 %, y 0 amagues en el ciclo
completo y en un barrido de 16 órdenes.

**Coherencia de parámetros:** `min_turn_radius()` a velocidad de crucero debe ser
menor que el radio de curvatura del óvalo (`semi_x²/semi_y` en el punto más cerrado).
Si el avión es demasiado rápido para el óvalo, vuela por fuera.

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
| `INGRESS` | Encara el blanco, corrigiendo el punto cada frame | Al llegar a `min_range × break_off_margin`, o al disparar (`break_off()`) |
| `EGRESS` | Se aleja recto hacia un punto de fuga fijado al romper | Al alcanzar la distancia de reencare |

| Señal | Cuándo |
|-------|--------|
| `target_lost` | El objetivo dejó de ser válido (murió). Se apaga a sí mismo **antes** de emitirla, para que quien escuche pueda darle otra orden al avión sin que este nodo se la pise en el frame siguiente |

| Export | Default | Uso |
|--------|---------|-----|
| `attack_speed` | 90 | Velocidad mientras está dentro del alcance. El piloto nunca baja de su `min_speed`; lo brusco del frenado es su `acceleration` |
| `break_off_margin` | 1.2 | Corta la pasada ese % antes del alcance mínimo |
| `reengage_fraction` | 0.85 | Fracción del alcance máximo a la que vuelve a encarar |
| `separation_gain` | 1.15 | Separación mínima al romper, relativa a **dónde** rompió |
| `egress_overshoot` | 1.3 | Cuánto más allá del reencare apunta el punto de fuga |
| `pilot_path` | `../PlaneController` | |

**API:** `engage(target, min_range, max_range)`, `set_envelope(min, max)`, `break_off()`, `stop()`.

`engage()` y cada reencare usan `set_target()` del piloto (destino nuevo, replantea el
viraje desde cero); dentro de INGRESS se corrige con `update_target()` sin soltar el
compromiso, igual que `OrbitBehavior` con el óvalo.

**`separation_gain` existe por un bug real:** romper justo en el borde del alcance máximo
no servía de nada, porque la condición de reencarar ya estaba cumplida en el mismo frame
y el avión seguía metiéndose. La separación tiene que ser relativa a dónde se rompió, no
sólo al alcance del arma.

**`max_range` a 0** (unidad sin arma) = se comporta como el viejo perseguir: va derecho,
que es lo único sensato sin envolvente que respetar.

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
| — | `icon` | Texture2D (`AtlasTexture` sobre `Jet_bombs_missiles.png`) |
| Objetivos | `targets` | Flags Aire / Superficie. Contra qué sirve |
| Alcance | `min_range`, `max_range` | Envolvente de tiro. Debajo del mínimo el arma aún no se estabilizó; encima del máximo se queda sin combustible |
| Alcance | `firing_arc_deg` | Cuánto puede estar el blanco fuera del morro para poder tirar |
| Daño | `damage`, `blast_radius` | 0 de radio = sólo daña lo que toca |
| Lanzamiento | `projectile_scene` | Qué se instancia al disparar |
| Lanzamiento | `salvo_size` | 1 = de una en una; **0 = todo lo que quede** |
| Lanzamiento | `salvo_spread` | Radio de dispersión del punto de apuntado de cada arma de la andanada |
| Lanzamiento | `reload_time` | Segundos entre andanadas |

`get_short_name()` cae al nombre largo si el corto está vacío.
`can_engage_domain(domain)` e `in_range(distance)` responden las dos preguntas que hace
`WeaponSystem` antes de disparar. El cañón (`gau12_cannon.tres`) es un `WeaponType` más,
sin icono ni `projectile_scene`: no cuelga de ninguna estación y aún no dispara nada.

**Las cifras de combate están aquí y las de vuelo en la escena del proyectil.** Así la
misma escena de misil sirve para dos armas con pegada distinta, y la cifra que se
enseñaría en el hangar es exactamente la que se aplica. Valores del AGM-65: superficie,
300–1000 px, arco 25°, daño 120, radio 20, de uno en uno, recarga 1,5 s.

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
| Arte | `sprite_offset_deg` (−90) |

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

El primer enganche con arte es el escape (`MissileExhaust`, abajo). Siguen sin arte la
**explosión, el humo, la sombra y la caída**.

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
| `set_active(bool)` | Encender/apagar. Arranca encendido |
| `fired(weapon)` | Señal. La escucha el vuelo para romper el ataque |
| `rack_path` | Export, `../Hardpoints` |

**No dispara mientras tenga algo suyo en el aire.** De ahí sale solo el "si no muere,
lanza el otro": se lanza, se espera a que explote, y si el blanco sigue vivo sale el
siguiente. Nadie escribió "reevaluar tras el impacto".

**No comprueba hostilidad**: el portero de a-quién-se-ataca es `SelectionManager` /
`Unit.receive_attack_order`. Ver "Un solo portero por regla".

---

### `T-14 Armata` — `core/unit/t14_armata/`

Tanque enemigo. **Sin script**: instancia de `unit.tscn` con `unit_type` y `team = ENEMY`,
en el grupo `unit_ground`. `Unit` ya le da contorno, nombre y selección, y
`receive_move_order()` virtual vacío significa que no se mueve. Tendrá script cuando
tenga IA.

Sirve de patrón para cualquier unidad estática: **una unidad no necesita script propio
hasta que tenga comportamiento**.

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
`R`). `z_index = 10` en el raíz.

**API:**
- `start_flight(orbit_center, initial_speed)` — la cubierta le cede el control y enciende el armamento. **Sólo entra al circuito de espera si no tiene órdenes**: si hay `attack_target` sale a por él, y si `orbit.has_pending_order()` no toca nada (el destino ya está puesto en el piloto). El circuito es lo que hace un avión sin órdenes, y el jugador pudo darle una mientras estaba en cubierta
- `receive_move_order(target)` — para `attack`, delega en `orbit.orbit_at(target)`
- `receive_attack_order(target)` — para `orbit`, delega en `attack.engage(target, min, max)`
- `get_facing()` / `get_velocity()` — el rumbo **real** del piloto, no la rotación del nodo: el arte apunta a +Y y el armamento heredaría el desfase, saliendo disparado de lado
- `get_time_to_impact()` — delega en `weapons`

**Armamento apagado en cubierta:** un avión que ya tiene la orden no dispara desde el
barco. Lo enciende `start_flight()`.

**Disparar rompe el ataque:** `weapons.fired` → `attack.break_off()`. Y
`active_weapon_changed` → `attack.set_envelope(...)`, porque cambiar de arma en pleno
ataque cambia a qué distancia hay que volar.

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

API:
- `show_selected_unit(unit: Unit)` — muestra panel + acciones (si controla) + barra de armas (si controla) + botón ×; se suscribe a `attack_target_changed` de la unidad
- `clear_selected_unit()` — oculta todo, incluido el aviso de ataque; se desuscribe
- `open_target_menu(target, can_attack)` / `close_target_menu()` — delegan en `TargetMenu`, convirtiendo la posición mundo→pantalla con `get_global_transform_with_canvas()`
- `set_zoom_state(level, count)` — hasta dónde puede seguir acercándose o alejándose. Se lo dice `SelectionManager`, que sí tiene la cámara delante

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
├── EventLog         (PanelContainer) — offset (6,195)
├── Minimap          (PanelContainer) — offset (5,292) — placeholder
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
extends PanelContainer
```
`add_event(text: String)` — añade línea, máximo 4, elimina la más vieja.

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

El actuador tampoco decide límites: `set_speed_limit()` lo pone quien manda al avión, no
el piloto. El piloto sabe volar; **cuándo** hay que ir despacio es de quien da la orden.

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
Ver `MissileExhaust` sobre `GuidedMissile.motor_ignited` / `fuel_spent`.

### Colocar arte sobre arte: medir los píxeles, no ajustar a ojo
El desplazamiento de un efecto respecto a lo que decora sale de las filas/columnas opacas
reales de las dos texturas, no de mover el nodo hasta que quede bien. Con sprites
centrados de N×N, el píxel de la fila `r` ocupa local `[r − N/2, r − N/2 + 1]`, y de ahí
sale el offset exacto. **Anchos par e impar no se pueden centrar con offsets enteros**: el
desvío mínimo es medio píxel y uno fraccionario rompe el encaje. Cuando pase, se deja
escrito de qué lado quedó y por qué — es un arreglo de arte, no de posición.

### El contexto desambigua el gesto, no un modo aparte
Antes de añadir un modo o un gesto secundario para una acción nueva, comprobar si el
contexto ya alcanza para distinguirla. Ejemplo: atacar no necesitó doble-tap ni un botón de
"modo ataque" — con una unidad propia seleccionada, tocar a un hostil sólo puede
significar "atacar", así que el mismo click/tap que selecciona ya sirve. Se reserva un
gesto secundario (aquí, pulsación mantenida / click derecho) sólo para la acción que de
verdad compite por el mismo gesto primario (inspeccionar vs. atacar).

---

## Paleta de colores (Resurrect64 en uso)

| Uso | Hex | Color GDScript |
|-----|-----|----------------|
| Fondo paneles | `#313638` | `Color(0.192, 0.212, 0.220)` |
| Texto/borde | `#ab947a` | `Color(0.671, 0.580, 0.478)` |
| Accent/selección | `#8fd3ff` | `Color(0.561, 0.827, 1.0)` |
| Bando aliado (IA) | `#a8ca58` | `Color(0.659, 0.792, 0.345)` |
| Bando enemigo | `#e83b3b` | `Color(0.910, 0.231, 0.231)` |

Los dos colores de bando viven en `Team._COLORS`; el del jugador es el mismo accent del HUD.

---

## Estado de implementación

### Implementado y funcional
- [x] Cámara con pan + follow a unidad seleccionada
- [x] Selección de unidades por click (física query manual)
- [x] Órdenes de movimiento (click izq. vacío / click der.)
- [x] Marcador de destino (se queda donde se ordenó, como referencia para ajustar el vuelo)
- [x] Deselección: Escape + botón × en HUD
- [x] AV-8B Harrier: vuelo al punto → órbita CCW
- [x] LHD Wasp: despliegue completo (elevador → taxi → despegue → óvalo)
- [x] HangarWindow: selector cantidad + misión + DESPLEGAR
- [x] HUD base: event log, minimap placeholder, selection panel, actions panel
- [x] Vuelo separado en `PlaneController` (cómo vuela) + `OrbitBehavior` (a dónde va); la cubierta cede el control con `start_flight()` y no vuelve a tocar al avión
- [x] Escuadrones agrupan en un solo cuadrito con badge `xN` en `DeployedPanel`, click enfoca al líder
- [x] Armamento por misión: se elige loadout en el hangar y el avión sale con las armas colgadas de los `Marker2D` de las alas (`HardpointRack`)
- [x] Capas de dibujado por `z_index`: la capa la lleva el raíz de la unidad, las piezas de dentro usan 0/1/2
- [x] Las configuraciones de armamento del hangar salen de `PlayerFleet._available_weapons`; las no armables no se ofrecen
- [x] `WeaponBar`: elegir arma activa al seleccionar un avión (cañón siempre presente)
- [x] Arma por defecto según el loadout — un avión armado no sale seleccionando el cañón
- [x] Bandos (`Team`): jugador/aliado/enemigo, color en el contorno, enemigo seleccionable pero no controlable ni listado en la UI del jugador
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
- [x] Tres niveles de zoom (0,5x / 1x / 2x) con botones `+` / `−` en el HUD
- [x] Pausa y play (botón + barra espaciadora); cámara, HUD y selección siguen vivos en pausa

### Pendiente
- [ ] Proyectil balístico para bombas (el mecanismo de andanada con dispersión ya existe: `salvo_size` / `salvo_spread`)
- [ ] Cañón: hace falta resolver antes cómo dibujar una ráfaga sin instanciar un nodo por bala (impacto por cálculo + trazadoras)
- [ ] Efectos: humo, explosión, sombra y caída. Los enganches existen (`detonated`), falta el arte. El fuego del propulsor ya está hecho — `MissileExhaust` sirve de patrón
- [ ] Contramedidas (bengalas, chaff, ECM) como blancos falsos y degradación del guiado
- [ ] Qué hace el avión cuando se queda sin munición y el blanco sigue vivo (hoy sigue haciendo pasadas)
- [ ] Cadena de repliegue de arma: usar la siguiente cuando se acaba una, cañón como último recurso
- [ ] Elección de arma por distancia en combate aéreo (sistema de dogfight, sin planear)
- [ ] Vuelo en formación (aviones del mismo escuadrón) — hoy la orden sólo llega al líder
- [ ] Animación del elevador (placeholder `elevator_cycle_time` ya existe)
- [ ] Misiones funcionales: SEAD/CAP/CAS tienen UI, sin comportamiento de IA
- [ ] Bloqueo por misión activa (no desplegar mientras escuadrón en vuelo)
- [ ] Sistema de vuelo completo: objetivos, ataque, regreso al portaaviones
- [ ] Aterrizaje/recuperación de aviones
- [ ] Pantalla de puerto (reemplazar `PlayerFleet` hardcodeado)
- [ ] Minimapa interactivo (placeholder existe, lógica pendiente de definir)
- [ ] Mecánicas de ataque/combate
- [ ] Unidades enemigas
- [ ] Menú de opciones al clickear unidad enemiga (ya se selecciona; falta el menú)
- [ ] IA de unidades enemigas y aliadas (`Team.Side.ALLY` existe pero nadie la mueve)
