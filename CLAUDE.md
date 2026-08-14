# war-project — contexto técnico

RTT (real-time tactics) 2D, inspirado visualmente en Raid on Bungeling Bay, mecánicas propias.

## Stack y restricciones técnicas
- Motor: Godot
- Resolución base del mundo: 640×384 (5:3)
- Escala: entera siempre (1x, 2x, 3x). Nunca 1.5x.
- Filtro: Nearest en todo, incluida la fuente.
- Paleta: Resurrect64
- Arte: pixel art top-down
- Fuente: pixel font externa. No dibujar fuentes a mano. En uso: **m6x11plus para títulos, M5X7 para cuerpo**, las dos a tamaño **16**.
- Plataformas objetivo: PC, móvil, Nintendo Switch

## UI
- **Se diseña sobre 640×384 a escala 1:1.** Lo que se dibuja en el lienzo es lo que se ve; el escalado entero del viewport hace el resto. Elegir un tamaño no es estético, es decidir qué fracción de esos 640×384 se ocupa.
- **Un pixel font sólo vale a su tamaño nativo y sus múltiplos enteros.** Por debajo se remuestrea y el borrón se magnifica al escalar. Las dos del proyecto son nativas a 16.
- **Toda fuente nueva viene mal importada.** Hay que poner *Antialiasing*, *Hinting* y *Subpixel Positioning* en ninguno/desactivado, o sale difuminada por más que el tamaño sea correcto.
- **Comprobar que la fuente tenga el glifo** antes de meter cualquier signo tipográfico en un texto de UI: si falta, Godot lo saca de una fuente del sistema y rompe el alto de línea. Ninguna de las dos tiene `→ ← ↑ ↓ — – … • ‹ ›`.
- **El tamaño nativo de una fuente se comprueba rasterizando un glifo, no leyendo su ficha.** Que el avance sea entero no basta: dice que las letras caen en píxel entero, no que quede letra. Sacar el glifo del atlas (`font_render_glyph` → `font_get_glyph_uv_rect` → `font_get_texture_image`) y volcarlo píxel a píxel; el tamaño bueno es el menor en que cada trazo cae en 1 px sólido. En uso: **Silver a 14** para etiquetas cortas.
- **Para achicar un PNG de UI, quitar filas y columnas repetidas antes que remuestrear.** Casi todo marco es liso por dentro; quitando las idénticas a su vecina se llega a cualquier medida sin perder un píxel de borde, filo ni esquinas. Remuestrear se guarda para lo figurativo, que no tiene repetidas, y ahí conviene moda de bloque 2×2 en vez de descartar píxeles alternos: conserva las masas y no inventa colores fuera de paleta.
- **Antes de dar por bueno un texto o un asset, mirarlo.** Que el juego arranque sin errores de script no dice nada de si se lee. Componer el resultado y verlo, o se entrega arte roto.
- **Lo que se ve se construye como escena**, no con nodos fabricados en código: si no existe en el editor, no se puede ajustar sin arrancar el juego.
- **Los paneles van como nine-patch.** El PNG es una muestra, no una medida: el marco y las esquinas se conservan al píxel y sólo se estira el relleno. Esto vale también para el **tamaño**: un panel puede dibujarse cuadrado y verse achatado en pantalla. Vale más que entre exacto a que respete la medida del sprite — un borde vacío alrededor del contenido se lee como un fallo.
- **Los cortes de un nine-patch se remiden cada vez que se retoca el PNG.** No son estables: quitar un detalle de una esquina cambia el corte de ese lado. Se sacan buscando el tramo contiguo más largo de filas idénticas a la anterior y de columnas idénticas a la anterior — ese tramo es la zona estirable y lo que queda a los lados son los cortes.
- **En un nine-patch sólo las cuatro esquinas quedan 1:1.** Todo detalle figurativo —remaches, marcas de agarre, una brújula— se dibuja pegado a una esquina, o sale del PNG y se cuelga como nodo propio encima. En mitad de un borde no hay margen que lo salve. Los cortes se miden y se ponen en Godot; el PNG no los lleva dentro, así que el arte nunca necesita rehacerse por esto.
- **Antes de dar por bueno un nine-patch**, comprobar que cada fila de los bordes superior e inferior sea de un solo color a lo ancho, y cada columna de los laterales de un solo color a lo alto. Si alguna varía, hay dibujo en zona estirable.
- **Lo que se dibuja encima del mapa no se pega como textura, se traza.** Una textura escala con el terreno y una línea de 1 px se vuelve de 4 px al agrandar; trazada mide 1 px de pantalla siempre. Vale para la rejilla, los puntos de unidad y cualquier icono.

## Estructura de carpetas
Organización por feature: cada unidad/barco/pantalla vive en su propia carpeta con su escena, script y arte específico juntos. `assets/` solo para lo que se comparte entre varias features (arte genérico, audio, fuentes). No hay scaffold completo creado de antemano — las carpetas se crean de forma incremental, a medida que se necesitan.

## Documentación relacionada
- `docs/GDD.md` — diseño del juego (mecánicas, unidades, flota)
- `docs/decisions.md` — bitácora de decisiones, más recientes arriba

## Notas de trabajo
- El usuario gestiona git por su cuenta (init, commits, remotos). No ejecutar comandos git salvo pedido explícito.
- Actualizar este archivo y `docs/decisions.md` cuando se tome una decisión técnica o de diseño relevante.
