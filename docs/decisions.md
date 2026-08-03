# Decisiones — war-project

Registro cronológico (más reciente arriba). Una entrada por decisión: qué se decidió y por qué.

## 2026-08-02

### Armamento visible en el Harrier: el dato se queda, el dibujado está a prueba
Se implementó armamento por misión: se elige un loadout en el hangar y el avión sale con las armas colgadas de puntos de anclaje (`Marker2D`) en las alas.

**El dato funciona. El dibujado no convence** y puede echarse atrás sin tocar lo demás.

Por qué no convence, medido sobre los PNG y no supuesto: las armas del atlas miden **10–14 px de largo** (el AIM-120, 14) y la cuerda del ala donde cuelgan mide **10 px**. Dibujadas encima sobresalen siempre; dibujadas debajo desaparecen, porque el ala es opaca justo ahí (opaca de la fila 19 a la 28 en la columna de `L2a`, y el arma ocupa de la 16 a la 27: sobreviven 3 px). Además los cuerpos de 1–3 px de ancho hierven al rotar el avión en vuelo.

Se descartó por el camino que fuera un problema de capas o de escala. `z_index` hacía exactamente lo que debía. La escala fraccionaria del despegue (0.7 → 0.8 → 0.9) sí agravaba el pixel art y se dejó apagada tras un parámetro (`FlightDeck.spawn_scale`, 1.0 = apagado, 0.7 = comportamiento anterior), pero no era la causa.

Opciones sobre la mesa, sin decidir: (1) redibujar las armas más cortas y gruesas (6–8 px de largo, 2–3 px de cuerpo) para que quepan dentro de la silueta del ala; (2) no dibujar armas y dejar el loadout sólo como dato de HUD y combate; (3) un sprite del Harrier por preset — viable si el daño se resuelve como capa superpuesta y no como variante del sprite base, porque las capas se suman y los sprites base se multiplican.

**Cómo echar atrás sólo el dibujado** (el loadout sigue vivo como dato para HUD y combate):
- borrar `core/weapon/hardpoint_rack.gd`
- borrar los cinco `AtlasTexture` de `assets/art/sprites/`: `aim9_sidewinder.tres`, `aim120_amraam.tres`, `agm65_maverick.tres`, `mk82.tres`, `gbu54.tres`
- borrar el nodo `Hardpoints` y sus `Marker2D` de `core/unit/av8b_harrier/av8b_harrier.tscn`
- quitar de `Unit.set_weapon_loadout()` el bucle que busca el `HardpointRack` (la unidad sigue guardando su `weapon_loadout`)

**Cómo echar atrás el sistema entero**, además de lo anterior: borrar la carpeta `core/weapon/` y `core/unit/av8b_harrier/av8b_harrier_loadouts.gd`, y revertir los retoques de `unit.gd`, `flight_deck.gd` (parámetro `weapon_loadout` de `request_deploy`), `player_fleet.gd` (clave `weapon_loadouts`) y `hangar_window.gd` (los botones de misión volverían a una lista fija).

`assets/art/sprites/Jet_bombs_missiles.png` no se borra en ningún caso: sirve para iconos de HUD aunque no se dibujen armas en el avión.

## 2026-08-01 (4)

### El amague al virar era un `atan2` indeterminado en el centro del óvalo, no un parámetro mal puesto
El avión amagaba hacia un lado y viraba hacia el otro. Se sugirió al usuario ajustar `reengage_deg` y `dead_circle_hysteresis` — **ambas sugerencias eran incorrectas** y no sirvieron. La causa real se encontró midiendo, no ajustando parámetros.

`OrbitBehavior._lead_point()` calculaba la fase del circuito desde la posición del avión: `atan2(rel.y/semi_y, rel.x/semi_x)`. Cuando el avión pasa por el centro del óvalo, `rel ≈ 0` y ese ángulo es indeterminado: gira 180° de un frame a otro. Medido en headless, al llegar a 1 px del centro **el punto de referencia saltaba 450 px de golpe**, de abajo-derecha a arriba-izquierda. El avión venía virando hacia un lado y de pronto el objetivo estaba al otro. Eso era el amague.

