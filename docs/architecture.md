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

| Método | Descripción |
|--------|-------------|
| `set_selected(bool)` | Muestra/oculta SelectionIndicator |
| `get_display_name()` | unit_name si existe, sino tr(unit_type.display_name) |
| `get_actions()` | PackedStringArray desde unit_type.actions |
| `receive_move_order(Vector2)` | **Virtual vacío** — sobreescribir en subclases |

Señales opcionales (no en la base, implementadas por subclases que las necesiten):
- `order_fulfilled` — la unidad llegó al destino
- `taking_self_control` — la unidad dejó de ser controlada externamente

SelectionManager usa `has_signal()` antes de conectar — no acoplamiento directo.

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

---

### `SelectionIndicator` — `core/unit/selection_indicator.gd`
```
extends Node2D
```
Dibuja contorno de selección en `_draw()`. Export `size: Vector2`. Color accent `#8fd3ff`.

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

**`_find_unit_at(pos)`:** Query `PhysicsPointQueryParameters2D` con `collide_with_areas=true, collide_with_bodies=false`. Devuelve la primer `Unit` bajo el cursor o null.

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
Gestiona el ciclo completo de despliegue: Elevador → Taxi → Despegue → Patrulla oval.

**Exports clave:**
- `taxi_speed`, `elevator_cycle_time`, `launch_delay`, `takeoff_speed`
- `post_bow_distance`, `climb_duration`
- `patrol_semi_x` (200), `patrol_semi_y` (280) — semiejes del óvalo alrededor del barco
- `turn_rate` (2.0 rad/s) — giro de aviones en el óvalo

**Estado interno:**
- `_occupied[4]`, `_units[4]` — slots de cubierta
- `_taxi_queues[2]` — cola por elevador
- `_patrol_planes: Array[{unit, angle, heading}]` — aviones en óvalo

**API pública:**
- `request_deploy(scene: PackedScene) → bool` — inicia ciclo de despliegue
- `has_free_slot() → bool`

**`_start_patrol(unit)`:** Añade avión al óvalo. Si la unidad tiene señal `taking_self_control`, la conecta con `CONNECT_ONE_SHOT` para removerla del óvalo automáticamente cuando tome control propio.

**`_process`:** Mueve cada avión en el óvalo. Velocidad lineal constante compensando la curvatura. Steering con blend tangente/corrección (igual que Harrier pero elipse).

---

### `AV-8B Harrier II` — `core/unit/av8b_harrier/`

**`av8b_harrier.gd`:**
```
extends Unit
```
| Señal | Cuándo |
|-------|--------|
| `order_fulfilled` | Llegó al punto destino (entró en órbita) |
| `taking_self_control` | Recibió una orden de movimiento |

| Export | Default |
|--------|---------|
| `patrol_radius` | 120.0 px |
| `turn_rate` | 2.0 rad/s |
| `patrol_speed` | 120.0 px/s |

**Estados (`_State`):**
- `FLYING_TO` — navega al punto, gira hacia él con `turn_rate`
- `ORBITING` — círculo CCW (ángulo decreciente), radio `patrol_radius`

**`receive_move_order(target)`:**
1. Inicializa `_heading` desde `global_transform.y` (continuidad de vuelo)
2. Entra en `FLYING_TO`
3. Emite `taking_self_control` → FlightDeck lo elimina del óvalo

**Entrada al círculo:** Al llegar a < 30px del centro, `_patrol_angle = _heading`. Esto pone el primer punto target adelante en la dirección de llegada, evitando inversión brusca.

**Órbita:** Siempre CCW. Steering: blend entre tangente y corrección al punto de la elipse, clamped a 0.4 máximo.

**Rotación sprite (Y-forward):**
```gdscript
global_rotation = atan2(-move_dir.x, move_dir.y)
```

---

## HUD — `ui/hud/`

### `HUD` — `hud.gd`
```
extends CanvasLayer   class_name HUD
```
| Señal | Cuándo |
|-------|--------|
| `deselect_requested` | Botón × presionado |

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
Inventario de flota. **Hardcodeado** — reemplazar con sistema de puerto cuando exista.

```gdscript
_loadouts = {
    "LHD Wasp": [
        { "display_name": "AV-8B Harrier II",
          "scene": preload("res://core/unit/av8b_harrier/av8b_harrier.tscn"),
          "total": 6, "deployed": 0 }
    ]
}
```

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

---

## Paleta de colores (Resurrect64 en uso)

| Uso | Hex | Color GDScript |
|-----|-----|----------------|
| Fondo paneles | `#313638` | `Color(0.192, 0.212, 0.220)` |
| Texto/borde | `#ab947a` | `Color(0.671, 0.580, 0.478)` |
| Accent/selección | `#8fd3ff` | `Color(0.561, 0.827, 1.0)` |

---

## Estado de implementación

### Implementado y funcional
- [x] Cámara con pan + follow a unidad seleccionada
- [x] Selección de unidades por click (física query manual)
- [x] Órdenes de movimiento (click izq. vacío / click der.)
- [x] Marcador de destino (desaparece al llegar)
- [x] Deselección: Escape + botón × en HUD
- [x] AV-8B Harrier: vuelo al punto → órbita CCW
- [x] LHD Wasp: despliegue completo (elevador → taxi → despegue → óvalo)
- [x] HangarWindow: selector cantidad + misión + DESPLEGAR
- [x] HUD base: event log, minimap placeholder, selection panel, actions panel
- [x] Transición flight_deck → control propio del Harrier via `taking_self_control`

### Pendiente
- [ ] Suavizar movimiento en patrulla oval del portaaviones
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
- [ ] Menú de opciones al clickear unidad enemiga
