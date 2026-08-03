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
| `set_selected(bool)` | Muestra/oculta SelectionIndicator |
| `is_player_controlled()` | ¿Obedece órdenes del jugador? Sólo `PLAYER` — las aliadas las mueve la IA |
| `is_hostile_to(other)` | ¿Se disparan? Delega en `Team.are_hostile()` |
| `get_display_name()` | unit_name si existe, sino tr(unit_type.display_name) |
| `get_actions()` | PackedStringArray desde unit_type.actions |
| `set_weapon_loadout(loadout)` | Arma la unidad y la dibuja si tiene `HardpointRack` |
| `get_weapons()` | `Array[WeaponType]`: cañón + un arma por tipo colgado, sin repetir |
| `get_default_weapon()` | La principal del loadout; el cañón sólo si va desarmada |
| `set_active_weapon(w)` | Con qué ataca. Emite `active_weapon_changed` |
| `receive_move_order(Vector2)` | **Virtual vacío** — sobreescribir en subclases |

Estado de armamento: `weapon_loadout` (qué lleva) y `active_weapon` (con qué ataca). El
arma activa vive aquí y no en el HUD porque el panel se reconstruye en cada selección.
Sale puesta la principal del loadout — desde `_ready()` para unidades del mapa, y desde
`set_weapon_loadout()` al armarlas, porque el arma que hubiera puede no estar en el
armamento nuevo.

| Señal | Cuándo |
|-------|--------|
| `active_weapon_changed(weapon)` | Cambió el arma seleccionada |

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
| `clicked(world_position: Vector2)` | Click sin arrastre (umbral 6px) |

| Variable | Descripción |
|----------|-------------|
| `follow_target: Node2D` | Si no es null, `_process` copia su `global_position` |

- Pan: click+arrastre izquierdo. Al empezar el arrastre, `follow_target = null`.
- Límites auto-calculados en `_ready()` desde todos los `TileMapLayer` de la escena.
- `SelectionManager` asigna `follow_target = _selected_unit` en `_select()`.

---

### `SelectionManager` — `core/selection/selection_manager.gd`
```
extends Node2D
```
NodePaths exportados: `camera_path`, `hud_path` → resueltos con `get_node()` en `_ready()`.

**Flujo de input:**
```
click izquierdo → PanCamera.clicked → _on_camera_clicked(pos)
  └─ unidad bajo cursor → _select(unit)
  └─ sin unidad + hay seleccionada → _issue_move_order(pos)
  └─ misma unidad seleccionada → _select(null)

click derecho + unidad seleccionada → _issue_move_order(pos)
ESC → _select(null)
HUD.deselect_requested → _select(null)
```

**`_find_unit_at(pos)`:** Query `PhysicsPointQueryParameters2D` con `collide_with_areas=true, collide_with_bodies=false`. Devuelve la primer `Unit` bajo el cursor o null — si esa unidad tiene `squad != null`, devuelve `unit.squad.leader` en su lugar (click en cualquier integrante de un escuadrón selecciona al líder, no al que se clickeó).

**`_select(unit)`:**
1. Llama `set_selected(false/true)` en la unidad anterior/nueva
2. Actualiza HUD: `show_selected_unit` / `clear_selected_unit`
3. Asigna `_camera.follow_target`
4. Muestra MoveMarker solo si hay orden activa para la unidad seleccionada

**`_issue_move_order(target)`:**
1. Desconecta señal anterior si existe
2. Llama `_selected_unit.receive_move_order(target)`
3. Posiciona y muestra `_move_marker`
4. Si la unidad tiene `order_fulfilled`, conecta `_on_order_fulfilled` con `CONNECT_ONE_SHOT`

**`_on_order_fulfilled`:** Oculta el marcador, limpia `_order_unit`.

---

### `MoveMarker` — `core/selection/move_marker.gd`
```
extends Node2D
```
Creado dinámicamente por SelectionManager en `_ready()`, añadido a la escena raíz.
Dibuja: círculo (radio 8) + cruz, color accent con 85% alpha.
**IMPORTANTE:** llama `queue_redraw()` en `NOTIFICATION_VISIBILITY_CHANGED` — sin esto `_draw()` no se ejecuta al hacer `show()`.

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

**API:** `enable(initial_speed)`, `disable()`, `set_target(pos)`, `update_target(pos)`, `clear_target()`, `current_turn_rate()`, `min_turn_radius()`.

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
jugador: va al punto y luego orbita ahí), `stop()`.

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

---

### Armamento — `core/weapon/`