Ocurría exactamente al terminar una orden del jugador, porque ahí el avión queda en el centro exacto del óvalo nuevo. Por eso no aparecía en la patrulla del despegue (el avión sale a 165 px del barco, nunca pasa por el centro) y por eso ningún parámetro lo arreglaba.

**Arreglo:** `OrbitBehavior` mantiene ahora una fase propia (`_phase`) que avanza sola cada frame al ritmo al que vuela el avión — nunca da saltos. La posición del avión sólo se usa para engancharla suavemente (`sync_rate`), y sólo cuando está más allá de `center_deadzone` (0.25 del óvalo), es decir, cuando su posición define un ángulo con sentido. Dentro de esa zona manda el rumbo del avión: `_reset_phase()` coloca el punto de referencia delante del morro con `atan2(semi_x·sin h, semi_y·cos h)`, que es la fase de la elipse alineada con el rumbo.

Tras el arreglo, el punto se mueve 2–3 px por frame al pasar por el centro (antes, 450 de golpe). Verificado en headless: 0 amagues en el ciclo completo (despegue → órbita → orden lejana → orden corta) y 0 amagues en un barrido de 16 órdenes (8 rumbos × 2 distancias). Criterio de amague: invertir un viraje fuerte (>0,35 rad/s) en menos de medio segundo. Se excluye la inversión inmediata al recibir una orden nueva: eso es obedecer, no dudar.

**Lección de método:** ante un síntoma de movimiento, medir antes de tocar parámetros. Un contador de inversiones de viraje a secas no sirve (1–3 son normales: virar, enderezar, entrar en órbita); lo que delata el problema es registrar los saltos del punto objetivo frame a frame.

## 2026-08-01 (3)

### El vuelo se separa del portaaviones y del avión: `PlaneController` + `OrbitBehavior`
El control de vuelo estaba repartido entre tres sitios que escribían la posición del mismo avión: los tweens de `flight_deck.gd` (taxi y despegue), el `_process` de `flight_deck.gd` (óvalo de patrulla) y el `_process` de `av8b_harrier.gd` (estados `FLYING_TO`/`ORBITING` tras una orden). El portaaviones pilotaba aviones, y `av8b_harrier.gd` mezclaba identidad de unidad, registro en grupos y steering. Quitarle el script al Harrier no detenía la patrulla — porque la patrulla no era suya. Se reorganizó en tres responsabilidades, una por archivo:

- **`core/unit/flight/plane_controller.gd`** (`PlaneController`) — *cómo* vuela. Velocidad, viraje, inercia, todo `@export`. Mueve al nodo padre desde `_physics_process`. Arranca inactivo. Base tomada de un script externo aportado por el usuario, adaptado a la escala y las convenciones del proyecto.
- **`core/unit/flight/orbit_behavior.gd`** (`OrbitBehavior`) — *a dónde* va cuando no hay órdenes.
- **`core/unit/av8b_harrier/av8b_harrier.gd`** — sólo qué ES el Harrier: identidad, grupo, y ruteo de la orden del jugador. Sin vuelo.

`flight_deck.gd` conserva únicamente la cubierta (elevadores, taxi, cola, carrera de proa). Al terminar el tramo de proa llama `_hand_over_control(unit)` → `unit.start_flight(barco, takeoff_speed)` y no vuelve a tocar al avión. Se eliminaron `_patrol_planes`, `_start_patrol`, su `_process` y los exports `patrol_semi_x`/`patrol_semi_y`/`turn_rate`. Se eliminó la señal `taking_self_control` del Harrier: existía sólo para que la cubierta sacara al avión del óvalo, y ya no hay óvalo en la cubierta.

