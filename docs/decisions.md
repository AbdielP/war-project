# Decisiones — war-project

Registro cronológico (más reciente arriba). Una entrada por decisión: qué se decidió y por qué.

## 2026-08-05

### La estela no es una animación: es un rastro de piezas que ya salieron
Humo del AGM-65, con arte del usuario (tira de 288×16 = 18 frames de 16×16, el último vacío y descartado). No es una cola que se deforme: `MissileSmokeTrail` cuelga de la tobera y va **soltando bocanadas sueltas por el mundo**, cada una con la rotación que llevaba el misil en ese instante. La curva sale sola — no hay geometría que doblar, hay piezas que ya salieron apuntando a donde el misil iba entonces. `guided_missile.gd` no se tocó: mismo enganche que el fuego (`motor_ignited` / `fuel_spent`, por duck-typing).

**Las bocanadas cuelgan del mundo, no del misil.** Es la decisión que hace que esto sea una estela y no un adorno: hijas del misil viajarían *con* él, que es exactamente lo contrario. Nacen como hermanas suyas, en el nodo donde `WeaponSystem` ya suelta los proyectiles, y por eso **sobreviven al impacto**: el misil explota y la cola que dejó sigue deshaciéndose sola.

**Se siembra por distancia recorrida, no por tiempo.** `spacing_px` (4 px). Con un temporizador el espaciado quedaría atado a la velocidad: estela rala en la aceleración inicial y apelmazada al frenar sin combustible, y encima cambiaría si algún día cambian los fps de física. Por distancia es uniforme siempre y el número significa algo que se puede mirar en el arte. **Además se siembra a lo largo del tramo, no en el punto actual**: a velocidad de crucero el misil avanza 5 px por frame, así que una bocanada por frame dejaría la cola a trozos; se interpolan posición y rumbo dentro del segmento recorrido.

**El largo de la cola no se alarga bajando los fps, se alarga por frame.** La primera versión duraba 0,71 s (210 px) y se veía corta. Bajar `speed` a la mitad habría alargado igual, pero también habría vuelto a 12 fps el nacimiento de la bocanada, que es donde el dibujo cambia mucho de un frame al siguiente y donde un salto se ve. En su lugar se usaron duraciones por frame: los 9 primeros a 24 fps limpios, los 8 últimos alargándose de 1,5× a 5×. Vida 1,458 s → **438 px de estela y ~109 bocanadas vivas** a la vez.

**Contra la repetición: espejo y desfase.** Todas las bocanadas son el mismo dibujo saliendo cada 4 px exactos, y eso se lee como un sello repetido. `flip_h` al azar duplica los dibujos gratis (y mueve el píxel de nacimiento de la columna 7 a la 8, las dos cola del misil, así que sigue anclada). El desfase tiene dos partes: un frame entero opcional (`start_jitter_frames`) que cambia el dibujo, y **siempre uno de menos de un frame**, que no cambia nada visible al nacer pero descoloca *cuándo* cada una salta al siguiente frame. Sin esa segunda parte seguirían escalonando a la vez, que era lo que se notaba: a velocidad de crucero cada frame dura tres bocanadas, y se veían bandas de tres iguales avanzando en bloque.

**Limitación conocida y sin resolver: la cola se ve plana al final.** Es el precio de haber alargado estirando duraciones. Los 8 frames finales se llevan **26 de las 35 unidades de vida — ~325 px de los 438 son dibujo congelado**; el frame 16 dura 0,208 s, y en ese rato nacen ~16 bocanadas que enseñan el mismo píxel en fila. El desfase no lo arregla porque es **fijo**: donde cada frame dura 1 unidad lo cambia todo, y donde dura 5 sólo despeina el borde de la racha. De ahí que varíe la cabeza y no la cola. Segundo síntoma del mismo origen: todas mueren a los 438 px exactos, así que la estela termina en corte recto.

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
