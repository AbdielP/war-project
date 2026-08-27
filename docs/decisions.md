# Decisiones — war-project

Registro cronológico (más reciente arriba). Una entrada por decisión: qué se decidió y por qué.

## 2026-08-27 — el juego deja de ser una misión suelta: carcasa, router y secuencia de pantallas

> **Las pantallas están en hueso.** Navegan de verdad, se guardan de verdad y se pueden recorrer de
> punta a punta, pero su contenido es texto de muestra y su arte es el mínimo para leerse. Lo que
> queda cerrado aquí es el esqueleto y el flujo, no el aspecto.

### El problema no era "falta un menú", era que la misión *era* el juego
`main.tscn` se abría al arrancar y ahí acababa todo. Cualquier pantalla nueva —menú, puerto,
briefing— habría tenido que colgarse de la misión o reemplazarla a mano desde algún sitio.

Lo que se ha hecho es lo contrario: la raíz del proyecto pasa a ser `game.tscn`, **una carcasa con
un hueco y un velo**, y todo lo demás son inquilinos de ese hueco. La misión deja de ser el juego y
pasa a ser una pantalla más. No se ha tocado una línea de `main.tscn`.

### Ninguna pantalla depende de que otra la haya preparado
Es la regla que sostiene todo lo demás, y la petición explícita del usuario: *"no puedo pasar por
todo eso cada vez que vengo a programar"*. Si una pantalla necesita que alguien le pase datos antes
de existir, sólo se puede probar atravesando la secuencia entera.

Así que cada pantalla trae **contexto de muestra** en un `@export` y lo usa cuando nadie la
configuró. Abres `port.tscn`, F6, y estás en el Puerto en medio segundo — sin logo, sin menú, sin
partida guardada. Es la misma idea del `preview: PackedScene` del hangar, subida un nivel.

No es un apaño de desarrollo: una pantalla que no puede existir sin las tres anteriores está mal
aislada, y eso se paga igual el día que haya que cambiar el orden de la secuencia.

### El router va aparte porque si no, todo se conoce con todo
`Screens` es un autoload y **nadie instancia a nadie**. Sin él, el menú acabaría guardando una
referencia a la campaña y la campaña al menú.

Tiene dos caminos y las pantallas no saben en cuál están:
- **Con carcasa**: fundido, carga en hilo aparte, pantalla de carga si tarda.
- **Sin carcasa** (F6 sobre una pantalla suelta): cambio de escena a pelo. Se pierde el fundido y
  **la navegación sigue funcionando**, así que se puede recorrer el flujo desde donde estabas.

### El Puerto no es un destino, es una pantalla hija
Decisión del usuario: al Puerto sólo se llega desde el briefing o desde la pantalla de campaña. Eso
cambia cómo se programa: no puede tener una salida fija, porque tiene dos entradas.

De ahí que el router lleve **pila** además de reemplazo. `push()` recuerda desde dónde se vino,
`back()` devuelve. El Puerto no necesita saber quién lo abrió, y abierto suelto con F6 el botón sale
apagado en vez de muerto.

```
Splash → Menú ─┬─ Nueva ─────↘
               └─ Continuar ─→ CAMPAÑA ──→ Briefing ──→ Misión
                                ↑  ↓ ↑        ↓ ↑          ↓
                                │ Puerto ─────┘        Debriefing
                                └──────────────────────────┘
```

### No hay pantalla de arranque
El arranque lo hace la propia carcasa antes de enseñar nada. Una pantalla para eso sería un fundido
a negro para entrar en algo negro y otro para salir — y además obligaría a que la primera pantalla
del juego pidiese otra desde su propio `_ready`, que es el caso que más cuesta encadenar bien.

### Guardar entre misiones, y eso decide el formato entero
El usuario puso *Guardar* como opción de la pantalla de campaña. Eso cierra la pregunta que quedaba
abierta: se guarda **con la campaña quieta**, no en mitad de un tiroteo.

La diferencia no es de comodidad, es de coste. Guardar a mitad de misión obliga a serializar cada
unidad, cada proyectil en el aire y cada orden pendiente, y condiciona cómo se escribe todo lo demás
desde hoy. Entre misiones cabe en cuatro campos —progreso, dinero, desbloqueos, versión de formato—
y es todo lo que hace falta para que *Continuar* funcione.

`Campaign.FORMAT` está desde el primer día: un guardado de otra versión **se descarta entero**, no se
carga a medias. Media partida cargada es peor que ninguna.

### El progreso se apunta en el debriefing, no al terminar la misión
Hasta que el jugador no ha leído el parte, la misión no está cerrada. Si cierra el juego antes de
darle a *Continuar*, la vuelve a jugar. Es también lo que evita tener que decidir qué pasa si sale
por la ventana de al lado.

### F6 lleva a una pantalla; `dev_boot.cfg` lleva a una situación
La distinción es la que de verdad ahorra tiempo. F6 no puede darte "el Puerto con 50.000 y el Cobra
desbloqueado" ni "el debriefing de una misión perdida".

`dev_boot.cfg` dice a qué pantalla ir y con qué contexto. **No va al repositorio** —es de tu máquina
y de tu día de trabajo— y **no llega nunca a una versión publicada** sin tener que acordarse de
quitarlo: se lee bajo `OS.has_feature("editor")`, que es falso en cualquier build exportada. Lo mismo
por línea de comandos (`--screen=port --instant`), que es lo que sirve para lanzar pruebas
automáticas dentro de una pantalla concreta.

### La pantalla de carga sale por tiempo, no siempre
Casi todas las pantallas cargan en un fotograma, y enseñar "CARGANDO" durante 30 ms es un parpadeo
que se lee como un fallo. Sólo sale si la carga pasa de `loading_delay` (0,25 s), y hoy sólo la
misión pasa de ahí.

**Y hubo que destaparla**: el primer montaje la dibujaba debajo del velo negro, así que no se veía
nunca. El fundido tiene que abrirse cuando la barra aparece y volver a cerrarse antes del cambio. Se
descubrió mirando la captura, no leyendo el código — el juego arrancaba sin un solo error.

### Lo que sí molesta y se deja apuntado
La carga en hilo aparte deja **11 objetos internos sin liberar al cerrar** el juego, y sólo con la
misión: `main.tscn` arrancada sola no los deja, y con carga bloqueante tampoco. **No se acumulan** —
entrar y salir de la misión tres veces sigue dando 11— así que no es una fuga que crezca, sino caché
del cargador que el motor no suelta al salir. Se queda la carga en hilo, que es lo que hace posible
la barra.

### El menú no tiene *Opciones*, a propósito
No hay ninguna opción todavía, y un botón que abre una pantalla vacía es peor que no tenerlo.

### La salida de la misión es un andamio y está marcada como tal
Mientras no haya condiciones de victoria hace falta alguna forma de llegar al debriefing para poder
recorrer el juego entero. Hoy es **F10**, en el envoltorio de la misión y no dentro del juego. Se va
el día que la misión sepa terminarse sola.

---

## 2026-08-26 — el mapa deja de ser cuadraditos: símbolos de contacto, y arte nuevo de marcadores

> **Los colores no son definitivos.** Falta trabajo, sobre todo en el aliado, y el azul del jugador
> todavía no convence. Lo que está cerrado es la geometría y el reparto; el tono se seguirá tocando.

### El lienzo es común a todas las variantes; lo que cambia es el marco dentro
Primer error al dimensionarlos: dije "9×9" pensando en el marco y no en el hueco. Un rectángulo de
11×7 y un rombo no caben en la misma medida si se mide cada uno por su cuenta — pero **tienen que
caber en la misma caja**, porque si no, la marca de dominio cae en un sitio distinto según el bando
y el icono de tipo habría que redibujarlo cuatro veces.

La caja es **11×11** en el mapa táctico y **7×7** en el minimapa. Dentro: el rombo hostil la llena
entera, el rectángulo amigo mide 11×7 y el cuadrado neutral 9×9, los tres centrados.

### En una familia de formas, el tamaño lo fija la más restrictiva
Y aquí es el rombo. Un rombo sólo deja un cuadrado útil de **2/5 de su ancho**, y en píxeles reales
eso se ve de golpe:

- rombo de 9×9 → filas de 1,3,5,7,9,7,5,3,1 → cabe un icono de **3×3**. Inservible.
- rombo de 11×11 → 1,3,5,7,9,11,9,7,5,3,1 → cabe **5×5**.

Nadie más de la familia tenía ese problema; el rectángulo aguanta cualquier medida. Se dimensiona
contra el caso peor y los demás sobran de sitio, no al revés.

### Macizo o hueco no es una decisión general: es una por mapa
Se probaron los dos en el mapa de verdad, con cuatro tanques apiñados sobre una isla.

**Macizo** gana contraste y poco más. **Hueco** gana dos cosas que se ven a la primera:

- **El terreno se lee.** Con relleno, los cuatro contactos tapaban la isla entera.
- **Los apiñados se cuentan.** Con relleno eran una mancha roja; con borde son cuatro rombos aunque
  se toquen. Y es la única forma de que el icono de tipo tenga un dentro donde ir.

Y pierde una: **la masa que despegaba el símbolo del fondo**. Por eso el reparto es hueco en el mapa
táctico —donde hay sitio, detalle que leer y contactos que contar— y macizo en el minimapa, donde a
5×5 un anillo de 1 px no dice nada y lo único que se pide es "hay alguien ahí".

### El bando que peor se leía era el propio, y era problema de color
El `#5184c1` del jugador y el `#4d9be6` del agua son casi el mismo azul. Con relleno se salvaba por
los pelos; en hueco había que buscarlo, y es justo el bando que más se mira. Los otros tres —verde,
blanco, rojo— contrastan con el mar y nunca dieron problema.

Se arregló por color y no volviendo al relleno: el borde pasó a `#8fd3ff`, que es el azul que **ya
significa "jugador"** en este HUD — el del recuadro de selección y el de las coordenadas. Sigue sin
convencer del todo, pero el fallo ya no es de legibilidad.

### Una marca que acompaña va separada, no solapada
La barra de dominio se puso primero con 2 px de solape, para que las dos piezas se leyeran como una.
El resultado fue que **se comía la punta del rombo**, que es justo lo que identifica al hostil. Ahora
son 2 px de aire (`domain_gap`, en el inspector). Un rombo con la punta puesta y una barra encima se
lee como dos datos; solapados se leen como una forma rara que no es ninguno de los dos.

### El dominio se dibuja, pero el juego todavía no sabe contestarlo
La barra vale para las dos cosas: **encima significa que vuela y debajo que navega**. La T invertida,
sólo debajo, es bajo el agua. Puestas las tres y sólo sale la de aire, porque `UnitType.Domain`
separa aire de superficie y nada más: un buque y un tanque son la misma cosa para el juego, y
pintarle la barra de mar a los dos sería mentir sobre el tanque.

Separar naval de terrestre no es un campo más: `targets` es hoy una máscara de dos casillas —Aire y
Superficie— en las diez armas, y un tercer dominio las corre todas. Queda como decisión pendiente.

### La onda del marcador de destino sale tres veces
Salía una sola vez, con este razonamiento: el dato ya lo dio al aparecer y un marcador que late sin
parar pide atención cada dos segundos para no decir nada nuevo. Sigue siendo cierto lo segundo, pero
una sola onda **se pierde si estabas mirando a otro lado** — que es exactamente lo que la onda venía
a evitar.

Tres, con 0,2 s entre ellas: la tanda dura ~2,6 s y después se calla para siempre. Y una orden nueva
a mitad de tanda **no encadena dos series**: la espera pendiente lleva apuntado a qué orden pertenece
y se descarta sola si ya no es la de ahora.

### Arte actualizado del sheet
Se reextrajeron del `UI.png` nuevo, todos con la misma medida que tenían: las cuatro flechas de
unidad `(112, 38|54|70|86, 16, 10)`, la mirilla redonda del cursor de ataque `(175, 63, 19, 20)` y
los seis fotogramas del banderín `(150 + 640k, 35, 22, 24)`.

El banderín va **alineado por el mástil, no por la caja del dibujo**: cada fotograma tiene su origen
exactamente 640 px más allá del anterior y la onda crece hacia fuera desde ahí, así que las cajas de
tinta no coinciden entre sí y alinearlas por ellas descolocaría el mástil.

### El retrato del Harrier era el caza blanco, no el gris
Comparando píxel a píxel, tanto `icon_av8b.png` como `thumb_av8b.png` salían **idénticos** al sheet, y
di por hecho que no había cambiado nada. El caza blanco que había al lado lo descarté por mi cuenta:
el buque y el helicóptero también vienen en pareja gris/blanco, así que lo leí como la variante
resaltada de una pareja. Era el nuevo.

Lo que falló no fue la medida sino haber resuelto una ambigüedad en vez de preguntarla. Y deja algo
pendiente a la vista: el caza sale blanco con sombreado y el helicóptero y el buque siguen grises y
planos en el mismo panel.

## 2026-08-25 — el SuperCobra dispara: postura de tiro, cohetes que no llenan la pantalla y el arma que el jugador eligió

### La maniobra de tiro de un helicóptero es un destino, no un comportamiento
El avión necesita `AttackRunBehavior` porque no puede parar: hay que inventarle cómo acercarse a un
blanco sin frenar. El helicóptero no. Su maniobra de tiro es **plantarse a la distancia que pida el
arma con el morro puesto**, y eso cabe en el piloto que ya existía.

Dentro de `HelicopterController` los dos mandos se separan del todo: el pedal clava el morro en el
blanco —sin `face_range` que valga, encarar de cerca es justo lo que se quiere— y el cíclico se
ocupa **sólo de la distancia**. Y el sitio bueno no es un punto sino un **anillo**: cualquiera a esa
distancia sirve, así que dentro de `hold_band` se da por colocado y deja de corregir. Sin holgura
corregiría eternamente el último píxel contra un blanco que también se mueve.

De ahí sale gratis el gesto que se buscaba desde que voló: al entrar, mientras la cola todavía gira,
el mismo vector radial sale con componente lateral y **el aparato entra de costado**. No está
programado; es lo que pasa cuando el morro va por un lado y el cíclico por otro.

### El blanco y el destino no conviven: dar uno suelta el otro
Un aparato que siguiera encarado al enemigo mientras el jugador lo manda a otro sitio estaría
obedeciendo a medias, y esto es un juego de órdenes. `set_target()` suelta el blanco y `attack()`
suelta el destino. La base ya lo hacía por su lado —`Unit.receive_move_order` pone el blanco a
`null`—, así que las dos mitades dicen lo mismo.

### A qué distancia plantarse lo decide la unidad, no el piloto
El piloto no sabe de alcances ni de munición; quien da la orden sí. Así que `attack()` recibe la
distancia ya calculada y el `AH-1W` la saca del arma activa: `standoff_fraction` (0,8) del alcance
máximo, nunca por dentro del mínimo.

**Y sin nada con lo que dispararle, se queda donde está** con el morro puesto. Meterse en el alcance
de algo a lo que no puedes hacer nada es sólo ponerse a tiro. No es negarse a la orden —el blanco
queda marcado y el HUD lo dice—, es no gastar el aparato en un viaje que no sirve.

### Un solo sitio traduce "a quién ataco" en maniobra
No hay `receive_attack_order` sobrescrito en el Cobra: la orden sólo anota a quién, y todo pasa por
`attack_target_changed`. Por ese mismo aviso entran el ataque que empieza porque el jugador lo pidió,
el que se cancela porque mandó al aparato a otro sitio y el que termina porque el blanco murió. Tres
caminos, un handler.

