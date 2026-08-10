# Decisiones — war-project

Registro cronológico (más reciente arriba). Una entrada por decisión: qué se decidió y por qué.

## 2026-08-10

### Los casquillos van por calibre, no por unidad
Un archivo de 5×6 px con los dos casquillos dentro, recortados con `AtlasTexture`, y dos
escenas: `casing_30mm.tscn` y `casing_25mm.tscn`. **Nombrados por el cartucho y no por el
vehículo** porque el casquillo es del cartucho: el mismo 25 mm vale para cualquier arma que lo
dispare, y atarlo al Harrier obligaría a duplicarlo en cuanto haya otra que use ese calibre.

Como con las trazadoras, **no se echa uno por bala**: 8–10 por segundo de los 50–60 que se
disparan. Sesenta nodos por segundo no se sostienen y además no se distinguirían.

### Por qué lado sale un casquillo lo decide el arma, no el cartucho
Primer intento: `eject_angle_deg` vivía en `Casing`. No funciona con un cañón gemelo — los dos
tubos usan el mismo cartucho y escupen a lados opuestos —, y habría obligado a dos escenas por
calibre. Se movió a `CasingEjector`, y `Casing.launch()` recibe la dirección **ya resuelta**: el
cartucho no sabe de armas.

### La izquierda del piloto y la izquierda del dibujo son lados opuestos
Costó tres intentos y merece quedar escrito, porque va a volver a pasar con cualquier efecto
lateral.

El arte apunta a **+Y**, o sea al sur. **Quien mira al sur tiene el este a su izquierda**, y el
este es +X: el lado **derecho** de la imagen. Así que "el lado izquierdo de la cabina" y "el
lado izquierdo del sprite en el editor" son sitios contrarios, y mirar el sprite quieto para
decidir el signo lleva justo al error.

La regla: **para cualquier cosa que salga de lado, razonar desde dentro del vehículo, no desde
la imagen.** Es la misma familia de fallo que el `−90` del rumbo y que el `get_facing()` de la
torreta: el sistema de referencia del dibujo no es el del vehículo.

De paso, la primera medición no lo detectó porque comprobaba **dónde nacían** los casquillos y
no **hacia dónde salían**: con los dos eyectores del Tunguska escupiendo al mismo lado, el test
seguía viendo casquillos a izquierda y derecha, porque nacían en sitios distintos. Medir el
efecto, no la posición de partida.

### La cadencia de siembra es una sola, esté quien esté sembrando
`TracerStream` y `CasingEjector` llevaban la misma cuenta —restar el delta, soltar los que
toquen, arrastrar el resto al frame siguiente— y sólo cambiaba qué sale. Se extrajo a
`EffectEmitter._due(delta, per_second)`.

Devuelve un **número** y no un sí/no a propósito: con cadencias por encima de los fps toca
soltar más de uno en el mismo frame, y sin arrastrar el resto la cadencia real quedaría limitada
por los fotogramas. `_begin()` de la base pone el reloj a cero para que **el primero salga ya**;
quien siembre por distancia (`SmokeTrail`) lo sobrescribe. El cañón del avión no notó el cambio:
sigue quitando 37,7 en la primera pasada y abriendo fuego una sola vez por pasada.

### Un casquillo hereda parte de la velocidad, ni toda ni ninguna
`inherit_velocity = 0.5`. A 1 volarían pegados al avión como si fueran parte de él; a 0 se
quedarían clavados en el aire, como si el avión no llevara inercia. A la mitad salen
acompañando y **se van quedando atrás** — medido, hasta 68 px por detrás del morro antes de
frenarse del todo.

Se le pregunta la velocidad a la unidad (`get_velocity()`) y no se deduce de cómo se mueve el
nodo emisor: **la torreta de un antiaéreo gira, y girar no es desplazarse**.

### Una unidad antiaérea son tres componentes genéricos y veinte líneas de pegamento
El 2S6 Tunguska es la primera unidad enemiga con comportamiento. Podía haber sido una clase
`Tunguska` con todo dentro; se hizo al revés, y la prueba de que la separación es real es
dónde vive cada archivo:

| pieza | vive en | qué sabe |
|---|---|---|
| `RangeRings` | `core/unit/` | dibujar dos círculos |
| `RadarDish` | `core/unit/` | girar |
| `TurretTracker` | `core/unit/` | a quién seguir y apuntarle |
| `tunguska_2s6.gd` | carpeta de la unidad | atar los cabos que ninguno puede atar solo |

En `core/unit/` porque **ninguno menciona al Tunguska** y cualquier batería futura los reusa. En
la carpeta de la unidad sólo quedan dos cosas que son propias de este vehículo: que lo que el
radar engancha es a quien se dispara, y que su `get_facing()` es la línea de los cañones.

Es la misma lección que dejó la etiqueta de unidad más abajo en esta misma fecha: lo genérico
sale solo cuando se construye fuera de la escena concreta, no después a base de mover archivos.

### Detectar por distancia y no con un `Area2D`
El radar y la torreta podrían haber usado un `Area2D` con un `CircleShape2D`. Se descartó: el
combate entero ya resuelve alcance por distancia (`WeaponType.in_range()`), y un área nueva
sería **un segundo mecanismo en paralelo respondiendo a la misma pregunta**, con capas y
máscaras que mantener. Recorrer el grupo `unit_air` y medir es directo, y `rescan_interval`
(0,1 s) evita hacerlo 60 veces por segundo — nada cruza un rango entero en una décima.

Efecto lateral bueno: es genérico desde el primer día. Nada nombra al Harrier; cualquier
aeronave que entre en el grupo entra en la búsqueda.

### El radar de vigilancia no sigue a nadie
Primera versión: el radar detectaba y seguía al avión. Doble error, y el de fondo no era de
código.

El técnico: `sprite_offset_deg` invertido, así que apuntaba con la parte de atrás del plato.
El de diseño, que es el que importa: **un radar de vigilancia barre todo el cielo**; si se para
a mirar a un avión deja de vigilar el resto, que es lo contrario de para lo que está. En el
trasto real quien engancha es el radar de puntería de la torreta.

Así que `RadarDish` quedó reducido a girar y ya — quince líneas — y engancharse pasó a
`TurretTracker`. Menos código y más parecido a la máquina.

### El rango es una mecánica, así que el jugador tiene que poder verlo
`RangeRings` dibuja los dos círculos con `_draw()` y es `@tool`, para ajustarlos arrastrando un
número sin ejecutar el juego. Son dos y no uno porque **ver y poder disparar no son lo mismo**:
la corona entre ambos es la ventana en la que la unidad ya te vio y todavía no te llega, y ése
es el margen de reacción del jugador.

Dos fallos al montarlo, los dos por no pensar en la pantalla:

1. **`z_index = -1` los metió debajo del suelo.** El terreno es un `TileMapLayer` en 0. En 0
   basta: el mapa se dibuja antes por orden de árbol y la unidad va en 1.
2. **No cabían.** Se pusieron en 700 y 400 px de radio cuando a zoom 1x sólo se ven 320 px
   desde el centro. Los dos círculos caían fuera de cuadro y parecía que no se dibujaba nada.

La regla que queda: **en un mundo de 640×384, cualquier alcance por encima de ~320 px no se ve
entero**, y un rango que no cabe en pantalla significa que el jugador entra en cobertura sin
ver la amenaza. Vale para los círculos y vale para las armas.

### Las ráfagas son un dato del arma, y 0 significa "sin ráfagas"
Un antiaéreo no puede escupir fuego continuo desde que te ve hasta que sales: ni suena ni se ve
como un antiaéreo, y le quita al jugador el hueco por el que colarse. Pero el cañón del avión
**sí** debe tirar seguido, porque ahí la pasada ya es la ráfaga.

Se resolvió con dos campos en `WeaponType` — `burst_seconds` y `burst_pause` — y la elección de
que **`burst_seconds = 0` sea "sin ráfagas"**. Así el arma del avión no cambia sin tocarla, y el
comportamiento nuevo no es un `if` por unidad sino un número por arma. Medido: 0,80 s de fuego /
0,70 s de silencio, exactos; y el cañón del Harrier sigue abriendo fuego una sola vez por pasada
y quitando los mismos 37,7 de daño que antes.

El silencio se implementa soltando el gatillo (`_release_trigger()`), no con una bandera aparte:
así los efectos apagan el fogonazo por la señal de siempre y **ninguno se entera de que existen
las ráfagas**.

### Lo que dispara no siempre es de quien cuelga el efecto
`EffectEmitter` daba por hecho que su padre era la `Unit`: `get_parent() as Unit` para el rumbo,
y `get_parent().get_parent()` para saber cuál es "el mundo". Cierto en un avión, falso en un
vehículo con torreta, donde hay un nivel de más. Los dos sitios pasaron a subir por el árbol
hasta encontrar la `Unit` (`_shooter()`).

El segundo era el peligroso: sin arreglarlo, las trazadoras nacían colgadas de la unidad y
**habrían girado con la torreta** en vez de quedarse donde se soltaron. Un rastro que sigue a
quien lo suelta no es un rastro.

### El `get_facing()` de un vehículo con torreta es el de la torreta
`WeaponSystem` pregunta `get_facing()` para saber si el blanco está en el cono, y los efectos
para saber hacia dónde sale el fuego. Con la implementación por defecto — la rotación del nodo —
el Tunguska habría creído apuntar hacia donde mira el casco: no dispararía nunca, o peor,
dispararía de lado. `tunguska_2s6.gd` lo redirige a la torreta.

Es el mismo problema que el `-90` del Harrier, un escalón más arriba: **la orientación que
importa para el arma no es la del vehículo, es la de lo que sostiene el arma**.

### Colocar la boca de un arma: contar píxeles, no poner el centro
El primer emisor del cañón se puso en `(0, 12)` — el centro de la torreta — y la ráfaga salió
por el radar de seguimiento frontal. Además era **uno solo**, cuando el Tunguska tiene dos tubos.

Los tubos están en `x = ∓7` con la boca en `y = +12`, medido sobre los píxeles del sprite. Hoy
hay un juego de efectos por cañón (fogonazo, trazadoras y humo), los seis enganchados a las
mismas señales, así que abren y cierran sincronizados como el cañón gemelo que son.

Refuerza el patrón que ya estaba escrito para el arte sobre arte: **medir los píxeles, no
ajustar a ojo** — y mirar el sprite antes de decidir cuántos emisores hacen falta.

### La etiqueta de una unidad es HUD que se mueve, no adorno pegado a la unidad
`UnitTag` — línea desplegable + nombre al seleccionar. Se construyó primero **dentro de la escena del Harrier**, con dos nodos en `top_level`, y hubo que rehacerlo entero. Vale la pena dejar por qué, porque los tres fallos parecían tres bugs y eran el mismo error de sitio:

1. **Aparecía lejísimos un frame y desaparecía.** `top_level` no hereda posición; se dibujaba donde estaba antes de que el reposicionado la corrigiera.
2. **Temblaba al volar.** Se reposicionaba en `_physics_process`, pero quien mueve el avión es `PlaneController`, un nodo **hijo**. El padre corre antes, así que leía la posición de un tick atrás, cada tick.
3. **Vibraba con el zoom y a 0,5x era ilegible.** Ésta ya no se podía parchear: la cámara escala todo lo que vive en el mundo.

La 3 es la decisión de verdad: **una etiqueta que sigue a una unidad no es parte del mundo.** Tiene que medir siempre lo mismo y sólo cambiar de sitio. Va en el `CanvasLayer` y pregunta cada frame dónde cae la unidad en pantalla (`get_global_transform_with_canvas()`). Verificado a 0,5x / 1x / 2x: escala (1,1) y fuente 16 en los tres.

Lo incómodo del asunto es que **el patrón ya estaba escrito tres funciones más arriba**: `HUD._impact_timer` lleva haciéndolo desde siempre. Reusé el patrón que tenía a mano en la escena del avión (`top_level`, como `SelectionIndicator` y los efectos del cañón) sin preguntarme si aplicaba. Regla nueva en `architecture.md`: lo que sigue a una unidad pero se **lee** va en el HUD.

Efecto lateral: al sacarlo del Harrier quedó genérico. Ahora cualquier unidad seleccionada muestra su nombre, y `av8b_harrier.gd` volvió a quedar exactamente como estaba.

### Un `Control` puesto en el mundo vibra, y no es culpa de la fuente
Perseguí el temblor del texto un buen rato dándole vueltas al import de la fuente. La causa era otra: `snap_controls_to_pixels` está activo por defecto y redondea la posición de **todo `Control`** al píxel. Para un HUD fijo es lo correcto; para un `Label` que viaja por el mundo con zoom, el redondeo cae en el espacio equivocado y cada salto se magnifica.

Hubo un paso intermedio (`FloatingLabel`, un `Node2D` con `_draw()`, como `SelectionIndicator`) que **sí arreglaba la vibración** y se borró igual al mover todo al HUD — donde un `Label` normal está en su sitio y el snap juega a favor. Queda como nota: si alguna vez hace falta texto de verdad en el mundo, se dibuja con `_draw()`, nunca con un `Control`.

### Si un valor se ajusta a ojo, la escena tiene que traer contra qué mirarlo
`UnitTag` empezó con dos `@export` de offset. Inservibles: se ajustaban contra el vacío, sin nada al lado con que comparar. Ahora la escena trae un `EditorGuide` —el sprite del avión al 50%, apagado en `_ready()`— y la colocación **se lee de dónde quedó el nodo**, así que el ajuste es arrastrar con el ratón y guardar. Misma treta que `MuzzleFlash`.