**El óvalo no es un riel.** Antes, una fórmula de elipse calculaba la posición del avión cada frame y se la imponía — de ahí que se viera antinatural: la trayectoria venía de afuera, el avión sólo la obedecía. Ahora `OrbitBehavior` le da al piloto, cada frame, un punto sobre la elipse `lead_deg` (35°) por delante de donde está el avión, y el avión lo persigue. La curva que se ve es el resultado real de su inercia y su radio de giro.

Se probó primero con waypoints discretos sobre la elipse y **no funciona**: un avión que no puede frenar nunca "llega" a un punto que tiene al costado; se queda orbitándolo a distancia constante para siempre. Medido en prueba headless: 0 waypoints alcanzados en 600 frames, dando vueltas a 129 px de un punto con radio de giro de 134 px. El punto deslizante elimina el problema de raíz.

**Dos correcciones al script de control aportado**, ambas por el mismo motivo — el latch de compromiso de viraje (lo que evita el amague) creaba trampas geométricas:
1. *Círculo muerto.* El script comprobaba si el destino caía dentro del círculo de giro sólo al elegir el lado. Una vez comprometido no lo volvía a mirar, y como en esa situación el error angular se queda en ~90° (nunca baja de `release_deg`), el compromiso no se soltaba nunca. Ahora se comprueba en continuo. La respuesta correcta es **nivelar y salir recto** hasta que la geometría permita enfilar el punto; invertir el viraje se probó y produce oscilación (el avión se alejaba en zigzag sin converger).
2. *`flyby_capture`.* Da por alcanzado un destino ya rebasado si está dentro del radio de giro. Sin esto el avión da un bucle completo para volver a un punto que ya dejó atrás.

**Parámetros a escala del proyecto.** El script venía con `min_speed` 110 / `max_speed` 290 / `base_turn_deg` 130, que a velocidad de crucero dan un radio de giro de ~300 px — imposible ceñir el óvalo de 200×280, el avión volaba un 40–74 % por fuera. Se ajustó a 70 / 150 / 150, coherente con los 120 px/s que usaba el vuelo original. Regla a respetar al tocar estos valores: `min_turn_radius()` a crucero debe ser menor que el radio de curvatura del óvalo (`semi_x²/semi_y` en el punto más cerrado). Tras el ajuste el avión ciñe el óvalo con error < 9 %.

**Orientación del sprite.** El arte del Harrier apunta a **+Y local** (abajo); el script aportado asume +X. Se expuso como `sprite_offset_deg` (−90) en vez de dejarlo hardcodeado, para que cada avión con arte distinto lo ajuste desde el Inspector.

Verificado en headless (`--script` sobre un `SceneTree` de prueba, borrado después): órbita estable alrededor del barco ciñendo el óvalo; orden del jugador a 1133 px de distancia cumplida en 7,7 s con `order_fulfilled` y órbita posterior sobre el punto nuevo; y el ciclo completo de cubierta con dos aviones desplegados, taxi, despegue y entrega de control.

## 2026-08-01 (2)

### Escuadrones: líder = quien despega primero, y selección por click en el mundo
Se probó una implementación completa de vuelo en formación (seguidores persiguiendo un rastro del líder) en la rama `formation` y se descartó por completo — el movimiento resultante era inestable (virajes bruscos al despegar, oscilación en vuelo) y no se pudo estabilizar en varios intentos. Se revirtió todo el código de movimiento/seguimiento. El vuelo en formación queda pendiente, a implementar en otra sesión (ver `README.md`, sección de pendientes, con notas del usuario sobre por dónde empezar: `core/unit/squad.gd`, y ajustar a mano los parámetros de `flight_deck.gd` y `av8b_harrier.gd`).

De esa implementación se conservaron dos piezas, porque son correctas y no dependen de nada del movimiento:

1. **Líder = quien despega primero.** `Squad.add(unit, slot)` (`core/unit/squad.gd`) ahora recibe el `slot` de cubierta asignado al avión (`flight_deck.gd` se lo pasa en `_process_queue`) y asigna como líder a quien tenga el slot más alto del grupo (`_leader_slot`, se recalcula en cada `add`). Como `_launch_next` despega primero los slots más altos, el líder despega siempre primero dentro de su escuadrón — antes el líder era simplemente "el primero en subir al elevador", que no tenía relación con el orden real de despegue.

2. **Click en cualquier integrante del escuadrón selecciona al líder.** `SelectionManager._find_unit_at()` (`core/selection/selection_manager.gd`) ahora, si la unidad bajo el cursor tiene `squad != null`, devuelve `unit.squad.leader` en vez de la unidad clickeada. Esto es aparte de lo que ya hacía `DeployedPanel` (el panel de arriba ya enfocaba al líder al click desde antes) — ahora también funciona clickeando directo sobre cualquier avión del escuadrón en el mapa.

## 2026-08-01

### Escuadrones: identidad de grupo sin seguimiento/formación todavía
Pendiente del README: "las unidades desplegadas como escuadrón deben salir en el menú de unidades como una sola con multiplicador xN". Se implementó SOLO esa parte — agrupar en el panel y enfocar al líder al click. El seguimiento/formación (que seguidores repliquen movimiento y ataque del líder) queda pendiente para más adelante; se necesitaba primero algo que identifique "quién es el líder de quién".

Se creó `Squad` (`core/unit/squad.gd`, `RefCounted`, no `Resource` — es agrupación en tiempo de ejecución, no dato para persistir), con `leader: Unit` y `members: Array[Unit]`; `add(unit)` asigna líder al primero que llega. `Unit` (`core/unit/unit.gd`) gana un campo no exportado `squad: Squad = null` — mismo patrón opcional que `unit_name`.

La asignación ocurre en `flight_deck.gd`, el único lugar que hoy instancia aviones: `request_deploy(scene, squad: Squad = null)` ahora acepta un `Squad` opcional y lo guarda en el job de la cola; al spawnear el avión (`_process_queue`), si el job trae `squad`, se castea la unidad a `Unit` (`job["scene"].instantiate()` devuelve `Node2D`, no expone `.squad` sin castear) y se llama `squad.add(unit)`. No se tocó nada de la lógica de cola/elevador/pista — el pendiente de "un vuelo espera a que la pista se libere" sigue sin resolver (se había intentado y se revirtió por no funcionar bien; queda para otra sesión).

`HangarWindow._on_deploy()` crea un `Squad` nuevo solo si `_quantity > 1` y lo pasa a cada `request_deploy()` del lote; con cantidad 1 pasa `null` (unidad suelta, sin escuadrón).

`DeployedPanel` (`ui/hud/deployed_panel/deployed_panel.gd`) ahora, al recorrer las unidades de un grupo, colapsa las que comparten `squad` en un solo botón (nombre del líder) y le agrega un badge `xN` — `Label` hijo posicionado en la esquina inferior derecha del botón (`mouse_filter = IGNORE` para no tapar el click), NO texto concatenado al nombre. Unidades sin `squad` se muestran igual que antes. Al click, emite `unit_selected(squad.leader)` en vez de una unidad cualquiera del grupo.

## 2026-07-31

### Cámara sigue a la unidad seleccionada (`core/camera/pan_camera.gd`)
`PanCamera` tiene `follow_target: Node2D`. En `_process` mueve `position` al `global_position` del target cada frame. Al arrastrar el mapa (drag), `follow_target = null` — el pan queda libre pero la unidad sigue seleccionada. Hacer click sobre la misma unidad re-engancha el follow. `SelectionManager` asigna `_camera.follow_target = _selected_unit` en `_select()`, y lo limpia a null al deseleccionar.