### Un aparato al que se le apunta el blanco en cubierta tiene que despegar igual
`HelicopterController.enable()` miraba si había **destino** para arrancar la subida. Pero la cubierta
apunta el blanco antes de soltar el aparato (`FlightDeck._obey_standing_order` llama a
`set_attack_target`, no a `receive_attack_order`), así que al llegar a `enable()` lo que está puesto
es `aim` y no `has_target`. Resultado: un Cobra lanzado desde el hangar con orden de atacar **se
quedaba en cubierta para siempre**, con el morro girado hacia el enemigo y sin que nadie volviera a
sacarlo — la orden no se repite porque el blanco no ha cambiado.

Se arregla mirando las dos clases de orden. La lección general: cuando a un estado se llega por dos
caminos, la puerta de salida tiene que preguntar por los dos.

### El cañón de un helicóptero necesita ráfagas; el de un avión no
El `M197` salió clonado del GAU-12 del Harrier y traía `min_range = 220`, que es distancia de pasada
de reactor. Un helicóptero dispara desde parado y a bocajarro: a 0.

Más de fondo: el cañón del avión tiene `burst_seconds = 0` porque **la pasada ya es la ráfaga** —
entra, tira, rompe. Uno en estacionario no tiene pasada que le marque el ritmo, así que aguantaría el
gatillo indefinidamente y se leería como un chorro continuo. Ráfagas de 0,9 s con 0,5 de silencio.
Es el mismo razonamiento que ya estaba escrito para la batería antiaérea, aplicado a algo que vuela.

### El humo es el gasto, no los cohetes
La duda al montar los cohetes era si instanciarlos de verdad o falsearlos como las trazadoras del
cañón. Falsearlos está mal: una bala es invisible e instantánea y la trazadora es una mentira que
vale por cinco, pero un cohete es lento, grande, su vuelo **es** el espectáculo y sobre todo **tiene
que poder fallar**. Falseado, el daño se decidiría al apretar el gatillo y los fallos se verían
arbitrarios.

Lo que llena la pantalla no son los cohetes: es su estela. Medido en el motor, nodos vivos a la vez:

| | proyectiles | bocanadas de humo |
|---|---|---|
| **un** AGM-114 | 1 | **95** |
| **siete** Hydra-70 | 7 | **133** |

Una salva entera cuesta un 40 % más de humo que un solo misil. La diferencia está en usar la
bocanada del cañón (10 fotogramas) en vez de la del misil (23) y separarlas más. El proyectil no era
el problema.

### La salva no es el cargador
19 Hydras es lo que lleva el contenedor, no lo que sale por gatillazo. `salvo_size` y `salvo_interval`
ya hacían la ristra para las bombas del Harrier, así que no hubo que construir nada: Hydra sale de 7
en 7 cada 0,06 s, Zuni de 2 en 2. En pantalla nunca hay más de 7.

### Del pilón cuelga a veces el arma y a veces el aparato que la lanza
`HardpointRack.release()` descolgaba el sprite en cada disparo. Con un misil está bien —el misil
**es** lo que cuelga y el pilón queda pelado—, pero el primer Hydra se llevaba el contenedor entero
del ala y los dieciocho siguientes salían de la nada.

De ahí `WeaponType.icon_is_launcher`. El contenedor se queda mientras le queden cohetes y se suelta
cuando **ya no puede llevar lo que falta por tirar**: con dos de 19 y 19 gastados, uno sobra y cae.
Se cuenta desde la munición y no llevando la cuenta en el rack, porque el rack no es el contador —
el mismo número mirado desde dos sitios es como se acaba con dos verdades distintas.

Va en el arma y no en la carga porque no depende del contexto: un contenedor de cohetes es un
contenedor cuelgue de donde cuelgue.

### Un cohete no es un misil sin buscador ni una bomba con motor
`Rocket` no hereda de ninguno de los dos. El misil corrige durante todo el vuelo —la mitad de su
código es guiado proporcional y radio de giro— y la bomba no tiene motor y todo su vuelo sale de
cuánto frena. Un cohete empuja recto: es el más simple de los tres y meterlo en cualquiera de los
otros sería arrastrar maquinaria que no usa jamás.

**Fija el rumbo al salir y no lo vuelve a tocar.** A partir de esa línea ya no sabe dónde está el
blanco, sólo hacia dónde va. Y de ahí sale que falle, sin ninguna tirada: cada cohete de la salva
apunta a un punto distinto alrededor del objetivo (`salvo_spread`), así que uno quieto se come casi
todos y uno que se movió, casi ninguno. Eso es exactamente lo que significa "sin guía".

Sin cuenta atrás de impacto, por lo mismo: un número prometería una puntería que este arma no tiene.

### El punto de apuntado se comprueba contra el tramo, no contra el final del paso
A 340 px/s un cohete avanza 5,7 px por fotograma. Mirando sólo dónde acaba el paso, cruza su punto de
apuntado sin enterarse y sigue de largo. Se mide la distancia del punto al **segmento** recorrido.

### Los dos calibres son dos oficios
Hydra-70 son 70 mm con cabeza HE o de flechettes: infantería, blandos y vehículos ligeros; su arma es
la saturación. Zuni son 127 mm con cabeza mucho mayor, contra lo duro. Contra un T-14 de 100 de vida,
medido: **los 38 Hydras lo dejan al 0,1 y los 4 Zunis al 0,8**. El contenedor entero de Hydras cuesta
lo mismo que cuatro Zunis, que es la diferencia entre saturar y perforar.

El AGM-114 es el tercero y no se parece al GBU-54 pese a que los dos son "lo que cuelga contra
tierra": el JDAM es una bomba de 227 kg **sin motor** que planea, y el Hellfire un misil de 49 kg con
cohete y carga hueca de 9 kg. Diez veces menos explosivo y aun así es el que mata carros, porque una
carga hueca perfora lo que a la onda expansiva le da igual. Y para el juego manda el motor: la bomba
necesita velocidad y altura —por eso el Harrier hace la pasada— y el misil se va solo, que es lo que
permite lanzarlo desde un helicóptero parado.

### La elección de arma del jugador no caduca por cambiar de blanco
Se descartaba en cuanto apuntabas a otro, con este razonamiento: si elegiste un AMRAAM para un caza y
ahora apuntas a un tanque, tu elección ya no significa nada. Pero contra tierra el automático elige
**la que más lejos llega**, y eso era buen sustituto de "la más adecuada" cuando el Harrier llevaba
Maverick, GBU y Mk-82. Con el Cobra deja de serlo: el Zuni y el Hellfire no son dos bandas de
distancia, son dos oficios. Elegías Zuni, apuntabas al siguiente tanque y te ponía el Hellfire encima.

La regla nueva: **se respeta la elección salvo que el arma no pueda dispararse** contra el blanco
nuevo — ni sirve contra ese medio, o se acabó. Que otra encaje mejor no cuenta: eso es preferencia, y
la preferencia es del jugador.

Al cambiar la pregunta de "¿es el mismo blanco?" a "¿todavía sirve?", `_manual_target` y
`_manual_pending` se quedaron sin nadie que las leyera — existían sólo para llevar la cuenta de para
qué objetivo se había elegido. Fuera. Y el caso raro que protegían —elegir el arma **antes** de tener
blanco— sale bien solo.

### La frase que se canta y la abreviatura que se escribe son el mismo dato en dos sitios
El cañón cantaba `guns, guns, guns!` por una convención de radio que no es tal, y los cohetes
heredaron `Rifle` del Maverick, que es la llamada de **misil** aire-superficie. Ninguna de las dos
armas tiene llamada propia de radio.

Primer intento: una frase en el HUD elegida por `fire_mode == SUSTAINED`. Funcionaba para el cañón y
no daba para los cohetes, que son lanzadores igual que los misiles. Se acabó en
**`WeaponType.radio_call`**: la frase vive en el arma, y vacío = se canta el código. Siguen siendo dos
campos porque son dos sitios —el parte de eventos escribe `(Guns)`, `(Rockets)` entre paréntesis—
pero un solo camino.

### Una llamada de radio se calla mientras dure lo que anuncia
El cañón sacaba un cartel cada dos ráfagas y un helicóptero en estacionario los sacaba para siempre.
Dos fallos sumados:

- La ventana de agrupado (2,8 s) era **más corta que el ciclo de ráfaga** (0,9 + 0,5). Las armas de
  chorro continuo tienen la suya, `sustained_call_window`, a 6 s.
- Y el de fondo: la cuenta arrancaba en **la última vez que se cantó**, no en el último disparo. Por
  larga que fuera la ventana, un cañón que no para volvía a cantar al cumplirse. Ahora la hora se
  apunta también cuando la llamada se calla, y eso convierte la ventana en "hace mucho que no pasa"
  en vez de "hace mucho que no lo digo".

Medido: **un cartel en 25 s de fuego continuo**, donde antes salía uno cada dos ráfagas.

### La cuenta atrás de impacto la contesta la unidad, y el Cobra no contestaba
`Unit.get_time_to_impact()` devuelve −1 de fábrica y el único que lo sobrescribía era el Harrier. El
contador no se veía y el recuadro del blanco no se cerraba, y no era del misil ni del HUD: faltaba el
dato en la unidad. Se pregunta **acotado al propio blanco**, o al cambiar de objetivo el nuevo
hereda la cuenta atrás del anterior.

**Anotado y sin arreglar**: la cuenta no baja lineal. `Projectile.time_to_impact()` divide la
distancia entre la velocidad **de ahora mismo**, y un misil acelera — frena al separarse del ala (el
número sube) y al llegar a crucero se desploma. Es la fórmula de siempre, compartida con el Maverick
y el AMRAAM; en el Hellfire canta más porque sale a 55 px/s y cruza a 280. Arreglarlo cambiaría la
cuenta de todas las armas del juego.

### El contador de impacto: Yellow Pixel a 16, y por qué no a 8
Su tamaño nativo es **8** — el dígito cae en 3×5 con trazos de 1 px sólido. Por debajo el `8` se
convierte en un borrón macizo; en 9, 10 y 12 se deforma. Los múltiplos enteros son exactos.

Va a **16** y no a 8, que también sería nítido: el contador se dibuja encima del terreno sin borde ni
fondo, y a 1 px de trazo se pierde. A 16 son dígitos de 6×10 con trazo de 2 px, el mismo tamaño que
el resto del texto del HUD. Comprobado sobre los cuatro colores que de verdad hay en el mapa —sacados
contando píxeles de los dos tilesets— y el render sale con exactamente cinco colores: los cuatro
fondos y la tinta.

## 2026-08-25 — señalar sin envolver: cursor propio, marcas de unidad y el arma que se quedó vacía

### El recuadro de selección se sustituye por una flecha encima
El cuadro que envolvía a la unidad seleccionada crecía con ella: alrededor del LHD envolvía media
pantalla. Una flecha apuntando desde arriba dice lo mismo y ocupa igual sobre el Harrier que sobre
el buque, sin tapar lo que hay alrededor.

**El color de bando no se tiñe, se cambia de dibujo.** Teñir es multiplicar, y el borde casi negro
de la flecha multiplicado por rojo se queda casi igual de negro: se pierde el filo claro que la
despega del terreno y los tonos intermedios se van fuera de Resurrect64. Van los cuatro PNG por el
inspector — azul jugador, verde aliado, rojo enemigo, blanco neutral.

### La caja de una unidad es la tinta de su sprite, no el tamaño de su PNG
`SelectionIndicator.size` venía del recuadro viejo y era más pequeña que el dibujo en tres de las
seis unidades: el Harrier declaraba 28×32 con un sprite de 35×48, así que 8 px de aire por arriba
se los comía la nariz. Y el buque declaraba 160×304 —el PNG entero— cuando su casco ocupa 106×222
dentro, corrido 25 px hacia abajo: la flecha le salía a 66 px de la proa, flotando en el mar.

De ahí sale `center`: dónde cae el centro del dibujo respecto al origen de la unidad. Vale cero en
todas menos en el buque y el T-14. **Se mide rasterizando la tinta dentro del motor**, no leyendo
el tamaño del archivo.

### Lo que acompaña a algo que gira se mide contra la caja ya girada
Media caja fija no vale: un helicóptero de 23×48 pasa a medir 48×23 de perfil, y la marca se queda
flotando en el aire media vuelta de cada dos. Se calcula lo que sobresale la caja rotada
(`|sin|·ancho + |cos|·alto`) y la marca va pegada a ella todo el rato. La marca en cambio **no
gira**: girada dejaría de leerse como marca y pasaría a leerse como rumbo.

### Con `@tool`, se coloca dibujando y no moviendo el nodo
Colocar la flecha cambiándole la posición al nodo obligaba a escribirle encima cada fotograma, y en
el editor eso queda **guardado dentro de las seis escenas de unidad**. Dibujándola con
`draw_set_transform` el nodo se queda quieto en el origen y lo que se ajusta es el trazo, así que
`size`, `center` y `gap` se pueden tocar en vivo sin que el editor ensucie nada.

### El marcador de movimiento: una bandera con onda, reproducida una vez
Seis fotogramas repartidos uno por "página" de 640 px del sheet, con el mástil siempre en la misma
columna. Anclado en el **centro de las ondas**, no en la base del mástil: es de donde sale la onda y
donde cayó el clic.

La onda **se reproduce una vez y descansa en el primer fotograma**, que es la bandera sola. Un
marcador que late sin parar acaba pidiendo atención cada dos segundos para no decir nada nuevo: la
onda es el acuse de recibo y la bandera el recordatorio.

### El puntero del ratón se dibuja dentro del juego
El cursor del sistema se pinta a la resolución de la pantalla, no a la del juego: un dibujo de 13×14
sale del tamaño de una uña al lado de unidades que la ventana agranda ×2 o ×3. Dibujado dentro va
escalado con todo lo demás.

Tres decisiones que lo sostienen:

- **Capa propia (`layer = 100`), no hermano del HUD.** Media pantalla del HUD llama a
  `move_to_front()` al abrirse —la ventana del buque, el mapa táctico— y eso reordena a los
  hermanos: tarde o temprano uno se pondría encima. La capa no depende de quién se movió el último.
- **Se cuadra a píxel entero del juego, no de pantalla.** Con la ventana al doble, un píxel de
  pantalla es medio de juego y el ratón llega con decimales; sin redondear sale a media rejilla,
  borroso y temblando. El precio —avanzar de dos en dos píxeles de pantalla— es lo que hace ya todo
  lo demás que se ve.
- **En móvil no se dibuja, y tampoco se esconde el del sistema.** Se pregunta por `FEATURE_MOUSE`,
  no por el sistema operativo: un portátil táctil tiene las dos cosas.

### La mira sale exactamente cuando el clic sería un disparo
No basta con que sean enemigos. `_can_attack` sólo comprueba enemistad, y con eso el buque —que no
lleva cañón ni armamento— sacaba la mira sobre cualquier hostil prometiendo un ataque imposible. De
ahí `_can_shoot`, que además exige `get_weapons()` no vacío, y que usan el clic izquierdo y el
cursor. **La mira y el clic hacen la misma pregunta**: si dijeran cosas distintas, el cursor estaría
prometiendo algo que el clic no cumple.

Dos exclusiones más: encima del HUD no hay mira aunque debajo del panel haya un enemigo —ahí el clic
se lo queda la interfaz y nunca llega al mundo—, y tampoco sobre un blanco al que ya se le dio la
orden, porque eso ya lo dicen sus cuatro esquinas.

`_can_attack` se queda como está —sólo enemistad— alimentando el menú del objetivo: ver *pendiente*
al final de esta entrada.