### La sombra de la bomba tonta, sin tocar la sombra
`MissileShadow` pide `get_distance_to_aim()` por duck-typing, así que la Mk-82 sólo tuvo que implementarlo. En la planeadora es "lo que falta para llegar al blanco"; en la tonta no hay blanco, así que es "lo que falta para quedarse sin altura" — para una sombra es lo mismo, mide caída y no puntería. No es velocidad × tiempo (la bomba frena todo el rato y la sombra tocaría suelo antes que ella): es la integral del frenado exponencial. Medido: los 7 frames repartidos parejo y el último justo al impactar.

Es prestada. **La Mk-82 necesita su propia sombra** — otra silueta, otra caída — cuando exista el arte.

### La fuente sigue sin decidirse, y el motivo importa
`ui_theme.tres` está vacío a propósito: sin fuente asignada cae en la del motor. Se probaron Boxel, Tiny5 y Pixelzone; hoy `UnitTag` usa **m5x7 a 16 px**, que es la que convence.

Lo que sí quedó aprendido: **la cobertura de glifos se comprueba antes de enamorarse de una fuente.** La Boxel se descartó tras gustarle al usuario, porque no trae **ninguna** tilde, ni Ñ, ni `¿ ¡` — medido:

```
tiene: AEIOUaeiou
le falta: ÁÉÍÓÚáéíóúÑñ¿¡
```

Sin eso no hay español, y menos aún localización. Y una segunda lección de proceso: pasé varias rondas ajustando tamaños de fuente a ciegas, sin ver nunca la pantalla. Eso se corta con una escena de prueba en el editor, que es donde el usuario puede comparar en vivo.

## 2026-08-09 (noche)

### La bomba tonta es tonta de verdad: no apunta a nada
La Mk-82 (`BallisticBomb`) se desprende con la velocidad del avión, abre el freno de cola y **cae donde la deja la inercia**. No guía, no corrige y no sabe dónde está el blanco.

Decisión de fondo: **su alcance no se configura, sale de la geometría.** No hay ningún parámetro que diga "llega a X px" — llega hasta donde la lleve su velocidad mientras dure `fall_time`. Soltarla pronto la deja corta, soltarla tarde la pasa de largo. Por eso el `max_range` del arma significa "desde dónde hay que soltarla", no un muro. Misma familia de decisión que el `fall_time` de la planeadora y el combustible del misil: el fallo sale de la simulación.

**Hermana de `GlideBomb`, no subclase suya.** Comparten el "no tiene motor, se desprende y cae", pero la planeadora manda sobre su rumbo y ésta no manda sobre nada. Unirlas con un `if` habría obligado a arrastrar guiado, espoleta de proximidad y punto de apuntado por un camino que no los usa jamás.

**La dispersión se mudó de sitio.** `WeaponType.salvo_spread` dispersa el *punto de apuntado*, y esto no apunta. Lo que varía de una bomba a otra es **cómo se desprende**: sale un pelo torcida (`wander_deg`) y frena un pelo distinto (`fall_spread`). El `aim_offset` le llega y se ignora a propósito — ignorarlo es la forma de decir en el código que una bomba tonta no tiene puntería que dispersar.

### Una andanada escalonada es un disparo que dura, no N disparos sueltos
Las 6 bombas salen una detrás de otra (`salvo_interval`). Eso chocaba de frente con dos reglas que ya estaban:

- **"No dispares mientras tengas algo tuyo en el aire"** habría bloqueado las cinco siguientes con la primera ya volando.
- **`fired` rompe el ataque.** Emitirlo con la primera pondría al avión a virar con cinco bombas colgadas, y saldrían abanicadas hacia donde ya no está el blanco.

Solución: la ristra pasa a ser un estado en curso en `WeaponSystem`, atendido antes que nada y **terminado siempre** — ni perder el permiso de tiro ni que el blanco muera la interrumpen; las bombas ya están saliendo del avión. Sólo apagar el armamento la aborta. Y `fired` se emite con la última.

**La longitud de la ristra no se configura**: sale del intervalo por la velocidad del avión. Medido (0,1 s a 115 px/s): 75 px de línea batida, las primeras cortas, las del medio encima y las últimas largas, con 6 de 6 dentro del radio de explosión y variación real entre pasadas.

### Cómo se ataca es del arma, no del avión
`WeaponType.slows_to_aim`. El cañón frena para apuntar; la Mk-82 cruza a máxima y sale de ahí. Va por el mismo canal que la envolvente (`set_envelope`) y por la misma razón: una propiedad del arma traducida a vuelo, con `AttackRunBehavior` sin saber de armas. Es el mismo reparto que ya trajo `fire_mode`.

### La convención del arte no se negocia
Monté la bomba con `sprite_offset_deg = +90` asumiendo que el sprite apuntaba hacia arriba. Volaba de culo, **con el freno desplegándose por delante** — un paracaídas en vez de un retardador. Todo el arte de este proyecto apunta a +Y y lleva −90: avión, misil, planeadora, trazadora. Cuando una pieza nueva parece necesitar otro valor, casi siempre es que se está leyendo mal el dibujo.

## 2026-08-09 (tarde)

### La pasada de ametrallamiento se compromete: enfilar y no volver a corregir
El avión "bailaba por todos lados" atacando con cañón. Tres causas distintas que se veían como una sola:

**1. Corregía el rumbo cada frame hasta el final.** `AttackRunBehavior` llamaba a `update_target(blanco)` en todo el INGRESS. Cada corrección movía el morro, el blanco entraba y salía del cono, y la ráfaga salía a tirones. Ahora, en cuanto el morro entra en `aim_tolerance_deg` **y** ya está dentro del alcance, el avión **se compromete**: el destino pasa a ser un punto 600 px pasado el blanco y no se vuelve a tocar hasta que rompe. Atraviesa el objetivo y sigue, que es lo que hace un avión ametrallando.

El punto va lejos y no sobre el blanco por el mismo motivo que el circuito de espera: puesto encima, el avión intentaría llegar exactamente ahí y acabaría dando vueltas sobre él.

**2. Disparaba mientras rompía.** El `WeaponSystem` sólo miraba distancia y ángulo, así que en cuanto el avión viraba y el morro cruzaba el blanco de refilón, salía una ráfaga. Y virando lo cruza muchas veces. **Apuntar y tener permiso para tirar son cosas distintas**: `set_cleared_to_fire()`, atado a `attack_run_started` / `attack_run_ended`. Fuera de la pasada no sale un tiro por mucho que el blanco pase por delante. Un `WeaponSystem` suelto arranca con permiso — un tanque no se lo pide a nadie —; es el avión el que se lo quita.

**3. Se alineaba dentro del alcance del arma.** Esto sólo salió midiendo. Reencaraba a 390 px, llegaba de la vuelta todavía torcido y no enfilaba hasta ~300, con la ruptura en 264: **36 px de ventana de fuego**. `turn_around_margin` sube de 3.0 a 4.5. La separación no sólo tiene que dar para girar, tiene que dar para **girar y salir apuntando**.

Medido, con el morro tomado como desvío al blanco durante la ráfaga:

| | pasada 1 | pasada 2 | pasada 3 |
|---|---|---|---|
| antes | 54 daño | 18 | 10 |
| ahora | 37.7 (±0.0°) | 34.5 (−2.7°/+0.9°) | 27.8 (−0.9°/+2.8°) |

Las tres abren fuego en el borde del alcance (~418 px) y el morro se mueve menos de 3°. De regalo, el sobrevuelo del blanco pasó de ~50 px a 220: ya no se le echa encima.

### Las trazadoras se acaban en el blanco, no cuando se les acaba el alcance
Volaban 420 px fijos. Un tiro abierto a 273 px seguía **150 px más allá del tanque**: balas prometiendo impactos imposibles muy por detrás de lo que se estaba ametrallando.

El trazo ahora recibe en `launch()` la distancia real de tiro, que le da el arma (`WeaponSystem.get_firing_distance()`). Eso además mata un duplicado que ya escocía: el alcance del cañón estaba escrito en el `.tres` **y** en `Tracer.range_px` — el mismo vicio que `attack_speed`, dos sitios para el mismo número.

Y en los últimos 90 px el trazo **se consume**: recorre al revés los mismos frames cortos con los que salió del arma. Con `reach_spread` (±12%) unas se pasan y otras se quedan cortas, que es lo que tiene que pasar en una ráfaga — sin eso la línea de fuego parece una regla. Medido: se pasan 22 px de media, 44 la peor.

### Una tira de dibujos no siempre es una animación
`Tracer_16x64.png` estaba montado como animación seguida de 8 frames a 20 fps. Son 0,35 s formándose, que a 900 px/s son **315 px de los 360**: la bala se pasaba el 87% del viaje saliendo del arma y el trazo de verdad sólo aparecía los últimos 45 px, justo antes de borrarse.

No eran 8 pasos de un ciclo: eran **dos estados**. Los frames 0–6 son la bala saliendo del cañón y el 7 es la trazadora, que hace el resto del recorrido. Separados en `muzzle` y `streak`: 105 px formándose y 315 de trazo. La lección es de proceso — cuando el arte no encaja, preguntar qué representa cada frame antes de asumir que es una secuencia.

### Pendiente reconocido: el daño es provisional
Un Harrier destruye un T-14 en tres pasadas de cañón. Es demasiado fácil para lo que debería costar, y se deja así a sabiendas. El daño se definirá en serio junto con las barras de vida y las marcas de impacto, por unidad y por arma — no ajustando el `damage` del cañón hasta que quede bien.

## 2026-08-09

### El cañón: un chorro, no un lanzador
El GAU-12 no encajaba en la maquinaria de armas, que estaba construida para disparos discretos. Tres cosas lo bloqueaban: "no vuelvas a tirar hasta que llegue lo anterior" (un cañón no tiene nada en el aire), un nodo por disparo (~60 por segundo, inviable) y romper el ataque al disparar (con el cañón te quedas encima apretando el gatillo).

**`WeaponType.fire_mode`: `LAUNCHER` o `SUSTAINED`.** Explícito y no inferido de "no tiene `projectile_scene`" — esa clase de inferencia implícita es la que nos mordió con `attack_speed`.

**`fired` pasa a significar "ya hay algo en camino, deja de acercarte", y un arma sostenida nunca lo emite.** Con eso el avión sigue metiéndose y rompe por distancia. Convertir una pasada de misil en una de ametrallamiento no costó **ni una línea** en `AttackRunBehavior`.

**El daño se cuenta en proyectiles, no en daño por segundo**, para que `damage` siga significando lo que hace UNA bala en vez de sobrecargar el campo. Cuántas entran lo dice la geometría: la distancia (de cerca la dispersión no ha tenido sitio para abrirse) y la puntería (fuera del cono, cero — se ve el fogonazo y no acierta nada). El fallo sale de la geometría y no de un dado, y la pasada importa: entrar cerca y encarado mata, hostigar de lejos hace cosquillas. **Ninguna bala existe como objeto**; las trazadoras son 12/s de puro adorno contra 60 balas/s reales.

**Histéresis en el gatillo**, igual que el compromiso de viraje del piloto: se abre con 10° y no se suelta hasta 20°. Sin eso el blanco entra y sale del cono mientras el avión corrige y la ráfaga sale a tirones. Medido: una sola apertura por pasada.

### Y el bug que sólo se vio midiendo: el avión orbitaba en vez de rehacer la pasada
Tras la primera pasada se quedaba dando vueltas a 180 px picoteando 1 a 4 de daño. Rompía a 180 y reencaraba a 297: **117 px para invertir el rumbo con un radio de giro de 130.** Llegaba torcido a cada pasada.

Es literalmente la misma lección que el suelo del circuito de espera: una distancia fija que no sabe nada del viraje del avión se rompe en cuanto el viraje cambia. `turn_around_margin` (3 radios de giro) le pone suelo al reencare. Con un arma de largo alcance no se nota — el Maverick reencara a 850 y el suelo son 390 —, así que sólo actúa donde hace falta.

Contra un tanque de 100, antes: 54, 1, 4 y seguía. Después: **54, 39, 6 y muerto**, las tres abriendo a 349–350 px bien encaradas.

### Un tercer efecto, y una base para no copiarlo
El humo y las trazadoras compartían todo salvo un punto, así que eso subió a `EffectEmitter`: engancharse por señal, encontrar el mundo, parir allí. **Lo único que heredan las subclases es cuándo toca soltar la siguiente** — el humo por distancia recorrida (para que la densidad no dependa de los fps), la ráfaga por cadencia (un cañón dispara a su ritmo aunque el avión frene). El fogonazo es un sprite y no puede heredar, pero usa la misma función de enganche, que es estática justo por eso.

`source_path` porque quien manda no siempre es de quien cuelgas: los efectos cuelgan del avión y los enciende su `WeaponSystem`. Descartado que el avión reemitiera — un salto de más para nada.

**Segundo bug, este reportado por el usuario: los trazos salían de lado.** La causa es vieja conocida: la rotación del nodo del avión **no es su rumbo**, lleva −90 de desfase porque el arte apunta a +Y. Heredarla mandaba las trazadoras perpendiculares al morro. Ahora se pregunta `get_facing()`, que es lo que ya hacía el armamento por este mismo motivo, y el arreglo vive en `EffectEmitter` para que no vuelva a pasar. Medido: con el avión a 40°, desvío de 0°.

