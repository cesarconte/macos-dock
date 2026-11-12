# Baseline de rendimiento — macos-dock

Fecha: $(date)

## Memoria (proceso macos-dock)
- RSS: ~218 MB
- VSZ: ~2.1 GB (incluye mapeos compartidos Qt/Plasma/KF)

## CPU/GPU
- Medición puntual; animaciones de magnificación y liquid glass son los hot paths visuales.

## Optimizaciones identificadas (D4)
1. Eliminar `qDebug` en hot paths (hecho en D1).
2. Evitar recreación de `QRegion` en `updateMask` cuando la geometría no cambia (cachear última región).
3. Limitar repaints: usar `QQuickItem::update()` solo cuando cambian propiedades relevantes.
4. Revisar `StackDialog`/`GroupDialog` creación de componentes (Qt.createComponent por hover).
5. Considerar desactivar blur cuando `glassOpacity` es máximo (opaco).

## Nota
Profiling profundo (heaptrack/massif) requiere reiniciar el dock bajo el profiler;
pendiente para sesión dedicada sin interrumpir al usuario.