### Las cuatro esquinas se componen contra la caja, no se estiran
En el sheet la animación está dibujada sobre un cuadro de 32 que se cierra hasta 22. Eso es la
**holgura**, no la medida: entre un tanque de 26×42 y un buque de 106×222 no hay cuadro fijo que
sirva. Son cuatro piezas de 8×8 colocadas una a una contra las esquinas de la caja, y el fotograma
sólo decide cuánto aire dejan (5 px a 0).

Las de abajo **no son las de arriba del revés** —llevan su propio remate—, así que van las cuatro en
un PNG de 16×16 en vez de espejar una.

Dice tres cosas seguidas: destello en rojo oscuro al recibir la orden, latido lento entre las dos
aperturas más anchas mientras se acerca, y cierre repartiendo los cuatro fotogramas restantes contra
`get_time_to_impact()` para llegar cerrada al impacto. Sin cuenta atrás —el cañón, una bomba tonta—
se queda latiendo.

**La caja se le pide a la flecha de selección**, no se repite. Es el mismo dato ya medido en las
seis escenas; copiado, el día que se retoque una se queda vieja la otra.

**La flecha y las esquinas dejaron de compartir `visible`.** Antes un solo estado servía para
"seleccionado" y para "es el blanco", así que el objetivo salía marcado igual que quien da la orden,
y son papeles opuestos. Ahora `_selected` manda la flecha y `_targeted` las esquinas.

Y se quitó del todo el rótulo rojo "Atacando: X": lo que dice ya lo dicen las esquinas y el registro
de eventos.

### El arma vacía que nadie volvía a cambiar
Síntoma: el avión enfilaba el blanco, tenía permiso de tiro y estaba en alcance, y no disparaba
nunca. Se quedaba dando pasadas eternas.

Causa: `WeaponSelector` sólo se replantea el arma en dos momentos —al cambiar de blanco, y en un
repaso periódico **acotado a blancos que vuelan**—. Al vaciarse el lanzador, `_on_ammo_changed`
devolvía el mando al automático y ya: contra tierra no había nadie que volviera a preguntar. El
avión seguía con el AGM-65 a cero y dos GBU-54 colgando del ala.

**Devolver el mando no es replantearse.** Ahora `_on_ammo_changed` rearma en el acto. Y el repliegue
de `_rearm_for` pedía "el arma principal" sin mirar si le quedaba algo, así que el avión se acercaba
guiado por un arma gastada: ahora exige munición y deja el cañón para el final.

Lo que despistaba: **cambiar de blanco lo curaba**, porque ese camino sí replantea. Parecía un fallo
del cambio de blanco y era justo lo contrario.

### Una cuenta atrás sin dueño se contagia
`time_to_impact()` devolvía lo primero que fuera a llegar, apuntara a quien apuntara. Al cambiar de
blanco con un misil todavía en el aire, el blanco nuevo heredaba la cuenta del anterior: sus
esquinas se cerraban contra un impacto que iba a ocurrir en otro sitio. Ahora se acota al blanco que
se pregunta. El contador del HUD tenía el mismo contagio y queda arreglado por el mismo sitio.

### Las manos del cursor, y preguntar al panel en vez de a su clase
Cinco formas: flecha, mira, mano señalando sobre algo pulsable, puño semicerrado al pulsarlo, puño
cerrado arrastrando. Las manos son **de la interfaz y sólo de ella**: sobre el mundo ya hablan la
mira y las marcas de las unidades.

- **El cursor averigua solo tres de las cinco.** Si hay un botón debajo y si está pulsado son
  preguntas de interfaz. Las otras dos le llegan de fuera porque no puede saberlas: si hay algo a
  tiro (lo sabe la selección) y si se arrastra una ventana (lo sabe la ventana).
- **Se le pregunta al panel antes de mirar de qué clase es.** Hay paneles partidos por dentro: el
  minimapa se estira por la franja de arriba y se pulsa por abajo, y "de qué clase eres" no puede
  contestar eso. Con un método opcional `cursor_shape_at(local)` cada panel declara sus zonas y el
  cursor no acumula una lista de nombres que mantener.
- **Las manos se anclan por la muñeca, no por el dedo.** Al cerrarse, un puño curva los dedos hacia
  la palma con la muñeca quieta; ancladas por el dedo, la mano pega un salto al pulsar.
- **Se pregunta por el botón físico del ratón, no por el estado del `BaseButton`.** Ese estado es la
  casilla de los conmutados; hoy no hay ninguno, pero el día que lo haya el cursor se quedaría con
  el puño puesto.

El puño semicerrado es también el aviso de que una ventana se puede arrastrar. Es flojo como anuncio
—hay que estar ya encima—, pero la ventana es casi toda zona de agarre y se aprende sin buscarlo. La
alternativa era dibujar rayitas de agarre, y se descartó por no tocar más arte.

### Pendiente: atacar con la aviación del buque
El LHD no lleva armas propias pero **sí puede atacar: con lo que despega**. Queda abierta una
tercera forma de mandar aeronaves desde el menú del objetivo, con el blanco ya puesto. Sin decidir:
si se valida qué vehículo puede atacar ese blanco, si se valida qué armas son eficaces, y qué pasa
si la salida llega y no puede hacer nada.

Provisional: **no validar nada y dejar la opción "Atacar" en el menú** aunque la unidad no tenga
armas. Por eso `_can_attack` y `_can_shoot` están separadas y **no se deben unificar** hasta que
esto se decida.

### Nota de método: una prueba puede mentir
Persiguiendo una zona equivocada del minimapa culpé a `get_local_mouse_position()` de traer
coordenadas del mundo y "arreglé" algo que no estaba roto. El que mentía era el test:
`Input.warp_mouse()` mueve el ratón del sistema y la interfaz lo sigue —el control bajo el ratón
cambia—, pero **si la ventana no tiene el foco, la posición que reporta el viewport se queda
congelada donde esté el ratón físico**. Se estaba midiendo contra un punto que no era. Lo que sí
sirve: probar la regla llamando directamente a la función que la contiene.

## 2026-08-24 — el armamento del SuperCobra: seis pilones, y una fuente que no se envuelve

### Del pilón cuelga el contenedor, no el cohete
El sheet trae el tubo verde y los cohetes dibujados por separado —azul el Hydra, blanco y rojo el
Zuni— y al principio se cortó "tubo + cohete" como una sola imagen. Está mal: **el tubo es el
lanzador**, y lo que se cuelga del ala es él. Los cohetes son lo que sale de dentro.

Así que `agm114_hellfire.tres` cuelga su misil, y Hydra y Zuni cuelgan **el mismo**
`rocket_pod.tres` — un contenedor es un contenedor mire lo que mire dentro. Los dos recortes de
cohete (`hydra70.tres`, `zuni.tres`) quedan guardados sin usar todavía: son los proyectiles del día
que el Cobra dispare.

De paso, los tres recortes nuevos son **ajustados al dibujo** y no tiles de 16×16 como los del
Harrier. El sprite se cuelga centrado en el `Marker2D`, así que un recorte ajustado cae donde se
espera y uno con aire alrededor se descoloca por lo que el dibujo esté descentrado dentro del tile.
El AIM-9 se dejó como estaba: ya vuela en el Harrier y moverlo le cambiaría las alas.

### Dónde se enseña un arma lo decide la carga, no el arma
Apoyo cercano lleva cuatro armas y con las cuatro en fila la ventana tenía que ensancharse. La
solución es subir el AIM-9 junto al cañón — pero **sólo ahí**.

El primer intento puso la marca en el arma (`WeaponType.self_defense`), y eso se la llevó a todas
partes: el Harrier también dejó de enseñar su AIM-9 en la fila, sin que nadie lo pidiera. Un arma
no sabe si en *esta* configuración sobra sitio o falta. Ahora es `WeaponLoadout.self_defense`, y la
rellena una sola de las seis configuraciones que existen.

**La regla general:** cuando algo se ve distinto según el contexto, el que decide es el contexto, no
la cosa. Puesto en la cosa, viaja a todos los contextos.

### Dos fichas en una fila de 126 px: el texto va debajo del icono
El cañón se enseñaba con el icono a la izquierda y tres renglones al lado: 84 px. Sumarle el AIM-9
en el mismo formato pide 63 + 75 = 138, y en esa fila hay 126. No caben, y no es cuestión de
apretar: `SIDEWINDER` gasta 39 px él solo.

Con el texto **debajo** del icono —el formato de las fichas de armamento de abajo— cada una mide 40
y las dos juntas 90, con 10 px de aire entre ellas. Cabe, y además las dos filas se leen como la
misma clase de cosa.

Un intento intermedio las apiló en vertical, una debajo de otra. Funcionaba —el ancho no crecía—
pero gastaba 34 px de alto por evitar 12 de ancho. Se descartó al ver que el formato compacto
resolvía las dos.

### Una `FontVariation` sobre un pixel font lo desdibuja
`ZUNI-127MM` mide 42 px en una ficha de 40. Se intentó apretarle el espaciado con una
`FontVariation` de `spacing_glyph = -1`, midiendo sólo el renglón que se salía. El texto cupo… y
salió **borroso**: envolver la fuente en una `FontVariation` la vuelve a rasterizar sin los ajustes
de importación del `FontFile` original —antialiasing, hinting y subpixel desactivados— y el pixel
font deja de ser nítido.

Se revirtió entero y el arma pasó a llamarse `Zuni-127`: el `127` sí cabía (30 px de 40), era el
`MM` lo que se pasaba. **Cuando un texto no cabe se acorta el texto o se ensancha el hueco; la
fuente no se toca.**

Comprobado contando colores en el render, que es lo único que vale aquí: en toda la zona de texto
hay exactamente tres —fondo, gris y blanco—, o sea cero tonos intermedios.

### El hueco de un modelo cambia de tamaño después de colocarlo
`UnitModel._fit()` centra el aparato contra el tamaño de su hueco, y se llamaba una sola vez, al
elegir la aeronave. Pero la ventana se ensancha **después**, con la animación de despliegue: el
modelo se quedaba cuadrado contra el tamaño viejo y visiblemente escorado a la izquierda.

Ahora se engancha a `resized` y se recoloca guardando lo que ocupa (`_bounds`) en vez de volver a
copiar la escena — el modelo no cambió, sólo el sitio donde cabe.

### Seis pilones en 23 px de ala
Punta, externo e interno por cada lado. El ala del sprite va de −11 a +11 y el fuselaje empieza
sobre ±5, así que quedan unos 6 px de ala expuesta por lado para tres estaciones de 4 px de ancho:
rozarse es inevitable. Quedaron en ±12 / ±10 / ±7, todas a y = 6 para que las armas straddleen el
ala en vez de asomar por arriba.

Las cifras son `Marker2D` de la escena, no números del código: se ajustan arrastrando.

**Dos verdades que ya estaban en el rack y aquí se cobraron:** la munición de una estación
(`per_station`) no tiene nada que ver con cuántos sprites caben —del externo cuelga **un** Hellfire
y se disparan cuatro—, y por eso un contenedor con 19 cohetes es un solo dibujo. Y las posiciones
sólo se pueden juzgar **mirándolas**: con el fuselaje encima, el dibujo del ala tiene detalles
verdes y oscuros que se confunden con las propias armas, así que hubo que renderizar el aparato con
el cuerpo oculto para ver de verdad qué colgaba de dónde.

## 2026-08-24 — el hangar completo: ficha de aeronave, armamento y despegue con orden

### Una orden dada antes de despegar se da **antes** de soltar el aparato, no después
El botón "SELECT TARGET AND TAKE OFF" abre el mapa táctico, el jugador señala, y la salida despega
ya con esa orden. La primera versión la aplicaba en `FlightDeck._hand_over_control` **después** de
`start_flight()`, y el avión decía "Atacando X" en el registro mientras se iba tranquilamente al
circuito de espera del barco. La causa: `start_flight` del Harrier sólo monta el circuito
`elif not orbit.has_pending_order()` — mira si ya hay blanco, y en ese instante todavía no lo había.
La orden que llegaba después iba por `set_attack_target()`, que **sólo anota a quién y avisa**; el
que monta la maniobra es `receive_attack_order()`, y ese tren ya había pasado. Por eso el arma sí
apuntaba —le llegó el blanco— y el vuelo no.

Las dos aeronaves ya estaban escritas para recibir la orden en cubierta: el Harrier respeta un
destino ya puesto, y `HelicopterController.set_target` contempla que llegue mientras el barco lo
está colocando. **La regla general**: cuando dos sistemas se pasan el control (cubierta → piloto),
el estado se entrega antes del relevo, no después — después, el que recibe ya tomó sus decisiones
con el estado viejo y sólo se le puede cambiar el rótulo.

Y se anota con `set_attack_target` y no con `receive_attack_order`: en cubierta no hay piloto con
el que hacer la maniobra, así que se guarda a quién y el aparato la monta al arrancar.

### La orden pendiente la guarda la cubierta, no el avión
Entre pulsar "despegar" y volar hay ascensor, taxi y carrera de pista: **la unidad ni siquiera
existe cuando se elige el blanco**. `FlightDeck` guarda la orden en un diccionario por id de
instancia y la consume en `_hand_over_control`. Dársela al avión nada más aparecer sería peor que
no dársela: mientras la cubierta lo lleva a su sitio no se pilota, y una orden de movimiento
pelearía contra el propio taxi.

### La ventana mide lo que mide su contenido, en los dos ejes
`HangarPage` emite `size_wanted(width, height, seconds)` y `VesselWindow` le suma su marco. Tres
alturas —sin aeronave, con aeronave, con armamento elegido— y dos anchuras, según quepan dos fichas
de arma o tres. Detalles que costaron un intento cada uno:

- **El alto no tiene mínimo y el ancho sí.** A lo alto la ventana se pliega hasta esconder bloques
  enteros, así que bajar de lo dibujado es justo lo que se le pide; a lo ancho no se esconde nada
  —la ficha del avión sigue ahí— y lo dibujado es el suelo.
- **Crece hacia la derecha y hacia abajo**, con el borde superior izquierdo clavado: así las
  solapas, la pestaña del título y las columnas de botones no se mueven ni un píxel. Ensanchar por
  el centro las movería todas y el cambio se notaría mucho más de lo que cuesta.
- **El panel y la ventana crecen a la vez y en el mismo tiempo.** El recorte (`LoadoutClip`, un
  `Control` con `clip_contents`) va por el alto de la página: si el panel fuera más deprisa asomaría
  por abajo, y más despacio dejaría ver el fondo de la ventana bajo él.
- **`clip_contents` recorta el dibujo, no el ratón.** Un botón fuera del recorte se deja pulsar
  igual, así que al plegar hay que esconderlo de verdad al terminar la animación.

### Un panel que se despliega guarda **lo que hay ahora**, no el hueco de lo que podría haber
Antes de elegir armamento, el bloque llega hasta el último botón y nada más; al elegir, se estira y
salen el cañón, las fichas de armas y los dos botones de despegue. Reservar el hueco y esconder lo
de dentro se lee como que algo se rompió, no como que falta elegir. Las dos medidas se sacan de los
`offset` de la escena —la grande es la que trae puesta el nodo, la pequeña llega hasta donde acaba
la columna de botones—, así que moverlo en el editor sigue mandando sobre el número.

### El armamento sale de `WeaponLoadout`, y el duplicado que metí en `UnitType` se borró
Llegué a añadir `loadouts: PackedStringArray` al tipo de unidad sin ver que ya existía
`av8b_harrier_loadouts.gd` con las configuraciones de verdad: estaciones, armas y cantidades. Godot
reescribió el `.tres` sin ese campo y pareció que "se habían borrado los loadouts". Lo correcto es
`PlayerFleet` → `entry["weapon_loadouts"]`, que además vienen **ya filtradas por las armas que el
jugador tiene**. Las tres del Harrier se renombraron a los nombres de la UI (`AIR TO AIR`,
`BOMBARDMENT`, `LASER GUIDED`) en su propio archivo, para que no haya dos sitios donde mirar.