Y un tercero por el camino: `Tracer` leía su rumbo en `_ready()`, pero entra en el árbol antes de que se le coloque — salían todos hacia +X. Ahora tiene `launch()` aparte, igual que `Projectile`: nacer y salir disparado son dos momentos distintos.

Pendiente de mirar en el editor. Y anotado: el avión sobrevuela el blanco a ~50 px en cada pasada, consecuencia directa del radio de giro 130 contra una rotura a 180. Honesto para un ametrallamiento, pero es lo contrario de lo que se buscó con las bombas.

## 2026-08-08 (3)

### Los efectos del cañón: un fogonazo de dos tiempos y un humo que ya existía
Primer trozo del cañón del Harrier. Sólo los efectos — quién abre fuego y cómo ataca el avión con cañón queda para mañana.

**El fogonazo tiene dos animaciones, no una.** La primera versión metía los 11 fotogramas en un solo bucle, y eso está mal: el arranque volvía a aparecer en cada vuelta. La tira son en realidad dos cosas — **0–5 el arma poniéndose en marcha** (una vez) y **6–10 la ráfaga sostenida** (en bucle) —, que es la misma estructura que ya tenía `MissileExhaust` con `ignite` / `burn`.

El sostenido cicla por un motivo físico: un cañón de rotación suelta cientos de proyectiles por minuto, así que el fogonazo mantenido no puede ser un destello por bala — a esa cadencia sería un parpadeo ilegible. Es una llama que titila. Pero arrancar se ve **una sola vez**: volver a enseñar ese crecimiento en mitad de la ráfaga delataría el bucle. Cortar el fuego apaga en seco incluso a mitad del arranque, porque el arma dejó de disparar y una llama creciendo sería mentira.

**El humo del cañón no llevó código nuevo.** La estela del misil ya hacía exactamente lo que hacía falta: soltar bocanadas que **se quedan en el mundo** con el rumbo congelado, que es lo que hace que el rastro se doble solo al virar. Lo único distinto entre los dos humos era el dibujo, la densidad y quién los enciende.

Así que `MissileSmokeTrail` pasó a **`SmokeTrail`** y esas tres cosas son datos del inspector: `puff_scene`, `spacing_px` y los nombres de las dos señales del padre (`start_signal` / `stop_signal`). El misil no se tocó — sus valores por defecto siguen siendo `motor_ignited` / `fuel_spent`. Un humo nuevo cuesta ahora dos ficheros de datos y cero código.

**Se descartó heredar.** `CannonSmokeTrail extends SmokeTrail` habría sido un archivo entero para no hacer más que enchufar dos señales distintas. Poner los nombres en `@export` deja una sola clase y lo mueve al sitio donde se decide de verdad: la escena.

La bocanada (`SmokePuff`) tampoco se tocó: el dibujo y la duración son de la escena, no de la clase. El humo del cañón es **10 fotogramas y 0,67 s** contra los 23 y 1,47 s del misil — medido, un rastro de **45 px** frente a ~440. Es humo de boca de arma, no una estela que marque una trayectoria.

**Los dos efectos se enganchan por señal al avión, y el avión todavía no las emite.** `cannon_firing_started` / `cannon_firing_stopped`. Si el padre no las tiene, no se conecta nada y se encienden a mano — que es como se han probado. Eso deja el "cuándo" para mañana sin bloquear nada, y cuando el avión las emita, los dos efectos y la trazadora se suman solos sin tocarse entre ellos.

Verificado en headless: el fogonazo se ve en orden `start` → `sustain` y no vuelve al arranque; el humo siembra 10 bocanadas vivas, la primera a 47 px por detrás del avión (o sea que no viaja con él), con **9° de abanico en los rumbos** estando el avión en viraje; al cortar el fuego no nacen más. Regresión del misil tras el renombrado: sigue sembrando 95 bocanadas en vuelo.

Pendiente de mirar en el editor: nada de esto se ha visto en juego todavía, sólo medido.

## 2026-08-08 (2)

### El avión deja de ser un carrito: el viraje se mide en radio y la velocidad en intención
Tres cosas que resultaron ser la misma: el avión no sabía volar como un avión porque en tres sitios distintos había números que no le pertenecían.

**El viraje se parametriza por RADIO, no por grados por segundo.** Estaba al revés: `base_turn_deg` mandaba y el radio salía de dividir, así que **volar más lento cerraba el viraje** — lo contrario de lo real. Con los valores del Harrier el radio efectivo eran **41 px** contra un sprite de 32: el avión pivotaba sobre sí mismo, y bajarle la velocidad lo empeoraba. Ahora `turn_radius` es el parámetro y la velocidad de giro sale de él (`speed / turn_radius`), que es como ya lo hacían `GuidedMissile` y `GlideBomb`. El giro pasó de 125°/s a 40°/s y el arco de 82 px a 266. `turn_inertia` bajó de 5 a 2 para que haya entrada en viraje en vez de saltar al alabeo máximo.

**Se probó y se descartó** que al bloquearse un lado del viraje el avión tomase el contrario: geométricamente correcto, pero se siente mal — el avión se abre por fuera cuando el jugador esperaba que fuese al punto. Queda como estaba: nivela y sale recto hasta que la geometría permita enfilarlo.

**El circuito de espera se rehízo entero.** Con el viraje nuevo dejó de funcionar: el avión cortaba por dentro del óvalo y acababa encerrado en un círculo de su propio radio pegado a la proa, justo en el corredor de despegue. Se midió que **ningún parámetro lo arreglaba** — `lead_deg`, `sync_rate`, `fine_gain`, `turn_inertia` y el tamaño del óvalo (hasta 500×600) no movían la aguja; sólo `turn_radius`, que funcionaba hasta 50 y se rompía de 90 en adelante. Era diseño, no ajuste.

Fuera el óvalo con fase propia. Ahora se le señala al piloto el punto del círculo que corresponde a dónde está el avión **ahora**, corrido un poco hacia adelante. Por dentro le queda hacia afuera y entra; encima, le queda delante y lo recorre. **De seis parámetros a dos** (`radius`, `clockwise`); se borraron `semi_x`, `semi_y`, `lead_deg`, `sync_rate` y `center_deadzone`. Sigue al barco gratis, porque el centro se relee cada frame.

Y lleva **suelo automático**: el circuito nunca es más apretado que 2,5 veces el viraje del avión. Ahí estaba la causa real del "dan vueltas frente al barco" — un círculo más pequeño que eso es imposible de rodear, cada punto cae dentro del propio giro. Con el suelo, tocar `turn_radius` ya no rompe nada. Medido: 0.93 con radio 130, 1.02 con radio 50, 1.01 con el barco navegando (1.00 = clavado).

**La velocidad pasó de techo numérico a interruptor.** `speed_limit` en px/s desapareció; queda `cruising` (bool), y el avión ya sabe cuáles son sus dos velocidades. **`min_speed` es el estado normal** — despegue, espera, alineación de tiro — y `max_speed` la excepción, sólo mientras hay orden que cumplir. Al revés el avión despegaba acelerando a tope para frenar acto seguido al entrar en el circuito, que es tonto.

Con eso murieron dos números que estaban donde no debían:
- **`AttackRunBehavior.attack_speed`** valía 90, exactamente la `max_speed` del Harrier. "Frenar para atacar" no frenaba nada y nadie se había enterado. Lo lento es la `min_speed` del propio avión; no hace falta configurarlo.
- **`FlightDeck.takeoff_speed`** valía 120 contra un avión que vuela a 90 como mucho: el piloto lo recortaba en silencio y la animación de pista estaba cronometrada con una velocidad imposible. Ahora la cubierta pregunta (`Unit.get_takeoff_speed()`), acelera por la pista desde parado hasta ahí y lo suelta a esa velocidad exacta — que es la misma del circuito, así que despegue y espera son un movimiento continuo sin acelerón ni frenada. De paso, cada avión despega según su propio inspector sin tocar la cubierta.

El ease-in cuadrático que ya tenía la pista **era** una aceleración constante bien hecha: el factor 2 que parecía arbitrario es lo que hace llegar a proa exactamente a la velocidad pedida. Sólo estaba alimentado con el número equivocado.

Verificado en headless el ciclo entero: soltado de cubierta a mínima, espera a mínima, gas al recibir orden, suelta al llegar, gas al atacar, suelta al entrar en la envolvente para alinearse, gas al romper. La rampa completa mínima→máxima midió **2,73 s contra 2,75 teóricos** — 1 % de desvío, o sea que `acceleration` manda la transición entera y nadie salta la velocidad a mano.

**Dos límites conocidos, anotados en `architecture.md`:** con `turn_radius` 130 el circuito mide 660 px de diámetro, más ancho que la pantalla — consecuencia directa del radio de giro elegido. Y si el barco navega a más de ~1/3 de la velocidad máxima del avión, el avión no mantiene el circuito.

La regla que sale de las tres: **a un actuador se le pide la intención, no el número**. Un valor absoluto en otro script duplica algo que no le pertenece y se desincroniza en silencio en cuanto se toca el original.

## 2026-08-08 (1)

### GBU-54: el alcance es altura, no empuje
Bomba planeadora guiada. **Hermana de `GuidedMissile`, no hija**: una bomba no tiene fases de motor que heredar, y no lleva ni fuego ni estela — se suelta y cae en silencio.

El problema de diseño era cómo simular que se tira de lejos sin que el avión tenga que sobrevolar el blanco, que sería absurdo. La respuesta es que el alcance no venga de un motor sino de la **altura**: `fall_time` (5,5 s) es la altura de la bomba, y lo que recorra picando durante ese rato es hasta dónde llega. Hereda la velocidad del avión al soltarse y va **ganando** velocidad al picar, lo contrario del misil.

**Dos finales y sólo dos:** llegó al blanco, o se le acabó la caída y aterriza donde esté. El segundo es lo que le da sentido al `max_range`: no es una regla ni un muro, es hasta dónde llega. Medido desde parado (el peor caso), el límite físico son 1018 px; con `max_range` en 900 hay margen, y a 1100 cae 82 px corta — fuera del radio de explosión, fallo limpio. El fallo sale de la simulación, no de un dado.

Se detectó al escribirla un doble reparto de daño: el planeo llamaba a `detonate()` y `_physics_process` volvía a llamarlo el mismo frame al agotarse `fall_time`. Los dos finales salen ahora del mismo `if`.

Verificado en headless con el ciclo completo del Harrier: suelta a 898 px, nunca se acerca a menos de 782 (`min_range` 350, así que no sobrevuela nada), gasta una sola por pasada y mata.

## 2026-08-07 (3)

### El parte de guerra, y una columna que se mide sola
El registro de eventos existía como cuadro vacío: `add_event(text)` y nadie que lo llamara. Ahora cuenta órdenes, ataques, disparos y bajas.

**Se engancha él solo a cada unidad por el grupo**, como el mapa con sus puntos: nadie tiene que avisarle de quién nace o muere. El repaso inicial va **diferido**, y ahí hubo un fallo que sólo apareció probando: en `_ready()` sólo existen las unidades que van *antes* que el HUD en la escena, y `node_added` tampoco coge a las demás porque ya estaban en el árbol al conectarse. Resultado: el LHD se registraba y los cuatro T-14 no. Difiriendo el repaso al final del frame, todos.

**El código de brevedad OTAN va en el arma, no en una tabla del registro.** `WeaponType.brevity_code`: AGM-65 *Rifle*, AIM-9 *Fox Two*, AIM-120 *Fox Three*, GAU-12 *Guns*, bombas *Pickle*. Es parte de lo que el arma es, así que un arma nueva lo trae puesto y nadie tiene que acordarse de añadirla a una lista aparte.

**Las coordenadas son pulsables y llevan el punto exacto del mundo, no la letra.** La zona es para leerla; la cámara va a donde pasó la cosa. Cada línea es un `RichTextLabel` con BBCode — con `Label` no había forma de hacer pulsable un trozo de texto.

Segundo fallo salido de la prueba: el parte leía las coordenadas del **minimapa**, donde las zonas se agrupan hasta caber en 87 px. Todo el mapa eran dos coordenadas y todo salía como `A1`. Ahora las lee del mapa táctico, que es la rejilla que el jugador ve.

**El minimapa se recorta a su dibujo, no al revés.** Tenía un marco negro alrededor del terreno, y la causa es estructural: la escala es entera, así que un dibujo de 64×45 nunca llena un panel de 87×87. En vez de encajar el dibujo en el panel, el panel se recorta al dibujo.

**Y se estira: arrastrando su borde de arriba, elige escala, no píxeles.** El alto que pide el ratón se traduce a la escala entera que quepa, y el panel se pone del tamaño exacto del dibujo a esa escala — salta 1x → 2x → 3x sin franjas negras. Dos cosas que costaron un intento: estirar sólo a lo alto no hacía nada, porque el ancho también manda sobre la escala (crecen los dos); y el alto pedido hay que guardarlo aparte del real, o el arrastre se atasca en el escalón en vez de seguir al ratón.

**El registro se aparta solo.** Los dos viven en la misma columna y el minimapa crece justo hacia donde está el parte, así que el HUD lo recoloca al oír `resized`. Para que eso funcione, el minimapa asigna **la posición antes que el tamaño**: cambiar el tamaño es lo que dispara el aviso, y al revés el HUD leería el sitio viejo. El parte además se mide por su contenido y crece hacia arriba con el borde de abajo quieto, como una consola; vacío no se dibuja, que un recuadro negro sin nada dentro ocupa sitio y no dice nada.