### Sistema de órdenes de movimiento (`core/selection/selection_manager.gd`)
Esquema de input unificado PC/móvil: click derecho (PC) sobre el mapa o click izquierdo sobre espacio vacío con unidad seleccionada emiten una orden de movimiento a la unidad. Click sobre la misma unidad seleccionada la deselecciona. Click sobre otra unidad la selecciona. El contexto (qué hay bajo el cursor) determina la acción, sin separar gestos por plataforma. `Unit` base tiene `receive_move_order(target: Vector2)` como virtual vacío; las unidades que se mueven lo sobreescriben. `Unit` base también tiene `order_fulfilled` como señal opcional; `SelectionManager` conecta a ella con `CONNECT_ONE_SHOT` si existe.

### Marcador de destino (`core/selection/move_marker.gd`)
`Node2D` con `_draw()` que dibuja un círculo con cruz en color accent del HUD. Creado dinámicamente por `SelectionManager` y añadido a la escena. Aparece al dar la orden, desaparece cuando la unidad emite `order_fulfilled`. Al deseleccionar se oculta; al reseleccionar la misma unidad con orden activa reaparece. Una sola orden activa por unidad — nueva orden reemplaza la anterior.

### Patrulla del AV-8B Harrier II (`core/unit/av8b_harrier/av8b_harrier.gd`)
El Harrier tiene script propio que extiende `Unit`. Durante la patrulla inicial (óvalo del portaaviones) es controlado por `flight_deck.gd` via `_patrol_planes` como siempre. Al recibir `receive_move_order`, emite `taking_self_control` — `flight_deck` lo escucha y lo elimina de `_patrol_planes`. El Harrier toma control de su propio `_process` con dos estados:
- `FLYING_TO`: navega al punto destino girando a `turn_rate` rad/s. Al llegar a 30px del centro emite `order_fulfilled` y entra en `ORBITING`.
- `ORBITING`: círculo de radio 120px (configurable) alrededor del punto. Siempre CCW en pantalla (ángulo decreciente). El punto de entrada al círculo se inicializa con `_patrol_angle = _heading` al pasar por el centro — esto pone el target adelante en la dirección que traía el avión, evitando inversiones bruscas. El heading se inicializa desde `global_transform.y` en el momento de recibir la orden para continuidad de vuelo.

### Deselección de unidades
Dos mecanismos complementarios implementados:
- **Escape (PC):** `SelectionManager._unhandled_input` detecta `KEY_ESCAPE` (con `not event.echo` para ignorar repeticiones) y llama `_select(null)`.
- **Botón × (PC y móvil):** Nodo `Button` independiente en `hud.tscn`, posicionado a la izquierda del `SelectionPanel`. Se muestra/oculta con `show_selected_unit`/`clear_selected_unit`. Al presionarlo, `HUD` emite `deselect_requested` — `SelectionManager` conecta a esta señal en `_ready()` y llama `_select(null)`. El botón es un nodo libre en el HUD (no dentro del SelectionPanel) para evitar problemas de layout.