Las fichas se **agrupan por arma y no por estación**: el AIM-120 va en la central y en la interna,
dos montajes de dos, y al jugador lo que le importa es que van cuatro. La cuenta la da
`WeaponLoadout.ammo_of()`, la misma de la que tira el avión en vuelo.

### El modelo del hangar son los `Sprite2D` de la unidad, copiados
`UnitModel` instancia la escena de la aeronave, copia sus `Sprite2D` con sus transformaciones y
suelta el original. Nunca entra en el árbol, así que **no corre ningún `_ready`**: la unidad no se
registra en ningún sitio ni queda nada colgando. Una aeronave nueva se ve aquí el día que exista sin
tocar el archivo. Dos cosas que salieron de hacerlo:

- **El rotor quieto no se lee.** Está dibujado como una barra recta porque en el juego gira; a 0°
  cae encima del fuselaje y parece un mástil. Se le da una pose de 45° **sólo para el retrato** —el
  original no se toca— y ahí se ven las dos palas.
- **Lo que ocupa se mide por las cuatro esquinas giradas**, no por ancho × alto: con el rotor
  ladeado la caja real es mucho mayor que la del dibujo, y midiendo de la otra forma se sale del
  hueco. Con eso, Harrier (48×48) y Cobra (37×49) entran a 1:1 en un hueco de 92×60.

### `power` es una nota, no una estadística
Diez dibujos de barra en `UI.png`, medios pasos incluidos, y un `@export_range(0, 9)` en `UnitType`.
**El valor es el fotograma**: no hay escala que convertir ni relleno que calcular, sólo mover la
ventana de un `AtlasTexture`. No lo lee nada del juego — existe para comparar dos aparatos de un
vistazo sin leerse una tabla. `cannon_rounds` va por el mismo camino pero en la aeronave y no en el
arma: no es propiedad del cañón sino de lo que le cabe al aparato.

### Lo que se llena en marcha se guarda **puesto** en la escena, y lo apaga el código
La ficha del avión y el bloque de armamento nacían ocultos, así que en el editor eran rectángulos
invisibles imposibles de colocar. Ahora se guardan visibles y con datos de muestra —tres botones de
armamento, una ficha de arma, y un `@export var preview: PackedScene` con `@tool` que dibuja un
Harrier de verdad dentro del hueco del modelo—, y es `_ready` quien decide qué se ve al arrancar.
La casilla del inspector deja de ser la autoridad sobre la visibilidad, y a cambio el editor enseña
lo que se está diseñando.

### Comprobar la fuente **antes** de escribir el texto, no después
Tres veces en la misma sesión: la `x` minúscula de "x300" no existe (salía "300" a secas, se pasó a
`X300`), `%` y `<` `>` no existían hasta que se actualizó la fuente, y el guion de `AV-8B` está
dibujado en la fila del pie —a la altura de un subrayado—, que parecía un bug del código y era el
glifo. **Rasterizar el mapa de caracteres es más rápido que discutir la captura de pantalla.** Así
apareció también el cursor: el cuadrado macizo de 3×5 vive en `U+00AA`, y se escribe por su código
de escape para que no dependa de con qué se guarde el archivo.

### El cursor parpadea por alfa, no escondiéndose
Vive en un `HBoxContainer` centrado junto a "CONTINUE": ocultarlo encogería la fila y el texto se
movería medio carácter en cada parpadeo. Medio segundo por mitad, el ritmo de un cursor de terminal.
Y sale **sólo con el aviso que pide algo**: `NO LOADOUTS AVAILABLE` y `NO WEAPONS FITTED` van sin
él, porque un cursor donde no hay nada que pulsar es una promesa falsa.

### Reparentar un nodo en un `.tscn` a mano: hay que cambiar **su** `parent`, no el de sus hijos
Al meter `Cards` y `Prompt` dentro del envoltorio `Weapons`, un script de reemplazo cambió las rutas
de sus hijos y no las suyas: los hijos apuntaban a padres inexistentes y el juego reventaba en
`@implicit_ready`. Y en el segundo intento se colaron sus `offset` absolutos viejos, que ya dentro
del envoltorio los empujaban 82 px a la derecha. **La comprobación que lo caza**: cruzar cada `$ruta`
de los scripts contra los `[node name=... parent=...]` del `.tscn`. Dar por buena la salida de un
script de texto no es verificar.

## 2026-08-23 — la ventana del buque: cámara que aparta el foco y el primer marco jugable

### `Intento de UI final.png` se borró tras comprobar que nada la referenciaba
Antes de borrarla, un `grep` de todo el proyecto por su nombre de archivo dio cero resultados
fuera de su propio `.import`. Esa es la pregunta correcta — **"está en el sheet viejo" no es lo
mismo que "está en uso"**: para entonces ya todo lo migrado vivía como archivos propios
(`portrait_frame.png`, `weapon_button.png`, los iconos de arma...), extraídos una vez y sueltos del
origen. El icono del LHD (`icon_lhd.png`) se volvió a extraer desde el `UI.png` ya actualizado,
16×9, centrado en el mismo canvas 20×20 que ya usan AH-1W y AV-8B.

### El desvío de cámara vive en `offset`, no en `position`
Al abrir la ventana del buque, la cámara aparta el foco a un lado (`PanCamera.focus_offset`,
animado con un `Tween`) para dejarle sitio al panel. La primera versión lo sumaba dentro de
`position`, en el mismo `if follow_target != null` que hace el seguimiento normal. Se rompía al
cerrar con Escape: deseleccionar suelta `follow_target` en el mismo instante que se pide la vuelta
al centro, y sin objetivo el `_process` salía antes de tocar nada — la cámara se quedaba **congelada
a medio camino para siempre**. La condición correcta: `offset` es independiente de a quién se siga,
así que el desvío se deshace aunque no haya nadie que seguir.

### Cerrar de golpe si se cambia de unidad; despacio si sólo se suelta
`VesselWindow.close(instant: bool)` y `PanCamera.pan_focus(offset, duration)`: cambiar de unidad
selecciona a otra en el mismo gesto — la vista ya está saltando a otra parte del mapa, y una
transición larga encima del salto sólo lo emborrona, así que ahí `duration = 0`. Soltar la unidad
(Escape, botón ×) no mueve la vista a ningún sitio nuevo, así que ahí sí conviene que se note: 0,9 s,
más lento que los 0,6 s de la ida a propósito, porque a la ida hay un panel apareciendo que se lleva
la atención y a la vuelta no hay nada que mirar.

### La ventana se arrastra entera, sin barra de título
En vez de un `TitleBar` dedicado con `mouse_filter = STOP` (el patrón de `HangarWindow`), todo el
decorado de `VesselWindow` —los tres marcos nine-patch y la pestaña del título— quedó en `IGNORE`,
y `_gui_input` vive en la raíz. El clic que ningún hijo detiene cae hasta ahí, así que se arrastra
desde cualquier borde o desde la pestaña "HANGAR", y las solapas y casillas (que sí paran el ratón)
siguen pulsándose normal. Costó un bug real al verificarlo: la primera versión leía
`get_global_mouse_position()`, que consulta el singleton `Input` y no siempre va sincronizado con
el evento que se está atendiendo — el desvío salía siempre en cero. La posición correcta es la que
trae el propio evento (`event.global_position`).

### `UnitType.hangar_icon`: otro dibujo, no el mismo achicado, con relleno automático
La miniatura de la casilla del hangar se ve a 13 px; el `portrait_icon` del panel de desplegadas se
ve a 20. Bajar el segundo destruiría detalle, así que es un campo nuevo y aparte. Vacío, la casilla
cae en `portrait_icon` como relleno reconocible — es lo que pasa hoy con el AH-1W SuperCobra, que
no tiene miniatura propia todavía — y el día que se dibuje, sólo hay que rellenar el campo.

### Las casillas de aeronave salen de `PlayerFleet.get_loadout()`, no de una lista fija
`HangarPage` construye una casilla por cada entrada de la flota del buque abierto, con su
`total`/`deployed` real. Nada se escribe a mano: si la flota gana una tercera aeronave, aparece
sola en la rejilla de 2 columnas.

### Aparte, un aviso de método: un `SubViewport` creado por código no hereda el filtro Nearest del proyecto
Varias capturas de verificación de esta sesión salieron con las costuras de los nine-patch algo
blandas — colores fuera de paleta en los bordes que no estaban en el arte. La causa no era el
arte: un `SubViewport` instanciado desde un script arranca en filtro **Lineal** aunque
`project.godot` tenga `default_texture_filter = Nearest`, ese ajuste no se hereda. Se corrige
poniendo `canvas_item_default_texture_filter = NEAREST` en el propio `SubViewport` de prueba. Sin
eso, una comprobación puede darse por buena con un desenfoque que el juego real nunca tuvo.

## 2026-08-23 — fuente pixel propia (Yellow Pixel Font), botón "Comandar" y panel de unidad seleccionada

### Un font casero puede fallar en el mapa de caracteres, no sólo en el tamaño
La primera exportación con `ase2ttf` de la fuente hecha en LibreSprite se veía "borrosa" en el
juego. No era blur: pedir el carácter `0` dibujaba la `Q`, pedir `6` dibujaba la `W` — cada
carácter salía desplazado **33 posiciones** en la tabla, siempre en la misma dirección. La causa:
`ase2ttf` numera los glifos de la grilla a partir del código Unicode que dice el nombre de la capa
en el `.aseprite` (`U+0020-…`); la grilla del usuario empezaba directo en la `A` pero la capa seguía
declarando el arranque en el espacio, así que todo el alfabeto quedó corrido. El tamaño nativo
(8 px, y sus múltiplos 16/24) nunca fue el problema — eso se comprobó aparte, rasterizando, y dio
limpio desde el primer intento.

Para cualquier fuente casera nueva: además de comprobar tamaño nativo e importación (antialiasing/
hinting/subpixel en cero), hay que **pedirle un alfabeto completo y mirar si cada letra sale donde
corresponde** — un mapa de caracteres roto no se nota goteando, se nota como "se ve mal" y engaña
hacia el tamaño o el import.

### La fuente nueva no tiene minúsculas
Los códigos de `a` a `o` están vacíos (el diseño los reserva para vocales acentuadas mayúsculas).
Cualquier texto que use esta fuente va en **mayúsculas** — así quedó "COMANDAR" en el botón nuevo,
a juego además con el resto de rótulos del kit (HANGAR, ATTACK…).

### El botón "Comandar" se arma de piezas sueltas de `UI.png`, no de una textura fija
El botón vivía como `TextureButton` con una sola imagen de 96×25 que traía el ancla y la flecha ya
dibujadas encima, fija. Ahora el fondo es un `StyleBoxTexture` (píldora de 3 celdas, tramo del medio
liso — se estira sin problema) sobre un `Button` normal, con el ancla como ícono aparte **fuera**
del botón (cuelga de él con offset negativo, así se mueve gratis) y el texto en Yellow Pixel Font a
16. Al presionar, ancla y texto cambian juntos a un tono apagado (`button_down`/`button_up` en
`unit_tag.gd`) porque el `StyleBoxTexture` sólo cambia el fondo por su cuenta.

### `UI.png` separa sus tiles con 1 px transparente — es una guía, no se conserva
Todo el kit viene como rejillas de tiles de 16×16 con 1 px de hueco entre cada uno, para que se
distingan a simple vista dentro del sheet. Si se recorta y monta tal cual, ese hueco queda como una
raya rota en medio del panel. Hay que **quitar el hueco al recomponer** — los tiles pegados, sin
separación — antes de usarlos como nine-patch. Costó dos vueltas notarlo bien; queda anotado en
`assets/art/UI/UI.png` como advertencia para la próxima pieza que se saque de ahí.

### El panel de la unidad seleccionada usa dos nine-patch nuevos, y M5X7 en vez de m6x11plus
`selection_box.png` (una sola textura fija) se reemplazó por dos piezas de `UI.png` recompuestas sin
el hueco de guía: `panel_thumb.png` (cámara) y `panel_name.png` (nombre), cortes de nine-patch a 16
px — el tamaño del tile —, pegadas sin separación entre sí. La cámara pasó de 93×59 con 2 px de aire
a 82×52 con 9 px, y el nombre gana el mismo margen.

De paso se comparó la fuente del nombre contra M5X7: mismo ancho por letra que m6x11plus (ambas
nativas a 16), pero trazo más fino — se ve mejor contra el panel nuevo y quedó como la fuente del
`Name`.

### Falta migrar el resto de `UI.png`
Quedan sin usar: play/pausa y zoom (mismo tamaño que los iconos actuales, swap directo), marcos de
retrato 24×24 normal/seleccionado, siluetas de unidad gris/blanco, armas del Harrier para el
`weapon_bar`, iconos de carga, y varios juegos de panel tileable sin asignar (candidatos para
`event_log`, `hangar_window`, `target_menu`, `actions_panel`, `countermeasure_bar` — hoy estos tres
últimos son `StyleBoxFlat` sin arte). También hay una versión tileada del panel del minimapa, al
lado de la del panel de unidad, por si `minimap_panel.png` da problemas al estirar.

## 2026-08-17 — el HUD pasa a ser arte: iconos en vez de nombres, y lo que cuesta repetir mal

### Los botones de arma enseñan el arma, no su nombre
La barra fabricaba un `Button` por arma con un `StyleBoxFlat` gris y la designación escrita
dentro a tamaño 7. Ese 7 no se eligió: se llegó a él bajando la fuente hasta que `AGM-65` cupiera
en 30 px, y 7 es justo donde las mayúsculas dejan de distinguirse. O sea que el botón era ilegible
por construcción.

Ahora cada botón lleva **el dibujo del arma** sobre el PNG del botón, y la designación exacta se
va al tooltip. Una silueta se reconoce sin leerla, así que el problema del ancho desaparece en
vez de resolverse: no hay texto que quepa o deje de caber.

Es el mismo movimiento que ya se anotó el día anterior —«si algo no cabe legible, no va ahí»—
aplicado al sitio donde de verdad dolía.

### Un icono puede desbordar su botón; recortarlo para que quepa lo mutila
Los dibujos de arma son verticales y llegan a 33 px; la cara del botón mide 32. El primer intento
los centró dentro de un lienzo de 32×32, y el AIM-120 perdió la punta y la cola — un píxel por
lado que era justo lo que lo distinguía de los demás misiles.

La regla que se aplicó mal venía de la miniatura de unidad, donde un píxel fuera del marco **sí**
es un fallo. Pero ahí es una ventana de cámara con un borde que la enmarca; aquí es un icono
dibujado *encima* de un botón, y que asome es normal en un HUD. **Antes de recortar hay que
preguntarse si el borde es un marco o sólo un fondo.** Ahora los iconos van en lienzo de 32×34 y
sobresalen 1 px por arriba y por abajo.

### Apagar un botón con `modulate` apaga también lo que dice
Las armas no elegidas se atenúan al 50 %. Hecho con `modulate` se atenuaba **el nodo y toda su
descendencia**, así que la cantidad —`x2`, `x12`— salía translúcida sobre el cielo y no se leía.

Con `self_modulate` se apaga sólo el dibujo del propio nodo y los hijos quedan intactos. La
distinción importa siempre que un elemento apagado siga teniendo que **informar**: el arma
agotada se ve casi borrada, pero su `x0` se lee igual que el resto.

### La cantidad va en `xN` y a 16, y por eso sobresale del botón
A 8 las cifras miden 4 px y no se leen; a 16 miden 9. Con `x300` eso son 24 px de ancho, que no
caben en un botón de 32 con un icono dentro — así que **sobresale por la esquina inferior
derecha**, con borde oscuro de 2 px porque el número cae sobre el cielo cuando la barra queda
sobre mar abierto.