Tercer fallo de la prueba: una sola línea pedía **308 px de alto**. `RichTextLabel` con `fit_content` calcula su alto mínimo suponiendo ancho cero si no se lo dices; hay que fijarle `custom_minimum_size.x` a mano.

Verificado en headless: las cinco clases de línea con las unidades reales (`LHD Wasp → F4`, `LHD Wasp ataca T-14 Armata B2`, `LHD Wasp: AGM-65 (Rifle!)`, `Splash! T-14 Armata B2`); pulsar `D1` lleva la cámara a (997,3) y suelta el seguimiento; el minimapa sin sobrante a ninguna escala y con el borde inferior clavado en 379; y minimapa y registro sin solaparse ni estirando a 3x.

## 2026-08-07 (2)

### Una rejilla que se lee, y un gesto que se reconoce en un solo sitio
La cuadrícula del mapa táctico se veía rayada. La causa: había **dos** rejillas encima del terreno, y la fina dibujaba una línea por celda de terreno — 64×45 = casi 2900 cuadritos de 7 px.

**Se quitó entera.** El tamaño del tile es un detalle de implementación: no le dice nada al jugador, y a esa densidad no se lee como cuadrícula sino como rayado. Queda sólo la rejilla de zonas, que es la que lleva coordenada. Miradas otras soluciones antes de decidir: las cartas náuticas (Silent Hunter, Sea Power, Command) usan **una sola rejilla con pocas divisiones** y subdividen sólo con zoom; los wargames de sectores (Wargame, Steel Division) usan regiones translúcidas con nombre; el RTS clásico (C&C, StarCraft) no dibuja rejilla ninguna. Se eligió el modelo de carta náutica porque es el que da coordenadas automáticas para el registro de eventos sin bautizar nada a mano en cada mapa.

**Las zonas pasaron de 4 a 8 celdas: 8×6 zonas, A1…H6** en vez de 16×12.

**Y `zone_cells` dejó de ser una orden para ser una petición.** El mapa va a crecer, así que un número fijo de celdas por zona volvería a llenar la pantalla de rayas el día que se cargue un mapa mayor, y habría que ir retocando el exportado misión por misión. Ahora la vista **agrupa las zonas de dos en dos** hasta que una mide al menos 24 px en pantalla. La regla que queda, hermana de la de la escala: **exportar la intención, calcular el resultado**. Se añadió `zone_label_at()` para que el registro de eventos pregunte la coordenada con el tamaño que se está dibujando de verdad y no puedan divergir el texto y el dibujo.

**La pulsación mantenida salió de `PanCamera` a `LongPress`.** Faltaba en el mapa —en móvil no había forma de abrir el menú de una unidad desde ahí— y el detector estaba enredado con el estado del paneo de la cámara. Copiarlo era lo rápido; en su lugar se sacó a `core/input/long_press.gd`, que **no conoce eventos ni nodos**: se le cuenta lo que pasa y contesta qué significa. Por eso lo usan igual la cámara (coordenadas de pantalla, `_unhandled_input`) y la vista del mapa (locales, `_gui_input`), y el gesto se reconoce con el mismo tiempo y el mismo umbral en los dos sitios.

De ahí salió un cambio que no estaba previsto y que era correcto: **el click izquierdo en el mapa se cuenta al soltar, no al pulsar.** Hasta que el dedo no se levanta no se sabe si era un click o el principio de una mantenida. De regalo, arrastrar sobre el mapa ya no dispara una orden.

Verificado en headless por el camino real del input: zona de 56 px con 8×6 zonas `A1…H6` (LHD en `G5`, T-14 en `B2`); la mantenida sobre el punto del T-14 abre su menú a los 0,504 s **sin soltar**, y soltar después no da orden; el click corto sigue ordenando; arrastrar no ordena; y el paneo de la cámara sigue funcionando tras el refactor.

## 2026-08-07

### El mapa táctico no es otro modo de juego, es la misma partida vista de lejos
Se puede mandar desde el mapa: dirigir a la unidad seleccionada, atacar pulsando el punto de un enemigo y abrir su menú con el botón derecho.

**El significado del gesto se sacó a una función compartida.** `_handle_click` y `_handle_context` reciben ya resuelto qué hay debajo; el mundo lo averigua con una consulta de física y el mapa preguntándole a `MapView`. Escribir la lógica dos veces era lo cómodo y lo que garantiza que dentro de un mes el mapa y el mundo hagan cosas distintas sin que nadie se dé cuenta. La regla que queda: **una vista nueva no inventa gestos nuevos**; si los necesita, el problema es la vista.

**Lo que hay bajo el click lo resuelve el mapa contra sus propios puntos, no contra el mundo.** A 7 px por celda, un píxel son ~4,5 px de mundo, así que una consulta de física en el punto pulsado no acertaría a una unidad nunca. Lo que el jugador apunta es el punto que ve, no la unidad de tamaño real que hay detrás: gana el punto más cercano, con 3 px de margen alrededor porque un cuadrito de 4 px no se acierta ni con ratón.

**Pulsar no cierra el mapa.** Lo hice al revés primero —cerrar como parte del gesto, "se decide y estorba"— y era incómodo: das una orden y pierdes de vista el mapa justo cuando quieres comprobar a dónde va. Ahora sólo cierran la tecla `M` y un botón `×`, que además es la única salida en móvil, donde no hay teclado. Como el marcador de destino del mundo no se ve con el mapa abierto, **se dibuja también dentro del mapa** (y del minimapa).

**El recuadro de cámara y la unidad seleccionada son excluyentes.** Con una unidad seleccionada la cámara la sigue, así que el recuadro de pantalla se convertía en un cuadro enorme persiguiéndola por todo el mapa. Habiendo selección se resalta **su** punto y se calla el recuadro; sin selección vuelve el recuadro. Sólo en el táctico: al minimapa no se le pasa la selección y ahí el recuadro sigue siendo lo útil.

**Tocar el mapa suelta el `follow_target`.** Esto era gratis antes sin saberlo: todos los clicks pasaban por `_look_at()`, que ya lo soltaba. Al dejar de pasar por ahí, la cámara se quedó pegada a la unidad y el recuadro se fue de paseo. Se soltó explícitamente, que es donde debía estar desde el principio.

**El mapa se acomodó, no se puso encima.** Al ver la barra de armas por delante del terreno moví el mapa al final del `CanvasLayer` para que tapara el HUD entero — y con ello dejé sin acceso el hangar y la lista de desplegadas. La corrección: el orden vuelve a estar como estaba y **el área de dibujo del mapa esquiva a los paneles** (empieza en `y=26`, acaba en `x=486`), con lo que no se solapa nada y la escala sigue en 7 px por celda. Lo único que se esconde con el mapa abierto es la barra de armas, que cae justo sobre el terreno y ahí no se dispara nada.

Verificado en headless metiendo los eventos por el viewport, no llamando a los manejadores: `M` abre; click izquierdo en terreno deja el mapa abierto, planta el destino en los dos mapas y suelta la cámara (`follow_target` de `LHD_WASP` a `null`); click derecho sobre el punto del T-14 abre su menú colocado sobre ese punto; click izquierdo sobre él deja `attack_target = T-14`; el botón `×` y `M` cierran. Y que ninguno de los cinco paneles del HUD cruza el rectángulo del terreno.

Queda pendiente la **pulsación mantenida** en el mapa: en móvil no hay forma de abrir el menú contextual desde ahí. El detector vive en `PanCamera` y lo suyo es sacarlo a un sitio común en vez de duplicarlo.

## 2026-08-06 (4)

### Un bando nuevo se añade por el final, y el neutral no es enemigo de nadie
Puntos de unidad en el minimapa y en el mapa táctico, del color de su bando. Los colores ya existían en `Team` desde antes —azul `#8fd3ff` el jugador, verde `#a8ca58` los aliados, rojo `#e83b3b` los enemigos—, así que lo único que faltaba de verdad era el neutral.

**`NEUTRAL` va al final del enum, no en su sitio "lógico".** `Unit.team` es exportado y se guarda como número en las escenas: meterlo entre `ALLY` y `ENEMY` habría renumerado `ENEMY` y convertido en otra cosa a todos los T-14 ya colocados en `main.tscn`. Comprobado tras el cambio que siguen siendo enemigos.

**El neutral obligó a cambiar `are_hostile()`, que es lógica de combate.** La regla era "hostiles si exactamente uno de los dos es enemigo". Con un cuarto bando eso convertía al neutral en **enemigo del enemigo**, que es justo lo contrario de lo que significa. Ahora con un neutral no se mete nadie. La excepción va en `Team` y no en quien pregunta, que es lo que el propio archivo ya decía que había que hacer.

**Los puntos salen del grupo de unidades, preguntando al dibujar.** Ni lista propia ni suscripción a `died`: el mapa no se entera de quién nace ni de quién muere, y no hay nada que se pueda quedar desincronizado. Probado añadiendo una unidad neutral en caliente — aparece sin avisar a nadie.

**El punto mide lo mismo en pantalla en los dos mapas, no a escala del terreno.** Es un icono: a 1 px por celda un punto a escala sería invisible, y a 8 px una mancha. Lleva un filo oscuro de 1 px que **no es decoración** — el azul del jugador (`#8fd3ff`) y el del agua (`#4d9be6`) se parecen demasiado, y un punto de 2 px sin borde se pierde en el mar. Una unidad que se salga del mapa no se pinta pegada al borde: se metería encima de las coordenadas y mentiría sobre dónde está.

Con unidades el mapa se redibuja cada frame en vez de sólo cuando se mueve la cámara. Son unos pocos rectángulos y un mapa oculto no se dibuja, así que no se complicó con detección de cambios.

Verificado en headless: los cuatro bandos con sus colores y `NEUTRAL = 3`; hostilidad jugador↔enemigo `true`, jugador↔aliado `false`, neutral↔jugador y neutral↔enemigo `false`; las 5 unidades del mapa en su píxel y su zona correctos (el LHD en `N10`, los T-14 en `C4`, `E3`, `F2` y `H2`).

## 2026-08-06 (3)

### El mapa no sabe cuánto mide el mapa
Minimapa y mapa táctico. Cuatro archivos en `ui/hud/minimap/` y **un solo dibujo**: el de la esquina y el de pantalla completa son el mismo `MapView` con distintos ajustes, sobre la misma imagen a distinta escala. Por ahora sólo terreno, sin unidades.

**Nada guarda el tamaño del mapa.** Es la decisión de la que cuelga todo lo demás. Los mapas van a variar por misión, así que cualquier constante con el tamaño se queda vieja el día que se cargue otro. El tamaño se le pregunta al `TileMapLayer` (`get_used_rect()`), que es de donde ya lo sacaba `PanCamera` para sus límites. Una sola verdad, y el minimapa de una misión nueva funciona sin tocar nada.

**La escala se calcula: el mayor entero de píxeles por celda que quepa.** Con el mapa actual sale 1 px/celda en el panel de 87 (imagen de 64×45) y 8 px/celda a pantalla completa (512×360). Si un mapa fuera tan grande que no cabe ni a 1, **se reduce el dato y no el dibujo**: cada píxel de la imagen resume un bloque de celdas y se sigue dibujando a escala 1. Nunca hay escala fraccionaria, que con filtro Nearest es exactamente lo que hierve al mover la cámara — el mismo motivo por el que `PanCamera` sólo admite potencias de dos.

**El terreno sale de un dato del tile, no del color del dibujo.** Se añadió al TileSet una capa de datos `tipo` (`agua`, `tierra`, `arena`) marcada **una vez por tile en el atlas**, no por celda pintada: son 101 tiles contra 2880 celdas. Llegué a proponer deducirlo del color dominante de cada tile, que funciona y no exige marcar nada; el usuario lo rechazó y tenía razón — pinta bien pero no *sabe* nada, y el día que haga falta "¿puede pasar un tanque por aquí?" el color no lo contesta. El color se usó sólo como **borrador** para rellenar los 101 tiles de una pasada en vez de a mano.

De paso apareció que el atajo que había ofrecido como parche —clasificar por `source_id`— **habría salido mal**: el tileset `sand2` contiene tiles de agua *y* de arena mezclados, y los dos de agua son el 95 % del mapa.

**Las coordenadas no pueden ir en la rejilla de 32 px.** Son 2880 celdas: ni caben etiquetas (a 8 px por celda no entra una letra) ni sirve de nada un nombre por celda. Van por **zonas de 4×4 celdas** → 16 × 12 = A1…P12, rotuladas **fuera del mapa** y repetidas en los dos bordes, para no seguir una fila con el dedo hasta el otro extremo. La rejilla de 32 px se queda como líneas finas sin rotular, y **se apaga sola** por debajo de 4 px por celda: más juntas no se leen como cuadrícula, se leen como suciedad. El tamaño de zona queda como exportado (`zone_cells`) porque es de verlo en pantalla, no de decidirlo en una tabla.

**El origen del mapa no es (0,0)** — hoy arranca en la fila −6. Las coordenadas cuentan desde la primera celda usada; contarlas desde el cero del mundo habría desplazado todas las etiquetas sin que se notase.

