# GDD — war-project

## Concepto
RTT (real-time tactics) simplificado, inspirado visualmente en Raid on Bungeling Bay, con mecánicas propias.

## Flota del jugador
- Buque insignia: siempre un buque de asalto anfibio multipropósito. Mejorable o reemplazable por uno mejor.
- El jugador puede comprar barcos adicionales (o mejores) para proteger la flota.

## Unidades
- Se despliegan desde el buque insignia.
- Actúan por IA por defecto.
- El jugador puede tomar control manual de una unidad puntual y devolverla a la IA en cualquier momento.
- Unidades del jugador: las desbloqueadas/compradas hasta el momento.
- Unidades enemigas: dependen del nivel y del mapa.

## Puerto
Donde se gasta el dinero entre misiones. Se llega desde la campaña y desde el briefing, y se vuelve a quien lo abrió.

Dos menús, no tres:
- **Arsenal** — lo que *no* tienes: vehículos (terrestres, marítimos y aéreos) y armamento, con su precio. Comprar desbloquea el modelo; no hay stock por unidad.
- **Flota** — lo que *sí* tienes: cada barco, qué aeronaves lleva a bordo, su pañol y sus mejoras.

Decisiones que sostienen esa forma:
- **La munición no es una tienda aparte.** Cuánta cabe lo decide el barco, así que se rellena desde su ficha, viendo contra qué se gasta.
- **Las mejoras no son un árbol de habilidades**, sino una lista corta en la ficha de cada unidad: una mejora se aplica a una unidad concreta y hay que estar mirándola.
- El fondo es el puerto con los barcos fondeados; los menús se abren **encima** y no lo sustituyen.

## Plataformas objetivo
PC, móvil, Nintendo Switch.

## Pendiente de definir
(ir agregando acá temas abiertos: economía, progresión, tipos de unidades, diseño de niveles, etc.)
- Minimapa: cómo funciona el zoom/navegación dentro del recuadro chico del HUD (no se centra en ninguna unidad, eso se descartó). Ver detalle técnico en `docs/decisions.md` (2026-07-26).
- Mapa táctico grande: pantalla aparte, todavía no implementada. Se abriría al hacer click en el minimapa.
- Puerto: cantidades de munición por barco (cuánta cabe, qué cuesta rellenar) y catálogo de mejoras por unidad. Los precios actuales son de relleno.
- Puerto: arte del muelle. Hoy son bandas de color con el sprite del LHD amarrado — andamio a propósito, ver `docs/decisions.md` (2026-08-27).