Es la aplicación directa de la lección del día anterior: el número manda sobre el hueco, y cuando
no cabe se saca fuera en vez de encogerlo.

### Los retratos vuelven a 24 px, con siluetas redibujadas y no reducidas
Las de 32×32 achicadas a 16 perdían tres de cada cuatro píxeles. Las nuevas son **otro dibujo**,
con la silueta simplificada a propósito y centradas en un lienzo de 20×20, que es la ventana del
marco de 24. El cuadrito completo mide 24×39.

El ancho de 24 tampoco es redondeo: la fuente del nombre gasta 8 px por letra y el nombre son tres
caracteres. Nueve desplegadas ocupan 232 px de 640 en vez de 376.

### La línea de la etiqueta se alarga repitiendo, no estirando
La animación de despliegue son 10 fotogramas de 36 px, y el nombre más largo pide 104. Estirar la
textura habría engordado el trazo de 1 px a 3.

No hizo falta arte nuevo: de los 36 px del último fotograma, sólo los 10 primeros son dibujo —la
diagonal— y las 26 columnas restantes son idénticas entre sí. Un nine-patch en modo mosaico las
repite y el trazo sale igual mida lo que mida.

**La animación dibujada no se toca**: se reproduce entera y, cuando se acaba, un segundo trozo
sigue creciendo desde ahí. El empalme no se ve porque va al mismo ritmo, y ese ritmo **se midió,
no se eligió**: el trazo avanza 4 px por fotograma a 24 fps, o sea 96 px/s. El retraso tampoco es
un número escrito a mano — es la duración de la propia animación, fotogramas partidos por su
velocidad, para que retocar la tira no deje esto desincronizado.

### El corte de un nine-patch lo decide la curva, no el borde que se ve
La bandeja de la barra de armas se dibujó dos veces, una encima de otra, y el motivo fue medir el
corte superior a ojo: el remate parecía de 3 px —borde oscuro, brillo, medio tono— y se puso 3.

Pero **las esquinas redondeadas bajan 15 filas de las 24 que mide el panel**. Con el corte en 3,
todo lo que hay entre la fila 3 y la 14 —la curva entera— caía en zona repetible y se volvía a
pintar más abajo.

La regla ya estaba escrita en `CLAUDE.md` y aun así se saltó, así que se anota el matiz que
faltaba: **el tramo repetible se busca, no se estima**. Filas idénticas a la anterior, columnas
idénticas a la anterior; donde empieza el tramo contiguo, ahí está el corte. Un borde plano en el
centro no dice nada de lo que hacen las esquinas.

### La etiqueta de selección se aparta según lo grande que sea la unidad
Está colocada contra un avión de 23×53 y sobre el LHD, que mide 160 de manga, caía dentro del
casco. Se resolvió con `UnitType.tag_offset`, un desvío que **se suma** a la colocación de la
escena y que sólo tocan las unidades grandes — el Wasp lleva 80, el resto cero.

No se dedujo del sprite a propósito: el dibujo dice cuánto ocupa, pero no por qué lado hay sitio
libre ni cuánto aire pide cada unidad. Eso es una decisión de composición, no un dato.

### Una puerta a otra pantalla no es una "acción"
El "Hangar" del LHD vivía en `UnitType.actions`, la lista de textos que el panel de acciones
convierte en botones sueltos. Pero una acción es una orden que se le da a la unidad y se resuelve
sola; esto es la entrada a otra pantalla —hangar, pañol, tropas—, tiene arte propio, sitio propio
en el HUD y sólo puede haber una.

Ahora es `UnitType.has_interior`, un booleano, y el botón vive en la etiqueta de selección. Dejarlo
en la lista lo habría devuelto a dibujarse como un botón de texto más.

El botón se llama **"Comandar"**. Nombra lo que haces, no el objeto que tienes delante. Y la
etiqueta no sabe qué hay dentro: emite `boarding_requested` y es el HUD quien decide que hoy eso
abre la ventana de hangar.

### "En espera" en verde, y en el mismo verde
El estado usa `#91db69` de Resurrect64, que es **el verde que ya usaba la barra de vida de los
retratos**. Reutilizarlo en vez de elegir otro parecido hace que "está bien" tenga un solo color en
todo el HUD.

### El fondo de la barra de armas se dimensiona a las armas que haya
La bandeja mide `n × 32 + (n−1) × 6 + 12` y se centra bajo la fila, así que una unidad con un arma
la tiene de 44 px y otra con cinco de 196. Que cambie de tamaño entre unidades no se nota porque
**desaparece al deseleccionar**: nunca se ven dos seguidas para comparar.

Se calcula en vez de preguntárselo al `HBoxContainer`, que no sabe su tamaño hasta el frame
siguiente — esperar dejaría un fotograma con la bandeja de la unidad anterior.

Obligó a **reestructurar la escena de la barra**: un `HBoxContainer` coloca a todos sus hijos en
fila y ahí no cabe un fondo. La raíz pasó a ser un `Control` con la bandeja primero (o sea detrás)
y la fila después. La API que usa el HUD no cambió.

## 2026-08-16 — cámara en vivo de la unidad, retratos a tamaño nativo y el coste del texto

### El texto en 640×384 cuesta 7 px de alto y 6 por letra, y ese número manda sobre el arte
La lección más cara de la sesión, y se pagó en un botón de 36 px. **Por debajo de 7 px de alto
una mayúscula tiene trazos de 4 px y deja de distinguirse**: `GBU-54` y `GAU-12` se confunden.
Eso fija un suelo que ninguna fuente esquiva, porque no es cuestión de elegir mejor sino de
cuántos píxeles tiene una letra.

De ahí sale el presupuesto de cualquier etiqueta, medido con M5X7 a 16:

| texto | hueco que necesita |
|---|---|
| `AIM-120` (7 caracteres) | 44 × 11 |
| `MK82` (4 caracteres) | 25 × 11 |
| `x12` | 18 × 11 |

**El error de método fue dibujar el hueco primero y meter el texto después.** Con pixel fonts va
al revés y sin excepciones: se mide lo que ocupa el texto, ese número es el tamaño mínimo del
elemento, y el arte se dibuja alrededor. Se perdieron tres iteraciones agrandando y encogiendo
un botón porque nadie había puesto ese número sobre la mesa.

Y la salida cuando aun así no cabe **no es encoger la fuente: es quitar el requisito**. Un botón
de arma de 36×35 no necesita decir `AIM-120` — necesita que se reconozca el misil y se lea
cuántos quedan. El nombre va donde hay sitio. Si algo no cabe legible, es que no va ahí.

### M5X7 a 8 es nítida y aun así no sirve para leer
Rasterizada a 8, cada trazo cae en 1 px sólido: es tamaño nativo legítimo, no está remuestreada.
Pero sus mayúsculas miden **4 px de alto**, y a esa altura las letras dejan de ser distinguibles.

La lección corrige a medias una regla anterior del proyecto: **que un tamaño sea nativo dice que
saldrá limpio, no que se pueda leer.** Son dos comprobaciones distintas y hay que hacer las dos —
rasterizar para ver si está limpia, y mirar una palabra real para ver si se entiende.

### La miniatura de la unidad seleccionada es una cámara al mundo, no un retrato
El hueco de la caja lleva un `SubViewport` que comparte el `World2D` de la partida y apunta a la
unidad elegida. Se la ve moverse, girar y disparar en directo con sus efectos, porque es la misma
unidad del mapa vista desde otro sitio.

**Se queda sola en el cuadro por invitación, no por exclusión.** Ocultar el terreno y las demás
una por una sería una lista interminable que habría que mantener cada vez que se añade algo. En
vez de eso la miniatura mira una capa que nace vacía (`canvas_cull_mask`), y al seleccionar se le
presta esa capa a la unidad. Todo lo demás queda fuera por no estar invitado.

Dos cosas que sólo se descubren estrellándose:

- **El descarte del canvas es por rama, no por nodo.** La unidad tenía la capa y el cuadro salía
  negro, porque su padre no la tenía y cortaba por arriba. Hay que prestársela también a los
  ancestros — y eso no cuela el terreno, que es hermano de la unidad y sigue sin capa.
- **Lo que cuelga de la unidad entra gratis, y eso incluye lo que estorba.** Los anillos de
  alcance del 2S6 llenaban el cuadro de puntos verdes. Se resuelve con un grupo (`sin_miniatura`)
  que se marca en la escena, para que sacar algo más no obligue a tocar código.

### La cámara de la miniatura NO se redondea a píxel entero
Parece que redondear da nitidez y aquí hace lo contrario. Esta cámara no mira un escenario
quieto: **viaja pegada al objeto que enfoca**. Cuadrarla a la rejilla mientras la unidad avanza en
decimales deja entre las dos una diferencia que cambia cada frame, y la unidad vibra dentro del
cuadro. Pegada a ella sin redondeos la diferencia es constante y la imagen se queda clavada.

Verificado moviendo un tanque en pasos decimales durante 20 frames: el dibujo ocupó **un solo
sitio en los 20**. Con redondeo saltaba en todos.

### Centrar bien es lo que decide cuánto zoom aguanta una unidad
El Cobra no cabía a 1:1 y las palas asomaban por el borde. La causa no era su tamaño: la cámara
apuntaba al fuselaje, y el rotor cuelga desplazado en `(1,6)`, así que el conjunto barría un
círculo de 59 px alrededor de un centro que no era el suyo — justo el borde de la ventana.

Apuntando al **centro del círculo envolvente más pequeño** de todas sus piezas, el mismo
helicóptero barre 56 px y entra de sobra. Cada pieza entra como círculo y no como rectángulo
porque aquí todo gira: la unidad entera, y el rotor además por su cuenta.

La diferencia no es cosmética: con el centro corrido 2 px, el Cobra pasa de media escala a 1:1.
**Centrar bien es lo que decide si una unidad se ve entera o hay que tirar medio dibujo.**

Medido girando las seis unidades en 36 rumbos cada una: cinco de seis a 1:1 sin tocar el borde en
ningún rumbo; sólo el LHD baja a 1/4, y ahí no hay nada que hacer porque mide 247 px girando.

### Los retratos vuelven a tamaño nativo: reducir arte figurativo lo destruye
Se venían achicando el marco (38→22) y las siluetas (32→16) para que diez desplegadas no comieran
la pantalla. El resultado se veía mal por una razón sencilla: **un icono de 32×32 bajado a 16×16
pierde tres de cada cuatro píxeles.** El «1» de la cubierta del LHD desaparece, la cuadrícula del
borde se vuelve una línea sucia y el rotor del Cobra queda en un palito. Por bien que esté dibujado
a 32, a 16 no cabe esa información.

Se anula el escalado: retrato de **38×53** (marco 38×38, silueta 32×32). Con nueve desplegadas
ocupa 376 px de 640 (59%) y llegan a caber unas quince.

La regla general: **el pixel art se dibuja al tamaño en que se va a ver.** Si hace falta más
pequeño, se dibuja otra versión simplificando la silueta a propósito — no se encoge la grande.

### Agrupar retratos por tipo se descartó: es una solución que se rompe al crecer
Se propuso una casilla por tipo con contador (`AH1 ×4`) para recuperar espacio. **Mala idea en un
juego en desarrollo**: hoy hay seis tipos y va a haber muchos más, así que el ahorro desaparece
justo cuando más falta hace. Queda anotado para no volver a proponerlo.

### Al depurar, no filtrar los errores de script de la salida
Se perdió un buen rato persiguiendo un fallo fantasma —«se sale en 36 de 36 rumbos»— que en
realidad era el panel corriendo **sin script**, porque una variable mal tipada impedía compilarlo.
Los `grep` de las sondas venían descartando `SCRIPT ERROR` para limpiar ruido. Un panel sin script
no da error visible: se comporta como un nodo vacío y todo lo que se mide sale mal.

## 2026-08-15 — botones con icono y caja de unidad seleccionada

### Pausa y zoom pasan a icono dibujado, y el arte que cambia con el estado va exportada
Los tres botones eran `Button` con texto (`+`, `-`, `||`). Ahora son `TextureButton` con el
arte del usuario. La versión oscura de cada icono entra como `texture_pressed`, que Godot ya
enseña solo mientras se mantiene el clic — no hay que programar nada.

El botón de pausa **sigue enseñando la acción y no el estado** (corriendo se ve la pausa,
pausado se ve el play), que es lo que ya hacía con texto. Lo que cambió es de dónde salen sus
cuatro iconos: empezaron como `preload` dentro del script y **eso fue un error que el usuario
detectó a la primera** — desde el inspector no se podía cambiar ninguno. Pasan a cuatro
`@export`.

De ahí el corolario de "lo que se ve se construye como escena": **si un nodo cambia de arte
según su estado, todas las variantes van exportadas, no sólo la que se ve al arrancar.** Con
`preload` la escena miente: enseña una textura que el script sustituirá.

Las lupas no traen versión oscura, así que el estado "ya no queda zoom" se resuelve bajando el
`modulate` al 30% en vez del `StyleBoxFlat` que llevaban antes.

### El editor no relee una escena instanciada dentro de una pestaña abierta
Al cambiar los `.tscn` desde fuera, Godot reimportó los PNG nuevos él solo —los `.ctex` se
generaron— pero el HUD seguía enseñando los botones de texto. No era caché de texturas: es que
**una escena instanciada dentro de una pestaña abierta se sirve del `PackedScene` en memoria**,
y ése no se relee. Recargar la pestaña del padre tampoco basta.

Se arregla con *Proyecto → Recargar Proyecto Actual*. Queda apuntado porque costó una vuelta
entera de "está roto / no, está bien" y volverá a pasar cada vez que se editen escenas fuera
del editor.

### La caja de la unidad seleccionada no se dimensiona al sprite — el zoom se dimensiona a la caja
El error más caro de la sesión, y lo cazó el usuario: se estaba eligiendo el tamaño de la caja
para que las unidades cupieran a 1:1. **Es imposible por construcción.** Medido:

| unidad | sprite |
|---|---|
| AH-1W SuperCobra | 23×53 |
| 2S6 Tunguska | 24×35 |
| AV-8B Harrier II | 48×48 |
| **LHD Wasp** | **160×304** |

Entre el helicóptero y el barco hay un factor de 8. Ninguna medida sirve para los dos: la caja
que enseña el LHD entero deja el helicóptero como un punto, y a la inversa. A 0,125x el LHD
queda en 20×38, que no es un barco sino una mancha.

La causa del error fue aplicar a los sprites la regla que sólo vale para las fuentes —*"es el
hueco el que tiene que adaptarse al texto"*—. **No vale, y la diferencia es que una fuente no
escala y un sprite sí** (por potencias de dos, que es lo que permite la regla de escala entera
del proyecto). Así que el orden es el inverso: **el tamaño de la caja lo decide cuánto de los
640×384 se quiere gastar, y el zoom por `UnitType` ajusta cada unidad.**

Y la segunda mitad de la lección: **la miniatura no tiene por qué enseñar la unidad entera.**
Es una cámara en vivo, no un retrato. El LHD recortado —un trozo de cubierta con la isla— dice
"esto es un barco grande" mucho mejor que el mismo barco entero y diminuto.

### Apretar la fuente para que quepa un nombre estropea todos los demás
La banda del nombre quedó en 91 px de hueco y `AH-1W SuperCobra` mide 95 con M5X7 a 16. Se dijo
que los 4 px se absorbían apretando 1 px el espaciado entre letras. **Compuesto y mirado, era
falso:** con `spacing_glyph = -1` las letras se pegan unas a otras y `AH-1W` o `Tunguska` se
leen como un borrón. Se habían empeorado los seis nombres para arreglar uno.