**El recuadro de lo que se ve en pantalla sale de la transformación del lienzo, no de la cámara.** Es una propiedad de lo que hay en pantalla, no de un nodo concreto, así que el mapa lo dibuja sin conocer a nadie. Para *mover* la cámara sí se emite señal y la mueve `SelectionManager`, como el zoom: el HUD no manda sobre la cámara.

**Pulsar el mapa grande lleva la mirada allí y lo cierra**, soltando el `follow_target` (si no, la cámara volvería a la unidad al frame siguiente y parecería roto). El minimapa **no navega**: a 1 px por celda no tiene sentido apuntar a un sitio, así que entero es un botón que abre el grande. El mapa táctico tapa la pantalla y se come los clicks a propósito, para que una pulsación no se cuele hasta el mundo y dé una orden sin querer. En pausa funciona sin hacer nada, porque cuelga del HUD.

Verificado en headless: imagen de 64×45 con 2749 agua / 97 tierra / 34 arena —cuadra celda a celda con el tileset—, 16×12 zonas con las 192 devolviendo su propia etiqueta, letras `A`/`Z`/`AA`/`AB`/`AZ`/`BA`, esquinas `A1` y `P12`, ida y vuelta click↔mundo con error 0,000 px, la cadena completa minimapa → abre → click → cámara → cierra, y la `M` abriendo y cerrando **también con la partida pausada**.

## 2026-08-06 (2)

### La sombra no cuenta el tiempo, mide la distancia
Sombra del AGM-65, con arte del usuario (112×16 = 7 frames de 16×16: una barra de 2 px a alfa 39 % que se desliza de la columna 14 a la 8 y crece de 7 a 10 px de alto). `MissileShadow` cuelga del misil como hijo, así que viaja y rota con él — al revés que la estela, que se queda atrás.

**Los 7 frames no se reproducen: son una escala de altura.** El frame se asigna a mano cada `_physics_process` a partir de `get_distance_to_aim()`. La razón no es estética: el misil lleva **espoleta de proximidad**, o sea que no sabe cuándo va a explotar, y «reproduce esto los últimos 0,3 s» es literalmente imposible de programar. La distancia sí la sabe siempre, y atándolo a ella la sombra se junta con el misil justo en el impacto venga a la velocidad que venga y desde donde venga. Mismo razonamiento que sembrar la estela por distancia recorrida en vez de con temporizador.

**El suelo está a 12 px, no a cero.** El misil detona por proximidad sin llegar a tocar nada. Contando hasta cero, el último frame —la sombra pegada al misil, que es el remate del efecto— no se vería nunca. Salió en la prueba headless: a 12 px el frame era el 5.

**Un getter público en vez de una señal.** `guided_missile.gd` sólo creció en `get_distance_to_aim()`. Las señales sirven para *que pase algo*; aquí el efecto depende de *cuánto vale algo*, que hay que leer cada frame. Se pide por duck-typing (`has_method`), igual que el fuego y el humo piden sus señales: si no está, la sombra se apaga sola.

**La diagonal la pone el nodo, no el dibujo.** El arte traía el alejamiento sólo en horizontal. Con el sol al noroeste, a más altura la sombra tiene que irse abajo *y* a la derecha; la componente vertical faltaba porque **no cabía en el tile** —el cuerpo del misil llega a la fila 13 y sólo quedan dos libres—. Se añade como `position.y` (`altitude_drop_px`, 5 px), que no está atado a los 16 px, y **se encoge con la misma cuenta que el dibujo**: fija, al impactar la sombra quedaría 5 px por debajo del misil.

**Se asume que la sombra rota con el objeto, sabiendo que es incorrecto.** Decisión del usuario, extendida a convención del proyecto: el arte se dibuja mirando al sur con la sombra abajo a la derecha, y al rotar la sombra rota también, así que el sol acaba siguiendo a cada objeto (se ve en el LHD, girado en la escena). Lo correcto sería separar forma —silueta, rota— de desplazamiento —lo decide el sol, fijo en el mundo—, que no necesita iluminación del motor, sólo un vector constante. Se descarta porque exige redibujar centrado todo el arte de sombras existente. Anotado en `architecture.md` para que, si se cambia algún día, se cambie para todo a la vez.

Verificado en headless: 7 frames, el nodo `Shadow` en la escena a `z_index = -2` (bajo el humo y el misil), y el barrido de distancias da 400 px → frame 0 con 5,00 de caída, 60 px → frame 3 con 2,22, y 12 px → frame 6 con 0,00. Con un padre que no expone el getter, el nodo se apaga y no revienta.

Pendiente de arte, decidido con el usuario: redibujarla **ovalada y de 3 px de ancho**. Hoy mide exactamente lo mismo que el cuerpo del misil (2 px), así que en los dos últimos frames se funden y parece que el misil engordó en vez de que la sombra llegó.

## 2026-08-06

### La cola plana se arregló donde estaba el problema: en el dibujo
El usuario redibujó la fase de disipación del humo. La tira pasa de 288×16 (18 frames, uno vacío) a **368×16 = 23 frames**, todos en uso. Los frames 0–8 —la bocanada formándose— están intactos, así que el píxel de nacimiento sigue en (7,14) y el nodo `SmokeTrail` no se movió de (0,−12). Lo nuevo son los **14 frames de disipación** (9–22) donde antes había 8: ahora **se abren** hasta ocupar el tile entero (de 6 a 16 columnas) y **se desvanecen por alfa** (100 → 70 → 55 → 39 → 22 → 11 %), en vez de encoger hasta un píxel sólido.

**Con arte de verdad, las duraciones vuelven casi a plano.** Ya no hay que inventar la disipación estirando: frames 0–8 a `1,0` (24 fps limpios) y 9–22 con una rampa suave de `1,5` a `2,6`. 35,2 unidades / 24 fps = 1,467 s → **440 px de estela y ~110 bocanadas vivas**, prácticamente el mismo largo que antes. Lo que cambia es el reparto: **la banda más larga baja de 62 px a 32 px**, y cae en los frames al 22 % y 11 % de alfa, donde apenas se ve. Ahí estaba la cola plana. El parche descartado en su día —±15 % de velocidad por bocanada— sigue sin hacer falta.

**Queda una reserva, y es de reparto, no de dibujo.** Los frames opacos (0–17) se llevan 301 px y el fade (18–22) los otros 139: la estela empieza a desvanecerse a un tercio del recorrido, así que se lee más como algo que se disuelve que como un rastro. Se deja así a propósito. Alargar la fase opaca sólo con duraciones devolvería las bandas; el camino bueno es dibujar 3 o 4 pasos opacos más (y más de 5 de alfa, para que el final no sea un corte). Y hay un límite duro que conviene tener presente: con 2,5 s de combustible el misil vuela ~700 px, así que una cola mucho más larga cubriría el recorrido entero y dejaría de verse disolver mientras vuela.

Verificado en headless: 23 frames, `loop = false`, espaciado real 4,000 exacto de mínimo a máximo sobre una curva de 90°, ~110 bocanadas simultáneas, y el emisor se apaga en `fuel_spent`.

## 2026-08-05

### La estela no es una animación: es un rastro de piezas que ya salieron
Humo del AGM-65, con arte del usuario (tira de 288×16 = 18 frames de 16×16, el último vacío y descartado). No es una cola que se deforme: `MissileSmokeTrail` cuelga de la tobera y va **soltando bocanadas sueltas por el mundo**, cada una con la rotación que llevaba el misil en ese instante. La curva sale sola — no hay geometría que doblar, hay piezas que ya salieron apuntando a donde el misil iba entonces. `guided_missile.gd` no se tocó: mismo enganche que el fuego (`motor_ignited` / `fuel_spent`, por duck-typing).

**Las bocanadas cuelgan del mundo, no del misil.** Es la decisión que hace que esto sea una estela y no un adorno: hijas del misil viajarían *con* él, que es exactamente lo contrario. Nacen como hermanas suyas, en el nodo donde `WeaponSystem` ya suelta los proyectiles, y por eso **sobreviven al impacto**: el misil explota y la cola que dejó sigue deshaciéndose sola.

**Se siembra por distancia recorrida, no por tiempo.** `spacing_px` (4 px). Con un temporizador el espaciado quedaría atado a la velocidad: estela rala en la aceleración inicial y apelmazada al frenar sin combustible, y encima cambiaría si algún día cambian los fps de física. Por distancia es uniforme siempre y el número significa algo que se puede mirar en el arte. **Además se siembra a lo largo del tramo, no en el punto actual**: a velocidad de crucero el misil avanza 5 px por frame, así que una bocanada por frame dejaría la cola a trozos; se interpolan posición y rumbo dentro del segmento recorrido.

**El largo de la cola no se alarga bajando los fps, se alarga por frame.** La primera versión duraba 0,71 s (210 px) y se veía corta. Bajar `speed` a la mitad habría alargado igual, pero también habría vuelto a 12 fps el nacimiento de la bocanada, que es donde el dibujo cambia mucho de un frame al siguiente y donde un salto se ve. En su lugar se usaron duraciones por frame: los 9 primeros a 24 fps limpios, los 8 últimos alargándose de 1,5× a 5×. Vida 1,458 s → **438 px de estela y ~109 bocanadas vivas** a la vez.

**Contra la repetición: espejo y desfase.** Todas las bocanadas son el mismo dibujo saliendo cada 4 px exactos, y eso se lee como un sello repetido. `flip_h` al azar duplica los dibujos gratis (y mueve el píxel de nacimiento de la columna 7 a la 8, las dos cola del misil, así que sigue anclada). El desfase tiene dos partes: un frame entero opcional (`start_jitter_frames`) que cambia el dibujo, y **siempre uno de menos de un frame**, que no cambia nada visible al nacer pero descoloca *cuándo* cada una salta al siguiente frame. Sin esa segunda parte seguirían escalonando a la vez, que era lo que se notaba: a velocidad de crucero cada frame dura tres bocanadas, y se veían bandas de tres iguales avanzando en bloque.

**Limitación conocida: la cola se ve plana al final.** *(Resuelta el 2026-08-06 redibujando el arte — ver la entrada de arriba. Se deja el diagnóstico porque explica por qué se resolvió así.)* Es el precio de haber alargado estirando duraciones. Los 8 frames finales se llevan **26 de las 35 unidades de vida — ~325 px de los 438 son dibujo congelado**; el frame 16 dura 0,208 s, y en ese rato nacen ~16 bocanadas que enseñan el mismo píxel en fila. El desfase no lo arregla porque es **fijo**: donde cada frame dura 1 unidad lo cambia todo, y donde dura 5 sólo despeina el borde de la racha. De ahí que varíe la cabeza y no la cola. Segundo síntoma del mismo origen: todas mueren a los 438 px exactos, así que la estela termina en corte recto.

**Se deja así a propósito, porque el arreglo es de arte.** El diagnóstico real: **el arte no tiene fase de disipación** —el alfa es 100 % en los 17 frames, y lo que parece un desvanecido es perder píxeles hasta quedar uno solo, sólido— y esa fase se inventó estirando. Los frames 9–16 *encogen*, cuando una estela real se abre en cono: el humo no pasa de 6 columnas de ancho en toda su vida, ni en el pico. El usuario los va a redibujar más anchos, más rotos y con rampa de alfa; con frames de verdad hay largo *y* variedad, y las duraciones pueden volver casi a plano. Los parches disponibles mientras tanto —dar a cada bocanada una velocidad ±15 % para que la divergencia crezca con la edad— se descartaron por ahora: arreglan el síntoma en la zona equivocada del problema.

**Se descartó `GPUParticles2D`.** Sabe animar tiras, pero el espaciado por distancia y la rotación congelada por partícula se pelean con el sistema, y ~109 `Node2D` con sprite no justifican pagar ese control. Un `Line2D` tampoco: sería una cinta que hay que deformar, justo el problema que la estela por piezas no tiene.

Verificado en headless: 100 px de vuelo recto dan 25 bocanadas con espaciado 4,000 exacto de mínimo a máximo; virando 90° el rumbo de las nuevas va de 3° a 88°; tras `fuel_spent` no nace ninguna más; al liberar el misil las 54 vivas siguen ahí; cada una se borra sola al acabar su animación; y la primera sale de la tobera —(0,−12), su píxel de nacimiento sobre el último de la cola— y no del centro del misil. Confirmado por el usuario en el editor, con la reserva de la cola plana anotada arriba.

## 2026-08-04 (4)

### Pausa: qué sigue vivo lo declara cada escena, no una lista en el código
Un solo botón que alterna `get_tree().paused`, en el borde derecho bajo los de zoom, con la barra espaciadora como atajo (`shortcut_key`, exportado, `KEY_NONE` lo desactiva).

**El botón enseña la acción disponible, no el estado.** Corriendo se ve `||` (púlsame para pausar) y pausado se ve `>`. Es lo que hace cualquier reproductor; enseñar el estado obliga a traducir mentalmente cuál de los dos símbolos significa qué. Como refuerzo, pausado se pinta en color de acento: con todo congelado no queda nada en pantalla que delate el estado.

**Lo que sigue funcionando en pausa se declara con `process_mode = Always` en cada escena** —`hud.tscn`, `pan_camera.tscn`, `selection_manager.tscn`— y no con una lista de excepciones dentro del botón. Así se ve en el inspector de cada nodo, y una escena nueva decide por sí misma sin que nadie tenga que acordarse de añadirla a ningún sitio.