Tres niveles, separados a propósito: qué es un arma, qué se monta en una salida, y
cómo se dibuja.

**`WeaponType`** (`weapon_type.gd`, `extends Resource`) — definición compartida de un
arma. Existe un `.tres` por tipo (`aim9_sidewinder`, `aim120_amraam`, `agm65_maverick`,
`mk82`, `gbu54`) y los loadouts lo referencian en vez de copiarlo, así el nombre y el
icono no se desincronizan entre misiones.

| Export | Tipo |
|--------|------|
| `display_name` | String |
| `short_name` | String — para los botones de `WeaponBar`, donde caben ~6 caracteres |
| `icon` | Texture2D (`AtlasTexture` sobre `Jet_bombs_missiles.png`) |

`get_short_name()` cae al nombre largo si el corto está vacío. El cañón
(`gau12_cannon.tres`) es un `WeaponType` más, sin icono: no cuelga de ninguna estación.

**`WeaponMount`** (`weapon_mount.gd`, `extends RefCounted`) — un tipo de arma sobre un
grupo de estaciones simétricas. `weapon: WeaponType`, `stations: PackedStringArray`
(ids como `"L2"`, `"R2"` — no nombres de marker), `per_station: int`. `total()` suma
todas las estaciones del grupo.

`per_station` es **dato de munición, no de dibujo**: una estación con 3 Mk-82 lleva 3
aunque en pantalla quepa una sola.

**`WeaponLoadout`** (`weapon_loadout.gd`, `extends RefCounted`) — el armamento completo
de una salida: `display_name` + `mounts: Array[WeaponMount]` + `default_weapon`. Única
fuente de verdad — el HUD saca de aquí el resumen y el `HardpointRack` los sprites, así
que no hay dos cifras que puedan discrepar.

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

**`av8b_harrier.gd`:** sólo identidad y ruteo de órdenes. No pilota.
```
extends Unit
```
| Señal | Cuándo |
|-------|--------|
| `order_fulfilled` | Llegó al punto ordenado (reenvía `OrbitBehavior.center_reached`) |

**Escena:** `Sprite2D`, `CollisionShape2D`, `SelectionIndicator`, `PlaneController`,
`OrbitBehavior`, `Hardpoints` (`HardpointRack` con 10 `Marker2D`: `L1`, `L2a`, `L2c`,
`L3a`, `L3c` y sus simétricos `R`). `z_index = 10` en el raíz.

**API:**
- `start_flight(orbit_center, initial_speed)` — la cubierta le cede el control
- `receive_move_order(target)` — delega en `orbit.orbit_at(target)`

---

## HUD — `ui/hud/`

### `HUD` — `hud.gd`
```
extends CanvasLayer   class_name HUD
```
| Señal | Cuándo |
|-------|--------|
| `deselect_requested` | Botón × presionado |
| `unit_focus_requested(unit: Unit)` | Click en un cuadrito de `DeployedPanel` |

API:
- `show_selected_unit(unit: Unit)` — muestra panel + acciones + botón ×
- `clear_selected_unit()` — oculta todo

Ruteo de acciones en `_on_action_pressed(name)`:
```gdscript
match action_name.to_lower():
    "hangar": _hangar_window.open(_current_unit)
```
Agregar casos aquí al implementar nuevas acciones.

**Árbol de `hud.tscn`:**
```
CanvasLayer (HUD)
├── EventLog         (PanelContainer) — offset (6,195)
├── Minimap          (PanelContainer) — offset (5,292) — placeholder
├── HangarWindow     (PanelContainer)
├── ActionsPanel     (PanelContainer) — offset_left=544, offset_top=313
├── SelectionPanel   (PanelContainer) — offset_left=544, offset_top=349
├── DeployedPanel    (PanelContainer) — panel superior, unidades desplegadas
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
| `clear()` | Vacía y oculta |
| `weapon_selected(weapon)` | El jugador pulsó un arma |

El activo va a alpha 1.0, el resto a `_DIM_ALPHA` (0.45). **No guarda estado**: la fuente
de verdad es `Unit.active_weapon`, porque la barra se reconstruye en cada selección.
`HUD` hace de intermediario — recibe `weapon_selected` y llama a `Unit.set_active_weapon()`.

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

### Pendiente
- [ ] Disparar: `Unit.active_weapon` ya dice con qué, falta el ataque en sí
- [ ] Cadena de repliegue al agotarse un arma (necesita munición consumible, que no existe)
- [ ] Elección de arma por distancia en combate aéreo (sistema de dogfight, sin planear)
- [ ] Vuelo en formación (aviones del mismo escuadrón)
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