Quedó apretando **sólo el nombre que se sale**, midiendo contra el ancho del propio Label
—no contra un número escrito en el script, para que mover el Label en el editor siga
valiendo—. Cuatro de seis salen con espaciado natural; se aprietan `AV-8B Harrier II` (88) y
`AH-1W SuperCobra` (95) contra 85 de hueco útil.

Es un remiendo declarado como tal en el código. **La salida limpia son 10 px más de ancho de
banda** (hueco de 101), y entonces la condición no se dispara nunca. Lo que no se hizo, otra
vez, fue acortar el nombre: la regla del parte de eventos sigue valiendo — el ancho se arregla
por la caja, nunca por el mensaje.

Nota de método que se repite: **los tres hallazgos de esta entrada salieron de renderizar y
mirar**, no de leer números. Los 88 px de `AV-8B Harrier II` "cabían" en 91 y en pantalla el
texto tocaba los dos filetes.

## 2026-08-15 — registro de eventos

### El parte no lleva íconos, ni filete, ni fondo: sólo texto y aire
Los cuatro PNG de la columna izquierda se cambiaron por una **marca de un carácter** (`>` orden,
`*` ataque, `!` alarma, `X` baja propia, `+` derribo). Al ser texto entra en el flujo del
renglón: no hay columna que alinear, ni ícono que se quede arriba cuando la línea parte en dos,
y a 8 px un dibujo tampoco distinguía cinco cosas. Los PNG siguen en `assets/art/UI/` sin uso.

El filete de 112×1 px se quitó por dos razones que se refuerzan: **no hay ancho que le cuadre**
—cada renglón mide una cosa distinta— y se apagaba junto con la entrada, así que dejaba un hilo
mal medido y medio invisible. Lo que separa una entrada de otra es el aire.

Y ahí está el descubrimiento que importa: **el aire que se ve no es el número del padding**, es
`offset_top + padding_bottom + 4`. Esos 4 px salen de la caja de la fuente, que es más alta que
la letra. Con 3 y 3 el hueco real era de 10 px para letras de 9 px. Con 1 y 1 queda en 6, y por
debajo no se puede bajar porque los descendentes se salen de la caja y tocarían la tilde del
renglón siguiente.

### Sin borde negro en la letra, el color deja de ser decoración
El texto del parte iba blanco con `outline_size = 2`. Al quitar el borde —pedido, para dejar la
fuente limpia— se descubrió que ese contorno era lo único que despegaba el texto del terreno.

La consecuencia no fue que el texto se viera mal: fue que **desapareció información**. La
coordenada iba en azul `#4d9be6`, el mar es azul, y las líneas pasaron a leerse como `AV-8B` a
secas. Parecía que el registro había dejado de funcionar; el texto estaba entero.

De ahí la regla: en un HUD sin fondo ni contorno, ningún color puede elegirse por gusto — tiene
que contrastar con **todo** el terreno posible. La coordenada quedó en amarillo `#fee761`, que
aguanta agua y tierra, y además entre corchetes: dos señales, porque el color se pierde si se
toca la paleta y los corchetes no.

Lo que **no** hay que hacer para arreglar un problema de legibilidad: acortar los mensajes. Se
intentó y fue un error — los textos son del usuario, y el ancho se arregla por la fuente o por
el panel.

### La coordenada lleva preposición, y no siempre la misma
Una `B4` suelta al final del renglón no dice nada: el jugador no tiene por qué saber que eso es
una casilla del mapa. Se pusieron `en` para lo que ocurre en un sitio, `a` para la orden y
**`desde` para las alarmas**.

La tercera no es gramática, es información: la coordenada de una alarma es de dónde viene la
amenaza, no dónde está quien la sufre. El código siempre pasó la posición de la amenaza, pero
la línea no lo contaba y se leía justo al revés.

### En el parte, sólo la coordenada se queda el clic
El registro flota sobre el mapa. Dar una orden bajo una línea del parte no hacía nada, sin
señal de por qué. El culpable no era el texto —que ya iba en `PASS`— sino `Lines` y
`EventEntry`, **con el `MOUSE_FILTER_STOP` que Godot pone por defecto**: se comían el clic en
los 200 px de ancho de la fila, hubiera texto o no, y también cuando la entrada ya estaba
apagada al 35%.

Los dos pasan a `IGNORE`, y el texto alterna `PASS`/`STOP` según el cursor esté o no sobre la
coordenada, usando `meta_hover_started` / `meta_hover_ended`. De paso esos dos avisos ponen el
cursor en mano y devuelven la entrada a plena vista.

Vale como recordatorio general: **`mouse_filter` no configurado es `STOP`**, así que cualquier
Control decorativo encima del mundo roba clics hasta que se le diga que no.

### La fuente del parte es M5X7 a 16, después de probar tres
Se probaron con la misma frase de 28 letras en el panel de 200 px. **Public Pixel a 8** es
monoespaciada a 8 px por letra: dos de los seis mensajes partían en dos filas. Una tercera
candidata era la más estrecha de todas (118 px) pero con minúsculas de 3 filas de píxeles, y al
tamaño en que sí se leía reservaba 19 px de caja para 8 de tinta, subiendo el bloque al 39% de
la pantalla. M5X7 a 16 cabe entera, se lee y deja el panel en 200×90.

Tres lecciones del recorrido, cada una contraintuitiva:
- **El número pequeño no implica letra pequeña.** Public Pixel a 8 ocupa más que M5X7 a 16:
  monoespaciada y de trazo doble, está dibujada para escalarse ×2.
- **El tamaño bueno se rasteriza, no se lee de la ficha.** Hay fuentes que no dan ninguno.
- **El alto de línea no es el alto de la letra**, y la diferencia se suma al padding.

Y una cuarta que no es de tipografía: **mirar la licencia antes de encariñarse**. La candidata
descartada exigía atribución en los créditos y dejaba de ser gratis por encima de cierto
presupuesto. Se acabó borrando del proyecto para no dejar peso muerto en `assets/fonts/`.

## 2026-08-15

### La fuente de los retratos es Public Pixel a 8, y por ser monoespaciada manda el ancho
La fuente anterior se leía, pero mal: el usuario la descartó de un vistazo. Se cambió por
**Public Pixel a 8**, que es su tamaño nativo de verdad —rasterizada, cada trazo cae en 2 px
sólidos— y trae las medidas recomendadas en su documentación (8, 16, 32…, siempre múltiplos).

Lo que esto cambió no es cosmético: **es monoespaciada, 8 px por letra sin excepción**. El ancho
de una etiqueta suya no se ajusta, se calcula, y eso invierte quién manda en el tamaño de un
elemento de UI. Antes el retrato medía lo que medía el arte y el nombre se recortaba a lo que
cupiera; ahora el nombre sólo puede medir 8, 16, 24 o 32, y el retrato tiene que ser al menos
eso. Con el cuadrito en 24 px caben **tres caracteres y ni uno más**.

De ahí sale `UnitType.short_name`: tres caracteres puestos a mano por unidad. Va a mano porque
no hay regla que saque `LHD` de "Buque de asalto anfibio" — recortar el primer token daba `BUQ`.
Para los modelos con designación el recorte automático sí sirve y se queda de respaldo
(`AH-1W SuperCobra` → `AH1`).

### El tamaño de un retrato lo fija su ventana interior, no la mitad de la medida original
Al achicar los retratos a la mitad, la cadena de medidas sólo encaja en un sitio. El arte trae
marco de 38 con ventana interior de 32 y silueta de 32 que la llena al píxel. La silueta a la
mitad da 16, que es exacto (2:1, moda de bloque 2×2). El marco a la mitad daría 19 — y ahí se
rompe: con 19 la ventana cae a 14, la silueta de 16 ya no entra, y habría que achicarla a 14,
que no es 2:1 y la ensucia.

Así que **el marco se para en 22**, la medida más pequeña que deja ventana de 16. Se prefiere
desviarse 3 px de "la mitad" antes que degradar el dibujo: la silueta es lo que se mira, el
marco sólo la rodea. La regla general: al escalar un conjunto de piezas encajadas, la que manda
es la que no admite escalado sucio, y las demás se ajustan a ella.

### La barra de vida del retrato pasa a color plano
Eran dos PNG partidos del mismo dibujo (marco y relleno). El usuario quitó la barra del PNG
maestro y pidió "una barra verde sencilla", así que ahora es un `ProgressBar` con dos
`StyleBoxFlat` —hueco `#3e3546`, relleno `#91db69`—. La ventaja no es sólo que haya menos arte
que mantener: un rectángulo se estira a cualquier ancho sin romper nada, mientras que la versión
dibujada había que rehacerla cada vez que el retrato cambiaba de medida, y en esta sesión cambió
tres veces.

## 2026-08-14

### Las unidades desplegadas son retratos dibujados, no botones con texto
El panel superior era una fila de botones grises con el nombre recortado dentro. Se cambió por
el arte del usuario: marco dibujado, silueta de la unidad, barra de vida y el modelo debajo.

Dos versiones del marco, **suelto y seleccionado, como texturas distintas y no como un tinte**:
el seleccionado cambia el color del borde entero y añade marcas rojas en las esquinas, y eso no
sale de ningún `modulate`. La marca la pone el `HUD` y no el panel, porque da igual cómo se
haya elegido la unidad —clic en el mapa, en el retrato, o desde el panel—: todas acaban pasando
por `show_selected_unit()`.

La barra de vida se partió en dos PNG desde el mismo dibujo, **sin retocar un píxel**: marco
(todo menos el verde) y relleno (sólo el verde). Así el marco se ve entero siempre y sólo se
recorta lo lleno. Cuando el usuario la redibujó más alta, el relleno pasó a tener dos verdes
—`a0e679` de brillo y `91db69` debajo— y los dos cuentan como relleno; si se cogiera sólo uno,
la fila del brillo se quedaría fija mientras la de abajo baja.

Dos cosas que esto obligó a añadir al núcleo:
- `UnitType.portrait_icon` — dónde vive "qué silueta es esta unidad". Va en el tipo y no en la
  instancia, igual que `max_health`: dos Harrier se dibujan igual.
- `Unit.health_changed(current, maximum)` — no existía. Lo anticipaba el propio comentario de
  `take_damage`: *"la barra de vida —cuando exista— no mentirá"*. Como `ammo_changed`, la barra
  se entera cuando pasa algo en vez de preguntar cada frame.

### Achicar un PNG de UI: quitar filas repetidas, no remuestrear
Los retratos salieron demasiado grandes (38×38: con diez desplegadas, 400 px de los 640). Al
pedirlos "a la mitad" se probó primero el remuestreo 1:2 y **se descartó tras mirarlo**: el
marco perdía el filo entero —vive en filas alternas y desaparece completo— y las siluetas
quedaban irreconocibles a 9×16.

Lo que sí funcionó: el marco resultó **liso por dentro**, con 19 columnas y 20 filas idénticas
a su vecina. Quitando repetidas se llega a cualquier medida **sin perder un píxel** del borde,
el filo, la muesca de abajo ni los puntos rojos del seleccionado. Es lo mismo que hace un
nine-patch, pero horneado en el PNG y verificado a mano. Igual con la barra de vida, que tenía
29 columnas repetidas.

Sólo las siluetas hubo que remuestrearlas, porque no tienen nada repetido. Ahí se usó **moda de
bloque 2×2** en vez de descartar píxeles alternos: conserva mejor la masa del casco y las
marcas naranjas del LHD, y no inventa colores fuera de la paleta.

**Cómo se decide la medida:** el reparto se hace por mitades a cada lado (7 columnas de la
izquierda y 7 de la derecha) para que el dibujo quede centrado. Y al medir se comprueba que las
repetidas sean comunes a **las dos** versiones del marco, o suelto y seleccionado dejarían de
cuadrar entre sí.

### El tamaño de una fuente se mide rasterizando, no leyendo la ficha
La fuente de los retratos se importó "a 8 px" porque es lo que decía. En pantalla salieron
garabatos: a tamaño 8 sus mayúsculas ocupan **3 filas de píxeles**. No es una letra.

Lo que faltó fue mirar el rasterizado de verdad. Que el avance por glifo sea entero —que era la
comprobación que se estaba haciendo— **no basta**: dice que las letras caen en píxel entero,
no que quede letra. Hay que sacar el glifo del atlas del `TextServer`
(`font_render_glyph` → `font_get_glyph_uv_rect` → `font_get_texture_image`) y volcarlo píxel a
píxel, y quedarse con el menor tamaño en que cada trazo cae en 1 px sólido.

Consecuencia de tamaño: el nombre más largo pasó a medir 22 px, así que los retratos pasaron de
19 a **24 de ancho** (10 desplegadas = 260 px de los 640). El arte se regeneró desde el PNG
maestro con el mismo método de quitar repetidas.

Y como todas las fuentes del proyecto, **venía mal importada**: `antialiasing=1`, `hinting=3`,
`subpixel_positioning=4`. Los tres a 0.

### El minimapa se recorta al dibujo, aunque no sea del tamaño del sprite
Se probó lo contrario a petición del usuario —que arrancase a 82×85, el tamaño exacto del
PNG— y se deshizo al verlo: el hueco del marco es cuadrado (72×72) y el mapa mide 64×45
celdas, así que quedaban 8 px de fondo a los lados y **27 arriba y abajo**. Se lee como un
fallo, no como un marco.

De ahí la regla, que ya valía para el nine-patch y ahora vale también para el tamaño: **el
sprite es una muestra, no una medida**. Lo que manda son sus bordes y sus esquinas, que se
conservan al píxel a cualquier tamaño. El PNG puede dibujarse cuadrado y verse achatado en
pantalla sin que se note.

El hueco sólo desaparecería con un mapa cuadrado, o con un marco apaisado (82×64) — no
agrandando el mapa: lo que sobra depende de la **proporción**, no del tamaño, porque al crecer
el mapa se resume para caber y la banda vuelve igual.

### En un nine-patch, el dibujo va en las esquinas
El marco del minimapa es el PNG del usuario (`minimap_panel.png`, 84×87). Un nine-patch parte
la imagen en nueve regiones y **sólo conserva 1:1 las cuatro esquinas**: los bordes se estiran
en un eje y el centro en los dos. Los detalles que él dibujó —la sombra azul de arriba a la
izquierda, las dos marcas de agarre de arriba a la derecha— caían fuera de las esquinas y se
deformaban al estirar la ventana.

Los cortes quedaron en **15 / 17 / 21 / 5**. No son estéticos: son dónde acaban esos detalles
(la sombra llega a x14/y16, las marcas empiezan en x63).

Costó dos intentos porque las dos primeras veces di el problema por resuelto mirando sólo un
detalle. **La comprobación que hay que hacer siempre:** recorrer las cuatro franjas de borde y
exigir que cada fila del borde superior e inferior sea de un solo color a lo ancho, y cada
columna del izquierdo y el derecho de un solo color a lo alto. Si alguna varía, hay dibujo en
zona estirable. Con eso verificado, `axis_stretch = TILE` no aporta nada: estirar un color
plano da lo mismo que repetirlo.

**El arte no se toca; los cortes son cosa del motor.** El PNG no lleva dentro dónde cortar, así
que da igual cómo se dibuje: hay que medirlo y ponerlo en el `StyleBoxTexture`. Lo que sí
decide el dibujante es *dónde* pone el detalle — pegado a una esquina el margen es chico y el
panel conserva libertad; en mitad de un borde no hay margen que valga y hay que sacarlo del
PNG a un nodo propio encima.