**Se puede panear, cambiar el zoom y seleccionar con la partida congelada, a propósito.** Una pausa que además congela la cámara sólo sirve para irse a por un café; ésta sirve para *mirar* — que es justo lo que hace falta con el bug de las pasadas de ataque, donde la maniobra ocupa más que la pantalla. **La selección era lo que más podía romperse**: hace una consulta al servidor de física, que en pausa no se está simulando. Se comprobó explícitamente y responde.

**Sin cableado con nadie.** `paused` es estado del árbol, no de otro nodo: no hay a quién pedírselo ni a quién avisar, así que el botón lo toca directo en vez de pasar por `HUD` → `SelectionManager` como hace el zoom. Queda una señal `pause_toggled` sin oyentes, para un aviso en el registro o un velo el día que se quieran.

**Consecuencia aceptada:** el hangar también responde en pausa. Desplegar con la partida congelada acepta la orden pero el ciclo de cubierta no arranca hasta reanudar, porque `FlightDeck` sí es pausable. No se bloqueó: el caso raro no justifica una excepción.

Verificado en headless sobre `main.tscn`: botón y espacio alternan y el símbolo cambia; con un Harrier en vuelo real, corriendo avanza 44 px en 20 frames de física y pausado se mueve 0,000; el zoom responde y el mapa se panea con todo parado; se puede seleccionar una unidad en pausa; y al reanudar el avión sigue desde donde estaba. Confirmado por el usuario en el editor.

## 2026-08-04 (3)

### Zoom: tres niveles fijos en potencias de dos, y el mapa táctico se queda con el resto
Tres niveles —0,5x, 1x y 2x— con dos botones de 14×14 en el borde derecho, bajo el panel de desplegadas. El de en medio es el de siempre; 2x para mirar una unidad de cerca y 0,5x para leer la zona a su alrededor.

**Potencias de dos, y no una escala continua ni un 0,75.** Con filtro Nearest, un factor de 0,5 descarta exactamente uno de cada dos píxeles del mundo; cualquier factor intermedio descarta un patrón irregular que hierve en cuanto la cámara se mueve. Es la misma regla que ya gobierna la ventana ("escala entera siempre, nunca 1.5x"), aplicada dentro del juego. Por lo mismo **el cambio es instantáneo y no interpolado**: una transición suave pasaría medio segundo por zooms fraccionarios, que es justo lo que se está evitando.

**Alejarse se corta en 0,5x a propósito.** El mapa mide 2048×1440 y a 0,5x se ven 1280×768: la zona de la unidad, no el teatro entero. Ver todo el mapa es trabajo del mapa táctico, que es otra pantalla y otro problema — si el zoom llegara hasta ahí, el mapa táctico no tendría razón de existir.

**Niveles como dato (`zoom_levels`, `PackedFloat32Array` exportado), no como enum.** Añadir un cuarto nivel o mover el de arranque es tocar el inspector. La cámara sólo garantiza dos cosas de código: que no se sale del array y que **no da la vuelta** al llegar al extremo — un botón de acercar que alejase del todo sería una trampa.

**Los botones no saben qué zoom hay puesto.** Reciben "estás en el nivel N de M" y con eso apagan el que ya no lleva a ninguna parte. Es el mismo criterio que `WeaponBar` con las armas agotadas: se distingue de un vistazo "puedes" de "no puedes", y la fuente de verdad sigue siendo un solo sitio.

**El cableado pasa por `SelectionManager`, no por el HUD.** El HUD no conoce la cámara y no va a empezar ahora: reenvía `zoom_change_requested(step)` y recibe `set_zoom_state(level, count)`. `SelectionManager` ya era el corredor entre los dos. Detalle que costó un `if`: la cámara fija su nivel en su propio `_ready()`, antes de que nadie esté conectado, así que el estado inicial de los botones hay que pedirlo a mano — conectarse a la señal no basta cuando la señal ya sonó.

Verificado en headless sobre `main.tscn`: los tres niveles con sus topes sin dar la vuelta; el arrastre de cámara sigue cuadrando exacto (64 px de pantalla mueven 128/64/32 px de mundo según el zoom); lo que el HUD coloca sobre el mundo —cuenta atrás, menú de objetivo— sigue centrado en los tres niveles; y cerca del borde del mapa la cámara topa con sus límites sin sacar nada de pantalla. Eso último **no es un fallo y se dejó así**: el zoom no puede enseñar más allá del mapa, así que una unidad en la esquina deja de estar centrada. Confirmado por el usuario en el editor.

## 2026-08-04 (2)

### El efecto escucha a la simulación; la simulación no sabe que hay efecto
Primer arte de efectos: el fuego del propulsor del AGM-65, animación del usuario (tira de 320×16 = 20 frames de 16×16). `MissileExhaust` es un `AnimatedSprite2D` hijo del misil que se conecta **solo** a `motor_ignited` / `fuel_spent` en su `_ready()`, por duck-typing (`has_signal`). `GuidedMissile` no se tocó ni una línea: las dos señales ya estaban puestas como enganche desde el día anterior, y esto es cobrarlas.

**Por qué un nodo aparte y no un `AnimatedSprite2D` manejado desde `guided_missile.gd`:** el misil decide cuándo hay empuje; enseñarlo es otro trabajo. Con la separación, el humo y la explosión entran igual —otro hijo, otras señales— sin engordar el script de vuelo, y cualquier proyectil futuro que emita esas dos señales lleva escape gratis sin heredar de nada.

**Tres animaciones sobre la misma tira, no una.** El arte tiene tres momentos dibujados —prende (frames 0–9), arde estable (10–14), se apaga (15–19)— y coinciden con las fases que el misil ya emitía. Las alternativas se descartaron por lo que se ve: ciclar los 20 frames enteros apaga y vuelve a encender la llama cada 0,8 s, y reproducirlos una sola vez deja 2,5 s de vuelo con motor encendido y sin llama. `ignite` → `burn` (la única que cicla) → `shutdown` → invisible.

**Dónde corta cada fase lo dice quien dibujó la tira, no una métrica.** El primer reparto (0–7 / 8–16 / 17–19) se dedujo contando píxeles opacos por frame, y estaba mal: esa cifra sube mientras la llama crece y baja mientras se apaga, pero no distingue "creciendo" de "ardiendo" — el tramo estable resultó ser 10–14, cinco frames, no nueve. Lo corrigió el usuario mirándola. **Contar píxeles sirve para medir posiciones —de ahí salió el offset de la cola, y ese sí estaba bien—, no para leer intención.** Nota de comunicación: al hablar de frames hay dos numeraciones y no coinciden, la de la tira (0–19) y la del panel de `SpriteFrames`, que reinicia dentro de cada animación.

**El JSON de frames del editor de pixel art no se usó.** La tira es una rejilla uniforme y Godot la corta con veinte `AtlasTexture` de región calculada. El JSON sólo se gana el sueldo con atlas empaquetados de recortes irregulares; aquí sería un archivo más que mantener sincronizado a cambio de nada. Si algún día hay atlas empaquetado, se reconsidera.

**La colocación se midió sobre los píxeles, no se ajustó a ojo.** El Maverick apunta a +Y, su último píxel de cola está en la fila 2 del recorte de 16×16 y el primer píxel de la llama en la fila 15: con sprites centrados eso da `position = (0, -13)` exacto, y la llama crece hacia −Y, o sea hacia atrás. Es el único número que hay que rehacer si cambia el arte del misil.

**Medio píxel de desvío lateral que no se puede cuadrar, y se deja documentado en vez de disimulado:** el cuerpo del misil tiene ancho **par** (columnas 7–8, eje en x=0) y la llama ancho **impar** (núcleo en la columna 8, eje en x=+0,5). Ningún desplazamiento entero centra una cosa en la otra — y uno fraccionario rompería el encaje de píxel. Se dejó desviada a la derecha porque así el primer píxel de la llama cae justo sobre un píxel de la cola, que es lo que se pidió. Cuadrarlo de verdad es cosa del arte: hacer par el núcleo de la llama o impar el cuerpo del misil.

Verificado en headless: el recurso carga y está cortado en 10/5/5 frames arrancando en los índices 0/10/15 de la tira, con los tres `loop` correctos; la fila de la llama y la de la cola ocupan el mismo intervalo en Y y la llama cae dentro de las dos columnas de la cola; el ciclo completo prende → arde (ciclando sola) → se apaga → desaparece; y en un lanzamiento real por `launch()`, la llama no existe mientras cae del ala, aparece sola pasada la separación y queda detrás del misil (producto escalar −1,00 contra el rumbo).

## 2026-08-04

### El arma es dato; el proyectil, comportamiento
Punto de partida: un script de misil escrito fuera del proyecto, sin contexto. Se aprovechó su estructura —fases de vuelo (separación del ala → ignición → aceleración → crucero → sin combustible), heredar la velocidad del lanzador, guiado proporcional, serpenteo inicial que se apaga solo, señales para los efectos— y se descartaron sus cifras y su modelo de maniobra.

**Las cifras de combate viven en el `WeaponType` (`.tres`), el vuelo en la escena del proyectil.** Alcance mínimo y máximo, arco de tiro, daño, radio de explosión, tamaño de andanada, dispersión y recarga son del arma. Velocidad, radio de giro, combustible y espoleta son del proyectil. Así la misma escena de misil sirve para dos armas con pegada distinta, y la cifra que el jugador vería en el hangar es exactamente la que se aplica. Todo `@export`: se ajusta en el inspector sin tocar código.

**`Projectile` como base y `GuidedMissile` encima.** En la base está lo que comparten todos —de dónde salieron, a qué apuntan, qué pasa al explotar y el reparto de daño en área—; en la subclase, cómo vuelan. La base existe porque el daño en área es idéntico para una bomba y para un misil, y porque quien dispara necesita un tipo común al que pedirle `launch()`.

**Por qué el misil del script original era invencible: expresaba la maniobra en grados por segundo.** Eso hace que cuanto más rápido va, *más cerrado* gira — al revés que un misil real, y sin geometría en la que se le pueda escapar nada. Aquí el giro está limitado por **radio** (`min_turn_radius`), así que la velocidad angular disponible sale de dividir la velocidad entre ese radio: más rápido, más abierto.

**El fallo sale de la simulación, no de un dado.** Nada de tirar una probabilidad al final: eso se siente arbitrario y el jugador no puede leer en pantalla por qué falló. Los mecanismos son (a) **combustible finito** — agotado, el misil sigue recto perdiendo velocidad, que es lo que castiga tirar desde demasiado lejos; (b) **espoleta por máximo acercamiento** — detona cuando la distancia deja de bajar y empieza a subir, así existen los roces en vez de matar siempre que llegue cerca; (c) el **alcance mínimo**, por debajo del cual el arma aún no se ha estabilizado. Las contramedidas futuras (bengalas, chaff, ECM) encajan aquí como blancos falsos reales y degradación del guiado, no como un porcentaje invisible — pero el AGM-65 no necesita nada de eso: va contra un blanco de superficie ya designado, que es exactamente el `attack_target` que ya existía.

**Se empezó por el AGM-65 y no por el cañón** (propuesta inicial descartada por el usuario): el cañón exige resolver antes cómo dibujar mil balas sin instanciar mil nodos, y ese problema es de presentación, no de combate. El Maverick, en cambio, es dispara-y-olvida contra un blanco ya elegido: cierra el bucle completo —apuntar, disparar, impactar, dañar, morir— con lo mínimo.

**Las armas salen de la estación del ala, de una en una y alternando lados.** El `HardpointRack` ya sabía qué cuelga de dónde; ahora también sabe descolgarlo (`release(weapon) → Marker2D`). Se vacía de fuera hacia dentro y de un lado al otro, como se descarga un avión de verdad y para que no quede visiblemente descompensado a mitad de ataque. **Descolgar el sprite y descontar munición son cosas distintas**: una estación puede llevar más armas de las que caben dibujadas, así que el avión sigue teniendo con qué tirar aunque el ala ya se vea vacía.

**Cuántas salen a la vez es del arma, no del código:** `salvo_size` (1 = de una en una; 0 = todo lo que quede) y `salvo_spread`. El misil antitanque sale de uno en uno y espera a ver si hace falta el siguiente; una carga de bombas saldrá entera con dispersión para batir un área. El mecanismo está puesto; el proyectil balístico de las bombas, no.

**"Si no muere, lanza el otro" no se programó como tal.** `WeaponSystem` no dispara mientras tenga algo suyo en el aire. De ahí sale solo: se lanza un misil, se espera a que explote, y si el blanco sigue vivo sale el siguiente. Nadie tuvo que escribir "reevaluar tras el impacto".

Verificado en headless: primer disparo exactamente en el borde del alcance; vuelo de 1,4 s para 300 px con arranque a 140 px/s y aceleración hasta 300; sale alternando alas (derecha, luego izquierda); nunca hay dos misiles en el aire a la vez; con el blanco a 500 de vida encaja los dos (500 → 380 → 260) y al agotarse deja de tirar; no dispara desde cubierta aunque tenga la orden; con un arma aire-aire contra un blanco de superficie no dispara nada.

### La munición es de la salida, no del catálogo
Bug latente encontrado al implementar el gasto de munición: `PlayerFleet` construye los loadouts **una sola vez** y `FlightDeck` le pasa **esa misma instancia** a cada avión desplegado. Descontar sobre ella habría hecho que el segundo Harrier de la misión despegara con los misiles que gastó el primero, y que no se recuperaran nunca.