## 2026-07-26
- Sistema de acciones por unidad: `UnitType` (`core/unit/unit_type.gd`) ahora tiene `actions: PackedStringArray`. Se configura en el Inspector de Godot editando el `.tres` de cada tipo (p. ej. `lhd_wasp_type.tres`), sin tocar código. `Unit.get_actions()` lo expone. `ActionsPanel` (`ui/hud/actions_panel/`) genera un `Button` por acción de forma dinámica en `show_actions()` y emite la señal `action_pressed(action_name)`. El ruteo acción→ventana vive en `HUD._on_action_pressed()` con un `match` — punto único de conexión para agregar futuras acciones.
- Ventanas arrastrables de unidad (patrón establecido): primer caso `HangarWindow` (`ui/hud/hangar_window/`), abierta por la acción "hangar" del LHD Wasp. Estructura: `PanelContainer` con barra de título (`HBoxContainer`, `mouse_filter=STOP`) que maneja drag vía `gui_input`, label de título, botón X para cerrar, y un nodo `Content` (`Control`) vacío donde irá el contenido específico. Mismo estilo visual que el resto del HUD (paleta Resurrect64). Futuras ventanas de acción siguen este mismo patrón.
- Minimapa interactivo: quedó en diseño, sin implementar todavía. Ideas acordadas hasta ahora: debe autodescubrir el mapa de la escena donde se instancie (mismo patrón que `PanCamera._fit_limits_to_map()`, sin wiring manual); dibujar el mapa en versión esquemática/simplificada (no el arte real) por rendimiento en móvil/Switch; mostrar unidades solo como nombre (`Unit.get_display_name()`) + ícono aún sin diseñar, nunca el sprite real, descubriéndolas por grupo de Godot en vez de referencia directa. Pendiente de definir: el zoom NO debe centrarse en ninguna unidad (esto se descartó explícitamente) — la idea es poder ver mejor partes del mapa y la acción, posiblemente navegando dentro del minimapa, o mostrando lo último visto en el mapa táctico grande (pantalla aparte, todavía no implementada). Falta resolver el mecanismo concreto de zoom/navegación antes de programar nada.
- `Unit` (`core/unit/unit.gd`) ahora tiene `unit_name` exportado, un nombre propio por instancia que no pasa por traducción (a diferencia de `unit_type.display_name`, que sí). Si `unit_name` está vacío, `get_display_name()` cae de nuevo a la categoría del `UnitType`. Bugfix asociado: `SelectionManager` esperaba nodos tipados (`camera`/`hud`) resueltos automáticamente desde un `NodePath` escrito a mano en `main.tscn`, pero esa auto-resolución no ocurre así — se cambió a exportar `camera_path`/`hud_path` (`NodePath`) y resolverlos explícitamente con `get_node()` en `_ready()`, patrón más confiable. También se corrigió `ui/hud/selection_panel/`: el `Label` no tenía autowrap, así que con nombres largos el `PanelContainer` se agrandaba y se salía de los 640×384 de pantalla — se le agregó `autowrap_mode` y se agrandó un poco el panel.
- Selección de unidades (primera versión): se distingue click de arrastre por umbral de movimiento del mouse (`click_threshold_px` en `PanCamera`, `core/camera/pan_camera.gd`) — si el mouse no se movió más de ese umbral entre press y release, se interpreta como click y `PanCamera` emite la señal `clicked(world_position)`; si lo superó, sigue paneando como antes. `PanCamera` no sabe nada de selección, solo reporta el gesto.
- Nueva clase base `Unit` (`core/unit/unit.gd`, extiende `Area2D`) para toda unidad seleccionable, con `CollisionShape2D` (tamaño por instancia) y un `SelectionIndicator` (`core/unit/selection_indicator.gd`) que dibuja un contorno cuando está seleccionada. Cada unidad concreta vive en su propia carpeta con su escena que hereda de `core/unit/unit.tscn` — primer caso real: `core/unit/lhd_wasp/lhd_wasp.tscn`, que además reemplaza al `Sprite2D` suelto que tenía `main.tscn` para el LHD_WASP.
- Nuevo nodo `core/selection/selection_manager.gd`: escucha la señal `clicked` de `PanCamera` y hace un query de física (`intersect_point`) para encontrar la `Unit` bajo el cursor. Vive en `main.tscn`, referenciando a `PanCamera` y `HUD` por `NodePath` exportado — no hace falta habilitar picking automático de Viewport porque el query es manual.
- Datos de unidad separados en un `Resource` compartido por tipo: `UnitType` (`core/unit/unit_type.gd`), con `display_name`. Se decidió así (en vez de un string suelto por instancia) pensando en localización: el nombre mostrado pasa por `tr()`, y como el `Resource` se comparte entre todas las instancias de un mismo tipo (ej. `core/unit/lhd_wasp/lhd_wasp_type.tres`), el día que se arme el catálogo de traducciones solo hay que tocar la clave en un lugar por tipo, no por instancia. Nombres propios de unidad (si se agregan más adelante) irían aparte, sin pasar por traducción.
- Nuevo panel de HUD `ui/hud/selection_panel/` (mismo estilo visual que `event_log`/`minimap`), ubicado esquina inferior derecha, que muestra el nombre de la unidad seleccionada vía `HUD.show_selected_unit()` / `clear_selected_unit()` (`ui/hud/hud.gd`, nuevo script en la raíz de `hud.tscn`). Pendiente: todavía no hay stats/estado/acciones por unidad — se agregan cuando se defina el sistema de combate/órdenes.
- Confirmado: el pan de cámara con click+arrastre funciona correctamente probando en la ventana del juego (F6), tras reiniciar el editor de Godot. El bloqueo anterior era de sesión/testeo (se estaba probando el arrastre en la vista 2D del editor en vez de en la ventana del juego corriendo), no un bug del script — `core/camera/pan_camera.gd` queda validado tal cual. `HUD` (`ui/hud/hud.tscn`) y `PanCamera` (`core/camera/pan_camera.tscn`) ya están instanciados en `main.tscn` junto al `TileMapLayer` y el sprite `LHD_WASP`.