### La rejilla del mapa se traza, no se pega
Se probó a usar una celda dibujada de 8×8 px repetida una vez por zona. Falló por algo que vale
para cualquier adorno del mapa: **una textura escala con el terreno**, así que la línea de 1 px
del dibujo se veía de 4 px con el minimapa a 4x. Trazada por código mide 1 px de pantalla
siempre, igual que los puntos de las unidades y por el mismo motivo — la rejilla es un icono
encima del mapa, no terreno.

Queda translúcida (`alpha 0.5`, color `#2D3A4A` sacado del dibujo) y sin recuadro exterior en el
minimapa, que ya lo pone el marco. El soporte de textura sigue en el código por si algún día
sirve, con un resguardo: si el lado de zona no es múltiplo exacto de la celda, vuelve a las
líneas en vez de escalar a medio píxel.

Efecto secundario que salió bien: como `_zone_side()` agrupa zonas cuando el mapa es chico, la
rejilla es **más gruesa al tamaño mínimo y más fina al agrandar** — 2 divisiones a 1x, 8 a 4x.

### El minimapa entra exacto a cualquier escala
Ya lo hacía `_fit_to_drawing()`, pero al cambiar el marco había que rehacer las cuentas del
relleno (12×15 con los bordes nuevos). Verificado con el terreno real a las cuatro escalas:
**0×0 px de espacio sobrante** en todas. Estirar salta de escala entera en escala entera, así
que nunca aparecen franjas negras.

### El registro de eventos no tiene caja
Llegó a tener panel dibujado con marco, biseles y barra de título. Se quitó entero. El motivo
es de presupuesto de pantalla: ocupaba 144×160 px sobre un lienzo de 640×384 —casi un cuarto
del ancho, el 40% del alto— para mostrar seis renglones de texto. Ahora es texto flotante sobre
el mapa y ocupa sólo lo que ocupa lo que dice.

Quitar el marco además resolvió de rebote el problema que más costó: con caja quedaban 123 px
útiles, unos 20 caracteres, y las frases no cabían sin quedarse sin sentido. Sin caja son 191.

Dos cosas que el cambio obliga y no son opcionales:
- **Contorno negro de 2 px en el texto.** Va sobre selva, agua y arena; un color plano se pierde
  contra la mitad de los fondos.
- **`MOUSE_FILTER_PASS` en el texto.** En `IGNORE` las coordenadas dejan de ser pulsables; en
  `STOP` el registro le roba al mapa todos los clicks de su superficie, que ahora es
  transparente.

**Las entradas se transparentan, no desaparecen**: a los 6 s bajan a `alpha 0.35` y se quedan.
Siguen leyéndose y siguen siendo pulsables. Desaparecer habría costado la historia del parte;
esto sólo le quita protagonismo.

El PNG del panel no se tira: es un nine-patch y sirve tal cual para las ventanas de acción
—hangar, mapa táctico—, que es lo que ya decía la entrada del 2026-07-26 sobre ventanas
arrastrables.

### Cada línea del parte es una escena, no nodos hechos en código
La primera versión fabricaba cada fila a mano: `HBoxContainer.new()`, `TextureRect.new()`,
`RichTextLabel.new()`. Funciona y es imposible de ajustar — nada existe hasta que corre el
juego, así que para mover un ícono dos píxeles había que editar código, arrancar y adivinar.

Ahora hay `event_entry.tscn`, que se abre en el editor con contenido de muestra y se toca ahí.
El `EventLog` sólo la instancia y le pasa qué decir. **Regla general para la UI de aquí en
adelante:** lo que se ve se construye como escena.

Consecuencia deliberada: **dentro de la entrada nada está en contenedores**. En Godot un
contenedor decide dónde van sus hijos y el editor bloquea el arrastre, así que un nodo dentro de
un `HBoxContainer` no se puede colocar a mano. Se eligió poder mover el ícono y el texto con el
ratón; el precio es que el alto no se calcula solo y lo lleva `EventEntry._fit()`.

### Empezar a atacar y destruir son las dos noticias; disparar no
Cada arma que salía escribía su línea. Estaba resuelto para no repetirse —una andanada de seis
Mk-82 se agrupaba en un renglón con la cuenta al lado— y aun así sobraba: `ataca` ya dice que el
compromiso empezó y `Splash!` que terminó, así que era una tercera entrada del mismo suceso. Con
varias unidades a la vez tapaba lo único urgente, que son las alarmas.

Se desconectó de `ammo_changed` y se borró el agrupador entero. El código de brevedad (`RIFLE`,
`FOX 2`) se mudó a la línea de ataque, preguntándole a `WeaponSelector.best_for()` qué elegiría
para ese blanco. La munición se ve en el `WeaponBar`, que es donde toca.

Queda un efecto secundario anotado: `attack_target_changed` sólo emite cuando el blanco cambia,
así que varias pasadas sobre el mismo objetivo dan una línea y después silencio. Si molesta, la
salida es reenganchar tras un rato sin atacar, no volver al disparo por disparo.

### El tamaño de la UI sale de la fuente, y la fuente sólo vale a su tamaño nativo
Un pixel font sólo es nítido a su tamaño de diseño y a sus múltiplos enteros; por debajo Godot
la remuestrea, y el borrón se magnifica cuando el viewport escala a ×2 o ×3. Medido: **M5X7 es
nativa a 16** (avance de 6 px por letra, 9 de tinta) y **m6x11plus también a 16** (12 de tinta).
A 12 y a 14 las dos salen sucias.

De ahí sale el reparto: **m6x11plus 16 para títulos, M5X7 16 para cuerpo** — misma familia, y
13 px de línea contra 17 dan jerarquía sin que el cuerpo ocupe un 30% más.

Las dos venían importadas con `antialiasing=1`, `hinting=3` y `subpixel_positioning=4`, que para
un pixel font es sencillamente estar mal: salen difuminadas por más que el tamaño sea correcto.
Los tres van apagados. **Cualquier fuente nueva viene así por defecto y hay que corregirla.**

Corolario práctico para el arte: se diseña sobre un lienzo de 640×384 a escala 1:1 —lo que se
dibuja ahí es lo que se ve— y el escalado entero del viewport se encarga del resto. El tamaño
que se elige no es estético, es qué fracción de esos 640×384 se come.

## 2026-08-13

### El helicóptero se mueve en sus propios ejes, no hacia un punto
`PlaneController` no servía y no era cuestión de ajustarlo: está construido sobre el radio de
giro —no puede parar, no puede ir despacio, todo lo que hace sale de un círculo mínimo— y un
helicóptero hace exactamente lo contrario. Controlador nuevo, `HelicopterController`.

Lo que lo distingue de "ir hacia un punto" es que dentro hay **un mando**: `_stick` (adelante y
costados, en ejes del propio aparato) y `_pedal` (el giro), como las dos manos con las que se
lleva un helicóptero en cualquier juego. De ahí salen solas las dos cosas que lo hacen
reconocible.

**Los ejes no valen lo mismo:** 85 px/s de morro, 38 de costado, 28 de espaldas. Si los tres
fueran iguales esto sería un icono deslizándose. Que recular sea incómodo es lo que empuja a
girar en vez de irse de espaldas medio mapa.

**Girar no es consecuencia de moverse.** El rumbo lo decide `_wanted_heading`, aparte de la
traslación: se encara si el destino está a más de `face_range` (70 px) y si no, se entra de lado
sin molestarse en girar. Medido: un punto a 49 px por detrás se resuelve con **0 grados** de
giro. Esa separación es la que dejará hacer, el día que haya blanco, lo que se le pide a un
helicóptero artillado — nariz clavada en el objetivo mientras se desplaza de costado. Hoy no
aparece porque no hay nada más a lo que mirar que el destino.

Lo único que se hace esperar es `stick_delay` (0,25 s de pedal antes de tocar el cíclico): un
helicóptero primero se encara y luego sale. Pasa siempre igual, así que se lee como arranque.

### Una unidad que obedece órdenes llega exacta
Hubo una versión intermedia con un piloto **torpe** dentro: soltaba el freno tarde y se pasaba
del punto, corregía, movía el mando a golpes cada 0,18 s, dejaba el morro unos grados desviado.
La idea venía de los juegos donde pilotas tú —Desert Strike, Choplifter— y ahí funciona, porque
el error es tuyo y lo sientes en las manos.

**Aquí no.** En un juego de órdenes, una unidad imprecisa no parece un piloto humano: parece que
no te hizo caso. Se quitó entera. El mando pasó a ser analógico y la frenada exacta —se pide en
cada eje la velocidad que permite pararse en lo que falta, `v² = 2·a·d`—, y con eso llega a menos
de 1,5 px del punto en 40 de 40 órdenes al azar, frente a los 6 px y las 30 correcciones de la
versión torpe. Encima llega antes: la más lenta bajó de 11,2 s a 7,4 s.

Lo que queda es la regla: **el carácter va en el peso** —lo que cuesta arrancar y parar, la rampa
de la cola, que los ejes no valgan lo mismo—, **nunca en el error**. Si un movimiento se siente
muerto, la causa está en la representación (el sprite no se inclina, no reacciona) o en el
render, no en meterle ruido a la lógica.

### La plaza en cubierta se libera al despegar, no al soltar el aparato
Un avión deja su plaza en cuanto empieza la carrera. Un helicóptero no: se queda posado en ella
hasta que el jugador le da un sitio a donde ir, y **esa primera orden es también la orden de
despegar** (sube en vertical `lift_time` y sale). Si la plaza se hubiera dado por libre al
cederle el control, el siguiente aparato habría taxiado hasta el mismo punto y se le habría
montado encima.

Quién avisa es el propio helicóptero (`took_off`), porque es el único que sabe cuándo se va. Y el
barco se engancha a esa señal **al crearlo, no al soltarlo**: la orden puede llegar mientras
todavía lo están colocando en cubierta, y en ese caso se guarda y se cumple en cuanto hay
control. Tragarse una orden que el jugador ya dio —y que ve marcada en el mapa— habría sido peor
que cualquier bug de colocación.

## 2026-08-12

### La unidad expone hechos; el HUD los pone en palabras
Dos cosas del día que salieron de la misma idea, y por eso conviene leerlas juntas.

**Las llamadas de radio** (`BrevityCalls`): `Fox Three!`, `Rifle!`, `Pickle!` sobre el avión que
dispara. El código **sale del arma** (`brevity_code`), no está escrito en el HUD — un arma nueva
trae su llamada puesta. Y lo que es presentación se queda en la presentación: el cañón se canta
`guns, guns, guns` porque en radio se repite tres veces, pero el `.tres` sigue diciendo `Guns` a
secas y en el parte de eventos sale corto.

Salen sobre **cualquier avión propio**, esté seleccionado o no — ahí está la diferencia con
`UnitTag`, que acompaña a uno solo. Lo interesante es justamente enterarte de lo que hacen los
que no estás mirando.

**El estado en la etiqueta** (`Status: Atacando a Su-33 Flanker-D`): se compone en el HUD a
partir de hechos que la unidad ya sabía —a quién ataca— más uno nuevo, `get_move_destination()`,
que devuelve **un punto y no un texto**. Así el mismo dato le sirve luego al parte de eventos,
que lo cuenta con otras palabras.

Dos detalles de comportamiento: **atacar manda sobre moverse** —un avión que ataca también se
desplaza, y lo que interesa es lo primero—, y "moviéndose" sólo cuenta *mientras se acerca*: una
vez llegado se pone a orbitar ahí, y eso ya es esperar.

Contra el spam, dos cortes distintos porque venía por dos caminos: la ventana que agrupa
repeticiones del mismo arma (una ristra de seis Mk-82 canta **un** `Pickle!`), y la regla de que
**un avión canta de uno en uno** — al llegar una llamada nueva, la anterior de ese avión se
manda a desvanecer en vez de solaparse.

### Lo que no despega por pista se queda donde está
El AH-1W usa **la misma cubierta que el Harrier**: elevador, taxi y colocación en su punto. Ahí
se detiene. La cubierta lo sabe preguntándole al aparato —`get_takeoff_speed()` a 0— y no con
una lista de modelos: no tiene por qué conocer qué existe, y el día que haya otro helicóptero
funciona solo.

Mismo criterio con el **rotor**: arranca cuando el aparato lleva medio segundo quieto, mirando
si se mueve. Mientras el barco lo lleva de un sitio a otro está rodando; en cuanto se para, es
que llegó. Ni el barco avisa ni el helicóptero pregunta, así que cambiar el recorrido de
cubierta no rompe nada. Y una vez arrancado **no se para**: lo contrario sería un rotor que se
apaga justo al despegar.

Las tres misiones del helicóptero —CAS, Escolta, Antiblindaje— existen **sin armamento**. Al no
pedir ninguna arma, el filtro del hangar las deja pasar siempre, que es lo que se quiere hasta
que haya con qué armarlas.

### Contar el tiempo al impacto sólo tiene sentido a veces
El contador sobre el blanco se quitó del combate aéreo (todo pasa en segundos y no da tiempo ni
a leerse), del cañón (no hay nada en el aire que esperar) y de las bombas tontas.

Los dos primeros se cortan en el HUD, porque son decisiones de interfaz. El tercero **no**: lo
dice el proyectil con `guides()`, porque es el único que sabe si persigue o cae donde caiga. El
primer intento fue distinguirlas por el campo `seeker` del arma y estaba mal — ese campo se
añadió para las contramedidas, y ni el Maverick ni la GBU-54 lo tienen puesto, así que se
habrían quedado sin contador justo los dos casos donde hace falta.


### El arma que guía el vuelo es la mejor que se lleva, no la que ya se puede disparar
El bug más difícil de ver del día, porque era un **círculo cerrado** y cada pieza parecía
correcta por separado. Con un Harrier de bombardeo (Mk-82 + AIM-9) entrando de frente a un
Su-33:

1. El AIM-9 no engancha de frente — necesita ver la tobera.
2. Como no puede dispararse, el selector ponía el **cañón**.
3. Con el cañón puesto, el vuelo va **derecho**: el cañón no necesita la cola.
4. Yendo derecho, el AIM-9 no conseguía ángulo nunca. Vuelta al paso 1.

El avión acababa metiéndose a los tiros contra un caza con un misil intacto colgado del ala.

La corrección: si lo único disparable es el cañón pero hay un misil al que **sólo le falta
ángulo**, manda el misil aunque todavía no se pueda tirar. El vuelo va entonces a buscar la
posición y el disparo llega solo. Medido entrando de frente: cuatro AIM-9 y ni un cañonazo.

Lo que queda como regla: **el selector dice hacia qué se está peleando; quien comprueba si se
puede tirar es el armamento.** Confundir las dos cosas es lo que cerró el círculo.

### Combate aéreo y ataque a tierra son dos sistemas, y el arma es donde se tocan
La lección más cara del día, y la causa de casi todo lo que se rompió.

El Harrier usaba `AttackRunBehavior` contra **todo**, y ese comportamiento hace pasadas: entra,
suelta y **rompe**. Contra un tanque es correcto —no te persigue, quedarse encima no aporta—.
Contra un avión es absurdo: soltabas un AMRAAM y el avión se alejaba, regalando la iniciativa.
De ahí salió `DogfightBehavior`, y el Harrier elige uno u otro **según el dominio del blanco**.

Pero separar los comportamientos no bastó, porque **el arma la comparten los dos**. El cañón es
un solo `.tres`, y su `min_range` alimentaba tres cosas a la vez:

1. Hasta dónde alcanza.
2. A qué distancia rompe la pasada en tierra (el vuelo lo multiplica).
3. La puntería (se interpola entre mínimo y máximo).

Bajarlo de 220 a 40 —necesario para que el cañón sirva a quemarropa en el aire— movió las tres.
El sobrevuelo sobre los tanques y el daño por pasada cambiaron **sin que nadie tocara nada de
tierra**, y costó varias rondas de discusión entender por qué.