**Un mismo objeto hacía de dos cosas incompatibles:** en `PlayerFleet` es un catálogo —qué configuraciones existen—, y en un avión es su carga real. Ahora `Unit.set_weapon_loadout()` se queda con un `clone()`. **Clonar ahí y no en quien llama** es lo que hace que no se pueda olvidar: quien arme una unidad no tiene que acordarse de nada.

El contador (`WeaponMount.remaining`) vive en el loadout, no en el rack: el rack es una representación y ya podía discrepar por diseño (dibuja sólo las armas que caben).

Verificado en headless: el avión gasta sus dos Maverick y el catálogo sigue en 2.

### El arma manda sobre el vuelo: `AttackRunBehavior` sustituye a `ChaseBehavior`
Tres bugs reportados por el usuario resultaron ser el mismo: el avión no frenaba al entrar en alcance, se metía por debajo del alcance mínimo hasta no poder disparar, y con un misil de largo alcance volaba derecho al blanco tirando por la borda su ventaja. Todos venían de que `ChaseBehavior` llevaba el avión *encima* del objetivo sin saber que había un arma.

**Un avión armado no persigue: hace pasadas.** El comportamiento se reescribió como un ciclo de dos fases sobre la envolvente de tiro del arma — INGRESS (encara y aguanta hasta poco antes del alcance mínimo) y EGRESS (rompe, se aleja recto y vuelve a encarar cerca del alcance máximo). Se sustituyó en vez de añadir un comportamiento nuevo al lado: uno que persigue y otro que hace pasadas serían casi el mismo código.

**El comportamiento no sabe de armas.** Recibe la envolvente ya resuelta (`engage(target, min, max)`); quien la traduce del arma activa es el Harrier, que también rehace las distancias si el jugador cambia de arma en pleno ataque. Con `max_range` a 0 —sin arma— se comporta como el viejo perseguir, que es lo único sensato cuando no hay envolvente que respetar.

**Romper el ataque al disparar, no sólo al acercarse.** `WeaponSystem` emite `fired` y el avión rompe: seguir metiéndose hacia un blanco al que ya le mandaste un arma en camino no aporta nada, y la separación es justo lo que da sitio para recargar.

**Frenar es un techo temporal de velocidad, no un modo del piloto.** `PlaneController.set_speed_limit()` obedece; quién y cuándo lo decide es de quien manda al avión. `attack_speed` es `@export` del comportamiento (90 por defecto): atacar se hace más despacio que desplazarse.

**Bug encontrado probando, no reportado:** romper el ataque justo en el borde del alcance máximo no servía de nada — la condición de volver a encarar ya estaba cumplida en el mismo frame y el avión seguía metiéndose. La separación ahora es relativa a **dónde se rompió** (`separation_gain`), no sólo al alcance del arma.

Verificado en headless con la envolvente real (300–1000): dispara a 1000, se aleja a 1152, reencara y dispara a 998; **distancia mínima en todo el ataque, 882 px** — nunca se acerca al mínimo del arma. Velocidad 90 dentro del alcance y 150 fuera. Al morir el objetivo se libera el límite y vuelve a orbitar.

### Salud y daño: un número, sin blindaje
`UnitType.max_health` y `Unit.health`, con `take_damage()` y señal `died`. Sin blindaje ni tipos de daño por ahora: el AGM-65 pega 120 y un tanque aguanta 100, así que muere de un impacto —como debe— pero la cifra ya significa algo para algo más grande. Si luego hacen falta penetración o resistencias, se añaden encima sin tocar nada más.

El daño en área reparte desde el centro con caída lineal hasta el borde, y **no distingue bandos** —una explosión no lo hace—, salvo a quien disparó: sale hacia adelante y nunca debería alcanzarse, pero si la geometría se tuerce, un avión suicidándose con su propia arma se lee como un bug y no como fuego amigo.

`UnitType.domain` (AIR / SURFACE) y `WeaponType.targets` (flags) resuelven el pendiente de "no puedes atacar un tanque con un Sidewinder": el arma declara contra qué sirve y el sistema de disparo no la usa contra lo que no toca.

### Cuenta atrás de impacto y armas agotadas
**La cuenta atrás vive con la selección**, como el recuadro del objetivo: es lo que está disparando la unidad que miras, no un adorno del mapa. Aparece sobre el objetivo al disparar (10 px a la derecha, 14 arriba), desaparece al impactar, y se va y vuelve con la selección. Es una estimación honesta —distancia entre velocidad actual— y no un cronómetro: si el arma aún acelera o el blanco maniobra, la cifra se corrige sola.

**Los botones de arma llevan la cantidad y se deshabilitan al agotarse.** Un arma agotada apagada más que una simplemente no seleccionada, para distinguir de un vistazo "no elegida" de "no disponible". El cañón no muestra número porque no se gasta. La barra se entera por `Unit.ammo_changed` en vez de preguntar cada frame por algo que cambia de tarde en tarde.

**El marcador de destino se retira al atacar:** la última orden manda, y dejarlo puesto hacía creer que el avión seguía yendo a ese punto.

**Tercera aparición del mismo fallo de objetos liberados**, esta vez por la otra cara: no comparar con `null`, sino *usar* la referencia. El HUD pedía el tiempo restante desde `_process` y la lista de proyectiles en vuelo se limpia en el proceso de física; en el hueco entre que un misil explota y el sistema lo olvida, la referencia seguía en la lista y el cast reventaba.

Verificado en headless: la cuenta atrás va de 5,3 s a 0,0 y se oculta al impactar, no aparece sin nada en el aire y desaparece al deseleccionar; los botones pasan de `AGM-65[2]` a `[1]` a `[0] agotada`.

### Bug de órdenes en cubierta: no reproducido
Reportado: dar orden de ataque antes de despegar y cancelarla con un click en el mapa dejaba al avión sin ir al punto. **No se reprodujo en 14 corridas** por el flujo real —despliegue por cubierta, órdenes pasando por `SelectionManager`— dando la orden en nueve momentos distintos del despegue y con el punto lejos y cerca. En todas cancela el ataque y vuela al punto.

Hipótesis registrada, a confirmar: el circuito de espera tiene semiejes de 200×280 px, un óvalo de 400×560 en una pantalla de 640×384 — más alto que la pantalla. El avión llega al punto y se aleja hasta ~450 px orbitándolo, lo que en pantalla es indistinguible de "no fue y se quedó dando vueltas". Si se confirma, la corrección es reducir `semi_x`/`semi_y` del `OrbitBehavior`, no tocar las órdenes.

## 2026-08-03 (5)

### Atacar: mismo gesto que seleccionar, desambiguado por el contexto
Con una unidad propia seleccionada, click izquierdo (o tap) sobre un enemigo lo ataca en vez de seleccionarlo. No hace falta un gesto aparte ni doble tap: el contexto ya alcanza — "tengo algo mío seleccionado y hay un hostil debajo" sólo puede significar una cosa. Esto sigue la misma regla ya escrita para el input: *el contexto determina la acción, sin separar gestos por plataforma.*

**Costo aceptado:** con algo propio seleccionado, ya no se puede simplemente mirar a un enemigo con el click izquierdo — clickearlo ataca. Para inspeccionar sin atacar se usa el menú contextual (ver abajo). Atacar es la acción frecuente; mirar es la rara, y se resuelve con un gesto secundario en vez de complicar el primario.

**El menú contextual resuelve inspección + ataque sin sacrificar agilidad.** `click derecho` (PC) o **pulsación mantenida** (táctil, `PanCamera.long_pressed`, 0,5 s por defecto) abren un menú junto a la unidad con Atacar / Información / Cerrar. Se dispara sin soltar el botón, como cualquier menú contextual táctil; soltar después de que ya se disparó no cuenta como click, o el menú se abriría y acto seguido llegaría una orden encima. "Información" hoy es sólo seleccionarla —es lo único que hay que ver de una unidad—, y ese es el único punto que hay que tocar cuando exista una ficha de verdad.

**El menú no decide si puede atacar; sólo pregunta y muestra la opción si le dicen que sí.** La condición real (`_can_attack`) vive en `SelectionManager` y se vuelve a comprobar al ejecutar la orden, no sólo al ofrecerla — la selección pudo cambiar entre que se abrió el menú y que se tocó "Atacar".

**El objetivo es un dato de la unidad (`Unit.attack_target`), no del HUD ni de la orden.** Moverse cancela el ataque en curso — compiten por el mismo destino —, y perder el objetivo (murió) es harina de otro costal: cada tipo de unidad decide qué hacer, porque un tanque y un avión no reaccionan igual. Por eso `receive_attack_order()` es virtual, igual que `receive_move_order()`.

**El vuelo de intercepción es un componente nuevo (`ChaseBehavior`), hermano de `OrbitBehavior`**, no una rama de código dentro de él. Los dos comportamientos existentes reutilizados sin cambios: le dan puntos móviles al mismo `PlaneController`, que no sabe si está orbitando o persiguiendo. `Av8bHarrier` es quien arbitra cuál manda — nunca corren a la vez, se paran explícitamente el uno al otro.

**Qué hace el Harrier al quedarse sin objetivo en pleno viaje (usuario): orbita donde llegó, no donde estaba el enemigo.** Seguir volando hasta un punto vacío se vería como que no se enteró. Esto no necesitó una posición guardada aparte: `ChaseBehavior` avisa (`target_lost`) *antes* de dejar de procesar, así que `global_position` en ese instante ya es "donde está el avión ahora".

**Por qué no se hizo nada para "cuando llega" (usuario):** con lógica de ataque de verdad el avión nunca llega — dispara antes, o se acerca lo justo para cañón/arma corta. Programar un comportamiento de llegada ahora sería trabajo que se tira en cuanto exista el disparo.

Verificado en headless: los cuatro cruces de quién puede atacar a quién; click izquierdo sobre el enemigo fija objetivo sin cambiar la selección; el menú abre sólo sobre unidades ajenas y no sobre mapa vacío; una orden de movimiento cancela el ataque; al morir el objetivo el avión pasa a orbitar a 0 px de donde estaba en ese instante (con el enemigo a 506 px de ahí). Confirmado por el usuario en el editor: funciona bien.

### El circuito de espera es para aviones sin órdenes, no un paso obligatorio del despegue
Bug reportado: dar una orden de ataque mientras el avión seguía en cubierta marcaba el objetivo pero, al despegar, el avión se iba a dar vueltas al portaaviones y lo ignoraba.

`start_flight()` llamaba siempre a `_orbit_around(portaaviones)`, que para `chase` antes de arrancar `orbit`. La orden sí se había registrado (`attack_target` quedaba puesto, por eso el enemigo salía marcado); lo que la pisaba era el propio despegue.

**El circuito de espera es lo que hace un avión que *no tiene* órdenes.** Ejecutarlo incondicionalmente al soltar el avión trataba "recién despegado" como sinónimo de "sin órdenes", y no lo son: la cubierta tarda en soltarlo y el jugador puede haber decidido algo en ese rato. Ahora `start_flight()` mira si ya hay objetivo y, si lo hay, arranca persiguiéndolo.

Aplica igual a las órdenes de **movimiento** dadas en cubierta, que tenían el mismo problema. Ahí no hizo falta reordenar nada: el destino ya está puesto en el piloto desde `orbit_at()`, sólo había que **no pisarlo**. `OrbitBehavior.has_pending_order()` (`_running and _approaching`) es lo que permite preguntarlo sin duplicar el punto ordenado en otra variable.

Verificado en headless, los tres caminos: orden de ataque en cubierta → sale persiguiendo (`orbit` parado, destino a 0 px del enemigo); orden de movimiento en cubierta → sale hacia el punto (destino a 0 px del punto, `chase` parado); sin orden → circuito alrededor del portaaviones como siempre. Seguido a lo largo de 1200 frames, los dos primeros convergen: el que se movió entra en `arrive_radius` (39 px) y pasa a orbitar ahí; el atacante llega a 49 px y sigue persiguiendo.

### Recuadro de objetivo y aviso "Atacando: X": el estado es de la selección, no de la unidad
El enemigo bajo ataque se marca reutilizando `SelectionIndicator` (mismo dibujo que la selección, color del bando de quien lo mira — un enemigo apuntado sale en rojo) y el HUD muestra `Atacando: <nombre>` sobre la barra de armas.

**Primer intento, descartado tras que el usuario lo probara:** guardar `_targeted_by` como contador en la propia `Unit`, pensando en que varias unidades podrían apuntar al mismo blanco. Bug reportado: al deseleccionar la unidad propia, el recuadro rojo del enemigo se quedaba encendido — debía irse junto con el resto de la UI y volver si el ataque seguía al reseleccionar.

**La causa era conceptual, no un olvido de un `if`:** el recuadro no es un hecho sobre el enemigo ("me están atacando"), es una vista de lo que el jugador tiene seleccionado ahora mismo ("esto es lo que está mirando"). Por eso la marca la posee y gestiona `SelectionManager` —el mismo sitio que ya gestiona `set_selected()`—, enganchada a `attack_target_changed` de la unidad seleccionada, y se apaga/enciende exactamente cuando se apaga/enciende el resto de la UI de esa unidad. `Unit` sólo expone `set_targeted(bool)`; no sabe ni le importa quién ni cuántos la estén marcando.