## 2026-07-25
- Bugfix: `HUD` estaba colgado de un `Control` bajo el `Node2D` del mundo en vez de un `CanvasLayer`, así que la cámara lo arrastraba junto con el mapa. Se cambió el nodo raíz de `hud.tscn` a `CanvasLayer` para que quede fijo en pantalla. También se hizo que `PanCamera` arranque centrada en el centro del área pintada del mapa (antes arrancaba en (0,0), fuera del mapa, por lo que el arrastre no se notaba).
- Cámara: pan con click izquierdo + arrastre (y tap+arrastre en móvil vía emulación de mouse de Godot). Los límites de cámara NO son fijos: se recalculan en `_ready()` a partir de `get_used_rect()` de todos los `TileMapLayer` presentes en la escena (unión de sus rects), porque el tamaño del mapa está en desarrollo y cambia constantemente. Vive en `core/camera/pan_camera.gd` + `.tscn`. Pendiente: regla para distinguir click de selección de unidad vs. arrastre de cámara — se define cuando se construya la selección de unidades.
- HUD: colores del mockup mapeados a códigos exactos de Resurrect64 (fondo/paneles `#313638`, borde `#8fd3ff`, texto `#ab947a`), para no salir de paleta. Primeros componentes creados en `ui/hud/`: `event_log/` (panel con `add_event(text)`, máx. 4 líneas visibles) y `minimap/` (panel placeholder sin lógica aún, a la espera de datos de mapa/mundo). `hud.tscn` los instancia y posiciona en la esquina inferior izquierda; falta integrarlo a `main.tscn` manualmente.
- Estructura de carpetas: se organiza por feature (cada unidad/barco/pantalla con su escena+script+arte propios juntos; `assets/` solo para lo compartido) pero de forma incremental — sin scaffold completo inicial. Las carpetas se crean a medida que se necesitan, no todas de una vez.
- Configurado `project.godot`: viewport 640x384, ventana inicial 1280x768 (2x), stretch mode "viewport" + aspect "keep" + scale_mode "integer" (fuerza escala entera siempre), filtro de texturas global Nearest. Pendiente: importar fuente pixel y desactivar su antialiasing/filtro por recurso (no es global).
- Contexto del proyecto se mantiene en archivos versionados dentro del repo (`CLAUDE.md`, `docs/GDD.md`, `docs/decisions.md`) en vez de en la memoria local de Claude, para que sea portable entre equipos vía git. El usuario gestiona git por su cuenta.
- Definición inicial del juego: RTT 2D simplificado inspirado en Raid on Bungeling Bay, flota con buque insignia anfibio multipropósito mejorable/reemplazable, unidades con IA + control manual opcional. Godot, resolución 640×384, escala entera, paleta Resurrect64, pixel art, fuente pixel externa. Plataformas: PC, móvil, Switch.