**El error de origen era más viejo:** ese `min_range = 220` lo puse días antes para arreglar el
sobrevuelo, o sea que usé *el alcance del arma* para resolver *un problema de vuelo*. Un cañón
de 25 mm alcanza desde muy cerca; que el avión no deba meterse tanto es una decisión de cómo
vuela. Era un parche, y al quitarlo salieron los efectos que estaba tapando.

La regla que queda: **lo que es del arma va en el arma, lo que es del vuelo va en el vuelo.** Y
si una propiedad del arma significa cosas distintas según el blanco, se declara por blanco en
vez de elegir un número de compromiso.

### El mismo cañón, dos envolventes
De lo anterior salieron `air_min_range` y `air_max_range` en `WeaponType`: el alcance que aplica
sólo contra lo que vuela. En el cañón:

| | contra tierra | contra aire |
|---|---|---|
| alcance | 220 – 420 | **40 – 150** |

Los dos extremos importan, y cada uno arregló un fallo distinto:

- **El mínimo**, porque a quemarropa en un duelo el cañón es lo único que queda.
- **El máximo**, porque con 420 el cañón llegaba **más lejos que el AIM-9** (360). Entre 360 y
  420 era lo único con alcance, así que el avión se ponía a los tiros a 400 px en vez de tirar
  el misil — y la regla de "el cañón es el último recurso" no servía de nada, porque no había
  ningún otro recurso. Acertarle a algo que se mueve a 400 px con un cañón no pasa.

### El duelo se pelea por el ángulo, no por la distancia
`DogfightBehavior` no vuela hacia el enemigo: vuela hacia **el punto que lo pone detrás de él**.
Como ese punto se mueve con el blanco, perseguirlo produce solo las persecuciones circulares de
un dogfight, sin programar ninguna maniobra. Y decide quién gana sin reglas extra: **el avión
que vira más cerrado cierra por dentro**, así que el radio de giro —que ya era el parámetro
maestro del vuelo— decide también el combate aéreo.

Lo que le da forma es `WeaponType.max_aspect_deg`: desde qué parte del blanco hay que atacarlo,
medido desde su cola. El AIM-9 pide **60°** porque busca la tobera; el AMRAAM entra por donde
sea. Así **el arma decide la geometría del vuelo**: si puede disparar de frente se vuela derecho
y se dispara mientras se cierra, y sólo se va a buscar la cola cuando el arma lo exige.

Al cañón se le puso 45° y **se le quitó**: si el jugador lo elige, que dispare desde donde sea.
Ya está limitado por su alcance.

### Cuándo manda el automático y cuándo el jugador
`WeaponSelector` salió del Tunguska —donde estaba escrito a mano— en cuanto hizo falta lo mismo
en el avión. Las reglas costaron tres correcciones seguidas, todas del mismo tipo: casos donde
el automático pisaba al jugador o donde nadie ponía un arma sensata.

| situación | quién manda |
|---|---|
| duelo aéreo sin que el jugador toque nada | el automático, cambiando de banda según se cierra |
| ataque a tierra | **el jugador**: se pone un arma que sirva al empezar y no se vuelve a tocar |
| el jugador elige en la barra | él, hasta que el arma se agote o cambie a otro blanco |
| elige el arma **antes** de dar la orden | él: la elección **espera** al blanco que venga |

Ese último caso era el orden normal de las cosas —eliges arma, después pulsas al enemigo— y la
primera versión lo daba por caducado justo al atacar, pisándole el arma.

Y el que se escapó hasta que el usuario lo vio jugando: al desactivar el automático en tierra,
**el arma se quedaba pegada de lo anterior**. Salías de un duelo con el cañón puesto, mandabas
al avión contra un tanque, y se iba a ametrallar con distancia de sobra para bombardear. La
distinción que faltaba: el automático **no cambia el arma durante** un ataque a tierra, pero
**sí pone una que sirva al empezarlo**.

### Una referencia liberada no es `null`, y ya van dos
Segunda vez en pocos días que el mismo patrón revienta el juego: `WeaponSystem` con
`attack_target`, y ahora `Projectile._shooter` al explotar una bomba cuyo lanzador ya había
muerto. Una bomba tarda segundos en caer, así que da tiempo de sobra.

Una referencia a un objeto liberado **conserva su tipo**, así que no falla al comprobarla:
falla al **pasarla** a algo que espera un `Unit`, antes de que nadie pueda comprobar nada
dentro. La forma de evitarlo es normalizarla a `null` en el sitio donde se lee, no confiar en
que quien la reciba se defienda.

### Un blanco que no se muere es una herramienta de trabajo
`Unit.invulnerable`: encaja el daño pero se queda en 1 de vida. Va **en la instancia y no en el
`UnitType`**, porque un tipo entero invulnerable se acaba colando en una misión; así el modelo
conserva su resistencia real y sólo el que pusiste en el mapa para probar aguanta.

Se queda en 1 y no a tope aposta: se sigue viendo que el arma pega, y la barra de vida —cuando
exista— no mentirá diciendo que está intacto.

## 2026-08-10

### Simular las contramedidas no funcionó, y el porcentaje sí
La entrada más cara del día, por lo que enseña. El objetivo era que soltar chaff no fuese un
interruptor de invulnerabilidad, y se intentó **sin dados**, por geometría pura, apoyándose en
la regla ya escrita de que "el fallo sale de la simulación, no de un dado".

Cuatro modelos, cada uno arreglando el anterior y ninguno funcionando:

| criterio del buscador | qué pasó |
|---|---|
| el señuelo **más centrado** | el chaff nace en la posición del avión: siempre estaba tan centrado como él. Engañaba **siempre** |
| el señuelo **más cercano** | de frente las nubes quedan detrás del avión: no engañaba **nunca** |
| **señal** = fuerza / distancia² × ángulo², con la nube floreciendo en 0,4 s | seguía engañando siempre: el misil acaba persiguiendo por la cola y los señuelos le quedan delante |
| lo anterior + **resolución angular** + margen de captura | igual. Medido: señuelo a 137 px contra avión a 279 |

El error de fondo no fue ninguno de los cuatro: fue **elegir la simulación para algo con cinco
variables acopladas**. La regla de "que lo decida la geometría" vale para el cañón, donde son
dos —distancia y ángulo— y el jugador las ve. Aquí ni yo podía predecir el resultado leyendo el
código, así que el jugador menos.

**Lo que se hizo al final es lo que el usuario había propuesto desde el principio:** tirar una
vez, al lanzar, y que todo lo demás sea representación. Si la tirada dice que falla, el misil se
va tras una bengala a la vista de todos; si dice que acierta, va derecho. **Se ve exactamente
igual** —los señuelos, el florecimiento y el seguimiento siguen ahí— pero el resultado es un
número ajustable en vez de cinco perillas imposibles.

La lección para la próxima: *simular* está bien cuando el jugador puede leer la simulación. Si
no puede, es azar disfrazado — y encima azar que no se puede ajustar.

### La evasión automática se implementó y se quitó el mismo día
Se llegó a construir un `EvasionBehavior` que viraba cruzándose al misil y aceleraba. Estaba
mal por dos motivos, y el segundo era un fallo ya documentado en esta misma bitácora:

1. **Con orden de ataque:** evadía, el misil se perdía, volvía al blanco, entraba en rango, otro
   misil. Bucle infinito encima de la batería hasta quedarse sin chaff.
2. **Sin órdenes:** al terminar orbitaba **donde había acabado de esquivar** — al lado del
   Tunguska. Es literalmente el caso que se había anotado como "el avión muere por una decisión
   automática del juego", reintroducido.

Y el viraje perpendicular, correcto en un simulador, aquí no sacaba al avión de ningún sitio:
con radio de giro de 130 px sólo lo dejaba dando vueltas dentro de la zona.

**Se eliminó entera.** El avión suelta señuelos y sigue con lo suyo; sacarlo de una zona batida
es del jugador. Vuelve a valer la regla sin excepciones: *la iniciativa propia llena huecos,
nunca contradice una orden*.

### Dos capas contra un misil: lo que llevas puesto y lo que gastas
- **`UnitType.ecm_evasion`** — lo que el avión se libra por sí solo, sin gastar nada (20% en el
  Harrier). Va en el tipo y no en la instancia, como `max_health`: es lo que trae el modelo de
  fábrica, así que el menú de progresión lo subirá para todos los de ese modelo de una vez.
- **`WeaponType.decoy_bonus`** — lo que suma soltar un señuelo (+55%), mientras queden cargas.

Así **un avión sin cargas no queda vendido**, sólo mucho más expuesto. Medido:

```
             misil 1   2     3     4     5
con chaff      75%   58%   44%   29%   12%
sin chaff      20%    5%    0%    0%    0%
```

### La batería afina la puntería, y olvida de dos maneras
Con un porcentaje fijo y 30 cargas, un avión aguantaría veinte misiles y quedarse en la zona no
costaría nada. Por eso cada misil que una batería le tira **al mismo blanco** descuenta 15
puntos: la insistencia es lo que mata, no el primer disparo.

El olvido va por dos vías, y la primera importa más de lo que parece:

- **Por tiempo** (25 s sin tenerlo enganchado). Se descartó olvidar al salir del círculo de
  detección: sería un botón de reiniciar — entrar, salir y volver con la cuenta a cero.
- **Al volver a base** (`forget_solution()`). Un avión que aterrizó y se rearmó no es el mismo
  contacto que la batería llevaba media hora estudiando. El enganche está puesto pero **no lo
  llama nadie**: la recuperación de aviones todavía no existe.

Es por pareja batería-blanco, así que otra batería empieza de cero contra ese avión, y la misma
batería empieza de cero contra otro avión.

### Los porcentajes no se enseñan, pero la escalada tiene que notarse
Decisión: **ningún número en pantalla**. Es un arcade, no un juego de tablero; lo que el jugador
tiene que aprender es "cerca de una batería te matan", no "tengo 44%". En el menú de progresión
sí irán números, porque ahí se gastan recursos y hace falta saber qué se compra.

Con una condición pendiente: **la escalada es hoy invisible**, y es la mecánica más importante
que se acaba de meter. Quien pierda un avión al cuarto misil lo leerá como mala suerte y no como
"me quedé demasiado". Si no se percibe, la mecánica no existe — sólo hace que el juego parezca
aleatorio. Idea del usuario para resolverlo: un indicador en el avión que muestre desde dónde lo
están siguiendo y que se intensifique, pulsando y sonando más fuerte.

### El daño no se hace justo esquivando: se hace justo avisando
El problema era que el Tunguska mataba aviones y eso frustraba. La primera propuesta fue que el
avión esquivara solo, y se descartó: **cambia frustración por algo peor**, un avión que no va
donde lo mandaste. Lo que frustra no es recibir daño, es recibirlo sin haberlo podido prever.

También se descartó la segunda idea, dejar los círculos de alcance siempre visibles: **un
círculo comunica geometría, no peligro**. Está siempre ahí, no cambia, y el jugador deja de
verlo a los cinco minutos.

Lo que quedó es feedback **direccional y en el momento**, que le dice al jugador dónde mirar
justo cuando importa:

| aviso | de qué señal sale | qué dice |
|---|---|---|
| `MUD SPIKE` | `TurretTracker.target_acquired` | te tienen enganchado, aún no disparan |
| `AAA, bajo fuego` | `WeaponSystem.firing_started` | ya te disparan |

Y **la anticipación sale gratis de los rangos**, sin ningún círculo: detección 400 px, tiro
250 px, y la torreta tarda hasta 3 s en apuntar. Medido, el `MUD SPIKE` llega 4,8 s antes del
primer disparo. El aviso de que te siguen *es* la telegrafía.

### La alarma es una sola aunque la oigan varios
El filtro anti-repetición vive en `Unit` (`ALARM_SILENCE`, 8 s por amenaza y por tipo), no en el
parte de eventos. Si cada consumidor —el parte, los dos mapas y el audio que falta— filtrara por
su cuenta, tarde o temprano dirían cosas distintas sobre lo mismo.

Hace falta de verdad: un cañón de ráfagas abre fuego cada segundo y medio, así que sin filtro el
parte sería una línea repetida hasta que el avión se fuera. **Una alarma que se repite deja de
ser una alarma.** Medido: 2 avisos donde habría habido ~10.

Y el aviso va **del agresor a la víctima**, porque el que apunta es el único que sabe a quién.
La víctima decide qué hacer con la noticia — hoy el parte y los mapas, mañana la radio.

### Cada mapa lleva su propio registro de contactos
`ThreatPulses` sólo lleva la cuenta —qué señalar y desde cuándo—; el dibujo es de cada mapa, que
sabe su escala. El mismo contacto se pinta con un anillo de 12 px en el minimapa y de 28 en el
grande.

Que el minimapa y el mapa táctico tengan **una instancia cada uno** parece desperdicio y es
justo lo que da el comportamiento que se buscaba: **el mapa grande está oculto casi siempre pero
sigue apuntando lo que pasa**, así que al abrirlo porque algo sonó se ven los contactos vivos en
vez de una pantalla en blanco. Verificado con el HUD real: 1 pulso registrado con `visible:
false`.

El radio de la onda va en **píxeles de pantalla y no de mundo**, como los puntos de unidad: lo
que dice es "mirá acá", y eso tiene que medir lo mismo en los dos mapas. A escala real serían
2 px en el minimapa. Y salen **tres ondas por contacto** en vez de una, porque una sola se
pierde si el jugador estaba mirando a otro lado.

### Perder una unidad y derribar una no se cuentan igual
`Splash!` es lo que se canta **al abatir algo**, no lo que se dice al perder a uno de los tuyos.
El parte los separa: lo enemigo sigue con `Splash!`, lo propio pasa a
`UNIT LOST — <unidad>, derribado por <quién>`.

Para poder decir *por quién* hubo que propagar el autor: `take_damage()` acepta un `source`
opcional y la unidad apunta `killed_by`. Se guarda **quién pegó el último**, no quién pegó más:
es lo que se dice en un parte de bajas y lo único que se puede saber sin llevar la cuenta de
cuánto puso cada uno. Opcional porque no todo daño tendrá autor —un choque, el terreno— y
entonces la línea sale sin culpable en vez de inventarlo.

### Una baja no desaparece del panel: se apaga y se va al final
Que un cuadrito se esfume sin más deja al jugador dudando de si perdió algo o si nunca lo tuvo.
Apagado y al final de su fila, es el recuento de la operación. El panel guarda **el nombre y no
la unidad**, porque para entonces la unidad ya no existe: el panel es lo único que queda de ella.

### La iniciativa propia llena huecos, nunca contradice una orden
La regla que zanjó el debate sobre si el avión debe evitar las zonas defendidas:

| orden | qué fijó el jugador | puede evitar |
|---|---|---|
| ir a un punto | el destino, no la ruta | **sí** — rodear y llegar igual es obedecer |
| atacar a X | el resultado | **no** — avisa y sigue |

La evasión en ruta **queda aparcada a propósito**: toca el comportamiento de vuelo, que es lo
que más costó dejar bien, y no se puede decidir con el mapa casi vacío — rodear sólo tiene
sentido cuando hay algo que rodear. Se reevalúa cuando haya varias baterías y misiones con ruta
real.

Queda anotado **un caso que sí es un hueco** y hay que vigilar: el avión que se queda sin
órdenes dentro del alcance. Pasa solo — al terminar un ataque, `_on_target_lost()` lo pone a
orbitar *donde está*, que es justo encima de la defensa que acaba de atacar. Ahí no obedece
nada: muere por una decisión automática del juego. No es esquivar, es **elegir dónde orbitar**.

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