**Bug de Godot encontrado de paso, con impacto real (el aviso se quedaba pegado tras morir el objetivo):** un objeto liberado (`queue_free`) se compara `== null` como verdadero. `set_attack_target(null)` comprobaba `attack_target == target` y, tras la muerte del enemigo, eso ya daba `true` — "no hay cambio" — así que ni reasignaba ni emitía la señal, y el HUD nunca se enteraba de que el ataque había terminado. Ocurría en dos sitios con la misma forma (`Unit.set_attack_target` y `SelectionManager._mark_target`). Arreglado con la misma regla en los dos: la comparación de "no hubo cambio" sólo es de fiar si el valor **anterior** sigue vivo (`is_instance_valid`); si murió, se trata como si ya fuera `null` y se deja pasar el cambio aunque el nuevo valor también sea `null`.

Verificado en headless con la secuencia completa: atacar (recuadro + aviso) → deseleccionar (ambos se apagan, el ataque sigue en curso) → reseleccionar (ambos vuelven) → seleccionar al enemigo (su propio recuadro por selección) → ordenar movimiento (ambos se apagan) → volver a atacar (recuadro vuelve) → morir el objetivo (aviso se apaga). Confirmado por el usuario tras el arreglo.

## 2026-08-03 (4)

### Bandos: identidad en `Team`, decisiones en quien las toma
El juego tendrá tres bandos —jugador (azul `#8fd3ff`), aliados por IA (verde `#a8ca58`) y enemigos (rojo `#e83b3b`)—, así que hacía falta el concepto antes de meter el primer enemigo.

`core/team/team.gd` guarda **sólo identidad de bando**: el enum `Side`, el color de cada uno y `are_hostile()`. No decide quién manda a quién ni quién puede disparar a quién; eso lo consultan el HUD, la selección y la IA, pero lo aplican ellos. Un `Team` que además decidiera esas cosas acabaría siendo el sitio donde vive medio juego.

**El bando va en la instancia (`Unit.team`), no en el `UnitType`:** el mismo T-14 puede ser enemigo en una misión y aliado en otra. El tipo describe el modelo, no de quién es.

**Dos preguntas distintas, no una:**
- `is_player_controlled()` — ¿obedece órdenes del jugador? Sólo `PLAYER`. Las aliadas son de su bando pero las mueve la IA.
- `is_hostile_to(other)` — ¿se disparan? Delega en `Team.are_hostile()`.

Seleccionar no depende de ninguna de las dos: cualquier unidad se puede seleccionar, para ver qué es o para atacarla.

**Un solo portero por regla.** El bloqueo de órdenes está dentro de `SelectionManager._issue_move_order()`, que es por donde pasan tanto el click derecho como el izquierdo en vacío — antes, ordenar a un enemigo no lo movía (`receive_move_order` es virtual vacío) pero sí plantaba el marcador de destino, y parecía que había obedecido. El HUD pasa `null` a `WeaponBar` para las unidades ajenas en vez de repetir la condición dentro de la barra.

**El panel de desplegadas filtra por bando:** los grupos (`unit_air`/`unit_ground`/`unit_maritime`) dicen de qué tipo es la unidad, no de quién es. Sin el filtro, cualquier enemigo terrestre se colaba en el inventario del jugador. Muestra sólo `PLAYER`, no las aliadas IA.

`SelectionIndicator` pasó de tener el color en una constante a recibirlo de `Unit` según el bando.

**El T-14 no lleva script.** `Unit` ya da contorno, nombre y selección, y `receive_move_order()` vacío significa que no se mueve. Un enemigo estático no necesita nada más — cuando tenga IA, tendrá script.

Verificado en headless: contorno rojo en el tanque y azul en el Harrier; los cuatro cruces de hostilidad (incluido PLAYER↔ALLY = no hostiles); con el enemigo seleccionado la orden no planta marcador y con el Wasp sí; el enemigo no aparece en el panel de desplegadas ni le sale barra de armas ni panel de acciones. Confirmado en el editor por el usuario: se ve, se subraya en rojo y no se puede mover; las unidades propias siguen saliendo en el panel.

**Detalle de GDScript:** las firmas de `Team` usan `Team.Side` y no `Side` a secas. Dentro del propio archivo, GDScript trata el enum local como un tipo distinto del que ven los demás scripts, y las llamadas desde fuera fallan a compilar con "argument should be Side but is Team.Side".

## 2026-08-03 (3)

### Barra de armas: el arma activa vive en la unidad, no en el HUD
Al seleccionar un avión aparece abajo al centro una fila de botones cuadrados (34×34), uno por arma, para elegir con cuál ataca. El no seleccionado se apaga a alpha 0.45 (`WeaponBar._DIM_ALPHA`).

**El estado vive en `Unit.active_weapon`**, no en el panel: el HUD se destruye y se reconstruye con cada selección, y el arma elegida tiene que sobrevivir a eso. `WeaponBar` sólo muestra y emite `weapon_selected`; no sabe qué es disparar.

**Qué armas salen** — `Unit.get_weapons()`: el cañón primero y después un botón por *tipo* colgado. Un tipo montado en dos estaciones da un botón, no dos (el Caza/Interceptor lleva AIM-120 en central e interna).

**El cañón es un `UnitType.cannon` exportado**, no un caso especial del HUD. Va siempre y no ocupa estación, así que no puede salir del loadout; ponerlo como `preload` dentro de la barra habría metido un arma del Harrier dentro del HUD. El Wasp lo deja vacío y por eso no le sale barra.

**Nombre corto en campo propio (`WeaponType.short_name`)** en vez de recortar `display_name` por el primer espacio. En el botón caben ~6 caracteres; recortar funciona con los cinco nombres actuales por casualidad, y un arma futura saldría cortada donde no toca.

Sin badge de cantidad: no hay consumo de munición todavía, así que el número nunca bajaría.

**El botón no recorta el texto (`clip_text` desactivado):** si un nombre no cabe, el botón se ensancha. Se probó al revés primero — a `font_size` 8 y botón de 32×32 quedaban 28 px útiles y "AGM-65" ocupa 31, así que salía en pantalla como "AGM-6" y no lo detectó nadie hasta verlo. Un botón que se deforma avisa; uno que corta en silencio, no. El tamaño actual (34×34, `font_size` 7) se eligió midiendo: el nombre más ancho ocupa 27 px sobre 30 útiles.

Verificado en headless: `[CAÑÓN, AGM-65, GBU-54, AIM-9]` para CAS, `[CAÑÓN, Mk-82, AIM-9]` para Bombardeo, `[CAÑÓN, AIM120, AIM-9]` para Caza (AIM-120 sin duplicar); el Wasp da lista vacía y la barra se oculta; pulsar un botón cambia `active_weapon`. Fila de 136 px con cuatro armas en un hueco de 320.

### El arma por defecto la decide el loadout, no la barra
Un avión armado con AGM-65 no debe salir seleccionando el cañón. `WeaponLoadout.get_default_weapon()` dice con cuál sale y `Unit.get_default_weapon()` cae al cañón sólo si va desarmado.

`default_weapon` es un tercer parámetro **opcional** de `WeaponLoadout`: vacío = la primera montada. No se rellenó en ninguno de los tres presets porque en los tres la principal ya es la primera declarada (AGM-65, Mk-82, AIM-120; el AIM-9 de autodefensa va último).

**Por qué un campo y no sólo la convención "la primera":** el orden de declaración ya gobierna el orden de los botones y el de la lista del hangar. Reordenar por estética cambiaría el arma por defecto sin que nadie se entere — el mismo tipo de fallo silencioso que el texto recortado de arriba. El campo lo desacopla; que sea opcional evita tener que rellenarlo donde el orden ya es el correcto.

**Salvaguarda:** si `default_weapon` apunta a un arma que no está montada (cambiaron los mounts y nadie actualizó el campo), cae a la primera en vez de dejar al avión con un arma que no lleva.

Fuera de alcance por ahora, y por la misma razón en los dos casos — la mecánica de la que dependen no existe: cadena de repliegue cuando un arma se agota (necesita munición consumible) y elección por distancia en combate aéreo (necesita el sistema de dogfight, que no está ni planeado).

Verificado en headless: CAS → AGM-65, Bombardeo → Mk-82, Caza → AIM-120, sin armamento → CAÑÓN; un default explícito distinto del primero se respeta; uno que apunta a un arma no montada cae a la primera.

## 2026-08-03 (2)

### El armamento del hangar sale de una lista de disponibles, no de una lista fija
Las configuraciones de armamento se ofrecían siempre las tres, completas. Ahora `Av8bHarrierLoadouts.build()` recibe la lista de armas que tiene el jugador y devuelve sólo las que se pueden armar con ella (`WeaponLoadout.can_arm_with()`, todo o nada). La lista vive en `PlayerFleet._available_weapons`, hardcodeada igual que el inventario de aeronaves.

**Las misiones no armables simplemente no aparecen.** Sin avisos de "no disponible" ni botones deshabilitados: no hay sistema de compra ni de desbloqueo que explique la ausencia, así que inventar el mensaje sería inventar la mecánica.

**Por qué así y no con un sistema de desbloqueo de verdad:** el sistema de compra/desbloqueo no existe todavía. Lo único que cambia el día que exista es **quién llena la lista** (hoy el código, mañana la tienda); quién la lee no se entera. Por eso no se añadieron ids de arma para guardar en disco, ni catálogo, ni cantidades, ni precios — nada de eso hace falta para que la lista funcione, y cualquiera de esas piezas habría sido adivinar cómo será el desbloqueo.

Descartado un autoload `PlayerWeapons` aparte: `PlayerFleet` ya es "lo que el jugador posee" y la pantalla de puerto lo va a reemplazar entero; separarlo ahora duplica esa migración.

Verificado en headless: con todo disponible salen las tres misiones; sin AGM-65 desaparece CAS/Antitanque; con sólo AIM-9 + Mk-82 queda Bombardeo; sin AIM-9 (que va en las tres) no queda ninguna, y el hangar no rompe — el botón DESPLEGAR ya exigía una misión elegida.

## 2026-08-03 (1)

### Capas de dibujado: la capa la lleva la unidad, no sus piezas
Las armas colgadas se dibujaban encima del fuselaje del Harrier. No era un fallo del motor: en 2D el orden es determinista — primero `z_index`, y a igual `z_index`, el orden del árbol. `Hardpoints` está después del `Sprite2D` en el árbol, así que se dibujaba después, o sea encima.

Se fijó una convención en dos niveles, en vez de repartir `z_index` sueltos por cada escena:

**Dentro de una unidad** (definido una sola vez en `core/unit/unit.tscn`, lo heredan todas):

| z | qué va ahí |
|---|---|
| 0 | lo que cuelga bajo el fuselaje — `Hardpoints` y sus markers |
| 1 | `Sprite2D`, el fuselaje |
| 2 | `SelectionIndicator`, el contorno de selección |

**Entre unidades** (`z_index` del nodo raíz de cada escena de unidad): naval 0, aire 10.

El nivel entre unidades no es cosmético: `z_as_relative` está activo por defecto, así que los `z` de dentro se suman al de la raíz. Con el Harrier en 10 sus armas quedan en 10 y el fuselaje del portaaviones en 1 — las bombas se ven mientras el avión rueda por cubierta. Si la capa se hubiera puesto en el `Sprite2D` del avión en lugar de en su raíz, las armas se habrían quedado en 0 y la cubierta las habría tapado.

Descartado poner las armas en `z = -1`: quedarían por debajo del terreno.

Con las capas resueltas, **el dibujado de armamento por hardpoints queda adoptado**. El día anterior había quedado "a prueba" con recetas para echarlo atrás; se retiraron. Lo que sigue abierto es sólo el arte de los sprites de armas, no el sistema.

## 2026-08-02

### Armamento visible en el Harrier
Se implementó armamento por misión: se elige un loadout en el hangar y el avión sale con las armas colgadas de puntos de anclaje (`Marker2D`) en las alas.

Tres niveles separados a propósito: `WeaponType` (qué es un arma, un `.tres` por tipo), `WeaponLoadout`/`WeaponMount` (qué se monta en una salida) y `HardpointRack` (cómo se dibuja). El rack es lo único que sabe dibujar armas y no conoce misiones ni unidades. El nombre de cada marker empieza por el id de su estación, así que **mover, añadir o borrar markers en la escena cambia lo que se dibuja sin tocar código**.

`per_station` es dato de munición, no de dibujo: una estación con 3 Mk-82 lleva 3 aunque en pantalla quepa una sola.

**Límite conocido del pixel art**, medido sobre los PNG y no supuesto: las armas del atlas miden **10–14 px de largo** (el AIM-120, 14) y la cuerda del ala donde cuelgan mide **10 px**, así que sobresalen de la silueta. Debajo del ala no es alternativa: es opaca justo ahí (de la fila 19 a la 28 en la columna de `L2a`, y el arma ocupa de la 16 a la 27 — sobreviven 3 px). Además los cuerpos de 1–3 px de ancho hierven al rotar el avión en vuelo.

Se descartó que fuera un problema de escala. La escala fraccionaria del despegue (0.7 → 0.8 → 0.9) sí agravaba el pixel art y se dejó apagada tras un parámetro (`FlightDeck.spawn_scale`, 1.0 = apagado, 0.7 = comportamiento anterior), pero no era la causa.

Opciones de arte sobre la mesa, sin decidir: (1) redibujar las armas más cortas y gruesas (6–8 px de largo, 2–3 px de cuerpo) para que quepan dentro de la silueta del ala; (2) un sprite del Harrier por preset — viable si el daño se resuelve como capa superpuesta y no como variante del sprite base, porque las capas se suman y los sprites base se multiplican.

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
