# war-project — contexto técnico

RTT (real-time tactics) 2D, inspirado visualmente en Raid on Bungeling Bay, mecánicas propias.

## Stack y restricciones técnicas
- Motor: Godot
- Resolución base del mundo: 640×384 (5:3)
- Escala: entera siempre (1x, 2x, 3x). Nunca 1.5x.
- Filtro: Nearest en todo, incluida la fuente.
- Paleta: Resurrect64
- Arte: pixel art top-down
- Fuente: pixel font externa (Pixel Operator / m5x7 / Tiny5). No dibujar fuentes a mano.
- Plataformas objetivo: PC, móvil, Nintendo Switch

## Estructura de carpetas
Organización por feature: cada unidad/barco/pantalla vive en su propia carpeta con su escena, script y arte específico juntos. `assets/` solo para lo que se comparte entre varias features (arte genérico, audio, fuentes). No hay scaffold completo creado de antemano — las carpetas se crean de forma incremental, a medida que se necesitan.

## Documentación relacionada
- `docs/GDD.md` — diseño del juego (mecánicas, unidades, flota)
- `docs/decisions.md` — bitácora de decisiones, más recientes arriba

## Notas de trabajo
- El usuario gestiona git por su cuenta (init, commits, remotos). No ejecutar comandos git salvo pedido explícito.
- Actualizar este archivo y `docs/decisions.md` cuando se tome una decisión técnica o de diseño relevante.
