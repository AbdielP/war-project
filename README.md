# war-project

RTT (real-time tactics) 2D, inspirado visualmente en Raid on Bungeling Bay. Mecánicas propias.

## Stack
- **Motor:** Godot 4
- **Resolución:** 640×384 (5:3), escala entera, filtro Nearest
- **Paleta:** Resurrect64
- **Arte:** pixel art top-down
- **Plataformas objetivo:** PC, móvil, Nintendo Switch

## Cómo correr
1. Abrir el proyecto en Godot 4
2. F5 (o botón Play) para correr desde `main.tscn`
3. F6 para correr solo la escena actual

## Controles (build actual)
| Acción | PC |
|--------|----|
| Pan de cámara | Click izq + arrastre |
| Seleccionar unidad | Click izq sobre unidad |
| Deseleccionar | Escape / botón × |
| Dar orden de movimiento | Click der, o click izq en espacio vacío con unidad seleccionada |
| Centrar cámara en unidad | Click en card del panel superior |

## Documentación
- `docs/GDD.md` — diseño del juego, mecánicas, unidades
- `docs/decisions.md` — bitácora de decisiones técnicas
- `docs/architecture.md` — índice de clases, señales y estado de implementación
- `CLAUDE.md` — instrucciones de trabajo para Claude Code


# PENDIENTES:
- No desplegar aviones si hay otro vuelo en pista. puede ir subiendo al elevador, eso es todo.
- Las unidades desplegadas como escuadron deben navegar/desplazarce siguiendo al lider.
- Las unidades desplegadas como escuadron deben salir en el menú deu nidades como una sola y un multiplicador de la cantidad: x2, x3.. xN
- Minimapa y mapa tactico
    - A partir de aqui iniciar las opciones de ataque de unidades